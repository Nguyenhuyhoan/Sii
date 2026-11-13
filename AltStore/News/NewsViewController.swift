
//
//  NewsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers
import Combine
import Network
import AltStoreCore
import Minimuxer

@objc(NewsViewController)
final class NewsViewController: UICollectionViewController {
    private var hostingController: UIHostingController<CheckDashboardView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.collectionView.isHidden = true

        let hc = UIHostingController(rootView: CheckDashboardView())
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        addChild(hc)
        view.addSubview(hc.view)
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hc.didMove(toParent: self)
        self.hostingController = hc
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

// MARK: - Models & ViewModel

private enum CheckDetailSheet: String, Identifiable {
    case pairing, vpn, cellular, anisette
    var id: String { rawValue }
}

private enum PairingGuideTab: Int, CaseIterable { case ios27 = 0, pc = 1 }

@MainActor
private final class CheckDashboardViewModel: ObservableObject {
    @Published var isPairingFileInstalled = false
    @Published var isTunnelHealthy = false
    @Published var isPairingVerified = false
    @Published var isPairingInvalid = false
    @Published var isVPNActive = false
    @Published var vpnInterfaceName = "—"
    @Published var vpnIPAddress = "—"
    @Published var isCellularActive = false
    @Published var isCellularEnabledOnDevice = false
    @Published var cellularRefreshEnabled = UserDefaults.standard.isCellularRefreshEnabled {
        didSet {
            if UserDefaults.standard.isCellularRefreshEnabled != cellularRefreshEnabled {
                UserDefaults.standard.isCellularRefreshEnabled = cellularRefreshEnabled
            }
        }
    }
    @Published var useLocalAnisette = UserDefaults.standard.useLocalAnisette
    @Published var currentAnisetteURL = UserDefaults.standard.textInputAnisetteURL

    private var timer: Timer?
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.sidestore.check.networkmonitor")
    private var hasPathSnapshot = false
    private var latestWiFiActive = false
    private var latestCellularActive = false
    private var latestCellularAvailable = false

