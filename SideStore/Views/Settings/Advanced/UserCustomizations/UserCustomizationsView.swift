
//
//  UserCustomizationsView.swift
//  SideStore
//
//  Created by Magesh K on 8/2/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import Minimuxer

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TAB CÀI ĐẶT)
private enum CustomizationsCSSTheme {
    static let white = Color.white
    static let light = Color(red: 248/255, green: 249/255, blue: 250/255)               // #f8f9fa
    static let border = Color(red: 233/255, green: 236/255, blue: 239/255)              // #e9ecef
    static let blue = Color(red: 0/255, green: 123/255, blue: 255/255)                  // #007bff
    static let purple = Color(red: 111/255, green: 66/255, blue: 193/255)               // #6f42c1
    static let green = Color(red: 40/255, green: 167/255, blue: 69/255)                 // #28a745
    static let magenta = Color(red: 255/255, green: 0/255, blue: 255/255)               // #ff00ff
    static let red = Color(red: 220/255, green: 53/255, blue: 69/255)                   // #dc3545
    static let darkText = Color(red: 52/255, green: 58/255, blue: 64/255)               // #343a40
    static let secondaryText = Color(red: 52/255, green: 58/255, blue: 64/255).opacity(0.75)

    // Gradient Background (#f3e0ff -> #e0f7ff) giống hệt CSSGradientBackgroundView
    static let bgGradientStart = Color(red: 243/255, green: 224/255, blue: 255/255)
    static let bgGradientEnd = Color(red: 224/255, green: 247/255, blue: 255/255)

    static var pageBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Hero Banner Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88))
    static let heroStart = Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.92)
    static let heroEnd = Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.88)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [heroStart, heroEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let cornerRadius: CGFloat = 15.0
    static let cardShadow = Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.08)
}

// MARK: - Hiệu ứng nhấn nút thu nhỏ mượt mà chuẩn Tab Cài đặt
private struct CustomizationsBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

struct UserCustomizationsView: View {
    @State private var selectedBackend: GatewayBackend = selectedGatewayBackendCache
    @State private var useOnDeviceAnisette: Bool = UserDefaults.standard.useOnDeviceAnisette
    @State private var showAnisetteRestartConfirmation: Bool = false
    @State private var customizeInfoPlist: Bool = UserDefaults.standard.customizeInfoPlist
    @State private var customizeAppId: Bool = UserDefaults.standard.customizeAppId
    @State private var customizeAppIcon: Bool = UserDefaults.standard.customizeAppIcon
    @State private var customizeAppExtensions: AppExtensionCustomization = UserDefaults.standard.customizeAppExtensions
    @State private var appImportSourceMode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode
    @State private var isInstallConfirmationEnabled: Bool = UserDefaults.standard.isInstallConfirmationEnabled
    @State private var isClearCustomizationsOnUninstallEnabled: Bool = UserDefaults.standard.isClearCustomizationsOnUninstallEnabled
    @State private var isAutoLaunchAppAfterInstallEnabled: Bool = UserDefaults.standard.isAutoLaunchAppAfterInstallEnabled
    @State private var autoFixAppGroupIDs: Bool = UserDefaults.standard.autoFixAppGroupIDs
    @State private var pendingBackendOption: GatewayBackend? = nil
    @State private var showBackendRestartConfirmation: Bool = false
    @State private var appVerificationDisabled: Bool = UserDefaults.standard.appVerificationDisabled
    @State private var isBundleIDVerificationEnabled: Bool = UserDefaults.standard.isBundleIDVerificationEnabled
    @State private var isiOSVersionVerificationEnabled: Bool = UserDefaults.standard.isiOSVersionVerificationEnabled
    @State private var isAppVersionVerificationEnabled: Bool = UserDefaults.standard.isAppVersionVerificationEnabled
    @State private var permissionCheckingDisabled: Bool = UserDefaults.standard.permissionCheckingDisabled
    @State private var isCellularRefreshEnabled: Bool = UserDefaults.standard.isCellularRefreshEnabled
    @State private var turnOnDataShortcutName: String = UserDefaults.standard.turnOnDataShortcutName
    @State private var turnOffDataShortcutName: String = UserDefaults.standard.turnOffDataShortcutName

