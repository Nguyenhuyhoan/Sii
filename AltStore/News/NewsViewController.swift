
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

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN 100% MÃ WEB CSS & SOURCESVIEWCONTROLLER
private enum CSSTheme {
    // UIKit Colors (Đồng bộ 100% với SourcesCSSTheme)
    static let uiWhite = UIColor.white                                                          // #fff (--white)
    static let uiBorder = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0)      // #e9ecef (--border)
    static let uiBlue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff (--blue)
    static let uiPurple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1 (--purple)
    static let bgGradientStartCG = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor // #f3e0ff
    static let bgGradientEndCG = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor   // #e0f7ff

    // SwiftUI Colors chuẩn CSS :root
    static let white = SwiftUI.Color.white                                                      // #fff (--white)
    static let light = SwiftUI.Color(red: 248/255, green: 249/255, blue: 250/255)               // #f8f9fa (--light)
    static let border = SwiftUI.Color(red: 233/255, green: 236/255, blue: 239/255)              // #e9ecef (--border)
    static let innerBorder = SwiftUI.Color(red: 233/255, green: 236/255, blue: 239/255)         // #e9ecef (--border)
    static let primary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)               // #007bff (--blue)
    static let secondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)            // #6f42c1 (--purple)
    static let darkAccent = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)           // #6f42c1 (--purple)
    static let green = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)                 // #28a745 (--green)
    static let badgeGreenBorder = SwiftUI.Color(red: 50/255, green: 196/255, blue: 83/255)      // #32c453
    static let red = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)                   // #dc3545 (--red)
    static let magenta = SwiftUI.Color(red: 230/255, green: 0/255, blue: 230/255)               // #e600e6 (data-tab="1")
    static let dark = SwiftUI.Color(red: 52/255, green: 58/255, blue: 64/255)                   // #343a40 (--dark)

    /// Màu Đen Tuyền (#000000) cho toàn bộ chữ tiêu đề và nội dung chuẩn CSS
    static let pureBlack = SwiftUI.Color.black                                                  // #000000
    static let darkText = SwiftUI.Color.black                                                   // #000000
    static let subText = SwiftUI.Color(red: 52/255, green: 58/255, blue: 64/255)                // #343a40 (--dark)

    /// Màu trung tính để nhắc "Nhấn vào đây để kiểm tra"
    static let neutralInspect = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)       // #6f42c1

    // Body Gradient chuẩn CSS: linear-gradient(to right, #f3e0ff, #e0f7ff)
    static let bgGradientStart = SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255)
    static let bgGradientEnd = SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)

    static var pageBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // Sleek Top Banner Gradient chuẩn CSS: linear-gradient(125deg, #007bff 0%, #6f42c1 52%, #d600d6 100%)
    static let bannerGradStart = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)
    static let bannerGradMid = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
    static let bannerGradEnd = SwiftUI.Color(red: 214/255, green: 0/255, blue: 214/255)

    static var heroGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: bannerGradStart, location: 0.0),
                .init(color: bannerGradMid, location: 0.52),
                .init(color: bannerGradEnd, location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Gradient Nút chính & Khung điện thoại Video: linear-gradient(135deg, var(--blue), var(--purple))
    static var primaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Gradient Viền ảnh hướng dẫn chuẩn CSS (.guide img): linear-gradient(135deg, var(--blue), var(--purple), #f0f)
    static var guideImageBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                primary,
                secondary,
                SwiftUI.Color(red: 1.0, green: 0.0, blue: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Gradient Viền điện thoại Video chuẩn CSS (.video-phone-frame): linear-gradient(135deg, var(--blue), var(--purple))
    static var mediaFrameBorderGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Trả về 4 màu chủ đạo luân phiên chuẩn `.tab-button[data-tab="1..4"]` & `.guide-step-card:nth-child(4n+1..4)`
    static func tabAccentColor(for index: Int) -> SwiftUI.Color {
        switch index % 4 {
        case 0: return magenta   // #e600e6
        case 1: return secondary // #6f42c1
        case 2: return primary   // #007bff
        default: return green    // #28a745
        }
    }

    // Kích thước bo góc chuẩn CSS Web
    static let cornerRadius: CGFloat = 15.0             // --radius: 15px
    static let innerCornerRadius: CGFloat = 15.0        // --radius: 15px
    static let bannerCornerRadius: CGFloat = 18.0       // .sleek-top-banner: 18px
    static let videoPhoneOuterRadius: CGFloat = 34.0    // .video-phone-frame: 34px
    static let videoPhoneInnerRadius: CGFloat = 30.0    // .video-phone-inner: 30px
    static let videoPhoneBorderPadding: CGFloat = 4.0   // .video-phone-frame padding: 4px
    static let guideImageBorderPadding: CGFloat = 3.0   // .guide img padding: 3px

    static let pageBackground = SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255)
    static let cardBackground = SwiftUI.Color.white
    static let innerRowBackground = SwiftUI.Color.white
}

// MARK: - 🌈 LỚP NỀN BODY GRADIENT NGANG CỐ ĐỊNH (linear-gradient(to right, #f3e0ff, #e0f7ff))
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
        // Chuẩn CSS: linear-gradient(to right, #f3e0ff, #e0f7ff)
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
}

// MARK: - Hiệu ứng nhấn nút thu nhỏ & nảy lò xo chuẩn Web (.tab-button:active)
private struct CSSBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.24, dampingFraction: 0.70), value: configuration.isPressed)
    }
}

// MARK: - 🌟 SLEEK TOP BANNER ĐẦU TRANG (GIỐNG HỆT 100% `.sleek-top-banner` TRONG MÃ WEB & SOURCESVIEWCONTROLLER)
private struct CSSHeroBannerView: SwiftUI.View {
    let title: String
    let subtitle: String

    var body: some SwiftUI.View {
        VStack(spacing: 4) {
            // .banner-title-row
            HStack(spacing: 9) {
                // .banner-glass-icon (30x30px, border-radius: 10px, border: 1.3px solid rgba(255,255,255,0.7), ngôi sao trắng)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(SwiftUI.Color.white.opacity(0.22))
                        .frame(width: 30, height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(SwiftUI.Color.white.opacity(0.70), lineWidth: 1.3)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 5, x: 0, y: 3)

                    SwiftUI.Image(systemName: "star")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(.white)
                }

                // .sleek-top-banner h1
                SwiftUI.Text(title)
                    .font(.system(size: 21, weight: .heavy))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.22), radius: 4, x: 0, y: 2)
            }

            // .sleek-top-banner p
            SwiftUI.Text(subtitle)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundColor(.white.opacity(0.95))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(
            ZStack {
                // Màu nền dự phòng đảm bảo không bao giờ trong suốt
                CSSTheme.secondary

                // Gradient chuẩn CSS: linear-gradient(125deg, #007bff 0%, #6f42c1 52%, #d600d6 100%)
                CSSTheme.heroGradient

                // Vệt kính chéo chuẩn CSS (.sleek-top-banner::before: skewX(-22deg))
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            SwiftUI.Color.clear,
                            SwiftUI.Color.white.opacity(0.24),
                            SwiftUI.Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.55, height: geo.size.height * 1.6)
                    .rotationEffect(.degrees(-22))
                    .offset(x: -geo.size.width * 0.12, y: -geo.size.height * 0.3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.bannerCornerRadius, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.bannerCornerRadius, style: .continuous)
                .stroke(SwiftUI.Color.white.opacity(0.70), lineWidth: 1.5)
        )
        .shadow(color: CSSTheme.secondary.opacity(0.28), radius: 14, x: 0, y: 8)
    }
}

