
//
//  NewsViewController.swift
//  AltStore
//

@preconcurrency import UIKit
import SwiftUI
import Network
import UniformTypeIdentifiers
@preconcurrency import Minimuxer
import MinimuxerCommon
import Combine
import Darwin

enum CheckAppLanguage: String, CaseIterable {
    case vi = "vi"
    case en = "en"
}

private enum SkyTheme {
    static let primary = SwiftUI.Color(red: 0.05, green: 0.58, blue: 0.96)
    static let secondary = SwiftUI.Color(red: 0.22, green: 0.72, blue: 1.00)
    static let darkAccent = SwiftUI.Color(red: 0.02, green: 0.44, blue: 0.82)

    static let pageBackground = SwiftUI.Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.05, green: 0.08, blue: 0.13, alpha: 1.0)
            : UIColor(red: 0.93, green: 0.97, blue: 1.00, alpha: 1.0)
    })

    static let cardBackground = SwiftUI.Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.10, green: 0.14, blue: 0.21, alpha: 1.0)
            : UIColor.white
    })

    static let cardHeaderBackground = SwiftUI.Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.20, blue: 0.30, alpha: 0.75)
            : UIColor(red: 0.88, green: 0.95, blue: 1.00, alpha: 0.85)
    })

    static let innerRowBackground = SwiftUI.Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.19, blue: 0.28, alpha: 1.0)
            : UIColor(red: 0.96, green: 0.99, blue: 1.00, alpha: 1.0)
    })

    static let border = SwiftUI.Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.22, green: 0.55, blue: 0.90, alpha: 0.35)
            : UIColor(red: 0.12, green: 0.60, blue: 0.96, alpha: 0.24)
    })

    static let innerBorder = SwiftUI.Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.25, green: 0.60, blue: 0.95, alpha: 0.22)
            : UIColor(red: 0.12, green: 0.60, blue: 0.96, alpha: 0.14)
    })

    static let shadow = SwiftUI.Color(red: 0.04, green: 0.42, blue: 0.78).opacity(0.08)
}

private enum CellularRefreshDefaultBootstrapper {
    private static let initializedKey = "com.sidestore.cellularRefresh.defaultEnabledInitialized"
    private static var didApply = false

    static func applyDefaultTrueIfNeeded() {
        guard !didApply else { return }
        didApply = true

        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            #keyPath(UserDefaults.isCellularRefreshEnabled): true
        ])
        if !defaults.bool(forKey: initializedKey) {
            defaults.set(true, forKey: initializedKey)
            CellularRefreshManager.shared.setEnabled(true)
        }
    }
}

private enum AnisetteDefaultsHelper {
    static var currentServerURL: String {
        let menuURL = UserDefaults.standard.menuAnisetteURL.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !menuURL.isEmpty {
            return menuURL
        }
        if let textInput = UserDefaults.standard.textInputAnisetteURL?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
           !textInput.isEmpty {
            return textInput
        }
        if let custom = UserDefaults.standard.customAnisetteURL?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines),
           !custom.isEmpty {
            return custom
        }
        return AppConstants.Anisette.Servers.defaultServerURL
    }

    static func selectServerFromList(_ url: String) {
        let trimmed = url.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.textServer = false
        UserDefaults.standard.menuAnisetteURL = trimmed
        UserDefaults.standard.textInputAnisetteURL = trimmed
        UserDefaults.standard.customAnisetteURL = trimmed
    }

    static func setCustomServerURL(_ url: String) {
        let trimmed = url.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        UserDefaults.standard.menuAnisetteURL = trimmed
        UserDefaults.standard.textInputAnisetteURL = trimmed
        UserDefaults.standard.customAnisetteURL = trimmed
    }
}

/// Quản lý giữ tiến trình chạy nền khi người dùng chuyển sang app Cài đặt để nhập mã PIN Pairing
@MainActor
private final class PairingBackgroundKeepAliveManager {
    static let shared = PairingBackgroundKeepAliveManager()
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    func beginKeepAlive() {
        guard bgTask == .invalid else { return }
        bgTask = UIApplication.shared.beginBackgroundTask(withName: "com.sidestore.wirelessPairing.keepAlive") { [weak self] in
            Task { @MainActor in
                self?.endKeepAlive()
            }
        }
    }

    func endKeepAlive() {
        guard bgTask != .invalid else { return }
        UIApplication.shared.endBackgroundTask(bgTask)
        bgTask = .invalid
    }
}

class NewsViewController: UICollectionViewController {
    var source: Source?

    init?(source: Source?, coder: NSCoder) {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        self.source = source
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()

        self.title = "Check"
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.collectionView.backgroundColor = UIColor(SkyTheme.pageBackground)
        self.collectionView.contentInsetAdjustmentBehavior = .never

        let hostingController = UIHostingController(rootView: SystemCheckDashboardView())
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = UIColor(SkyTheme.pageBackground)
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
    }
}

@MainActor
final class SystemCheckViewModel: ObservableObject {
    private static let languageStorageKey = "com.sidestore.check.selectedLanguage"
    private static let verifiedPairingCacheKey = "com.sidestore.check.lastVerifiedPairingSuccess"

    @Published var language: CheckAppLanguage = {
        if let raw = UserDefaults.standard.string(forKey: languageStorageKey),
           let saved = CheckAppLanguage(rawValue: raw) {
            return saved
        }
        return .vi
    }()

    @Published var isPairingOK: Bool = false
    @Published var pairingProtocol: String = ""
    @Published var hasAnyStoredPairingFile: Bool = false

    @Published var isVpnOK: Bool = false
    @Published var tunnelIP: String = ""
    @Published var deviceIP: String = ""

    @Published var isCellularOK: Bool = false
    @Published var cellularDetail: String = ""

    @Published var isAnisetteOK: Bool = !UserDefaults.standard.useOnDeviceAnisette
    @Published var useOnDeviceAnisette: Bool = UserDefaults.standard.useOnDeviceAnisette
    @Published var selectedAnisetteServerURL: String = AnisetteDefaultsHelper.currentServerURL
    @Published var anisetteDetail: String = ""

    @Published var isCellularRefreshEnabled: Bool = {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        return UserDefaults.standard.isCellularRefreshEnabled
    }()

    /// Cờ báo hiệu đang phát sóng cài Pairing trực tiếp (tạm dừng mọi tác vụ chọc ngoáy Minimuxer)
    @Published var isWirelessPairingActive: Bool = false

    private let pathMonitor = NWPathMonitor()
    private let cellularMonitor = NWPathMonitor(requiredInterfaceType: .cellular)
    private let wifiMonitor = NWPathMonitor(requiredInterfaceType: .wifi)
    private let monitorQueue = DispatchQueue(label: "com.sidestore.check.network", qos: .utility)

    private var usesCellularPath: Bool = false
    private var isCellularPathSatisfied: Bool = false
    private var usesWifiPath: Bool = false
    private var isWifiPathSatisfied: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private var timerTask: Task<Void, Never>?

    private var isViewVisible: Bool = false
    private var isChecking: Bool = false
    private var isUpdatingDefaultsInternally: Bool = false

    private var lastVerifiedPairingSuccess: Bool = UserDefaults.standard.bool(forKey: verifiedPairingCacheKey) {
        didSet {
            if oldValue != lastVerifiedPairingSuccess {
                UserDefaults.standard.set(lastVerifiedPairingSuccess, forKey: Self.verifiedPairingCacheKey)
            }
        }
    }

    private var lastVerifiedTunnelIP: String = ""
    private var lastLiveVerifyTimestamp: Date = .distantPast
    private var didAttemptLiveVerify: Bool = false
    private var consecutiveVerifyFailures: Int = 0

    private let networkChangeSubject = PassthroughSubject<Bool, Never>()

    func tr(_ vi: String, _ en: String) -> String {
        language == .vi ? vi : en
    }

    func setLanguage(_ newLang: CheckAppLanguage) {
        guard language != newLang else { return }
        language = newLang
        UserDefaults.standard.set(newLang.rawValue, forKey: Self.languageStorageKey)
        updateInstantStatus()
    }

    func setWirelessPairingActive(_ active: Bool) {
        guard isWirelessPairingActive != active else { return }
        isWirelessPairingActive = active
        if active {
            PairingBackgroundKeepAliveManager.shared.beginKeepAlive()
            stopSmartPeriodicMonitor()
        } else {
            PairingBackgroundKeepAliveManager.shared.endKeepAlive()
            if isViewVisible {
                startSmartPeriodicMonitor()
                Task { await checkAllStatuses(forceVerify: true) }
            }
        }
    }

    func markPairingVerifiedImmediately() {
        self.hasAnyStoredPairingFile = true
        self.didAttemptLiveVerify = false
        self.consecutiveVerifyFailures = 0
        updateInstantStatus()
    }

    init() {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        updateInstantStatus()
        setupRealtimeListeners()
        Task {
            _ = try? await AnisetteServersManager.shared.syncWithRemote()
            await checkAllStatuses(forceVerify: true)
        }
    }

    deinit {
        pathMonitor.cancel()
        cellularMonitor.cancel()
        wifiMonitor.cancel()
        timerTask?.cancel()
    }

    func setViewVisible(_ visible: Bool) {
        guard isViewVisible != visible else { return }
        isViewVisible = visible
        if visible {
            updateInstantStatus()
            if !isWirelessPairingActive {
                startSmartPeriodicMonitor()
                Task { await checkAllStatuses(forceVerify: true) }
            }
        } else {
            stopSmartPeriodicMonitor()
        }
    }

