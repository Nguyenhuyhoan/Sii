//
//  UserCustomizationOperation.swift
//  SideStore
//
//  Created by Magesh K on 30/07/26.
//  Copyright © 2026 AltStore. All rights reserved.
//


import Foundation
import CoreData
import SideSign

/// Thông tin một App ID rảnh rỗi có thể tái sử dụng ngay (tốn 0 slot ID mới)
public struct ReusableAppIDCandidate: Identifiable, Hashable, Sendable {
    public var id: String { fullBundleIdentifier }
    public let name: String
    /// Bundle ID đầy đủ chính xác trên Apple Portal (ví dụ: com.alone.37D6PWG5PP)
    public let fullBundleIdentifier: String
    /// Bundle ID hiển thị/gán vào context (giữ nguyên giống hệt fullBundleIdentifier, không cắt đuôi)
    public let baseBundleIdentifier: String
    /// Không bao giờ tự gắn thêm .TEAMID nữa vì fullBundleIdentifier đã là ID hoàn chỉnh
    public let requiresAppendingTeamID: Bool
    public let expirationDate: Date?

    public init(
        name: String,
        fullBundleIdentifier: String,
        baseBundleIdentifier: String? = nil,
        requiresAppendingTeamID: Bool = false,
        expirationDate: Date?
    ) {
        self.name = name
        self.fullBundleIdentifier = fullBundleIdentifier
        self.baseBundleIdentifier = baseBundleIdentifier ?? fullBundleIdentifier
        self.requiresAppendingTeamID = requiresAppendingTeamID
        self.expirationDate = expirationDate
    }
}

final class UserCustomizationOperation: BasePipelineOperation<InstallAppOperationContext, String?>, @unchecked Sendable {

