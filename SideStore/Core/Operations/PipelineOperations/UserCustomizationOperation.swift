
//
//  UserCustomizationOperation.swift
//  AltStore
//
//  Created by SideStore Team.
//

import Foundation
import SideSign
import Roxas
import CoreData

@objc(ALTUserCustomizationOperation)
final class UserCustomizationOperation: ResultOperation<Void> {
    let context: InstallAppOperationContext

    init(context: InstallAppOperationContext) {
        self.context = context
        super.init()
    }

    override func main() {
        super.main()

        if let error = self.context.error {
            self.finish(.failure(error))
            return
        }

        Task {
            await executeCustomizations()
        }
    }

    private func executeCustomizations() async {
        // Skip customizations for updates/refreshes or when globally disabled unless a feature flag requires intervention.
        guard !context.isUpdate else {
            self.finish(.success(()))
            return
        }

        guard let app = context.app else {
            self.finish(.failure(OperationError.invalidParameters("UserCustomizationOperation.main: self.context.app is nil")))
            return
        }

        let defaults = UserDefaults.standard
        let isCustomizationEnabled = defaults.isUserCustomizationEnabled
        let shouldPromptPlaceholders = defaults.isRemoveAppPlaceholdersEnabled
        let shouldPromptMainBundleID = defaults.isSmartBundleIDReuseEnabled

        // Check installed state
        let bundleID = context.bundleIdentifier
        let installedSnap: (exists: Bool, name: String?, customId: String?, appendTeamId: Bool) = await DatabaseManager.shared.persistentContainer.viewContext.perform {
            let predicate = NSPredicate(format: "%K == %@", #keyPath(InstalledApp.bundleIdentifier), bundleID)
            if let installed = InstalledApp.first(satisfying: predicate, in: DatabaseManager.shared.persistentContainer.viewContext) {
                return (true, installed.customAppName, installed.customBundleIdentifier, installed.appendTeamID)
            }
            return (false, nil, nil, false)
        }

        if installedSnap.exists {
            // Re-apply stored customizations automatically
            context.customAppName = installedSnap.name
            context.customBundleIdentifier = installedSnap.customId
            context.appendTeamID = installedSnap.appendTeamId

            if let customName = installedSnap.name {
                applyCustomName(customName, to: app)
            }

            if shouldPromptPlaceholders {
                await promptAndRemoveExtensions(from: app, isPlaceholderCleanup: true)
            }

            self.finish(.success(()))
            return
        }

        // If none of the interactive features are enabled, exit early
        guard isCustomizationEnabled || shouldPromptPlaceholders || shouldPromptMainBundleID else {
            self.finish(.success(()))
            return
        }

        // Wait if pipelineHandler is nil? No, fallback to DefaultPipelineHandler
        let handler = context.pipelineHandler ?? DefaultPipelineHandler.shared

        var didCustomizeName = false
        var didCustomizeBundleID = false

        // 1. Custom App Name
        if isCustomizationEnabled && defaults.isCustomAppNameEnabled {
            let chosenName = await handler.requestCustomAppName(defaultName: app.name, bundleId: app.bundleIdentifier)
            let trimmed = chosenName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != app.name {
                context.customAppName = trimmed
                applyCustomName(trimmed, to: app)
                didCustomizeName = true
            }
        }

        // 2. Smart Main Bundle ID Reuse OR Standard Custom Bundle ID
        if shouldPromptMainBundleID || (isCustomizationEnabled && defaults.isCustomBundleIDEnabled) {
            let teamID = context.authenticatedAccount?.team?.identifier ?? ""
            let reusableCandidates = await fetchReusableMainBundleIDCandidates(
                for: app,
                teamID: teamID,
                includePortalAppIDs: shouldPromptMainBundleID
            )

            let result: (customID: String, appendTeamID: Bool)
            if shouldPromptMainBundleID {
                result = await handler.requestSmartBundleIDSelection(
                    appName: context.customAppName ?? app.name,
                    defaultBundleId: app.bundleIdentifier,
                    teamId: teamID,
                    candidates: reusableCandidates
                )
            } else {
                result = await handler.requestCustomBundleID(
                    defaultBundleId: app.bundleIdentifier,
                    teamId: teamID
                )
            }

            let chosenRawID = result.customID.trimmingCharacters(in: .whitespacesAndNewlines)

            // Check if the user selected one of the discovered reusable Portal/Cert candidates
            if let matchedCandidate = reusableCandidates.first(where: {
                $0.baseBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame ||
                $0.fullBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame
            }) {
                if matchedCandidate.requiresAppendingTeamID {
                    // Strip trailing TeamID so downstream operations append it cleanly once
                    // Example: "com.alone.37D6PWG5PP" -> base = "com.alone" + appendTeamID = true
                    let cleanBaseID = Self.stripTrailingTeamID(from: matchedCandidate.baseBundleIdentifier, teamID: teamID)
                    context.appendTeamID = true
                    if !cleanBaseID.isEmpty, cleanBaseID.caseInsensitiveCompare(context.bundleIdentifier) != .orderedSame {
                        context.customBundleIdentifier = cleanBaseID
                        didCustomizeBundleID = true
                    } else {
                        context.customBundleIdentifier = nil
                    }
                } else {
                    // Candidate either has embedded TeamID in the middle (e.g., com.kdt.livecontainer.TEAMID.LiveWidget)
                    // or does not end with .TEAMID -> use fullBundleIdentifier directly without appending TeamID again!
                    context.appendTeamID = false
                    if matchedCandidate.fullBundleIdentifier.caseInsensitiveCompare(context.bundleIdentifier) != .orderedSame {
                        context.customBundleIdentifier = matchedCandidate.fullBundleIdentifier
                        didCustomizeBundleID = true
                    } else {
                        context.customBundleIdentifier = nil
                    }
                }
            } else {
                // User manually typed a custom Bundle ID or kept the default
                // Always strip trailing TeamID if appendTeamID is enabled to prevent ".TEAMID.TEAMID" duplication!
                let normalizedID: String
                if result.appendTeamID && !teamID.isEmpty {
                    normalizedID = Self.stripTrailingTeamID(from: chosenRawID, teamID: teamID)
                } else {
                    normalizedID = chosenRawID
                }

                context.appendTeamID = result.appendTeamID
                if !normalizedID.isEmpty, normalizedID.caseInsensitiveCompare(context.bundleIdentifier) != .orderedSame {
                    context.customBundleIdentifier = normalizedID
                    didCustomizeBundleID = true
                } else {
                    context.customBundleIdentifier = nil
                }
            }
        }

        // 3. Extension Management / Remove App Placeholders (PlugIns)
        if shouldPromptPlaceholders || (isCustomizationEnabled && defaults.isExtensionMgmtEnabled) {
            await promptAndRemoveExtensions(
                from: app,
                isPlaceholderCleanup: shouldPromptPlaceholders && !(isCustomizationEnabled && defaults.isExtensionMgmtEnabled)
            )
        }

        // 4. Info.plist Editor (for Main App & Remaining App Extensions)
        if isCustomizationEnabled && defaults.isInfoPlistEditorEnabled {
            let editableBundles = loadEditableInfoPlistBundles(
                for: app,
                didCustomizeName: didCustomizeName,
                didCustomizeBundleID: didCustomizeBundleID
            )
            if !editableBundles.isEmpty {
                let editsByBundleID = await handler.requestInfoPlistEdits(bundles: editableBundles)
                if !editsByBundleID.isEmpty {
                    context.customInfoPlistByBundleID = editsByBundleID
                    applyInfoPlistEditsImmediately(editsByBundleID, to: app)
                }
            }
        }

        self.finish(.success(()))
    }

    // MARK: - Extension / Placeholder Removal

    private func promptAndRemoveExtensions(from app: ALTApplication, isPlaceholderCleanup: Bool) async {
        let handler = context.pipelineHandler ?? DefaultPipelineHandler.shared
        let extensions = app.appExtensions
        guard !extensions.isEmpty else { return }

        var extInfos: [InstallAppOperationContext.AppExtensionInfo] = []
        for ext in extensions {
            let size = (try? FileManager.default.allocatedSizeOfDirectory(at: ext.fileURL)) ?? 0
            extInfos.append(.init(
                name: ext.name,
                bundleIdentifier: ext.bundleIdentifier,
                fileURL: ext.fileURL,
                sizeInBytes: Int64(size)
            ))
        }

        let urlsToRemove = await handler.requestExtensionRemoval(extensions: extInfos)
        context.extensionsToRemove = urlsToRemove

        for url in urlsToRemove {
            do {
                try FileManager.default.removeItem(at: url)
                print("Removed extension/placeholder at \(url.lastPathComponent)")
            } catch {
                print("Failed to remove extension at \(url): \(error)")
            }
        }
    }

    // MARK: - Smart Bundle ID Reuse Discovery

    private func fetchReusableMainBundleIDCandidates(
        for app: ALTApplication,
        teamID: String,
        includePortalAppIDs: Bool
    ) async -> [InstallAppOperationContext.ReusableBundleIDCandidate] {
        var candidatesByFullID: [String: InstallAppOperationContext.ReusableBundleIDCandidate] = [:]
        let trailingSuffix = teamID.isEmpty ? "" : ".\(teamID)".lowercased()
        let middleToken = teamID.isEmpty ? "" : ".\(teamID).".lowercased()

        // A. Query existing InstalledApp & InactiveApp records from local CoreData
        let localCandidates: [InstallAppOperationContext.ReusableBundleIDCandidate] = await DatabaseManager.shared.persistentContainer.viewContext.perform {
            var results: [InstallAppOperationContext.ReusableBundleIDCandidate] = []
            let viewContext = DatabaseManager.shared.persistentContainer.viewContext

            let installedApps = InstalledApp.all(in: viewContext)
            for installed in installedApps {
                guard !InstalledApp.openAltStoreAppIDs.contains(installed.bundleIdentifier) else { continue }
                let rawBase = installed.customBundleIdentifier ?? installed.bundleIdentifier
                let full = installed.resignedBundleIdentifier
                let hasTrailingTeam = !teamID.isEmpty && full.lowercased().hasSuffix(trailingSuffix)
                let cleanBase = hasTrailingTeam ? Self.stripTrailingTeamID(from: full, teamID: teamID) : rawBase
                let hasEmbedded = !teamID.isEmpty && full.lowercased().contains(middleToken)
                let isExt = Self.looksLikeExtensionBundleID(baseID: cleanBase, fullID: full, name: installed.name)

                results.append(.init(
                    name: installed.customAppName ?? installed.name,
                    baseBundleIdentifier: cleanBase,
                    fullBundleIdentifier: full,
                    expirationDate: installed.expirationDate,
                    hasEmbeddedTeamID: hasEmbedded,
                    requiresAppendingTeamID: hasTrailingTeam || installed.appendTeamID,
                    isLikelyExtension: isExt,
                    sourceDescription: "Đã cài trên thiết bị"
                ))
            }

            let inactiveApps = InactiveApp.all(in: viewContext)
            for inactive in inactiveApps {
                let base = inactive.bundleIdentifier
                let full = (!teamID.isEmpty && !base.lowercased().contains(teamID.lowercased())) ? "\(base).\(teamID)" : base
                let hasTrailingTeam = !teamID.isEmpty && full.lowercased().hasSuffix(trailingSuffix)
                let cleanBase = hasTrailingTeam ? Self.stripTrailingTeamID(from: full, teamID: teamID) : base
                let hasEmbedded = !teamID.isEmpty && full.lowercased().contains(middleToken)
                let isExt = Self.looksLikeExtensionBundleID(baseID: cleanBase, fullID: full, name: inactive.name)

                results.append(.init(
                    name: inactive.name,
                    baseBundleIdentifier: cleanBase,
                    fullBundleIdentifier: full,
                    expirationDate: nil,
                    hasEmbeddedTeamID: hasEmbedded,
                    requiresAppendingTeamID: hasTrailingTeam,
                    isLikelyExtension: isExt,
                    sourceDescription: "Ứng dụng không hoạt động"
                ))
            }
            return results
        }

        for item in localCandidates {
            candidatesByFullID[item.fullBundleIdentifier.lowercased()] = item
        }

        // B. Query Apple Developer Portal App IDs (if authenticated & requested)
        if includePortalAppIDs, let team = context.authenticatedAccount?.team {
            if let portalAppIDs = try? await DeveloperPortalProxy.shared.fetchAppIDs(for: team) {
                for portalID in portalAppIDs {
                    let fullID = portalID.bundleIdentifier
                    let lowerFull = fullID.lowercased()

                    // Skip SideStore/AltStore's own bundle IDs
                    if lowerFull.contains("com.rileytestut.altstore") || lowerFull.contains("com.sidestore.sidestore") {
                        continue
                    }

                    let hasTrailingTeamID = !teamID.isEmpty && lowerFull.hasSuffix(trailingSuffix)
                    let hasEmbeddedTeamID = !teamID.isEmpty && lowerFull.contains(middleToken)

                    let baseID: String
                    if hasTrailingTeamID {
                        baseID = Self.stripTrailingTeamID(from: fullID, teamID: teamID)
                    } else {
                        baseID = fullID
                    }

                    let isExt = Self.looksLikeExtensionBundleID(baseID: baseID, fullID: fullID, name: portalID.name)
                    let existing = candidatesByFullID[lowerFull]

                    candidatesByFullID[lowerFull] = .init(
                        name: existing?.name ?? portalID.name,
                        baseBundleIdentifier: baseID,
                        fullBundleIdentifier: fullID,
                        expirationDate: portalID.expirationDate ?? existing?.expirationDate,
                        hasEmbeddedTeamID: hasEmbeddedTeamID,
                        requiresAppendingTeamID: hasTrailingTeamID,
                        isLikelyExtension: isExt,
                        sourceDescription: existing != nil ? "Đã cài & Có trên Chứng chỉ" : "Có sẵn trên Chứng chỉ Apple"
                    )
                }
            }
        }

        // Sort: Main App IDs first, then non-expired, then alphabetical by name
        return candidatesByFullID.values.sorted { lhs, rhs in
            if lhs.isLikelyExtension != rhs.isLikelyExtension {
                return !lhs.isLikelyExtension
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func stripTrailingTeamID(from bundleID: String, teamID: String) -> String {
        guard !teamID.isEmpty else { return bundleID }
        let suffix = ".\(teamID)"
        var result = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        while result.lowercased().hasSuffix(suffix.lowercased()), result.count > suffix.count {
            result = String(result.dropLast(suffix.count))
        }
        return result
    }

    private static func looksLikeExtensionBundleID(baseID: String, fullID: String, name: String) -> Bool {
        let combined = "\(baseID.lowercased()) \(fullID.lowercased()) \(name.lowercased())"
        let extensionKeywords = [
            "widget", "extension", "notification", "intents", "share",
            "siri", "watchkit", "clip", "keyboard", "fileprovider",
            "broadcast", "tunnel", "packet", "safari", "action", "today"
        ]
        return extensionKeywords.contains { combined.contains($0) }
    }

    // MARK: - Info.plist Helpers

    private func loadEditableInfoPlistBundles(
        for app: ALTApplication,
        didCustomizeName: Bool,
        didCustomizeBundleID: Bool
    ) -> [InstallAppOperationContext.EditableInfoPlistBundle] {
        var result: [InstallAppOperationContext.EditableInfoPlistBundle] = []

        if var entries = readStringEntriesFromInfoPlist(at: app.fileURL) {
            if didCustomizeName, let customName = context.customAppName {
                entries["CFBundleDisplayName"] = customName
                entries["CFBundleName"] = customName
            }
            if didCustomizeBundleID, let customID = context.customBundleIdentifier {
                entries["CFBundleIdentifier"] = customID
            }
            result.append(.init(
                id: app.bundleIdentifier,
                title: "Ứng dụng chính (\(context.customAppName ?? app.name))",
                bundlePath: app.fileURL.path,
                entries: entries
            ))
        }

        let removedPaths = Set(context.extensionsToRemove.map { $0.path })
        for ext in app.appExtensions where !removedPaths.contains(ext.fileURL.path) {
            guard FileManager.default.fileExists(atPath: ext.fileURL.path),
                  let entries = readStringEntriesFromInfoPlist(at: ext.fileURL) else { continue }
            result.append(.init(
                id: ext.bundleIdentifier,
                title: "Extension: \(ext.name)",
                bundlePath: ext.fileURL.path,
                entries: entries
            ))
        }

        return result
    }

    private func readStringEntriesFromInfoPlist(at bundleURL: URL) -> [String: String]? {
        let plistURL = bundleURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return nil
        }

        var entries: [String: String] = [:]
        for (key, value) in plist {
            if let str = value as? String {
                entries[key] = str
            } else if let boolVal = value as? Bool {
                entries[key] = boolVal ? "true" : "false"
            } else if let num = value as? NSNumber {
                entries[key] = num.stringValue
            }
        }
        return entries
    }

    private func applyInfoPlistEditsImmediately(_ editsByBundleID: [String: [String: String]], to app: ALTApplication) {
        if let mainEdits = editsByBundleID[app.bundleIdentifier] {
            writeInfoPlistEdits(mainEdits, toBundleAt: app.fileURL)
            if let updatedName = mainEdits["CFBundleDisplayName"] ?? mainEdits["CFBundleName"],
               !updatedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                context.customAppName = updatedName
            }
            if let editedBundleID = mainEdits["CFBundleIdentifier"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !editedBundleID.isEmpty {
                let teamID = context.authenticatedAccount?.team?.identifier ?? ""
                let cleanedEditedID = context.appendTeamID
                    ? Self.stripTrailingTeamID(from: editedBundleID, teamID: teamID)
                    : editedBundleID
                if !cleanedEditedID.isEmpty, cleanedEditedID.caseInsensitiveCompare(app.bundleIdentifier) != .orderedSame {
                    context.customBundleIdentifier = cleanedEditedID
                }
            }
        }

        for ext in app.appExtensions {
            if let extEdits = editsByBundleID[ext.bundleIdentifier],
               FileManager.default.fileExists(atPath: ext.fileURL.path) {
                writeInfoPlistEdits(extEdits, toBundleAt: ext.fileURL)
            }
        }
    }

    private func writeInfoPlistEdits(_ edits: [String: String], toBundleAt bundleURL: URL) {
        let plistURL = bundleURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
            return
        }

        for (key, rawValue) in edits {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased() == "true" {
                plist[key] = true
            } else if trimmed.lowercased() == "false" {
                plist[key] = false
            } else if let intVal = Int(trimmed), String(intVal) == trimmed {
                plist[key] = intVal
            } else {
                plist[key] = rawValue
            }
        }

        if let updatedData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? updatedData.write(to: plistURL)
        }
    }

    private func applyCustomName(_ name: String, to app: ALTApplication) {
        let infoPlistURL = app.fileURL.appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoPlistURL),
              var plist = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] else {
            return
        }

