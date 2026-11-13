
//
//  NewsViewController.swift
//  AltStore
//

@preconcurrency import UIKit
import SwiftUI
import WebKit
import Network
import UniformTypeIdentifiers
@preconcurrency import Minimuxer
import MinimuxerCommon
import Combine
import Darwin
import ImageIO

enum CheckItemVisualState: Equatable {
    case actionRequired // Màu Tím (Purple): Trung tính, mời nhấn vào kiểm tra (Không Xanh, Không Đỏ)
    case verifiedOK     // Màu Xanh Lá (Green): Hoạt động tốt
    case failedError    // Màu Đỏ (Red): Lỗi thật sự hoặc chưa có tệp
}

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TAB CÀI ĐẶT)
private enum CSSTheme {
    // UIKit Colors (Dùng cho ViewController & Lớp nền Gradient cố định)
    static let uiWhite = UIColor.white
    static let uiBorder = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0) // #e9ecef
    static let uiBlue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)     // #007bff
    static let bgGradientStartCG = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEndCG = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // SwiftUI Colors
    static let primary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)      // #007bff (--primary-blue)
    static let secondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)   // #6f42c1 (--primary-purple)
    static let darkAccent = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)  // #6f42c1
    static let green = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)        // #28a745 (--primary-green)
    static let red = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)          // #dc3545 (--primary-red)
    static let magenta = SwiftUI.Color(red: 255/255, green: 0/255, blue: 255/255)      // #ff00ff
    static let darkText = SwiftUI.Color(red: 52/255, green: 58/255, blue: 64/255)      // #343a40 (--dark-text)

    /// Màu trung tính để nhắc "Nhấn vào đây để kiểm tra"
    static let neutralInspect = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)

    // Nền Gradient (#f3e0ff -> #e0f7ff) chéo từ góc trên trái xuống góc dưới phải giống hệt Settings
    static let bgGradientStart = SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255)
    static let bgGradientEnd = SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)

    static var pageBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Hero Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88)) giống hệt Settings
    static let heroStart = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.92)
    static let heroEnd = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.88)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [heroStart, heroEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let cornerRadius: CGFloat = 15.0
    static let pageBackground = SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255)
    static let cardBackground = SwiftUI.Color.white
    static let cardHeaderBackground = SwiftUI.Color(red: 248/255, green: 249/255, blue: 250/255).opacity(0.95)
    static let innerRowBackground = SwiftUI.Color(red: 248/255, green: 249/255, blue: 250/255) // #f8f9fa
    static let border = SwiftUI.Color(red: 233/255, green: 236/255, blue: 239/255)             // #e9ecef
    static let innerBorder = SwiftUI.Color(red: 233/255, green: 236/255, blue: 239/255)        // #e9ecef
    static let shadow = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.08)
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG KHI CUỘN)
private final class CSSGradientBackgroundView: UIView {
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
        gradientLayer.colors = [CSSTheme.bgGradientStartCG, CSSTheme.bgGradientEndCG]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - Hiệu ứng nhấn nút thu nhỏ & nảy lò xo (Đồng bộ với Settings)
private struct CSSBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - 🌟 HERO BANNER ĐẦU TRANG (BẮT CHƯỚC Y HỆT TAB CÀI ĐẶT)
private struct CSSHeroBannerView: SwiftUI.View {
    let title: String
    let subtitle: String
    @State private var isAppeared = false

    var body: some SwiftUI.View {
        VStack(spacing: 4) {
            SwiftUI.Text(title)
                .font(.system(size: 25, weight: .heavy))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.35), radius: 4, x: 1, y: 2)

            SwiftUI.Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .fill(CSSTheme.heroGradient)
        )
        .shadow(color: CSSTheme.primary.opacity(0.25), radius: 16, x: 0, y: 6)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : -10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05)) {
                isAppeared = true
            }
        }
    }
}

/// Bộ tải và giải mã ảnh trên Background Thread + Cache RAM giúp cuộn ScrollView mượt 120fps không bao giờ khựng
private final class GuideImageCacheManager: @unchecked Sendable {
    static let shared = GuideImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession

    private init() {
        cache.countLimit = 12
        cache.totalCostLimit = 30 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 80 * 1024 * 1024)
        session = URLSession(configuration: config)
    }

    func cachedImage(for urlString: String) -> UIImage? {
        cache.object(forKey: urlString as NSString)
    }

    func prefetchAllGuideImages() {
        let urls = [
            "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2589.jpeg",
            "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2588.jpeg"
        ]
        for urlString in urls where cachedImage(for: urlString) == nil {
            Task.detached(priority: .utility) {
                _ = await Self.shared.loadAndDecodeImage(urlString: urlString)
            }
        }
    }

    func loadAndDecodeImage(urlString: String, maxDimension: CGFloat = 1080) async -> UIImage? {
        if let existing = cachedImage(for: urlString) {
            return existing
        }
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await session.data(from: url)
            return await Task.detached(priority: .userInitiated) { () -> UIImage? in
                let options: [CFString: Any] = [
                    kCGImageSourceShouldCache: false
                ]
                guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
                    return UIImage(data: data)
                }
                let downsampleOptions: [CFString: Any] = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxDimension
                ]
                if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) {
                    let decoded = UIImage(cgImage: cgImage)
                    Self.shared.cache.setObject(decoded, forKey: urlString as NSString)
                    return decoded
                }
                if let fallback = UIImage(data: data)?.preparingForDisplay() {
                    Self.shared.cache.setObject(fallback, forKey: urlString as NSString)
                    return fallback
                }
                return nil
            }.value
        } catch {
            return nil
        }
    }
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
    private var floatingBackButton: UIButton?

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

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
        GuideImageCacheManager.shared.prefetchAllGuideImages()

        // 1. Ẩn hoàn toàn tiêu đề và thanh điều hướng giống hệt SettingsViewController
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = CSSTheme.uiBlue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif

        // 2. Đặt lớp nền Gradient cố định toàn màn hình (Không bao giờ bị trắng khi cuộn)
        let bgView = CSSGradientBackgroundView(frame: view.bounds)
        bgView.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(bgView, at: 0)
        NSLayoutConstraint.activate([
            bgView.topAnchor.constraint(equalTo: view.topAnchor),
            bgView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bgView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bgView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        self.view.backgroundColor = .clear
        self.collectionView.isHidden = true
        self.collectionView.isScrollEnabled = false
        self.collectionView.contentInsetAdjustmentBehavior = .never

        // 3. Nhúng giao diện SwiftUI tràn viền mượt mà
        let hostingController = UIHostingController(rootView: SystemCheckDashboardView())
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
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
}

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ CỐ ĐỊNH (ĐỒNG BỘ SETTINGS)
extension NewsViewController: UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        navigationController.setNavigationBarHidden(true, animated: false)
        viewController.title = nil
        viewController.navigationItem.title = nil
        #if !os(tvOS)
        viewController.navigationItem.largeTitleDisplayMode = .never
        #endif

        let isRoot = (viewController === navigationController.viewControllers.first)
        updateFloatingBackButton(in: navigationController, show: !isRoot)
    }

    private func updateFloatingBackButton(in nav: UINavigationController, show: Bool) {
        if self.floatingBackButton == nil {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false

            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
            btn.tintColor = CSSTheme.uiBlue
            btn.backgroundColor = CSSTheme.uiWhite.withAlphaComponent(0.92)

            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = CSSTheme.uiBorder.cgColor
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
        #if !os(tvOS)
        if gestureRecognizer === self.navigationController?.interactivePopGestureRecognizer {
            return (self.navigationController?.viewControllers.count ?? 0) > 1
        }
        #endif
        return true
    }
}

@MainActor
final class SystemCheckViewModel: ObservableObject {
    private static let verifiedPairingCacheKey = "com.sidestore.check.lastVerifiedPairingSuccess"

    @Published var isPairingOK: Bool = false
    @Published var isPairingVerifiedError: Bool = false
    @Published var pairingProtocol: String = ""
    @Published var hasAnyStoredPairingFile: Bool = false

    @Published var isVpnOK: Bool = false
    @Published var tunnelIP: String = ""
    @Published var deviceIP: String = ""

    @Published var isCellularOK: Bool = false
    @Published var isWifiActive: Bool = false
    @Published var cellularDetail: String = ""

