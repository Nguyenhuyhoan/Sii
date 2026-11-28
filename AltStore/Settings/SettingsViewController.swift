
//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SwiftUI
#if !os(tvOS)
import MessageUI
#endif
import Intents
#if !os(tvOS)
import IntentsUI
#endif

import SemanticVersion
import SideSign
import UniformTypeIdentifiers
import Network
@preconcurrency import Minimuxer
import MinimuxerCommon
import Combine
import Darwin

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% TOÀN HỆ THỐNG & CHỮ ĐEN TUYỀN)
private struct CSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                 // #000000 (Chữ đen tuyền độ tương phản tuyệt đối)
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)   // #f5f8ff
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)  // #dce2ec
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)      // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)   // #6f42c1
    static let indigo = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1.0)    // #5856d6
    static let teal = UIColor(red: 23/255, green: 162/255, blue: 184/255, alpha: 1.0)     // #17a2b8
    static let orange = UIColor(red: 253/255, green: 126/255, blue: 20/255, alpha: 1.0)   // #fd7e14
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)     // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)       // #dc3545
    static let magenta = UIColor(red: 232/255, green: 30/255, blue: 99/255, alpha: 1.0)   // #e91e63
    static let dark = UIColor.black                                                      // #000000

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,193,.92))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.95).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.92).cgColor

    static let cornerRadius: CGFloat = 18.0
    static let innerCornerRadius: CGFloat = 14.0

    // SwiftUI Colors (Phục vụ bảng Máy chủ Anisette & Pairing)
    static let suiPrimary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)
    static let suiSecondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
    static let suiNeutralInspect = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
    static let suiGreen = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)
    static let suiRed = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)
    static let suiPureBlack = SwiftUI.Color.black
    static let suiCardBackground = SwiftUI.Color.white
    static let suiInnerRowBackground = SwiftUI.Color(red: 245/255, green: 248/255, blue: 255/255)
    static let suiBorder = SwiftUI.Color(red: 220/255, green: 226/255, blue: 236/255)
    static let suiInnerBorder = SwiftUI.Color(red: 222/255, green: 229/255, blue: 240/255)
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

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG KHI CUỘN XUỐNG DƯỚI)
private final class CSSGradientBackgroundView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        gradientLayer.colors = [CSSTheme.bgGradientStart, CSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 🌐 BỘ QUẢN LÝ & GIAO DIỆN MÁY CHỦ ANISETTE
private enum SettingsAnisetteDefaultsHelper {
    static var currentServerURL: String {
        let menuURL = UserDefaults.standard.menuAnisetteURL.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !menuURL.isEmpty {
            return menuURL
        }
        if let textInput = UserDefaults.standard.textInputAnisetteURL?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
           !textInput.isEmpty {
            return textInput
        }
        if let custom = UserDefaults.standard.customAnisetteURL?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return AppConstants.Anisette.Servers.defaultServerURL
    }

    static func selectServerFromList(_ url: String) {
        let trimmed = url.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.textServer = false
        UserDefaults.standard.menuAnisetteURL = trimmed
        UserDefaults.standard.textInputAnisetteURL = trimmed
        UserDefaults.standard.customAnisetteURL = trimmed
    }

    static func setCustomServerURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.menuAnisetteURL = trimmed
        UserDefaults.standard.textInputAnisetteURL = trimmed
        UserDefaults.standard.customAnisetteURL = trimmed
    }
}

private struct SettingsBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

private struct SettingsSkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil
    var footerText: String? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                            .fill(color.opacity(0.14))
                            .frame(width: 22, height: 22)
                        SwiftUI.Image(systemName: icon)
                            .font(.system(size: 11.5, weight: .heavy))
                            .foregroundColor(color)
                    }

                    SwiftUI.Text(title.uppercased())
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(CSSTheme.suiPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if let statusOK = statusOK {
                        SwiftUI.Image(systemName: statusOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(statusOK ? CSSTheme.suiGreen : CSSTheme.suiRed)
                            .animation(.spring(), value: statusOK)
                    }

                    Spacer(minLength: 4)

                    if let trailingView = trailingView {
                        trailingView
                    }
                }

                RoundedRectangle(cornerRadius: 1.75)
                    .fill(
                        LinearGradient(
                            colors: [CSSTheme.suiPrimary, CSSTheme.suiSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 38, height: 3.5)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSTheme.suiCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.suiBorder, lineWidth: 1.1)
            )
            .shadow(color: CSSTheme.suiPrimary.opacity(0.09), radius: 14, x: 0, y: 6)

            if let footerText = footerText {
                SwiftUI.Text(footerText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CSSTheme.suiPureBlack)
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
            }
        }
    }
}

@MainActor
private final class SettingsAnisetteViewModel: ObservableObject {
    @Published var isAnisetteOK: Bool = !UserDefaults.standard.useOnDeviceAnisette
    @Published var useOnDeviceAnisette: Bool = UserDefaults.standard.useOnDeviceAnisette
    @Published var isAnisetteAutoRotationEnabled: Bool = !UserDefaults.standard.disableAnisetteRotation
    @Published var selectedAnisetteServerURL: String = SettingsAnisetteDefaultsHelper.currentServerURL
    @Published var anisetteDetail: String = ""
    @Published var servers: [AnisetteServerItem] = []
    @Published var isLoading: Bool = false

    init() {
        updateInstantStatus()
    }

    func updateInstantStatus() {
        let onDevice = UserDefaults.standard.useOnDeviceAnisette
        useOnDeviceAnisette = onDevice
        isAnisetteOK = !onDevice
        isAnisetteAutoRotationEnabled = !UserDefaults.standard.disableAnisetteRotation

        let selectedURL = SettingsAnisetteDefaultsHelper.currentServerURL
        selectedAnisetteServerURL = selectedURL
        let serverHost = URL(string: selectedURL)?.host ?? selectedURL
        anisetteDetail = onDevice
            ? "Không ổn định • Hãy tắt Use On-Device Anisette"
            : "Ổn định • Máy chủ: \(serverHost)"
    }

    func setUseOnDeviceAnisette(_ enabled: Bool) {
        UserDefaults.standard.useOnDeviceAnisette = enabled
        updateInstantStatus()
    }

    func setAnisetteAutoRotationEnabled(_ enabled: Bool) {
        UserDefaults.standard.disableAnisetteRotation = !enabled
        updateInstantStatus()
    }

    func selectAnisetteServerURL(_ urlString: String, isCustom: Bool = false) {
        if isCustom {
            SettingsAnisetteDefaultsHelper.setCustomServerURL(urlString)
        } else {
            SettingsAnisetteDefaultsHelper.selectServerFromList(urlString)
        }
        if UserDefaults.standard.useOnDeviceAnisette {
            UserDefaults.standard.useOnDeviceAnisette = false
        }
        updateInstantStatus()
    }

    func loadCachedAndSync(customPrefix: String) async {
        let local = await AnisetteServersManager.shared.loadLocalServers().filter { !$0.isHidden }
        if !local.isEmpty {
            self.servers = mergeWithCurrent(local, customPrefix: customPrefix)
        }
        await refreshFromRemote(customPrefix: customPrefix)
    }

    func refreshFromRemote(customPrefix: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if let synced = try? await AnisetteServersManager.shared.syncWithRemote() {
            let visible = synced.filter { !$0.isHidden }
            self.servers = mergeWithCurrent(visible, customPrefix: customPrefix)
        } else {
            let local = await AnisetteServersManager.shared.loadLocalServers().filter { !$0.isHidden }
            self.servers = mergeWithCurrent(local, customPrefix: customPrefix)
        }
    }

    func reloadCurrentSelection(customPrefix: String) async {
        let local = await AnisetteServersManager.shared.loadLocalServers().filter { !$0.isHidden }
        self.servers = mergeWithCurrent(local, customPrefix: customPrefix)
    }

    private func mergeWithCurrent(_ items: [AnisetteServerItem], customPrefix: String) -> [AnisetteServerItem] {
        var result = items
        if result.isEmpty {
            result = [
                AnisetteServerItem(
                    name: "SideStore (New)",
                    address: AppConstants.Anisette.Servers.defaultServerURL,
                    isHidden: false
                )
            ]
        }
        let current = SettingsAnisetteDefaultsHelper.currentServerURL.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !current.isEmpty,
           !result.contains(where: { $0.address.caseInsensitiveCompare(current) == .orderedSame }) {
            let host = URL(string: current)?.host ?? current
            result.insert(AnisetteServerItem(name: "\(customPrefix) (\(host))", address: current, isHidden: false), at: 0)
        }
        return result
    }
}

