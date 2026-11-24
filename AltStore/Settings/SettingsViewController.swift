
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

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN 100% MÃ WEB CSS & SOURCESVIEWCONTROLLER
private struct CSSTheme {
    static let white = UIColor.white                                                          // #fff (--white)
    static let pureBlack = UIColor.black                                                      // #000 (Chữ tiêu đề & nội dung)
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0)       // #f8f9fa (--light)
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0)      // #e9ecef (--border)
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff (--blue)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1 (--purple)
    static let indigo = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1.0)        // #5856d6
    static let teal = UIColor(red: 23/255, green: 162/255, blue: 184/255, alpha: 1.0)         // #17a2b8
    static let orange = UIColor(red: 253/255, green: 126/255, blue: 20/255, alpha: 1.0)       // #fd7e14
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)         // #28a745 (--green)
    static let badgeGreenBorder = UIColor(red: 50/255, green: 196/255, blue: 83/255, alpha: 1.0) // #32c453 (.topic-id-badge border)
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)           // #dc3545
    static let magenta = UIColor(red: 230/255, green: 0/255, blue: 230/255, alpha: 1.0)       // #e600e6 (data-tab="1")
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0)           // #343a40 (--dark)

    // Body Gradient: linear-gradient(to right, #f3e0ff, #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Sleek Top Banner Gradient: linear-gradient(125deg, #007bff 0%, #6f42c1 52%, #d600d6 100%)
    static let bannerGradStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0).cgColor
    static let bannerGradMid = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0).cgColor
    static let bannerGradEnd = UIColor(red: 214/255, green: 0/255, blue: 214/255, alpha: 1.0).cgColor

    static let cornerRadius: CGFloat = 15.0        // --radius: 15px
    static let bannerCornerRadius: CGFloat = 18.0  // .sleek-top-banner border-radius: 18px

    /// Trả về đúng 4 màu chủ đạo luân phiên theo chuẩn `.tab-button[data-tab="1..4"]` và `.guide-step-card:nth-child(4n+1..4)`
    static func tabAccentColor(for index: Int) -> UIColor {
        switch index % 4 {
        case 0: return magenta // #e600e6
        case 1: return purple  // #6f42c1
        case 2: return blue    // #007bff
        default: return green  // #28a745
        }
    }

    /// Áp dụng viền 4 cạnh bằng nhau (2px solid var(--border)) + đổ bóng màu chuẩn CSS
    static func applyColoredGlowCardStyle(
        to view: UIView,
        accentColor: UIColor,
        cornerRadius: CGFloat = CSSTheme.cornerRadius,
        shadowOpacity: Float = 0.22
    ) {
        view.backgroundColor = CSSTheme.white
        view.layer.backgroundColor = CSSTheme.white.cgColor
        view.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 2.0
        view.layer.borderColor = CSSTheme.border.cgColor
        view.layer.shadowColor = accentColor.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 14
        view.layer.shadowOpacity = shadowOpacity
    }

    /// Áp dụng style cho khung bao trắng lớn (.tab-container & footer)
    static func applyContainerCardStyle(to view: UIView, cornerRadius: CGFloat = CSSTheme.cornerRadius) {
        view.backgroundColor = CSSTheme.white
        view.layer.backgroundColor = CSSTheme.white.cgColor
        view.layer.cornerRadius = cornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            view.layer.cornerCurve = .continuous
        }
        view.layer.borderWidth = 0.0
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 20
        view.layer.shadowOpacity = 0.10
    }

    // SwiftUI Colors (Phục vụ bảng Máy chủ Anisette đồng bộ 100% với CSS)
    static let suiPrimary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)
    static let suiSecondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
    static let suiMagenta = SwiftUI.Color(red: 230/255, green: 0/255, blue: 230/255)
    static let suiGreen = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)
    static let suiRed = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)
    static let suiPureBlack = SwiftUI.Color.black
    static let suiDark = SwiftUI.Color(red: 52/255, green: 58/255, blue: 64/255)
    static let suiCardBackground = SwiftUI.Color.white
    static let suiInnerRowBackground = SwiftUI.Color(red: 248/255, green: 249/255, blue: 250/255) // #f8f9fa (--light)
    static let suiBorder = SwiftUI.Color(red: 233/255, green: 236/255, blue: 239/255)           // #e9ecef (--border)

    // Chuẩn CSS: background: linear-gradient(to right, #f3e0ff, #e0f7ff)
    static var suiPageGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255),
                SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - 🌈 LỚP NỀN BODY GRADIENT NGANG (linear-gradient(to right, #f3e0ff, #e0f7ff))
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
        // Chuẩn CSS: linear-gradient(to right, #f3e0ff, #e0f7ff)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
}

// MARK: - 🌟 LỚP NỀN SLEEK TOP BANNER TỰ ĐỘNG PHỦ MÀU 100% (.sleek-top-banner & ::before)
private final class SleekTopBannerGradientView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    private let shineLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBannerLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBannerLayers()
    }

    private func setupBannerLayers() {
        backgroundColor = CSSTheme.purple

        layer.cornerRadius = CSSTheme.bannerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            layer.cornerCurve = .continuous
        }
        clipsToBounds = true
        layer.borderWidth = 1.5
        layer.borderColor = UIColor.white.withAlphaComponent(0.70).cgColor

        if let gradientLayer = self.layer as? CAGradientLayer {
            // Chuẩn CSS: background: linear-gradient(125deg, #007bff 0%, #6f42c1 52%, #d600d6 100%)
            gradientLayer.colors = [
                CSSTheme.bannerGradStart,
                CSSTheme.bannerGradMid,
                CSSTheme.bannerGradEnd
            ]
            gradientLayer.locations = [0.0, 0.52, 1.0]
            gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
            gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        }

        // Chuẩn CSS .sleek-top-banner::before (Vệt kính chéo skewX(-22deg))
        shineLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.24).cgColor,
            UIColor.clear.cgColor
        ]
        shineLayer.locations = [0.0, 0.5, 1.0]
        shineLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        shineLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        shineLayer.setAffineTransform(CGAffineTransform(a: 1, b: 0, c: -0.40, d: 1, tx: 0, ty: 0))
        layer.insertSublayer(shineLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shineLayer.frame = CGRect(
            x: -bounds.width * 0.15,
            y: -bounds.height * 0.2,
            width: bounds.width * 0.55,
            height: bounds.height * 1.4
        )
        CATransaction.commit()
    }
}

