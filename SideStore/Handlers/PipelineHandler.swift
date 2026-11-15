
//
//  PipelineHandler.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit
import SwiftUI
import SideSign

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (Đồng bộ 100% với SettingsViewController)
private struct PipelineCSSTheme {
    static let white = UIColor.white
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0) // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0) // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0) // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0) // #dc3545
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0) // #ff00ff

    static let cornerRadius: CGFloat = 15.0

    // SwiftUI Colors (Đồng bộ với SettingsViewController)
    static let suiPrimary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)
    static let suiSecondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
    static let suiGreen = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)
    static let suiRed = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)
    static let suiMagenta = SwiftUI.Color(red: 255/255, green: 0/255, blue: 255/255)
    static let suiPureBlack = SwiftUI.Color.black
    static let suiCardBackground = SwiftUI.Color.white
    static let suiInnerRowBackground = SwiftUI.Color(red: 246/255, green: 248/255, blue: 251/255)
    static let suiBorder = SwiftUI.Color(red: 218/255, green: 224/255, blue: 233/255)
    static let suiInnerBorder = SwiftUI.Color(red: 222/255, green: 228/255, blue: 236/255)

    static var suiPageGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255),
                SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct PipelineBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - 🧩 KHUNG LỰA CHỌN XỬ LÝ APP ID HIỆN Ở GIỮA MÀN HÌNH (CHỈ GỒM 4 CÁCH XỬ LÝ & NÚT HỦY)
private enum ExtensionAlertChoice {
    case keepAllMainProfile
    case keepAllSeparateAppIDs
    case removeAll
    case chooseCustom
    case cancel
}

private struct ExtensionDecisionCenterModalView: SwiftUI.View {
    let extensionCount: Int
    let onSelect: (ExtensionAlertChoice) -> Void

