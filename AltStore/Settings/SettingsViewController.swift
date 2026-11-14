
//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import SafariServices
import UniformTypeIdentifiers
import Combine

import AltStoreCore
importRoxas

import Minimuxer
import MinimuxerCommon
import SemanticVersion

// MARK: - 🎨 BỘ GIAO DIỆN ĐỒNG BỘ 100% VỚI MẪU CSS & TAB KIỂM TRA (CHỮ ĐEN TUYỀN RÕ NÉT)
private enum SettingsCSSTheme {
    static let primaryBlue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)      // #007bff
    static let primaryGreen = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)     // #28a745
    static let primaryPurple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)   // #6f42c1
    static let primaryRed = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)       // #dc3545
    static let neonMagenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0)      // #ff00ff

    static let pureBlack = UIColor.black                                                         // #000000
    static let darkGray = UIColor.black                                                          // #000000
    static let secondaryText = UIColor.black                                                     // #000000
    static let white = UIColor.white                                                             // #ffffff
    static let borderColor = UIColor(red: 218/255, green: 224/255, blue: 233/255, alpha: 1.0)    // Viền sắc nét
    static let softHoverBg = UIColor(red: 243/255, green: 247/255, blue: 255/255, alpha: 1.0)

    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor // #f3e0ff
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor   // #e0f7ff

    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.94).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.90).cgColor

    static let cardCornerRadius: CGFloat = 15.0
    static let horizontalInset: CGFloat = 16.0

    // SwiftUI Colors dùng cho mục Máy chủ Anisette
    static let swiftPrimary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)
    static let swiftSecondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
    static let swiftGreen = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)
    static let swiftRed = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)
    static let swiftPureBlack = SwiftUI.Color.black
    static let swiftCardBg = SwiftUI.Color.white
    static let swiftInnerBg = SwiftUI.Color(red: 246/255, green: 248/255, blue: 251/255)
    static let swiftBorder = SwiftUI.Color(red: 218/255, green: 224/255, blue: 233/255)
    static let swiftInnerBorder = SwiftUI.Color(red: 222/255, green: 228/255, blue: 236/255)
}

// MARK: - 🌐 QUẢN LÝ & GIAO DIỆN MÁY CHỦ ANISETTE (ĐẶT NGAY TRÊN LỊCH SỬ LÀM MỚI ỨNG DỤNG)
private struct SettingsAnisetteBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

private struct SettingsAnisetteServerOption: Identifiable, Hashable {
    var id: String { url }
    let name: String
    let url: String
}

private enum SettingsAnisetteConstants {
    static let autoFallbackEnabledKey = "com.sidestore.anisette.autoFallbackEnabled"
    static let customAnisetteURLKey = "ALTAnisetteURL"
    static let useCustomAnisetteServerKey = "ALTUseCustomAnisetteServer"
    static let serversJSONURL = "https://servers.sidestore.io/servers.json"

    static let defaultServers: [SettingsAnisetteServerOption] = [
        SettingsAnisetteServerOption(name: "Macley (Khuyên dùng)", url: "https://ani.sidestore.io"),
        SettingsAnisetteServerOption(name: "Subway / Myau", url: "https://anisette.PNGserver.uk"),
        SettingsAnisetteServerOption(name: "SideStore Official (Cũ)", url: "https://ani.sidestore.zip"),
        SettingsAnisetteServerOption(name: "Kavii (V3)", url: "https://ani.8848888.xyz"),
        SettingsAnisetteServerOption(name: "Sideloadly / Community 1", url: "https://ani.sideload.ly"),
        SettingsAnisetteServerOption(name: "StosVPN / Community 2", url: "https://anisette.stosvpn.com"),
        SettingsAnisetteServerOption(name: "Mist / Europe (EU)", url: "https://ani.mist.com"),
        SettingsAnisetteServerOption(name: "Asia / Singapore (SG)", url: "https://anisette.sg.sidestore.io"),
        SettingsAnisetteServerOption(name: "US East (Mỹ - Đông)", url: "https://anisette.useast.sidestore.io"),
        SettingsAnisetteServerOption(name: "US West (Mỹ - Tây)", url: "https://anisette.uswest.sidestore.io"),
        SettingsAnisetteServerOption(name: "Germany (Đức - EU)", url: "https://anisette.de.sidestore.io"),
        SettingsAnisetteServerOption(name: "Japan (Nhật Bản - JP)", url: "https://anisette.jp.sidestore.io"),
        SettingsAnisetteServerOption(name: "NY / North America", url: "https://ani.ny.sidestore.io"),
        SettingsAnisetteServerOption(name: "Backup / Global Mirror", url: "https://anisette.sidestore.io")
    ]
}

@MainActor
private final class SettingsAnisetteManagerViewModel: ObservableObject {
    @Published var servers: [SettingsAnisetteServerOption] = SettingsAnisetteConstants.defaultServers
    @Published var currentAnisetteURL: String = ""
    @Published var isAnisetteAutoFallbackEnabled: Bool = true
    @Published var isAnisetteChecking: Bool = false
    @Published var anisetteStatusMessage: String = "Nhấn 'Kiểm tra máy chủ' để đo phản hồi"
    @Published var anisetteCheckResultOK: Bool? = nil

    weak var hostViewController: SettingsViewController?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            SettingsAnisetteConstants.autoFallbackEnabledKey: true
        ])

        let savedURL = (defaults.string(forKey: SettingsAnisetteConstants.customAnisetteURLKey) ?? UserDefaults.standard.textInputAnisetteURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let initialURL = savedURL.isEmpty
            ? (SettingsAnisetteConstants.defaultServers.first?.url ?? "https://ani.sidestore.io")
            : savedURL

        self.currentAnisetteURL = initialURL
        self.isAnisetteAutoFallbackEnabled = defaults.bool(forKey: SettingsAnisetteConstants.autoFallbackEnabledKey)

        applyAnisetteURLToSystem(initialURL, notifyHost: false)

        Task {
            await fetchRemoteAnisetteServersList()
            await testCurrentAnisetteServer(allowAutoSwitch: self.isAnisetteAutoFallbackEnabled)
        }
    }

    func syncFromUserDefaults() {
        let savedURL = (UserDefaults.standard.string(forKey: SettingsAnisetteConstants.customAnisetteURLKey) ?? UserDefaults.standard.textInputAnisetteURL)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !savedURL.isEmpty && savedURL != currentAnisetteURL {
            currentAnisetteURL = savedURL
        }
    }

    func selectAnisetteServer(_ urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if currentAnisetteURL != trimmed {
            currentAnisetteURL = trimmed
        }
        applyAnisetteURLToSystem(trimmed, notifyHost: true)
        anisetteCheckResultOK = nil
        anisetteStatusMessage = "Đã chọn máy chủ • Đang kiểm tra kết nối..."
        Task {
            await testCurrentAnisetteServer(allowAutoSwitch: isAnisetteAutoFallbackEnabled)
        }
    }

    func updateCustomAnisetteURL(_ urlString: String) {
        currentAnisetteURL = urlString
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            applyAnisetteURLToSystem(trimmed, notifyHost: true)
        }
    }

    func setAnisetteAutoFallbackEnabled(_ enabled: Bool) {
        guard isAnisetteAutoFallbackEnabled != enabled else { return }
        isAnisetteAutoFallbackEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: SettingsAnisetteConstants.autoFallbackEnabledKey)
        if enabled && anisetteCheckResultOK == false {
            Task {
                await testCurrentAnisetteServer(allowAutoSwitch: true)
            }
        }
    }

    private func applyAnisetteURLToSystem(_ urlString: String, notifyHost: Bool) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let defaults = UserDefaults.standard
        defaults.set(trimmed, forKey: SettingsAnisetteConstants.customAnisetteURLKey)
        defaults.set(true, forKey: SettingsAnisetteConstants.useCustomAnisetteServerKey)

        UserDefaults.standard.textInputAnisetteURL = trimmed
        let existsInMenu = UserDefaults.standard.menuAnisetteServersList.contains { $0.value == trimmed }
        UserDefaults.standard.menuAnisetteURL = existsInMenu ? trimmed : ""

        if notifyHost {
            hostViewController?.syncAnisetteSelectionFromSwiftUI()
        }
    }

    func fetchRemoteAnisetteServersList() async {
        guard let url = URL(string: SettingsAnisetteConstants.serversJSONURL) else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 6.0
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rawServers = json["servers"] as? [[String: String]] {
                var merged = SettingsAnisetteConstants.defaultServers
                for item in rawServers {
                    if let name = item["name"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                       let address = item["address"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !name.isEmpty, !address.isEmpty {
                        if !merged.contains(where: { $0.url.lowercased() == address.lowercased() }) {
                            merged.append(SettingsAnisetteServerOption(name: name, url: address))
                        }
                    }
                }
                self.servers = merged
            }
        } catch {
            // Giữ danh sách 14 máy chủ mặc định nếu không tải được danh sách online
        }
    }

    private nonisolated static func probeAnisetteServer(urlString: String) async -> (Bool, Int) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            return (false, 0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("SideStore/1.0 (iOS)", forHTTPHeaderField: "User-Agent")

        let startTime = DispatchTime.now()
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let endTime = DispatchTime.now()
            let elapsedMs = Int((endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000)

            guard let http = response as? HTTPURLResponse else {
                return (false, elapsedMs)
            }

            if (200...299).contains(http.statusCode) && !data.isEmpty {
                return (true, max(elapsedMs, 1))
            }
            return (false, elapsedMs)
        } catch {
            return (false, 0)
        }
    }

    func testCurrentAnisetteServer(allowAutoSwitch: Bool) async {
        guard !isAnisetteChecking else { return }
        let targetURL = currentAnisetteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !targetURL.isEmpty else {
            anisetteCheckResultOK = false
            anisetteStatusMessage = "URL máy chủ đang trống • Hãy chọn hoặc nhập URL"
            return
        }

        isAnisetteChecking = true
        anisetteStatusMessage = "Đang kiểm tra kết nối máy chủ Anisette..."

        let (isOK, latencyMs) = await Self.probeAnisetteServer(urlString: targetURL)
        if isOK {
            applyAnisetteURLToSystem(targetURL, notifyHost: true)
            anisetteCheckResultOK = true
            let matchedName = servers.first(where: { $0.url.lowercased() == targetURL.lowercased() })?.name
            if let matchedName = matchedName {
                anisetteStatusMessage = "Hoạt động tốt • \(matchedName) (\(latencyMs) ms)"
            } else {
                anisetteStatusMessage = "Hoạt động tốt • Phản hồi nhanh (\(latencyMs) ms)"
            }
            isAnisetteChecking = false
            return
        }

        if allowAutoSwitch && isAnisetteAutoFallbackEnabled {
            anisetteStatusMessage = "Máy chủ hiện tại lỗi • Đang tự động tìm máy chủ ổn định..."
            for candidate in servers where candidate.url.lowercased() != targetURL.lowercased() {
                let (candidateOK, candidateMs) = await Self.probeAnisetteServer(urlString: candidate.url)
                if candidateOK {
                    currentAnisetteURL = candidate.url
                    applyAnisetteURLToSystem(candidate.url, notifyHost: true)
                    anisetteCheckResultOK = true
                    anisetteStatusMessage = "Đã tự động chuyển sang \(candidate.name) (\(candidateMs) ms)"
                    isAnisetteChecking = false
                    return
                }
            }
        }

        anisetteCheckResultOK = false
        anisetteStatusMessage = "Máy chủ phản hồi lỗi hoặc quá thời gian • Hãy đổi máy chủ khác"
        isAnisetteChecking = false
    }
}