    @Published var isAnisetteOK: Bool = !UserDefaults.standard.useOnDeviceAnisette
    @Published var useOnDeviceAnisette: Bool = UserDefaults.standard.useOnDeviceAnisette
    @Published var selectedAnisetteServerURL: String = AnisetteDefaultsHelper.currentServerURL
    @Published var anisetteDetail: String = ""

    @Published var isCellularRefreshEnabled: Bool = {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        return UserDefaults.standard.isCellularRefreshEnabled
    }()

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

    private var isViewVisible: Bool = false
    private var isChecking: Bool = false
    private var needsAnotherCheck: Bool = false
    private var pendingForceVerify: Bool = false
    private var isUpdatingDefaultsInternally: Bool = false

    private var lastVerifiedPairingSuccess: Bool = UserDefaults.standard.bool(forKey: verifiedPairingCacheKey) {
        didSet {
            if oldValue != lastVerifiedPairingSuccess {
                UserDefaults.standard.set(lastVerifiedPairingSuccess, forKey: Self.verifiedPairingCacheKey)
            }
        }
    }

    private var lastVerifiedModeSignature: String = ""
    private var didAttemptLiveVerifyInCurrentMode: Bool = false

    private let networkChangeSubject = PassthroughSubject<Bool, Never>()

    var canAutoVerifyPairingInCurrentNetwork: Bool {
        guard isVpnOK else { return false }
        if isWifiActive {
            return true
        }
        return !isCellularOK
    }

    var pairingVisualState: CheckItemVisualState {
        if !hasAnyStoredPairingFile {
            return .failedError
        }
        guard canAutoVerifyPairingInCurrentNetwork else {
            return .actionRequired
        }
        if isPairingOK {
            return .verifiedOK
        }
        if isPairingVerifiedError {
            return .failedError
        }
        return .actionRequired
    }

    func setWirelessPairingActive(_ active: Bool) {
        guard isWirelessPairingActive != active else { return }
        isWirelessPairingActive = active
        if active {
            PairingBackgroundKeepAliveManager.shared.beginKeepAlive()
        } else {
            PairingBackgroundKeepAliveManager.shared.endKeepAlive()
            if isViewVisible {
                Task { await checkAllStatuses(forceVerify: true) }
            }
        }
    }

    func markPairingVerifiedImmediately() {
        self.hasAnyStoredPairingFile = true
        self.didAttemptLiveVerifyInCurrentMode = false
        self.lastVerifiedModeSignature = ""
        self.isPairingVerifiedError = false
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
    }

    func setViewVisible(_ visible: Bool) {
        guard isViewVisible != visible else { return }
        isViewVisible = visible
        if visible {
            updateInstantStatus()
            if !isWirelessPairingActive {
                Task { await checkAllStatuses(forceVerify: false) }
            }
        }
    }

    private func setupRealtimeListeners() {
        networkChangeSubject
            .debounce(for: .milliseconds(550), scheduler: DispatchQueue.main)
            .sink { [weak self] forceVerify in
                guard let self = self,
                      self.isViewVisible,
                      !self.isWirelessPairingActive,
                      !self.isUpdatingDefaultsInternally else { return }
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
                var changed = false
                if self.usesCellularPath != usesCell {
                    self.usesCellularPath = usesCell
                    changed = true
                }
                if self.usesWifiPath != usesWifi {
                    self.usesWifiPath = usesWifi
                    changed = true
                }
                guard changed, self.isViewVisible, !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(false)
            }
        }
        pathMonitor.start(queue: monitorQueue)

