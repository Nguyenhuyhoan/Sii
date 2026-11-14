
//
//  AnisetteDataView.swift
//  SideStore
//
//  Created by Magesh K on 31/7/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (TƯƠNG PHẢN CAO - DỄ ĐỌC)
private enum AnisetteCSSTheme {
    static let white = Color.white
    static let inputBg = Color(red: 242/255, green: 245/255, blue: 250/255) // Nền ô nhập dịu mắt, rõ chữ
    static let border = Color(red: 210/255, green: 218/255, blue: 226/255) // Viền sắc nét hơn
    static let inputBorder = Color(red: 190/255, green: 202/255, blue: 216/255) // Viền khung nhập liệu rõ ràng
    static let blue = Color(red: 0/255, green: 110/255, blue: 235/255) // Xanh đậm chuẩn dễ đọc
    static let purple = Color(red: 102/255, green: 51/255, blue: 185/255) // Tím đậm rõ nét
    static let green = Color(red: 30/255, green: 150/255, blue: 60/255)
    static let danger = Color(red: 220/255, green: 38/255, blue: 38/255) // Đỏ đậm dễ đọc thay cho hồng chói
    static let textPrimary = Color(red: 18/255, green: 24/255, blue: 33/255) // Đen đậm sắc nét
    static let textSecondary = Color(red: 55/255, green: 65/255, blue: 81/255) // Xám đậm dễ đọc cho chữ nhỏ

    // Gradient Nền chính (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = Color(red: 243/255, green: 224/255, blue: 255/255)
    static let bgGradientEnd = Color(red: 224/255, green: 247/255, blue: 255/255)

    // Gradient Hero Banner
    static let heroStart = Color(red: 0/255, green: 115/255, blue: 245/255)
    static let heroEnd = Color(red: 105/255, green: 58/255, blue: 190/255)

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

