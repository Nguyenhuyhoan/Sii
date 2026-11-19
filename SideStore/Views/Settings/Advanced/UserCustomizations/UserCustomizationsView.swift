//
//  UserCustomizationsView.swift
//  SideStore
//
//  Created by Magesh K on 30/07/26.
//  Copyright © 2026 AltStore. All rights reserved.
//


import UIKit
import SwiftUI
import UniformTypeIdentifiers
import SideSign

// MARK: - Protocol & Adapter

public struct InfoPlistTarget: Identifiable {
    public let id: String          // original bundle ID of target
    public let name: String        // display name of app / extension
    public let isExtension: Bool
    public let initialPlist: [String: Any]

    public init(id: String, name: String, isExtension: Bool, initialPlist: [String: Any]) {
        self.id = id
        self.name = name
        self.isExtension = isExtension
        self.initialPlist = initialPlist
    }
}

public struct InfoPlistCustomizationResult {
    public let modifiedPlists: [String: [String: Any]] // keyed by InfoPlistTarget.id
    public let appendTeamID: Bool

    public init(modifiedPlists: [String: [String: Any]], appendTeamID: Bool) {
        self.modifiedPlists = modifiedPlists
        self.appendTeamID = appendTeamID
    }
}

public enum ProvisioningProfileChoice {
    case profile(ALTProvisioningProfile)
    case defaultProfile
    case none
}

public protocol UserCustomizationHandling: Sendable {
    func resolveBundleIDOverride(
        initialBundleID: String,
        appName: String,
        teamID: String,
        reusableAppIDs: [ReusableAppIDCandidate]
    ) async throws -> (customID: String, appendTeamID: Bool)?

    func resolveInfoPlistCustomization(
        targets: [InfoPlistTarget],
        initialBundleID: String,
        appendTeamID: Bool,
        installedAppIdentities: [String: String], // [authoritativeBundleID: appName]
        teamID: String
    ) async throws -> InfoPlistCustomizationResult?

    func resolveEntitlementsCustomization(
        targets: [EntitlementsTarget],
        teamType: ALTTeamType
    ) async throws -> [String: [String: Any]]?

    func resolveAppIconCustomization(appName: String) async throws -> URL?
    func resolveProvisioningProfileCustomization(appName: String, bundleID: String) async throws -> ProvisioningProfileChoice
}

public extension UserCustomizationHandling {
    func resolveBundleIDOverride(initialBundleID: String) async throws -> (customID: String, appendTeamID: Bool)? {
        try await resolveBundleIDOverride(
            initialBundleID: initialBundleID,
            appName: "",
            teamID: "",
            reusableAppIDs: []
        )
    }
}

final class UserCustomizationAdapter: UserCustomizationHandling, @unchecked Sendable {
    private weak var presentingViewController: UIViewController?

    init(presentingViewController: UIViewController?) {
        self.presentingViewController = presentingViewController
    }

    private func resolveTopPresenter() async -> UIViewController? {
        await MainActor.run {
            let base = self.presentingViewController ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?.rootViewController
            var top = base
            while let presented = top?.presentedViewController {
                top = presented
            }
            return top
        }
    }

