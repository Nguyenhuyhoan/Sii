
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

    // SwiftUI Colors (Phục vụ bảng Máy chủ Anisette)
    static let suiPrimary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)
    static let suiSecondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
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
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

private struct SettingsSkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var trailingView: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                            .fill(CSSTheme.suiPrimary.opacity(0.14))
                            .frame(width: 22, height: 22)
                        SwiftUI.Image(systemName: icon)
                            .font(.system(size: 11.5, weight: .heavy))
                            .foregroundColor(CSSTheme.suiPrimary)
                    }

                    SwiftUI.Text(title.uppercased())
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(CSSTheme.suiPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

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
        case refreshAttempts
        case refreshSideJITServer
        case certificateManagement
        case userCustomizations
        case errorLog
        case clearCache

        static var activeItems: [UnifiedSettingsItem] {
            return [
                .anisetteServers,
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
        if identifier == "anisetteServers" {
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
        btn.setTitle(" \(title)", for: .normal)
        btn.tintColor = color
        btn.setTitleColor(color, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        btn.backgroundColor = color.withAlphaComponent(0.10)
        btn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
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

    // Tìm chính xác khung Card bên trong InsetGroupTableViewCell mà không phụ thuộc vào frame.width (tránh lỗi khi cell đang ẩn height = 0)
    private func resolveTargetCardView(for cell: UITableViewCell) -> UIView {
        if let insetCell = cell as? InsetGroupTableViewCell {
            return insetCell.insetContentView
        }
        return cell.subviews.first(where: {
            $0 !== cell.contentView && $0 !== cell.selectedBackgroundView && $0 !== cell.backgroundView && !($0 is UIButton)
        }) ?? cell.contentView
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
            
            // Cài đặt nâng cao & Máy chủ Anisette
            "Anisette Servers": "Máy chủ Anisette",
            "Anisette Server": "Máy chủ Anisette",
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
                    let cleanText = translateStaticText(rawText)
                    guard !cleanText.isEmpty else { continue }

                    let font: UIFont
                    let textColor: UIColor

                    if section == .signIn {
                        textColor = CSSTheme.blue
                        font = UIFont.systemFont(ofSize: 16, weight: .bold)
                    } else if isClearCacheRow {
                        textColor = CSSTheme.magenta
                        font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
                    } else if label.textColor == .systemRed {
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
            let toggleTitle = self.isAccountDetailsExpanded ? " Ẩn ▲" : " Hiện ▼"
            toggleBtn.setTitle(toggleTitle, for: .normal)
            toggleBtn.tintColor = CSSTheme.white
            toggleBtn.setTitleColor(CSSTheme.white, for: .normal)
            toggleBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
            toggleBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
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
                settingsHeaderFooterView.secondaryLabel.text = "Quản lý máy chủ Anisette, cấu hình chứng chỉ, tùy chỉnh giao diện và dọn dẹp bộ nhớ đệm để tối ưu hóa hiệu suất hoạt động của SideStore."
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
            Task.detached { [weak self] in
                await AuthManager.shared.signOut(
                    keepCertificate: keepCert,
                    keepAnisetteData: keepAnisette,
                    keepAnisetteHeaders: keepAnisetteHeaders,
                    keepSideSignHeaders: keepSideSignHeaders
                )
                await MainActor.run {
                    self?.update()
                }
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
            insetCell.insetContentView.backgroundColor = CSSTheme.white
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
            insetCell.insetContentView.backgroundColor = CSSTheme.white
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