        if let presentingVC = UIApplication.shared.topViewController() {
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

                    // Thanh chuyển đổi chế độ xem (Custom Segmented Control cực rõ chữ)
                    modeSwitcher

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
                                    .font(.system(size: 16.5, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .frame(height: 52)
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
                                    customTextEditor(text: $viewModel.rawEditableJSON, minHeight: 310)

                                    SwiftUI.Button {
                                        Task {
                                            await viewModel.saveRawJSON()
                                        }
                                    } label: {
                                        HStack {
                                            Spacer()
                                            Label("Lưu Mã JSON", systemImage: "square.and.arrow.down.fill")
                                                .font(.system(size: 16.5, weight: .bold))
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
                                                .font(.system(size: 13.5, weight: .bold))
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
                                                HStack(spacing: 5) {
                                                    Image(systemName: isCopiedServer ? "checkmark" : "doc.on.doc")
                                                    Text(isCopiedServer ? "Đã chép" : "Sao chép")
                                                }
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundColor(isCopiedServer ? AnisetteCSSTheme.green : AnisetteCSSTheme.blue)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background((isCopiedServer ? AnisetteCSSTheme.green : AnisetteCSSTheme.blue).opacity(0.12))
                                                .cornerRadius(8)
                                            }
                                        }

                                        ScrollView(.horizontal, showsIndicators: true) {
                                            Text(viewModel.serverReturnedHeadersJSON)
                                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                                .foregroundColor(AnisetteCSSTheme.textPrimary)
                                                .padding(12)
                                                .background(AnisetteCSSTheme.inputBg)
                                                .cornerRadius(10)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(AnisetteCSSTheme.inputBorder, lineWidth: 1)
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
                                                    .font(.system(size: 15, weight: .bold))
                                                    .foregroundColor(.white)
                                                Spacer()
                                            }
                                            .frame(height: 46)
                                            .background(AnisetteCSSTheme.blue)
                                            .cornerRadius(10)
                                        }
                                        .disabled(viewModel.serverReturnedHeadersJSON == "{}" || viewModel.serverReturnedHeadersJSON.isEmpty)
                                    }
                                    .padding(.top, 10)
                                } label: {
                                    HStack {
                                        Label("Đồng bộ cấu hình máy chủ", systemImage: "network")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(AnisetteCSSTheme.textPrimary)
                                        Spacer()
                                        SwiftUI.Button {
                                            Task {
                                                await viewModel.fetchFreshFromServer()
                                                withAnimation { showingServerHeaders = true }
                                            }
                                        } label: {
                                            HStack(spacing: 5) {
                                                Image(systemName: "arrow.clockwise")
                                                Text("Tải về")
                                            }
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundColor(AnisetteCSSTheme.blue)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(AnisetteCSSTheme.blue.opacity(0.12))
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(AnisetteCSSTheme.blue.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                }
                                .accentColor(AnisetteCSSTheme.blue)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
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
                                if let topVC = UIApplication.shared.topViewController() {
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
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AnisetteCSSTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AnisetteCSSTheme.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
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
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(AnisetteCSSTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(AnisetteCSSTheme.textSecondary)
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
                            }

                            divider

                            SwiftUI.Button(role: .destructive) {
                                showingResetAlert = true
                            } label: {
                                HStack {
                                    Label("Khôi phục về Mặc định", systemImage: "arrow.circlepath")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(AnisetteCSSTheme.danger)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .frame(height: 52)
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
        // Khóa môi trường Light Mode cho View này để chữ trong TextField/TextEditor không bao giờ bị biến thành màu trắng khi máy bật Dark Mode
        .environment(\.colorScheme, .light)
        .navigationTitle("")
        #if !os(tvOS)
        .navigationBarHidden(true)
        #endif
        .overlay(
            Group {
                if viewModel.isLoading {
                    ProgressView("Đang xử lý...")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AnisetteCSSTheme.blue)
                        .padding(22)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(AnisetteCSSTheme.white)
                                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 4)
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

    // MARK: - 💎 CÁC THÀNH PHẦN GIAO DIỆN ĐỒNG BỘ CSS THEME (TƯƠNG PHẢN CAO)

    private var heroBanner: some View {
        VStack(spacing: 6) {
            Text("Cấu Hình Anisette")
                .font(.system(size: 24, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)

            Text("Tùy chỉnh định danh thiết bị & đồng bộ thông số xác thực ID Apple")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [AnisetteCSSTheme.heroStart, AnisetteCSSTheme.heroEnd]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AnisetteCSSTheme.cornerRadius)
        .shadow(color: AnisetteCSSTheme.blue.opacity(0.28), radius: 14, x: 0, y: 6)
    }

    /// Khung chuyển đổi chế độ xem Tương tác / JSON được thiết kế riêng đảm bảo độ tương phản cao nhất
    private var modeSwitcher: some View {
        HStack(spacing: 8) {
            modeTabButton(title: "Giao diện Tương tác", icon: "slider.horizontal.3", tag: 0)
            modeTabButton(title: "Mã JSON Thô", icon: "curlybraces", tag: 1)
        }
        .padding(6)
        .background(AnisetteCSSTheme.white)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AnisetteCSSTheme.border, lineWidth: 1.2)
        )
        .shadow(color: AnisetteCSSTheme.blue.opacity(0.08), radius: 8, x: 0, y: 4)
    }

    private func modeTabButton(title: String, icon: String, tag: Int) -> some View {
        let isSelected = viewModel.viewMode == tag
        return SwiftUI.Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.viewMode = tag
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 14.5, weight: .bold))
            }
            .foregroundColor(isSelected ? .white : AnisetteCSSTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Group {
                    if isSelected {
                        LinearGradient(
                            gradient: Gradient(colors: [AnisetteCSSTheme.blue, AnisetteCSSTheme.purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        AnisetteCSSTheme.inputBg
                    }
                }
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.clear : AnisetteCSSTheme.inputBorder.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 14.5, weight: .heavy))
                .foregroundColor(AnisetteCSSTheme.blue)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(AnisetteCSSTheme.blue)
                .frame(width: 42, height: 3)
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
                .stroke(AnisetteCSSTheme.border, lineWidth: 1.2)
        )
        .shadow(color: AnisetteCSSTheme.blue.opacity(0.08), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func customTextEditor(text: Binding<String>, minHeight: CGFloat) -> some View {
        #if !os(tvOS)
        if #available(iOS 16.0, *) {
            TextEditor(text: text)
                .scrollContentBackground(.hidden)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(AnisetteCSSTheme.textPrimary)
                .frame(minHeight: minHeight)
                .padding(10)
                .background(AnisetteCSSTheme.inputBg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AnisetteCSSTheme.inputBorder, lineWidth: 1.2)
                )
        } else {
            TextEditor(text: text)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(AnisetteCSSTheme.textPrimary)
                .frame(minHeight: minHeight)
                .padding(10)
                .background(AnisetteCSSTheme.inputBg)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(AnisetteCSSTheme.inputBorder, lineWidth: 1.2)
                )
        }
        #else
        TextField("", text: text)
            .font(.system(size: 14, weight: .semibold, design: .monospaced))
            .foregroundColor(AnisetteCSSTheme.textPrimary)
            .padding(10)
            .background(AnisetteCSSTheme.inputBg)
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
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(AnisetteCSSTheme.textPrimary)
                Spacer()
                Text(headerKey)
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .foregroundColor(AnisetteCSSTheme.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AnisetteCSSTheme.purple.opacity(0.14))
                    .cornerRadius(6)
            }

            if isMultiline {
                customTextEditor(text: text, minHeight: 72)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(AnisetteCSSTheme.textPrimary)
                    .autocapitalization(autocapitalization)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(AnisetteCSSTheme.inputBg)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(AnisetteCSSTheme.inputBorder, lineWidth: 1.2)
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func infoTokenRow(title: String, headerKey: String, subtitle: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 8) {
                    Text(title)
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(AnisetteCSSTheme.textPrimary)
                    Spacer()
                    Text(headerKey)
                        .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                        .foregroundColor(AnisetteCSSTheme.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AnisetteCSSTheme.blue.opacity(0.14))
                        .cornerRadius(6)
                }
                Text(subtitle)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(AnisetteCSSTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(AnisetteCSSTheme.border)
            .frame(height: 1.0)
            .padding(.horizontal, 16)
    }
}