    func resolveBundleIDOverride(
        initialBundleID: String,
        appName: String = "",
        teamID: String = "",
        reusableAppIDs: [ReusableAppIDCandidate] = []
    ) async throws -> (customID: String, appendTeamID: Bool)? {
        guard let presenter = await resolveTopPresenter() else { return nil }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                var hasResumed = false
                let resumeOnce: ((String, Bool)?) -> Void = { value in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }

                let view = BundleIDOverrideView(
                    initialBundleID: initialBundleID,
                    appName: appName,
                    teamID: teamID,
                    reusableAppIDs: reusableAppIDs
                ) { result in
                    presenter.dismiss(animated: true) {
                        resumeOnce(result)
                    }
                }
                let hosting = LifecycleAwareHostingController(rootView: view) {
                    resumeOnce(nil)
                }
                hosting.modalPresentationStyle = .overFullScreen
                hosting.modalTransitionStyle = .crossDissolve
                hosting.view.backgroundColor = .clear
                presenter.present(hosting, animated: true)
            }
        }
    }

    func resolveInfoPlistCustomization(
        targets: [InfoPlistTarget],
        initialBundleID: String,
        appendTeamID: Bool,
        installedAppIdentities: [String: String],
        teamID: String
    ) async throws -> InfoPlistCustomizationResult? {
        guard let presenter = await resolveTopPresenter() else { return nil }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                var hasResumed = false
                let resumeOnce: (InfoPlistCustomizationResult?) -> Void = { value in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }

                let view = InfoPlistEditorView(
                    targets: targets,
                    initialBundleID: initialBundleID,
                    initialAppendTeamID: appendTeamID,
                    installedAppIdentities: installedAppIdentities,
                    teamID: teamID
                ) { result in
                    presenter.dismiss(animated: true) {
                        resumeOnce(result)
                    }
                }
                let hosting = LifecycleAwareHostingController(rootView: view) {
                    resumeOnce(nil)
                }
                hosting.modalPresentationStyle = .overFullScreen
                hosting.modalTransitionStyle = .crossDissolve
                hosting.view.backgroundColor = .clear
                presenter.present(hosting, animated: true)
            }
        }
    }

    func resolveEntitlementsCustomization(
        targets: [EntitlementsTarget],
        teamType: ALTTeamType
    ) async throws -> [String: [String: Any]]? {
        guard let presenter = await resolveTopPresenter() else { return nil }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                var hasResumed = false
                let resumeOnce: ([String: [String: Any]]?) -> Void = { value in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }

                let view = EntitlementsEditorView(
                    targets: targets,
                    teamType: teamType
                ) { result in
                    presenter.dismiss(animated: true) {
                        resumeOnce(result)
                    }
                }
                let hosting = LifecycleAwareHostingController(rootView: view) {
                    resumeOnce(nil)
                }
                hosting.modalPresentationStyle = .overFullScreen
                hosting.modalTransitionStyle = .crossDissolve
                hosting.view.backgroundColor = .clear
                presenter.present(hosting, animated: true)
            }
        }
    }

    func resolveAppIconCustomization(appName: String) async throws -> URL? {
        guard let presenter = await resolveTopPresenter() else { return nil }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                var hasResumed = false
                let resumeOnce: (URL?) -> Void = { value in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }

                let view = AppIconCustomizationView(appName: appName) { selectedURL in
                    presenter.dismiss(animated: true) {
                        resumeOnce(selectedURL)
                    }
                }
                let hosting = LifecycleAwareHostingController(rootView: view) {
                    resumeOnce(nil)
                }
                hosting.modalPresentationStyle = .overFullScreen
                hosting.modalTransitionStyle = .crossDissolve
                hosting.view.backgroundColor = .clear
                presenter.present(hosting, animated: true)
            }
        }
    }

    func resolveProvisioningProfileCustomization(appName: String, bundleID: String) async throws -> ProvisioningProfileChoice {
        guard let presenter = await resolveTopPresenter() else { return .none }
        return await withCheckedContinuation { continuation in
            Task { @MainActor in
                var hasResumed = false
                let resumeOnce: (ProvisioningProfileChoice) -> Void = { value in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(returning: value)
                }

                let view = ProvisioningProfileCustomizationView(appName: appName, bundleID: bundleID) { choice in
                    presenter.dismiss(animated: true) {
                        resumeOnce(choice)
                    }
                }
                let hosting = LifecycleAwareHostingController(rootView: view) {
                    resumeOnce(.none)
                }
                hosting.modalPresentationStyle = .overFullScreen
                hosting.modalTransitionStyle = .crossDissolve
                hosting.view.backgroundColor = .clear
                presenter.present(hosting, animated: true)
            }
        }
    }
}