        plist["CFBundleDisplayName"] = name
        plist["CFBundleName"] = name

        if let updatedData = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? updatedData.write(to: infoPlistURL)
        }

        // Remove localized CFBundleDisplayName / CFBundleName in .lproj folders so iOS doesn't override custom name
        if let contents = try? FileManager.default.contentsOfDirectory(at: app.fileURL, includingPropertiesForKeys: nil) {
            for url in contents where url.pathExtension == "lproj" {
                let stringsURL = url.appendingPathComponent("InfoPlist.strings")
                if FileManager.default.fileExists(atPath: stringsURL.path),
                   let stringsData = try? Data(contentsOf: stringsURL),
                   var stringsDict = try? PropertyListSerialization.propertyList(from: stringsData, options: .mutableContainersAndLeaves, format: nil) as? [String: Any] {
                    stringsDict["CFBundleDisplayName"] = name
                    stringsDict["CFBundleName"] = name
                    if let newData = try? PropertyListSerialization.data(fromPropertyList: stringsDict, format: .xml, options: 0) {
                        try? newData.write(to: stringsURL)
                    }
                }
            }
        }
    }
}

extension FileManager {
    func allocatedSizeOfDirectory(at directoryURL: URL) throws -> UInt64 {
        var accumulatedSize: UInt64 = 0
        let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .fileAllocatedSizeKey, .totalFileAllocatedSizeKey]

        guard let enumerator = self.enumerator(at: directoryURL, includingPropertiesForKeys: resourceKeys, options: [], errorHandler: nil) else {
            return 0
        }

        for case let fileURL as URL in enumerator {
            let resourceValues = try fileURL.resourceValues(forKeys: Set(resourceKeys))
            guard resourceValues.isRegularFile ?? false else { continue }
            accumulatedSize += UInt64(resourceValues.totalFileAllocatedSize ?? resourceValues.fileAllocatedSize ?? 0)
        }

        return accumulatedSize
    }
}