    var body: some SwiftUI.View {
        ZStack {
            // Lớp nền tối mờ nhẹ phía sau khung giữa màn hình
            SwiftUI.Color.black.opacity(0.42)
                .ignoresSafeArea()

            // Khung chính nằm giữa màn hình (Đồng bộ chuẩn thẻ SettingsViewController)
            VStack(spacing: 12) {
                // Khối thẻ trắng chứa đúng 4 cách xử lý App ID
                VStack(spacing: 9) {
                    // Cách 1: Giữ tất cả (Dùng chung Profile chính)
                    optionButton(
                        icon: "shield.lefthalf.filled.badge.checkmark",
                        iconColor: PipelineCSSTheme.suiGreen,
                        title: "Giữ tất cả (Dùng hồ sơ chính)",
                        subtitle: "Giữ nguyên tiện ích, không tốn thêm App ID",
                        badge: "★ Khuyên dùng",
                        badgeColor: PipelineCSSTheme.suiGreen,
                        borderColor: PipelineCSSTheme.suiGreen.opacity(0.55)
                    ) {
                        onSelect(.keepAllMainProfile)
                    }

                    // Cách 2: Giữ tất cả (Tạo App ID riêng)
                    optionButton(
                        icon: "key.radiowaves.forward.fill",
                        iconColor: PipelineCSSTheme.suiPrimary,
                        title: "Giữ tất cả (Tạo App ID riêng)",
                        subtitle: "Đăng ký từng App ID riêng cho mỗi tiện ích",
                        badge: nil,
                        badgeColor: PipelineCSSTheme.suiPrimary,
                        borderColor: PipelineCSSTheme.suiInnerBorder
                    ) {
                        onSelect(.keepAllSeparateAppIDs)
                    }

                    // Cách 3: Tùy chọn từng tiện ích
                    optionButton(
                        icon: "checklist",
                        iconColor: PipelineCSSTheme.suiSecondary,
                        title: "Tùy chọn từng tiện ích...",
                        subtitle: "Chọn các tiện ích muốn giữ hoặc gỡ bỏ",
                        badge: "\(extensionCount) mục",
                        badgeColor: PipelineCSSTheme.suiSecondary,
                        borderColor: PipelineCSSTheme.suiInnerBorder
                    ) {
                        onSelect(.chooseCustom)
                    }

                    // Cách 4: Gỡ bỏ tất cả tiện ích
                    optionButton(
                        icon: "trash.fill",
                        iconColor: PipelineCSSTheme.suiRed,
                        title: "Gỡ bỏ tất cả tiện ích",
                        subtitle: "Chỉ cài ứng dụng chính để tiết kiệm App ID",
                        badge: "Tiết kiệm ID",
                        badgeColor: PipelineCSSTheme.suiRed,
                        borderColor: PipelineCSSTheme.suiRed.opacity(0.38)
                    ) {
                        onSelect(.removeAll)
                    }
                }
                .padding(12)
                .background(PipelineCSSTheme.suiCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous)
                        .stroke(PipelineCSSTheme.suiBorder, lineWidth: 1.0)
                )
                .shadow(color: PipelineCSSTheme.suiPrimary.opacity(0.08), radius: 10, x: 0, y: 5)

                // Nút Hủy cài đặt
                SwiftUI.Button {
                    onSelect(.cancel)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        SwiftUI.Text("Hủy cài đặt")
                            .font(.system(size: 15.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12.5)
                    .background(
                        LinearGradient(
                            colors: [PipelineCSSTheme.suiRed, PipelineCSSTheme.suiMagenta.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: PipelineCSSTheme.suiRed.opacity(0.32), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PipelineBounceButtonStyle())
            }
            .padding(14)
            .background(PipelineCSSTheme.suiPageGradient)
            .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius + 3, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius + 3, style: .continuous)
                    .stroke(SwiftUI.Color.white.opacity(0.85), lineWidth: 1.5)
            )
            .shadow(color: SwiftUI.Color.black.opacity(0.22), radius: 22, x: 0, y: 10)
            .frame(maxWidth: 380)
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func optionButton(
        icon: String,
        iconColor: SwiftUI.Color,
        title: String,
        subtitle: String,
        badge: String?,
        badgeColor: SwiftUI.Color,
        borderColor: SwiftUI.Color,
        action: @escaping () -> Void
    ) -> some SwiftUI.View {
        SwiftUI.Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 6) {
                        SwiftUI.Text(title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(PipelineCSSTheme.suiPureBlack)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)

                        if let badge = badge {
                            SwiftUI.Text(badge)
                                .font(.system(size: 10, weight: .heavy))
                                .padding(.horizontal, 6.5)
                                .padding(.vertical, 2)
                                .background(badgeColor.opacity(0.15))
                                .foregroundColor(badgeColor)
                                .clipShape(Capsule())
                        }
                    }

                    SwiftUI.Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(PipelineCSSTheme.suiPureBlack.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                SwiftUI.Image(systemName: "chevron.right")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(PipelineCSSTheme.suiPrimary.opacity(0.75))
            }
            .padding(11)
            .background(PipelineCSSTheme.suiInnerRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.2)
            )
        }
        .buttonStyle(PipelineBounceButtonStyle())
    }
}

