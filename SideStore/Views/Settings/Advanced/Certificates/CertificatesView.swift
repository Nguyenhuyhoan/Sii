
//
//  CertificatesView.swift
//  SideStore
//
//  Created by Magesh K on 2026-06-29.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import SideSign
import UniformTypeIdentifiers

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TOÀN BỘ ỨNG DỤNG & CHỮ ĐEN TUYỀN)
private enum CertCSSTheme {
    static let white = Color.white
    static let pureBlack = Color.black                                              // #000000 (Chữ đen tuyền độ tương phản tuyệt đối)
    static let light = Color(red: 245/255, green: 248/255, blue: 255/255)           // #f5f8ff (Đồng bộ innerRowBackground)
    static let border = Color(red: 220/255, green: 226/255, blue: 236/255)          // #dce2ec (Viền chuẩn toàn hệ thống)
    static let innerBorder = Color(red: 222/255, green: 229/255, blue: 240/255)     // #dee5f0
    static let blue = Color(red: 0/255, green: 123/255, blue: 255/255)              // #007bff (--primary-blue)
    static let purple = Color(red: 111/255, green: 66/255, blue: 193/255)           // #6f42c1 (--primary-purple)
    static let green = Color(red: 40/255, green: 167/255, blue: 69/255)             // #28a745 (--primary-green)
    static let magenta = Color(red: 255/255, green: 0/255, blue: 255/255)           // #ff00ff
    static let dark = Color.black                                                   // #000000

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 243/255, green: 224/255, blue: 255/255),
            Color(red: 224/255, green: 247/255, blue: 255/255)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,255,.92))
    static let heroGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.95),
            Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.92)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Thanh gạch chân Gradient Xanh - Tím đồng bộ toàn hệ thống
    static let accentUnderlineGradient = LinearGradient(
        gradient: Gradient(colors: [blue, purple]),
        startPoint: .leading,
        endPoint: .trailing
    )

    static let cornerRadius: CGFloat = 18.0
    static let innerCornerRadius: CGFloat = 14.0
}

// MARK: - 🛠 MODIFIER ẨN NỀN MẶC ĐỊNH CỦA LIST / FORM ĐỂ HIỂN THỊ GRADIENT CSS
private struct ClearListBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 16.0, tvOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content.onAppear {
                UITableView.appearance().backgroundColor = .clear
            }
        }
    }
}

struct CertificatesView: View {
    weak var presentingViewController: UIViewController?
    
    @StateObject private var viewModel = CertificatesViewModel()
    
    private var allowedImportTypes: [UTType] {
        ["p12", "pfx", "pkcs12", "der", "cer", "crt", "pem"].compactMap { UTType(filenameExtension: $0) }
    }
    private var allowedKeyImportTypes: [UTType] {
        ["key", "pem", "der"].compactMap { UTType(filenameExtension: $0) }
    }
    
    @State private var showCreateSheet            = false
    @State private var showFileImporter           = false
    @State private var showRevokeConfirmation     = false
    @State private var showDeactivateConfirmation = false
    @State private var showDeleteConfirmation     = false
    @State private var showExportPasswordPrompt   = false
    @State private var showClearKeyConfirmation   = false
    @State private var hasInitialLoaded           = false
    @State private var hasCopiedActiveSerial      = false
    
    @State private var exportPasswordInput   = ""
    @State private var fileImportMode: FileImportMode       = .certificate
    @State private var keyTextImportItem: KeyTextImportItem? = nil
    @State private var privateKeyTextInput   = ""
    
    @State private var deleteLocalOnRevoke: Bool = true
    
    @State private var certificateToRevoke:      ALTX509Certificate? = nil
    @State private var certificateToDelete:      ALTX509Certificate? = nil
    @State private var certificateToExport:      ALTX509Certificate? = nil
    @State private var certificateToAddKeyFor:   ALTX509Certificate? = nil
    @State private var certificateToClearKeyFor: ALTX509Certificate? = nil
    
