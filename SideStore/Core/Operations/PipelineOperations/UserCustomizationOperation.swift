
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
    /// Bundle ID đã bỏ đuôi Team ID để hiển thị gọn gàng trên UI (ví dụ: com.alone)
    public let baseBundleIdentifier: String
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

        guard let targetAppBundle = context.targetAppBundle else {
            throw OperationError.invalidParameters("UserCustomizationOperation: context.targetAppBundle is nil")
        }

        let authTeam = try await AuthManager.shared.getAuthenticatedTeam()
        let teamID = authTeam.identifier
        guard !teamID.isEmpty else {
            debugLog("[UserCustomizationOperation] FAILED: authTeamID is empty")
            throw OperationError.invalidParameters("Active developer team identifier is missing.")
        }

        // Luôn bật cờ gộp chung 1 Provisioning Profile của App chính cho mọi phần mở rộng
        self.context.useMainProfile = true

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
        if context.isStoreUpdate || context.installedApp != nil {
            let existingResignedID: String? = context.dbBackgroundContext.performAndWait {
                self.context.installedApp?.resignedBundleIdentifier
            }
            if let trimmedResigned = existingResignedID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !trimmedResigned.isEmpty {
                context.customBundleIdentifier = trimmedResigned
                context.appendTeamID = false
            }
            debugLog("[UserCustomizationOperation] Existing app update detected; keeping existing ID and skipping prompt.")
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
                appendTeamID: true,
                installedAppIdentities: installedAppIdentities,
                teamID: teamID
            ) else {
                throw OperationError.cancelled
            }

            context.appendTeamID = true

            let mainModifiedPlist = result.modifiedPlists[initialBundleID] ?? [:]
            let customID = InfoPlistParser(dictionary: mainModifiedPlist).bundleIdentifier
            if let customID = customID, !customID.isEmpty, customID != context.bundleIdentifier {
                context.customBundleIdentifier = Self.stripTrailingTeamID(from: customID, teamID: teamID)
                didCustomizeBundleID = true
            } else {
                context.customBundleIdentifier = nil
            }

            for (targetID, plist) in result.modifiedPlists {
                let key = (targetID == initialBundleID) ? context.targetBundleIdentifier : targetID
                context.customInfoPlistByBundleID[key] = plist
            }

            let effectiveCustomID = context.customBundleIdentifier ?? initialBundleID
            let resolvedID = !teamID.isEmpty ? "\(effectiveCustomID).\(teamID)" : effectiveCustomID
            if let matchingApp = installedApps.first(where: { $0.bundleIdentifier == resolvedID || $0.resignedBundleIdentifier == resolvedID }) {
                context.installedApp = matchingApp
            } else {
                context.installedApp = nil
            }
        } else {
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

            // Kiểm tra xem ID người dùng chọn có nằm trong danh sách ID cũ rảnh rỗi không
            // (Khớp cả trường hợp truyền fullBundleIdentifier lẫn baseBundleIdentifier đã cắt đuôi Team ID)
            if let matchedCandidate = reusableCandidates.first(where: {
                $0.fullBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame ||
                $0.baseBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame
            }) {
                // KHI CHỌN "DÙNG LẠI ID CŨ":
                // Luôn lấy fullBundleIdentifier chính xác trên Apple Portal (VD: com.alone.37D6PWG5PP)
                // và đặt appendTeamID = false để không bị gắn trùng đuôi Team ID lần 2!
                context.appendTeamID = false
                context.customBundleIdentifier = matchedCandidate.fullBundleIdentifier
                didCustomizeBundleID = true
            } else {
                // KHI DÙNG ID GỐC CỦA IPA HOẶC TỰ GÕ ID MỚI:
                // Mặc định luôn bật gắn hậu tố Team ID (appendTeamID = true)
                context.appendTeamID = true
                let cleanCustomID = Self.stripTrailingTeamID(from: chosenRawID, teamID: teamID)
                if !cleanCustomID.isEmpty, cleanCustomID != context.bundleIdentifier {
                    context.customBundleIdentifier = cleanCustomID
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

    // MARK: - Helpers: Quét và lọc Kho App ID Trống (Loại bỏ cả ID chính lẫn ID phụ .appex của App đang sống)

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
            let lowerTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Bảo vệ ứng dụng chủ SideStore đang chạy (kèm các extension của chính nó)
            if !hostMainBundleID.isEmpty {
                activeMainIDs.insert(hostMainBundleID)
                if !lowerTeam.isEmpty && !hostMainBundleID.hasSuffix(".\(lowerTeam)") {
                    activeMainIDs.insert("\(hostMainBundleID).\(lowerTeam)")
                }
            }

            for app in installedApps {
                let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

                for idVariant in [rawID, resignedID] where !idVariant.isEmpty {
                    let lower = idVariant.lowercased()
                    activeMainIDs.insert(lower)
                    mapByID[lower] = app.objectID

                    // Đưa cả biến thể có gắn .TEAM_ID của App đang sống vào danh sách bận
                    // để chặn luôn các ID phụ (ví dụ: com.kdt.livecontainer.TEAMID.LaunchAppExtension)
                    if !lowerTeam.isEmpty && !lower.hasSuffix(".\(lowerTeam)") {
                        activeMainIDs.insert("\(lower).\(lowerTeam)")
                    }
                }

                if !Self.isProtectedHostOrCoreApp(
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

            // 1. Chặn ID chính và các ID phụ (.appex) của SideStore / AltStore / LiveContainer hệ thống
            if Self.isProtectedHostOrCoreApp(
                lowerFull: lowerFull,
                hostMainID: hostMainBundleID,
                teamID: teamID
            ) {
                continue
            }

            // 2. Chặn cả ID chính LẪN mọi ID phụ (.appex) của các App ĐANG SỐNG trên máy
            // (Vì iOS installd không cho phép cài 1 app mới trùng ID với .appex của app đang cài)
            let isUsedByActiveAppOrItsExtensions = activeMainIDsLowercased.contains { activeID in
                lowerFull == activeID || lowerFull.hasPrefix(activeID + ".")
            }
            if isUsedByActiveAppOrItsExtensions {
                continue
            }

            guard !seenFullIDs.contains(lowerFull) else { continue }
            seenFullIDs.insert(lowerFull)

            // Cắt bỏ .TEAM_ID (cả ở cuối lẫn ở giữa) để hiển thị trên giao diện gọn gàng
            let shortDisplayID = Self.stripTrailingTeamID(from: fullID, teamID: teamID)

            candidates.append(
                ReusableAppIDCandidate(
                    name: item.name.isEmpty ? shortDisplayID : item.name,
                    fullBundleIdentifier: fullID,
                    baseBundleIdentifier: shortDisplayID,
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

    /// Kiểm tra xem ID có thuộc về SideStore / AltStore (kể cả Widget/Extension của nó) hay không
    private static func isProtectedHostOrCoreApp(
        lowerFull: String,
        hostMainID: String,
        teamID: String
    ) -> Bool {
        let lowerTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if !hostMainID.isEmpty {
            if lowerFull == hostMainID || lowerFull.hasPrefix(hostMainID + ".") {
                return true
            }
        }

        let protectedMainBases = [
            "com.sidestore.sidestore",
            "com.rileytestut.altstore"
        ]

        for mainBase in protectedMainBases {
            if lowerFull == mainBase || lowerFull.hasPrefix(mainBase + ".") {
                return true
            }
            if !lowerTeam.isEmpty {
                let withTeam = "\(mainBase).\(lowerTeam)"
                if lowerFull == withTeam || lowerFull.hasPrefix(withTeam + ".") {
                    return true
                }
            }
        }

        return false
    }

    /// Tự động cắt bỏ `.TEAM_ID` ở cuối (VD: `com.alone.37D6PWG5PP` -> `com.alone`)
    /// hoặc `.TEAM_ID.` ở giữa của ID phụ thuộc app đã xóa (VD: `com.app.37D6PWG5PP.Widget` -> `com.app.Widget`)
    static func stripTrailingTeamID(from bundleID: String, teamID: String) -> String {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTeamID = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTeamID.isEmpty else { return trimmed }

        let middleToken = ".\(cleanTeamID)."
        if let range = trimmed.range(of: middleToken, options: .caseInsensitive) {
            return trimmed.replacingCharacters(in: range, with: ".")
        }

        let suffix = ".\(cleanTeamID)"
        if trimmed.lowercased().hasSuffix(suffix.lowercased()), trimmed.count > suffix.count {
            return String(trimmed.dropLast(suffix.count))
        }
        return trimmed
    }
}
