//
//  ThemeManager.swift
//  AltStore
//
//  Created by SideStore Team.
//  Copyright © 2024 SideStore. All rights reserved.
//

import UIKit
import SwiftUI

public extension Notification.Name {
    static let themeDidChange = Notification.Name("ALTThemeDidChangeNotification")
}

public enum AppearanceMode: Int, CaseIterable, Identifiable {
    case system = 0
    case light = 1
    case dark = 2
    
    public var id: Int { self.rawValue }
    
    public var title: String {
        switch self {
        case .system: return AppStrings.Settings.appearanceSystem
        case .light: return AppStrings.Settings.appearanceLight
        case .dark: return AppStrings.Settings.appearanceDark
        }
    }
    
    public var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - CSS Theme Constants (AppUI)
public struct AppUI {
    public struct Colors {
        public static var primaryPurple: UIColor {
            return ThemeManager.shared.accentColor
        }
        public static let secondaryBlue = UIColor(red: 116/255, green: 185/255, blue: 255/255, alpha: 1.0) // #74b9ff
        
        public static let gradientStart = UIColor(red: 108/255, green: 92/255, blue: 231/255, alpha: 0.12)
        public static let gradientEnd = UIColor(red: 116/255, green: 185/255, blue: 255/255, alpha: 0.12)
        
        public static let cardBackground = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 28/255, green: 29/255, blue: 38/255, alpha: 0.92)
                : UIColor.white
        }
        
        public static let cardSubtleBackground = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 38/255, green: 40/255, blue: 52/255, alpha: 1.0)
                : UIColor(red: 248/255, green: 249/255, blue: 255/255, alpha: 1.0)
        }
        
        public static let textPrimary = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 245/255, green: 246/255, blue: 250/255, alpha: 1.0)
                : UIColor(red: 45/255, green: 52/255, blue: 54/255, alpha: 1.0)
        }
        
        public static let textSecondary = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 164/255, green: 176/255, blue: 190/255, alpha: 1.0)
                : UIColor(red: 99/255, green: 110/255, blue: 114/255, alpha: 1.0)
        }
        
        public static let borderPurple = UIColor(red: 108/255, green: 92/255, blue: 231/255, alpha: 0.15)
        public static let dangerRed = UIColor(red: 255/255, green: 71/255, blue: 87/255, alpha: 1.0)
        public static let successGreen = UIColor(red: 46/255, green: 213/255, blue: 115/255, alpha: 1.0)
        public static let warningOrange = UIColor(red: 255/255, green: 165/255, blue: 2/255, alpha: 1.0)
        
        // Aliases tương thích với BrowseViewController & MyAppsViewController
        public static var blue: UIColor { primaryPurple }
        public static var dark: UIColor { textPrimary }
        public static var white: UIColor { cardBackground }
        public static var border: UIColor { borderPurple }
        public static var green: UIColor { successGreen }
        public static var red: UIColor { dangerRed }
        public static var gray: UIColor { textSecondary }
    }
    
    public struct Layout {
        public static let containerCornerRadius: CGFloat = 24.0
        public static let cardCornerRadius: CGFloat = 18.0
        public static let buttonCornerRadius: CGFloat = 14.0
        public static let badgeCornerRadius: CGFloat = 10.0
        public static var radius: CGFloat { cardCornerRadius }
    }
}

// MARK: - UIView CSS Styling Extensions
public extension UIView {
    private static let cssGradientLayerName = "CSSBodyGradientLayer"
    
    func applyCSSBodyGradient() {
        self.backgroundColor = UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 15/255, green: 16/255, blue: 22/255, alpha: 1.0)
                : UIColor(red: 244/255, green: 245/255, blue: 252/255, alpha: 1.0)
        }
        
        self.layer.sublayers?.removeAll(where: { $0.name == UIView.cssGradientLayerName })
        
        let gradientLayer = CAGradientLayer()
        gradientLayer.name = UIView.cssGradientLayerName
        gradientLayer.frame = self.bounds
        gradientLayer.colors = [
            AppUI.Colors.primaryPurple.withAlphaComponent(0.14).cgColor,
            AppUI.Colors.secondaryBlue.withAlphaComponent(0.14).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        
        self.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    func updateCSSGradientFrame() {
        guard let sublayers = self.layer.sublayers else { return }
        for layer in sublayers where layer.name == UIView.cssGradientLayerName {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            layer.frame = self.bounds
            CATransaction.commit()
        }
    }
    
    func updateCSSBodyGradientFrame() {
        updateCSSGradientFrame()
    }
    
    func applyCSSCardStyle(cornerRadius: CGFloat = AppUI.Layout.cardCornerRadius) {
        self.backgroundColor = AppUI.Colors.cardBackground
        self.layer.cornerRadius = cornerRadius
        self.layer.cornerCurve = .continuous
        self.layer.borderWidth = 1.0
        self.layer.borderColor = AppUI.Colors.borderPurple.cgColor
        
        self.layer.shadowColor = AppUI.Colors.primaryPurple.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 8)
        self.layer.shadowRadius = 18
        self.layer.shadowOpacity = 0.08
        self.layer.masksToBounds = false
    }
    
    func applyCSSBannerShadow() {
        self.layer.cornerCurve = .continuous
        self.layer.shadowColor = AppUI.Colors.primaryPurple.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 6)
        self.layer.shadowRadius = 14
        self.layer.shadowOpacity = 0.1
    }
    
    func applyCSSPillButtonStyle() {
        self.layer.cornerRadius = AppUI.Layout.buttonCornerRadius
        self.layer.cornerCurve = .continuous
        self.layer.shadowColor = AppUI.Colors.primaryPurple.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 10
        self.layer.shadowOpacity = 0.25
    }
}

