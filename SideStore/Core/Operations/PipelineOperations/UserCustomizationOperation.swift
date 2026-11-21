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

    private static let appIDNameHistoryDefaultsKey = "SideStore.ReusableAppIDNameHistory.v1"

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

        // 1. Quét danh sách App (cả đang Active lẫn Inactive) và Extension trong Database
        let installedSnap = fetchInstalledAppSnapshots(teamID: teamID)

        // =========================================================================
        // THUẬT TOÁN NHẬN DIỆN THÔNG MINH (CHỐNG CÀI ĐÈ NHẦM KHI KHÁC TÊN APP HOẶC APP INACTIVE)
        // =========================================================================
        if !context.isStoreUpdate {
            // BƯỚC 1A: Kiểm tra lại context.installedApp (nếu bước Preflight trước đó đã gán sẵn do trùng ID)
            if let preMatchedApp = context.installedApp {
                let isSameActiveAppIdentity: Bool = context.dbBackgroundContext.performAndWait {
                    guard preMatchedApp.isActive else { return false }
                    let existingName = preMatchedApp.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    return !incomingNameLower.isEmpty && existingName == incomingNameLower
                }

                if !isSameActiveAppIdentity {
                    debugLog("[UserCustomizationOperation] Blocked auto-overwrite: Incoming IPA '\(targetAppBundle.name)' differs in name or target app is inactive. Forcing prompt!")
                    context.installedApp = nil
                    context.customBundleIdentifier = nil
                }
            }

            // BƯỚC 1B: Nếu context.installedApp đang nil, chỉ tự động khớp với App ĐANG HOẠT ĐỘNG (isActive == true)
            // khi khớp chính xác cả Tên + ID gốc, hoặc Tên duy nhất (nếu cùng dòng app đã mượn ID cũ).
            if context.installedApp == nil, !incomingNameLower.isEmpty {
                let matchedObjectID = installedSnap.objectIDByExactNameAndBaseID["\(incomingNameLower)|\(incomingOrigBaseLower)"]
                    ?? installedSnap.objectIDByUniqueAppName[incomingNameLower]

                if let matchedObjectID {
                    context.dbBackgroundContext.performAndWait {
                        if let matchedApp = try? context.dbBackgroundContext.existingObject(with: matchedObjectID) as? InstalledApp,
                           matchedApp.isActive {
                            self.context.installedApp = matchedApp
                        }
                    }
                }
            }
        }

        // 2. NẾU LÀ CẬP NHẬT THẬT SỰ (Bấm Update từ Store HOẶC cài IPA mới của đúng App đang Active trên máy):
        if context.isStoreUpdate || context.installedApp != nil {
            let existingResignedID: String? = context.dbBackgroundContext.performAndWait {
                if let custom = self.context.installedApp?.customBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !custom.isEmpty {
                    return custom
                }
                return self.context.installedApp?.resignedBundleIdentifier
            }
            if let trimmedResigned = existingResignedID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !trimmedResigned.isEmpty {
                let finalWithTeam = Self.ensureTrailingTeamID(for: trimmedResigned, teamID: teamID)
                context.customBundleIdentifier = finalWithTeam
                context.appendTeamID = false

                Self.recordAppIDDisplayName(
                    appName: targetAppBundle.name,
                    fullBundleID: finalWithTeam,
                    teamID: teamID
                )
            }
            debugLog("[UserCustomizationOperation] Genuine existing app update detected ('\(targetAppBundle.name)'); keeping existing ID and skipping prompt.")
            self.setProgress(100)
            return context.customBundleIdentifier != nil ? context.targetBundleIdentifier : nil
        }

        // 3. NẾU LÀ APP MỚI (HOẶC APP KHÁC TÊN / ĐANG TẮT):
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
            let finalChosenWithTeam = "\(resolvedBaseID).\(teamID)"
            context.appendTeamID = false
            context.customBundleIdentifier = finalChosenWithTeam
            didCustomizeBundleID = true

            Self.recordAppIDDisplayName(
                appName: targetAppBundle.name,
                fullBundleID: finalChosenWithTeam,
                teamID: teamID
            )

            for (targetID, plist) in result.modifiedPlists {
                let key = (targetID == initialBundleID) ? context.targetBundleIdentifier : targetID
                context.customInfoPlistByBundleID[key] = plist
            }

            // Hậu kiểm: Chỉ gán installedApp (để ghi đè) nếu ID cuối cùng người dùng chốt trùng với một app đang có trong DB
            syncInstalledAppWithFinalChosenBundleID(teamID: teamID, installedSnap: installedSnap)
        } else {
            self.setProgress(35)
            let reusableCandidates = await fetchReusableAppIDCandidates(
                authTeam: authTeam,
                teamID: teamID,
                excludedOriginalBundleID: trueOriginalBundleID,
                installedSnap: installedSnap
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

                Self.recordAppIDDisplayName(
                    appName: targetAppBundle.name,
                    fullBundleID: matchedCandidate.fullBundleIdentifier,
                    teamID: teamID
                )
            } else {
                // KHI DÙNG ID GỐC CỦA IPA HOẶC TỰ GÕ ID MỚI:
                // Luôn lưu đầy đủ cả hậu tố TeamID vào customBundleIdentifier ngay từ lần cài đầu tiên
                // để khi bấm Làm mới (Refresh) không bao giờ bị lệch/thiếu TeamID!
                let cleanCustomID = Self.stripTrailingTeamID(
                    from: chosenRawID.isEmpty ? initialBundleID : chosenRawID,
                    teamID: teamID
                )
                let finalChosenWithTeam = "\(cleanCustomID).\(teamID)"
                context.appendTeamID = false
                context.customBundleIdentifier = finalChosenWithTeam
                didCustomizeBundleID = true

                Self.recordAppIDDisplayName(
                    appName: targetAppBundle.name,
                    fullBundleID: finalChosenWithTeam,
                    teamID: teamID
                )
            }

            // Hậu kiểm: Sau khi người dùng đã được hỏi và tự tay chốt ID trên bảng chọn:
            // - Nếu họ chọn 1 ID mới/ID cũ đang rảnh -> context.installedApp = nil (Cài thành App mới độc lập!)
            // - Nếu họ cố tình nhập/chọn đúng cái ID đang thuộc về 1 App đã có trong DB -> Gán installedApp để cập nhật đúng slot đó.
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
    /// còn nếu cố tình chọn trùng ID với một app đang có trong DB thì cập nhật đúng vào slot đó.
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
        /// Toàn bộ ID (bundleIdentifier, customBundleIdentifier, resignedBundleIdentifier) của mọi App (cả Active & Inactive)
        let activeMainIDsLowercased: Set<String>
        /// Toàn bộ Base ID (đã cắt TeamID) của mọi App (cả Active & Inactive) -> dùng để chặn cả các .appex của chúng
        let activeBaseMainIDsLowercased: Set<String>
        /// Toàn bộ ID của các tiện ích mở rộng (.appex) đã biết trong Database
        let knownExtensionIDsLowercased: Set<String>
        /// Khóa kép "tên_app|base_id" của các App ĐANG HOẠT ĐỘNG (isActive == true)
        let objectIDByExactNameAndBaseID: [String: NSManagedObjectID]
        /// Tên App duy nhất (chỉ xét các App isActive == true và chỉ khi ID gốc cũng khớp dòng hoặc mượn ID cũ)
        let objectIDByUniqueAppName: [String: NSManagedObjectID]
        /// Bản đồ ID thực tế -> ObjectID (dùng cho bước Hậu kiểm sau khi người dùng đã tự tay chọn trên bảng hỏi)
        let objectIDByActiveBundleID: [String: NSManagedObjectID]
        /// Bản đồ lưu lịch sử Tên hiển thị đẹp theo ID
        let knownDisplayNamesByLowerID: [String: String]
    }

    private func fetchInstalledAppSnapshots(teamID: String) -> InstalledAppSnapshot {
        context.dbBackgroundContext.performAndWait {
            let request = InstalledApp.fetchRequest()
            let installedApps = (try? context.dbBackgroundContext.fetch(request)) ?? []

            let extRequest = InstalledAppExtension.fetchRequest()
            let installedExtensions = (try? context.dbBackgroundContext.fetch(extRequest)) ?? []

            var activeMainIDs = Set<String>()
            var activeBaseMainIDs = Set<String>()
            var knownExtensionIDs = Set<String>()
            var mapByNameAndBaseID: [String: NSManagedObjectID] = [:]
            var mapByUniqueName: [String: NSManagedObjectID] = [:]
            var duplicatedNames = Set<String>()
            var mapByActiveBundleID: [String: NSManagedObjectID] = [:]
            var displayNamesByLowerID = Self.loadSavedAppIDNameHistory()

            let hostMainBundleID = (Bundle.main.bundleIdentifier ?? "").lowercased()
            let lowerTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

            // Bảo vệ ứng dụng chủ SideStore đang chạy
            if !hostMainBundleID.isEmpty {
                activeMainIDs.insert(hostMainBundleID)
                let hostBase = Self.stripTrailingTeamID(from: hostMainBundleID, teamID: teamID).lowercased()
                activeBaseMainIDs.insert(hostBase)
                if !lowerTeam.isEmpty && !hostMainBundleID.hasSuffix(".\(lowerTeam)") {
                    activeMainIDs.insert("\(hostMainBundleID).\(lowerTeam)")
                }
            }

            // Ghi nhận toàn bộ Extension (.appex) từng lưu trong CoreData
            for ext in installedExtensions {
                let rawExt = ext.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let resignedExt = ext.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                for extID in [rawExt, resignedExt] where !extID.isEmpty {
                    knownExtensionIDs.insert(extID)
                    let baseExt = Self.stripTrailingTeamID(from: extID, teamID: teamID).lowercased()
                    knownExtensionIDs.insert(baseExt)
                    if !lowerTeam.isEmpty {
                        knownExtensionIDs.insert("\(baseExt).\(lowerTeam)")
                    }
                }
            }

            for app in installedApps {
                let rawID = app.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let customID = (app.customBundleIdentifier ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let resignedID = app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanAppName = app.name.trimmingCharacters(in: .whitespacesAndNewlines)
                let nameKey = cleanAppName.lowercased()

                let isHostApp = Self.isProtectedHostOrCoreApp(
                    lowerFull: rawID.lowercased(),
                    hostMainID: hostMainBundleID,
                    teamID: teamID
                )

                // Ghi nhận luôn các appExtensions gắn trực tiếp với app này
                for ext in app.appExtensions {
                    let eRaw = ext.bundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    let eRes = ext.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    for extID in [eRaw, eRes] where !extID.isEmpty {
                        knownExtensionIDs.insert(extID)
                        let baseExt = Self.stripTrailingTeamID(from: extID, teamID: teamID).lowercased()
                        knownExtensionIDs.insert(baseExt)
                    }
                }

                // Gom đủ cả 3 trường ID của cả App đang hoạt động lẫn App Không hoạt động (Deactivated/Inactive)
                // để TUYỆT ĐỐI KHÔNG BAO GIỜ hiển thị ID của chúng vào khung "Dùng lại ID cũ"!
                let allAppIDVariants = [rawID, customID, resignedID].filter { !$0.isEmpty }

                for idVariant in allAppIDVariants {
                    let lower = idVariant.lowercased()
                    let baseLower = Self.stripTrailingTeamID(from: idVariant, teamID: teamID).lowercased()

                    activeMainIDs.insert(lower)
                    activeMainIDs.insert(baseLower)
                    activeBaseMainIDs.insert(baseLower)

                    if !lowerTeam.isEmpty {
                        activeMainIDs.insert("\(baseLower).\(lowerTeam)")
                    }

                    if !cleanAppName.isEmpty {
                        displayNamesByLowerID[lower] = cleanAppName
                        displayNamesByLowerID[baseLower] = cleanAppName
                        if !lowerTeam.isEmpty {
                            displayNamesByLowerID["\(baseLower).\(lowerTeam)"] = cleanAppName
                        }
                    }

                    if !isHostApp {
                        // Chỉ map vào bộ nhận diện cài đè trực tiếp đối với cái ID thực tế mà App đang mặc (customID / resignedID, hoặc rawID nếu chưa có custom)
                        let effectiveActiveID = !customID.isEmpty ? customID : (!resignedID.isEmpty ? resignedID : rawID)
                        let effectiveLower = effectiveActiveID.lowercased()
                        let effectiveBaseLower = Self.stripTrailingTeamID(from: effectiveActiveID, teamID: teamID).lowercased()

                        mapByActiveBundleID[effectiveLower] = app.objectID
                        mapByActiveBundleID[effectiveBaseLower] = app.objectID

                        // Chỉ tự động bỏ qua bảng hỏi (Auto-Update) khi App đó ĐANG HOẠT ĐỘNG (app.isActive == true)
                        if app.isActive, !nameKey.isEmpty {
                            mapByNameAndBaseID["\(nameKey)|\(baseLower)"] = app.objectID
                            mapByNameAndBaseID["\(nameKey)|\(lower)"] = app.objectID
                        }
                    }
                }

                // Ghi nhận Tên App duy nhất cho các App đang Active
                if !isHostApp, app.isActive, !nameKey.isEmpty {
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

            // Đồng bộ lưu lại bảng tên đẹp vào UserDefaults
            Self.saveAppIDNameHistory(displayNamesByLowerID)

            return InstalledAppSnapshot(
                activeMainIDsLowercased: activeMainIDs,
                activeBaseMainIDsLowercased: activeBaseMainIDs,
                knownExtensionIDsLowercased: knownExtensionIDs,
                objectIDByExactNameAndBaseID: mapByNameAndBaseID,
                objectIDByUniqueAppName: mapByUniqueName,
                objectIDByActiveBundleID: mapByActiveBundleID,
                knownDisplayNamesByLowerID: displayNamesByLowerID
            )
        }
    }

    private func fetchReusableAppIDCandidates(
        authTeam: ALTTeam,
        teamID: String,
        excludedOriginalBundleID: String,
        installedSnap: InstalledAppSnapshot
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
        let lowerTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let now = Date()

        // Chuẩn bị ID gốc của chính file IPA đang cài để loại trừ (tránh hiện trùng lặp với nút "Dùng ID gốc của IPA" ở trên)
        let cleanExcludedOrig = excludedOriginalBundleID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanExcludedBase = Self.stripTrailingTeamID(from: cleanExcludedOrig, teamID: teamID).lowercased()

        // Tập hợp tất cả các Base ID trên Portal (chỉ tính các ID có TeamID ở cuối cùng) để phát hiện quan hệ Cha - Con (.appex)
        var allPortalBaseIDs = Set<String>()
        for item in portalSnapshots {
            let full = item.bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !full.isEmpty else { continue }
            if !Self.hasMiddleTeamID(fullBundleID: full, teamID: teamID) {
                let base = Self.stripTrailingTeamID(from: full, teamID: teamID).lowercased()
                if !base.isEmpty {
                    allPortalBaseIDs.insert(base)
                }
            }
        }

        var seenFullIDs = Set<String>()
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

            // 1. Chặn ID chính và các ID phụ (.appex) của SideStore / AltStore hệ thống
            if Self.isProtectedHostOrCoreApp(
                lowerFull: lowerFull,
                hostMainID: hostMainBundleID,
                teamID: teamID
            ) {
                continue
            }

            // 2. Chặn chính ID gốc của file IPA đang cài (vì đã có nút "Dùng ID gốc của IPA" riêng ở phía trên)
            if !cleanExcludedBase.isEmpty {
                if lowerFull == cleanExcludedOrig ||
                   lowerBase == cleanExcludedBase ||
                   (!lowerTeam.isEmpty && lowerFull == "\(cleanExcludedBase).\(lowerTeam)") {
                    continue
                }
            }

            // 3. Chặn 100% các ID của tiện ích mở rộng (.appex):
            // 3a. Nếu TeamID nằm ở giữa chuỗi (ví dụ: com.app.TEAMID.widget) -> Chắc chắn 100% là .appex do SideStore/AltStore tạo ra!
            if Self.hasMiddleTeamID(fullBundleID: fullID, teamID: teamID) {
                continue
            }
            // 3b. Nếu nằm trong bảng InstalledAppExtension của CoreData
            if installedSnap.knownExtensionIDsLowercased.contains(lowerFull) ||
               installedSnap.knownExtensionIDsLowercased.contains(lowerBase) {
                continue
            }
            // 3c. Nếu là nhánh con (.appex) của một App đang cài (Active hoặc Inactive) hoặc của chính IPA đang cài
            let isChildOfInstalledOrIncomingApp = installedSnap.activeBaseMainIDsLowercased.contains { activeBase in
                !activeBase.isEmpty && lowerBase.hasPrefix(activeBase + ".")
            } || (!cleanExcludedBase.isEmpty && lowerBase.hasPrefix(cleanExcludedBase + "."))
            if isChildOfInstalledOrIncomingApp {
                continue
            }
            // 3d. Nếu là nhánh con (.appex) của một App ID khác trên cùng Apple Portal hoặc có hậu tố đặc trưng của iOS App Extension
            if Self.isLikelyPortalExtensionBundleID(
                lowerBase: lowerBase,
                rawPortalName: item.name,
                allPortalBaseIDs: allPortalBaseIDs
            ) {
                continue
            }

            // 4. Chặn toàn bộ ID đang được sử dụng bởi bất kỳ App nào trên máy (cả App Đang hoạt động lẫn App Không hoạt động / Deactivated)
            if installedSnap.activeMainIDsLowercased.contains(lowerFull) ||
               installedSnap.activeMainIDsLowercased.contains(lowerBase) {
                continue
            }

            guard !seenFullIDs.contains(lowerFull) else { continue }
            seenFullIDs.insert(lowerFull)

            // 5. Làm sạch tên hiển thị: Ưu tiên tên thật trong lịch sử -> Làm sạch tên Portal bị dính TeamID hoặc dấu cách
            let cleanDisplayName = Self.cleanCandidateDisplayName(
                rawPortalName: item.name,
                fullBundleID: fullID,
                baseBundleID: shortDisplayID,
                teamID: teamID,
                knownDisplayNamesByLowerID: installedSnap.knownDisplayNamesByLowerID
            )

            candidates.append(
                ReusableAppIDCandidate(
                    name: cleanDisplayName,
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

    // MARK: - Helpers: Nhận diện .appex & Làm sạch Tên hiển thị

    /// Kiểm tra xem mã TeamID có nằm ở giữa chuỗi Bundle ID hay không (ví dụ: `com.example.37D6PWG5PP.widget`).
    /// Trong SideStore/AltStore, chỉ có App Extension (`.appex`) mới có cấu trúc `parentIDWithTeam + .extensionSuffix`.
    private static func hasMiddleTeamID(fullBundleID: String, teamID: String) -> Bool {
        let trimmed = fullBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTeam.isEmpty else { return false }
        return trimmed.range(of: ".\(cleanTeam).", options: .caseInsensitive) != nil
    }

    /// Kiểm tra xem một Base Bundle ID (khi TeamID nằm ở cuối) có phải là App Extension (`.appex`) hay không.
    private static func isLikelyPortalExtensionBundleID(
        lowerBase: String,
        rawPortalName: String,
        allPortalBaseIDs: Set<String>
    ) -> Bool {
        // 1. Nếu trên cùng Apple Portal có một ID cha (ví dụ có cả `com.app` và `com.app.widget`)
        // thì `com.app.widget` chính là extension của `com.app`.
        for otherBase in allPortalBaseIDs where otherBase != lowerBase && !otherBase.isEmpty {
            if lowerBase.hasPrefix(otherBase + ".") {
                return true
            }
        }

        // 2. Kiểm tra hậu tố chuẩn của các iOS App Extension phổ biến (khi app chính đã bị xóa khỏi Portal trước đó)
        let parts = lowerBase.split(separator: ".").map(String.init)
        guard parts.count >= 4, let lastSegment = parts.last else {
            return false
        }

        let exactExtensionSuffixes: Set<String> = [
            "appex", "widget", "widgets", "widgetextension", "extension",
            "notificationservice", "notificationserviceextension", "notifications",
            "notificationcontent", "notificationcontentextension",
            "share", "shareextension", "sharing",
            "intents", "intentsextension", "intentsui", "siri", "siriextension",
            "watchkitapp", "watchkitextension", "watchapp", "watchextension",
            "today", "todayextension", "actionextension", "photoediting",
            "broadcast", "broadcastupload", "broadcastsetupui",
            "fileprovider", "fileproviderui", "quicklook", "spotlight",
            "autofill", "credentialprovider", "networkextension", "packet-tunnel",
            "packettunnel", "clip", "appclip", "stickers", "imessage", "messagesextension",
            "keyboard", "keyboardextension", "safariextension", "openin", " liveactivity"
        ]

        if exactExtensionSuffixes.contains(lastSegment) {
            return true
        }

        let extensionKeywordSuffixes = [
            "widget", "extension", "notificationservice", "notificationcontent",
            "shareextension", "watchkit", "broadcastupload", "intentsextension"
        ]
        for keyword in extensionKeywordSuffixes {
            if lastSegment.hasSuffix(keyword) {
                return true
            }
        }

        return false
    }

    /// Làm sạch tên hiển thị của App ID trên khung "Dùng lại ID cũ":
    /// - Ưu tiên lấy tên App thật (có dấu) đã được lưu trong lịch sử máy.
    /// - Xóa bỏ mã TeamID bị dính ở cuối tên (ví dụ: `"com alone 37D6PWG5PP"` -> `"Alone"`).
    private static func cleanCandidateDisplayName(
        rawPortalName: String,
        fullBundleID: String,
        baseBundleID: String,
        teamID: String,
        knownDisplayNamesByLowerID: [String: String]
    ) -> String {
        let lowerFull = fullBundleID.lowercased()
        let lowerBase = baseBundleID.lowercased()

        // 1. Nếu có trong lịch sử tên App thật trên máy -> Dùng ngay tên đẹp này!
        if let savedName = knownDisplayNamesByLowerID[lowerFull] ?? knownDisplayNamesByLowerID[lowerBase],
           !savedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return savedName
        }

        // 2. Làm sạch chuỗi tên trả về từ Apple Portal
        var working = rawPortalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines)

        // Cắt bỏ mã TeamID ở cuối hoặc ở giữa (dù ngăn cách bằng dấu chấm hay dấu cách)
        if !cleanTeam.isEmpty {
            working = stripTrailingTeamID(from: working, teamID: cleanTeam)
            let spaceTeamSuffix = " \(cleanTeam)"
            if working.lowercased().hasSuffix(spaceTeamSuffix.lowercased()), working.count > spaceTeamSuffix.count {
                working = String(working.dropLast(spaceTeamSuffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let middleSpaceToken = " \(cleanTeam) "
            if let range = working.range(of: middleSpaceToken, options: .caseInsensitive) {
                working = working.replacingCharacters(in: range, with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Kiểm tra xem tên trên Portal có phải chỉ là chuỗi Bundle ID bị thay dấu chấm bằng dấu cách không
        // (Ví dụ: baseBundleID = "com.alone" -> working = "com alone")
        let baseSpaced = baseBundleID.replacingOccurrences(of: ".", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if working.isEmpty ||
           working.caseInsensitiveCompare(baseBundleID) == .orderedSame ||
           working.caseInsensitiveCompare(fullBundleID) == .orderedSame ||
           working.caseInsensitiveCompare(baseSpaced) == .orderedSame {
            return humanReadableName(fromBaseBundleID: baseBundleID)
        }

        return working
    }

    /// Biến một Base Bundle ID (ví dụ: `com.alone` hoặc `com.google.ios.youtube`) thành tên ngắn gọn, dễ nhìn (`Alone`, `Youtube`).
    private static func humanReadableName(fromBaseBundleID baseBundleID: String) -> String {
        let ignoredTokens: Set<String> = [
            "com", "net", "org", "io", "me", "co", "uk", "vn", "us", "jp", "cn", "de", "fr", "ru",
            "app", "apps", "ios", "iphone", "ipad", "mobile", "client", "release", "prod", " official"
        ]
        let parts = baseBundleID
            .split(separator: ".")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let meaningfulLast = parts.last(where: { !ignoredTokens.contains($0.lowercased()) }) {
            return meaningfulLast.prefix(1).uppercased() + meaningfulLast.dropFirst()
        }
        if let last = parts.last {
            return last.prefix(1).uppercased() + last.dropFirst()
        }
        return baseBundleID
    }

    // MARK: - Lưu & Đọc lịch sử Tên hiển thị của App ID

    static func recordAppIDDisplayName(appName: String, fullBundleID: String, teamID: String) {
        let cleanName = appName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanFull = fullBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty, !cleanFull.isEmpty else { return }

        let baseID = stripTrailingTeamID(from: cleanFull, teamID: teamID)
        // Không lưu nếu bản thân appName lại là chuỗi Bundle ID thô
        if cleanName.caseInsensitiveCompare(cleanFull) == .orderedSame ||
           cleanName.caseInsensitiveCompare(baseID) == .orderedSame {
            return
        }

        var history = loadSavedAppIDNameHistory()
        history[cleanFull.lowercased()] = cleanName
        history[baseID.lowercased()] = cleanName
        let cleanTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !cleanTeam.isEmpty {
            history["\(baseID.lowercased()).\(cleanTeam)"] = cleanName
        }
        saveAppIDNameHistory(history)
    }

    private static func loadSavedAppIDNameHistory() -> [String: String] {
        (UserDefaults.standard.dictionary(forKey: appIDNameHistoryDefaultsKey) as? [String: String]) ?? [:]
    }

    private static func saveAppIDNameHistory(_ history: [String: String]) {
        UserDefaults.standard.set(history, forKey: appIDNameHistoryDefaultsKey)
    }

    private static func ensureTrailingTeamID(for bundleID: String, teamID: String) -> String {
        let trimmed = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTeam.isEmpty else { return trimmed }

        let lower = trimmed.lowercased()
        let lowerTeam = cleanTeam.lowercased()
        if lower.hasSuffix(".\(lowerTeam)") || lower.contains(".\(lowerTeam).") {
            return trimmed
        }
        return "\(trimmed).\(cleanTeam)"
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
            let hostBase = stripTrailingTeamID(from: hostMainID, teamID: teamID).lowercased()
            if !hostBase.isEmpty && (lowerFull == hostBase || lowerFull.hasPrefix(hostBase + ".")) {
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
