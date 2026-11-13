
//
//  UserCustomizationsView.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Minimuxer

// MARK: - 🎨 BỘ GIAO DIỆN CSS THEME (ĐỒNG BỘ TOÀN HỆ THỐNG)
private enum CustomizationsCSSTheme {
    static let primaryBlue = Color(red: 0/255, green: 123/255, blue: 255/255)          // #007bff (--primary-blue)
    static let primaryPurple = Color(red: 111/255, green: 66/255, blue: 193/255)       // #6f42c1 (--primary-purple)
    static let primaryGreen = Color(red: 40/255, green: 167/255, blue: 69/255)         // #28a745 (--primary-green)
    static let primaryRed = Color(red: 220/255, green: 53/255, blue: 69/255)           // #dc3545 (--primary-red)
    static let darkText = Color(red: 52/255, green: 58/255, blue: 64/255)              // #343a40 (--dark-text)
    static let secondaryText = Color(red: 52/255, green: 58/255, blue: 64/255).opacity(0.65)
    
    static let bgGradientStart = Color(red: 243/255, green: 224/255, blue: 255/255)    // #f3e0ff
    static let bgGradientEnd = Color(red: 224/255, green: 247/255, blue: 255/255)      // #e0f7ff
    
    static var pageBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    static let cardBackground = Color.white
    static let innerFieldBackground = Color(red: 248/255, green: 249/255, blue: 250/255) // #f8f9fa
    static let border = Color(red: 233/255, green: 236/255, blue: 239/255)               // #e9ecef
    static let shadow = Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.12)
}

// MARK: - Hiệu ứng nhấn nút thu nhỏ chuẩn CSS (.btn:active transform: scale(0.96))
private struct CustomizationsBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

struct UserCustomizationsView: View {
    @State private var selectedBackend: GatewayBackend = selectedGatewayBackendCache
    @State private var isBackgroundServiceEnabled: Bool = UserDefaults.standard.isBackgroundServiceEnabled
    @State private var selectedBackgroundServiceMode: BackgroundServiceMode = UserDefaults.standard.backgroundServiceMode
    @State private var useOnDeviceAnisette: Bool = UserDefaults.standard.useOnDeviceAnisette
    @State private var showAnisetteRestartConfirmation: Bool = false
    @State private var customizeInfoPlist: Bool = UserDefaults.standard.customizeInfoPlist
    @State private var preferSheetForInfoPlistCustomization: Bool = UserDefaults.standard.preferSheetForInfoPlistCustomization
    @State private var customizeEntitlements: Bool = UserDefaults.standard.customizeEntitlements
    @State private var preferSheetForEntitlementsCustomization: Bool = UserDefaults.standard.preferSheetForEntitlementsCustomization
    @State private var customizeAppId: Bool = UserDefaults.standard.customizeAppId
    @State private var customizeAppIcon: Bool = UserDefaults.standard.customizeAppIcon
    @State private var customizeProvisioningProfile: Bool = UserDefaults.standard.customizeProvisioningProfile
    @State private var customizeAppExtensions: AppExtensionCustomization = UserDefaults.standard.customizeAppExtensions
    @State private var appImportSourceMode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode
    @State private var isInstallConfirmationEnabled: Bool = UserDefaults.standard.isInstallConfirmationEnabled
    @State private var isClearCustomizationsOnUninstallEnabled: Bool = UserDefaults.standard.isClearCustomizationsOnUninstallEnabled
    @State private var isAutoLaunchAppAfterInstallEnabled: Bool = UserDefaults.standard.isAutoLaunchAppAfterInstallEnabled
    @State private var autoFixAppGroupIDs: Bool = UserDefaults.standard.autoFixAppGroupIDs
    @State private var preferResignedIPA: Bool = UserDefaults.standard.preferResignedIPA
    @State private var pendingPreferIPAOngoing: Bool = false
    @State private var showPreferIPAToggleAlert: Bool = false
    @State private var isExportResignedAppEnabled: Bool = UserDefaults.standard.isExportResignedAppEnabled
    @State private var enableEMPforWireguard: Bool = UserDefaults.standard.enableEMPforWireguard
    @State private var pendingEMPOption: Bool = false
    @State private var showEMPRestartConfirmation: Bool = false
    @State private var pendingBackendOption: GatewayBackend? = nil
    @State private var showBackendRestartConfirmation: Bool = false
    @State private var skipNonCopyableFiles: Bool = UserDefaults.standard.skipNonCopyableBackupFiles
    @State private var appVerificationDisabled: Bool = UserDefaults.standard.appVerificationDisabled
    @State private var isBundleIDVerificationEnabled: Bool = UserDefaults.standard.isBundleIDVerificationEnabled
    @State private var isiOSVersionVerificationEnabled: Bool = UserDefaults.standard.isiOSVersionVerificationEnabled
    @State private var isAppVersionVerificationEnabled: Bool = UserDefaults.standard.isAppVersionVerificationEnabled
    @State private var isChecksumVerificationEnabled: Bool = UserDefaults.standard.isChecksumVerificationEnabled
    @State private var isFileSizeVerificationEnabled: Bool = UserDefaults.standard.isFileSizeVerificationEnabled
    @State private var permissionCheckingDisabled: Bool = UserDefaults.standard.permissionCheckingDisabled
    @State private var isCellularRefreshEnabled: Bool = UserDefaults.standard.isCellularRefreshEnabled
    @State private var turnOnDataShortcutName: String = UserDefaults.standard.turnOnDataShortcutName
    @State private var turnOffDataShortcutName: String = UserDefaults.standard.turnOffDataShortcutName
    @State private var turnOnBaseDelayText: String = {
        let delay = CellularRefreshManager.shared.turnOnDataBaseDelayOverride ?? AppConstants.Shortcuts.defaultTurnOnDataBaseDelay
        return String(delay)
    }()
    @State private var turnOffBaseDelayText: String = {
        let delay = CellularRefreshManager.shared.turnOffDataBaseDelayOverride ?? AppConstants.Shortcuts.defaultTurnOffDataBaseDelay
        return String(delay)
    }()
    @State private var wireGuardExportURL: URL? = nil