    init() {
        if !UserDefaults.standard.bool(forKey: "com.sidestore.check.defaultCellularRefreshInitialized") {
            UserDefaults.standard.set(true, forKey: "com.sidestore.check.defaultCellularRefreshInitialized")
            UserDefaults.standard.isCellularRefreshEnabled = true
            self.cellularRefreshEnabled = true
        }
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let wifi = path.usesInterfaceType(.wifi)
            let cell = path.usesInterfaceType(.cellular)
            let cellAvail = cell || path.availableInterfaces.contains { $0.type == .cellular }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.hasPathSnapshot = true
                self.latestWiFiActive = wifi
                self.latestCellularActive = cell
                self.latestCellularAvailable = cellAvail
                self.refreshStatuses()
            }
        }
        pathMonitor.start(queue: monitorQueue)
        refreshStatuses()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshStatuses() }
        }
    }

    deinit { timer?.invalidate(); pathMonitor.cancel() }

    func refreshStatuses() {
        let fm = FileManager.default
        let pairingExists = (DatabaseManager.shared.PairingFile() != nil) ||
            (fm.documentsDirectory.map { fm.fileExists(atPath: $0.appendingPathComponent("ALTPairingFile.mobiledevicepairing").path) } ?? false)
        isPairingFileInstalled = pairingExists

        let ready = Minimuxer.ready()
        isTunnelHealthy = ready

        let vpnInfo = Self.detectVPNInterface()
        isVPNActive = vpnInfo.active
        vpnInterfaceName = vpnInfo.interfaceName
        vpnIPAddress = vpnInfo.ipAddress

        let cellInfo = Self.detectCellularStatus()
        isCellularActive = hasPathSnapshot ? latestCellularActive : cellInfo.active
        isCellularEnabledOnDevice = (hasPathSnapshot ? (latestCellularActive || latestCellularAvailable) : false) || cellInfo.enabledOnDevice

        if !pairingExists {
            isPairingVerified = false; isPairingInvalid = false
        } else if isVPNActive {
            let status = test_device_connection()
            isPairingVerified = (status == .Ok) || (ready && status != .NoConnection)
            isPairingInvalid = !isPairingVerified && (status == .NoConnection || (!latestWiFiActive && !isCellularActive))
        } else {
            isPairingVerified = ready; isPairingInvalid = false
        }

        if cellularRefreshEnabled != UserDefaults.standard.isCellularRefreshEnabled {
            cellularRefreshEnabled = UserDefaults.standard.isCellularRefreshEnabled
        }
        useLocalAnisette = UserDefaults.standard.useLocalAnisette
        currentAnisetteURL = UserDefaults.standard.textInputAnisetteURL
    }

    func selectAnisetteURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.textInputAnisetteURL = trimmed
        UserDefaults.standard.selectedAnisetteURL = trimmed
        currentAnisetteURL = trimmed
    }

    func setUseLocalAnisette(_ enabled: Bool) {
        UserDefaults.standard.useLocalAnisette = enabled
        useLocalAnisette = enabled
    }

    func removePairingFile() {
        try? AppManager.shared.deletePairing()
        if let docDir = FileManager.default.documentsDirectory {
            try? FileManager.default.removeItem(at: docDir.appendingPathComponent("ALTPairingFile.mobiledevicepairing"))
        }
        isPairingFileInstalled = false; isPairingVerified = false; isPairingInvalid = false
        refreshStatuses()
    }

    var anisetteHostSummary: String {
        URL(string: currentAnisetteURL)?.host ?? currentAnisetteURL
    }

    private static func detectVPNInterface() -> (active: Bool, interfaceName: String, ipAddress: String) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (false, "—", "—") }
        defer { freeifaddrs(ifaddr) }
        var fallback: (String, String)?
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee
            let name = String(cString: interface.ifa_name)
            let isUp = (Int32(interface.ifa_flags) & IFF_UP) != 0 && (Int32(interface.ifa_flags) & IFF_RUNNING) != 0
            if isUp, let addr = interface.ifa_addr, (name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp") || name.hasPrefix("tun") || name.hasPrefix("tap")) {
                let family = addr.pointee.sa_family
                if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let len = family == UInt8(AF_INET) ? socklen_t(MemoryLayout<sockaddr_in>.size) : socklen_t(MemoryLayout<sockaddr_in6>.size)
                    if getnameinfo(addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: host)
                        if ip.hasPrefix("10.7.") || ip.hasPrefix("fd00:") { return (true, name, ip) }
                        if family == UInt8(AF_INET), !ip.hasPrefix("169.254."), !ip.hasPrefix("127.") { fallback = (name, ip) }
                        else if fallback == nil && !ip.hasPrefix("fe80:") { fallback = (name, ip) }
                    }
                }
            }
            ptr = interface.ifa_next
        }
        return fallback.map { (true, $0.0, $0.1) } ?? (false, "—", "—")
    }

    private static func detectCellularStatus() -> (active: Bool, enabledOnDevice: Bool) {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (false, false) }
        defer { freeifaddrs(ifaddr) }
        var hasPDP = false
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee
            if String(cString: interface.ifa_name).hasPrefix("pdp_ip"),
               (Int32(interface.ifa_flags) & IFF_UP) != 0,
               let addr = interface.ifa_addr {
                let family = addr.pointee.sa_family
                if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                    var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let len = family == UInt8(AF_INET) ? socklen_t(MemoryLayout<sockaddr_in>.size) : socklen_t(MemoryLayout<sockaddr_in6>.size)
                    if getnameinfo(addr, len, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: host)
                        if !ip.isEmpty && !ip.hasPrefix("fe80:") && !ip.hasPrefix("169.254.") && !ip.hasPrefix("127.") && ip != "0.0.0.0" {
                            hasPDP = true; break
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }
        return (hasPDP, hasPDP)
    }
}

// MARK: - Main Dashboard View

private struct CheckDashboardView: View {
    @StateObject private var vm = CheckDashboardViewModel()
    @AppStorage(CheckAppLanguage.storageKey) private var langRaw = CheckAppLanguage.vi.rawValue
    @State private var activeSheet: CheckDetailSheet?
    @Environment(\.openURL) private var openURL

    private var lang: CheckAppLanguage { CheckAppLanguage(rawValue: langRaw) ?? .vi }

