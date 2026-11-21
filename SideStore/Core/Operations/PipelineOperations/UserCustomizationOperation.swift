
//
//  UserCustomizationOperation.swift
//  SideStore
//
//  Created by Magesh K on 01/03/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import SideSign
import CoreData

/// Thông tin một App ID cũ đang còn hạn trên tài khoản Apple (nhưng không thuộc về bất kỳ app hay tiện ích mở rộng nào đang sống trên máy)
public struct ReusableAppIDCandidate: Identifiable, Sendable, Equatable {
    public var id: String { fullBundleIdentifier }
    public let name: String
    /// Mã gốc không kèm đuôi TeamID (để hiển thị gọn gàng)
    public let baseBundleIdentifier: String
    /// Mã đầy đủ trên Apple Developer Portal (có đuôi .TEAMID)
    public let fullBundleIdentifier: String
    public let expirationDate: Date?

    public init(
        name: String,
        baseBundleIdentifier: String,
        fullBundleIdentifier: String,
        expirationDate: Date?
    ) {
        self.name = name
        self.baseBundleIdentifier = baseBundleIdentifier
        self.fullBundleIdentifier = fullBundleIdentifier
        self.expirationDate = expirationDate
    }
}

/// Thông tin một ứng dụng đang sống trên máy (trừ SideStore và LiveContainer+SideStore) có thể chọn để cài đè trực tiếp
public struct OverwriteAppCandidate: Identifiable, Sendable, Equatable {
    public var id: String { fullBundleIdentifier }
    public let name: String
    /// Mã gốc không kèm đuôi TeamID (để hiển thị gọn gàng)
    public let baseBundleIdentifier: String
    /// Mã đầy đủ của ứng dụng đang sống (có đuôi .TEAMID)
    public let fullBundleIdentifier: String
    public let expirationDate: Date?

    public init(
        name: String,
        baseBundleIdentifier: String,
        fullBundleIdentifier: String,
        expirationDate: Date?
    ) {
        self.name = name
        self.baseBundleIdentifier = baseBundleIdentifier
        self.fullBundleIdentifier = fullBundleIdentifier
        self.expirationDate = expirationDate
    }
}

final class UserCustomizationOperation: BasePipelineOperation<InstallAppOperationContext, Void>, @unchecked Sendable {

