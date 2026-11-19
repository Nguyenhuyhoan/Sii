//
//  FetchProvisioningProfilesOperation.swift
//  AltStore
//
//  Created by Riley Testut on 1/23/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation
import AltStoreCore
import Roxas

@objc(ALTFetchProvisioningProfilesOperation)
final class FetchProvisioningProfilesOperation: ResultOperation<[String: ALTProvisioningProfile]>
{
    let context: InstallAppOperationContext

    init(context: InstallAppOperationContext)
    {
        self.context = context

        super.init()
    }

    override func main()
    {
        super.main()

        if let error = self.context.error
        {
            self.finish(.failure(error))
            return
        }

        guard let targetAppBundle = self.context.app else {
            return self.finish(.failure(OperationError.invalidParameters("FetchProvisioningProfilesOperation.main: self.context.app is nil")))
        }

        guard let team = self.context.authenticatedAccount?.team else { return self.finish(.failure(OperationError.notAuthenticated)) }

        let effectiveBundleId = self.context.targetBundleIdentifier

        // Check if we can use the existing profile on disk (unless user customized the Bundle ID for this install)
        if self.context.customBundleIdentifier == nil,
           let provisioningProfile = self.context.provisioningProfile,
           FileManager.default.fileExists(atPath: (self.context.app?.fileURL.appendingPathComponent("embedded.mobileprovision").path) ?? "") {
            var profiles = [effectiveBundleId: provisioningProfile]
            self.finish(.success(profiles))
            return
        }

        self.progress.localizedDescription = String(format: NSLocalizedString("Fetching Provisioning Profiles for %@…", comment: ""), targetAppBundle.name)

        Task<Void, Never>{
            do {
                let profile = try await self.provisionAndFetchProfile(for: targetAppBundle, parentAppBundle: nil, team: team)
                var profiles = [effectiveBundleId: profile]
                if effectiveBundleId != targetAppBundle.bundleIdentifier {
                    profiles[targetAppBundle.bundleIdentifier] = profile
                }

                let removedExtensionPaths = Set(self.context.extensionsToRemove.map { $0.path })
                for appExtension in targetAppBundle.appExtensions
                {
                    if removedExtensionPaths.contains(appExtension.fileURL.path) ||
                        !FileManager.default.fileExists(atPath: appExtension.fileURL.path) {
                        continue
                    }
                    let profile = try await self.provisionAndFetchProfile(for: appExtension, parentAppBundle: targetAppBundle, team: team)
                    profiles[appExtension.bundleIdentifier] = profile
                }

                let finalProfiles = profiles
                self.finish(.success(finalProfiles))
            } catch {
                self.finish(.failure(error))
            }
        }
    }

    func provisionAndFetchProfile(for targetAppBundle: ALTApplication,
                                  parentAppBundle: ALTApplication?,
                                  team: ALTTeam
    ) async throws -> ALTProvisioningProfile
    {
        let preferredName: String
        let preferredBundleID: String

        if let parentAppBundle = parentAppBundle
        {
            let parentID = try await getPreferredBundleID(parentAppBundle: parentAppBundle, team: team)
            let parentName = self.context.customAppName ?? parentAppBundle.name

            preferredName = "\(parentName) \(targetAppBundle.name)"
            let suffix: String
            if let range = targetAppBundle.bundleIdentifier.range(
                of: parentAppBundle.bundleIdentifier,
                options: [.anchored, .caseInsensitive]
            ) {
                suffix = String(targetAppBundle.bundleIdentifier[range.upperBound...])
            } else {
                let lastComponent = targetAppBundle.bundleIdentifier.components(separatedBy: ".").last ?? targetAppBundle.name
                suffix = "." + lastComponent
            }
            preferredBundleID = parentID + suffix
        }
        else
        {
            preferredName = self.context.customAppName ?? targetAppBundle.name
            preferredBundleID = try await getPreferredBundleID(parentAppBundle: targetAppBundle, team: team)
        }

        // Register the app ID with Apple and get the resulting ALTAppID containing its portal info
        var appID = try await self.registerAppID(name: preferredName,
                                                 bundleID: preferredBundleID,
                                                 team: team)
        appID = try await self.updateFeatures(for: appID, app: targetAppBundle, team: team)
        appID = try await self.updateAppGroups(for: appID, targetAppBundle: targetAppBundle, team: team)
        return try await self.fetchProvisioningProfile(for: appID, app: targetAppBundle, team: team)
    }