    private var shortcuts: [(icon: String, color: Color, title: String, sub: String, url: String)] {[
        ("antenna.radiowaves.left.and.right.slash", AppUI.SwiftUIColors.red, AppStrings.Check.shortcutTurnOff4G(lang), "iCloud Shortcut", "https://www.icloud.com/shortcuts/440f5efcd4fb44c887aa8a8dccefb2fd"),
        ("antenna.radiowaves.left.and.right", AppUI.SwiftUIColors.blue, AppStrings.Check.shortcutTurnOn4G(lang), "iCloud Shortcut", "https://www.icloud.com/shortcuts/762b21c622b24e359f5b9cd45163dbad"),
        ("clock.badge.checkmark", AppUI.SwiftUIColors.green, AppStrings.Check.shortcutAutoRefresh6AM(lang), "Auto Refresh 4G • 06:00", "https://www.icloud.com/shortcuts/3acbd28dc0fb4ec8bddcb8bc5c00201f"),
        ("clock.fill", AppUI.SwiftUIColors.purple, AppStrings.Check.shortcutAutoRefresh3PM(lang), "Auto Refresh 4G 2 • 15:00", "https://www.icloud.com/shortcuts/f2af9ca5f3de4fd3982ebfd8ebccfd0c")
    ]}

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 18) {
                headerBar

                CSSSectionCard(title: AppStrings.Check.systemStatus(lang), icon: "checkmark.shield.fill") {
                    VStack(spacing: 0) {
                        statusRow(icon: "key.fill", color: pairingColor, title: "Pairing File", subtitle: pairingSubtitle, ok: vm.isPairingVerified, warning: vm.isPairingFileInstalled && !vm.isPairingVerified && !vm.isPairingInvalid) { activeSheet = .pairing }
                        Divider().padding(.leading, 52)
                        statusRow(icon: "network.badge.shield.half.filled", color: vm.isVPNActive ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.red, title: "LocalDevVPN", subtitle: vm.isVPNActive ? "\(AppStrings.Common.stable(lang)) • \(vm.vpnInterfaceName) (\(vm.vpnIPAddress))" : AppStrings.Common.disconnected(lang), ok: vm.isVPNActive) { activeSheet = .vpn }
                        Divider().padding(.leading, 52)
                        statusRow(icon: "antenna.radiowaves.left.and.right", color: cellularReady ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.red, title: AppStrings.Check.cellularData(lang), subtitle: cellularReady ? AppStrings.Common.stable(lang) : AppStrings.Common.disabled(lang), ok: cellularReady) { activeSheet = .cellular }
                        Divider().padding(.leading, 52)
                        statusRow(icon: "server.rack", color: !vm.useLocalAnisette ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.red, title: AppStrings.Check.anisetteServer(lang), subtitle: !vm.useLocalAnisette ? "\(AppStrings.Common.stable(lang)) • \(vm.anisetteHostSummary)" : AppStrings.Common.unstable(lang), ok: !vm.useLocalAnisette) { activeSheet = .anisette }
                    }
                }

                CSSSectionCard(title: AppStrings.Check.shortcuts(lang), icon: "bolt.horizontal.circle.fill") {
                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            CSSIconBox("cellularbars", color: AppUI.SwiftUIColors.green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(AppStrings.Check.cellularRefreshToggleTitle(lang)).font(.system(size: 16, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark)
                                Text(AppStrings.Check.enabledByDefault(lang)).font(.system(size: 13)).foregroundColor(AppUI.SwiftUIColors.subtitle)
                            }
                            Spacer()
                            Toggle("", isOn: $vm.cellularRefreshEnabled).labelsHidden().tint(AppUI.SwiftUIColors.green)
                        }.padding(.vertical, 10)

                        ForEach(Array(shortcuts.enumerated()), id: \.offset) { _, item in
                            Divider().padding(.leading, 52)
                            shortcutRow(icon: item.icon, color: item.color, title: item.title, subtitle: item.sub, urlString: item.url)
                        }
                    }
                }

                CSSSectionCard(title: AppStrings.Check.automationGuide(lang), icon: "photo.on.rectangle.angled") {
                    VStack(alignment: .leading, spacing: 16) {
                        guideStep(caption: AppStrings.Check.autoGuideStep1Caption(lang), url: "https://raw.githubusercontent.com/dabeecao/check/refs/heads/main/IMG_4982.png")
                        Divider()
                        guideStep(caption: AppStrings.Check.autoGuideStep2Caption(lang), url: "https://raw.githubusercontent.com/dabeecao/check/refs/heads/main/IMG_4983.png")
                    }.padding(.vertical, 6)
                }

                CSSSectionCard(title: AppStrings.Check.shortcutVideoGuide(lang), icon: "play.rectangle.fill") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(AppStrings.Check.videoGuideDescription(lang)).font(.system(size: 14)).foregroundColor(AppUI.SwiftUIColors.dark)
                        Link(destination: URL(string: "https://youtu.be/b5ce983WT9M?si=2faA7nE7W7s7tG1E")!) {
                            ZStack {
                                AsyncImage(url: URL(string: "https://img.youtube.com/vi/b5ce983WT9M/hqdefault.jpg")) { phase in
                                    if case .success(let img) = phase { img.resizable().scaledToFill() }
                                    else { Rectangle().fill(Color.black.opacity(0.8)) }
                                }.frame(height: 190).clipped().cornerRadius(AppUI.Layout.radius)
                                Circle().fill(AppUI.SwiftUIColors.red).frame(width: 60, height: 60).shadow(radius: 8)
                                    .overlay(Image(systemName: "play.fill").font(.system(size: 24, weight: .bold)).foregroundColor(.white).offset(x: 2))
                            }
                        }.buttonStyle(CSSPressButtonStyle())
                    }.padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .cssBodyBackground()
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .pairing: PairingDetailSheetView(vm: vm, lang: lang)
            case .vpn: VPNDetailSheetView(vm: vm, lang: lang)
            case .cellular: CellularDetailSheetView(vm: vm, lang: lang)
            case .anisette: AnisetteDetailSheetView(vm: vm, lang: lang)
            }
        }
    }

    private var cellularReady: Bool { vm.isCellularActive || vm.isCellularEnabledOnDevice }
    private var pairingColor: Color {
        if !vm.isPairingFileInstalled || vm.isPairingInvalid { return AppUI.SwiftUIColors.red }
        return vm.isPairingVerified ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.orange
    }
    private var pairingSubtitle: String {
        if !vm.isPairingFileInstalled { return AppStrings.Check.noPairingFile(lang) }
        if vm.isPairingVerified { return "\(AppStrings.Common.stable(lang)) • \(AppStrings.Check.pairingFileLoaded(lang))" }
        if vm.isPairingInvalid { return AppStrings.Check.pairingErrorTapRepair(lang) }
        return AppStrings.Check.tapToVerify(lang)
    }

    /// Thanh Header chuẩn `.site-header` và `.lang-btn` từ CSS trong ThemeManager
    private var headerBar: some View {
        HStack {
            HStack(spacing: 10) {
                CSSIconBox("shield.lefthalf.filled.badge.checkmark", color: AppUI.SwiftUIColors.blue, size: 40)
                Text("Check")
                    .font(.system(size: 26, weight: .heavy))
                    .foregroundColor(AppUI.SwiftUIColors.blue)
            }
            Spacer()
            CSSLanguageSwitcher(
                items: CheckAppLanguage.allCases,
                selected: lang,
                titleProvider: { $0 == .vi ? "VN" : "EN" },
                onSelect: { langRaw = $0.rawValue }
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .modifier(CSSCardModifier())
    }

    private func statusRow(icon: String, color: Color, title: String, subtitle: String, ok: Bool, warning: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CSSIconBox(icon, color: color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark)
                    Text(subtitle).font(.system(size: 13)).foregroundColor(ok ? AppUI.SwiftUIColors.green : (warning ? AppUI.SwiftUIColors.orange : AppUI.SwiftUIColors.red)).lineLimit(1)
                }
                Spacer()
                Image(systemName: ok ? "checkmark.circle.fill" : (warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill"))
                    .font(.system(size: 20)).foregroundColor(ok ? AppUI.SwiftUIColors.green : (warning ? AppUI.SwiftUIColors.orange : AppUI.SwiftUIColors.red))
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.gray.opacity(0.6))
            }.padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(CSSPressButtonStyle())
    }

    private func shortcutRow(icon: String, color: Color, title: String, subtitle: String, urlString: String) -> some View {
        Button { if let u = URL(string: urlString) { openURL(u) } } label: {
            HStack(spacing: 14) {
                CSSIconBox(icon, color: color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark).multilineTextAlignment(.leading)
                    Text(subtitle).font(.system(size: 12)).foregroundColor(AppUI.SwiftUIColors.subtitle)
                }
                Spacer()
                Text(AppStrings.Common.get(lang)).font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Capsule().fill(AppUI.SwiftUIColors.blue))
                    .shadow(color: AppUI.SwiftUIColors.blue.opacity(0.3), radius: 5, x: 0, y: 3)
            }.padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(CSSPressButtonStyle())
    }

    private func guideStep(caption: String, url: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(caption).font(.system(size: 14, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark)
            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .empty: HStack { Spacer(); ProgressView(AppStrings.Check.loadingImage(lang)); Spacer() }.frame(height: 180)
                case .success(let img):
                    img.resizable().scaledToFit().frame(maxWidth: .infinity)
                        .cornerRadius(AppUI.Layout.radius)
                        .overlay(RoundedRectangle(cornerRadius: AppUI.Layout.radius).stroke(AppUI.SwiftUIColors.border, lineWidth: 1))
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                case .failure: Text(AppStrings.Check.imageLoadError(lang)).font(.system(size: 13)).foregroundColor(AppUI.SwiftUIColors.red)
                @unknown default: EmptyView()
                }
            }
        }
    }
}

