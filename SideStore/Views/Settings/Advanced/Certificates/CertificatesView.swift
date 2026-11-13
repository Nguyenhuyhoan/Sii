
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

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI SETTINGSVIEWCONTROLLER)
private enum CertCSSTheme {
    static let white = Color.white
    static let light = Color(red: 248/255, green: 249/255, blue: 250/255) // #f8f9fa
    static let border = Color(red: 233/255, green: 236/255, blue: 239/255) // #e9ecef
    static let blue = Color(red: 0/255, green: 123/255, blue: 255/255) // #007bff
    static let purple = Color(red: 111/255, green: 66/255, blue: 193/255) // #6f42c1
    static let green = Color(red: 40/255, green: 167/255, blue: 69/255) // #28a745
    static let magenta = Color(red: 255/255, green: 0/255, blue: 255/255) // #ff00ff
    static let dark = Color(red: 52/255, green: 58/255, blue: 64/255) // #343a40

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 243/255, green: 224/255, blue: 255/255),
            Color(red: 224/255, green: 247/255, blue: 255/255)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Hero Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88))
    static let heroGradient = LinearGradient(
        gradient: Gradient(colors: [
            Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.92),
            Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.88)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let cornerRadius: CGFloat = 15.0
}

// MARK: - 🛠 MODIFIER ẨN NỀN MẶC ĐỊNH CỦA FORM TRONG SHEET
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
                
                // 3. Nội dung cuộn gồm 3 Khung chuẩn CSS (Không dùng List đen mặc định)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        // KHUNG 1: Hero Banner chuẩn CSS
                        heroBannerSection
                        
                        // KHUNG 2: Active Signing Certificate (Nền trắng, chữ đen/xanh chuẩn Cài Đặt)
                        activeSigningCertificateCard
                        
                        // KHUNG 3: Danh sách chứng chỉ (VD: SideStore - Hoang's iPhone (R))
                        certificatesListCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 50)
                }
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
        .navigationTitle("")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(CertCSSTheme.magenta)
                                .padding(.vertical, 4)
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
    
    // MARK: - 🧭 THANH CÔNG CỤ NỔI THÔNG MINH
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
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(viewModel.isGlobalHideActive ? CertCSSTheme.purple : CertCSSTheme.blue)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(CertCSSTheme.white.opacity(0.92))
                .cornerRadius(17)
                .overlay(
                    RoundedRectangle(cornerRadius: 17)
                        .stroke(CertCSSTheme.border, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
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
                    .background(CertCSSTheme.white.opacity(0.92))
                    .cornerRadius(17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(CertCSSTheme.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
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
                    .background(CertCSSTheme.white.opacity(0.92))
                    .cornerRadius(17)
                    .overlay(
                        RoundedRectangle(cornerRadius: 17)
                            .stroke(CertCSSTheme.border, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 5, x: 0, y: 2)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }
    
    // MARK: - 🌈 KHUNG 1: HERO BANNER CHUẨN CSS THEME
    private var heroBannerSection: some View {
        VStack(spacing: 6) {
            Text("Quản Lý Chứng Chỉ")
                .font(.system(size: 23, weight: .heavy))
                .foregroundColor(CertCSSTheme.white)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 1, y: 2)
            
            Text("Tạo mới, nhập tệp .p12 và quản lý chứng chỉ ký ứng dụng của bạn")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(CertCSSTheme.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
            
            HStack(spacing: 10) {
                SwiftUI.Button {
                    showCreateSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Tạo mới")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(CertCSSTheme.blue)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CertCSSTheme.white)
                    .cornerRadius(12)
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
                            .font(.system(size: 13, weight: .bold))
                        Text("Nhập tệp")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(CertCSSTheme.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CertCSSTheme.white.opacity(0.22))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(CertCSSTheme.white.opacity(0.45), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(CertCSSTheme.heroGradient)
        .cornerRadius(CertCSSTheme.cornerRadius)
        .shadow(color: CertCSSTheme.blue.opacity(0.25), radius: 14, x: 0, y: 6)
    }
    
    // MARK: - 🏷 TIÊU ĐỀ MỤC CHUẨN TAB CÀI ĐẶT (CHỮ XANH + GẠCH CHÂN 3PT)
    private func sectionHeaderTitle(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(CertCSSTheme.blue)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(CertCSSTheme.blue)
                .frame(width: 38, height: 3)
        }
        .padding(.leading, 4)
    }
    
    // MARK: - 🛡 KHUNG 2: ACTIVE SIGNING CERTIFICATE (GỌN ĐẸP, NỀN TRẮNG, CHỮ ĐEN)
    private var activeSigningCertificateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeaderTitle("CHỨNG CHỈ ĐANG SỬ DỤNG")
            
            HStack(spacing: 12) {
                Image(systemName: viewModel.activeCertificate != nil ? "checkmark.seal.fill" : "seal")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(viewModel.activeCertificate != nil ? CertCSSTheme.green : CertCSSTheme.purple)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Signing Certificate")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    if let active = viewModel.activeCertificate {
                        Text(displayCertificateTitle(for: active))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(CertCSSTheme.blue)
                            .lineLimit(1)
                    } else {
                        Text("Chưa chọn chứng chỉ ký ứng dụng")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(CertCSSTheme.purple)
                    }
                }
                
                Spacer()
                
                if viewModel.activeCertificate != nil {
                    Menu {
                        if let active = viewModel.activeCertificate {
                            SwiftUI.Button {
                                pushDetailView(for: active)
                            } label: {
                                Label("Xem chi tiết", systemImage: "info.circle")
                            }
                        }
                        SwiftUI.Button(role: .destructive) {
                            showDeactivateConfirmation = true
                        } label: {
                            Label("Hủy kích hoạt", systemImage: "xmark.circle")
                        }
                    } label: {
                        Text("Đang dùng")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(CertCSSTheme.green)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(CertCSSTheme.green.opacity(0.12))
                            .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(CertCSSTheme.white)
            .cornerRadius(CertCSSTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius)
                    .stroke(CertCSSTheme.border, lineWidth: 1)
            )
            .shadow(color: CertCSSTheme.blue.opacity(0.07), radius: 10, x: 0, y: 5)
            .contentShape(Rectangle())
            .onTapGesture {
                if let active = viewModel.activeCertificate {
                    pushDetailView(for: active)
                }
            }
        }
    }
    
    // MARK: - 📋 KHUNG 3: DANH SÁCH CHỨNG CHỈ (GỌN ĐẸP, NỀN TRẮNG, CHỮ ĐEN)
    private var certificatesListCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeaderTitle("DANH SÁCH CHỨNG CHỈ")
            
            VStack(spacing: 0) {
                if viewModel.mergedCertificates.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(CertCSSTheme.purple)
                        Text("Chưa có chứng chỉ nào được lưu")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                } else {
                    ForEach(Array(viewModel.mergedCertificates.enumerated()), id: \.element.serialNumber) { index, cert in
                        certificateRowView(for: cert)
                        
                        // Đường kẻ phân cách chuẩn #e9ecef giữa các dòng
                        if index < viewModel.mergedCertificates.count - 1 {
                            Rectangle()
                                .fill(CertCSSTheme.border)
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .background(CertCSSTheme.white)
            .cornerRadius(CertCSSTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius)
                    .stroke(CertCSSTheme.border, lineWidth: 1)
            )
            .shadow(color: CertCSSTheme.blue.opacity(0.07), radius: 10, x: 0, y: 5)
        }
    }
    
    // Dòng hiển thị gọn nhẹ cho từng chứng chỉ (VD: SideStore - Hoang's iPhone (R))
    private func certificateRowView(for cert: ALTX509Certificate) -> some View {
        let isActive = (viewModel.activeCertificate?.serialNumber == cert.serialNumber)
        let hasKey = (viewModel.getSignableCertificate(for: cert.serialNumber) != nil)
        
        return HStack(spacing: 12) {
            Image(systemName: hasKey ? "key.fill" : "doc.text.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isActive ? CertCSSTheme.green : (hasKey ? CertCSSTheme.blue : CertCSSTheme.purple))
                .frame(width: 24)
            
            Text(displayCertificateTitle(for: cert))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .lineLimit(1)
            
            Spacer()
            
            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CertCSSTheme.green)
            }
            
            // Nút Menu thao tác nhanh (Kích hoạt / Xuất .p12 / Khóa riêng tư / Thu hồi / Xóa)
            Menu {
                SwiftUI.Button {
                    pushDetailView(for: cert)
                } label: {
                    Label("Xem chi tiết", systemImage: "info.circle")
                }
                
                if hasKey && !isActive {
                    SwiftUI.Button {
                        viewModel.setActiveCertificate(cert)
                    } label: {
                        Label("Sử dụng chứng chỉ này", systemImage: "checkmark.seal")
                    }
                }
                
                if hasKey {
                    SwiftUI.Button {
                        certificateToExport = cert
                        exportPasswordInput = ""
                        showExportPasswordPrompt = true
                    } label: {
                        Label("Xuất tệp (.p12)", systemImage: "square.and.arrow.up")
                    }
                    
                    SwiftUI.Button(role: .destructive) {
                        certificateToClearKeyFor = cert
                        showClearKeyConfirmation = true
                    } label: {
                        Label("Xóa khóa riêng tư", systemImage: "key.slash")
                    }
                } else {
                    SwiftUI.Button {
                        importPrivateKeyAction(for: cert)
                    } label: {
                        Label("Nhập khóa riêng tư từ tệp", systemImage: "doc.badge.plus")
                    }
                    
                    SwiftUI.Button {
                        keyTextImportItem = KeyTextImportItem(id: cert.serialNumber, cert: cert)
                    } label: {
                        Label("Dán khóa riêng tư (Văn bản)", systemImage: "doc.on.clipboard")
                    }
                }
                
                Divider()
                
                if cert.identifier != nil {
                    SwiftUI.Button(role: .destructive) {
                        presentRevokeAlert(for: cert)
                    } label: {
                        Label("Thu hồi trên Apple (Revoke)", systemImage: "flame")
                    }
                }
                
                SwiftUI.Button(role: .destructive) {
                    certificateToDelete = cert
                    showDeleteConfirmation = true
                } label: {
                    Label("Xóa khỏi thiết bị", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(CertCSSTheme.blue.opacity(0.85))
                    .padding(.vertical, 4)
                    .padding(.leading, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(CertCSSTheme.white)
        .contentShape(Rectangle())
        .onTapGesture {
            pushDetailView(for: cert)
        }
    }
    
    // Lấy tên hiển thị ưu tiên kiểu "SideStore - Hoang's iPhone (R)"
    private func displayCertificateTitle(for cert: ALTX509Certificate) -> String {
        let rawTitle: String
        if let machine = cert.machineName, !machine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawTitle = machine
        } else if let display = cert.displayName, !display.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawTitle = display
        } else if !cert.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            rawTitle = cert.name
        } else {
            rawTitle = "Certificate (\(cert.serialNumber.prefix(8)))"
        }
        
        if viewModel.isGlobalHideActive {
            return "••••••••••••••••••••"
        }
        return rawTitle
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
        detailVC.title = nil
        detailVC.navigationItem.title = nil
        #if !os(tvOS)
        detailVC.navigationItem.largeTitleDisplayMode = .never
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
            title: "Thu hồi chứng chỉ",
            message: "Bạn có chắc chắn muốn thu hồi chứng chỉ này không? Thao tác này sẽ xóa vĩnh viễn chứng chỉ trên máy chủ của Apple.",
            preferredStyle: .alert
        )
        
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: "Hủy", style: .cancel, handler: nil)
        let revokeAction = UIAlertAction(title: "Thu hồi", style: .destructive) { _ in
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
            Color.black.opacity(0.22).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .tint(CertCSSTheme.blue)
                    .scaleEffect(1.2)
                Text("Đang xử lý...")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(CertCSSTheme.blue)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 20)
            .background(CertCSSTheme.white)
            .cornerRadius(CertCSSTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius)
                    .stroke(CertCSSTheme.border, lineWidth: 1)
            )
            .shadow(color: CertCSSTheme.blue.opacity(0.22), radius: 14, x: 0, y: 6)
        }
    }
}

// MARK: - ➕ MÀN HÌNH TẠO CHỨNG CHỈ MỚI (ĐỒNG BỘ CSS THEME & VIỆT HÓA)
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
                        // Banner tiêu đề nhỏ trong Sheet
                        VStack(spacing: 4) {
                            Text("Khởi Tạo Chứng Chỉ Mới")
                                .font(.system(size: 19, weight: .heavy))
                                .foregroundColor(CertCSSTheme.white)
                            Text("Đăng ký chứng chỉ trực tiếp với máy chủ Apple và lưu khóa riêng tư trên máy")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(CertCSSTheme.white.opacity(0.92))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 12)
                        .background(CertCSSTheme.heroGradient)
                        .cornerRadius(CertCSSTheme.cornerRadius)
                        .shadow(color: CertCSSTheme.blue.opacity(0.22), radius: 10, x: 0, y: 4)
                        
                        // Khung nhập thông tin nền trắng chữ đen
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("THÔNG TIN CHỨNG CHỈ")
                                    .font(.system(size: 13, weight: .heavy))
                                    .foregroundColor(CertCSSTheme.blue)
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(CertCSSTheme.blue)
                                    .frame(width: 34, height: 3)
                            }
                            .padding(.leading, 4)
                            
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Loại chứng chỉ")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Picker("Loại chứng chỉ", selection: $selectedCertificateType) {
                                        ForEach(viewModel.availableCertificateTypes, id: \.rawValue) { certType in
                                            Text(certType.displayName).tag(certType)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(CertCSSTheme.blue)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                Rectangle()
                                    .fill(CertCSSTheme.border)
                                    .frame(height: 1)
                                    .padding(.horizontal, 16)
                                
                                HStack {
                                    Text("Tên thiết bị")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.black)
                                    Spacer()
                                    TextField("Nhập tên thiết bị...", text: $machineName)
                                        .multilineTextAlignment(.trailing)
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(CertCSSTheme.purple)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .background(CertCSSTheme.white)
                            .cornerRadius(CertCSSTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: CertCSSTheme.cornerRadius)
                                    .stroke(CertCSSTheme.border, lineWidth: 1)
                            )
                            .shadow(color: CertCSSTheme.blue.opacity(0.07), radius: 10, x: 0, y: 5)
                            
                            Text(isPaidWarningVisible
                                ? "⚠️ Loại chứng chỉ này yêu cầu Tài khoản Nhà phát triển Apple trả phí (Paid Developer Account)."
                                : "Chọn loại chứng chỉ và đặt tên thiết bị dễ nhớ để quản lý.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(isPaidWarningVisible ? CertCSSTheme.magenta : CertCSSTheme.dark.opacity(0.8))
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
                    .font(.system(size: 15, weight: .semibold))
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
