
//
//  NewsViewController.swift
//  AltStore
//

@preconcurrency import UIKit
import SwiftUI
import WebKit
import Combine
import ImageIO

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI CÁC MÀN HÌNH TRƯỚC & CHỮ ĐEN TUYỀN)
private enum CSSTheme {
    // UIKit Colors (Dùng cho ViewController & Lớp nền Gradient cố định)
    static let uiWhite = UIColor.white
    static let uiBorder = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0) // #dce2ec
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

    /// Màu Gradient Hồng cho Icon tiêu đề "Tổng quan & Tính năng" (Đồng bộ 100% với SourcesViewController)
    static let pinkGradientStart = SwiftUI.Color(red: 255/255, green: 90/255, blue: 165/255) // #ff5aa5
    static let pinkGradientEnd = SwiftUI.Color(red: 236/255, green: 38/255, blue: 143/255)   // #ec268f

    /// Màu Đen Tuyền (#000000) cho toàn bộ chữ chính và chữ nhỏ giúp độ tương phản tuyệt đối, cực kỳ dễ đọc
    static let pureBlack = SwiftUI.Color(red: 0/255, green: 0/255, blue: 0/255)        // #000000
    static let darkText = SwiftUI.Color(red: 0/255, green: 0/255, blue: 0/255)         // #000000
    static let subText = SwiftUI.Color(red: 0/255, green: 0/255, blue: 0/255)          // #000000

    // Nền Gradient (#f3e0ff -> #e0f7ff) chéo từ góc trên trái xuống góc dưới phải giống hệt các tab khác
    static let bgGradientStart = SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255)
    static let bgGradientEnd = SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)

    static var pageBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [bgGradientStart, bgGradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,193,.92)) đồng bộ hoàn toàn
    static let heroStart = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.95)
    static let heroEnd = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.92)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [heroStart, heroEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var accentBarGradient: LinearGradient {
        LinearGradient(
            colors: [primary, secondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Viền khung điện thoại đồng bộ cho cả Ảnh hướng dẫn và Video YouTube
    static var mediaFrameBorderGradient: LinearGradient {
        LinearGradient(
            colors: [
                primary.opacity(0.75),
                secondary.opacity(0.55),
                primary.opacity(0.75)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static let mediaFrameCornerRadius: CGFloat = 47.33
    static let mediaFrameLineWidth: CGFloat = 4.0

    static let cornerRadius: CGFloat = 18.0
    static let innerCornerRadius: CGFloat = 14.0
    static let pageBackground = SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255)
    static let cardBackground = SwiftUI.Color.white
    static let cardHeaderBackground = SwiftUI.Color(red: 248/255, green: 249/255, blue: 250/255).opacity(0.95)
    static let innerRowBackground = SwiftUI.Color(red: 245/255, green: 248/255, blue: 255/255) // Sáng trong, nổi bật chữ đen
    static let border = SwiftUI.Color(red: 220/255, green: 226/255, blue: 236/255)             // Viền chuẩn #dce2ec
    static let innerBorder = SwiftUI.Color(red: 222/255, green: 229/255, blue: 240/255)
    static let shadow = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.09)
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

// MARK: - Hiệu ứng nhấn nút thu nhỏ & nảy lò xo (Đồng bộ với toàn bộ App)
private struct CSSBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

// MARK: - 🌟 HERO BANNER ĐẦU TRANG (ĐỒNG BỘ MÀU ICON VỚI SOURCESVIEWCONTROLLER)
private struct CSSHeroBannerView: SwiftUI.View {
    let title: String
    let subtitle: String
    @State private var isAppeared = false

    var body: some SwiftUI.View {
        VStack(spacing: 6) {
            HStack(spacing: 9) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    CSSTheme.pinkGradientStart,
                                    CSSTheme.pinkGradientEnd
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(SwiftUI.Color.white.opacity(0.65), lineWidth: 1.2)
                        )

                    SwiftUI.Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 14.5, weight: .bold))
                        .foregroundColor(.white)
                }

                SwiftUI.Text(title)
                    .font(.system(size: 23, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 2)
            }

            SwiftUI.Text(subtitle)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.white.opacity(0.96))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .fill(CSSTheme.heroGradient)

                // Ánh sáng trang trí góc trên giống các thẻ Hero khác
                GeometryReader { geo in
                    Circle()
                        .fill(SwiftUI.Color.white.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .offset(x: geo.size.width - 75, y: -45)
                }
                .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                .stroke(SwiftUI.Color.white.opacity(0.32), lineWidth: 1.2)
        )
        .shadow(color: CSSTheme.primary.opacity(0.26), radius: 14, x: 0, y: 7)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : -10)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05)) {
                isAppeared = true
            }
        }
    }
}