private struct SettingsAnisetteSheetView: SwiftUI.View {
    @StateObject private var vm = SettingsAnisetteViewModel()
    @State private var customServerInput: String = ""
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)? = nil

    private let customServerPrefix = "Máy chủ tùy chỉnh"

    private func isRecommendedSideStoreNew(_ server: AnisetteServerItem) -> Bool {
        let lowerName = server.name.lowercased()
        return lowerName.contains("sidestore (new)")
            || (lowerName.contains("sidestore") && lowerName.contains("new"))
    }

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.isAnisetteOK ? CSSTheme.suiGreen.opacity(0.15) : CSSTheme.suiRed.opacity(0.15))
                                .frame(width: 48, height: 48)
                            SwiftUI.Image(systemName: vm.isAnisetteOK ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 23, weight: .bold))
                                .foregroundColor(vm.isAnisetteOK ? CSSTheme.suiGreen : CSSTheme.suiRed)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            SwiftUI.Text(vm.isAnisetteOK
                                         ? "Máy Chủ Anisette Ổn Định"
                                         : "Đang Bật On-Device Anisette")
                                .font(.system(size: 16.5, weight: .bold))
                                .foregroundColor(CSSTheme.suiPureBlack)
                            SwiftUI.Text(vm.anisetteDetail)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(CSSTheme.suiPureBlack)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(CSSTheme.suiCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.suiBorder, lineWidth: 1.1)
                    )
                    .shadow(color: CSSTheme.suiPrimary.opacity(0.08), radius: 10, x: 0, y: 5)

                    SettingsSkySectionCard(
                        title: "CHẾ ĐỘ XÁC THỰC ANISETTE",
                        icon: "slider.horizontal.3",
                        color: CSSTheme.suiPrimary
                    ) {
                        Toggle(isOn: Binding(
                            get: { vm.useOnDeviceAnisette },
                            set: { vm.setUseOnDeviceAnisette($0) }
                        )) {
                            HStack(spacing: 10) {
                                SwiftUI.Image(systemName: "iphone.gen3")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(CSSTheme.suiPrimary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    SwiftUI.Text("Use On-Device Anisette")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(CSSTheme.suiPureBlack)
                                    SwiftUI.Text(vm.useOnDeviceAnisette
                                                 ? "Đang BẬT (Khuyên tắt để ổn định hơn)"
                                                 : "(Nên Tắt Để Dễ Đăng Nhập)")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(vm.useOnDeviceAnisette ? CSSTheme.suiRed : CSSTheme.suiGreen)
                                }
                            }
                        }
                        .tint(CSSTheme.suiPrimary)
                        .padding(12)
                        .background(CSSTheme.suiInnerRowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(CSSTheme.suiInnerBorder, lineWidth: 1)
                        )

                        Toggle(isOn: Binding(
                            get: { vm.isAnisetteAutoRotationEnabled },
                            set: { vm.setAnisetteAutoRotationEnabled($0) }
                        )) {
                            HStack(spacing: 10) {
                                SwiftUI.Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(CSSTheme.suiSecondary)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    SwiftUI.Text("Enable Auto Rotation")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(CSSTheme.suiPureBlack)
                                    SwiftUI.Text(vm.isAnisetteAutoRotationEnabled
                                                 ? "(Tự Động Đổi Máy Chủ Khi Lỗi)"
                                                 : "Đang Tắt “Nên chọn SideStore (New)”")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(vm.isAnisetteAutoRotationEnabled ? CSSTheme.suiGreen : CSSTheme.suiRed)
                                }
                            }
                        }
                        .tint(CSSTheme.suiPrimary)
                        .padding(12)
                        .background(CSSTheme.suiInnerRowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(CSSTheme.suiInnerBorder, lineWidth: 1)
                        )

                        if vm.useOnDeviceAnisette {
                            SwiftUI.Button {
                                vm.setUseOnDeviceAnisette(false)
                            } label: {
                                HStack(spacing: 8) {
                                    SwiftUI.Image(systemName: "checkmark.shield.fill")
                                    SwiftUI.Text("Tắt ngay Use On-Device Anisette")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CSSTheme.suiPrimary)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: CSSTheme.suiPrimary.opacity(0.35), radius: 5, x: 0, y: 3)
                            }
                            .buttonStyle(SettingsBounceButtonStyle())
                        }
                    }

                    SettingsSkySectionCard(
                        title: "CHỌN MÁY CHỦ ANISETTE",
                        icon: "server.rack",
                        color: CSSTheme.suiSecondary,
                        trailingView: vm.isLoading ? AnyView(ProgressView().tint(CSSTheme.suiPrimary)) : nil
                    ) {
                        VStack(spacing: 8) {
                            ForEach(vm.servers) { server in
                                let isSelected = (vm.selectedAnisetteServerURL.caseInsensitiveCompare(server.address) == .orderedSame)
                                let isRecommended = isRecommendedSideStoreNew(server)

                                SwiftUI.Button {
                                    vm.selectAnisetteServerURL(server.address, isCustom: false)
                                    Task { await vm.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                } label: {
                                    HStack(spacing: 12) {
                                        SwiftUI.Image(systemName: isSelected ? "checkmark.circle.fill" : "globe")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundColor(isSelected ? CSSTheme.suiPrimary : CSSTheme.suiSecondary.opacity(0.75))

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                SwiftUI.Text(server.name)
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(CSSTheme.suiPureBlack)

                                                if isRecommended {
                                                    SwiftUI.Text("★ Khuyên dùng")
                                                        .font(.system(size: 10.5, weight: .heavy))
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2.5)
                                                        .background(CSSTheme.suiGreen.opacity(0.16))
                                                        .foregroundColor(CSSTheme.suiGreen)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            SwiftUI.Text(server.address)
                                                .font(.system(size: 12.5, weight: .medium))
                                                .foregroundColor(CSSTheme.suiPureBlack.opacity(0.75))
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if isSelected {
                                            SwiftUI.Text("Đang dùng")
                                                .font(.system(size: 11.5, weight: .bold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(CSSTheme.suiPrimary.opacity(0.15))
                                                .foregroundColor(CSSTheme.suiPrimary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(12)
                                    .background(CSSTheme.suiInnerRowBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(
                                                isSelected
                                                ? CSSTheme.suiPrimary.opacity(0.65)
                                                : (isRecommended ? CSSTheme.suiGreen.opacity(0.45) : CSSTheme.suiInnerBorder),
                                                lineWidth: isSelected ? 1.5 : 1.1
                                            )
                                    )
                                }
                                .buttonStyle(SettingsBounceButtonStyle())
                            }
                        }

                        Divider().padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                SwiftUI.Image(systemName: "link.badge.plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(CSSTheme.suiPrimary)
                                SwiftUI.Text("Hoặc nhập URL máy chủ tùy chỉnh:")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(CSSTheme.suiPureBlack)
                            }

                            HStack(spacing: 8) {
                                TextField(AppConstants.Anisette.Servers.defaultServerURL, text: $customServerInput)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(CSSTheme.suiPureBlack)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(10)
                                    .background(CSSTheme.suiInnerRowBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(CSSTheme.suiInnerBorder, lineWidth: 1)
                                    )

                                SwiftUI.Button {
                                    let trimmed = customServerInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    vm.selectAnisetteServerURL(trimmed, isCustom: true)
                                    Task { await vm.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                    customServerInput = ""
                                } label: {
                                    HStack(spacing: 4) {
                                        SwiftUI.Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 13.5, weight: .bold))
                                        SwiftUI.Text("Lưu")
                                            .font(.system(size: 14.5, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(CSSTheme.suiPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: CSSTheme.suiPrimary.opacity(0.35), radius: 5, x: 0, y: 3)
                                }
                                .buttonStyle(SettingsBounceButtonStyle())
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(CSSTheme.suiPageGradient.ignoresSafeArea())
            .navigationTitle("Máy Chủ Anisette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        SwiftUI.Image(systemName: "server.rack")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CSSTheme.suiPrimary)
                        SwiftUI.Text("Máy Chủ Anisette")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(CSSTheme.suiPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") {
                        onDismiss?()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(CSSTheme.suiPrimary)
                }
            }
            .task {
                vm.updateInstantStatus()
                await vm.loadCachedAndSync(customPrefix: customServerPrefix)
            }
        }
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
        .onDisappear {
            onDismiss?()
        }
    }
}

// MARK: - 🔗 BỘ QUẢN LÝ & GIAO DIỆN PAIRING & THIẾT BỊ GHÉP NỐI (ĐỒNG BỘ 100% VỚI SETTINGS)
private enum SettingsPairingVisualState: Equatable {
    case actionRequired // Màu Tím: Đang chờ xác minh qua LocalDevVPN
    case verifiedOK     // Màu Xanh Lá: Hoạt động tốt
    case failedError    // Màu Đỏ: Lỗi hoặc chưa có tệp Pairing
}

/// Quản lý giữ tiến trình chạy nền khi người dùng chuyển sang app Cài đặt để nhập mã PIN Pairing 6 chữ số
@MainActor
private final class SettingsPairingKeepAliveManager {
    static let shared = SettingsPairingKeepAliveManager()
    private var bgTask: UIBackgroundTaskIdentifier = .invalid
    private var isKeepAliveActive: Bool = false
    private var lifecycleCancellables = Set<AnyCancellable>()

    private init() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isKeepAliveActive else { return }
                self.refreshBackgroundTaskToken()
            }
            .store(in: &lifecycleCancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isKeepAliveActive else { return }
                self.refreshBackgroundTaskToken()
            }
            .store(in: &lifecycleCancellables)
    }

    func beginKeepAlive() {
        isKeepAliveActive = true
        refreshBackgroundTaskToken()
    }

    func endKeepAlive() {
        isKeepAliveActive = false
        endCurrentToken()
    }

    private func refreshBackgroundTaskToken() {
        let oldTask = bgTask
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "com.sidestore.settings.wirelessPairing.keepAlive") { [weak self] in
            Task { @MainActor in
                self?.endCurrentToken()
            }
        }
        if oldTask != .invalid {
            UIApplication.shared.endBackgroundTask(oldTask)
        }
    }

    private func endCurrentToken() {
        guard bgTask != .invalid else { return }
        let taskToEnd = bgTask
        bgTask = .invalid
        UIApplication.shared.endBackgroundTask(taskToEnd)
    }
}

@MainActor
private final class SettingsPairingCheckViewModel: ObservableObject {
    private static let verifiedPairingCacheKey = "com.sidestore.check.lastVerifiedPairingSuccess"

    @Published var isPairingOK: Bool = false
    @Published var isPairingVerifiedError: Bool = false
    @Published var pairingProtocol: String = ""
    @Published var hasAnyStoredPairingFile: Bool = false

    @Published var isVpnOK: Bool = false
    @Published var tunnelIP: String = "Chưa kết nối"
    @Published var deviceIP: String = "Chưa kết nối"

    @Published var isCellularOK: Bool = false
    @Published var isWifiActive: Bool = false
    @Published var isWirelessPairingActive: Bool = false

    private let pathMonitor = NWPathMonitor()
    private let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
    private let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "com.sidestore.settings.pairing.network", qos: .utility)

    private var usesCellularPath: Bool = false
    private var isCellularPathSatisfied: Bool = false
    private var didReceiveCellularMonitorUpdate: Bool = false

    private var usesWifiPath: Bool = false
    private var isWifiPathSatisfied: Bool = false
    private var didReceiveWifiMonitorUpdate: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var activeSheetPeriodicTask: Task<Void, Never>? = nil

    private var isViewVisible: Bool = false
    private var isChecking: Bool = false
    private var needsAnotherCheck: Bool = false
    private var pendingForceVerify: Bool = false
    private var lastInternalConfigWriteTime: TimeInterval = 0
    private var latestSnapshot: SystemInterfaceSnapshot? = nil

    private var lastVerifiedPairingSuccess: Bool = UserDefaults.standard.bool(forKey: verifiedPairingCacheKey) {
        didSet {
            if oldValue != lastVerifiedPairingSuccess {
                UserDefaults.standard.set(lastVerifiedPairingSuccess, forKey: Self.verifiedPairingCacheKey)
            }
        }
    }

    private var lastVerifiedModeSignature: String = ""
    private var didAttemptLiveVerifyInCurrentMode: Bool = false

    private let networkChangeSubject = PassthroughSubject<Bool, Never>()

    private func resolveCellularActive(snapshot: SystemInterfaceSnapshot) -> Bool {
        if didReceiveCellularMonitorUpdate {
            return usesCellularPath || isCellularPathSatisfied
        }
        return usesCellularPath || isCellularPathSatisfied || snapshot.hasCellularIPv4
    }

    private func resolveWifiActive(snapshot: SystemInterfaceSnapshot) -> Bool {
        if didReceiveWifiMonitorUpdate {
            return usesWifiPath || isWifiPathSatisfied
        }
        return usesWifiPath || isWifiPathSatisfied || snapshot.hasWifiIPv4
    }

    var canAutoVerifyPairingInCurrentNetwork: Bool {
        guard isVpnOK else { return false }
        if isWifiActive {
            return true
        }
        return !isCellularOK
    }

    var pairingVisualState: SettingsPairingVisualState {
        if !hasAnyStoredPairingFile {
            return .failedError
        }
        guard canAutoVerifyPairingInCurrentNetwork else {
            return .actionRequired
        }
        if isPairingOK {
            return .verifiedOK
        }
        if isPairingVerifiedError {
            return .failedError
        }
        return .actionRequired
    }

    func setWirelessPairingActive(_ active: Bool) {
        guard isWirelessPairingActive != active else { return }
        isWirelessPairingActive = active
        if active {
            SettingsPairingKeepAliveManager.shared.beginKeepAlive()
        } else {
            SettingsPairingKeepAliveManager.shared.endKeepAlive()
            if isViewVisible {
                Task { await checkAllStatuses(forceVerify: true) }
            }
        }
    }

    func markPairingVerifiedImmediately() {
        self.hasAnyStoredPairingFile = true
        self.didAttemptLiveVerifyInCurrentMode = true
        self.lastVerifiedPairingSuccess = true
        self.lastVerifiedModeSignature = ""
        self.isPairingVerifiedError = false
        self.isPairingOK = true
        refreshSnapshotAsyncAndApply()
    }

    init() {
        setupRealtimeListeners()
    }

    deinit {
        activeSheetPeriodicTask?.cancel()
        pathMonitor.cancel()
        cellularMonitor.cancel()
        wifiMonitor.cancel()
    }

    func setViewVisible(_ visible: Bool) {
        guard isViewVisible != visible else { return }
        isViewVisible = visible
        if visible {
            if !isWirelessPairingActive {
                Task { await checkAllStatuses(forceVerify: false) }
            } else {
                refreshSnapshotAsyncAndApply()
            }
            startActiveSheetPeriodicCheck()
        } else {
            stopActiveSheetPeriodicCheck()
        }
    }

    private func startActiveSheetPeriodicCheck() {
        activeSheetPeriodicTask?.cancel()
        activeSheetPeriodicTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled, let self = self else { break }
                guard self.isViewVisible,
                      !self.isWirelessPairingActive,
                      !self.isChecking,
                      !self.isWithinInternalWriteCooldown else {
                    continue
                }
                await self.checkAllStatuses(forceVerify: false)
            }
        }
    }

    private func stopActiveSheetPeriodicCheck() {
        activeSheetPeriodicTask?.cancel()
        activeSheetPeriodicTask = nil
    }

    private func refreshSnapshotAsyncAndApply() {
        Task { @MainActor [weak self] in
            guard let self = self, self.isViewVisible else { return }
            let snap = await Task.detached(priority: .utility) {
                Self.scanSystemInterfaces()
            }.value
            guard self.isViewVisible else { return }
            self.latestSnapshot = snap
            self.updateInstantStatus(existingSnapshot: snap)
        }
    }

    private var isWithinInternalWriteCooldown: Bool {
        (CFAbsoluteTimeGetCurrent() - lastInternalConfigWriteTime) < 0.8
    }

    private func setupRealtimeListeners() {
        networkChangeSubject
            .debounce(for: .milliseconds(850), scheduler: DispatchQueue.main)
            .sink { [weak self] forceVerify in
                guard let self = self,
                      self.isViewVisible,
                      !self.isChecking,
                      !self.isWirelessPairingActive,
                      !self.isWithinInternalWriteCooldown else { return }
                Task { @MainActor [weak self] in
                    await self?.checkAllStatuses(forceVerify: forceVerify)
                }
            }
            .store(in: &cancellables)

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let usesCell = (path.status == .satisfied) && path.usesInterfaceType(.cellular)
            let usesWifi = (path.status == .satisfied) && path.usesInterfaceType(.wifi)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                var changed = false
                if self.usesCellularPath != usesCell {
                    self.usesCellularPath = usesCell
                    changed = true
                }
                if self.usesWifiPath != usesWifi {
                    self.usesWifiPath = usesWifi
                    changed = true
                }
                guard changed, self.isViewVisible, !self.isWirelessPairingActive else { return }
                if let snap = self.latestSnapshot {
                    self.updateInstantStatus(existingSnapshot: snap)
                }
                self.networkChangeSubject.send(false)
            }
        }
        pathMonitor.start(queue: monitorQueue)

        cellularMonitor.pathUpdateHandler = { [weak self] path in
            let cellSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let firstUpdate = !self.didReceiveCellularMonitorUpdate
                self.didReceiveCellularMonitorUpdate = true
                guard firstUpdate || self.isCellularPathSatisfied != cellSatisfied else { return }
                self.isCellularPathSatisfied = cellSatisfied
                guard self.isViewVisible, !self.isWirelessPairingActive else { return }
                if let snap = self.latestSnapshot {
                    self.updateInstantStatus(existingSnapshot: snap)
                }
                self.networkChangeSubject.send(false)
            }
        }
        cellularMonitor.start(queue: monitorQueue)

        wifiMonitor.pathUpdateHandler = { [weak self] path in
            let wifiSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let firstUpdate = !self.didReceiveWifiMonitorUpdate
                self.didReceiveWifiMonitorUpdate = true
                guard firstUpdate || self.isWifiPathSatisfied != wifiSatisfied else { return }
                self.isWifiPathSatisfied = wifiSatisfied
                guard self.isViewVisible, !self.isWirelessPairingActive else { return }
                if let snap = self.latestSnapshot {
                    self.updateInstantStatus(existingSnapshot: snap)
                }
                self.networkChangeSubject.send(false)
            }
        }
        wifiMonitor.start(queue: monitorQueue)

        minimuxer.network.pathPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      self.isViewVisible,
                      !self.isChecking,
                      !self.isWirelessPairingActive,
                      !self.isWithinInternalWriteCooldown else { return }
                self.networkChangeSubject.send(false)
            }
            .store(in: &cancellables)

        minimuxerStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      self.isViewVisible,
                      !self.isChecking,
                      !self.isWirelessPairingActive,
                      !self.isWithinInternalWriteCooldown else { return }
                self.networkChangeSubject.send(false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isViewVisible else { return }
                guard !self.isWirelessPairingActive else {
                    self.refreshSnapshotAsyncAndApply()
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.checkAllStatuses(forceVerify: false)
                }
            }
            .store(in: &cancellables)
    }

    struct SystemInterfaceSnapshot: Sendable, Equatable {
        let hasCellularIPv4: Bool
        let hasWifiIPv4: Bool
        let hasActiveLocalDevUtun: Bool
        let detectedLocalDevUtunIPv4: String?
    }

    private nonisolated static func scanSystemInterfaces() -> SystemInterfaceSnapshot {
        var hasPdpIPv4 = false
        var hasEn0IPv4 = false
        var hasLocalDevUtun = false
        var bestLocalDevUtunIP: String? = nil

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr {
            defer { freeifaddrs(ifaddr) }
            var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
            while let current = ptr {
                let flags = Int32(current.pointee.ifa_flags)
                let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
                if isUp, let addr = current.pointee.ifa_addr {
                    let family = addr.pointee.sa_family
                    if family == UInt8(AF_INET) {
                        let name = String(cString: current.pointee.ifa_name).lowercased()
                        if name == "pdp_ip0" || name == "en0" || name.hasPrefix("utun") {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(
                                addr,
                                socklen_t(addr.pointee.sa_len),
                                &hostname,
                                socklen_t(hostname.count),
                                nil,
                                0,
                                NI_NUMERICHOST
                            ) == 0 {
                                let ip = String(cString: hostname)
                                if !ip.isEmpty && !ip.hasPrefix("169.254.") && ip != "0.0.0.0" {
                                    if name == "pdp_ip0" {
                                        hasPdpIPv4 = true
                                    } else if name == "en0" {
                                        hasEn0IPv4 = true
                                    } else if name.hasPrefix("utun") {
                                        if ip.hasPrefix("10.7.") {
                                            hasLocalDevUtun = true
                                            bestLocalDevUtunIP = ip
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                ptr = current.pointee.ifa_next
            }
        }

        return SystemInterfaceSnapshot(
            hasCellularIPv4: hasPdpIPv4,
            hasWifiIPv4: hasEn0IPv4,
            hasActiveLocalDevUtun: hasLocalDevUtun,
            detectedLocalDevUtunIPv4: bestLocalDevUtunIP
        )
    }

    private func ensureTunnelRoutingPinned(snapshot: SystemInterfaceSnapshot) {
        guard isViewVisible, !isWirelessPairingActive else { return }
        guard let utunIP = snapshot.detectedLocalDevUtunIPv4, utunIP.hasPrefix("10.7.") else { return }

        let config = ConnectionConfig.shared
        var didWrite = false
        if config.overrideTunnelPeerIp != "10.7.0.1" {
            config.overrideTunnelPeerIp = "10.7.0.1"
            didWrite = true
        }
        if !config.overrideTunnelPeerReachable {
            config.overrideTunnelPeerReachable = true
            didWrite = true
        }
        if didWrite {
            lastInternalConfigWriteTime = CFAbsoluteTimeGetCurrent()
        }
    }

    func deleteAllPairingFiles() {
        PairingFileManager.shared.resetAllPairingFiles()
        self.hasAnyStoredPairingFile = false
        self.lastVerifiedPairingSuccess = false
        self.lastVerifiedModeSignature = ""
        self.didAttemptLiveVerifyInCurrentMode = false
        self.isPairingVerifiedError = true
        self.isPairingOK = false
        if let snap = latestSnapshot {
            updateInstantStatus(existingSnapshot: snap)
        } else {
            refreshSnapshotAsyncAndApply()
        }
    }

    private static func isValidConnectedIP(_ value: String?, disconnectedText: String) -> Bool {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return false
        }
        let lower = trimmed.lowercased()
        if trimmed == disconnectedText
            || lower.contains("chưa kết nối")
            || lower.contains("disconnected")
            || lower == "none"
            || lower == "nil"
            || lower == "n/a"
            || lower == "0.0.0.0" {
            return false
        }
        return true
    }

    private func assignIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<SettingsPairingCheckViewModel, T>, _ newValue: T) {
        if self[keyPath: keyPath] != newValue {
            self[keyPath: keyPath] = newValue
        }
    }

    func updateInstantStatus(existingSnapshot: SystemInterfaceSnapshot) {
        guard isViewVisible else { return }
        let snapshot = existingSnapshot
        self.latestSnapshot = snapshot
        ensureTunnelRoutingPinned(snapshot: snapshot)

        let cellularActive = resolveCellularActive(snapshot: snapshot)
        let wifiActive = resolveWifiActive(snapshot: snapshot)
        assignIfChanged(\.isCellularOK, cellularActive)
        assignIfChanged(\.isWifiActive, wifiActive)

        let disconnectedText = "Chưa kết nối"
        let config = ConnectionConfig.shared

        let activeTunnelIP: String? = {
            if let detected = snapshot.detectedLocalDevUtunIPv4, !detected.isEmpty {
                return config.formattedTunnelIface ?? config.tunnelIfaceIp ?? detected
            }
            if let iface = config.tunnelIfaceIp, iface.hasPrefix("10.7.") {
                return config.formattedTunnelIface ?? iface
            }
            return nil
        }()

        let activeDeviceIP: String? = {
            guard activeTunnelIP != nil else { return nil }
            if let formattedPeer = config.formattedTunnelPeer, !formattedPeer.isEmpty {
                return formattedPeer
            }
            if let peer = config.tunnelPeerIp, !peer.isEmpty {
                return peer
            }
            if config.overrideTunnelPeerReachable, !config.overrideTunnelPeerIp.isEmpty {
                return config.overrideTunnelPeerIp
            }
            if let tIP = activeTunnelIP, tIP.contains("10.7.") {
                return "10.7.0.1"
            }
            return nil
        }()

        let resolvedTunnelText = Self.isValidConnectedIP(activeTunnelIP, disconnectedText: disconnectedText)
            ? activeTunnelIP!
            : disconnectedText
        let resolvedDeviceText = Self.isValidConnectedIP(activeDeviceIP, disconnectedText: disconnectedText)
            ? activeDeviceIP!
            : disconnectedText

        assignIfChanged(\.tunnelIP, resolvedTunnelText)
        assignIfChanged(\.deviceIP, resolvedDeviceText)

        let vpnConnected = snapshot.hasActiveLocalDevUtun
            || ((resolvedTunnelText != disconnectedText) && (resolvedDeviceText != disconnectedText))
        assignIfChanged(\.isVpnOK, vpnConnected)

        let hasRp = PairingFileManager.shared.hasPairingFile(for: .rppairing)
        let hasLd = PairingFileManager.shared.hasPairingFile(for: .lockdown)
        let hasUnk = PairingFileManager.shared.hasPairingFile(for: .unknown)
        let hasAnyFile = hasRp || hasLd || hasUnk
        assignIfChanged(\.hasAnyStoredPairingFile, hasAnyFile)

        let coreLoaded = minimuxer.core.isPairingFileLoaded && hasAnyFile
        let activeType: PairingProtocol = {
            if coreLoaded && minimuxer.core.pairingFileType != .unknown {
                return minimuxer.core.pairingFileType
            }
            if let persisted = PairingFileManager.shared.persistedActiveProtocol {
                let hasPersisted = (persisted == .rppairing && hasRp)
                                || (persisted == .lockdown && hasLd)
                                || (persisted == .unknown && hasUnk)
                if hasPersisted {
                    return persisted
                }
            }
            if hasRp { return .rppairing }
            if hasLd { return .lockdown }
            return .unknown
        }()

        let protocolName: String = {
            switch activeType {
            case .rppairing:
                return "Remote Pairing • Chuẩn iOS 17+ / iOS 27"
            case .lockdown:
                return "Lockdown Pairing • Chuẩn PC / Mac"
            case .unknown:
                return (hasAnyFile || coreLoaded)
                    ? "Đã nạp tệp Pairing hợp lệ"
                    : "Chưa có tệp Pairing trong ứng dụng"
            }
        }()

        let canVerifyNow = vpnConnected && (wifiActive || !cellularActive)

        if !hasAnyFile {
            self.lastVerifiedPairingSuccess = false
            self.lastVerifiedModeSignature = ""
            self.didAttemptLiveVerifyInCurrentMode = false
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, true)
            assignIfChanged(\.pairingProtocol, "Chưa có tệp Pairing • Hãy cài trực tiếp hoặc nhập tệp")
        } else if !canVerifyNow {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, false)
            assignIfChanged(\.pairingProtocol, "Đã lưu tệp Pairing (\(protocolName)) • Bật LocalDevVPN để xác minh")
        } else if self.didAttemptLiveVerifyInCurrentMode {
            if self.lastVerifiedPairingSuccess {
                assignIfChanged(\.isPairingOK, true)
                assignIfChanged(\.isPairingVerifiedError, false)
                assignIfChanged(\.pairingProtocol, protocolName)
            } else {
                assignIfChanged(\.isPairingOK, false)
                assignIfChanged(\.isPairingVerifiedError, true)
                assignIfChanged(\.pairingProtocol, "Pairing bị lỗi hoặc hết hạn • Hãy ghép nối hoặc nạp lại tệp mới")
            }
        } else if self.lastVerifiedPairingSuccess {
            assignIfChanged(\.isPairingOK, true)
            assignIfChanged(\.isPairingVerifiedError, false)
            assignIfChanged(\.pairingProtocol, protocolName)
        } else {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, false)
            assignIfChanged(\.pairingProtocol, "Đã lưu tệp Pairing (\(protocolName)) • Đang chờ xác minh")
        }
    }

    private func verifyPairingOverTunnel(initialSnapshot: SystemInterfaceSnapshot) async -> Bool {
        ensureTunnelRoutingPinned(snapshot: initialSnapshot)

        let hasRp = PairingFileManager.shared.hasPairingFile(for: .rppairing)
        let hasLd = PairingFileManager.shared.hasPairingFile(for: .lockdown)

        var candidateProtocols: [PairingProtocol] = []
        if let persisted = PairingFileManager.shared.persistedActiveProtocol {
            if (persisted == .rppairing && hasRp) || (persisted == .lockdown && hasLd) {
                candidateProtocols.append(persisted)
            }
        }
        if hasRp && !candidateProtocols.contains(.rppairing) {
            candidateProtocols.append(.rppairing)
        }
        if hasLd && !candidateProtocols.contains(.lockdown) {
            candidateProtocols.append(.lockdown)
        }
        if candidateProtocols.isEmpty {
            candidateProtocols.append(.unknown)
        }

        for proto in candidateProtocols {
            if proto != .unknown {
                if !minimuxer.core.isPairingFileLoaded || minimuxer.core.pairingFileType != proto {
                    try? await minimuxerSwitchPairingProtocol(to: proto)
                }
            }

            for attempt in 0..<2 {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    let retrySnap = await Task.detached(priority: .utility) {
                        Self.scanSystemInterfaces()
                    }.value
                    ensureTunnelRoutingPinned(snapshot: retrySnap)
                }

                if let udid = try? await fetchUDID(forceLive: true), !udid.isEmpty {
                    return true
                }
            }
        }
        return false
    }

    func checkAllStatuses(forceVerify: Bool = false) async {
        guard isViewVisible else { return }

        if isWirelessPairingActive {
            if forceVerify {
                pendingForceVerify = true
            }
            return
        }

        if isChecking {
            needsAnotherCheck = true
            if forceVerify { pendingForceVerify = true }
            return
        }

        let effectiveForceVerify = forceVerify || pendingForceVerify
        pendingForceVerify = false

        isChecking = true
        defer {
            lastInternalConfigWriteTime = CFAbsoluteTimeGetCurrent()
            isChecking = false
            if needsAnotherCheck && isViewVisible && !isWirelessPairingActive {
                let shouldForce = pendingForceVerify
                needsAnotherCheck = false
                pendingForceVerify = false
                Task { @MainActor [weak self] in
                    await self?.checkAllStatuses(forceVerify: shouldForce)
                }
            } else {
                needsAnotherCheck = false
            }
        }

        let snapshot = await Task.detached(priority: .utility) {
            Self.scanSystemInterfaces()
        }.value

        guard isViewVisible else { return }
        updateInstantStatus(existingSnapshot: snapshot)

        guard hasAnyStoredPairingFile else {
            self.lastVerifiedPairingSuccess = false
            self.lastVerifiedModeSignature = ""
            self.didAttemptLiveVerifyInCurrentMode = false
            self.isPairingVerifiedError = true
            assignIfChanged(\.isPairingOK, false)
            updateInstantStatus(existingSnapshot: snapshot)
            return
        }

        let cellularActive = resolveCellularActive(snapshot: snapshot)
        let wifiActive = resolveWifiActive(snapshot: snapshot)
        let vpnActive = isVpnOK || snapshot.hasActiveLocalDevUtun

        let canVerifyNow = vpnActive && (wifiActive || !cellularActive)

        if canVerifyNow {
            let isStrictLoopbackTestMode = vpnActive && !wifiActive && !cellularActive
            let currentSignature = "\(tunnelIP)|strict:\(isStrictLoopbackTestMode)"
            let signatureChanged = (lastVerifiedModeSignature != currentSignature)

            let shouldPerformHeavyHandshake = effectiveForceVerify
                || !didAttemptLiveVerifyInCurrentMode
                || !lastVerifiedPairingSuccess
                || (isStrictLoopbackTestMode && signatureChanged)

            if shouldPerformHeavyHandshake {
                let ok = await verifyPairingOverTunnel(initialSnapshot: snapshot)
                guard isViewVisible else { return }
                self.didAttemptLiveVerifyInCurrentMode = true
                self.lastVerifiedModeSignature = currentSignature
                if ok {
                    self.lastVerifiedPairingSuccess = true
                    assignIfChanged(\.isPairingOK, true)
                    assignIfChanged(\.isPairingVerifiedError, false)
                } else {
                    self.lastVerifiedPairingSuccess = false
                    assignIfChanged(\.isPairingOK, false)
                    assignIfChanged(\.isPairingVerifiedError, true)
                }
            }
        } else {
            self.didAttemptLiveVerifyInCurrentMode = false
            self.lastVerifiedModeSignature = ""
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, false)
        }

        updateInstantStatus(existingSnapshot: snapshot)
    }
}