    override func execute(parentProgress: Progress?) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[UserCustomization] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[UserCustomization] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)
        if let error = self.context.error { throw error }

        guard let targetAppBundle = self.context.targetAppBundle else {
            throw OperationError.invalidParameters("UserCustomizationOperation: targetAppBundle is nil")
        }

        let isNewInstall = (self.context.installedApp == nil)
        let isResignActive = self.context.handler.preflightChecksHandler.isResignActive

        guard isNewInstall || isResignActive else {
            debugLog("[UserCustomization] Skipping — regular refresh/update requires no customization.")
            self.setProgress(100)
            return
        }

        let customizePlist        = UserDefaults.standard.customizeInfoPlist
        let customizeEntitlements = UserDefaults.standard.customizeEntitlements
        let customizeBundleID     = UserDefaults.standard.customizeAppId
        let customizeAppIcon      = UserDefaults.standard.customizeAppIcon
        let customizeProfile      = UserDefaults.standard.customizeProvisioningProfile

        let team = try await AuthManager.shared.getAuthenticatedTeam()
        let teamID = team.identifier
        guard !teamID.isEmpty else {
            throw OperationError.invalidParameters("UserCustomizationOperation: Team identifier is empty.")
        }

        var initialBundleID = self.context.customBundleIdentifier ?? targetAppBundle.bundleIdentifier
        initialBundleID = Self.stripTrailingTeamID(from: initialBundleID, teamID: teamID)

        if let installedAppID = self.context.installedApp?.objectID {
            let existingCustomID: String? = await self.context.dbBackgroundContext.perform {
                guard let app = try? self.context.dbBackgroundContext.existingObject(with: installedAppID) as? InstalledApp else {
                    return nil
                }
                return app.customBundleIdentifier ?? app.resignedBundleIdentifier
            }
            if let existingID = existingCustomID, !existingID.isEmpty {
                initialBundleID = Self.stripTrailingTeamID(from: existingID, teamID: teamID)
            }
        }

        var appendTeamID = self.context.appendTeamID
        if let installedAppID = self.context.installedApp?.objectID {
            let existingResigned: String? = await self.context.dbBackgroundContext.perform {
                guard let app = try? self.context.dbBackgroundContext.existingObject(with: installedAppID) as? InstalledApp else {
                    return nil
                }
                return app.resignedBundleIdentifier
            }
            if let resigned = existingResigned, !resigned.isEmpty {
                appendTeamID = resigned.lowercased().hasSuffix(".\(teamID.lowercased())")
            }
        }

        var workingMainPlist: [String: any Sendable]?
        var workingAllPlists: [String: [String: any Sendable]] = [:]

        // Load main app's Info.plist
        let mainInfoPlistURL = targetAppBundle.fileURL.appendingPathComponent("Info.plist")
        if let parser = try? InfoPlistParser(plistURL: mainInfoPlistURL) {
            workingMainPlist = parser.rawDictionary
        }

        if let installedApp = self.context.installedApp,
           let savedPlistURL = installedApp.customInfoPlistURL,
           let savedParser = try? InfoPlistParser(plistURL: savedPlistURL) {
            workingMainPlist = savedParser.rawDictionary
        }

        // Initialize map with main app
        if let mainPlist = workingMainPlist {
            workingAllPlists[targetAppBundle.bundleIdentifier] = mainPlist
        }

        // Load extensions' Info.plists
        for ext in targetAppBundle.appExtensions {
            let extPlistURL = ext.fileURL.appendingPathComponent("Info.plist")
            if let parser = try? InfoPlistParser(plistURL: extPlistURL) {
                workingAllPlists[ext.bundleIdentifier] = parser.rawDictionary
            }
        }

        // MARK: - 🛡️ CƠ CHẾ HIỆN BẢNG CHỌN APP ID THÔNG MINH & GỘP TẤT CẢ EXTENSION VÀO 1 ID CHÍNH DUY NHẤT KHI CÀI MỚI IPA
        let isSideStoreItself = targetAppBundle.isAltStoreApp || initialBundleID == StoreApp.altstoreAppID

        if isNewInstall && !isSideStoreItself {
            // Luôn bật useMainProfile = true để mọi tiện ích mở rộng bên trong IPA đều ký gộp chung vào 1 App ID chính duy nhất (Tiết kiệm tuyệt đối App ID)
            self.context.useMainProfile = true

            // Lấy danh sách ID cũ rảnh rỗi (10 ID từ Apple trừ đi ID của các app đang sống và trừ đi các ID tiện ích của các app đang sống)
            // và danh sách các app đang sống có thể cài đè (trừ SideStore và LiveContainer+SideStore)
            let (reusableCandidates, overwritableApps) = await self.fetchSmartInstallCandidates(
                for: team,
                excludingBundleID: initialBundleID
            )

            // Luôn hiện bảng chọn ID thông minh khi cài IPA mới (Trừ khi bật trình sửa Info.plist nâng cao đầy đủ)
            if !customizePlist {
                guard let result = try await self.context.handler.userCustomizationHandler.resolveBundleIDOverride(
                    initialBundleID: initialBundleID,
                    appName: targetAppBundle.name,
                    teamID: teamID,
                    reusableAppIDs: reusableCandidates,
                    overwritableApps: overwritableApps
                ) else {
                    debugLog("[UserCustomization] Smart Bundle ID picker cancelled by user.")
                    throw OperationError.cancelled
                }

                let rawCustomID = result.customID.trimmingCharacters(in: .whitespacesAndNewlines)
                let chosenID = rawCustomID.isEmpty ? initialBundleID : rawCustomID
                appendTeamID = result.appendTeamID
                self.context.appendTeamID = appendTeamID

                // Nếu người dùng bấm chọn 1 ứng dụng trong mục "Cài đè lên app" (hoặc nhập đúng ID của app đang sống đó),
                // gán context.installedApp vào đúng ứng dụng đang sống đó để thực hiện cài đè chuẩn xác!
                await self.bindActiveInstalledAppForOverwriteIfNeeded(chosenBundleID: chosenID, teamID: teamID)

                let finalEffectiveID = Self.computeEffectiveBundleID(from: chosenID, teamID: teamID, appendTeamID: appendTeamID)

                var basePlist = workingMainPlist ?? [:]
                basePlist[kCFBundleIdentifierKey as String] = finalEffectiveID
                workingMainPlist = basePlist
                workingAllPlists[targetAppBundle.bundleIdentifier] = basePlist
                initialBundleID = Self.stripTrailingTeamID(from: chosenID, teamID: teamID)

                debugLog("[UserCustomization] Smart Bundle ID chosen -> raw='\(chosenID)', effective='\(finalEffectiveID)', appendTeamID=\(appendTeamID), overwriteApp=\(String(describing: self.context.installedApp?.name))")
            }
        } else if customizeBundleID && !customizePlist {
            guard let result = try await self.context.handler.userCustomizationHandler.resolveBundleIDOverride(
                initialBundleID: initialBundleID
            ) else {
                debugLog("[UserCustomization] Bundle ID override cancelled by user.")
                throw OperationError.cancelled
            }

            let rawCustomID = result.customID.trimmingCharacters(in: .whitespacesAndNewlines)
            let chosenID = rawCustomID.isEmpty ? initialBundleID : rawCustomID
            appendTeamID = result.appendTeamID
            self.context.appendTeamID = appendTeamID

            let finalEffectiveID = Self.computeEffectiveBundleID(from: chosenID, teamID: teamID, appendTeamID: appendTeamID)

            var basePlist = workingMainPlist ?? [:]
            basePlist[kCFBundleIdentifierKey as String] = finalEffectiveID
            workingMainPlist = basePlist
            workingAllPlists[targetAppBundle.bundleIdentifier] = basePlist
            initialBundleID = Self.stripTrailingTeamID(from: chosenID, teamID: teamID)

            debugLog("[UserCustomization] Bundle ID override -> '\(finalEffectiveID)' (appendTeamID: \(appendTeamID))")
        }
        self.setProgress(25)

        if customizePlist {
            var targets: [InfoPlistTarget] = []
            
            // Main App Target
            if let mainPlist = workingMainPlist {
                targets.append(InfoPlistTarget(
                    id: targetAppBundle.bundleIdentifier,
                    name: targetAppBundle.name,
                    isExtension: false,
                    initialPlist: mainPlist
                ))
            }
            
            // Extension Targets
            for ext in targetAppBundle.appExtensions {
                if let extPlist = workingAllPlists[ext.bundleIdentifier] {
                    targets.append(InfoPlistTarget(
                        id: ext.bundleIdentifier,
                        name: ext.name,
                        isExtension: true,
                        initialPlist: extPlist
                    ))
                }
            }

            let currentInstalledAppID = self.context.installedApp?.objectID
            let installedAppIdentities: [String: String] = await self.context.dbBackgroundContext.perform {
                let apps = InstalledApp.fetchActiveApps(in: self.context.dbBackgroundContext)
                var mapping: [String: String] = [:]
                for app in apps {
                    if let currentID = currentInstalledAppID, app.objectID == currentID {
                        continue
                    }
                    let bID = Self.stripTrailingTeamID(from: app.bundleIdentifier, teamID: teamID).lowercased()
                    mapping[bID] = app.name
                    mapping[app.bundleIdentifier] = app.name
                    if let cID = app.customBundleIdentifier {
                        let strippedCID = Self.stripTrailingTeamID(from: cID, teamID: teamID).lowercased()
                        mapping[strippedCID] = app.name
                        mapping[cID] = app.name
                    }
                    let rID = Self.stripTrailingTeamID(from: app.resignedBundleIdentifier, teamID: teamID).lowercased()
                    mapping[rID] = app.name
                    mapping[app.resignedBundleIdentifier] = app.name
                }
                return mapping
            }

            guard let result = try await self.context.handler.userCustomizationHandler.resolveInfoPlistCustomization(
                targets: targets,
                initialBundleID: initialBundleID,
                appendTeamID: appendTeamID,
                installedAppIdentities: installedAppIdentities,
                teamID: teamID
            ) else {
                debugLog("[UserCustomization] Info.plist customization cancelled by user.")
                throw OperationError.cancelled
            }

            appendTeamID = result.appendTeamID
            self.context.appendTeamID = appendTeamID
            workingAllPlists = result.modifiedPlists
            workingMainPlist = workingAllPlists[targetAppBundle.bundleIdentifier]

            // Nếu trong trình sửa Info.plist người dùng chọn/nhập đúng ID của một app đang sống khi cài mới, tự động liên kết để cài đè
            if isNewInstall && !isSideStoreItself,
               let editedMainID = workingMainPlist?[kCFBundleIdentifierKey as String] as? String {
                await self.bindActiveInstalledAppForOverwriteIfNeeded(chosenBundleID: editedMainID, teamID: teamID)
            }

            debugLog("[UserCustomization] Multi-target Info.plist customization applied (\(workingAllPlists.count) target(s)).")
        }
        self.setProgress(50)

        try self.applyInfoPlistOverrides(
            workingAllPlists: workingAllPlists,
            to: targetAppBundle,
            teamID: teamID,
            appendTeamID: appendTeamID
        )
        self.setProgress(65)

        if customizeAppIcon {
            if let customIconURL = try await self.context.handler.userCustomizationHandler.resolveAppIconCustomization(appName: targetAppBundle.name) {
                self.context.alternateIconMode = .set(customIconURL)
                debugLog("[UserCustomization] Custom app icon selected: \(customIconURL.lastPathComponent)")
            }
        }
        self.setProgress(75)

        if customizeProfile {
            let effectiveMainID = self.context.targetBundleIdentifier
            guard let choice = try await self.context.handler.userCustomizationHandler.resolveProvisioningProfileCustomization(
                appName: targetAppBundle.name,
                bundleID: effectiveMainID
            ) else {
                debugLog("[UserCustomization] Provisioning profile selection cancelled by user.")
                throw OperationError.cancelled
            }

            switch choice {
            case .defaultProfile:
                self.context.overrideProvisioningProfile = nil
            case .profile(let selectedProfile):
                self.context.overrideProvisioningProfile = selectedProfile
                debugLog("[UserCustomization] Custom provisioning profile selected: \(selectedProfile.name) (\(selectedProfile.uuid))")
            }
        }
        self.setProgress(85)

        if customizeEntitlements {
            var entitlementTargets: [EntitlementsTarget] = []
            
            var mainEnts: [String: any Sendable] = [:]
            for (k, v) in targetAppBundle.entitlements {
                mainEnts[k.rawValue] = v
            }
            if let installedApp = self.context.installedApp,
               let savedEnts = installedApp.customEntitlements {
                mainEnts = savedEnts
            }
            entitlementTargets.append(EntitlementsTarget(
                id: targetAppBundle.bundleIdentifier,
                name: targetAppBundle.name,
                isExtension: false,
                initialEntitlements: mainEnts
            ))
            
            for ext in targetAppBundle.appExtensions {
                var extEnts: [String: any Sendable] = [:]
                for (k, v) in ext.entitlements {
                    extEnts[k.rawValue] = v
                }
                entitlementTargets.append(EntitlementsTarget(
                    id: ext.bundleIdentifier,
                    name: ext.name,
                    isExtension: true,
                    initialEntitlements: extEnts
                ))
            }

            guard let modifiedEntitlementsMap = try await self.context.handler.userCustomizationHandler.resolveEntitlementsCustomization(
                targets: entitlementTargets,
                teamType: team.type
            ) else {
                debugLog("[UserCustomization] Entitlements customization cancelled by user.")
                throw OperationError.cancelled
            }

            self.context.customEntitlementsByBundleID = modifiedEntitlementsMap
            debugLog("[UserCustomization] Entitlements customization applied for \(modifiedEntitlementsMap.count) target(s).")
        }

        self.setProgress(100)
    }

    // MARK: - 🔍 LỌC DANH SÁCH ID CŨ RẢNH RỖI & DANH SÁCH CÁC APP ĐANG SỐNG ĐỂ CÀI ĐÈ
    /// - `reusableAppIDs`: Lấy danh sách 10 ID từ Apple Developer Portal, trừ đi ID chính của các app đang sống VÀ trừ đi tất cả ID tiện ích mở rộng của các app đang sống (kèm loại trừ SideStore / LC+SS).
    /// - `overwritableApps`: Lấy danh sách các app đang sống trên máy (trừ SideStore và LiveContainer+SideStore / `lc+ss`) để hiển thị ở mục "Cài đè lên app".
    private func fetchSmartInstallCandidates(
        for team: ALTTeam,
        excludingBundleID: String
    ) async -> (reusable: [ReusableAppIDCandidate], overwritable: [OverwriteAppCandidate]) {
        let teamID = team.identifier
        let cleanInitialBase = Self.stripTrailingTeamID(from: excludingBundleID, teamID: teamID).lowercased()

        // 1. Lấy danh sách App ID trực tiếp từ Apple Developer Portal (hoặc bộ nhớ đệm sharedContext)
        let portalAppIDs: [ALTAppID] = await {
            do {
                return try await TaskChainCoalescer.shared.coalesce(key: "fetch_app_ids_\(teamID)") {
                    if let cached = self.context.sharedContext.appIDs {
                        return cached
                    }
                    let fetched = try await DeveloperPortalProxy.shared.fetchAppIDs(for: team)
                    self.context.sharedContext.appIDs = fetched
                    return fetched
                }
            } catch {
                self.debugLog("[UserCustomization] Failed to fetch portal App IDs, falling back to local DB: \(error.localizedDescription)")
                return self.context.sharedContext.appIDs ?? []
            }
        }()

        // 2. Truy vấn CoreData để lấy các app đang sống, các tiện ích mở rộng của app đang sống, và ngày hết hạn AppID
        return await self.context.dbBackgroundContext.perform {
            let ctx = self.context.dbBackgroundContext
            let activeApps = InstalledApp.fetchActiveApps(in: ctx)
            let localDBAppIDs = AppID.all(in: ctx)
            let now = Date()

            // Map lưu ngày hết hạn và tên từ bảng AppID trong CoreData (nếu có)
            var dbExpirationByFullID: [String: Date] = [:]
            var dbNameByFullID: [String: String] = [:]
            for dbItem in localDBAppIDs {
                let key = dbItem.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if let exp = dbItem.expirationDate {
                    dbExpirationByFullID[key] = exp
                }
                let trimmedName = dbItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedName.isEmpty {
                    dbNameByFullID[key] = trimmedName
                }
            }

            // Tập hợp tất cả các ID đang bận của ứng dụng đang sống + toàn bộ tiện ích mở rộng của ứng dụng đang sống
            var activeFullIDs = Set<String>()
            var activeBaseIDs = Set<String>()
            var overwritableApps: [OverwriteAppCandidate] = []
            var seenOverwriteFullIDs = Set<String>()

            for app in activeApps {
                let resigned = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let orig = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let custom = app.customBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                for raw in [resigned, orig, custom] where !raw.isEmpty {
                    let lowerFull = raw.lowercased()
                    let lowerBase = Self.stripTrailingTeamID(from: raw, teamID: teamID).lowercased()
                    activeFullIDs.insert(lowerFull)
                    activeBaseIDs.insert(lowerBase)
                    activeFullIDs.insert("\(lowerBase).\(teamID.lowercased())")
                }

                // Thu thập toàn bộ các tiện ích mở rộng (InstalledExtension) của ứng dụng đang sống này
                for ext in app.appExtensions {
                    let extResigned = ext.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                    let extOrig = ext.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                    let extCustom = ext.customBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                    for extRaw in [extResigned, extOrig, extCustom] where !extRaw.isEmpty {
                        let lowerExtFull = extRaw.lowercased()
                        let lowerExtBase = Self.stripTrailingTeamID(from: extRaw, teamID: teamID).lowercased()
                        activeFullIDs.insert(lowerExtFull)
                        activeBaseIDs.insert(lowerExtBase)
                        activeFullIDs.insert("\(lowerExtBase).\(teamID.lowercased())")
                    }
                }

                // Kiểm tra nếu app đang sống này KHÔNG phải SideStore và KHÔNG phải LiveContainer+SideStore (LC+SS)
                // thì đưa vào danh sách "Cài đè lên app"
                let effectiveFull = !resigned.isEmpty ? resigned : (!custom.isEmpty ? custom : orig)
                let effectiveBase = Self.stripTrailingTeamID(from: effectiveFull, teamID: teamID)
                let fullWithTeam = Self.computeEffectiveBundleID(from: effectiveFull, teamID: teamID, appendTeamID: true)

                if !Self.isProtectedSystemOrHostApp(
                    name: app.name,
                    baseBundleID: effectiveBase,
                    fullBundleID: fullWithTeam,
                    originalBundleID: orig
                ) {
                    let dedupKey = fullWithTeam.lowercased()
                    if seenOverwriteFullIDs.insert(dedupKey).inserted {
                        let displayName = app.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? effectiveBase
                            : app.name
                        overwritableApps.append(
                            OverwriteAppCandidate(
                                name: displayName,
                                baseBundleIdentifier: effectiveBase,
                                fullBundleIdentifier: fullWithTeam,
                                expirationDate: app.expirationDate
                            )
                        )
                    }
                }
            }

            // Sắp xếp danh sách "Cài đè lên app" theo tên dễ nhìn
            overwritableApps.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

            // Chuẩn bị nguồn dữ liệu 10 App ID từ Apple Portal (kết hợp DB cục bộ nếu offline)
            struct RawPortalAppID {
                let name: String
                let fullBundleID: String
                let expirationDate: Date?
            }

            var combinedPortalList: [RawPortalAppID] = []
            var seenPortalKeys = Set<String>()

            for portalID in portalAppIDs {
                let full = portalID.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !full.isEmpty else { continue }
                let lower = full.lowercased()
                guard seenPortalKeys.insert(lower).inserted else { continue }
                let exp = dbExpirationByFullID[lower]
                let resolvedName = dbNameByFullID[lower] ?? portalID.name
                combinedPortalList.append(
                    RawPortalAppID(
                        name: resolvedName,
                        fullBundleID: full,
                        expirationDate: exp
                    )
                )
            }

            // Bổ sung từ bảng AppID trong CoreData nếu có mục nào chưa nằm trong kết quả trả về
            for dbItem in localDBAppIDs {
                if let itemTeamID = dbItem.team?.identifier, !itemTeamID.isEmpty,
                   itemTeamID.caseInsensitiveCompare(teamID) != .orderedSame {
                    continue
                }
                let full = dbItem.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !full.isEmpty else { continue }
                let lower = full.lowercased()
                guard seenPortalKeys.insert(lower).inserted else { continue }
                combinedPortalList.append(
                    RawPortalAppID(
                        name: dbItem.name,
                        fullBundleID: full,
                        expirationDate: dbItem.expirationDate
                    )
                )
            }

            // Lọc ra danh sách ID cũ rảnh rỗi:
            // Lấy 10 ID từ Apple TRỪ ĐI:
            // 1. ID chính của các ứng dụng đang sống
            // 2. Tất cả các ID tiện ích mở rộng của các ứng dụng đang sống (bao gồm cả khớp trực tiếp và tiền tố <activeAppID>.)
            // 3. SideStore và LiveContainer+SideStore (LC+SS)
            var reusableCandidates: [ReusableAppIDCandidate] = []
            var seenReusableBaseIDs = Set<String>()

            for rawItem in combinedPortalList {
                // Nếu có ngày hết hạn trong DB và đã hết hạn thì bỏ qua
                if let exp = rawItem.expirationDate, exp <= now {
                    continue
                }

                let fullID = rawItem.fullBundleID
                let lowerFullID = fullID.lowercased()
                let baseID = Self.stripTrailingTeamID(from: fullID, teamID: teamID)
                let lowerBaseID = baseID.lowercased()
                guard !lowerBaseID.isEmpty else { continue }

                // Loại trừ SideStore và LiveContainer+SideStore
                if Self.isProtectedSystemOrHostApp(
                    name: rawItem.name,
                    baseBundleID: baseID,
                    fullBundleID: fullID,
                    originalBundleID: baseID
                ) {
                    continue
                }

                // Loại trừ nếu trùng với ID gốc của IPA đang cài
                if lowerBaseID == cleanInitialBase {
                    continue
                }

                // 1. Loại trừ nếu trùng với ID chính hoặc ID tiện ích của bất kỳ ứng dụng nào đang sống
                if activeFullIDs.contains(lowerFullID) || activeBaseIDs.contains(lowerBaseID) {
                    continue
                }

                // 2. Loại trừ mọi ID tiện ích mở rộng trên Apple Portal thuộc về bất kỳ ứng dụng nào đang sống
                let isExtensionOfActiveApp = activeFullIDs.contains { activeFull in
                    lowerFullID.hasPrefix(activeFull + ".")
                } || activeBaseIDs.contains { activeBase in
                    lowerBaseID.hasPrefix(activeBase + ".") || lowerFullID.hasPrefix(activeBase + ".")
                }

                if isExtensionOfActiveApp {
                    continue
                }

                guard seenReusableBaseIDs.insert(lowerBaseID).inserted else { continue }

                let cleanName = rawItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
                reusableCandidates.append(
                    ReusableAppIDCandidate(
                        name: cleanName.isEmpty ? baseID : cleanName,
                        baseBundleIdentifier: baseID,
                        fullBundleIdentifier: fullID,
                        expirationDate: rawItem.expirationDate
                    )
                )
            }

            // Sắp xếp ưu tiên các ID còn hạn lâu nhất lên đầu
            reusableCandidates.sort { lhs, rhs in
                switch (lhs.expirationDate, rhs.expirationDate) {
                case let (lDate?, rDate?):
                    if lDate != rDate { return lDate > rDate }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                case (_?, nil):
                    return true
                case (nil, _?):
                    return false
                case (nil, nil):
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
            }

            return (reusableCandidates, overwritableApps)
        }
    }

    /// Kiểm tra xem một ứng dụng/App ID có phải là SideStore hoặc LiveContainer+SideStore (`lc+ss`) cần được bảo vệ không cho cài đè / dùng lại hay không
    private static func isProtectedSystemOrHostApp(
        name: String,
        baseBundleID: String,
        fullBundleID: String,
        originalBundleID: String
    ) -> Bool {
        let lowerName = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerBase = baseBundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerFull = fullBundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let lowerOrig = originalBundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let altStoreID = StoreApp.altstoreAppID.lowercased()
        if let mainBundleID = Bundle.main.bundleIdentifier?.lowercased() {
            let strippedMain = mainBundleID.components(separatedBy: ".").dropLast().joined(separator: ".")
            if lowerBase == mainBundleID || lowerFull == mainBundleID || lowerOrig == mainBundleID || (!strippedMain.isEmpty && lowerBase == strippedMain) {
                return true
            }
        }

        // Bảo vệ SideStore / AltStore và các tiện ích của nó
        if lowerBase == altStoreID ||
           lowerOrig == altStoreID ||
           lowerBase.hasPrefix(altStoreID + ".") ||
           lowerFull.hasPrefix(altStoreID + ".") ||
           lowerBase.contains("com.sidestore.sidestore") ||
           lowerName == "sidestore" ||
           lowerName == "altstore" {
            return true
        }

        // Bảo vệ LiveContainer+SideStore (LC+SS)
        if lowerName.contains("livecontainer") ||
           lowerName.contains("lc+ss") ||
           lowerBase.contains("livecontainer") ||
           lowerFull.contains("livecontainer") ||
           lowerOrig.contains("livecontainer") {
            return true
        }

        return false
    }

    /// Nếu người dùng chọn 1 ứng dụng đang sống trong mục "Cài đè lên app", tự động liên kết `self.context.installedApp` vào đúng ứng dụng đó
    private func bindActiveInstalledAppForOverwriteIfNeeded(chosenBundleID: String, teamID: String) async {
        let trimmed = chosenBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let strippedChosen = Self.stripTrailingTeamID(from: trimmed, teamID: teamID).lowercased()
        let fullChosenWithTeam = Self.computeEffectiveBundleID(from: trimmed, teamID: teamID, appendTeamID: true).lowercased()
        let lowerTrimmed = trimmed.lowercased()

        let matchedAppID: NSManagedObjectID? = await self.context.dbBackgroundContext.perform {
            let activeApps = InstalledApp.fetchActiveApps(in: self.context.dbBackgroundContext)
            for app in activeApps {
                let resigned = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let custom = app.customBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let orig = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)

                let baseResigned = Self.stripTrailingTeamID(from: resigned, teamID: teamID)
                let fullResigned = Self.computeEffectiveBundleID(from: resigned, teamID: teamID, appendTeamID: true)

                // Không bao giờ tự động đè lên SideStore hoặc LiveContainer+SideStore
                if Self.isProtectedSystemOrHostApp(
                    name: app.name,
                    baseBundleID: baseResigned,
                    fullBundleID: fullResigned,
                    originalBundleID: orig
                ) {
                    continue
                }

                let candidates = [resigned, custom, orig].filter { !$0.isEmpty }
                let matches = candidates.contains { candidate in
                    let lowerCand = candidate.lowercased()
                    let lowerCandBase = Self.stripTrailingTeamID(from: candidate, teamID: teamID).lowercased()
                    let lowerCandFull = Self.computeEffectiveBundleID(from: candidate, teamID: teamID, appendTeamID: true).lowercased()
                    return lowerCand == lowerTrimmed ||
                           lowerCand == fullChosenWithTeam ||
                           lowerCandBase == strippedChosen ||
                           lowerCandFull == fullChosenWithTeam
                }

                if matches {
                    return app.objectID
                }
            }
            return nil
        }

        if let matchedAppID {
            let resolvedApp: InstalledApp? = await self.context.dbBackgroundContext.perform {
                try? self.context.dbBackgroundContext.existingObject(with: matchedAppID) as? InstalledApp
            }
            if let resolvedApp {
                self.context.installedApp = resolvedApp
                self.debugLog("[UserCustomization] Bound context.installedApp to active app '\(resolvedApp.name)' (\(resolvedApp.resignedBundleIdentifier)) for direct overwrite.")
            }
        }
    }

    private func applyInfoPlistOverrides(
        workingAllPlists: [String: [String: any Sendable]],
        to targetAppBundle: ALTApplication,
        teamID: String,
        appendTeamID: Bool
    ) throws {
        let oldMainBundleID = targetAppBundle.bundleIdentifier
        guard var mainModifiedPlist = workingAllPlists[oldMainBundleID] else { return }

        let parser = InfoPlistParser(dictionary: mainModifiedPlist)
        let rawEditedID = parser.bundleIdentifier ?? oldMainBundleID
        let cleanBaseID = Self.stripTrailingTeamID(from: rawEditedID, teamID: teamID)
        let sanitizedBase = InfoPlistParser.sanitizeBundleID(cleanBaseID)
        let resolvedBaseID = sanitizedBase.isEmpty ? cleanBaseID : sanitizedBase
        let effectiveBundleID = Self.computeEffectiveBundleID(from: resolvedBaseID, teamID: teamID, appendTeamID: appendTeamID)

        let isNewInstall = (self.context.installedApp == nil)
        let oldBaseBundleID = Self.stripTrailingTeamID(from: oldMainBundleID, teamID: teamID)
        let baseBundleIDChanged = (resolvedBaseID != oldBaseBundleID)

        // Gán resolvedBaseID vào customBundleIdentifier khi ID thay đổi hoặc khi đang cài đè/gia hạn
        if baseBundleIDChanged || !isNewInstall {
            self.context.customBundleIdentifier = resolvedBaseID
        }

        // Đặt CFBundleIdentifier = resolvedBaseID trong Info.plist tùy chỉnh để PatchInfoPlistOperation và PrepareAppExtensionBundleIDsOperation xử lý đồng nhất với phần còn lại của pipeline
        mainModifiedPlist[kCFBundleIdentifierKey as String] = resolvedBaseID

        // Nếu cài đặt mới như một bản nhân bản (Bundle ID khác gốc), tự động thêm dấu "+" vào tên hiển thị (nếu chưa có)
        if isNewInstall && baseBundleIDChanged {
            let currentDisplayName = (mainModifiedPlist["CFBundleDisplayName"] as? String)
                ?? (mainModifiedPlist[kCFBundleNameKey as String] as? String)
                ?? targetAppBundle.name
            if !currentDisplayName.hasSuffix("+") {
                let updatedName = currentDisplayName + "+"
                mainModifiedPlist["CFBundleDisplayName"] = updatedName
                mainModifiedPlist[kCFBundleNameKey as String] = updatedName
                debugLog("[UserCustomization] Appended '+' to display name for custom bundle ID install: '\(updatedName)'")
            }
        }

        var updatedMap = workingAllPlists
        updatedMap[oldMainBundleID] = mainModifiedPlist

        // Đồng bộ tiền tố Bundle ID cho toàn bộ App Extensions trong customInfoPlistByBundleID nếu người dùng đổi sang ID khác
        for ext in targetAppBundle.appExtensions {
            let extOrigID = ext.bundleIdentifier
            guard var extMod = updatedMap[extOrigID] else { continue }
            let extEditedID = (extMod[kCFBundleIdentifierKey as String] as? String) ?? extOrigID
            let cleanExtID = Self.stripTrailingTeamID(from: extEditedID, teamID: teamID)

            if cleanExtID.hasPrefix(oldBaseBundleID + ".") {
                let suffix = String(cleanExtID.dropFirst(oldBaseBundleID.count))
                extMod[kCFBundleIdentifierKey as String] = resolvedBaseID + suffix
            } else if extOrigID.hasPrefix(oldMainBundleID + ".") {
                let suffix = String(extOrigID.dropFirst(oldMainBundleID.count))
                extMod[kCFBundleIdentifierKey as String] = resolvedBaseID + suffix
            }
            updatedMap[extOrigID] = extMod
        }

        self.context.customInfoPlistByBundleID = updatedMap
        debugLog("[UserCustomization] Prepared customInfoPlistByBundleID — base='\(resolvedBaseID)', effective='\(effectiveBundleID)', targets=\(updatedMap.count)")
    }

    static func stripTrailingTeamID(from bundleID: String, teamID: String) -> String {
        guard !teamID.isEmpty else { return bundleID }
        let suffix = ".\(teamID)"
        var result = bundleID
        while result.lowercased().hasSuffix(suffix.lowercased()) {
            result = String(result.dropLast(suffix.count))
        }
        return result
    }

    static func computeEffectiveBundleID(from rawBundleID: String, teamID: String, appendTeamID: Bool) -> String {
        let stripped = stripTrailingTeamID(from: rawBundleID.trimmingCharacters(in: .whitespacesAndNewlines), teamID: teamID)
        let sanitized = InfoPlistParser.sanitizeBundleID(stripped)
        let base = sanitized.isEmpty ? stripped : sanitized
        if appendTeamID && !teamID.isEmpty {
            return "\(base).\(teamID)"
        }
        return base
    }
}
