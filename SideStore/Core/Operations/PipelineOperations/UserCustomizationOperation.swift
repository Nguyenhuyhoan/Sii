
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
    /// Bundle ID đầy đủ trên Apple Portal (ví dụ: com.example.app.TEAMID)
    public let fullBundleIdentifier: String
    /// Bundle ID cơ sở sau khi đã tách bỏ hậu tố .TEAMID (ví dụ: com.example.app)
    public let baseBundleIdentifier: String
    public let expirationDate: Date?

    public init(name: String, fullBundleIdentifier: String, baseBundleIdentifier: String, expirationDate: Date?) {
        self.name = name
        self.fullBundleIdentifier = fullBundleIdentifier
        self.baseBundleIdentifier = baseBundleIdentifier
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
            let incomingBaseID = Self.stripTeamID(from: context.targetBundleIdentifier, teamID: teamID).lowercased()
            let incomingWithTeamID = "\(incomingBaseID).\(teamID)".lowercased()
            let incomingNameKey = targetAppBundle.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Tìm theo Bundle ID trước, nếu không khớp thì tìm theo Tên App (trường hợp App đang sống trước đó dùng ID tái sử dụng)
            let matchedObjectID = installedSnap.objectIDByBundleID[incomingBaseID]
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
        // -> Đi thẳng 100% không hiện bảng hỏi, tự động giữ nguyên ID hiện tại của App đó và gộp mọi mở rộng vào 1 ID chính!
        if context.isStoreUpdate || context.installedApp != nil {
            if let existingApp = context.installedApp {
                let existingResignedID = context.dbBackgroundContext.performAndWait {
                    existingApp.resignedBundleIdentifier
                }
                let existingBaseID = Self.stripTeamID(from: existingResignedID, teamID: teamID)
                if !existingBaseID.isEmpty, existingBaseID != context.bundleIdentifier {
                    context.customBundleIdentifier = existingBaseID
                }
                context.appendTeamID = true
            }
            debugLog("[UserCustomizationOperation] Existing app update detected; installing directly with 1 main ID for all extensions.")
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
                context.customBundleIdentifier = Self.stripTeamID(from: customID, teamID: teamID)
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
            // "Dùng ID gốc của IPA" HOẶC "Tái sử dụng ID sẵn có (bao gồm cả ID phụ cũ)"
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

            context.appendTeamID = result.appendTeamID
            let normalizedCustomID = Self.stripTeamID(from: result.customID, teamID: teamID)
            if !normalizedCustomID.isEmpty, normalizedCustomID != context.bundleIdentifier {
                context.customBundleIdentifier = normalizedCustomID
                didCustomizeBundleID = true
            } else {
                context.customBundleIdentifier = nil
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

    // MARK: - Helpers: Quét và lọc Kho App ID Trống an toàn 100%

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
            let hostBaseBundleID = Self.stripTeamID(from: hostMainBundleID, teamID: teamID).lowercased()

            for app in installedApps {
                let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let strippedRaw = Self.stripTeamID(from: rawID, teamID: teamID)
                let strippedResigned = Self.stripTeamID(from: resignedID, teamID: teamID)

                for idVariant in [
                    rawID,
                    resignedID,
                    strippedRaw,
                    strippedResigned,
                    "\(strippedRaw).\(teamID)",
                    "\(strippedResigned).\(teamID)"
                ] where !idVariant.isEmpty {
                    let lower = idVariant.lowercased()
                    activeMainIDs.insert(lower)
                    mapByID[lower] = app.objectID
                }

                // Không map theo tên đối với chính SideStore/LiveContainer để tránh nhận nhầm
                if !Self.isProtectedHostOrSideStoreID(
                    lowerFull: rawID.lowercased(),
                    lowerBase: strippedRaw.lowercased(),
                    hostMainID: hostMainBundleID,
                    hostBaseID: hostBaseBundleID
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
        let hostBaseBundleID = Self.stripTeamID(from: hostMainBundleID, teamID: teamID).lowercased()
        let now = Date()

        var seenBaseIDs = Set<String>()
        var candidates: [ReusableAppIDCandidate] = []

        for item in portalSnapshots {
            let fullID = item.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullID.isEmpty else { continue }

            if let exp = item.expirationDate, exp <= now {
                continue
            }

            let baseID = Self.stripTeamID(from: fullID, teamID: teamID)
            let lowerFull = fullID.lowercased()
            let lowerBase = baseID.lowercased()

            // 1. Loại bỏ hoàn toàn ID chính + mọi ID phụ của SideStore, LiveContainer, LC+SS
            if Self.isProtectedHostOrSideStoreID(
                lowerFull: lowerFull,
                lowerBase: lowerBase,
                hostMainID: hostMainBundleID,
                hostBaseID: hostBaseBundleID
            ) {
                continue
            }

            // 2. Loại bỏ hoàn toàn ID chính của các App đang sống (đang cài) trên máy
            if activeMainIDsLowercased.contains(lowerFull) || activeMainIDsLowercased.contains(lowerBase) {
                continue
            }

            // 3. Giữ lại toàn bộ các ID còn lại (bao gồm ID của app đã xóa VÀ các ID phụ/Extension của mọi app)
            guard !seenBaseIDs.contains(lowerBase) else { continue }
            seenBaseIDs.insert(lowerBase)

            candidates.append(
                ReusableAppIDCandidate(
                    name: item.name.isEmpty ? baseID : item.name,
                    fullBundleIdentifier: fullID,
                    baseBundleIdentifier: baseID,
                    expirationDate: item.expirationDate
                )
            )
        }

        candidates.sort { lhs, rhs in
            switch (lhs.expirationDate, rhs.expirationDate) {
            case let (l?, r?):
                if l != r { return l > r }
                return lhs.baseBundleIdentifier.localizedCaseInsensitiveCompare(rhs.baseBundleIdentifier) == .orderedAscending
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                return lhs.baseBundleIdentifier.localizedCaseInsensitiveCompare(rhs.baseBundleIdentifier) == .orderedAscending
            }
        }

        return candidates
    }

    private static func isProtectedHostOrSideStoreID(
        lowerFull: String,
        lowerBase: String,
        hostMainID: String,
        hostBaseID: String
    ) -> Bool {
        if !hostMainID.isEmpty && (lowerFull == hostMainID || lowerFull.hasPrefix(hostMainID + ".") || lowerBase == hostMainID || lowerBase.hasPrefix(hostMainID + ".")) {
            return true
        }
        if !hostBaseID.isEmpty && (lowerFull == hostBaseID || lowerFull.hasPrefix(hostBaseID + ".") || lowerBase == hostBaseID || lowerBase.hasPrefix(hostBaseID + ".")) {
            return true
        }

        let protectedPrefixes = [
            "com.sidestore.sidestore",
            "com.rileytestut.altstore",
            "com.kdt.livecontainer"
        ]
        for prefix in protectedPrefixes {
            if lowerBase == prefix || lowerBase.hasPrefix(prefix + ".") || lowerFull == prefix || lowerFull.hasPrefix(prefix + ".") {
                return true
            }
        }

        let protectedKeywords = [
            "livecontainer",
            "sidestore",
            "livewidget",
            "altwidget"
        ]
        for keyword in protectedKeywords {
            if lowerBase.contains(keyword) {
                return true
            }
        }

        return false
    }

    static func stripTeamID(from bundleID: String, teamID: String) -> String {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !teamID.isEmpty else { return trimmed }
        let suffix = ".\(teamID)"
        if trimmed.lowercased().hasSuffix(suffix.lowercased()) {
            return String(trimmed.dropLast(suffix.count))
        }
        return trimmed
    }
}

