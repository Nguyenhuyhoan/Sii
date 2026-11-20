
//
//  FetchProvisioningProfilesOperation.swift
//  AltStore
//
//  Created by Riley Testut on 6/18/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import CoreData

import AltSign
import AltStoreCore
import Roxas

@objc(FetchProvisioningProfilesOperation)
final class FetchProvisioningProfilesOperation: ResultOperation<[String: ALTProvisioningProfile]> {
    let context: AppOperationContext
    
    /// Enables verbose debug logging to the error log when user toggles the setting.
    private var isVerboseLoggingEnabled: Bool {
        UserDefaults.standard.isAltEventSubscriberAdded
    }
    
    init(context: AppOperationContext) {
        self.context = context
        
        super.init()
        
        // Progress Profile:
        //  1: Refresh Team (FetchTeamOperation)
        //  2: Refresh Certificate (FetchCertificateOperation)
        //  5: Fetch Provisioning Profiles (main)
        self.progress.totalUnitCount = 8
    }
    
    // MARK: - Logging Helpers
    
    private func verboseLog(_ message: String) {
        guard self.isVerboseLoggingEnabled else { return }
        Logger.sidestore.notice("\(message, privacy: .public)")
    }
    
    private func debugLog(_ message: String) {
        Logger.sidestore.debug("\(message, privacy: .public)")
    }
    
    // MARK: - Operation Entry
    
    override func main() {
        super.main()
        
        if let error = self.context.error {
            self.finish(.failure(error))
            return
        }
        
        let bundle = self.context.app ?? self.context.targetAppBundle
        guard let targetAppBundle = bundle else {
            self.finish(.failure(OperationError.invalidParameters("FetchProvisioningProfilesOperation.main: self.context.app and self.context.targetAppBundle are both nil")))
            return
        }
        
        self.debugLog("[FetchProvisioningProfiles] Starting operation for bundle: \(targetAppBundle.bundleIdentifier) (useMainProfile: \(self.context.useMainProfile), appendTeamID: \(self.context.appendTeamID))")
        
        Task<Void, Never> {
            await self.fetchProvisioningProfiles(for: targetAppBundle)
        }
    }
    
    // MARK: - Async Pipeline
    
    func fetchProvisioningProfiles(for targetAppBundle: ALTApplication) async {
        do {
            guard !self.isCancelled else { throw OperationError.cancelled }
            
            // Step 1: Refresh Team (reuse cached team in sharedContext if already fetched in this group)
            let team = try await self.resolveTeam()
            self.debugLog("[FetchProvisioningProfiles] Resolved team: \(team.name) (\(team.identifier), type: \(team.type.rawValue))")
            guard !self.isCancelled else { throw OperationError.cancelled }
            
            // Step 2: Refresh Certificate (reuse cached certificate in sharedContext if already fetched in this group)
            let certificate = try await self.resolveCertificate(for: team)
            self.debugLog("[FetchProvisioningProfiles] Resolved certificate: \(certificate.name) (serial: \(certificate.serialNumber))")
            guard !self.isCancelled else { throw OperationError.cancelled }
            
            // Step 3: Prepare provisioning profiles for main app & extensions
            let fetchProgress = Progress.discreteProgress(totalUnitCount: 5)
            self.progress.addChild(fetchProgress, withPendingUnitCount: 5)
            
            let profiles = try await self.prepareProvisioningProfiles(for: targetAppBundle, team: team)
            fetchProgress.completedUnitCount = fetchProgress.totalUnitCount
            
            guard !self.isCancelled else { throw OperationError.cancelled }
            
            // Cache variables for future operations in the pipeline.
            self.context.team = team
            self.context.certificate = certificate
            self.context.provisioningProfiles = profiles
            
            self.debugLog("[FetchProvisioningProfiles] Successfully prepared \(profiles.count) provisioning profile(s): \(profiles.keys.joined(separator: ", "))")
            self.finish(.success(profiles))
        } catch {
            Logger.sidestore.error("[FetchProvisioningProfiles] Failed with error: \(error.localizedDescription, privacy: .public)")
            self.finish(.failure(error))
        }
    }
    
    // MARK: - Sub-operations Bridge
    
