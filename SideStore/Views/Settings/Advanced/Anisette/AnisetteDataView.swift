
//
//  AnisetteDataView.swift
//  SideStore
//
//  Created by Magesh K on 31/7/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ SETTINGS)
private enum AnisetteCSSTheme {
    static let white = Color.white
    static let light = Color(red: 248/255, green: 249/255, blue: 250/255) // #f8f9fa
    static let border = Color(red: 233/255, green: 236/255, blue: 239/255) // #e9ecef
    static let blue = Color(red: 0/255, green: 123/255, blue: 255/255) // #007bff
    static let purple = Color(red: 111/255, green: 66/255, blue: 193/255) // #6f42c1
    static let green = Color(red: 40/255, green: 167/255, blue: 69/255) // #28a745
    static let magenta = Color(red: 255/255, green: 0/255, blue: 255/255) // #ff00ff
    static let dark = Color(red: 52/255, green: 58/255, blue: 64/255) // #343a40

    // Gradient Nền chính (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = Color(red: 243/255, green: 224/255, blue: 255/255)
    static let bgGradientEnd = Color(red: 224/255, green: 247/255, blue: 255/255)

    // Gradient Hero Banner
    static let heroStart = Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.92)
    static let heroEnd = Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.88)

    static let cornerRadius: CGFloat = 15.0
}

@MainActor
class AnisetteDataViewModel: ObservableObject {
    @Published var clientInfo: String = ""
    @Published var userAgent: String = ""
    @Published var customDeviceID: String = ""
    @Published var customLocalUserID: String = ""
    @Published var customLocale: String = ""
    @Published var customTimeZone: String = ""
    @Published var customSerialNumber: String = ""
    @Published var customRoutingInfo: String = ""

    @Published var isLoading: Bool = false

    @Published var viewMode: Int = 0 // 0 = Tương tác, 1 = Mã JSON
    @Published var rawEditableJSON: String = ""
    @Published var serverReturnedHeadersJSON: String = "{}"

    init() {
        Task {
            await loadData()
        }
    }

