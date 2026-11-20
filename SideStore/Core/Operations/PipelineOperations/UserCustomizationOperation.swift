
//
//  UserCustomizationOperation.swift
//  AltStore
//
//  Created by SideStore Team.
//

import Foundation
import UIKit
import AltStoreCore
import AltSign
import Roxas

@objc(UserCustomizationOperation)
final class UserCustomizationOperation: ResultOperation<ALTApplication> {
    let context: AppOperationContext
    
    init(context: AppOperationContext) {
        self.context = context
        super.init()
    }
    
    override func main() {
        super.main()
        
        if let error = self.context.error {
            self.finish(.failure(error))
            return
        }
        
        guard let targetAppBundle = self.context.targetAppBundle else {
            self.finish(.failure(OperationError.invalidParameters("UserCustomizationOperation.main: self.context.targetAppBundle is nil")))
            return
        }
        
        // 1. Không hiển thị bảng hỏi nếu đây là bản tự cài đặt/cập nhật của chính SideStore
        if context.bundleIdentifier == StoreApp.altstoreAppID {
            self.context.useMainProfile = true
            self.context.appendTeamID = true
            self.finish(.success(targetAppBundle))
            return
        }
        
        // 2. Nếu là cập nhật hoặc cài đè lên ứng dụng ĐÃ CÀI ĐẶT sẵn trên máy -> Giữ nguyên thiết lập cũ
        if context.isStoreUpdate || context.installedApp != nil {
            self.context.useMainProfile = true
            let existingCustomID: String? = self.context.dbBackgroundContext.performAndWait {
                self.context.installedApp?.customBundleIdentifier
            }
            let existingResignedID: String? = self.context.dbBackgroundContext.performAndWait {
                self.context.installedApp?.resignedBundleIdentifier
            }
            let activeTeamID: String? = self.context.dbBackgroundContext.performAndWait {
                DatabaseManager.shared.activeTeam(in: self.context.dbBackgroundContext)?.identifier
            }
            
            if let existingResignedID, !existingResignedID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmedResigned = existingResignedID.trimmingCharacters(in: .whitespacesAndNewlines)
                context.customBundleIdentifier = trimmedResigned
                context.appendTeamID = false
            } else if let existingCustomID = existingCustomID ?? context.customBundleIdentifier,
                      !existingCustomID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let trimmed = existingCustomID.trimmingCharacters(in: .whitespacesAndNewlines)
                if let activeTeamID, trimmed.lowercased().hasSuffix(".\(activeTeamID.lowercased())") {
                    context.customBundleIdentifier = trimmed
                    context.appendTeamID = false
                } else if let activeTeamID, !activeTeamID.isEmpty {
                    let baseID = Self.stripTrailingTeamID(from: trimmed, teamID: activeTeamID)
                    context.customBundleIdentifier = "\(baseID).\(activeTeamID)"
                    context.appendTeamID = false
                } else {
                    context.customBundleIdentifier = trimmed
                    context.appendTeamID = true
                }
            } else {
                context.appendTeamID = true
            }
            