private struct SettingsGuideStepRow: SwiftUI.View {
    let num: String
    var title: String? = nil
    let text: LocalizedStringKey

    var body: some SwiftUI.View {
        HStack(alignment: .top, spacing: 11) {
            SwiftUI.Text(num)
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.white)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [CSSTheme.suiPrimary, CSSTheme.suiSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .shadow(color: CSSTheme.suiPrimary.opacity(0.25), radius: 3, x: 0, y: 2)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                if let title = title {
                    SwiftUI.Text(title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CSSTheme.suiPureBlack)
                }
                SwiftUI.Text(text)
                    .font(.system(size: 13.8, weight: .regular))
                    .foregroundColor(CSSTheme.suiPureBlack)
                    .lineSpacing(2.5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(11)
        .background(CSSTheme.suiInnerRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous)
                .stroke(CSSTheme.suiInnerBorder, lineWidth: 1)
        )
    }
}

private struct SettingsPairingSheetView: SwiftUI.View {
    @StateObject private var vm = SettingsPairingCheckViewModel()
    @StateObject private var wirelessVM = WirelessPairViewModel()
    @StateObject private var pairingMgmtVM = PairingFileManagementViewModel()

    @State private var statusBannerMessage: String? = nil
    @State private var isExportSheetPresented = false
    @State private var exportFileURL: URL? = nil
    @State private var didPressInstallPairing = false
    @State private var showDeleteConfirmAlert = false

    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)? = nil

    private var installedPairingURLForExport: URL? {
        if let url = wirelessVM.shareSheetURL, FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    statusHeaderCard
                    verificationAdviceCard

                    if let banner = statusBannerMessage {
                        HStack(spacing: 10) {
                            SwiftUI.Image(systemName: vm.isPairingOK ? "checkmark.seal.fill" : "info.circle.fill")
                                .foregroundColor(vm.isPairingOK ? CSSTheme.suiGreen : CSSTheme.suiPrimary)
                            SwiftUI.Text(banner)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(CSSTheme.suiPureBlack)
                            Spacer()
                        }
                        .padding(12)
                        .background((vm.isPairingOK ? CSSTheme.suiGreen : CSSTheme.suiPrimary).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous)
                                .stroke(CSSTheme.suiBorder, lineWidth: 1)
                        )
                    }

