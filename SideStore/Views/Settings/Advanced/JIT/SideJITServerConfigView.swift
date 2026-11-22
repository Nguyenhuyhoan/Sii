
//
//  SideJITServerConfigView.swift
//  SideStore
//
//  Created by Magesh K on 23/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TOÀN BỘ ỨNG DỤNG & CHỮ ĐEN TUYỀN)
private enum SideJITCSSTheme {
    static let white = Color.white
    static let pureBlack = Color.black                                               // #000000 (Chữ đen tuyền độ tương phản tuyệt đối)
    static let light = Color(red: 245/255, green: 248/255, blue: 255/255)            // #f5f8ff (Đồng bộ innerRowBackground)
    static let border = Color(red: 220/255, green: 226/255, blue: 236/255)           // #dce2ec (Viền chuẩn toàn hệ thống)
    static let innerBorder = Color(red: 222/255, green: 229/255, blue: 240/255)      // #dee5f0
    static let blue = Color(red: 0/255, green: 123/255, blue: 255/255)               // #007bff
    static let purple = Color(red: 111/255, green: 66/255, blue: 193/255)            // #6f42c1
    static let green = Color(red: 40/255, green: 167/255, blue: 69/255)              // #28a745
    static let orange = Color(red: 253/255, green: 126/255, blue: 20/255)            // #fd7e14
    static let red = Color(red: 220/255, green: 53/255, blue: 69/255)                // #dc3545
    static let magenta = Color(red: 255/255, green: 0/255, blue: 255/255)            // #ff00ff
    static let dark = Color.black                                                    // #000000

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = Color(red: 243/255, green: 224/255, blue: 255/255)
    static let bgGradientEnd = Color(red: 224/255, green: 247/255, blue: 255/255)

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,193,.92))
    static let heroStart = Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.95)
    static let heroEnd = Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.92)

    static var accentUnderlineGradient: LinearGradient {
        LinearGradient(
            colors: [blue, purple],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static let cornerRadius: CGFloat = 18.0
    static let innerCornerRadius: CGFloat = 14.0
}

private struct SideJITBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

enum SideJITConnectionStatus: Equatable {
    case disabled
    case ready(latencyMs: Int, address: String)
    case discovering
    case disconnected(reason: String)
    case checking
    
    var color: Color {
        switch self {
        case .disabled: return SideJITCSSTheme.pureBlack
        case .ready: return SideJITCSSTheme.green
        case .discovering, .checking: return SideJITCSSTheme.orange
        case .disconnected: return SideJITCSSTheme.red
        }
    }
    
    var title: String {
        switch self {
        case .disabled: return "Đã tắt"
        case .ready(let latency, _): return "Sẵn sàng (\(latency) ms)"
        case .discovering: return "Đang dò tìm Bonjour…"
        case .checking: return "Đang kiểm tra kết nối…"
        case .disconnected: return "Không thể kết nối"
        }
    }
}

struct SideJITResponseLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let endpoint: String
    let httpMethod: String
    let statusCode: Int
    let latencyMs: Int
    let rawPayload: String
    
    var isSuccess: Bool {
        statusCode >= 200 && statusCode < 300
    }
    
    var prettyPayload: String {
        rawPayload.prettyPrintedJSON
    }
}

public extension String {
    var prettyPrintedJSON: String {
        guard let data = self.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys]),
              let prettyString = String(data: prettyData, encoding: .utf8) else {
            return self
        }
        return prettyString
    }
}

enum SideJITDiagnosticAction: Equatable {
    case ping
    case refresh
    case version
}

