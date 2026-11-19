//
//  PipelineHandler.swift
//  AltStore
//
//  Created by SideStore Team.
//

import Foundation
import UIKit
import SwiftUI

extension InstallAppOperationContext {
    public struct AppExtensionInfo: Identifiable {
        public let id = UUID()
        public let name: String
        public let bundleIdentifier: String
        public let fileURL: URL
        public let sizeInBytes: Int64

        public var formattedSize: String {
            ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
        }
    }

    public struct ReusableBundleIDCandidate: Identifiable, Hashable {
        public var id: String { fullBundleIdentifier }
        public let name: String
        public let baseBundleIdentifier: String
        public let fullBundleIdentifier: String
        public let expirationDate: Date?
        public let hasEmbeddedTeamID: Bool
        public let requiresAppendingTeamID: Bool
        public let isLikelyExtension: Bool
        public let sourceDescription: String
    }

    public struct EditableInfoPlistBundle: Identifiable {
        public let id: String // bundleIdentifier
        public let title: String
        public let bundlePath: String
        public var entries: [String: String]
    }
}

public protocol PipelineHandler: AnyObject {
    func updateProgress(stepName: String, stepIndex: Int, totalSteps: Int)
    func requestCustomAppName(defaultName: String, bundleId: String) async -> String
    func requestCustomBundleID(defaultBundleId: String, teamId: String) async -> (customID: String, appendTeamID: Bool)
    func requestSmartBundleIDSelection(
        appName: String,
        defaultBundleId: String,
        teamId: String,
        candidates: [InstallAppOperationContext.ReusableBundleIDCandidate]
    ) async -> (customID: String, appendTeamID: Bool)
    func requestExtensionRemoval(extensions: [InstallAppOperationContext.AppExtensionInfo]) async -> [URL]
    func requestInfoPlistEdits(bundles: [InstallAppOperationContext.EditableInfoPlistBundle]) async -> [String: [String: String]]
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

// MARK: - SwiftUI Modal Views for Customizations

struct SmartBundleIDCenterModalView: View {
    let appName: String
    let defaultBundleId: String
    let teamId: String
    let candidates: [InstallAppOperationContext.ReusableBundleIDCandidate]
    var onComplete: ((String, Bool)) -> Void

    @State private var customId: String
    @State private var appendTeamId: Bool = true
    @State private var showExtensionIDs: Bool = false

    init(
        appName: String,
        defaultBundleId: String,
        teamId: String,
        candidates: [InstallAppOperationContext.ReusableBundleIDCandidate],
        onComplete: @escaping ((String, Bool)) -> Void
    ) {
        self.appName = appName
        self.defaultBundleId = defaultBundleId
        self.teamId = teamId
        self.candidates = candidates
        self.onComplete = onComplete
        self._customId = State(initialValue: defaultBundleId)
    }

    private var filteredCandidates: [InstallAppOperationContext.ReusableBundleIDCandidate] {
        candidates.filter { showExtensionIDs || !$0.isLikelyExtension }
    }

    private var previewFinalId: String {
        let base = customId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultBundleId
            : customId.trimmingCharacters(in: .whitespacesAndNewlines)
        if appendTeamId && !teamId.isEmpty {
            let cleanBase = stripTrailingTeamSuffix(base, teamID: teamId)
            return "\(cleanBase).\(teamId)"
        }
        return base
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .none
        return df
    }()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Ứng dụng đang cài đặt")) {
                    HStack {
                        Text("Tên ứng dụng")
                        Spacer()
                        Text(appName)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("ID Gói gốc")
                        Spacer()
                        Text(defaultBundleId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Section(
                    header: Text("Chọn lại ID Gói Chính sẵn có trên Chứng chỉ (\(filteredCandidates.count))"),
                    footer: Text("Chọn một ID gói ứng dụng chính đã đăng ký trước đó để tái sử dụng lại slot App ID mà không tốn thêm lượt đăng ký mới. Hệ thống tự động giữ nguyên các ID có Team ID nằm ở giữa.")
                ) {
                    if candidates.contains(where: { $0.isLikelyExtension }) {
                        Toggle("Hiển thị cả ID của Phần mở rộng (Extensions)", isOn: $showExtensionIDs)
                    }

                    if filteredCandidates.isEmpty {
                        Text("Chưa tìm thấy ID gói sẵn có nào trên chứng chỉ của bạn.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(filteredCandidates) { candidate in
                            SwiftUI.Button {
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

                                    Text(candidate.fullBundleIdentifier)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.primary)

                                    HStack {
                                        Text(candidate.sourceDescription)
                                        if let exp = candidate.expirationDate {
                                            Text("• Hết hạn: \(Self.dateFormatter.string(from: exp))")
                                        }
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                Section(
                    header: Text("Hoặc tự nhập ID Gói tùy chỉnh"),
                    footer: Text("ID thực tế sẽ dùng khi ký: \(previewFinalId)")
                ) {
                    TextField("Nhập ID gói", text: $customId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Toggle("Tự động nối thêm Mã Nhóm (Team ID)", isOn: $appendTeamId)

                    SwiftUI.Button("Dùng ID tùy chỉnh ở trên") {
                        let rawInput = customId.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectiveInput = rawInput.isEmpty ? defaultBundleId : rawInput
                        let finalId = appendTeamId
                            ? stripTrailingTeamSuffix(effectiveInput, teamID: teamId)
                            : effectiveInput
                        onComplete((finalId, appendTeamId))
                    }
                    .font(.headline)
                }
            }
            .navigationTitle("Quản lý & Chọn ID Gói")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Giữ Mặc định") {
                        onComplete((stripTrailingTeamSuffix(defaultBundleId, teamID: teamId), true))
                    }
                }
            }
        }
    }
}

struct CustomBundleIDModalView: View {
    let defaultBundleId: String
    let teamId: String
    var onComplete: ((String, Bool)) -> Void