        cellularMonitor.pathUpdateHandler = { [weak self] path in
            let cellSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.isCellularPathSatisfied != cellSatisfied else { return }
                self.isCellularPathSatisfied = cellSatisfied
                guard self.isViewVisible, !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(false)
            }
        }
        cellularMonitor.start(queue: monitorQueue)

        wifiMonitor.pathUpdateHandler = { [weak self] path in
            let wifiSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard self.isWifiPathSatisfied != wifiSatisfied else { return }
                self.isWifiPathSatisfied = wifiSatisfied
                guard self.isViewVisible, !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(false)
            }
        }
        wifiMonitor.start(queue: monitorQueue)

        minimuxer.network.pathPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      self.isViewVisible,
                      !self.isWirelessPairingActive,
                      !self.isUpdatingDefaultsInternally else { return }
                self.networkChangeSubject.send(false)
            }
            .store(in: &cancellables)

        minimuxerStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      self.isViewVisible,
                      !self.isWirelessPairingActive,
                      !self.isUpdatingDefaultsInternally else { return }
                self.networkChangeSubject.send(false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isViewVisible else { return }
                self.updateInstantStatus()
                guard !self.isWirelessPairingActive else { return }
                Task { @MainActor [weak self] in
                    _ = try? await AnisetteServersManager.shared.syncWithRemote()
                    await self?.checkAllStatuses(forceVerify: false)
                }
            }
            .store(in: &cancellables)
    }

    struct SystemInterfaceSnapshot: Sendable {
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
        self.lastVerifiedModeSignature = ""
        self.didAttemptLiveVerifyInCurrentMode = false
        self.isPairingVerifiedError = true
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

    func updateInstantStatus(existingSnapshot: SystemInterfaceSnapshot? = nil) {
        let snapshot = existingSnapshot ?? Self.scanSystemInterfaces()
        ensureTunnelRoutingPinned(snapshot: snapshot)

        let cellularActive = usesCellularPath || isCellularPathSatisfied || snapshot.hasCellularIPv4
        let wifiActive = usesWifiPath || isWifiPathSatisfied || snapshot.hasWifiIPv4
        assignIfChanged(\.isCellularOK, cellularActive)
        assignIfChanged(\.isWifiActive, wifiActive)

        let newCellularDetail: String
        if usesCellularPath {
            newCellularDetail = "Ổn định • Đang dùng trực tiếp 4G / 5G"
        } else if cellularActive {
            newCellularDetail = "Ổn định • 4G / 5G đang bật sẵn sàng"
        } else {
            newCellularDetail = "Chưa bật • Hãy bật Dữ liệu di động (4G/5G)"
        }
        assignIfChanged(\.cellularDetail, newCellularDetail)

        let disconnectedText = "Chưa kết nối"
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

        let vpnConnected = snapshot.hasActiveLocalDevUtun
            || ((resolvedTunnelText != disconnectedText) && (resolvedDeviceText != disconnectedText))
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
                    ? "Đã nạp Pairing File"
                    : "Chưa có tệp Pairing"
            }
        }()

        let canVerifyNow = vpnConnected && (wifiActive || !cellularActive)

        if !hasAnyFile {
            self.lastVerifiedPairingSuccess = false
            self.lastVerifiedModeSignature = ""
            self.didAttemptLiveVerifyInCurrentMode = false
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, true)
            assignIfChanged(\.pairingProtocol, "Chưa có tệp Pairing")
        } else if !canVerifyNow {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, false)
            assignIfChanged(\.pairingProtocol, "")
        } else if self.didAttemptLiveVerifyInCurrentMode {
            if self.lastVerifiedPairingSuccess {
                assignIfChanged(\.isPairingOK, true)
                assignIfChanged(\.isPairingVerifiedError, false)
                assignIfChanged(\.pairingProtocol, protocolName)
            } else {
                assignIfChanged(\.isPairingOK, false)
                assignIfChanged(\.isPairingVerifiedError, true)
                assignIfChanged(\.pairingProtocol, "Pairing bị lỗi hoặc hết hạn • Hãy cài lại Pairing mới")
            }
        } else if self.lastVerifiedPairingSuccess {
            assignIfChanged(\.isPairingOK, true)
            assignIfChanged(\.isPairingVerifiedError, false)
            assignIfChanged(\.pairingProtocol, protocolName)
        } else {
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, false)
            assignIfChanged(\.pairingProtocol, "")
        }

        let onDevice = UserDefaults.standard.useOnDeviceAnisette
        assignIfChanged(\.useOnDeviceAnisette, onDevice)
        assignIfChanged(\.isAnisetteOK, !onDevice)

        let selectedURL = AnisetteDefaultsHelper.currentServerURL
        assignIfChanged(\.selectedAnisetteServerURL, selectedURL)
        let serverHost = URL(string: selectedURL)?.host ?? selectedURL
        let newAnisetteDetail = onDevice
            ? "Không ổn định • Hãy tắt Use On-Device Anisette"
            : "Ổn định • Máy chủ: \(serverHost)"
        assignIfChanged(\.anisetteDetail, newAnisetteDetail)

        let currentCellularRefresh = UserDefaults.standard.isCellularRefreshEnabled
        assignIfChanged(\.isCellularRefreshEnabled, currentCellularRefresh)
    }

    private func verifyPairingOverTunnel(initialSnapshot: SystemInterfaceSnapshot) async -> Bool {
        ensureTunnelRoutingPinned(snapshot: initialSnapshot)

        let hasRp = PairingFileManager.shared.hasPairingFile(for: .rppairing)
        let hasLd = PairingFileManager.shared.hasPairingFile(for: .lockdown)

        var candidateProtocols: [PairingProtocol] = []
        if let persisted = PairingFileManager.shared.persistedActiveProtocol {
            if (persisted == .rppairing && hasRp) || (persisted == .lockdown && hasLd) {
                candidateProtocols.append(persisted)
            }
        }
        if hasRp && !candidateProtocols.contains(.rppairing) {
            candidateProtocols.append(.rppairing)
        }
        if hasLd && !candidateProtocols.contains(.lockdown) {
            candidateProtocols.append(.lockdown)
        }
        if candidateProtocols.isEmpty {
            candidateProtocols.append(.unknown)
        }

        for proto in candidateProtocols {
            if proto != .unknown {
                if !minimuxer.core.isPairingFileLoaded || minimuxer.core.pairingFileType != proto {
                    try? await minimuxerSwitchPairingProtocol(to: proto)
                }
            }

            for attempt in 0..<2 {
                if attempt > 0 {
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    let retrySnap = await Task.detached(priority: .utility) {
                        Self.scanSystemInterfaces()
                    }.value
                    ensureTunnelRoutingPinned(snapshot: retrySnap)
                }

                if let udid = try? await fetchUDID(forceLive: true), !udid.isEmpty {
                    return true
                }
            }
        }
        return false
    }

    func checkAllStatuses(forceVerify: Bool = false) async {
        guard !isWirelessPairingActive else { return }

        if isChecking {
            needsAnotherCheck = true
            if forceVerify { pendingForceVerify = true }
            return
        }

        isChecking = true
        defer {
            isChecking = false
            if needsAnotherCheck {
                let shouldForce = pendingForceVerify
                needsAnotherCheck = false
                pendingForceVerify = false
                Task { @MainActor [weak self] in
                    await self?.checkAllStatuses(forceVerify: shouldForce)
                }
            }
        }

        let snapshot = await Task.detached(priority: .userInitiated) {
            Self.scanSystemInterfaces()
        }.value

        updateInstantStatus(existingSnapshot: snapshot)

        guard hasAnyStoredPairingFile else {
            self.lastVerifiedPairingSuccess = false
            self.lastVerifiedModeSignature = ""
            self.didAttemptLiveVerifyInCurrentMode = false
            self.isPairingVerifiedError = true
            assignIfChanged(\.isPairingOK, false)
            updateInstantStatus(existingSnapshot: snapshot)
            return
        }

        let cellularActive = usesCellularPath || isCellularPathSatisfied || snapshot.hasCellularIPv4
        let wifiActive = usesWifiPath || isWifiPathSatisfied || snapshot.hasWifiIPv4
        let vpnActive = isVpnOK || snapshot.hasActiveLocalDevUtun

        let canVerifyNow = vpnActive && (wifiActive || !cellularActive)

        if canVerifyNow {
            let currentSignature = "\(tunnelIP)|wifi:\(wifiActive)|cell:\(cellularActive)"
            let signatureChanged = (lastVerifiedModeSignature != currentSignature)

            if forceVerify || !didAttemptLiveVerifyInCurrentMode || signatureChanged {
                let ok = await verifyPairingOverTunnel(initialSnapshot: snapshot)
                self.didAttemptLiveVerifyInCurrentMode = true
                self.lastVerifiedModeSignature = currentSignature
                if ok {
                    self.lastVerifiedPairingSuccess = true
                    assignIfChanged(\.isPairingOK, true)
                    assignIfChanged(\.isPairingVerifiedError, false)
                } else {
                    self.lastVerifiedPairingSuccess = false
                    assignIfChanged(\.isPairingOK, false)
                    assignIfChanged(\.isPairingVerifiedError, true)
                }
            }
        } else {
            self.didAttemptLiveVerifyInCurrentMode = false
            self.lastVerifiedModeSignature = ""
            assignIfChanged(\.isPairingOK, false)
            assignIfChanged(\.isPairingVerifiedError, false)
        }

        updateInstantStatus(existingSnapshot: snapshot)
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
            VStack(spacing: 18) {
                // Khối Hero Banner đồng bộ 100% với SettingsViewController
                CSSHeroBannerView(
                    title: "SideStore",
                    subtitle: "Kiểm tra kết nối hệ thống, Pairing & tự động làm mới qua 4G"
                )
                .padding(.top, 4)

                systemStatusSection
                serverSection
                shortcutsSection
                automationGuideSection
                shortcutVideoGuideSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 50)
        }
        .background(SwiftUI.Color.clear)
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

    private var systemStatusSection: some SwiftUI.View {
        let allReady = vm.isPairingOK && vm.isVpnOK && vm.isCellularOK && vm.isAnisetteOK

        let pairingSubtitleText: String = {
            switch vm.pairingVisualState {
            case .verifiedOK:
                return "Ổn định"
            case .failedError:
                return !vm.hasAnyStoredPairingFile
                    ? "Chưa có tệp Pairing"
                    : "Pairing lỗi • Nhấn vào để cài lại"
            case .actionRequired:
                return "Nhấn vào đây để kiểm tra"
            }
        }()

        return SkySectionCard(
            title: "TRẠNG THÁI HỆ THỐNG",
            icon: "cpu.fill",
            color: CSSTheme.primary,
            statusOK: allReady ? true : nil,
            footerText: "Chạm vào từng mục bên trên để kiểm tra chi tiết hoặc cài đặt lại kết nối hệ thống."
        ) {
            CheckItemButton(
                title: "LocalDevVPN",
                subtitle: vm.isVpnOK ? "Ổn định" : "Chưa kết nối",
                icon: "network.badge.shield.half.filled",
                visualState: vm.isVpnOK ? .verifiedOK : .failedError
            ) {
                showVpnSheet = true
            }

            CheckItemButton(
                title: "Pairing File",
                subtitle: pairingSubtitleText,
                icon: "doc.badge.gearshape.fill",
                visualState: vm.pairingVisualState
            ) {
                showPairingSheet = true
            }

            CheckItemButton(
                title: "Mạng 4G/Di Động",
                subtitle: vm.isCellularOK ? "Ổn định" : "Chưa bật",
                icon: "antenna.radiowaves.left.and.right",
                visualState: vm.isCellularOK ? .verifiedOK : .failedError
            ) {
                showCellularSheet = true
            }
        }
    }

    private var serverSection: some SwiftUI.View {
        SkySectionCard(
            title: "MÁY CHỦ ANISETTE",
            icon: "server.rack",
            color: CSSTheme.secondary,
            footerText: "Khuyên tắt 'Use On-Device Anisette' để đăng nhập ID Apple và gia hạn ứng dụng ổn định nhất."
        ) {
            CheckItemButton(
                title: "Máy chủ Anisette",
                subtitle: vm.isAnisetteOK ? "Ổn định" : "Không ổn định",
                icon: "server.rack",
                visualState: vm.isAnisetteOK ? .verifiedOK : .failedError
            ) {
                showAnisetteSheet = true
            }
        }
    }

    private var shortcutsSection: some SwiftUI.View {
        SkySectionCard(
            title: "PHÍM TẮT & LÀM MỚI 4G",
            icon: "bolt.circle.fill",
            color: CSSTheme.primary,
            footerText: "Bật 'Cellular Refresh' và thêm các phím tắt để tự động gia hạn ứng dụng trực tiếp qua mạng 4G/5G."
        ) {
            CellularRefreshToggleRow(
                title: "Cellular Refresh (Refresh Qua 4G)",
                onText: "Đã bật mặc định",
                offText: "Chưa bật",
                isOn: Binding(
                    get: { vm.isCellularRefreshEnabled },
                    set: { vm.setCellularRefreshEnabled($0) }
                )
            )

            ShortcutLinkRow(
                title: "Phím tắt Tắt 4G",
                buttonTitle: "Nhận",
                icon: "antenna.radiowaves.left.and.right.slash",
                color: CSSTheme.secondary,
                urlString: "https://www.icloud.com/shortcuts/ee47f3710b02435883faa746c7355236"
            )

            ShortcutLinkRow(
                title: "Phím tắt Bật 4G",
                buttonTitle: "Nhận",
                icon: "antenna.radiowaves.left.and.right",
                color: CSSTheme.primary,
                urlString: "https://www.icloud.com/shortcuts/10bd8bb0aa1540c4b1221182b835fc43"
            )

            ShortcutLinkRow(
                title: "Tự động làm mới App (6:00 sáng)",
                buttonTitle: "Nhận",
                icon: "clock.arrow.2.circlepath",
                color: CSSTheme.green,
                urlString: "https://www.icloud.com/shortcuts/56b0ab8cb0984d0b9a98543ac879eeec"
            )

            ShortcutLinkRow(
                title: "Tự động làm mới App (15:00 chiều)",
                buttonTitle: "Nhận",
                icon: "sun.max.circle.fill",
                color: CSSTheme.primary,
                urlString: "https://www.icloud.com/shortcuts/9f93051e8bf142258ffc93e08f3c0849"
            )
        }
    }

    private var automationGuideSection: some SwiftUI.View {
        SkySectionCard(
            title: "HƯỚNG DẪN TỰ ĐỘNG HÓA",
            icon: "bell.badge.fill",
            color: CSSTheme.secondary
        ) {
            VStack(spacing: 14) {
                RemoteGuideImageView(
                    urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2589.jpeg",
                    caption: "Bước 1: Mở Phím Tắt mục Auto Refresh 4G (Auto Refresh 4G 2) và nhấn vào dấu xổ xuống:",
                    loadingText: "Đang tải ảnh...",
                    errorText: "Không tải được ảnh. Vui lòng kiểm tra mạng."
                )
                RemoteGuideImageView(
                    urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2588.jpeg",
                    caption: "Bước 2: Bật nút Tự động hóa:",
                    loadingText: "Đang tải ảnh...",
                    errorText: "Không tải được ảnh. Vui lòng kiểm tra mạng."
                )
            }
            .padding(12)
            .background(CSSTheme.innerRowBackground)
            .cornerRadius(CSSTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.innerBorder, lineWidth: 1)
            )
        }
    }

    private var shortcutVideoGuideSection: some SwiftUI.View {
        SkySectionCard(
            title: "HƯỚNG DẪN VIDEO PHÍM TẮT",
            icon: "play.rectangle.fill",
            color: CSSTheme.primary
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    SwiftUI.Image(systemName: "sparkles.tv.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(CSSTheme.primary)
                        .padding(.top, 2)

                    SwiftUI.Text("Nếu phím tắt tải về không tương thích với phiên bản iOS trên máy của bạn, bạn có thể xem video bên dưới để tự tạo phím tắt.")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(CSSTheme.darkText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CSSTheme.innerRowBackground)
                .cornerRadius(CSSTheme.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                        .stroke(CSSTheme.innerBorder, lineWidth: 1)
                )

                IPhone14VerticalVideoFrameView(
                    videoID: "j0Ng2cYvd1o"
                )
            }
        }
    }
}