/// Bộ tải và giải mã ảnh (gồm cả Ảnh hướng dẫn + Thumbnail Video YouTube) trên Background Thread + Cache RAM + Chống tải trùng lặp (In-Flight Deduplication)
private final class GuideImageCacheManager: @unchecked Sendable {
    static let shared = GuideImageCacheManager()
    private let cache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private let lock = NSLock()
    private var inFlightTasks: [String: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 20
        cache.totalCostLimit = 40 * 1024 * 1024
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.urlCache = URLCache(memoryCapacity: 25 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        session = URLSession(configuration: config)
    }

    func cachedImage(for urlString: String) -> UIImage? {
        cache.object(forKey: urlString as NSString)
    }

    func prefetchAllGuideImages() {
        let urls = [
            "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2589.jpeg",
            "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2588.jpeg",
            "https://i.ytimg.com/vi/j0Ng2cYvd1o/maxresdefault.jpg",
            "https://i.ytimg.com/vi/j0Ng2cYvd1o/hqdefault.jpg"
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

        let task: Task<UIImage?, Never> = lock.withLock {
            if let existingTask = inFlightTasks[urlString] {
                return existingTask
            }
            let newTask = Task.detached(priority: .utility) { [weak self] () -> UIImage? in
                guard let self = self, let url = URL(string: urlString) else { return nil }
                defer {
                    self.lock.withLock {
                        _ = self.inFlightTasks.removeValue(forKey: urlString)
                    }
                }
                if let cached = self.cachedImage(for: urlString) {
                    return cached
                }
                do {
                    let (data, response) = try await self.session.data(from: url)
                    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
                        return nil
                    }
                    let options: [CFString: Any] = [
                        kCGImageSourceShouldCache: false
                    ]
                    guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
                        if let rawImage = UIImage(data: data) {
                            self.cache.setObject(rawImage, forKey: urlString as NSString)
                            return rawImage
                        }
                        return nil
                    }
                    let downsampleOptions: [CFString: Any] = [
                        kCGImageSourceCreateThumbnailFromImageAlways: true,
                        kCGImageSourceShouldCacheImmediately: true,
                        kCGImageSourceCreateThumbnailWithTransform: true,
                        kCGImageSourceThumbnailMaxPixelSize: maxDimension
                    ]
                    if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) {
                        let decoded = UIImage(cgImage: cgImage)
                        self.cache.setObject(decoded, forKey: urlString as NSString)
                        return decoded
                    }
                    if let fallback = UIImage(data: data)?.preparingForDisplay() {
                        self.cache.setObject(fallback, forKey: urlString as NSString)
                        return fallback
                    }
                    return nil
                } catch {
                    return nil
                }
            }
            inFlightTasks[urlString] = newTask
            return newTask
        }

        return await task.value
    }
}

/// Bộ quản lý dùng chung WKProcessPool giúp khi người dùng nhấn Play thì WebView mở tức thì mà không làm giật lúc cuộn
@MainActor
private final class WebKitWarmupPool {
    static let shared = WebKitWarmupPool()
    let processPool = WKProcessPool()
    private init() {}
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
        _ = WebKitWarmupPool.shared

        // Khoá giao diện Sáng (Light Mode) để chữ đen tuyền luôn hiển thị rõ nét nhất trên nền thẻ trắng
        overrideUserInterfaceStyle = .light

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
        if !show && self.floatingBackButton == nil {
            return
        }

        if self.floatingBackButton == nil {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false

            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
            btn.tintColor = CSSTheme.uiBlue
            btn.backgroundColor = CSSTheme.uiWhite.withAlphaComponent(0.95)

            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = CSSTheme.uiBorder.cgColor
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowRadius = 6
            btn.layer.shadowOpacity = 0.14

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
    @Published var isCellularRefreshEnabled: Bool = {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        return UserDefaults.standard.isCellularRefreshEnabled
    }()

    private var cancellables = Set<AnyCancellable>()

    init() {
        CellularRefreshDefaultBootstrapper.applyDefaultTrueIfNeeded()
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.syncCellularRefreshStatus()
            }
            .store(in: &cancellables)
    }

    func syncCellularRefreshStatus() {
        let current = UserDefaults.standard.isCellularRefreshEnabled
        if isCellularRefreshEnabled != current {
            isCellularRefreshEnabled = current
        }
    }