    @State private var customId: String
    @State private var appendTeamId: Bool = true

    init(defaultBundleId: String, teamId: String, onComplete: @escaping ((String, Bool)) -> Void) {
        self.defaultBundleId = defaultBundleId
        self.teamId = teamId
        self.onComplete = onComplete
        self._customId = State(initialValue: defaultBundleId)
    }

    var previewFinalId: String {
        let base = customId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultBundleId
            : customId.trimmingCharacters(in: .whitespacesAndNewlines)
        if appendTeamId && !teamId.isEmpty {
            let cleanBase = stripTrailingTeamSuffix(base, teamID: teamId)
            return "\(cleanBase).\(teamId)"
        }
        return base
    }

    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Mã định danh gói (ID ứng dụng)"),
                    footer: Text("Đổi ID gói giúp bạn cài đặt bản sao (nhân bản ứng dụng) hoặc dùng lại một App ID đã đăng ký trước đó.")
                ) {
                    TextField("Nhập ID gói", text: $customId)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Toggle("Nối thêm Mã Nhóm (Team ID)", isOn: $appendTeamId)
                }

                Section(header: Text("Xem trước ID gói cuối cùng")) {
                    Text(previewFinalId)
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                if customId != defaultBundleId {
                    Section {
                        SwiftUI.Button("Khôi phục ID gốc (\(defaultBundleId))") {
                            customId = defaultBundleId
                        }
                    }
                }
            }
            .navigationTitle("Đổi ID Gói")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Mặc định") {
                        onComplete((stripTrailingTeamSuffix(defaultBundleId, teamID: teamId), true))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button("Tiếp tục") {
                        let rawInput = customId.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectiveInput = rawInput.isEmpty ? defaultBundleId : rawInput
                        let finalId = appendTeamId
                            ? stripTrailingTeamSuffix(effectiveInput, teamID: teamId)
                            : effectiveInput
                        onComplete((finalId, appendTeamId))
                    }
                    .font(.headline)
                }
            }
        }
    }
}

struct ExtensionRemovalModalView: View {
    let extensions: [InstallAppOperationContext.AppExtensionInfo]
    var onComplete: ([URL]) -> Void

    @State private var selectedForRemoval: Set<URL> = []

    var body: some View {
        NavigationView {
            List {
                Section(
                    header: Text("Các phần mở rộng (PlugIns) phát hiện trong IPA"),
                    footer: Text("Đánh dấu các phần mở rộng bạn muốn XÓA BỎ trước khi tạo Nhóm ứng dụng (App Groups) và lấy Hồ sơ cấp phép. Việc xóa các phần mở rộng không cần thiết giúp tiết kiệm số lượng App ID tối đa (10 ID/tuần) trên tài khoản Apple miễn phí.")
                ) {
                    ForEach(extensions) { ext in
                        SwiftUI.Button {
                            if selectedForRemoval.contains(ext.fileURL) {
                                selectedForRemoval.remove(ext.fileURL)
                            } else {
                                selectedForRemoval.insert(ext.fileURL)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedForRemoval.contains(ext.fileURL) ? "trash.circle.fill" : "circle")
                                    .foregroundColor(selectedForRemoval.contains(ext.fileURL) ? .red : .secondary)
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ext.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    Text(ext.bundleIdentifier)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(ext.formattedSize)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                Section {
                    SwiftUI.Button("Chọn xóa tất cả phần mở rộng") {
                        selectedForRemoval = Set(extensions.map { $0.fileURL })
                    }
                    .foregroundColor(.red)

                    SwiftUI.Button("Giữ lại tất cả") {
                        selectedForRemoval.removeAll()
                    }
                }
            }
            .navigationTitle("Gỡ Phần Mở Rộng / PlugIns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button(selectedForRemoval.isEmpty ? "Giữ tất cả" : "Xóa (\(selectedForRemoval.count)) & Tiếp tục") {
                        onComplete(Array(selectedForRemoval))
                    }
                    .font(.headline)
                }
            }
        }
    }
}

struct InfoPlistEditorModalView: View {
    @State var bundles: [InstallAppOperationContext.EditableInfoPlistBundle]
    var onComplete: ([String: [String: String]]) -> Void

