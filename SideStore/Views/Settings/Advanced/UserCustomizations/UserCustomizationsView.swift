//
//  UserCustomizationsView.swift
//  SideStore
//
//  Created by SideStore Team.
//

import SwiftUI
import UIKit

private struct PresetColorItem: Identifiable, Hashable {
    let name: String
    let hex: String
    var id: String { hex }
}

struct UserCustomizationsView: View {
    @AppStorage("hideAppDescriptions") private var hideAppDescriptions = false
    @AppStorage("hideScreenshots") private var hideScreenshots = false
    @AppStorage("showAppSourceBadge") private var showAppSourceBadge = true
    @AppStorage("useCustomTintColor") private var useCustomTintColor = false
    @AppStorage("customTintColorHex") private var customTintColorHex = "#6552CC"
    @AppStorage("enableDetailedLogs") private var enableDetailedLogs = false
    
    @State private var selectedColor: Color = Color(hex: "#6552CC") ?? .purple
    @State private var showingClearLogsAlert = false
    @State private var showingCacheClearedAlert = false
    @State private var isExportingLogs = false
    @State private var logFileURL: URL?
    
    private let presetColors: [PresetColorItem] = [
        PresetColorItem(name: "SideStore Purple", hex: "#6552CC"),
        PresetColorItem(name: "AltStore Teal", hex: "#008080"),
        PresetColorItem(name: "Ocean Blue", hex: "#007AFF"),
        PresetColorItem(name: "Emerald Green", hex: "#34C759"),
        PresetColorItem(name: "Sunset Orange", hex: "#FF9500"),
        PresetColorItem(name: "Crimson Red", hex: "#FF3B30"),
        PresetColorItem(name: "Hot Pink", hex: "#FF2D55")
    ]
    
    var body: some View {
        Form {
            // MARK: - Layout Section
            Section(header: Text(AppStrings.Customizations.layoutSectionHeader)) {
                Toggle(AppStrings.Customizations.hideAppDescriptionsToggle, isOn: $hideAppDescriptions)
                Toggle(AppStrings.Customizations.hideScreenShotsToggle, isOn: $hideScreenshots)
                Toggle(AppStrings.Customizations.showAppSourceBadgeToggle, isOn: $showAppSourceBadge)
            }
            
            // MARK: - Tint Color Section
            Section(header: Text(AppStrings.Customizations.tintColorSectionHeader)) {
                Toggle(AppStrings.Customizations.customTintColorToggle, isOn: $useCustomTintColor)
                
                if useCustomTintColor {
                    ColorPicker(AppStrings.Customizations.selectColorPicker, selection: $selectedColor, supportsOpacity: false)
                        .onChange(of: selectedColor) { newColor in
                            if let hex = newColor.toHex() {
                                customTintColorHex = hex
                                applyTintColor(hex: hex)
                            }
                        }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppStrings.Customizations.presetColorsHeader)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(presetColors) { preset in
                                    Button {
                                        if let color = Color(hex: preset.hex) {
                                            selectedColor = color
                                            customTintColorHex = preset.hex
                                            applyTintColor(hex: preset.hex)
                                        }
                                    } label: {
                                        Circle()
                                            .fill(Color(hex: preset.hex) ?? .purple)
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: customTintColorHex == preset.hex ? 2 : 0)
                                            )
                                    }
                                    .accessibilityLabel(Text("\(AppStrings.Customizations.colorDescription) \(preset.name)"))
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button(AppStrings.Common.resetToDefault()) {
                        customTintColorHex = "#6552CC"
                        if let defaultColor = Color(hex: "#6552CC") {
                            selectedColor = defaultColor
                        }
                        applyTintColor(hex: "#6552CC")
                    }
                    .foregroundColor(.red)
                }
            }
            
            // MARK: - Cache Section
            Section(
                header: Text(AppStrings.Customizations.cacheSectionHeader),
                footer: Text(AppStrings.Customizations.clearCacheFooter)
            ) {
                Button(AppStrings.Customizations.clearCacheButton) {
                    clearCache()
                }
            }
            
            // MARK: - Logs Section
            Section(header: Text(AppStrings.Customizations.logsSectionHeader)) {
                Toggle(AppStrings.Customizations.enableDetailedLogsToggle, isOn: $enableDetailedLogs)
                
                Button(AppStrings.Customizations.exportLogsButton) {
                    exportLogs()
                }
                
                Button(AppStrings.Customizations.clearLogsButton) {
                    showingClearLogsAlert = true
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle(AppStrings.UserCustomizations.title)
        .onAppear {
            if let savedColor = Color(hex: customTintColorHex) {
                selectedColor = savedColor
            }
        }
        .alert(isPresented: $showingClearLogsAlert) {
            Alert(
                title: Text(AppStrings.Customizations.clearLogsConfirmationTitle),
                message: Text(AppStrings.Customizations.clearLogsConfirmationMessage),
                primaryButton: .destructive(Text(AppStrings.Common.delete)) {
                    clearLogs()
                },
                secondaryButton: .cancel(Text(AppStrings.Common.cancel))
            )
        }
        .alert(isPresented: $showingCacheClearedAlert) {
            Alert(
                title: Text(AppStrings.Customizations.cacheClearedTitle),
                message: Text(AppStrings.Customizations.cacheClearedMessage),
                dismissButton: .default(Text(systemLocalizedString("OK")))
            )
        }
        .sheet(isPresented: $isExportingLogs) {
            if let logFileURL = logFileURL {
                ShareSheet(activityItems: [logFileURL])
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func applyTintColor(hex: String) {
        guard let uiColor = UIColor(hex: hex) else { return }
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .forEach { window in
                window.tintColor = uiColor
            }
    }
    
    private func clearCache() {
        URLCache.shared.removeAllCachedResponses()
        showingCacheClearedAlert = true
    }
    
    private func exportLogs() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logURL = documentsURL.appendingPathComponent("sidestore.log")
            if fileManager.fileExists(atPath: logURL.path) {
                self.logFileURL = logURL
                self.isExportingLogs = true
            }
        }
    }
    
    private func clearLogs() {
        let fileManager = FileManager.default
        if let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let logURL = documentsURL.appendingPathComponent("sidestore.log")
            try? fileManager.removeItem(at: logURL)
        }
    }
}

// MARK: - ShareSheet Helper

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Color Extensions

private extension Color {
    init?(hex: String) {
        guard let uiColor = UIColor(hex: hex) else { return nil }
        self.init(uiColor)
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        return String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
    }
}