private final class LifecycleAwareHostingController<Content: View>: UIHostingController<Content> {
    private var onDismiss: (() -> Void)?

    init(rootView: Content, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || isMovingFromParent {
            onDismiss?()
            onDismiss = nil
        }
    }
}

// MARK: - 1. Smart Bundle ID Selection & Override View (Chuẩn CSS Tab Cài Đặt)

struct BundleIDOverrideView: View {
    let initialBundleID: String
    let appName: String
    let teamID: String
    let reusableAppIDs: [ReusableAppIDCandidate]
    let onComplete: ((String, Bool)?) -> Void

    @State private var isManualEntryExpanded: Bool = false
    @State private var bundleIDText: String
    @State private var appendTeamID: Bool = true

    init(
        initialBundleID: String,
        appName: String = "",
        teamID: String = "",
        reusableAppIDs: [ReusableAppIDCandidate] = [],
        onComplete: @escaping ((String, Bool)?) -> Void
    ) {
        self.initialBundleID = initialBundleID
        self.appName = appName
        self.teamID = teamID
        self.reusableAppIDs = reusableAppIDs
        self.onComplete = onComplete
        self._bundleIDText = State(initialValue: initialBundleID)
    }

    private func remainingDaysText(for date: Date?) -> String {
        guard let date else { return "Khả dụng" }
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return "Hết hạn" }
        let days = Int(ceil(seconds / 86400.0))
        return "Còn \(days) ngày"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                // Header
                VStack(spacing: 5) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                        Text(appName.isEmpty ? "Chọn Định Danh (App ID)" : "Cài đặt: \(appName)")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.black)
                            .lineLimit(1)
                    }

                    Text("Tự động gộp mọi phần mở rộng vào 1 ID chính duy nhất")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(Color(white: 0.42))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 2)

                // Lựa chọn 1: Dùng ID gốc của IPA
                Button {
                    onComplete((initialBundleID, true))
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: "plus.app.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text("Dùng ID gốc của IPA")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(.black)
                                Spacer()
                                Text("Mặc định")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2.5)
                                    .background(
                                        Capsule()
                                            .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.12))
                                    )
                            }

                            Text(initialBundleID)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(Color(white: 0.38))
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(white: 0.97))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.45), lineWidth: 1.2)
                    )
                }
                .buttonStyle(.plain)

                // Lựa chọn 2: Kho ID Trống khả dụng (tái sử dụng tốn 0 slot)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Tái sử dụng ID sẵn có (Tốn 0 ID)", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.62, blue: 0.28))
                        Spacer()
                        Text("\(reusableAppIDs.count) khả dụng")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(Color(white: 0.45))
                    }

                    if reusableAppIDs.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 14))
                                .foregroundColor(Color(white: 0.5))
                            Text("Hiện không có ID dư thừa nào ngoài các ứng dụng đang chạy.")
                                .font(.system(size: 12.5))
                                .foregroundColor(Color(white: 0.45))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(white: 0.96))
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 7) {
                                ForEach(reusableAppIDs) { candidate in
                                    Button {
                                        onComplete((candidate.baseBundleIdentifier, true))
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "bolt.shield.fill")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(Color(red: 0.18, green: 0.72, blue: 0.34))
                                                .frame(width: 28, height: 28)
                                                .background(
                                                    Circle()
                                                        .fill(Color(red: 0.18, green: 0.72, blue: 0.34).opacity(0.14))
                                                )

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(candidate.name)
                                                    .font(.system(size: 13.5, weight: .semibold))
                                                    .foregroundColor(.black)
                                                    .lineLimit(1)

                                                Text(candidate.baseBundleIdentifier)
                                                    .font(.system(size: 11.5, weight: .regular, design: .monospaced))
                                                    .foregroundColor(Color(white: 0.40))
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }

                                            Spacer(minLength: 4)

                                            VStack(alignment: .trailing, spacing: 2) {
                                                Text("0 ID")
                                                    .font(.system(size: 10.5, weight: .bold))
                                                    .foregroundColor(Color(red: 0.12, green: 0.62, blue: 0.28))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color(red: 0.18, green: 0.72, blue: 0.34).opacity(0.15))
                                                    )

                                                Text(remainingDaysText(for: candidate.expirationDate))
                                                    .font(.system(size: 10.5, weight: .medium))
                                                    .foregroundColor(Color(white: 0.48))
                                            }
                                        }
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color.white)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(2)
                        }
                        .frame(maxHeight: min(CGFloat(reusableAppIDs.count) * 62.0, 210.0))
                    }
                }
                .padding(11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(white: 0.97))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )

                // Lựa chọn 3: Tự nhập Bundle ID tùy chỉnh
                VStack(spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isManualEntryExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Tự nhập mã Bundle ID tùy chỉnh khác")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Image(systemName: isManualEntryExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(Color(white: 0.32))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(white: 0.95))
                        )
                    }
                    .buttonStyle(.plain)

                    if isManualEntryExpanded {
                        VStack(spacing: 8) {
                            TextField("com.example.app", text: $bundleIDText)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .font(.system(size: 13.5, design: .monospaced))
                                .foregroundColor(.black)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.white)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                )

                            Toggle("Tự động gắn hậu tố Mã Nhóm (Team ID)", isOn: $appendTeamID)
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(.black)
                                .tint(Color(red: 0.04, green: 0.52, blue: 1.0))

                            Button {
                                let trimmed = bundleIDText.trimmingCharacters(in: .whitespacesAndNewlines)
                                let finalID = trimmed.isEmpty ? initialBundleID : trimmed
                                onComplete((finalID, appendTeamID))
                            } label: {
                                Text("Áp dụng ID tùy chỉnh này")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Color(red: 0.04, green: 0.52, blue: 1.0))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(white: 0.96))
                        )
                    }
                }

                // Nút Hủy
                Button {
                    onComplete(nil)
                } label: {
                    Text("Hủy cài đặt")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color(red: 0.90, green: 0.22, blue: 0.21))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(red: 0.90, green: 0.22, blue: 0.21).opacity(0.10))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .environment(\.colorScheme, .light)
        }
    }
}