// MARK: - 1. Pairing Detail Sheet

private struct PairingDetailSheetView: View {
    @ObservedObject var vm: CheckDashboardViewModel
    let lang: CheckAppLanguage
    @Environment(\.dismiss) private var dismiss
    @StateObject private var wirelessPairing = WirelessPairingManager()
    @State private var selectedTab: PairingGuideTab = .ios27
    @State private var isImporterPresented = false
    @State private var isExporterPresented = false
    @State private var exportDocument: PairingFileExportDocument?
    @State private var statusBannerMessage: String?
    @State private var isStatusError = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CSSSheetStatusHeader(icon: headerIcon, color: headerColor, title: headerTitle, subtitle: headerSub)
                    verificationStepsBox
                    tabSelector
                    if let msg = statusBannerMessage {
                        HStack(spacing: 10) {
                            Image(systemName: isStatusError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundColor(isStatusError ? AppUI.SwiftUIColors.red : AppUI.SwiftUIColors.green)
                            Text(msg).font(.system(size: 13, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark)
                            Spacer()
                        }.padding(12).modifier(CSSCardModifier())
                    }
                    if selectedTab == .ios27 { ios27Content } else { pcContent }
                    deleteButtonSection
                }.padding(16)
            }
            .cssBodyBackground()
            .navigationTitle(AppStrings.Check.pairingVerificationTitle(lang))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(AppStrings.Common.done(lang)) { dismiss() }.font(.headline) } }
            .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.data, .item, .xml, .propertyList], allowsMultipleSelection: false, onCompletion: handleImport)
            .fileExporter(isPresented: $isExporterPresented, document: exportDocument, contentType: .mobileDevicePairingExportType, defaultFilename: "ALTPairingFile.mobiledevicepairing") { _ in }
            .alert(AppStrings.Check.deletePairingAlertTitle(lang), isPresented: $showDeleteConfirmation) {
                Button(AppStrings.Common.delete(lang), role: .destructive) {
                    vm.removePairingFile()
                    isStatusError = false
                    statusBannerMessage = AppStrings.Check.pairingDeletedBanner(lang)
                }
                Button(AppStrings.Common.cancel(lang), role: .cancel) {}
            } message: { Text(AppStrings.Check.deletePairingAlertMessage(lang)) }
            .onChange(of: wirelessPairing.pairedSuccessCount) { count in
                guard count > 0, let data = wirelessPairing.lastGeneratedPairingData else { return }
                activatePairingData(data, msg: AppStrings.Check.pairingInstalledBanner(lang))
            }
        }
    }

    private var headerIcon: String {
        if !vm.isPairingFileInstalled || vm.isPairingInvalid { return "xmark.octagon.fill" }
        return vm.isPairingVerified ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
    }
    private var headerColor: Color {
        if !vm.isPairingFileInstalled || vm.isPairingInvalid { return AppUI.SwiftUIColors.red }
        return vm.isPairingVerified ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.orange
    }
    private var headerTitle: String {
        if !vm.isPairingFileInstalled { return AppStrings.Check.pairingHeaderMissing(lang) }
        if vm.isPairingVerified { return AppStrings.Check.pairingHeaderVerified(lang) }
        return vm.isPairingInvalid ? AppStrings.Check.pairingHeaderInvalid(lang) : AppStrings.Check.pairingHeaderWaiting(lang)
    }
    private var headerSub: String {
        if !vm.isPairingFileInstalled { return AppStrings.Check.noPairingFile(lang) }
        if vm.isPairingVerified { return "\(AppStrings.Common.stable(lang)) • \(AppStrings.Check.pairingFileLoaded(lang))" }
        return vm.isPairingInvalid ? AppStrings.Check.pairingExpiredDetail(lang) : AppStrings.Check.tapToVerify(lang)
    }

    private var verificationStepsBox: some View {
        CSSSectionCard(title: AppStrings.Check.verify3StepsTitle(lang), icon: "checklist.checked") {
            VStack(alignment: .leading, spacing: 10) {
                stepRow("1", AppStrings.Check.verifyStep1Title(lang), AppStrings.Check.verifyStep1Body(lang))
                stepRow("2", AppStrings.Check.verifyStep2Title(lang), AppStrings.Check.verifyStep2Body(lang))
                stepRow("3", AppStrings.Check.verifyStep3Title(lang), AppStrings.Check.verifyStep3Body(lang))
                Divider()
                Text(AppStrings.Check.verifyFooterNote(lang)).font(.system(size: 13, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.blue)
            }
        }
    }

    /// Nút chuyển Tab thiết kế theo `.tab-button` trong CSS (Tab 1: Magenta, Tab 2: Purple)
    private var tabSelector: some View {
        HStack(spacing: 10) {
            ForEach(PairingGuideTab.allCases, id: \.rawValue) { tab in
                let isSelected = (selectedTab == tab)
                let tabColor = (tab == .ios27) ? AppUI.SwiftUIColors.magenta : AppUI.SwiftUIColors.purple
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedTab = tab }
                } label: {
                    Text(tab == .ios27 ? AppStrings.Check.part1iOS27Title(lang) : AppStrings.Check.part2PCTitle(lang))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? .white : tabColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Group {
                                if isSelected {
                                    LinearGradient(colors: [tabColor, tabColor.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                } else {
                                    AppUI.SwiftUIColors.white.opacity(0.92)
                                }
                            }
                        )
                        .cornerRadius(AppUI.Layout.radius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppUI.Layout.radius)
                                .stroke(isSelected ? tabColor : AppUI.SwiftUIColors.border, lineWidth: 2)
                        )
                        .shadow(color: tabColor.opacity(isSelected ? 0.35 : 0.18), radius: isSelected ? 12 : 6, x: 0, y: 6)
                }
                .buttonStyle(CSSPressButtonStyle())
            }
        }
    }

    private var ios27Content: some View {
        VStack(alignment: .leading, spacing: 16) {
            CSSSectionCard(title: AppStrings.Check.directPairingSubtitle(lang), icon: "iphone.radiowaves.left.and.right") {
                VStack(alignment: .leading, spacing: 12) {
                    stepRow("1", AppStrings.Check.ios27Step1Title(lang), AppStrings.Check.ios27Step1Body(lang))
                    stepRow("2", AppStrings.Check.ios27Step2Title(lang), AppStrings.Check.ios27Step2Body(lang))
                    stepRow("3", AppStrings.Check.ios27Step3Title(lang), AppStrings.Check.ios27Step3Body(lang))
                    stepRow("4", AppStrings.Check.ios27Step4Title(lang), AppStrings.Check.ios27Step4Body(lang))
                }
            }

            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Text(AppStrings.Check.pinCodeHeader(lang)).font(.system(size: 12, weight: .bold)).foregroundColor(AppUI.SwiftUIColors.gray)
                    Text(wirelessPairing.pinCode).font(.system(size: 32, weight: .heavy, design: .monospaced)).tracking(6).foregroundColor(AppUI.SwiftUIColors.blue)
                    if !wirelessPairing.statusText.isEmpty {
                        Text(wirelessPairing.statusText).font(.system(size: 13, weight: .medium))
                            .foregroundColor(wirelessPairing.hasPairedSuccessfully ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.dark)
                            .multilineTextAlignment(.center)
                    }
                }.frame(maxWidth: .infinity).padding(14).background(AppUI.SwiftUIColors.light).cornerRadius(12)

                CSSActionButton(
                    icon: wirelessPairing.isRunning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right",
                    title: wirelessPairing.isRunning ? AppStrings.Check.stopPairingBroadcastBtn(lang) : AppStrings.Check.startPairingBroadcastBtn(lang),
                    style: wirelessPairing.isRunning ? .warningOrange : .primaryBlue
                ) {
                    wirelessPairing.isRunning ? wirelessPairing.stop() : wirelessPairing.start()
                }

                CSSActionButton(icon: "square.and.arrow.up.fill", title: AppStrings.Check.exportBackupBtn(lang), style: .green) {
                    prepareAndExport()
                }

                CSSActionButton(icon: "folder.fill.badge.plus", title: AppStrings.Check.importExistingPairingBtn(lang), style: .purple) {
                    isImporterPresented = true
                }
            }.padding(16).modifier(CSSCardModifier())
        }
    }

    private var pcContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            CSSSectionCard(title: AppStrings.Check.pcPairingSubtitle(lang), icon: "desktopcomputer") {
                VStack(alignment: .leading, spacing: 14) {
                    Text(.init(AppStrings.Check.pcPrepInfo(lang))).font(.system(size: 13.5)).foregroundColor(AppUI.SwiftUIColors.dark)
                    Divider()
                    pcCard("1.circle.fill", AppStrings.Check.pcMethod1Title(lang), AppStrings.Check.pcMethod1Body(lang))
                    pcCard("2.circle.fill", AppStrings.Check.pcMethod2Title(lang), AppStrings.Check.pcMethod2Body(lang))
                    pcCard("3.circle.fill", AppStrings.Check.pcMethod3Title(lang), AppStrings.Check.pcMethod3Body(lang))
                }
            }

            VStack(spacing: 12) {
                CSSActionButton(icon: "folder.fill.badge.plus", title: AppStrings.Check.importFromFilesBtn(lang), style: .primaryBlue) {
                    isImporterPresented = true
                }
            }.padding(16).modifier(CSSCardModifier())
        }
    }

    @ViewBuilder private var deleteButtonSection: some View {
        if vm.isPairingFileInstalled {
            VStack {
                CSSActionButton(icon: "trash.fill", title: AppStrings.Check.deletePairingBtn(lang), style: .destructiveRed) {
                    showDeleteConfirmation = true
                }
            }.padding(16).modifier(CSSCardModifier())
        }
    }

    private func stepRow(_ num: String, _ title: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(num).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                .frame(width: 26, height: 26).background(Circle().fill(AppUI.SwiftUIColors.blue))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(AppUI.SwiftUIColors.dark)
                Text(.init(desc)).font(.system(size: 13.5)).foregroundColor(AppUI.SwiftUIColors.dark.opacity(0.85))
            }
        }
    }

    private func pcCard(_ icon: String, _ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).foregroundColor(AppUI.SwiftUIColors.blue)
                Text(title).font(.system(size: 14.5, weight: .bold)).foregroundColor(AppUI.SwiftUIColors.blue)
            }
            Text(.init(body)).font(.system(size: 13)).foregroundColor(AppUI.SwiftUIColors.dark.opacity(0.9))
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(AppUI.SwiftUIColors.light).cornerRadius(10)
    }

    private func prepareAndExport() {
        if let data = wirelessPairing.lastGeneratedPairingData ?? DatabaseManager.shared.PairingFile() ??
            FileManager.default.documentsDirectory.flatMap({ try? Data(contentsOf: $0.appendingPathComponent("ALTPairingFile.mobiledevicepairing")) }) {
            exportDocument = PairingFileExportDocument(data: data)
            isExporterPresented = true
        } else {
            isStatusError = true
            statusBannerMessage = AppStrings.Check.exportBeforePairWarning(lang)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url) { activatePairingData(data, msg: AppStrings.Check.pairingImportedBanner(lang)) }
        case .failure(let err):
            isStatusError = true; statusBannerMessage = err.localizedDescription
        }
    }

    private func activatePairingData(_ data: Data, msg: String) {
        if let docDir = FileManager.default.documentsDirectory {
            try? data.write(to: docDir.appendingPathComponent("ALTPairingFile.mobiledevicepairing"), options: .atomic)
        }
        AppManager.shared.installPairingFile(data: data) { res in
            DispatchQueue.main.async {
                if case .failure(let err) = res { isStatusError = true; statusBannerMessage = err.localizedDescription }
                else { isStatusError = false; statusBannerMessage = msg }
                vm.refreshStatuses()
            }
        }
    }
}

