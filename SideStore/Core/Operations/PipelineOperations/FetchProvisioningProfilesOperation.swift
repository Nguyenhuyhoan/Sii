
//
//  FetchProvisioningProfilesOperation.swift
//  AltStore
//
//  Created by Riley Testut on 1/24/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//


import Foundation
import CoreData

import SideSign

@objc(FetchProvisioningProfilesOperation)
final class FetchProvisioningProfilesOperation: BasePipelineOperation<InstallAppOperationContext, [String: ALTProvisioningProfile]>, @unchecked Sendable {

    override var progressWeight: Int64 { 15 }

    private let appIDFetchLock = NSLock()

    override func execute(parentProgress: Progress?) async throws -> [String: ALTProvisioningProfile] {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[FetchProvisioningProfilesOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[FetchProvisioningProfilesOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)
        self.setProgress(3)
        
        let team = try await AuthManager.shared.getAuthenticatedTeam()
        
        let bundleIdentifier = self.context.targetBundleIdentifier
        let appName = self.context.targetAppBundle?.name ?? bundleIdentifier
        let appBundle = self.context.targetAppBundle
        let additionalEntitlements = self.context.additionalEntitlements
        let isAltStoreApp = self.context.targetAppBundle?.isAltStoreApp ?? false
        let appExtensions = self.context.targetAppBundle?.appExtensions ?? []
        let installedAppObjectID = self.context.installedApp?.objectID
        
        var profiles = [String: ALTProvisioningProfile]()
        
        self.setProgress(10)
        // Prepare Main App Bundle
        let mainProfile: ALTProvisioningProfile
        if let overrideProfile = self.context.overrideProvisioningProfile {
            mainProfile = overrideProfile
        } else {
            mainProfile = try await self.prepare(
                bundleName: appName,
                bundleIdentifier: bundleIdentifier,
                appBundle: appBundle,
                additionalEntitlements: additionalEntitlements,
                isAltStoreApp: isAltStoreApp,
                installedAppObjectID: installedAppObjectID,
                team: team
            )
        }
        profiles[bundleIdentifier] = mainProfile

        guard !self.context.useMainProfile, !appExtensions.isEmpty else {
            self.setProgress(100)
            return profiles
        }
        
        self.setProgress(40)
        
        guard let mainAppBundleID = appBundle?.bundleIdentifier else {
            throw OperationError.invalidParameters("FetchProvisioningProfilesOperation.execute: appBundle.bundleIdentifier is nil")
        }
        
        let progressCount = Int64(appExtensions.count)
        let incrementProgressCount = (90 - 40)/progressCount
        
        let fetchedProfiles = try await withThrowingTaskGroup(of: (String, ALTProvisioningProfile).self, returning: [String: ALTProvisioningProfile].self) { taskGroup in
            for appExtension in appExtensions {
                let updatedAppExBundleId = appExtension.bundleIdentifier.replacingOccurrences(of: mainAppBundleID, with: bundleIdentifier)
                taskGroup.addTask {
                    try Task.checkCancellation()
                    let profile = try await self.prepare(
                        bundleName: appExtension.name,
                        bundleIdentifier: updatedAppExBundleId,
                        appBundle: appExtension,
                        additionalEntitlements: [:],
                        isAltStoreApp: isAltStoreApp,
                        installedAppObjectID: nil,
                        team: team
                    )
                    self.incrementProgress(by: incrementProgressCount)
                    return (updatedAppExBundleId, profile)
                }
            }
            
            var results = [String: ALTProvisioningProfile]()
            for try await (id, profile) in taskGroup {
                results[id] = profile
            }
            return results
        }
        
        profiles.merge(fetchedProfiles) { (_, new) in new }
        
        self.setProgress(100)
        return profiles
    }

    private func prepare(
        bundleName: String,
        bundleIdentifier: String,
        appBundle: ALTApplication?,
        additionalEntitlements: [ALTEntitlement: Any],
        isAltStoreApp: Bool,
        installedAppObjectID: NSManagedObjectID?,
        team: ALTTeam
    ) async throws -> ALTProvisioningProfile {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[FetchProvisioningProfilesOperation] prepare(\(bundleIdentifier)) started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[FetchProvisioningProfilesOperation] prepare(\(bundleIdentifier)) took: \(String(format: "%.3fs", elapsed))")
        }
        var prefixedBundleIdentifier = !context.appendTeamID
            ? bundleIdentifier
            : InstalledApp.refreshedBundleIdentifier(forBundleIdentifier: bundleIdentifier, teamIdentifier: team.identifier)
        
        if let installedAppObjectID = installedAppObjectID {
            prefixedBundleIdentifier = self.context.dbBackgroundContext.performAndWait {
                guard let installedApp = try? self.context.dbBackgroundContext.existingObject(with: installedAppObjectID) as? InstalledApp else {
                    return prefixedBundleIdentifier
                }
                return installedApp.CheckAndCorrectRefreshedBundleIdentifier(teamIdentifier: team.identifier)
            }
        }
        
        // Register App ID
        var appID = try await self.registerAppID(
            withName: bundleName,
            bundleIdentifier: bundleIdentifier,
            prefixedBundleIdentifier: prefixedBundleIdentifier,
            team: team
        )
        
        if let appBundle = appBundle {
            // Update Entitlements / Features
            appID = try await self.updateFeatures(
                for: appID,
                appBundle: appBundle,
                additionalEntitlements: additionalEntitlements,
                team: team
            )
            
            // Update App Groups
            appID = try await self.updateAppGroups(
                for: appID,
                appBundle: appBundle,
                additionalEntitlements: additionalEntitlements,
                isAltStoreApp: isAltStoreApp,
                team: team
            )
        }
        
        // Fetch Provisioning Profile
        let profile = try await self.fetchProvisioningProfile(for: appID, appBundle: appBundle, team: team)
        
        return profile
    }
    