// MARK: - 🏷️ KHỐI BANNER TIÊU ĐỀ TRÊN CÙNG CĂN GIỮA 100% (.sleek-top-banner)
private final class SleekTopBannerBoxView: UIView {
    private let shadowContainer = UIView()
    private let gradientBannerView = SleekTopBannerGradientView()

    private let contentStack = UIStackView()
    private let titleRowStack = UIStackView()
    private let iconGlassBox = UIView()
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBannerUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBannerUI()
    }

    private func setupBannerUI() {
        backgroundColor = .clear

        // Đổ bóng chuẩn CSS: box-shadow: 0 10px 22px rgba(111, 66, 193, 0.28)
        shadowContainer.translatesAutoresizingMaskIntoConstraints = false
        shadowContainer.backgroundColor = .clear
        shadowContainer.layer.cornerRadius = CSSTheme.bannerCornerRadius
        if #available(iOS 13.0, tvOS 13.0, *) {
            shadowContainer.layer.cornerCurve = .continuous
        }
        shadowContainer.layer.masksToBounds = false
        shadowContainer.layer.shadowColor = CSSTheme.purple.cgColor
        shadowContainer.layer.shadowOffset = CGSize(width: 0, height: 10)
        shadowContainer.layer.shadowRadius = 16
        shadowContainer.layer.shadowOpacity = 0.28

        gradientBannerView.translatesAutoresizingMaskIntoConstraints = false

        // Hộp kính (.banner-glass-icon: 30x30px, border-radius: 10px)
        iconGlassBox.translatesAutoresizingMaskIntoConstraints = false
        iconGlassBox.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        iconGlassBox.layer.cornerRadius = 10
        if #available(iOS 13.0, tvOS 13.0, *) {
            iconGlassBox.layer.cornerCurve = .continuous
        }
        iconGlassBox.layer.borderWidth = 1.3
        iconGlassBox.layer.borderColor = UIColor.white.withAlphaComponent(0.70).cgColor
        iconGlassBox.layer.shadowColor = UIColor.black.cgColor
        iconGlassBox.layer.shadowOffset = CGSize(width: 0, height: 3)
        iconGlassBox.layer.shadowRadius = 5
        iconGlassBox.layer.shadowOpacity = 0.15

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        let starCfg = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)
        iconImageView.image = UIImage(systemName: "star", withConfiguration: starCfg)
        iconImageView.tintColor = CSSTheme.white
        iconImageView.contentMode = .scaleAspectFit
        iconGlassBox.addSubview(iconImageView)

        // Tiêu đề h1 (.sleek-top-banner h1)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 21.0, weight: .heavy)
        titleLabel.textColor = CSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.22

        // Hàng tiêu đề (.banner-title-row)
        titleRowStack.translatesAutoresizingMaskIntoConstraints = false
        titleRowStack.axis = .horizontal
        titleRowStack.alignment = .center
        titleRowStack.distribution = .fill
        titleRowStack.spacing = 9
        titleRowStack.addArrangedSubview(iconGlassBox)
        titleRowStack.addArrangedSubview(titleLabel)

        // Phụ đề p (.sleek-top-banner p)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        // Stack tổng căn giữa hoàn toàn
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 4
        contentStack.addArrangedSubview(titleRowStack)
        contentStack.addArrangedSubview(subtitleLabel)

        gradientBannerView.addSubview(contentStack)
        shadowContainer.addSubview(gradientBannerView)
        addSubview(shadowContainer)

        NSLayoutConstraint.activate([
            shadowContainer.leadingAnchor.constraint(equalTo: leadingAnchor),
            shadowContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            shadowContainer.topAnchor.constraint(equalTo: topAnchor),
            shadowContainer.bottomAnchor.constraint(equalTo: bottomAnchor),

            gradientBannerView.leadingAnchor.constraint(equalTo: shadowContainer.leadingAnchor),
            gradientBannerView.trailingAnchor.constraint(equalTo: shadowContainer.trailingAnchor),
            gradientBannerView.topAnchor.constraint(equalTo: shadowContainer.topAnchor),
            gradientBannerView.bottomAnchor.constraint(equalTo: shadowContainer.bottomAnchor),

            iconGlassBox.widthAnchor.constraint(equalToConstant: 30),
            iconGlassBox.heightAnchor.constraint(equalToConstant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: iconGlassBox.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconGlassBox.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),

            contentStack.topAnchor.constraint(equalTo: gradientBannerView.topAnchor, constant: 14),
            contentStack.bottomAnchor.constraint(equalTo: gradientBannerView.bottomAnchor, constant: -14),
            contentStack.leadingAnchor.constraint(equalTo: gradientBannerView.leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(equalTo: gradientBannerView.trailingAnchor, constant: -14),

            titleRowStack.leadingAnchor.constraint(greaterThanOrEqualTo: contentStack.leadingAnchor),
            titleRowStack.trailingAnchor.constraint(lessThanOrEqualTo: contentStack.trailingAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor)
        ])
    }

    func configure(title: String, subtitle: String, customIcon: UIImage? = nil) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        if let customIcon = customIcon {
            iconImageView.image = customIcon
            iconImageView.layer.cornerRadius = 5
            iconImageView.clipsToBounds = true
        } else {
            let starCfg = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)
            iconImageView.image = UIImage(systemName: "star", withConfiguration: starCfg)
            iconImageView.tintColor = CSSTheme.white
            iconImageView.layer.cornerRadius = 0
            iconImageView.clipsToBounds = false
        }
    }
}

// MARK: - ➖ THANH GẠCH CHÂN XANH NẰM CHÍNH GIỮA (60x3pt CHUẨN `.features h2::after` TRONG CSS GỐC)
private final class CSSCenteredUnderlineView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = CSSTheme.blue
        layer.cornerRadius = 1.5
        clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = CSSTheme.blue
        layer.cornerRadius = 1.5
        clipsToBounds = true
    }
}