    private func resolveTeam() async throws -> ALTTeam {
        let stepProgress = Progress.discreteProgress(totalUnitCount: 1)
        self.progress.addChild(stepProgress, withPendingUnitCount: 1)
        defer { stepProgress.completedUnitCount = 1 }
        
        return try await TaskChainCoalescer.shared.coalesce(key: "fetch_team") {
            if let cachedTeam = self.context.sharedContext.team {
                self.debugLog("[FetchProvisioningProfiles] Using cached team from shared context.")
                return cachedTeam
            }
            
            let fetchTeamOperation = FetchTeamOperation(context: self.context)
            let team: ALTTeam = try await withCheckedThrowingContinuation { continuation in
                fetchTeamOperation.resultHandler = { result in
                    continuation.resume(with: result)
                }
                AppManager.shared.operationQueue.addOperation(fetchTeamOperation)
            }
            self.context.sharedContext.team = team
            return team
        }
    }
    
    private func resolveCertificate(for team: ALTTeam) async throws -> ALTCertificate {
        let stepProgress = Progress.discreteProgress(totalUnitCount: 2)
        self.progress.addChild(stepProgress, withPendingUnitCount: 2)
        defer { stepProgress.completedUnitCount = 2 }
        
        return try await TaskChainCoalescer.shared.coalesce(key: "fetch_certificate_\(team.identifier)") {
            if let cachedCert = self.context.sharedContext.certificate {
                self.debugLog("[FetchProvisioningProfiles] Using cached certificate from shared context.")
                return cachedCert
            }
            
            let fetchCertOperation = FetchCertificateOperation(team: team, context: self.context)
            let certificate: ALTCertificate = try await withCheckedThrowingContinuation { continuation in
                fetchCertOperation.resultHandler = { result in
                    continuation.resume(with: result)
                }
                AppManager.shared.operationQueue.addOperation(fetchCertOperation)
            }
            self.context.sharedContext.certificate = certificate
            return certificate
        }
    }
    
    // MARK: - Provisioning Profile Preparation
    
    private func prepareProvisioningProfiles(for targetAppBundle: ALTApplication,
                                             team: ALTTeam) async throws -> [String: ALTProvisioningProfile] {
        // Provision main application first
        let mainProfile = try await self.provisionAndFetchProfile(for: targetAppBundle, parentAppBundle: nil, team: team)
        var profiles: [String: ALTProvisioningProfile] = [targetAppBundle.bundleIdentifier: mainProfile]
        
        // Provision app extensions
        for appExtension in targetAppBundle.appExtensions {
            guard !self.isCancelled else { throw OperationError.cancelled }
            
            if self.context.useMainProfile {
                if let modifiedProfile = mainProfile.CompleteUpdatedProvisioningProfile(bundleID: appExtension.bundleIdentifier) {
                    self.debugLog("[FetchProvisioningProfiles] Reusing main profile for extension: \(appExtension.bundleIdentifier)")
                    profiles[appExtension.bundleIdentifier] = modifiedProfile
                } else {
                    throw OperationError.invalidParameters("FetchProvisioningProfilesOperation.prepareProvisioningProfiles: self.context.useMainProfile was set yet mainProfile.CompleteUpdatedProvisioningProfile returned nil for \(appExtension.bundleIdentifier)")
                }
            } else {
                self.debugLog("[FetchProvisioningProfiles] Provisioning dedicated profile for extension: \(appExtension.bundleIdentifier)")
                let extensionProfile = try await self.provisionAndFetchProfile(for: appExtension, parentAppBundle: targetAppBundle, team: team)
                profiles[appExtension.bundleIdentifier] = extensionProfile
            }
        }
        
        return profiles
    }
    
    private func getPreferredBundleID(for targetAppBundle: ALTApplication, team: ALTTeam) async -> String? {
        // 1. Ưu tiên lấy trực tiếp từ context.installedApp (khi đang Refresh / Resign / Update)
        if let currentInstalledApp = self.context.installedApp {
            let directResigned: String? = await self.context.dbBackgroundContext.perform {
                let resigned = currentInstalledApp.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !resigned.isEmpty else { return nil }
                return resigned
            }
            if let directResigned {
                if directResigned.lowercased().hasSuffix(".\(team.identifier.lowercased())") || directResigned.localizedCaseInsensitiveContains(team.identifier) {
                    self.debugLog("[FetchProvisioningProfiles] Resolved preferredBundleID directly from context.installedApp: \(directResigned)")
                    return directResigned
                } else {
                    let withTeam = "\(directResigned).\(team.identifier)"
                    self.debugLog("[FetchProvisioningProfiles] Resolved preferredBundleID with appended teamID from context.installedApp: \(withTeam)")
                    return withTeam
                }
            }
        }

        // 2. Fallback: Tìm trong Database theo cả bundleIdentifier gốc, customBundleIdentifier và resignedBundleIdentifier
        return await DatabaseManager.shared.persistentContainer.performBackgroundTask { [weak self] (context) -> String? in
            guard let self else { return nil }
            let target = self.context.targetBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let origBundleID = self.context.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let predicate = NSPredicate(
                format: "(%K ==[c] %@) OR (%K ==[c] %@) OR (%K ==[c] %@) OR (%K ==[c] %@)",
                #keyPath(InstalledApp.bundleIdentifier), target,
                #keyPath(InstalledApp.bundleIdentifier), origBundleID,
                #keyPath(InstalledApp.customBundleIdentifier), target,
                #keyPath(InstalledApp.resignedBundleIdentifier), target
            )
            guard let installedApp = InstalledApp.first(satisfying: predicate, in: context) else {
                self.verboseLog("[FetchProvisioningProfiles] No existing InstalledApp found for target: \(target)")
                return nil
            }
            
            let resigned = installedApp.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resigned.isEmpty else { return nil }

            let teamsMatch = (installedApp.team?.identifier == team.identifier || installedApp.team == nil)
                             && resigned.localizedCaseInsensitiveContains(team.identifier)
            
            let result = teamsMatch ? resigned : "\(resigned).\(team.identifier)"
            self.debugLog("[FetchProvisioningProfiles] preferredBundleID result: \(result)")
            return result
        }
    }
    