    private func startSmartPeriodicMonitor() {
        guard timerTask == nil, !isWirelessPairingActive else { return }
        timerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                let isAllGood = (self?.isVpnOK == true && self?.isPairingOK == true)
                let sleepNanoseconds: UInt64 = isAllGood ? 8_000_000_000 : 4_000_000_000
                try? await Task.sleep(nanoseconds: sleepNanoseconds)

                guard let self = self, !Task.isCancelled, self.isViewVisible, !self.isWirelessPairingActive else { break }

                let elapsed = Date().timeIntervalSince(self.lastLiveVerifyTimestamp)
                let needDeepVerify = !self.lastVerifiedPairingSuccess || elapsed > 15
                await self.checkAllStatuses(forceVerify: needDeepVerify)
            }
        }
    }

    private func stopSmartPeriodicMonitor() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func setupRealtimeListeners() {
        networkChangeSubject
            .debounce(for: .milliseconds(600), scheduler: DispatchQueue.main)
            .sink { [weak self] forceVerify in
                guard let self = self, !self.isWirelessPairingActive else { return }
                self.updateInstantStatus()
                guard self.isViewVisible else { return }
                Task { @MainActor [weak self] in
                    await self?.checkAllStatuses(forceVerify: forceVerify)
                }
            }
            .store(in: &cancellables)

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let usesCell = path.usesInterfaceType(.cellular)
            let usesWifi = path.usesInterfaceType(.wifi)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.usesCellularPath != usesCell {
                    self.usesCellularPath = usesCell
                }
                if self.usesWifiPath != usesWifi {
                    self.usesWifiPath = usesWifi
                }
                guard !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(true)
            }
        }
        pathMonitor.start(queue: monitorQueue)

        cellularMonitor.pathUpdateHandler = { [weak self] path in
            let cellSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isCellularPathSatisfied != cellSatisfied {
                    self.isCellularPathSatisfied = cellSatisfied
                }
                guard !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(true)
            }
        }
        cellularMonitor.start(queue: monitorQueue)

        wifiMonitor.pathUpdateHandler = { [weak self] path in
            let wifiSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if self.isWifiPathSatisfied != wifiSatisfied {
                    self.isWifiPathSatisfied = wifiSatisfied
                }
                guard !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(true)
            }
        }
        wifiMonitor.start(queue: monitorQueue)

        minimuxer.network.pathPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(true)
            }
            .store(in: &cancellables)

        minimuxerStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(true)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateInstantStatus()
                guard !self.isWirelessPairingActive else { return }
                if self.isViewVisible {
                    self.startSmartPeriodicMonitor()
                }
                Task { @MainActor [weak self] in
                    _ = try? await AnisetteServersManager.shared.syncWithRemote()
                    await self?.checkAllStatuses(forceVerify: true)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.stopSmartPeriodicMonitor()
            }
            .store(in: &cancellables)
    }

    private struct SystemInterfaceSnapshot: Sendable {
        let hasCellularIPv4: Bool
        let hasWifiIPv4: Bool
        let hasActiveLocalDevUtun: Bool
        let detectedLocalDevUtunIPv4: String?
    }

    private nonisolated static func scanSystemInterfaces() -> SystemInterfaceSnapshot {
        var hasPdpIPv4 = false
        var hasEn0IPv4 = false
        var hasLocalDevUtun = false
        var bestLocalDevUtunIP: String? = nil

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr {
            defer { freeifaddrs(ifaddr) }
            var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
            while let current = ptr {
                let flags = Int32(current.pointee.ifa_flags)
                let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
                if isUp, let addr = current.pointee.ifa_addr {
                    let family = addr.pointee.sa_family
                    if family == UInt8(AF_INET) {
                        let name = String(cString: current.pointee.ifa_name).lowercased()
                        if name == "pdp_ip0" || name == "en0" || name.hasPrefix("utun") {
                            var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                            if getnameinfo(
                                addr,
                                socklen_t(addr.pointee.sa_len),
                                &hostname,
                                socklen_t(hostname.count),
                                nil,
                                0,
                                NI_NUMERICHOST
                            ) == 0 {
                                let ip = String(cString: hostname)
                                if !ip.isEmpty && !ip.hasPrefix("169.254.") && ip != "0.0.0.0" {
                                    if name == "pdp_ip0" {
                                        hasPdpIPv4 = true
                                    } else if name == "en0" {
                                        hasEn0IPv4 = true
                                    } else if name.hasPrefix("utun") {
                                        if ip.hasPrefix("10.7.") {
                                            hasLocalDevUtun = true
                                            bestLocalDevUtunIP = ip
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                ptr = current.pointee.ifa_next
            }
        }

        return SystemInterfaceSnapshot(
            hasCellularIPv4: hasPdpIPv4,
            hasWifiIPv4: hasEn0IPv4,
            hasActiveLocalDevUtun: hasLocalDevUtun,
            detectedLocalDevUtunIPv4: bestLocalDevUtunIP
        )
    }

    private func ensureTunnelRoutingPinned(snapshot: SystemInterfaceSnapshot) {
        guard !isWirelessPairingActive else { return }
        guard let utunIP = snapshot.detectedLocalDevUtunIPv4, utunIP.hasPrefix("10.7.") else { return }

        isUpdatingDefaultsInternally = true
        defer { isUpdatingDefaultsInternally = false }

        let config = ConnectionConfig.shared
        if config.overrideTunnelPeerIp != "10.7.0.1" {
            config.overrideTunnelPeerIp = "10.7.0.1"
        }
        if !config.overrideTunnelPeerReachable {
            config.overrideTunnelPeerReachable = true
        }
    }

    func setUseOnDeviceAnisette(_ enabled: Bool) {
        UserDefaults.standard.useOnDeviceAnisette = enabled
        updateInstantStatus()
    }

    func setCellularRefreshEnabled(_ enabled: Bool) {
        guard isCellularRefreshEnabled != enabled || UserDefaults.standard.isCellularRefreshEnabled != enabled else { return }
        isCellularRefreshEnabled = enabled
        CellularRefreshManager.shared.setEnabled(enabled)
        updateInstantStatus()
    }

    func selectAnisetteServerURL(_ urlString: String, isCustom: Bool = false) {
        if isCustom {
            AnisetteDefaultsHelper.setCustomServerURL(urlString)
        } else {
            AnisetteDefaultsHelper.selectServerFromList(urlString)
        }
        if UserDefaults.standard.useOnDeviceAnisette {
            UserDefaults.standard.useOnDeviceAnisette = false
        }
        updateInstantStatus()
    }

    func deleteAllPairingFiles() {
        PairingFileManager.shared.resetAllPairingFiles()
        self.hasAnyStoredPairingFile = false
        self.lastVerifiedPairingSuccess = false
        self.lastVerifiedTunnelIP = ""
        self.didAttemptLiveVerify = false
        self.consecutiveVerifyFailures = 0
        self.isPairingOK = false
        updateInstantStatus()
    }

    private static func isValidConnectedIP(_ value: String?, disconnectedText: String) -> Bool {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return false
        }
        let lower = trimmed.lowercased()
        if trimmed == disconnectedText
            || lower.contains("chưa kết nối")
            || lower.contains("disconnected")
            || lower == "none"
            || lower == "nil"
            || lower == "n/a"
            || lower == "0.0.0.0" {
            return false
        }
        return true
    }

    private func assignIfChanged<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<SystemCheckViewModel, T>, _ newValue: T) {
        if self[keyPath: keyPath] != newValue {
            self[keyPath: keyPath] = newValue
        }
    }

    func updateInstantStatus() {
        let snapshot = Self.scanSystemInterfaces()
        ensureTunnelRoutingPinned(snapshot: snapshot)

        let cellularActive = usesCellularPath || isCellularPathSatisfied || snapshot.hasCellularIPv4
        let wifiActive = usesWifiPath || isWifiPathSatisfied || snapshot.hasWifiIPv4
        assignIfChanged(\.isCellularOK, cellularActive)

        let newCellularDetail: String
        if usesCellularPath {
            newCellularDetail = tr(
                "Ổn định • Đang dùng trực tiếp 4G / 5G",
                "Stable • Using 4G / 5G directly"
            )
        } else if cellularActive {
            newCellularDetail = tr(
                "Ổn định • 4G / 5G đang bật sẵn sàng",
                "Stable • 4G / 5G is enabled and ready"
            )
        } else {
            newCellularDetail = tr(
                "Chưa bật • Hãy bật Dữ liệu di động (4G/5G)",
                "Disabled • Please turn on Cellular Data (4G/5G)"
            )
        }
        assignIfChanged(\.cellularDetail, newCellularDetail)

        let disconnectedText = tr("Chưa kết nối", "Disconnected")
        let config = ConnectionConfig.shared

        let activeTunnelIP: String? = {
            if let detected = snapshot.detectedLocalDevUtunIPv4, !detected.isEmpty {
                return config.formattedTunnelIface ?? config.tunnelIfaceIp ?? detected
            }
            if let iface = config.tunnelIfaceIp, iface.hasPrefix("10.7.") {
                return config.formattedTunnelIface ?? iface
            }
            return nil
        }()

        let activeDeviceIP: String? = {
            guard activeTunnelIP != nil else { return nil }
            if let formattedPeer = config.formattedTunnelPeer, !formattedPeer.isEmpty {
                return formattedPeer
            }
            if let peer = config.tunnelPeerIp, !peer.isEmpty {
                return peer
            }
            if config.overrideTunnelPeerReachable, !config.overrideTunnelPeerIp.isEmpty {
                return config.overrideTunnelPeerIp
            }
            if let tIP = activeTunnelIP, tIP.contains("10.7.") {
                return "10.7.0.1"
            }
            return nil
        }()

        let resolvedTunnelText = Self.isValidConnectedIP(activeTunnelIP, disconnectedText: disconnectedText)
            ? activeTunnelIP!
            : disconnectedText
        let resolvedDeviceText = Self.isValidConnectedIP(activeDeviceIP, disconnectedText: disconnectedText)
            ? activeDeviceIP!
            : disconnectedText

        assignIfChanged(\.tunnelIP, resolvedTunnelText)
        assignIfChanged(\.deviceIP, resolvedDeviceText)

        let vpnConnected = (resolvedTunnelText != disconnectedText) && (resolvedDeviceText != disconnectedText)
        assignIfChanged(\.isVpnOK, vpnConnected)

        let hasRp = PairingFileManager.shared.hasPairingFile(for: .rppairing)
        let hasLd = PairingFileManager.shared.hasPairingFile(for: .lockdown)
        let hasUnk = PairingFileManager.shared.hasPairingFile(for: .unknown)
        let hasAnyFile = hasRp || hasLd || hasUnk
        assignIfChanged(\.hasAnyStoredPairingFile, hasAnyFile)

        let coreLoaded = minimuxer.core.isPairingFileLoaded && hasAnyFile
        let activeType: PairingProtocol = {
            if coreLoaded && minimuxer.core.pairingFileType != .unknown {
                return minimuxer.core.pairingFileType
            }
            if let persisted = PairingFileManager.shared.persistedActiveProtocol {
                let hasPersisted = (persisted == .rppairing && hasRp)
                                || (persisted == .lockdown && hasLd)
                                || (persisted == .unknown && hasUnk)
                if hasPersisted {
                    return persisted
                }
            }
            if hasRp { return .rppairing }
            if hasLd { return .lockdown }
            return .unknown
        }()

        let protocolName: String = {
            switch activeType {
            case .rppairing:
                return "Remote Pairing (iOS 17+ / 27)"
            case .lockdown:
                return "Lockdown Pairing"
            case .unknown:
                return (hasAnyFile || coreLoaded)
                    ? tr("Đã nạp Pairing File", "Pairing File Loaded")
                    : tr("Chưa có Pairing File", "No Pairing File")
            }
        }()

        // Điều kiện kiểm tra Pairing chính xác 100%:
        // 1. Bật LocalDevVPN (vpnConnected == true)
        // 2. Tắt cả Wi-Fi và 4G (!wifiActive && !cellularActive) để kết nối thẳng qua LocalDevVPN
        let isDirectLocalDevOnly = vpnConnected && !wifiActive && !cellularActive

        if !hasAnyFile {
            self.lastVerifiedPairingSuccess = false
            self.lastVerifiedTunnelIP = ""
            self.didAttemptLiveVerify = false
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.pairingProtocol, tr("Chưa xác minh • Chưa có Pairing File", "Unverified • No Pairing File"))
        } else if !vpnConnected {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.pairingProtocol, tr(
                "Chưa xác minh • Bước 1: Hãy bật LocalDevVPN",
                "Unverified • Step 1: Please turn ON LocalDevVPN"
            ))
        } else if wifiActive || cellularActive {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.pairingProtocol, tr(
                "Chưa xác minh • Bước 2: Hãy tắt Wi-Fi và 4G để kiểm tra",
                "Unverified • Step 2: Turn OFF Wi-Fi & 4G to verify"
            ))
        } else if isDirectLocalDevOnly && self.lastVerifiedPairingSuccess {
            assignIfChanged(\.isPairingOK, true)
            assignIfChanged(\.pairingProtocol, protocolName)
        } else if self.didAttemptLiveVerify {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.pairingProtocol, tr(
                "Pairing lỗi hoặc hết hạn • Hãy cài lại Pairing",
                "Pairing invalid or expired • Please re-pair"
            ))
        } else {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.pairingProtocol, tr("Đang kiểm tra qua LocalDevVPN...", "Verifying over LocalDevVPN..."))
        }

        let onDevice = UserDefaults.standard.useOnDeviceAnisette
        assignIfChanged(\.useOnDeviceAnisette, onDevice)
        assignIfChanged(\.isAnisetteOK, !onDevice)

        let selectedURL = AnisetteDefaultsHelper.currentServerURL
        assignIfChanged(\.selectedAnisetteServerURL, selectedURL)
        let serverHost = URL(string: selectedURL)?.host ?? selectedURL
        let newAnisetteDetail = onDevice
            ? tr("Không ổn định • Hãy tắt Use On-Device Anisette", "Unstable • Please disable Use On-Device Anisette")
            : tr("Ổn định • Máy chủ: \(serverHost)", "Stable • Server: \(serverHost)")
        assignIfChanged(\.anisetteDetail, newAnisetteDetail)

        let currentCellularRefresh = UserDefaults.standard.isCellularRefreshEnabled
        assignIfChanged(\.isCellularRefreshEnabled, currentCellularRefresh)
    }

    private func verifyPairingOverTunnel() async -> Bool {
        for attempt in 0..<2 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            if let udid = try? await fetchUDID(forceLive: true), !udid.isEmpty {
                return true
            }
        }
        return false
    }

    func checkAllStatuses(forceVerify: Bool = false) async {
        guard !isWirelessPairingActive else { return }
        updateInstantStatus()

        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        guard hasAnyStoredPairingFile else {
            self.lastVerifiedPairingSuccess = false
            self.lastVerifiedTunnelIP = ""
            self.didAttemptLiveVerify = false
            self.consecutiveVerifyFailures = 0
            assignIfChanged(\.isPairingOK, false)
            updateInstantStatus()
            return
        }

        if hasAnyStoredPairingFile && !minimuxer.core.isPairingFileLoaded {
            let proto: PairingProtocol = PairingFileManager.shared.persistedActiveProtocol
                ?? (PairingFileManager.shared.hasPairingFile(for: .rppairing) ? .rppairing : .lockdown)
            try? await minimuxerSwitchPairingProtocol(to: proto)
        }

        let snapshot = Self.scanSystemInterfaces()
        let cellularActive = usesCellularPath || isCellularPathSatisfied || snapshot.hasCellularIPv4
        let wifiActive = usesWifiPath || isWifiPathSatisfied || snapshot.hasWifiIPv4
        let isDirectLocalDevOnly = isVpnOK && !wifiActive && !cellularActive

        if isDirectLocalDevOnly {
            let tunnelChanged = (lastVerifiedTunnelIP != tunnelIP)
            if forceVerify || !didAttemptLiveVerify || !lastVerifiedPairingSuccess || tunnelChanged {
                let ok = await verifyPairingOverTunnel()
                self.didAttemptLiveVerify = true
                self.lastLiveVerifyTimestamp = Date()
                if ok {
                    self.consecutiveVerifyFailures = 0
                    self.lastVerifiedPairingSuccess = true
                    self.lastVerifiedTunnelIP = tunnelIP
                    assignIfChanged(\.isPairingOK, true)
                } else {
                    self.consecutiveVerifyFailures += 1
                    self.lastVerifiedPairingSuccess = false
                    assignIfChanged(\.isPairingOK, false)
                }
            }
        } else {
            self.consecutiveVerifyFailures = 0
            self.didAttemptLiveVerify = false
            assignIfChanged(\.isPairingOK, false)
        }

        updateInstantStatus()
    }
}

