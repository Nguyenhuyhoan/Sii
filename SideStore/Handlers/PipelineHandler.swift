
//
//  PipelineHandler.swift
//  AltStore
//
//  Created by SideStore Team.
//  Copyright © 2024 SideStore. All rights reserved.
//

import UIKit
import SwiftUI
import AltStoreCore

// MARK: - Data Models for Customization Modals

public struct AppExtensionInfo: Identifiable, Hashable {
    public var id: String { fileURL.path }
    public let name: String
    public let bundleIdentifier: String
    public let fileURL: URL
    public let sizeInBytes: Int64
    
    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
}

public struct ReusableBundleIDCandidate: Identifiable, Hashable {
    public var id: String { fullBundleIdentifier.lowercased() }
    public let name: String
    public let baseBundleIdentifier: String
    public let fullBundleIdentifier: String
    public let expirationDate: Date?
    public let hasEmbeddedTeamID: Bool
    public let requiresAppendingTeamID: Bool
    public let isLikelyExtension: Bool
    public let sourceDescription: String
}

public struct EditableInfoPlistBundle: Identifiable, Hashable {
    public let id: String // Original bundleIdentifier
    public let title: String
    public let bundlePath: String
    public var entries: [String: String]
}

// MARK: - PipelineHandler Protocol

public protocol PipelineHandler: AnyObject {
    func updateProgress(stepName: String, stepIndex: Int, totalSteps: Int)
    func requestCustomAppName(defaultName: String, bundleId: String) async throws -> String
    func requestCustomBundleID(defaultBundleId: String, teamId: String) async throws -> (customID: String, appendTeamID: Bool)
    func requestSmartBundleIDSelection(
        appName: String,
        defaultBundleId: String,
        teamId: String,
        candidates: [ReusableBundleIDCandidate]
    ) async throws -> (customID: String, appendTeamID: Bool)
    func requestExtensionRemoval(extensions: [AppExtensionInfo]) async throws -> [URL]
    func requestInfoPlistEdits(bundles: [EditableInfoPlistBundle]) async throws -> [String: [String: String]]
}

// MARK: - Default UI Implementation

@MainActor
public final class DefaultPipelineHandler: PipelineHandler {
    public static let shared = DefaultPipelineHandler()
    
    private init() {}
    
