
//
//  ThemeManager.swift
//  SideStore
//
//  Created by Magesh K on 9/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

// MARK: - 1. CẤU HÌNH MÀU SẮC, BÓNG ĐỔ & BỐ CỤC TỪ CSS (:root)
public struct AppUI {
    
    // Bảng màu cho UIKit
    public struct Colors {
        public static let white = UIColor(hex: "#FFFFFF")!
        public static let light = UIColor(hex: "#F8F9FA")!
        public static let border = UIColor(hex: "#E9ECEF")!
        public static let blue = UIColor(hex: "#007BFF")!
        public static let blueHover = UIColor(hex: "#0056B3")!
        public static let purple = UIColor(hex: "#6F42C1")!
        public static let green = UIColor(hex: "#28A745")!
        public static let magenta = UIColor(hex: "#FF00FF")! // #f0f trong CSS
        public static let red = UIColor(hex: "#DC3545")!
        public static let orange = UIColor(hex: "#FD7E14")!
        public static let dark = UIColor(hex: "#343A40")!
        public static let gray = UIColor(hex: "#6C757D")!
        
        // Màu nền Gradient của body: linear-gradient(to right, #f3e0ff, #e0f7ff)
        public static let bgGradientStart = UIColor(hex: "#F3E0FF")!
        public static let bgGradientEnd = UIColor(hex: "#E0F7FF")!
    }
    
    // Bảng màu đồng bộ cho SwiftUI
    public struct SwiftUIColors {
        public static let white = Color(uiColor: Colors.white)
        public static let light = Color(uiColor: Colors.light)
        public static let border = Color(uiColor: Colors.border)
        public static let blue = Color(uiColor: Colors.blue)
        public static let purple = Color(uiColor: Colors.purple)
        public static let green = Color(uiColor: Colors.green)
        public static let magenta = Color(uiColor: Colors.magenta)
        public static let red = Color(uiColor: Colors.red)
        public static let orange = Color(uiColor: Colors.orange)
        public static let dark = Color(uiColor: Colors.dark)
        public static let gray = Color(uiColor: Colors.gray)
        public static let subtitle = Color(uiColor: Colors.dark).opacity(0.68)
        
        // Nền Gradient chuẩn CSS body
        public static let bodyGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(uiColor: Colors.bgGradientStart),
                Color(uiColor: Colors.bgGradientEnd)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // Thông số kích thước và đổ bóng (--radius: 15px, --shadow: 0 8px 20px rgba(0,0,0,.1))
    public struct Layout {
        public static let radius: CGFloat = 15.0
        public static let smallRadius: CGFloat = 10.0
        public static let shadowColor: CGColor = UIColor.black.cgColor
        public static let shadowOpacity: Float = 0.10
        public static let shadowOffset: CGSize = CGSize(width: 0, height: 8)
        public static let shadowRadius: CGFloat = 10.0
    }
    
    // Các kiểu màu nút bấm giống trong CSS (.btn-color-1, 2, 3, 4 & #tab-content-4 .btn)
    public enum ButtonStyleType {
        case primaryBlue      // --blue (#007bff)
        case neonMagenta      // #f0f
        case purple           // --purple (#6f42c1)
        case green            // --green (#28a745)
        case destructiveRed   // Nút xóa/cảnh báo
        case warningOrange    // Nút tạm dừng/cảnh báo nhẹ
        case outlineBlue      // Nút viền trắng chữ xanh (#tab-content-4 .btn)
        case outlineMagenta   // Nút viền trắng chữ tím hồng
        
        public var mainColor: UIColor {
            switch self {
            case .primaryBlue, .outlineBlue: return Colors.blue
            case .neonMagenta, .outlineMagenta: return Colors.magenta
            case .purple: return Colors.purple
            case .green: return Colors.green
            case .destructiveRed: return Colors.red
            case .warningOrange: return Colors.orange
            }
        }
        
        public var swiftUIColor: Color {
            Color(uiColor: mainColor)
        }
        
        public var isOutline: Bool {
            switch self {
            case .outlineBlue, .outlineMagenta: return true
            default: return false
            }
        }
    }
}

// MARK: - 2. HỆ THỐNG GIAO DIỆN DÙNG CHUNG CHO UIKIT
public extension UIView {
    