    @State private var isFreeAccount: Bool = false

    struct EditDialogState: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let placeholder: String
        let keyboardType: UIKeyboardType
        let onSave: (String) -> Void
    }

    @State private var editDialog: EditDialogState? = nil
    @State private var editingValueText: String = ""

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                // Section 0: GIAO DIỆN & CHỦ ĐỀ
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "GIAO DIỆN & CHỦ ĐỀ", icon: "paintpalette.fill")
                    
                    sectionCard {
                        NavigationLink(destination: ThemePickerView()) {
                            HStack {
                                Text("Quản lý Chủ đề (Theme)")
                                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                    .foregroundColor(CustomizationsCSSTheme.darkText)
                                Spacer()
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color(uiColor: ThemeManager.shared.primaryColor))
                                        .frame(width: 16, height: 16)
                                        .overlay(
                                            Circle()
                                                .stroke(CustomizationsCSSTheme.border, lineWidth: 1)
                                        )
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(CustomizationsCSSTheme.primaryPurple.opacity(0.7))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                        }
                    }
                }

                // Section 1: ANISETTE
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "ANISETTE", icon: "server.rack")
                    
                    sectionCard {
                        toggleRow(
                            title: "Anisette Trên Thiết Bị (On-Device)",
                            subtitle: "Chạy giả lập ADI trực tiếp trên máy thay vì dùng máy chủ từ xa",
                            isOn: Binding(
                                get: { useOnDeviceAnisette },
                                set: { newValue in
                                    useOnDeviceAnisette = newValue
                                    showAnisetteRestartConfirmation = true
                                }
                            )
                        )
                        
                        divider
                        
                        NavigationLink(destination: AnisetteDataView()) {
                            HStack {
                                Text("Cấu hình Máy khách Anisette")
                                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                    .foregroundColor(CustomizationsCSSTheme.darkText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(CustomizationsCSSTheme.primaryPurple.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                        }
                        
                        divider
                        
                        SwiftUI.Button(role: .destructive) {
                            presentResetAdiDialog()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Đặt lại dữ liệu adi.pb")
                                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                        .foregroundColor(CustomizationsCSSTheme.primaryRed)
                                    Text("Xoá dữ liệu cấp phép Anisette cục bộ khỏi Chuỗi khóa (Keychain)")
                                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                        .foregroundColor(CustomizationsCSSTheme.secondaryText)
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(CustomizationsCSSTheme.primaryRed.opacity(0.12))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(CustomizationsCSSTheme.primaryRed)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 54)
                        }
                        .buttonStyle(CustomizationsBounceButtonStyle())
                    }
                }

                // Section: SIDESIGN
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "SIDESIGN", icon: "signature")
                    
                    sectionCard {
                        NavigationLink(destination: SideSignConfigurationView()) {
                            HStack {
                                Text("Cấu hình Máy khách SideSign")
                                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                    .foregroundColor(CustomizationsCSSTheme.darkText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(CustomizationsCSSTheme.primaryPurple.opacity(0.7))
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                        }
                    }
                }

                // Section 2: CÀI ĐẶT CHUNG
                generalSection

                // Section 3: XÁC MINH ỨNG DỤNG
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "XÁC MINH ỨNG DỤNG", icon: "checkmark.shield.fill")
                    
                    sectionCard {
                        toggleRow(title: "Tắt tất cả bước xác minh", isOn: Binding(
                            get: { appVerificationDisabled },
                            set: { newValue in
                                appVerificationDisabled = newValue
                                UserDefaults.standard.appVerificationDisabled = newValue
                            }
                        ))
                        
                        divider
                        
                        Group {
                            toggleRow(title: "Kiểm tra Bundle Identifier", isOn: Binding(
                                get: { isBundleIDVerificationEnabled },
                                set: { newValue in
                                    isBundleIDVerificationEnabled = newValue
                                    UserDefaults.standard.isBundleIDVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "Kiểm tra phiên bản iOS", isOn: Binding(
                                get: { isiOSVersionVerificationEnabled },
                                set: { newValue in
                                    isiOSVersionVerificationEnabled = newValue
                                    UserDefaults.standard.isiOSVersionVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "Kiểm tra phiên bản ứng dụng", isOn: Binding(
                                get: { isAppVersionVerificationEnabled },
                                set: { newValue in
                                    isAppVersionVerificationEnabled = newValue
                                    UserDefaults.standard.isAppVersionVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "Kiểm tra mã băm (SHA-256)", isOn: Binding(
                                get: { isChecksumVerificationEnabled },
                                set: { newValue in
                                    isChecksumVerificationEnabled = newValue
                                    UserDefaults.standard.isChecksumVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "Kiểm tra dung lượng tệp ứng dụng", isOn: Binding(
                                get: { isFileSizeVerificationEnabled },
                                set: { newValue in
                                    isFileSizeVerificationEnabled = newValue
                                    UserDefaults.standard.isFileSizeVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "Kiểm tra quyền truy cập ứng dụng", isOn: Binding(
                                get: { !permissionCheckingDisabled },
                                set: { newValue in
                                    permissionCheckingDisabled = !newValue
                                    UserDefaults.standard.permissionCheckingDisabled = !newValue
                                }
                            ))
                        }
                        .disabled(appVerificationDisabled)
                        .opacity(appVerificationDisabled ? 0.45 : 1.0)
                    }
                }

                // Section 4: EMPROXY & WIREGUARD
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "EMPROXY & WIREGUARD", icon: "network.badge.shield.half.filled")
                    
                    sectionCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Xuất cấu hình WireGuard")
                                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                    .foregroundColor(CustomizationsCSSTheme.darkText)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("Xuất tệp SideStore.conf để nhập vào ứng dụng WireGuard VPN")
                                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                    .foregroundColor(CustomizationsCSSTheme.secondaryText)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer()
                            SwiftUI.Button(action: { exportWireGuardConfig() }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(CustomizationsCSSTheme.primaryBlue.opacity(0.14))
                                        .frame(width: 44, height: 40)
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(CustomizationsCSSTheme.primaryBlue)
                                }
                            }
                            .buttonStyle(CustomizationsBounceButtonStyle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(minHeight: 54)
                        
                        divider
                        
                        toggleRow(
                            title: "Máy chủ EMProxy (WireGuard)",
                            subtitle: "Cần khởi động lại ứng dụng để áp dụng thay đổi",
                            isOn: Binding(
                                get: { enableEMPforWireguard },
                                set: { newValue in
                                    pendingEMPOption = newValue
                                    showEMPRestartConfirmation = true
                                }
                            )
                        )
                    }
                }

                // Section 5: LÀM MỚI QUA 4G (CELLULAR REFRESH)
                cellularRefreshShortcutsSection

                // Section 6: MINIMUXER BACKEND
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "MINIMUXER BACKEND", icon: "cpu.fill")
                    
                    sectionCard {
                        ForEach(GatewayBackend.allCases, id: \.self) { backend in
                            SwiftUI.Button(action: {
                                if selectedBackend != backend {
                                    if UserDefaults.standard.isMinimuxerBackendHotswapEnabled {
                                        applyBackendChange(backend, restartRequired: false)
                                    } else {
                                        pendingBackendOption = backend
                                        showBackendRestartConfirmation = true
                                    }
                                }
                            }) {
                                HStack {
                                    Text(backend.rawValue)
                                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                        .foregroundColor(CustomizationsCSSTheme.darkText)
                                    Spacer()
                                    if selectedBackend == backend {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(CustomizationsCSSTheme.primaryBlue)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(CustomizationsBounceButtonStyle())
                            if backend != GatewayBackend.allCases.last {
                                divider
                            }
                        }
                    }
                }

                // Section 7: DỊCH VỤ CHẠY NỀN
                VStack(alignment: .leading, spacing: 8) {
                    sectionHeader(title: "DỊCH VỤ CHẠY NỀN", icon: "clock.arrow.2.circlepath")
                    
                    sectionCard {
                        toggleRow(title: "Bật duy trì hoạt động dưới nền", isOn: Binding(
                            get: { isBackgroundServiceEnabled },
                            set: { newValue in
                                isBackgroundServiceEnabled = newValue
                                BackgroundServiceManager.setEnabled(newValue)
                            }
                        ))
                        
                        divider
                        
                        ForEach(BackgroundServiceMode.allCases, id: \.self) { mode in
                            SwiftUI.Button(action: {
                                selectedBackgroundServiceMode = mode
                                BackgroundServiceManager.switchTo(mode: mode)
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(mode.displayName)
                                            .font(.system(size: 16.5, weight: .bold, design: .rounded))
                                            .foregroundColor(isBackgroundServiceEnabled ? CustomizationsCSSTheme.darkText : CustomizationsCSSTheme.darkText.opacity(0.4))
                                        Text(mode.subtitle)
                                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                                            .foregroundColor(isBackgroundServiceEnabled ? CustomizationsCSSTheme.secondaryText : CustomizationsCSSTheme.secondaryText.opacity(0.4))
                                    }
                                    Spacer()
                                    if selectedBackgroundServiceMode == mode {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(isBackgroundServiceEnabled ? CustomizationsCSSTheme.primaryBlue : CustomizationsCSSTheme.darkText.opacity(0.3))
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                            }
                            .buttonStyle(CustomizationsBounceButtonStyle())
                            .disabled(!isBackgroundServiceEnabled)
                            
                            if mode != BackgroundServiceMode.allCases.last {
                                divider
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(CustomizationsCSSTheme.pageBackgroundGradient.ignoresSafeArea())
        .navigationTitle("Tùy Chỉnh Người Dùng")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .alert("Cần Khởi Động Lại", isPresented: $showAnisetteRestartConfirmation) {
            SwiftUI.Button("Khởi động lại ngay", role: .destructive) {
                Task {
                    await AuthManager.shared.signOut(keepCertificate: true, keepAnisetteData: false)
                    UserDefaults.standard.useOnDeviceAnisette = useOnDeviceAnisette
                    exit(0)
                }
            }
            SwiftUI.Button("Huỷ", role: .cancel) {
                useOnDeviceAnisette = UserDefaults.standard.useOnDeviceAnisette
            }
        } message: {
            Text("Việc thay đổi cấu hình Anisette sẽ làm mất hiệu lực dữ liệu Anisette hiện tại và tài khoản của bạn sẽ được đăng xuất.\n\nThao tác này yêu cầu khởi động lại ứng dụng, bạn có muốn tiếp tục không?")
        }
        .alert("Cần Khởi Động Lại", isPresented: $showEMPRestartConfirmation) {
            SwiftUI.Button("Khởi động lại ngay", role: .destructive) {
                enableEMPforWireguard = pendingEMPOption
                UserDefaults.standard.enableEMPforWireguard = pendingEMPOption
                exit(0)
            }
            SwiftUI.Button("Huỷ", role: .cancel) {}
        } message: {
            Text("Thay đổi cài đặt EMProxy yêu cầu khởi động lại SideStore. Nếu nhấn Huỷ, thay đổi sẽ không được lưu.")
        }
        .alert("Cần Khởi Động Lại", isPresented: $showBackendRestartConfirmation) {
            SwiftUI.Button("Khởi động lại ngay", role: .destructive) {
                if let newBackend = pendingBackendOption {
                    applyBackendChange(newBackend, restartRequired: true)
                }
            }
            SwiftUI.Button("Huỷ", role: .cancel) {
                pendingBackendOption = nil
            }
        } message: {
            Text("Thay đổi Minimuxer backend yêu cầu khởi động lại SideStore. Nếu nhấn Huỷ, thay đổi sẽ không được lưu.")
        }
        .alert(pendingPreferIPAOngoing ? "Ưu tiên IPA đã ký lại" : "Ưu tiên Gói ứng dụng (App Bundle)", isPresented: $showPreferIPAToggleAlert) {
            SwiftUI.Button("Chuyển đổi") {
                preferResignedIPA = pendingPreferIPAOngoing
                UserDefaults.standard.preferResignedIPA = pendingPreferIPAOngoing
            }
            SwiftUI.Button("Huỷ", role: .cancel) {
                pendingPreferIPAOngoing = preferResignedIPA
            }
        } message: {
            if pendingPreferIPAOngoing {
                Text("Chuyển sang IPA đã ký lại giúp ưu tiên tốc độ cài đặt (nhanh hơn ~40%) bằng cách đóng gói tệp IPA không nén để truyền tải nhanh, nhưng sẽ tạm thời tốn thêm dung lượng bộ nhớ trong lúc đóng gói.")
            } else {
                Text("Chuyển sang Gói ứng dụng (App Bundle) giúp tiết kiệm dung lượng bộ nhớ bằng cách truyền trực tiếp thư mục ứng dụng mà không tạo tệp IPA tạm thời, nhưng tốc độ truyền tải sẽ chậm hơn đáng kể.")
            }
        }
        .sheet(isPresented: Binding<Bool>(
            get: { wireGuardExportURL != nil },
            set: { if !$0 { wireGuardExportURL = nil } }
        )) {
            if let url = wireGuardExportURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .alert(
            editDialog?.title ?? "",
            isPresented: Binding<Bool>(
                get: { editDialog != nil },
                set: { if !$0 { editDialog = nil } }
            )
        ) {
            TextField(editDialog?.placeholder ?? "", text: $editingValueText)
                #if !os(tvOS)
                .keyboardType(editDialog?.keyboardType ?? .default)
                #endif
            SwiftUI.Button("Lưu") {
                if let dialog = editDialog {
                    dialog.onSave(editingValueText)
                }
                editDialog = nil
            }
            SwiftUI.Button("Huỷ", role: .cancel) {
                editDialog = nil
            }
        } message: {
            Text(editDialog?.message ?? "")
        }
        .task {
            isFreeAccount = (try? await AuthManager.shared.getAuthenticatedTeam())?.type == .free
        }
    }

    // MARK: - Thành phần giao diện chuẩn CSS

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CustomizationsCSSTheme.primaryBlue)
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(CustomizationsCSSTheme.primaryPurple)
        }
        .padding(.horizontal, 12)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(CustomizationsCSSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(CustomizationsCSSTheme.border, lineWidth: 1.5)
        )
        .shadow(color: CustomizationsCSSTheme.shadow, radius: 14, x: 0, y: 8)
    }

    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    .foregroundColor(CustomizationsCSSTheme.darkText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(CustomizationsCSSTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(CustomizationsCSSTheme.primaryGreen)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: 52)
    }

    private func textFieldRow(
        title: String,
        subtitle: String? = nil,
        placeholder: String,
        value: String,
        unit: String? = nil,
        onTap: @escaping () -> Void
    ) -> some View {
        SwiftUI.Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                        .foregroundColor(CustomizationsCSSTheme.darkText)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .medium, design: .rounded))
                            .foregroundColor(CustomizationsCSSTheme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack {
                    Text(value.isEmpty ? placeholder : (unit != nil ? "\(value) \(unit!)" : value))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(value.isEmpty ? CustomizationsCSSTheme.secondaryText.opacity(0.6) : CustomizationsCSSTheme.primaryBlue)
                    Spacer()
                    Image(systemName: "pencil.line")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(CustomizationsCSSTheme.primaryPurple.opacity(0.75))
                }
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(CustomizationsCSSTheme.innerFieldBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(CustomizationsCSSTheme.border, lineWidth: 1)
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(CustomizationsBounceButtonStyle())
    }

    @ViewBuilder
    private var cellularRefreshShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "LÀM MỚI QUA 4G (CELLULAR REFRESH)", icon: "antenna.radiowaves.left.and.right")

            sectionCard {
                toggleRow(
                    title: "Làm mới qua 4G (Cellular Refresh)",
                    subtitle: "Tự động bật/tắt dữ liệu di động qua Phím tắt trong quá trình làm mới",
                    isOn: Binding(
                        get: { isCellularRefreshEnabled },
                        set: { newValue in
                            isCellularRefreshEnabled = newValue
                            CellularRefreshManager.shared.setEnabled(newValue)
                        }
                    )
                )

                divider

                textFieldRow(
                    title: "Phím tắt Bật 4G",
                    subtitle: "Tên của phím tắt trong ứng dụng Phím tắt (Shortcuts) của Apple",
                    placeholder: AppConstants.Shortcuts.defaultTurnOnDataShortcutName,
                    value: turnOnDataShortcutName,
                    onTap: openTurnOnShortcutDialog
                )

                divider

                textFieldRow(
                    title: "Phím tắt Tắt 4G",
                    subtitle: "Tên của phím tắt trong ứng dụng Phím tắt (Shortcuts) của Apple",
                    placeholder: AppConstants.Shortcuts.defaultTurnOffDataShortcutName,
                    value: turnOffDataShortcutName,
                    onTap: openTurnOffShortcutDialog
                )

                divider

                textFieldRow(
                    title: "Độ trễ cơ bản khi Bật 4G",
                    subtitle: "Thời gian chờ cơ bản sau khi bật dữ liệu di động (giây, ≥ 0)",
                    placeholder: String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay),
                    value: turnOnBaseDelayText,
                    unit: "giây",
                    onTap: openTurnOnBaseDelayDialog
                )

                divider

                textFieldRow(
                    title: "Độ trễ cơ bản khi Tắt 4G",
                    subtitle: "Thời gian chờ cơ bản sau khi tắt dữ liệu di động (giây, ≥ 0)",
                    placeholder: String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay),
                    value: turnOffBaseDelayText,
                    unit: "giây",
                    onTap: openTurnOffBaseDelayDialog
                )

                divider

                SwiftUI.Button(action: resetCellularDefaults) {
                    HStack {
                        Spacer()
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CustomizationsCSSTheme.primaryRed)
                        Text("Khôi phục về Mặc định")
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundColor(CustomizationsCSSTheme.primaryRed)
                        Spacer()
                    }
                    .padding(.vertical, 13)
                }
                .buttonStyle(CustomizationsBounceButtonStyle())
            }
        }
    }

    private func openTurnOnShortcutDialog() {
        editingValueText = turnOnDataShortcutName
        editDialog = EditDialogState(
            title: "Phím tắt Bật 4G",
            message: "Nhập tên của phím tắt trong ứng dụng Phím tắt (Shortcuts) của Apple",
            placeholder: AppConstants.Shortcuts.defaultTurnOnDataShortcutName,
            keyboardType: .default,
            onSave: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolved = trimmed.isEmpty ? AppConstants.Shortcuts.defaultTurnOnDataShortcutName : trimmed
                let sanitized = CellularRefreshManager.sanitizeShortcutName(resolved, fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
                turnOnDataShortcutName = sanitized
                CellularRefreshManager.shared.setTurnOnDataShortcutName(sanitized)
            }
        )
    }

    private func openTurnOffShortcutDialog() {
        editingValueText = turnOffDataShortcutName
        editDialog = EditDialogState(
            title: "Phím tắt Tắt 4G",
            message: "Nhập tên của phím tắt trong ứng dụng Phím tắt (Shortcuts) của Apple",
            placeholder: AppConstants.Shortcuts.defaultTurnOffDataShortcutName,
            keyboardType: .default,
            onSave: { newValue in
                let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let resolved = trimmed.isEmpty ? AppConstants.Shortcuts.defaultTurnOffDataShortcutName : trimmed
                let sanitized = CellularRefreshManager.sanitizeShortcutName(resolved, fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
                turnOffDataShortcutName = sanitized
                CellularRefreshManager.shared.setTurnOffDataShortcutName(sanitized)
            }
        )
    }

    private func openTurnOnBaseDelayDialog() {
        editingValueText = turnOnBaseDelayText
        editDialog = EditDialogState(
            title: "Độ trễ cơ bản khi Bật 4G",
            message: "Thời gian chờ cơ bản sau khi bật dữ liệu di động (giây, ≥ 0)",
            placeholder: String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay),
            keyboardType: .decimalPad,
            onSave: { newValue in
                let filtered = newValue.filter { "0123456789.".contains($0) }
                if let delay = Double(filtered), delay >= 0 {
                    turnOnBaseDelayText = String(delay)
                    CellularRefreshManager.shared.setTurnOnDataBaseDelayOverride(delay)
                } else {
                    turnOnBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay)
                    CellularRefreshManager.shared.setTurnOnDataBaseDelayOverride(nil)
                }
            }
        )
    }

    private func openTurnOffBaseDelayDialog() {
        editingValueText = turnOffBaseDelayText
        editDialog = EditDialogState(
            title: "Độ trễ cơ bản khi Tắt 4G",
            message: "Thời gian chờ cơ bản sau khi tắt dữ liệu di động (giây, ≥ 0)",
            placeholder: String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay),
            keyboardType: .decimalPad,
            onSave: { newValue in
                let filtered = newValue.filter { "0123456789.".contains($0) }
                if let delay = Double(filtered), delay >= 0 {
                    turnOffBaseDelayText = String(delay)
                    CellularRefreshManager.shared.setTurnOffDataBaseDelayOverride(delay)
                } else {
                    turnOffBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay)
                    CellularRefreshManager.shared.setTurnOffDataBaseDelayOverride(nil)
                }
            }
        )
    }

    private func resetCellularDefaults() {
        CellularRefreshManager.shared.resetToDefaults()
        turnOnDataShortcutName = AppConstants.Shortcuts.defaultTurnOnDataShortcutName
        turnOffDataShortcutName = AppConstants.Shortcuts.defaultTurnOffDataShortcutName
        turnOnBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOnDataBaseDelay)
        turnOffBaseDelayText = String(AppConstants.Shortcuts.defaultTurnOffDataBaseDelay)
    }

    private var customizeAppExtensionsBinding: Binding<AppExtensionCustomization> {
        Binding<AppExtensionCustomization>(
            get: { customizeAppExtensions },
            set: { newValue in
                customizeAppExtensions = newValue
                UserDefaults.standard.customizeAppExtensions = newValue
            }
        )
    }

    private var appImportSourceModeBinding: Binding<AppImportSourceMode> {
        Binding<AppImportSourceMode>(
            get: { appImportSourceMode },
            set: { newValue in
                appImportSourceMode = newValue
                UserDefaults.standard.appImportSourceMode = newValue
            }
        )
    }

    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "CÀI ĐẶT CHUNG", icon: "gearshape.2.fill")
            
            sectionCard {
                toggleRow(title: "Tùy chỉnh Info.plist", isOn: Binding(
                    get: { customizeInfoPlist },
                    set: { newValue in
                        customizeInfoPlist = newValue
                        UserDefaults.standard.customizeInfoPlist = newValue
                    }
                ))
                
                divider
                
                toggleRow(title: "Tùy chỉnh AppID", isOn: Binding(
                    get: { customizeInfoPlist ? true : customizeAppId },
                    set: { newValue in
                        customizeAppId = newValue
                        UserDefaults.standard.customizeAppId = newValue
                    }
                ))
                .disabled(customizeInfoPlist)
                .opacity(customizeInfoPlist ? 0.45 : 1.0)
                
                divider
                
                HStack {
                    Text("Tùy chỉnh Tiện ích mở rộng (Extensions)")
                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                        .foregroundColor(CustomizationsCSSTheme.darkText)
                    Spacer()
                    Picker("", selection: customizeAppExtensionsBinding) {
                        ForEach(AppExtensionCustomization.allCases) { (option: AppExtensionCustomization) in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CustomizationsCSSTheme.primaryBlue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 52)
                
                divider
                
                HStack {
                    Text("Chế độ nhập tệp mặc định")
                        .font(.system(size: 16.5, weight: .bold, design: .rounded))
                        .foregroundColor(CustomizationsCSSTheme.darkText)
                    Spacer()
                    Picker("", selection: appImportSourceModeBinding) {
                        ForEach(AppImportSourceMode.allCases) { (option: AppImportSourceMode) in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(CustomizationsCSSTheme.primaryBlue)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 52)
                
                divider

                toggleRow(
                    title: "Xác nhận trước khi cài đặt ứng dụng",
                    subtitle: "Hiển thị hộp thoại xác nhận trước khi cài đặt hoặc nhập tệp ứng dụng",
                    isOn: Binding(
                        get: { isInstallConfirmationEnabled },
                        set: { newValue in
                            isInstallConfirmationEnabled = newValue
                            UserDefaults.standard.isInstallConfirmationEnabled = newValue
                        }
                    )
                )
                
                divider

                toggleRow(
                    title: "Xoá tùy chỉnh khi gỡ cài đặt",
                    subtitle: "Đặt lại hồ sơ cấp phép, chứng chỉ tùy chỉnh và dữ liệu phụ khi xoá ứng dụng",
                    isOn: Binding(
                        get: { isClearCustomizationsOnUninstallEnabled },
                        set: { newValue in
                            isClearCustomizationsOnUninstallEnabled = newValue
                            UserDefaults.standard.isClearCustomizationsOnUninstallEnabled = newValue
                        }
                    )
                )
                
                divider

                toggleRow(
                    title: "Tự động mở ứng dụng sau khi cài xong",
                    subtitle: "Tự động khởi chạy ứng dụng ngay sau khi quá trình cài đặt hoàn tất",
                    isOn: Binding(
                        get: { isAutoLaunchAppAfterInstallEnabled },
                        set: { newValue in
                            isAutoLaunchAppAfterInstallEnabled = newValue
                            UserDefaults.standard.isAutoLaunchAppAfterInstallEnabled = newValue
                        }
                    )
                )
                
                divider
                
                toggleRow(title: "Tùy chỉnh Quyền hạn (Entitlements)", isOn: Binding(
                    get: { customizeEntitlements },
                    set: { newValue in
                        customizeEntitlements = newValue
                        UserDefaults.standard.customizeEntitlements = newValue
                    }
                ))
                
                divider
                
                toggleRow(
                    title: "Tự động sửa AppGroup ID",
                    subtitle: isFreeAccount ? "Bắt buộc đối với tài khoản nhà phát triển miễn phí" : "Tự động sửa lỗi lệch chữ hoa/thường trong App Group",
                    isOn: Binding(
                        get: { isFreeAccount ? true : autoFixAppGroupIDs },
                        set: { newValue in
                            guard !isFreeAccount else { return }
                            autoFixAppGroupIDs = newValue
                            UserDefaults.standard.autoFixAppGroupIDs = newValue
                        }
                    )
                )
                .disabled(isFreeAccount)

                divider

                toggleRow(
                    title: "Tùy chỉnh Biểu tượng ứng dụng (Icon)",
                    subtitle: "Hỏi chọn biểu tượng tùy chỉnh trước khi cài đặt",
                    isOn: Binding(
                        get: { customizeAppIcon },
                        set: { newValue in
                            customizeAppIcon = newValue
                            UserDefaults.standard.customizeAppIcon = newValue
                        }
                    )
                )

                divider

                toggleRow(
                    title: "Tùy chỉnh Hồ sơ cấp phép (Provisioning Profile)",
                    subtitle: "Hỏi chọn hồ sơ cấp phép trước khi cài đặt",
                    isOn: Binding(
                        get: { customizeProvisioningProfile },
                        set: { newValue in
                            customizeProvisioningProfile = newValue
                            UserDefaults.standard.customizeProvisioningProfile = newValue
                        }
                    )
                )
                
                divider
                
                toggleRow(
                    title: "Ưu tiên tệp IPA đã ký lại",
                    subtitle: "Ưu tiên tốc độ cài đặt (IPA) so với tiết kiệm bộ nhớ (App Bundle)",
                    isOn: Binding(
                        get: { preferResignedIPA },
                        set: { newValue in
                            pendingPreferIPAOngoing = newValue
                            showPreferIPAToggleAlert = true
                        }
                    )
                )
                
                divider
                
                toggleRow(title: "Cho phép xuất tệp IPA đã ký lại", isOn: Binding(
                    get: { isExportResignedAppEnabled },
                    set: { newValue in
                        isExportResignedAppEnabled = newValue
                        UserDefaults.standard.isExportResignedAppEnabled = newValue
                    }
                ))
                
                divider
                
                toggleRow(title: "Bỏ qua các tệp sao lưu không thể sao chép", isOn: Binding(
                    get: { skipNonCopyableFiles },
                    set: { newValue in
                        skipNonCopyableFiles = newValue
                        UserDefaults.standard.skipNonCopyableBackupFiles = newValue
                    }
                ))
                
                divider
                
                toggleRow(
                    title: "Ưu tiên mở bảng trượt (Sheet) cho Info.plist",
                    subtitle: "Sử dụng bảng trượt thay vì hộp thoại nhỏ",
                    isOn: Binding(
                        get: { preferSheetForInfoPlistCustomization },
                        set: { newValue in
                            preferSheetForInfoPlistCustomization = newValue
                            UserDefaults.standard.preferSheetForInfoPlistCustomization = newValue
                        }
                    )
                )
                .disabled(!customizeInfoPlist)
                .opacity(!customizeInfoPlist ? 0.45 : 1.0)
                
                divider
                
                toggleRow(
                    title: "Ưu tiên mở bảng trượt (Sheet) cho Entitlements",
                    subtitle: "Sử dụng bảng trượt thay vì hộp thoại nhỏ",
                    isOn: Binding(
                        get: { preferSheetForEntitlementsCustomization },
                        set: { newValue in
                            preferSheetForEntitlementsCustomization = newValue
                            UserDefaults.standard.preferSheetForEntitlementsCustomization = newValue
                        }
                    )
                )
                .disabled(!customizeEntitlements)
                .opacity(!customizeEntitlements ? 0.45 : 1.0)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(CustomizationsCSSTheme.border)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private func exportWireGuardConfig() {
        guard let url = Bundle.main.url(forResource: "SideStore", withExtension: "conf") else {
            if let top = UIApplication.shared.topViewController() {
                let toastView = ToastView(text: "Thiếu tệp SideStore.conf!", detailText: "Không tìm thấy tệp SideStore.conf trong tài nguyên ứng dụng.")
                toastView.show(in: top)
            }
            return
        }
        wireGuardExportURL = url
    }

    private func presentResetAdiDialog() {
        guard let top = UIApplication.shared.topViewController() else { return }
        let alertController = UIAlertController(
            title: "Đặt lại adi.pb",
            message: "Thao tác này sẽ đăng xuất Apple ID của bạn khỏi SideStore và xoá dữ liệu adi.pb đã cấp phép khỏi Keychain. Chứng chỉ ký hiện tại của bạn vẫn sẽ được giữ nguyên.",
            preferredStyle: .alert
        )
        let contentVC = ResetAdiAlertViewController()
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: "Huỷ", style: .cancel, handler: nil)
        let resetAction = UIAlertAction(title: "Đặt lại & Đăng xuất", style: .destructive) { _ in
            let keepHeaders = contentVC.isKeepHeadersChecked
            Task {
                await AuthManager.shared.signOut(keepCertificate: true, keepAnisetteData: false, keepAnisetteHeaders: keepHeaders)
                debugLog("Reset adi.pb (keepAnisetteHeaders: \(keepHeaders)) and signed out")
                if let topVC = UIApplication.shared.topViewController() {
                    let detail = keepHeaders
                        ? "Đã đăng xuất Apple ID. Bây giờ bạn có thể đăng nhập lại với dữ liệu cấp phép mới."
                        : "Đã đăng xuất Apple ID. Đã đặt lại adi.pb và cấu hình header về mặc định."
                    ToastView(
                        text: "Đã xoá adi.pb!",
                        detailText: detail
                    ).show(in: topVC)
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(resetAction)
        top.present(alertController, animated: true, completion: nil)
    }

    private func applyBackendChange(_ newBackend: GatewayBackend, restartRequired: Bool) {
        selectedBackend = newBackend
        selectedGatewayBackendCache = newBackend
        UserDefaults.standard.minimuxerGatewayBackend = newBackend.rawValue
        UserDefaults.standard.synchronize()
        if restartRequired {
            exit(0)
        } else {
            syncMinimuxerBackendFromUserDefaults()
        }
    }
}