    private func provisionAndFetchProfile(for targetAppBundle: ALTApplication,
                                          parentAppBundle: ALTApplication?,
                                          team: ALTTeam) async throws -> ALTProvisioningProfile {
        let parentID: String
        if let preferredBundleID = await self.getPreferredBundleID(for: targetAppBundle, team: team) {
            parentID = preferredBundleID
        } else {
            let rawTarget = self.context.targetBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
            let teamSuffix = ".\(team.identifier)"
            if rawTarget.lowercased().hasSuffix(teamSuffix.lowercased()) {
                parentID = rawTarget
            } else {
                // Luôn đảm bảo có hậu tố TeamID cho tài khoản Apple để khớp với App ID trên Portal
                parentID = "\(rawTarget)\(teamSuffix)"
            }
        }
        
        var bundleID = parentID
        var appName = targetAppBundle.name
        
        if let parentApp = parentAppBundle {
            bundleID = targetAppBundle.bundleIdentifier.replacingOccurrences(of: parentApp.bundleIdentifier, with: parentID)
            appName = parentApp.name + " " + appName
        }
        
        self.verboseLog("[FetchProvisioningProfiles] Provisioning target '\(appName)' with resolved bundleID: '\(bundleID)' (original: '\(targetAppBundle.bundleIdentifier)')")
        
        // 1. Register App ID (or reuse existing)
        var appID = try await self.registerAppID(for: targetAppBundle, name: appName, bundleIdentifier: bundleID, team: team)
        guard !self.isCancelled else { throw OperationError.cancelled }
        
        // 2. Update Features
        appID = try await self.updateFeatures(for: appID, app: targetAppBundle, team: team)
        guard !self.isCancelled else { throw OperationError.cancelled }
        
        // 3. Update App Groups
        appID = try await self.updateAppGroups(for: appID, app: targetAppBundle, team: team)
        guard !self.isCancelled else { throw OperationError.cancelled }
        
        // 4. Fetch Provisioning Profile
        let profile = try await self.fetchProvisioningProfile(for: appID, app: targetAppBundle, team: team)
        return profile
    }
    
    // MARK: - Portal Steps
    
