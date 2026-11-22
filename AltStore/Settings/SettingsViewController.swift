

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

// MARK: - 🌸✨ BỘ GIAO DIỆN ĐỘC QUYỀN: AURORA PASTEL LUXURY ✨🌸
// (Xanh Da Trời Nhạt • Hồng Phấn • Trắng Sữa • Tím Mộng Mơ)
private struct CSSTheme {
    // 1. Trắng Sữa Ngọc Trai (Milky Cream White) & Viền Tím Phấn
    static let white = UIColor(red: 255/255, green: 252/255, blue: 250/255, alpha: 1.0)       // #FFFCFA (Trắng sữa sang trọng)
    static let light = UIColor(red: 249/255, green: 245/255, blue: 255/255, alpha: 1.0)       // #F9F5FF (Trắng ánh tím mộng mơ)
    static let border = UIColor(red: 230/255, green: 218/255, blue: 248/255, alpha: 1.0)      // #E6DAF8 (Viền tím phấn dịu)
    static let separator = UIColor(red: 238/255, green: 228/255, blue: 252/255, alpha: 0.85)  // Đường kẻ phân cách pastel

    // 2. Bảng màu Chủ đạo: Xanh Da Trời - Tím Mộng Mơ - Hồng Phấn
    static let skyBlue = UIColor(red: 56/255, green: 165/255, blue: 255/255, alpha: 1.0)      // #38A5FF (Xanh da trời thanh lịch)
    static let softSky = UIColor(red: 130/255, green: 202/255, blue: 255/255, alpha: 1.0)     // #82CAFF (Xanh da trời nhạt)
    static let dreamyPurple = UIColor(red: 148/255, green: 102/255, blue: 242/255, alpha: 1.0)// #9466F2 (Tím mộng mơ chủ đạo)
    static let blushPink = UIColor(red: 244/255, green: 114/255, blue: 176/255, alpha: 1.0)   // #F472B0 (Hồng phấn kiêu sa)
    static let pastelGreen = UIColor(red: 46/255, green: 196/255, blue: 138/255, alpha: 1.0)  // #2EC48A (Xanh ngọc lục bảo dịu)

    // Giữ tên biến tương thích hoàn toàn với cấu trúc cũ
    static let blue = skyBlue
    static let purple = dreamyPurple
    static let green = pastelGreen
    static let magenta = blushPink

    // 3. Màu chữ Tím Than Đậm (Deep Velvet Indigo - Thanh lịch hơn màu đen thuần)
    static let dark = UIColor(red: 45/255, green: 34/255, blue: 76/255, alpha: 1.0)           // #2D224C
    static let textPrimary = UIColor(red: 45/255, green: 34/255, blue: 76/255, alpha: 1.0)    // #2D224C
    static let textSecondary = UIColor(red: 126/255, green: 110/255, blue: 162/255, alpha: 1.0)// #7E6EA2

    // 4. Nền Cực Quang 3 Tầng: Xanh Da Trời Nhạt -> Tím Mộng Mơ -> Hồng Phấn
    static let bgGradientTop = UIColor(red: 224/255, green: 243/255, blue: 255/255, alpha: 1.0).cgColor    // #E0F3FF (Xanh da trời nhạt)
    static let bgGradientMiddle = UIColor(red: 242/255, green: 232/255, blue: 255/255, alpha: 1.0).cgColor // #F2E8FF (Tím mộng mơ nhạt)
    static let bgGradientBottom = UIColor(red: 255/255, green: 233/255, blue: 244/255, alpha: 1.0).cgColor // #FFE9F4 (Hồng phấn nhạt)

    // 5. Hero Banner Gradient 3 Màu: Xanh Da Trời -> Tím Mộng Mơ -> Hồng Phấn
    static let heroStart = UIColor(red: 78/255, green: 178/255, blue: 255/255, alpha: 1.0).cgColor         // #4EB2FF
    static let heroMiddle = UIColor(red: 158/255, green: 112/255, blue: 248/255, alpha: 1.0).cgColor        // #9E70F8
    static let heroEnd = UIColor(red: 248/255, green: 128/255, blue: 188/255, alpha: 1.0).cgColor           // #F880BC

    static let cornerRadius: CGFloat = 20.0

    // 6. SwiftUI Colors (Đồng bộ tuyệt đối cho bảng Máy chủ Anisette)
    static let suiPrimary = SwiftUI.Color(red: 148/255, green: 102/255, blue: 242/255)        // Tím mộng mơ
    static let suiSkyBlue = SwiftUI.Color(red: 56/255, green: 165/255, blue: 255/255)         // Xanh da trời
    static let suiBlushPink = SwiftUI.Color(red: 244/255, green: 114/255, blue: 176/255)      // Hồng phấn
    static let suiSecondary = SwiftUI.Color(red: 244/255, green: 114/255, blue: 176/255)
    static let suiGreen = SwiftUI.Color(red: 46/255, green: 196/255, blue: 138/255)
    static let suiRed = SwiftUI.Color(red: 244/255, green: 96/255, blue: 148/255)
    static let suiPureBlack = SwiftUI.Color(red: 45/255, green: 34/255, blue: 76/255)         // Chữ tím than sang trọng
    static let suiTextSecondary = SwiftUI.Color(red: 126/255, green: 110/255, blue: 162/255)
    static let suiCardBackground = SwiftUI.Color(red: 255/255, green: 252/255, blue: 250/255) // Trắng sữa #FFFCFA
    static let suiInnerRowBackground = SwiftUI.Color(red: 250/255, green: 246/255, blue: 255/255)
    static let suiBorder = SwiftUI.Color(red: 228/255, green: 214/255, blue: 250/255)
    static let suiInnerBorder = SwiftUI.Color(red: 234/255, green: 222/255, blue: 252/255)