    private func topMostViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene.windows.first?.rootViewController else {
            return nil
        }
        
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }
        return topVC
    }
    
    nonisolated public func updateProgress(stepName: String, stepIndex: Int, totalSteps: Int) {
        Task { @MainActor in
            PipelineMonitorState.shared.update(stepName: stepName, index: stepIndex, total: totalSteps)
        }
    }
    
    nonisolated public func requestCustomAppName(defaultName: String, bundleId: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let presenter = self.topMostViewController() else {
                    continuation.resume(returning: defaultName)
                    return
                }
                
                let alert = UIAlertController(
                    title: "Đặt tên ứng dụng tùy chỉnh",
                    message: "Nhập tên hiển thị mới cho ứng dụng.\nID gói gốc: \(bundleId)",
                    preferredStyle: .alert
                )
                
                alert.addTextField { textField in
                    textField.text = defaultName
                    textField.placeholder = defaultName
                    textField.clearButtonMode = .whileEditing
                }
                
                alert.addAction(UIAlertAction(title: "Giữ mặc định", style: .cancel) { _ in
                    continuation.resume(returning: defaultName)
                })
                
                alert.addAction(UIAlertAction(title: "Tiếp tục", style: .default) { _ in
                    let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: text.isEmpty ? defaultName : text)
                })
                
                presenter.present(alert, animated: true)
            }
        }
    }
    
    nonisolated public func requestCustomBundleID(defaultBundleId: String, teamId: String) async throws -> (customID: String, appendTeamID: Bool) {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let presenter = self.topMostViewController() else {
                    continuation.resume(returning: (defaultBundleId, true))
                    return
                }
                
                var hasResumed = false
                let modalView = CustomBundleIDModalView(
                    defaultBundleId: defaultBundleId,
                    teamId: teamId
                ) { result in
                    guard !hasResumed else { return }
                    hasResumed = true
                    presenter.dismiss(animated: true) {
                        continuation.resume(returning: result)
                    }
                }
                
                let hostingVC = UIHostingController(rootView: modalView)
                hostingVC.isModalInPresentation = true
                hostingVC.modalPresentationStyle = .formSheet
                presenter.present(hostingVC, animated: true)
            }
        }
    }
    
    nonisolated public func requestSmartBundleIDSelection(
        appName: String,
        defaultBundleId: String,
        teamId: String,
        candidates: [ReusableBundleIDCandidate]
    ) async throws -> (customID: String, appendTeamID: Bool) {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let presenter = self.topMostViewController() else {
                    continuation.resume(returning: (defaultBundleId, true))
                    return
                }
                
                var hasResumed = false
                let modalView = SmartBundleIDCenterModalView(
                    appName: appName,
                    defaultBundleId: defaultBundleId,
                    teamId: teamId,
                    candidates: candidates
                ) { result in
                    guard !hasResumed else { return }
                    hasResumed = true
                    presenter.dismiss(animated: true) {
                        continuation.resume(returning: result)
                    }
                }
                
                let hostingVC = UIHostingController(rootView: modalView)
                hostingVC.isModalInPresentation = true
                hostingVC.modalPresentationStyle = .formSheet
                presenter.present(hostingVC, animated: true)
            }
        }
    }
    
    nonisolated public func requestExtensionRemoval(extensions: [AppExtensionInfo]) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let presenter = self.topMostViewController() else {
                    continuation.resume(returning: [])
                    return
                }
                
                var hasResumed = false
                let modalView = ExtensionRemovalModalView(extensions: extensions) { urlsToRemove in
                    guard !hasResumed else { return }
                    hasResumed = true
                    presenter.dismiss(animated: true) {
                        continuation.resume(returning: urlsToRemove)
                    }
                }
                
                let hostingVC = UIHostingController(rootView: modalView)
                hostingVC.isModalInPresentation = true
                hostingVC.modalPresentationStyle = .formSheet
                presenter.present(hostingVC, animated: true)
            }
        }
    }
    
    nonisolated public func requestInfoPlistEdits(bundles: [EditableInfoPlistBundle]) async throws -> [String: [String: String]] {
        return try await withCheckedThrowingContinuation { continuation in
            Task { @MainActor in
                guard let presenter = self.topMostViewController() else {
                    continuation.resume(returning: [:])
                    return
                }
                
                var hasResumed = false
                let modalView = InfoPlistEditorModalView(bundles: bundles) { editedMap in
                    guard !hasResumed else { return }
                    hasResumed = true
                    presenter.dismiss(animated: true) {
                        continuation.resume(returning: editedMap)
                    }
                }
                
                let hostingVC = UIHostingController(rootView: modalView)
                hostingVC.isModalInPresentation = true
                hostingVC.modalPresentationStyle = .formSheet
                presenter.present(hostingVC, animated: true)
            }
        }
    }
}

// MARK: - Live Pipeline Monitor State

public final class PipelineMonitorState: ObservableObject {
    public static let shared = PipelineMonitorState()
    
    @Published public var currentStepName: String = ""
    @Published public var currentStepIndex: Int = 0
    @Published public var totalSteps: Int = 0
    @Published public var isActive: Bool = false
    
    private init() {}
    
    public func update(stepName: String, index: Int, total: Int) {
        self.currentStepName = stepName
        self.currentStepIndex = index
        self.totalSteps = total
        self.isActive = index < total
    }
    
    public func reset() {
        self.isActive = false
        self.currentStepName = ""
        self.currentStepIndex = 0
        self.totalSteps = 0
    }
}