    func getPreferredBundleID(parentAppBundle: ALTApplication,
                              team: ALTTeam
    ) async throws -> String
    {
        let existingBundleID: String? = await DatabaseManager.shared.persistentContainer.viewContext.perform {
            let target = self.context.targetBundleIdentifier
            let predicate = NSPredicate(
                format: "(%K == %@) OR (%K == %@) OR (%K == %@)",
                #keyPath(InstalledApp.bundleIdentifier), parentAppBundle.bundleIdentifier,
                #keyPath(InstalledApp.customBundleIdentifier), target,
                #keyPath(InstalledApp.resignedBundleIdentifier), target
            )

            // Only reuse existing resignedBundleIdentifier if user did NOT explicitly customize to a different ID in this session
            if self.context.customBundleIdentifier == nil,
               let installedApp = InstalledApp.first(satisfying: predicate, in: DatabaseManager.shared.persistentContainer.viewContext) {
                return installedApp.resignedBundleIdentifier
            }
            return nil
        }

        let parentID: String
        if let existing = existingBundleID, !existing.isEmpty {
            parentID = existing
        } else {
            let rawBaseID = self.context.targetBundleIdentifier
            if self.context.appendTeamID {
                let cleanBaseID = Self.stripTrailingTeamID(from: rawBaseID, teamID: team.identifier)
                parentID = "\(cleanBaseID).\(team.identifier)"
            } else {
                parentID = rawBaseID
            }
        }

        return parentID
    }

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

    func registerAppID(name appName: String,
                       bundleID: String,
                       team: ALTTeam
    ) async throws -> ALTAppID {
        let appIDs = try await DeveloperPortalProxy.shared.fetchAppIDs(for: team)

        if let appID = appIDs.first(where: { $0.bundleIdentifier.caseInsensitiveCompare(bundleID) == .orderedSame }) {
            return appID
        } else {
            let appID = try await DeveloperPortalProxy.shared.addAppID(name: appName, bundleIdentifier: bundleID, team: team)
            return appID
        }
    }

    func updateFeatures(for appID: ALTAppID,
                        app: ALTApplication,
                        team: ALTTeam
    ) async throws -> ALTAppID
    {
        let requiredFeatures = app.entitlements.compactMap { (entitlement, value) -> (ALTFeature, Any)? in
            guard let feature = ALTFeature(entitlement: entitlement) else { return nil }
            return (feature, value)
        }

        var features = requiredFeatures.reduce(into: [ALTFeature: Any]()) { $0[$1.0] = $1.1 }

        if let applicationGroups = app.entitlements[.appGroups] as? [String], !applicationGroups.isEmpty
        {
            // This entitlement doesn't have a corresponding ALTFeature alignment, so handle it manually
            features[.appGroups] = true
        }

        let updateFeatures = features.filter { (feature, value) -> Bool in
            guard let existingValue = appID.features[feature] as? NSObject, let value = value as? NSObject else { return true }
            return existingValue != value
        }

        guard !updateFeatures.isEmpty else {
            // Features already enabled, no need to update.
            return appID
        }

        let appID = appID.copy() as! ALTAppID
        appID.features = features

        return try await DeveloperPortalProxy.shared.updateAppID(appID, team: team)
    }