    override func execute(parentProgress: Progress?) async throws -> String? {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[UserCustomizationOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[UserCustomizationOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)
        self.setProgress(10)

        // Luôn ép gộp mọi App Extensions vào 1 ID chính cho cả cài mới, cập nhật và làm mới
        self.context.useMainProfile = true

        guard let targetAppBundle = context.targetAppBundle else {
            throw OperationError.invalidParameters("UserCustomizationOperation: context.targetAppBundle is nil")
        }

        let authTeam = try await AuthManager.shared.getAuthenticatedTeam()
        let teamID = authTeam.identifier
        guard !teamID.isEmpty else {
            debugLog("[UserCustomizationOperation] FAILED: authTeamID is empty")
            throw OperationError.invalidParameters("Active developer team identifier is missing.")
        }

        // 1. Quét danh sách App đang sống trên máy để nhận diện Cài Mới hay Cập Nhật IPA
        let installedSnap = fetchInstalledAppSnapshots(teamID: teamID)

        if context.installedApp == nil {
            let incomingRawID = context.targetBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let incomingWithTeamID = "\(incomingRawID).\(teamID)".lowercased()
            let incomingNameKey = targetAppBundle.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            let matchedObjectID = installedSnap.objectIDByBundleID[incomingRawID]
                ?? installedSnap.objectIDByBundleID[incomingWithTeamID]
                ?? installedSnap.objectIDByAppName[incomingNameKey]

            if let matchedObjectID {
                context.dbBackgroundContext.performAndWait {
                    if let matchedApp = try? context.dbBackgroundContext.existingObject(with: matchedObjectID) as? InstalledApp {
                        self.context.installedApp = matchedApp
                    }
                }
            }
        }

        // 2. NẾU LÀ CẬP NHẬT (Store Update hoặc cài IPA cập nhật đè lên App đang sống trên máy):
        // -> Giữ nguyên 100% ID hiện tại của App (ví dụ com.alone.37D6PWG5PP), không cắt đuôi hay thêm đuôi!
        if context.isStoreUpdate || context.installedApp != nil {
            if let existingApp = context.installedApp {
                let existingResignedID = context.dbBackgroundContext.performAndWait {
                    existingApp.resignedBundleIdentifier
                }
                let trimmedResigned = existingResignedID.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedResigned.isEmpty {
                    context.customBundleIdentifier = trimmedResigned
                    context.appendTeamID = false
                    applyUnifiedBundleIDToAllTargets(
                        exactBundleID: trimmedResigned,
                        targetAppBundle: targetAppBundle
                    )
                }
            }
            debugLog("[UserCustomizationOperation] Existing app update detected; using exact ID without stripping/appending.")
            self.setProgress(100)
            return context.customBundleIdentifier != nil ? context.targetBundleIdentifier : nil
        }

        let handler = context.handler.userCustomizationHandler
        var didCustomizeBundleID = false

        // 3. NẾU LÀ CÀI ĐẶT IPA MỚI HOÀN TOÀN:
        if UserDefaults.standard.customizeInfoPlist {
            let installedApps: [InstalledApp] = context.dbBackgroundContext.performAndWait {
                let request = InstalledApp.fetchRequest()
                return (try? context.dbBackgroundContext.fetch(request)) ?? []
            }
            let installedAppIdentities = Dictionary(
                installedApps.compactMap { app -> (String, String)? in
                    (app.bundleIdentifier, app.name)
                },
                uniquingKeysWith: { first, _ in first }
            )

            let initialBundleID = context.targetBundleIdentifier
            var targets: [InfoPlistTarget] = [
                InfoPlistTarget(id: initialBundleID, name: targetAppBundle.name, isExtension: false, initialPlist: targetAppBundle.infoPlist)
            ]
            for ext in targetAppBundle.allAppBundles where ext.isExtension {
                targets.append(InfoPlistTarget(id: ext.bundleIdentifier, name: ext.name, isExtension: true, initialPlist: ext.infoPlist))
            }

            self.setProgress(40)

            guard let result = try await handler.resolveInfoPlistCustomization(
                targets: targets,
                initialBundleID: initialBundleID,
                appendTeamID: context.appendTeamID,
                installedAppIdentities: installedAppIdentities,
                teamID: teamID
            ) else {
                throw OperationError.cancelled
            }

            context.appendTeamID = result.appendTeamID

            let mainModifiedPlist = result.modifiedPlists[initialBundleID] ?? [:]
            let customID = InfoPlistParser(dictionary: mainModifiedPlist).bundleIdentifier
            if let customID = customID, !customID.isEmpty, customID != context.bundleIdentifier {
                context.customBundleIdentifier = customID
                didCustomizeBundleID = true
            } else {
                context.customBundleIdentifier = nil
            }

            for (targetID, plist) in result.modifiedPlists {
                let key = (targetID == initialBundleID) ? context.targetBundleIdentifier : targetID
                context.customInfoPlistByBundleID[key] = plist
            }

            let effectiveCustomID = context.customBundleIdentifier ?? initialBundleID
            let resolvedID = result.appendTeamID && !teamID.isEmpty ? "\(effectiveCustomID).\(teamID)" : effectiveCustomID
            if let matchingApp = installedApps.first(where: { $0.bundleIdentifier == resolvedID || $0.resignedBundleIdentifier == resolvedID }) {
                context.installedApp = matchingApp
            } else {
                context.installedApp = nil
            }
        } else {
            // Hiển thị bảng chọn ID thông minh:
            self.setProgress(35)
            let reusableCandidates = await fetchReusableAppIDCandidates(
                authTeam: authTeam,
                teamID: teamID,
                activeMainIDsLowercased: installedSnap.activeMainIDsLowercased
            )

            let initialBundleID = context.targetBundleIdentifier
            self.setProgress(50)

            guard let result = try await handler.resolveBundleIDOverride(
                initialBundleID: initialBundleID,
                appName: targetAppBundle.name,
                teamID: teamID,
                reusableAppIDs: reusableCandidates
            ) else {
                throw OperationError.cancelled
            }

            let chosenRawID = result.customID.trimmingCharacters(in: .whitespacesAndNewlines)

            // Nếu người dùng chọn ID cũ (ví dụ com.alone.37D6PWG5PP):
            // -> Giữ nguyên 100% com.alone.37D6PWG5PP, tắt appendTeamID, và áp dụng cho toàn bộ App + Extensions!
            if let matchedCandidate = reusableCandidates.first(where: {
                $0.fullBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame
            }) {
                let exactID = matchedCandidate.fullBundleIdentifier
                context.appendTeamID = false
                context.customBundleIdentifier = exactID
                applyUnifiedBundleIDToAllTargets(
                    exactBundleID: exactID,
                    targetAppBundle: targetAppBundle
                )
                didCustomizeBundleID = true
            } else {
                context.appendTeamID = result.appendTeamID
                if !chosenRawID.isEmpty, chosenRawID != context.bundleIdentifier {
                    context.customBundleIdentifier = chosenRawID
                    if !result.appendTeamID {
                        applyUnifiedBundleIDToAllTargets(
                            exactBundleID: chosenRawID,
                            targetAppBundle: targetAppBundle
                        )
                    }
                    didCustomizeBundleID = true
                } else {
                    context.customBundleIdentifier = nil
                }
            }
        }

        if UserDefaults.standard.customizeEntitlements {
            let mainTargetID = context.targetBundleIdentifier
            self.setProgress(70)

            var targets: [EntitlementsTarget] = [
                EntitlementsTarget(
                    id: mainTargetID,
                    name: targetAppBundle.name,
                    isExtension: false,
                    initialEntitlements: targetAppBundle.entitlements
                )
            ]

            for ext in targetAppBundle.allAppBundles where ext.isExtension {
                targets.append(
                    EntitlementsTarget(
                        id: ext.bundleIdentifier,
                        name: ext.name,
                        isExtension: true,
                        initialEntitlements: ext.entitlements
                    )
                )
            }

            guard let result = try await handler.resolveEntitlementsCustomization(
                targets: targets,
                teamType: authTeam.type
            ) else {
                throw OperationError.cancelled
            }

            for (targetID, targetEntitlements) in result {
                context.customEntitlementsByBundleID[targetID] = targetEntitlements
            }

            if let mainEntitlements = result[mainTargetID] {
                for (key, value) in mainEntitlements {
                    context.additionalEntitlements[ALTEntitlement(key)] = value
                }
            }
        }

        if UserDefaults.standard.customizeAppIcon {
            self.setProgress(85)
            if let iconURL = try await handler.resolveAppIconCustomization(appName: targetAppBundle.name) {
                context.alternateIconMode = .set(iconURL)
            }
        }

        if UserDefaults.standard.customizeProvisioningProfile {
            self.setProgress(95)
            let effectiveBundleID = context.customBundleIdentifier ?? context.targetBundleIdentifier
            let choice = try await handler.resolveProvisioningProfileCustomization(
                appName: targetAppBundle.name,
                bundleID: effectiveBundleID
            )
            switch choice {
            case .profile(let profile):
                context.overrideProvisioningProfile = profile
                ProfileManager.shared.assignProfile(uuid: profile.uuid, for: effectiveBundleID)
            case .defaultProfile, .none:
                break
            }
        }

        self.setProgress(100)
        if didCustomizeBundleID || UserDefaults.standard.customizeInfoPlist || UserDefaults.standard.customizeAppId || UserDefaults.standard.customizeAppIcon || UserDefaults.standard.customizeProvisioningProfile {
            return context.targetBundleIdentifier
        } else {
            return nil
        }
    }

    // MARK: - Đồng bộ nguyên vẹn ID (VD: com.alone.37D6PWG5PP) cho App chính và tất cả phần mở rộng
    private func applyUnifiedBundleIDToAllTargets(
        exactBundleID: String,
        targetAppBundle: ALTApplication
    ) {
        var mainPlist = context.customInfoPlistByBundleID[context.targetBundleIdentifier] ?? targetAppBundle.infoPlist
        mainPlist["CFBundleIdentifier"] = exactBundleID
        context.customInfoPlistByBundleID[context.targetBundleIdentifier] = mainPlist

        for ext in targetAppBundle.allAppBundles where ext.isExtension {
            var extPlist = context.customInfoPlistByBundleID[ext.bundleIdentifier] ?? ext.infoPlist
            extPlist["CFBundleIdentifier"] = exactBundleID
            if var nsExt = extPlist["NSExtension"] as? [String: any Sendable],
               var attrs = nsExt["NSExtensionAttributes"] as? [String: any Sendable],
               attrs["WKAppBundleIdentifier"] != nil {
                attrs["WKAppBundleIdentifier"] = exactBundleID
                nsExt["NSExtensionAttributes"] = attrs
                extPlist["NSExtension"] = nsExt
            }
            context.customInfoPlistByBundleID[ext.bundleIdentifier] = extPlist
        }
    }

    // MARK: - Helpers: Quét và lọc Kho App ID Trống (Giữ nguyên ID gốc, không cắt đuôi)

    private struct InstalledAppSnapshot {
        let activeMainIDsLowercased: Set<String>
        let objectIDByBundleID: [String: NSManagedObjectID]
        let objectIDByAppName: [String: NSManagedObjectID]
    }

    private func fetchInstalledAppSnapshots(teamID: String) -> InstalledAppSnapshot {
        context.dbBackgroundContext.performAndWait {
            let request = InstalledApp.fetchRequest()
            let installedApps = (try? context.dbBackgroundContext.fetch(request)) ?? []

            var activeMainIDs = Set<String>()
            var mapByID: [String: NSManagedObjectID] = [:]
            var mapByName: [String: NSManagedObjectID] = [:]

            let hostMainBundleID = (Bundle.main.bundleIdentifier ?? "").lowercased()

            for app in installedApps {
                let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

                for idVariant in [rawID, resignedID] where !idVariant.isEmpty {
                    let lower = idVariant.lowercased()
                    activeMainIDs.insert(lower)
                    mapByID[lower] = app.objectID
                }

                if !Self.isExactProtectedHostMainID(
                    lowerFull: rawID.lowercased(),
                    hostMainID: hostMainBundleID,
                    teamID: teamID
                ) {
                    let nameKey = app.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    if !nameKey.isEmpty {
                        mapByName[nameKey] = app.objectID
                    }
                }
            }

            return InstalledAppSnapshot(
                activeMainIDsLowercased: activeMainIDs,
                objectIDByBundleID: mapByID,
                objectIDByAppName: mapByName
            )
        }
    }

    private func fetchReusableAppIDCandidates(
        authTeam: ALTTeam,
        teamID: String,
        activeMainIDsLowercased: Set<String>
    ) async -> [ReusableAppIDCandidate] {
        var portalSnapshots: [(name: String, bundleID: String, expirationDate: Date?)] = []

        if let remoteAppIDs = try? await DeveloperPortalProxy.shared.fetchAppIDs(for: authTeam) {
            portalSnapshots = remoteAppIDs.map {
                (name: $0.name, bundleID: $0.bundleIdentifier, expirationDate: $0.expirationDate)
            }
        }

        if portalSnapshots.isEmpty {
            portalSnapshots = context.dbBackgroundContext.performAndWait {
                let request = AppID.fetchRequest()
                let localIDs = (try? context.dbBackgroundContext.fetch(request)) ?? []
                return localIDs.map {
                    (name: $0.name, bundleID: $0.bundleIdentifier, expirationDate: $0.expirationDate)
                }
            }
        }

        let hostMainBundleID = (Bundle.main.bundleIdentifier ?? "").lowercased()
        let now = Date()

        var seenFullIDs = Set<String>()
        var candidates: [ReusableAppIDCandidate] = []

        for item in portalSnapshots {
            let fullID = item.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullID.isEmpty else { continue }

            if let exp = item.expirationDate, exp <= now {
                continue
            }

            let lowerFull = fullID.lowercased()

            // 1. Chỉ bảo vệ đúng ID CHÍNH của ứng dụng chủ (SideStore / LiveContainer / LC+SS)
            if Self.isExactProtectedHostMainID(
                lowerFull: lowerFull,
                hostMainID: hostMainBundleID,
                teamID: teamID
            ) {
                continue
            }

            // 2. Loại bỏ ID CHÍNH của các App đang cài trên máy
            if activeMainIDsLowercased.contains(lowerFull) {
                continue
            }

            // 3. Giữ nguyên 100% fullID (VD: com.alone.37D6PWG5PP), không cắt đuôi, không gắn thêm đuôi
            guard !seenFullIDs.contains(lowerFull) else { continue }
            seenFullIDs.insert(lowerFull)

            candidates.append(
                ReusableAppIDCandidate(
                    name: item.name.isEmpty ? fullID : item.name,
                    fullBundleIdentifier: fullID,
                    baseBundleIdentifier: fullID,
                    requiresAppendingTeamID: false,
                    expirationDate: item.expirationDate
                )
            )
        }

        candidates.sort { lhs, rhs in
            switch (lhs.expirationDate, rhs.expirationDate) {
            case let (l?, r?):
                if l != r { return l > r }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        }

        return candidates
    }

    /// Chỉ chặn đúng ID chính của ứng dụng chủ (SideStore / LiveContainer / LC+SS)
    private static func isExactProtectedHostMainID(
        lowerFull: String,
        hostMainID: String,
        teamID: String
    ) -> Bool {
        let lowerTeam = teamID.lowercased()

        if !hostMainID.isEmpty && lowerFull == hostMainID {
            return true
        }

        let exactProtectedMainBases = [
            "com.sidestore.sidestore",
            "com.rileytestut.altstore",
            "com.kdt.livecontainer"
        ]

        for mainBase in exactProtectedMainBases {
            if lowerFull == mainBase || (!lowerTeam.isEmpty && lowerFull == "\(mainBase).\(lowerTeam)") {
                return true
            }
        }

        return false
    }

    static func stripTrailingTeamID(from bundleID: String, teamID: String) -> String {
        return bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