// MARK: - Helper for Stripping Trailing Team ID in UI

private func stripTrailingTeamSuffix(_ bundleID: String, teamID: String) -> String {
    let trimmedTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedTeam.isEmpty else { return bundleID }
    
    var result = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    let suffix = "." + trimmedTeam
    while result.lowercased().hasSuffix(suffix.lowercased()), result.count > suffix.count {
        result = String(result.dropLast(suffix.count))
    }
    return result
}

// MARK: - 1. Smart Bundle ID Reuse Center Modal View

struct SmartBundleIDCenterModalView: View {
    let appName: String
    let defaultBundleId: String
    let teamId: String
    let candidates: [ReusableBundleIDCandidate]
    let onComplete: ((customID: String, appendTeamID: Bool)) -> Void
    
    @State private var customBundleID: String
    @State private var appendTeamID: Bool = true
    @State private var showExtensionIDs: Bool = false
    
    init(
        appName: String,
        defaultBundleId: String,
        teamId: String,
        candidates: [ReusableBundleIDCandidate],
        onComplete: @escaping ((customID: String, appendTeamID: Bool)) -> Void
    ) {
        self.appName = appName
        self.defaultBundleId = defaultBundleId
        self.teamId = teamId
        self.candidates = candidates
        self.onComplete = onComplete
        _customBundleID = State(initialValue: defaultBundleId)
    }
    
    private var filteredCandidates: [ReusableBundleIDCandidate] {
        candidates.filter { showExtensionIDs || !$0.isLikelyExtension }
    }
    
    private var previewFinalBundleID: String {
        let trimmed = customBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? defaultBundleId : trimmed
        if appendTeamID && !teamId.isEmpty {
            let cleanBase = stripTrailingTeamSuffix(base, teamID: teamId)
            return "\(cleanBase).\(teamId)"
        }
        return base
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Tái sử dụng App ID đã cấp cho \"\(appName)\""),
                    footer: Text("Chọn một ID ứng dụng chính từ chứng chỉ của bạn để tiết kiệm giới hạn 10 App ID mỗi tuần. Nếu ID có chứa Mã Nhóm ở giữa (ví dụ: com.kdt.livecontainer.\(teamId.isEmpty ? "TEAMID" : teamId).LiveWidget), hệ thống sẽ giữ nguyên mà không gắn trùng lặp hậu tố.")
                ) {
                    if filteredCandidates.isEmpty {
                        Text("Không tìm thấy App ID cũ nào trên chứng chỉ hoặc thiết bị.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(filteredCandidates) { candidate in
                            SwiftUI.Button {
                                // Pass clean baseBundleIdentifier when requiresAppendingTeamID is true
                                // so downstream operations never duplicate ".TEAMID.TEAMID"
                                let selectedID = candidate.requiresAppendingTeamID
                                    ? stripTrailingTeamSuffix(candidate.baseBundleIdentifier, teamID: teamId)
                                    : candidate.fullBundleIdentifier
                                onComplete((selectedID, candidate.requiresAppendingTeamID))
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(candidate.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        if candidate.hasEmbeddedTeamID {
                                            Text("TeamID ở giữa")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.orange.opacity(0.2))
                                                .foregroundColor(.orange)
                                                .cornerRadius(4)
                                        } else {
                                            Text("Tái sử dụng")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.blue.opacity(0.15))
                                                .foregroundColor(.blue)
                                                .cornerRadius(4)
                                        }
                                    }
                                    
                                    Text("ID đầy đủ: \(candidate.fullBundleIdentifier)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text("ID gốc: \(candidate.baseBundleIdentifier) • \(candidate.sourceDescription)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    if candidates.contains(where: { $0.isLikelyExtension }) {
                        Toggle("Hiển thị cả ID của Phần mở rộng (Widget/Plugin)", isOn: $showExtensionIDs)
                            .font(.subheadline)
                    }
                }
                
                Section(
                    header: Text("Hoặc tự nhập Bundle ID tùy chỉnh khác"),
                    footer: Text("ID cuối cùng sẽ dùng để ký: \(previewFinalBundleID)")
                ) {
                    TextField(defaultBundleId, text: $customBundleID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Toggle("Tự động gắn hậu tố Mã Nhóm (.\(teamId.isEmpty ? "TEAMID" : teamId))", isOn: $appendTeamID)
                    
                    SwiftUI.Button("Sử dụng ID tùy chỉnh ở trên") {
                        let rawInput = customBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectiveInput = rawInput.isEmpty ? defaultBundleId : rawInput
                        let finalID = appendTeamID
                            ? stripTrailingTeamSuffix(effectiveInput, teamID: teamId)
                            : effectiveInput
                        onComplete((finalID, appendTeamID))
                    }
                    .font(.headline)
                }
            }
            .navigationTitle("Chọn ID Gói Chính")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Giữ mặc định") {
                        onComplete(( stripTrailingTeamSuffix(defaultBundleId, teamID: teamId), true))
                    }
                }
            }
        }
    }
}