    func loadData() async {
        let config = await AnisetteConfigManager.shared.loadConfig()
        clientInfo = config.clientInfo
        userAgent = config.userAgent
        customDeviceID = config.customDeviceID ?? ""
        customLocalUserID = config.customLocalUserID ?? ""
        customLocale = config.customLocale ?? ""
        customTimeZone = config.customTimeZone ?? ""
        customSerialNumber = config.customSerialNumber ?? ""
        customRoutingInfo = config.customRoutingInfo ?? ""

        updateRawEditableJSON()

        let serverHeaders = await AnisetteConfigManager.shared.loadServerHeaders()
        if let data = try? JSONSerialization.data(withJSONObject: serverHeaders, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
           let str = String(data: data, encoding: .utf8) {
            serverReturnedHeadersJSON = str
        }
    }

    func updateRawEditableJSON() {
        var dict: [String: String] = [
            "clientInfo": clientInfo,
            "userAgent": userAgent
        ]
        if !customDeviceID.isEmpty { dict["customDeviceID"] = customDeviceID }
        if !customLocalUserID.isEmpty { dict["customLocalUserID"] = customLocalUserID }
        if !customLocale.isEmpty { dict["customLocale"] = customLocale }
        if !customTimeZone.isEmpty { dict["customTimeZone"] = customTimeZone }
        if !customSerialNumber.isEmpty { dict["customSerialNumber"] = customSerialNumber }
        if !customRoutingInfo.isEmpty { dict["customRoutingInfo"] = customRoutingInfo }

        if let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
           let str = String(data: data, encoding: .utf8) {
            rawEditableJSON = str
        }
    }

    func save() async {
        let currentConfig = await AnisetteConfigManager.shared.loadConfig()
        let config = AnisetteConfig(
            clientInfo: clientInfo,
            userAgent: userAgent,
            customDeviceID: customDeviceID.isEmpty ? nil : customDeviceID,
            customLocalUserID: customLocalUserID.isEmpty ? nil : customLocalUserID,
            customLocale: customLocale.isEmpty ? nil : customLocale,
            customTimeZone: customTimeZone.isEmpty ? nil : customTimeZone,
            customXcodeVersion: currentConfig.customXcodeVersion,
            customSerialNumber: customSerialNumber.isEmpty ? nil : customSerialNumber,
            customRoutingInfo: customRoutingInfo.isEmpty ? nil : customRoutingInfo
        )
        await AnisetteConfigManager.shared.saveConfig(config)
        updateRawEditableJSON()
        showToast(text: "Đã lưu cấu hình thành công!")
    }

    func saveRawJSON() async {
        guard let data = rawEditableJSON.data(using: .utf8) else {
            showToast(text: "Lỗi mã hóa dữ liệu", detailText: "Không thể mã hóa chuỗi JSON sang định dạng UTF-8.")
            return
        }

        do {
            let config = try Foundation.JSONDecoder().decode(AnisetteConfig.self, from: data)

            clientInfo = config.clientInfo
            userAgent = config.userAgent
            customDeviceID = config.customDeviceID ?? ""
            customLocalUserID = config.customLocalUserID ?? ""
            customLocale = config.customLocale ?? ""
            customTimeZone = config.customTimeZone ?? ""
            customSerialNumber = config.customSerialNumber ?? ""
            customRoutingInfo = config.customRoutingInfo ?? ""

            await AnisetteConfigManager.shared.saveConfig(config)
            updateRawEditableJSON()
            showToast(text: "Đã lưu cấu hình JSON thành công!")
        } catch {
            showToast(text: "Cấu trúc JSON không hợp lệ", error: error)
        }
    }

    func reset() async {
        let config = await AnisetteConfigManager.shared.resetToDefaults()
        clientInfo = config.clientInfo
        userAgent = config.userAgent
        customDeviceID = ""
        customLocalUserID = ""
        customLocale = ""
        customTimeZone = ""
        customSerialNumber = ""
        customRoutingInfo = ""
        updateRawEditableJSON()
        await save()
        showToast(text: "Đã khôi phục về cấu hình mặc định.")
    }

    func importJSON(url: URL) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let gotAccess = url.startAccessingSecurityScopedResource()
            defer {
                if gotAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let config = try await AnisetteConfigManager.shared.importFromFile(url: url)
            clientInfo = config.clientInfo
            userAgent = config.userAgent
            customDeviceID = config.customDeviceID ?? ""
            customLocalUserID = config.customLocalUserID ?? ""
            customLocale = config.customLocale ?? ""
            customTimeZone = config.customTimeZone ?? ""
            customSerialNumber = config.customSerialNumber ?? ""
            customRoutingInfo = config.customRoutingInfo ?? ""
            updateRawEditableJSON()
            showToast(text: "Nhập cấu hình thành công!", detailText: url.lastPathComponent)
        } catch {
            showToast(text: "Nhập cấu hình thất bại", error: error)
        }
    }

    func exportJSON() async -> URL? {
        guard let data = await AnisetteConfigManager.shared.exportConfigData() else { return nil }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("anisette-config.json")
        do {
            try data.write(to: tempURL, options: .atomic)
            return tempURL
        } catch {
            showToast(text: "Xuất cấu hình thất bại", error: error)
            return nil
        }
    }