    /// Áp dụng nền Gradient Tím-Xanh giống thẻ `body` trong CSS
    func applyCSSBodyGradient() {
        let gradientLayer: CAGradientLayer
        if let existing = self.layer.sublayers?.first(where: { $0.name == "AppBodyGradient" }) as? CAGradientLayer {
            gradientLayer = existing
        } else {
            gradientLayer = CAGradientLayer()
            gradientLayer.name = "AppBodyGradient"
            self.layer.insertSublayer(gradientLayer, at: 0)
        }
        
        gradientLayer.frame = self.bounds
        gradientLayer.colors = [AppUI.Colors.bgGradientStart.cgColor, AppUI.Colors.bgGradientEnd.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
    
    func applyBodyGradientBackground() {
        applyCSSBodyGradient()
    }
    
    /// Cập nhật kích thước nền Gradient khi xoay màn hình hoặc thay đổi layout
    func updateCSSBodyGradientFrame() {
        guard let gradientLayer = self.layer.sublayers?.first(where: { $0.name == "AppBodyGradient" }) as? CAGradientLayer else {
            applyCSSBodyGradient()
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = self.bounds
        CATransaction.commit()
    }
    
    /// Áp dụng khung Thẻ Trắng giống `.site-header` và `.tab-container` trong CSS
    func applyCSSCardStyle(cornerRadius: CGFloat = AppUI.Layout.radius) {
        self.backgroundColor = AppUI.Colors.white
        self.layer.cornerRadius = cornerRadius
        self.layer.borderWidth = 1.0
        self.layer.borderColor = AppUI.Colors.border.withAlphaComponent(0.8).cgColor
        self.layer.shadowColor = AppUI.Layout.shadowColor
        self.layer.shadowOpacity = AppUI.Layout.shadowOpacity
        self.layer.shadowOffset = AppUI.Layout.shadowOffset
        self.layer.shadowRadius = AppUI.Layout.shadowRadius
        self.layer.masksToBounds = false
    }
    
    func applyCardStyle() {
        applyCSSCardStyle()
    }
    
    /// Áp dụng bo góc và đổ bóng chuẩn CSS cho các Banner App / Source Cell
    func applyCSSBannerShadow() {
        self.layer.cornerRadius = AppUI.Layout.radius
        self.layer.shadowColor = AppUI.Layout.shadowColor
        self.layer.shadowOpacity = AppUI.Layout.shadowOpacity
        self.layer.shadowOffset = AppUI.Layout.shadowOffset
        self.layer.shadowRadius = AppUI.Layout.shadowRadius
        self.layer.masksToBounds = false
    }
    
    /// Áp dụng hiệu ứng Kính mờ + Bóng tím hồng giống thẻ `nav` trong CSS
    func applyGlassNavStyle() {
        self.backgroundColor = AppUI.Colors.white.withAlphaComponent(0.75)
        self.layer.cornerRadius = AppUI.Layout.radius
        self.layer.borderWidth = 1.0
        self.layer.borderColor = AppUI.Colors.white.withAlphaComponent(0.6).cgColor
        
        if !self.subviews.contains(where: { $0.restorationIdentifier == "CSSGlassBlurView" }) {
            let blurEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
            let blurView = UIVisualEffectView(effect: blurEffect)
            blurView.restorationIdentifier = "CSSGlassBlurView"
            blurView.frame = self.bounds
            blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            blurView.layer.cornerRadius = AppUI.Layout.radius
            blurView.clipsToBounds = true
            blurView.isUserInteractionEnabled = false
            self.insertSubview(blurView, at: 0)
        }
        
        self.layer.shadowColor = AppUI.Colors.magenta.cgColor
        self.layer.shadowOpacity = 0.25
        self.layer.shadowOffset = CGSize(width: 0, height: 10)
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
    }
}

public extension UIButton {
    /// Biến nút bấm thường thành nút bấm CSS có đổ bóng màu Neon và hiệu ứng nhún (.btn)
    func applyCSSButton(
        title: String? = nil,
        style: AppUI.ButtonStyleType = .primaryBlue,
        fontSize: CGFloat = 16,
        contentInsets: NSDirectionalEdgeInsets? = nil
    ) {
        let finalTitle = title ?? self.title(for: .normal) ?? ""
        var config = UIButton.Configuration.filled()
        config.title = finalTitle
        config.baseBackgroundColor = style.isOutline ? AppUI.Colors.white : style.mainColor
        config.baseForegroundColor = style.isOutline ? style.mainColor : AppUI.Colors.white
        config.cornerStyle = .fixed
        config.background.cornerRadius = AppUI.Layout.radius
        if style.isOutline {
            config.background.strokeWidth = 2.0
            config.background.strokeColor = AppUI.Colors.border
        }
        if let contentInsets {
            config.contentInsets = contentInsets
        } else {
            config.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20)
        }
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: fontSize, weight: .bold)
            return outgoing
        }
        self.configuration = config
        
        // Đổ bóng theo màu của nút (--tab-shadow)
        self.layer.cornerRadius = AppUI.Layout.radius
        self.layer.shadowColor = style.mainColor.cgColor
        self.layer.shadowOpacity = 0.28
        self.layer.shadowOffset = CGSize(width: 0, height: 8)
        self.layer.shadowRadius = 10
        self.layer.masksToBounds = false
        
        self.removeTarget(self, action: #selector(animateCSSTouchDown), for: [.touchDown, .touchDragEnter])
        self.removeTarget(self, action: #selector(animateCSSTouchUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
        self.addTarget(self, action: #selector(animateCSSTouchDown), for: [.touchDown, .touchDragEnter])
        self.addTarget(self, action: #selector(animateCSSTouchUp), for: [.touchUpInside, .touchCancel, .touchDragExit])
    }
    
    /// Làm đẹp các nút Icon mạng xã hội (Mastodon, Twitter, GitHub...) ở chân trang Settings
    func applyCSSSocialIconStyle() {
        let image = self.configuration?.background.image ?? self.image(for: .normal)
        self.configuration = nil
        self.setImage(image, for: .normal)
        self.imageView?.contentMode = .scaleAspectFit
        self.tintColor = AppUI.Colors.blue
        self.backgroundColor = AppUI.Colors.white
        self.layer.cornerRadius = 12
        self.layer.borderWidth = 1
        self.layer.borderColor = AppUI.Colors.border.cgColor
        self.layer.shadowColor = AppUI.Colors.blue.cgColor
        self.layer.shadowOpacity = 0.15
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 6
        self.layer.masksToBounds = false
    }
    
    @objc private func animateCSSTouchDown() {
        UIView.animate(withDuration: 0.12) {
            self.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }
    
    @objc private func animateCSSTouchUp() {
        UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 3, options: .allowUserInteraction) {
            self.transform = .identity
        }
    }
}

public extension UITableViewCell {
    /// Đồng bộ giao diện cho các dòng trong bảng Settings
    func applyCSSTableCellStyle() {
        self.backgroundColor = AppUI.Colors.white
        self.textLabel?.textColor = AppUI.Colors.dark
        self.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        self.detailTextLabel?.textColor = AppUI.Colors.blue
        self.detailTextLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        self.tintColor = AppUI.Colors.blue
        
        let selectedBg = UIView()
        selectedBg.backgroundColor = AppUI.Colors.blue.withAlphaComponent(0.08)
        self.selectedBackgroundView = selectedBg
    }
}

public extension UIViewController {
    /// Đồng bộ thanh Navigation Bar kính mờ giống `.site-header` cho mọi ViewController
    func applyCSSNavigationBar(tintColor: UIColor = AppUI.Colors.blue, transparentEdge: Bool = true) {
        #if !os(tvOS)
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithDefaultBackground()
        standardAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        standardAppearance.backgroundColor = AppUI.Colors.white.withAlphaComponent(0.88)
        standardAppearance.shadowColor = AppUI.Colors.border
        standardAppearance.titleTextAttributes = [
            .foregroundColor: AppUI.Colors.dark,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        standardAppearance.largeTitleTextAttributes = [
            .foregroundColor: tintColor,
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy)
        ]
        
        let scrollEdgeAppearance = standardAppearance.copy()
        if transparentEdge {
            scrollEdgeAppearance.configureWithTransparentBackground()
            scrollEdgeAppearance.backgroundColor = .clear
            scrollEdgeAppearance.shadowColor = .clear
        }
        
        self.navigationItem.standardAppearance = standardAppearance
        self.navigationItem.scrollEdgeAppearance = scrollEdgeAppearance
        self.navigationController?.navigationBar.standardAppearance = standardAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        self.navigationController?.navigationBar.tintColor = tintColor
        #endif
    }
}

public extension UILabel {
    /// Tiêu đề màu xanh giống `.features h2` trong CSS
    func applySectionTitle(text: String) {
        self.text = text
        self.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        self.textColor = AppUI.Colors.blue
        self.textAlignment = .center
    }
    
    /// Định dạng chuỗi hiển thị Phiên bản ở cuối màn hình Settings
    static func makeCSSVersionAttributedString(appVersion: String, iosVersion: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = 4

        let str = NSMutableAttributedString(string: appVersion, attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: AppUI.Colors.blue,
            .paragraphStyle: style
        ])
        str.append(NSAttributedString(string: "\n" + iosVersion, attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: AppUI.Colors.dark.withAlphaComponent(0.65),
            .paragraphStyle: style
        ]))
        return str
    }
    
    /// Định dạng hiệu ứng khi chạm copy phiên bản
    static func makeCSSCopiedAttributedString(copiedText: String) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        let attr = NSMutableAttributedString(string: "\(copiedText)! ", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: AppUI.Colors.blue,
            .paragraphStyle: style
        ])
        attr.append(NSAttributedString(string: "✓", attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .heavy),
            .foregroundColor: AppUI.Colors.green
        ]))
        return attr
    }
}