// MARK: - 2. Simple Custom Bundle ID Modal View

struct CustomBundleIDModalView: View {
    let defaultBundleId: String
    let teamId: String
    let onComplete: ((customID: String, appendTeamID: Bool)) -> Void
    
    @State private var customBundleID: String
    @State private var appendTeamID: Bool = true
    
    init(
        defaultBundleId: String,
        teamId: String,
        onComplete: @escaping ((customID: String, appendTeamID: Bool)) -> Void
    ) {
        self.defaultBundleId = defaultBundleId
        self.teamId = teamId
        self.onComplete = onComplete
        _customBundleID = State(initialValue: defaultBundleId)
    }
    
    private var previewFinalBundleID: String {
        let trimmed = customBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? defaultBundleId : trimmed
        if appendTeamID && !teamId.isEmpty {
            let cleanBase = stripTrailingTeamSuffix(base, teamID: teamId)
            return "\(cleanBase).\(teamId)"
        }
        return base
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Mã định danh gói (Bundle ID)"),
                    footer: Text("ID thực tế sau khi ký: \(previewFinalBundleID)")
                ) {
                    TextField(defaultBundleId, text: $customBundleID)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Toggle("Gắn hậu tố Mã Nhóm (.\(teamId.isEmpty ? "TEAMID" : teamId))", isOn: $appendTeamID)
                }
            }
            .navigationTitle("Tùy chỉnh Bundle ID")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Mặc định") {
                        onComplete((stripTrailingTeamSuffix(defaultBundleId, teamID: teamId), true))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button("Xác nhận") {
                        let rawInput = customBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectiveInput = rawInput.isEmpty ? defaultBundleId : rawInput
                        let finalID = appendTeamID
                            ? stripTrailingTeamSuffix(effectiveInput, teamID: teamId)
                            : effectiveInput
                        onComplete((finalID, appendTeamID))
                    }
                }
            }
        }
    }
}

// MARK: - 3. App Extensions / Placeholders Removal Modal View

struct ExtensionRemovalModalView: View {
    let extensions: [AppExtensionInfo]
    let onComplete: ([URL]) -> Void
    