    static var suiPageGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 224/255, green: 243/255, blue: 255/255), // Xanh da trời nhạt
                SwiftUI.Color(red: 242/255, green: 232/255, blue: 255/255), // Tím mộng mơ
                SwiftUI.Color(red: 255/255, green: 233/255, blue: 244/255)  // Hồng phấn
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var suiAccentGradient: LinearGradient {
        LinearGradient(
            colors: [suiSkyBlue, suiPrimary, suiBlushPink],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // Font chữ bo tròn mềm mại thanh lịch (SF Rounded)
    static func roundedFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return systemFont
    }

    static func triggerLightHaptic() {
        #if !os(tvOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}

// MARK: - 🌈 LỚP NỀN CỰC QUANG MỘNG MƠ 3 TẦNG CỐ ĐỊNH (XANH SKY -> TÍM -> HỒNG PHẤN)
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
        gradientLayer.colors = [
            CSSTheme.bgGradientTop,
            CSSTheme.bgGradientMiddle,
            CSSTheme.bgGradientBottom
        ]
        gradientLayer.locations = [0.0, 0.52, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 🌐 BỘ QUẢN LÝ & GIAO DIỆN MÁY CHỦ ANISETTE (PHONG CÁCH PASTEL DREAMY)
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
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

private struct SettingsSkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var trailingView: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(color.opacity(0.15))
                            .frame(width: 24, height: 24)
                        SwiftUI.Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(color)
                    }

                    SwiftUI.Text(title.uppercased())
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundColor(CSSTheme.suiPureBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Spacer(minLength: 4)

                    if let trailingView = trailingView {
                        trailingView
                    }
                }

                Capsule()
                    .fill(CSSTheme.suiAccentGradient)
                    .frame(width: 48, height: 3.5)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSTheme.suiCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.suiBorder, lineWidth: 1.2)
            )
            .shadow(color: CSSTheme.suiPrimary.opacity(0.10), radius: 14, x: 0, y: 6)
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
        CSSTheme.triggerLightHaptic()
        UserDefaults.standard.useOnDeviceAnisette = enabled
        updateInstantStatus()
    }

    func setAnisetteAutoRotationEnabled(_ enabled: Bool) {
        CSSTheme.triggerLightHaptic()
        UserDefaults.standard.disableAnisetteRotation = !enabled
        updateInstantStatus()
    }

    func selectAnisetteServerURL(_ urlString: String, isCustom: Bool = false) {
        CSSTheme.triggerLightHaptic()
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
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(vm.isAnisetteOK ? CSSTheme.suiGreen.opacity(0.16) : CSSTheme.suiBlushPink.opacity(0.18))
                                .frame(width: 50, height: 50)
                            SwiftUI.Image(systemName: vm.isAnisetteOK ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(vm.isAnisetteOK ? CSSTheme.suiGreen : CSSTheme.suiBlushPink)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            SwiftUI.Text(vm.isAnisetteOK
                                         ? "Máy Chủ Anisette Ổn Định"
                                         : "Đang Bật On-Device Anisette")
                                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                .foregroundColor(CSSTheme.suiPureBlack)
                            SwiftUI.Text(vm.anisetteDetail)
                                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                                .foregroundColor(CSSTheme.suiTextSecondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(CSSTheme.suiCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.suiBorder, lineWidth: 1.2)
                    )
                    .shadow(color: CSSTheme.suiPrimary.opacity(0.10), radius: 14, x: 0, y: 6)

                    SettingsSkySectionCard(
                        title: "CHẾ ĐỘ XÁC THỰC ANISETTE",
                        icon: "sparkles",
                        color: CSSTheme.suiSkyBlue
                    ) {
                        Toggle(isOn: Binding(
                            get: { vm.useOnDeviceAnisette },
                            set: { vm.setUseOnDeviceAnisette($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 4) {
                                SwiftUI.Text("Use On-Device Anisette")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(CSSTheme.suiPureBlack)
                                SwiftUI.Text(vm.useOnDeviceAnisette
                                             ? "Đang BẬT (Khuyên tắt để ổn định hơn)"
                                             : "(Nên Tắt Để Dễ Đăng Nhập)")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(vm.useOnDeviceAnisette ? CSSTheme.suiBlushPink : CSSTheme.suiGreen)
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
                            VStack(alignment: .leading, spacing: 4) {
                                SwiftUI.Text("Enable Auto Rotation")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundColor(CSSTheme.suiPureBlack)
                                SwiftUI.Text(vm.isAnisetteAutoRotationEnabled
                                             ? "(Tự Động Đổi Máy Chủ Khi Lỗi)"
                                             : "Đang Tắt “Nên chọn SideStore (New)”")
                                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(vm.isAnisetteAutoRotationEnabled ? CSSTheme.suiGreen : CSSTheme.suiBlushPink)
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
                                        .font(.system(size: 15, weight: .bold, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CSSTheme.suiAccentGradient)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: CSSTheme.suiPrimary.opacity(0.28), radius: 8, x: 0, y: 4)
                            }
                            .buttonStyle(SettingsBounceButtonStyle())
                        }
                    }

                    SettingsSkySectionCard(
                        title: "CHỌN MÁY CHỦ ANISETTE",
                        icon: "server.rack",
                        color: CSSTheme.suiPrimary,
                        trailingView: vm.isLoading ? AnyView(ProgressView().tint(CSSTheme.suiPrimary)) : nil
                    ) {
                        VStack(spacing: 9) {
                            ForEach(vm.servers) { server in
                                let isSelected = (vm.selectedAnisetteServerURL.caseInsensitiveCompare(server.address) == .orderedSame)
                                let isRecommended = isRecommendedSideStoreNew(server)

                                SwiftUI.Button {
                                    vm.selectAnisetteServerURL(server.address, isCustom: false)
                                    Task { await vm.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                } label: {
                                    HStack(spacing: 12) {
                                        SwiftUI.Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20, weight: .bold))
                                            .foregroundColor(isSelected ? CSSTheme.suiPrimary : CSSTheme.suiTextSecondary.opacity(0.5))

                                        VStack(alignment: .leading, spacing: 3) {
                                            HStack(spacing: 6) {
                                                SwiftUI.Text(server.name)
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundColor(CSSTheme.suiPureBlack)

                                                if isRecommended {
                                                    SwiftUI.Text("★ Khuyên dùng")
                                                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 2.5)
                                                        .background(CSSTheme.suiBlushPink.opacity(0.15))
                                                        .foregroundColor(CSSTheme.suiBlushPink)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            SwiftUI.Text(server.address)
                                                .font(.system(size: 12.5, weight: .medium))
                                                .foregroundColor(CSSTheme.suiTextSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if isSelected {
                                            SwiftUI.Text("Đang dùng")
                                                .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                                .padding(.horizontal, 9)
                                                .padding(.vertical, 4)
                                                .background(CSSTheme.suiSkyBlue.opacity(0.15))
                                                .foregroundColor(CSSTheme.suiSkyBlue)
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
                                                ? CSSTheme.suiPrimary.opacity(0.75)
                                                : (isRecommended ? CSSTheme.suiBlushPink.opacity(0.45) : CSSTheme.suiInnerBorder),
                                                lineWidth: isSelected ? 1.6 : 1.0
                                            )
                                    )
                                }
                                .buttonStyle(SettingsBounceButtonStyle())
                            }
                        }

                        Divider().padding(.vertical, 4)

                        VStack(alignment: .leading, spacing: 8) {
                            SwiftUI.Text("Hoặc nhập URL máy chủ tùy chỉnh:")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(CSSTheme.suiTextSecondary)

                            HStack(spacing: 8) {
                                TextField(AppConstants.Anisette.Servers.defaultServerURL, text: $customServerInput)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(CSSTheme.suiPureBlack)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(11)
                                    .background(CSSTheme.suiInnerRowBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(CSSTheme.suiInnerBorder, lineWidth: 1.0)
                                    )

                                SwiftUI.Button {
                                    let trimmed = customServerInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    vm.selectAnisetteServerURL(trimmed, isCustom: true)
                                    Task { await vm.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                    customServerInput = ""
                                } label: {
                                    SwiftUI.Text("Lưu")
                                        .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 11)
                                        .background(CSSTheme.suiAccentGradient)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .shadow(color: CSSTheme.suiPrimary.opacity(0.25), radius: 6, x: 0, y: 3)
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
                    SwiftUI.Text("✨ Máy Chủ Anisette")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(CSSTheme.suiPureBlack)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") {
                        CSSTheme.triggerLightHaptic()
                        onDismiss?()
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(CSSTheme.suiPrimary)
                }
            }
            .task {
                vm.updateInstantStatus()
                await vm.loadCachedAndSync(customPrefix: customServerPrefix)
            }
        }
        .preferredColorScheme(.light)
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

        // Biểu tượng SF Symbols & Màu Pastel riêng biệt cho từng mục
        var iconSymbol: String {
            switch self {
            case .anisetteServers: return "server.rack"
            case .refreshAttempts: return "clock.arrow.circlepath"
            case .refreshSideJITServer: return "bolt.horizontal.circle.fill"
            case .certificateManagement: return "checkmark.seal.fill"
            case .userCustomizations: return "paintbrush.pointed.fill"
            case .errorLog: return "doc.text.magnifyingglass"
            case .clearCache: return "sparkles.rectangle.stack.fill"
            }
        }

        var iconTintColor: UIColor {
            switch self {
            case .anisetteServers: return CSSTheme.skyBlue
            case .refreshAttempts: return CSSTheme.dreamyPurple
            case .refreshSideJITServer: return CSSTheme.blushPink
            case .certificateManagement: return CSSTheme.skyBlue
            case .userCustomizations: return CSSTheme.dreamyPurple
            case .errorLog: return CSSTheme.skyBlue
            case .clearCache: return CSSTheme.blushPink
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
        
        // Tắt cứng Làm mới ứng dụng, Beta và Developer Mode
        self.forceDisableRemovedSettings()
        
        // Xóa bỏ tiêu đề "Cài đặt" và ẩn hoàn toàn thanh điều hướng
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        // Giữ tính năng vuốt từ cạnh trái màn hình để quay lại khi ẩn thanh điều hướng
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
        
        // ✨ KÍCH HOẠT GIAO DIỆN ĐỘC QUYỀN AURORA PASTEL LUXURY ✨
        self.applySmartWebCSSTheme()
        
        self.update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let heroHeader = self.tableView.tableHeaderView,
           let heroCard = heroHeader.subviews.first {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
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

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI PHA LÊ MỘNG MƠ
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
            btn.tintColor = CSSTheme.dreamyPurple
            btn.backgroundColor = CSSTheme.white.withAlphaComponent(0.95)
            
            btn.layer.cornerRadius = 18
            btn.layer.cornerCurve = .continuous
            btn.layer.borderWidth = 1.2
            btn.layer.borderColor = CSSTheme.border.cgColor
            btn.layer.shadowColor = CSSTheme.dreamyPurple.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 4)
            btn.layer.shadowRadius = 10
            btn.layer.shadowOpacity = 0.22
            
            btn.addTarget(self, action: #selector(handleFloatingBackTap), for: .touchUpInside)
            nav.view.addSubview(btn)
            
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                btn.topAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.topAnchor, constant: 6),
                btn.widthAnchor.constraint(equalToConstant: 36),
                btn.heightAnchor.constraint(equalToConstant: 36)
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
        CSSTheme.triggerLightHaptic()
        self.navigationController?.popViewController(animated: true)
    }
}

// MARK: - ✨ HỆ THỐNG RENDER AURORA PASTEL LUXURY & BIỂU TƯỢNG THÔNG MINH ✨
private extension SettingsViewController {

    private func applySmartWebCSSTheme() {
        // 1. Nền Cực Quang 3 tầng (Xanh da trời nhạt -> Tím mộng mơ -> Hồng phấn)
        let bgView = CSSGradientBackgroundView(frame: UIScreen.main.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.backgroundView = bgView
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        
        // 2. Tạo khối Hero Banner Pha Lê 3 Màu kèm hiệu ứng ánh sáng Bokeh
        setupCSSHeroBanner()
        
        // 3. Tạo Footer hiển thị Lời cảm ơn Trắng Sữa + Phiên bản
        setupVersionTableFooterView()
        
        // 4. Cấu hình TabBar trắng sữa ánh tím mộng mơ
        #if !os(tvOS)
        if let tabBar = self.tabBarController?.tabBar {
            let tabAppearance = tabBar.standardAppearance
            tabAppearance.configureWithDefaultBackground()
            tabAppearance.backgroundColor = CSSTheme.white.withAlphaComponent(0.92)
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = CSSTheme.blushPink
            tabBar.standardAppearance = tabAppearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = tabAppearance
            }
            tabBar.tintColor = CSSTheme.dreamyPurple
        }
        #endif
        
        // 5. Làm đẹp các công tắc UISwitch với tông Tím Mộng Mơ & Hồng Phấn
        let switches = [
            self.backgroundRefreshSwitch, self.noIdleTimeoutSwitch, self.disableAppLimitSwitch,
            self.betaUpdatesSwitch, self.verboseOperationsLoggingSwitch, self.altSignVerboseLoggingSwitch,
            self.minimuxerVerboseLoggingSwitch, self.rotateLogsOnStartupSwitch,
            self.disableResponseCachingSwitch, self.recreateDatabaseSwitch
        ]
        
        for sw in switches {
            guard let sw = sw else { continue }
            sw.onTintColor = CSSTheme.dreamyPurple
            sw.thumbTintColor = CSSTheme.white
            sw.layer.shadowColor = CSSTheme.dreamyPurple.cgColor
            sw.layer.shadowOffset = CGSize(width: 0, height: 3)
            sw.layer.shadowRadius = 6
            sw.layer.shadowOpacity = 0.25
        }
    }

    // Tạo khối Hero Banner Aurora Pastel 3 màu (Xanh Sky -> Tím Mộng Mơ -> Hồng Phấn)
    private func setupCSSHeroBanner() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 122))
        headerContainer.backgroundColor = .clear
        
        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = 22.0
        heroCard.layer.cornerCurve = .continuous
        heroCard.layer.masksToBounds = false
        heroCard.layer.borderWidth = 1.2
        heroCard.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        heroCard.layer.shadowColor = CSSTheme.dreamyPurple.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 8)
        heroCard.layer.shadowRadius = 18
        heroCard.layer.shadowOpacity = 0.28
        
        let gradient = CAGradientLayer()
        gradient.colors = [CSSTheme.heroStart, CSSTheme.heroMiddle, CSSTheme.heroEnd]
        gradient.locations = [0.0, 0.52, 1.0]
        gradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradient.cornerRadius = 22.0
        gradient.cornerCurve = .continuous
        heroCard.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient

        // Lớp trang trí Bokeh lấp lánh bên trong Banner
        let bokehContainer = UIView()
        bokehContainer.translatesAutoresizingMaskIntoConstraints = false
        bokehContainer.clipsToBounds = true
        bokehContainer.layer.cornerRadius = 22.0
        bokehContainer.layer.cornerCurve = .continuous
        bokehContainer.isUserInteractionEnabled = false

        let circleRight = UIView(frame: CGRect(x: 240, y: -28, width: 110, height: 110))
        circleRight.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        circleRight.layer.cornerRadius = 55
        bokehContainer.addSubview(circleRight)

        let circleLeft = UIView(frame: CGRect(x: -25, y: 45, width: 86, height: 86))
        circleLeft.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        circleLeft.layer.cornerRadius = 43
        bokehContainer.addSubview(circleLeft)

        heroCard.addSubview(bokehContainer)

        // Huy hiệu nhỏ phía trên chữ SideStore
        let pillBadge = UILabel()
        pillBadge.translatesAutoresizingMaskIntoConstraints = false
        pillBadge.text = "  ✨ AURORA DREAMY EDITION ✨  "
        pillBadge.font = CSSTheme.roundedFont(ofSize: 10, weight: .heavy)
        pillBadge.textColor = UIColor.white
        pillBadge.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        pillBadge.layer.cornerRadius = 9
        pillBadge.layer.cornerCurve = .continuous
        pillBadge.layer.masksToBounds = true
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "SideStore"
        titleLabel.font = CSSTheme.roundedFont(ofSize: 26, weight: .heavy)
        titleLabel.textColor = UIColor.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = CSSTheme.dark.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 6
        titleLabel.layer.shadowOpacity = 0.20
        
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Không gian cài đặt thanh lịch • Tùy chỉnh ứng dụng theo phong cách của bạn"
        subLabel.font = CSSTheme.roundedFont(ofSize: 12.5, weight: .semibold)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.96)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2
        
        heroCard.addSubview(pillBadge)
        heroCard.addSubview(titleLabel)
        heroCard.addSubview(subLabel)
        headerContainer.addSubview(heroCard)
        
        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 6),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),

            bokehContainer.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor),
            bokehContainer.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor),
            bokehContainer.topAnchor.constraint(equalTo: heroCard.topAnchor),
            bokehContainer.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor),

            pillBadge.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            pillBadge.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 11),
            pillBadge.heightAnchor.constraint(equalToConstant: 18),
            
            titleLabel.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: pillBadge.bottomAnchor, constant: 4),
            
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14)
        ])
        
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.52, delay: 0.04, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
        
        self.tableView.tableHeaderView = headerContainer
    }

    private func createCompactCreditChip(title: String, color: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle("  \(title)  ", for: .normal)
        btn.setTitleColor(color, for: .normal)
        btn.titleLabel?.font = CSSTheme.roundedFont(ofSize: 11.5, weight: .bold)
        btn.backgroundColor = color.withAlphaComponent(0.12)
        btn.layer.cornerRadius = 12
        btn.layer.cornerCurve = .continuous
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = color.withAlphaComponent(0.30).cgColor
        btn.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.heightAnchor.constraint(equalToConstant: 25)
        ])
        return btn
    }

    // Chân trang Trắng Sữa Pastel: Thẻ Lời cảm ơn + Phiên bản ứng dụng
    private func setupVersionTableFooterView() {
        let footerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 196))
        footerContainer.backgroundColor = .clear

        let thanksCard = UIView()
        thanksCard.translatesAutoresizingMaskIntoConstraints = false
        thanksCard.backgroundColor = CSSTheme.white
        thanksCard.layer.cornerRadius = CSSTheme.cornerRadius
        thanksCard.layer.cornerCurve = .continuous
        thanksCard.layer.borderWidth = 1.2
        thanksCard.layer.borderColor = CSSTheme.border.cgColor
        thanksCard.layer.shadowColor = CSSTheme.dreamyPurple.cgColor
        thanksCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        thanksCard.layer.shadowRadius = 14
        thanksCard.layer.shadowOpacity = 0.10

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "🌸 LỜI CẢM ƠN & TRI ÂN 🌸"
        titleLabel.font = CSSTheme.roundedFont(ofSize: 12.5, weight: .heavy)
        titleLabel.textColor = CSSTheme.blushPink
        titleLabel.textAlignment = .center

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 4.0

        let bodyText = """
        Tri ân đội ngũ phát triển & cộng đồng mã nguồn mở:
        SideStore Team (@sidestoreio) • Giao diện: @lit_ritt
        Nền tảng AltStore: Riley Testut & Cộng đồng
        """
        bodyLabel.attributedText = NSAttributedString(
            string: bodyText,
            attributes: [
                .font: CSSTheme.roundedFont(ofSize: 11.5, weight: .medium),
                .foregroundColor: CSSTheme.textPrimary.withAlphaComponent(0.86),
                .paragraphStyle: paragraph
            ]
        )

        let btnSideStore = createCompactCreditChip(title: "@sidestoreio", color: CSSTheme.skyBlue, action: #selector(openSideStoreTwitterChip))
        let btnLitRitt = createCompactCreditChip(title: "@lit_ritt", color: CSSTheme.dreamyPurple, action: #selector(openLitRittTwitterChip))
        let btnGitHub = createCompactCreditChip(title: "GitHub", color: CSSTheme.blushPink, action: #selector(followAltStoreGitHub))

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

            titleLabel.topAnchor.constraint(equalTo: thanksCard.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: thanksCard.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: thanksCard.trailingAnchor, constant: -14),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            bodyLabel.leadingAnchor.constraint(equalTo: thanksCard.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: thanksCard.trailingAnchor, constant: -14),

            chipStack.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 10),
            chipStack.centerXAnchor.constraint(equalTo: thanksCard.centerXAnchor),
            chipStack.bottomAnchor.constraint(equalTo: thanksCard.bottomAnchor, constant: -12),

            vLabel.topAnchor.constraint(equalTo: thanksCard.bottomAnchor, constant: 12),
            vLabel.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 16),
            vLabel.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -16)
        ])

        self.tableView.tableFooterView = footerContainer
    }

    @objc private func openSideStoreTwitterChip() {
        CSSTheme.triggerLightHaptic()
        self.openTwitter(username: "sidestoreio")
    }

    @objc private func openLitRittTwitterChip() {
        CSSTheme.triggerLightHaptic()
        self.openTwitter(username: "lit_ritt")
    }

    // ✨ BÓC TÁCH LỚP NỀN CELL & GẮN BIỂU TƯỢNG PASTEL THÔNG MINH ✨
    private func styleInnerCardOfCell(_ cell: UITableViewCell, at indexPath: IndexPath, totalRows: Int) {
        cell.selectionStyle = .none
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = .clear
        
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        let targetCardView: UIView = cell.subviews.first(where: {
            $0 !== cell.contentView && $0 !== cell.selectedBackgroundView && $0.frame.width > 100 && !($0 is UIButton)
        }) ?? cell.contentView
        
        // Màu Trắng Sữa Ngọc Trai (#FFFCFA) cực kỳ sang trọng
        targetCardView.backgroundColor = CSSTheme.white
        
        var corners: CACornerMask = []
        if totalRows == 1 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if indexPath.row == 0 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if indexPath.row == totalRows - 1 {
            corners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        
        targetCardView.layer.cornerRadius = corners.isEmpty ? 0 : CSSTheme.cornerRadius
        targetCardView.layer.cornerCurve = .continuous
        targetCardView.layer.maskedCorners = corners
        targetCardView.layer.borderWidth = 1.0
        targetCardView.layer.borderColor = CSSTheme.border.cgColor
        
        // Đổ bóng Tím Mộng Mơ dịu nhẹ
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = CSSTheme.dreamyPurple.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 5)
        cell.layer.shadowRadius = 12
        cell.layer.shadowOpacity = 0.08
        
        // Đường kẻ phân cách Pastel giữa các dòng
        let sepTag = 8888
        cell.contentView.viewWithTag(sepTag)?.removeFromSuperview()
        if indexPath.row < totalRows - 1 {
            let sep = UIView()
            sep.tag = sepTag
            sep.backgroundColor = CSSTheme.separator
            sep.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 54),
                sep.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
                sep.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1.0)
            ])
        }
        
        let section = Section.allCases[indexPath.section]
        // Gắn Huy hiệu Icon Pastel thông minh cho từng dòng
        configurePastelIconBadge(in: cell.contentView, section: section, row: indexPath.row)
        // Việt hóa và làm đẹp toàn bộ chữ bên trong Cell
        translateAndStyleLabelsInside(view: cell.contentView, section: section, row: indexPath.row)
    }

    // Tự động tạo Huy hiệu Icon Pastel (Squircle 30x30) ở đầu mỗi dòng cài đặt
    private func configurePastelIconBadge(in contentView: UIView, section: Section, row: Int) {
        let badgeTag = 7766
        contentView.viewWithTag(badgeTag)?.removeFromSuperview()

        var symbolName: String? = nil
        var tintColor: UIColor = CSSTheme.dreamyPurple

        if section == .signIn {
            symbolName = "person.crop.circle.badge.plus"
            tintColor = CSSTheme.skyBlue
        } else if section == .account && row < 3 {
            switch row {
            case 0:
                symbolName = "person.text.rectangle.fill"
                tintColor = CSSTheme.skyBlue
            case 1:
                symbolName = "envelope.fill"
                tintColor = CSSTheme.dreamyPurple
            default:
                symbolName = "crown.fill"
                tintColor = CSSTheme.blushPink
            }
        } else if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            if activeItems.indices.contains(row) {
                let item = activeItems[row]
                symbolName = item.iconSymbol
                tintColor = item.iconTintColor
            }
        }

        guard let iconName = symbolName else { return }

        let badgeView = UIView()
        badgeView.tag = badgeTag
        badgeView.translatesAutoresizingMaskIntoConstraints = false
        badgeView.backgroundColor = tintColor.withAlphaComponent(0.14)
        badgeView.layer.cornerRadius = 9.5
        badgeView.layer.cornerCurve = .continuous
        badgeView.layer.borderWidth = 0.8
        badgeView.layer.borderColor = tintColor.withAlphaComponent(0.28).cgColor
        badgeView.isUserInteractionEnabled = false

        let imgConfig = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
        let imgView = UIImageView(image: UIImage(systemName: iconName, withConfiguration: imgConfig))
        imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.tintColor = tintColor
        imgView.contentMode = .scaleAspectFit

        badgeView.addSubview(imgView)
        contentView.addSubview(badgeView)

        NSLayoutConstraint.activate([
            badgeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            badgeView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            badgeView.widthAnchor.constraint(equalToConstant: 30),
            badgeView.heightAnchor.constraint(equalToConstant: 30),

            imgView.centerXAnchor.constraint(equalTo: badgeView.centerXAnchor),
            imgView.centerYAnchor.constraint(equalTo: badgeView.centerYAnchor)
        ])

        // Tự động dịch nhẹ tiêu đề bên trái sang phải 34pt để nhường chỗ cho Icon Pastel mà không phá vỡ AutoLayout gốc
        for subview in contentView.subviews {
            if let label = subview as? UILabel,
               label !== self.accountNameLabel,
               label !== self.accountEmailLabel,
               label !== self.accountTypeLabel {
                label.transform = CGAffineTransform(translationX: 34, y: 0)
            }
        }
    }

    // Khôi phục ngay lập tức nền Trắng Sữa cho tất cả các Cell đang hiển thị
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
    }

    // Bộ từ điển dịch tự động 100% các chuỗi tĩnh từ Storyboard & Hệ thống sang Tiếng Việt
    private func translateStaticText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dictionary: [String: String] = [
            // Tài khoản & Đăng nhập
            "Sign in with Apple ID": "Đăng nhập bằng ID Apple",
            "Sign In with Apple ID": "Đăng nhập bằng ID Apple",
            "Sign In": "Đăng nhập",
            "Name": "Họ tên",
            "Email": "Email",
            "Type": "Loại tài khoản",
            "Free Developer Account": "Tài khoản Nhà phát triển Miễn phí",
            "Regular Account": "Tài khoản Miễn phí",
            "Developer Account": "Tài khoản Nhà phát triển",
            "Paid Developer Account": "Tài khoản Nhà phát triển Trả phí",
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
        
        return dictionary[trimmed] ?? text
    }

    private func translateAndStyleLabelsInside(view: UIView, section: Section, row: Int) {
        let activeItems = UnifiedSettingsItem.activeItems
        let isClearCacheRow = (section == .advancedSettings && activeItems.indices.contains(row) && activeItems[row] == .clearCache)

        for subview in view.subviews {
            if let label = subview as? UILabel {
                if subview.superview is UIButton {
                    continue
                }
                
                if let currentText = label.text, !currentText.isEmpty {
                    label.text = translateStaticText(currentText)
                }
                
                if label == self.accountNameLabel || label == self.accountEmailLabel || label == self.accountTypeLabel {
                    label.transform = .identity
                    if label == self.accountTypeLabel, let typeText = label.text {
                        label.text = translateStaticText(typeText)
                    }
                    label.textColor = (label == self.accountNameLabel) ? CSSTheme.skyBlue : CSSTheme.dreamyPurple
                    label.font = CSSTheme.roundedFont(ofSize: 15, weight: .bold)
                } else if section == .signIn {
                    label.textColor = CSSTheme.skyBlue
                    label.font = CSSTheme.roundedFont(ofSize: 16.5, weight: .bold)
                } else if isClearCacheRow {
                    label.textColor = CSSTheme.blushPink
                    label.font = CSSTheme.roundedFont(ofSize: 16, weight: .bold)
                } else if label.textColor == .systemRed {
                    label.textColor = CSSTheme.blushPink
                } else {
                    label.textColor = CSSTheme.textPrimary
                    if label.font.pointSize >= 15 {
                        label.font = CSSTheme.roundedFont(ofSize: 15.5, weight: .semibold)
                    }
                }
            }
            translateAndStyleLabelsInside(view: subview, section: section, row: row)
        }
    }

    // Xử lý bấm nút "Tài Khoản" để ẩn/hiện khung thông tin tài khoản
    @objc private func toggleAccountDetailsVisibility(_ sender: UIButton) {
        CSSTheme.triggerLightHaptic()
        self.isAccountDetailsExpanded.toggle()
        
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()
            
            if let headerView = self.tableView.headerView(forSection: Section.account.rawValue) as? SettingsHeaderFooterView {
                self.prepare(headerView, for: .account, isHeader: true)
            }
            
            for row in 0..<3 {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: row, section: Section.account.rawValue)) {
                    cell.alpha = self.isAccountDetailsExpanded ? 1.0 : 0.0
                    cell.isHidden = !self.isAccountDetailsExpanded
                }
            }
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
            string: "✨ " + appVersion + " ✨",
            attributes: [
                .font: CSSTheme.roundedFont(ofSize: 13.5, weight: .bold),
                .foregroundColor: CSSTheme.dreamyPurple,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        let iosVersionAttr = NSAttributedString(
            string: "\n" + iosVersion,
            attributes: [
                .font: CSSTheme.roundedFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: CSSTheme.textSecondary,
                .paragraphStyle: paragraphStyle
            ]
        )
        
        fullString.append(appVersionAttr)
        fullString.append(iosVersionAttr)
        return fullString
    }

    @objc private func copyVersionLabelTapped() {
        CSSTheme.triggerLightHaptic()
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
                .font: CSSTheme.roundedFont(ofSize: 14, weight: .bold),
                .foregroundColor: CSSTheme.dreamyPurple,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributed.append(NSAttributedString(string: "♥", attributes: [
            .font: CSSTheme.roundedFont(ofSize: 14, weight: .bold),
            .foregroundColor: CSSTheme.blushPink
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
        let typeIndexPath = IndexPath(row: 2, section: Section.account.rawValue)
        if let typeCell = self.tableView.cellForRow(at: typeIndexPath) as? InsetGroupTableViewCell {
            typeCell.style = (self.accountStatus == .completed) ? .bottom : .middle
        }
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

    private func prepare(_ settingsHeaderFooterView: SettingsHeaderFooterView, for section: Section, isHeader: Bool)
    {
        settingsHeaderFooterView.primaryLabel.isHidden = !isHeader
        settingsHeaderFooterView.secondaryLabel.isHidden = isHeader
        settingsHeaderFooterView.button.isHidden = true
        
        settingsHeaderFooterView.primaryLabel.textColor = CSSTheme.dark
        settingsHeaderFooterView.primaryLabel.font = CSSTheme.roundedFont(ofSize: 14, weight: .heavy)
        settingsHeaderFooterView.secondaryLabel.textColor = CSSTheme.textSecondary
        settingsHeaderFooterView.secondaryLabel.font = CSSTheme.roundedFont(ofSize: 12.5, weight: .medium)
        
        let toggleAccountTag = 9992
        let underlineTag = 9991
        settingsHeaderFooterView.contentView.viewWithTag(toggleAccountTag)?.removeFromSuperview()
        settingsHeaderFooterView.contentView.viewWithTag(underlineTag)?.removeFromSuperview()
        
        // Thanh gạch chân Gradient 3 màu (Xanh Sky -> Tím Mộng Mơ -> Hồng Phấn) cực xinh dưới tiêu đề
        if isHeader {
            let underline = UIView(frame: CGRect(x: 0, y: 0, width: 52, height: 3.5))
            underline.tag = underlineTag
            underline.layer.cornerRadius = 1.75
            underline.clipsToBounds = true
            underline.translatesAutoresizingMaskIntoConstraints = false

            let grad = CAGradientLayer()
            grad.frame = CGRect(x: 0, y: 0, width: 52, height: 3.5)
            grad.colors = [CSSTheme.skyBlue.cgColor, CSSTheme.dreamyPurple.cgColor, CSSTheme.blushPink.cgColor]
            grad.startPoint = CGPoint(x: 0, y: 0.5)
            grad.endPoint = CGPoint(x: 1, y: 0.5)
            underline.layer.insertSublayer(grad, at: 0)

            settingsHeaderFooterView.contentView.addSubview(underline)
            NSLayoutConstraint.activate([
                underline.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.leadingAnchor),
                underline.topAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.bottomAnchor, constant: 3),
                underline.widthAnchor.constraint(equalToConstant: 52),
                underline.heightAnchor.constraint(equalToConstant: 3.5)
            ])
        }
        
        settingsHeaderFooterView.layoutMargins.bottom = isHeader ? 8 : 8
        
        switch section
        {
        case .signIn:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = "✦ TÀI KHOẢN APPLE ID"
            } else {
                settingsHeaderFooterView.secondaryLabel.text = "Đăng nhập bằng ID Apple của bạn để tải xuống và làm mới ứng dụng từ SideStore."
            }
            
        case .account:
            settingsHeaderFooterView.primaryLabel.text = "✦ TÀI KHOẢN"
            
            // 1. Nút "Tài Khoản" Pastel Pill sang trọng
            let toggleBtn = UIButton(type: .system)
            toggleBtn.tag = toggleAccountTag
            toggleBtn.translatesAutoresizingMaskIntoConstraints = false
            let toggleTitle = self.isAccountDetailsExpanded ? "  Ẩn Tài Khoản ▲  " : "  Xem Tài Khoản ▼  "
            toggleBtn.setTitle(toggleTitle, for: .normal)
            toggleBtn.setTitleColor(CSSTheme.white, for: .normal)
            toggleBtn.titleLabel?.font = CSSTheme.roundedFont(ofSize: 11.5, weight: .bold)
            toggleBtn.backgroundColor = self.isAccountDetailsExpanded ? CSSTheme.dreamyPurple : CSSTheme.skyBlue
            toggleBtn.layer.cornerRadius = 12
            toggleBtn.layer.cornerCurve = .continuous
            toggleBtn.layer.shadowColor = CSSTheme.dreamyPurple.cgColor
            toggleBtn.layer.shadowOffset = CGSize(width: 0, height: 3)
            toggleBtn.layer.shadowRadius = 6
            toggleBtn.layer.shadowOpacity = 0.25
            toggleBtn.addTarget(self, action: #selector(toggleAccountDetailsVisibility(_:)), for: .touchUpInside)
            
            settingsHeaderFooterView.contentView.addSubview(toggleBtn)
            
            // 2. Nút "ĐĂNG XUẤT" màu Hồng Phấn (Blush Pink) ngọt ngào & nổi bật
            let signOutBtn = settingsHeaderFooterView.button!
            signOutBtn.removeTarget(nil, action: nil, for: .allEvents)
            signOutBtn.setTitle("  ĐĂNG XUẤT  ", for: .normal)
            signOutBtn.setTitleColor(CSSTheme.white, for: .normal)
            signOutBtn.titleLabel?.font = CSSTheme.roundedFont(ofSize: 11, weight: .bold)
            signOutBtn.backgroundColor = CSSTheme.blushPink
            signOutBtn.layer.cornerRadius = 12
            signOutBtn.layer.cornerCurve = .continuous
            signOutBtn.layer.shadowColor = CSSTheme.blushPink.cgColor
            signOutBtn.layer.shadowOffset = CGSize(width: 0, height: 3)
            signOutBtn.layer.shadowRadius = 6
            signOutBtn.layer.shadowOpacity = 0.28
            signOutBtn.addTarget(self, action: #selector(SettingsViewController.signOut(_:)), for: .primaryActionTriggered)
            signOutBtn.isHidden = false
            
            NSLayoutConstraint.activate([
                toggleBtn.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.trailingAnchor, constant: 10),
                toggleBtn.centerYAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.centerYAnchor),
                toggleBtn.heightAnchor.constraint(equalToConstant: 24)
            ])
            
        case .advancedSettings:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = "✦ TRUNG TÂM CÀI ĐẶT & HỆ THỐNG"
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
            return max(36, size.height)
        }
        return size.height + (isHeader ? 6 : 0)
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
        CSSTheme.triggerLightHaptic()
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

    // Khóa cứng trạng thái tắt cho các IBAction đã loại bỏ (Giữ @IBAction để không crash Storyboard)
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
                    toast.tintColor = CSSTheme.dreamyPurple
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
            String(format: "Bạn có chắc chắn muốn xóa bộ nhớ đệm của SideStore không?\n\nDung lượng đệm: %@", sizeString)
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
                self.openWebURL(safariURL, preferredTintColor: CSSTheme.dreamyPurple)
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

    // Giữ nguyên các @IBAction kết nối với Storyboard để không bao giờ gây crash khi nạp Nib
    @IBAction private func followAltStoreMastodon() { self.openMastodon(username: "@sidestoreio@fosstodon.org") }
    @IBAction private func followAltStoreThreads() { self.openThreads(username: "sidestore.io") }
    @IBAction private func followAltStoreTwitter() { self.openTwitter(username: "sidestoreio") }
    @objc @IBAction private func followAltStoreGitHub() {
        CSSTheme.triggerLightHaptic()
        UIApplication.shared.open(AppConstants.URLs.sideStoreGitHub, options: [:])
    }

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
            if indexPath.row == 3 {
                return AccountVerificationRow.preferredHeight
            }
        }
        
        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { return 0.0 }
            let baseHeight = super.tableView(tableView, heightForRowAt: activeItems[indexPath.row].originalIndexPath)
            return max(baseHeight, 52.0)
        }
        
        return super.tableView(tableView, heightForRowAt: indexPath)
    }

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
            
            if indexPath.row == 2, let insetCell = cell as? InsetGroupTableViewCell {
                insetCell.style = (self.accountStatus == .completed) ? .bottom : .middle
            } else if indexPath.row == 3, let actionCell = cell as? AccountVerificationRow {
                actionCell.style = self.isAccountDetailsExpanded ? .bottom : .single
                actionCell.backgroundColor = .clear
                actionCell.contentView.backgroundColor = .clear
                if #available(iOS 14.0, tvOS 14.0, *) {
                    actionCell.backgroundConfiguration = .clear()
                }
                return
            }
        }
        
        self.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
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
            cell.style = self.isAccountDetailsExpanded ? .bottom : .single
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
        cell.selectionStyle = .none
        
        if section == .account && indexPath.row == 2 {
            if let insetCell = cell as? InsetGroupTableViewCell {
                insetCell.style = (self.accountStatus == .completed) ? .bottom : .middle
            }
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
        CSSTheme.triggerLightHaptic()
        tableView.deselectRow(at: indexPath, animated: false)
        self.restoreVisibleCellsWhiteBackground()

        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.11, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
            }) { [weak self] _ in
                self?.restoreVisibleCellsWhiteBackground()
                UIView.animate(withDuration: 0.34, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
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