    var body: some View {
        ZStack(alignment: .top) {
            // 1. Lớp nền Gradient CSS cố định toàn màn hình
            CertCSSTheme.bgGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 2. Thanh công cụ nổi phía trên (Nằm cùng hàng với nút Back nổi của SettingsViewController)
                topFloatingActionToolbar
                
                // 3. Danh sách chuẩn xác từ File Gốc kết hợp giao diện CSS Theme
                List {
                    // KHUNG 1: Hero Banner chuẩn CSS
                    Section {
                        heroBannerSection
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            #if !os(tvOS)
                            .listRowSeparator(.hidden)
                            #endif
                    }
                    
                    // KHUNG 2: Active Signing Certificate (Sử dụng trực tiếp Component chuẩn của File Gốc)
                    ActiveCertSectionView(
                        viewModel: viewModel,
                        hasCopiedActiveSerial: $hasCopiedActiveSerial,
                        onDeactivate: { showDeactivateConfirmation = true }
                    )
                    .foregroundColor(CertCSSTheme.pureBlack)
                    .listRowBackground(CertCSSTheme.white)
                    
                    // KHUNG 3: Danh sách chứng chỉ (Sử dụng trực tiếp Component chuẩn của File Gốc)
                    CertificatesListView(
                        viewModel: viewModel,
                        onRowTap:     { pushDetailView(for: $0) },
                        onRevoke:     { presentRevokeAlert(for: $0) },
                        onExportP12:  { cert in
                            certificateToExport = cert
                            exportPasswordInput = ""
                            showExportPasswordPrompt = true
                        },
                        onClearKey:   { cert in
                            certificateToClearKeyFor = cert
                            showClearKeyConfirmation = true
                        },
                        onAddKeyBin:  { cert in
                            importPrivateKeyAction(for: cert)
                        },
                        onAddKeyText: { cert in
                            keyTextImportItem = KeyTextImportItem(id: cert.serialNumber, cert: cert)
                        },
                        onDelete: { certificateToDelete = $0; showDeleteConfirmation = true }
                    )
                    .foregroundColor(CertCSSTheme.pureBlack)
                    .listRowBackground(CertCSSTheme.white)
                }
                #if !os(tvOS)
                .listStyle(.insetGrouped)
                #endif
                .modifier(ClearListBackgroundModifier())
                .refreshable {
                    await withCheckedContinuation { continuation in
                        viewModel.loadCertificates(presentingViewController: presentingViewController, isPullToRefresh: true) {
                            continuation.resume()
                        }
                    }
                }
            }
            
            if viewModel.isLoading { LoadingOverlay() }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
        .navigationTitle("Chứng chỉ")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                SwiftUI.Button {
                    viewModel.isGlobalHideActive.toggle()
                } label: {
                    Image(systemName: viewModel.isGlobalHideActive ? "eye.slash" : "eye")
                        .foregroundColor(CertCSSTheme.blue)
                }
                .accessibilityLabel("Ẩn/Hiện thông tin nhạy cảm")
                
                SwiftUI.Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(viewModel.team == nil ? Color.gray : CertCSSTheme.blue)
                }
                .accessibilityLabel("Tạo chứng chỉ")
                .disabled(viewModel.team == nil)
                