/// Khung phát video dọc tỉ lệ 9:19.5 được thiết kế lớn, sắc nét, bo tròn 4 góc chuẩn iPhone 14 (47.33pt continuous)
struct IPhone14VerticalVideoFrameView: SwiftUI.View {
    let videoID: String
    @State private var isVisibleOnScreen: Bool = false
    @State private var shouldMountWebView: Bool = false

    private let iPhone14CornerRadius: CGFloat = 47.33

    var body: some SwiftUI.View {
        ZStack {
            SwiftUI.Color.black
            if shouldMountWebView {
                YouTubeVerticalPlayerWebView(
                    videoID: videoID,
                    isVisibleOnScreen: isVisibleOnScreen
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView()
                    .tint(CSSTheme.primary)
            }
        }
        .aspectRatio(9.0 / 19.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: iPhone14CornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: iPhone14CornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            CSSTheme.primary.opacity(0.65),
                            CSSTheme.secondary.opacity(0.45),
                            CSSTheme.primary.opacity(0.65)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
        )
        .shadow(color: CSSTheme.secondary.opacity(0.22), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 4)
        .onAppear {
            isVisibleOnScreen = true
            if !shouldMountWebView {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    shouldMountWebView = true
                }
            }
        }
        .onDisappear {
            isVisibleOnScreen = false
        }
    }
}

/// WebView nhúng trình phát YouTube tối ưu cho khung dọc 9:19.5
struct YouTubeVerticalPlayerWebView: UIViewRepresentable {
    let videoID: String
    let isVisibleOnScreen: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = [.all]
        config.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = true
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if !isVisibleOnScreen {
            uiView.evaluateJavaScript(
                "var iframe = document.querySelector('iframe'); if (iframe && iframe.contentWindow) { iframe.contentWindow.postMessage('{\"event\":\"command\",\"func\":\"pauseVideo\",\"args\":\"\"}', '*'); }",
                completionHandler: nil
            )
            return
        }

        guard context.coordinator.loadedVideoID != videoID else { return }
        context.coordinator.loadedVideoID = videoID

        let originDomain = "https://sidestore.io"
        let embedURL = "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&rel=0&modestbranding=1&fs=1&enablejsapi=1&origin=\(originDomain)"