// MARK: - 🌐 BỘ QUẢN LÝ & GIAO DIỆN MÁY CHỦ ANISETTE (ĐỒNG BỘ 100% MÃ WEB CSS)
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
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .offset(y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// Khung Section SwiftUI chuẩn `.features h2` + `.tab-container` trong mã Web
private struct SettingsSkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var trailingView: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .center, spacing: 12) {
            // Tiêu đề `.features h2` + gạch chân `60x3pt` ở chính giữa
            VStack(alignment: .center, spacing: 7) {
                HStack(spacing: 6) {
                    SwiftUI.Text(title.uppercased())
                        .font(.system(size: 17.5, weight: .heavy))
                        .foregroundColor(CSSTheme.suiPrimary)
                        .multilineTextAlignment(.center)

                    if let trailingView = trailingView {
                        trailingView
                    }
                }

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(CSSTheme.suiPrimary)
                    .frame(width: 60, height: 3.0)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)

            // Khung trắng `.tab-container`
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSTheme.suiCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .shadow(color: SwiftUI.Color.black.opacity(0.10), radius: 14, x: 0, y: 8)
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

    private func tabColor(for index: Int) -> SwiftUI.Color {
        switch index % 4 {
        case 0: return CSSTheme.suiMagenta
        case 1: return CSSTheme.suiSecondary
        case 2: return CSSTheme.suiPrimary
        default: return CSSTheme.suiGreen
        }
    }

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // 1. Thanh tiêu đề trên cùng chuẩn `.sleek-top-banner` trong mã Web
                    VStack(spacing: 4) {
                        HStack(spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(SwiftUI.Color.white.opacity(0.22))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(SwiftUI.Color.white.opacity(0.70), lineWidth: 1.3)
                                    )
                                SwiftUI.Image(systemName: vm.isAnisetteOK ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            SwiftUI.Text(vm.isAnisetteOK ? "Máy Chủ Anisette Ổn Định" : "Đang Bật On-Device Anisette")
                                .font(.system(size: 19.5, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        SwiftUI.Text(vm.anisetteDetail)
                            .font(.system(size: 13.0, weight: .medium))
                            .foregroundColor(SwiftUI.Color.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            stops: [
                                .init(color: CSSTheme.suiPrimary, location: 0.0),
                                .init(color: CSSTheme.suiSecondary, location: 0.52),
                                .init(color: SwiftUI.Color(red: 214/255, green: 0/255, blue: 214/255), location: 1.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.bannerCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.bannerCornerRadius, style: .continuous)
                            .stroke(SwiftUI.Color.white.opacity(0.70), lineWidth: 1.5)
                    )
                    .shadow(color: CSSTheme.suiSecondary.opacity(0.28), radius: 14, x: 0, y: 8)

                    // 2. Chế độ xác thực Anisette
                    SettingsSkySectionCard(
                        title: "CHẾ ĐỘ XÁC THỰC ANISETTE",
                        icon: "slider.horizontal.3",
                        color: CSSTheme.suiPrimary
                    ) {
                        Toggle(isOn: Binding(
                            get: { vm.useOnDeviceAnisette },
                            set: { vm.setUseOnDeviceAnisette($0) }
                        )) {
                            HStack(spacing: 11) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(CSSTheme.suiMagenta)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: CSSTheme.suiMagenta.opacity(0.28), radius: 6, x: 0, y: 4)
                                    SwiftUI.Image(systemName: "iphone.gen3")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    SwiftUI.Text("Use On-Device Anisette")
                                        .font(.system(size: 15.5, weight: .bold))
                                        .foregroundColor(CSSTheme.suiPureBlack)
                                    SwiftUI.Text(vm.useOnDeviceAnisette
                                                 ? "Đang BẬT (Khuyên tắt để ổn định hơn)"
                                                 : "(Nên Tắt Để Dễ Đăng Nhập)")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(vm.useOnDeviceAnisette ? CSSTheme.suiRed : CSSTheme.suiGreen)
                                }
                            }
                        }
                        .tint(CSSTheme.suiPrimary)
                        .padding(12)
                        .background(CSSTheme.suiCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                                .stroke(CSSTheme.suiBorder, lineWidth: 2.0)
                        )
                        .shadow(color: CSSTheme.suiMagenta.opacity(0.20), radius: 10, x: 0, y: 6)

                        Toggle(isOn: Binding(
                            get: { vm.isAnisetteAutoRotationEnabled },
                            set: { vm.setAnisetteAutoRotationEnabled($0) }
                        )) {
                            HStack(spacing: 11) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                                        .fill(CSSTheme.suiSecondary)
                                        .frame(width: 40, height: 40)
                                        .shadow(color: CSSTheme.suiSecondary.opacity(0.28), radius: 6, x: 0, y: 4)
                                    SwiftUI.Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 17, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    SwiftUI.Text("Enable Auto Rotation")
                                        .font(.system(size: 15.5, weight: .bold))
                                        .foregroundColor(CSSTheme.suiPureBlack)
                                    SwiftUI.Text(vm.isAnisetteAutoRotationEnabled
                                                 ? "(Tự Động Đổi Máy Chủ Khi Lỗi)"
                                                 : "Đang Tắt “Nên chọn SideStore (New)”")
                                        .font(.system(size: 12.5, weight: .semibold))
                                        .foregroundColor(vm.isAnisetteAutoRotationEnabled ? CSSTheme.suiGreen : CSSTheme.suiRed)
                                }
                            }
                        }
                        .tint(CSSTheme.suiPrimary)
                        .padding(12)
                        .background(CSSTheme.suiCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                                .stroke(CSSTheme.suiBorder, lineWidth: 2.0)
                        )
                        .shadow(color: CSSTheme.suiSecondary.opacity(0.20), radius: 10, x: 0, y: 6)

                        if vm.useOnDeviceAnisette {
                            SwiftUI.Button {
                                vm.setUseOnDeviceAnisette(false)
                            } label: {
                                HStack(spacing: 8) {
                                    SwiftUI.Image(systemName: "checkmark.shield.fill")
                                    SwiftUI.Text("Tắt ngay Use On-Device Anisette")
                                        .font(.system(size: 15.5, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    LinearGradient(
                                        colors: [CSSTheme.suiPrimary, CSSTheme.suiSecondary],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                                .shadow(color: CSSTheme.suiPrimary.opacity(0.30), radius: 8, x: 0, y: 5)
                            }
                            .buttonStyle(SettingsBounceButtonStyle())
                        }
                    }

                    // 3. Danh sách máy chủ Anisette chuẩn `.tab-button`
                    SettingsSkySectionCard(
                        title: "CHỌN MÁY CHỦ ANISETTE",
                        icon: "server.rack",
                        color: CSSTheme.suiSecondary,
                        trailingView: vm.isLoading ? AnyView(ProgressView().tint(CSSTheme.suiPrimary)) : nil
                    ) {
                        VStack(spacing: 12) {
                            ForEach(Array(vm.servers.enumerated()), id: \.element.id) { idx, server in
                                let isSelected = (vm.selectedAnisetteServerURL.caseInsensitiveCompare(server.address) == .orderedSame)
                                let isRecommended = isRecommendedSideStoreNew(server)
                                let rowAccent = tabColor(for: idx)

                                SwiftUI.Button {
                                    vm.selectAnisetteServerURL(server.address, isCustom: false)
                                    Task { await vm.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                } label: {
                                    HStack(spacing: 11) {
                                        // Huy hiệu `.tab-num-badge`
                                        VStack(spacing: 1) {
                                            SwiftUI.Text("✦")
                                                .font(.system(size: 9.5, weight: .heavy))
                                                .foregroundColor(SwiftUI.Color.white.opacity(0.9))
                                            SwiftUI.Image(systemName: isSelected ? "checkmark" : "globe")
                                                .font(.system(size: 14, weight: .heavy))
                                                .foregroundColor(.white)
                                        }
                                        .frame(width: 44, height: 44)
                                        .background(rowAccent)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .shadow(color: rowAccent.opacity(0.28), radius: 6, x: 0, y: 4)

                                        VStack(alignment: .leading, spacing: 3) {
                                            SwiftUI.Text(server.name)
                                                .font(.system(size: 15.5, weight: .bold))
                                                .foregroundColor(CSSTheme.suiPureBlack)

                                            SwiftUI.Text("• " + server.address)
                                                .font(.system(size: 12.5, weight: .medium))
                                                .foregroundColor(CSSTheme.suiDark)
                                                .lineLimit(1)

                                            // Hàng huy hiệu `.tab-meta-pills`
                                            HStack(spacing: 5) {
                                                if isRecommended {
                                                    SwiftUI.Text("★ KHUYÊN DÙNG")
                                                        .font(.system(size: 10.0, weight: .heavy))
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2.5)
                                                        .background(CSSTheme.suiInnerRowBackground)
                                                        .foregroundColor(CSSTheme.suiGreen)
                                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                                .stroke(CSSTheme.suiBorder, lineWidth: 1)
                                                        )
                                                }
                                                if isSelected {
                                                    SwiftUI.Text("✓ ĐANG DÙNG")
                                                        .font(.system(size: 10.0, weight: .heavy))
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 2.5)
                                                        .background(CSSTheme.suiInnerRowBackground)
                                                        .foregroundColor(rowAccent)
                                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                                .stroke(CSSTheme.suiBorder, lineWidth: 1)
                                                        )
                                                }
                                            }
                                            .padding(.top, 2)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                    .background(CSSTheme.suiCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                                            .stroke(CSSTheme.suiBorder, lineWidth: 2.0)
                                    )
                                    .shadow(color: rowAccent.opacity(0.22), radius: 10, x: 0, y: 6)
                                }
                                .buttonStyle(SettingsBounceButtonStyle())
                            }
                        }

                        Divider()
                            .background(CSSTheme.suiBorder)
                            .padding(.vertical, 4)

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
                                    .padding(11)
                                    .background(CSSTheme.suiInnerRowBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(CSSTheme.suiBorder, lineWidth: 1.5)
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
                                    .padding(.vertical, 11)
                                    .background(
                                        LinearGradient(
                                            colors: [CSSTheme.suiPrimary, CSSTheme.suiSecondary],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .shadow(color: CSSTheme.suiPrimary.opacity(0.30), radius: 6, x: 0, y: 4)
                                }
                                .buttonStyle(SettingsBounceButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 12)
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
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(CSSTheme.suiPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") {
                        onDismiss?()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .heavy))
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

        // Cấu hình Icon SF Symbols & Màu sắc luân phiên chuẩn 4 màu data-tab="1..4" của mã Web
        var iconSpec: (symbol: String, color: UIColor, showChevron: Bool) {
            switch self {
            case .anisetteServers:
                return ("server.rack", CSSTheme.magenta, true)               // data-tab="1" (#e600e6)
            case .refreshAttempts:
                return ("clock.arrow.circlepath", CSSTheme.purple, true)     // data-tab="2" (#6f42c1)
            case .refreshSideJITServer:
                return ("bolt.horizontal.circle.fill", CSSTheme.blue, true)  // data-tab="3" (#007bff)
            case .certificateManagement:
                return ("checkmark.shield.fill", CSSTheme.green, true)       // data-tab="4" (#28a745)
            case .userCustomizations:
                return ("paintbrush.pointed.fill", CSSTheme.magenta, true)   // data-tab="1" (#e600e6)
            case .errorLog:
                return ("doc.text.magnifyingglass", CSSTheme.purple, true)   // data-tab="2" (#6f42c1)
            case .clearCache:
                return ("trash.fill", CSSTheme.blue, false)                  // data-tab="3" (#007bff)
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
    private let sleekBannerView = SleekTopBannerBoxView()

    // Nút quay lại chuẩn `.back-clean-btn` ở góc trên bên trái khi vào mục con
    private var floatingBackButton: UIButton?

    // Bộ đệm hình ảnh Icon gắn trực tiếp vào Label theo chuẩn `.tab-num-badge` của mã Web
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
        
        // Khóa cứng chế độ Sáng (Light Mode) để giữ chuẩn 100% bảng màu Web CSS
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
        self.tableView.contentInset.bottom = 40
        if #available(iOS 15.0, tvOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 0
        }
        
        // ✨ KÍCH HOẠT GIAO DIỆN WEB CSS & SOURCESVIEWCONTROLLER THEME ✨
        self.applySmartWebCSSTheme()
        
        self.update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Đảm bảo sau khi InsetGroupTableViewCell.layoutSubviews() chạy xong, các thẻ `.tab-button` và `.tab-container` giữ đúng style Web CSS
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

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI CHUẨN `.back-clean-btn` Ở MỤC CON
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
            // Chuẩn CSS `.back-clean-btn`: ‹ Quay lại cài đặt
            btn.setTitle("‹ Quay lại cài đặt", for: .normal)
            btn.setTitleColor(CSSTheme.blue, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .heavy)
            btn.backgroundColor = CSSTheme.white
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
            btn.layer.cornerRadius = 10
            btn.layer.borderWidth = 1.5
            btn.layer.borderColor = CSSTheme.border.cgColor
            btn.layer.shadowColor = CSSTheme.blue.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 6)
            btn.layer.shadowRadius = 10
            btn.layer.shadowOpacity = 0.18
            
            btn.addTarget(self, action: #selector(handleFloatingBackTap), for: .touchUpInside)
            nav.view.addSubview(btn)
            
            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.leadingAnchor, constant: 10),
                btn.topAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.topAnchor, constant: 6),
                btn.heightAnchor.constraint(equalToConstant: 32)
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

// MARK: - ✨ HỆ THỐNG RENDER CSS (.sleek-top-banner, .tab-container, .tab-button, footer)
private extension SettingsViewController {

    private func applySmartWebCSSTheme() {
        // 1. Nền Body cố định chuẩn CSS: linear-gradient(to right, #f3e0ff, #e0f7ff)
        let bgView = CSSGradientBackgroundView(frame: UIScreen.main.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.backgroundView = bgView
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none
        
        // 2. Tạo khối `.sleek-top-banner` trên cùng giống hệt mã Web & SourcesViewController
        setupCSSHeroBanner()
        
        // 3. Tạo `<footer>` chuẩn mã Web hiển thị Lời cảm ơn + Phiên bản
        setupVersionTableFooterView()
        
        // 4. Cấu hình TabBar đồng bộ màu
        #if !os(tvOS)
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = CSSTheme.blue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif
        
        // 5. Làm đẹp các công tắc UISwitch
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

    // Tạo khối `.sleek-top-banner` chuẩn 100% mã Web và SourcesViewController
    private func setupCSSHeroBanner() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 102))
        headerContainer.backgroundColor = .clear

        sleekBannerView.translatesAutoresizingMaskIntoConstraints = false
        sleekBannerView.configure(
            title: "Cài Đặt & Hệ Thống",
            subtitle: "Tùy chỉnh & quản lý trải nghiệm cài đặt ứng dụng của bạn",
            customIcon: loadSideStoreAppIcon()
        )

        headerContainer.addSubview(sleekBannerView)
        NSLayoutConstraint.activate([
            sleekBannerView.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 4),
            sleekBannerView.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -4),
            sleekBannerView.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            sleekBannerView.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4)
        ])

        sleekBannerView.alpha = 0
        UIView.animate(withDuration: 0.45) {
            self.sleekBannerView.alpha = 1
        }

        self.tableView.tableHeaderView = headerContainer
    }

    private func createCompactCreditChip(title: String, iconName: String, color: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        let config = UIImage.SymbolConfiguration(pointSize: 10.0, weight: .bold)
        let icon = UIImage(systemName: iconName, withConfiguration: config)
        btn.setImage(icon, for: .normal)
        btn.setTitle("  \(title)  ", for: .normal)
        btn.tintColor = color
        btn.setTitleColor(color, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 11.0, weight: .heavy)
        // Chuẩn `.tab-pill` trong mã Web: background: var(--light); border: 1px solid var(--border); border-radius: 7px
        btn.backgroundColor = CSSTheme.light
        btn.layer.cornerRadius = 7
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = CSSTheme.border.cgColor
        btn.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            btn.heightAnchor.constraint(equalToConstant: 24)
        ])
        return btn
    }

    // Chân trang chuẩn `<footer>` của mã Web (max-width: 99%, background: #fff, border-radius: 15px)
    private func setupVersionTableFooterView() {
        let footerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 190))
        footerContainer.backgroundColor = .clear

        let footerCard = UIView()
        footerCard.translatesAutoresizingMaskIntoConstraints = false
        CSSTheme.applyContainerCardStyle(to: footerCard, cornerRadius: CSSTheme.cornerRadius)

        let bodyLabel = UILabel()
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        bodyLabel.numberOfLines = 0
        bodyLabel.textAlignment = .center

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 3.5

        let bodyText = "Tri ân đội ngũ phát triển SideStore Team (@sidestoreio) • Giao diện: @lit_ritt\nNền tảng AltStore: Riley Testut & Cộng đồng mã nguồn mở"
        bodyLabel.attributedText = NSAttributedString(
            string: bodyText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12.5, weight: .semibold),
                .foregroundColor: CSSTheme.dark,
                .paragraphStyle: paragraph
            ]
        )

        let btnSideStore = createCompactCreditChip(title: "@sidestoreio", iconName: "sparkles", color: CSSTheme.magenta, action: #selector(openSideStoreTwitterChip))
        let btnLitRitt = createCompactCreditChip(title: "@lit_ritt", iconName: "paintbrush.fill", color: CSSTheme.purple, action: #selector(openLitRittTwitterChip))
        let btnGitHub = createCompactCreditChip(title: "GitHub", iconName: "chevron.left.forwardslash.chevron.right", color: CSSTheme.blue, action: #selector(followAltStoreGitHub))

        let chipStack = UIStackView(arrangedSubviews: [btnSideStore, btnLitRitt, btnGitHub])
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipStack.axis = .horizontal
        chipStack.spacing = 6
        chipStack.alignment = .center

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = CSSTheme.border

        let vLabel = UILabel()
        vLabel.tag = 7771
        vLabel.translatesAutoresizingMaskIntoConstraints = false
        vLabel.attributedText = getVersionAttributedString()
        vLabel.numberOfLines = 0
        vLabel.textAlignment = .center
        vLabel.isUserInteractionEnabled = true
        vLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyVersionLabelTapped)))

        footerCard.addSubview(bodyLabel)
        footerCard.addSubview(chipStack)
        footerCard.addSubview(separator)
        footerCard.addSubview(vLabel)
        footerContainer.addSubview(footerCard)

        NSLayoutConstraint.activate([
            footerCard.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 16),
            footerCard.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 4),
            footerCard.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -4),
            footerCard.bottomAnchor.constraint(equalTo: footerContainer.bottomAnchor, constant: -4),

            bodyLabel.topAnchor.constraint(equalTo: footerCard.topAnchor, constant: 16),
            bodyLabel.leadingAnchor.constraint(equalTo: footerCard.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: footerCard.trailingAnchor, constant: -14),

            chipStack.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 10),
            chipStack.centerXAnchor.constraint(equalTo: footerCard.centerXAnchor),

            separator.topAnchor.constraint(equalTo: chipStack.bottomAnchor, constant: 12),
            separator.leadingAnchor.constraint(equalTo: footerCard.leadingAnchor, constant: 18),
            separator.trailingAnchor.constraint(equalTo: footerCard.trailingAnchor, constant: -18),
            separator.heightAnchor.constraint(equalToConstant: 1.0),

            vLabel.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            vLabel.leadingAnchor.constraint(equalTo: footerCard.leadingAnchor, constant: 14),
            vLabel.trailingAnchor.constraint(equalTo: footerCard.trailingAnchor, constant: -14),
            vLabel.bottomAnchor.constraint(lessThanOrEqualTo: footerCard.bottomAnchor, constant: -14)
        ])

        self.tableView.tableFooterView = footerContainer
    }

    @objc private func openSideStoreTwitterChip() {
        self.openTwitter(username: "sidestoreio")
    }

    @objc private func openLitRittTwitterChip() {
        self.openTwitter(username: "lit_ritt")
    }

    // Xác định cấu hình Icon (SF Symbol + Màu sắc luân phiên chuẩn data-tab="1..4" + Chevron) cho từng dòng
    private func iconSpecForRow(section: Section, row: Int) -> (symbol: String, color: UIColor, showChevron: Bool)? {
        switch section {
        case .signIn:
            return ("applelogo", CSSTheme.blue, true)
        case .account:
            switch row {
            case 0: return ("person.fill", CSSTheme.magenta, false)
            case 1: return ("envelope.fill", CSSTheme.purple, false)
            case 2: return ("checkmark.seal.fill", CSSTheme.blue, false)
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

    // Vẽ biểu tượng ô vuông đặc bo góc chuẩn `.tab-num-badge` (nền màu đặc, icon trắng sắc nét)
    private func renderInlineBadgeImage(symbol: String, color: UIColor) -> UIImage {
        let key = "\(symbol)_\(color.description)"
        if let cached = Self.inlineBadgeImageCache[key] {
            return cached
        }
        let size = CGSize(width: 32, height: 32)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size)
            let bgPath = UIBezierPath(roundedRect: rect, cornerRadius: 9.0)
            color.setFill()
            bgPath.fill()

            let config = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)
            if let symImg = UIImage(systemName: symbol, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
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

    // Gắn mũi tên điều hướng > cách lề phải của khung `.tab-button` (targetCardView) 16pt
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
        let chevConfig = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .heavy)
        chevronView.image = UIImage(systemName: "chevron.right", withConfiguration: chevConfig)
        chevronView.tintColor = spec.color
        cell.contentView.addSubview(chevronView)

        NSLayoutConstraint.activate([
            chevronView.trailingAnchor.constraint(equalTo: targetCardView.trailingAnchor, constant: -16),
            chevronView.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor)
        ])
    }

    // Tìm chính xác khung Card bên trong InsetGroupTableViewCell
    private func resolveTargetCardView(for cell: UITableViewCell) -> UIView {
        if let cardView = cell.subviews.first(where: {
            $0 !== cell.contentView &&
            $0 !== cell.selectedBackgroundView &&
            $0 !== cell.backgroundView &&
            $0.tag != 8880 &&
            !($0 is UIControl)
        }) {
            return cardView
        }
        return cell.contentView
    }

    // Tạo lát cắt nền trắng bao ngoài (`.tab-container` trong mã Web & `outerContainerSlice` trong SourcesViewController)
    private func ensureOuterContainerSlice(for cell: UITableViewCell, isFirst: Bool, isLast: Bool) {
        let sliceTag = 8880
        let sliceView: UIView
        if let existing = cell.subviews.first(where: { $0.tag == sliceTag }) {
            sliceView = existing
        } else {
            let v = UIView()
            v.tag = sliceTag
            v.translatesAutoresizingMaskIntoConstraints = false
            v.isUserInteractionEnabled = false
            v.backgroundColor = CSSTheme.white
            v.layer.shadowColor = UIColor.black.cgColor
            v.layer.shadowOffset = CGSize(width: 0, height: 6)
            v.layer.shadowRadius = 14
            v.layer.shadowOpacity = 0.06
            cell.insertSubview(v, at: 0)
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                v.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                v.topAnchor.constraint(equalTo: cell.topAnchor),
                v.bottomAnchor.constraint(equalTo: cell.bottomAnchor)
            ])
            sliceView = v
        }

        sliceView.backgroundColor = CSSTheme.white
        if #available(iOS 13.0, tvOS 13.0, *) {
            sliceView.layer.cornerCurve = .continuous
        }

        if isFirst && isLast {
            sliceView.layer.cornerRadius = CSSTheme.cornerRadius
            sliceView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        } else if isFirst {
            sliceView.layer.cornerRadius = CSSTheme.cornerRadius
            sliceView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if isLast {
            sliceView.layer.cornerRadius = CSSTheme.cornerRadius
            sliceView.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else {
            sliceView.layer.cornerRadius = 0
        }
    }

    // Xóa sạch mọi màu nền xám/khác màu của các view trung gian trong Storyboard
    private func clearIntermediateBackgrounds(in view: UIView, keeping targetCardView: UIView) {
        for sub in view.subviews {
            if sub === targetCardView || sub is UIButton || sub is UISwitch || sub.tag == 8880 || sub.tag == 8888 || sub.tag == 8889 || sub.tag == 8890 {
                continue
            }
            sub.backgroundColor = .clear
            clearIntermediateBackgrounds(in: sub, keeping: targetCardView)
        }
    }

    // Đảm bảo các dòng Tài khoản (0, 1, 2) luôn giữ đúng nền trắng tinh #FFFFFF và viền chuẩn CSS
    private func enforceUniformWhiteBackgroundOnAccountRows() {
        guard self.isViewLoaded else { return }
        for row in 0..<3 {
            let indexPath = IndexPath(row: row, section: Section.account.rawValue)
            guard let cell = self.tableView.cellForRow(at: indexPath) else { continue }
            self.styleInnerCardOfCell(cell, at: indexPath, totalRows: 3)
        }
    }

    // Biến mỗi dòng thành một thẻ `.tab-button` nằm gọn bên trong khung trắng `.tab-container` giống hệt mã Web & SourcesViewController
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
        
        let section = Section.allCases[indexPath.section]
        let effectiveTotalRows = (section == .account) ? 3 : totalRows
        let isFirst = (indexPath.row == 0)
        let isLast = (indexPath.row == effectiveTotalRows - 1)

        // 1. Tạo khung bao trắng `.tab-container` bên ngoài
        ensureOuterContainerSlice(for: cell, isFirst: isFirst, isLast: isLast)

        // 2. Tạo thẻ `.tab-button` bên trong: Viền 4 cạnh bằng nhau (2px solid #e9ecef) + Đổ bóng màu luân phiên
        let targetCardView = resolveTargetCardView(for: cell)
        targetCardView.overrideUserInterfaceStyle = .light
        clearIntermediateBackgrounds(in: cell.contentView, keeping: targetCardView)

        let accentColor = iconSpecForRow(section: section, row: indexPath.row)?.color
            ?? CSSTheme.tabAccentColor(for: indexPath.row)

        CSSTheme.applyColoredGlowCardStyle(
            to: targetCardView,
            accentColor: accentColor,
            cornerRadius: CSSTheme.cornerRadius,
            shadowOpacity: 0.22
        )
        targetCardView.layer.maskedCorners = [
            .layerMinXMinYCorner, .layerMaxXMinYCorner,
            .layerMinXMaxYCorner, .layerMaxXMaxYCorner
        ]
        targetCardView.layer.masksToBounds = false

        // Tạo khoảng cách giữa các thẻ `.tab-button` bên trong `.tab-container`
        let topPad: CGFloat = isFirst ? 10.0 : 5.0
        let bottomPad: CGFloat = isLast ? 10.0 : 5.0
        let cardInsetFrame = cell.bounds.inset(by: UIEdgeInsets(top: topPad, left: 11, bottom: bottomPad, right: 11))
        if cardInsetFrame.width > 0 && cardInsetFrame.height > 0 && targetCardView !== cell.contentView {
            targetCardView.frame = cardInsetFrame
        }

        cell.layer.masksToBounds = (section == .account && indexPath.row < 3 && !self.isAccountDetailsExpanded)
        cell.layer.shadowOpacity = 0.0
        
        // 3. Gắn nút > nằm gọn bên trong thẻ `.tab-button`
        self.attachChevronInsideCard(cell: cell, targetCardView: targetCardView, section: section, row: indexPath.row)
        
        // Không cần vạch kẻ cũ vì mỗi dòng đã là một thẻ `.tab-button` có viền 2px độc lập
        cell.contentView.viewWithTag(8888)?.removeFromSuperview()
        
        // 4. Việt hóa và nhúng Icon `.tab-num-badge` trực tiếp vào Label bên trong Cell
        translateAndStyleLabelsInside(view: cell.contentView, section: section, row: indexPath.row)
    }

    // Khôi phục ngay lập tức giao diện chuẩn CSS cho tất cả các Cell đang hiển thị
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
                    // 2. Nhóm Label tiêu đề bên trái (`.tab-card-title` chuẩn CSS: 15.8px, bold, #000)
                    let rawText = label.attributedText?.string ?? label.text ?? ""
                    let cleanText = translateStaticText(rawText)
                    guard !cleanText.isEmpty else { continue }

                    let font: UIFont = UIFont.systemFont(ofSize: 15.5, weight: .bold)
                    let textColor: UIColor

                    if section == .signIn {
                        textColor = CSSTheme.blue
                    } else if isClearCacheRow {
                        textColor = CSSTheme.pureBlack
                    } else {
                        textColor = CSSTheme.pureBlack
                    }

                    label.textAlignment = .left

                    // Gắn Icon 32x32 chuẩn `.tab-num-badge` trực tiếp vào đầu Label
                    if let spec = rowIconSpec {
                        let badgeImg = renderInlineBadgeImage(symbol: spec.symbol, color: spec.color)
                        let attachment = NSTextAttachment()
                        attachment.image = badgeImg
                        let yOffset = (font.capHeight - 32.0) / 2.0
                        attachment.bounds = CGRect(x: 0, y: yOffset, width: 32, height: 32)

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
        paragraphStyle.lineSpacing = 3
        
        let fullString = NSMutableAttributedString()
        
        let appVersionAttr = NSAttributedString(
            string: "✦ " + appVersion,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13.0, weight: .heavy),
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
                .font: UIFont.systemFont(ofSize: 13.5, weight: .heavy),
                .foregroundColor: CSSTheme.blue,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributed.append(NSAttributedString(string: "✓", attributes: [
            .font: UIFont.systemFont(ofSize: 13.5, weight: .heavy),
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
                cell.style = .single
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

    // Tạo tiêu đề Section chuẩn `.features h2` trong mã Web (Chữ xanh #007bff, in hoa, đậm, căn giữa)
    private func setSectionHeaderTitle(_ label: UILabel, title: String) {
        label.attributedText = nil
        label.text = title.uppercased()
        label.font = UIFont.systemFont(ofSize: 18.5, weight: .heavy)
        label.textColor = CSSTheme.blue
        label.textAlignment = .center
    }

    private func prepare(_ settingsHeaderFooterView: SettingsHeaderFooterView, for section: Section, isHeader: Bool)
    {
        settingsHeaderFooterView.primaryLabel.isHidden = !isHeader
        settingsHeaderFooterView.secondaryLabel.isHidden = isHeader
        settingsHeaderFooterView.button.isHidden = true
        
        settingsHeaderFooterView.primaryLabel.textColor = CSSTheme.blue
        settingsHeaderFooterView.primaryLabel.font = UIFont.systemFont(ofSize: 18.5, weight: .heavy)
        settingsHeaderFooterView.primaryLabel.textAlignment = .center

        settingsHeaderFooterView.secondaryLabel.textColor = CSSTheme.dark
        settingsHeaderFooterView.secondaryLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        settingsHeaderFooterView.secondaryLabel.textAlignment = .center
        
        let toggleAccountTag = 9992
        settingsHeaderFooterView.contentView.viewWithTag(toggleAccountTag)?.removeFromSuperview()
        
        let underlineTag = 9991
        settingsHeaderFooterView.contentView.viewWithTag(underlineTag)?.removeFromSuperview()
        if isHeader {
            let underline = CSSCenteredUnderlineView()
            underline.tag = underlineTag
            underline.translatesAutoresizingMaskIntoConstraints = false
            settingsHeaderFooterView.contentView.addSubview(underline)
            if section == .account {
                NSLayoutConstraint.activate([
                    underline.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.leadingAnchor),
                    underline.topAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.bottomAnchor, constant: 5),
                    underline.widthAnchor.constraint(equalToConstant: 60),
                    underline.heightAnchor.constraint(equalToConstant: 3.0)
                ])
            } else {
                // Căn chính giữa chuẩn `.features h2::after` (width: 60px, height: 3px, left: 50%)
                NSLayoutConstraint.activate([
                    underline.centerXAnchor.constraint(equalTo: settingsHeaderFooterView.contentView.centerXAnchor),
                    underline.topAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.bottomAnchor, constant: 6),
                    underline.widthAnchor.constraint(equalToConstant: 60),
                    underline.heightAnchor.constraint(equalToConstant: 3.0)
                ])
            }
        }
        
        settingsHeaderFooterView.layoutMargins.bottom = isHeader ? 12 : 8
        
        switch section
        {
        case .signIn:
            if isHeader {
                setSectionHeaderTitle(settingsHeaderFooterView.primaryLabel, title: "TÀI KHOẢN APPLE ID")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = "Đăng nhập bằng ID Apple của bạn để tải xuống và làm mới ứng dụng từ SideStore."
            }
            
        case .account:
            settingsHeaderFooterView.primaryLabel.text = "TÀI KHOẢN"
            settingsHeaderFooterView.primaryLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .heavy)
            settingsHeaderFooterView.primaryLabel.textAlignment = .left
            
            let toggleBtn = UIButton(type: .system)
            toggleBtn.tag = toggleAccountTag
            toggleBtn.translatesAutoresizingMaskIntoConstraints = false
            let toggleTitle = self.isAccountDetailsExpanded ? "  ✦ ẨN ▲  " : "  ✦ HIỆN ▼  "
            toggleBtn.setTitle(toggleTitle, for: .normal)
            toggleBtn.setTitleColor(CSSTheme.white, for: .normal)
            toggleBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
            toggleBtn.backgroundColor = CSSTheme.blue
            toggleBtn.layer.cornerRadius = 10
            toggleBtn.layer.borderWidth = 1.5
            toggleBtn.layer.borderColor = CSSTheme.badgeGreenBorder.cgColor
            toggleBtn.layer.shadowColor = CSSTheme.blue.cgColor
            toggleBtn.layer.shadowOffset = CGSize(width: 0, height: 4)
            toggleBtn.layer.shadowRadius = 8
            toggleBtn.layer.shadowOpacity = 0.22
            toggleBtn.addTarget(self, action: #selector(toggleAccountDetailsVisibility(_:)), for: .touchUpInside)
            
            settingsHeaderFooterView.contentView.addSubview(toggleBtn)
            
            let signOutBtn = settingsHeaderFooterView.button!
            signOutBtn.removeTarget(nil, action: nil, for: .allEvents)
            signOutBtn.setTitle("  ĐĂNG XUẤT  ", for: .normal)
            signOutBtn.setTitleColor(CSSTheme.white, for: .normal)
            signOutBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
            signOutBtn.backgroundColor = CSSTheme.purple
            signOutBtn.layer.cornerRadius = 10
            signOutBtn.layer.shadowColor = CSSTheme.purple.cgColor
            signOutBtn.layer.shadowOffset = CGSize(width: 0, height: 4)
            signOutBtn.layer.shadowRadius = 8
            signOutBtn.layer.shadowOpacity = 0.25
            signOutBtn.addTarget(self, action: #selector(SettingsViewController.signOut(_:)), for: .primaryActionTriggered)
            signOutBtn.isHidden = false
            
            NSLayoutConstraint.activate([
                toggleBtn.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.trailingAnchor, constant: 10),
                toggleBtn.centerYAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.centerYAnchor),
                toggleBtn.heightAnchor.constraint(equalToConstant: 26)
            ])
            
        case .advancedSettings:
            if isHeader {
                setSectionHeaderTitle(settingsHeaderFooterView.primaryLabel, title: "TỔNG HỢP CÁC DANH MỤC")
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
            return max(40, size.height + 6)
        }
        return size.height + (isHeader ? 12 : 4)
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
                let isEdge = (indexPath.row == 0 || indexPath.row == 2)
                return isEdge ? 66.0 : 58.0
            }
            if indexPath.row == 3 {
                return AccountVerificationRow.preferredHeight
            }
        }
        
        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { return 0.0 }
            let isEdge = (indexPath.row == 0 || indexPath.row == activeItems.count - 1)
            return isEdge ? 72.0 : 64.0
        }
        
        return 72.0
    }

    // ✨ CAN THIỆP SÂU VÀO TỪNG CELL ĐỂ ÁP DỤNG KHUNG `.tab-container` + THẺ `.tab-button` ✨
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        let totalRows = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
        
        if section == .account {
            if indexPath.row < 3 {
                cell.clipsToBounds = !self.isAccountDetailsExpanded
                cell.isHidden = !self.isAccountDetailsExpanded
                cell.alpha = self.isAccountDetailsExpanded ? 1.0 : 0.0
            }
            
            if let insetCell = cell as? InsetGroupTableViewCell {
                insetCell.style = .single
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
        
        // Ép lại style ở chu kỳ RunLoop tiếp theo để thắng tuyệt đối hàm layoutSubviews() của InsetGroupTableViewCell
        DispatchQueue.main.async { [weak self, weak cell] in
            guard let self = self, let cell = cell else { return }
            self.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
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
        
        if let insetCell = cell as? InsetGroupTableViewCell {
            // Đặt `.single` để mọi mục đều bo tròn 4 góc như `.tab-button` trong mã Web
            insetCell.style = .single
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
                cell.transform = CGAffineTransform(translationX: 0, y: -2).scaledBy(x: 0.985, y: 0.985)
            }) { [weak self] _ in
                self?.restoreVisibleCellsWhiteBackground()
                UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
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
