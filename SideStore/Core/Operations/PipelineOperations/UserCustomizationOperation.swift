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

        // Lấy Tên thật và ID gốc thật sự của file IPA đang đưa vào
        let trueOriginalBundleID = targetAppBundle.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let incomingOrigBaseLower = Self.stripTrailingTeamID(from: trueOriginalBundleID, teamID: teamID).lowercased()
        let incomingNameLower = targetAppBundle.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // 1. Quét danh sách App đang sống trên máy
        let installedSnap = fetchInstalledAppSnapshots(teamID: teamID)

        // =========================================================================
        // THUẬT TOÁN NHẬN DIỆN THÔNG MINH (CHỐNG CÀI ĐÈ NHẦM KHI KHÁC TÊN APP)
        // =========================================================================
        // Nguyên tắc vàng:
        // - Nếu KHÔNG PHẢI bấm Update từ Store (context.isStoreUpdate == false):
        //   Hai app có thể dùng chung/mượn lại cùng một Bundle ID cũ, nên BẮT BUỘC
        //   TÊN APP PHẢI GIỐNG HỆT NHAU (existingName == incomingNameLower) thì mới
        //   được coi là tự động Cập Nhật (Update) không cần hỏi!
        // - Nếu trùng Bundle ID (hoặc nhớ lại ID cũ trong UserDefaults) nhưng TÊN APP KHÁC NHAU:
        //   Tuyệt đối KHÔNG được tự ý cài đè! Phải reset để hiện bảng hỏi cho người dùng chọn!
        // =========================================================================

        if !context.isStoreUpdate {
            // BƯỚC 1A: Kiểm tra lại context.installedApp (nếu bước Preflight trước đó đã gán sẵn do trùng ID)
            if let preMatchedApp = context.installedApp {
                let isSameAppIdentity: Bool = context.dbBackgroundContext.performAndWait {
                    let existingName = preMatchedApp.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    // BẮT BUỘC TÊN APP PHẢI TRÙNG KHỚP! Nếu khác tên app -> Chắc chắn là 2 app khác nhau!
                    return !incomingNameLower.isEmpty && existingName == incomingNameLower
                }

                if !isSameAppIdentity {
                    debugLog("[UserCustomizationOperation] Blocked auto-overwrite: Incoming IPA '\(targetAppBundle.name)' has different name from existing app. Forcing prompt!")
                    context.installedApp = nil
                    context.customBundleIdentifier = nil
                }
            }

            // BƯỚC 1B: Nếu context.installedApp đang nil, tìm xem có đúng App đó đang sống trên máy không
            // Chỉ khớp tự động khi TÊN APP TRÙNG KHỚP HOÀN TOÀN (ưu tiên khớp cả ID + Tên trước, sau đó mới tới Tên duy nhất)
            if context.installedApp == nil, !incomingNameLower.isEmpty {
                let matchedObjectID = installedSnap.objectIDByExactNameAndBaseID["\(incomingNameLower)|\(incomingOrigBaseLower)"]
                    ?? installedSnap.objectIDByUniqueAppName[incomingNameLower]

                if let matchedObjectID {
                    context.dbBackgroundContext.performAndWait {
                        if let matchedApp = try? context.dbBackgroundContext.existingObject(with: matchedObjectID) as? InstalledApp {
                            self.context.installedApp = matchedApp
                        }
                    }
                }
            }
        }

        // 2. NẾU LÀ CẬP NHẬT THẬT SỰ (Bấm Update từ Store HOẶC cài IPA mới của đúng App có cùng Tên đang sống trên máy):
        if context.isStoreUpdate || context.installedApp != nil {
            let existingResignedID: String? = context.dbBackgroundContext.performAndWait {
                self.context.installedApp?.resignedBundleIdentifier
            }
            if let trimmedResigned = existingResignedID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !trimmedResigned.isEmpty {
                context.customBundleIdentifier = trimmedResigned
                context.appendTeamID = false
            }
            debugLog("[UserCustomizationOperation] Genuine existing app update detected ('\(targetAppBundle.name)'); keeping existing ID and skipping prompt.")
            self.setProgress(100)
            return context.customBundleIdentifier != nil ? context.targetBundleIdentifier : nil
        }

        // 3. NẾU LÀ APP MỚI (HOẶC APP KHÁC TÊN NHƯNG TRÙNG/NHỚ LẠI ID CŨ):
        // Xóa sạch customBundleIdentifier cũ để hiện bảng hỏi với ID gốc sạch sẽ của IPA!
        context.customBundleIdentifier = nil

        let handler = context.handler.userCustomizationHandler
        var didCustomizeBundleID = false

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

            let initialBundleID = trueOriginalBundleID
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

            let mainModifiedPlist = result.modifiedPlists[initialBundleID] ?? [:]
            let customID = InfoPlistParser(dictionary: mainModifiedPlist).bundleIdentifier
            let resolvedBaseID = Self.stripTrailingTeamID(
                from: (customID?.isEmpty == false ? customID! : initialBundleID),
                teamID: teamID
            )
            context.appendTeamID = false
            context.customBundleIdentifier = "\(resolvedBaseID).\(teamID)"
            didCustomizeBundleID = true

            for (targetID, plist) in result.modifiedPlists {
                let key = (targetID == initialBundleID) ? context.targetBundleIdentifier : targetID
                context.customInfoPlistByBundleID[key] = plist
            }

            // Hậu kiểm: Chỉ gán installedApp (để ghi đè) nếu ID cuối cùng người dùng chốt trùng với một app đang có trên máy
            syncInstalledAppWithFinalChosenBundleID(teamID: teamID, installedSnap: installedSnap)
        } else {
            self.setProgress(35)
            let reusableCandidates = await fetchReusableAppIDCandidates(
                authTeam: authTeam,
                teamID: teamID,
                activeMainIDsLowercased: installedSnap.activeMainIDsLowercased
            )

            let initialBundleID = trueOriginalBundleID
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

            if let matchedCandidate = reusableCandidates.first(where: {
                $0.fullBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame ||
                $0.baseBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame
            }) {
                // KHI CHỌN "DÙNG LẠI ID CŨ":
                context.appendTeamID = false
                context.customBundleIdentifier = matchedCandidate.fullBundleIdentifier
                didCustomizeBundleID = true
            } else {
                // KHI DÙNG ID GỐC CỦA IPA HOẶC TỰ GÕ ID MỚI:
                // Luôn lưu đầy đủ cả hậu tố TeamID vào customBundleIdentifier ngay từ lần cài đầu tiên
                // để khi bấm Làm mới (Refresh) lần đầu không bao giờ bị lệch/thiếu TeamID gây lỗi 9120!
                let cleanCustomID = Self.stripTrailingTeamID(
                    from: chosenRawID.isEmpty ? initialBundleID : chosenRawID,
                    teamID: teamID
                )
                context.appendTeamID = false
                context.customBundleIdentifier = "\(cleanCustomID).\(teamID)"
                didCustomizeBundleID = true
            }

            // Hậu kiểm: Sau khi người dùng đã được hỏi và tự tay chốt ID trên bảng chọn:
            // - Nếu họ chọn 1 ID mới/ID cũ đang rảnh -> context.installedApp = nil (Cài thành App mới độc lập!)
            // - Nếu họ cố tình nhập/chọn đúng cái ID đang thuộc về 1 App đang sống -> Gán installedApp để cài đè theo ý họ.
            syncInstalledAppWithFinalChosenBundleID(teamID: teamID, installedSnap: installedSnap)
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

    // MARK: - Helpers: Đồng bộ & Nhận diện Thông minh

    /// Kiểm tra ID cuối cùng sau khi người dùng đã chọn trên bảng hỏi.
    /// Đảm bảo nếu chọn ID rảnh thì cài mới độc lập (`installedApp = nil`),
    /// còn nếu cố tình chọn trùng ID với một app đang sống thì cập nhật đúng vào slot đó.
    private func syncInstalledAppWithFinalChosenBundleID(teamID: String, installedSnap: InstalledAppSnapshot) {
        let baseChosen = (context.customBundleIdentifier ?? context.targetBundleIdentifier)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let finalFullID: String
        if context.appendTeamID && !teamID.isEmpty && !baseChosen.lowercased().hasSuffix(".\(teamID.lowercased())") {
            finalFullID = "\(baseChosen).\(teamID)"
        } else {
            finalFullID = baseChosen
        }

        let lowerFinal = finalFullID.lowercased()
        let lowerBase = Self.stripTrailingTeamID(from: finalFullID, teamID: teamID).lowercased()

        if let matchedID = installedSnap.objectIDByActiveBundleID[lowerFinal] ?? installedSnap.objectIDByActiveBundleID[lowerBase] {
            context.dbBackgroundContext.performAndWait {
                self.context.installedApp = try? context.dbBackgroundContext.existingObject(with: matchedID) as? InstalledApp
            }
        } else {
            context.installedApp = nil
        }
    }

    private struct InstalledAppSnapshot {
        /// Toàn bộ ID (cả gốc lẫn resigned) của các App đang sống -> dùng để ẩn khỏi danh sách "Dùng lại ID cũ"
        let activeMainIDsLowercased: Set<String>
        /// Khóa kép "tên_app|base_id" -> Nhận diện chuẩn xác 100% cùng Tên và cùng ID
        let objectIDByExactNameAndBaseID: [String: NSManagedObjectID]
        /// Chỉ lưu Tên App nếu trên máy có DUY NHẤT 1 App mang tên đó (dùng để nhận diện Update khi App đang mặc áo ID cũ khác với ID gốc trong IPA)
        let objectIDByUniqueAppName: [String: NSManagedObjectID]
        /// Bản đồ ID đang hoạt động -> ObjectID (chỉ dùng cho bước Hậu kiểm sau khi người dùng đã tự tay chọn trên bảng hỏi)
        let objectIDByActiveBundleID: [String: NSManagedObjectID]
    }

    private func fetchInstalledAppSnapshots(teamID: String) -> InstalledAppSnapshot {
        context.dbBackgroundContext.performAndWait {
            let request = InstalledApp.fetchRequest()
            let installedApps = (try? context.dbBackgroundContext.fetch(request)) ?? []

            var activeMainIDs = Set<String>()
            var mapByNameAndBaseID: [String: NSManagedObjectID] = [:]
            var mapByUniqueName: [String: NSManagedObjectID] = [:]
            var duplicatedNames = Set<String>()
            var mapByActiveBundleID: [String: NSManagedObjectID] = [:]

            let hostMainBundleID = (Bundle.main.bundleIdentifier ?? "").lowercased()
            let lowerTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Bảo vệ ứng dụng chủ SideStore đang chạy
            if !hostMainBundleID.isEmpty {
                activeMainIDs.insert(hostMainBundleID)
                if !lowerTeam.isEmpty && !hostMainBundleID.hasSuffix(".\(lowerTeam)") {
                    activeMainIDs.insert("\(hostMainBundleID).\(lowerTeam)")
                }
            }

            for app in installedApps {
                let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let nameKey = app.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                let isHostApp = Self.isProtectedHostOrCoreApp(
                    lowerFull: rawID.lowercased(),
                    hostMainID: hostMainBundleID,
                    teamID: teamID
                )

                for idVariant in [rawID, resignedID] where !idVariant.isEmpty {
                    let lower = idVariant.lowercased()
                    activeMainIDs.insert(lower)

                    if !lowerTeam.isEmpty && !lower.hasSuffix(".\(lowerTeam)") {
                        activeMainIDs.insert("\(lower).\(lowerTeam)")
                    }

                    if !isHostApp {
                        let baseLower = Self.stripTrailingTeamID(from: idVariant, teamID: teamID).lowercased()
                        mapByActiveBundleID[lower] = app.objectID
                        mapByActiveBundleID[baseLower] = app.objectID

                        if !nameKey.isEmpty {
                            mapByNameAndBaseID["\(nameKey)|\(baseLower)"] = app.objectID
                            mapByNameAndBaseID["\(nameKey)|\(lower)"] = app.objectID
                        }
                    }
                }

                // Ghi nhận Tên App duy nhất (nếu có 2 bản clone trùng tên trên máy thì loại khỏi danh sách tự động khớp theo tên để luôn hỏi người dùng muốn cập nhật bản nào)
                if !isHostApp, !nameKey.isEmpty {
                    if duplicatedNames.contains(nameKey) {
                        // Đã bị trùng tên -> không tự đoán mò
                    } else if mapByUniqueName[nameKey] != nil {
                        mapByUniqueName.removeValue(forKey: nameKey)
                        duplicatedNames.insert(nameKey)
                    } else {
                        mapByUniqueName[nameKey] = app.objectID
                    }
                }
            }

            return InstalledAppSnapshot(
                activeMainIDsLowercased: activeMainIDs,
                objectIDByExactNameAndBaseID: mapByNameAndBaseID,
                objectIDByUniqueAppName: mapByUniqueName,
                objectIDByActiveBundleID: mapByActiveBundleID
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

            // 1. Chặn ID chính và các ID phụ (.appex) của SideStore / AltStore hệ thống
            if Self.isProtectedHostOrCoreApp(
                lowerFull: lowerFull,
                hostMainID: hostMainBundleID,
                teamID: teamID
            ) {
                continue
            }

            // 2. Chặn cả ID chính LẪN mọi ID phụ (.appex) của các App ĐANG SỐNG trên máy
            let isUsedByActiveAppOrItsExtensions = activeMainIDsLowercased.contains { activeID in
                lowerFull == activeID || lowerFull.hasPrefix(activeID + ".")
            }
            if isUsedByActiveAppOrItsExtensions {
                continue
            }

            guard !seenFullIDs.contains(lowerFull) else { continue }
            seenFullIDs.insert(lowerFull)

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