private struct SettingsAnisetteEmbeddedView: SwiftUI.View {
    @ObservedObject var vm: SettingsAnisetteManagerViewModel

    private var selectedServerDisplayName: String {
        let trimmed = vm.currentAnisetteURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if let matched = vm.servers.first(where: { $0.url.lowercased() == trimmed.lowercased() }) {
            return matched.name
        }
        return trimmed.isEmpty ? "Chưa chọn máy chủ" : "Tùy chỉnh (URL riêng)"
    }

    private var statusBadgeColor: SwiftUI.Color {
        if vm.isAnisetteChecking {
            return SettingsCSSTheme.swiftPrimary
        }
        if let ok = vm.anisetteCheckResultOK {
            return ok ? SettingsCSSTheme.swiftGreen : SettingsCSSTheme.swiftRed
        }
        return SettingsCSSTheme.swiftSecondary
    }

    private var statusBadgeIcon: String {
        if vm.isAnisetteChecking {
            return "arrow.triangle.2.circlepath.circle.fill"
        }
        if let ok = vm.anisetteCheckResultOK {
            return ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
        }
        return "server.rack"
    }

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            // 1. Trạng thái máy chủ thời gian thực
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(statusBadgeColor.opacity(0.14))
                        .frame(width: 44, height: 44)
                    if vm.isAnisetteChecking {
                        ProgressView()
                            .tint(SettingsCSSTheme.swiftPrimary)
                    } else {
                        SwiftUI.Image(systemName: statusBadgeIcon)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(statusBadgeColor)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    SwiftUI.Text("Trạng thái Máy chủ Anisette")
                        .font(.system(size: 15.5, weight: .bold))
                        .foregroundColor(SettingsCSSTheme.swiftPureBlack)
                    SwiftUI.Text(vm.anisetteStatusMessage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(statusBadgeColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)
            }
            .padding(12)
            .background(SettingsCSSTheme.swiftInnerBg)
            .cornerRadius(SettingsCSSTheme.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SettingsCSSTheme.cardCornerRadius, style: .continuous)
                    .stroke(statusBadgeColor.opacity(0.35), lineWidth: 1.0)
            )

            // 2. Menu chọn nhanh máy chủ Anisette có sẵn
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SwiftUI.Image(systemName: "list.bullet.rectangle.portrait.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(SettingsCSSTheme.swiftPrimary)
                    SwiftUI.Text("Chọn máy chủ Anisette có sẵn:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(SettingsCSSTheme.swiftPureBlack)
                    Spacer()
                }

                Menu {
                    ForEach(vm.servers) { item in
                        SwiftUI.Button {
                            vm.selectAnisetteServer(item.url)
                        } label: {
                            HStack {
                                SwiftUI.Text("\(item.name) — \(item.url)")
                                if item.url.lowercased() == vm.currentAnisetteURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                                    SwiftUI.Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            SwiftUI.Text(selectedServerDisplayName)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(SettingsCSSTheme.swiftPureBlack)
                                .lineLimit(1)
                            SwiftUI.Text(vm.currentAnisetteURL)
                                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                .foregroundColor(SettingsCSSTheme.swiftPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            SwiftUI.Text("Đổi máy chủ")
                                .font(.system(size: 12.5, weight: .bold))
                            SwiftUI.Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            LinearGradient(
                                colors: [SettingsCSSTheme.swiftPrimary, SettingsCSSTheme.swiftSecondary],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                    }
                    .padding(12)
                    .background(SettingsCSSTheme.swiftCardBg)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(SettingsCSSTheme.swiftBorder, lineWidth: 1.0)
                    )
                }
            }
            .padding(12)
            .background(SettingsCSSTheme.swiftInnerBg)
            .cornerRadius(SettingsCSSTheme.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SettingsCSSTheme.cardCornerRadius, style: .continuous)
                    .stroke(SettingsCSSTheme.swiftInnerBorder, lineWidth: 1.0)
            )

            // 3. Ô nhập URL Máy chủ Anisette tùy chỉnh + Nút Kiểm tra ngay
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    SwiftUI.Image(systemName: "link.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(SettingsCSSTheme.swiftSecondary)
                    SwiftUI.Text("Nhập URL Máy chủ Anisette tùy chỉnh:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(SettingsCSSTheme.swiftPureBlack)
                    Spacer()
                }

                HStack(spacing: 8) {
                    TextField(
                        "https://ani.sidestore.io",
                        text: Binding(
                            get: { vm.currentAnisetteURL },
                            set: { vm.updateCustomAnisetteURL($0) }
                        )
                    )
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(SettingsCSSTheme.swiftPureBlack)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.done)
                    .onSubmit {
                        Task {
                            await vm.testCurrentAnisetteServer(allowAutoSwitch: vm.isAnisetteAutoFallbackEnabled)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(SettingsCSSTheme.swiftCardBg)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(SettingsCSSTheme.swiftBorder, lineWidth: 1.0)
                    )

                    if !vm.currentAnisetteURL.isEmpty {
                        SwiftUI.Button {
                            if let pasted = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
                               !pasted.isEmpty {
                                vm.selectAnisetteServer(pasted)
                            }
                        } label: {
                            SwiftUI.Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(SettingsCSSTheme.swiftPrimary)
                                .frame(width: 40, height: 40)
                                .background(SettingsCSSTheme.swiftCardBg)
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(SettingsCSSTheme.swiftBorder, lineWidth: 1.0)
                                )
                        }
                        .buttonStyle(SettingsAnisetteBounceButtonStyle())
                    }
                }

                SwiftUI.Button {
                    Task {
                        await vm.testCurrentAnisetteServer(allowAutoSwitch: vm.isAnisetteAutoFallbackEnabled)
                    }
                } label: {
                    HStack(spacing: 8) {
                        if vm.isAnisetteChecking {
                            ProgressView()
                                .tint(.white)
                        } else {
                            SwiftUI.Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                        }
                        SwiftUI.Text(vm.isAnisetteChecking ? "Đang kiểm tra máy chủ..." : "Kiểm tra & Lưu máy chủ ngay")
                            .font(.system(size: 14.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        LinearGradient(
                            colors: [SettingsCSSTheme.swiftPrimary, SettingsCSSTheme.swiftSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(11)
                    .shadow(color: SettingsCSSTheme.swiftPrimary.opacity(0.28), radius: 5, x: 0, y: 3)
                }
                .buttonStyle(SettingsAnisetteBounceButtonStyle())
                .disabled(vm.isAnisetteChecking)
            }
            .padding(12)
            .background(SettingsCSSTheme.swiftInnerBg)
            .cornerRadius(SettingsCSSTheme.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SettingsCSSTheme.cardCornerRadius, style: .continuous)
                    .stroke(SettingsCSSTheme.swiftInnerBorder, lineWidth: 1.0)
            )

            // 4. Công tắc Tự động đổi máy chủ khi lỗi
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill((vm.isAnisetteAutoFallbackEnabled ? SettingsCSSTheme.swiftGreen : SettingsCSSTheme.swiftSecondary).opacity(0.14))
                        .frame(width: 44, height: 44)
                    SwiftUI.Image(systemName: "arrow.triangle.swap")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(vm.isAnisetteAutoFallbackEnabled ? SettingsCSSTheme.swiftGreen : SettingsCSSTheme.swiftPureBlack)
                }

                VStack(alignment: .leading, spacing: 3) {
                    SwiftUI.Text("Tự động đổi máy chủ khi lỗi")
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundColor(SettingsCSSTheme.swiftPureBlack)
                    SwiftUI.Text(vm.isAnisetteAutoFallbackEnabled
                                 ? "Đang bật • Tự chuyển sang server sống nếu lỗi"
                                 : "Đang tắt • Giữ cố định máy chủ đã chọn")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(vm.isAnisetteAutoFallbackEnabled ? SettingsCSSTheme.swiftGreen : SettingsCSSTheme.swiftPureBlack)
                        .lineLimit(1)
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { vm.isAnisetteAutoFallbackEnabled },
                        set: { vm.setAnisetteAutoFallbackEnabled($0) }
                    )
                )
                .labelsHidden()
                .tint(SettingsCSSTheme.swiftPrimary)
                .shadow(color: SettingsCSSTheme.swiftPrimary.opacity(0.28), radius: 6, x: 0, y: 3)
            }
            .padding(12)
            .background(SettingsCSSTheme.swiftInnerBg)
            .cornerRadius(SettingsCSSTheme.cardCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: SettingsCSSTheme.cardCornerRadius, style: .continuous)
                    .stroke(SettingsCSSTheme.swiftInnerBorder, lineWidth: 1.0)
            )
        }
        .padding(14)
        .background(SettingsCSSTheme.swiftCardBg)
    }
}