                    ios27DirectPairingCard
                    pcPairingGuideCard
                }
                .padding(16)
            }
            .background(CSSTheme.suiPageGradient.ignoresSafeArea())
            .navigationTitle("Pairing & Thiết Bị Ghép Nối")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        SwiftUI.Image(systemName: "iphone.radiowaves.left.and.right")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CSSTheme.suiPrimary)
                        SwiftUI.Text("Pairing & Thiết Bị Ghép Nối")
                            .font(.system(size: 16.5, weight: .bold))
                            .foregroundColor(CSSTheme.suiPrimary)
                            .lineLimit(1)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") {
                        if wirelessVM.isAdvertising {
                            wirelessVM.togglePairing()
                        }
                        vm.setWirelessPairingActive(false)
                        vm.setViewVisible(false)
                        onDismiss?()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(CSSTheme.suiPrimary)
                }
            }
            .onAppear {
                vm.setViewVisible(true)
            }
            .onDisappear {
                if wirelessVM.isAdvertising {
                    wirelessVM.togglePairing()
                }
                vm.setWirelessPairingActive(false)
                vm.setViewVisible(false)
                onDismiss?()
            }
            .alert("Xoá tệp Pairing?", isPresented: $showDeleteConfirmAlert) {
                SwiftUI.Button("Xoá", role: .destructive) {
                    vm.deleteAllPairingFiles()
                    statusBannerMessage = "Đã xoá toàn bộ tệp Pairing khỏi ứng dụng."
                }
                SwiftUI.Button("Huỷ", role: .cancel) {}
            } message: {
                SwiftUI.Text("Tệp Pairing hiện tại sẽ bị xoá hoàn toàn khỏi ứng dụng. Bạn sẽ cần ghép nối lại hoặc nhập tệp mới để cài đặt và gia hạn ứng dụng.")
            }
            #if !os(tvOS)
            .fileImporter(
                isPresented: $pairingMgmtVM.showFileImporter,
                allowedContentTypes: pairingMgmtVM.allowedPairingTypes
            ) { result in
                pairingMgmtVM.handleImportResult(result)
                Task { @MainActor in
                    let proto = PairingFileManager.shared.persistedActiveProtocol
                        ?? PairingFileManager.shared.preferredProtocol
                        ?? .rppairing
                    try? await minimuxerSwitchPairingProtocol(to: proto)
                    if case .success = result {
                        vm.markPairingVerifiedImmediately()
                        statusBannerMessage = "Đã nạp và kích hoạt tệp Pairing thành công!"
                    }
                    await vm.checkAllStatuses(forceVerify: true)
                }
            }
            #endif
            .sheet(isPresented: Binding(
                get: { wirelessVM.pinCode != nil && !isExportSheetPresented },
                set: { if !$0 { wirelessVM.pinCode = nil } }
            )) {
                if let pin = wirelessVM.pinCode {
                    if #available(iOS 16.0, tvOS 16.0, *) {
                        WirelessPairPinDialog(pin: pin) { wirelessVM.pinCode = nil }
                            .presentationDetents([.fraction(0.45), .medium])
                            .presentationDragIndicator(.visible)
                    } else {
                        WirelessPairPinDialog(pin: pin) { wirelessVM.pinCode = nil }
                    }
                }
            }
            .sheet(isPresented: $isExportSheetPresented) {
                if let fileURL = exportFileURL {
                    ActivityViewController(activityItems: [fileURL])
                }
            }
            .onChange(of: wirelessVM.isAdvertising) { advertising in
                vm.setWirelessPairingActive(advertising)
            }
            .onChange(of: wirelessVM.pairedDevice != nil) { isPaired in
                if isPaired, let pairedURL = wirelessVM.shareSheetURL {
                    wirelessVM.pinCode = nil
                    wirelessVM.isShareSheetPresented = false
                    vm.setWirelessPairingActive(false)

                    PairingFileManager.shared.resetAllPairingFiles()
                    try? PairingFileManager.shared.importPairingFile(from: pairedURL, preferred: .rppairing)
                    Task { @MainActor in
                        try? await minimuxerSwitchPairingProtocol(to: .rppairing)
                        vm.markPairingVerifiedImmediately()
                        await vm.checkAllStatuses(forceVerify: true)
                        statusBannerMessage = "Đã ghép nối và kích hoạt tệp Pairing thành công!"
                    }
                }
            }
        }
        .preferredColorScheme(.light)
        .environment(\.colorScheme, .light)
    }

    private var statusHeaderCard: some SwiftUI.View {
        let state = vm.pairingVisualState

        let badgeColor: SwiftUI.Color = {
            switch state {
            case .verifiedOK: return CSSTheme.suiGreen
            case .actionRequired: return CSSTheme.suiNeutralInspect
            case .failedError: return CSSTheme.suiRed
            }
        }()

        let badgeIcon: String = {
            switch state {
            case .verifiedOK: return "checkmark.shield.fill"
            case .actionRequired: return "doc.text.magnifyingglass"
            case .failedError: return "xmark.shield.fill"
            }
        }()

        let headerTitle: String = {
            switch state {
            case .verifiedOK:
                return "Thiết Bị Đã Ghép Nối Ổn Định (Tích Xanh)"
            case .actionRequired:
                return "Đã Lưu Pairing • Đang Chờ Xác Minh Kết Nối"
            case .failedError:
                return !vm.hasAnyStoredPairingFile
                    ? "Chưa Có Tệp Pairing (Tích Đỏ)"
                    : "Tệp Pairing Lỗi Hoặc Hết Hạn (Tích Đỏ)"
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(badgeColor.opacity(0.15))
                        .frame(width: 48, height: 48)
                    SwiftUI.Image(systemName: badgeIcon)
                        .font(.system(size: 23, weight: .bold))
                        .foregroundColor(badgeColor)
                }
                VStack(alignment: .leading, spacing: 4) {
                    SwiftUI.Text(headerTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(CSSTheme.suiPureBlack)

                    if !vm.pairingProtocol.isEmpty {
                        SwiftUI.Text(vm.pairingProtocol)
                            .font(.system(size: 13.2, weight: .semibold))
                            .foregroundColor(CSSTheme.suiPureBlack.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }

            Divider()

            HStack(spacing: 10) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(vm.isVpnOK ? CSSTheme.suiGreen : CSSTheme.suiRed)
                        .frame(width: 8, height: 8)
                    SwiftUI.Text(vm.isVpnOK ? "LocalDevVPN: Đã bật (\(vm.tunnelIP))" : "LocalDevVPN: Chưa bật")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(CSSTheme.suiPureBlack)
                }

                Spacer()

                SwiftUI.Button {
                    Task { await vm.checkAllStatuses(forceVerify: true) }
                } label: {
                    HStack(spacing: 4) {
                        SwiftUI.Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11.5, weight: .heavy))
                        SwiftUI.Text("Kiểm tra lại")
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(CSSTheme.suiPrimary.opacity(0.14))
                    .foregroundColor(CSSTheme.suiPrimary)
                    .clipShape(Capsule())
                }
                .buttonStyle(SettingsBounceButtonStyle())
            }
        }
        .padding(14)
        .background(CSSTheme.suiCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(badgeColor.opacity(0.45), lineWidth: 1.5)
        )
        .shadow(color: CSSTheme.suiPrimary.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    private var verificationAdviceCard: some SwiftUI.View {
        SettingsSkySectionCard(
            title: "3 BƯỚC XÁC MINH TỆP PAIRING CHUẨN XÁC",
            icon: "checkmark.shield.fill",
            color: CSSTheme.suiPrimary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                SettingsGuideStepRow(
                    num: "1",
                    title: "Đảm bảo iPhone có kết nối mạng",
                    text: LocalizedStringKey("Bật **Wi-Fi** hoặc **Dữ liệu di động (4G/5G)** trên iPhone của bạn.")
                )

                SettingsGuideStepRow(
                    num: "2",
                    title: "Kích hoạt LocalDevVPN",
                    text: LocalizedStringKey("Mở ứng dụng **LocalDevVPN** và gạt bật kết nối VPN lên.")
                )

                SettingsGuideStepRow(
                    num: "3",
                    title: "Kiểm tra độc lập (Tắt cả Wi-Fi & 4G, chỉ để LocalDevVPN)",
                    text: LocalizedStringKey("Để kiểm tra chính xác tuyệt đối, hãy tạm tắt cả **Wi-Fi** và **4G**, chỉ để lại **LocalDevVPN** đang bật rồi nhấn **Kiểm tra lại**.")
                )
            }

            SwiftUI.Text("💡 Ngay sau khi thực hiện, khung trạng thái phía trên sẽ tự động báo Tích Xanh (Pairing hoạt động tốt) hoặc Tích Đỏ (Pairing bị lỗi / cần ghép nối lại).")
                .font(.system(size: 13.2, weight: .semibold))
                .foregroundColor(CSSTheme.suiPureBlack)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CSSTheme.suiNeutralInspect.opacity(0.11))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(CSSTheme.suiNeutralInspect.opacity(0.38), lineWidth: 1.2)
                )
        }
    }

    private var ios27DirectPairingCard: some SwiftUI.View {
        SettingsSkySectionCard(
            title: "PHẦN 1: GHÉP NỐI TRỰC TIẾP TRÊN IPHONE (IOS 27)",
            icon: "iphone.radiowaves.left.and.right",
            color: CSSTheme.suiPrimary
        ) {
            SwiftUI.Text("Tự tạo & kích hoạt Pairing trực tiếp không cần máy tính")
                .font(.system(size: 15.5, weight: .bold))
                .foregroundColor(CSSTheme.suiSecondary)

            VStack(alignment: .leading, spacing: 10) {
                SettingsGuideStepRow(
                    num: "1",
                    title: "Bắt đầu phát tín hiệu ghép nối",
                    text: LocalizedStringKey("Nhấn vào nút **\"Bắt đầu ghép nối trên iPhone\"** ở bên dưới để ứng dụng phát tín hiệu.")
                )

                SettingsGuideStepRow(
                    num: "2",
                    title: "Mở Chế độ nhà phát triển trong Cài đặt",
                    text: LocalizedStringKey("Thoát ra màn hình chính (không vuốt tắt ứng dụng), mở **Cài đặt (Settings)** ➔ **Quyền riêng tư & Bảo mật** ➔ kéo xuống cuối chọn **Chế độ nhà phát triển (Developer Mode)**.")
                )

                SettingsGuideStepRow(
                    num: "3",
                    title: "Nhập mã PIN 6 chữ số (Tự động nạp & kích hoạt)",
                    text: LocalizedStringKey("Trong Chế độ nhà phát triển, xoá thiết bị ghép đôi cũ (nếu có), sau đó chạm vào **Pair with SideStore** và nhập mật khẩu màn hình. Xem **mã 6 chữ số** hiện từ ứng dụng này, nhập vào Cài đặt và nhấn **Ghép đôi**. Ứng dụng sẽ **tự động nạp và kích hoạt Pairing ngay lập tức**!")
                )

                SettingsGuideStepRow(
                    num: "4",
                    title: "Xuất tệp Pairing lưu dự phòng (Khuyên dùng)",
                    text: LocalizedStringKey("Sau khi ghép nối xong, hãy nhấn nút **“Xuất tệp Pairing (Lưu dự phòng)”** (màu xanh lá) ➔ chọn **Lưu vào Tệp (Save to Files)** để cất giữ dự phòng khi cài lại ứng dụng.")
                )
            }

            Divider().padding(.vertical, 2)

            VStack(spacing: 10) {
                if let pin = wirelessVM.pinCode {
                    VStack(spacing: 6) {
                        SwiftUI.Text("MÃ PIN GHÉP NỐI 6 CHỮ SỐ")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(CSSTheme.suiPrimary)
                        SwiftUI.Text(pin)
                            .font(.system(size: 30, weight: .heavy, design: .monospaced))
                            .tracking(6)
                            .foregroundColor(CSSTheme.suiPureBlack)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 18)
                            .background(RoundedRectangle(cornerRadius: 10).fill(CSSTheme.suiPrimary.opacity(0.12)))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                }

                if let errorMsg = wirelessVM.errorMessage {
                    SwiftUI.Text(errorMsg)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(CSSTheme.suiRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SwiftUI.Button {
                    didPressInstallPairing = true
                    wirelessVM.togglePairing()
                    vm.setWirelessPairingActive(wirelessVM.isAdvertising)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: wirelessVM.isAdvertising ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text(wirelessVM.isAdvertising
                                     ? "Dừng ghép nối (Đang phát tín hiệu...)"
                                     : "Bắt đầu ghép nối trên iPhone")
                            .font(.system(size: 15.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(wirelessVM.isAdvertising ? CSSTheme.suiRed : CSSTheme.suiPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: (wirelessVM.isAdvertising ? CSSTheme.suiRed : CSSTheme.suiPrimary).opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(SettingsBounceButtonStyle())

                if didPressInstallPairing || installedPairingURLForExport != nil {
                    SwiftUI.Button {
                        if let pairedURL = installedPairingURLForExport {
                            wirelessVM.pinCode = nil
                            exportFileURL = pairedURL
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isExportSheetPresented = true
                            }
                        } else {
                            statusBannerMessage = "Vui lòng hoàn tất Bước 2 & Bước 3 (nhập mã 6 chữ số trong Cài đặt ➔ Chế độ nhà phát triển) trước khi xuất tệp dự phòng."
                        }
                    } label: {
                        HStack(spacing: 8) {
                            SwiftUI.Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 17, weight: .bold))
                            SwiftUI.Text("Xuất tệp Pairing (Lưu dự phòng)")
                                .font(.system(size: 15.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(installedPairingURLForExport != nil ? CSSTheme.suiGreen : CSSTheme.suiGreen.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .shadow(color: CSSTheme.suiGreen.opacity(0.35), radius: 6, x: 0, y: 4)
                    }
                    .buttonStyle(SettingsBounceButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }

                SwiftUI.Button {
                    pairingMgmtVM.promptImport(for: .rppairing)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Nhập tệp Pairing có sẵn (Từ Tệp)")
                            .font(.system(size: 15.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CSSTheme.suiSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: CSSTheme.suiSecondary.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(SettingsBounceButtonStyle())

                SwiftUI.Button {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Xoá tệp Pairing hiện tại")
                            .font(.system(size: 15.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CSSTheme.suiRed)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: CSSTheme.suiRed.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(SettingsBounceButtonStyle())
            }
            .padding(12)
            .background(CSSTheme.suiInnerRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous)
                    .stroke(CSSTheme.suiInnerBorder, lineWidth: 1)
            )
        }
    }

    private var pcPairingGuideCard: some SwiftUI.View {
        SettingsSkySectionCard(
            title: "PHẦN 2: GHÉP NỐI QUA MÁY TÍNH (DƯỚI IOS 27 - PC / MAC)",
            icon: "laptopcomputer.and.iphone",
            color: CSSTheme.suiSecondary
        ) {
            SwiftUI.Text("Tạo hoặc nạp tệp Pairing từ Windows / macOS / Linux")
                .font(.system(size: 15.5, weight: .bold))
                .foregroundColor(CSSTheme.suiSecondary)

            HStack(alignment: .top, spacing: 8) {
                SwiftUI.Image(systemName: "info.circle.fill")
                    .foregroundColor(CSSTheme.suiPrimary)
                    .font(.system(size: 16, weight: .bold))
                    .padding(.top, 1)
                SwiftUI.Text(LocalizedStringKey("**Chuẩn bị chung:** Trên Windows cần cài đặt **iTunes** & **iCloud** bản chính chủ từ Apple (không dùng bản Microsoft Store). Cắm cáp kết nối iPhone với máy tính, mở khóa màn hình iPhone và nhấn **Tin cậy (Trust)** + nhập mật khẩu. Chọn **1 trong 3 công cụ** dưới đây:"))
                    .font(.system(size: 13.5, weight: .regular))
                    .foregroundColor(CSSTheme.suiPureBlack)
                    .lineSpacing(2)
            }
            .padding(12)
            .background(CSSTheme.suiPrimary.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CSSTheme.suiPrimary.opacity(0.28), lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 10) {
                SettingsGuideStepRow(
                    num: "1",
                    title: "Cách 1: Dùng idevice_pair (Khuyên dùng - Hỗ trợ nạp thẳng & xuất tệp)",
                    text: LocalizedStringKey("• Mở **idevice_pair** trên máy tính và chọn thiết bị iPhone của bạn.\n• **Nạp thẳng vào ứng dụng:** Chọn **SideStore** hoặc **LiveContainer** trong danh sách rồi nhấn **Load / Install Pairing File** để chép thẳng vào ứng dụng.\n• **Xuất tệp `.mobiledevicepairing` dự phòng:** Nhấn **Generate** ➔ **Export / Save** để lưu tệp ra máy tính, gửi sang iPhone (qua AirDrop, Zalo, iCloud Drive), chọn **Lưu vào Tệp** rồi nhấn nút **“Nhập tệp Pairing”** bên dưới.")
                )

                SettingsGuideStepRow(
                    num: "2",
                    title: "Cách 2: Dùng jitterbugpair (Xuất tệp `.mobiledevicepairing` ra máy tính)",
                    text: LocalizedStringKey("• Tải và giải nén **jitterbugpair** (trên Windows/macOS/Linux).\n• Giữ màn hình iPhone luôn sáng và mở khóa, sau đó chạy **`jitterbugpair.exe`** (Windows) hoặc **`./jitterbugpair`** trong Terminal (Mac).\n• Công cụ sẽ tạo ra tệp **`<UDID>.mobiledevicepairing`** nằm cùng thư mục. Hãy gửi tệp đó sang iPhone ➔ **Lưu vào Tệp (Save to Files)** ➔ nhấn nút **“Nhập tệp Pairing”** bên dưới.")
                )

                SettingsGuideStepRow(
                    num: "3",
                    title: "Cách 3: Dùng iLoader (Tự động nạp trực tiếp vào ứng dụng)",
                    text: LocalizedStringKey("• Mở **iLoader** trên máy tính và kết nối với iPhone đã nhấn Tin cậy.\n• Chọn tính năng **Generate / Place Pairing File** để tự động tạo và nạp trực tiếp (Inject) tệp Pairing vào **SideStore / LiveContainer**.\n• Sau khi hoàn tất trên máy tính, hãy mở lại mục này để ứng dụng tự động nhận diện.")
                )
            }

            VStack(spacing: 10) {
                SwiftUI.Button {
                    pairingMgmtVM.promptImport(for: .rppairing)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "folder.fill.badge.plus")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Nhập tệp Pairing (Từ ứng dụng Tệp)")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(CSSTheme.suiPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: CSSTheme.suiPrimary.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(SettingsBounceButtonStyle())

                SwiftUI.Button {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Xoá tệp Pairing hiện tại")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(CSSTheme.suiRed)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .shadow(color: CSSTheme.suiRed.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(SettingsBounceButtonStyle())
            }
            .padding(.top, 4)
        }
    }
}

extension SettingsViewController
{
    fileprivate enum Section: Int, CaseIterable
    {
        case signIn
        case account
        case patreon
        case display
        case appRefresh
        case instructions
        case techyThings
        case credits
        case betaTesting
        case advancedSettings
        case diagnostics
    }

    fileprivate enum AppRefreshRow: Int, CaseIterable
    {
        case backgroundRefresh
        case noIdleTimeout
        case addToSiri
        case disableAppLimit
        
        static var allCases: [AppRefreshRow] {
            return []
        }
    }

    fileprivate enum CreditsRow: Int, CaseIterable
    {
        case developer
        case operations
        case designer
        case softwareLicenses
    }

    fileprivate enum TechyThingsRow: Int, CaseIterable
    {
        case healthCheck
        case errorLog
        case storageExplorer
        case clearCache
        
        static var allCases: [TechyThingsRow] {
            return [.errorLog, .clearCache]
        }
    }

    fileprivate enum AdvancedSettingsRow: Int, CaseIterable
    {
        case sendFeedback
        case refreshAttempts
        case refreshSideJITServer
        case pairingFileManagement
        case anisetteServers
        case connectionConfig
        case networkDiscovery
        case developerServices
        case profileManagement
        case certificateManagement
        case backupAndRestore
        case userCustomizations
        
        static var allCases: [AdvancedSettingsRow] {
            return [
                .anisetteServers,
                .pairingFileManagement,
                .refreshAttempts,
                .refreshSideJITServer,
                .certificateManagement,
                .userCustomizations
            ]
        }
    }

    fileprivate enum BetaTestingRow: Int, CaseIterable {
        case betaUpdates
        case betaTrack
        
        static var allCases: [BetaTestingRow] {
            return []
        }
    }

    fileprivate enum DiagnosticsRow: Int, CaseIterable
    {
        case developerOptions
        case experimentalFeatures
        
        static var allCases: [DiagnosticsRow] {
            return []
        }
    }

    // MARK: - 📦 GỘP TẤT CẢ CÁC MỤC CÀI ĐẶT THÀNH 1 MỤC DUY NHẤT CHUẨN GỐC
    fileprivate enum UnifiedSettingsItem: CaseIterable
    {
        case anisetteServers
        case pairingAndDevices
        case refreshAttempts
        case refreshSideJITServer
        case certificateManagement
        case userCustomizations
        case errorLog
        case clearCache

        static var activeItems: [UnifiedSettingsItem] {
            return [
                .anisetteServers,
                .pairingAndDevices,
                .refreshAttempts,
                .refreshSideJITServer,
                .certificateManagement,
                .userCustomizations,
                .errorLog,
                .clearCache
            ]
        }

        // Cấu hình Icon SF Symbols & Màu sắc riêng biệt cho từng mục
        var iconSpec: (symbol: String, color: UIColor, showChevron: Bool) {
            switch self {
            case .anisetteServers:
                return ("server.rack", CSSTheme.blue, true)
            case .pairingAndDevices:
                return ("iphone.radiowaves.left.and.right", CSSTheme.purple, true)
            case .refreshAttempts:
                return ("clock.arrow.circlepath", CSSTheme.green, true)
            case .refreshSideJITServer:
                return ("bolt.horizontal.circle.fill", CSSTheme.orange, true)
            case .certificateManagement:
                return ("checkmark.shield.fill", CSSTheme.purple, true)
            case .userCustomizations:
                return ("paintbrush.pointed.fill", CSSTheme.indigo, true)
            case .errorLog:
                return ("doc.text.magnifyingglass", CSSTheme.teal, true)
            case .clearCache:
                return ("trash.fill", CSSTheme.magenta, false)
            }
        }

        // Ánh xạ chính xác về IndexPath gốc trên Storyboard để giữ nguyên UI và Segue
        var originalIndexPath: IndexPath {
            switch self {
            case .anisetteServers:
                return IndexPath(row: AdvancedSettingsRow.anisetteServers.rawValue, section: Section.advancedSettings.rawValue)
            case .pairingAndDevices:
                return IndexPath(row: AdvancedSettingsRow.pairingFileManagement.rawValue, section: Section.advancedSettings.rawValue)
            case .refreshAttempts:
                return IndexPath(row: AdvancedSettingsRow.refreshAttempts.rawValue, section: Section.advancedSettings.rawValue)
            case .refreshSideJITServer:
                return IndexPath(row: AdvancedSettingsRow.refreshSideJITServer.rawValue, section: Section.advancedSettings.rawValue)
            case .certificateManagement:
                return IndexPath(row: AdvancedSettingsRow.certificateManagement.rawValue, section: Section.advancedSettings.rawValue)
            case .userCustomizations:
                return IndexPath(row: AdvancedSettingsRow.userCustomizations.rawValue, section: Section.advancedSettings.rawValue)
            case .errorLog:
                return IndexPath(row: TechyThingsRow.errorLog.rawValue, section: Section.techyThings.rawValue)
            case .clearCache:
                return IndexPath(row: TechyThingsRow.clearCache.rawValue, section: Section.techyThings.rawValue)
            }
        }
    }
}

final class SettingsViewController: UITableViewController
{
    private var activeTeam: ALTTeam?
    private var accountStatus: AccountVerificationRow.Status = .completed
    private var accountVerificationTask: Task<Void, Never>?

    // Trạng thái ẩn/hiện khung thông tin Tài khoản (Mặc định: Ẩn)
    private var isAccountDetailsExpanded: Bool = false

    private var prototypeHeaderFooterView: SettingsHeaderFooterView!
    private var heroGradientLayer: CAGradientLayer?

    // Nút quay lại nhỏ cố định ở góc trên bên trái khi vào mục con
    private var floatingBackButton: UIButton?

    // Bộ đệm hình ảnh Icon (28x28) gắn trực tiếp vào Label giúp không bao giờ đè viền hoặc đè chữ
    private static var inlineBadgeImageCache: [String: UIImage] = [:]

    @IBOutlet private var betaTrackLabel: UILabel!
    @IBOutlet private var betaTrackPopupButton: UIButton!

    private var debugGestureCounter = 0
    private weak var debugGestureTimer: Timer?

    @IBOutlet private var accountNameLabel: UILabel!
    @IBOutlet private var accountEmailLabel: UILabel!
    @IBOutlet private var accountTypeLabel: UILabel!

    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var noIdleTimeoutSwitch: UISwitch!
    @IBOutlet private var disableAppLimitSwitch: UISwitch!
    @IBOutlet private var betaUpdatesSwitch: UISwitch!
    @IBOutlet private var verboseOperationsLoggingSwitch: UISwitch!
    @IBOutlet private var altSignVerboseLoggingSwitch: UISwitch!
    @IBOutlet private var minimuxerVerboseLoggingSwitch: UISwitch!
    @IBOutlet private var rotateLogsOnStartupSwitch: UISwitch!
    @IBOutlet private var disableResponseCachingSwitch: UISwitch!

    @IBOutlet private var mastodonButton: UIButton!
    @IBOutlet private var threadsButton: UIButton!
    @IBOutlet private var twitterButton: UIButton!
    @IBOutlet private var githubButton: UIButton!

    @IBOutlet private var versionLabel: UILabel!
    @IBOutlet private var recreateDatabaseSwitch: UISwitch!

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    private static var exportDBInProgress = false
    private static var deleteDBInProgress = false

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openPatreonSettings(_:)), name: AppDelegate.openPatreonSettingsDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }

    deinit
    {
        NotificationCenter.default.removeObserver(self)
    }

    // Tắt cứng toàn bộ tính năng Làm mới ứng dụng, Beta Updates và Developer Mode
    private func forceDisableRemovedSettings() {
        UserDefaults.standard.isBackgroundRefreshEnabled = false
        UserDefaults.standard.isIdleTimeoutDisableEnabled = false
        UserDefaults.standard.isAppLimitDisabled = false
        UserDefaults.standard.isBetaUpdatesEnabled = false
        UserDefaults.standard.isDebugModeEnabled = false
        
        self.backgroundRefreshSwitch?.isOn = false
        self.noIdleTimeoutSwitch?.isOn = false
        self.disableAppLimitSwitch?.isOn = false
        self.betaUpdatesSwitch?.isOn = false
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Khóa cứng chế độ Sáng (Light Mode) để không bao giờ bị hệ thống đổi màu nền cell/chữ
        self.overrideUserInterfaceStyle = .light
        self.tableView.overrideUserInterfaceStyle = .light
        
        self.forceDisableRemovedSettings()
        
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        #endif
        
        let nib = UINib(nibName: "SettingsHeaderFooterView", bundle: nil)
        self.prototypeHeaderFooterView = nib.instantiate(withOwner: nil, options: nil)[0] as? SettingsHeaderFooterView
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "HeaderFooterView")
        
        self.versionLabel.attributedText = getVersionAttributedString()
        self.versionLabel.isUserInteractionEnabled = true
        self.versionLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyVersionLabelTapped)))
        self.versionLabel.numberOfLines = 0
        self.versionLabel.lineBreakMode = .byWordWrapping
        self.versionLabel.setNeedsUpdateConstraints()
        
        self.tableView.contentInset.top = 0
        self.tableView.contentInset.bottom = 50
        if #available(iOS 15.0, tvOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 0
        }
        
        // ✨ KÍCH HOẠT GIAO DIỆN WEB CSS, ICON & VIỆT HÓA ✨
        self.applySmartWebCSSTheme()
        
        self.update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let heroHeader = self.tableView.tableHeaderView,
           let heroCard = heroHeader.subviews.first {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
        // Đảm bảo sau khi InsetGroupTableViewCell.layoutSubviews() chạy xong, nền trắng #FFFFFF của cả 3 dòng Tài khoản luôn đồng nhất 100%
        self.enforceUniformWhiteBackgroundOnAccountRows()
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.forceDisableRemovedSettings()
        self.update()
        self.restoreVisibleCellsWhiteBackground()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.restoreVisibleCellsWhiteBackground()
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.accountVerificationTask?.cancel()
    }

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "anisetteServers" || identifier == "pairingFileManagement" {
            return false
        }
        return super.shouldPerformSegue(withIdentifier: identifier, sender: sender)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let controller = segue.destination
        controller.title = nil
        controller.navigationItem.title = nil
        #if !os(tvOS)
        controller.navigationItem.largeTitleDisplayMode = .never
        #endif
        
        if segue.identifier == "anisetteServers" || segue.identifier == "developerServices" || segue.identifier == "profileManagement" || segue.identifier == "certificateManagement" || segue.identifier == "diagnostics" {
            self.show(controller, sender: nil)
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }
}

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ CỐ ĐỊNH Ở MỤC CON
extension SettingsViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.setNavigationBarHidden(true, animated: false)
        viewController.title = nil
        viewController.navigationItem.title = nil
        #if !os(tvOS)
        viewController.navigationItem.largeTitleDisplayMode = .never
        #endif

        let isRoot = (viewController === navigationController.viewControllers.first)
        updateFloatingBackButton(in: navigationController, show: !isRoot)
    }

    private func updateFloatingBackButton(in nav: UINavigationController, show: Bool) {
        if !show && self.floatingBackButton == nil {
            return
        }

        if self.floatingBackButton == nil {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
            btn.tintColor = CSSTheme.blue
            btn.backgroundColor = CSSTheme.white.withAlphaComponent(0.95)
            
            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.1
            btn.layer.borderColor = CSSTheme.border.cgColor
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowRadius = 6
            btn.layer.shadowOpacity = 0.15
            
            btn.addTarget(self, action: #selector(handleFloatingBackTap), for: .touchUpInside)
            nav.view.addSubview(btn)
            
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                btn.topAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.topAnchor, constant: 6),
                btn.widthAnchor.constraint(equalToConstant: 34),
                btn.heightAnchor.constraint(equalToConstant: 34)
            ])
            
            self.floatingBackButton = btn
        }
        
        guard let btn = self.floatingBackButton else { return }
        nav.view.bringSubviewToFront(btn)
        
        UIView.animate(withDuration: 0.2) {
            btn.alpha = show ? 1.0 : 0.0
            btn.isHidden = !show
        }
    }

    @objc private func handleFloatingBackTap() {
        self.navigationController?.popViewController(animated: true)
    }
}

// MARK: - ✨ HỆ THỐNG RENDER CSS, ICON INLINE & VIỆT HÓA TOÀN DIỆN
private extension SettingsViewController {

    private func applySmartWebCSSTheme() {
        // 1. Nền Body cố định: Không bao giờ bị trắng khi lướt xuống dưới
        let bgView = CSSGradientBackgroundView(frame: UIScreen.main.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.backgroundView = bgView
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        
        // 2. Tạo khối .hero Banner kèm Icon SideStore nổi bật
        setupCSSHeroBanner()
        
        // 3. Tạo Footer hiển thị Lời cảm ơn gọn gàng + Phiên bản
        setupVersionTableFooterView()
        
        // 4. Cấu hình TabBar đồng bộ màu
        #if !os(tvOS)
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = CSSTheme.blue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif
        
        // 5. Làm đẹp các công tắc UISwitch (Đổ bóng Neon)
        let switches = [
            self.backgroundRefreshSwitch, self.noIdleTimeoutSwitch, self.disableAppLimitSwitch,
            self.betaUpdatesSwitch, self.verboseOperationsLoggingSwitch, self.altSignVerboseLoggingSwitch,
            self.minimuxerVerboseLoggingSwitch, self.rotateLogsOnStartupSwitch,
            self.disableResponseCachingSwitch, self.recreateDatabaseSwitch
        ]
        
        for sw in switches {
            guard let sw = sw else { continue }
            sw.onTintColor = CSSTheme.blue
            sw.thumbTintColor = CSSTheme.white
            sw.layer.shadowColor = CSSTheme.blue.cgColor
            sw.layer.shadowOffset = CGSize(width: 0, height: 3)
            sw.layer.shadowRadius = 6
            sw.layer.shadowOpacity = 0.28
        }
    }

    private func loadSideStoreAppIcon() -> UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let lastIcon = files.last,
           let image = UIImage(named: lastIcon) {
            return image
        }
        if let image = UIImage(named: "AppIcon60x60") ?? UIImage(named: "AppIcon") {
            return image
        }
        return nil
    }

    // Tạo khối .hero Banner sang trọng có gắn Icon SideStore & Huy hiệu xác thực
    private func setupCSSHeroBanner() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 112))
        headerContainer.backgroundColor = .clear
        
        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = CSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = CSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 7)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.28
        
        let gradient = CAGradientLayer()
        gradient.colors = [CSSTheme.heroStart, CSSTheme.heroEnd]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = CSSTheme.cornerRadius
        gradient.borderWidth = 1.2
        gradient.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
        heroCard.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient
        
        let iconBadge = UIView()
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.backgroundColor = UIColor.white.withAlphaComponent(0.20)
        iconBadge.layer.cornerRadius = 11
        iconBadge.layer.borderWidth = 1.0
        iconBadge.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        
        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        if let appIcon = loadSideStoreAppIcon() {
            iconImageView.image = appIcon
            iconImageView.layer.cornerRadius = 8
            iconImageView.clipsToBounds = true
        } else {
            let symConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            iconImageView.image = UIImage(systemName: "cube.box.fill", withConfiguration: symConfig)
            iconImageView.tintColor = .white
        }
        iconBadge.addSubview(iconImageView)
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "SideStore"
        titleLabel.font = UIFont.systemFont(ofSize: 25, weight: .heavy)
        titleLabel.textColor = CSSTheme.white
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.28

        let verifiedIcon = UIImageView()
        verifiedIcon.translatesAutoresizingMaskIntoConstraints = false
        let verifiedConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        verifiedIcon.image = UIImage(systemName: "checkmark.seal.fill", withConfiguration: verifiedConfig)
        verifiedIcon.tintColor = UIColor(red: 140/255, green: 255/255, blue: 195/255, alpha: 1.0)
        
        let titleStack = UIStackView(arrangedSubviews: [iconBadge, titleLabel, verifiedIcon])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 9
        
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "✨ Tùy chỉnh & quản lý trải nghiệm cài đặt ứng dụng của bạn"
        subLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        subLabel.textColor = CSSTheme.white.withAlphaComponent(0.96)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2
        
        heroCard.addSubview(titleStack)
        heroCard.addSubview(subLabel)
        headerContainer.addSubview(heroCard)
        
        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),
            
            iconBadge.widthAnchor.constraint(equalToConstant: 34),
            iconBadge.heightAnchor.constraint(equalToConstant: 34),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 26),
            iconImageView.heightAnchor.constraint(equalToConstant: 26),
            
            titleStack.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleStack.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),
            
            subLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14)
        ])
        
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
        
        self.tableView.tableHeaderView = headerContainer
    }

    private func createCompactCreditChip(title: String, iconName: String, color: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        let config = UIImage.SymbolConfiguration(pointSize: 10.5, weight: .bold)
        let icon = UIImage(systemName: iconName, withConfiguration: config)
        btn.setImage(icon, for: .normal)
        btn.setTitle("  \(title)  ", for: .normal)
        btn.tintColor = color
        btn.setTitleColor(color, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        btn.backgroundColor = color.withAlphaComponent(0.10)
        btn.layer.cornerRadius = 12
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = color.withAlphaComponent(0.28).cgColor
        btn.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.heightAnchor.constraint(equalToConstant: 25)
        ])
        return btn
    }

    // Chân trang gọn đẹp: Thẻ Lời cảm ơn rút gọn kèm Icon + Phiên bản ứng dụng
    private func setupVersionTableFooterView() {
        let footerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 196))
        footerContainer.backgroundColor = .clear

        let thanksCard = UIView()
        thanksCard.translatesAutoresizingMaskIntoConstraints = false
        thanksCard.backgroundColor = CSSTheme.white
        thanksCard.layer.cornerRadius = CSSTheme.cornerRadius
        thanksCard.layer.borderWidth = 1.1
        thanksCard.layer.borderColor = CSSTheme.border.cgColor
        thanksCard.layer.shadowColor = CSSTheme.blue.cgColor
        thanksCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        thanksCard.layer.shadowRadius = 10
        thanksCard.layer.shadowOpacity = 0.08

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "❤️ LỜI CẢM ƠN & TRI ÂN"
        titleLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .heavy)
        titleLabel.textColor = CSSTheme.blue
        titleLabel.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3.5

        let bodyText = """
        Tri ân đội ngũ phát triển & cộng đồng mã nguồn mở:
        SideStore Team (@sidestoreio) • Giao diện: @lit_ritt
        Nền tảng AltStore: Riley Testut & Cộng đồng
        """
        bodyLabel.attributedText = NSAttributedString(
            string: bodyText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: CSSTheme.pureBlack,
                .paragraphStyle: paragraph
            ]
        )

        let btnSideStore = createCompactCreditChip(title: "@sidestoreio", iconName: "sparkles", color: CSSTheme.blue, action: #selector(openSideStoreTwitterChip))
        let btnLitRitt = createCompactCreditChip(title: "@lit_ritt", iconName: "paintbrush.fill", color: CSSTheme.purple, action: #selector(openLitRittTwitterChip))
        let btnGitHub = createCompactCreditChip(title: "GitHub", iconName: "chevron.left.forwardslash.chevron.right", color: CSSTheme.pureBlack, action: #selector(followAltStoreGitHub))

        let chipStack = UIStackView(arrangedSubviews: [btnSideStore, btnLitRitt, btnGitHub])
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.alignment = .center
        chipStack.distribution = .equalSpacing

        thanksCard.addSubview(titleLabel)
        thanksCard.addSubview(bodyLabel)
        thanksCard.addSubview(chipStack)

        let vLabel = UILabel()
        vLabel.tag = 7771
        vLabel.translatesAutoresizingMaskIntoConstraints = false
        vLabel.attributedText = getVersionAttributedString()
        vLabel.numberOfLines = 0
        vLabel.textAlignment = .center
        vLabel.isUserInteractionEnabled = true
        vLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyVersionLabelTapped)))

        footerContainer.addSubview(thanksCard)
        footerContainer.addSubview(vLabel)

        NSLayoutConstraint.activate([
            thanksCard.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 6),
            thanksCard.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 16),
            thanksCard.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -16),

            titleLabel.topAnchor.constraint(equalTo: thanksCard.topAnchor, constant: 11),
            titleLabel.leadingAnchor.constraint(equalTo: thanksCard.leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(equalTo: thanksCard.trailingAnchor, constant: -12),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: thanksCard.leadingAnchor, constant: 12),
            bodyLabel.trailingAnchor.constraint(equalTo: thanksCard.trailingAnchor, constant: -12),

            chipStack.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 9),
            chipStack.centerXAnchor.constraint(equalTo: thanksCard.centerXAnchor),
            chipStack.bottomAnchor.constraint(equalTo: thanksCard.bottomAnchor, constant: -11),

            vLabel.topAnchor.constraint(equalTo: thanksCard.bottomAnchor, constant: 12),
            vLabel.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 16),
            vLabel.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -16)
        ])

        self.tableView.tableFooterView = footerContainer
    }

    @objc private func openSideStoreTwitterChip() {
        self.openTwitter(username: "sidestoreio")
    }

    @objc private func openLitRittTwitterChip() {
        self.openTwitter(username: "lit_ritt")
    }

    // Xác định cấu hình Icon (SF Symbol + Màu sắc + Chevron) cho từng dòng trong bảng
    private func iconSpecForRow(section: Section, row: Int) -> (symbol: String, color: UIColor, showChevron: Bool)? {
        switch section {
        case .signIn:
            return ("applelogo", CSSTheme.blue, true)
        case .account:
            switch row {
            case 0: return ("person.fill", CSSTheme.blue, false)
            case 1: return ("envelope.fill", CSSTheme.purple, false)
            case 2: return ("checkmark.seal.fill", CSSTheme.green, false)
            default: return nil
            }
        case .advancedSettings:
            let items = UnifiedSettingsItem.activeItems
            guard items.indices.contains(row) else { return nil }
            return items[row].iconSpec
        default:
            return nil
        }
    }

    // Vẽ biểu tượng ô vuông bo góc (28x28) sắc nét để nhúng trực tiếp vào Label (không bao giờ đè lên chữ hoặc viền)
    private func renderInlineBadgeImage(symbol: String, color: UIColor) -> UIImage {
        let key = "\(symbol)_\(color.description)"
        if let cached = Self.inlineBadgeImageCache[key] {
            return cached
        }
        let size = CGSize(width: 28, height: 28)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let bgPath = UIBezierPath(roundedRect: rect, cornerRadius: 7.5)
            color.withAlphaComponent(0.14).setFill()
            bgPath.fill()

            let borderPath = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 7.5)
            color.withAlphaComponent(0.28).setStroke()
            borderPath.lineWidth = 1.0
            borderPath.stroke()

            let config = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
            if let symImg = UIImage(systemName: symbol, withConfiguration: config)?.withTintColor(color, renderingMode: .alwaysOriginal) {
                let symOrigin = CGPoint(
                    x: (size.width - symImg.size.width) / 2.0,
                    y: (size.height - symImg.size.height) / 2.0
                )
                symImg.draw(at: symOrigin)
            }
        }
        Self.inlineBadgeImageCache[key] = image
        return image
    }

    // Gắn mũi tên điều hướng > cách lề phải của khung trắng (targetCardView) 18pt thoáng đẹp
    private func attachChevronInsideCard(cell: UITableViewCell, targetCardView: UIView, section: Section, row: Int) {
        let badgeTag = 8889
        let chevronTag = 8890
        cell.contentView.viewWithTag(badgeTag)?.removeFromSuperview()
        cell.contentView.viewWithTag(chevronTag)?.removeFromSuperview()
        targetCardView.viewWithTag(chevronTag)?.removeFromSuperview()

        cell.accessoryType = .none
        cell.accessoryView = nil

        guard let spec = iconSpecForRow(section: section, row: row), spec.showChevron else { return }

        let chevronView = UIImageView()
        chevronView.tag = chevronTag
        chevronView.translatesAutoresizingMaskIntoConstraints = false
        let chevConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        chevronView.image = UIImage(systemName: "chevron.right", withConfiguration: chevConfig)
        chevronView.tintColor = spec.color.withAlphaComponent(0.75)
        cell.contentView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            chevronView.trailingAnchor.constraint(equalTo: targetCardView.trailingAnchor, constant: -18),
            chevronView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
    }

    // Tìm chính xác khung Card bên trong InsetGroupTableViewCell mà không phụ thuộc vào frame.width hay private property
    private func resolveTargetCardView(for cell: UITableViewCell) -> UIView {
        if let cardView = cell.subviews.first(where: {
            $0 !== cell.contentView &&
            $0 !== cell.selectedBackgroundView &&
            $0 !== cell.backgroundView &&
            !($0 is UIControl)
        }) {
            return cardView
        }
        return cell.contentView
    }

    // Xóa sạch mọi màu nền xám/khác màu của các view trung gian trong Storyboard (đặc biệt ở dòng Loại tài khoản - Row 2)
    private func clearIntermediateBackgrounds(in view: UIView, keeping targetCardView: UIView) {
        for sub in view.subviews {
            if sub === targetCardView || sub is UIButton || sub is UISwitch || sub.tag == 8888 || sub.tag == 8889 || sub.tag == 8890 {
                continue
            }
            sub.backgroundColor = .clear
            clearIntermediateBackgrounds(in: sub, keeping: targetCardView)
        }
    }

    // Ép đồng bộ nền trắng tinh #FFFFFF tuyệt đối cho cả 3 dòng Họ tên (0), Email (1), Loại tài khoản (2)
    private func enforceUniformWhiteBackgroundOnAccountRows() {
        guard self.isViewLoaded else { return }
        for row in 0..<3 {
            let indexPath = IndexPath(row: row, section: Section.account.rawValue)
            guard let cell = self.tableView.cellForRow(at: indexPath) else { continue }
            cell.overrideUserInterfaceStyle = .light
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.backgroundView = nil
            if #available(iOS 14.0, tvOS 14.0, *) {
                var bgConfig = UIBackgroundConfiguration.clear()
                bgConfig.backgroundColor = .clear
                cell.backgroundConfiguration = bgConfig
            }
            let targetCardView = resolveTargetCardView(for: cell)
            targetCardView.overrideUserInterfaceStyle = .light
            targetCardView.backgroundColor = CSSTheme.white
            targetCardView.layer.backgroundColor = CSSTheme.white.cgColor
            clearIntermediateBackgrounds(in: cell.contentView, keeping: targetCardView)
        }
    }

    // Bóc tách lớp nền của InsetGroupTableViewCell để ép nhận diện 1 khung Card duy nhất + Icon
    private func styleInnerCardOfCell(_ cell: UITableViewCell, at indexPath: IndexPath, totalRows: Int) {
        cell.overrideUserInterfaceStyle = .light
        cell.selectionStyle = .none
        cell.backgroundView = nil
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = .clear
        if #available(iOS 14.0, tvOS 14.0, *) {
            var bgConfig = UIBackgroundConfiguration.clear()
            bgConfig.backgroundColor = .clear
            cell.backgroundConfiguration = bgConfig
        }
        
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        let targetCardView = resolveTargetCardView(for: cell)
        targetCardView.overrideUserInterfaceStyle = .light
        targetCardView.backgroundColor = CSSTheme.white
        targetCardView.layer.backgroundColor = CSSTheme.white.cgColor
        
        // Xóa bỏ toàn bộ màu nền phụ từ Storyboard bên trong contentView để dòng Loại tài khoản giống hệt Họ tên & Email
        clearIntermediateBackgrounds(in: cell.contentView, keeping: targetCardView)
        
        let section = Section.allCases[indexPath.section]

        // Trong mục Tài khoản: Chỉ 1 khung Card duy nhất chứa Họ tên (0), Email (1) và Loại tài khoản (2)
        let effectiveTotalRows = (section == .account) ? 3 : totalRows

        var corners: CACornerMask = []
        if effectiveTotalRows == 1 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if indexPath.row == 0 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if indexPath.row == effectiveTotalRows - 1 {
            corners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        
        targetCardView.layer.cornerRadius = corners.isEmpty ? 0 : CSSTheme.cornerRadius
        targetCardView.layer.maskedCorners = corners
        targetCardView.layer.masksToBounds = true
        
        // Tắt đổ bóng trực tiếp trên từng cell riêng lẻ khi gộp nhiều dòng để dòng cuối (Loại tài khoản) không bị bóng xanh ám tối nền
        cell.layer.masksToBounds = (section == .account && indexPath.row < 3)
        if effectiveTotalRows > 1 {
            cell.layer.shadowOpacity = 0.0
        } else {
            cell.layer.shadowColor = CSSTheme.blue.cgColor
            cell.layer.shadowOffset = CGSize(width: 0, height: 5)
            cell.layer.shadowRadius = 10
            cell.layer.shadowOpacity = 0.07
        }
        
        // Gắn nút > nằm gọn bên trong khung trắng (cách viền phải khung 18pt)
        self.attachChevronInsideCard(cell: cell, targetCardView: targetCardView, section: section, row: indexPath.row)
        
        // Đường kẻ phân cách nằm gọn bên trong khung trắng (từ sau Icon đến cách viền phải khung 16pt)
        let sepTag = 8888
        cell.contentView.viewWithTag(sepTag)?.removeFromSuperview()
        if indexPath.row < effectiveTotalRows - 1 {
            let sep = UIView()
            sep.tag = sepTag
            sep.backgroundColor = CSSTheme.border
            sep.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: targetCardView.leadingAnchor, constant: 52),
                sep.trailingAnchor.constraint(equalTo: targetCardView.trailingAnchor, constant: -16),
                sep.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1.0)
            ])
        }
        
        // Việt hóa và nhúng Icon trực tiếp vào Label bên trong Cell
        translateAndStyleLabelsInside(view: cell.contentView, section: section, row: indexPath.row)
    }

    // Khôi phục ngay lập tức nền trắng #FFFFFF cho tất cả các Cell đang hiển thị
    private func restoreVisibleCellsWhiteBackground() {
        for cell in self.tableView.visibleCells {
            guard let indexPath = self.tableView.indexPath(for: cell) else { continue }
            let section = Section.allCases[indexPath.section]
            if section == .account && indexPath.row == 3 { continue }
            let totalRows = self.tableView(self.tableView, numberOfRowsInSection: indexPath.section)
            cell.setHighlighted(false, animated: false)
            cell.setSelected(false, animated: false)
            self.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
        }
        self.enforceUniformWhiteBackgroundOnAccountRows()
    }

    // Bộ từ điển dịch tự động 100% các chuỗi tĩnh từ Storyboard & Hệ thống sang Tiếng Việt
    private func translateStaticText(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: "\u{FFFC}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let dictionary: [String: String] = [
            // Tài khoản & Đăng nhập
            "Sign in with Apple ID": "Đăng nhập bằng ID Apple",
            "Sign In with Apple ID": "Đăng nhập bằng ID Apple",
            "Sign In": "Đăng nhập",
            "Name": "Họ tên",
            "Email": "Email",
            "Type": "Loại tài khoản",
            "Account Type": "Loại tài khoản",
            "Free Developer Account": "Nhà phát triển Miễn phí",
            "Tài khoản Nhà phát triển Miễn phí": "Nhà phát triển Miễn phí",
            "Regular Account": "Tài khoản Miễn phí",
            "Developer Account": "Nhà phát triển",
            "Paid Developer Account": "Nhà phát triển Trả phí",
            "Tài khoản Nhà phát triển Trả phí": "Nhà phát triển Trả phí",
            "Individual": "Cá nhân",
            "Organization": "Tổ chức",
            "Unknown": "Không xác định",
            
            // Công cụ kỹ thuật
            "Error Log": "Nhật ký lỗi hệ thống",
            "View Error Log": "Xem nhật ký lỗi hệ thống",
            "Clear Cache": "Xóa bộ nhớ đệm (Cache)",
            
            // Cài đặt nâng cao, Máy chủ Anisette & Pairing
            "Anisette Servers": "Máy chủ Anisette",
            "Anisette Server": "Máy chủ Anisette",
            "Pairing File Management": "Pairing & Thiết bị ghép nối",
            "Manage Pairing File": "Pairing & Thiết bị ghép nối",
            "Reset Pairing File": "Pairing & Thiết bị ghép nối",
            "Pairing File": "Pairing & Thiết bị ghép nối",
            "Pairing & Thiết bị ghép nối": "Pairing & Thiết bị ghép nối",
            "View Refresh Attempts": "Lịch sử làm mới ứng dụng",
            "Refresh Attempts": "Lịch sử làm mới ứng dụng",
            "Refresh SideJITServer": "Cấu hình máy chủ SideJITServer",
            "SideJITServer": "Cấu hình máy chủ SideJITServer",
            "Certificate Management": "Quản lý chứng chỉ (Certificate)",
            "Certificates Management": "Quản lý chứng chỉ (Certificate)",
            "User Customizations": "Tùy chỉnh giao diện & người dùng"
        ]
        
        return dictionary[cleaned] ?? cleaned
    }

    private func translateAndStyleLabelsInside(view: UIView, section: Section, row: Int) {
        let activeItems = UnifiedSettingsItem.activeItems
        let isClearCacheRow = (section == .advancedSettings && activeItems.indices.contains(row) && activeItems[row] == .clearCache)
        let isPairingRow = (section == .advancedSettings && activeItems.indices.contains(row) && activeItems[row] == .pairingAndDevices)
        let rowIconSpec = iconSpecForRow(section: section, row: row)

        for subview in view.subviews {
            if let label = subview as? UILabel {
                if subview.superview is UIButton {
                    continue
                }
                label.backgroundColor = .clear
                
                // 1. Nhóm Label giá trị bên phải của khung Tài khoản (Tên, Email, Nhà phát triển Miễn phí)
                if label == self.accountNameLabel || label == self.accountEmailLabel || label == self.accountTypeLabel {
                    if label == self.accountTypeLabel, let typeText = label.text {
                        label.text = translateStaticText(typeText)
                    }
                    label.textColor = (label == self.accountNameLabel) ? CSSTheme.blue : CSSTheme.purple
                    label.font = UIFont.systemFont(ofSize: 14.5, weight: .bold)
                    label.textAlignment = .right
                    label.adjustsFontSizeToFitWidth = true
                    label.minimumScaleFactor = 0.8
                } else {
                    // 2. Nhóm Label tiêu đề bên trái (Họ tên, Email, Loại tài khoản & các mục Cài đặt)
                    let rawText = label.attributedText?.string ?? label.text ?? ""
                    let cleanText = isPairingRow ? "Pairing & Thiết bị ghép nối" : translateStaticText(rawText)
                    guard !cleanText.isEmpty else { continue }

                    let font: UIFont
                    let textColor: UIColor

                    if section == .signIn {
                        textColor = CSSTheme.blue
                        font = UIFont.systemFont(ofSize: 16, weight: .bold)
                    } else if isClearCacheRow {
                        textColor = CSSTheme.magenta
                        font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
                    } else if label.textColor == .systemRed && !isPairingRow {
                        textColor = CSSTheme.magenta
                        font = UIFont.systemFont(ofSize: 15.5, weight: .semibold)
                    } else {
                        textColor = CSSTheme.pureBlack
                        font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
                    }

                    label.textAlignment = .left

                    // Gắn Icon 28x28 trực tiếp vào đầu Label bằng NSTextAttachment để nằm gọn trong khung và tự đẩy chữ sang phải
                    if let spec = rowIconSpec {
                        let badgeImg = renderInlineBadgeImage(symbol: spec.symbol, color: spec.color)
                        let attachment = NSTextAttachment()
                        attachment.image = badgeImg
                        let yOffset = (font.capHeight - 28.0) / 2.0
                        attachment.bounds = CGRect(x: 0, y: yOffset, width: 28, height: 28)

                        let fullAttr = NSMutableAttributedString(attachment: attachment)
                        fullAttr.append(NSAttributedString(
                            string: "   " + cleanText,
                            attributes: [
                                .font: font,
                                .foregroundColor: textColor
                            ]
                        ))
                        label.attributedText = fullAttr
                    } else {
                        label.text = cleanText
                        label.font = font
                        label.textColor = textColor
                    }
                }
            }
            translateAndStyleLabelsInside(view: subview, section: section, row: row)
        }
    }

    // Xử lý bấm nút "Tài Khoản" để ẩn/hiện khung thông tin tài khoản
    @objc private func toggleAccountDetailsVisibility(_ sender: UIButton) {
        self.isAccountDetailsExpanded.toggle()
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            
            if let headerView = self.tableView.headerView(forSection: Section.account.rawValue) as? SettingsHeaderFooterView {
                self.prepare(headerView, for: .account, isHeader: true)
            }
            
            for row in 0..<3 {
                let idx = IndexPath(row: row, section: Section.account.rawValue)
                if let cell = self.tableView.cellForRow(at: idx) {
                    cell.alpha = self.isAccountDetailsExpanded ? 1.0 : 0.0
                    cell.isHidden = !self.isAccountDetailsExpanded
                    self.styleInnerCardOfCell(cell, at: idx, totalRows: 3)
                }
            }
            self.enforceUniformWhiteBackgroundOnAccountRows()
        } completion: { [weak self] _ in
            self?.restoreVisibleCellsWhiteBackground()
        }
    }
}

