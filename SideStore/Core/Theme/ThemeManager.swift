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
        public static let secondaryBlue = UIColor(red: 116/255, green: 185/255, blue: 255/255, alpha: 1.0)     // #74b9ff
        
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
                : UIColor(red: 248/255, green: 249/255, blue: 255/255, alpha: 1.0) // #f8f9ff
        }
        
        public static let textPrimary = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 245/255, green: 246/255, blue: 250/255, alpha: 1.0)
                : UIColor(red: 45/255, green: 52/255, blue: 54/255, alpha: 1.0)     // #2d3436
        }
        
        public static let textSecondary = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 164/255, green: 176/255, blue: 190/255, alpha: 1.0)
                : UIColor(red: 99/255, green: 110/255, blue: 114/255, alpha: 1.0)   // #636e72
        }
        
        public static let borderPurple = UIColor(red: 108/255, green: 92/255, blue: 231/255, alpha: 0.15)
        public static let dangerRed = UIColor(red: 255/255, green: 71/255, blue: 87/255, alpha: 1.0)       // #ff4757
        public static let successGreen = UIColor(red: 46/255, green: 213/255, blue: 115/255, alpha: 1.0)   // #2ed573
        public static let warningOrange = UIColor(red: 255/255, green: 165/255, blue: 2/255, alpha: 1.0)   // #ffa502
    }
    
    public struct Layout {
        public static let containerCornerRadius: CGFloat = 24.0
        public static let cardCornerRadius: CGFloat = 18.0
        public static let buttonCornerRadius: CGFloat = 14.0
        public static let badgeCornerRadius: CGFloat = 10.0
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
    
    func applyCSSPillButtonStyle() {
        self.layer.cornerRadius = AppUI.Layout.buttonCornerRadius
        self.layer.cornerCurve = .continuous
        self.layer.shadowColor = AppUI.Colors.primaryPurple.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 10
        self.layer.shadowOpacity = 0.25
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

// MARK: - SwiftUI UserCustomizationsView
public struct UserCustomizationsView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedColor: Color = ThemeManager.shared.swiftUIAccentColor
    @State private var showingResetConfirmation = false
    @State private var showingCacheClearedAlert = false
    
    private let presetColors: [PresetThemeColor] = [
        PresetThemeColor(name: "Tím SideStore", hex: "#6C5CE7"),
        PresetThemeColor(name: "Xanh Dương", hex: "#0984E3"),
        PresetThemeColor(name: "Xanh Ngọc", hex: "#00CEC9"),
        PresetThemeColor(name: "Xanh Lá", hex: "#2ED573"),
        PresetThemeColor(name: "Cam", hex: "#FFA502"),
        PresetThemeColor(name: "Đỏ Hồng", hex: "#FF4757"),
        PresetThemeColor(name: "Hồng Tím", hex: "#E84393")
    ]
    
    public init() {}
    
    public var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(AppUI.Colors.primaryPurple).opacity(0.14),
                    Color(AppUI.Colors.secondaryBlue).opacity(0.14)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // 1. Chế độ hiển thị (Sáng / Tối / Hệ thống)
                    CSSSectionCard(title: AppStrings.Settings.appearanceModeTitle, icon: "circle.lefthalf.filled") {
                        Picker(AppStrings.Settings.appearanceModeTitle, selection: $themeManager.appearanceMode) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // 2. Màu sắc chủ đề
                    CSSSectionCard(title: AppStrings.Settings.themeSectionHeader, icon: "paintpalette.fill") {
                        VStack(spacing: 16) {
                            Toggle(AppStrings.Settings.useCustomAccentColor, isOn: $themeManager.useCustomAccentColor)
                                .tint(themeManager.swiftUIAccentColor)
                            
                            if themeManager.useCustomAccentColor {
                                Divider()
                                
                                ColorPicker(AppStrings.Settings.accentColorTitle, selection: $selectedColor, supportsOpacity: false)
                                    .onChange(of: selectedColor) { newColor in
                                        if let hex = UIColor(newColor).toHex() {
                                            themeManager.customAccentColorHex = hex
                                        }
                                    }
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(presetColors) { preset in
                                            PresetColorCircleButton(
                                                preset: preset,
                                                isSelected: themeManager.customAccentColorHex.uppercased() == preset.hex.uppercased()
                                            ) {
                                                themeManager.customAccentColorHex = preset.hex
                                                if let uiColor = UIColor(hex: preset.hex) {
                                                    selectedColor = Color(uiColor)
                                                }
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                    
                    // 3. Quản lý bộ nhớ đệm
                    CSSSectionCard(title: AppStrings.Settings.cacheSectionHeader, icon: "internaldrive.fill") {
                        VStack(spacing: 12) {
                            Button(action: clearImageAndAppCache) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text(AppStrings.Settings.clearAppCache)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .foregroundColor(Color(AppUI.Colors.primaryPurple))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Color(AppUI.Colors.primaryPurple).opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            Button(action: { showingResetConfirmation = true }) {
                                HStack {
                                    Image(systemName: "arrow.counterclockwise")
                                    Text(AppStrings.Settings.resetCustomizations)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                .foregroundColor(Color(AppUI.Colors.dangerRed))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Color(AppUI.Colors.dangerRed).opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle(AppStrings.Settings.customizationsTitle)
        .onAppear {
            selectedColor = themeManager.swiftUIAccentColor
        }
        .alert(AppStrings.Settings.resetCustomizations, isPresented: $showingResetConfirmation) {
            Button(AppStrings.Common.cancel, role: .cancel) {}
            Button(AppStrings.Common.reset, role: .destructive) {
                themeManager.resetToDefaults()
                selectedColor = themeManager.swiftUIAccentColor
            }
        }
        .alert(AppStrings.Common.success, isPresented: $showingCacheClearedAlert) {
            Button(AppStrings.Common.ok, role: .cancel) {}
        } message: {
            Text(AppStrings.Settings.cacheClearedMessage)
        }
    }
    
    private func clearImageAndAppCache() {
        URLCache.shared.removeAllCachedResponses()
        showingCacheClearedAlert = true
    }
}

// MARK: - Subview cho nút chọn màu Preset (Tách riêng để tránh lỗi Type-Inference của SwiftUI)
private struct PresetColorCircleButton: View {
    let preset: PresetThemeColor
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(UIColor(hex: preset.hex) ?? ThemeManager.defaultAccentColor))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .accessibilityLabel(Text(preset.name))
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
