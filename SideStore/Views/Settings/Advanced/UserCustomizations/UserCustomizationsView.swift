
//
//  UserCustomizationsView.swift
//  SideStore
//
//  Created by Magesh K on 01/02/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import SwiftUI
import AltStoreCore

struct UserCustomizationsView: View {
    @AppStorage("customAnisetteURL") private var customAnisetteURL: String = ""
    @AppStorage("textInputAnisetteURL") private var textInputAnisetteURL: String = ""
    @AppStorage("selectedAnisetteURL") private var selectedAnisetteURL: String = ""
    @State private var isMenuPresented = false
    @State private var showAppRestartAlert: Bool = false

    @AppStorage("defaultAnisetteServers") private var anisetteServersData: Data = Data()
    private var defaultAnisetteServers: [String: String] {
        get { (try? JSONDecoder().decode([String: String].self, from: anisetteServersData)) ?? [:] }
        set { anisetteServersData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    @AppStorage("customCachingServer") private var customCachingServer: String = ""
    @AppStorage("allowCustomAnisetteURL") private var allowCustomAnisetteURL: Bool = false
    @AppStorage("useLocalAnisette") private var useLocalAnisette: Bool = false
    @AppStorage("resetButtonPressed") private var resetButtonPressed: Bool = false
    @AppStorage("serverlistRefreshRequested") private var serverlistRefreshRequested: Bool = false
    @AppStorage("showDebugRepresentations") private var showDebugRepresentations: Bool = false
    @AppStorage("signingCertInfo") private var signingCertInfo: Data = Data()
    @AppStorage("adi.pb") private var adiPb: Data = Data()
    @AppStorage("cleanLocalAnisetteData") private var cleanLocalAnisetteData: Bool = false
    @AppStorage("exportLocalAnisetteData") private var exportLocalAnisetteData: Bool = false
    @AppStorage("allowLockdownMode") private var allowLockdownMode: Bool = false
    @AppStorage("useAltAppsOnMainProfile") private var useAltAppsOnMainProfile: Bool = false
    @AppStorage("isRefreshResultNotificationEnabled") private var isRefreshResultNotificationEnabled: Bool = false

    @State private var showConfirmationSheet: Bool = false

    private var signingCertificateDetails: SigningCertificateDetails? {
        guard !signingCertInfo.isEmpty else { return nil }
        return try? JSONDecoder().decode(SigningCertificateDetails.self, from: signingCertInfo)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CSSSectionCard(title: AppStrings.Customizations.themeSection, icon: "paintpalette.fill") {
                    navRow(title: AppStrings.Customizations.accentColor, destination: ThemeSelectionView())
                }

                CSSSectionCard(title: AppStrings.Customizations.appDocuments, icon: "folder.fill") {
                    VStack(spacing: 12) {
                        navRow(title: AppStrings.Customizations.documentsBrowser, destination: FileBrowserView(rootURL: FileManager.default.documentsDirectory!))
                        divider
                        navRow(title: AppStrings.Customizations.GroupContainerBrowser, destination: FileBrowserView(rootURL: FileManager.default.appGroupDirectory()!))
                    }
                }

                if let cert = signingCertificateDetails {
                    CSSSectionCard(title: AppStrings.Customizations.certDetailsSection, icon: "checkmark.seal.fill") {
                        navRow(title: AppStrings.Customizations.viewCertDetails, destination: CertificateDetailsView(certificate: cert))
                    }
                }

                CSSSectionCard(title: AppStrings.Customizations.anisetteSection, icon: "server.rack") {
                    VStack(alignment: .leading, spacing: 14) {
                        toggleRow(title: AppStrings.Customizations.useLocalAnisette, isOn: $useLocalAnisette)
                        if !useLocalAnisette {
                            divider
                            anisettePickerContent
                        } else if !adiPb.isEmpty {
                            divider
                            localAnisetteActionsContent
                        }
                        footerText(AppStrings.Customizations.anisetteFooter)
                    }
                }

                CSSSectionCard(title: AppStrings.Customizations.notificationsSection, icon: "bell.badge.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        toggleRow(title: AppStrings.Customizations.notifyRefreshStatus, isOn: $isRefreshResultNotificationEnabled)
                        footerText(AppStrings.Customizations.notificationsFooter)
                    }
                }

                CSSSectionCard(title: AppStrings.Customizations.minimuxerSection, icon: "shield.lefthalf.filled") {
                    VStack(alignment: .leading, spacing: 10) {
                        toggleRow(title: AppStrings.Customizations.supportLockdownMode, isOn: $allowLockdownMode)
                            .onChange(of: allowLockdownMode) { _ in showAppRestartAlert = true }
                        footerText(AppStrings.Customizations.minimuxerFooter)
                    }
                }

                if UserDefaults.standard.useMainProfile {
                    CSSSectionCard(title: AppStrings.Customizations.appInstallOptions, icon: "square.and.arrow.down.fill") {
                        VStack(alignment: .leading, spacing: 10) {
                            toggleRow(title: AppStrings.Customizations.useMainProfileForAltApps, isOn: $useAltAppsOnMainProfile)
                            footerText(AppStrings.Customizations.appInstallFooter)
                        }
                    }
                }

                CSSSectionCard(title: AppStrings.Customizations.cachingSection, icon: "externaldrive.fill.badge.wifi") {
                    VStack(alignment: .leading, spacing: 12) {
                        textFieldRow(title: AppStrings.Customizations.cachingServer, placeholder: AppStrings.Customizations.enterServerURL, text: $customCachingServer, keyboard: .URL)
                        CSSActionButton(icon: "trash.fill", title: AppStrings.Customizations.cleanCacheButton, style: .outlineMagenta) {
                            showConfirmationSheet = true
                        }
                        footerText(AppStrings.Customizations.cachingFooter)
                    }
                }

                CSSSectionCard(title: AppStrings.Customizations.debuggingSection, icon: "ladybug.fill") {
                    VStack(alignment: .leading, spacing: 10) {
                        toggleRow(title: AppStrings.Customizations.additionalDebugging, isOn: $showDebugRepresentations)
                        footerText(AppStrings.Customizations.debuggingFooter)
                    }
                }

                CSSActionButton(icon: "arrow.counterclockwise", title: AppStrings.Common.resetToDefault(), style: .destructiveRed) {
                    resetToDefault()
                }
            }
            .padding(16)
        }
        .cssBodyBackground()
        .navigationTitle(AppStrings.Customizations.title)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(AppStrings.Customizations.confirmCleanCacheTitle, isPresented: $showConfirmationSheet, titleVisibility: .visible) {
            Button(AppStrings.Customizations.deleteAllData, role: .destructive) { cleanCacheData() }
            Button(AppStrings.Common.cancel(), role: .cancel) {}
        } message: {
            Text(AppStrings.Customizations.confirmCleanCacheMessage)
        }
        .alert(isPresented: $showAppRestartAlert) {
            Alert(
                title: Text(AppStrings.Customizations.restartRequiredTitle),
                message: Text(AppStrings.Customizations.restartRequiredMessage),
                dismissButton: .default(Text(RSTSystemLocalizedString("OK")))
            )
        }
    }

    // MARK: - Subviews & Builders
    @ViewBuilder
    private var anisettePickerContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(AppStrings.Customizations.preferredServer)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppUI.SwiftUIColors.dark)
                Spacer()
                Button(action: { isMenuPresented.toggle() }) {
                    Text(selectedAnisetteURL.isEmpty ? AppStrings.Customizations.selectServer : labelForURL(selectedAnisetteURL))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppUI.SwiftUIColors.blue)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .sheet(isPresented: $isMenuPresented) {
                    AnisetteSelectionSheet(
                        selectedAnisetteURL: $selectedAnisetteURL,
                        textInputAnisetteURL: $textInputAnisetteURL,
                        defaultAnisetteServers: defaultAnisetteServers
                    )
                }
            }
            divider
            textFieldRow(title: AppStrings.Customizations.serverURL, placeholder: AppStrings.Customizations.customAnisettePlaceholder, text: $textInputAnisetteURL, keyboard: .URL)
                .disabled(!allowCustomAnisetteURL)
                .onChange(of: textInputAnisetteURL) { newValue in
                    if allowCustomAnisetteURL { customAnisetteURL = newValue }
                }
            divider
            toggleRow(title: AppStrings.Customizations.customWalkthrough, isOn: $allowCustomAnisetteURL)
                .onChange(of: allowCustomAnisetteURL) { isAllowed in
                    textInputAnisetteURL = isAllowed ? customAnisetteURL : selectedAnisetteURL
                }
            if !allowCustomAnisetteURL {
                CSSActionButton(icon: "arrow.clockwise", title: AppStrings.Customizations.refreshList, style: .outlineBlue) {
                    serverlistRefreshRequested = true
                }
            }
        }
    }

    @ViewBuilder
    private var localAnisetteActionsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppStrings.Customizations.localDataFound)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppUI.SwiftUIColors.green)
            HStack(spacing: 12) {
                CSSActionButton(icon: "trash", title: AppStrings.Customizations.resetData, style: .destructiveRed) {
                    cleanLocalAnisetteData = true
                }
                CSSActionButton(icon: "square.and.arrow.up", title: AppStrings.Customizations.exportData, style: .primaryBlue) {
                    exportLocalAnisetteData = true
                }
            }
        }
    }

    private func navRow<D: View>(title: String, destination: D) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppUI.SwiftUIColors.dark)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppUI.SwiftUIColors.blue)
            }
            .padding(.vertical, 4)
        }
    }

    private func toggleRow(title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppUI.SwiftUIColors.dark)
        }
        .tint(AppUI.SwiftUIColors.green)
    }

    private func textFieldRow(title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppUI.SwiftUIColors.dark)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocapitalization(.none)
                .padding(10)
                .background(AppUI.SwiftUIColors.light)
                .cornerRadius(10)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppUI.SwiftUIColors.border, lineWidth: 1))
        }
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundColor(AppUI.SwiftUIColors.dark.opacity(0.75))
            .padding(.top, 2)
    }

    private var divider: some View {
        Divider().overlay(AppUI.SwiftUIColors.border)
    }

    private func resetToDefault() {
        resetButtonPressed = true
        useAltAppsOnMainProfile = false
    }

    private func cleanCacheData() {
        URLCache.shared.removeAllCachedResponses()
    }

    private func labelForURL(_ url: String) -> String {
        defaultAnisetteServers.first(where: { $0.value == url })?.key ?? url
    }
}