private extension SettingsViewController
{
    private func getVersionAttributedString() -> NSAttributedString {
        var appVersion = Bundle.Info.activeBundleVersion
        appVersion = appVersion.replacingOccurrences(of: "Version ", with: "Phiên bản ")
        let iosVersion = "iOS \(UIDevice.current.systemVersion) (Bản dựng \(ProcessInfo.processInfo.operatingSystemBuild))"

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        
        let fullString = NSMutableAttributedString()
        
        let appVersionAttr = NSAttributedString(
            string: "📦 " + appVersion,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13.5, weight: .bold),
                .foregroundColor: CSSTheme.blue,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        let iosVersionAttr = NSAttributedString(
            string: "\n" + iosVersion,
            attributes: [
                .font: UIFont.systemFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: CSSTheme.purple,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        fullString.append(appVersionAttr)
        fullString.append(iosVersionAttr)
        return fullString
    }

    @objc private func copyVersionLabelTapped() {
        let appVersion = Bundle.Info.activeBundleVersion
        let iosVersion = "iOS \(UIDevice.current.systemVersion) (\(ProcessInfo.processInfo.operatingSystemBuild))"
        let fullText = "\(appVersion)\n\(iosVersion)"
        #if !os(tvOS)
        UIPasteboard.general.string = fullText.hasPrefix("Version ") ? String(fullText.dropFirst("Version ".count)) : fullText
        #endif
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributed = NSMutableAttributedString(
            string: "Đã sao chép phiên bản! ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: CSSTheme.blue,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributed.append(NSAttributedString(string: "✓", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: CSSTheme.green
        ]))
        
        self.versionLabel?.attributedText = attributed
        if let footerLabel = self.tableView.tableFooterView?.viewWithTag(7771) as? UILabel {
            footerLabel.attributedText = attributed
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let normalAttr = self.getVersionAttributedString()
            self.versionLabel?.attributedText = normalAttr
            if let footerLabel = self.tableView.tableFooterView?.viewWithTag(7771) as? UILabel {
                footerLabel.attributedText = normalAttr
            }
        }
    }