// MARK: - 2. Info.plist Editor View

struct InfoPlistEditorView: View {
    let targets: [InfoPlistTarget]
    let initialBundleID: String
    let initialAppendTeamID: Bool
    let installedAppIdentities: [String: String]
    let teamID: String
    let onComplete: (InfoPlistCustomizationResult?) -> Void

    @State private var selectedTargetIndex: Int = 0
    @State private var targetPlists: [String: [String: Any]]
    @State private var appendTeamID: Bool
    @State private var searchText: String = ""

    @State private var appDisplayName: String = ""
    @State private var appBundleID: String = ""
    @State private var appVersion: String = ""
    @State private var appBuildVersion: String = ""
    @State private var minOSVersion: String = ""
    @State private var fileSharingEnabled: Bool = false
    @State private var supportsDocumentsBrowser: Bool = false
    @State private var requiresFullScreen: Bool = false

    @State private var showAddKeyAlert: Bool = false
    @State private var newKeyName: String = ""
    @State private var newKeyValue: String = ""

    init(
        targets: [InfoPlistTarget],
        initialBundleID: String,
        initialAppendTeamID: Bool,
        installedAppIdentities: [String: String],
        teamID: String,
        onComplete: @escaping (InfoPlistCustomizationResult?) -> Void
    ) {
        self.targets = targets
        self.initialBundleID = initialBundleID
        self.initialAppendTeamID = initialAppendTeamID
        self.installedAppIdentities = installedAppIdentities
        self.teamID = teamID
        self.onComplete = onComplete

        var map: [String: [String: Any]] = [:]
        for t in targets {
            map[t.id] = t.initialPlist
        }
        self._targetPlists = State(initialValue: map)
        self._appendTeamID = State(initialValue: initialAppendTeamID)

        let mainPlist = targets.first?.initialPlist ?? [:]
        let displayName = (mainPlist["CFBundleDisplayName"] as? String)
            ?? (mainPlist["CFBundleName"] as? String)
            ?? ""
        let bundleID = (mainPlist["CFBundleIdentifier"] as? String) ?? initialBundleID
        let shortVersion = (mainPlist["CFBundleShortVersionString"] as? String) ?? ""
        let buildVer = (mainPlist["CFBundleVersion"] as? String) ?? ""
        let minOS = (mainPlist["MinimumOSVersion"] as? String) ?? ""
        let fileSharing = (mainPlist["UIFileSharingEnabled"] as? Bool) ?? false
        let docBrowser = (mainPlist["UISupportsDocumentBrowser"] as? Bool) ?? false
        let fullScreen = (mainPlist["UIRequiresFullScreen"] as? Bool) ?? false

        self._appDisplayName = State(initialValue: displayName)
        self._appBundleID = State(initialValue: bundleID)
        self._appVersion = State(initialValue: shortVersion)
        self._appBuildVersion = State(initialValue: buildVer)
        self._minOSVersion = State(initialValue: minOS)
        self._fileSharingEnabled = State(initialValue: fileSharing)
        self._supportsDocumentsBrowser = State(initialValue: docBrowser)
        self._requiresFullScreen = State(initialValue: fullScreen)
    }

