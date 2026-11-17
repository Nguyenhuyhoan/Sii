//
//  ResignAppOperation.swift
//  AltStore
//
//  Created by Riley Testut on 6/7/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import Foundation
import SideSign

final class ResignAppOperation: BasePipelineOperation<InstallAppOperationContext, ALTApplication>, @unchecked Sendable {
    
    override func execute(parentProgress: Progress?) async throws -> ALTApplication {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[ResignAppOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[ResignAppOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)
        
        let team = try await AuthManager.shared.getAuthenticatedTeam()
        guard
            let appBundle = self.context.targetAppBundle,
            let profiles = self.context.provisioningProfiles,
            let certificate = self.context.targetSigningCertificate
        else {
            throw OperationError.invalidParameters("ResignAppOperation.main: " +
                                                   "self.context.targetAppBundle or " +
                                                   "self.context.provisioningProfiles or " +
                                                   "self.context.targetSigningCertificate is nil")
        }
        
        debugLog("[ResignAppOperation] Resigning app \(self.context.bundleIdentifier)...")
        
        self.setProgress(5)
        
        let appBundleURL = try await self.prepareAppBundle(for: appBundle, profiles: profiles, appexBundleIds: context.appexBundleIds ?? [:])
        
        self.setProgress(40)
        
        let resignedAppURL = try await self.resignAppBundle(at: appBundleURL, team: team, certificate: certificate, profiles: Array(profiles.values))
        guard let resignedAppBundle = ALTApplication(fileURL: resignedAppURL) else {
            throw OperationError.invalidApp(reason: "Could not load resigned app bundle at '\(resignedAppURL.lastPathComponent)'")
        }
        
        self.debugLog("[ResignAppOperation] Resigned app \(self.context.bundleIdentifier) to \(resignedAppBundle.bundleIdentifier).")
        self.setProgress(100)
        
        return resignedAppBundle
    }

    private func prepareAppBundle(for targetAppBundle: ALTApplication, profiles: [String: ALTProvisioningProfile], appexBundleIds: [String: String]) async throws -> URL {
        let bundleIdentifier = context.targetBundleIdentifier
        let originalBundleIdentifier = targetAppBundle.bundleIdentifier
        let isAltStoreApp = targetAppBundle.isAltStoreApp
        
        let finalBundleIdentifier: String
        if let profile = context.useMainProfile ? profiles.values.first : profiles[bundleIdentifier] {
            finalBundleIdentifier = appexBundleIds[bundleIdentifier] ?? profile.bundleIdentifier
        } else {
            finalBundleIdentifier = bundleIdentifier
        }
        
        // Use customized bundle ID if applicable
        let openURL = InstalledApp.openAppURL(targetBundleIdentifier: finalBundleIdentifier)
        let fileURL = targetAppBundle.fileURL
        let appBundleURL = self.context.temporaryDirectory.appendingPathComponent("App.app")
        
        // SMART MOVE / COPY: Chuẩn hóa đường dẫn để so sánh chính xác (tránh lỗi symlink /private/var và /var trên iOS)
        let sourcePath = fileURL.standardizedFileURL.path
        let destinationPath = appBundleURL.standardizedFileURL.path
        let tempDirPath = self.context.temporaryDirectory.standardizedFileURL.path
        
        if sourcePath != destinationPath {
            if FileManager.default.fileExists(atPath: destinationPath) {
                try FileManager.default.removeItem(at: appBundleURL)
            }
            
            // Nếu file gốc đã nằm trong thư mục tạm (vừa giải nén từ IPA), chỉ cần Move (đổi tên) để đạt tốc độ tức thì.
            // Nếu nằm ngoài (ví dụ: đang refresh app hoặc cài chính SideStore), thực hiện Copy để bảo toàn file gốc.
            if sourcePath.hasPrefix(tempDirPath) {
                try FileManager.default.moveItem(at: fileURL, to: appBundleURL)
            } else {
                try FileManager.default.copyItem(at: fileURL, to: appBundleURL)
            }
        }
        
        guard let appBundle = ALTApplication(fileURL: appBundleURL) else {
            throw OperationError.missingAppBundle(reason: "Could not load bundle at '\(appBundleURL.lastPathComponent)'")
        }
        
        // Replace scheme targets to match the bundle suffix so multiple instances can be correctly routed for helper apps like SideBackup
        var allURLSchemes = appBundle.infoPlist[Bundle.Info.urlTypes] as? [[String: Any]] ?? []
        allURLSchemes.removeAll { urlType in
            guard let schemes = urlType["CFBundleURLSchemes"] as? [String] else { return false }
            return schemes.contains { $0.hasPrefix("sidestore-") }
        }
        
        if let scheme = openURL.scheme {
            let altstoreURLScheme: [String: Any] = [
                "CFBundleTypeRole": "Editor",
                "CFBundleURLName": finalBundleIdentifier,
                "CFBundleURLSchemes": [scheme]
            ]
            allURLSchemes.append(altstoreURLScheme)
        }
        
        var additionalValues: [String: Any] = [Bundle.Info.urlTypes: allURLSchemes]

        if isAltStoreApp {
            if let activeCert = CertificateManager.shared.activeCertificate {
                additionalValues[Bundle.Info.certificateID] = activeCert.serialNumber
                let certURL = appBundle.fileURL.appendingPathComponent("ALTCertificate.p12")
                try activeCert.p12Data.write(to: certURL, options: .atomic)
            } else {
                self.verboseLog("[ResignAppOperation] No activeCertificate found in CertificateManager. Embedded certificate + certificate identifier in app bundle will not be updated.")
            }
        }
        
        // Prepare main app
        try self.prepare(appBundle, bundleID: bundleIdentifier, additionalInfoDictionaryValues: additionalValues, profiles: profiles, appexBundleIds: appexBundleIds)
        try self.removeMissingAppExtensionReferences(from: appBundle)
        
        // Prepare app extensions
        for appExtension in appBundle.appExtensions {
            let updatedAppExBundleId = appExtension.bundleIdentifier.replacingOccurrences(of: originalBundleIdentifier, with: bundleIdentifier)
            try self.prepare(appExtension, bundleID: updatedAppExBundleId, profiles: profiles, appexBundleIds: appexBundleIds)
        }
        
        return appBundleURL
    }
    
    private func prepare(_ appBundle: ALTApplication, bundleID identifier: String?, additionalInfoDictionaryValues: [String: Any] = [:], profiles: [String: ALTProvisioningProfile], appexBundleIds: [String: String]) throws {
        guard let identifier else {
            throw OperationError.invalidParameters("Bundle is missing bundle identifier.")
        }
        guard let profile = context.useMainProfile ? profiles.values.first : profiles[identifier] else {
            throw OperationError.missingProvisioningProfile(reason: "No provisioning profile found for identifier '\(identifier)'.")
        }
        guard let parser = try? InfoPlistParser(plistURL: appBundle.infoPlistURL) else {
            throw OperationError.missingInfoPlist(reason: "Could not read Info.plist for bundle '\(identifier)'.")
        }
        var infoDictionary = parser.rawDictionary as [String: Any]
        
        let bundleIDKey = kCFBundleIdentifierKey as String
        let newBundleID = appexBundleIds[identifier] ?? profile.bundleIdentifier
        infoDictionary[bundleIDKey] = newBundleID

        // Fix-up BGTaskScheduler identifiers so they stay under the new bundle ID.
        if identifier != newBundleID, let taskIDs = infoDictionary["BGTaskSchedulerPermittedIdentifiers"] as? [String] {
            infoDictionary["BGTaskSchedulerPermittedIdentifiers"] = self.rewrittenTaskSchedulerIdentifiers(taskIDs, from: identifier, to: newBundleID)
        }

        infoDictionary.removeValue(forKey: "DTXcode")
        infoDictionary.removeValue(forKey: "DTXcodeBuild")

        for (key, value) in additionalInfoDictionaryValues {
            infoDictionary[key] = value
        }

        if let customPlist = context.customInfoPlistByBundleID[identifier] {
            for (key, value) in customPlist where key != bundleIDKey {
                infoDictionary[key] = value
            }
        }

        if let appGroups = profile.entitlements[.appGroups] as? [String],
           var extensionInfo = infoDictionary["NSExtension"] as? [String: Any],
           let appGroup = extensionInfo["NSExtensionFileProviderDocumentGroup"] as? String,
           let localAppGroup = appGroups.filter({ $0.contains(appGroup) }).min(by: { $0.count < $1.count }) {
            // To keep file providers working, remap the NSExtensionFileProviderDocumentGroup, if there is one.
            extensionInfo["NSExtensionFileProviderDocumentGroup"] = localAppGroup
            infoDictionary["NSExtension"] = extensionInfo
        }
        
        // Add app-specific exported UTI so we can check later if this app (extension) is installed or not.
        let installedAppUTI: [String: Any] = [
            "UTTypeConformsTo": [],
            "UTTypeDescription": "AltStore Installed App",
            "UTTypeIconFiles": [],
            "UTTypeIdentifier": InstalledApp.installedAppUTI(forBundleIdentifier: profile.bundleIdentifier),
            "UTTypeTagSpecification": [:]
        ]
        
        var exportedUTIs = infoDictionary[Bundle.Info.exportedUTIs] as? [[String: Any]] ?? []
        exportedUTIs.append(installedAppUTI)
        infoDictionary[Bundle.Info.exportedUTIs] = exportedUTIs
        
        try InfoPlistParser(dictionary: infoDictionary).write(to: appBundle.infoPlistURL)
        
        // Remove _CodeSignature folder (if it exists)
        let codeSignatureURL = appBundle.fileURL.appendingPathComponent("_CodeSignature")
        if FileManager.default.fileExists(atPath: codeSignatureURL.path) {
            try FileManager.default.removeItem(at: codeSignatureURL)
            self.verboseLog("[ResignAppOperation] Removed _CodeSignature folder at \(codeSignatureURL.path)")
        }
    }
    
    private func resignAppBundle(at fileURL: URL, team: ALTTeam, certificate: ALTCertificate, profiles: [ALTProvisioningProfile]) async throws -> URL {
        let signer = ALTSigner(team: team, certificate: certificate)
        try await signer.signApp(at: fileURL, provisioningProfiles: profiles, progress: nil)
        return fileURL
    }
    
    private func removeMissingAppExtensionReferences(from appBundle: ALTApplication) throws {
        let manifestPlistURL = appBundle.fileURL.appendingPathComponent("SC_Info/Manifest.plist")
        
        guard let manifestPlist = try? InfoPlistParser(plistURL: manifestPlistURL),
              let sinfReplicationPaths = manifestPlist.rawDictionary["SinfReplicationPaths"] as? [String] else { return }
        
        // Remove references to missing files.
        let filteredReplicationPaths = sinfReplicationPaths.filter { path in
            guard let fileURL = URL(string: path, relativeTo: appBundle.fileURL) else { return false }
            return FileManager.default.fileExists(atPath: fileURL.path)
        }
        
        var updatedManifest = manifestPlist.rawDictionary
        updatedManifest["SinfReplicationPaths"] = filteredReplicationPaths
        
        try InfoPlistParser(dictionary: updatedManifest).write(to: manifestPlistURL)
    }

    private func rewrittenTaskSchedulerIdentifiers(_ taskIDs: [String], from originalBundleID: String, to newBundleID: String) -> [String] {
        var seen = Set<String>()
        var rewrittenTaskIDs = [String]()
        for taskID in taskIDs {
            let rewritten: String
            if taskID == newBundleID || taskID.hasPrefix(newBundleID + ".") {
                rewritten = taskID
            } else if taskID == originalBundleID || taskID.hasPrefix(originalBundleID + ".") {
                rewritten = newBundleID + taskID.dropFirst(originalBundleID.count)
            } else {
                rewritten = taskID
            }
            if seen.insert(rewritten).inserted {
                rewrittenTaskIDs.append(rewritten)
            }
        }
        return rewrittenTaskIDs
    }
}