    private func update()
    {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let currentActiveTeam = try? await AuthManager.shared.getAuthenticatedTeam()
            let appleID = AuthManager.shared.currentAppleID
            verboseLog("[SettingsVC] update() called. activeTeam: \(currentActiveTeam?.identifier ?? "nil"), account: \(appleID ?? "nil")")
            
            if let team = currentActiveTeam, AuthManager.shared.isAuthenticated
            {
                self.accountNameLabel.text = team.name
                self.accountEmailLabel.text = appleID
                self.accountTypeLabel.text = self.translateStaticText(team.type.localizedDescription)
                
                self.activeTeam = team
                self.startAccountVerification(for: team)
            }
            else
            {
                self.activeTeam = nil
                self.accountVerificationTask?.cancel()
                self.accountVerificationTask = nil
                self.accountStatus = .completed
                self.updateAccountCardRowStyles()
            }
            self.tableView.reloadData()
            self.restoreVisibleCellsWhiteBackground()
        }
        
        self.forceDisableRemovedSettings()
        
        self.disableResponseCachingSwitch?.isOn = UserDefaults.standard.responseCachingDisabled
        self.verboseOperationsLoggingSwitch?.isOn = UserDefaults.standard.isVerboseOperationsLoggingEnabled
        self.altSignVerboseLoggingSwitch?.isOn = UserDefaults.standard.isAltSignVerboseLoggingEnabled
        self.minimuxerVerboseLoggingSwitch?.isOn = UserDefaults.standard.isMinimuxerVerboseLoggingEnabled
        self.rotateLogsOnStartupSwitch?.isOn = UserDefaults.standard.isRotateLogsOnStartupEnabled
        self.recreateDatabaseSwitch?.isOn = UserDefaults.standard.recreateDatabaseOnNextStart
        