// MARK: - 🦶 KHUNG FOOTER CUỐI TRANG CHUẨN MÃ WEB (`<footer>`)
private struct WebStyleFooterCardView: SwiftUI.View {
    let text: String

    var body: some SwiftUI.View {
        SwiftUI.Text(text)
            .font(.system(size: 13.5, weight: .semibold))
            .foregroundColor(CSSTheme.dark)
            .multilineTextAlignment(.center)
            .lineSpacing(3)
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(CSSTheme.white)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 16, x: 0, y: 8)
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
            return await Task.detached(priority: .utility) { () -> UIImage? in
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

        // Khoá giao diện Sáng (Light Mode) để chữ đen tuyền luôn hiển thị rõ nét nhất trên nền thẻ trắng
        overrideUserInterfaceStyle = .light

        // 1. Ẩn hoàn toàn tiêu đề và thanh điều hướng giống hệt SourcesViewController
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

        // 2. Đặt lớp nền Gradient ngang cố định toàn màn hình (linear-gradient(to right, #f3e0ff, #e0f7ff))
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
        hostingController.overrideUserInterfaceStyle = .light
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

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ CỐ ĐỊNH
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
            btn.backgroundColor = CSSTheme.uiWhite

            btn.layer.cornerRadius = 10
            btn.layer.borderWidth = 1.5
            btn.layer.borderColor = CSSTheme.uiBorder.cgColor
            btn.layer.shadowColor = CSSTheme.uiBlue.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 6)
            btn.layer.shadowRadius = 10
            btn.layer.shadowOpacity = 0.18

            btn.addTarget(self, action: #selector(handleFloatingBackTap), for: .touchUpInside)
            nav.view.addSubview(btn)

            NSLayoutConstraint.activate([
                btn.leadingAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.leadingAnchor, constant: 12),
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
    @Published var tunnelIP: String = "Chưa kết nối"
    @Published var deviceIP: String = "Chưa kết nối"

    @Published var isCellularOK: Bool = false
    @Published var isWifiActive: Bool = false
    @Published var cellularDetail: String = ""

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
    private var didReceiveCellularMonitorUpdate: Bool = false

    private var usesWifiPath: Bool = false
    private var isWifiPathSatisfied: Bool = false
    private var didReceiveWifiMonitorUpdate: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private var isViewVisible: Bool = false
    private var isChecking: Bool = false
    private var needsAnotherCheck: Bool = false
    private var pendingForceVerify: Bool = false
    private var lastInternalConfigWriteTime: TimeInterval = 0
    private var latestSnapshot: SystemInterfaceSnapshot? = nil

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

    /// Xác định chính xác 100% Dữ liệu di động (4G/5G) đang bật hay tắt (không bị đánh lừa bởi cổng ngầm VoLTE pdp_ip1/pdp_ip2)
    private func resolveCellularActive(snapshot: SystemInterfaceSnapshot) -> Bool {
        if didReceiveCellularMonitorUpdate {
            return usesCellularPath || isCellularPathSatisfied
        }
        return usesCellularPath || isCellularPathSatisfied || snapshot.hasCellularIPv4
    }

    /// Xác định chính xác Wi-Fi đang bật và kết nối hay tắt
    private func resolveWifiActive(snapshot: SystemInterfaceSnapshot) -> Bool {
        if didReceiveWifiMonitorUpdate {
            return usesWifiPath || isWifiPathSatisfied
        }
        return usesWifiPath || isWifiPathSatisfied || snapshot.hasWifiIPv4
    }

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
        self.didAttemptLiveVerifyInCurrentMode = true
        self.lastVerifiedPairingSuccess = true
        self.lastVerifiedModeSignature = ""
        self.isPairingVerifiedError = false
        self.isPairingOK = true
        refreshSnapshotAsyncAndApply()
    }

    init() {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        setupRealtimeListeners()
        refreshSnapshotAsyncAndApply()
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
            if !isWirelessPairingActive {
                Task { await checkAllStatuses(forceVerify: false) }
            } else {
                refreshSnapshotAsyncAndApply()
            }
        }
    }