            self.finish(.success(targetAppBundle))
            return
        }
        
        let initialName = targetAppBundle.name
        let initialBundleID = self.context.customBundleIdentifier ?? targetAppBundle.bundleIdentifier
        
        // 3. Tải danh sách App ID hiện có trên Apple Developer Portal để người dùng có thể chọn dùng lại
        Task {
            let (team, existingPortalAppIDs, installedResignedIDs) = await self.fetchExistingAppIDChoices()
            let teamID = team?.identifier ?? ""
            
            let cleanInitialBundleID = Self.stripTrailingTeamID(from: initialBundleID, teamID: teamID)
            
            let result = await MainActor.run { () async -> CustomizationResult? in
                guard let presenter = Self.topViewController() else {
                    return CustomizationResult(
                        customName: initialName,
                        selectedBundleID: cleanInitialBundleID,
                        isReusingPortalAppID: false
                    )
                }
                
                return await withCheckedContinuation { continuation in
                    self.presentCustomizationSheet(
                        on: presenter,
                        initialName: initialName,
                        initialBundleID: cleanInitialBundleID,
                        teamID: teamID,
                        portalAppIDs: existingPortalAppIDs,
                        installedResignedIDs: installedResignedIDs,
                        completion: { result in
                            continuation.resume(returning: result)
                        }
                    )
                }
            }
            
            guard let result = result else {
                self.finish(.failure(OperationError.cancelled))
                return
            }
            
            let trimmedName = result.customName.trimmingCharacters(in: .whitespacesAndNewlines)
            let chosenRawID = result.selectedBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            
            var didCustomizeName = false
            var didCustomizeBundleID = false
            
            if !trimmedName.isEmpty && trimmedName != initialName {
                didCustomizeName = true
            }
            
            // Ép cứng sử dụng chung Profile của App chính cho toàn bộ Extensions (useMainProfile = true)
            // để không bao giờ tạo thêm App ID phụ cho các Widget/Extensions.
            self.context.useMainProfile = true
            
            if result.isReusingPortalAppID {
                // KHI CHỌN DÙNG LẠI APP ID ĐÃ ĐĂNG KÝ TRÊN APPLE PORTAL:
                // Giữ nguyên chính xác 100% Bundle Identifier đầy đủ của App ID đó (đã có đuôi .TEAM_ID)
                // và tắt appendTeamID để không bao giờ bị nối chồng thành .TEAM_ID.TEAM_ID!
                context.appendTeamID = false
                context.customBundleIdentifier = chosenRawID
                didCustomizeBundleID = true
            } else {
                // KHI DÙNG ID GỐC CỦA IPA HOẶC TỰ GÕ ID MỚI:
                // Luôn lưu đầy đủ cả hậu tố TeamID vào customBundleIdentifier ngay từ lần cài đầu tiên
                // để khi Làm mới (Refresh) lần đầu không bao giờ bị lệch ID!
                let baseID = Self.stripTrailingTeamID(
                    from: chosenRawID.isEmpty ? cleanInitialBundleID : chosenRawID,
                    teamID: teamID
                )
                if !teamID.isEmpty {
                    context.appendTeamID = false
                    context.customBundleIdentifier = "\(baseID).\(teamID)"
                    didCustomizeBundleID = true
                } else {
                    context.appendTeamID = true
                    if !baseID.isEmpty, baseID != context.bundleIdentifier {
                        context.customBundleIdentifier = baseID
                        didCustomizeBundleID = true
                    } else {
                        context.customBundleIdentifier = nil
                    }
                }
            }
            
            if didCustomizeName {
                do {
                    try Self.applyDisplayName(trimmedName, to: targetAppBundle.fileURL)
                } catch {
                    self.finish(.failure(error))
                    return
                }
            }
            
            guard let refreshedApplication = ALTApplication(fileURL: targetAppBundle.fileURL) else {
                self.finish(.failure(OperationError.invalidApp))
                return
            }
            
            if didCustomizeName || didCustomizeBundleID {
                self.context.targetAppBundle = refreshedApplication
            }
            
            self.finish(.success(refreshedApplication))
        }
    }
    
    // MARK: - Data Models
    
    private struct PortalAppIDChoice {
        let name: String
        let fullBundleID: String
        let baseBundleID: String
        let expirationDate: Date?
        let isCurrentlyInstalled: Bool
    }
    
    private struct CustomizationResult {
        let customName: String
        let selectedBundleID: String
        let isReusingPortalAppID: Bool
    }
    
    // MARK: - Fetch Existing App IDs (Apple Portal + Local DB Fallback)
    
    private func fetchExistingAppIDChoices() async -> (ALTTeam?, [PortalAppIDChoice], Set<String>) {
        // Lấy thông tin từ Core Data trước
        let (localAppIDs, installedResignedIDs): ([(name: String, bundleID: String, expDate: Date?)], Set<String>) = await self.context.dbBackgroundContext.perform {
            var localList: [(name: String, bundleID: String, expDate: Date?)] = []
            var installedSet = Set<String>()
            
            let installedApps = InstalledApp.all(in: self.context.dbBackgroundContext)
            for app in installedApps {
                if !app.resignedBundleIdentifier.isEmpty {
                    installedSet.insert(app.resignedBundleIdentifier.lowercased())
                }
                if let customID = app.customBundleIdentifier, !customID.isEmpty {
                    installedSet.insert(customID.lowercased())
                }
            }
            
            if let activeTeam = DatabaseManager.shared.activeTeam(in: self.context.dbBackgroundContext) {
                for appID in activeTeam.appIDs {
                    localList.append((name: appID.name, bundleID: appID.bundleIdentifier, expDate: appID.expirationDate))
                }
            }
            return (localList, installedSet)
        }
        
        // Cố gắng lấy Team & danh sách App ID mới nhất từ Apple Portal
        var resolvedTeam: ALTTeam? = self.context.sharedContext.team ?? self.context.team
        if resolvedTeam == nil {
            let fetchTeamOp = FetchTeamOperation(context: self.context)
            resolvedTeam = try? await withCheckedThrowingContinuation { continuation in
                fetchTeamOp.resultHandler = { result in
                    continuation.resume(with: result)
                }
                AppManager.shared.operationQueue.addOperation(fetchTeamOp)
            }
            if let resolvedTeam {
                self.context.sharedContext.team = resolvedTeam
            }
        }
        
        var portalChoices: [PortalAppIDChoice] = []
        let teamID = resolvedTeam?.identifier ?? ""
        
        if let team = resolvedTeam {
            let fetchedPortalIDs: [ALTAppID]? = try? await DeveloperPortalProxy.shared.fetchAppIDs(for: team)
            if let fetchedPortalIDs {
                self.context.sharedContext.appIDs = fetchedPortalIDs
                
                for item in fetchedPortalIDs {
                    let fullID = item.bundleIdentifier
                    let baseID = Self.stripTrailingTeamID(from: fullID, teamID: teamID)
                    
                    // Không liệt kê App ID của chính SideStore để tránh người dùng chọn nhầm đè lên SideStore
                    if baseID.lowercased().contains("com.SideStore.SideStore".lowercased()) {
                        continue
                    }
                    
                    let localMatch = localAppIDs.first { $0.bundleID.lowercased() == fullID.lowercased() }
                    let isInstalled = installedResignedIDs.contains(fullID.lowercased()) || installedResignedIDs.contains(baseID.lowercased())
                    
                    portalChoices.append(
                        PortalAppIDChoice(
                            name: item.name,
                            fullBundleID: fullID,
                            baseBundleID: baseID,
                            expirationDate: localMatch?.expDate,
                            isCurrentlyInstalled: isInstalled
                        )
                    )
                }
            }
        }
        
        // Nếu không tải được trực tiếp từ Portal (hoặc lỗi mạng tạm thời), dùng dữ liệu cache trong Core Data
        if portalChoices.isEmpty {
            for local in localAppIDs {
                let fullID = local.bundleID
                let baseID = Self.stripTrailingTeamID(from: fullID, teamID: teamID)
                if baseID.lowercased().contains("com.SideStore.SideStore".lowercased()) {
                    continue
                }
                let isInstalled = installedResignedIDs.contains(fullID.lowercased()) || installedResignedIDs.contains(baseID.lowercased())
                portalChoices.append(
                    PortalAppIDChoice(
                        name: local.name,
                        fullBundleID: fullID,
                        baseBundleID: baseID,
                        expirationDate: local.expDate,
                        isCurrentlyInstalled: isInstalled
                    )
                )
            }
        }
        
        // Sắp xếp: Ưu tiên các App ID ĐANG RẢNH (chưa có app cài trên máy) lên đầu để người dùng dễ tận dụng lại khi hết 10 App ID
        portalChoices.sort { lhs, rhs in
            if lhs.isCurrentlyInstalled != rhs.isCurrentlyInstalled {
                return !lhs.isCurrentlyInstalled
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        
        return (resolvedTeam, portalChoices, installedResignedIDs)
    }
    
    // MARK: - UI Presentation
    
    @MainActor
    private func presentCustomizationSheet(
        on presenter: UIViewController,
        initialName: String,
        initialBundleID: String,
        teamID: String,
        portalAppIDs: [PortalAppIDChoice],
        installedResignedIDs: Set<String>,
        completion: @escaping (CustomizationResult?) -> Void
    ) {
        let vc = AppCustomizationSheetViewController(
            initialName: initialName,
            initialBundleID: initialBundleID,
            teamID: teamID,
            portalAppIDs: portalAppIDs,
            completion: completion
        )
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        nav.isModalInPresentation = true
        presenter.present(nav, animated: true)
    }
    
    // MARK: - Helpers
    
    /// Cắt bỏ mọi hậu tố `.TEAM_ID` bị lặp ở cuối chuỗi Bundle ID để tránh lỗi `.TEAM_ID.TEAM_ID`
    static func stripTrailingTeamID(from bundleID: String, teamID: String) -> String {
        var result = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !teamID.isEmpty else { return result }
        
        let suffix = ".\(teamID)"
        while result.lowercased().hasSuffix(suffix.lowercased()), result.count > suffix.count {
            result = String(result.dropLast(suffix.count))
        }
        return result
    }
    
    private static func applyDisplayName(_ newName: String, to appBundleURL: URL) throws {
        let infoPlistURL = appBundleURL.appendingPathComponent("Info.plist")
        let data = try Data(contentsOf: infoPlistURL)
        
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard var plist = try PropertyListSerialization.propertyList(
            from: data,
            options: [.mutableContainersAndLeaves],
            format: &format
        ) as? [String: Any] else {
            throw OperationError.invalidApp
        }
        
        plist["CFBundleDisplayName"] = newName
        plist["CFBundleName"] = newName
        
        let updatedData = try PropertyListSerialization.data(fromPropertyList: plist, format: format, options: 0)
        try updatedData.write(to: infoPlistURL, options: .atomic)
        
        // Cập nhật tất cả các file InfoPlist.strings đa ngôn ngữ để iOS hiển thị đúng tên đã đổi trên Màn hình chính
        if let contents = try? FileManager.default.contentsOfDirectory(at: appBundleURL, includingPropertiesForKeys: nil) {
            for itemURL in contents where itemURL.pathExtension.lowercased() == "lproj" {
                let stringsURL = itemURL.appendingPathComponent("InfoPlist.strings")
                guard FileManager.default.fileExists(atPath: stringsURL.path),
                      let stringsData = try? Data(contentsOf: stringsURL) else { continue }
                
                var stringsFormat = PropertyListSerialization.PropertyListFormat.xml
                if var stringsDict = (try? PropertyListSerialization.propertyList(
                    from: stringsData,
                    options: [.mutableContainersAndLeaves],
                    format: &stringsFormat
                )) as? [String: Any] {
                    if stringsDict["CFBundleDisplayName"] != nil || stringsDict["CFBundleName"] != nil {
                        stringsDict["CFBundleDisplayName"] = newName
                        stringsDict["CFBundleName"] = newName
                        if let outData = try? PropertyListSerialization.data(fromPropertyList: stringsDict, format: stringsFormat, options: 0) {
                            try? outData.write(to: stringsURL, options: .atomic)
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }
        
        guard let window = scenes.flatMap({ $0.windows }).first(where: { $0.isKeyWindow }) ?? scenes.flatMap({ $0.windows }).first,
              var topController = window.rootViewController else {
            return nil
        }
        
        while let presented = topController.presentedViewController {
            topController = presented
        }
        
        return topController
    }
    
    // MARK: - Sheet View Controller
    
    @MainActor
    private final class AppCustomizationSheetViewController: UITableViewController {
        private let initialName: String
        private let initialBundleID: String
        private let teamID: String
        private let portalAppIDs: [PortalAppIDChoice]
        private let completion: (CustomizationResult?) -> Void
        
        private let nameTextField = UITextField()
        private let bundleIDTextField = UITextField()
        
        /// `nil` nghĩa là đang dùng Bundle ID gốc/tự nhập; nếu khác `nil` là đang chọn dùng lại 1 App ID có sẵn trên Portal
        private var selectedPortalChoiceIndex: Int?
        
        init(
            initialName: String,
            initialBundleID: String,
            teamID: String,
            portalAppIDs: [PortalAppIDChoice],
            completion: @escaping (CustomizationResult?) -> Void
        ) {
            self.initialName = initialName
            self.initialBundleID = initialBundleID
            self.teamID = teamID
            self.portalAppIDs = portalAppIDs
            self.completion = completion
            super.init(style: .insetGrouped)
            
            // Nếu Bundle ID gốc của IPA trùng khớp sẵn với 1 App ID đã có trên Portal -> Tự động chọn sẵn luôn để không tốn thêm slot App ID!
            let expectedFullID = teamID.isEmpty ? initialBundleID : "\(initialBundleID).\(teamID)"
            if let existingIdx = portalAppIDs.firstIndex(where: {
                $0.fullBundleID.lowercased() == expectedFullID.lowercased() ||
                $0.baseBundleID.lowercased() == initialBundleID.lowercased()
            }) {
                self.selectedPortalChoiceIndex = existingIdx
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            self.title = "Tùy chỉnh cài đặt"
            
            self.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Hủy",
                style: .plain,
                target: self,
                action: #selector(didTapCancel)
            )
            
            let installButton = UIBarButtonItem(
                title: "Tiếp tục",
                style: .done,
                target: self,
                action: #selector(didTapContinue)
            )
            self.navigationItem.rightBarButtonItem = installButton
            
            self.nameTextField.text = self.initialName
            self.nameTextField.placeholder = "Tên hiển thị của ứng dụng"
            self.nameTextField.clearButtonMode = .whileEditing
            self.nameTextField.font = .systemFont(ofSize: 16)
            
            if let idx = self.selectedPortalChoiceIndex {
                self.bundleIDTextField.text = self.portalAppIDs[idx].baseBundleID
            } else {
                self.bundleIDTextField.text = self.initialBundleID
            }
            self.bundleIDTextField.placeholder = "com.example.app"
            self.bundleIDTextField.clearButtonMode = .whileEditing
            self.bundleIDTextField.autocapitalizationType = .none
            self.bundleIDTextField.autocorrectionType = .no
            self.bundleIDTextField.keyboardType = .asciiCapable
            self.bundleIDTextField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            self.bundleIDTextField.addTarget(self, action: #selector(bundleIDTextDidChange), for: .editingChanged)
        }
        
        @objc private func bundleIDTextDidChange() {
            let currentText = (self.bundleIDTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanText = UserCustomizationOperation.stripTrailingTeamID(from: currentText, teamID: self.teamID)
            
            if let matchIdx = self.portalAppIDs.firstIndex(where: {
                $0.baseBundleID.lowercased() == cleanText.lowercased() ||
                $0.fullBundleID.lowercased() == currentText.lowercased()
            }) {
                if self.selectedPortalChoiceIndex != matchIdx {
                    self.selectedPortalChoiceIndex = matchIdx
                    self.tableView.reloadSections(IndexSet(integer: 2), with: .none)
                }
            } else if self.selectedPortalChoiceIndex != nil {
                self.selectedPortalChoiceIndex = nil
                self.tableView.reloadSections(IndexSet(integer: 2), with: .none)
            }
        }
        
        @objc private func didTapCancel() {
            self.dismiss(animated: true) {
                self.completion(nil)
            }
        }
        
        @objc private func didTapContinue() {
            let finalName = (self.nameTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedName = finalName.isEmpty ? self.initialName : finalName
            
            if let idx = self.selectedPortalChoiceIndex {
                let choice = self.portalAppIDs[idx]
                let result = CustomizationResult(
                    customName: resolvedName,
                    selectedBundleID: choice.fullBundleID,
                    isReusingPortalAppID: true
                )
                self.dismiss(animated: true) {
                    self.completion(result)
                }
            } else {
                let rawID = (self.bundleIDTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanID = UserCustomizationOperation.stripTrailingTeamID(
                    from: rawID.isEmpty ? self.initialBundleID : rawID,
                    teamID: self.teamID
                )
                
                // Kiểm tra lần cuối xem cleanID có khớp với App ID nào đã có trên Portal không
                if let matchChoice = self.portalAppIDs.first(where: {
                    $0.baseBundleID.lowercased() == cleanID.lowercased() ||
                    $0.fullBundleID.lowercased() == rawID.lowercased()
                }) {
                    let result = CustomizationResult(
                        customName: resolvedName,
                        selectedBundleID: matchChoice.fullBundleID,
                        isReusingPortalAppID: true
                    )
                    self.dismiss(animated: true) {
                        self.completion(result)
                    }
                } else {
                    let result = CustomizationResult(
                        customName: resolvedName,
                        selectedBundleID: cleanID,
                        isReusingPortalAppID: false
                    )
                    self.dismiss(animated: true) {
                        self.completion(result)
                    }
                }
            }
        }
        
        // MARK: - Table View Data Source
        
        override func numberOfSections(in tableView: UITableView) -> Int {
            return 3
        }
        
        override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            switch section {
            case 0: return 1
            case 1: return 2
            case 2: return max(1, self.portalAppIDs.count)
            default: return 0
            }
        }
        
        override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            switch section {
            case 0:
                return "Tên hiển thị ứng dụng"
            case 1:
                return "Bundle ID (Tạo mới hoặc chỉnh sửa)"
            case 2:
                return "Hoặc chọn lại App ID đã có (\(self.portalAppIDs.count)/10)"
            default:
                return nil
            }
        }
        
        override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            switch section {
            case 1:
                if !self.teamID.isEmpty {
                    return "Hệ thống tự động quản lý hậu tố Team ID (.\(self.teamID)). Bạn không cần tự gõ hậu tố này."
                }
                return nil
            case 2:
                return "Khi bạn đã dùng hết 10/10 App ID của tài khoản Apple miễn phí, hãy chọn một App ID [Đang rảnh] bên trên để cài đặt ứng dụng mới mà không bị báo lỗi hết lượt App ID!"
            default:
                return nil
            }
        }
        
        override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            switch indexPath.section {
            case 0:
                let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.selectionStyle = .none
                self.embedTextField(self.nameTextField, in: cell.contentView)
                return cell
                
            case 1:
                if indexPath.row == 0 {
                    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                    cell.selectionStyle = .none
                    self.embedTextField(self.bundleIDTextField, in: cell.contentView)
                    return cell
                } else {
                    let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                    cell.textLabel?.text = "Khôi phục ID gốc của file IPA"
                    cell.textLabel?.textColor = .systemBlue
                    cell.textLabel?.font = .systemFont(ofSize: 15, weight: .medium)
                    cell.detailTextLabel?.text = self.initialBundleID
                    cell.detailTextLabel?.textColor = .secondaryLabel
                    cell.accessoryType = (self.selectedPortalChoiceIndex == nil && self.bundleIDTextField.text == self.initialBundleID) ? .checkmark : .none
                    return cell
                }
                
            case 2:
                if self.portalAppIDs.isEmpty {
                    let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                    cell.selectionStyle = .none
                    cell.textLabel?.text = "Chưa có App ID nào được lưu"
                    cell.textLabel?.textColor = .secondaryLabel
                    return cell
                }
                
                let choice = self.portalAppIDs[indexPath.row]
                let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "PortalAppIDCell")
                
                let statusBadge = choice.isCurrentlyInstalled ? "Đang cài trên máy" : "Đang rảnh - Khuyên dùng"
                cell.textLabel?.text = "\(choice.name)  •  [\(statusBadge)]"
                cell.textLabel?.font = .systemFont(ofSize: 15, weight: choice.isCurrentlyInstalled ? .regular : .semibold)
                cell.textLabel?.textColor = choice.isCurrentlyInstalled ? .label : .systemGreen
                cell.textLabel?.numberOfLines = 1
                
                cell.detailTextLabel?.text = choice.baseBundleID
                cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                cell.detailTextLabel?.textColor = .secondaryLabel
                cell.detailTextLabel?.numberOfLines = 1
                
                cell.accessoryType = (self.selectedPortalChoiceIndex == indexPath.row) ? .checkmark : .none
                return cell
                
            default:
                return UITableViewCell()
            }
        }
        
        override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            tableView.deselectRow(at: indexPath, animated: true)
            
            if indexPath.section == 1 && indexPath.row == 1 {
                self.bundleIDTextField.text = self.initialBundleID
                self.bundleIDTextDidChange()
                tableView.reloadSections(IndexSet([1, 2]), with: .none)
            } else if indexPath.section == 2, !self.portalAppIDs.isEmpty {
                let choice = self.portalAppIDs[indexPath.row]
                self.selectedPortalChoiceIndex = indexPath.row
                self.bundleIDTextField.text = choice.baseBundleID
                self.view.endEditing(true)
                tableView.reloadSections(IndexSet([1, 2]), with: .none)
            }
        }
        
        private func embedTextField(_ textField: UITextField, in contentView: UIView) {
            textField.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(textField)
            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
                textField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
                textField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 11),
                textField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -11),
                textField.heightAnchor.constraint(greaterThanOrEqualToConstant: 24)
            ])
        }
    }
}