// MARK: - Anisette Selection Sheet
struct AnisetteSelectionSheet: View {
    @Binding var selectedAnisetteURL: String
    @Binding var textInputAnisetteURL: String
    let defaultAnisetteServers: [String: String]
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(defaultAnisetteServers.sorted(by: { $0.key < $1.key }), id: \.value) { key, value in
                        Button(action: {
                            selectedAnisetteURL = value
                            textInputAnisetteURL = value
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(key)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AppUI.SwiftUIColors.blue)
                                    Text(value)
                                        .font(.system(size: 13))
                                        .foregroundColor(AppUI.SwiftUIColors.dark.opacity(0.7))
                                }
                                Spacer()
                                if selectedAnisetteURL == value {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppUI.SwiftUIColors.green)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding(14)
                            .modifier(CSSCardModifier())
                        }
                        .buttonStyle(CSSPressButtonStyle())
                    }
                }
                .padding(16)
            }
            .cssBodyBackground()
            .navigationTitle(AppStrings.Customizations.selectAnisetteServer)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppStrings.Common.cancel()) { presentationMode.wrappedValue.dismiss() }
                        .foregroundColor(AppUI.SwiftUIColors.blue)
                }
            }
        }
    }
}

// MARK: - Certificate Details View
struct CertificateDetailsView: View {
    let certificate: SigningCertificateDetails

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CSSSectionCard(title: AppStrings.Customizations.certInfoSection, icon: "doc.text.magnifyingglass") {
                    VStack(spacing: 10) {
                        infoRow(label: AppStrings.Customizations.certName, value: certificate.name)
                        Divider().overlay(AppUI.SwiftUIColors.border)
                        infoRow(label: AppStrings.Customizations.serialNumber, value: certificate.serialNumber)
                        if let machineName = certificate.machineName {
                            Divider().overlay(AppUI.SwiftUIColors.border)
                            infoRow(label: AppStrings.Customizations.machineName, value: machineName)
                        }
                        if let machineIdentifier = certificate.machineIdentifier {
                            Divider().overlay(AppUI.SwiftUIColors.border)
                            infoRow(label: AppStrings.Customizations.machineID, value: machineIdentifier)
                        }
                    }
                }