    func setCellularRefreshEnabled(_ enabled: Bool) {
        guard isCellularRefreshEnabled != enabled || UserDefaults.standard.isCellularRefreshEnabled != enabled else { return }
        isCellularRefreshEnabled = enabled
        CellularRefreshManager.shared.setEnabled(enabled)
    }
}

struct SystemCheckDashboardView: SwiftUI.View {
    @StateObject private var vm = SystemCheckViewModel()

    var body: some SwiftUI.View {
        ScrollView(showsIndicators: false) {
            // Dùng VStack cố định chiều cao kết hợp với Poster Video tĩnh giúp lướt từ đầu tới cuối mượt 120fps tuyệt đối không bao giờ khựng
            VStack(spacing: 20) {
                // Khối Hero Banner đồng bộ 100% với các màn hình trước
                CSSHeroBannerView(
                    title: "Tổng quan & Tính năng",
                    subtitle: "Tự động làm mới ứng dụng qua 4G/5G & Hướng dẫn Phím tắt"
                )
                .padding(.top, 4)

                shortcutsSection
                automationGuideSection
                shortcutVideoGuideSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 50)
        }
        .background(SwiftUI.Color.clear)
        .preferredColorScheme(.light)
        .onAppear {
            vm.syncCellularRefreshStatus()
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
            VStack(spacing: 22) {
                RemoteGuideImageView(
                    stepBadge: "BƯỚC 1",
                    urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/icons/main/IMG_2589.jpeg",
                    caption: "Mở Phím Tắt mục Auto Refresh 4G (Auto Refresh 4G 2) và nhấn vào dấu xổ xuống:",
                    loadingText: "Đang tải ảnh...",
                    errorText: "Không tải được ảnh. Vui lòng kiểm tra mạng."
                )

                RemoteGuideImageView(
                    stepBadge: "BƯỚC 2",
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
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(CSSTheme.primary.opacity(0.14))
                            .frame(width: 36, height: 36)
                        SwiftUI.Image(systemName: "sparkles.tv.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(CSSTheme.primary)
                    }

                    SwiftUI.Text("Nếu phím tắt tải về không tương thích với phiên bản iOS trên máy của bạn, bạn có thể xem video bên dưới để tự tạo phím tắt.")
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(CSSTheme.pureBlack)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CSSTheme.innerRowBackground)
                .cornerRadius(CSSTheme.innerCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous)
                        .stroke(CSSTheme.innerBorder, lineWidth: 1)
                )

                IPhone14VerticalVideoFrameView(
                    videoID: "j0Ng2cYvd1o"
                )
            }
        }
    }
}

// MARK: - 🎬 KHUNG VIDEO DỌC 9:19.5 SIÊU MƯỢT (CHỐNG ĐƠ/GIẬT 100% KHI LƯỚT CUỘN)
/// Khi người dùng lướt cuộn: Hiển thị ảnh Poster tĩnh đã giải mã sẵn trên RAM (nhẹ như 1 bức ảnh thường, không khởi tạo WKWebView lúc đang cuộn).
/// Khi người dùng chạm vào xem: Lập tức bung trình phát YouTube hoặc mở trực tiếp nếu muốn.
struct IPhone14VerticalVideoFrameView: SwiftUI.View {
    let videoID: String
    @State private var isPlayerActive: Bool = false
    @State private var isVisibleOnScreen: Bool = false
    @State private var posterImage: UIImage? = nil

    private let iPhone14CornerRadius: CGFloat = CSSTheme.mediaFrameCornerRadius

    private var maxResThumbnailURL: String {
        "https://i.ytimg.com/vi/\(videoID)/maxresdefault.jpg"
    }

    private var hqThumbnailURL: String {
        "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg"
    }

    var body: some SwiftUI.View {
        ZStack {
            SwiftUI.Color.black

            if isPlayerActive {
                YouTubeVerticalPlayerWebView(
                    videoID: videoID,
                    isVisibleOnScreen: isVisibleOnScreen,
                    autoplay: true
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
            } else {
                posterPreviewLayer
            }
        }
        .aspectRatio(9.0 / 19.5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: iPhone14CornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: iPhone14CornerRadius, style: .continuous)
                .strokeBorder(
                    CSSTheme.mediaFrameBorderGradient,
                    lineWidth: CSSTheme.mediaFrameLineWidth
                )
        )
        .shadow(color: CSSTheme.secondary.opacity(0.24), radius: 14, x: 0, y: 7)
        .padding(.horizontal, 4)
        .task(id: videoID) {
            if let cached = GuideImageCacheManager.shared.cachedImage(for: maxResThumbnailURL)
                ?? GuideImageCacheManager.shared.cachedImage(for: hqThumbnailURL) {
                self.posterImage = cached
                return
            }
            if let loadedMax = await GuideImageCacheManager.shared.loadAndDecodeImage(urlString: maxResThumbnailURL) {
                self.posterImage = loadedMax
            } else if let loadedHQ = await GuideImageCacheManager.shared.loadAndDecodeImage(urlString: hqThumbnailURL) {
                self.posterImage = loadedHQ
            }
        }
        .onAppear {
            isVisibleOnScreen = true
        }
        .onDisappear {
            isVisibleOnScreen = false
        }
    }