    /// Quét cổng mạng hoàn toàn trên nhân tiết kiệm điện (.utility), không bao giờ làm khựng Main Thread
    private func refreshSnapshotAsyncAndApply() {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let snap = await Task.detached(priority: .utility) {
                Self.scanSystemInterfaces()
            }.value
            self.latestSnapshot = snap
            self.updateInstantStatus(existingSnapshot: snap)
        }
    }

    private var isWithinInternalWriteCooldown: Bool {
        ( CFAbsoluteTimeGetCurrent() - lastInternalConfigWriteTime ) < 0.8
    }

    private func setupRealtimeListeners() {
        networkChangeSubject
            .debounce(for: .milliseconds(250), scheduler: DispatchQueue.main)
            .sink { [weak self] forceVerify in
                guard let self = self,
                      self.isViewVisible,
                      !self.isWirelessPairingActive,
                      !self.isWithinInternalWriteCooldown else { return }
                Task { @MainActor [weak self] in
                    await self?.checkAllStatuses(forceVerify: forceVerify)
                }
            }
            .store(in: &cancellables)

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let usesCell = (path.status == .satisfied) && path.usesInterfaceType(.cellular)
            let usesWifi = (path.status == .satisfied) && path.usesInterfaceType(.wifi)
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
                if changed {
                    if let snap = self.latestSnapshot {
                        self.updateInstantStatus(existingSnapshot: snap)
                    }
                    if self.isViewVisible && !self.isWirelessPairingActive {
                        self.networkChangeSubject.send(false)
                    }
                }
            }
        }
        pathMonitor.start(queue: monitorQueue)

        cellularMonitor.pathUpdateHandler = { [weak self] path in
            let cellSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let firstUpdate = !self.didReceiveCellularMonitorUpdate
                self.didReceiveCellularMonitorUpdate = true
                guard firstUpdate || self.isCellularPathSatisfied != cellSatisfied else { return }
                self.isCellularPathSatisfied = cellSatisfied
                if let snap = self.latestSnapshot {
                    self.updateInstantStatus(existingSnapshot: snap)
                }
                guard self.isViewVisible, !self.isWirelessPairingActive else { return }
                self.networkChangeSubject.send(false)
            }
        }
        cellularMonitor.start(queue: monitorQueue)

        wifiMonitor.pathUpdateHandler = { [weak self] path in
            let wifiSatisfied = (path.status == .satisfied)
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let firstUpdate = !self.didReceiveWifiMonitorUpdate
                self.didReceiveWifiMonitorUpdate = true
                guard firstUpdate || self.isWifiPathSatisfied != wifiSatisfied else { return }
                self.isWifiPathSatisfied = wifiSatisfied
                if let snap = self.latestSnapshot {
                    self.updateInstantStatus(existingSnapshot: snap)
                }
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
                      !self.isWithinInternalWriteCooldown else { return }
                self.networkChangeSubject.send(false)
            }
            .store(in: &cancellables)

        minimuxerStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      self.isViewVisible,
                      !self.isWirelessPairingActive,
                      !self.isWithinInternalWriteCooldown else { return }
                self.networkChangeSubject.send(false)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self, self.isViewVisible else { return }
                guard !self.isWirelessPairingActive else {
                    self.refreshSnapshotAsyncAndApply()
                    return
                }
                Task { @MainActor [weak self] in
                    await self?.checkAllStatuses(forceVerify: false)
                }
            }
            .store(in: &cancellables)
    }

    struct SystemInterfaceSnapshot: Sendable, Equatable {
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
                        // Chỉ kiểm tra đúng pdp_ip0 (kênh dữ liệu di động chính), bỏ qua pdp_ip1/2/3/4 của VoLTE/IMS
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

        let config = ConnectionConfig.shared
        var didWrite = false
        if config.overrideTunnelPeerIp != "10.7.0.1" {
            config.overrideTunnelPeerIp = "10.7.0.1"
            didWrite = true
        }
        if !config.overrideTunnelPeerReachable {
            config.overrideTunnelPeerReachable = true
            didWrite = true
        }
        if didWrite {
            lastInternalConfigWriteTime = CFAbsoluteTimeGetCurrent()
        }
    }

    func setCellularRefreshEnabled(_ enabled: Bool) {
        guard isCellularRefreshEnabled != enabled || UserDefaults.standard.isCellularRefreshEnabled != enabled else { return }
        lastInternalConfigWriteTime = CFAbsoluteTimeGetCurrent()
        isCellularRefreshEnabled = enabled
        CellularRefreshManager.shared.setEnabled(enabled)
        if let snap = latestSnapshot {
            updateInstantStatus(existingSnapshot: snap)
        } else {
            refreshSnapshotAsyncAndApply()
        }
    }

    func deleteAllPairingFiles() {
        PairingFileManager.shared.resetAllPairingFiles()
        self.hasAnyStoredPairingFile = false
        self.lastVerifiedPairingSuccess = false
        self.lastVerifiedModeSignature = ""
        self.didAttemptLiveVerifyInCurrentMode = false
        self.isPairingVerifiedError = true
        self.isPairingOK = false
        if let snap = latestSnapshot {
            updateInstantStatus(existingSnapshot: snap)
        } else {
            refreshSnapshotAsyncAndApply()
        }
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

    func updateInstantStatus(existingSnapshot: SystemInterfaceSnapshot) {
        let snapshot = existingSnapshot
        self.latestSnapshot = snapshot
        ensureTunnelRoutingPinned(snapshot: snapshot)

        let cellularActive = resolveCellularActive(snapshot: snapshot)
        let wifiActive = resolveWifiActive(snapshot: snapshot)
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
        if isWirelessPairingActive {
            if forceVerify {
                pendingForceVerify = true
            }
            return
        }

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

        let snapshot = await Task.detached(priority: .utility) {
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

        let cellularActive = resolveCellularActive(snapshot: snapshot)
        let wifiActive = resolveWifiActive(snapshot: snapshot)
        let vpnActive = isVpnOK || snapshot.hasActiveLocalDevUtun

        let canVerifyNow = vpnActive && (wifiActive || !cellularActive)

        if canVerifyNow {
            let isStrictLoopbackTestMode = vpnActive && !wifiActive && !cellularActive
            let currentSignature = "\(tunnelIP)|strict:\(isStrictLoopbackTestMode)"
            let signatureChanged = (lastVerifiedModeSignature != currentSignature)

            let shouldPerformHeavyHandshake = forceVerify
                || !didAttemptLiveVerifyInCurrentMode
                || !lastVerifiedPairingSuccess
                || (isStrictLoopbackTestMode && signatureChanged)

            if shouldPerformHeavyHandshake {
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

    var body: some SwiftUI.View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                // Khối Sleek Top Banner chuẩn 100% mã Web & SourcesViewController
                CSSHeroBannerView(
                    title: "SideStore",
                    subtitle: "Kiểm tra kết nối hệ thống, Pairing & tự động làm mới qua 4G"
                )
                .padding(.top, 8)

                systemStatusSection
                shortcutsSection
                automationGuideSection
                shortcutVideoGuideSection

                // Khối <footer> trắng ở cuối trang chuẩn mã Web
                WebStyleFooterCardView(
                    text: "Hệ thống tự động kiểm tra trạng thái kết nối theo thời gian thực\nNhấn vào từng mục trạng thái để xem hướng dẫn chi tiết & cấu hình"
                )
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 40)
        }
        .background(SwiftUI.Color.clear)
        .preferredColorScheme(.light)
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
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showVpnSheet) {
            VpnDetailSheetView(vm: vm)
                .preferredColorScheme(.light)
        }
        .sheet(isPresented: $showCellularSheet) {
            CellularDetailSheetView(vm: vm)
                .preferredColorScheme(.light)
        }
    }

    private var systemStatusSection: some SwiftUI.View {
        let allReady = vm.isPairingOK && vm.isVpnOK && vm.isCellularOK

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
                color: CSSTheme.magenta,
                urlString: "https://www.icloud.com/shortcuts/ee47f3710b02435883faa746c7355236"
            )

            ShortcutLinkRow(
                title: "Phím tắt Bật 4G",
                buttonTitle: "Nhận",
                icon: "antenna.radiowaves.left.and.right",
                color: CSSTheme.secondary,
                urlString: "https://www.icloud.com/shortcuts/10bd8bb0aa1540c4b1221182b835fc43"
            )

            ShortcutLinkRow(
                title: "Tự động làm mới App (6:00 sáng)",
                buttonTitle: "Nhận",
                icon: "clock.arrow.2.circlepath",
                color: CSSTheme.primary,
                urlString: "https://www.icloud.com/shortcuts/56b0ab8cb0984d0b9a98543ac879eeec"
            )

            ShortcutLinkRow(
                title: "Tự động làm mới App (15:00 chiều)",
                buttonTitle: "Nhận",
                icon: "sun.max.circle.fill",
                color: CSSTheme.green,
                urlString: "https://www.icloud.com/shortcuts/9f93051e8bf142258ffc93e08f3c0849"
            )
        }
    }

    private var automationGuideSection: some SwiftUI.View {
        SkySectionCard(
            title: "HƯỚNG DẪN TỰ ĐỘNG HÓA",
            icon: "bell.badge.fill",
            color: CSSTheme.primary
        ) {
            VStack(spacing: 16) {
                RemoteGuideImageView(
                    stepBadge: "BƯỚC 1",
                    accentColor: CSSTheme.magenta,
                    urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2589.jpeg",
                    caption: "Mở Phím Tắt mục Auto Refresh 4G (Auto Refresh 4G 2) và nhấn vào dấu xổ xuống:",
                    loadingText: "Đang tải ảnh...",
                    errorText: "Không tải được ảnh. Vui lòng kiểm tra mạng."
                )

                RemoteGuideImageView(
                    stepBadge: "BƯỚC 2",
                    accentColor: CSSTheme.secondary,
                    urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2588.jpeg",
                    caption: "Bật nút Tự động hóa:",
                    loadingText: "Đang tải ảnh...",
                    errorText: "Không tải được ảnh. Vui lòng kiểm tra mạng."
                )
            }
        }
    }

    private var shortcutVideoGuideSection: some SwiftUI.View {
        SkySectionCard(
            title: "HƯỚNG DẪN VIDEO PHÍM TẮT",
            icon: "play.rectangle.fill",
            color: CSSTheme.primary
        ) {
            VStack(alignment: .leading, spacing: 12) {
                // Khung bước hướng dẫn chuẩn .guide-step-card
                HStack(alignment: .top, spacing: 8) {
                    SwiftUI.Text("•")
                        .font(.system(size: 19, weight: .black))
                        .foregroundColor(CSSTheme.primary)
                        .frame(width: 14, alignment: .center)

                    SwiftUI.Text("Nếu phím tắt tải về không tương thích với phiên bản iOS trên máy của bạn, bạn có thể xem video bên dưới để tự tạo phím tắt.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(CSSTheme.pureBlack)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CSSTheme.white)
                .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                        .stroke(CSSTheme.border, lineWidth: 2.0)
                )
                .shadow(color: CSSTheme.primary.opacity(0.18), radius: 10, x: 0, y: 6)

                // Đường kẻ <hr class="tab-separator"> + Tiêu đề <h3>▶ HƯỚNG DẪN VIDEO</h3> chuẩn mã Web
                Rectangle()
                    .fill(CSSTheme.border)
                    .frame(height: 1.0)
                    .padding(.top, 4)

                SwiftUI.Text("▶ HƯỚNG DẪN VIDEO")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(CSSTheme.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 2)

                // Khung Video chuẩn .video-box-wrap + .video-phone-frame + .video-phone-inner
                IPhone14VerticalVideoFrameView(
                    videoID: "j0Ng2cYvd1o"
                )
            }
        }
    }
}