// MARK: - 3. HỆ THỐNG MODIFIER & COMPONENT DÙNG CHUNG CHO SWIFTUI
public struct CSSCardModifier: ViewModifier {
    public var cornerRadius: CGFloat = AppUI.Layout.radius
    public init(cornerRadius: CGFloat = AppUI.Layout.radius) {
        self.cornerRadius = cornerRadius
    }
    
    public func body(content: Content) -> some View {
        content
            .background(AppUI.SwiftUIColors.white)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppUI.SwiftUIColors.border.opacity(0.9), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 8)
    }
}

public extension View {
    /// Áp dụng khung thẻ trắng đổ bóng chuẩn CSS cho SwiftUI
    func cssCardStyle(padding: CGFloat? = nil, cornerRadius: CGFloat = AppUI.Layout.radius) -> some View {
        Group {
            if let padding {
                self.padding(padding).modifier(CSSCardModifier(cornerRadius: cornerRadius))
            } else {
                self.modifier(CSSCardModifier(cornerRadius: cornerRadius))
            }
        }
    }
    
    /// Áp dụng nền Gradient Tím-Xanh cho màn hình SwiftUI
    func cssBodyBackground() -> some View {
        self.background(AppUI.SwiftUIColors.bodyGradient.ignoresSafeArea())
    }
}