private final class SettingsAnisetteDashboardCell: UITableViewCell {
    private var hostingController: UIHostingController<SettingsAnisetteEmbeddedView>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
    }

    func configure(with vm: SettingsAnisetteManagerViewModel, parentViewController: UIViewController) {
        let rootView = SettingsAnisetteEmbeddedView(vm: vm)
        if let hostingController = self.hostingController {
            hostingController.rootView = rootView
        } else {
            let hc = UIHostingController(rootView: rootView)
            hc.overrideUserInterfaceStyle = .light
            hc.view.backgroundColor = .clear
            hc.view.translatesAutoresizingMaskIntoConstraints = false

            parentViewController.addChild(hc)
            contentView.addSubview(hc.view)

            NSLayoutConstraint.activate([
                hc.view.topAnchor.constraint(equalTo: contentView.topAnchor),
                hc.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                hc.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                hc.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor)
            ])
            hc.didMove(toParent: parentViewController)
            self.hostingController = hc
        }
    }
}

// MARK: - 🌈 LỚP NỀN GRADIENT TOÀN MÀN HÌNH (CHUẨN CSS BODY)
private final class SettingsGradientBackgroundView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        gradientLayer.colors = [SettingsCSSTheme.bgGradientStart, SettingsCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 🌟 HERO BANNER ĐẦU TRANG (CHUẨN CSS .HERO)
private final class SettingsHeroHeaderView: UIView {
    private let cardView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.layer.cornerRadius = SettingsCSSTheme.cardCornerRadius
        cardView.layer.masksToBounds = false
        cardView.layer.shadowColor = SettingsCSSTheme.primaryBlue.cgColor
        cardView.layer.shadowOpacity = 0.25
        cardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        cardView.layer.shadowRadius = 18

        gradientLayer.colors = [SettingsCSSTheme.heroStart, SettingsCSSTheme.heroEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        gradientLayer.cornerRadius = SettingsCSSTheme.cardCornerRadius
        cardView.layer.insertSublayer(gradientLayer, at: 0)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Cài đặt SideStore"
        titleLabel.font = .systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOpacity = 0.45
        titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        titleLabel.layer.shadowRadius = 5

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Quản lý tài khoản, chứng chỉ, máy chủ Anisette & cấu hình nâng cao"
        subtitleLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.95)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 2

        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SettingsCSSTheme.horizontalInset),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SettingsCSSTheme.horizontalInset),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 5),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            subtitleLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])

        cardView.alpha = 0
        cardView.transform = CGAffineTransform(translationX: 0, y: -12)
        UIView.animate(withDuration: 0.65, delay: 0.05, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
            self.cardView.alpha = 1
            self.cardView.transform = .identity
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradientLayer.frame = cardView.bounds
        CATransaction.commit()
    }
}

// MARK: - 📌 TIÊU ĐỀ SECTION KÈM GẠCH CHÂN MÀU XANH (CHUẨN CSS .FEATURES H2::AFTER)
private final class SettingsHeaderFooterView: UITableViewHeaderFooterView {
    static let headerIdentifier = "SettingsHeaderView"
    static let footerIdentifier = "SettingsFooterView"

    let label = UILabel()
    let accentBar = UIView()
    private var isFooterMode = false

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        contentView.backgroundColor = .clear
        backgroundView = UIView()
        backgroundView?.backgroundColor = .clear

        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.backgroundColor = SettingsCSSTheme.primaryBlue
        accentBar.layer.cornerRadius = 1.5

        contentView.addSubview(label)
        contentView.addSubview(accentBar)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SettingsCSSTheme.horizontalInset + 4),
            label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -(SettingsCSSTheme.horizontalInset + 4)),

            accentBar.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 4),
            accentBar.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 38),
            accentBar.heightAnchor.constraint(equalToConstant: 3),
            accentBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6)
        ])
    }

    func configureAsHeader(title: String) {
        isFooterMode = false
        accentBar.isHidden = false
        label.font = .systemFont(ofSize: 15, weight: .heavy)
        label.textColor = SettingsCSSTheme.primaryBlue
        label.text = title.uppercased()
    }

    func configureAsFooter(text: String) {
        isFooterMode = true
        accentBar.isHidden = true
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = SettingsCSSTheme.pureBlack
        label.text = text
    }
}

private extension SettingsViewController
{
    enum Section: Int, CaseIterable
    {
        case signIn
        case appleID
        case activeTeam
        case anisette
        case refreshAttempts
        case appData
        case backgroundRefresh
        case debug
        case troubleshooting
        case patreon
        case updates
        case betaUpdates
        case credits
    }

    enum TroubleshootingRow: Int, CaseIterable
    {
        case exportCertificate = 0
        case synchronizeAppIDs
        case resetAllPairingFiles
        case resetAllSettings
        case importBackup
        case exportBackup
    }

    enum DebugRow: Int, CaseIterable
    {
        case errorLog = 0
        case verboseLog
        case shareLog
        case jitRow
        caseudid
        case profileRow
        case connectionRow
        case cacheRow
    }

    enum UpdatesRow: Int, CaseIterable
    {
        case checkRow = 0
        case infoRow
    }

    enum BetaUpdatesRow: Int, CaseIterable
    {
        case trackPickerRow = 0
        case checkBetaRow
        case betaInfoRow
    }
}