struct SystemCheckDashboardView: SwiftUI.View {
    @StateObject private var vm = SystemCheckViewModel()
    @State private var showPairingSheet = false
    @State private var showVpnSheet = false
    @State private var showCellularSheet = false
    @State private var showAnisetteSheet = false

    var body: some SwiftUI.View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                languageTopCenteredSection
                systemStatusSection
                serverSection
                shortcutsSection
                automationGuideSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .background(SkyTheme.pageBackground.ignoresSafeArea())
        .onAppear {
            vm.setViewVisible(true)
        }
        .onDisappear {
            vm.setViewVisible(false)
        }
        .refreshable {
            await vm.checkAllStatuses(forceVerify: true)
        }
        .sheet(isPresented: $showPairingSheet) {
            PairingGuideSheetView(vm: vm)
        }
        .sheet(isPresented: $showVpnSheet) {
            VpnDetailSheetView(vm: vm)
        }
        .sheet(isPresented: $showCellularSheet) {
            CellularDetailSheetView(vm: vm)
        }
        .sheet(isPresented: $showAnisetteSheet) {
            AnisetteDetailSheetView(vm: vm)
        }
    }

    private var languageTopCenteredSection: some SwiftUI.View {
        HStack {
            Spacer()
            CompactLanguageSwitchButton(
                selectedLanguage: vm.language,
                onSelect: { vm.setLanguage($0) }
            )
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private var systemStatusSection: some SwiftUI.View {
        let allReady = vm.isPairingOK && vm.isVpnOK && vm.isCellularOK && vm.isAnisetteOK

        return SkySectionCard(
            title: vm.tr("Trạng Thái Hệ Thống", "System Status"),
            icon: "cpu.fill",
            color: SkyTheme.primary,
            statusOK: allReady
        ) {
            CheckItemButton(
                title: "LocalDevVPN",
                subtitle: vm.isVpnOK
                    ? vm.tr("Ổn định", "Stable")
                    : vm.tr("Chưa kết nối", "Disconnected"),
                icon: "network.badge.shield.half.filled",
                isStable: vm.isVpnOK
            ) {
                showVpnSheet = true
            }

            CheckItemButton(
                title: "Pairing File",
                subtitle: vm.isPairingOK
                    ? vm.tr("Ổn định", "Stable")
                    : vm.tr("Chưa xác minh", "Unverified"),
                icon: "doc.badge.gearshape.fill",
                isStable: vm.isPairingOK
            ) {
                showPairingSheet = true
            }

            CheckItemButton(
                title: vm.tr("Mạng 4G / Di động", "4G / Cellular Data"),
                subtitle: vm.isCellularOK
                    ? vm.tr("Ổn định", "Stable")
                    : vm.tr("Chưa bật", "Disabled"),
                icon: "antenna.radiowaves.left.and.right",
                isStable: vm.isCellularOK
            ) {
                showCellularSheet = true
            }
        }
    }

    private var serverSection: some SwiftUI.View {
        SkySectionCard(
            title: vm.tr("Máy chủ Anisette", "Anisette Server"),
            icon: "server.rack",
            color: SkyTheme.primary
        ) {
            CheckItemButton(
                title: vm.tr("Máy chủ Anisette", "Anisette Server"),
                subtitle: vm.isAnisetteOK
                    ? vm.tr("Ổn định", "Stable")
                    : vm.tr("Không ổn định", "Unstable"),
                icon: "server.rack",
                isStable: vm.isAnisetteOK
            ) {
                showAnisetteSheet = true
            }
        }
    }

    private var shortcutsSection: some SwiftUI.View {
        SkySectionCard(
            title: vm.tr("Phím Tắt", "Shortcuts"),
            icon: "bolt.circle.fill",
            color: SkyTheme.primary
        ) {
            CellularRefreshToggleRow(
                title: vm.tr("Cellular Refresh (Refresh Qua 4G)", "Cellular Refresh (Refresh via 4G)"),
                onText: vm.tr("Đã bật mặc định", "Enabled by Default"),
                offText: vm.tr("Chưa bật", "Disabled"),
                isOn: Binding(
                    get: { vm.isCellularRefreshEnabled },
                    set: { vm.setCellularRefreshEnabled($0) }
                )
            )

            ShortcutLinkRow(
                title: vm.tr("Phím tắt Tắt 4G", "Turn Off 4G Shortcut"),
                buttonTitle: vm.tr("Nhận", "Get"),
                icon: "antenna.radiowaves.left.and.right.slash",
                color: SkyTheme.darkAccent,
                urlString: "https://www.icloud.com/shortcuts/ee47f3710b02435883faa746c7355236"
            )

            ShortcutLinkRow(
                title: vm.tr("Phím tắt Bật 4G", "Turn On 4G Shortcut"),
                buttonTitle: vm.tr("Nhận", "Get"),
                icon: "antenna.radiowaves.left.and.right",
                color: SkyTheme.primary,
                urlString: "https://www.icloud.com/shortcuts/10bd8bb0aa1540c4b1221182b835fc43"
            )

            ShortcutLinkRow(
                title: vm.tr("Tự động làm mới App (6:00 sáng)", "Auto Refresh App (6:00 AM)"),
                buttonTitle: vm.tr("Nhận", "Get"),
                icon: "clock.arrow.2.circlepath",
                color: .cyan,
                urlString: "https://www.icloud.com/shortcuts/56b0ab8cb0984d0b9a98543ac879eeec"
            )

            ShortcutLinkRow(
                title: vm.tr("Tự động làm mới App (15:00 chiều)", "Auto Refresh App (3:00 PM)"),
                buttonTitle: vm.tr("Nhận", "Get"),
                icon: "sun.max.circle.fill",
                color: SkyTheme.primary,
                urlString: "https://www.icloud.com/shortcuts/9f93051e8bf142258ffc93e08f3c0849"
            )
        }
    }

    private var automationGuideSection: some SwiftUI.View {
        SkySectionCard(
            title: vm.tr("Hướng Dẫn Tự Động Hóa", "Automation Guide"),
            icon: "bell.badge.fill",
            color: SkyTheme.primary
        ) {
            VStack(spacing: 14) {
                RemoteGuideImageView(
                    urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2589.jpeg",
                    caption: vm.tr(
                        "Bước 1: Mở Phím Tắt mục Auto Refresh 4G (Auto Refresh 4G 2) và nhấn vào dấu xổ xuống:",
                        "Step 1: Open Shortcuts ➔ Auto Refresh 4G (Auto Refresh 4G 2) and tap the dropdown arrow:"
                    ),
                    loadingText: vm.tr("Đang tải ảnh...", "Loading image..."),
                    errorText: vm.tr("Không tải được ảnh. Vui lòng kiểm tra mạng.", "Failed to load image. Please check your connection.")
                )
                RemoteGuideImageView(
                    urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2588.jpeg",
                    caption: vm.tr(
                        "Bước 2: Bật nút Tự động hóa:",
                        "Step 2: Turn on Enable This Automation:"
                    ),
                    loadingText: vm.tr("Đang tải ảnh...", "Loading image..."),
                    errorText: vm.tr("Không tải được ảnh. Vui lòng kiểm tra mạng.", "Failed to load image. Please check your connection.")
                )
            }
            .padding(12)
            .background(SkyTheme.innerRowBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SkyTheme.innerBorder, lineWidth: 1)
            )
        }
    }
}