struct SideJITServerConfigView: View {
    @State private var isServerEnabled: Bool = UserDefaults.standard.isSideJITServerEnabled
    @State private var customAddress: String = UserDefaults.standard.textInputSideJITServerurl ?? ""
    @State private var resolvedAddress: String = ""
    @State private var connectionStatus: SideJITConnectionStatus = UserDefaults.standard.isSideJITServerEnabled ? .checking : .disabled
    @State private var latestLog: SideJITResponseLog? = nil
    @State private var activeAction: SideJITDiagnosticAction? = nil
    @State private var showCopiedToast = false
    @State private var animateHero = false

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Lớp nền Gradient cố định toàn màn hình (không bao giờ bị trắng khi cuộn)
            LinearGradient(
                gradient: Gradient(colors: [SideJITCSSTheme.bgGradientStart, SideJITCSSTheme.bgGradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // 2. Nội dung cuộn mượt mà theo cấu trúc CSS Card
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    heroBannerSection
                    headerSection
                    statusSection
                    configurationSection
                    diagnosticActionsSection
                    if let log = latestLog {
                        responseInspectorSection(log: log)
                    }
                    aboutSection
                }
                .padding(.horizontal, 16)
                // Chừa khoảng trống nhỏ phía trên để hài hòa với nút Back tròn nổi (34x34) của SettingsViewController
                .padding(.top, 8)
                .padding(.bottom, 50)
            }
            
            // 3. Thông báo Toast khi sao chép
            if showCopiedToast {
                copiedToastView
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.light)
        .navigationTitle("")
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarHidden(true)
        #endif
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                animateHero = true
            }
            refreshServerState()
        }
    }
    
    // MARK: - 🌟 KHỐI HERO BANNER CHUẨN CSS (ĐỒNG BỘ KÍNH MỜ & VÒNG TRÒN TRANG TRÍ)
    private var heroBannerSection: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 110, height: 110)
                .offset(x: 32, y: -42)

            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 30, height: 30)
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text("SideJITServer")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(SideJITCSSTheme.white)
                        .shadow(color: Color.black.opacity(0.28), radius: 4, x: 0, y: 2)
                        .multilineTextAlignment(.center)
                }
                
                Text("Kích hoạt biên dịch JIT tốc độ cao cho ứng dụng trên iOS 17+")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SideJITCSSTheme.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 28) // Tránh va chạm với nút Back nổi ở góc trái
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [SideJITCSSTheme.heroStart, SideJITCSSTheme.heroEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: SideJITCSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: SideJITCSSTheme.cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.32), lineWidth: 1.2)
        )
        .shadow(color: SideJITCSSTheme.blue.opacity(0.26), radius: 14, x: 0, y: 7)
        .opacity(animateHero ? 1.0 : 0.0)
        .offset(y: animateHero ? 0 : -10)
    }
    
    // MARK: - ⚡ BẬT / TẮT MÁY CHỦ SIDEJITSERVER
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            cssSectionHeader("KÍCH HOẠT DỊCH VỤ", icon: "power.circle.fill")
            
            cssCard {
                Toggle(isOn: $isServerEnabled) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [SideJITCSSTheme.blue.opacity(0.16), SideJITCSSTheme.purple.opacity(0.16)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 38, height: 38)
                            
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(SideJITCSSTheme.blue)
                        }
                        
                        VStack(alignment: .leading, spacing: 2.5) {
                            Text("Bật máy chủ SideJITServer")
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundColor(SideJITCSSTheme.pureBlack)
                            Text("Bắt buộc để kích hoạt JIT trên iOS 17 trở lên")
                                .font(.system(size: 12.2, weight: .medium))
                                .foregroundColor(SideJITCSSTheme.pureBlack)
                        }
                    }
                }
                .toggleStyle(SwitchToggleStyle(tint: SideJITCSSTheme.blue))
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .onChange(of: isServerEnabled) { newValue in
                    UserDefaults.standard.isSideJITServerEnabled = newValue
                    if newValue {
                        refreshServerState()
                    } else {
                        connectionStatus = .disabled
                        resolvedAddress = ""
                    }
                }
            }
        }
    }
    
    // MARK: - 📡 TRẠNG THÁI KẾT NỐI
    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            cssSectionHeader("TRẠNG THÁI KẾT NỐI", icon: "antenna.radiowaves.left.and.right")
            
            cssCard {
                VStack(spacing: 0) {
                    // Dòng 1: Trạng thái
                    HStack {
                        Text("Trạng thái")
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundColor(SideJITCSSTheme.pureBlack)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(connectionStatus.color)
                                .frame(width: 9, height: 9)
                                .shadow(color: connectionStatus.color.opacity(0.5), radius: 3, x: 0, y: 1)
                            Text(connectionStatus.title)
                                .font(.system(size: 13.5, weight: .bold))
                                .foregroundColor(connectionStatus.color)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(connectionStatus.color.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    
                    cssDivider
                    
                    // Dòng 2: Địa chỉ máy chủ đã phân giải
                    HStack {
                        Text("Địa chỉ phân giải")
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundColor(SideJITCSSTheme.pureBlack)
                            .layoutPriority(1)
                        Spacer()
                        Text(!isServerEnabled ? "Đã tắt" : (resolvedAddress.isEmpty ? "Đang phân giải…" : resolvedAddress))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor((!isServerEnabled || resolvedAddress.isEmpty) ? SideJITCSSTheme.pureBlack : SideJITCSSTheme.blue)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                    .contentShape(Rectangle())
                    .contextMenu {
                        if !resolvedAddress.isEmpty {
                            SwiftUI.Button {
                                #if !os(tvOS)
                                UIPasteboard.general.string = resolvedAddress
                                showCopied()
                                #endif
                            } label: {
                                Label("Sao chép địa chỉ", systemImage: "doc.on.doc")
                            }
                        }
                    }
                    
                    cssDivider
                    
                    // Dòng 3: Chế độ phân giải
                    HStack {
                        Text("Chế độ phân giải")
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundColor(SideJITCSSTheme.pureBlack)
                        Spacer()
                        Text(customAddress.isEmpty ? "Tự động (Bonjour mDNS)" : "Thủ công (Tùy chỉnh)")
                            .font(.system(size: 13.5, weight: .bold))
                            .foregroundColor(SideJITCSSTheme.purple)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(SideJITCSSTheme.purple.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 13)
                }
            }
        }
    }
    
    // MARK: - 🌐 ĐỊA CHỈ MÁY CHỦ TÙY CHỈNH
    private var configurationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            cssSectionHeader("ĐỊA CHỈ MÁY CHỦ", icon: "globe")
            
            cssCard {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(SideJITCSSTheme.blue.opacity(0.14))
                            .frame(width: 30, height: 30)
                        Image(systemName: "link")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(SideJITCSSTheme.blue)
                    }
                    
                    TextField(AppConstants.SideJIT.defaultServerURL, text: $customAddress)
                        .font(.system(size: 13.8, weight: .semibold, design: .monospaced))
                        .foregroundColor(SideJITCSSTheme.pureBlack)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        #if !os(tvOS)
                        .keyboardType(.URL)
                        #endif
                        .onChange(of: customAddress) { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                            UserDefaults.standard.textInputSideJITServerurl = trimmed.isEmpty ? nil : trimmed
                            refreshServerState()
                        }
                    
                    if !customAddress.isEmpty {
                        SwiftUI.Button {
                            customAddress = ""
                            UserDefaults.standard.textInputSideJITServerurl = nil
                            refreshServerState()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(SideJITCSSTheme.red)
                        }
                        .buttonStyle(SideJITBounceButtonStyle())
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            
            cssSectionFooter("Để trống ô này nếu bạn muốn tự động tìm kiếm máy chủ SideJITServer trong mạng nội bộ thông qua giao thức Bonjour.")
        }
    }
    
    // MARK: - 🛠️ CHẨN ĐOÁN & CÔNG CỤ KIỂM TRA
    private var diagnosticActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            cssSectionHeader("CHẨN ĐOÁN & CÔNG CỤ", icon: "wrench.and.screwdriver.fill")
            
            cssCard {
                VStack(spacing: 0) {
                    // Nút 1: Kiểm tra kết nối (Ping)
                    SwiftUI.Button {
                        testHealthCheck()
                    } label: {
                        HStack(spacing: 12) {
                            diagnosticIcon("network", color: SideJITCSSTheme.blue)
                            Text("Kiểm tra kết nối (Ping)")
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundColor(SideJITCSSTheme.pureBlack)
                            Spacer()
                            if activeAction == .ping {
                                ProgressView()
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(SideJITCSSTheme.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SideJITBounceButtonStyle())
                    .disabled(activeAction != nil)
                    
                    cssDivider
                    
                    // Nút 2: Làm mới bộ nhớ đệm thiết bị (/re/)
                    SwiftUI.Button {
                        triggerDeviceRefresh()
                    } label: {
                        HStack(spacing: 12) {
                            diagnosticIcon("arrow.clockwise", color: SideJITCSSTheme.purple)
                            Text("Làm mới bộ nhớ đệm thiết bị (/re/)")
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundColor(SideJITCSSTheme.pureBlack)
                            Spacer()
                            if activeAction == .refresh {
                                ProgressView()
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(SideJITCSSTheme.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SideJITBounceButtonStyle())
                    .disabled(activeAction != nil)
                    
                    cssDivider
                    
                    // Nút 3: Kiểm tra thông tin phiên bản (/ver/)
                    SwiftUI.Button {
                        queryVersionEndpoint()
                    } label: {
                        HStack(spacing: 12) {
                            diagnosticIcon("info.circle.fill", color: SideJITCSSTheme.green)
                            Text("Kiểm tra thông tin phiên bản (/ver/)")
                                .font(.system(size: 15.5, weight: .bold))
                                .foregroundColor(SideJITCSSTheme.pureBlack)
                            Spacer()
                            if activeAction == .version {
                                ProgressView()
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(SideJITCSSTheme.blue)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 13)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(SideJITBounceButtonStyle())
                    .disabled(activeAction != nil)
                }
            }
        }
    }
    
    // MARK: - 📄 PHẢN HỒI MỚI NHẤT TỪ MÁY CHỦ
    private func responseInspectorSection(log: SideJITResponseLog) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            cssSectionHeader("PHẢN HỒI MỚI NHẤT TỪ MÁY CHỦ", icon: "terminal.fill")
            
            cssCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(log.httpMethod)
                            .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                            .foregroundColor(SideJITCSSTheme.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3.5)
                            .background(SideJITCSSTheme.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        Text(log.endpoint)
                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                            .foregroundColor(SideJITCSSTheme.purple)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(log.statusCode == 0 ? "LỖI" : "HTTP \(log.statusCode)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(log.isSuccess ? SideJITCSSTheme.green : SideJITCSSTheme.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background((log.isSuccess ? SideJITCSSTheme.green : SideJITCSSTheme.red).opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        
                        Text("\(log.latencyMs) ms")
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(SideJITCSSTheme.pureBlack)
                    }
                    
                    ScrollView(.vertical, showsIndicators: true) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(log.prettyPayload)
                                .font(.system(size: 12.2, weight: .semibold, design: .monospaced))
                                .foregroundColor(SideJITCSSTheme.pureBlack)
                                .multilineTextAlignment(.leading)
                                .padding(12)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: 200)
                    .background(SideJITCSSTheme.light)
                    .clipShape(RoundedRectangle(cornerRadius: SideJITCSSTheme.innerCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: SideJITCSSTheme.innerCornerRadius, style: .continuous)
                            .stroke(SideJITCSSTheme.innerBorder, lineWidth: 1.1)
                    )
                    
                    HStack {
                        Spacer()
                        SwiftUI.Button {
                            #if !os(tvOS)
                            UIPasteboard.general.string = log.prettyPayload
                            showCopied()
                            #endif
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "doc.on.doc.fill")
                                    .font(.system(size: 11.5, weight: .bold))
                                Text("Sao chép phản hồi")
                                    .font(.system(size: 12.5, weight: .bold))
                            }
                            .foregroundColor(SideJITCSSTheme.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6.5)
                            .background(SideJITCSSTheme.blue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        .buttonStyle(SideJITBounceButtonStyle())
                    }
                }
                .padding(16)
            }
            .contextMenu {
                SwiftUI.Button {
                    #if !os(tvOS)
                    UIPasteboard.general.string = log.prettyPayload
                    showCopied()
                    #endif
                } label: {
                    Label("Sao chép phản hồi", systemImage: "doc.on.doc")
                }
            }
        }
    }
    
    // MARK: - ℹ️ GIỚI THIỆU VỀ SIDEJITSERVER
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            cssSectionHeader("THÔNG TIN GIỚI THIỆU", icon: "sparkles")
            
            cssCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(SideJITCSSTheme.purple.opacity(0.14))
                                .frame(width: 26, height: 26)
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(SideJITCSSTheme.purple)
                        }
                        Text("Cơ chế hoạt động của SideJITServer")
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(SideJITCSSTheme.purple)
                    }
                    
                    Text("SideJITServer giúp gắn dịch vụ debugserver của Apple từ máy tính vào các ứng dụng đang chạy trên iOS 17+ thông qua mạng Wi-Fi nội bộ hoặc cáp USB.")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(SideJITCSSTheme.pureBlack)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Text("Khi SideStore yêu cầu bật JIT, SideJITServer sẽ gửi tín hiệu gỡ lỗi và kích hoạt thực thi Just-In-Time (JIT) ngay lập tức.")
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(SideJITCSSTheme.pureBlack)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    
    // MARK: - 🎨 CÁC THÀNH PHẦN UI CHUẨN CSS HELPER (ĐỒNG BỘ ICON BOX & GẠCH CHÂN GRADIENT 38x3.5PT)
    private func cssSectionHeader(_ title: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6.5, style: .continuous)
                        .fill(SideJITCSSTheme.blue.opacity(0.14))
                        .frame(width: 22, height: 22)
                    Image(systemName: icon)
                        .font(.system(size: 11.5, weight: .heavy))
                        .foregroundColor(SideJITCSSTheme.blue)
                }

                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(SideJITCSSTheme.blue)
            }
            
            RoundedRectangle(cornerRadius: 1.75)
                .fill(SideJITCSSTheme.accentUnderlineGradient)
                .frame(width: 38, height: 3.5)
        }
        .padding(.leading, 4)
        .padding(.top, 2)
    }
    
    private func cssSectionFooter(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundColor(SideJITCSSTheme.pureBlack)
            .padding(.horizontal, 6)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private func cssCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(SideJITCSSTheme.white)
            .clipShape(RoundedRectangle(cornerRadius: SideJITCSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: SideJITCSSTheme.cornerRadius, style: .continuous)
                    .stroke(SideJITCSSTheme.border, lineWidth: 1.1)
            )
            .shadow(color: SideJITCSSTheme.blue.opacity(0.09), radius: 14, x: 0, y: 6)
    }
    
    private var cssDivider: some View {
        Rectangle()
            .fill(SideJITCSSTheme.border)
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
    
    private func diagnosticIcon(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.14))
                .frame(width: 32, height: 32)
            Image(systemName: systemName)
                .font(.system(size: 14.5, weight: .bold))
                .foregroundColor(color)
        }
    }
    
    private var copiedToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(SideJITCSSTheme.white)
            Text("Đã sao chép vào bộ nhớ tạm!")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(SideJITCSSTheme.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 11)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [SideJITCSSTheme.blue, SideJITCSSTheme.purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: SideJITCSSTheme.blue.opacity(0.35), radius: 8, x: 0, y: 4)
        .padding(.bottom, 20)
    }
    
    // MARK: - ⚙️ LOGIC XỬ LÝ MẠNG & CHẨN ĐOÁN (GIỮ NGUYÊN 100% CHUẨN GỐC)
    private func showCopied() {
        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.spring(response: 0.3)) {
                showCopiedToast = false
            }
        }
    }
    
    private func refreshServerState() {
        guard isServerEnabled else {
            connectionStatus = .disabled
            debugLog("[SideJITConfig] refreshServerState: SideJITServer is disabled")
            return
        }
        connectionStatus = .checking
        debugLog("[SideJITConfig] refreshServerState: resolving server URL (customAddress='\(customAddress)')")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            debugLog("[SideJITConfig] refreshServerState: resolved serverURL='\(serverURL)'")
            await MainActor.run {
                self.resolvedAddress = serverURL
            }
            await performPing(to: serverURL)
        }
    }
    
    private func performPing(to serverURL: String) async {
        guard let url = URL(string: serverURL) else {
            debugLog("[SideJITConfig] performPing: invalid URL string '\(serverURL)'")
            await MainActor.run {
                self.connectionStatus = .disconnected(reason: "URL không hợp lệ")
            }
            return
        }
        
        let start = Date()
        var request = URLRequest(url: url)
        request.timeoutInterval = AppConstants.SideJIT.timeout
        debugLog("[SideJITConfig] performPing: sending GET request to \(url) (timeout: \(AppConstants.SideJIT.timeout)s)")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            let payload = String(data: data, encoding: .utf8) ?? "<dữ liệu nhị phân>"
            debugLog("[SideJITConfig] performPing: success from \(url) (status=\(status), latency=\(latency)ms, bytes=\(data.count)):\n\(payload.prettyPrintedJSON)")
            
            await MainActor.run {
                if status >= 200 && status < 400 {
                    self.connectionStatus = .ready(latencyMs: latency, address: serverURL)
                } else {
                    self.connectionStatus = .disconnected(reason: "HTTP \(status)")
                }
                self.latestLog = SideJITResponseLog(
                    timestamp: Date(),
                    endpoint: "/",
                    httpMethod: "GET",
                    statusCode: status,
                    latencyMs: latency,
                    rawPayload: payload.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
        } catch {
            let latency = Int(Date().timeIntervalSince(start) * 1000)
            debugLog("[SideJITConfig] performPing: request failed for \(url) after \(latency)ms with error: \(error)")
            await MainActor.run {
                self.connectionStatus = .disconnected(reason: error.localizedDescription)
                self.latestLog = SideJITResponseLog(
                    timestamp: Date(),
                    endpoint: "/",
                    httpMethod: "GET",
                    statusCode: 0,
                    latencyMs: latency,
                    rawPayload: "Lỗi: \(error.localizedDescription)"
                )
            }
        }
    }
    
    private func testHealthCheck() {
        activeAction = .ping
        debugLog("[SideJITConfig] testHealthCheck: user triggered Test Connection (Ping)")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            await performPing(to: serverURL)
            await MainActor.run {
                self.activeAction = nil
            }
        }
    }
    
    private func triggerDeviceRefresh() {
        activeAction = .refresh
        debugLog("[SideJITConfig] triggerDeviceRefresh: user triggered Refresh Devices")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            guard let url = URL(string: "\(serverURL)/re/") else {
                debugLog("[SideJITConfig] triggerDeviceRefresh: invalid URL for '\(serverURL)/re/'")
                await MainActor.run { self.activeAction = nil }
                return
            }
            
            let start = Date()
            var request = URLRequest(url: url)
            request.timeoutInterval = AppConstants.SideJIT.timeout
            debugLog("[SideJITConfig] triggerDeviceRefresh: requesting \(url)")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                let payload = String(data: data, encoding: .utf8) ?? ""
                debugLog("[SideJITConfig] triggerDeviceRefresh: received status=\(status), latency=\(latency)ms:\n\(payload.prettyPrintedJSON)")
                
                await MainActor.run {
                    if status >= 200 && status < 400 {
                        self.connectionStatus = .ready(latencyMs: latency, address: serverURL)
                    }
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/re/",
                        httpMethod: "GET",
                        statusCode: status,
                        latencyMs: latency,
                        rawPayload: payload.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    self.activeAction = nil
                }
            } catch {
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                debugLog("[SideJITConfig] triggerDeviceRefresh: request failed after \(latency)ms with error: \(error)")
                await MainActor.run {
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/re/",
                        httpMethod: "GET",
                        statusCode: 0,
                        latencyMs: latency,
                        rawPayload: "Lỗi: \(error.localizedDescription)"
                    )
                    self.activeAction = nil
                }
            }
        }
    }
    
    private func queryVersionEndpoint() {
        activeAction = .version
        debugLog("[SideJITConfig] queryVersionEndpoint: user triggered Query Versions")
        Task {
            let serverURL = await SideJITManager.shared.resolveServerURL()
            guard let url = URL(string: "\(serverURL)/ver/") else {
                debugLog("[SideJITConfig] queryVersionEndpoint: invalid URL for '\(serverURL)/ver/'")
                await MainActor.run { self.activeAction = nil }
                return
            }
            
            let start = Date()
            var request = URLRequest(url: url)
            request.timeoutInterval = AppConstants.SideJIT.timeout
            debugLog("[SideJITConfig] queryVersionEndpoint: requesting \(url)")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                let payload = String(data: data, encoding: .utf8) ?? ""
                debugLog("[SideJITConfig] queryVersionEndpoint: received status=\(status), latency=\(latency)ms:\n\(payload.prettyPrintedJSON)")
                
                await MainActor.run {
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/ver/",
                        httpMethod: "GET",
                        statusCode: status,
                        latencyMs: latency,
                        rawPayload: payload.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    self.activeAction = nil
                }
            } catch {
                let latency = Int(Date().timeIntervalSince(start) * 1000)
                debugLog("[SideJITConfig] queryVersionEndpoint: request failed after \(latency)ms with error: \(error)")
                await MainActor.run {
                    self.latestLog = SideJITResponseLog(
                        timestamp: Date(),
                        endpoint: "/ver/",
                        httpMethod: "GET",
                        statusCode: 0,
                        latencyMs: latency,
                        rawPayload: "Lỗi: \(error.localizedDescription)"
                    )
                    self.activeAction = nil
                }
            }
        }
    }
}