                SwiftUI.Button {
                    importCertificatesAction()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .foregroundColor(CertCSSTheme.purple)
                }
                .accessibilityLabel("Nhập chứng chỉ")
            }
        }
        .onAppear {
            guard !hasInitialLoaded else { return }
            hasInitialLoaded = true
            viewModel.loadCertificates(presentingViewController: nil)
        }
        // MARK: - HỘP THOẠI CẢNH BÁO & THÔNG BÁO (ĐÃ VIỆT HÓA)
        .alert("Đã xảy ra lỗi", isPresented: $viewModel.showErrorAlert) {
            SwiftUI.Button("Đóng", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Đã xảy ra lỗi không xác định.")
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateCertificateSheetView(
                viewModel: viewModel,
                presentingViewController: presentingViewController,
                isPresented: $showCreateSheet
            )
        }
        .alert("Hủy kích hoạt chứng chỉ", isPresented: $showDeactivateConfirmation) {
            SwiftUI.Button("Hủy kích hoạt", role: .destructive) { viewModel.deactivateActiveCertificate() }
            SwiftUI.Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn hủy kích hoạt chứng chỉ ký ứng dụng đang dùng trên thiết bị này không?")
        }
        .alert("Xóa chứng chỉ", isPresented: $showDeleteConfirmation) {
            SwiftUI.Button("Xóa", role: .destructive) {
                if let cert = certificateToDelete { viewModel.deleteCertificate(cert) }
            }
            SwiftUI.Button("Hủy", role: .cancel) {}
        } message: {
            Text("Bạn có chắc chắn muốn xóa chứng chỉ này khỏi bộ nhớ cục bộ của thiết bị không?")
        }
        .alert("Mật khẩu giải mã chứng chỉ", isPresented: $viewModel.showPasswordPromptForImport) {
            SecureField("Nhập mật khẩu...", text: $viewModel.importPasswordInput)
            SwiftUI.Button("Nhập") { viewModel.submitImportPassword() }
            SwiftUI.Button("Hủy", role: .cancel) { viewModel.cancelImport() }
        } message: {
            Text("Vui lòng nhập mật khẩu để giải mã tệp chứng chỉ.\n\nTệp: \(viewModel.currentImportFilename)")
        }
        .alert("Thành công", isPresented: $viewModel.showAlert) {
            SwiftUI.Button("OK", role: .cancel) { viewModel.alertMessage = nil }
        } message: {
            Text(viewModel.alertMessage ?? "")
        }
        .alert("Kết quả nhập chứng chỉ", isPresented: $viewModel.showImportSummary) {
            if viewModel.importFailedCount > 0 {
                SwiftUI.Button("Xem chi tiết lỗi") {
                    DispatchQueue.main.async {
                        viewModel.showFailuresAlert = true
                    }
                }
                SwiftUI.Button("Đóng", role: .cancel) {}
            } else {
                SwiftUI.Button("OK", role: .cancel) {}
            }
        } message: {
            Text(viewModel.importSummaryMessage)
        }
        .sheet(isPresented: $viewModel.showFailuresAlert) {
            NavigationView {
                ZStack {
                    CertCSSTheme.bgGradient.ignoresSafeArea()
                    List {
                        ForEach(viewModel.failedImportsList, id: \.self) { failure in
                            Text(failure)
                                .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                                .foregroundColor(CertCSSTheme.magenta)
                                .padding(.vertical, 6)
                                .listRowBackground(CertCSSTheme.white)
                        }
                    }
                    .modifier(ClearListBackgroundModifier())
                }
                .navigationTitle("Danh sách lỗi khi nhập")
                #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        SwiftUI.Button("Xong") {
                            viewModel.showFailuresAlert = false
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CertCSSTheme.blue)
                    }
                }
            }
            .preferredColorScheme(.light)
        }
        .alert("Đặt mật khẩu xuất chứng chỉ", isPresented: $showExportPasswordPrompt) {
            SecureField("Nhập mật khẩu bảo vệ...", text: $exportPasswordInput)
            SwiftUI.Button("Xuất (.p12)") {
                if let cert = certificateToExport, let signable = viewModel.getSignableCertificate(for: cert.serialNumber) {
                    CertificateExporter.shareP12(signable, password: exportPasswordInput, onShare: { viewModel.shareURL = $0 }) { viewModel.errorMessage = $0 }
                }
            }
            SwiftUI.Button("Hủy", role: .cancel) {}
        } message: {
            Text("Thiết lập mật khẩu để mã hóa và bảo vệ tệp chứng chỉ .p12 khi xuất ra ngoài.")
        }
        .alert("Xóa khóa riêng tư (Private Key)", isPresented: $showClearKeyConfirmation) {
            if let cert = certificateToClearKeyFor {
                SwiftUI.Button("Xóa khóa", role: .destructive) {
                    viewModel.clearPrivateKey(for: cert)
                    certificateToClearKeyFor = nil
                }
            }
            SwiftUI.Button("Hủy", role: .cancel) { certificateToClearKeyFor = nil }
        } message: {
            if let cert = certificateToClearKeyFor {
                Text("Thao tác này sẽ xóa khóa riêng tư (Private Key) đang lưu trên máy của chứng chỉ này.\n\nTên: \(cert.name)\nSố Sê-ri: \(cert.serialNumber)")
            }
        }
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: fileImportMode == .certificate ? allowedImportTypes : allowedKeyImportTypes,
            allowsMultipleSelection: fileImportMode == .certificate
        ) { result in
            switch result {
            case .success(let urls):
                switch fileImportMode {
                case .certificate:
                    viewModel.startBulkImport(urls: urls)
                case .privateKey:
                    if let url = urls.first, let cert = certificateToAddKeyFor {
                        _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        do {
                            viewModel.importPrivateKey(data: try Data(contentsOf: url), for: cert)
                        } catch {
                            viewModel.errorMessage = "Không thể đọc tệp khóa riêng tư: " + error.localizedDescription
                        }
                    }
                }
            case .failure(let error):
                let type = fileImportMode == .certificate ? "tệp chứng chỉ" : "khóa riêng tư"
                viewModel.errorMessage = "Không thể chọn \(type): " + error.localizedDescription
            }
        }
        #endif
        .sheet(item: $keyTextImportItem) { item in
            PrivateKeyTextInputView(
                text: $privateKeyTextInput,
                cert: item.cert,
                viewModel: viewModel,
                allowedKeyImportTypes: allowedKeyImportTypes,
                onCancel: {
                    keyTextImportItem = nil
                    privateKeyTextInput = ""
                }
            )
        }
        .sheet(isPresented: Binding<Bool>(
            get: { viewModel.shareURL != nil },
            set: { if !$0 { viewModel.shareURL = nil } }
        )) {
            if let url = viewModel.shareURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }
    
    // MARK: - 🧭 THANH CÔNG CỤ NỔI THÔNG MINH (ĐỒNG BỘ KÍNH MỜ & ĐỔ BÓNG)
    private var topFloatingActionToolbar: some View {
        HStack(spacing: 10) {
            // Chừa khoảng trống bên trái (54pt) cho nút Back nổi (34x34 tại x:16) của SettingsViewController
            Spacer()
                .frame(width: 54)
            
            Spacer()
            
            // Nút Ẩn/Hiện thông tin nhạy cảm
            SwiftUI.Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.isGlobalHideActive.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: viewModel.isGlobalHideActive ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 13, weight: .bold))
                    Text(viewModel.isGlobalHideActive ? "Đang ẩn" : "Hiển thị")
                        .font(.system(size: 12.5, weight: .bold))
                }
                .foregroundColor(viewModel.isGlobalHideActive ? CertCSSTheme.purple : CertCSSTheme.blue)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(CertCSSTheme.white.opacity(0.95))
                .cornerRadius(17)
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(CertCSSTheme.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            // Nút Tạo chứng chỉ mới (+)
            SwiftUI.Button {
                showCreateSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(viewModel.team == nil ? Color.gray.opacity(0.5) : CertCSSTheme.blue)
                    .frame(width: 34, height: 34)
                    .background(CertCSSTheme.white.opacity(0.95))
                    .cornerRadius(17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(CertCSSTheme.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(viewModel.team == nil)
            
            // Nút Nhập chứng chỉ từ tệp (.p12 / .cer / .pem)
            SwiftUI.Button {
                importCertificatesAction()
            } label: {
                Image(systemName: "square.and.arrow.down")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(CertCSSTheme.purple)
                    .frame(width: 34, height: 34)
                    .background(CertCSSTheme.white.opacity(0.95))
                    .cornerRadius(17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(CertCSSTheme.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
    
    // MARK: - 🌈 KHUNG 1: HERO BANNER CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI NEWS & SOURCES)
    private var heroBannerSection: some View {
        ZStack(alignment: .topTrailing) {
            // Vòng tròn kính mờ trang trí góc trên bên phải
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 120, height: 120)
                .offset(x: 35, y: -45)
            
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 30, height: 30)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }
                    
                    Text("Quản Lý Chứng Chỉ")
                        .font(.system(size: 22.5, weight: .heavy, design: .rounded))
                        .foregroundColor(CertCSSTheme.white)
                        .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 2)
                }
                
                Text("Tạo mới, nhập tệp .p12 và quản lý chứng chỉ ký ứng dụng của bạn")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundColor(CertCSSTheme.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                
                HStack(spacing: 10) {
                    SwiftUI.Button {
                        showCreateSheet = true
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 13.5, weight: .bold))
                            Text("Tạo mới")
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .foregroundColor(CertCSSTheme.blue)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(CertCSSTheme.white)
                        .cornerRadius(13)
                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.team == nil)
                    .opacity(viewModel.team == nil ? 0.55 : 1.0)
                    
                    SwiftUI.Button {
                        importCertificatesAction()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "square.and.arrow.down.fill")
                                .font(.system(size: 13.5, weight: .bold))
                            Text("Nhập tệp")
                                .font(.system(size: 12.5, weight: .bold))
                        }
                        .foregroundColor(CertCSSTheme.white)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(CertCSSTheme.white.opacity(0.22))
                        .cornerRadius(13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(CertCSSTheme.white.opacity(0.45), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .padding(.horizontal, 12)
        }
        .background(CertCSSTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 1.2)
        )
        .shadow(color: CertCSSTheme.blue.opacity(0.26), radius: 14, x: 0, y: 7)
    }
    
    // MARK: - CÁC HÀM ĐIỀU HƯỚNG & XỬ LÝ SỰ KIỆN GỐC
    private func pushDetailView(for cert: ALTX509Certificate) {
        let metadata = DeveloperPortalMetadata(
            identifier: cert.identifier,
            machineName: cert.machineName,
            machineIdentifier: cert.machineIdentifier,
            requesterEmail: cert.requesterEmail,
            requesterFirstName: cert.requesterFirstName,
            requesterLastName: cert.requesterLastName,
            displayName: cert.displayName,
            certificateType: cert.certificateType,
            certificateTypeName: cert.certificateTypeName,
            certificateTypeId: cert.certificateTypeId,
            platform: cert.platform,
            platformName: cert.platformName,
            isManaged: cert.isManaged,
            status: cert.status,
            ownerName: cert.ownerName,
            ownerId: cert.ownerId,
            autoRotationEnabled: cert.autoRotationEnabled,
            requestedDate: cert.requestedDate,
            serialNumDecimal: cert.serialNumDecimal
        )
        let detailVC = UIHostingController(
            rootView: CertificateDetailView(certificate: cert, portalMetadata: metadata, viewModel: viewModel)
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
        )
        detailVC.overrideUserInterfaceStyle = .light
        #if !os(tvOS)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        detailVC.navigationItem.scrollEdgeAppearance = appearance
        detailVC.navigationItem.standardAppearance   = appearance
        #endif
        presentingViewController?.navigationController?.pushViewController(detailVC, animated: true)
    }
    
    private func presentRevokeAlert(for cert: ALTX509Certificate) {
        let contentVC = RevokeAlertViewController()
        
        let alertController = UIAlertController(
            title: NSLocalizedString("Thu hồi chứng chỉ", comment: ""),
            message: NSLocalizedString("Bạn có chắc chắn muốn thu hồi chứng chỉ này không? Thao tác này sẽ xóa vĩnh viễn chứng chỉ trên máy chủ của Apple.", comment: ""),
            preferredStyle: .alert
        )
        
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Hủy", comment: ""), style: .cancel, handler: nil)
        let revokeAction = UIAlertAction(title: NSLocalizedString("Thu hồi", comment: ""), style: .destructive) { _ in
            let keepLocal = contentVC.isKeepLocalChecked
            viewModel.revokeCertificate(cert, keepLocal: keepLocal, presentingViewController: presentingViewController)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(revokeAction)
        
        presentingViewController?.present(alertController, animated: true)
    }
    
    private func importPrivateKeyAction(for cert: ALTX509Certificate) {
        certificateToAddKeyFor = cert
        fileImportMode = .privateKey
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["der", "key", "pem", "p12"],
            title: "Nhập khóa riêng tư (.der/.pem)",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            do {
                let data = try Data(contentsOf: fileURL)
                viewModel.importPrivateKey(data: data, for: cert)
            } catch {
                viewModel.errorMessage = "Không thể đọc khóa riêng tư: " + error.localizedDescription
            }
            certificateToAddKeyFor = nil
        }
        #endif
    }
    
    private func importCertificatesAction() {
        fileImportMode = .certificate
        #if !os(tvOS)
        showFileImporter = true
        #else
        guard let topVC = presentingViewController ?? UIApplication.shared.topViewController() else { return }
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["p12", "der", "pem", "cer", "crt"],
            title: "Nhập chứng chỉ",
            presentingVC: topVC
        ) { fileURL in
            guard let fileURL = fileURL else { return }
            viewModel.startBulkImport(urls: [fileURL])
        }
        #endif
    }
}