private extension UTType {
    static var mobileDevicePairingExportType: UTType { UTType(filenameExtension: "mobiledevicepairing", conformingTo: .data) ?? .data }
}

private struct PairingFileExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.mobileDevicePairingExportType, .data, .propertyList] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { self.data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

// MARK: - 2. VPN, 3. Cellular & 4. Anisette Sheets

private struct VPNDetailSheetView: View {
    @ObservedObject var vm: CheckDashboardViewModel
    let lang: CheckAppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var copiedField: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CSSSheetStatusHeader(
                        icon: vm.isVPNActive ? "checkmark.shield.fill" : "xmark.shield.fill",
                        color: vm.isVPNActive ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.red,
                        title: vm.isVPNActive ? AppStrings.Check.vpnStableHeader(lang) : AppStrings.Check.vpnDisconnectedHeader(lang),
                        subtitle: vm.isVPNActive ? "Interface: \(vm.vpnInterfaceName) • IP: \(vm.vpnIPAddress)" : AppStrings.Check.vpnSwitchHint(lang)
                    )
                    CSSSectionCard(title: AppStrings.Check.vpnCurrentDetailsTitle(lang), icon: "network") {
                        VStack(spacing: 10) {
                            HStack { Text("Interface:").fontWeight(.semibold); Spacer(); Text(vm.vpnInterfaceName).foregroundColor(AppUI.SwiftUIColors.gray) }
                            HStack { Text("IP Address:").fontWeight(.semibold); Spacer(); Text(vm.vpnIPAddress).foregroundColor(AppUI.SwiftUIColors.gray) }
                        }
                    }
                    CSSSectionCard(title: AppStrings.Check.vpnRecommendedTitle(lang), icon: "slider.horizontal.3") {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(AppStrings.Check.vpnRecommendedDesc(lang)).font(.system(size: 14)).foregroundColor(AppUI.SwiftUIColors.dark)
                            copyRow(title: "Tunnel IPv4 Address", value: "10.7.0.0")
                            copyRow(title: "Tunnel IPv6 Address", value: "fd00::")
                        }
                    }
                }.padding(16)
            }
            .cssBodyBackground()
            .navigationTitle("LocalDevVPN").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(AppStrings.Common.done(lang)) { dismiss() }.font(.headline) } }
        }
    }

    private func copyRow(title: String, value: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium)).foregroundColor(AppUI.SwiftUIColors.gray)
                Text(value).font(.system(size: 16, weight: .bold, design: .monospaced)).foregroundColor(AppUI.SwiftUIColors.dark)
            }
            Spacer()
            Button {
                UIPasteboard.general.string = value
                withAnimation { copiedField = value }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copiedField == value ? "checkmark" : "doc.on.doc")
                    Text(copiedField == value ? AppStrings.Common.copied(lang) : AppStrings.Common.copy(lang))
                }.font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(copiedField == value ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.blue))
            }.buttonStyle(CSSPressButtonStyle())
        }.padding(12).background(AppUI.SwiftUIColors.light).cornerRadius(10)
    }
}