    @State private var selectedURLs: Set<URL> = []
    
    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Chọn các Phần mở rộng (PlugIns) muốn gỡ bỏ"),
                    footer: Text("Các phần mở rộng được đánh dấu sẽ bị xóa khỏi gói cài đặt trước khi tạo App Group và lấy Hồ sơ cấp phép, giúp tiết kiệm số lượng App ID của tài khoản miễn phí.")
                ) {
                    ForEach(extensions) { ext in
                        SwiftUI.Button {
                            if selectedURLs.contains(ext.fileURL) {
                                selectedURLs.remove(ext.fileURL)
                            } else {
                                selectedURLs.insert(ext.fileURL)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedURLs.contains(ext.fileURL) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedURLs.contains(ext.fileURL) ? .red : .secondary)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(ext.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    Text(ext.bundleIdentifier)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(ext.formattedSize)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.15))
                                    .cornerRadius(4)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section {
                    SwiftUI.Button("Chọn gỡ bỏ tất cả (\(extensions.count) phần mở rộng)") {
                        selectedURLs = Set(extensions.map { $0.fileURL })
                    }
                    .foregroundColor(.red)
                    
                    SwiftUI.Button("Giữ lại tất cả (Không gỡ bỏ)") {
                        selectedURLs.removeAll()
                    }
                }
            }
            .navigationTitle("Quản lý Phần mở rộng")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button(selectedURLs.isEmpty ? "Tiếp tục" : "Gỡ bỏ (\(selectedURLs.count))") {
                        onComplete(Array(selectedURLs))
                    }
                }
            }
        }
    }
}

// MARK: - 4. Info.plist Editor Modal View

struct InfoPlistEditorModalView: View {
    @State private var bundles: [EditableInfoPlistBundle]
    @State private var selectedBundleIndex: Int = 0
    @State private var searchText: String = ""
    @State private var newKeyName: String = ""
    @State private var newKeyValue: String = ""
    
    let onComplete: ([String: [String: String]]) -> Void
    
    init(bundles: [EditableInfoPlistBundle], onComplete: @escaping ([String: [String: String]]) -> Void) {
        _bundles = State(initialValue: bundles)
        self.onComplete = onComplete
    }
    
    private var currentKeys: [String] {
        guard bundles.indices.contains(selectedBundleIndex) else { return [] }
        let allKeys = bundles[selectedBundleIndex].entries.keys.sorted()
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return allKeys
        }
        return allKeys.filter {
            $0.localizedCaseInsensitiveContains(searchText) ||
            (bundles[selectedBundleIndex].entries[$0]?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if bundles.count > 1 {
                    Picker("Chọn gói", selection: $selectedBundleIndex) {
                        ForEach(bundles.indices, id: \.self) { idx in
                            Text(bundles[idx].title).tag(idx)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                List {
                    Section(header: Text("Tìm kiếm khóa hoặc giá trị")) {
                        TextField("Nhập từ khóa (VD: CFBundleDisplayName, UIFileSharingEnabled)...", text: $searchText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    
                    Section(header: Text("Thêm khóa mới vào Info.plist")) {
                        TextField("Tên khóa mới (Key)", text: $newKeyName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        TextField("Giá trị (Value - true/false/chuỗi)", text: $newKeyValue)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        SwiftUI.Button("Thêm / Cập nhật khóa này") {
                            let k = newKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !k.isEmpty, bundles.indices.contains(selectedBundleIndex) else { return }
                            bundles[selectedBundleIndex].entries[k] = newKeyValue
                            newKeyName = ""
                            newKeyValue = ""
                        }
                        .disabled(newKeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    Section(header: Text("Danh sách các khóa (\(currentKeys.count))")) {
                        ForEach(currentKeys, id: \.self) { key in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(key)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.blue)
                                    Spacer()
                                    SwiftUI.Button(role: .destructive) {
                                        bundles[selectedBundleIndex].entries.removeValue(forKey: key)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                    .buttonStyle(BorderlessButtonStyle())
                                }
                                
                                TextField("Giá trị", text: Binding(
                                    get: { bundles[selectedBundleIndex].entries[key] ?? "" },
                                    set: { bundles[selectedBundleIndex].entries[key] = $0 }
                                ))
                                .font(.subheadline)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Trình sửa Info.plist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Bỏ qua") {
                        onComplete([:])
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button("Lưu & Tiếp tục") {
                        var result: [String: [String: String]] = [:]
                        for bundle in bundles {
                            result[bundle.id] = bundle.entries
                        }
                        onComplete(result)
                    }
                }
            }
        }
    }
}