// MARK: - 🎬 KHUNG VIDEO CHUẨN 100% MÃ WEB (.video-box-wrap + .video-phone-frame + .video-phone-inner)
struct IPhone14VerticalVideoFrameView: SwiftUI.View {
    let videoID: String
    @State private var isVisibleOnScreen: Bool = false
    @State private var shouldMountWebView: Bool = false
    @State private var mountTask: Task<Void, Never>? = nil

    var body: some SwiftUI.View {
        // 1. .video-box-wrap (padding: 10px; background: #fff; border: 2px solid #e9ecef; border-radius: 15px; box-shadow: 0 10px 20px rgba(111,66,193,.22))
        VStack(spacing: 0) {
            // 2. .video-phone-frame (padding: 4px; border-radius: 34px; background: linear-gradient(135deg, var(--blue), var(--purple)))
            VStack(spacing: 0) {
                // 3. .video-phone-inner (aspect-ratio: 9 / 19.5; background: #000; border-radius: 30px; overflow: hidden)
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
                .clipShape(RoundedRectangle(cornerRadius: CSSTheme.videoPhoneInnerRadius, style: .continuous))
            }
            .padding(CSSTheme.videoPhoneBorderPadding)
            .background(CSSTheme.mediaFrameBorderGradient)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.videoPhoneOuterRadius, style: .continuous))
        }
        .padding(10)
        .background(CSSTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(CSSTheme.border, lineWidth: 2.0)
        )
        .shadow(color: CSSTheme.secondary.opacity(0.22), radius: 14, x: 0, y: 8)
        .onAppear {
            isVisibleOnScreen = true
            if !shouldMountWebView {
                mountTask?.cancel()
                mountTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    guard !Task.isCancelled, isVisibleOnScreen else { return }
                    shouldMountWebView = true
                }
            }
        }
        .onDisappear {
            isVisibleOnScreen = false
            mountTask?.cancel()
            mountTask = nil
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

// MARK: - 🗂️ CẤU TRÚC SECTION HEADER (`.features h2`) + KHUNG TRẮNG (`.tab-container`) CHUẨN 100% MÃ WEB
struct SkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil
    var footerText: String? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .center, spacing: 10) {
            // Tiêu đề `.features h2` căn giữa + Gạch chân xanh 60x3pt ở chính giữa chuẩn mã Web
            SectionHeaderView(
                title: title,
                icon: icon,
                color: color,
                statusOK: statusOK,
                trailingView: trailingView
            )
            .padding(.top, 2)

            // Khối `.tab-container` trắng bo góc 15px, đổ bóng chuẩn CSS: box-shadow: 0 8px 20px rgba(0,0,0,.1)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 8)

            // Chú thích chân mục nếu có
            if let footerText = footerText {
                SwiftUI.Text(footerText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CSSTheme.dark)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
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
        VStack(alignment: .center, spacing: 8) {
            HStack(spacing: 6) {
                SwiftUI.Text(title.uppercased())
                    .font(.system(size: 19, weight: .heavy))
                    .foregroundColor(CSSTheme.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                if let statusOK = statusOK {
                    SwiftUI.Image(systemName: statusOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(statusOK ? CSSTheme.green : CSSTheme.red)
                        .animation(.spring(), value: statusOK)
                }

                if let trailingView = trailingView {
                    trailingView
                }
            }

            // Thanh gạch chân xanh 60x3pt nằm chính giữa chuẩn `.features h2::after` trong mã Web
            RoundedRectangle(cornerRadius: 1.5)
                .fill(CSSTheme.primary)
                .frame(width: 60, height: 3.0)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - 🔘 NÚT KIỂM TRA TRẠNG THÁI CHUẨN `.tab-button` (VIỀN 2PX #E9ECEF + HUY HIỆU 46x46 + ĐỔ BÓNG MÀU)
struct CheckItemButton: SwiftUI.View {
    let title: String
    let subtitle: String
    let icon: String
    let visualState: CheckItemVisualState
    let action: () -> Void

    private var accentColor: SwiftUI.Color {
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

    var body: some SwiftUI.View {
        SwiftUI.Button(action: action) {
            HStack(spacing: 11) {
                // Huy hiệu `.tab-num-badge` 46x46px, bo góc 12px, nền màu chủ đạo + đổ bóng màu
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accentColor)
                        .frame(width: 46, height: 46)
                        .shadow(color: accentColor.opacity(0.28), radius: 7, x: 0, y: 4)

                    VStack(spacing: 1) {
                        SwiftUI.Text("✦")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundColor(.white.opacity(0.90))
                        SwiftUI.Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    // .tab-card-title (15.8px, bold, #000)
                    SwiftUI.Text(title)
                        .font(.system(size: 15.8, weight: .bold))
                        .foregroundColor(CSSTheme.pureBlack)

                    // Huy hiệu nhỏ `.tab-pill` báo trạng thái
                    HStack(spacing: 4) {
                        SwiftUI.Text("• " + subtitle)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(accentColor)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(CSSTheme.light)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1.0)
                    )
                }

                Spacer()

                SwiftUI.Image(systemName: trailingStatusIconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accentColor)
                    .animation(.spring(), value: visualState)

                SwiftUI.Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(CSSTheme.secondary)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 12)
            .background(CSSTheme.white)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.border, lineWidth: 2.0)
            )
            .shadow(color: accentColor.opacity(0.22), radius: 11, x: 0, y: 6)
        }
        .buttonStyle(CSSBounceButtonStyle())
    }
}

struct CellularRefreshToggleRow: SwiftUI.View {
    let title: String
    let onText: String
    let offText: String
    @Binding var isOn: Bool

    private var accentColor: SwiftUI.Color {
        isOn ? CSSTheme.primary : CSSTheme.secondary
    }

    var body: some SwiftUI.View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accentColor)
                    .frame(width: 46, height: 46)
                    .shadow(color: accentColor.opacity(0.28), radius: 7, x: 0, y: 4)

                VStack(spacing: 1) {
                    SwiftUI.Text("✦")
                        .font(.system(size: 9.5, weight: .heavy))
                        .foregroundColor(.white.opacity(0.90))
                    SwiftUI.Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(CSSTheme.pureBlack)

                SwiftUI.Text("• " + (isOn ? onText : offText))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.5)
                    .background(CSSTheme.light)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1.0)
                    )
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(CSSTheme.primary)
                .shadow(color: CSSTheme.primary.opacity(0.24), radius: 5, x: 0, y: 3)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 12)
        .background(CSSTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(CSSTheme.border, lineWidth: 2.0)
        )
        .shadow(color: accentColor.opacity(0.22), radius: 11, x: 0, y: 6)
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
            HStack(spacing: 11) {
                // Huy hiệu `.tab-num-badge` 46x46px chuẩn mã Web
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(color)
                        .frame(width: 46, height: 46)
                        .shadow(color: color.opacity(0.28), radius: 7, x: 0, y: 4)

                    VStack(spacing: 1) {
                        SwiftUI.Text("✦")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundColor(.white.opacity(0.90))
                        SwiftUI.Image(systemName: icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                SwiftUI.Text(title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(CSSTheme.pureBlack)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Nút hành động chuẩn `.topic-id-badge` / `.btn-primary`
                HStack(spacing: 4) {
                    SwiftUI.Text(buttonTitle)
                        .font(.system(size: 12.5, weight: .heavy))
                    SwiftUI.Image(systemName: "arrow.up.right")
                        .font(.system(size: 10.5, weight: .heavy))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(color)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .shadow(color: color.opacity(0.26), radius: 5, x: 0, y: 3)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 12)
            .background(CSSTheme.white)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.border, lineWidth: 2.0)
            )
            .shadow(color: color.opacity(0.22), radius: 11, x: 0, y: 6)
        }
        .buttonStyle(CSSBounceButtonStyle())
    }
}