/// Khung Section Card có Icon + Tiêu đề xanh + Gạch chân `.features h2::after` chuẩn CSS
public struct CSSSectionCard<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content
    
    public init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppUI.SwiftUIColors.blue)
                    }
                    Text(title)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(AppUI.SwiftUIColors.blue)
                    Spacer()
                }
                // Đường gạch chân trang trí lấy cảm hứng từ .features h2::after trong CSS
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppUI.SwiftUIColors.blue, AppUI.SwiftUIColors.purple.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 48, height: 3)
            }
            Divider().overlay(AppUI.SwiftUIColors.border)
            content
        }
        .padding(16)
        .modifier(CSSCardModifier())
    }
}

/// Hộp chứa Icon bo góc mềm với nền pha màu trong suốt
public struct CSSIconBox: View {
    let icon: String
    let color: Color
    let size: CGFloat
    
    public init(_ icon: String, color: Color = AppUI.SwiftUIColors.blue, size: CGFloat = 38) {
        self.icon = icon
        self.color = color
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: size, height: size)
            Image(systemName: icon)
                .font(.system(size: size * 0.47, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

/// Nút bấm SwiftUI chuẩn CSS (.btn & .tab-button.active) có Gradient, bóng đổ màu và hiệu ứng nhún
public struct CSSActionButton: View {
    let icon: String?
    let title: String
    let style: AppUI.ButtonStyleType
    let action: () -> Void
    
    public init(icon: String? = nil, title: String, style: AppUI.ButtonStyleType = .primaryBlue, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.style = style
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(style.isOutline ? style.swiftUIColor : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .padding(.horizontal, 12)
            .background(
                Group {
                    if style.isOutline {
                        AppUI.SwiftUIColors.white
                    } else {
                        LinearGradient(
                            colors: [style.swiftUIColor, style.swiftUIColor.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            )
            .cornerRadius(AppUI.Layout.radius)
            .overlay(
                RoundedRectangle(cornerRadius: AppUI.Layout.radius, style: .continuous)
                    .stroke(style.isOutline ? AppUI.SwiftUIColors.border : style.swiftUIColor.opacity(0.35), lineWidth: style.isOutline ? 2 : 1)
            )
            .shadow(color: style.swiftUIColor.opacity(0.28), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(CSSPressButtonStyle())
    }
}

/// Hiệu ứng nhún (.btn:active transform: scale(.98)) cho mọi Button trong SwiftUI
public struct CSSPressButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

/// Nút chuyển ngôn ngữ / Tab có hiệu ứng đổ bóng Tím Hồng giống `.lang-btn` và `.tab-button` trong CSS
public struct CSSLanguageSwitcher<T: Hashable>: View {
    let items: [T]
    let selected: T
    let titleProvider: (T) -> String
    let onSelect: (T) -> Void
    
    public init(items: [T], selected: T, titleProvider: @escaping (T) -> String, onSelect: @escaping (T) -> Void) {
        self.items = items
        self.selected = selected
        self.titleProvider = titleProvider
        self.onSelect = onSelect
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = (item == selected)
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        onSelect(item)
                    }
                } label: {
                    Text(titleProvider(item))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isSelected ? .white : AppUI.SwiftUIColors.blue)
                        .frame(width: 45, height: 32)
                        .background(isSelected ? AppUI.SwiftUIColors.blue : AppUI.SwiftUIColors.white)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.border, lineWidth: 1)
                        )
                        .shadow(
                            color: (isSelected ? AppUI.SwiftUIColors.blue : AppUI.SwiftUIColors.magenta).opacity(0.25),
                            radius: 8, x: 0, y: 5
                        )
                }
                .buttonStyle(CSSPressButtonStyle())
            }
        }
    }
}

/// Header trạng thái dùng chung cho các Sheet chi tiết (Pairing, VPN, Cellular, Anisette)
public struct CSSSheetStatusHeader: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    
    public init(icon: String, color: Color, title: String, subtitle: String) {
        self.icon = icon
        self.color = color
        self.title = title
        self.subtitle = subtitle
    }
    
    public var body: some View {
        HStack(spacing: 14) {
            CSSIconBox(icon, color: color, size: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppUI.SwiftUIColors.dark)
                Text(subtitle)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(AppUI.SwiftUIColors.subtitle)
            }
            Spacer()
        }
        .padding(16)
        .modifier(CSSCardModifier())
    }
}