    private var currentTarget: InfoPlistTarget {
        targets[min(max(selectedTargetIndex, 0), max(targets.count - 1, 0))]
    }

    private var effectiveMainBundleID: String {
        let trimmed = appBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? initialBundleID : trimmed
        if appendTeamID && !teamID.isEmpty && !base.hasSuffix(".\(teamID)") {
            return "\(base).\(teamID)"
        }
        return base
    }

    private var matchedExistingAppName: String? {
        installedAppIdentities[effectiveMainBundleID]
    }

    private var sortedKeys: [String] {
        let dict = targetPlists[currentTarget.id] ?? [:]
        let allKeys = dict.keys.sorted()
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return allKeys
        }
        return allKeys.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private func syncQuickFieldsIntoMainPlist() {
        guard let mainTarget = targets.first else { return }
        var mainDict = targetPlists[mainTarget.id] ?? [:]

        let trimmedName = appDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            mainDict["CFBundleDisplayName"] = trimmedName
        }

        let trimmedID = appBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        mainDict["CFBundleIdentifier"] = trimmedID.isEmpty ? initialBundleID : trimmedID

        if !appVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mainDict["CFBundleShortVersionString"] = appVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !appBuildVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mainDict["CFBundleVersion"] = appBuildVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if !minOSVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mainDict["MinimumOSVersion"] = minOSVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        mainDict["UIFileSharingEnabled"] = fileSharingEnabled
        mainDict["UISupportsDocumentBrowser"] = supportsDocumentsBrowser
        mainDict["UIRequiresFullScreen"] = requiresFullScreen