                if let data = certificate.data {
                    CSSSectionCard(title: AppStrings.Customizations.pemDataSection, icon: "lock.doc.fill") {
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(String(data: data, encoding: .utf8) ?? AppStrings.Customizations.invalidPEMData)
                                .font(.system(.footnote, design: .monospaced))
                                .foregroundColor(AppUI.SwiftUIColors.dark)
                                .padding(10)
                        }
                        .background(AppUI.SwiftUIColors.light)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(16)
        }
        .cssBodyBackground()
        .navigationTitle(AppStrings.Customizations.certDetailsTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppUI.SwiftUIColors.dark)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppUI.SwiftUIColors.blue)
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Theme Selection View
struct ThemeSelectionView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var selectedColor: Color = Color(ThemeManager.shared.primaryColor)
    @State private var hexInput: String = ThemeManager.shared.primaryColor.hexString

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                CSSSectionCard(title: AppStrings.Customizations.presetsSection, icon: "swatchpalette.fill") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 14) {
                            ForEach(ThemePreset.presets) { preset in
                                presetButton(for: preset)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                }

                CSSSectionCard(title: AppStrings.Customizations.colorWheelSection, icon: "eyedropper.halffull") {
                    ColorPicker(AppStrings.Customizations.selectAccentColor, selection: $selectedColor, supportsOpacity: false)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppUI.SwiftUIColors.dark)
                        .onChange(of: selectedColor) { newColor in
                            let uiColor = UIColor(newColor)
                            themeManager.primaryColor = uiColor
                            hexInput = uiColor.hexString
                        }
                }

                CSSSectionCard(title: AppStrings.Customizations.colorValuesSection, icon: "number.square.fill") {
                    VStack(spacing: 10) {
                        HStack {
                            Text(AppStrings.Customizations.hexCode)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(AppUI.SwiftUIColors.dark)
                            Spacer()
                            TextField("#19D3B5", text: $hexInput)
                                .multilineTextAlignment(.trailing)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(AppUI.SwiftUIColors.blue)
                                .autocapitalization(.allCharacters)
                                .disableAutocorrection(true)
                                .onSubmit { applyHexInput() }
                        }
                        Divider().overlay(AppUI.SwiftUIColors.border)
                        let rgb = themeManager.primaryColor.rgbComponents
                        valueRow(title: "RGB", value: "\(rgb.r), \(rgb.g), \(rgb.b)")
                        Divider().overlay(AppUI.SwiftUIColors.border)
                        let hsl = themeManager.primaryColor.hslComponents
                        valueRow(title: "HSL", value: "\(hsl.h)°, \(hsl.s)%, \(hsl.l)%")
                    }
                }

                CSSActionButton(icon: "arrow.counterclockwise", title: AppStrings.Customizations.resetDefaultTheme, style: .destructiveRed) {
                    themeManager.resetToDefault()
                    selectedColor = Color(themeManager.primaryColor)
                    hexInput = themeManager.primaryColor.hexString
                }
            }
            .padding(16)
        }
        .cssBodyBackground()
        .navigationTitle(AppStrings.Customizations.themeColorTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func valueRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppUI.SwiftUIColors.dark)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(AppUI.SwiftUIColors.blue)
        }
    }

    private func presetButton(for preset: ThemePreset) -> some View {
        let isSelected = themeManager.primaryColor.hexString.uppercased() == preset.hex.uppercased()
        return Button {
            let uiColor = preset.color
            themeManager.primaryColor = uiColor
            selectedColor = Color(uiColor)
            hexInput = uiColor.hexString
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(preset.color))
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(AppUI.SwiftUIColors.border, lineWidth: 2))
                        .shadow(color: Color(preset.color).opacity(0.4), radius: 5, x: 0, y: 3)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                Text(preset.name)
                    .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                    .foregroundColor(isSelected ? AppUI.SwiftUIColors.blue : AppUI.SwiftUIColors.dark)
            }
        }
        .buttonStyle(CSSPressButtonStyle())
    }

    private func applyHexInput() {
        if let color = UIColor(hex: hexInput) {
            themeManager.primaryColor = color
            selectedColor = Color(color)
            hexInput = color.hexString
        } else {
            hexInput = themeManager.primaryColor.hexString
        }
    }
}
