
//
//  UserCustomizationOperation.swift
//  AltStore
//
//  Created by SideStore Team.
//  Copyright © 2024 SideStore. All rights reserved.
//

import Foundation
import AltStoreCore
import Roxas

@objc(ALTUserCustomizationOperation)
final class UserCustomizationOperation: ResultOperation<Void> {
    let context: InstallAppOperationContext
    private var hasCleanedUp = false
    
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
        
        Task<Void, Never> {
            do {
                try await performCustomizations()
                self.finish(.success(()))
            } catch {
                self.finish(.failure(error))
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func performCustomizations() async throws {
        // Skip customizations for updates/refreshes or when globally disabled unless a feature flag requires intervention.
        guard !context.isUpdate else { return }
        
        guard let app = context.app else {
            throw OperationError.invalidParameters("UserCustomizationOperation.performCustomizations: self.context.app is nil")
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
            return (false, nil, nil, true)
        }
        
        let isInstalled = installedSnap.exists
        if isInstalled {
            context.customAppName = installedSnap.name
            context.customBundleIdentifier = installedSnap.customId
            context.appendTeamID = installedSnap.appendTeamId
        }
        
        var didCustomizeName = false
        var didCustomizeBundleID = false
        
        // 1. Prompt for Custom App Name (only on new installs if enabled)
        if !isInstalled && isCustomizationEnabled && defaults.isCustomAppNameEnabled {
            if let handler = context.pipelineHandler {
                let customName = try await handler.requestCustomAppName(defaultName: app.name, bundleId: app.bundleIdentifier)
                let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, trimmed != app.name {
                    context.customAppName = trimmed
                    didCustomizeName = true
                } else {
                    context.customAppName = nil
                }
            }
        }
        
        // 2. Prompt for Custom Bundle ID / Smart Bundle ID Reuse (only on new installs if enabled)
        let shouldShowBundleIDUI = !isInstalled && (
            shouldPromptMainBundleID ||
            (isCustomizationEnabled && defaults.isCustomBundleIDEnabled)
        )
        
        if shouldShowBundleIDUI, let handler = context.pipelineHandler {
            let teamID = context.authenticatedAccount?.team?.identifier ?? ""
            let reusableCandidates = await fetchReusableMainBundleIDCandidates(
                for: app,
                teamID: teamID,
                includePortalAppIDs: shouldPromptMainBundleID
            )
            
            let result: (customID: String, appendTeamID: Bool)
            if shouldPromptMainBundleID {
                result = try await handler.requestSmartBundleIDSelection(
                    appName: context.customAppName ?? app.name,
                    defaultBundleId: app.bundleIdentifier,
                    teamId: teamID,
                    candidates: reusableCandidates
                )
            } else {
                result = try await handler.requestCustomBundleID(
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
                    // Embedded TeamID in the middle (e.g., com.kdt.livecontainer.TEAMID.Widget)
                    // Keep full ID and disable automatic trailing TeamID append
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
        
        // 3. Prompt for App Extensions / Placeholders Removal
        // Shown when either RemoveAppPlaceholders is enabled OR UserCustomization + ExtensionMgmt is enabled
        let allExtensions = Array(app.appExtensions)
        let shouldShowExtensionRemovalUI = !allExtensions.isEmpty && (
            shouldPromptPlaceholders ||
            (isCustomizationEnabled && defaults.isExtensionMgmtEnabled)
        )
        
        if shouldShowExtensionRemovalUI, let handler = context.pipelineHandler {
            let extensionInfos = allExtensions.map { ext in
                let sizeInBytes = FileManager.default.directorySize(at: ext.fileURL) ?? 0
                return AppExtensionInfo(
                    name: ext.name,
                    bundleIdentifier: ext.bundleIdentifier,
                    fileURL: ext.fileURL,
                    sizeInBytes: sizeInBytes
                )
            }
            
            let extensionsToRemove = try await handler.requestExtensionRemoval(extensions: extensionInfos)
            context.extensionsToRemove = extensionsToRemove
            
            // Immediately remove selected extensions from the temporary app bundle on disk
            // so subsequent operations (App Group assignment, Provisioning Profile fetching) skip them!
            for extURL in extensionsToRemove {
                if FileManager.default.fileExists(atPath: extURL.path) {
                    try? FileManager.default.removeItem(at: extURL)
                }
            }
        }
        
        // 4. Prompt for Info.plist Editor (if enabled)
        if isCustomizationEnabled && defaults.isInfoPlistEditorEnabled, let handler = context.pipelineHandler {
            var bundles: [EditableInfoPlistBundle] = []
            
            // Main App Bundle
            let mainInfoPlistURL = app.fileURL.appendingPathComponent("Info.plist")
            if let rawDict = NSDictionary(contentsOf: mainInfoPlistURL) as? [String: Any] {
                var stringDict: [String: String] = [:]
                for (key, value) in rawDict {
                    stringDict[key] = Self.stringifyPlistValue(value)
                }
                
                // Pre-fill customized Name / Bundle ID if changed in earlier steps
                if didCustomizeName, let customName = context.customAppName {
                    stringDict["CFBundleDisplayName"] = customName
                    stringDict["CFBundleName"] = customName
                }
                if didCustomizeBundleID, let customID = context.customBundleIdentifier {
                    stringDict["CFBundleIdentifier"] = customID
                }
                
                bundles.append(EditableInfoPlistBundle(
                    id: app.bundleIdentifier,
                    title: "\(context.customAppName ?? app.name) (Ứng dụng chính)",
                    bundlePath: app.fileURL.path,
                    entries: stringDict
                ))
            }
            
            // Remaining Extensions (excluding those already deleted in Step 3)
            let removedPaths = Set(context.extensionsToRemove.map { $0.path })
            for ext in app.appExtensions where !removedPaths.contains(ext.fileURL.path) {
                let extPlistURL = ext.fileURL.appendingPathComponent("Info.plist")
                if let rawDict = NSDictionary(contentsOf: extPlistURL) as? [String: Any] {
                    var stringDict: [String: String] = [:]
                    for (key, value) in rawDict {
                        stringDict[key] = Self.stringifyPlistValue(value)
                    }
                    bundles.append(EditableInfoPlistBundle(
                        id: ext.bundleIdentifier,
                        title: "\(ext.name) (Phần mở rộng)",
                        bundlePath: ext.fileURL.path,
                        entries: stringDict
                    ))
                }
            }
            
            if !bundles.isEmpty {
                let editedMap = try await handler.requestInfoPlistEdits(bundles: bundles)
                context.customInfoPlistByBundleID = editedMap
                
                // Sync back Display Name or Bundle ID if user edited them directly inside the Info.plist Editor
                if let mainEdits = editedMap[app.bundleIdentifier] {
                    if let editedDisplayName = mainEdits["CFBundleDisplayName"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !editedDisplayName.isEmpty,
                       editedDisplayName != app.name {
                        context.customAppName = editedDisplayName
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
            }
        }
    }
    
    // MARK: - Smart Bundle ID Reuse Discovery
    
    private func fetchReusableMainBundleIDCandidates(
        for app: ALTApplication,
        teamID: String,
        includePortalAppIDs: Bool
    ) async -> [ReusableBundleIDCandidate] {
        var candidatesByFullID: [String: ReusableBundleIDCandidate] = [:]
        let trailingSuffix = teamID.isEmpty ? "" : ".\(teamID)".lowercased()
        let middleToken = teamID.isEmpty ? "" : ".\(teamID).".lowercased()
        
        // 1. Fetch active/expired App IDs from Apple Developer Portal (if authenticated)
        if includePortalAppIDs, let team = context.authenticatedAccount?.team {
            if let portalAppIDs = try? await DeveloperPortalProxy.shared.fetchAppIDs(for: team) {
                for appID in portalAppIDs {
                    let fullID = appID.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !fullID.isEmpty else { continue }
                    
                    // Filter out obvious AltStore/SideStore internal IDs if needed, or keep all user App IDs
                    let lowerFull = fullID.lowercased()
                    let hasTrailingTeamID = !teamID.isEmpty && lowerFull.hasSuffix(trailingSuffix)
                    let hasEmbeddedTeamID = !teamID.isEmpty && lowerFull.contains(middleToken)
                    
                    let baseID: String
                    let requiresAppending: Bool
                    
                    if hasTrailingTeamID {
                        baseID = Self.stripTrailingTeamID(from: fullID, teamID: teamID)
                        requiresAppending = true
                    } else if hasEmbeddedTeamID {
                        baseID = fullID
                        requiresAppending = false
                    } else {
                        baseID = fullID
                        requiresAppending = false
                    }
                    
                    let isLikelyExtension = Self.isLikelyExtensionBundleID(
                        fullBundleID: fullID,
                        baseBundleID: baseID,
                        name: appID.name,
                        allPortalAppIDs: portalAppIDs
                    )
                    
                    let candidate = ReusableBundleIDCandidate(
                        name: appID.name,
                        baseBundleIdentifier: baseID,
                        fullBundleIdentifier: fullID,
                        expirationDate: appID.expirationDate,
                        hasEmbeddedTeamID: hasEmbeddedTeamID && !hasTrailingTeamID,
                        requiresAppendingTeamID: requiresAppending,
                        isLikelyExtension: isLikelyExtension,
                        sourceDescription: "Apple Developer Portal"
                    )
                    candidatesByFullID[lowerFull] = candidate
                }
            }
        }
        
        // 2. Also inspect locally stored InstalledApps / InactiveApps in CoreData
        let localRecords: [(name: String, baseID: String, resignedID: String, appendTeam: Bool)] = await DatabaseManager.shared.persistentContainer.viewContext.perform {
            let fetchRequest = InstalledApp.fetchRequest()
            guard let apps = try? DatabaseManager.shared.persistentContainer.viewContext.fetch(fetchRequest) else {
                return []
            }
            return apps.map { installed in
                let effectiveBase = installed.customBundleIdentifier ?? installed.bundleIdentifier
                return (
                    name: installed.customAppName ?? installed.name,
                    baseID: effectiveBase,
                    resignedID: installed.resignedBundleIdentifier,
                    appendTeam: installed.appendTeamID
                )
            }
        }
        
        for record in localRecords {
            let fullID = record.resignedID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullID.isEmpty else { continue }
            let lowerFull = fullID.lowercased()
            
            if candidatesByFullID[lowerFull] == nil {
                let hasTrailingTeamID = !teamID.isEmpty && lowerFull.hasSuffix(trailingSuffix)
                let hasEmbeddedTeamID = !teamID.isEmpty && lowerFull.contains(middleToken)
                let cleanBase = hasTrailingTeamID
                    ? Self.stripTrailingTeamID(from: fullID, teamID: teamID)
                    : record.baseID
                
                candidatesByFullID[lowerFull] = ReusableBundleIDCandidate(
                    name: record.name,
                    baseBundleIdentifier: cleanBase,
                    fullBundleIdentifier: fullID,
                    expirationDate: nil,
                    hasEmbeddedTeamID: hasEmbeddedTeamID && !hasTrailingTeamID,
                    requiresAppendingTeamID: hasTrailingTeamID || record.appendTeam,
                    isLikelyExtension: false,
                    sourceDescription: "Đã lưu trên thiết bị"
                )
            }
        }
        
        // Sort: Main App IDs first, then by matching current app name/ID, then alphabetically
        return candidatesByFullID.values.sorted { lhs, rhs in
            if lhs.isLikelyExtension != rhs.isLikelyExtension {
                return !lhs.isLikelyExtension
            }
            let lhsMatchesDefault = lhs.baseBundleIdentifier.caseInsensitiveCompare(app.bundleIdentifier) == .orderedSame
            let rhsMatchesDefault = rhs.baseBundleIdentifier.caseInsensitiveCompare(app.bundleIdentifier) == .orderedSame
            if lhsMatchesDefault != rhsMatchesDefault {
                return lhsMatchesDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    /// Repeatedly strips `.TEAMID` from the end of a Bundle ID so it can never be duplicated into `.TEAMID.TEAMID`.
    private static func stripTrailingTeamID(from bundleID: String, teamID: String) -> String {
        let trimmedTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTeam.isEmpty else { return bundleID }
        
        var result = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = "." + trimmedTeam
        
        while result.lowercased().hasSuffix(suffix.lowercased()), result.count > suffix.count {
            result = String(result.dropLast(suffix.count))
        }
        return result
    }
    
    private static func isLikelyExtensionBundleID(
        fullBundleID: String,
        baseBundleID: String,
        name: String,
        allPortalAppIDs: [ALTAppID]
    ) -> Bool {
        let lowerFull = fullBundleID.lowercased()
        let lowerBase = baseBundleID.lowercased()
        let lowerName = name.lowercased()
        
        // 1. Check if another App ID in the portal is a strict prefix of this App ID
        for other in allPortalAppIDs {
            let otherFull = other.bundleIdentifier.lowercased()
            if otherFull != lowerFull && lowerFull.hasPrefix(otherFull + ".") {
                return true
            }
        }
        
        // 2. Common iOS App Extension suffixes/keywords
        let extensionKeywords = [
            "widget", "extension", "intents", "notification", "share",
            "siri", "watchkit", "today", "keyboard", "fileprovider",
            "broadcast", "clip", "stickers", "action", "safari"
        ]
        for keyword in extensionKeywords {
            if lowerBase.hasSuffix(".\(keyword)") || lowerName.hasSuffix(" \(keyword)") {
                return true
            }
        }
        
        return false
    }
    
    private static func stringifyPlistValue(_ value: Any) -> String {
        if let str = value as? String {
            return str
        } else if let num = value as? NSNumber {
            if CFGetTypeID(num) == CFBooleanGetTypeID() {
                return num.boolValue ? "true" : "false"
            }
            return num.stringValue
        } else if let data = try? PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0),
                  let xmlString = String(data: data, encoding: .utf8) {
            return xmlString
        }
        return String(describing: value)
    }
    
    // MARK: - Cleanup
    
    override func finish(_ result: Result<Void, Error>) {
        cleanup()
        super.finish(result)
    }
    
    private func cleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        // Perform any temporary resource cleanup if needed
    }
}