    @State private var isFreeAccount: Bool = false
    @State private var animateHero: Bool = false

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
            VStack(alignment: .leading, spacing: 20) {
                // Khối Hero Banner đồng bộ với Tab Cài đặt
                heroBannerView

                // Section 1: DỮ LIỆU ĐỊNH DANH ANISETTE
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "DỮ LIỆU ĐỊNH DANH ANISETTE")
                    
                    sectionCard {
                        toggleRow(
                            title: "Anisette trực tiếp trên thiết bị",
                            subtitle: "Chạy trình giả lập định danh ngay trên máy thay vì dùng máy chủ từ xa",
                            isOn: Binding(
                                get: { useOnDeviceAnisette },
                                set: { newValue in
                                    useOnDeviceAnisette = newValue
                                    showAnisetteRestartConfirmation = true
                                }
                            )
                        )
                        
                        divider
                        
                        SwiftUI.Button(role: .destructive) {
                            presentResetAdiDialog()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Đặt lại dữ liệu adi.pb")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(CustomizationsCSSTheme.magenta)
                                    Text("Xoá dữ liệu cấp phép Anisette cục bộ khỏi Chuỗi khóa bảo mật")
                                        .font(.system(size: 12.5, weight: .regular))
                                        .foregroundColor(CustomizationsCSSTheme.secondaryText)
                                }
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(CustomizationsCSSTheme.magenta.opacity(0.12))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "trash.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(CustomizationsCSSTheme.magenta)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(minHeight: 54)
                        }
                        .buttonStyle(CustomizationsBounceButtonStyle())
                    }
                }

                // Section 2: CÀI ĐẶT CHUNG
                generalSection

                // Section 3: XÁC MINH ỨNG DỤNG
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "XÁC MINH ỨNG DỤNG")
                    
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
                            toggleRow(title: "Kiểm tra Mã định danh gói (ID ứng dụng)", isOn: Binding(
                                get: { isBundleIDVerificationEnabled },
                                set: { newValue in
                                    isBundleIDVerificationEnabled = newValue
                                    UserDefaults.standard.isBundleIDVerificationEnabled = newValue
                                }
                            ))
                            
                            divider
                            
                            toggleRow(title: "Kiểm tra phiên bản hệ điều hành iOS", isOn: Binding(
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

                // Section 4: LÀM MỚI QUA MẠNG DI ĐỘNG (4G/5G)
                cellularRefreshShortcutsSection

                // Section 5: NHÂN KẾT NỐI MINIMUXER
                VStack(alignment: .leading, spacing: 10) {
                    sectionHeader(title: "NHÂN KẾT NỐI MINIMUXER")
                    
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
                                    Text(localizedBackendTitle(backend.rawValue))
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(CustomizationsCSSTheme.darkText)
                                    Spacer()
                                    if selectedBackend == backend {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 18, weight: .bold))
                                            .foregroundColor(CustomizationsCSSTheme.blue)
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
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 50)
        }
        .background(CustomizationsCSSTheme.pageBackgroundGradient.ignoresSafeArea())
        .navigationTitle("")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animateHero = true
            }
        }
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
            Text("Thay đổi nhân kết nối Minimuxer yêu cầu khởi động lại SideStore. Nếu nhấn Huỷ, thay đổi sẽ không được lưu.")
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

    // MARK: - 🌈 HERO BANNER CHUẨN TAB CÀI ĐẶT
    private var heroBannerView: some View {
        VStack(spacing: 4) {
            Text("Tùy chỉnh của người dùng")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(CustomizationsCSSTheme.white)
                .multilineTextAlignment(.center)
                .shadow(color: Color.black.opacity(0.35), radius: 4, x: 1, y: 2)

            Text("Thiết lập chuyên sâu quy trình cài đặt, xác minh và làm mới ứng dụng")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(CustomizationsCSSTheme.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(CustomizationsCSSTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: CustomizationsCSSTheme.cornerRadius, style: .continuous))
        .shadow(color: CustomizationsCSSTheme.blue.opacity(0.25), radius: 16, x: 0, y: 6)
        .opacity(animateHero ? 1.0 : 0.0)
        .offset(y: animateHero ? 0 : -10)
    }

    // MARK: - 🧩 THÀNH PHẦN GIAO DIỆN CHUẨN CSS TAB CÀI ĐẶT

    private func sectionHeader(title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(CustomizationsCSSTheme.blue)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(CustomizationsCSSTheme.blue)
                .frame(width: 38, height: 3)
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(CustomizationsCSSTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: CustomizationsCSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CustomizationsCSSTheme.cornerRadius, style: .continuous)
                .stroke(CustomizationsCSSTheme.border, lineWidth: 1.0)
        )
        .shadow(color: CustomizationsCSSTheme.cardShadow, radius: 10, x: 0, y: 5)
    }

    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CustomizationsCSSTheme.darkText)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundColor(CustomizationsCSSTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(CustomizationsCSSTheme.blue)
                .shadow(color: CustomizationsCSSTheme.blue.opacity(0.28), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(minHeight: 52)
    }

    // MARK: - 📶 LÀM MỚI QUA MẠNG DI ĐỘNG (4G/5G)
    @ViewBuilder
    private var cellularRefreshShortcutsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "LÀM MỚI QUA MẠNG DI ĐỘNG (4G/5G)")

            sectionCard {
                toggleRow(
                    title: "Làm mới qua mạng di động (4G/5G)",
                    subtitle: "Tự động bật/tắt dữ liệu di động qua ứng dụng Phím tắt trong quá trình gia hạn",
                    isOn: Binding(
                        get: { isCellularRefreshEnabled },
                        set: { newValue in
                            isCellularRefreshEnabled = newValue
                            CellularRefreshManager.shared.setEnabled(newValue)
                        }
                    )
                )

                divider

                VStack(alignment: .leading, spacing: 10) {
                    Text("2 phím tắt cần thiết để làm mới ứng dụng qua 4G:")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(CustomizationsCSSTheme.darkText)

                    HStack(spacing: 10) {
                        shortcutBadgeButton(
                            label: "Bật 4G",
                            shortcutName: turnOnDataShortcutName.isEmpty ? AppConstants.Shortcuts.defaultTurnOnDataShortcutName : turnOnDataShortcutName,
                            icon: "antenna.radiowaves.left.and.right",
                            action: openTurnOnShortcutDialog
                        )

                        shortcutBadgeButton(
                            label: "Tắt 4G",
                            shortcutName: turnOffDataShortcutName.isEmpty ? AppConstants.Shortcuts.defaultTurnOffDataShortcutName : turnOffDataShortcutName,
                            icon: "antenna.radiowaves.left.and.right.slash",
                            action: openTurnOffShortcutDialog
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    private func shortcutBadgeButton(
        label: String,
        shortcutName: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        SwiftUI.Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(CustomizationsCSSTheme.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CustomizationsCSSTheme.secondaryText)
                        .lineLimit(1)

                    Text(shortcutName)
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundColor(CustomizationsCSSTheme.blue)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Spacer(minLength: 2)

                Image(systemName: "pencil")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(CustomizationsCSSTheme.purple.opacity(0.75))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CustomizationsCSSTheme.light)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(CustomizationsCSSTheme.blue.opacity(0.32), lineWidth: 1.1)
            )
            .shadow(color: CustomizationsCSSTheme.purple.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(CustomizationsBounceButtonStyle())
    }

    private func openTurnOnShortcutDialog() {
        editingValueText = turnOnDataShortcutName
        editDialog = EditDialogState(
            title: "Tên phím tắt Bật mạng di động",
            message: "Nhập tên chính xác của phím tắt Bật 4G trong ứng dụng Phím tắt (mặc định: TurnOnData)",
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
            title: "Tên phím tắt Tắt mạng di động",
            message: "Nhập tên chính xác của phím tắt Tắt 4G trong ứng dụng Phím tắt (mặc định: TurnOffData)",
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

    // MARK: - ⚙️ CÀI ĐẶT CHUNG
    @ViewBuilder
    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "CÀI ĐẶT CHUNG")
            
            sectionCard {
                toggleRow(title: "Tùy chỉnh tệp cấu hình Info.plist", isOn: Binding(
                    get: { customizeInfoPlist },
                    set: { newValue in
                        customizeInfoPlist = newValue
                        UserDefaults.standard.customizeInfoPlist = newValue
                    }
                ))
                
                divider
                
                toggleRow(title: "Tùy chỉnh Mã định danh ứng dụng (ID)", isOn: Binding(
                    get: { customizeInfoPlist ? true : customizeAppId },
                    set: { newValue in
                        customizeAppId = newValue
                        UserDefaults.standard.customizeAppId = newValue
                    }
                ))
                .disabled(customizeInfoPlist)
                .opacity(customizeInfoPlist ? 0.45 : 1.0)
                
                divider
                
                // Nút chọn Tiện ích mở rộng dạng Viên thuốc (Capsule) mở rộng chứa trọn 1 hàng tiếng Việt
                HStack(spacing: 10) {
                    Text("Tùy chỉnh Tiện ích mở rộng")
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundColor(CustomizationsCSSTheme.darkText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 6)

                    Menu {
                        ForEach(AppExtensionCustomization.allCases) { option in
                            SwiftUI.Button {
                                customizeAppExtensions = option
                                UserDefaults.standard.customizeAppExtensions = option
                            } label: {
                                HStack {
                                    Text(localizedOptionTitle(option.displayName))
                                    if customizeAppExtensions == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        capsuleMenuButtonLabel(text: localizedOptionTitle(customizeAppExtensions.displayName))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 54)
                
                divider
                
                // Nút chọn Chế độ nhập tệp mặc định dạng Viên thuốc (Capsule) mở rộng chứa trọn 1 hàng tiếng Việt
                HStack(spacing: 10) {
                    Text("Chế độ nhập tệp mặc định")
                        .font(.system(size: 15.5, weight: .medium))
                        .foregroundColor(CustomizationsCSSTheme.darkText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 6)

                    Menu {
                        ForEach(AppImportSourceMode.allCases) { option in
                            SwiftUI.Button {
                                appImportSourceMode = option
                                UserDefaults.standard.appImportSourceMode = option
                            } label: {
                                HStack {
                                    Text(localizedOptionTitle(option.displayName))
                                    if appImportSourceMode == option {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        capsuleMenuButtonLabel(text: localizedOptionTitle(appImportSourceMode.displayName))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(minHeight: 54)
                
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
                
                toggleRow(
                    title: "Tự động sửa định danh Nhóm ứng dụng",
                    subtitle: isFreeAccount ? "Bắt buộc đối với tài khoản nhà phát triển miễn phí" : "Tự động sửa lỗi lệch chữ hoa/thường trong Nhóm ứng dụng",
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
                    title: "Tùy chỉnh Biểu tượng ứng dụng",
                    subtitle: "Hỏi chọn biểu tượng thay thế trước khi cài đặt",
                    isOn: Binding(
                        get: { customizeAppIcon },
                        set: { newValue in
                            customizeAppIcon = newValue
                            UserDefaults.standard.customizeAppIcon = newValue
                        }
                    )
                )
            }
        }
    }

    // Nhãn nút chọn kiểu viên thuốc tự động mở rộng chiều ngang để chứa trọn chữ tiếng Việt trên 1 hàng duy nhất
    private func capsuleMenuButtonLabel(text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(CustomizationsCSSTheme.blue)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(CustomizationsCSSTheme.blue)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .frame(minWidth: 148)
        .fixedSize(horizontal: true, vertical: false)
        .background(CustomizationsCSSTheme.light)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(CustomizationsCSSTheme.blue.opacity(0.35), lineWidth: 1.2)
        )
        .shadow(color: CustomizationsCSSTheme.purple.opacity(0.18), radius: 6, x: 0, y: 3)
    }

    private var divider: some View {
        Rectangle()
            .fill(CustomizationsCSSTheme.border)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }

    // MARK: - 🌐 BỘ TỪ ĐIỂN VIỆT HÓA CÁC TÙY CHỌN TIẾNG ANH ĐỘNG TỪ HỆ THỐNG
    private func localizedOptionTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let dictionary: [String: String] = [
            // AppExtensionCustomization & AppImportSourceMode
            "Prompt User": "Hỏi người dùng",
            "prompt user": "Hỏi người dùng",
            "Use Main Profile": "Dùng hồ sơ chính",
            "use main profile": "Dùng hồ sơ chính",
            "Ask": "Hỏi người dùng",
            "Always Ask": "Luôn hỏi",
            "Prompt": "Hỏi người dùng",
            "Keep": "Giữ nguyên",
            "Keep All": "Giữ tất cả",
            "Keep Extensions": "Giữ tiện ích",
            "Remove": "Xoá bỏ",
            "Remove All": "Xoá tất cả",
            "Remove Extensions": "Xoá tiện ích",
            "Register New": "Đăng ký hồ sơ mới",
            "Create Separate Profiles": "Tạo hồ sơ riêng",
            "Default": "Mặc định",
            "Automatic": "Tự động",
            "None": "Không dùng",
            "Off": "Tắt",
            "Disabled": "Đã tắt",
            "Enabled": "Đã bật",
            
            // AppImportSourceMode
            "Files": "Tệp (Files)",
            "File": "Tệp tin",
            "Files App": "Ứng dụng Tệp",
            "URL": "Liên kết URL",
            "Web URL": "Liên kết mạng",
            "Link": "Liên kết",
            "Both": "Hỏi người dùng"
        ]
        if let exactMatch = dictionary[trimmed] {
            return exactMatch
        }
        let lowercased = trimmed.lowercased()
        if lowercased == "prompt user" {
            return "Hỏi người dùng"
        }
        if lowercased == "use main profile" {
            return "Dùng hồ sơ chính"
        }
        return rawTitle
    }

    private func localizedBackendTitle(_ rawTitle: String) -> String {
        let trimmed = rawTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let dictionary: [String: String] = [
            "Legacy": "Cổ điển (Legacy)",
            "legacy": "Cổ điển (Legacy)",
            "Modern": "Hiện đại (Modern)",
            "modern": "Hiện đại (Modern)",
            "Default": "Mặc định",
            "Standard": "Tiêu chuẩn",
            "Native": "Nguyên bản (Native)",
            "Rust": "Nhân Rust",
            "C": "Nhân C",
            "Swift": "Nhân Swift",
            "idevice": "Giao thức idevice",
            "usbmuxd": "Giao thức usbmuxd"
        ]
        return dictionary[trimmed] ?? rawTitle
    }

    // MARK: - 🛠️ CÁC HÀM XỬ LÝ LOGIC HỆ THỐNG
    private func presentResetAdiDialog() {
        guard let top = UIApplication.shared.topViewController() else { return }
        let alertController = UIAlertController(
            title: "Đặt lại dữ liệu adi.pb",
            message: "Thao tác này sẽ đăng xuất ID Apple của bạn khỏi SideStore và xoá dữ liệu adi.pb đã cấp phép khỏi Chuỗi khóa bảo mật. Chứng chỉ ký hiện tại của bạn vẫn sẽ được giữ nguyên.",
            preferredStyle: .alert
        )
        let contentVC = ResetAdiAlertViewController()
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: "Huỷ", style: .cancel, handler: nil)
        let resetAction = UIAlertAction(title: "Đặt lại & Đăng xuất", style: .destructive) { _ in
            let keepHeaders = contentVC.isKeepHeadersChecked
            Task {
                await AuthManager.shared.signOut(keepCertificate: true, keepAnisetteData: false, keepAnisetteHeaders: keepHeaders)
                debugLog("Đã đặt lại adi.pb (giữ tiêu đề Anisette: \(keepHeaders)) và đăng xuất")
                if let topVC = UIApplication.shared.topViewController() {
                    let detail = keepHeaders
                        ? "Đã đăng xuất ID Apple. Bây giờ bạn có thể đăng nhập lại với dữ liệu cấp phép mới."
                        : "Đã đăng xuất ID Apple. Đã đặt lại adi.pb và cấu hình tiêu đề về mặc định."
                    ToastView(
                        text: "Đã xoá dữ liệu adi.pb!",
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