struct SkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeaderView(
                title: title,
                icon: icon,
                color: color,
                statusOK: statusOK,
                trailingView: trailingView
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(SkyTheme.cardHeaderBackground)

            Rectangle()
                .fill(SkyTheme.border)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 11) {
                content
            }
            .padding(14)
        }
        .background(SkyTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SkyTheme.border, lineWidth: 1.2)
        )
        .shadow(color: SkyTheme.shadow, radius: 10, x: 0, y: 4)
    }
}

struct CompactLanguageSwitchButton: SwiftUI.View {
    let selectedLanguage: CheckAppLanguage
    let onSelect: (CheckAppLanguage) -> Void

    var body: some SwiftUI.View {
        HStack(spacing: 6) {
            SwiftUI.Button {
                onSelect(.vi)
            } label: {
                HStack(spacing: 6) {
                    SwiftUI.Text("🇻🇳")
                        .font(.system(size: 16))
                    SwiftUI.Text("Tiếng Việt")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    selectedLanguage == .vi
                    ? LinearGradient(colors: [SkyTheme.primary, SkyTheme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [SwiftUI.Color.clear, SwiftUI.Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .foregroundColor(selectedLanguage == .vi ? .white : SkyTheme.darkAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())

            SwiftUI.Button {
                onSelect(.en)
            } label: {
                HStack(spacing: 6) {
                    SwiftUI.Text("🇺🇸")
                        .font(.system(size: 16))
                    SwiftUI.Text("English")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(
                    selectedLanguage == .en
                    ? LinearGradient(colors: [SkyTheme.primary, SkyTheme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [SwiftUI.Color.clear, SwiftUI.Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .foregroundColor(selectedLanguage == .en ? .white : SkyTheme.darkAccent)
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(4)
        .background(SkyTheme.cardBackground)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(SkyTheme.border, lineWidth: 1.4)
        )
        .shadow(color: SkyTheme.shadow, radius: 6, x: 0, y: 3)
    }
}

struct SectionHeaderView: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil

    var body: some SwiftUI.View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, SkyTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 34, height: 34)
                    .shadow(color: color.opacity(0.25), radius: 4, x: 0, y: 2)

                SwiftUI.Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            SwiftUI.Text(title)
                .font(.system(size: 18.5, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if let statusOK = statusOK {
                SwiftUI.Image(systemName: statusOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(statusOK ? .green : .red)
                    .animation(.spring(), value: statusOK)
            }

            Spacer(minLength: 4)

            if let trailingView = trailingView {
                trailingView
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct CheckItemButton: SwiftUI.View {
    let title: String
    let subtitle: String
    let icon: String
    let isStable: Bool
    let action: () -> Void

    var body: some SwiftUI.View {
        SwiftUI.Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(isStable ? SkyTheme.primary.opacity(0.14) : SwiftUI.Color.red.opacity(0.12))
                        .frame(width: 46, height: 46)
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(isStable ? SkyTheme.primary : .red)
                }

                VStack(alignment: .leading, spacing: 4) {
                    SwiftUI.Text(title)
                        .font(.system(size: 16.5, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    SwiftUI.Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                SwiftUI.Image(systemName: isStable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(isStable ? .green : .red)
                    .animation(.spring(), value: isStable)

                SwiftUI.Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(SkyTheme.primary.opacity(0.7))
            }
            .padding(13)
            .background(SkyTheme.innerRowBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SkyTheme.innerBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CellularRefreshToggleRow: SwiftUI.View {
    let title: String
    let onText: String
    let offText: String
    @Binding var isOn: Bool

    var body: some SwiftUI.View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill((isOn ? SkyTheme.primary : SwiftUI.Color.secondary).opacity(0.14))
                    .frame(width: 44, height: 44)
                SwiftUI.Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isOn ? SkyTheme.primary : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(title)
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                SwiftUI.Text(isOn ? onText : offText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(isOn ? SkyTheme.primary : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(SkyTheme.primary)
        }
        .padding(13)
        .background(SkyTheme.innerRowBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SkyTheme.innerBorder, lineWidth: 1)
        )
    }
}

struct ShortcutLinkRow: SwiftUI.View {
    let title: String
    let buttonTitle: String
    let icon: String
    let color: SwiftUI.Color
    let urlString: String

    var body: some SwiftUI.View {
        SwiftUI.Button(action: {
            if let url = URL(string: urlString) {
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(width: 44, height: 44)
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(color)
                }

                SwiftUI.Text(title)
                    .font(.system(size: 15.5, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                SwiftUI.Text(buttonTitle)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [SkyTheme.primary, SkyTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: SkyTheme.primary.opacity(0.25), radius: 3, x: 0, y: 2)
            }
            .padding(13)
            .background(SkyTheme.innerRowBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SkyTheme.innerBorder, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct RemoteGuideImageView: SwiftUI.View {
    let urlString: String
    let caption: String
    let loadingText: String
    let errorText: String

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            SwiftUI.Text(caption)
                .font(.system(size: 13.5, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        HStack(spacing: 8) {
                            ProgressView()
                                .tint(SkyTheme.primary)
                            SwiftUI.Text(loadingText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 150)
                        .background(SkyTheme.cardBackground)
                        .cornerRadius(14)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(SkyTheme.border, lineWidth: 1)
                            )
                    case .failure:
                        VStack(spacing: 6) {
                            SwiftUI.Image(systemName: "wifi.exclamationmark")
                                .font(.title3)
                                .foregroundColor(SkyTheme.primary)
                            SwiftUI.Text(errorText)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 110)
                        .background(SkyTheme.cardBackground)
                        .cornerRadius(14)
                    @unknown default:
                        EmptyView()
                    }
                }
            }
        }
    }
}

struct PairingGuideSheetView: SwiftUI.View {
    @ObservedObject var vm: SystemCheckViewModel
    @StateObject private var wirelessVM = WirelessPairViewModel()
    @StateObject private var pairingMgmtVM = PairingFileManagementViewModel()

    @State private var statusBannerMessage: String? = nil
    @State private var isExportSheetPresented = false
    @State private var exportFileURL: URL? = nil
    @State private var didPressInstallPairing = false
    @State private var showDeleteConfirmAlert = false

    @Environment(\.dismiss) private var dismiss

    private var installedPairingURLForExport: URL? {
        if let url = wirelessVM.shareSheetURL, FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        return nil
    }

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    statusHeaderCard
                    verificationAdviceCard

                    if let banner = statusBannerMessage {
                        HStack(spacing: 10) {
                            SwiftUI.Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(SkyTheme.primary)
                            SwiftUI.Text(banner)
                                .font(.footnote.bold())
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(12)
                        .background(SkyTheme.primary.opacity(0.12))
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(SkyTheme.border, lineWidth: 1)
                        )
                    }

                    ios27DirectPairingCard
                    pcPairingGuideCard
                }
                .padding(16)
            }
            .background(SkyTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(vm.tr("Mục Cài Pairing", "Pairing Setup Section"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button(vm.tr("Xong", "Done")) {
                        if wirelessVM.isAdvertising {
                            wirelessVM.togglePairing()
                        }
                        vm.setWirelessPairingActive(false)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(SkyTheme.primary)
                }
            }
            .onDisappear {
                if wirelessVM.isAdvertising {
                    wirelessVM.togglePairing()
                }
                vm.setWirelessPairingActive(false)
            }
            .alert(vm.tr("Xoá tệp Pairing?", "Delete Pairing File?"), isPresented: $showDeleteConfirmAlert) {
                SwiftUI.Button(vm.tr("Xoá", "Delete"), role: .destructive) {
                    vm.deleteAllPairingFiles()
                    statusBannerMessage = vm.tr(
                        "Đã xoá tệp Pairing khỏi ứng dụng.",
                        "Pairing file has been deleted from the app."
                    )
                }
                SwiftUI.Button(vm.tr("Huỷ", "Cancel"), role: .cancel) {}
            } message: {
                SwiftUI.Text(vm.tr(
                    "Tệp Pairing hiện tại sẽ bị xoá hoàn toàn khỏi ứng dụng. Bạn sẽ cần cài hoặc nhập lại tệp mới để tiếp tục sử dụng.",
                    "The current Pairing file will be completely removed from the app. You will need to pair or import a new file to continue."
                ))
            }
            #if !os(tvOS)
            .fileImporter(
                isPresented: $pairingMgmtVM.showFileImporter,
                allowedContentTypes: pairingMgmtVM.allowedPairingTypes
            ) { result in
                if case .success = result {
                    PairingFileManager.shared.resetAllPairingFiles()
                }
                pairingMgmtVM.handleImportResult(result)
                Task { @MainActor in
                    let proto = PairingFileManager.shared.persistedActiveProtocol
                        ?? PairingFileManager.shared.preferredProtocol
                        ?? .rppairing
                    try? await minimuxerSwitchPairingProtocol(to: proto)
                    vm.markPairingVerifiedImmediately()
                    await vm.checkAllStatuses(forceVerify: true)
                    if case .success = result {
                        statusBannerMessage = vm.tr(
                            "Đã nạp tệp Pairing! Hãy làm theo 2 bước bên trên (Bật LocalDevVPN + Tắt Wi-Fi và 4G) để kiểm tra.",
                            "Pairing file imported! Follow the 2 steps above (Turn ON LocalDevVPN + Turn OFF Wi-Fi & 4G) to verify."
                        )
                    }
                }
            }
            #endif
            .sheet(isPresented: Binding(
                get: { wirelessVM.pinCode != nil && !isExportSheetPresented },
                set: { if !$0 { wirelessVM.pinCode = nil } }
            )) {
                if let pin = wirelessVM.pinCode {
                    if #available(iOS 16.0, tvOS 16.0, *) {
                        WirelessPairPinDialog(pin: pin) { wirelessVM.pinCode = nil }
                            .presentationDetents([.fraction(0.45), .medium])
                            .presentationDragIndicator(.visible)
                    } else {
                        WirelessPairPinDialog(pin: pin) { wirelessVM.pinCode = nil }
                    }
                }
            }
            .sheet(isPresented: $isExportSheetPresented) {
                if let fileURL = exportFileURL {
                    ActivityViewController(activityItems: [fileURL])
                }
            }
            .onChange(of: wirelessVM.isAdvertising) { advertising in
                vm.setWirelessPairingActive(advertising)
            }
            .onChange(of: wirelessVM.pairedDevice != nil) { isPaired in
                if isPaired, let pairedURL = wirelessVM.shareSheetURL {
                    wirelessVM.pinCode = nil
                    wirelessVM.isShareSheetPresented = false
                    vm.setWirelessPairingActive(false)

                    PairingFileManager.shared.resetAllPairingFiles()
                    try? PairingFileManager.shared.importPairingFile(from: pairedURL, preferred: .rppairing)
                    Task { @MainActor in
                        try? await minimuxerSwitchPairingProtocol(to: .rppairing)
                        vm.markPairingVerifiedImmediately()
                        await vm.checkAllStatuses(forceVerify: true)
                        statusBannerMessage = vm.tr(
                            "Đã cài và nạp Pairing! Hãy làm theo 2 bước kiểm tra phía trên (Bật LocalDevVPN + Tắt Wi-Fi & 4G) để xác minh Tích xanh.",
                            "Pairing installed! Follow the 2 steps above (Turn ON LocalDevVPN + Turn OFF Wi-Fi & 4G) to verify Green Check."
                        )
                    }
                }
            }
        }
    }

    private var statusHeaderCard: some SwiftUI.View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(vm.isPairingOK ? SwiftUI.Color.green.opacity(0.15) : SwiftUI.Color.red.opacity(0.15))
                    .frame(width: 46, height: 46)
                SwiftUI.Image(systemName: vm.isPairingOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(vm.isPairingOK ? .green : .red)
            }
            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(
                    vm.isPairingOK
                    ? vm.tr("Pairing Chính Xác 100% (Tích Xanh OK)", "Pairing 100% Verified (Green Check OK)")
                    : vm.tr("Chưa Xác Minh (Tích Đỏ)", "Unverified (Red X)")
                )
                .font(.headline)
                SwiftUI.Text(vm.pairingProtocol)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(SkyTheme.cardBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SkyTheme.border, lineWidth: 1)
        )
    }

    private var verificationAdviceCard: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SwiftUI.Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(SkyTheme.primary)
                SwiftUI.Text(vm.tr(
                    "2 Bước Kiểm Tra Pairing Chính Xác 100%:",
                    "2 Steps to Verify Pairing 100% Accurately:"
                ))
                .font(.subheadline.bold())
                .foregroundColor(.primary)
            }

            VStack(alignment: .leading, spacing: 8) {
                GuideStepRow(
                    num: "1",
                    title: vm.tr("Bật LocalDevVPN", "Turn ON LocalDevVPN"),
                    text: LocalizedStringKey(vm.tr(
                        "Mở ứng dụng **LocalDevVPN** và bật kết nối VPN.",
                        "Open **LocalDevVPN** and turn ON the VPN connection."
                    ))
                )

                GuideStepRow(
                    num: "2",
                    title: vm.tr("Tắt cả Wi-Fi và 4G", "Turn OFF both Wi-Fi and 4G"),
                    text: LocalizedStringKey(vm.tr(
                        "Tắt **Wi-Fi** và **Dữ liệu di động (4G/5G)** để ứng dụng kết nối thẳng vào thiết bị đã ghép nối qua **LocalDevVPN**.",
                        "Turn OFF **Wi-Fi** and **Cellular Data (4G/5G)** so the app connects directly to the paired device via **LocalDevVPN**."
                    ))
                )
            }

            Divider()

            SwiftUI.Text(LocalizedStringKey(vm.tr(
                "✅ **Tích xanh:** Chắc chắn Pairing OK.\n❌ **Tích đỏ:** Chắc chắn Pairing lỗi hoặc hết hạn.",
                "✅ **Green Check:** Pairing is 100% OK.\n❌ **Red X:** Pairing is definitely invalid or expired."
            )))
            .font(.caption)
            .foregroundColor(.primary)
        }
        .padding(14)
        .background(SkyTheme.cardHeaderBackground)
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SkyTheme.border, lineWidth: 1)
        )
    }

    private var ios27DirectPairingCard: some SwiftUI.View {
        SkySectionCard(
            title: vm.tr("Phần 1: Dành Cho iOS 27", "Part 1: For iOS 27"),
            icon: "iphone.radiowaves.left.and.right",
            color: SkyTheme.primary
        ) {
            SwiftUI.Text(vm.tr("Ghép nối trực tiếp trên iPhone", "Direct On-Device Pairing on iPhone"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(SkyTheme.darkAccent)

            VStack(alignment: .leading, spacing: 12) {
                GuideStepRow(
                    num: "1",
                    title: vm.tr("Bắt đầu phát tín hiệu Pairing", "Start Pairing Broadcast"),
                    text: LocalizedStringKey(vm.tr(
                        "Tắt tạm LocalDevVPN (nếu đang bật), giữ kết nối Wi-Fi, sau đó nhấn vào nút **“Cài Pairing lên iPhone”** bên dưới để ứng dụng phát tín hiệu ghép đôi.",
                        "Temporarily turn OFF LocalDevVPN (if active), keep Wi-Fi ON, then tap **“Install Pairing on iPhone”** below to start broadcasting."
                    ))
                )

                GuideStepRow(
                    num: "2",
                    title: vm.tr("Mở Cài đặt Nhà phát triển", "Open Developer Mode Settings"),
                    text: LocalizedStringKey(vm.tr(
                        "Thoát ra màn hình chính (không vuốt tắt ứng dụng này), mở **Cài đặt (Settings)** ➔ **Quyền riêng tư & Bảo mật (Privacy & Security)** ➔ kéo xuống cuối chọn **Chế độ nhà phát triển (Developer Mode)**.",
                        "Go to the Home Screen (do not close this app), open **Settings** ➔ **Privacy & Security** ➔ scroll down and select **Developer Mode**."
                    ))
                )

                GuideStepRow(
                    num: "3",
                    title: vm.tr("Nhập mã PIN 6 chữ số (Tự động kích hoạt)", "Enter 6-Digit PIN (Auto-Activated)"),
                    text: LocalizedStringKey(vm.tr(
                        "Trong mục Chế độ nhà phát triển, nếu có “Thiết bị đã ghép đôi” cũ thì xoá đi, sau đó nhấn vào dòng **Pair with SideStore** và nhập mật khẩu iPhone. Quay lại app này xem **mã 6 chữ số**, rồi sang **Cài đặt** nhập vào và nhấn **Ghép đôi**. Ngay sau khi ghép đôi xong, ứng dụng sẽ **tự động nạp và kích hoạt Pairing luôn**!",
                        "In Developer Mode, remove any old paired devices, tap **Pair with SideStore**, and enter your iPhone passcode. Check the **6-digit PIN** in this app, enter it in **Settings**, and tap **Pair**. Once paired, the app **automatically loads and activates your Pairing file**!"
                    ))
                )

                GuideStepRow(
                    num: "4",
                    title: vm.tr("Lưu tệp Pairing dự phòng (Khuyên dùng)", "Save Backup Pairing File (Recommended)"),
                    text: LocalizedStringKey(vm.tr(
                        "Sau khi ghép nối xong, bạn **không cần nhập lại tệp nữa**. Tuy nhiên, hãy nhấn nút **“Xuất tệp Pairing (Lưu dự phòng)”** (màu xanh lá) ➔ chọn **Lưu vào Tệp (Save to Files)** để cất giữ dự phòng cho những lần cài lại app sau này.",
                        "After pairing, you **do not need to re-import the file**. However, tap **“Export Pairing File (Backup)”** (green button) ➔ **Save to Files** to keep a backup copy for future reinstalls."
                    ))
                )
            }

            Divider().padding(.vertical, 2)

            VStack(spacing: 10) {
                if let pin = wirelessVM.pinCode {
                    VStack(spacing: 6) {
                        SwiftUI.Text(vm.tr("MÃ GHÉP NỐI 6 CHỮ SỐ", "6-DIGIT PAIRING PIN"))
                            .font(.caption2.bold())
                            .foregroundColor(SkyTheme.primary)
                        SwiftUI.Text(pin)
                            .font(.system(size: 30, weight: .heavy, design: .monospaced))
                            .tracking(6)
                            .foregroundColor(.primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 18)
                            .background(RoundedRectangle(cornerRadius: 10).fill(SkyTheme.primary.opacity(0.12)))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                }

                if let errorMsg = wirelessVM.errorMessage {
                    SwiftUI.Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SwiftUI.Button {
                    didPressInstallPairing = true
                    if !wirelessVM.isAdvertising {
                        vm.setWirelessPairingActive(true)
                    }
                    wirelessVM.togglePairing()
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: wirelessVM.isAdvertising ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text(wirelessVM.isAdvertising
                                     ? vm.tr("Dừng Cài Pairing (Đang phát sóng...)", "Stop Pairing (Broadcasting...)")
                                     : vm.tr("Cài Pairing lên iPhone", "Install Pairing on iPhone"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(wirelessVM.isAdvertising ? SwiftUI.Color.red : SkyTheme.primary)
                    .cornerRadius(13)
                }

                if didPressInstallPairing || installedPairingURLForExport != nil {
                    SwiftUI.Button {
                        if let pairedURL = installedPairingURLForExport {
                            wirelessVM.pinCode = nil
                            exportFileURL = pairedURL
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isExportSheetPresented = true
                            }
                        } else {
                            statusBannerMessage = vm.tr(
                                "Vui lòng thực hiện Bước 2 & Bước 3 (nhập xong 6 chữ số trong Cài đặt ➔ Chế độ nhà phát triển) trước khi lưu tệp dự phòng.",
                                "Please complete Step 2 & Step 3 (enter the 6-digit PIN in Settings ➔ Developer Mode) before saving a backup file."
                            )
                        }
                    } label: {
                        HStack(spacing: 8) {
                            SwiftUI.Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 17, weight: .bold))
                            SwiftUI.Text(vm.tr("Xuất tệp Pairing (Lưu dự phòng)", "Export Pairing File (Backup)"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(installedPairingURLForExport != nil ? SwiftUI.Color.green : SwiftUI.Color.green.opacity(0.65))
                        .cornerRadius(13)
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                SwiftUI.Button {
                    pairingMgmtVM.promptImport(for: .rppairing)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text(vm.tr("Nhập tệp Pairing có sẵn", "Import Existing Pairing File"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(SkyTheme.darkAccent)
                    .cornerRadius(13)
                }

                SwiftUI.Button {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text(vm.tr("Xoá tệp Pairing", "Delete Pairing File"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(SwiftUI.Color.red)
                    .cornerRadius(13)
                }
            }
            .padding(12)
            .background(SkyTheme.innerRowBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(SkyTheme.innerBorder, lineWidth: 1)
            )
        }
    }

    private var pcPairingGuideCard: some SwiftUI.View {
        SkySectionCard(
            title: vm.tr("Phần 2: Dưới iOS 27 (PC / Mac)", "Part 2: Below iOS 27 (PC / Mac)"),
            icon: "laptopcomputer.and.iphone",
            color: SkyTheme.primary
        ) {
            SwiftUI.Text(vm.tr("Tạo / Cài tệp Pairing qua Máy tính (Windows / Mac)", "Generate / Install Pairing via Computer (Windows / Mac)"))
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(SkyTheme.darkAccent)

            HStack(alignment: .top, spacing: 8) {
                SwiftUI.Image(systemName: "info.circle.fill")
                    .foregroundColor(SkyTheme.primary)
                    .font(.subheadline)
                SwiftUI.Text(LocalizedStringKey(vm.tr(
                    "**Chuẩn bị chung:** Trên Windows cần cài đặt **iTunes** & **iCloud** bản chính chủ từ Apple (không tải bản Microsoft Store). Cắm cáp kết nối iPhone vào máy tính, mở khóa màn hình iPhone và nhấn **Tin cậy (Trust)** + nhập mật khẩu màn hình. Hãy chọn **1 trong 3 công cụ** dưới đây:",
                    "**General Preparation:** On Windows, install official Apple **iTunes** & **iCloud** (non-Microsoft Store version). Connect iPhone via USB cable, unlock the screen, tap **Trust**, and enter your passcode. Choose **1 of the 3 tools** below:"
                )))
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(10)
            .background(SkyTheme.primary.opacity(0.1))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 12) {
                GuideStepRow(
                    num: "1",
                    title: vm.tr(
                        "Cách 1: Dùng idevice_pair (Khuyên dùng - Hỗ trợ cả nạp thẳng & xuất tệp)",
                        "Method 1: Using idevice_pair (Recommended - Direct Load & File Export)"
                    ),
                    text: LocalizedStringKey(vm.tr(
                        "• Mở phần mềm **idevice_pair** trên máy tính và chọn iPhone của bạn.\n• **Cách nạp thẳng vào ứng dụng:** Trong mục ứng dụng trên **idevice_pair**, chọn **SideStore** hoặc **LiveContainer** rồi nhấn nút **Load** (hoặc **Install Pairing File**). Phần mềm sẽ tự động chép thẳng tệp Pairing vào trong ứng dụng trên iPhone mà không cần làm thủ công.\n• **Cách xuất ra tệp `.mobiledevicepairing` dự phòng:** Nhấn nút **Generate** rồi chọn **Export / Save** để lưu tệp có đuôi **`.mobiledevicepairing`** ra máy tính. Gửi tệp này sang iPhone (qua Zalo, AirDrop, iCloud Drive), chọn **Lưu vào Tệp** rồi nhấn nút **“Nhập tệp Pairing”** ở dưới.",
                        "• Open **idevice_pair** on your computer and select your iPhone.\n• **Direct App Injection:** Under the app list in **idevice_pair**, select **SideStore** or **LiveContainer** and click **Load** (or **Install Pairing File**). It will automatically install the Pairing file into the app.\n• **Export `.mobiledevicepairing` Backup:** Click **Generate** then **Export / Save** to save the **`.mobiledevicepairing`** file. Send it to your iPhone, choose **Save to Files**, and tap **“Import Pairing File”** below."
                    ))
                )

                GuideStepRow(
                    num: "2",
                    title: vm.tr(
                        "Cách 2: Dùng jitterbugpair (Công cụ xuất tệp `.mobiledevicepairing` ra máy tính)",
                        "Method 2: Using jitterbugpair (CLI Tool to Export `.mobiledevicepairing`)"
                    ),
                    text: LocalizedStringKey(vm.tr(
                        "• Tải và giải nén **jitterbugpair** (trên Windows/macOS/Linux).\n• Giữ màn hình iPhone luôn sáng và mở khóa, sau đó chạy file **`jitterbugpair.exe`** (trên Windows) hoặc chạy **`./jitterbugpair`** trong Terminal (trên Mac).\n• Công cụ sẽ tự động xuất ra một tệp có tên dạng **`<UDID>.mobiledevicepairing`** nằm ngay trong cùng thư mục chứa **jitterbugpair** (công cụ này chỉ xuất ra tệp chứ không tự chép vào app).\n• Gửi tệp **`.mobiledevicepairing`** đó sang iPhone ➔ chọn **Lưu vào Tệp (Save to Files)** ➔ nhấn nút **“Nhập tệp Pairing”** bên dưới để nạp vào ứng dụng.",
                        "• Download and extract **jitterbugpair** (Windows/macOS/Linux).\n• Keep your iPhone unlocked, then run **`jitterbugpair.exe`** (Windows) or **`./jitterbugpair`** in Terminal (Mac).\n• It will generate a **`<UDID>.mobiledevicepairing`** file in the same folder.\n• Transfer that **`.mobiledevicepairing`** file to your iPhone ➔ **Save to Files** ➔ tap **“Import Pairing File”** below."
                    ))
                )

                GuideStepRow(
                    num: "3",
                    title: vm.tr(
                        "Cách 3: Dùng iLoader (Cài đặt tự động vào ứng dụng trên iPhone)",
                        "Method 3: Using iLoader (Automatic Injection into iPhone App)"
                    ),
                    text: LocalizedStringKey(vm.tr(
                        "• Mở phần mềm **iLoader** trên máy tính, đăng nhập hoặc kết nối với iPhone đã nhấn Tin cậy.\n• **iLoader** chủ yếu hỗ trợ tính năng **Tự động tạo và nạp trực tiếp (Inject) Pairing File** vào **SideStore / LiveContainer** thông qua tùy chọn **Generate / Place Pairing File** ngay trong giao diện quản lý thiết bị.\n• Sau khi iLoader báo hoàn tất trên máy tính, hãy mở lại ứng dụng này trên iPhone để hệ thống tự nhận diện.",
                        "• Open **iLoader** on your computer and connect your trusted iPhone.\n• **iLoader** supports **Automatic Generation and Direct Injection** of the Pairing File into **SideStore / LiveContainer** via the **Generate / Place Pairing File** option.\n• Once iLoader finishes on your computer, reopen this app on your iPhone."
                    ))
                )
            }

            VStack(spacing: 10) {
                SwiftUI.Button {
                    pairingMgmtVM.promptImport(for: .rppairing)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "folder.fill.badge.plus")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text(vm.tr("Nhập tệp Pairing (Từ ứng dụng Tệp)", "Import Pairing File (From Files App)"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(SkyTheme.primary)
                    .cornerRadius(13)
                }

                SwiftUI.Button {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text(vm.tr("Xoá tệp Pairing", "Delete Pairing File"))
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(SwiftUI.Color.red)
                    .cornerRadius(13)
                }
            }
            .padding(.top, 4)
        }
    }
}

struct GuideStepRow: SwiftUI.View {
    let num: String
    var title: String? = nil
    let text: LocalizedStringKey

    var body: some SwiftUI.View {
        HStack(alignment: .top, spacing: 10) {
            SwiftUI.Text(num)
                .font(.caption.bold())
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(SkyTheme.primary))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                if let title = title {
                    SwiftUI.Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
                SwiftUI.Text(text)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct VpnDetailSheetView: SwiftUI.View {
    @ObservedObject var vm: SystemCheckViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.isVpnOK ? SwiftUI.Color.green.opacity(0.15) : SwiftUI.Color.red.opacity(0.15))
                                .frame(width: 46, height: 46)
                            SwiftUI.Image(systemName: vm.isVpnOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(vm.isVpnOK ? .green : .red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            SwiftUI.Text(vm.isVpnOK
                                         ? vm.tr("LocalDevVPN Đang Ổn Định", "LocalDevVPN is Stable")
                                         : vm.tr("LocalDevVPN Chưa Kết Nối", "LocalDevVPN is Disconnected"))
                                .font(.headline)
                            SwiftUI.Text(vm.tr(
                                "Hãy bật công tắc VPN trong ứng dụng LocalDevVPN.",
                                "Please turn on the VPN switch inside the LocalDevVPN app."
                            ))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(SkyTheme.cardBackground)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(SkyTheme.border, lineWidth: 1)
                    )

                    SkySectionCard(
                        title: vm.tr("Thông Số Kết Nối Hiện Tại", "Current Connection Details"),
                        icon: "network",
                        color: SkyTheme.primary
                    ) {
                        HStack {
                            SwiftUI.Text("Tunnel IP")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                            SwiftUI.Text(vm.tunnelIP)
                                .font(.system(.subheadline, design: .monospaced).bold())
                        }
                        Divider()
                        HStack {
                            SwiftUI.Text("Device IP")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                            SwiftUI.Text(vm.deviceIP)
                                .font(.system(.subheadline, design: .monospaced).bold())
                        }
                    }

                    SkySectionCard(
                        title: vm.tr("Cấu hình khuyên dùng iOS 27", "Recommended Config iOS 27"),
                        icon: "lightbulb.fill",
                        color: SkyTheme.primary
                    ) {
                        SwiftUI.Text(vm.tr(
                            "Nếu dùng iOS 27 và bản LiveContainer+SideStore này, hãy đặt IP trong LocalDevVPN theo thông số sau để kết nối nhanh nhất:",
                            "If using iOS 27 with this LiveContainer+SideStore build, set the IP addresses in LocalDevVPN as follows for the fastest connection:"
                        ))
                        .font(.footnote)
                        .foregroundColor(.secondary)

                        CopyableIPCard(
                            label: "Tunnel IP",
                            value: "10.7.1.1/32",
                            copyText: vm.tr("Sao chép", "Copy"),
                            copiedText: vm.tr("Đã chép", "Copied")
                        )
                        CopyableIPCard(
                            label: "Device IP",
                            value: "10.7.0.1/32",
                            copyText: vm.tr("Sao chép", "Copy"),
                            copiedText: vm.tr("Đã chép", "Copied")
                        )
                    }
                }
                .padding(16)
            }
            .background(SkyTheme.pageBackground.ignoresSafeArea())
            .navigationTitle("LocalDevVPN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button(vm.tr("Xong", "Done")) { dismiss() }
                        .font(.headline)
                        .foregroundColor(SkyTheme.primary)
                }
            }
        }
    }
}

struct CopyableIPCard: SwiftUI.View {
    let label: String
    let value: String
    let copyText: String
    let copiedText: String
    @State private var copied = false

    var body: some SwiftUI.View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                SwiftUI.Text(value)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundColor(.primary)
            }
            Spacer()
            SwiftUI.Button(action: {
                UIPasteboard.general.string = value
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    copied = false
                }
            }) {
                SwiftUI.Label(copied ? copiedText : copyText, systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(copied ? SwiftUI.Color.green.opacity(0.2) : SkyTheme.primary.opacity(0.15))
                    .foregroundColor(copied ? .green : SkyTheme.primary)
                    .cornerRadius(10)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(12)
        .background(SkyTheme.innerRowBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SkyTheme.innerBorder, lineWidth: 1)
        )
    }
}

struct CellularDetailSheetView: SwiftUI.View {
    @ObservedObject var vm: SystemCheckViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.isCellularOK ? SwiftUI.Color.green.opacity(0.15) : SwiftUI.Color.red.opacity(0.15))
                                .frame(width: 46, height: 46)
                            SwiftUI.Image(systemName: vm.isCellularOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(vm.isCellularOK ? .green : .red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            SwiftUI.Text(vm.isCellularOK
                                         ? vm.tr("Mạng 4G / Di Động Ổn Định", "4G / Cellular Data is Stable")
                                         : vm.tr("Mạng 4G / Di Động Đang Tắt", "4G / Cellular Data is Off"))
                                .font(.headline)
                            SwiftUI.Text(vm.cellularDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(SkyTheme.cardBackground)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(SkyTheme.border, lineWidth: 1)
                    )

                    SkySectionCard(
                        title: vm.tr("Cài & Gia hạn App qua 4G + VPN", "Install & Refresh Apps via 4G + VPN"),
                        icon: "antenna.radiowaves.left.and.right.circle.fill",
                        color: SkyTheme.primary
                    ) {
                        SwiftUI.Text(LocalizedStringKey(vm.tr(
                            "• **Không cần Wi-Fi:** Cài đặt IPA và làm mới ứng dụng trực tiếp qua **4G/5G + LocalDevVPN**.\n\n• **Tự động hóa:** Kết hợp phím tắt làm mới lúc 6:00 hoặc 15:00 để tự động gia hạn ứng dụng mỗi ngày.",
                            "• **No Wi-Fi Needed:** Install IPAs and refresh apps directly over **4G/5G + LocalDevVPN**.\n\n• **Automation:** Combine with the 6:00 AM or 3:00 PM shortcuts to automatically refresh apps daily."
                        )))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                }
                .padding(16)
            }
            .background(SkyTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(vm.tr("Mạng 4G / Di Động", "4G / Cellular Data"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button(vm.tr("Xong", "Done")) { dismiss() }
                        .font(.headline)
                        .foregroundColor(SkyTheme.primary)
                }
            }
        }
    }
}

@MainActor
final class AnisetteQuickListViewModel: ObservableObject {
    @Published var servers: [AnisetteServerItem] = []
    @Published var isLoading: Bool = false

    func loadCachedAndSync(customPrefix: String) async {
        let local = await AnisetteServersManager.shared.loadLocalServers().filter { !$0.isHidden }
        if !local.isEmpty {
            self.servers = mergeWithCurrent(local, customPrefix: customPrefix)
        }
        await refreshFromRemote(customPrefix: customPrefix)
    }

    func refreshFromRemote(customPrefix: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        if let synced = try? await AnisetteServersManager.shared.syncWithRemote() {
            let visible = synced.filter { !$0.isHidden }
            self.servers = mergeWithCurrent(visible, customPrefix: customPrefix)
        } else {
            let local = await AnisetteServersManager.shared.loadLocalServers().filter { !$0.isHidden }
            self.servers = mergeWithCurrent(local, customPrefix: customPrefix)
        }
    }

    func reloadCurrentSelection(customPrefix: String) async {
        let local = await AnisetteServersManager.shared.loadLocalServers().filter { !$0.isHidden }
        self.servers = mergeWithCurrent(local, customPrefix: customPrefix)
    }

    private func mergeWithCurrent(_ items: [AnisetteServerItem], customPrefix: String) -> [AnisetteServerItem] {
        var result = items
        if result.isEmpty {
            result = [
                AnisetteServerItem(
                    name: "SideStore Official",
                    address: AppConstants.Anisette.Servers.defaultServerURL,
                    isHidden: false
                )
            ]
        }
        let current = AnisetteDefaultsHelper.currentServerURL.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !current.isEmpty,
           !result.contains(where: { $0.address.caseInsensitiveCompare(current) == .orderedSame }) {
            let host = URL(string: current)?.host ?? current
            result.insert(AnisetteServerItem(name: "\(customPrefix) (\(host))", address: current, isHidden: false), at: 0)
        }
        return result
    }
}

struct AnisetteDetailSheetView: SwiftUI.View {
    @ObservedObject var vm: SystemCheckViewModel
    @StateObject private var listVM = AnisetteQuickListViewModel()
    @State private var customServerInput: String = ""
    @Environment(\.dismiss) private var dismiss

    private var customServerPrefix: String {
        vm.tr("Máy chủ tùy chỉnh", "Custom Server")
    }

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.isAnisetteOK ? SwiftUI.Color.green.opacity(0.15) : SwiftUI.Color.red.opacity(0.15))
                                .frame(width: 46, height: 46)
                            SwiftUI.Image(systemName: vm.isAnisetteOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(vm.isAnisetteOK ? .green : .red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            SwiftUI.Text(vm.isAnisetteOK
                                         ? vm.tr("Máy Chủ Anisette Ổn Định", "Anisette Server is Stable")
                                         : vm.tr("Đang Bật On-Device Anisette", "On-Device Anisette is Enabled"))
                                .font(.headline)
                            SwiftUI.Text(vm.anisetteDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(SkyTheme.cardBackground)
                    .cornerRadius(18)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(SkyTheme.border, lineWidth: 1)
                    )

                    SkySectionCard(
                        title: vm.tr("Chế độ xác thực Anisette", "Anisette Authentication Mode"),
                        icon: "switch.2",
                        color: SkyTheme.primary
                    ) {
                        Toggle(isOn: Binding(
                            get: { vm.useOnDeviceAnisette },
                            set: { vm.setUseOnDeviceAnisette($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                SwiftUI.Text("Use On-Device Anisette")
                                    .font(.subheadline.bold())
                                SwiftUI.Text(vm.useOnDeviceAnisette
                                             ? vm.tr("Đang BẬT (Khuyên tắt để ổn định hơn)", "ENABLED (Recommended to turn OFF for stability)")
                                             : vm.tr("(Nên Tắt Để Dễ Đăng Nhập)", "(Keep OFF for Easy Login)"))
                                    .font(.caption)
                                    .foregroundColor(vm.useOnDeviceAnisette ? .red : .green)
                            }
                        }
                        .tint(SkyTheme.primary)
                        .padding(12)
                        .background(SkyTheme.innerRowBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(SkyTheme.innerBorder, lineWidth: 1)
                        )

                        if vm.useOnDeviceAnisette {
                            SwiftUI.Button {
                                vm.setUseOnDeviceAnisette(false)
                            } label: {
                                HStack(spacing: 8) {
                                    SwiftUI.Image(systemName: "checkmark.shield.fill")
                                    SwiftUI.Text(vm.tr("Tắt ngay Use On-Device Anisette", "Turn Off Use On-Device Anisette Now"))
                                        .font(.subheadline.bold())
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(SkyTheme.primary)
                                .cornerRadius(12)
                            }
                        }
                    }

                    SkySectionCard(
                        title: vm.tr("Chọn Máy chủ Anisette", "Select Anisette Server"),
                        icon: "server.rack",
                        color: SkyTheme.primary,
                        trailingView: listVM.isLoading ? AnyView(ProgressView().tint(SkyTheme.primary)) : nil
                    ) {
                        VStack(spacing: 8) {
                            ForEach(listVM.servers) { server in
                                let isSelected = (vm.selectedAnisetteServerURL.caseInsensitiveCompare(server.address) == .orderedSame)
                                SwiftUI.Button {
                                    vm.selectAnisetteServerURL(server.address, isCustom: false)
                                    Task { await listVM.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                } label: {
                                    HStack(spacing: 12) {
                                        SwiftUI.Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(isSelected ? SkyTheme.primary : .secondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            SwiftUI.Text(server.name)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.primary)
                                            SwiftUI.Text(server.address)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if isSelected {
                                            SwiftUI.Text(vm.tr("Đang dùng", "In Use"))
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(SkyTheme.primary.opacity(0.15))
                                                .foregroundColor(SkyTheme.primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(12)
                                    .background(SkyTheme.innerRowBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? SkyTheme.primary.opacity(0.45) : SkyTheme.innerBorder, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }

                        Divider().padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            SwiftUI.Text(vm.tr("Hoặc nhập URL máy chủ tùy chỉnh:", "Or enter custom server URL:"))
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                TextField(AppConstants.Anisette.Servers.defaultServerURL, text: $customServerInput)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(10)
                                    .background(SkyTheme.innerRowBackground)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(SkyTheme.innerBorder, lineWidth: 1)
                                    )

                                SwiftUI.Button {
                                    let trimmed = customServerInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    vm.selectAnisetteServerURL(trimmed, isCustom: true)
                                    Task { await listVM.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                    customServerInput = ""
                                } label: {
                                    SwiftUI.Text(vm.tr("Lưu", "Save"))
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(SkyTheme.primary)
                                        .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(SkyTheme.pageBackground.ignoresSafeArea())
            .navigationTitle(vm.tr("Máy Chủ Anisette", "Anisette Server"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button(vm.tr("Xong", "Done")) { dismiss() }
                        .font(.headline)
                        .foregroundColor(SkyTheme.primary)
                }
            }
            .task {
                vm.updateInstantStatus()
                await listVM.loadCachedAndSync(customPrefix: customServerPrefix)
            }
        }
    }
}
