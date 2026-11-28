
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

/// Thông tin một App đang sống trên máy có thể chọn để cài đè trực tiếp (lấy ID của app đó gán cho IPA mới và mở rộng của IPA mới)
public struct OverwritableAppCandidate: Identifiable, Hashable, Sendable {
    public var id: String { fullBundleIdentifier }
    public let name: String
    /// Bundle ID đầy đủ có kèm Team ID đang dùng để ký app đó (ví dụ: com.example.app.37D6PWG5PP)
    public let fullBundleIdentifier: String
    /// Bundle ID đã cắt đuôi Team ID để hiển thị gọn gàng trên giao diện
    public let baseBundleIdentifier: String
    public let version: String?
    public let expirationDate: Date?

    public init(
        name: String,
        fullBundleIdentifier: String,
        baseBundleIdentifier: String? = nil,
        version: String? = nil,
        expirationDate: Date? = nil
    ) {
        self.name = name
        self.fullBundleIdentifier = fullBundleIdentifier
        self.baseBundleIdentifier = baseBundleIdentifier ?? fullBundleIdentifier
        self.version = version
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

        // Nếu chính gói IPA đang cài là SideStore / AltStore thì cài luôn không hỏi
        if targetAppBundle.isAltStoreApp || targetAppBundle.bundleIdentifier.isAltStoreAppID {
            self.setProgress(100)
            return context.customBundleIdentifier != nil ? context.targetBundleIdentifier : nil
        }

        // Lấy tất cả các biến thể Tên và ID gốc thật sự của file IPA đang đưa vào
        let trueOriginalBundleID = targetAppBundle.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let incomingOrigBaseLower = Self.stripTrailingTeamID(from: trueOriginalBundleID, teamID: teamID).lowercased()
        let incomingNamesLower = Self.extractNormalizedAppNames(from: targetAppBundle)

        // 1. Quét danh sách App ĐANG SỐNG THẬT SỰ trên máy
        let installedSnap = fetchInstalledAppSnapshots(teamID: teamID, teamType: authTeam.type)

        // =========================================================================
        // THUẬT TOÁN NHẬN DIỆN TỰ ĐỘNG:
        // - Nếu IPA đang cài có CÙNG TÊN APP + CÙNG ID -> Tự động cài đè luôn, không hiện bảng hỏi.
        // - Nếu chỉ trùng Tên App duy nhất trên máy (nhưng khác ID) hoặc chỉ trùng ID (nhưng khác Tên App)
        //   -> Vẫn hiện bảng hỏi!
        // =========================================================================
        if !context.isStoreUpdate {
            var matchedLiveObjectID: NSManagedObjectID? = nil

            // Ưu tiên 1: Tìm App đang sống có CÙNG TÊN APP và CÙNG ID
            for nameLower in incomingNamesLower {
                if let exactMatch = installedSnap.objectIDByExactNameAndBaseID["\(nameLower)|\(incomingOrigBaseLower)"] {
                    matchedLiveObjectID = exactMatch
                    break
                }
            }

            // Ưu tiên 2: Nếu context.installedApp đã được bước trước gán sẵn, kiểm tra xem nó có đang sống và CÙNG TÊN + CÙNG ID không
            if matchedLiveObjectID == nil, let preMatchedApp = context.installedApp {
                let isValidExactSameApp: Bool = context.dbBackgroundContext.performAndWait {
                    guard Self.isTrulyLiveInstalledApp(preMatchedApp) else { return false }
                    let existingName = Self.normalizeAppName(preMatchedApp.name)
                    let existingBaseID = Self.stripTrailingTeamID(from: preMatchedApp.bundleIdentifier, teamID: teamID).lowercased()
                    let existingResignedBaseID = Self.stripTrailingTeamID(from: preMatchedApp.resignedBundleIdentifier, teamID: teamID).lowercased()
                    let existingCustomBaseID = Self.stripTrailingTeamID(from: preMatchedApp.customBundleIdentifier ?? "", teamID: teamID).lowercased()

                    let hasMatchingID = (existingBaseID == incomingOrigBaseLower) ||
                                        (existingResignedBaseID == incomingOrigBaseLower) ||
                                        (!existingCustomBaseID.isEmpty && existingCustomBaseID == incomingOrigBaseLower)
                    let hasMatchingName = !existingName.isEmpty && incomingNamesLower.contains(existingName)

                    // Bắt buộc phải khớp CẢ Tên App LẪN ID
                    return hasMatchingName && hasMatchingID
                }
                if isValidExactSameApp {
                    matchedLiveObjectID = preMatchedApp.objectID
                } else {
                    debugLog("[UserCustomizationOperation] Cleared non-exact preMatchedApp for '\(targetAppBundle.name)' so user will be prompted.")
                    context.installedApp = nil
                    context.customBundleIdentifier = nil
                }
            }

            // Gán lại chính xác context.installedApp chỉ khi tìm thấy App đang sống trùng CẢ Tên lẫn ID
            if let matchedLiveObjectID {
                context.dbBackgroundContext.performAndWait {
                    if let liveApp = try? context.dbBackgroundContext.existingObject(with: matchedLiveObjectID) as? InstalledApp {
                        self.context.installedApp = liveApp
                    }
                }
            } else {
                context.installedApp = nil
            }
        }

        // 2. NẾU ĐÃ KHỚP APP ĐANG SỐNG (CÙNG TÊN + CÙNG ID / CẬP NHẬT STORE) -> CÀI ĐÈ LUÔN, KHÔNG HIỆN BẢNG HỎI!
        if context.isStoreUpdate || context.installedApp != nil {
            let existingEffectiveID: String? = context.dbBackgroundContext.performAndWait {
                guard let app = self.context.installedApp else { return nil }
                let custom = (app.customBundleIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                if !custom.isEmpty { return custom }
                let resigned = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                if !resigned.isEmpty { return resigned }
                let raw = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                return raw.isEmpty ? nil : raw
            }

            if let existingID = existingEffectiveID, !existingID.isEmpty {
                let cleanBase = Self.stripTrailingTeamID(from: existingID, teamID: teamID)
                let lowerTeam = teamID.lowercased()
                if existingID.lowercased().hasSuffix(".\(lowerTeam)") {
                    context.customBundleIdentifier = existingID
                } else {
                    context.customBundleIdentifier = "\(cleanBase).\(teamID)"
                }
                context.appendTeamID = false
            }

            debugLog("[UserCustomizationOperation] Matched live app with same Name + ID ('\(targetAppBundle.name)'); auto-installing with ID '\(context.customBundleIdentifier ?? context.targetBundleIdentifier)' without prompting.")
            self.setProgress(100)
            return context.customBundleIdentifier != nil ? context.targetBundleIdentifier : nil
        }

        // 3. NẾU LÀ APP MỚI HOÀN TOÀN (HOẶC TRÙNG TÊN DUY NHẤT NHƯNG KHÁC ID / TRÙNG ID NHƯNG KHÁC TÊN):
        // Xóa sạch customBundleIdentifier cũ để hiện bảng hỏi với ID gốc sạch sẽ của IPA!
        context.customBundleIdentifier = nil

        let handler = context.handler.userCustomizationHandler
        var didCustomizeBundleID = false

        if UserDefaults.standard.customizeInfoPlist {
            let installedApps: [InstalledApp] = context.dbBackgroundContext.performAndWait {
                InstalledApp.fetchActiveApps(in: context.dbBackgroundContext)
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

            // Hậu kiểm: Chỉ gán installedApp (để ghi đè) nếu ID cuối cùng người dùng chốt trùng với một app đang sống trên máy
            syncInstalledAppWithFinalChosenBundleID(teamID: teamID, installedSnap: installedSnap)
        } else {
            self.setProgress(35)
            let reusableCandidates = await fetchReusableAppIDCandidates(
                authTeam: authTeam,
                teamID: teamID,
                excludedBaseOrFullIDsLowercased: installedSnap.activeAndProtectedIDsLowercased
            )

            let initialBundleID = trueOriginalBundleID
            self.setProgress(50)

            guard let result = try await handler.resolveBundleIDOverride(
                initialBundleID: initialBundleID,
                appName: targetAppBundle.name,
                teamID: teamID,
                reusableAppIDs: reusableCandidates,
                overwritableApps: installedSnap.overwritableCandidates
            ) else {
                throw OperationError.cancelled
            }

            let chosenRawID = result.customID.trimmingCharacters(in: .whitespacesAndNewlines)

            if let matchedOverwrite = installedSnap.overwritableCandidates.first(where: {
                $0.fullBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame ||
                $0.baseBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame
            }) {
                // KHI CHỌN "CÀI ĐÈ LÊN APP":
                // Lấy chính xác Bundle ID đã ký của App bị cài đè gán cho IPA mới (và mở rộng của IPA mới sẽ tự nối theo ID này)
                context.appendTeamID = false
                context.customBundleIdentifier = matchedOverwrite.fullBundleIdentifier
                didCustomizeBundleID = true
            } else if let matchedCandidate = reusableCandidates.first(where: {
                $0.fullBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame ||
                $0.baseBundleIdentifier.caseInsensitiveCompare(chosenRawID) == .orderedSame
            }) {
                // KHI CHỌN "DÙNG LẠI ID CŨ":
                context.appendTeamID = false
                context.customBundleIdentifier = matchedCandidate.fullBundleIdentifier
                didCustomizeBundleID = true
            } else {
                // KHI DÙNG ID GỐC CỦA IPA HOẶC TỰ GÕ ID MỚI:
                let cleanCustomID = Self.stripTrailingTeamID(
                    from: chosenRawID.isEmpty ? initialBundleID : chosenRawID,
                    teamID: teamID
                )
                context.appendTeamID = false
                context.customBundleIdentifier = "\(cleanCustomID).\(teamID)"
                didCustomizeBundleID = true
            }

            // Hậu kiểm:
            // - Nếu chọn "Cài đè lên App" (hoặc gõ đúng ID của App đang sống): Gán context.installedApp = App đó để ghi đè và dùng lại ID cho cả IPA mới + phần mở rộng.
            // - Nếu chọn "Dùng lại ID cũ" đang rảnh hoặc ID mới: context.installedApp = nil (cài thành App mới độc lập).
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

    /// Chuẩn hóa tên App để so sánh chính xác (bỏ khoảng trắng thừa, gộp khoảng trắng, chữ thường)
    private static func normalizeAppName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let components = trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        return components.joined(separator: " ")
    }

    /// Lấy tất cả các biến thể tên của gói IPA đang cài (name, CFBundleDisplayName, CFBundleName)
    private static func extractNormalizedAppNames(from bundle: ALTApplication) -> Set<String> {
        var names = Set<String>()
        let n1 = normalizeAppName(bundle.name)
        if !n1.isEmpty { names.insert(n1) }

        if let displayName = bundle.infoPlist["CFBundleDisplayName"] as? String {
            let n2 = normalizeAppName(displayName)
            if !n2.isEmpty { names.insert(n2) }
        }
        if let bundleName = bundle.infoPlist["CFBundleName"] as? String {
            let n3 = normalizeAppName(bundleName)
            if !n3.isEmpty { names.insert(n3) }
        }
        return names
    }

    /// Kiểm tra một bản ghi `InstalledApp` trong Database có phải là App ĐANG SỐNG THỰC SỰ trên thiết bị hay không
    private static func isTrulyLiveInstalledApp(_ app: InstalledApp) -> Bool {
        if app.isDeleted { return false }
        guard app.isActive else { return false }
        let resigned = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !resigned.isEmpty else { return false }
        // Không lấy các app đã bị thu hồi hoặc hết hạn hoàn toàn mà không còn file
        if app.certificateStatus == .revoked { return false }
        if !FileManager.default.fileExists(atPath: app.directoryURL.path) &&
           !FileManager.default.fileExists(atPath: app.fileURL.path) {
            return false
        }
        return true
    }

    /// Kiểm tra xem một `InstalledApp` có phải là SideStore, AltStore hoặc LiveContainer (LC+SS) không
    private static func isProtectedInstalledApp(
        _ app: InstalledApp,
        hostMainID: String,
        teamID: String
    ) -> Bool {
        // 1. Kiểm tra bằng thuộc tính chuẩn của SideStore (StoreApp.altstoreAppID & .isAltStoreAppID)
        if app.bundleIdentifier == StoreApp.altstoreAppID ||
           app.bundleIdentifier.isAltStoreAppID ||
           app.resignedBundleIdentifier.isAltStoreAppID ||
           (app.customBundleIdentifier?.isAltStoreAppID == true) {
            return true
        }

        // 2. Kiểm tra đường dẫn bundle trùng với activeBundleURL đang chạy
        if app.fileURL.standardizedFileURL == Bundle.Info.activeBundleURL.standardizedFileURL {
            return true
        }

        let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let customID = (app.customBundleIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let appNameLower = normalizeAppName(app.name)

        // 3. Kiểm tra theo ID chính và Tên App (bao gồm cả LiveContainer / LC+SS)
        if isProtectedHostOrCoreApp(lowerFull: rawID, appNameLower: appNameLower, hostMainID: hostMainID, teamID: teamID) ||
           isProtectedHostOrCoreApp(lowerFull: resignedID, appNameLower: appNameLower, hostMainID: hostMainID, teamID: teamID) ||
           (!customID.isEmpty && isProtectedHostOrCoreApp(lowerFull: customID, appNameLower: appNameLower, hostMainID: hostMainID, teamID: teamID)) {
            return true
        }

        // 4. Kiểm tra các App Extension (.appex) bên trong:
        // Bản LC+SS (LiveContainer + SideStore) nhúng SideStore dưới dạng Extension -> bắt dính 100% dù người dùng đổi tên hay đổi ID!
        for ext in app.appExtensions {
            if ext.bundleIdentifier.isAltStoreAppID || ext.resignedBundleIdentifier.isAltStoreAppID {
                return true
            }
            let extRaw = ext.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let extResigned = ext.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let extName = normalizeAppName(ext.name)

            if isProtectedHostOrCoreApp(lowerFull: extRaw, appNameLower: extName, hostMainID: hostMainID, teamID: teamID) ||
               isProtectedHostOrCoreApp(lowerFull: extResigned, appNameLower: extName, hostMainID: hostMainID, teamID: teamID) {
                return true
            }
        }

        return false
    }

    /// Kiểm tra ID cuối cùng sau khi người dùng đã chọn trên bảng hỏi.
    /// Đảm bảo nếu chọn ID rảnh thì cài mới độc lập (`installedApp = nil`),
    /// còn nếu chọn "Cài đè lên App" (hoặc chọn trùng ID với một app đang sống) thì gán đúng vào slot `installedApp` đó.
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
        /// Toàn bộ ID (cả base lẫn có đuôi TeamID) của các App đang sống + SideStore + LC+SS -> dùng để trừ cả ID chính lẫn ID mở rộng khỏi "Dùng lại ID cũ"
        let activeAndProtectedIDsLowercased: Set<String>
        /// Danh sách các App đang sống thực sự có thể cài đè (đã trừ SideStore, LC+SS và các app đã xóa/không active)
        let overwritableCandidates: [OverwritableAppCandidate]
        /// Khóa kép "tên_app|base_id" -> Nhận diện chuẩn xác 100% cùng Tên và cùng ID
        let objectIDByExactNameAndBaseID: [String: NSManagedObjectID]
        /// Bản đồ ID đang hoạt động -> ObjectID (dùng cho bước Hậu kiểm & Cài đè)
        let objectIDByActiveBundleID: [String: NSManagedObjectID]
    }

    private func fetchInstalledAppSnapshots(teamID: String, teamType: ALTTeamType) -> InstalledAppSnapshot {
        context.dbBackgroundContext.performAndWait {
            let allFetchedApps = InstalledApp.fetchActiveApps(in: context.dbBackgroundContext)

            var activeAndProtectedIDs = Set<String>()
            var overwritableList: [OverwritableAppCandidate] = []
            var seenOverwritableBaseIDs = Set<String>()
            var mapByNameAndBaseID: [String: NSManagedObjectID] = [:]
            var mapByActiveBundleID: [String: NSManagedObjectID] = [:]

            let hostMainBundleID = (Bundle.main.bundleIdentifier ?? "").lowercased()
            let lowerTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Helper thêm cả bản gốc (không TeamID) và bản có TeamID vào tập hợp loại trừ để chặn sạch cả .appex
            let insertAllForms: (String) -> Void = { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                let lower = trimmed.lowercased()
                let baseLower = Self.stripTrailingTeamID(from: trimmed, teamID: teamID).lowercased()

                activeAndProtectedIDs.insert(lower)
                activeAndProtectedIDs.insert(baseLower)
                if !lowerTeam.isEmpty {
                    activeAndProtectedIDs.insert("\(baseLower).\(lowerTeam)")
                }
            }

            // Luôn bảo vệ StoreApp.altstoreAppID và ứng dụng chủ đang chạy (SideStore / LC+SS) cùng các App Extension của nó
            insertAllForms(StoreApp.altstoreAppID)
            if !hostMainBundleID.isEmpty {
                insertAllForms(hostMainBundleID)
            }
            if let activeBundle = Bundle(url: Bundle.Info.activeBundleURL),
               let activeID = activeBundle.bundleIdentifier {
                insertAllForms(activeID)
            }
            if let plugInsURL = Bundle.main.builtInPlugInsURL,
               let pluginURLs = try? FileManager.default.contentsOfDirectory(at: plugInsURL, includingPropertiesForKeys: nil) {
                for url in pluginURLs where url.pathExtension.lowercased() == "appex" {
                    if let extBundle = Bundle(url: url), let extID = extBundle.bundleIdentifier {
                        insertAllForms(extID)
                    }
                }
            }

            // Bảo vệ cả bản ghi AltStore/SideStore trong DB nếu có
            if let altStoreApp = InstalledApp.fetchAltStore(in: context.dbBackgroundContext) {
                insertAllForms(altStoreApp.bundleIdentifier)
                insertAllForms(altStoreApp.resignedBundleIdentifier)
                if let custom = altStoreApp.customBundleIdentifier {
                    insertAllForms(custom)
                }
                for ext in altStoreApp.appExtensions {
                    insertAllForms(ext.bundleIdentifier)
                    insertAllForms(ext.resignedBundleIdentifier)
                }
            }

            // Phân loại: Bảo vệ SideStore / LC+SS trước, sau đó lọc các App thường đang sống
            var liveUserApps: [InstalledApp] = []

            for app in allFetchedApps {
                let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let customID = (app.customBundleIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

                // 1. Nếu là SideStore hoặc LC+SS -> Đưa toàn bộ ID chính + Extension vào danh sách bảo vệ tuyệt đối, và KHÔNG BAO GIỜ đưa vào danh sách cài đè!
                if Self.isProtectedInstalledApp(app, hostMainID: hostMainBundleID, teamID: teamID) {
                    for idVariant in [rawID, resignedID, customID] where !idVariant.isEmpty {
                        insertAllForms(idVariant)
                    }
                    for ext in app.appExtensions {
                        insertAllForms(ext.bundleIdentifier)
                        insertAllForms(ext.resignedBundleIdentifier)
                    }
                    continue
                }

                // 2. Chỉ giữ lại những App đang sống thực sự trên máy
                guard Self.isTrulyLiveInstalledApp(app) else {
                    continue
                }

                liveUserApps.append(app)
            }

            // Sắp xếp các App đang sống theo ngày làm mới/cài đặt mới nhất trước.
            // Trên tài khoản Free (InstalledApp.freeAccountActiveAppsLimit == 3, trừ 1 slot của SideStore/LC+SS còn tối đa 2 App ngoài),
            // nếu chưa bật MacDirtyCow (isAppLimitDisabled == false) thì chỉ giữ đúng tối đa (freeAccountActiveAppsLimit - 1) = 2 App đang sống!
            liveUserApps.sort { lhs, rhs in
                if lhs.refreshedDate != rhs.refreshedDate {
                    return lhs.refreshedDate > rhs.refreshedDate
                }
                return lhs.installedDate > rhs.installedDate
            }

            if teamType == .free {
                let maxUserAppsOnDevice = max(1, InstalledApp.freeAccountActiveAppsLimit - 1)
                if liveUserApps.count > maxUserAppsOnDevice {
                    liveUserApps = Array(liveUserApps.prefix(maxUserAppsOnDevice))
                }
            }

            for app in liveUserApps {
                let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let customID = (app.customBundleIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let appName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let nameKey = Self.normalizeAppName(appName)

                // Đưa ID chính + các ID mở rộng (.appex) của App đang sống vào danh sách loại trừ khỏi "Dùng lại ID cũ"
                for idVariant in [rawID, resignedID, customID] where !idVariant.isEmpty {
                    insertAllForms(idVariant)
                }
                for ext in app.appExtensions {
                    insertAllForms(ext.bundleIdentifier)
                    insertAllForms(ext.resignedBundleIdentifier)
                }

                // Ghi nhận vào bảng tra cứu tự động cập nhật (Cùng Tên + Cùng ID) và bảng Cài đè
                for idVariant in [rawID, resignedID, customID] where !idVariant.isEmpty {
                    let lower = idVariant.lowercased()
                    let baseLower = Self.stripTrailingTeamID(from: idVariant, teamID: teamID).lowercased()

                    mapByActiveBundleID[lower] = app.objectID
                    mapByActiveBundleID[baseLower] = app.objectID
                    if !lowerTeam.isEmpty {
                        mapByActiveBundleID["\(baseLower).\(lowerTeam)"] = app.objectID
                    }

                    if !nameKey.isEmpty {
                        mapByNameAndBaseID["\(nameKey)|\(baseLower)"] = app.objectID
                        mapByNameAndBaseID["\(nameKey)|\(lower)"] = app.objectID
                    }
                }

                // Cũng đọc thêm CFBundleDisplayName / CFBundleName từ fileURL của App đang sống (nếu có) để khớp Tên App + ID chính xác 100%
                if let installedBundle = ALTApplication(fileURL: app.fileURL) {
                    let extraNames = Self.extractNormalizedAppNames(from: installedBundle)
                    for extraName in extraNames {
                        for idVariant in [rawID, resignedID, customID] where !idVariant.isEmpty {
                            let lower = idVariant.lowercased()
                            let baseLower = Self.stripTrailingTeamID(from: idVariant, teamID: teamID).lowercased()
                            mapByNameAndBaseID["\(extraName)|\(baseLower)"] = app.objectID
                            mapByNameAndBaseID["\(extraName)|\(lower)"] = app.objectID
                        }
                    }
                }

                // Tạo ứng viên cho mục "Cài đè lên App"
                let effectiveIDSource = !customID.isEmpty ? customID : (!resignedID.isEmpty ? resignedID : rawID)
                if !effectiveIDSource.isEmpty {
                    let cleanBase = Self.stripTrailingTeamID(from: effectiveIDSource, teamID: teamID)
                    let fullWithTeam: String
                    if !teamID.isEmpty && !effectiveIDSource.lowercased().hasSuffix(".\(lowerTeam)") {
                        fullWithTeam = "\(cleanBase).\(teamID)"
                    } else {
                        fullWithTeam = effectiveIDSource
                    }

                    let lowerBaseKey = cleanBase.lowercased()
                    if !seenOverwritableBaseIDs.contains(lowerBaseKey) {
                        seenOverwritableBaseIDs.insert(lowerBaseKey)
                        overwritableList.append(
                            OverwritableAppCandidate(
                                name: appName.isEmpty ? cleanBase : appName,
                                fullBundleIdentifier: fullWithTeam,
                                baseBundleIdentifier: cleanBase,
                                version: app.version,
                                expirationDate: app.expirationDate
                            )
                        )
                    }
                }
            }

            overwritableList.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            return InstalledAppSnapshot(
                activeAndProtectedIDsLowercased: activeAndProtectedIDs,
                overwritableCandidates: overwritableList,
                objectIDByExactNameAndBaseID: mapByNameAndBaseID,
                objectIDByActiveBundleID: mapByActiveBundleID
            )
        }
    }

    /// Hỏi Apple danh sách các App ID (tối đa 10 ID trên tài khoản Free), sau đó:
    /// - Trừ đi toàn bộ ID chính + các ID mở rộng (.appex) của các App còn sống trên máy
    /// - Trừ đi toàn bộ ID chính + các ID mở rộng (.appex) của SideStore và LC+SS (LiveContainer + SideStore)
    private func fetchReusableAppIDCandidates(
        authTeam: ALTTeam,
        teamID: String,
        excludedBaseOrFullIDsLowercased: Set<String>
    ) async -> [ReusableAppIDCandidate] {
        var portalSnapshots: [(name: String, bundleID: String, expirationDate: Date?)] = []

        if let remoteAppIDs = try? await DeveloperPortalProxy.shared.fetchAppIDs(for: authTeam) {
            self.context.sharedContext.appIDs = remoteAppIDs
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

        var seenBaseIDs = Set<String>()
        var candidates: [ReusableAppIDCandidate] = []

        for item in portalSnapshots {
            let fullID = item.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fullID.isEmpty else { continue }

            if let exp = item.expirationDate, exp <= now {
                continue
            }

            let lowerFull = fullID.lowercased()
            let shortDisplayID = Self.stripTrailingTeamID(from: fullID, teamID: teamID)
            let lowerBase = shortDisplayID.lowercased()
            let lowerItemName = Self.normalizeAppName(item.name)

            // 1. Trừ sạch ID chính và mọi ID mở rộng (.appex) của SideStore, AltStore và LC+SS (LiveContainer)
            if fullID.isAltStoreAppID || shortDisplayID.isAltStoreAppID ||
               Self.isProtectedHostOrCoreApp(
                lowerFull: lowerFull,
                appNameLower: lowerItemName,
                hostMainID: hostMainBundleID,
                teamID: teamID
               ) || Self.isProtectedHostOrCoreApp(
                lowerFull: lowerBase,
                appNameLower: lowerItemName,
                hostMainID: hostMainBundleID,
                teamID: teamID
               ) {
                continue
            }

            // 2. Trừ sạch ID chính LẪN mọi ID mở rộng (.appex) của các App còn sống trên máy
            let isUsedByActiveAppOrItsExtensions = excludedBaseOrFullIDsLowercased.contains { activeID in
                lowerFull == activeID ||
                lowerFull.hasPrefix(activeID + ".") ||
                lowerBase == activeID ||
                lowerBase.hasPrefix(activeID + ".")
            }
            if isUsedByActiveAppOrItsExtensions {
                continue
            }

            guard !seenBaseIDs.contains(lowerBase) else { continue }
            seenBaseIDs.insert(lowerBase)

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

        // Giới hạn tối đa trong phạm vi 10 ID của Apple
        if candidates.count > 10 {
            return Array(candidates.prefix(10))
        }
        return candidates
    }

    /// Nhận diện chuẩn xác SideStore, AltStore và LC+SS (LiveContainer + SideStore) cùng toàn bộ tiện ích mở rộng của chúng
    private static func isProtectedHostOrCoreApp(
        lowerFull: String,
        appNameLower: String = "",
        hostMainID: String,
        teamID: String
    ) -> Bool {
        let lowerTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerBase = Self.stripTrailingTeamID(from: lowerFull, teamID: teamID).lowercased()

        if lowerFull.isAltStoreAppID || lowerBase.isAltStoreAppID {
            return true
        }

        // 1. Bảo vệ chính ứng dụng chủ đang chạy (SideStore hoặc LC+SS) và mọi mở rộng của nó
        if !hostMainID.isEmpty {
            let hostBase = Self.stripTrailingTeamID(from: hostMainID, teamID: teamID).lowercased()
            if !hostBase.isEmpty {
                if lowerFull == hostMainID || lowerFull.hasPrefix(hostMainID + ".") ||
                   lowerBase == hostBase || lowerBase.hasPrefix(hostBase + ".") {
                    return true
                }
            }
        }

        // 2. Danh sách gốc Bundle ID của SideStore, AltStore và LiveContainer / LC+SS
        let protectedMainBases = [
            StoreApp.altstoreAppID.lowercased(),
            "com.sidestore.sidestore",
            "com.rileytestut.altstore",
            "com.kdt.livecontainer"
        ]

        for mainBase in protectedMainBases where !mainBase.isEmpty {
            if lowerFull == mainBase || lowerFull.hasPrefix(mainBase + ".") ||
               lowerBase == mainBase || lowerBase.hasPrefix(mainBase + ".") {
                return true
            }
            if !lowerTeam.isEmpty {
                let withTeam = "\(mainBase).\(lowerTeam)"
                if lowerFull == withTeam || lowerFull.hasPrefix(withTeam + ".") {
                    return true
                }
            }
        }

        // 3. Nhận diện theo từ khóa định danh trong Bundle ID hoặc Tên App của SideStore / LC+SS / LiveContainer
        let protectedTokens = [
            "sidestore",
            "altstore",
            "livecontainer",
            "lc+ss",
            "lcss"
        ]

        for token in protectedTokens {
            if lowerBase.contains(token) || appNameLower.contains(token) {
                return true
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