    private var posterPreviewLayer: some SwiftUI.View {
        SwiftUI.Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isPlayerActive = true
            }
        } label: {
            ZStack {
                // Lớp nền Poster Video đã giải mã sẵn
                GeometryReader { geo in
                    if let poster = posterImage {
                        SwiftUI.Image(uiImage: poster)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        LinearGradient(
                            colors: [
                                SwiftUI.Color(red: 18/255, green: 24/255, blue: 42/255),
                                SwiftUI.Color(red: 36/255, green: 22/255, blue: 68/255)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }

                // Lớp phủ tối nhẹ làm nổi bật nút Play
                LinearGradient(
                    colors: [
                        SwiftUI.Color.black.opacity(0.25),
                        SwiftUI.Color.black.opacity(0.10),
                        SwiftUI.Color.black.opacity(0.45)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Nút Play trung tâm + Nhãn hướng dẫn
                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(SwiftUI.Color.white.opacity(0.22))
                            .frame(width: 86, height: 86)

                        Circle()
                            .fill(CSSTheme.heroGradient)
                            .frame(width: 70, height: 70)
                            .overlay(
                                Circle()
                                    .stroke(SwiftUI.Color.white.opacity(0.85), lineWidth: 2)
                            )
                            .shadow(color: CSSTheme.primary.opacity(0.45), radius: 12, x: 0, y: 6)

                        SwiftUI.Image(systemName: "play.fill")
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .offset(x: 2)
                    }

                    HStack(spacing: 6) {
                        SwiftUI.Image(systemName: "hand.tap.fill")
                            .font(.system(size: 13, weight: .bold))
                        SwiftUI.Text("Chạm để phát video hướng dẫn")
                            .font(.system(size: 13.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(SwiftUI.Color.black.opacity(0.62))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(SwiftUI.Color.white.opacity(0.28), lineWidth: 1)
                    )
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CSSBounceButtonStyle())
    }
}

/// WebView nhúng trình phát YouTube tối ưu cho khung dọc 9:19.5 (Chỉ nạp khi người dùng bấm Play)
struct YouTubeVerticalPlayerWebView: UIViewRepresentable {
    let videoID: String
    let isVisibleOnScreen: Bool
    var autoplay: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WebKitWarmupPool.shared.processPool
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
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
        let autoParam = autoplay ? "1" : "0"
        let embedURL = "https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&autoplay=\(autoParam)&rel=0&modestbranding=1&fs=1&enablejsapi=1&origin=\(originDomain)"

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

// MARK: - 🗂️ CẤU TRÚC SECTION HEADER + CARD CHUẨN ĐỒNG BỘ TOÀN HỆ THỐNG
struct SkySectionCard<Content: SwiftUI.View>: SwiftUI.View {
    let title: String
    let icon: String
    let color: SwiftUI.Color
    var statusOK: Bool? = nil
    var trailingView: AnyView? = nil
    var footerText: String? = nil
    @ViewBuilder let content: Content

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 9) {
            // Tiêu đề Section bên ngoài Card + Gạch chân Gradient Xanh-Tím 38x3.5pt đồng bộ
            SectionHeaderView(
                title: title,
                icon: icon,
                color: color,
                statusOK: statusOK,
                trailingView: trailingView
            )
            .padding(.horizontal, 4)

            // Khối Card trắng bo góc 18pt, đổ bóng kép sang trọng giống hệt các màn hình trước
            VStack(alignment: .leading, spacing: 11) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CSSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.cornerRadius, style: .continuous)
                    .stroke(CSSTheme.border, lineWidth: 1.1)
            )
            .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 6)
            .shadow(color: CSSTheme.primary.opacity(0.08), radius: 16, x: 0, y: 8)

            // Chú thích chân trang (Footer) màu đen tuyền sắc nét, dễ đọc
            if let footerText = footerText {
                SwiftUI.Text(footerText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(CSSTheme.pureBlack)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(color.opacity(0.14))
                        .frame(width: 24, height: 24)
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 12.5, weight: .heavy))
                        .foregroundColor(color)
                }

                SwiftUI.Text(title.uppercased())
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
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

            // Thanh gạch chân Gradient Xanh - Tím dài 38pt, cao 3.5pt đồng bộ với AppViewController & SourcesViewController
            RoundedRectangle(cornerRadius: 1.75)
                .fill(CSSTheme.accentBarGradient)
                .frame(width: 38, height: 3.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                    .fill((isOn ? CSSTheme.primary : CSSTheme.secondary).opacity(0.14))
                    .frame(width: 44, height: 44)
                SwiftUI.Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(isOn ? CSSTheme.primary : CSSTheme.pureBlack)
            }

            VStack(alignment: .leading, spacing: 3) {
                SwiftUI.Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CSSTheme.pureBlack)
                SwiftUI.Text(isOn ? onText : offText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(isOn ? CSSTheme.primary : CSSTheme.pureBlack)
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
        .cornerRadius(CSSTheme.innerCornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous)
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
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundColor(CSSTheme.pureBlack)
                    .multilineTextAlignment(.leading)

                Spacer()

                // Nút viên thuốc có icon mũi tên tinh tế đồng bộ với các nút hành động trong App
                HStack(spacing: 4) {
                    SwiftUI.Text(buttonTitle)
                        .font(.system(size: 13, weight: .heavy))
                    SwiftUI.Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .heavy))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7.5)
                .background(
                    LinearGradient(
                        colors: [color, color.opacity(0.84)],
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
            .cornerRadius(CSSTheme.innerCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous)
                    .stroke(CSSTheme.innerBorder, lineWidth: 1.0)
            )
        }
        .buttonStyle(CSSBounceButtonStyle())
    }
}