    private func registerAppID(
        withName name: String,
        bundleIdentifier: String,
        prefixedBundleIdentifier: String,
        team: ALTTeam
    ) async throws -> ALTAppID {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[FetchProvisioningProfilesOperation] registerAppID(\(prefixedBundleIdentifier)) started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[FetchProvisioningProfilesOperation] registerAppID(\(prefixedBundleIdentifier)) took: \(String(format: "%.3fs", elapsed))")
        }
        self.verboseLog("[FetchProvisioningProfilesOperation] Fetching App IDs for team \(team.name)...")

        let appIDs: [ALTAppID]
        if let existing = self.context.sharedContext.appIDs {
            appIDs = existing
        } else {
            let fetched = try await DeveloperPortalProxy.shared.fetchAppIDs(for: team)
            self.appIDFetchLock.withLock {
                if self.context.sharedContext.appIDs == nil {
                    self.context.sharedContext.appIDs = fetched
                }
            }
            appIDs = self.context.sharedContext.appIDs ?? fetched
        }

        let targetPrefixed = prefixedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetRaw = bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existingAppID = appIDs.first(where: {
            $0.bundleIdentifier.caseInsensitiveCompare(targetPrefixed) == .orderedSame ||
            $0.bundleIdentifier.caseInsensitiveCompare(targetRaw) == .orderedSame
        }) {
            self.verboseLog("[FetchProvisioningProfilesOperation] Reusing existing App ID on portal: \(existingAppID.bundleIdentifier)")
            return existingAppID
        }