// MARK: - ⏳ HIỆU ỨNG ĐANG TẢI (LOADING OVERLAY CHUẨN CSS)
private struct LoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(CertCSSTheme.blue)
                    .scaleEffect(1.2)
                Text("Đang xử lý...")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(CertCSSTheme.pureBlack)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(CertCSSTheme.white)
            .clipShape(RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous)
                    .stroke(CertCSSTheme.border, lineWidth: 1.1)
            )
            .shadow(color: CertCSSTheme.blue.opacity(0.22), radius: 14, x: 0, y: 6)
        }
    }
}

// MARK: - ➕ MÀN HÌNH TẠO CHỨNG CHỈ MỚI (ĐỒNG BỘ CSS THEME & CHỮ ĐEN TUYỀN)
private struct CreateCertificateSheetView: View {
    @ObservedObject var viewModel: CertificatesViewModel
    var presentingViewController: UIViewController?
    @Binding var isPresented: Bool

    @State private var machineName: String = "SideStore - \(UIDevice.current.name)"
    @State private var selectedCertificateType: CertificateType = .development

    private var isPaidWarningVisible: Bool {
        selectedCertificateType.isPaidOnly && !viewModel.isPaidAccount
    }

    private var canCreate: Bool {
        !machineName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            ZStack {
                CertCSSTheme.bgGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Banner tiêu đề nhỏ trong Sheet đồng bộ với Hero Banner
                        ZStack(alignment: .topTrailing) {
                            Circle()
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 90, height: 90)
                                .offset(x: 28, y: -32)
                            
                            VStack(spacing: 5) {
                                HStack(spacing: 7) {
                                    Image(systemName: "plus.seal.fill")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(.white)
                                    Text("Khởi Tạo Chứng Chỉ Mới")
                                        .font(.system(size: 19.5, weight: .heavy, design: .rounded))
                                        .foregroundColor(CertCSSTheme.white)
                                }
                                Text("Đăng ký chứng chỉ trực tiếp với máy chủ Apple và lưu khóa riêng tư trên máy")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundColor(CertCSSTheme.white.opacity(0.95))
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 12)
                        }
                        .background(CertCSSTheme.heroGradient)
                        .clipShape(RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.32), lineWidth: 1.2)
                        )
                        .shadow(color: CertCSSTheme.blue.opacity(0.24), radius: 12, x: 0, y: 5)
                        
                        // Khung nhập thông tin nền trắng chữ đen tuyền #000000
                        VStack(alignment: .leading, spacing: 10) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack(spacing: 7) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(CertCSSTheme.blue.opacity(0.14))
                                            .frame(width: 22, height: 22)
                                        Image(systemName: "doc.badge.gearshape.fill")
                                            .font(.system(size: 11.5, weight: .heavy))
                                            .foregroundColor(CertCSSTheme.blue)
                                    }
                                    Text("THÔNG TIN CHỨNG CHỈ")
                                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                        .foregroundColor(CertCSSTheme.blue)
                                }
                                RoundedRectangle(cornerRadius: 1.75)
                                    .fill(CertCSSTheme.accentUnderlineGradient)
                                    .frame(width: 38, height: 3.5)
                            }
                            .padding(.leading, 4)
                            
                            VStack(spacing: 10) {
                                // Hàng 1: Loại chứng chỉ
                                HStack {
                                    Text("Loại chứng chỉ")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(CertCSSTheme.pureBlack)
                                    Spacer()
                                    Picker("Loại chứng chỉ", selection: $selectedCertificateType) {
                                        ForEach(viewModel.availableCertificateTypes, id: \.rawValue) { certType in
                                            Text(certType.displayName).tag(certType)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(CertCSSTheme.blue)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(CertCSSTheme.light)
                                .clipShape(RoundedRectangle(cornerRadius: CertCSSTheme.innerCornerRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CertCSSTheme.innerCornerRadius, style: .continuous)
                                        .stroke(CertCSSTheme.innerBorder, lineWidth: 1)
                                )
                                
                                // Hàng 2: Tên thiết bị
                                HStack {
                                    Text("Tên thiết bị")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(CertCSSTheme.pureBlack)
                                    Spacer()
                                    TextField("Nhập tên thiết bị...", text: $machineName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(CertCSSTheme.purple)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(CertCSSTheme.light)
                                .clipShape(RoundedRectangle(cornerRadius: CertCSSTheme.innerCornerRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CertCSSTheme.innerCornerRadius, style: .continuous)
                                        .stroke(CertCSSTheme.innerBorder, lineWidth: 1)
                                )
                            }
                            .padding(14)
                            .background(CertCSSTheme.white)
                            .clipShape(RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius, style: .continuous)
                                    .stroke(CertCSSTheme.border, lineWidth: 1.1)
                            )
                            .shadow(color: CertCSSTheme.blue.opacity(0.09), radius: 14, x: 0, y: 6)
                            
                            Text(isPaidWarningVisible
                                ? "⚠️ Loại chứng chỉ này yêu cầu Tài khoản Nhà phát triển Apple trả phí (Paid Developer Account)."
                                : "Chọn loại chứng chỉ và đặt tên thiết bị dễ nhớ để quản lý.")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(isPaidWarningVisible ? CertCSSTheme.magenta : CertCSSTheme.pureBlack)
                                .padding(.horizontal, 4)
                                .padding(.top, 2)
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Tạo chứng chỉ mới")
            #if !os(tvOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    SwiftUI.Button("Hủy") {
                        isPresented = false
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(CertCSSTheme.magenta)
                }
                ToolbarItem(placement: .confirmationAction) {
                    SwiftUI.Button("Tạo ngay") {
                        let name = machineName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !name.isEmpty else { return }
                        isPresented = false
                        viewModel.createCertificate(
                            machineName: name,
                            type: selectedCertificateType,
                            presentingViewController: presentingViewController
                        )
                    }
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(canCreate ? CertCSSTheme.blue : Color.gray)
                    .disabled(!canCreate)
                }
            }
        }
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }
}