private struct CellularDetailSheetView: View {
    @ObservedObject var vm: CheckDashboardViewModel
    let lang: CheckAppLanguage
    @Environment(\.dismiss) private var dismiss
    private var ready: Bool { vm.isCellularActive || vm.isCellularEnabledOnDevice }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CSSSheetStatusHeader(
                        icon: "antenna.radiowaves.left.and.right",
                        color: ready ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.red,
                        title: ready ? AppStrings.Check.cellularStableHeader(lang) : AppStrings.Check.cellularOffHeader(lang),
                        subtitle: vm.isCellularActive ? AppStrings.Check.cellularDirectDetail(lang) : (vm.isCellularEnabledOnDevice ? AppStrings.Check.cellularReadyDetail(lang) : AppStrings.Check.cellularOffDetail(lang))
                    )
                    CSSSectionCard(title: AppStrings.Check.cellularCardTitle(lang), icon: "bolt.shield.fill") {
                        Text(.init(AppStrings.Check.cellularCardBody(lang))).font(.system(size: 14)).foregroundColor(AppUI.SwiftUIColors.dark)
                    }
                }.padding(16)
            }
            .cssBodyBackground()
            .navigationTitle(AppStrings.Check.cellularData(lang)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(AppStrings.Common.done(lang)) { dismiss() }.font(.headline) } }
        }
    }
}