final class SettingsViewController: UITableViewController,
    UIDocumentPickerDelegate,
    UITextFieldDelegate
{
    private var account: Account?
    private var team: Team?
    private var refreshAttempts = [RefreshAttempt]()
    private var didCheckForUpdates = false

    private var _altstoreApp:InstalledApp?
    private var altstoreApp: InstalledApp? {
        get {
            if _altstoreApp == nil {
                _altstoreApp = DatabaseManager.shared.altStoreApp()
            }
            return _altstoreApp
        }
        set {
            _altstoreApp = newValue
        }
    }

    var callbackURL: URL?

    // MARK: - ViewModel quản lý toàn diện Máy chủ Anisette (Đặt ngay trên Lịch sử làm mới ứng dụng)
    private lazy var anisetteManagerVM: SettingsAnisetteManagerViewModel = {
        let vm = SettingsAnisetteManagerViewModel()
        vm.hostViewController = self
        return vm
    }()

    // Outlets
    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var jitCell: UITableViewCell!
    @IBOutlet private var customAnisetteTextCell: UITableViewCell!
    @IBOutlet private var customAnisetteTextField: UITextField!
    @IBOutlet private var anisetteServersMenuButton: UIButton!
    @IBOutlet private var udidLabel: UILabel!
    @IBOutlet private var pairingManageButton: UIButton!
    @IBOutlet private var updateCheckButton: UIButton!

    // Dynamic update info cell properties
    private var isShowingUpdateInfo = false
    private var updateInfoText: String?
    private var isUpdateAvailable = false

    // Beta updates state
    private var isShowingBetaUpdateInfo = false
    private var betaUpdateInfoText: String?
    private var isBetaUpdateAvailable = false
    private var latestBetaDownloadURL: URL?
    private var latestBetaVersion: String?
    private var didAutoCheckBetaUpdates = false

    // Track backup operation mode
    private enum BackupOperationMode {
        case none
        case exportBackup
        case importBackup
    }
    private var currentBackupMode: BackupOperationMode = .none

    // Floating Back Button (Khi ẩn thanh điều hướng)
    private var floatingBackButton: UIButton?

    @IBAction func resetAnisetteTextField(_ sender: Any) {
        self.customAnisetteTextField.text = ""
        self.textFieldDidEndEditing(self.customAnisetteTextField)
    }

    internal func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    private func setupAnisetteListPopupButton() {
        var menuList: [UIAction] = []

        let currentServerURL = UserDefaults.standard.menuAnisetteURL

        for item: MenuItem in UserDefaults.standard.menuAnisetteServersList {
            let state: UIMenuElement.State = (item.value == currentServerURL) ? .on : .off
            let action = UIAction(title: item.key, state: state) { [weak self] action in
                UserDefaults.standard.menuAnisetteURL = item.value
                if !item.value.isEmpty {
                    UserDefaults.standard.textInputAnisetteURL = item.value
                    self?.anisetteManagerVM.selectAnisetteServer(item.value)
                }
                self?.tableView.reloadSections(IndexSet(integer: Section.anisette.rawValue), with: .none)
            }
            menuList.append(action)
        }

        if menuList.isEmpty {
            let fallbackAction = UIAction(title: NSLocalizedString("Default", comment: ""), state: .on) { _ in }
            menuList.append(fallbackAction)
        }

        self.anisetteServersMenuButton?.menu = UIMenu(children: menuList)
        self.anisetteServersMenuButton?.showsMenuAsPrimaryAction = true
        self.anisetteServersMenuButton?.changesSelectionAsPrimaryAction = true

        styleAnisettePopupButton()
    }

    func syncAnisetteSelectionFromSwiftUI() {
        self.customAnisetteTextField?.text = UserDefaults.standard.textInputAnisetteURL
        self.setupAnisetteListPopupButton()
    }

    internal func textFieldDidEndEditing(_ textField: UITextField){
        guard let text = textField.text else { return }
        if !text.isEmpty && URL(string: text) == nil {
            let toastView = ToastView(text: "Invalid URL the previous value will be restored", detailText: nil)
            toastView.Layer.backgroundColor = UIColor.systemRed.cgColor
            toastView.show(in: self)

            textField.text = UserDefaults.standard.textInputAnisetteURL
            return
        }

        textField.isEnabled = false
        defer { textField.isEnabled = true }

        UserDefaults.standard.textInputAnisetteURL = text
        if !text.isEmpty {
            self.anisetteManagerVM.selectAnisetteServer(text)
        }
        setupAnisetteListPopupButton()
        self.tableView.reloadSections(IndexSet(integer: Section.anisette.rawValue), with: .none)
    }

    private func reloadUDIDLabel(){
        fetchUDID(). { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                switch result {
                case .success(let udid):
                    self.udidLabel.text = udid
                    self.udidLabel.textColor = SettingsCSSTheme.pureBlack
                case .failure(_):
                    self.udidLabel.text = "Error fetching UDID"
                    self.udidLabel.textColor = SettingsCSSTheme.primaryRed
                }
                self.tableView.reloadSections(IndexSet(integer: Section.debug.rawValue), with: .none)
            }
        }
    }

    // MARK: - View Lifecycle

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Khoá chế độ Sáng (Light Mode) để chữ đen tuyền hiển thị rõ nét nhất trên nền thẻ trắng
        overrideUserInterfaceStyle = .light

        self.tableView.register(RSTButtonTableViewCell.self, forCellReuseIdentifier: "ButtonCell")
        self.tableView.register(SettingsHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: SettingsHeaderFooterView.headerIdentifier)
        self.tableView.register(SettingsHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: SettingsHeaderFooterView.footerIdentifier)

        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.didUpdatePatrons(_:)), name: PatreonAPI.didUpdatePatronsNotification, object: nil)

        self.customAnisetteTextField?.text = UserDefaults.standard.textInputAnisetteURL
        self.customAnisetteTextField?.placeholder = Server.defaultAnisetteURL
        self.customAnisetteTextField?.delegate = self

        setupAnisetteListPopupButton()
        applyModernCSSTheme()

        updateData()
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        // Luôn ẩn thanh điều hướng để không hiện tiêu đề Settings hay nút Done
        self.navigationController?.setNavigationBarHidden(true, animated: animated)

        self.anisetteManagerVM.syncFromUserDefaults()
        self.update()
        self.reloadUDIDLabel()

        // Automatically check for beta updates if a track is selected
        if !self.didAutoCheckBetaUpdates && UserDefaults.standard.betaUpdateTrack != .none
        {
            self.didAutoCheckBetaUpdates = true
            self.performBetaUpdateCheck(automatic: true)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
}

// MARK: - 🎨 ÁP DỤNG GIAO DIỆN CSS ĐỒNG BỘ 100% VỚI TAB KIỂM TRA (CHỮ ĐEN TUYỀN)
private extension SettingsViewController {
    func applyModernCSSTheme() {
        // 1. Ẩn thanh điều hướng và nút Done
        self.title = nil
        self.navigationItem.title = nil
        self.navigationItem.rightBarButtonItem = nil
        self.navigationItem.leftBarButtonItem = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true

        // 2. Nền Gradient toàn màn hình (#f3e0ff -> #e0f7ff)
        let bgView = SettingsGradientBackgroundView(frame: self.tableView.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.backgroundView = bgView
        self.tableView.backgroundColor = .clear

        // 3. Cấu hình bảng & khoảng cách
        self.tableView.separatorStyle = .singleLine
        self.tableView.separatorColor = SettingsCSSTheme.borderColor.withAlphaComponent(0.65)
        self.tableView.separatorInset = UIEdgeInsets(top: 0, left: SettingsCSSTheme.horizontalInset + 16, bottom: 0, right: SettingsCSSTheme.horizontalInset + 16)
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 36, right: 0)

        if #available(iOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 6
        }

        // 4. Gắn Hero Banner đầu trang
        let heroHeader = SettingsHeroHeaderView(frame: CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 108))
        self.tableView.tableHeaderView = heroHeader

        // 5. Style Switch & TextField & Button theo CSS
        self.backgroundRefreshSwitch?.onTintColor = SettingsCSSTheme.primaryBlue
        self.backgroundRefreshSwitch?.layer.shadowColor = SettingsCSSTheme.primaryBlue.cgColor
        self.backgroundRefreshSwitch?.layer.shadowOpacity = 0.35
        self.backgroundRefreshSwitch?.layer.shadowOffset = CGSize(width: 0, height: 2)
        self.backgroundRefreshSwitch?.layer.shadowRadius = 6

        if let tf = self.customAnisetteTextField {
            tf.backgroundColor = UIColor(red: 246/255, green: 248/255, blue: 251/255, alpha: 1.0)
            tf.textColor = SettingsCSSTheme.pureBlack
            tf.tintColor = SettingsCSSTheme.primaryBlue
            tf.font = .systemFont(ofSize: 14, weight: .semibold)
            tf.layer.cornerRadius = 10
            tf.layer.borderWidth = 1.0
            tf.layer.borderColor = SettingsCSSTheme.borderColor.cgColor
            tf.clipsToBounds = true
            let leftPad = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
            tf.leftView = leftPad
            tf.leftViewMode = .always
        }

        stylePillActionButton(self.pairingManageButton, bgColor: SettingsCSSTheme.primaryPurple)
        stylePillActionButton(self.updateCheckButton, bgColor: SettingsCSSTheme.primaryBlue)
        styleAnisettePopupButton()
    }

    func stylePillActionButton(_ button: UIButton?, bgColor: UIColor) {
        guard let button = button else { return }
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = bgColor
            config.baseForegroundColor = .white
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 14, bottom: 6, trailing: 14)
            let currentTitle = button.title(for: .normal) ?? button.configuration?.title ?? ""
            var attr = AttributedString(currentTitle)
            attr.font = .systemFont(ofSize: 13.5, weight: .bold)
            config.attributedTitle = attr
            button.configuration = config
        } else {
            button.backgroundColor = bgColor
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .bold)
            button.layer.cornerRadius = 14
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)
        }
        button.layer.shadowColor = bgColor.cgColor
        button.layer.shadowOpacity = 0.35
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 6
    }

    func styleAnisettePopupButton() {
        guard let btn = self.anisetteServersMenuButton else { return }
        btn.tintColor = SettingsCSSTheme.primaryBlue
        btn.setTitleColor(SettingsCSSTheme.primaryBlue, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .bold)
        btn.backgroundColor = SettingsCSSTheme.primaryBlue.withAlphaComponent(0.10)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = SettingsCSSTheme.primaryBlue.withAlphaComponent(0.28).cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
    }

    func styleInnerCardOfCell(_ cell: UITableViewCell) {
        cell.backgroundColor = SettingsCSSTheme.white
        cell.contentView.backgroundColor = .clear
        cell.tintColor = SettingsCSSTheme.primaryBlue

        let selectedBg = UIView()
        selectedBg.backgroundColor = SettingsCSSTheme.softHoverBg
        selectedBg.layer.cornerRadius = 12
        cell.selectedBackgroundView = selectedBg

        if let textLabel = cell.textLabel {
            if textLabel.textColor != SettingsCSSTheme.primaryRed &&
               textLabel.textColor != .systemRed &&
               textLabel.textColor != SettingsCSSTheme.primaryGreen &&
               textLabel.textColor != .systemGreen &&
               textLabel.textColor != SettingsCSSTheme.primaryBlue {
                textLabel.textColor = SettingsCSSTheme.pureBlack
            }
            if textLabel.font.pointSize < 15 {
                textLabel.font = .systemFont(ofSize: 15.5, weight: .semibold)
            } else {
                textLabel.font = .systemFont(ofSize: textLabel.font.pointSize, weight: .semibold)
            }
        }

        if let detailLabel = cell.detailTextLabel {
            if detailLabel.textColor != SettingsCSSTheme.primaryRed &&
               detailLabel.textColor != .systemRed &&
               detailLabel.textColor != SettingsCSSTheme.primaryGreen &&
               detailLabel.textColor != .systemGreen {
                detailLabel.textColor = SettingsCSSTheme.pureBlack
            }
            detailLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        }

        applyThemeToSubviews(in: cell.contentView)
    }

    func applyThemeToSubviews(in rootView: UIView) {
        for subview in rootView.subviews {
            if let sw = subview as? UISwitch {
                sw.onTintColor = SettingsCSSTheme.primaryBlue
            } else if let label = subview as? UILabel {
                if label !== self.udidLabel &&
                   label.textColor != SettingsCSSTheme.primaryRed &&
                   label.textColor != .systemRed &&
                   label.textColor != SettingsCSSTheme.primaryGreen &&
                   label.textColor != .systemGreen &&
                   label.textColor != SettingsCSSTheme.primaryBlue &&
                   label.textColor != .white {
                    label.textColor = SettingsCSSTheme.pureBlack
                }
            }
            applyThemeToSubviews(in: subview)
        }
    }
}

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ KHI VÀO TRANG CON
extension SettingsViewController: UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.setNavigationBarHidden(true, animated: false)
        viewController.title = nil
        viewController.navigationItem.title = nil
        viewController.navigationItem.rightBarButtonItem = nil

        let isRoot = (viewController === navigationController.viewControllers.first)
        updateFloatingBackButton(in: navigationController, show: !isRoot)
    }

    private func updateFloatingBackButton(in nav: UINavigationController, show: Bool) {
        if self.floatingBackButton == nil {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false

            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
            btn.tintColor = SettingsCSSTheme.primaryBlue
            btn.backgroundColor = SettingsCSSTheme.white.withAlphaComponent(0.92)

            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = SettingsCSSTheme.borderColor.cgColor
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowRadius = 6
            btn.layer.shadowOpacity = 0.15

            btn.addTarget(self, action: #selector(handleFloatingBackTap), for: .touchUpInside)
            nav.view.addSubview(btn)

            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
                btn.topAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.topAnchor, constant: 6),
                btn.widthAnchor.constraint(equalToConstant: 34),
                btn.heightAnchor.constraint(equalToConstant: 34)
            ])

            self.floatingBackButton = btn
        }

        guard let btn = self.floatingBackButton else { return }
        nav.view.bringSubviewToFront(btn)

        UIView.animate(withDuration: 0.2) {
            btn.alpha = show ? 1.0 : 0.0
            btn.isHidden = !show
        }
    }

    @objc private func handleFloatingBackTap() {
        self.navigationController?.popViewController(animated: true)
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === self.navigationController?.interactivePopGestureRecognizer {
            return (self.navigationController?.viewControllers.count ?? 0) > 1
        }
        return true
    }
}