        if self.isViewLoaded
        {
            self.tableView.reloadData()
            self.restoreVisibleCellsWhiteBackground()
        }
    }

    private func startAccountVerification(for team: ALTTeam)
    {
        self.accountVerificationTask?.cancel()
        self.accountVerificationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            if !UserDefaults.standard.isDeviceRegistered {
                self.accountStatus = .checking
                self.tableView.reloadData()
                self.updateAccountCardRowStyles()
            }
            let status = await AccountVerificationRow.verifyStatus(for: team)
            if !Task.isCancelled {
                self.accountStatus = status
                self.tableView.reloadData()
                self.updateAccountCardRowStyles()
            }
        }
    }

    private func updateAccountCardRowStyles()
    {
        guard self.isViewLoaded else { return }
        for row in 0..<3 {
            let indexPath = IndexPath(row: row, section: Section.account.rawValue)
            if let cell = self.tableView.cellForRow(at: indexPath) as? InsetGroupTableViewCell {
                if row == 0 {
                    cell.style = .top
                } else if row == 1 {
                    cell.style = .middle
                } else if row == 2 {
                    // Luôn bo góc dưới cho dòng Loại tài khoản để 3 dòng nằm chung 1 khung trắng đồng nhất
                    cell.style = .bottom
                }
                self.styleInnerCardOfCell(cell, at: indexPath, totalRows: 3)
            }
        }
        self.enforceUniformWhiteBackgroundOnAccountRows()
    }

    private func resolvePendingAccountActions()
    {
        guard let team = self.activeTeam else { return }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await AccountVerificationRow.resolvePendingActions(for: self.accountStatus, team: team, presentingViewController: self)
            self.startAccountVerification(for: team)
        }
    }

    // Tạo tiêu đề Section có gắn SF Symbol phía trước đẹp mắt
    private func setSectionHeaderTitle(_ label: UILabel, iconName: String, title: String) {
        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .heavy)
        attachment.image = UIImage(systemName: iconName, withConfiguration: config)?.withTintColor(CSSTheme.blue, renderingMode: .alwaysOriginal)
        
        let attr = NSMutableAttributedString(attachment: attachment)
        attr.append(NSAttributedString(
            string: "  " + title,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14.5, weight: .heavy),
                .foregroundColor: CSSTheme.blue
            ]
        ))
        label.attributedText = attr
    }

    private func prepare(_ settingsHeaderFooterView: SettingsHeaderFooterView, for section: Section, isHeader: Bool)
    {
        settingsHeaderFooterView.primaryLabel.isHidden = !isHeader
        settingsHeaderFooterView.secondaryLabel.isHidden = isHeader
        settingsHeaderFooterView.button.isHidden = true
        
        settingsHeaderFooterView.primaryLabel.textColor = CSSTheme.blue
        settingsHeaderFooterView.primaryLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .heavy)
        settingsHeaderFooterView.secondaryLabel.textColor = CSSTheme.pureBlack
        settingsHeaderFooterView.secondaryLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        
        let toggleAccountTag = 9992
        settingsHeaderFooterView.contentView.viewWithTag(toggleAccountTag)?.removeFromSuperview()
        
        let underlineTag = 9991
        settingsHeaderFooterView.contentView.viewWithTag(underlineTag)?.removeFromSuperview()
        if isHeader {
            let underline = UIView()
            underline.tag = underlineTag
            underline.backgroundColor = CSSTheme.blue
            underline.layer.cornerRadius = 1.75
            underline.translatesAutoresizingMaskIntoConstraints = false
            settingsHeaderFooterView.contentView.addSubview(underline)
            NSLayoutConstraint.activate([
                underline.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.leadingAnchor),
                underline.topAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.bottomAnchor, constant: 2),
                underline.widthAnchor.constraint(equalToConstant: 38),
                underline.heightAnchor.constraint(equalToConstant: 3.5)
            ])
        }
        
        settingsHeaderFooterView.layoutMargins.bottom = isHeader ? 6 : 8
        
        switch section
        {
        case .signIn:
            if isHeader {
                setSectionHeaderTitle(settingsHeaderFooterView.primaryLabel, iconName: "person.crop.circle.fill", title: "TÀI KHOẢN APPLE ID")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = "Đăng nhập bằng ID Apple của bạn để tải xuống và làm mới ứng dụng từ SideStore."
            }
            
        case .account:
            setSectionHeaderTitle(settingsHeaderFooterView.primaryLabel, iconName: "person.text.rectangle.fill", title: "TÀI KHOẢN")
            
            let toggleBtn = UIButton(type: .system)
            toggleBtn.tag = toggleAccountTag
            toggleBtn.translatesAutoresizingMaskIntoConstraints = false
            let eyeSymbol = self.isAccountDetailsExpanded ? "eye.slash.fill" : "eye.fill"
            let eyeConfig = UIImage.SymbolConfiguration(pointSize: 10.5, weight: .bold)
            toggleBtn.setImage(UIImage(systemName: eyeSymbol, withConfiguration: eyeConfig), for: .normal)
            let toggleTitle = self.isAccountDetailsExpanded ? "  Ẩn ▲  " : "  Hiện ▼  "
            toggleBtn.setTitle(toggleTitle, for: .normal)
            toggleBtn.tintColor = CSSTheme.white
            toggleBtn.setTitleColor(CSSTheme.white, for: .normal)
            toggleBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
            toggleBtn.backgroundColor = self.isAccountDetailsExpanded ? CSSTheme.purple : CSSTheme.blue
            toggleBtn.layer.cornerRadius = 12
            toggleBtn.layer.shadowColor = CSSTheme.blue.cgColor
            toggleBtn.layer.shadowOffset = CGSize(width: 0, height: 2)
            toggleBtn.layer.shadowRadius = 4
            toggleBtn.layer.shadowOpacity = 0.25
            toggleBtn.addTarget(self, action: #selector(toggleAccountDetailsVisibility(_:)), for: .touchUpInside)
            
            settingsHeaderFooterView.contentView.addSubview(toggleBtn)
            
            let signOutBtn = settingsHeaderFooterView.button!
            signOutBtn.removeTarget(nil, action: nil, for: .allEvents)
            signOutBtn.setTitle("  ĐĂNG XUẤT  ", for: .normal)
            signOutBtn.setTitleColor(CSSTheme.white, for: .normal)
            signOutBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
            signOutBtn.backgroundColor = CSSTheme.magenta
            signOutBtn.layer.cornerRadius = 12
            signOutBtn.layer.shadowColor = CSSTheme.magenta.cgColor
            signOutBtn.layer.shadowOffset = CGSize(width: 0, height: 2)
            signOutBtn.layer.shadowRadius = 5
            signOutBtn.layer.shadowOpacity = 0.3
            signOutBtn.addTarget(self, action: #selector(SettingsViewController.signOut(_:)), for: .primaryActionTriggered)
            signOutBtn.isHidden = false
            
            NSLayoutConstraint.activate([
                toggleBtn.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.trailingAnchor, constant: 10),
                toggleBtn.centerYAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.centerYAnchor),
                toggleBtn.heightAnchor.constraint(equalToConstant: 24)
            ])
            
        case .advancedSettings:
            if isHeader {
                setSectionHeaderTitle(settingsHeaderFooterView.primaryLabel, iconName: "slider.horizontal.below.square.filled.and.square", title: "TRUNG TÂM CÀI ĐẶT & HỆ THỐNG")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = "Quản lý máy chủ Anisette, tệp Pairing & thiết bị ghép nối, cấu hình chứng chỉ, tùy chỉnh giao diện và dọn dẹp bộ nhớ đệm để tối ưu hóa hiệu suất hoạt động của SideStore."
            }
            
        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            break
        }
    }

    private func preferredHeight(for settingsHeaderFooterView: SettingsHeaderFooterView, in section: Section, isHeader: Bool) -> CGFloat
    {
        let widthConstraint = settingsHeaderFooterView.contentView.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        NSLayoutConstraint.activate([widthConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint]) }
        
        self.prepare(settingsHeaderFooterView, for: section, isHeader: isHeader)
        
        let size = settingsHeaderFooterView.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        if section == .account && isHeader {
            return max(34, size.height)
        }
        return size.height + (isHeader ? 4 : 0)
    }

    private func isSectionHidden(_ section: Section) -> Bool
    {
        switch section {
        case .signIn, .account, .advancedSettings:
            return false
        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            return true
        }
    }
}

private extension SettingsViewController
{
    private func signIn()
    {
        debugLog("[SettingsVC] signIn() invoked by user action")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let result = try await AuthManager.shared.signIn(presentingViewController: self)
                debugLog("[SettingsVC] signIn() authentication succeeded for team: \(result.team.name) (\(result.team.identifier))")
            } catch is CancellationError {
                debugLog("[SettingsVC] signIn() authentication cancelled by user")
            } catch {
                debugLog("[SettingsVC] signIn() authentication failed with error: \(error)")
                let toastView = ToastView(error: error)
                toastView.show(in: self.view)
            }