    func registerAppID(for targetAppBundle: ALTApplication,
                       name: String,
                       bundleIdentifier: String,
                       team: ALTTeam) async throws -> ALTAppID {
        let appIDs = try await TaskChainCoalescer.shared.coalesce(key: "fetch_app_ids_\(team.identifier)") {
            if let cachedAppIDs = self.context.sharedContext.appIDs {
                self.debugLog("[FetchProvisioningProfiles] Using cached App IDs from shared context.")
                return cachedAppIDs
            }
            self.debugLog("[FetchProvisioningProfiles] Fetching existing App IDs from Apple for team \(team.identifier)...")
            let fetchedAppIDs = try await DeveloperPortalProxy.shared.fetchAppIDs(for: team)
            self.context.sharedContext.appIDs = fetchedAppIDs
            self.verboseLog("[FetchProvisioningProfiles] Found \(fetchedAppIDs.count) existing App IDs on portal for team \(team.identifier): \(fetchedAppIDs.map { $0.bundleIdentifier })")
            return fetchedAppIDs
        }
        
        let trimmedTarget = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let teamSuffix = ".\(team.identifier)"
        let targetWithTeam = trimmedTarget.lowercased().hasSuffix(teamSuffix.lowercased())
            ? trimmedTarget
            : "\(trimmedTarget)\(teamSuffix)"
        let targetWithoutTeam = UserCustomizationOperation.stripTrailingTeamID(from: trimmedTarget, teamID: team.identifier)
        
        // Đối chiếu thông minh: Khớp chính xác cả bản có TeamID hoặc bản gốc trên Portal
        // để tuyệt đối không gọi lệnh addAppID tạo mới khi App ID đã tồn tại!
        if let appID = appIDs.first(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(trimmedTarget) == .orderedSame ||
            $0.bundleIdentifier.caseInsensitiveCompare(targetWithTeam) == .orderedSame ||
            $0.bundleIdentifier.caseInsensitiveCompare("\(targetWithoutTeam)\(teamSuffix)") == .orderedSame
        }) {
            self.debugLog("[FetchProvisioningProfiles] Found existing App ID on portal: \(appID.bundleIdentifier)")
            return appID
        } else {
            let requiredAppIDs = 1 + (self.context.useMainProfile ? 0 : targetAppBundle.appExtensions.count)
            let availableAppIDs = max(0, Team.maximumFreeAppIDs - appIDs.count)
            self.verboseLog("[FetchProvisioningProfiles] App ID not found on portal for '\(targetWithTeam)'. Required: \(requiredAppIDs), Available: \(availableAppIDs) (teamType: \(team.type))")
            
            let appIDName = self.sanitizeAppIDName(name: name, bundleIdentifier: targetWithTeam)
            
            self.debugLog("[FetchProvisioningProfiles] Calling DeveloperPortalProxy.shared.addAppID with name '\(appIDName)' and identifier '\(targetWithTeam)'...")
            let appID = try await DeveloperPortalProxy.shared.addAppID(name: appIDName, bundleIdentifier: targetWithTeam, team: team)
            self.context.sharedContext.appendAppID(appID)
            self.debugLog("[FetchProvisioningProfiles] Successfully registered new App ID '\(appID.bundleIdentifier)' on Apple portal.")
            return appID
        }
    }
    
    func updateFeatures(for appID: ALTAppID,
                        app: ALTApplication,
                        team: ALTTeam) async throws -> ALTAppID {
        let applicationGroupsEntitlement: ALTEntitlement = .appGroups
        let increasedMemoryLimitEntitlement: ALTEntitlement = .increasedMemoryLimit
        
        var requiredFeatures = app.entitlements.compactMap { (entitlement, value) -> (ALTFeature, Any)? in
            guard entitlement != applicationGroupsEntitlement else {
                // Handled separately by updateAppGroups().
                return nil
            }
            
            if entitlement == increasedMemoryLimitEntitlement,
               UserDefaults.standard.sideStoreAppIDSkipIncreasedMemoryLimit,
               app.bundleIdentifier == StoreApp.altstoreAppID {
                self.verboseLog("[FetchProvisioningProfiles] Skipping increased-memory-limit feature for SideStore.")
                return nil
            }
            
            guard let feature = ALTFeature(entitlement: entitlement) else {
                // This entitlement does not have a corresponding feature.
                return nil
            }
            return (feature, value)
        }.reduce(into: [ALTFeature: Any]()) { $0[$1.0] = $1.1 }
        
        if let enableGameCenter = requiredFeatures[.gameCenter] as? Bool, enableGameCenter {
            // Game Center is enabled by default, so no need to explicitly set it if true.
            requiredFeatures[.gameCenter] = nil
        }
        
        let updateFeatures = requiredFeatures.filter { (feature, value) -> Bool in
            guard let currentValue = appID.features[feature] as? NSObject,
                  let value = value as? NSObject else {
                return true
            }
            return currentValue != value
        }
        
        guard !updateFeatures.isEmpty else {
            // Features already match; no portal update required.
            self.debugLog("[FetchProvisioningProfiles] Features already up-to-date for App ID '\(appID.bundleIdentifier)'.")
            return appID
        }
        
        let features = appID.features.merging(requiredFeatures) { $1 }
        let updatedAppID = appID.copy() as! ALTAppID
        updatedAppID.features = features
        
        self.debugLog("[FetchProvisioningProfiles] Updating features for App ID '\(appID.bundleIdentifier)': \(updateFeatures.keys.map { $0.rawValue })")
        return try await DeveloperPortalProxy.shared.updateAppID(updatedAppID, team: team)
    }
    
    func updateAppGroups(for appID: ALTAppID,
                         app: ALTApplication,
                         team: ALTTeam) async throws -> ALTAppID {
        var applicationGroups = app.entitlements[.appGroups] as? [String] ?? []
        if app.bundleIdentifier == StoreApp.altstoreAppID {
            let groupID = Bundle.main.AltStoreAppGroup
            applicationGroups = [groupID]
        }
        
        guard !applicationGroups.isEmpty else {
            // App requires no groups; skip fetching/creating groups.
            self.debugLog("[FetchProvisioningProfiles] No App Groups required for '\(app.bundleIdentifier)'.")
            return appID
        }
        
        let allGroups = try await TaskChainCoalescer.shared.coalesce(key: "fetch_app_groups_\(team.identifier)") {
            if let cachedGroups = self.context.sharedContext.appGroups {
                self.debugLog("[FetchProvisioningProfiles] Using cached App Groups from shared context.")
                return cachedGroups
            }
            self.debugLog("[FetchProvisioningProfiles] Fetching existing App Groups from Apple for team \(team.identifier)...")
            let fetchedGroups = try await DeveloperPortalProxy.shared.fetchAppGroups(for: team)
            self.context.sharedContext.appGroups = fetchedGroups
            return fetchedGroups
        }
        
        var assignedGroups = [ALTAppGroup]()
        
        for groupIdentifier in applicationGroups {
            guard !self.isCancelled else { throw OperationError.cancelled }
            
            var adjustedGroupIdentifier = groupIdentifier + "." + team.identifier
            if let group = allGroups.first(where: { $0.groupIdentifier == adjustedGroupIdentifier }) {
                self.debugLog("[FetchProvisioningProfiles] Found existing App Group: \(adjustedGroupIdentifier)")
                assignedGroups.append(group)
            } else {
                // Ensure "group" is prefix
                adjustedGroupIdentifier = "group." + adjustedGroupIdentifier.replacingOccurrences(of: "group.", with: "")
                let name = adjustedGroupIdentifier.replacingOccurrences(of: ".", with: " ")
                
                self.debugLog("[FetchProvisioningProfiles] Creating new App Group '\(adjustedGroupIdentifier)' (name: '\(name)')...")
                let group = try await DeveloperPortalProxy.shared.addAppGroup(name: name, groupIdentifier: adjustedGroupIdentifier, team: team)
                self.context.sharedContext.appendAppGroup(group)
                assignedGroups.append(group)
            }
        }
        
        self.debugLog("[FetchProvisioningProfiles] Assigning \(assignedGroups.count) App Group(s) to App ID '\(appID.bundleIdentifier)'...")
        try await DeveloperPortalProxy.shared.assignAppID(appID, toGroups: assignedGroups, team: team)
        
        let updatedAppID = appID.copy() as! ALTAppID
        updatedAppID.entitlements = {
            var entitlements = appID.entitlements
            entitlements[.appGroups] = assignedGroups.map { $0.groupIdentifier }
            return entitlements
        }()
        return updatedAppID
    }
    
    func fetchProvisioningProfile(for appID: ALTAppID,
                                  app: ALTApplication,
                                  team: ALTTeam) async throws -> ALTProvisioningProfile {
        self.debugLog("[FetchProvisioningProfiles] Fetching provisioning profile for App ID '\(appID.bundleIdentifier)'...")
        var profile = try await DeveloperPortalProxy.shared.fetchProvisioningProfile(for: appID, deviceType: .iphone, team: team)
        
        // Delete existing profile first so the refreshed profile always has the latest expiration date.
        self.debugLog("[FetchProvisioningProfiles] Deleting old provisioning profile '\(profile.name)' (UUID: \(profile.uuid)) to force fresh expiration date...")
        try await DeveloperPortalProxy.shared.deleteProvisioningProfile(profile, for: team)
        
        self.debugLog("[FetchProvisioningProfiles] Fetching fresh provisioning profile for App ID '\(appID.bundleIdentifier)'...")
        profile = try await DeveloperPortalProxy.shared.fetchProvisioningProfile(for: appID, deviceType: .iphone, team: team)
        self.verboseLog("[FetchProvisioningProfiles] Received fresh provisioning profile '\(profile.name)' (UUID: \(profile.uuid), expires: \(profile.expirationDate))")
        
        return profile
    }
    
    // MARK: - Helpers
    
    /// Apple Developer Portal only allows alphanumeric characters and spaces in App ID names.
    private func sanitizeAppIDName(name: String, bundleIdentifier: String) -> String {
        let Folded = name.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US"))
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let filteredScalars = Folded.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character(" ") }
        let collapsed = String(filteredScalars)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        
        if !collapsed.isEmpty {
            return collapsed
        }
        
        // Fallback to sanitized bundleIdentifier if app name had only symbols/non-Latin characters
        let fallback = bundleIdentifier
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return fallback.isEmpty ? "SideStore App" : fallback
    }
}