private struct AnisetteDetailSheetView: View {
    @ObservedObject var vm: CheckDashboardViewModel
    let lang: CheckAppLanguage
    @Environment(\.dismiss) private var dismiss
    @State private var customURLInput = ""

    private var servers: [(name: String, url: String)] {
        var list = UserDefaults.standard.defaultAnisetteServers.map { ($0.key, $0.value) }
        let cur = vm.currentAnisetteURL
        if !cur.isEmpty, !list.contains(where: { $0.url == cur }) {
            list.insert(("\(AppStrings.Check.customServerPrefix(lang)) (\(URL(string: cur)?.host ?? cur))", cur), at: 0)
        }
        return list
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CSSSheetStatusHeader(
                        icon: !vm.useLocalAnisette ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                        color: !vm.useLocalAnisette ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.red,
                        title: !vm.useLocalAnisette ? AppStrings.Check.anisetteStableHeader(lang) : AppStrings.Check.anisetteOnDeviceHeader(lang),
                        subtitle: !vm.useLocalAnisette ? AppStrings.Check.anisetteStableHost(vm.anisetteHostSummary, lang) : AppStrings.Check.anisetteOnDeviceWarning(lang)
                    )
                    CSSSectionCard(title: AppStrings.Check.anisetteModeCardTitle(lang), icon: "cpu") {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Use On-Device Anisette").font(.system(size: 15, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark)
                                    Text(vm.useLocalAnisette ? AppStrings.Check.anisetteOnDeviceEnabledSub(lang) : AppStrings.Check.anisetteOnDeviceDisabledSub(lang))
                                        .font(.system(size: 12.5, weight: .semibold)).foregroundColor(vm.useLocalAnisette ? AppUI.SwiftUIColors.red : AppUI.SwiftUIColors.green)
                                }
                                Spacer()
                                Toggle("", isOn: Binding(get: { vm.useLocalAnisette }, set: { vm.setUseLocalAnisette($0) })).labelsHidden().tint(AppUI.SwiftUIColors.blue)
                            }
                            if vm.useLocalAnisette {
                                CSSActionButton(title: AppStrings.Check.turnOffOnDeviceNowBtn(lang), style: .green) {
                                    vm.setUseLocalAnisette(false)
                                }
                            }
                        }
                    }

                    CSSSectionCard(title: AppStrings.Check.selectAnisetteServerTitle(lang), icon: "server.rack") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(servers, id: \.url) { item in
                                let sel = (vm.currentAnisetteURL == item.url)
                                Button { vm.selectAnisetteURL(item.url); customURLInput = item.url } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: sel ? "largecircle.fill.circle" : "circle").font(.system(size: 18)).foregroundColor(sel ? AppUI.SwiftUIColors.green : AppUI.SwiftUIColors.gray)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name).font(.system(size: 14, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark).lineLimit(1)
                                            Text(item.url).font(.system(size: 12)).foregroundColor(AppUI.SwiftUIColors.gray).lineLimit(1)
                                        }
                                        Spacer()
                                        if sel {
                                            Text(AppStrings.Check.inUseBadge(lang)).font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                                                .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(AppUI.SwiftUIColors.green))
                                        }
                                    }.padding(10).background(sel ? AppUI.SwiftUIColors.green.opacity(0.08) : AppUI.SwiftUIColors.light).cornerRadius(10)
                                }.buttonStyle(CSSPressButtonStyle())
                            }
                            Divider()
                            Text(AppStrings.Check.customServerInputLabel(lang)).font(.system(size: 13, weight: .semibold)).foregroundColor(AppUI.SwiftUIColors.dark)
                            HStack(spacing: 8) {
                                TextField("https://...", text: $customURLInput).textInputAutocapitalization(.never).disableAutocorrection(true)
                                    .font(.system(size: 14)).padding(10).background(AppUI.SwiftUIColors.light).cornerRadius(8)
                                Button { vm.selectAnisetteURL(customURLInput) } label: {
                                    Text(AppStrings.Common.save(lang)).font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                        .padding(.horizontal, 14).padding(.vertical, 10).background(AppUI.SwiftUIColors.blue).cornerRadius(8)
                                }.buttonStyle(CSSPressButtonStyle())
                            }
                        }
                    }
                }.padding(16)
            }
            .cssBodyBackground()
            .navigationTitle(AppStrings.Check.anisetteServerTitle(lang)).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button(AppStrings.Common.done(lang)) { dismiss() }.font(.headline) } }
            .onAppear { customURLInput = vm.currentAnisetteURL }
        }
    }
}