            debugLog("[SettingsVC] signIn() calling update()...")
            self.update()
        }
    }

    @objc private func signOut(_ sender: UIBarButtonItem)
    {
        debugLog("[SettingsVC] signOut() invoked by user action")
        let contentVC = SignOutAlertViewController()
        
        let alertController = UIAlertController(
            title: "Đăng xuất tài khoản",
            message: "Bạn có chắc chắn muốn đăng xuất không? Bạn sẽ không thể cài đặt hoặc làm mới ứng dụng sau khi đăng xuất.",
            preferredStyle: .alert
        )
        
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: "Hủy", style: .cancel, handler: nil)
        
        let signOutAction = UIAlertAction(title: "Đăng xuất", style: .destructive) { [weak self] _ in
            let keepCert = contentVC.isChecked
            let keepAnisette = contentVC.isKeepAnisetteChecked
            let keepAnisetteHeaders = contentVC.isKeepAnisetteHeadersChecked
            let keepSideSignHeaders = contentVC.isKeepSideSignHeadersChecked
            Task { @MainActor [weak self] in
                await AuthManager.shared.signOut(
                    keepCertificate: keepCert,
                    keepAnisetteData: keepAnisette,
                    keepAnisetteHeaders: keepAnisetteHeaders,
                    keepSideSignHeaders: keepSideSignHeaders
                )
                self?.update()
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(signOutAction)
        
        self.present(alertController, animated: true, completion: nil)
    }

    @IBAction private func toggleDisableAppLimit(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isAppLimitDisabled = false
    }

    @IBAction private func toggleIsBackgroundRefreshEnabled(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isBackgroundRefreshEnabled = false
    }

    @IBAction private func toggleNoIdleTimeoutEnabled(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isIdleTimeoutDisableEnabled = false
    }

    @IBAction private func toggleVerboseOperationsLogging(_ sender: UISwitch) {
        UserDefaults.standard.isVerboseOperationsLoggingEnabled = sender.isOn
    }

    @IBAction private func toggleAltSignVerboseLogging(_ sender: UISwitch) {
        UserDefaults.standard.isAltSignVerboseLoggingEnabled = sender.isOn
        AltSign.setLogging(sender.isOn)
    }

    @IBAction private func toggleMinimuxerVerboseLogging(_ sender: UISwitch) {
        UserDefaults.standard.isMinimuxerVerboseLoggingEnabled = sender.isOn
        minimuxerSetLogging(sender.isOn)
    }

    @IBAction private func toggleRotateLogsOnStartup(_ sender: UISwitch) {
        UserDefaults.standard.isRotateLogsOnStartupEnabled = sender.isOn
        let suffixFormat: SuffixFormat = sender.isOn ? .timestamp : .none
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.consoleLog.updateConfiguration(baseName: "console", suffixFormat: suffixFormat, policy: .immediate)
    }

    @IBAction private func toggleRecreateDatabaseSwitch(_ sender: UISwitch) {
        UserDefaults.standard.recreateDatabaseOnNextStart = sender.isOn
        guard sender.isOn else { return }
        
        DispatchQueue.global().async {
            for time in (1...3).reversed() {
                DispatchQueue.main.async {
                    guard UserDefaults.standard.recreateDatabaseOnNextStart else { return }
                    let toast = ToastView(text: "Đã lên lịch xóa Cơ sở dữ liệu ở lần mở tới", detailText: "Ứng dụng sẽ đóng sau \(time) giây...")
                    toast.tintColor = CSSTheme.purple
                    toast.preferredDuration = 1
                    toast.show(in: self)
                }
                sleep(1)
            }
            
            DispatchQueue.main.async {
                guard UserDefaults.standard.recreateDatabaseOnNextStart else { return }
                exit(0)
            }
        }
    }

    @IBAction private func toggleEnableBetaUpdates(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isBetaUpdatesEnabled = false
    }

    @IBAction private func toggleDisableResponseCaching(_ sender: UISwitch) {
        UserDefaults.standard.responseCachingDisabled = sender.isOn
    }

    private func clearCache()
    {
        let makeCacheTitle: (String) -> String = { sizeString in
            String(format: "Dung lượng đệm: %@", sizeString)
        }
        let alertController = UIAlertController(title: makeCacheTitle("Đang tính toán…"),
                                                message: "Thao tác này sẽ xóa toàn bộ tệp tạm thời cũng như bản sao lưu của các ứng dụng đã gỡ cài đặt.",
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel) { [weak self] _ in
            self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
            self?.restoreVisibleCellsWhiteBackground()
        })
        alertController.addAction(UIAlertAction(title: "Xóa bộ nhớ đệm", style: .destructive) { [weak self] _ in
            AppManager.shared.clearAppCache { result in
                DispatchQueue.main.async {
                    self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
                    self?.restoreVisibleCellsWhiteBackground()
                    switch result {
                    case .success: break
                    case .failure(let error):
                        let alertController = UIAlertController(title: "Không thể xóa bộ nhớ đệm", message: error.localizedDescription, preferredStyle: .alert)
                        alertController.addAction(.ok)
                        self?.present(alertController, animated: true)
                    }
                }
            }
        })
        
        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        self.present(alertController, animated: true)
        
        CacheManager.shared.formattedCacheSize { [weak alertController] sizeString in
            DispatchQueue.main.async {
                alertController?.title = makeCacheTitle(sizeString)
            }
        }
    }

    @IBAction private func handleDebugModeGesture(_ gestureRecognizer: UISwipeGestureRecognizer)
    {
        UserDefaults.standard.isDebugModeEnabled = false
    }

    private func openTwitter(username: String)
    {
        let twitterAppURL = URL(string: "twitter://user?screen_name=" + username)!
        UIApplication.shared.open(twitterAppURL, options: [:]) { (success) in
            if success {
                if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
            } else {
                let safariURL = URL(string: "https://twitter.com/" + username)!
                self.openWebURL(safariURL, preferredTintColor: CSSTheme.blue)
            }
        }
    }

    private func openMastodon(username: String)
    {
        let components = username.split(separator: "@")
        guard components.count == 2 else { return }
        let server = String(components[1])
        let username = "@" + String(components[0])
        guard let serverURL = URL(string: "https://" + server) else { return }
        let mastodonURL = serverURL.appendingPathComponent(username)
        UIApplication.shared.open(mastodonURL, options: [:])
    }

    private func openThreads(username: String)
    {
        let safariURL = URL(string: "https://www.threads.net/@" + username)!
        UIApplication.shared.open(safariURL, options: [:])
    }

    @IBAction private func followAltStoreMastodon() { self.openMastodon(username: "@sidestoreio@fosstodon.org") }
    @IBAction private func followAltStoreThreads() { self.openThreads(username: "sidestore.io") }
    @IBAction private func followAltStoreTwitter() { self.openTwitter(username: "sidestoreio") }
    @objc @IBAction private func followAltStoreGitHub() { UIApplication.shared.open(AppConstants.URLs.sideStoreGitHub, options: [:]) }

    private func presentAnisetteSheet() {
        let sheetView = SettingsAnisetteSheetView(onDismiss: { [weak self] in
            DispatchQueue.main.async {
                self?.restoreVisibleCellsWhiteBackground()
            }
        })
        let hostingController = UIHostingController(rootView: sheetView)
        hostingController.overrideUserInterfaceStyle = .light
        hostingController.presentationController?.delegate = self
        self.present(hostingController, animated: true) { [weak self] in
            self?.restoreVisibleCellsWhiteBackground()
        }
    }

    private func presentPairingSheet() {
        let sheetView = SettingsPairingSheetView(onDismiss: { [weak self] in
            DispatchQueue.main.async {
                self?.restoreVisibleCellsWhiteBackground()
            }
        })
        let hostingController = UIHostingController(rootView: sheetView)
        hostingController.overrideUserInterfaceStyle = .light
        hostingController.presentationController?.delegate = self
        self.present(hostingController, animated: true) { [weak self] in
            self?.restoreVisibleCellsWhiteBackground()
        }
    }
}

extension SettingsViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        self.restoreVisibleCellsWhiteBackground()
    }
}

private extension SettingsViewController
{
    @objc private func openPatreonSettings(_ notification: Notification)
    {
        // Đã ẩn ỦNG HỘ CHÚNG TÔI
    }

    @objc private func openErrorLog(_: Notification) {
        guard self.presentedViewController == nil else { return }
        self.navigationController?.popViewController(animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.performSegue(withIdentifier: "showErrorLog", sender: nil)
        }
    }
}

extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let section = Section.allCases[indexPath.section]
        if isSectionHidden(section) {
            return 0.0
        }
        
        if section == .account {
            if indexPath.row < 3 && !self.isAccountDetailsExpanded {
                return 0.0
            }
            if indexPath.row < 3 {
                return 48.0
            }
            if indexPath.row == 3 {
                return AccountVerificationRow.preferredHeight
            }
        }
        
        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { return 0.0 }
            let baseHeight = super.tableView(tableView, heightForRowAt: activeItems[indexPath.row].originalIndexPath)
            return max(baseHeight, 50.0)
        }
        
        return max(super.tableView(tableView, heightForRowAt: indexPath), 50.0)
    }

    // ✨ CAN THIỆP SÂU VÀO TỪNG CELL ĐỂ ÁP DỤNG 1 KHUNG DUY NHẤT, ICON & ẨN/HIỆN TÀI KHOẢN ✨
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        let totalRows = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
        
        if section == .account {
            if indexPath.row < 3 {
                cell.clipsToBounds = true
                cell.isHidden = !self.isAccountDetailsExpanded
                cell.alpha = self.isAccountDetailsExpanded ? 1.0 : 0.0
            }
            
            // Luôn gom 3 dòng Họ tên (0), Email (1), Loại tài khoản (2) thành 1 khung Card duy nhất (.top -> .middle -> .bottom)
            if let insetCell = cell as? InsetGroupTableViewCell {
                if indexPath.row == 0 {
                    insetCell.style = .top
                } else if indexPath.row == 1 {
                    insetCell.style = .middle
                } else if indexPath.row == 2 {
                    insetCell.style = .bottom
                }
            } else if indexPath.row == 3, let actionCell = cell as? AccountVerificationRow {
                actionCell.style = .single
                actionCell.backgroundColor = .clear
                actionCell.contentView.backgroundColor = .clear
                if #available(iOS 14.0, tvOS 14.0, *) {
                    actionCell.backgroundConfiguration = .clear()
                }
                return
            }
        }
        
        self.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
        
        // Ép lại màu trắng tinh #FFFFFF ở chu kỳ RunLoop tiếp theo để thắng tuyệt đối hàm layoutSubviews() của InsetGroupTableViewCell
        if section == .account && indexPath.row < 3 {
            DispatchQueue.main.async { [weak self, weak cell] in
                guard let self = self, let cell = cell else { return }
                self.styleInnerCardOfCell(cell, at: indexPath, totalRows: 3)
            }
        }
    }

    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int
    {
        let section = Section.allCases[indexPath.section]
        if section == .account && indexPath.row == 3 {
            return 0
        }
        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { return 0 }
            return super.tableView(tableView, indentationLevelForRowAt: activeItems[indexPath.row].originalIndexPath)
        }
        return super.tableView(tableView, indentationLevelForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 0
        case .signIn: return (self.activeTeam == nil) ? 1 : 0
        case .account: return (self.activeTeam == nil) ? 0 : (self.accountStatus == .completed ? 3 : 4)
        case .advancedSettings: return UnifiedSettingsItem.activeItems.count
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let section = Section.allCases[indexPath.section]
        if section == .account && indexPath.row == 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: AccountVerificationRow.reuseIdentifier) as? AccountVerificationRow
                ?? AccountVerificationRow()
            cell.configure(with: self.accountStatus)
            cell.style = .single
            return cell
        }
        
        let effectiveIndexPath: IndexPath
        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            effectiveIndexPath = activeItems[indexPath.row].originalIndexPath
        } else {
            effectiveIndexPath = indexPath
        }
        
        let cell = super.tableView(tableView, cellForRowAt: effectiveIndexPath)
        cell.overrideUserInterfaceStyle = .light
        cell.selectionStyle = .none
        
        if section == .account, let insetCell = cell as? InsetGroupTableViewCell {
            if indexPath.row == 0 {
                insetCell.style = .top
            } else if indexPath.row == 1 {
                insetCell.style = .middle
            } else if indexPath.row == 2 {
                insetCell.style = .bottom
            }
            let targetCardView = self.resolveTargetCardView(for: insetCell)
            targetCardView.backgroundColor = CSSTheme.white
        }
        
        if section == .advancedSettings,
           let insetCell = cell as? InsetGroupTableViewCell {
            let total = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
            if total == 1 {
                insetCell.style = .single
            } else if indexPath.row == 0 {
                insetCell.style = .top
            } else if indexPath.row == total - 1 {
                insetCell.style = .bottom
            } else {
                insetCell.style = .middle
            }
            let targetCardView = self.resolveTargetCardView(for: insetCell)
            targetCardView.backgroundColor = CSSTheme.white
        }
        
        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return nil
        case .signIn where self.activeTeam != nil: return nil
        case .account where self.activeTeam == nil: return nil
        case .signIn, .account, .advancedSettings:
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(headerView, for: section, isHeader: true)
            return headerView
            
        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return nil
        case .signIn where self.activeTeam != nil: return nil
        case .signIn, .advancedSettings:
            let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(footerView, for: section, isHeader: false)
            return footerView
            
        case .account, .patreon, .display, .appRefresh, .credits, .techyThings, .instructions, .betaTesting, .diagnostics:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 0.01
        case .signIn where self.activeTeam != nil: return 0.01
        case .account where self.activeTeam == nil: return 0.01
        case .signIn, .account, .advancedSettings:
            return self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: true)
        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            return 0.01
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 0.01
        case .signIn where self.activeTeam != nil: return 0.01
        case .account where self.activeTeam == nil: return 0.01
        case .signIn, .advancedSettings:
            return self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: false)
        case .account, .patreon, .display, .appRefresh, .credits, .techyThings, .instructions, .betaTesting, .diagnostics:
            return 0.01
        }
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath)
    {
        if let cell = tableView.cellForRow(at: indexPath) {
            let section = Section.allCases[indexPath.section]
            if !(section == .account && indexPath.row == 3) {
                let totalRows = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
                self.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath)
    {
        if let cell = tableView.cellForRow(at: indexPath) {
            let section = Section.allCases[indexPath.section]
            if !(section == .account && indexPath.row == 3) {
                let totalRows = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
                DispatchQueue.main.async { [weak self] in
                    self?.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: false)
        self.restoreVisibleCellsWhiteBackground()

        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(translationX: 5, y: -2).scaledBy(x: 0.98, y: 0.98)
            }) { [weak self] _ in
                self?.restoreVisibleCellsWhiteBackground()
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                    cell.transform = .identity
                }, completion: { [weak self] _ in
                    self?.restoreVisibleCellsWhiteBackground()
                })
            }
        }

        let section = Section.allCases[indexPath.section]
        verboseLog("[SettingsVC] didSelectRowAt: section \(section) (index \(indexPath.section)), row \(indexPath.row)")
        switch section
        {
        case .signIn:
            self.signIn()
            
        case .account:
            if indexPath.row == 3 {
                self.resolvePendingAccountActions()
            }
            
        case .advancedSettings:
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { break }
            let item = activeItems[indexPath.row]
            
            switch item {
            case .anisetteServers:
                self.presentAnisetteSheet()
                
            case .pairingAndDevices:
                self.presentPairingSheet()
                
            case .refreshAttempts, .errorLog:
                break
                
            case .refreshSideJITServer:
                let vc = UIHostingController(rootView: SideJITServerConfigView())
                vc.title = nil
                self.navigationController?.pushViewController(vc, animated: true)
                
            case .certificateManagement:
                let vc = UIHostingController(rootView: CertificatesView(presentingViewController: self))
                vc.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "certificateManagement", source: self, destination: vc), sender: nil)
                
            case .userCustomizations:
                let vc = UIHostingController(rootView: UserCustomizationsView())
                vc.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: vc), sender: nil)
                
            case .clearCache:
                self.clearCache()
            }
            
        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            break
        }
    }
}

#if !os(tvOS)
extension SettingsViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        if let error = error {
            let toastView = ToastView(error: error)
            toastView.show(in: self)
        }
        controller.dismiss(animated: true, completion: nil)
    }
}
#endif

extension SettingsViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        #if !os(tvOS)
        if gestureRecognizer === self.navigationController?.interactivePopGestureRecognizer {
            return (self.navigationController?.viewControllers.count ?? 0) > 1
        }
        #endif
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }
}

#if !os(tvOS)
extension SettingsViewController: INUIAddVoiceShortcutViewControllerDelegate
{
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?)
    {
        if let indexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        controller.dismiss(animated: true, completion: nil)
        guard let error = error else { return }
        let toastView = ToastView(error: error)
        toastView.show(in: self)
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController)
    {
        if let indexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        controller.dismiss(animated: true, completion: nil)
    }
}
#endif