/// Hiển thị ảnh hướng dẫn không có khung bao ngoài để chiều rộng ảnh bằng đúng 100% chiều rộng khung Video YouTube
struct RemoteGuideImageView: SwiftUI.View {
    var stepBadge: String? = nil
    let urlString: String
    let caption: String
    let loadingText: String
    let errorText: String

    @State private var uiImage: UIImage? = nil
    @State private var didFail: Bool = false

    private let frameCornerRadius: CGFloat = CSSTheme.mediaFrameCornerRadius

    var body: some SwiftUI.View {
        VStack(alignment: .leading, spacing: 14) {
            // Thanh tiêu đề Bước 1 / Bước 2 đồng bộ kích thước với hộp chú thích của mục Video
            VStack(spacing: 6) {
                if let badge = stepBadge {
                    HStack(spacing: 6) {
                        SwiftUI.Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .heavy))
                        SwiftUI.Text(badge)
                            .font(.system(size: 12, weight: .heavy))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: [CSSTheme.primary, CSSTheme.secondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: CSSTheme.primary.opacity(0.25), radius: 4, x: 0, y: 2)
                }

                SwiftUI.Text(caption)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundColor(CSSTheme.pureBlack)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(13)
            .frame(maxWidth: .infinity)
            .background(CSSTheme.innerRowBackground)
            .cornerRadius(CSSTheme.innerCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: CSSTheme.innerCornerRadius, style: .continuous)
                    .stroke(CSSTheme.innerBorder, lineWidth: 1)
            )

            // Khung ảnh tràn rộng với padding(.horizontal, 4) giống hệt IPhone14VerticalVideoFrameView
            if let image = uiImage {
                SwiftUI.Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .background(SwiftUI.Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                            .strokeBorder(
                                CSSTheme.mediaFrameBorderGradient,
                                lineWidth: CSSTheme.mediaFrameLineWidth
                            )
                    )
                    .shadow(color: CSSTheme.secondary.opacity(0.24), radius: 14, x: 0, y: 7)
                    .padding(.horizontal, 4)
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
                .background(CSSTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                        .strokeBorder(
                            CSSTheme.mediaFrameBorderGradient,
                            lineWidth: CSSTheme.mediaFrameLineWidth
                        )
                )
                .shadow(color: CSSTheme.secondary.opacity(0.24), radius: 14, x: 0, y: 7)
                .padding(.horizontal, 4)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(CSSTheme.primary)
                    SwiftUI.Text(loadingText)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(CSSTheme.pureBlack)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .background(CSSTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous)
                        .strokeBorder(
                            CSSTheme.mediaFrameBorderGradient,
                            lineWidth: CSSTheme.mediaFrameLineWidth
                        )
                )
                .shadow(color: CSSTheme.secondary.opacity(0.24), radius: 14, x: 0, y: 7)
                .padding(.horizontal, 4)
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