    @State private var selectedBundleIndex: Int = 0
    @State private var newKeyName: String = ""
    @State private var newKeyValue: String = ""
    @State private var searchText: String = ""

    private let priorityKeys: [String] = [
        "CFBundleDisplayName",
        "CFBundleName",
        "CFBundleIdentifier",
        "CFBundleShortVersionString",
        "CFBundleVersion",
        "MinimumOSVersion",
        "UIFileSharingEnabled",
        "LSSupportsOpeningDocumentsInPlace",
        "UISupportsDocumentBrowser"
    ]

    var body: some View {
        NavigationView {
            Form {
                if bundles.count > 1 {
                    Section(header: Text("Chọn Gói (Ứng dụng chính / Extension)")) {
                        Picker("Gói", selection: $selectedBundleIndex) {
                            ForEach(bundles.indices, id: \.self) { idx in
                                Text(bundles[idx].title).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                if bundles.indices.contains(selectedBundleIndex) {
                    Section(header: Text("Tìm kiếm Khóa (Key)")) {
                        TextField("Lọc theo tên khóa...", text: $searchText)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    Section(
                        header: Text("Các Khóa Chính & Giá Trị Info.plist"),
                        footer: Text("Bạn có thể chỉnh sửa trực tiếp giá trị chuỗi/số/boolean (true/false) trong Info.plist trước khi ứng dụng được ký.")
                    ) {
                        ForEach(sortedKeys(for: bundles[selectedBundleIndex]), id: \.self) { key in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(key)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(priorityKeys.contains(key) ? .accentColor : .secondary)

                                TextField(
                                    "Giá trị",
                                    text: Binding(
                                        get: { bundles[selectedBundleIndex].entries[key] ?? "" },
                                        set: { bundles[selectedBundleIndex].entries[key] = $0 }
                                    )
                                )
                                .font(.system(.subheadline, design: .monospaced))
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete { indexSet in
                            let currentKeys = sortedKeys(for: bundles[selectedBundleIndex])
                            for idx in indexSet where currentKeys.indices.contains(idx) {
                                bundles[selectedBundleIndex].entries.removeValue(forKey: currentKeys[idx])
                            }
                        }
                    }

                    Section(header: Text("Thêm Khóa (Key) Mới")) {
                        TextField("Tên khóa (VD: UIFileSharingEnabled)", text: $newKeyName)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        TextField("Giá trị (VD: true, false, 15.0...)", text: $newKeyValue)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)

                        SwiftUI.Button("Thêm / Cập nhật Khóa") {
                            let trimmedKey = newKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmedKey.isEmpty else { return }
                            bundles[selectedBundleIndex].entries[trimmedKey] = newKeyValue
                            newKeyName = ""
                            newKeyValue = ""
                        }
                        .disabled(newKeyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        var map: [String: [String: String]] = [:]
                        for bundle in bundles {
                            map[bundle.id] = bundle.entries
                        }
                        onComplete(map)
                    }
                    .font(.headline)
                }
            }
        }
    }

    private func sortedKeys(for bundle: InstallAppOperationContext.EditableInfoPlistBundle) -> [String] {
        let allKeys = Array(bundle.entries.keys).filter {
            searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            $0.localizedCaseInsensitiveContains(searchText) ||
            (bundle.entries[$0]?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        return allKeys.sorted { lhs, rhs in
            let lIdx = priorityKeys.firstIndex(of: lhs) ?? Int.max
            let rIdx = priorityKeys.firstIndex(of: rhs) ?? Int.max
            if lIdx != rIdx { return lIdx < rIdx }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }
}

// MARK: - Default Pipeline UI Handler

public final class DefaultPipelineHandler: PipelineHandler {
    public static let shared = DefaultPipelineHandler()

    public init() {}

    public func updateProgress(stepName: String, stepIndex: Int, totalSteps: Int) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: Notification.Name("ALTPipelineProgressUpdated"),
                object: nil,
                userInfo: [
                    "stepName": stepName,
                    "stepIndex": stepIndex,
                    "totalSteps": totalSteps
                ]
            )
        }
    }

    public func requestCustomAppName(defaultName: String, bundleId: String) async -> String {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topVC = Self.topViewController() else {
                    continuation.resume(returning: defaultName)
                    return
                }

                let alert = UIAlertController(
                    title: "Đổi Tên Ứng Dụng",
                    message: "Nhập tên hiển thị tùy chỉnh cho \(defaultName)\n(\(bundleId))",
                    preferredStyle: .alert
                )

                alert.addTextField { textField in
                    textField.text = defaultName
                    textField.placeholder = defaultName
                    textField.clearButtonMode = .whileEditing
                }

                alert.addAction(UIAlertAction(title: "Giữ Mặc định", style: .cancel) { _ in
                    continuation.resume(returning: defaultName)
                })

                alert.addAction(UIAlertAction(title: "Áp dụng", style: .default) { _ in
                    let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
                    if let text = text, !text.isEmpty {
                        continuation.resume(returning: text)
                    } else {
                        continuation.resume(returning: defaultName)
                    }
                })

                topVC.present(alert, animated: true)
            }
        }
    }

    public func requestCustomBundleID(defaultBundleId: String, teamId: String) async -> (customID: String, appendTeamID: Bool) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topVC = Self.topViewController() else {
                    continuation.resume(returning: (defaultBundleId, true))
                    return
                }

                var hasResumed = false
                let view = CustomBundleIDModalView(defaultBundleId: defaultBundleId, teamId: teamId) { result in
                    guard !hasResumed else { return }
                    hasResumed = true
                    topVC.dismiss(animated: true) {
                        continuation.resume(returning: result)
                    }
                }

                let host = UIHostingController(rootView: view)
                host.isModalInPresentation = true
                topVC.present(host, animated: true)
            }
        }
    }

    public func requestSmartBundleIDSelection(
        appName: String,
        defaultBundleId: String,
        teamId: String,
        candidates: [InstallAppOperationContext.ReusableBundleIDCandidate]
    ) async -> (customID: String, appendTeamID: Bool) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topVC = Self.topViewController() else {
                    continuation.resume(returning: (defaultBundleId, true))
                    return
                }

                var hasResumed = false
                let view = SmartBundleIDCenterModalView(
                    appName: appName,
                    defaultBundleId: defaultBundleId,
                    teamId: teamId,
                    candidates: candidates
                ) { result in
                    guard !hasResumed else { return }
                    hasResumed = true
                    topVC.dismiss(animated: true) {
                        continuation.resume(returning: result)
                    }
                }

                let host = UIHostingController(rootView: view)
                host.isModalInPresentation = true
                topVC.present(host, animated: true)
            }
        }
    }

    public func requestExtensionRemoval(extensions: [InstallAppOperationContext.AppExtensionInfo]) async -> [URL] {
        guard !extensions.isEmpty else { return [] }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topVC = Self.topViewController() else {
                    continuation.resume(returning: [])
                    return
                }

                var hasResumed = false
                let view = ExtensionRemovalModalView(extensions: extensions) { urlsToRemove in
                    guard !hasResumed else { return }
                    hasResumed = true
                    topVC.dismiss(animated: true) {
                        continuation.resume(returning: urlsToRemove)
                    }
                }

                let host = UIHostingController(rootView: view)
                host.isModalInPresentation = true
                topVC.present(host, animated: true)
            }
        }
    }

    public func requestInfoPlistEdits(bundles: [InstallAppOperationContext.EditableInfoPlistBundle]) async -> [String: [String: String]] {
        guard !bundles.isEmpty else { return [:] }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                guard let topVC = Self.topViewController() else {
                    continuation.resume(returning: [:])
                    return
                }

                var hasResumed = false
                let view = InfoPlistEditorModalView(bundles: bundles) { editedMap in
                    guard !hasResumed else { return }
                    hasResumed = true
                    topVC.dismiss(animated: true) {
                        continuation.resume(returning: editedMap)
                    }
                }

                let host = UIHostingController(rootView: view)
                host.isModalInPresentation = true
                topVC.present(host, animated: true)
            }
        }
    }

    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let root: UIViewController?
        if let base = base {
            root = base
        } else {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let activeWindow = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.flatMap { $0.windows }.first
            root = activeWindow?.rootViewController
        }

        if let nav = root as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = root?.presentedViewController {
            return topViewController(base: presented)
        }
        return root
    }
}