        targetPlists[mainTarget.id] = mainDict
    }

    var body: some View {
        NavigationView {
            Form {
                if targets.count > 1 {
                    Section(header: Text("Thành phần gói ứng dụng")) {
                        Picker("Mục tiêu", selection: $selectedTargetIndex) {
                            ForEach(targets.indices, id: \.self) { idx in
                                let t = targets[idx]
                                Text(t.isExtension ? "🧩 \(t.name)" : "📱 \(t.name)")
                                    .tag(idx)
                            }
                        }
                    }
                }

                if selectedTargetIndex == 0 {
                    Section(header: Text("Thông tin định danh chính")) {
                        HStack {
                            Text("Tên hiển thị")
                            Spacer()
                            TextField("Tên ứng dụng", text: $appDisplayName)
                                .multilineTextAlignment(.trailing)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Bundle Identifier")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("com.example.app", text: $appBundleID)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .font(.system(size: 14, design: .monospaced))
                        }

                        Toggle("Gắn hậu tố Mã Nhóm (.\(teamID))", isOn: $appendTeamID)

                        if let existingName = matchedExistingAppName {
                            Label("Cài đè / Cập nhật lên: \(existingName)", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                                .font(.footnote)
                                .foregroundColor(.blue)
                        } else {
                            Label("Cài đặt như ứng dụng mới độc lập", systemImage: "plus.app.fill")
                                .font(.footnote)
                                .foregroundColor(.green)
                        }
                    }

                    Section(header: Text("Phiên bản & Tương thích")) {
                        HStack {
                            Text("Phiên bản (Version)")
                            Spacer()
                            TextField("1.0", text: $appVersion)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("Số bản dựng (Build)")
                            Spacer()
                            TextField("1", text: $appBuildVersion)
                                .multilineTextAlignment(.trailing)
                        }
                        HStack {
                            Text("iOS tối thiểu")
                            Spacer()
                            TextField("14.0", text: $minOSVersion)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Section(header: Text("Tính năng tiện ích")) {
                        Toggle("Mở khóa Chia sẻ Tệp (iTunes File Sharing)", isOn: $fileSharingEnabled)
                        Toggle("Hiện thư mục trong ứng dụng Tệp (Files)", isOn: $supportsDocumentsBrowser)
                        Toggle("Bắt buộc Toàn màn hình (Full Screen)", isOn: $requiresFullScreen)
                    }
                }

                Section(header: HStack {
                    Text("Khóa Info.plist nâng cao (\(sortedKeys.count))")
                    Spacer()
                    Button {
                        newKeyName = ""
                        newKeyValue = ""
                        showAddKeyAlert = true
                    } label: {
                        Label("Thêm khóa", systemImage: "plus.circle.fill")
                            .font(.caption)
                    }
                }) {
                    TextField("Tìm kiếm khóa Info.plist...", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    ForEach(sortedKeys, id: \.self) { key in
                        let rawValue = targetPlists[currentTarget.id]?[key]
                        if let boolVal = rawValue as? Bool {
                            Toggle(key, isOn: Binding(
                                get: { (targetPlists[currentTarget.id]?[key] as? Bool) ?? boolVal },
                                set: { newVal in
                                    var dict = targetPlists[currentTarget.id] ?? [:]
                                    dict[key] = newVal
                                    targetPlists[currentTarget.id] = dict
                                }
                            ))
                            .font(.system(size: 13, design: .monospaced))
                        } else if let strVal = rawValue as? String {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(key)
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.secondary)
                                TextField("Giá trị", text: Binding(
                                    get: { (targetPlists[currentTarget.id]?[key] as? String) ?? strVal },
                                    set: { newVal in
                                        var dict = targetPlists[currentTarget.id] ?? [:]
                                        dict[key] = newVal
                                        targetPlists[currentTarget.id] = dict
                                    }
                                ))
                                .font(.system(size: 13.5))
                            }
                        } else {
                            HStack {
                                Text(key)
                                    .font(.system(size: 12.5, design: .monospaced))
                                Spacer()
                                Text(String(describing: rawValue ?? ""))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var dict = targetPlists[currentTarget.id] ?? [:]
                        for idx in offsets {
                            let keyToRemove = sortedKeys[idx]
                            dict.removeValue(forKey: keyToRemove)
                        }
                        targetPlists[currentTarget.id] = dict
                    }
                }
            }
            .navigationTitle("Tùy chỉnh Info.plist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        onComplete(nil)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tiếp tục") {
                        syncQuickFieldsIntoMainPlist()
                        let res = InfoPlistCustomizationResult(
                            modifiedPlists: targetPlists,
                            appendTeamID: appendTeamID
                        )
                        onComplete(res)
                    }
                }
            }
            .alert("Thêm khóa Info.plist", isPresented: $showAddKeyAlert) {
                TextField("Tên khóa (Key)", text: $newKeyName)
                TextField("Giá trị chuỗi (Value)", text: $newKeyValue)
                Button("Hủy", role: .cancel) {}
                Button("Thêm") {
                    let k = newKeyName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !k.isEmpty else { return }
                    var dict = targetPlists[currentTarget.id] ?? [:]
                    dict[k] = newKeyValue
                    targetPlists[currentTarget.id] = dict
                }
            }
        }
        .environment(\.colorScheme, .light)
    }
}

// MARK: - 3. App Icon Customization View

struct AppIconCustomizationView: View {
    let appName: String
    let onComplete: (URL?) -> Void

    @State private var selectedImage: UIImage?
    @State private var selectedFileURL: URL?
    @State private var isShowingFilePicker: Bool = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("Biểu tượng Ứng dụng")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)

                Text("Chọn ảnh mới cho '\(appName)' hoặc giữ nguyên biểu tượng mặc định.")
                    .font(.system(size: 13))
                    .foregroundColor(Color(white: 0.42))
                    .multilineTextAlignment(.center)

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 84, height: 84)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(white: 0.95))
                        .frame(width: 84, height: 84)
                        .overlay(
                            Image(systemName: "app.dashed")
                                .font(.system(size: 32))
                                .foregroundColor(Color(white: 0.55))
                        )
                }

                Button {
                    isShowingFilePicker = true
                } label: {
                    Label("Chọn ảnh từ Tệp...", systemImage: "photo.on.rectangle")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button {
                        onComplete(nil)
                    } label: {
                        Text("Dùng mặc định")
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundColor(Color(white: 0.3))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color(white: 0.93))
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        onComplete(selectedFileURL)
                    } label: {
                        Text("Áp dụng")
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color(red: 0.04, green: 0.52, blue: 1.0))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 22, x: 0, y: 10)
            )
            .padding(.horizontal, 28)
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.image],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessed { url.stopAccessingSecurityScopedResource() }
                    }
                    if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                        let tempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent("custom_icon_\(UUID().uuidString).png")
                        if let pngData = img.pngData() {
                            try? pngData.write(to: tempURL)
                            selectedImage = img
                            selectedFileURL = tempURL
                        }
                    }
                }
            }
            .environment(\.colorScheme, .light)
        }
    }
}