    func fetchFreshFromServer() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let activeServer = UserDefaults.standard.menuAnisetteURL
            guard !activeServer.isEmpty, let url = URL(string: activeServer) else {
                throw NSError(domain: "AnisetteDataViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Chưa cấu hình địa chỉ máy chủ Anisette đang hoạt động."])
            }

            let clientInfoURL = url.appendingPathComponent("v3").appendingPathComponent("client_info")
            var request = URLRequest(url: clientInfoURL)
            request.timeoutInterval = 10

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: String] else {
                throw NSError(domain: "AnisetteDataViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Phản hồi từ máy chủ không phải là định dạng JSON hợp lệ."])
            }

            await AnisetteConfigManager.shared.saveServerHeaders(json)

            let serverHeaders = await AnisetteConfigManager.shared.loadServerHeaders()
            if let data = try? JSONSerialization.data(withJSONObject: serverHeaders, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]),
               let str = String(data: data, encoding: .utf8) {
                serverReturnedHeadersJSON = str
            }

            showToast(text: "Đã tải cấu hình từ máy chủ!", detailText: url.host)
        } catch {
            showToast(text: "Không thể tải từ máy chủ", error: error)
        }
    }

    func loadServerHeadersIntoOverrides() async {
        let serverHeaders = await AnisetteConfigManager.shared.loadServerHeaders()
        guard !serverHeaders.isEmpty else {
            showToast(text: "Chưa có dữ liệu từ máy chủ", detailText: "Vui lòng bấm Tải về từ máy chủ trước.")
            return
        }

        func getValue(forKeys keys: [String]) -> String? {
            for key in keys {
                if let val = serverHeaders[key] {
                    return val
                }
            }
            return nil
        }

        if let val = getValue(forKeys: ["client_info", "clientInfo", "X-Mme-Client-Info"]) {
            clientInfo = val
        }
        if let val = getValue(forKeys: ["user_agent", "userAgent", "User-Agent"]) {
            userAgent = val
        }
        if let val = getValue(forKeys: ["custom_device_id", "customDeviceID", "X-Mme-Device-Id", "deviceUniqueIdentifier"]) {
            customDeviceID = val
        }
        if let val = getValue(forKeys: ["custom_local_user_id", "customLocalUserID", "X-Apple-I-MD-LU", "localUserID"]) {
            customLocalUserID = val
        }
        if let val = getValue(forKeys: ["custom_locale", "customLocale", "X-Apple-Locale", "locale"]) {
            customLocale = val
        }
        if let val = getValue(forKeys: ["custom_time_zone", "customTimeZone", "X-Apple-I-TimeZone", "timeZone"]) {
            customTimeZone = val
        }
        if let val = getValue(forKeys: ["custom_serial_number", "customSerialNumber", "X-Apple-I-SRL-NO", "serialNumber"]) {
            customSerialNumber = val
        }
        if let val = getValue(forKeys: ["custom_routing_info", "customRoutingInfo", "X-Apple-I-MD-RINFO", "routingInfo"]) {
            customRoutingInfo = val
        }

        await save()
        showToast(text: "Đã áp dụng dữ liệu máy chủ vào cấu hình!")
    }

    func showToast(text: String, detailText: String? = nil, error: Error? = nil) {
        let toast: ToastView
        if let error = error {
            toast = ToastView(error: error, opensLog: true)
        } else {
            toast = ToastView(text: text, detailText: detailText)
        }

        if let presentingVC = PresenterProvider.shared.topViewController ?? UIApplication.shared.topViewController() {
            toast.show(in: presentingVC)
        }
    }
}

struct AnisetteDataView: View {
    @StateObject private var viewModel = AnisetteDataViewModel()
    @State private var showingResetAlert = false
    @State private var showingFileImporter = false
    @State private var showingServerHeaders = false
    @State private var isCopiedServer = false
    @State private var exportURL: URL? = nil