// MARK: - 🚀 PIPELINE HANDLER CHÍNH
final class PipelineHandler: PipelineExecutionHandler,
                             PreflightChecksHandler,
                             EntitlementsReviewHandler,
                             ExtensionRemovalHandler,
                             UnsupportedVersionHandler,
                             InstallAppHandler,
                             UserCustomizationHandler,
                             Sendable
{
    var preflightChecksHandler: PreflightChecksHandler { self }
    var entitlementsReviewHandler: EntitlementsReviewHandler { self }
    var extensionRemovalHandler: ExtensionRemovalHandler { self }
    var unsupportedVersionHandler: UnsupportedVersionHandler { self }
    var installAppHandler: InstallAppHandler { self }
    var userCustomizationHandler: UserCustomizationHandler { self }

    let isResignActive: Bool
    private let presenterProvider: PresenterProvider?

    init(
        isResignActive: Bool = false,
        presenterProvider: PresenterProvider? = nil
    ) {
        self.isResignActive = isResignActive
        self.presenterProvider = presenterProvider
    }

    @MainActor
    private var isPresenterAvailable: Bool {
        return self.activePresenter != nil
    }

    @MainActor
    private var activePresenter: UIViewController? {
        return self.presenterProvider?()
    }

    @MainActor
    func resolveBundleIDMismatch(targetID: String, activeEffectiveID: String) async -> Bool {
        guard let presenter = self.activePresenter else {
            return false
        }
        
        let title = "Không Khớp Bundle ID"
        let message = String(
            format: "Ứng dụng bạn đang cài đặt có Bundle ID (%@) không khớp với ứng dụng đang hoạt động (%@). Bạn có muốn tiếp tục không?",
            targetID,
            activeEffectiveID
        )
        
        return await withCheckedContinuation { continuation in
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.view.tintColor = PipelineCSSTheme.blue
            alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alertController.addAction(UIAlertAction(title: "Tiếp tục", style: .default) { _ in
                continuation.resume(returning: true)
            })
            presenter.present(alertController, animated: true)
        }
    }

    @MainActor
    func reviewPermissions(_ permissions: [ALTEntitlement], for app: AppProtocol, mode: PermissionReviewMode) async throws {
        guard let presenter = self.activePresenter else {
            throw OperationError.invalidParameters("PipelineHandler: Không thể kiểm tra quyền vì màn hình hiển thị không khả dụng")
        }
        let reviewPermissionsViewController = ReviewPermissionsViewController(app: app, permissions: permissions, mode: mode)
        let navigationController = UINavigationController(rootViewController: reviewPermissionsViewController)
        
        defer {
            navigationController.dismiss(animated: true)
        }
        
        try await withCheckedThrowingContinuation { continuation in
            reviewPermissionsViewController.completionHandler = { result in
                continuation.resume(with: result)
            }
            
            presenter.present(navigationController, animated: true)
        }
    }

    // MARK: - ✨ KHUNG HIỆN Ở GIỮA MÀN HÌNH (CHỈ CHỨA 4 CÁCH XỬ LÝ APP ID & NÚT HỦY) ✨
    @MainActor
    func selectAppExtensionsToRemove(
        appBundle: ALTApplication,
        localAppExtensions: [ALTApplication],
        excessExtensions: Set<ALTApplication>
    ) async throws -> ExtensionRemovalDecision {
        guard let presenter = self.activePresenter else {
            return .removeSelected(excessExtensions)
        }
        
        let step1Choice: ExtensionAlertChoice = await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: (ExtensionAlertChoice) -> Void = { choice in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: choice)
            }

            var hostingController: UIHostingController<ExtensionDecisionCenterModalView>?

            let modalView = ExtensionDecisionCenterModalView(
                extensionCount: appBundle.appExtensions.count
            ) { choice in
                if let hc = hostingController, hc.presentingViewController != nil {
                    hc.dismiss(animated: true) {
                        resumeOnce(choice)
                    }
                } else {
                    resumeOnce(choice)
                }
            }

            let hc = UIHostingController(rootView: modalView)
            hostingController = hc
            hc.overrideUserInterfaceStyle = .light
            hc.view.backgroundColor = .clear
            hc.modalPresentationStyle = .overFullScreen
            hc.modalTransitionStyle = .crossDissolve

            presenter.present(hc, animated: true) {
                if presenter.presentedViewController == nil && !hc.isViewLoaded {
                    resumeOnce(.cancel)
                }
            }
        }

        switch step1Choice {
        case .cancel:
            throw OperationError.cancelled
        case .keepAllMainProfile:
            return .keepAll(useMainProfile: true)
        case .keepAllSeparateAppIDs:
            return .keepAll(useMainProfile: false)
        case .removeAll:
            return .removeAll
        case .chooseCustom:
            return try await presentCustomExtensionPicker(for: appBundle, from: presenter)
        }
    }

    @MainActor
    private func presentCustomExtensionPicker(
        for appBundle: ALTApplication,
        from presenter: UIViewController
    ) async throws -> ExtensionRemovalDecision {
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let resumeOnce: (Result<ExtensionRemovalDecision, Error>) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            let popoverContentController = AppExtensionViewHostingController(extensions: appBundle.appExtensions) { selection in
                resumeOnce(.success(.removeSelected(Set(selection))))
            }
            popoverContentController.overrideUserInterfaceStyle = .light

            #if !os(tvOS)
            popoverContentController.modalPresentationStyle = .pageSheet
            if #available(iOS 15.0, *), let sheet = popoverContentController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
            presenter.present(popoverContentController, animated: true) {
                if presenter.presentedViewController == nil && !popoverContentController.isViewLoaded {
                    resumeOnce(.failure(OperationError.invalidParameters("Không thể mở danh sách tiện ích mở rộng.")))
                }
            }
            #else
            popoverContentController.modalPresentationStyle = .blurOverFullScreen
            presenter.present(popoverContentController, animated: true)
            #endif
        }
    }

    @MainActor
    func resolveUnsupportediOSVersion(errorDescription: String, appName: String, compatibleVersion: String) async throws -> Bool {
        guard let presenter = self.activePresenter else {
            return false
        }
        
        let title = "Phiên Bản iOS Không Hỗ Trợ"
        let message = errorDescription + "\n\n" + "Bạn có muốn tải xuống phiên bản cuối cùng tương thích với thiết bị này không?"
        
        return await withCheckedContinuation { continuation in
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.view.tintColor = PipelineCSSTheme.blue
            alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alertController.addAction(UIAlertAction(title: String(format: "Tải %@ %@", appName, compatibleVersion), style: .default) { _ in
                continuation.resume(returning: true)
            })
            presenter.present(alertController, animated: true)
        }
    }

    func requestBackgroundSuspension() async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let alert = UIAlertController(
                    title: "Hoàn Tất Làm Mới",
                    message: """
                    Để hoàn tất quá trình làm mới, SideStore cần được chuyển xuống chạy nền. Bạn có thể tự thoát ra Màn hình chính hoặc bấm "Tiếp tục" bên dưới, sau đó mở lại SideStore.
                    """,
                    preferredStyle: .alert
                )
                alert.view.tintColor = PipelineCSSTheme.blue
                alert.addAction(UIAlertAction(title: "Tiếp tục", style: .default, handler: { _ in
                    continuation.resume()
                }))
                
                let presenter = self.activePresenter
                                ?? UIApplication.shared.connectedScenes
                                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                                    .first?.rootViewController
                                    
                if var topVC = presenter {
                    while let presented = topVC.presentedViewController {
                        topVC = presented
                    }
                    topVC.present(alert, animated: true)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func suspendToHomeScreen() async {
        await CellularRefreshManager.shared.turnOnDataIfNeeded()
        await MainActor.run {
            _ = UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        }
    }

    func isAppInForeground() async -> Bool {
        await MainActor.run {
            UIApplication.shared.applicationState == .active
        }
    }

    @MainActor
    func resolveInfoPlistCustomization(
        targets: [InfoPlistTarget],
        initialBundleID: String,
        appendTeamID: Bool,
        installedAppIdentities: [String: String],
        teamID: String
    ) async throws -> (modifiedPlists: [String: [String: any Sendable]], appendTeamID: Bool)? {
        debugLog("[PipelineHandler] resolveInfoPlistCustomization (targets: \(targets.count)): initialBundleID='\(initialBundleID)', teamID='\(teamID)', appendTeamID=\(appendTeamID)")
        guard let presenter = self.activePresenter else {
            debugLog("[PipelineHandler] resolveInfoPlistCustomization: activePresenter is nil!")
            var fallback: [String: [String: any Sendable]] = [:]
            for t in targets {
                fallback[t.id] = t.initialPlist
            }
            return (fallback, appendTeamID)
        }

        let result: (modifiedPlists: [String: [String: any Sendable]], appendTeamID: Bool)?
        if UserDefaults.standard.preferSheetForInfoPlistCustomization {
            result = await InfoPlistCustomizationSheetView.present(
                from: presenter,
                targets: targets,
                initialBundleID: initialBundleID,
                appendTeamID: appendTeamID,
                installedAppIdentities: installedAppIdentities,
                teamID: teamID
            )
        } else {
            result = await InfoPlistCustomizationView.present(
                from: presenter,
                targets: targets,
                initialBundleID: initialBundleID,
                appendTeamID: appendTeamID,
                installedAppIdentities: installedAppIdentities,
                teamID: teamID
            )
        }
        debugLog("[PipelineHandler] resolveInfoPlistCustomization result: \(result?.modifiedPlists.count ?? 0) target(s) returned, appendTeamID=\(result?.appendTeamID ?? false)")
        return result
    }

    @MainActor
    func resolveInfoPlistCustomization(
        initialPlist: [String: any Sendable],
        initialBundleID: String,
        appendTeamID: Bool,
        installedAppIdentities: [String: String],
        teamID: String
    ) async throws -> (modifiedPlist: [String: any Sendable], appendTeamID: Bool)? {
        let target = InfoPlistTarget(
            id: initialBundleID,
            name: (initialPlist["CFBundleDisplayName"] as? String) ?? (initialPlist["CFBundleName"] as? String) ?? initialBundleID,
            isExtension: false,
            initialPlist: initialPlist
        )
        guard let result = try await resolveInfoPlistCustomization(
            targets: [target],
            initialBundleID: initialBundleID,
            appendTeamID: appendTeamID,
            installedAppIdentities: installedAppIdentities,
            teamID: teamID
        ) else { return nil }
        let plist = result.modifiedPlists[initialBundleID] ?? initialPlist
        return (plist, result.appendTeamID)
    }

    @MainActor
    func resolveEntitlementsCustomization(
        targets: [EntitlementsTarget],
        teamType: ALTTeamType
    ) async throws -> [String: [String: any Sendable]]? {
        debugLog("[PipelineHandler] resolveEntitlementsCustomization: targets=\(targets.count), teamType=\(teamType.displayName)")
        guard let presenter = self.activePresenter else {
            debugLog("[PipelineHandler] resolveEntitlementsCustomization: activePresenter is nil!")
            var fallback: [String: [String: any Sendable]] = [:]
            for t in targets {
                fallback[t.id] = t.initialEntitlements
            }
            return fallback
        }

        let result: [String: [String: any Sendable]]?
        if UserDefaults.standard.preferSheetForEntitlementsCustomization {
            result = await EntitlementsCustomizationSheetView.present(
                from: presenter,
                targets: targets,
                teamType: teamType
            )
        } else {
            result = await EntitlementsCustomizationView.present(
                from: presenter,
                targets: targets,
                teamType: teamType
            )
        }
        debugLog("[PipelineHandler] resolveEntitlementsCustomization result: \(result?.count ?? 0) target(s) returned")
        return result
    }

    @MainActor
    func resolveEntitlementsCustomization(
        initialEntitlements: [String: any Sendable],
        bundleID: String,
        teamType: ALTTeamType
    ) async throws -> [String: any Sendable]? {
        let target = EntitlementsTarget(
            id: bundleID,
            name: bundleID,
            isExtension: false,
            initialEntitlements: initialEntitlements
        )
        let result = try await resolveEntitlementsCustomization(targets: [target], teamType: teamType)
        return result?[bundleID]
    }

    @MainActor
    func resolveBundleIDOverride(initialBundleID: String) async throws -> (customID: String, appendTeamID: Bool)? {
        guard let presenter = self.activePresenter else {
            return (initialBundleID, true)
        }
        
        let titleText = "Tùy Chỉnh App ID"
        let messageText = "Chỉnh sửa App ID nếu cần thiết và nhấn 'Xác nhận' để tiếp tục."
        
        let alert = UIAlertController(
            title: titleText,
            message: messageText,
            preferredStyle: .alert
        )
        alert.view.tintColor = PipelineCSSTheme.blue
        
        let team = try await AuthManager.shared.getAuthenticatedTeam()
        debugLog("[PipelineHandler] resolveBundleIDOverride: initialBundleID='\(initialBundleID)', teamID='\(team.identifier)', isAuthenticated=\(AuthManager.shared.isAuthenticated)")
        let teamID = team.identifier
        guard !teamID.isEmpty else {
            debugLog("[PipelineHandler] resolveBundleIDOverride FAILED: teamID is empty")
            throw OperationError.invalidParameters("Mã định danh nhóm nhà phát triển (Team ID) đang trống.")
        }
        let cleanInitialID: String = {
            let trimmed = initialBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            let base: String
            if !teamID.isEmpty && trimmed.hasSuffix(".\(teamID)") {
                base = String(trimmed.dropLast((".\(teamID)").count))
            } else {
                base = trimmed
            }
            let sanitized = InfoPlistParser.sanitizeBundleID(base)
            verboseLog("[PipelineHandler] cleanInitialID: trimmed='\(trimmed)', base='\(base)', sanitized='\(sanitized)'")
            return sanitized
        }()

        let checkboxView = AppendTeamIDCheckboxView(isChecked: true, teamID: teamID)
        checkboxView.translatesAutoresizingMaskIntoConstraints = false

        alert.addTextField { textField in
            let initialText = !teamID.isEmpty ? "\(cleanInitialID).\(teamID)" : cleanInitialID
            verboseLog("[PipelineHandler] resolveBundleIDOverride: setting textField.text='\(initialText)'")
            textField.text = initialText
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            textField.clearButtonMode = .whileEditing
            checkboxView.attach(to: textField, teamID: teamID)
        }
        
        alert.addTextField { textField in
            textField.isUserInteractionEnabled = false
        }
        
        _ = alert.view
        if let tf1 = alert.textFields?.first, let tf1View = tf1.superview {
            tf1View.layer.cornerRadius = 20
            tf1View.layer.cornerCurve = .continuous
            tf1View.layer.maskedCorners = [
                .layerMinXMinYCorner,
                .layerMaxXMinYCorner,
                .layerMinXMaxYCorner,
                .layerMaxXMaxYCorner
            ]
            tf1View.layer.masksToBounds = true
            tf1View.clipsToBounds = true
            
            tf1View.superview?.backgroundColor = .clear
            tf1View.superview?.layer.borderWidth = 0
            tf1View.superview?.layer.borderColor = UIColor.clear.cgColor
        }
        
        if (alert.textFields?.count ?? 0) >= 2,
           let tf2 = alert.textFields?[1],
           let container = tf2.superview {
            tf2.isHidden = true
            container.backgroundColor = .clear
            container.layer.borderWidth = 0
            container.layer.borderColor = UIColor.clear.cgColor
            
            for subview in container.subviews where subview !== checkboxView && subview !== tf2 {
                subview.isHidden = true
                subview.alpha = 0
            }
            
            container.addSubview(checkboxView)
            NSLayoutConstraint.activate([
                checkboxView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
                checkboxView.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -16),
                checkboxView.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
        }
        
        return await withCheckedContinuation { continuation in
            let okAction = UIAlertAction(title: "Xác nhận", style: .default) { _ in
                let baseID = checkboxView.cleanBaseID()
                let customID = InfoPlistParser.sanitizeBundleID(!baseID.isEmpty ? baseID : cleanInitialID)
                let appendTeamID = checkboxView.isChecked
                debugLog("[PipelineHandler] resolveBundleIDOverride confirmed: baseID='\(baseID)', customID='\(customID)', appendTeamID=\(appendTeamID)")
                continuation.resume(returning: (customID, appendTeamID))
            }
            
            let cancelAction = UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(returning: nil)
            }
            alert.addAction(cancelAction)
            alert.addAction(okAction)
            presenter.present(alert, animated: true)
        }
    }

    @MainActor
    func resolveAppGroupMismatch(originalGroup: String, correctedGroup: String) async throws -> AppGroupResolution {
        guard let presenter = self.activePresenter else {
            return .correctAndProceed(correctedGroup)
        }
        
        let title = "Sai Lệch App Group"
        let message = String(
            format: "Nhóm ứng dụng '%@' không khớp kiểu chữ hoa/thường với Bundle ID. Bạn có muốn tự động sửa thành '%@' không?",
            originalGroup,
            correctedGroup
        )
        
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.view.tintColor = PipelineCSSTheme.blue
            
            alert.addAction(UIAlertAction(title: "Sửa & Tiếp tục", style: .default) { _ in
                continuation.resume(returning: .correctAndProceed(correctedGroup))
            })
            
            alert.addAction(UIAlertAction(title: "Giữ nguyên gốc", style: .destructive) { _ in
                continuation.resume(returning: .keepOriginal(originalGroup))
            })
            
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(returning: .keepOriginal(originalGroup))
            })
            
            presenter.present(alert, animated: true)
        }
    }

    @MainActor
    func resolveAppIconCustomization(appName: String) async throws -> URL? {
        guard let presenter = self.activePresenter else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let title = "Tùy Chỉnh Biểu Tượng"
            let message = String(format: "Bạn muốn chọn ảnh biểu tượng (Icon) mới cho '%@' hay giữ nguyên biểu tượng gốc?", appName)

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.view.tintColor = PipelineCSSTheme.blue

            alert.addAction(UIAlertAction(title: "Chọn từ Thư viện ảnh", style: .default) { _ in
                #if !os(tvOS)
                let pickerDelegate = ImagePickerDelegateHandler { image in
                    guard let image = image,
                          let icon = image.resizing(toFill: CGSize(width: 256, height: 256)),
                          let iconData = icon.pngData() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CustomIcon_\(UUID().uuidString).png")
                    do {
                        try iconData.write(to: tempURL, options: .atomic)
                        continuation.resume(returning: tempURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } onCancel: {
                    continuation.resume(returning: nil)
                }

                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = true
                imagePicker.delegate = pickerDelegate
                objc_setAssociatedObject(imagePicker, "pickerDelegate", pickerDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                presenter.present(imagePicker, animated: true)
                #else
                TVWebFileTransferManager.shared.startImport(
                    acceptedExtensions: ["png", "jpg", "jpeg"],
                    title: "Tải lên Biểu tượng Tùy chỉnh",
                    presentingVC: presenter
                ) { fileURL in
                    guard let fileURL = fileURL,
                          let data = try? Data(contentsOf: fileURL),
                          let image = UIImage(data: data),
                          let icon = image.resizing(toFill: CGSize(width: 256, height: 256)),
                          let iconData = icon.pngData() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CustomIcon_\(UUID().uuidString).png")
                    do {
                        try iconData.write(to: tempURL, options: .atomic)
                        continuation.resume(returning: tempURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                #endif
            })

            alert.addAction(UIAlertAction(title: "Giữ biểu tượng gốc", style: .default) { _ in
                continuation.resume(returning: nil)
            })

            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(throwing: OperationError.cancelled)
            })

            presenter.present(alert, animated: true)
        }
    }

    @MainActor
    func resolveProvisioningProfileCustomization(appName: String, bundleID: String) async throws -> ProfileCustomizationChoice? {
        guard let presenter = self.activePresenter else {
            return .defaultProfile
        }

        let allProfiles = ProfileManager.shared.getAllLocalProfiles()
        guard !allProfiles.isEmpty else {
            return .defaultProfile
        }

        return try await withCheckedThrowingContinuation { continuation in
            let title = "Chọn Hồ Sơ Cấu Hình"
            let message = String(format: "Chọn hồ sơ cấu hình (Provisioning Profile) cho '%@' (%@) hoặc dùng hồ sơ tự động mặc định.", appName, bundleID)

            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alert.view.tintColor = PipelineCSSTheme.blue

            alert.addAction(UIAlertAction(title: "Mặc định (Hồ sơ nhóm tự động)", style: .default) { _ in
                continuation.resume(returning: .defaultProfile)
            })

            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none

            for profile in allProfiles {
                let isReady = ProfileManager.shared.isProfileReadyToSign(profile)
                let certInfo = isReady ? "✓ Sẵn sàng" : (profile.expirationDate < Date() ? "Hết hạn" : "Thiếu khóa")
                let profileTitle = "\(profile.name) (\(certInfo), HSD: \(formatter.string(from: profile.expirationDate)))"

                alert.addAction(UIAlertAction(title: profileTitle, style: .default) { _ in
                    continuation.resume(returning: .profile(profile))
                })
            }

            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(throwing: OperationError.cancelled)
            })

            #if !os(tvOS)
            if let popover = alert.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            #endif

            presenter.present(alert, animated: true)
        }
    }
}

private final class ImagePickerDelegateHandler: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onSelect: (UIImage?) -> Void
    let onCancel: () -> Void

    init(onSelect: @escaping (UIImage?) -> Void, onCancel: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        picker.dismiss(animated: true) {
            self.onSelect(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.onCancel()
        }
    }
}