// MARK: - 4. Provisioning Profile Customization View

struct ProvisioningProfileCustomizationView: View {
    let appName: String
    let bundleID: String
    let onComplete: (ProvisioningProfileChoice) -> Void

    @State private var isShowingFilePicker: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("Hồ sơ Cấp phép (Profile)")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)

                Text("Ứng dụng: \(appName)\n(\(bundleID))")
                    .font(.system(size: 12.5))
                    .foregroundColor(Color(white: 0.42))
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    isShowingFilePicker = true
                } label: {
                    Label("Nhập tệp .mobileprovision...", systemImage: "doc.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.04, green: 0.52, blue: 1.0))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.12))
                        )
                }
                .buttonStyle(.plain)

                Button {
                    onComplete(.defaultProfile)
                } label: {
                    Text("Tự động dùng Hồ sơ mặc định")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color(red: 0.04, green: 0.52, blue: 1.0))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.18), radius: 22, x: 0, y: 10)
            )
            .padding(.horizontal, 28)
            .fileImporter(
                isPresented: $isShowingFilePicker,
                allowedContentTypes: [.data, .item],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer {
                        if accessed { url.stopAccessingSecurityScopedResource() }
                    }
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("custom_\(UUID().uuidString).mobileprovision")
                    do {
                        if FileManager.default.fileExists(atPath: tempURL.path) {
                            try FileManager.default.removeItem(at: tempURL)
                        }
                        try FileManager.default.copyItem(at: url, to: tempURL)
                        if let profile = ALTProvisioningProfile(url: tempURL) {
                            onComplete(.profile(profile))
                        } else {
                            errorMessage = "Tệp .mobileprovision không hợp lệ."
                        }
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
            .environment(\.colorScheme, .light)
        }
    }
}