    var body: some View {
        ZStack {
            // Nền Gradient cố định xuyên suốt đồng bộ với SettingsViewController
            LinearGradient(
                gradient: Gradient(colors: [AnisetteCSSTheme.bgGradientStart, AnisetteCSSTheme.bgGradientEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    // Khoảng trống phía trên cho nút Back tròn nổi của SettingsViewController
                    Spacer().frame(height: 26)

                    // Khối Hero Banner đồng bộ giao diện gốc
                    heroBanner

                    // Thanh chuyển đổi chế độ xem
                    Picker("Chế độ xem", selection: $viewModel.viewMode) {
                        Text("Giao diện Tương tác").tag(0)
                        Text("Mã JSON Thô").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(6)
                    .background(AnisetteCSSTheme.white.opacity(0.92))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AnisetteCSSTheme.border, lineWidth: 1)
                    )
                    .shadow(color: AnisetteCSSTheme.blue.opacity(0.06), radius: 8, x: 0, y: 4)

                    if viewModel.viewMode == 0 {
                        // MỤC 1: THÔNG TIN TRÌNH KHÁCH CHÍNH
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("THÔNG TIN TRÌNH KHÁCH CHÍNH")

                            cssCard {
                                headerFieldRow(
                                    title: "Thông tin Trình khách (Client Info)",
                                    headerKey: "X-Mme-Client-Info",
                                    text: $viewModel.clientInfo,
                                    placeholder: AppConstants.Anisette.defaultClientInfo,
                                    isMultiline: true
                                )

                                divider

                                headerFieldRow(
                                    title: "Định danh Ứng dụng (User Agent)",
                                    headerKey: "User-Agent",
                                    text: $viewModel.userAgent,
                                    placeholder: AppConstants.Anisette.defaultUserAgent,
                                    isMultiline: true
                                )
                            }
                        }

                        // MỤC 2: THIẾT BỊ & ĐỊNH DANH
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("THIẾT BỊ & ĐỊNH DANH")

                            cssCard {
                                headerFieldRow(
                                    title: "Mã định danh Thiết bị (Device UUID)",
                                    headerKey: "X-Mme-Device-Id",
                                    text: $viewModel.customDeviceID,
                                    placeholder: "UUID thiết bị do hệ thống tự tạo"
                                )

                                divider

                                headerFieldRow(
                                    title: "ID Người dùng Cục bộ (Local User ID)",
                                    headerKey: "X-Apple-I-MD-LU",
                                    text: $viewModel.customLocalUserID,
                                    placeholder: "0"
                                )

                                divider

                                headerFieldRow(
                                    title: "Số Sê-ri Thiết bị (Serial Number)",
                                    headerKey: "X-Apple-I-SRL-NO",
                                    text: $viewModel.customSerialNumber,
                                    placeholder: AppConstants.Anisette.defaultDeviceSerialNumber
                                )

                                divider

                                headerFieldRow(
                                    title: "Thông tin Định tuyến (Routing Info)",
                                    headerKey: "X-Apple-I-MD-RINFO",
                                    text: $viewModel.customRoutingInfo,
                                    placeholder: "17106176"
                                )
                            }
                        }

                        // MỤC 3: MÔI TRƯỜNG & VÙNG ĐỊA LÝ
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("MÔI TRƯỜNG & VÙNG ĐỊA LÝ")

                            cssCard {
                                headerFieldRow(
                                    title: "Ngôn ngữ & Khu vực (Locale)",
                                    headerKey: "X-Apple-Locale",
                                    text: $viewModel.customLocale,
                                    placeholder: "en_US"
                                )

                                divider

                                headerFieldRow(
                                    title: "Múi giờ Hệ thống (Time Zone)",
                                    headerKey: "X-Apple-I-TimeZone",
                                    text: $viewModel.customTimeZone,
                                    placeholder: "VD: UTC, Asia/Ho_Chi_Minh",
                                    autocapitalization: .allCharacters
                                )
                            }
                        }

                        // MỤC 4: MÃ BẢO MẬT ĐỘNG (CHỈ HIỂN THỊ THÔNG TIN)
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("MÃ BẢO MẬT ĐỘNG (TỰ ĐỘNG TÍNH TOÁN)")

                            cssCard {
                                infoTokenRow(
                                    title: "Mật khẩu Một lần (OTP)",
                                    headerKey: "X-Apple-I-MD",
                                    subtitle: "Mã băm HMAC được bộ máy ADI tự động tính toán riêng cho mỗi yêu cầu"
                                )

                                divider

                                infoTokenRow(
                                    title: "Mã định danh Máy (Machine ID)",
                                    headerKey: "X-Apple-I-MD-M",
                                    subtitle: "Định danh phần cứng được trích xuất từ tệp adi.pb và thông tin thiết bị"
                                )

                                divider

                                infoTokenRow(
                                    title: "Thời gian Trình khách (Client Time)",
                                    headerKey: "X-Apple-I-Client-Time",
                                    subtitle: "Mốc thời gian chuẩn ISO8601 UTC khớp với thời điểm khởi tạo mã OTP"
                                )
                            }
                        }

                        // NÚT LƯU CẤU HÌNH TÙY CHỈNH
                        SwiftUI.Button {
                            Task {
                                await viewModel.save()
                            }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Lưu Cấu Hình Tùy Chỉnh", systemImage: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [AnisetteCSSTheme.blue, AnisetteCSSTheme.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(AnisetteCSSTheme.cornerRadius)
                            .shadow(color: AnisetteCSSTheme.blue.opacity(0.28), radius: 10, x: 0, y: 5)
                        }
                        .disabled(viewModel.clientInfo.isEmpty || viewModel.userAgent.isEmpty)
                        .opacity((viewModel.clientInfo.isEmpty || viewModel.userAgent.isEmpty) ? 0.5 : 1.0)

                    } else {
                        // CHẾ ĐỘ XEM MÃ JSON THÔ
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("DỮ LIỆU CẤU HÌNH JSON THÔ")

                            cssCard {
                                VStack(spacing: 14) {
                                    customTextEditor(text: $viewModel.rawEditableJSON, minHeight: 300)

                                    SwiftUI.Button {
                                        Task {
                                            await viewModel.saveRawJSON()
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Label("Lưu Mã JSON", systemImage: "square.and.arrow.down.fill")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.white)
                                            Spacer()
                                        }
                                        .frame(height: 48)
                                        .background(
                                            LinearGradient(
                                                gradient: Gradient(colors: [AnisetteCSSTheme.blue, AnisetteCSSTheme.purple]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .cornerRadius(12)
                                        .shadow(color: AnisetteCSSTheme.blue.opacity(0.25), radius: 8, x: 0, y: 4)
                                    }
                                    .disabled(viewModel.rawEditableJSON.isEmpty)
                                    .opacity(viewModel.rawEditableJSON.isEmpty ? 0.5 : 1.0)
                                }
                                .padding(16)
                            }
                        }
                    }

                    // MỤC ĐỒNG BỘ MÁY CHỦ TỪ XA (CHỈ HIỆN KHI TẮT ON-DEVICE ANISETTE)
                    if !UserDefaults.standard.useOnDeviceAnisette {
                        VStack(alignment: .leading, spacing: 10) {
                            sectionHeader("ĐỒNG BỘ TỪ MÁY CHỦ ANISETTE")

                            cssCard {
                                DisclosureGroup(isExpanded: $showingServerHeaders) {
                                    VStack(alignment: .leading, spacing: 12) {
                                        divider.padding(.horizontal, -16)

                                        HStack {
                                            Text("Máy chủ: \(URL(string: UserDefaults.standard.menuAnisetteURL)?.host ?? "Đang hoạt động")")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(AnisetteCSSTheme.purple)
                                            Spacer()
                                            SwiftUI.Button {
                                                #if !os(tvOS)
                                                UIPasteboard.general.string = viewModel.serverReturnedHeadersJSON
                                                #endif
                                                withAnimation { isCopiedServer = true }
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                    withAnimation { isCopiedServer = false }
                                                }
                                            } label: {
                                                HStack(spacing: 4) {
                                                    Image(systemName: isCopiedServer ? "checkmark" : "doc.on.doc")
                                                    Text(isCopiedServer ? "Đã chép" : "Sao chép")
                                                }
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(isCopiedServer ? AnisetteCSSTheme.green : AnisetteCSSTheme.blue)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background((isCopiedServer ? AnisetteCSSTheme.green : AnisetteCSSTheme.blue).opacity(0.1))
                                                .cornerRadius(8)
                                            }
                                        }

                                        ScrollView(.horizontal, showsIndicators: true) {
                                            Text(viewModel.serverReturnedHeadersJSON)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(AnisetteCSSTheme.dark)
                                                .padding(10)
                                                .background(AnisetteCSSTheme.light)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(AnisetteCSSTheme.border, lineWidth: 1)
                                                )
                                        }

                                        SwiftUI.Button {
                                            Task {
                                                await viewModel.loadServerHeadersIntoOverrides()
                                            }
                                        } label: {
                                            HStack {
                                                Spacer()
                                                Label("Áp Dụng Vào Cấu Hình Hiện Tại", systemImage: "square.and.arrow.down.on.square")
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundColor(.white)
                                                Spacer()
                                            }
                                            .frame(height: 44)
                                            .background(AnisetteCSSTheme.blue)
                                            .cornerRadius(10)
                                        }
                                        .disabled(viewModel.serverReturnedHeadersJSON == "{}" || viewModel.serverReturnedHeadersJSON.isEmpty)
                                    }
                                    .padding(.top, 8)
                                } label: {
                                    HStack {
                                        Label("Đồng bộ cấu hình máy chủ", systemImage: "network")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.black)
                                        Spacer()
                                        SwiftUI.Button {
                                            Task {
                                                await viewModel.fetchFreshFromServer()
                                                withAnimation { showingServerHeaders = true }
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Tải về")
                                            }
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(AnisetteCSSTheme.blue)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(AnisetteCSSTheme.blue.opacity(0.1))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(AnisetteCSSTheme.blue.opacity(0.25), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .accentColor(AnisetteCSSTheme.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                        }
                    }

                    // MỤC THAO TÁC TỆP & KHÔI PHỤC
                    VStack(alignment: .leading, spacing: 10) {
                        sectionHeader("QUẢN LÝ & KHÔI PHỤC CẤU HÌNH")

                        cssCard {
                            SwiftUI.Button {
                                #if !os(tvOS)
                                showingFileImporter = true
                                #else
                                if let topVC = PresenterProvider.shared.topViewController ?? UIApplication.shared.topViewController() {
                                    TVWebFileTransferManager.shared.startImport(
                                        acceptedExtensions: ["json"],
                                        title: "Nhập tệp JSON Cấu hình Anisette",
                                        presentingVC: topVC
                                    ) { fileURL in
                                        guard let fileURL = fileURL else { return }
                                        Task {
                                            await viewModel.importJSON(url: fileURL)
                                        }
                                    }
                                }
                                #endif
                            } label: {
                                HStack {
                                    Label("Nhập cấu hình từ tệp JSON", systemImage: "square.and.arrow.down")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AnisetteCSSTheme.dark.opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 50)
                            }

                            divider

                            SwiftUI.Button {
                                Task {
                                    if let url = await viewModel.exportJSON() {
                                        exportURL = url
                                    }
                                }
                            } label: {
                                HStack {
                                    Label("Xuất cấu hình ra tệp JSON", systemImage: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AnisetteCSSTheme.dark.opacity(0.4))
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 50)
                            }

                            divider

                            SwiftUI.Button(role: .destructive) {
                                showingResetAlert = true
                            } label: {
                                HStack {
                                    Label("Khôi phục về Mặc định", systemImage: "arrow.circlepath")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AnisetteCSSTheme.magenta)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 50)
                            }
                            .alert("Khôi phục về Mặc định?", isPresented: $showingResetAlert) {
                                SwiftUI.Button("Khôi phục", role: .destructive) {
                                    Task {
                                        await viewModel.reset()
                                    }
                                }
                                SwiftUI.Button("Hủy", role: .cancel) {}
                            } message: {
                                Text("Thao tác này sẽ đặt lại toàn bộ thông số cấu hình Anisette Client về giá trị khuyến nghị ban đầu.")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("")
        #if !os(tvOS)
        .navigationBarHidden(true)
        #endif
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView("Đang xử lý...")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AnisetteCSSTheme.blue)
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AnisetteCSSTheme.white)
                                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
                        )
                }
            }
        )
        #if !os(tvOS)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    Task {
                        await viewModel.importJSON(url: url)
                    }
                }
            case .failure(let error):
                viewModel.showToast(text: "Không thể chọn tệp", error: error)
            }
        }
        #endif
        .sheet(isPresented: Binding<Bool>(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )) {
            if let url = exportURL {
                ActivityViewController(activityItems: [url])
            }
        }
    }

    // MARK: - 💎 CÁC THÀNH PHẦN GIAO DIỆN ĐỒNG BỘ CSS THEME

    private var heroBanner: some View {
        VStack(spacing: 4) {
            Text("Cấu Hình Anisette")
                .font(.system(size: 23, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 4, x: 1, y: 2)

            Text("Tùy chỉnh định danh thiết bị & đồng bộ thông số xác thực ID Apple")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [AnisetteCSSTheme.heroStart, AnisetteCSSTheme.heroEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AnisetteCSSTheme.cornerRadius)
        .shadow(color: AnisetteCSSTheme.blue.opacity(0.25), radius: 14, x: 0, y: 6)
    }

    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(AnisetteCSSTheme.blue)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(AnisetteCSSTheme.blue)
                .frame(width: 38, height: 3)
        }
        .padding(.horizontal, 4)
    }

    private func cssCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(AnisetteCSSTheme.white)
        .cornerRadius(AnisetteCSSTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: AnisetteCSSTheme.cornerRadius)
                .stroke(AnisetteCSSTheme.border, lineWidth: 1)
        )
        .shadow(color: AnisetteCSSTheme.blue.opacity(0.07), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func customTextEditor(text: Binding<String>, minHeight: CGFloat) -> some View {
        #if !os(tvOS)
        if #available(iOS 16.0, *) {
            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AnisetteCSSTheme.dark)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(AnisetteCSSTheme.light)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AnisetteCSSTheme.border, lineWidth: 1)
                )
        } else {
            TextEditor(text: text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(AnisetteCSSTheme.dark)
                .frame(minHeight: minHeight)
                .padding(8)
                .background(AnisetteCSSTheme.light)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AnisetteCSSTheme.border, lineWidth: 1)
                )
        }
        #else
        TextField("", text: text)
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(AnisetteCSSTheme.dark)
            .padding(8)
            .background(AnisetteCSSTheme.light)
            .cornerRadius(10)
        #endif
    }

    private func headerFieldRow(
        title: String,
        headerKey: String,
        text: Binding<String>,
        placeholder: String,
        isMultiline: Bool = false,
        autocapitalization: UITextAutocapitalizationType = .none
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                Spacer()
                Text(headerKey)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(AnisetteCSSTheme.purple)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(AnisetteCSSTheme.purple.opacity(0.1))
                    .cornerRadius(5)
            }

            if isMultiline {
                customTextEditor(text: text, minHeight: 64)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(AnisetteCSSTheme.dark)
                    .autocapitalization(autocapitalization)
                    .disableAutocorrection(true)
                    .padding(10)
                    .background(AnisetteCSSTheme.light)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AnisetteCSSTheme.border, lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func infoTokenRow(title: String, headerKey: String, subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Spacer()
                    Text(headerKey)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(AnisetteCSSTheme.blue)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(AnisetteCSSTheme.blue.opacity(0.1))
                        .cornerRadius(5)
                }
                Text(subtitle)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(AnisetteCSSTheme.dark.opacity(0.78))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Rectangle()
            .fill(AnisetteCSSTheme.border)
            .frame(height: 1.0)
            .padding(.horizontal, 16)
    }
}