public extension UILabel {
    func applySectionTitle(text: String) {
        self.text = text
        self.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        self.textColor = AppUI.Colors.textPrimary
    }
}

public extension UIViewController {
    func applyCSSNavigationBar(tintColor: UIColor = AppUI.Colors.primaryPurple, transparentEdge: Bool = true) {
        guard let navBar = self.navigationController?.navigationBar else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = AppUI.Colors.cardBackground.withAlphaComponent(0.82)
        appearance.shadowColor = AppUI.Colors.borderPurple
        
        appearance.titleTextAttributes = [
            .foregroundColor: AppUI.Colors.textPrimary,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppUI.Colors.textPrimary,
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy)
        ]
        
        navBar.standardAppearance = appearance
        if transparentEdge {
            let edgeAppearance = UINavigationBarAppearance()
            edgeAppearance.configureWithTransparentBackground()
            edgeAppearance.titleTextAttributes = appearance.titleTextAttributes
            edgeAppearance.largeTitleTextAttributes = appearance.largeTitleTextAttributes
            navBar.scrollEdgeAppearance = edgeAppearance
        } else {
            navBar.scrollEdgeAppearance = appearance
        }
        navBar.compactAppearance = appearance
        navBar.tintColor = tintColor
    }
}

public extension UINavigationController {
    func applyCSSNavigationBar() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = AppUI.Colors.cardBackground.withAlphaComponent(0.82)
        appearance.shadowColor = AppUI.Colors.borderPurple
        
        appearance.titleTextAttributes = [
            .foregroundColor: AppUI.Colors.textPrimary,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: AppUI.Colors.textPrimary,
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy)
        ]
        
        self.navigationBar.standardAppearance = appearance
        self.navigationBar.scrollEdgeAppearance = appearance
        self.navigationBar.compactAppearance = appearance
        self.navigationBar.tintColor = AppUI.Colors.primaryPurple
    }
}

// MARK: - ThemeManager
public final class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    private let useCustomAccentKey = "ALTUseCustomAccentColor"
    private let accentColorHexKey = "ALTCustomAccentColorHex"
    private let appearanceModeKey = "ALTAppearanceMode"
    
    public static let defaultAccentColor = UIColor(red: 108/255, green: 92/255, blue: 231/255, alpha: 1.0) // #6c5ce7
    
    @Published public var useCustomAccentColor: Bool {
        didSet {
            UserDefaults.standard.set(useCustomAccentColor, forKey: useCustomAccentKey)
            notifyThemeChanged()
        }
    }
    
    @Published public var customAccentColorHex: String {
        didSet {
            UserDefaults.standard.set(customAccentColorHex, forKey: accentColorHexKey)
            notifyThemeChanged()
        }
    }
    
    @Published public var appearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearanceMode.rawValue, forKey: appearanceModeKey)
            applyAppearanceMode()
            notifyThemeChanged()
        }
    }
    
    public var accentColor: UIColor {
        if useCustomAccentColor, let customColor = UIColor(hex: customAccentColorHex) {
            return customColor
        }
        return Self.defaultAccentColor
    }
    
    public var swiftUIAccentColor: Color {
        return Color(accentColor)
    }
    
    private init() {
        self.useCustomAccentColor = UserDefaults.standard.bool(forKey: useCustomAccentKey)
        self.customAccentColorHex = UserDefaults.standard.string(forKey: accentColorHexKey) ?? "#6C5CE7"
        let modeRaw = UserDefaults.standard.integer(forKey: appearanceModeKey)
        self.appearanceMode = AppearanceMode(rawValue: modeRaw) ?? .system
    }
    
    public func applyAppearanceMode() {
        DispatchQueue.main.async {
            let style = self.appearanceMode.userInterfaceStyle
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        window.overrideUserInterfaceStyle = style
                        window.tintColor = self.accentColor
                    }
                }
            }
        }
    }
    
    public func resetToDefaults() {
        self.useCustomAccentColor = false
        self.customAccentColorHex = "#6C5CE7"
        self.appearanceMode = .system
    }
    
    private func notifyThemeChanged() {
        applyAppearanceMode()
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }
}

// MARK: - Preset Color Model
public struct PresetThemeColor: Identifiable {
    public let id: String
    public let name: String
    public let hex: String
    
    public init(name: String, hex: String) {
        self.id = hex
        self.name = name
        self.hex = hex
    }
}

// MARK: - Reusable SwiftUI CSS Card Component
public struct CSSSectionCard<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    public init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(Color(AppUI.Colors.primaryPurple))
                    .font(.system(size: 16, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(AppUI.Colors.textPrimary))
            }
            
            content
        }
        .padding(18)
        .background(Color(AppUI.Colors.cardBackground))
        .cornerRadius(AppUI.Layout.cardCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AppUI.Layout.cardCornerRadius)
                .stroke(Color(AppUI.Colors.borderPurple), lineWidth: 1)
        )
        .shadow(color: Color(AppUI.Colors.primaryPurple).opacity(0.08), radius: 14, x: 0, y: 6)
    }
}

// MARK: - UIColor Hex Conversion Helpers
public extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        if length == 6 {
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else if length == 8 {
            let r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgb & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        } else {
            return nil
        }
    }
    
    func toHex() -> String? {
        guard let components = cgColor.components, components.count >= 3 else { return nil }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