        let embedHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
        <meta name="referrer" content="strict-origin-when-cross-origin">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body {
                width: 100%;
                height: 100%;
                background-color: #000000;
                overflow: hidden;
            }
            .video-container {
                position: fixed;
                top: 0;
                left: 0;
                width: 100%;
                height: 100%;
                background-color: #000000;
            }
            iframe {
                width: 100%;
                height: 100%;
                border: 0;
            }
        </style>
        </head>
        <body>
            <div class="video-container">
                <iframe
                    src="\(embedURL)"
                    title="YouTube video player"
                    referrerpolicy="strict-origin-when-cross-origin"
                    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
                    allowfullscreen>
                </iframe>
            </div>
        </body>
        </html>
        """

        uiView.loadHTMLString(embedHTML, baseURL: URL(string: originDomain))
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.stopLoading()
        if #available(iOS 15.0, *) {
            uiView.pauseAllMediaPlayback()
        }
    }

    final class Coordinator {
        var loadedVideoID: String?
    }
}

// MARK: - 🗂️ CẤU TRÚC SECTION HEADER + CARD CHUẨN SETTINGS VIEW CONTROLLER
struct SkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil
    var footerText: String? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            // Tiêu đề Section bên ngoài Card + Gạch chân màu xanh 38x3pt giống hệt SettingsHeaderFooterView
            SectionHeaderView(
                title: title,
                icon: icon,
                color: color,
                statusOK: statusOK,
                trailingView: trailingView
            )
            .padding(.horizontal, 4)

            // Khối Card trắng bo góc 15pt, đổ bóng xanh dịu giống hệt styleInnerCardOfCell trong Settings
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.border, lineWidth: 1.0)
            )
            .shadow(color: CSSTheme.primary.opacity(0.07), radius: 10, x: 0, y: 5)

            // Chú thích chân trang (Footer) giống SettingsHeaderFooterView
            if let footerText = footerText {
                SwiftUI.Text(footerText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(CSSTheme.darkText.opacity(0.78))
                    .padding(.horizontal, 6)
                    .padding(.top, 2)
            }
        }
    }
}

struct SectionHeaderView: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                SwiftUI.Image(systemName: icon)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(CSSTheme.primary)

                SwiftUI.Text(title.uppercased())
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(CSSTheme.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                if let statusOK = statusOK {
                    SwiftUI.Image(systemName: statusOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(statusOK ? CSSTheme.green : CSSTheme.red)
                        .animation(.spring(), value: statusOK)
                }

                Spacer(minLength: 4)

                if let trailingView = trailingView {
                    trailingView
                }
            }

            // Thanh gạch chân màu xanh (.features h2::after) dài 38pt, cao 3pt giống hệt Settings
            RoundedRectangle(cornerRadius: 1.5)
                .fill(CSSTheme.primary)
                .frame(width: 38, height: 3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CheckItemButton: SwiftUI.View {
    let title: String
    let subtitle: String
    let icon: String
    let visualState: CheckItemVisualState
    let action: () -> Void

    private var iconContainerColor: SwiftUI.Color {
        switch visualState {
        case .verifiedOK:
            return CSSTheme.green.opacity(0.14)
        case .actionRequired:
            return CSSTheme.neutralInspect.opacity(0.14)
        case .failedError:
            return CSSTheme.red.opacity(0.14)
        }
    }

    private var iconForegroundColor: SwiftUI.Color {
        switch visualState {
        case .verifiedOK:
            return CSSTheme.green
        case .actionRequired:
            return CSSTheme.neutralInspect
        case .failedError:
            return CSSTheme.red
        }
    }

    private var subtitleForegroundColor: SwiftUI.Color {
        switch visualState {
        case .verifiedOK:
            return CSSTheme.green
        case .actionRequired:
            return CSSTheme.neutralInspect
        case .failedError:
            return CSSTheme.red
        }
    }

    private var trailingStatusIconName: String {
        switch visualState {
        case .verifiedOK:
            return "checkmark.circle.fill"
        case .actionRequired:
            return "doc.text.magnifyingglass"
        case .failedError:
            return "xmark.circle.fill"
        }
    }

    private var trailingStatusColor: SwiftUI.Color {
        switch visualState {
        case .verifiedOK:
            return CSSTheme.green
        case .actionRequired:
            return CSSTheme.neutralInspect
        case .failedError:
            return CSSTheme.red
        }
    }

    var body: some SwiftUI.View {
        SwiftUI.Button(action: action) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconContainerColor)
                        .frame(width: 44, height: 44)
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(iconForegroundColor)
                }

                VStack(alignment: .leading, spacing: 3) {
                    SwiftUI.Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(CSSTheme.darkText)
                    SwiftUI.Text(subtitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(subtitleForegroundColor)
                        .lineLimit(1)
                }

                Spacer()

                SwiftUI.Image(systemName: trailingStatusIconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(trailingStatusColor)
                    .animation(.spring(), value: visualState)

                SwiftUI.Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(CSSTheme.secondary.opacity(0.65))
            }
            .padding(12)
            .background(CSSTheme.innerRowBackground)
            .cornerRadius(CSSTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(
                        visualState == .actionRequired
                        ? CSSTheme.neutralInspect.opacity(0.35)
                        : CSSTheme.innerBorder,
                        lineWidth: 1.0
                    )
            )
        }
        .buttonStyle(CSSBounceButtonStyle())
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
                    .fill((isOn ? CSSTheme.primary : SwiftUI.Color.secondary).opacity(0.14))
                    .frame(width: 44, height: 44)
                SwiftUI.Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isOn ? CSSTheme.primary : .secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(CSSTheme.darkText)
                SwiftUI.Text(isOn ? onText : offText)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(isOn ? CSSTheme.primary : .secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Công tắc UISwitch màu xanh có đổ bóng Neon giống hệt SettingsViewController
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(CSSTheme.primary)
                .shadow(color: CSSTheme.primary.opacity(0.28), radius: 6, x: 0, y: 3)
        }
        .padding(12)
        .background(CSSTheme.innerRowBackground)
        .cornerRadius(CSSTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(CSSTheme.innerBorder, lineWidth: 1.0)
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
                        .font(.system(size: 19, weight: .bold))
                        .foregroundColor(color)
                }

                SwiftUI.Text(title)
                    .font(.system(size: 15.5, weight: .medium))
                    .foregroundColor(CSSTheme.darkText)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Nút viên thuốc giống styleBetaTrackPopupButton / nút hành động của Settings
                SwiftUI.Text(buttonTitle)
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [color, color.opacity(0.82)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(color: color.opacity(0.28), radius: 5, x: 0, y: 3)
            }
            .padding(12)
            .background(CSSTheme.innerRowBackground)
            .cornerRadius(CSSTheme.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.innerBorder, lineWidth: 1.0)
            )
        }
        .buttonStyle(CSSBounceButtonStyle())
    }
}

/// Hiển thị ảnh hướng dẫn đã được giải mã ngầm (Background Decoded) + Cache RAM giúp cuộn không bị khựng
struct RemoteGuideImageView: SwiftUI.View {
    let urlString: String
    let caption: String
    let loadingText: String
    let errorText: String

    @State private var uiImage: UIImage? = nil
    @State private var didFail: Bool = false

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 8) {
            SwiftUI.Text(caption)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(CSSTheme.darkText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            if let image = uiImage {
                SwiftUI.Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1)
                    )
            } else if didFail {
                VStack(spacing: 6) {
                    SwiftUI.Image(systemName: "wifi.exclamationmark")
                        .font(.title3)
                        .foregroundColor(CSSTheme.primary)
                    SwiftUI.Text(errorText)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, minHeight: 160)
                .background(CSSTheme.cardBackground)
                .cornerRadius(14)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(CSSTheme.primary)
                    SwiftUI.Text(loadingText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
                .background(CSSTheme.cardBackground)
                .cornerRadius(14)
            }
        }
        .task(id: urlString) {
            if let cached = GuideImageCacheManager.shared.cachedImage(for: urlString) {
                self.uiImage = cached
                return
            }
            if let loaded = await GuideImageCacheManager.shared.loadAndDecodeImage(urlString: urlString) {
                self.uiImage = loaded
                self.didFail = false
            } else {
                self.didFail = true
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
                VStack(alignment: .leading, spacing: 18) {
                    statusHeaderCard
                    verificationAdviceCard

                    if let banner = statusBannerMessage {
                        HStack(spacing: 10) {
                            SwiftUI.Image(systemName: vm.isPairingOK ? "checkmark.seal.fill" : "info.circle.fill")
                                .foregroundColor(vm.isPairingOK ? CSSTheme.green : CSSTheme.primary)
                            SwiftUI.Text(banner)
                                .font(.footnote.bold())
                                .foregroundColor(CSSTheme.darkText)
                            Spacer()
                        }
                        .padding(12)
                        .background((vm.isPairingOK ? CSSTheme.green : CSSTheme.primary).opacity(0.12))
                        .cornerRadius(CSSTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius)
                                .stroke(CSSTheme.border, lineWidth: 1)
                        )
                    }

                    ios27DirectPairingCard
                    pcPairingGuideCard
                }
                .padding(16)
            }
            .background(CSSTheme.pageBackgroundGradient.ignoresSafeArea())
            .navigationTitle("Kiểm Tra Pairing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SwiftUI.Text("Kiểm Tra Pairing")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(CSSTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") {
                        if wirelessVM.isAdvertising {
                            wirelessVM.togglePairing()
                        }
                        vm.setWirelessPairingActive(false)
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(CSSTheme.primary)
                }
            }
            .onDisappear {
                if wirelessVM.isAdvertising {
                    wirelessVM.togglePairing()
                }
                vm.setWirelessPairingActive(false)
            }
            .alert("Xoá tệp Pairing?", isPresented: $showDeleteConfirmAlert) {
                SwiftUI.Button("Xoá", role: .destructive) {
                    vm.deleteAllPairingFiles()
                    statusBannerMessage = "Đã xoá tệp Pairing khỏi ứng dụng."
                }
                SwiftUI.Button("Huỷ", role: .cancel) {}
            } message: {
                SwiftUI.Text("Tệp Pairing hiện tại sẽ bị xoá hoàn toàn khỏi ứng dụng. Bạn sẽ cần cài hoặc nhập lại tệp mới để tiếp tục sử dụng.")
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
                        statusBannerMessage = "Đã nạp tệp Pairing thành công!"
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
                        statusBannerMessage = "Đã cài và nạp Pairing thành công!"
                    }
                }
            }
        }
    }

    private var statusHeaderCard: some SwiftUI.View {
        let state = vm.pairingVisualState

        let badgeColor: SwiftUI.Color = {
            switch state {
            case .verifiedOK: return CSSTheme.green
            case .actionRequired: return CSSTheme.neutralInspect
            case .failedError: return CSSTheme.red
            }
        }()

        let badgeIcon: String = {
            switch state {
            case .verifiedOK: return "checkmark.circle.fill"
            case .actionRequired: return "doc.text.magnifyingglass"
            case .failedError: return "xmark.circle.fill"
            }
        }()

        let headerTitle: String = {
            switch state {
            case .verifiedOK:
                return "Pairing Hoạt Động Tốt (Tích Xanh)"
            case .actionRequired:
                return "Đang Chờ Xác Minh Pairing"
            case .failedError:
                return !vm.hasAnyStoredPairingFile
                    ? "Chưa Có Tệp Pairing (Tích Đỏ)"
                    : "Pairing Lỗi Hoặc Hết Hạn (Tích Đỏ)"
            }
        }()

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(badgeColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                SwiftUI.Image(systemName: badgeIcon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(badgeColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                SwiftUI.Text(headerTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CSSTheme.darkText)

                if state != .actionRequired && !vm.pairingProtocol.isEmpty {
                    SwiftUI.Text(vm.pairingProtocol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(CSSTheme.cardBackground)
        .cornerRadius(CSSTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(badgeColor.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: CSSTheme.primary.opacity(0.07), radius: 10, x: 0, y: 5)
    }

    private var verificationAdviceCard: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SwiftUI.Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(CSSTheme.primary)
                SwiftUI.Text("3 Bước Kiểm Tra Pairing Chính Xác:")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CSSTheme.darkText)
            }

            VStack(alignment: .leading, spacing: 10) {
                GuideStepRow(
                    num: "1",
                    title: "Kết nối mạng trên iPhone",
                    text: LocalizedStringKey("Đảm bảo iPhone của bạn đang có kết nối **Wi-Fi** hoặc **4G**.")
                )

                GuideStepRow(
                    num: "2",
                    title: "Bật LocalDevVPN",
                    text: LocalizedStringKey("Mở ứng dụng **LocalDevVPN** và bật kết nối VPN lên.")
                )

                GuideStepRow(
                    num: "3",
                    title: "Tắt cả Wi-Fi và 4G (Chỉ bật LocalDevVPN)",
                    text: LocalizedStringKey("Tắt cả **Wi-Fi** và **4G**, chỉ để lại mỗi **LocalDevVPN** đang bật.")
                )
            }

            SwiftUI.Text("Xong 3 bước trên, nhìn lên mục Đang Chờ Xác Minh Pairing ở phía trên sẽ tự động hiện Tích Xanh báo đang hoạt động tốt hoặc Tích Đỏ đã bị lỗi / cần cài lại.")
                .font(.system(size: 13.5, weight: .bold))
                .foregroundColor(CSSTheme.neutralInspect)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CSSTheme.neutralInspect.opacity(0.10))
                .cornerRadius(13)
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(CSSTheme.neutralInspect.opacity(0.32), lineWidth: 1)
                )
                .padding(.top, 6)
        }
        .padding(16)
        .background(CSSTheme.cardBackground)
        .cornerRadius(CSSTheme.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(CSSTheme.border, lineWidth: 1.0)
        )
        .shadow(color: CSSTheme.primary.opacity(0.07), radius: 10, x: 0, y: 5)
    }

    private var ios27DirectPairingCard: some SwiftUI.View {
        SkySectionCard(
            title: "PHẦN 1: DÀNH CHO IOS 27",
            icon: "iphone.radiowaves.left.and.right",
            color: CSSTheme.primary
        ) {
            SwiftUI.Text("Ghép nối trực tiếp trên iPhone")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(CSSTheme.secondary)

            VStack(alignment: .leading, spacing: 12) {
                GuideStepRow(
                    num: "1",
                    title: "Bắt đầu phát tín hiệu Pairing",
                    text: LocalizedStringKey("Nhấn vào nút **\"Cài Pairing lên iPhone\"** ở bên dưới để ứng dụng phát tín hiệu ghép đôi.")
                )

                GuideStepRow(
                    num: "2",
                    title: "Mở Cài đặt Nhà phát triển",
                    text: LocalizedStringKey("Thoát ra màn hình chính (không vuốt tắt ứng dụng này), mở **Cài đặt (Settings)** ➔ **Quyền riêng tư & Bảo mật (Privacy & Security)** ➔ kéo xuống cuối chọn **Chế độ nhà phát triển (Developer Mode)**.")
                )

                GuideStepRow(
                    num: "3",
                    title: "Nhập mã PIN 6 chữ số (Tự động kích hoạt)",
                    text: LocalizedStringKey("Trong mục Chế độ nhà phát triển, nếu có “Thiết bị đã ghép đôi” cũ thì xoá đi, sau đó nhấn vào dòng **Pair with SideStore** và nhập mật khẩu iPhone. Quay lại app này xem **mã 6 chữ số**, rồi sang **Cài đặt** nhập vào và nhấn **Ghép đôi**. Ngay sau khi ghép đôi xong, ứng dụng sẽ **tự động nạp và kích hoạt Pairing luôn**!")
                )

                GuideStepRow(
                    num: "4",
                    title: "Lưu tệp Pairing dự phòng (Khuyên dùng)",
                    text: LocalizedStringKey("Sau khi ghép nối xong, bạn **không cần nhập lại tệp nữa**. Tuy nhiên, hãy nhấn nút **“Xuất tệp Pairing (Lưu dự phòng)”** (màu xanh lá) ➔ chọn **Lưu vào Tệp (Save to Files)** để cất giữ dự phòng cho những lần cài lại app sau này.")
                )
            }

            Divider().padding(.vertical, 2)

            VStack(spacing: 10) {
                if let pin = wirelessVM.pinCode {
                    VStack(spacing: 6) {
                        SwiftUI.Text("MÃ GHÉP NỐI 6 CHỮ SỐ")
                            .font(.caption2.bold())
                            .foregroundColor(CSSTheme.primary)
                        SwiftUI.Text(pin)
                            .font(.system(size: 30, weight: .heavy, design: .monospaced))
                            .tracking(6)
                            .foregroundColor(CSSTheme.darkText)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 18)
                            .background(RoundedRectangle(cornerRadius: 10).fill(CSSTheme.primary.opacity(0.12)))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                }

                if let errorMsg = wirelessVM.errorMessage {
                    SwiftUI.Text(errorMsg)
                        .font(.caption)
                        .foregroundColor(CSSTheme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                SwiftUI.Button {
                    didPressInstallPairing = true
                    wirelessVM.togglePairing()
                    vm.setWirelessPairingActive(wirelessVM.isAdvertising)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: wirelessVM.isAdvertising ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text(wirelessVM.isAdvertising
                                     ? "Dừng Cài Pairing (Đang phát sóng...)"
                                     : "Cài Pairing lên iPhone")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(wirelessVM.isAdvertising ? CSSTheme.red : CSSTheme.primary)
                    .cornerRadius(13)
                    .shadow(color: (wirelessVM.isAdvertising ? CSSTheme.red : CSSTheme.primary).opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(CSSBounceButtonStyle())

                if didPressInstallPairing || installedPairingURLForExport != nil {
                    SwiftUI.Button {
                        if let pairedURL = installedPairingURLForExport {
                            wirelessVM.pinCode = nil
                            exportFileURL = pairedURL
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isExportSheetPresented = true
                            }
                        } else {
                            statusBannerMessage = "Vui lòng thực hiện Bước 2 & Bước 3 (nhập xong 6 chữ số trong Cài đặt ➔ Chế độ nhà phát triển) trước khi lưu tệp dự phòng."
                        }
                    } label: {
                        HStack(spacing: 8) {
                            SwiftUI.Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 17, weight: .bold))
                            SwiftUI.Text("Xuất tệp Pairing (Lưu dự phòng)")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(installedPairingURLForExport != nil ? CSSTheme.green : CSSTheme.green.opacity(0.65))
                        .cornerRadius(13)
                        .shadow(color: CSSTheme.green.opacity(0.35), radius: 6, x: 0, y: 4)
                    }
                    .buttonStyle(CSSBounceButtonStyle())
                    .transition(.scale.combined(with: .opacity))
                }

                SwiftUI.Button {
                    pairingMgmtVM.promptImport(for: .rppairing)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Nhập tệp Pairing có sẵn")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CSSTheme.secondary)
                    .cornerRadius(13)
                    .shadow(color: CSSTheme.secondary.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(CSSBounceButtonStyle())

                SwiftUI.Button {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Xoá tệp Pairing")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CSSTheme.red)
                    .cornerRadius(13)
                    .shadow(color: CSSTheme.red.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(CSSBounceButtonStyle())
            }
            .padding(12)
            .background(CSSTheme.innerRowBackground)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(CSSTheme.innerBorder, lineWidth: 1)
            )
        }
    }

    private var pcPairingGuideCard: some SwiftUI.View {
        SkySectionCard(
            title: "PHẦN 2: DƯỚI IOS 27 (PC / MAC)",
            icon: "laptopcomputer.and.iphone",
            color: CSSTheme.secondary
        ) {
            SwiftUI.Text("Tạo / Cài tệp Pairing qua Máy tính (Windows / Mac)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(CSSTheme.secondary)

            HStack(alignment: .top, spacing: 8) {
                SwiftUI.Image(systemName: "info.circle.fill")
                    .foregroundColor(CSSTheme.primary)
                    .font(.subheadline)
                SwiftUI.Text(LocalizedStringKey("**Chuẩn bị chung:** Trên Windows cần cài đặt **iTunes** & **iCloud** bản chính chủ từ Apple (không tải bản Microsoft Store). Cắm cáp kết nối iPhone vào máy tính, mở khóa màn hình iPhone và nhấn **Tin cậy (Trust)** + nhập mật khẩu màn hình. Hãy chọn **1 trong 3 công cụ** dưới đây:"))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(10)
            .background(CSSTheme.primary.opacity(0.1))
            .cornerRadius(10)

            VStack(alignment: .leading, spacing: 12) {
                GuideStepRow(
                    num: "1",
                    title: "Cách 1: Dùng idevice_pair (Khuyên dùng - Hỗ trợ cả nạp thẳng & xuất tệp)",
                    text: LocalizedStringKey("• Mở phần mềm **idevice_pair** trên máy tính và chọn iPhone của bạn.\n• **Cách nạp thẳng vào ứng dụng:** Trong mục ứng dụng trên **idevice_pair**, chọn **SideStore** hoặc **LiveContainer** rồi nhấn nút **Load** (hoặc **Install Pairing File**). Phần mềm sẽ tự động chép thẳng tệp Pairing vào trong ứng dụng trên iPhone mà không cần làm thủ công.\n• **Cách xuất ra tệp `.mobiledevicepairing` dự phòng:** Nhấn nút **Generate** rồi chọn **Export / Save** để lưu tệp có đuôi **`.mobiledevicepairing`** ra máy tính. Gửi tệp này sang iPhone (qua Zalo, AirDrop, iCloud Drive), chọn **Lưu vào Tệp** rồi nhấn nút **“Nhập tệp Pairing”** ở dưới.")
                )

                GuideStepRow(
                    num: "2",
                    title: "Cách 2: Dùng jitterbugpair (Công cụ xuất tệp `.mobiledevicepairing` ra máy tính)",
                    text: LocalizedStringKey("• Tải và giải nén **jitterbugpair** (trên Windows/macOS/Linux).\n• Giữ màn hình iPhone luôn sáng và mở khóa, sau đó chạy file **`jitterbugpair.exe`** (trên Windows) hoặc chạy **`./jitterbugpair`** trong Terminal (trên Mac).\n• Công cụ sẽ tự động xuất ra một tệp có tên dạng **`<UDID>.mobiledevicepairing`** nằm ngay trong cùng thư mục chứa **jitterbugpair** (công cụ này chỉ xuất ra tệp chứ không tự chép vào app).\n• Gửi tệp **`.mobiledevicepairing`** đó sang iPhone ➔ chọn **Lưu vào Tệp (Save to Files)** ➔ nhấn nút **“Nhập tệp Pairing”** bên dưới để nạp vào ứng dụng.")
                )

                GuideStepRow(
                    num: "3",
                    title: "Cách 3: Dùng iLoader (Cài đặt tự động vào ứng dụng trên iPhone)",
                    text: LocalizedStringKey("• Mở phần mềm **iLoader** trên máy tính, đăng nhập hoặc kết nối với iPhone đã nhấn Tin cậy.\n• **iLoader** chủ yếu hỗ trợ tính năng **Tự động tạo và nạp trực tiếp (Inject) Pairing File** vào **SideStore / LiveContainer** thông qua tùy chọn **Generate / Place Pairing File** ngay trong giao diện quản lý thiết bị.\n• Sau khi iLoader báo hoàn tất trên máy tính, hãy mở lại ứng dụng này trên iPhone để hệ thống tự nhận diện.")
                )
            }

            VStack(spacing: 10) {
                SwiftUI.Button {
                    pairingMgmtVM.promptImport(for: .rppairing)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "folder.fill.badge.plus")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Nhập tệp Pairing (Từ ứng dụng Tệp)")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(CSSTheme.primary)
                    .cornerRadius(13)
                    .shadow(color: CSSTheme.primary.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(CSSBounceButtonStyle())

                SwiftUI.Button {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Xoá tệp Pairing")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                    .background(CSSTheme.red)
                    .cornerRadius(13)
                    .shadow(color: CSSTheme.red.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(CSSBounceButtonStyle())
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
                .background(
                    Circle().fill(
                        LinearGradient(colors: [CSSTheme.primary, CSSTheme.secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                )
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                if let title = title {
                    SwiftUI.Text(title)
                        .font(.subheadline.bold())
                        .foregroundColor(CSSTheme.darkText)
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
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.isVpnOK ? CSSTheme.green.opacity(0.15) : CSSTheme.red.opacity(0.15))
                                .frame(width: 46, height: 46)
                            SwiftUI.Image(systemName: vm.isVpnOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(vm.isVpnOK ? CSSTheme.green : CSSTheme.red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            SwiftUI.Text(vm.isVpnOK
                                         ? "LocalDevVPN Đang Ổn Định"
                                         : "LocalDevVPN Chưa Kết Nối")
                                .font(.headline)
                                .foregroundColor(CSSTheme.darkText)
                            SwiftUI.Text("Hãy bật công tắc VPN trong ứng dụng LocalDevVPN.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(CSSTheme.cardBackground)
                    .cornerRadius(CSSTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1.0)
                    )
                    .shadow(color: CSSTheme.primary.opacity(0.07), radius: 10, x: 0, y: 5)

                    SkySectionCard(
                        title: "THÔNG SỐ KẾT NỐI HIỆN TẠI",
                        icon: "network",
                        color: CSSTheme.primary
                    ) {
                        HStack {
                            SwiftUI.Text("Tunnel IP")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                            SwiftUI.Text(vm.tunnelIP)
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundColor(CSSTheme.primary)
                        }
                        Divider()
                        HStack {
                            SwiftUI.Text("Device IP")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            Spacer()
                            SwiftUI.Text(vm.deviceIP)
                                .font(.system(.subheadline, design: .monospaced).bold())
                                .foregroundColor(CSSTheme.secondary)
                        }
                    }

                    SkySectionCard(
                        title: "CẤU HÌNH KHUYÊN DÙNG IOS 27",
                        icon: "lightbulb.fill",
                        color: CSSTheme.secondary
                    ) {
                        SwiftUI.Text("Nếu dùng iOS 27 và bản LiveContainer+SideStore này, hãy đặt IP trong LocalDevVPN theo thông số sau để kết nối nhanh nhất:")
                            .font(.footnote)
                            .foregroundColor(.secondary)

                        CopyableIPCard(
                            label: "Tunnel IP",
                            value: "10.7.1.1/32",
                            copyText: "Sao chép",
                            copiedText: "Đã chép"
                        )
                        CopyableIPCard(
                            label: "Device IP",
                            value: "10.7.0.1/32",
                            copyText: "Sao chép",
                            copiedText: "Đã chép"
                        )
                    }
                }
                .padding(16)
            }
            .background(CSSTheme.pageBackgroundGradient.ignoresSafeArea())
            .navigationTitle("LocalDevVPN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SwiftUI.Text("LocalDevVPN")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(CSSTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") { dismiss() }
                        .font(.headline)
                        .foregroundColor(CSSTheme.primary)
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
    @State private var resetTask: Task<Void, Never>? = nil

    var body: some SwiftUI.View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                SwiftUI.Text(value)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundColor(CSSTheme.darkText)
            }
            Spacer()
            SwiftUI.Button(action: {
                UIPasteboard.general.string = value
                copied = true
                resetTask?.cancel()
                resetTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    if !Task.isCancelled {
                        copied = false
                    }
                }
            }) {
                SwiftUI.Label(copied ? copiedText : copyText, systemImage: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(copied ? CSSTheme.green.opacity(0.2) : CSSTheme.primary.opacity(0.15))
                    .foregroundColor(copied ? CSSTheme.green : CSSTheme.primary)
                    .cornerRadius(10)
            }
            .buttonStyle(CSSBounceButtonStyle())
        }
        .padding(12)
        .background(CSSTheme.innerRowBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(CSSTheme.innerBorder, lineWidth: 1)
        )
    }
}

struct CellularDetailSheetView: SwiftUI.View {
    @ObservedObject var vm: SystemCheckViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.isCellularOK ? CSSTheme.green.opacity(0.15) : CSSTheme.red.opacity(0.15))
                                .frame(width: 46, height: 46)
                            SwiftUI.Image(systemName: vm.isCellularOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(vm.isCellularOK ? CSSTheme.green : CSSTheme.red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            SwiftUI.Text(vm.isCellularOK
                                         ? "Mạng 4G/Di Động Ổn Định"
                                         : "Mạng 4G/Di Động Đang Tắt")
                                .font(.headline)
                                .foregroundColor(CSSTheme.darkText)
                            SwiftUI.Text(vm.cellularDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(CSSTheme.cardBackground)
                    .cornerRadius(CSSTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1.0)
                    )
                    .shadow(color: CSSTheme.primary.opacity(0.07), radius: 10, x: 0, y: 5)

                    SkySectionCard(
                        title: "CÀI & GIA HẠN APP QUA 4G + VPN",
                        icon: "antenna.radiowaves.left.and.right.circle.fill",
                        color: CSSTheme.primary
                    ) {
                        SwiftUI.Text(LocalizedStringKey("• **Không cần Wi-Fi:** Cài đặt IPA và làm mới ứng dụng trực tiếp qua **4G/5G + LocalDevVPN**.\n\n• **Tự động hóa:** Kết hợp phím tắt làm mới lúc 6:00 hoặc 15:00 để tự động gia hạn ứng dụng mỗi ngày."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
            }
            .background(CSSTheme.pageBackgroundGradient.ignoresSafeArea())
            .navigationTitle("Mạng 4G/Di Động")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SwiftUI.Text("Mạng 4G/Di Động")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(CSSTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") { dismiss() }
                        .font(.headline)
                        .foregroundColor(CSSTheme.primary)
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

    private let customServerPrefix = "Máy chủ tùy chỉnh"

    var body: some SwiftUI.View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(vm.isAnisetteOK ? CSSTheme.green.opacity(0.15) : CSSTheme.red.opacity(0.15))
                                .frame(width: 46, height: 46)
                            SwiftUI.Image(systemName: vm.isAnisetteOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(vm.isAnisetteOK ? CSSTheme.green : CSSTheme.red)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            SwiftUI.Text(vm.isAnisetteOK
                                         ? "Máy Chủ Anisette Ổn Định"
                                         : "Đang Bật On-Device Anisette")
                                .font(.headline)
                                .foregroundColor(CSSTheme.darkText)
                            SwiftUI.Text(vm.anisetteDetail)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(CSSTheme.cardBackground)
                    .cornerRadius(CSSTheme.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1.0)
                    )
                    .shadow(color: CSSTheme.primary.opacity(0.07), radius: 10, x: 0, y: 5)

                    SkySectionCard(
                        title: "CHẾ ĐỘ XÁC THỰC ANISETTE",
                        icon: "switch.2",
                        color: CSSTheme.primary
                    ) {
                        Toggle(isOn: Binding(
                            get: { vm.useOnDeviceAnisette },
                            set: { vm.setUseOnDeviceAnisette($0) }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                SwiftUI.Text("Use On-Device Anisette")
                                    .font(.subheadline.bold())
                                    .foregroundColor(CSSTheme.darkText)
                                SwiftUI.Text(vm.useOnDeviceAnisette
                                             ? "Đang BẬT (Khuyên tắt để ổn định hơn)"
                                             : "(Nên Tắt Để Dễ Đăng Nhập)")
                                    .font(.caption)
                                    .foregroundColor(vm.useOnDeviceAnisette ? CSSTheme.red : CSSTheme.green)
                            }
                        }
                        .tint(CSSTheme.primary)
                        .padding(12)
                        .background(CSSTheme.innerRowBackground)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(CSSTheme.innerBorder, lineWidth: 1)
                        )

                        if vm.useOnDeviceAnisette {
                            SwiftUI.Button {
                                vm.setUseOnDeviceAnisette(false)
                            } label: {
                                HStack(spacing: 8) {
                                    SwiftUI.Image(systemName: "checkmark.shield.fill")
                                    SwiftUI.Text("Tắt ngay Use On-Device Anisette")
                                        .font(.subheadline.bold())
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(CSSTheme.primary)
                                .cornerRadius(12)
                                .shadow(color: CSSTheme.primary.opacity(0.35), radius: 5, x: 0, y: 3)
                            }
                            .buttonStyle(CSSBounceButtonStyle())
                        }
                    }

                    SkySectionCard(
                        title: "CHỌN MÁY CHỦ ANISETTE",
                        icon: "server.rack",
                        color: CSSTheme.secondary,
                        trailingView: listVM.isLoading ? AnyView(ProgressView().tint(CSSTheme.primary)) : nil
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
                                            .foregroundColor(isSelected ? CSSTheme.primary : .secondary)

                                        VStack(alignment: .leading, spacing: 2) {
                                            SwiftUI.Text(server.name)
                                                .font(.subheadline.bold())
                                                .foregroundColor(CSSTheme.darkText)
                                            SwiftUI.Text(server.address)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        if isSelected {
                                            SwiftUI.Text("Đang dùng")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(CSSTheme.primary.opacity(0.15))
                                                .foregroundColor(CSSTheme.primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(12)
                                    .background(CSSTheme.innerRowBackground)
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(isSelected ? CSSTheme.primary.opacity(0.5) : CSSTheme.innerBorder, lineWidth: 1.2)
                                    )
                                }
                                .buttonStyle(CSSBounceButtonStyle())
                            }
                        }

                        Divider().padding(.vertical, 2)

                        VStack(alignment: .leading, spacing: 8) {
                            SwiftUI.Text("Hoặc nhập URL máy chủ tùy chỉnh:")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                TextField(AppConstants.Anisette.Servers.defaultServerURL, text: $customServerInput)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                    .padding(10)
                                    .background(CSSTheme.innerRowBackground)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(CSSTheme.innerBorder, lineWidth: 1)
                                    )

                                SwiftUI.Button {
                                    let trimmed = customServerInput.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    vm.selectAnisetteServerURL(trimmed, isCustom: true)
                                    Task { await listVM.reloadCurrentSelection(customPrefix: customServerPrefix) }
                                    customServerInput = ""
                                } label: {
                                    SwiftUI.Text("Lưu")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .background(CSSTheme.primary)
                                        .cornerRadius(10)
                                        .shadow(color: CSSTheme.primary.opacity(0.35), radius: 5, x: 0, y: 3)
                                }
                                .buttonStyle(CSSBounceButtonStyle())
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(CSSTheme.pageBackgroundGradient.ignoresSafeArea())
            .navigationTitle("Máy Chủ Anisette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SwiftUI.Text("Máy Chủ Anisette")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(CSSTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    SwiftUI.Button("Xong") { dismiss() }
                        .font(.headline)
                        .foregroundColor(CSSTheme.primary)
                }
            }
            .task {
                vm.updateInstantStatus()
                await listVM.loadCachedAndSync(customPrefix: customServerPrefix)
            }
        }
    }
}