// MARK: - 4. QUẢN LÝ THEME CỦA SIDESTORE (Tích hợp bộ màu CSS)
public struct ThemePreset: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let hex: String
    
    public var color: UIColor {
        UIColor(hex: hex) ?? AppUI.Colors.blue
    }
    
    public static let presets: [ThemePreset] = [
        ThemePreset(id: "cssBlue", name: "Modern Blue (Default)", hex: "#007BFF"),
        ThemePreset(id: "cssMagenta", name: "Neon Magenta", hex: "#FF00FF"),
        ThemePreset(id: "cssPurple", name: "Royal Purple", hex: "#6F42C1"),
        ThemePreset(id: "cssGreen", name: "Success Green", hex: "#28A745"),
        ThemePreset(id: "classic", name: "SideStore Teal", hex: "#19D3B5")
    ]
}

public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    public static let themeDidChangeNotification = Notification.Name("SideStoreThemeDidChangeNotification")

    private static let userDefaultsKey = "userCustomThemeHex"

    @Published public var primaryColor: UIColor {
        didSet {
            UserDefaults.standard.set(primaryColor.hexString, forKey: Self.userDefaultsKey)
            NotificationCenter.default.post(name: Self.themeDidChangeNotification, object: primaryColor)
            DispatchQueue.main.async {
                if let window = UIApplication.alt_shared?.alt_keyWindow {
                    window.tintColor = self.primaryColor
                }
            }
        }
    }

    private init() {
        if let hex = UserDefaults.standard.string(forKey: Self.userDefaultsKey),
           let color = UIColor(hex: hex) {
            self.primaryColor = color
        } else {
            self.primaryColor = AppUI.Colors.blue
        }
    }

    public func resetToDefault() {
        self.primaryColor = AppUI.Colors.blue
        UserDefaults.standard.removeObject(forKey: Self.userDefaultsKey)
    }
}

public extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.remove(at: hexSanitized.startIndex)
        }

        var rgbValue: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgbValue) else { return nil }

        let r, g, b, a: CGFloat
        if hexSanitized.count == 6 {
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgbValue & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgbValue & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgbValue & 0x000000FF) / 255.0
        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }
    
    var hexString: String {
        let components = self.rgbComponents
        return String(format: "#%02X%02X%02X", components.r, components.g, components.b)
    }

    var rgbComponents: (r: Int, g: Int, b: Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int(r * 255), Int(g * 255), Int(b * 255))
    }

    var hslComponents: (h: Int, s: Int, l: Int) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let maxVal = max(r, max(g, b)), minVal = min(r, min(g, b))
        let delta = maxVal - minVal
        var h: CGFloat = 0, s: CGFloat = 0
        let l: CGFloat = (maxVal + minVal) / 2.0

        if delta != 0 {
            s = l > 0.5 ? delta / (2.0 - maxVal - minVal) : delta / (maxVal + minVal)
            if maxVal == r { h = (g - b) / delta + (g < b ? 6 : 0) }
            else if maxVal == g { h = (b - r) / delta + 2 }
            else { h = (r - g) / delta + 4 }
            h /= 6.0
        }
        return (Int(h * 360), Int(s * 100), Int(l * 100))
    }
}