// MARK: - 🖼️ KHUNG ẢNH HƯỚNG DẪN CHUẨN `.guide-step-card` + `.guide img` (PADDING 3PX GRADIENT 3 MÀU + BÓNG SÂU)
struct RemoteGuideImageView: SwiftUI.View {
    var stepBadge: String? = nil
    var accentColor: SwiftUI.Color = CSSTheme.primary
    let urlString: String
    let caption: String
    let loadingText: String
    let errorText: String

    @State private var uiImage: UIImage? = nil
    @State private var didFail: Bool = false

    private let outerRadius: CGFloat = CSSTheme.cornerRadius
    private let innerRadius: CGFloat = CSSTheme.cornerRadius - CSSTheme.guideImageBorderPadding

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 10) {
            // Khung bước hướng dẫn chuẩn `.guide-step-card`
            VStack(alignment: .leading, spacing: 6) {
                if let badge = stepBadge {
                    HStack(spacing: 5) {
                        SwiftUI.Text("✦ " + badge)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(accentColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(CSSTheme.light)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1.0)
                    )
                }

                HStack(alignment: .top, spacing: 8) {
                    SwiftUI.Text("•")
                        .font(.system(size: 19, weight: .black))
                        .foregroundColor(accentColor)
                        .frame(width: 14, alignment: .center)

                    SwiftUI.Text(caption)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(CSSTheme.pureBlack)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSTheme.white)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.border, lineWidth: 2.0)
            )
            .shadow(color: accentColor.opacity(0.18), radius: 10, x: 0, y: 6)

            // Khung ảnh chuẩn CSS `.guide img`: padding: 3px; background: linear-gradient(135deg, var(--blue), var(--purple), #f0f); border-radius: 15px; box-shadow: 0 8px 22px rgba(0,0,0,.35)
            if let image = uiImage {
                VStack(spacing: 0) {
                    SwiftUI.Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .background(SwiftUI.Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                }
                .padding(CSSTheme.guideImageBorderPadding)
                .background(CSSTheme.guideImageBorderGradient)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
            } else if didFail {
                VStack(spacing: 8) {
                    SwiftUI.Image(systemName: "wifi.exclamationmark")
                        .font(.title2)
                        .foregroundColor(CSSTheme.primary)
                    SwiftUI.Text(errorText)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(CSSTheme.pureBlack)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(CSSTheme.white)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                .padding(CSSTheme.guideImageBorderPadding)
                .background(CSSTheme.guideImageBorderGradient)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(CSSTheme.primary)
                    SwiftUI.Text(loadingText)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(CSSTheme.pureBlack)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(CSSTheme.white)
                .clipShape(RoundedRectangle(cornerRadius: innerRadius, style: .continuous))
                .padding(CSSTheme.guideImageBorderPadding)
                .background(CSSTheme.guideImageBorderGradient)
                .clipShape(RoundedRectangle(cornerRadius: outerRadius, style: .continuous))
                .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
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

// MARK: - 🧭 THANH TOP BACK ROW TRONG CÁC SHEET CHI TIẾT (GIỐNG HỆT `.top-back-row` TRONG MÃ WEB)
private struct SheetTopBackRowView: SwiftUI.View {
    let badgeText: String
    let onClose: () -> Void

    var body: some SwiftUI.View {
        HStack {
            // Nút `.back-clean-btn`
            SwiftUI.Button(action: onClose) {
                SwiftUI.Text("‹ Quay lại danh mục")
                    .font(.system(size: 13.5, weight: .heavy))
                    .foregroundColor(CSSTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(CSSTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 1.5)
                    )
                    .shadow(color: CSSTheme.primary.opacity(0.18), radius: 8, x: 0, y: 5)
            }
            .buttonStyle(CSSBounceButtonStyle())

            Spacer()

            // Huy hiệu `.topic-id-badge`
            SwiftUI.Text("✦ " + badgeText)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(CSSTheme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(CSSTheme.badgeGreenBorder, lineWidth: 1.5)
                )
                .shadow(color: CSSTheme.primary.opacity(0.22), radius: 6, x: 0, y: 4)
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

    private func closeSheet() {
        if wirelessVM.isAdvertising {
            wirelessVM.togglePairing()
        }
        vm.setWirelessPairingActive(false)
        dismiss()
    }

    var body: some SwiftUI.View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SheetTopBackRowView(badgeText: "PAIRING FILE") {
                    closeSheet()
                }
                .padding(.top, 8)

                CSSHeroBannerView(
                    title: "Kiểm Tra & Cài Đặt Pairing",
                    subtitle: "Ghép nối trực tiếp trên iOS 27 hoặc nạp tệp Pairing từ máy tính"
                )

                statusHeaderCard
                verificationAdviceCard

                if let banner = statusBannerMessage {
                    HStack(spacing: 10) {
                        SwiftUI.Image(systemName: vm.isPairingOK ? "checkmark.seal.fill" : "info.circle.fill")
                            .foregroundColor(vm.isPairingOK ? CSSTheme.green : CSSTheme.primary)
                        SwiftUI.Text(banner)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CSSTheme.pureBlack)
                        Spacer()
                    }
                    .padding(12)
                    .background(CSSTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 2.0)
                    )
                    .shadow(color: (vm.isPairingOK ? CSSTheme.green : CSSTheme.primary).opacity(0.22), radius: 10, x: 0, y: 6)
                }

                ios27DirectPairingCard
                pcPairingGuideCard

                // Nút `.btn-tertiary` quay lại ở cuối bài giống hệt mã Web
                SwiftUI.Button {
                    closeSheet()
                } label: {
                    SwiftUI.Text("‹ Quay Lại Trang Kiểm Tra Hệ Thống")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CSSTheme.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(CSSBounceButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)
        }
        .background(CSSTheme.pageBackgroundGradient.ignoresSafeArea())
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
            pairingMgmtVM.handleImportResult(result)
            Task { @MainActor in
                let proto = PairingFileManager.shared.persistedActiveProtocol
                    ?? PairingFileManager.shared.preferredProtocol
                    ?? .rppairing
                try? await minimuxerSwitchPairingProtocol(to: proto)
                if case .success = result {
                    vm.markPairingVerifiedImmediately()
                    statusBannerMessage = "Đã nạp tệp Pairing thành công!"
                }
                await vm.checkAllStatuses(forceVerify: true)
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
        .preferredColorScheme(.light)
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(badgeColor)
                    .frame(width: 46, height: 46)
                    .shadow(color: badgeColor.opacity(0.28), radius: 7, x: 0, y: 4)
                SwiftUI.Image(systemName: badgeIcon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 4) {
                SwiftUI.Text(headerTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CSSTheme.pureBlack)

                if state != .actionRequired && !vm.pairingProtocol.isEmpty {
                    SwiftUI.Text(vm.pairingProtocol)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(badgeColor)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(13)
        .background(CSSTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(CSSTheme.border, lineWidth: 2.0)
        )
        .shadow(color: badgeColor.opacity(0.22), radius: 12, x: 0, y: 6)
    }

    private var verificationAdviceCard: some SwiftUI.View {
        SkySectionCard(
            title: "3 BƯỚC KIỂM TRA PAIRING CHÍNH XÁC",
            icon: "checkmark.shield.fill",
            color: CSSTheme.primary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                GuideStepRow(
                    num: "1",
                    colorIndex: 0,
                    title: "Kết nối mạng trên iPhone",
                    text: LocalizedStringKey("Đảm bảo iPhone của bạn đang có kết nối **Wi-Fi** hoặc **4G**.")
                )

                GuideStepRow(
                    num: "2",
                    colorIndex: 1,
                    title: "Bật LocalDevVPN",
                    text: LocalizedStringKey("Mở ứng dụng **LocalDevVPN** và bật kết nối VPN lên.")
                )

                GuideStepRow(
                    num: "3",
                    colorIndex: 2,
                    title: "Tắt cả Wi-Fi và 4G (Chỉ bật LocalDevVPN)",
                    text: LocalizedStringKey("Tắt cả **Wi-Fi** và **4G**, chỉ để lại mỗi **LocalDevVPN** đang bật.")
                )
            }

            // Khung thông báo chuẩn `.btn-outline-glow` trong mã Web
            SwiftUI.Text("💡 Xong 3 bước trên, nhìn lên mục Đang Chờ Xác Minh Pairing ở phía trên sẽ tự động hiện Tích Xanh báo đang hoạt động tốt hoặc Tích Đỏ đã bị lỗi / cần cài lại.")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(CSSTheme.primary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .center)
                .background(CSSTheme.white)
                .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                        .stroke(CSSTheme.border, lineWidth: 2.0)
                )
                .shadow(color: CSSTheme.primary.opacity(0.24), radius: 10, x: 0, y: 6)
                .padding(.top, 2)
        }
    }

    private var ios27DirectPairingCard: some SwiftUI.View {
        SkySectionCard(
            title: "PHẦN 1: DÀNH CHO IOS 27",
            icon: "iphone.radiowaves.left.and.right",
            color: CSSTheme.primary
        ) {
            VStack(alignment: .leading, spacing: 10) {
                GuideStepRow(
                    num: "1",
                    colorIndex: 0,
                    title: "Bắt đầu phát tín hiệu Pairing",
                    text: LocalizedStringKey("Nhấn vào nút **\"Cài Pairing lên iPhone\"** ở bên dưới để ứng dụng phát tín hiệu ghép đôi.")
                )

                GuideStepRow(
                    num: "2",
                    colorIndex: 1,
                    title: "Mở Cài đặt Nhà phát triển",
                    text: LocalizedStringKey("Thoát ra màn hình chính (không vuốt tắt ứng dụng này), mở **Cài đặt (Settings)** → **Quyền riêng tư & Bảo mật (Privacy & Security)** → kéo xuống cuối chọn **Chế độ nhà phát triển (Developer Mode)**.")
                )

                GuideStepRow(
                    num: "3",
                    colorIndex: 2,
                    title: "Nhập mã PIN 6 chữ số (Tự động kích hoạt)",
                    text: LocalizedStringKey("Trong mục Chế độ nhà phát triển, nếu có “Thiết bị đã ghép đôi” cũ thì xoá đi, sau đó nhấn vào dòng **Pair with SideStore** và nhập mật khẩu iPhone. Quay lại app này xem **mã 6 chữ số**, rồi sang **Cài đặt** nhập vào và nhấn **Ghép đôi**. Ngay sau khi ghép đôi xong, ứng dụng sẽ **tự động nạp và kích hoạt Pairing luôn**!")
                )

                GuideStepRow(
                    num: "4",
                    colorIndex: 3,
                    title: "Lưu tệp Pairing dự phòng (Khuyên dùng)",
                    text: LocalizedStringKey("Sau khi ghép nối xong, bạn **không cần nhập lại tệp nữa**. Tuy nhiên, hãy nhấn nút **“Xuất tệp Pairing (Lưu dự phòng)”** (màu xanh lá) → chọn **Lưu vào Tệp (Save to Files)** để cất giữ dự phòng cho những lần cài lại app sau này.")
                )
            }

            Rectangle()
                .fill(CSSTheme.border)
                .frame(height: 1.0)
                .padding(.vertical, 4)

            VStack(spacing: 10) {
                if let pin = wirelessVM.pinCode {
                    VStack(spacing: 6) {
                        SwiftUI.Text("MÃ GHÉP NỐI 6 CHỮ SỐ")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(CSSTheme.primary)
                        SwiftUI.Text(pin)
                            .font(.system(size: 30, weight: .heavy, design: .monospaced))
                            .tracking(6)
                            .foregroundColor(CSSTheme.pureBlack)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 18)
                            .background(CSSTheme.light)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(CSSTheme.border, lineWidth: 2.0)
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 4)
                }

                if let errorMsg = wirelessVM.errorMessage {
                    SwiftUI.Text(errorMsg)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(CSSTheme.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Nút `.btn-primary` chuẩn CSS
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
                            .font(.system(size: 16.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Group {
                            if wirelessVM.isAdvertising {
                                CSSTheme.red
                            } else {
                                CSSTheme.primaryButtonGradient
                            }
                        }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
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
                            statusBannerMessage = "Vui lòng thực hiện Bước 2 & Bước 3 (nhập xong 6 chữ số trong Cài đặt → Chế độ nhà phát triển) trước khi lưu tệp dự phòng."
                        }
                    } label: {
                        HStack(spacing: 8) {
                            SwiftUI.Image(systemName: "square.and.arrow.up.fill")
                                .font(.system(size: 17, weight: .bold))
                            SwiftUI.Text("Xuất tệp Pairing (Lưu dự phòng)")
                                .font(.system(size: 16.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(installedPairingURLForExport != nil ? CSSTheme.green : CSSTheme.green.opacity(0.65))
                        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
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
                            .font(.system(size: 16.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CSSTheme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(CSSBounceButtonStyle())

                SwiftUI.Button {
                    showDeleteConfirmAlert = true
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "trash.fill")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Xoá tệp Pairing")
                            .font(.system(size: 16.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CSSTheme.red)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(CSSBounceButtonStyle())
            }
        }
    }

    private var pcPairingGuideCard: some SwiftUI.View {
        SkySectionCard(
            title: "PHẦN 2: DƯỚI IOS 27 (PC / MAC)",
            icon: "laptopcomputer.and.iphone",
            color: CSSTheme.primary
        ) {
            // Hộp chuẩn bị chung theo chuẩn `.guide-step-card`
            HStack(alignment: .top, spacing: 8) {
                SwiftUI.Text("•")
                    .font(.system(size: 19, weight: .black))
                    .foregroundColor(CSSTheme.primary)
                    .frame(width: 14, alignment: .center)

                SwiftUI.Text(LocalizedStringKey("**Chuẩn bị chung:** Trên Windows cần cài đặt **iTunes** & **iCloud** bản chính chủ từ Apple (không tải bản Microsoft Store). Cắm cáp kết nối iPhone vào máy tính, mở khóa màn hình iPhone và nhấn **Tin cậy (Trust)** + nhập mật khẩu màn hình. Hãy chọn **1 trong 3 công cụ** dưới đây:"))
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(CSSTheme.pureBlack)
                    .lineSpacing(2.5)
            }
            .padding(12)
            .background(CSSTheme.white)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.border, lineWidth: 2.0)
            )
            .shadow(color: CSSTheme.primary.opacity(0.18), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 10) {
                GuideStepRow(
                    num: "1",
                    colorIndex: 0,
                    title: "Cách 1: Dùng idevice_pair (Khuyên dùng - Hỗ trợ cả nạp thẳng & xuất tệp)",
                    text: LocalizedStringKey("• Mở phần mềm **idevice_pair** trên máy tính và chọn iPhone của bạn.\n• **Cách nạp thẳng vào ứng dụng:** Trong mục ứng dụng trên **idevice_pair**, chọn **SideStore** hoặc **LiveContainer** rồi nhấn nút **Load** (hoặc **Install Pairing File**). Phần mềm sẽ tự động chép thẳng tệp Pairing vào trong ứng dụng trên iPhone mà không cần làm thủ công.\n• **Cách xuất ra tệp `.mobiledevicepairing` dự phòng:** Nhấn nút **Generate** rồi chọn **Export / Save** để lưu tệp có đuôi **`.mobiledevicepairing`** ra máy tính. Gửi tệp này sang iPhone (qua Zalo, AirDrop, iCloud Drive), chọn **Lưu vào Tệp** rồi nhấn nút **“Nhập tệp Pairing”** ở dưới.")
                )

                GuideStepRow(
                    num: "2",
                    colorIndex: 1,
                    title: "Cách 2: Dùng jitterbugpair (Công cụ xuất tệp `.mobiledevicepairing` ra máy tính)",
                    text: LocalizedStringKey("• Tải và giải nén **jitterbugpair** (trên Windows/macOS/Linux).\n• Giữ màn hình iPhone luôn sáng và mở khóa, sau đó chạy file **`jitterbugpair.exe`** (trên Windows) hoặc chạy **`./jitterbugpair`** trong Terminal (trên Mac).\n• Công cụ sẽ tự động xuất ra một tệp có tên dạng **`<UDID>.mobiledevicepairing`** nằm ngay trong cùng thư mục chứa **jitterbugpair** (công cụ này chỉ xuất ra tệp chứ không tự chép vào app).\n• Gửi tệp **`.mobiledevicepairing`** đó sang iPhone → chọn **Lưu vào Tệp (Save to Files)** → nhấn nút **“Nhập tệp Pairing”** bên dưới để nạp vào ứng dụng.")
                )

                GuideStepRow(
                    num: "3",
                    colorIndex: 2,
                    title: "Cách 3: Dùng iLoader (Cài đặt tự động vào ứng dụng trên iPhone)",
                    text: LocalizedStringKey("• Mở phần mềm **iLoader** trên máy tính, đăng nhập hoặc kết nối với iPhone đã nhấn Tin cậy.\n• **iLoader** chủ yếu hỗ trợ tính năng **Tự động tạo và nạp trực tiếp (Inject) Pairing File** vào **SideStore / LiveContainer** thông qua tùy chọn **Generate / Place Pairing File** ngay trong giao diện quản lý thiết bị.\n• Sau khi iLoader báo hoàn tất trên máy tính, hãy mở lại ứng dụng này trên iPhone để hệ thống tự nhận diện.")
                )
            }

            Rectangle()
                .fill(CSSTheme.border)
                .frame(height: 1.0)
                .padding(.vertical, 4)

            VStack(spacing: 10) {
                SwiftUI.Button {
                    pairingMgmtVM.promptImport(for: .rppairing)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "folder.fill.badge.plus")
                            .font(.system(size: 17, weight: .bold))
                        SwiftUI.Text("Nhập tệp Pairing (Từ ứng dụng Tệp)")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(CSSTheme.primaryButtonGradient)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
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
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(CSSBounceButtonStyle())
            }
        }
    }
}

// MARK: - 📝 HÀNG BƯỚC HƯỚNG DẪN CHUẨN `.guide-step-card` (VIỀN 2PX #E9ECEF + CHẤM TRÒN 4 MÀU LUÂN PHIÊN)
struct GuideStepRow: SwiftUI.View {
    let num: String
    var colorIndex: Int = 0
    var title: String? = nil
    let text: LocalizedStringKey

    private var accentColor: SwiftUI.Color {
        if let parsed = Int(num), parsed > 0 {
            return CSSTheme.tabAccentColor(for: parsed - 1)
        }
        return CSSTheme.tabAccentColor(for: colorIndex)
    }

    var body: some SwiftUI.View {
        HStack(alignment: .top, spacing: 8) {
            SwiftUI.Text("•")
                .font(.system(size: 19, weight: .black))
                .foregroundColor(accentColor)
                .frame(width: 14, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                if let title = title {
                    SwiftUI.Text("Bước \(num): \(title)")
                        .font(.system(size: 15.2, weight: .bold))
                        .foregroundColor(CSSTheme.pureBlack)
                }
                SwiftUI.Text(text)
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundColor(CSSTheme.pureBlack)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(CSSTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(CSSTheme.border, lineWidth: 2.0)
        )
        .shadow(color: accentColor.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

struct VpnDetailSheetView: SwiftUI.View {
    @ObservedObject var vm: SystemCheckViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SheetTopBackRowView(badgeText: "LOCALDEVVPN") {
                    dismiss()
                }
                .padding(.top, 8)

                CSSHeroBannerView(
                    title: "Kiểm Tra LocalDevVPN",
                    subtitle: "Đường hầm mạng nội bộ giúp ký và làm mới ứng dụng ngay trên iPhone"
                )

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(vm.isVpnOK ? CSSTheme.green : CSSTheme.red)
                            .frame(width: 46, height: 46)
                            .shadow(color: (vm.isVpnOK ? CSSTheme.green : CSSTheme.red).opacity(0.28), radius: 7, x: 0, y: 4)
                        SwiftUI.Image(systemName: vm.isVpnOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        SwiftUI.Text(vm.isVpnOK
                                     ? "LocalDevVPN Đang Ổn Định"
                                     : "LocalDevVPN Chưa Kết Nối")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(CSSTheme.pureBlack)
                        SwiftUI.Text("Hãy bật công tắc VPN trong ứng dụng LocalDevVPN.")
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(CSSTheme.dark)
                    }
                    Spacer()
                }
                .padding(13)
                .background(CSSTheme.white)
                .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                        .stroke(CSSTheme.border, lineWidth: 2.0)
                )
                .shadow(color: (vm.isVpnOK ? CSSTheme.green : CSSTheme.red).opacity(0.22), radius: 12, x: 0, y: 6)

                SkySectionCard(
                    title: "THÔNG SỐ KẾT NỐI HIỆN TẠI",
                    icon: "network",
                    color: CSSTheme.primary
                ) {
                    HStack {
                        SwiftUI.Text("• Tunnel IP")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CSSTheme.pureBlack)
                        Spacer()
                        SwiftUI.Text(vm.tunnelIP)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(CSSTheme.primary)
                    }
                    .padding(12)
                    .background(CSSTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 2.0)
                    )
                    .shadow(color: CSSTheme.primary.opacity(0.16), radius: 8, x: 0, y: 5)

                    HStack {
                        SwiftUI.Text("• Device IP")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CSSTheme.pureBlack)
                        Spacer()
                        SwiftUI.Text(vm.deviceIP)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundColor(CSSTheme.secondary)
                    }
                    .padding(12)
                    .background(CSSTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 2.0)
                    )
                    .shadow(color: CSSTheme.secondary.opacity(0.16), radius: 8, x: 0, y: 5)
                }

                SkySectionCard(
                    title: "CẤU HÌNH KHUYÊN DÙNG IOS 27",
                    icon: "lightbulb.fill",
                    color: CSSTheme.primary
                ) {
                    HStack(alignment: .top, spacing: 8) {
                        SwiftUI.Text("•")
                            .font(.system(size: 19, weight: .black))
                            .foregroundColor(CSSTheme.magenta)
                            .frame(width: 14, alignment: .center)

                        SwiftUI.Text("Nếu dùng iOS 27 và bản LiveContainer+SideStore này, hãy đặt IP trong LocalDevVPN theo thông số sau để kết nối nhanh nhất:")
                            .font(.system(size: 14.5, weight: .medium))
                            .foregroundColor(CSSTheme.pureBlack)
                            .lineSpacing(2.5)
                    }
                    .padding(12)
                    .background(CSSTheme.white)
                    .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                            .stroke(CSSTheme.border, lineWidth: 2.0)
                    )
                    .shadow(color: CSSTheme.magenta.opacity(0.16), radius: 8, x: 0, y: 5)

                    CopyableIPCard(
                        label: "Tunnel IP",
                        value: "10.7.1.1/32",
                        copyText: "Sao chép",
                        copiedText: "Đã chép",
                        accentColor: CSSTheme.primary
                    )
                    CopyableIPCard(
                        label: "Device IP",
                        value: "10.7.0.1/32",
                        copyText: "Sao chép",
                        copiedText: "Đã chép",
                        accentColor: CSSTheme.secondary
                    )
                }

                SwiftUI.Button {
                    dismiss()
                } label: {
                    SwiftUI.Text("‹ Quay Lại Trang Kiểm Tra Hệ Thống")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CSSTheme.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(CSSBounceButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)
        }
        .background(CSSTheme.pageBackgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

struct CopyableIPCard: SwiftUI.View {
    let label: String
    let value: String
    let copyText: String
    let copiedText: String
    var accentColor: SwiftUI.Color = CSSTheme.primary
    @State private var copied = false
    @State private var resetTask: Task<Void, Never>? = nil

    var body: some SwiftUI.View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(accentColor)
                SwiftUI.Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(CSSTheme.pureBlack)
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
                    .font(.system(size: 13, weight: .heavy))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(copied ? CSSTheme.green : accentColor)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: (copied ? CSSTheme.green : accentColor).opacity(0.25), radius: 5, x: 0, y: 3)
            }
            .buttonStyle(CSSBounceButtonStyle())
        }
        .padding(12)
        .background(CSSTheme.white)
        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(CSSTheme.border, lineWidth: 2.0)
        )
        .shadow(color: accentColor.opacity(0.18), radius: 10, x: 0, y: 6)
    }
}

struct CellularDetailSheetView: SwiftUI.View {
    @ObservedObject var vm: SystemCheckViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some SwiftUI.View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SheetTopBackRowView(badgeText: "MẠNG 4G / 5G") {
                    dismiss()
                }
                .padding(.top, 8)

                CSSHeroBannerView(
                    title: "Mạng 4G / Di Động",
                    subtitle: "Cài đặt và tự động gia hạn ứng dụng trực tiếp qua 4G/5G không cần Wi-Fi"
                )

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(vm.isCellularOK ? CSSTheme.green : CSSTheme.red)
                            .frame(width: 46, height: 46)
                            .shadow(color: (vm.isCellularOK ? CSSTheme.green : CSSTheme.red).opacity(0.28), radius: 7, x: 0, y: 4)
                        SwiftUI.Image(systemName: vm.isCellularOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        SwiftUI.Text(vm.isCellularOK
                                     ? "Mạng 4G/Di Động Ổn Định"
                                     : "Mạng 4G/Di Động Đang Tắt")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(CSSTheme.pureBlack)
                        SwiftUI.Text(vm.cellularDetail)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(CSSTheme.dark)
                    }
                    Spacer()
                }
                .padding(13)
                .background(CSSTheme.white)
                .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                        .stroke(CSSTheme.border, lineWidth: 2.0)
                )
                .shadow(color: (vm.isCellularOK ? CSSTheme.green : CSSTheme.red).opacity(0.22), radius: 12, x: 0, y: 6)

                SkySectionCard(
                    title: "CÀI & GIA HẠN APP QUA 4G + VPN",
                    icon: "antenna.radiowaves.left.and.right.circle.fill",
                    color: CSSTheme.primary
                ) {
                    GuideStepRow(
                        num: "1",
                        colorIndex: 0,
                        title: "Không cần Wi-Fi",
                        text: LocalizedStringKey("Cài đặt IPA và làm mới ứng dụng trực tiếp qua **4G/5G + LocalDevVPN**.")
                    )

                    GuideStepRow(
                        num: "2",
                        colorIndex: 1,
                        title: "Tự động hóa mỗi ngày",
                        text: LocalizedStringKey("Kết hợp phím tắt làm mới lúc **6:00 sáng** hoặc **15:00 chiều** để tự động gia hạn ứng dụng mỗi ngày.")
                    )
                }

                SwiftUI.Button {
                    dismiss()
                } label: {
                    SwiftUI.Text("‹ Quay Lại Trang Kiểm Tra Hệ Thống")
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(CSSTheme.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 5)
                }
                .buttonStyle(CSSBounceButtonStyle())
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 30)
        }
        .background(CSSTheme.pageBackgroundGradient.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}