private extension SettingsViewController
{
    func update()
    {
        self.account = DatabaseManager.shared.activeAccount()
        self.team = DatabaseManager.shared.activeTeam()

        let fetchRequest = RefreshAttempt.fetchRequest() as NSFetchRequest<RefreshAttempt>
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RefreshAttempt.date, ascending: false)]
        fetchRequest.fetchLimit = 3
        self.refreshAttempts = (try? DatabaseManager.shared.viewContext.fetch(fetchRequest)) ?? []

        self.backgroundRefreshSwitch.isOn = UserDefaults.standard.isBackgroundRefreshEnabled

        self.tableView.reloadData()
    }

    @objc func didUpdatePatrons(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.tableView.reloadSections([Section.credits.rawValue], with: .automatic)
        }
    }

    @IBAction func toggleBackgroundRefresh(_ sender: UISwitch)
    {
        UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn

        self.tableView.reloadSections([Section.backgroundRefresh.rawValue], with: .none)
    }

    @IBAction func signInWithAppleID(_ sender: Any)
    {
        if self.account != nil
        {
            let title = String(format: NSLocalizedString("Are you sure you want to sign out of %@?", comment: ""), self.account?.appleID ?? "your account")
            let message = NSLocalizedString("You won't be able to install or refresh any apps until you sign in again.", comment: "")

            let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "Sign Out", style: .destructive) { (action) in
                self.signOut()
            })
            alertController.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: UIAlertAction.cancel.style, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
        else
        {
            self.signIn()
        }
    }

    func signIn()
    {
        let navigationController = UIStoryboard(name: "SignIn", bundle: nil).instantiateInitialViewController()!
        self.present(navigationController, animated: true, completion: nil)
    }

    func signOut()
    {
        DatabaseManager.shared.signOut { (error) in
            DispatchQueue.main.async {
                if let error = error
                {
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                }

                self.update()
            }
        }
    }

    @IBAction func showDebugInstructions(_ sender: UIButton)
    {
        guard let url = URL(string: "https://faq.altstore.io/how-to-use-altstore/wired-jit") else { return }

        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredControlTintColor = SettingsCSSTheme.primaryBlue
        self.present(safariViewController, animated: true, completion: nil)
    }

    @IBAction func viewRefreshAttempts(_ sender: Any)
    {
        self.performSegue(withIdentifier: "showRefreshAttempts", sender: sender)
    }

    @IBAction func resetPairingFile(_ sender: Any) {
        let controller = UIHostingController(rootView: PairingFileManagementView())
        controller.overrideUserInterfaceStyle = .light
        self.navigationController?.pushViewController(controller, animated: true)
    }

    @IBAction func checkForUpdates(_ sender: UIButton)
    {
        var buttonConfig = sender.configuration
        buttonConfig?.showsActivityIndicator = true
        buttonConfig?.title = nil
        sender.configuration = buttonConfig
        sender.isEnabled = false

        AppManager.shared.checkForUpdates { [weak self] isAvailable, statusMsg in
            DispatchQueue.main.async {
                guard let self = self else { return }

                buttonConfig?.showsActivityIndicator = false
                buttonConfig?.title = "Check Now"
                sender.configuration = buttonConfig
                sender.isEnabled = true
                self.stylePillActionButton(sender, bgColor: SettingsCSSTheme.primaryBlue)

                self.isUpdateAvailable = isAvailable
                self.updateInfoText = statusMsg

                self.showUpdateInfoCell()
            }
        }
    }

    private func showUpdateInfoCell()
    {
        let infoIndexPath = IndexPath(row: UpdatesRow.infoRow.rawValue, section: Section.updates.rawValue)

        self.tableView.beginUpdates()
        if !self.isShowingUpdateInfo {
            self.isShowingUpdateInfo = true
            self.tableView.insertRows(at: [infoIndexPath], with: .fade)
        } else {
            self.tableView.reloadRows(at: [infoIndexPath], with: .fade)
        }
        self.tableView.endUpdates()

        if !self.isUpdateAvailable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, self.isShowingUpdateInfo else { return }
                self.isShowingUpdateInfo = false
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [infoIndexPath], with: .fade)
                self.tableView.endUpdates()
            }
        }
    }

    // MARK: - Beta Updates Methods

    private func setupBetaTrackPopupButton(_ button: UIButton)
    {
        let currentTrack = UserDefaults.standard.betaUpdateTrack

        let actions: [UIAction] = BetaUpdateTrack.allCases.map { track in
            let state: UIMenuElement.State = (track == currentTrack) ? .on : .off
            return UIAction(title: track.displayName, state: state) { [weak self] _ in
                guard let self = self else { return }
                UserDefaults.standard.betaUpdateTrack = track

                self.isShowingBetaUpdateInfo = false
                self.betaUpdateInfoText = nil
                self.isBetaUpdateAvailable = false
                self.latestBetaDownloadURL = nil
                self.latestBetaVersion = nil

                self.tableView.reloadSections(IndexSet(integer: Section.betaUpdates.rawValue), with: .automatic)

                if track != .none {
                    self.performBetaUpdateCheck(automatic: true)
                }
            }
        }

        button.menu = UIMenu(children: actions)
        button.showsMenuAsPrimaryAction = true
        button.changesSelectionAsPrimaryAction = true

        styleBetaTrackPopupButton(button)
    }

    private func styleBetaTrackPopupButton(_ button: UIButton) {
        button.tintColor = SettingsCSSTheme.primaryPurple
        button.setTitleColor(SettingsCSSTheme.primaryPurple, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .bold)
        button.backgroundColor = SettingsCSSTheme.primaryPurple.withAlphaComponent(0.10)
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1.0
        button.layer.borderColor = SettingsCSSTheme.primaryPurple.withAlphaComponent(0.28).cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
    }

    private func performBetaUpdateCheck(automatic: Bool = false)
    {
        let track = UserDefaults.standard.betaUpdateTrack
        guard track != .none else { return }

        AppManager.shared.checkForBetaUpdates(track: track) { [weak self] isAvailable, statusMsg, downloadURL, latestVersion in
            DispatchQueue.main.async {
                guard let self = self else { return }

                self.isBetaUpdateAvailable = isAvailable
                self.betaUpdateInfoText = statusMsg
                self.latestBetaDownloadURL = downloadURL
                self.latestBetaVersion = latestVersion

                if automatic && !isAvailable {
                    return
                }

                self.showBetaUpdateInfoCell()
            }
        }
    }

    private func showBetaUpdateInfoCell()
    {
        let infoIndexPath = IndexPath(row: BetaUpdatesRow.betaInfoRow.rawValue, section: Section.betaUpdates.rawValue)

        self.tableView.beginUpdates()
        if !self.isShowingBetaUpdateInfo {
            self.isShowingBetaUpdateInfo = true
            self.tableView.insertRows(at: [infoIndexPath], with: .fade)
        } else {
            self.tableView.reloadRows(at: [infoIndexPath], with: .fade)
        }
        self.tableView.endUpdates()

        if !self.isBetaUpdateAvailable {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self, self.isShowingBetaUpdateInfo else { return }
                self.isShowingBetaUpdateInfo = false
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [infoIndexPath], with: .fade)
                self.tableView.endUpdates()
            }
        }
    }

    private func installBetaUpdate()
    {
        guard let downloadURL = self.latestBetaDownloadURL else { return }

        let versionString = self.latestBetaVersion ?? "latest"
        let trackName = UserDefaults.standard.betaUpdateTrack.displayName

        let alertController = UIAlertController(
            title: String(format: NSLocalizedString("Install %@ Update?", comment: ""), trackName),
            message: String(format: NSLocalizedString("SideStore will download and install version %@ from the %@ track.", comment: ""), versionString, trackName),
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Install", comment: ""), style: .default) { [weak self] _ in
            guard let self = self else { return }

            let toastView = ToastView(
                text: String(format: NSLocalizedString("Installing %@ update…", comment: ""), trackName),
                detailText: nil
            )
            toastView.show(in: self)

            _ = AppManager.shared.installModels(
                at: [downloadURL],
                presentingViewController: self,
                shouldKeepData: true,
                usedforUpdating: true
            ) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .failure(let error):
                        let errorToast = ToastView(error: error)
                        errorToast.show(in: self)
                    case .success:
                        let successToast = ToastView(
                            text: NSLocalizedString("Beta update installed successfully!", comment: ""),
                            detailText: nil
                        )
                        successToast.show(in: self)
                    }
                }
            }
        })

        self.present(alertController, animated: true, completion: nil)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        let currentMode = self.currentBackupMode
        self.currentBackupMode = .none

        switch currentMode {
        case .exportBackup:
            self.exportAllBackups(to: url)
        case .importBackup:
            self.importAllBackups(from: url)
        case .none:
            break
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        self.currentBackupMode = .none
    }

    func exportCertificate()
    {
        guard let team = DatabaseManager.shared.activeTeam(), let certificate = team.activeCertificate else { return }

        let alertController = UIAlertController(title: NSLocalizedString("Enter Password", comment: ""), message: NSLocalizedString("Enter the password to use to encrypt the exported certificate.", comment: ""), preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = NSLocalizedString("Password", comment: "")
        }

        let exportAction = UIAlertAction(title: NSLocalizedString("Export", comment: ""), style: .default) { (action) in
            let password = alertController.textFields?.first?.text ?? ""
            do
            {
                guard let encryptedData = certificate.encryptedData(withPassword: password) else { throw OperationError.unknown() }

                let temporaryURL = FileManager.default.uniqueTemporaryURL().appendingPathComponent("\(certificate.serialNumber).p12")
                try encryptedData.write(to: temporaryURL)

                let activityViewController = UIActivityViewController(activityItems: [temporaryURL], applicationActivities: nil)
                activityViewController.completionWithItemsHandler = { (activityType, completed, items, error) in
                    try? FileManager.default.removeItem(at: temporaryURL)
                }
                self.present(activityViewController, animated: true, completion: nil)
            }
            catch
            {
                let toastView = ToastView(error: error)
                toastView.show(in: self)
            }
        }
        alertController.addAction(exportAction)
        alertController.addAction(.cancel)
        alertController.preferredAction = exportAction

        self.present(alertController, animated: true, completion: nil)
    }

    func synchronizeAppIDs()
    {
        AppManager.shared.synchronizeAllAppIDs(presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)

                case .success:
                    let toastView = ToastView(text: NSLocalizedString("Synchronized App IDs", comment: ""), detailText: "")
                    toastView.show(in: self)
                }
            }
        }
    }

    func resetAllSettings()
    {
        let title = NSLocalizedString("Reset All Settings?", comment: "")
        let message = NSLocalizedString("This will reset all user settings to their default values.\n\nSince pairing file will also be reset, don't proceed unless you have a copy of your pairing file to re-import.", comment: "")

        let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: NSLocalizedString("Reset", comment: ""), style: .destructive) { _ in
            guard let bundleID = Bundle.main.bundleIdentifier else { return }
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()

            UserDefaults.registerDefaults()

            if let groupID = Bundle.main.altstoreAppGroup {
                UserDefaults(suiteName: groupID)?.removePersistentDomain(forName: groupID)
            }

            let cacheResult = self.clearCache()

            PairingFileManager.shared.resetAllPairingFiles()

            DatabaseManager.shared.signOut { error in
                DispatchQueue.main.async {
                    if let error = error {
                        ToastView(error: error).show(in: self)
                    } else if case .failure(let cacheError) = cacheResult {
                        ToastView(error: cacheError).show(in: self)
                    } else {
                        ToastView(text: NSLocalizedString("All settings have been reset", comment: ""), detailText: nil).show(in: self)
                    }

                    self.viewDidLoad()
                    self.viewWillAppear(false)
                }
            }
        })
        alert.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: .cancel))

        self.present(alert, animated: true)
    }

    private func clearCache() -> Result<Int64, Error> {
        do {
            var totalBytesCleared: Int64 = 0
            let fileManager = FileManager.default

            if let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                totalBytesCleared += try fileManager.clearDirectory(at: cacheURL)
            }

            let tempURL = fileManager.temporaryDirectory
            totalBytesCleared += try fileManager.clearDirectory(at: tempURL)

            return .success(totalBytesCleared)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Backup Import/Export Methods

    func promptImportBackup()
    {
        let alertController = UIAlertController(
            title: NSLocalizedString("Import Backup", comment: ""),
            message: NSLocalizedString("Select a directory containing app backups to import into SideStore's Backups folder.", comment: ""),
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: NSLocalizedString("Select Directory", comment: ""), style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.currentBackupMode = .importBackup
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            self.present(documentPicker, animated: true, completion: nil)
        })

        alertController.addAction(.cancel)
        self.present(alertController, animated: true, completion: nil)
    }

    func promptExportBackup()
    {
        guard let backupsDirectory = FileManager.default.backupsDirectory else {
            let toastView = ToastView(text: NSLocalizedString("Backups directory not available", comment: ""), detailText: nil)
            toastView.layer.backgroundColor = UIColor.systemRed.cgColor
            toastView.show(in: self)
            return
        }

        do {
            if !FileManager.default.fileExists(atPath: backupsDirectory.path) {
                let toastView = ToastView(text: NSLocalizedString("No backups to export", comment: ""), detailText: nil)
                toastView.show(in: self)
                return
            }

            let contents = try FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
            if contents.isEmpty {
                let toastView = ToastView(text: NSLocalizedString("No backups to export", comment: ""), detailText: nil)
                toastView.show(in: self)
                return
            }
        } catch {
            let toastView = ToastView(error: error)
            toastView.show(in: self)
            return
        }

        let alertController = UIAlertController(
            title: NSLocalizedString("Export Backups", comment: ""),
            message: NSLocalizedString("Select a destination directory to export all app backups.", comment: ""),
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: NSLocalizedString("Select Directory", comment: ""), style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.currentBackupMode = .exportBackup
            let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
            documentPicker.delegate = self
            documentPicker.allowsMultipleSelection = false
            self.present(documentPicker, animated: true, completion: nil)
        })

        alertController.addAction(.cancel)
        self.present(alertController, animated: true, completion: nil)
    }

    private func exportAllBackups(to destinationURL: URL)
    {
        guard let backupsDirectory = FileManager.default.backupsDirectory else {
            let toastView = ToastView(text: NSLocalizedString("Backups directory not available", comment: ""), detailText: nil)
            toastView.layer.backgroundColor = UIColor.systemRed.cgColor
            toastView.show(in: self)
            return
        }

        guard destinationURL.startAccessingSecurityScopedResource() else {
            let toastView = ToastView(text: NSLocalizedString("Failed to access selected directory", comment: ""), detailText: nil)
            toastView.layer.backgroundColor = UIColor.systemRed.cgColor
            toastView.show(in: self)
            return
        }
        defer {
            destinationURL.stopAccessingSecurityScopedResource()
        }

        do {
            let backupItems = try FileManager.default.contentsOfDirectory(at: backupsDirectory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

            var exportedCount = 0
            for itemURL in backupItems {
                let destinationItemURL = destinationURL.appendingPathComponent(itemURL.lastPathComponent)

                if FileManager.default.fileExists(atPath: destinationItemURL.path) {
                    try FileManager.default.removeItem(at: destinationItemURL)
                }

                try FileManager.default.copyItem(at: itemURL, to: destinationItemURL)
                exportedCount += 1
            }

            let message = String(format: NSLocalizedString("Exported %d backup item(s) successfully", comment: ""), exportedCount)
            let toastView = ToastView(text: message, detailText: nil)
            toastView.show(in: self)
        } catch {
            let toastView = ToastView(error: error)
            toastView.show(in: self)
        }
    }

    private func importAllBackups(from sourceURL: URL)
    {
        guard let backupsDirectory = FileManager.default.backupsDirectory else {
            let toastView = ToastView(text: NSLocalizedString("Backups directory not available", comment: ""), detailText: nil)
            toastView.layer.backgroundColor = UIColor.systemRed.cgColor
            toastView.show(in: self)
            return
        }

        guard sourceURL.startAccessingSecurityScopedResource() else {
            let toastView = ToastView(text: NSLocalizedString("Failed to access selected directory", comment: ""), detailText: nil)
            toastView.layer.backgroundColor = UIColor.systemRed.cgColor
            toastView.show(in: self)
            return
        }
        defer {
            sourceURL.stopAccessingSecurityScopedResource()
        }

        do {
            try FileManager.default.createDirectory(at: backupsDirectory, withIntermediateDirectories: true, attributes: nil)

            let sourceItems = try FileManager.default.contentsOfDirectory(at: sourceURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

            if sourceItems.isEmpty {
                let toastView = ToastView(text: NSLocalizedString("Selected directory is empty", comment: ""), detailText: nil)
                toastView.show(in: self)
                return
            }

            var importedCount = 0
            for itemURL in sourceItems {
                let destinationItemURL = backupsDirectory.appendingPathComponent(itemURL.lastPathComponent)

                if FileManager.default.fileExists(atPath: destinationItemURL.path) {
                    try FileManager.default.removeItem(at: destinationItemURL)
                }

                try FileManager.default.copyItem(at: itemURL, to: destinationItemURL)
                importedCount += 1
            }

            let message = String(format: NSLocalizedString("Imported %d backup item(s) successfully", comment: ""), importedCount)
            let toastView = ToastView(text: message, detailText: nil)
            toastView.show(in: self)
        } catch {
            let toastView = ToastView(error: error)
            toastView.show(in: self)
        }
    }
}

extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn:
            guard self.account == nil else { return 0 }
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)

        case .appleID:
            guard self.account != nil else { return 0 }
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)

        case .activeTeam:
            guard self.team != nil else { return 0 }
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)

        case .anisette:
            // Hiển thị toàn bộ giao diện Máy chủ Anisette mới (14 server + nhập URL + test tốc độ + tự động đổi) ngay trên Lịch sử làm mới ứng dụng
            return 1

        case .refreshAttempts:
            guard !self.refreshAttempts.isEmpty && UserDefaults.standard.isBackgroundRefreshEnabled else { return 0 }
            return self.refreshAttempts.count + 1

        case .appData:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)

        case .troubleshooting:
            return TroubleshootingRow.allCases.count

        case .patreon:
            return 0

        case .updates:
            return self.isShowingUpdateInfo ? 2 : 1

        case .betaUpdates:
            let track = UserDefaults.standard.betaUpdateTrack
            if track == .none {
                return 1
            } else {
                return self.isShowingBetaUpdateInfo ? 3 : 2
            }

        case .backgroundRefresh, .debug, .credits:
            return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.account != nil: return nil
        case .appleID where self.account == nil: return nil
        case .activeTeam where self.team == nil: return nil
        case .anisette: return "MÁY CHỦ ANISETTE"
        case .refreshAttempts where self.refreshAttempts.isEmpty || !UserDefaults.standard.isBackgroundRefreshEnabled: return nil
        case .patreon: return nil
        case .updates: return NSLocalizedString("UPDATES", comment: "")
        case .betaUpdates: return NSLocalizedString("BETA UPDATES", comment: "")
        default: return super.tableView(tableView, titleForHeaderInSection: section.rawValue)
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String?
    {
        let section = Section.allCases[section]
        switch section
        {
        case .signIn where self.account != nil: return nil
        case .appleID where self.account == nil: return nil
        case .activeTeam where self.team == nil: return nil
        case .anisette:
            return "Mẹo: Bạn có thể chọn nhanh máy chủ từ danh sách, nhập URL riêng hoặc bật tự động chuyển đổi sang máy chủ ổn định khi gặp lỗi."
        case .refreshAttempts where self.refreshAttempts.isEmpty || !UserDefaults.standard.isBackgroundRefreshEnabled: return nil
        case .patreon: return nil
        case .updates: return nil
        case .betaUpdates:
            return NSLocalizedString("Select a beta track to check for pre-release versions of SideStore (Beta or Nightly builds).", comment: "")
        default: return super.tableView(tableView, titleForFooterInSection: section.rawValue)
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let title = self.tableView(tableView, titleForHeaderInSection: section),
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: SettingsHeaderFooterView.headerIdentifier) as? SettingsHeaderFooterView else {
            return nil
        }
        header.configureAsHeader(title: title)
        return header
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        guard let footerText = self.tableView(tableView, titleForFooterInSection: section),
              !footerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard let footer = tableView.dequeueReusableHeaderFooterView(withIdentifier: SettingsHeaderFooterView.footerIdentifier) as? SettingsHeaderFooterView else {
            return nil
        }
        footer.configureAsFooter(text: footerText)
        return footer
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let sectionType = Section.allCases[section]
        switch sectionType
        {
        case .signIn where self.account != nil: return .leastNormalMagnitude
        case .appleID where self.account == nil: return .leastNormalMagnitude
        case .activeTeam where self.team == nil: return .leastNormalMagnitude
        case .refreshAttempts where self.refreshAttempts.isEmpty || !UserDefaults.standard.isBackgroundRefreshEnabled: return .leastNormalMagnitude
        case .patreon: return .leastNormalMagnitude
        default:
            if self.tableView(tableView, titleForHeaderInSection: section) != nil {
                return UITableView.automaticDimension
            }
            return super.tableView(tableView, heightForHeaderInSection: sectionType.rawValue)
        }
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return 38
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let sectionType = Section.allCases[section]
        switch sectionType
        {
        case .signIn where self.account != nil: return .leastNormalMagnitude
        case .appleID where self.account == nil: return .leastNormalMagnitude
        case .activeTeam where self.team == nil: return .leastNormalMagnitude
        case .refreshAttempts where self.refreshAttempts.isEmpty || !UserDefaults.standard.isBackgroundRefreshEnabled: return .leastNormalMagnitude
        case .patreon: return .leastNormalMagnitude
        case .updates: return .leastNormalMagnitude
        default:
            if self.tableView(tableView, titleForFooterInSection: section) != nil {
                return UITableView.automaticDimension
            }
            return super.tableView(tableView, heightForFooterInSection: sectionType.rawValue)
        }
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        return 32
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .anisette, .refreshAttempts:
            return UITableView.automaticDimension

        case .updates:
            if indexPath.row == UpdatesRow.infoRow.rawValue {
                return UITableView.automaticDimension
            }
            return super.tableView(tableView, heightForRowAt: IndexPath(row: 0, section: section.rawValue))

        case .betaUpdates:
            return UITableView.automaticDimension

        case .troubleshooting:
            return 48

        case .patreon:
            return 0

        default:
            return super.tableView(tableView, heightForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .anisette, .refreshAttempts, .updates, .betaUpdates, .troubleshooting: return 0
        default: return super.tableView(tableView, indentationLevelForRowAt: indexPath)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell: UITableViewCell

        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .anisette:
            let anisetteCell = SettingsAnisetteDashboardCell(style: .default, reuseIdentifier: nil)
            anisetteCell.configure(with: self.anisetteManagerVM, parentViewController: self)
            return anisetteCell

        case .updates:
            let updatesRow = UpdatesRow(rawValue: indexPath.row)!
            switch updatesRow
            {
            case .checkRow:
                cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: section.rawValue))

            case .infoRow:
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.selectionStyle = self.isUpdateAvailable ? .default : .none
                cell.accessoryType = self.isUpdateAvailable ? .disclosureIndicator : .none

                cell.textLabel?.text = self.updateInfoText
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
                cell.textLabel?.textColor = self.isUpdateAvailable ? SettingsCSSTheme.primaryBlue : SettingsCSSTheme.pureBlack

                if self.isUpdateAvailable {
                    cell.detailTextLabel?.text = NSLocalizedString("Tap to go to My Apps and update", comment: "")
                    cell.detailTextLabel?.textColor = SettingsCSSTheme.primaryBlue
                    cell.detailTextLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
                } else {
                    cell.detailTextLabel?.text = nil
                }
            }

        case .betaUpdates:
            let betaRow = BetaUpdatesRow(rawValue: indexPath.row)!
            switch betaRow
            {
            case .trackPickerRow:
                cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.text = NSLocalizedString("Update Channel", comment: "")
                cell.textLabel?.font = .systemFont(ofSize: 15.5, weight: .semibold)

                let trackButton = UIButton(type: .system)
                trackButton.frame = CGRect(x: 0, y: 0, width: 150, height: 34)
                trackButton.contentHorizontalAlignment = .right
                self.setupBetaTrackPopupButton(trackButton)
                trackButton.sizeToFit()
                trackButton.frame.size.width = max(trackButton.frame.size.width + 20, 115)
                trackButton.frame.size.height = 32
                cell.accessoryView = trackButton

            case .checkBetaRow:
                cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.selectionStyle = .none
                cell.textLabel?.text = NSLocalizedString("Check for Beta Updates", comment: "")
                cell.textLabel?.font = .systemFont(ofSize: 15.5, weight: .semibold)

                let checkButton = UIButton(type: .system)
                checkButton.setTitle(NSLocalizedString("Check Now", comment: ""), for: .normal)
                stylePillActionButton(checkButton, bgColor: SettingsCSSTheme.primaryPurple)
                checkButton.sizeToFit()
                checkButton.frame.size.width += 8
                checkButton.frame.size.height = 32
                checkButton.addAction(UIAction { [weak self] _ in
                    self?.performBetaUpdateCheck(automatic: false)
                }, for: .touchUpInside)
                cell.accessoryView = checkButton

            case .betaInfoRow:
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.selectionStyle = self.isBetaUpdateAvailable ? .default : .none
                cell.accessoryType = self.isBetaUpdateAvailable ? .disclosureIndicator : .none

                cell.textLabel?.text = self.betaUpdateInfoText
                cell.textLabel?.numberOfLines = 0
                cell.textLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
                cell.textLabel?.textColor = self.isBetaUpdateAvailable ? SettingsCSSTheme.primaryPurple : SettingsCSSTheme.pureBlack

                if self.isBetaUpdateAvailable {
                    cell.detailTextLabel?.text = NSLocalizedString("Tap to download and install this beta update", comment: "")
                    cell.detailTextLabel?.textColor = SettingsCSSTheme.primaryPurple
                    cell.detailTextLabel?.font = .systemFont(ofSize: 12.5, weight: .semibold)
                } else {
                    cell.detailTextLabel?.text = nil
                }
            }

        case .appleID:
            cell = super.tableView(tableView, cellForRowAt: indexPath)
            cell.detailTextLabel?.text = self.account?.appleID
            cell.detailTextLabel?.textColor = SettingsCSSTheme.primaryBlue
            cell.detailTextLabel?.font = .systemFont(ofSize: 14, weight: .bold)

        case .activeTeam:
            cell = super.tableView(tableView, cellForRowAt: indexPath)

            if let team = self.team
            {
                cell.detailTextLabel?.text = team.name

                switch team.type
                {
                case .free: cell.textLabel?.text = NSLocalizedString("Free Developer Account", comment: "")
                case .individual: cell.textLabel?.text = NSLocalizedString("Individual Account", comment: "")
                case .organization: cell.textLabel?.text = NSLocalizedString("Organization Team", comment: "")
                case .unknown: cell.textLabel?.text = NSLocalizedString("Unknown Team", comment: "")
                }
            }
            else
            {
                cell.textLabel?.text = NSLocalizedString("No Active Team", comment: "")
                cell.detailTextLabel?.text = nil
            }

        case .refreshAttempts:
            if indexPath.row == self.refreshAttempts.count
            {
                cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: indexPath.section))
            }
            else
            {
                cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
                cell.selectionStyle = .none

                let attempt = self.refreshAttempts[indexPath.row]
                if attempt.isSuccess
                {
                    cell.textLabel?.text = NSLocalizedString("Success", comment: "")
                    cell.textLabel?.textColor = SettingsCSSTheme.primaryGreen
                    cell.textLabel?.font = .systemFont(ofSize: 15.5, weight: .bold)
                    cell.detailTextLabel?.text = nil
                }
                else
                {
                    cell.textLabel?.text = NSLocalizedString("Failure", comment: "")
                    cell.textLabel?.textColor = SettingsCSSTheme.primaryRed
                    cell.textLabel?.font = .systemFont(ofSize: 15.5, weight: .bold)
                    cell.detailTextLabel?.text = attempt.errorDescription
                    cell.detailTextLabel?.textColor = SettingsCSSTheme.pureBlack
                    cell.detailTextLabel?.numberOfLines = 0
                }

                let dateLabel = UILabel()
                dateLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
                dateLabel.text = RefreshAttemptsViewController.dateFormatter.string(from: attempt.date)
                dateLabel.textColor = SettingsCSSTheme.pureBlack
                dateLabel.sizeToFit()
                cell.accessoryView = dateLabel
            }

        case .debug:
            let debugRow = DebugRow(rawValue: indexPath.row)!
            cell = super.tableView(tableView, cellForRowAt: indexPath)
            switch debugRow
            {
            case .udid:
                cell.selectionStyle = .default
            default:
                break
            }

        case .troubleshooting:
            let troubleshootingRow = TroubleshootingRow(rawValue: indexPath.row)!
            switch troubleshootingRow
            {
            case .exportCertificate:
                cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 0, section: section.rawValue))
            case .synchronizeAppIDs:
                cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 1, section: section.rawValue))
            case .resetAllPairingFiles:
                cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 2, section: section.rawValue))
            case .resetAllSettings:
                cell = super.tableView(tableView, cellForRowAt: IndexPath(row: 3, section: section.rawValue))
            case .importBackup:
                cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = NSLocalizedString("Import Backup", comment: "")
                cell.textLabel?.textColor = SettingsCSSTheme.primaryBlue
                cell.textLabel?.font = .systemFont(ofSize: 15.5, weight: .semibold)
                cell.accessoryType = .disclosureIndicator
            case .exportBackup:
                cell = UITableViewCell(style: .default, reuseIdentifier: nil)
                cell.textLabel?.text = NSLocalizedString("Export Backup", comment: "")
                cell.textLabel?.textColor = SettingsCSSTheme.primaryBlue
                cell.textLabel?.font = .systemFont(ofSize: 15.5, weight: .semibold)
                cell.accessoryType = .disclosureIndicator
            }

        case .signIn, .appData, .backgroundRefresh, .patreon, .credits:
            cell = super.tableView(tableView, cellForRowAt: indexPath)
        }

        styleInnerCardOfCell(cell)
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        styleInnerCardOfCell(cell)
    }

    override func tableView(_ tableView: UITableView, didHighlightRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath), cell.selectionStyle != .none else { return }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
            cell.transform = CGAffineTransform(translationX: 5, y: 0).scaledBy(x: 0.985, y: 0.985)
        }
    }

    override func tableView(_ tableView: UITableView, didUnhighlightRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else { return }
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [.curveEaseOut]) {
            cell.transform = .identity
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)

        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .updates:
            let updatesRow = UpdatesRow(rawValue: indexPath.row)!
            if updatesRow == .infoRow && self.isUpdateAvailable {
                if let tabBarController = self.tabBarController,
                   let viewControllers = tabBarController.viewControllers {
                    for (index, vc) in viewControllers.enumerated() {
                        if let navController = vc as? UINavigationController,
                           navController.viewControllers.first is MyAppsViewController {
                            tabBarController.selectedIndex = index
                            break
                        } else if vc is MyAppsViewController {
                            tabBarController.selectedIndex = index
                            break
                        }
                    }
                }
            }

        case .betaUpdates:
            guard let betaRow = BetaUpdatesRow(rawValue: indexPath.row) else { break }
            if betaRow == .betaInfoRow && self.isBetaUpdateAvailable {
                self.installBetaUpdate()
            }

        case .debug:
            let row = DebugRow.allCases[indexPath.row]
            switch row {
                case .errorLog: break
                case .verboseLog:
                    self.performSegue(withIdentifier: "viewVerboseLog", sender: nil)
                case .shareLog:
                    let logFilePath = Logger.logFileURL

                    if FileManager.default.fileExists(atPath: logFilePath.path) {
                        let activityViewController = UIActivityViewController(activityItems: [logFilePath], applicationActivities: nil)

                        if let popoverController = activityViewController.popoverPresentationController {
                            popoverController.sourceView = tableView
                            popoverController.sourceRect = tableView.rectForRow(at: indexPath)
                        }

                        self.present(activityViewController, animated: true, completion: nil)
                    } else {
                        ToastView(error: OperationError.noLogFound).show(in: self)
                    }

                case .jitRow: break

                case .udid:
                    let value = self.udidLabel.text
                    UIPasteboard.general.string = value

                    let toast = ToastView(text: "Copied UDID to clipboard", detailText: nil)
                    toast.show(in: self.navigationController?.view ?? self.view, duration: 1)

                case .profileRow:
                    break
                case .connectionRow:
                    let controller = UIHostingController(rootView: ConnectionSettingsView())
                    controller.overrideUserInterfaceStyle = .light
                    self.navigationController?.pushViewController(controller, animated: true)
                    break
                case .cacheRow:
                    switch clearCache() {
                    case .success(let totalBytesCleared):
                        let byteCountFormatter = ByteCountFormatter()
                        byteCountFormatter.allowedUnits = [.useMB, .useKB, .useBytes]
                        byteCountFormatter.countStyle = .file
                        let formattedSize = byteCountFormatter.string(fromByteCount: totalBytesCleared)
                        ToastView(text: "Cleared \(formattedSize) in cache.", detailText: nil).show(in: self)
                    case .failure(let error):
                        ToastView(error: error).show(in: self)
                    }
            }
            break
        case .troubleshooting:
            let row = TroubleshootingRow.allCases[indexPath.row]
            switch row
            {
            case .exportCertificate: self.exportCertificate()
            case .synchronizeAppIDs: self.synchronizeAppIDs()
            case .resetAllPairingFiles:
                PairingFileManager.shared.resetAllPairingFiles()
                ToastView(text: "Reset all pairing files", detailText: nil).show(in: self)
            case .resetAllSettings:
                self.resetAllSettings()
            case .importBackup:
                self.promptImportBackup()
            case .exportBackup:
                self.promptExportBackup()
            }

        default: break
        }
    }
}

private extension SettingsViewController{

    func fetchAnisetteList(url: URL, completion: @escaping (_ jsonString: String?, _ error: Error?) -> Void)
    {
        var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
            if(error != nil){
                completion(nil, error)
            }
            if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                completion(jsonString, nil)
            }
        }).resume()
    }

    func updateData(){
        guard let url = URL(string: "https://servers.sidestore.io/servers.json") else {
            return
        }
        self.fetchAnisetteList(url: url) { jsonString, error in
            if error != nil{
                print(error!)
                return
            }
            guard let jsonData = jsonString?.data(using: .utf8) else { return }
            guard let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) else { return }
            guard let jsonDict = jsonObject as? [String: Any] else { return }

            if let serversArray = jsonDict["servers"] as? [[String: String]] {
                var serverList: [MenuItem] = []

                for item in serversArray {
                    if let name = item["name"], let address = item["address"] {
                        let menuItem = MenuItem(key: name, value: address)
                        serverList.append(menuItem)
                    }
                }
                if !serverList.isEmpty {
                    UserDefaults.standard.menuAnisetteServersList = serverList
                    DispatchQueue.main.async {
                        self.setupAnisetteListPopupButton()
                    }
                }
            }
        }
    }
}