        self.verboseLog("[FetchProvisioningProfilesOperation] Registering new App ID \(targetPrefixed)...")
        let addedAppID = try await DeveloperPortalProxy.shared.addAppID(
            withName: name,
            bundleIdentifier: targetPrefixed,
            team: team
        )
        self.context.sharedContext.appendAppID(addedAppID)
        return addedAppID
    }
    
    private func updateFeatures(
        for appID: ALTAppID,
        appBundle: ALTApplication,
        additionalEntitlements: [ALTEntitlement: Any],
        team: ALTTeam
    ) async throws -> ALTAppID {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[FetchProvisioningProfilesOperation] updateFeatures(\(appID.bundleIdentifier)) started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[FetchProvisioningProfilesOperation] updateFeatures(\(appID.bundleIdentifier)) took: \(String(format: "%.3fs", elapsed))")
        }
        let entitlements = appBundle.entitlements.merging(additionalEntitlements) { (_, new) in new }
        
        var features = entitlements.compactMapKeys { (entitlement) -> ALTFeature? in
            let feature = ALTFeature(entitlement: entitlement)
            return feature
        }
        
        if let applicationIdentifier = appBundle.infoPlist["INAlternativeAppNames"] {
            // Attempting to install an app showing notification icons with customizable app icons breaks notifications unless the push notifications feature is enabled on the app id
            self.verboseLog("[FetchProvisioningProfilesOperation] Enabling Push Notifications feature for \(applicationIdentifier)...")
            features[.pushNotifications] = true
        }
        
        if appBundle.entitlements[.increasedMemoryLimit] as? Bool == true {
            features[.increasedMemoryLimit] = true
        }
        
        if appBundle.entitlements[.extendedVirtualAddressing] as? Bool == true {
            features[.extendedVirtualAddressing] = true
        }
        
        let updateFeatures = features.filter { (feature, value) -> Bool in
            guard let value = value as? NSObject else { return true }
            
            let previousValue = appID.features[feature] as? NSObject
            return value != previousValue
        }
        
        guard !updateFeatures.isEmpty else {
            // Features haven't changed, so no need to update them.
            return appID
        }
        
        let copiedAppID = appID.copy() as! ALTAppID
        copiedAppID.features = features
        
        self.verboseLog("[FetchProvisioningProfilesOperation] Updating features for App ID \(appID.bundleIdentifier)...")
        return try await DeveloperPortalProxy.shared.updateAppID(copiedAppID, team: team)
    }
    
    private func updateAppGroups(
        for appID: ALTAppID,
        appBundle: ALTApplication,
        additionalEntitlements: [ALTEntitlement: Any],
        isAltStoreApp: Bool,
        team: ALTTeam
    ) async throws -> ALTAppID {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[FetchProvisioningProfilesOperation] updateAppGroups(\(appID.bundleIdentifier)) started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[FetchProvisioningProfilesOperation] updateAppGroups(\(appID.bundleIdentifier)) took: \(String(format: "%.3fs", elapsed))")
        }
        var applicationGroups = Set(appBundle.entitlements[.appGroups] as? [String] ?? [])
        
        if let Groups = additionalEntitlements[.appGroups] as? [String]
        {
            applicationGroups.formUnion(Groups)
        }
        
        if isAltStoreApp, let groupID = Bundle.main.altstoreAppGroup
        {
            // Technically only need to add group to the main application, not its extensions
            // However as of writing (2022/08/21) our extensions happens to not have any groups.
            // Also, maybe we want to use this group in an extension later anyway?
            applicationGroups.insert(groupID)
        }
        
        guard !applicationGroups.isEmpty else {
            //Assuming no app groups exist right now on this app id, might have to rework that logic?
            return appID
        }
        
        self.verboseLog("[FetchProvisioningProfilesOperation] Fetching App Groups for team \(team.name)...")
        let groups: [ALTAppGroup]
        if let existing = self.context.sharedContext.appGroups {
            groups = existing
        } else {
            let fetched = try await DeveloperPortalProxy.shared.fetchAppGroups(for: team)
            self.appIDFetchLock.withLock {
                if self.context.sharedContext.appGroups == nil {
                    self.context.sharedContext.appGroups = fetched
                }
            }
            groups = self.context.sharedContext.appGroups ?? fetched
        }
        
        var assignedGroups = [ALTAppGroup]()
        
        for groupIdentifier in applicationGroups
        {
            let adjustedGroupIdentifier = self.adjustedGroupIdentifier(for: groupIdentifier, team: team)
            
            let matchingGroup = groups.first { $0.groupIdentifier == adjustedGroupIdentifier }
            
            let group: ALTAppGroup
            if let matchingGroup = matchingGroup {
                group = matchingGroup
            } else {
                let name = groupIdentifier.replacingOccurrences(of: ".", with: " ")
                group = try await DeveloperPortalProxy.shared.addAppGroup(
                    withName: name,
                    groupIdentifier: adjustedGroupIdentifier,
                    team: team
                )
                self.context.sharedContext.appendAppGroup(group)
            }
            
            assignedGroups.append(group)
        }
        
        self.verboseLog("[FetchProvisioningProfilesOperation] Assigning groups \(assignedGroups.map { $0.groupIdentifier }) to App ID \(appID.name)")
        let assignSuccess = try await DeveloperPortalProxy.shared.assignAppID(appID, toGroups: assignedGroups, team: team)
        guard assignSuccess else {
            throw OperationError.assignAppGroupFailed
        }
        
        let updatedAppID = appID.copy() as! ALTAppID
        updatedAppID.entitlements[.appGroups] = assignedGroups.map { $0.groupIdentifier }
        return updatedAppID
    }
    
    private func fetchProvisioningProfile(for appID: ALTAppID, appBundle: ALTApplication?, team: ALTTeam) async throws -> ALTProvisioningProfile {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[FetchProvisioningProfilesOperation] fetchProvisioningProfile(\(appID.bundleIdentifier)) started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[FetchProvisioningProfilesOperation] fetchProvisioningProfile(\(appID.bundleIdentifier)) took: \(String(format: "%.3fs", elapsed))")
        }
        self.verboseLog("[FetchProvisioningProfilesOperation] Fetching provisioning profile for App ID \(appID.name)...")
        let profile = try await DeveloperPortalProxy.shared.fetchProvisioningProfile(for: appID, team: team)
        
        if let appBundle = appBundle, appBundle.isExtension {
            return profile
        }
        
        self.verboseLog("[FetchProvisioningProfilesOperation] Deleting provisioning profile for App ID \(appID.name)...")
        let deleteSuccess = try await DeveloperPortalProxy.shared.delete(profile, for: team)
        guard deleteSuccess else {
            throw OperationError.deleteProvisioningProfileFailed
        }
        
        self.verboseLog("[FetchProvisioningProfilesOperation] Fetching updated provisioning profile for App ID \(appID.name)...")
        return try await DeveloperPortalProxy.shared.fetchProvisioningProfile(for: appID, team: team)
    }
    
    private func adjustedGroupIdentifier(for groupIdentifier: String, team: ALTTeam) -> String {
        var components = groupIdentifier.components(separatedBy: ".")
        components.insert(team.identifier, at: 1)
        
        let adjustedGroupIdentifier = components.joined(separator: ".")
        return adjustedGroupIdentifier
    }
}