    func updateAppGroups(for appID: ALTAppID,
                         targetAppBundle: ALTApplication,
                         team: ALTTeam
    ) async throws -> ALTAppID
    {
        let applicationGroups = targetAppBundle.entitlements[.appGroups] as? [String] ?? []
        guard !applicationGroups.isEmpty else {
            // No app groups, do nothing.
            return appID
        }

        let allGroups = try await DeveloperPortalProxy.shared.fetchAppGroups(for: team)
        var assignedGroups = [ALTAppGroup]()

        // Use a set of lowercased group identifiers to avoid duplicates
        var seenAdjustedIds = Set<String>()

        for groupIdentifier in applicationGroups
        {
            let adjustedGroupIdentifier = try await self.adjustedGroupIdentifier(for: groupIdentifier, appID: appID, targetAppBundle: targetAppBundle, team: team)
            let lowerAdjusted = adjustedGroupIdentifier.lowercased()
            if seenAdjustedIds.contains(lowerAdjusted) { continue }
            seenAdjustedIds.insert(lowerAdjusted)

            var matchingGroup: ALTAppGroup? = allGroups.first(where: { $0.groupIdentifier.lowercased() == lowerAdjusted })

            if matchingGroup == nil && UserDefaults.standard.autoUseExistingAppIDs {
                // If the specific group isn't found, and autoUseExistingAppIDs is enabled,
                // try to find ANY group that contains the base group name or use the first available group if limit is reached.
                let baseGroupName = groupIdentifier.replacingOccurrences(of: "group.", with: "").lowercased()
                matchingGroup = allGroups.first(where: { $0.groupIdentifier.lowercased().contains(baseGroupName) })
            }

            if let group = matchingGroup
            {
                assignedGroups.append(group)
            }
            else
            {
                do {
                    // App group doesn't exist yet, so create it.
                    let name = adjustedGroupIdentifier.replacingOccurrences(of: ".", with: " ")
                    let newGroup = try await DeveloperPortalProxy.shared.addAppGroup(name: name, groupIdentifier: adjustedGroupIdentifier, team: team)
                    assignedGroups.append(newGroup)
                } catch let error as NSError {
                    // Check if error is due to reaching maximum App Groups limit
                    // Apple error code for max groups is often related to portal limits
                    if UserDefaults.standard.autoUseExistingAppIDs, let fallbackGroup = allGroups.first {
                        print("Warning: Failed to create App Group '\(adjustedGroupIdentifier)' (Error: \(error.localizedDescription)). Falling back to existing group '\(fallbackGroup.groupIdentifier)'.")
                        if !assignedGroups.contains(where: { $0.identifier == fallbackGroup.identifier }) {
                            assignedGroups.append(fallbackGroup)
                        }
                    } else {
                        throw error
                    }
                }
            }
        }

        let _ = try await DeveloperPortalProxy.shared.assignAppID(appID, toGroups: assignedGroups, team: team)

        let appID = appID.copy() as! ALTAppID
        appID.entitlements[.appGroups] = assignedGroups.map { $0.groupIdentifier }

        return appID
    }

    func adjustedGroupIdentifier(for groupIdentifier: String, appID: ALTAppID, targetAppBundle: ALTApplication, team: ALTTeam) async throws -> String {
        #if DEBUG
        if groupIdentifier.contains(Bundle.baseAltStoreAppGroupID) && groupIdentifier.contains(team.identifier) {
            return groupIdentifier
        }
        #endif

        // When reusing a custom/portal Bundle ID (e.g. com.alone.37D6PWG5PP) for a different app,
        // unify the App Group identifier under the chosen App ID so it matches existing portal App Groups
        // and avoids failing or exhausting the free account App Group quota.
        if self.context.customBundleIdentifier != nil && UserDefaults.standard.autoFixAppGroupIDs {
            return "group." + appID.bundleIdentifier
        }

        let rawGroupID = groupIdentifier.replacingOccurrences(of: "group.", with: "")
        let targetBundleID = targetAppBundle.bundleIdentifier
        let contextTargetBundleID = self.context.targetBundleIdentifier

        let matchesBundleID = rawGroupID.caseInsensitiveCompare(targetBundleID) == .orderedSame ||
                              rawGroupID.caseInsensitiveCompare(contextTargetBundleID) == .orderedSame

        if UserDefaults.standard.autoFixAppGroupIDs && matchesBundleID {
            return "group." + appID.bundleIdentifier
        }

        var adjustedGroupID = groupIdentifier
        if self.context.appendTeamID {
            let cleanGroupID = Self.stripTrailingTeamID(from: adjustedGroupID, teamID: team.identifier)
            adjustedGroupID = cleanGroupID + "." + team.identifier
        }
        return adjustedGroupID
    }

    func fetchProvisioningProfile(for appID: ALTAppID,
                                  app: ALTApplication,
                                  team: ALTTeam
    ) async throws -> ALTProvisioningProfile
    {
        let profile = try await DeveloperPortalProxy.shared.fetchProvisioningProfile(for: appID, team: team)
        return profile
    }
}
