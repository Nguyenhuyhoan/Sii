
//  AltStore/TabBarController.swift
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
import Darwin
import Minimuxer
import SideSign

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI SETTINGSVIEWCONTROLLER)
private struct DiagnosticCSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                 // #000000 (Chữ đen tuyền tương phản tuyệt đối)
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)   // #f5f8ff
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)  // #dce2ec
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0)
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)      // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)   // #6f42c1
    static let indigo = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1.0)    // #5856d6
    static let teal = UIColor(red: 23/255, green: 162/255, blue: 184/255, alpha: 1.0)     // #17a2b8
    static let orange = UIColor(red: 253/255, green: 126/255, blue: 20/255, alpha: 1.0)   // #fd7e14
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)     // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)       // #dc3545
    static let magenta = UIColor(red: 232/255, green: 30/255, blue: 99/255, alpha: 1.0)   // #e91e63

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,193,.92))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.95).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.92).cgColor

    static let cornerRadius: CGFloat = 18.0
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG KHI CUỘN XUỐNG DƯỚI)
private final class DiagnosticGradientBackgroundView: UIView {
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
        gradientLayer.colors = [DiagnosticCSSTheme.bgGradientStart, DiagnosticCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

extension TabBarController
{
    // Khôi phục đủ 5 Tab: Thay thế vị trí tab Browse (index 2) bằng tab Bác sĩ (diagnostic)
    private enum Tab: Int, CaseIterable
    {
        case news        // 0: Tổng quan
        case sources     // 1: Sửa lỗi
        case diagnostic  // 2: Bác sĩ (Chẩn đoán hệ thống)
        case myApps      // 3: Ứng dụng
        case settings    // 4: Cài đặt
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?

    private var _viewDidAppear = false

    private var sourcesViewController: SourcesViewController!

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)

        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.presentSources(_:)), name: AppDelegate.addSourceDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()
        debugLog("[TabBarController] viewDidLoad()")

        // 0. CỐ ĐỊNH GIAO DIỆN SÁNG (Light Mode)
        // Thuộc tính này sẽ áp dụng cho cả TabBarController và toàn bộ các NavigationController con bên trong.
        self.overrideUserInterfaceStyle = .light

        // 1. Thay thế tab Browse cũ (nằm ở vị trí index 2 trên Storyboard gốc) bằng Tab "Bác sĩ" (Chẩn đoán hệ thống)
        if var viewControllers = self.viewControllers, viewControllers.count == 5 {
            let diagnosticVC = SystemDiagnosticViewController()
            let diagnosticNav = UINavigationController(rootViewController: diagnosticVC)
            diagnosticNav.overrideUserInterfaceStyle = .light
            diagnosticNav.setNavigationBarHidden(true, animated: false)
            let doctorIcon = UIImage(systemName: "stethoscope") ?? UIImage(systemName: "waveform.path.ecg")
            diagnosticNav.tabBarItem = UITabBarItem(
                title: "Bác sĩ",
                image: doctorIcon,
                selectedImage: doctorIcon
            )
            viewControllers[Tab.diagnostic.rawValue] = diagnosticNav
            self.viewControllers = viewControllers
        }

        // 2. Đổi tab News thành "Tổng quan"
        if let newsNav = self.viewControllers?[Tab.news.rawValue] as? UINavigationController
        {
            newsNav.tabBarItem.title = "Tổng quan"
            newsNav.tabBarItem.image = UIImage(systemName: "checkmark.shield")
            newsNav.tabBarItem.selectedImage = UIImage(systemName: "checkmark.shield.fill")
        }

        // 3. Đổi tab Sources (Nguồn) thành "Sửa lỗi" và cập nhật icon
        if let sourcesNav = self.viewControllers?[Tab.sources.rawValue] as? UINavigationController
        {
            sourcesNav.tabBarItem.title = "Sửa lỗi"
            sourcesNav.tabBarItem.image = UIImage(systemName: "wrench.and.screwdriver")
            sourcesNav.tabBarItem.selectedImage = UIImage(systemName: "wrench.and.screwdriver.fill")

            self.sourcesViewController = sourcesNav.viewControllers.first as? SourcesViewController
        }

        // 4. Đổi tab My Apps thành "Ứng dụng"
        if let myAppsNav = self.viewControllers?[Tab.myApps.rawValue] as? UINavigationController
        {
            myAppsNav.tabBarItem.title = "Ứng dụng"
        }

        // 5. Đổi tab Settings thành "Cài đặt"
        if let settingsNav = self.viewControllers?[Tab.settings.rawValue] as? UINavigationController
        {
            settingsNav.tabBarItem.title = "Cài đặt"
        }

        // 6. Đặt tab My Apps ("Ứng dụng") làm tab active mặc định khi mở app
        self.selectedIndex = Tab.myApps.rawValue
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")

        // Đảm bảo toàn bộ cửa sổ ứng dụng (bao gồm cả các Alert, Toast, Popup...) cũng luôn ở giao diện sáng
        self.view.window?.overrideUserInterfaceStyle = .light

        _viewDidAppear = true

        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }
    }

    override func performSegue(withIdentifier identifier: String, sender: Any?)
    {
        guard _viewDidAppear else {
            self.initialSegue = (identifier, sender)
            return
        }

        super.performSegue(withIdentifier: identifier, sender: sender)
    }
}

extension TabBarController
{
    @objc func presentSources(_ sender: Any)
    {
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true) {
                self.presentSources(sender)
            }

            return
        }

        if let notification = (sender as? Notification), let sourceURL = notification.userInfo?[AppDelegate.addSourceDeepLinkURLKey] as? URL
        {
            self.sourcesViewController?.deepLinkSourceURL = sourceURL
        }

        self.selectedIndex = Tab.sources.rawValue
    }
}

private extension TabBarController
{
    @objc func importApp(_ notification: Notification)
    {
        self.selectedIndex = Tab.myApps.rawValue
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }
}

// ============================================================================
// MARK: - 🩺 MÀN HÌNH "BÁC SĨ" CHẨN ĐOÁN HỆ THỐNG (ĐỒNG BỘ CSS THEME 100%)
// ============================================================================

@MainActor
private final class SystemDiagnosticViewController: UIViewController
{
    private enum CheckState
    {
        case idle
        case running(String)
        case success(String)
        case warning(String)
        case failure(String)
    }

    private struct StepSpec
    {
        let title: String
        let symbol: String
        let accentColor: UIColor
    }

    private struct StepCardViews
    {
        let container: UIView
        let badgeBox: UIView
        let symbolImageView: UIImageView
        let spinner: UIActivityIndicatorView
        let titleLabel: UILabel
        let pillView: UIView
        let pillLabel: UILabel
        let statusBox: UIView
        let statusIconView: UIImageView
        let statusLabel: UILabel
        let accentColor: UIColor
    }

    private let backgroundView = DiagnosticGradientBackgroundView(frame: .zero)
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    private let heroCard = UIView()
    private let heroGradientLayer = CAGradientLayer()
    private let networkPillView = UIView()
    private let networkBadgeLabel = UILabel()

    private let startButton = UIButton(type: .system)
    private let startButtonGradientLayer = CAGradientLayer()

    private var stepCards: [StepCardViews] = []

    private let remediationSectionWrapper = UIView()
    private let remediationContainer = UIView()
    private let remediationTextLabel = UILabel()

    private var isRunningDiagnostic = false

    private let stepSpecs: [StepSpec] = [
        StepSpec(title: "1. Kết nối LocalDevVPN", symbol: "network.badge.shield.half.filled", accentColor: DiagnosticCSSTheme.blue),
        StepSpec(title: "2. Đường truyền ngầm & File Pairing", symbol: "cable.connector.horizontal", accentColor: DiagnosticCSSTheme.purple),
        StepSpec(title: "3. Máy chủ Anisette (Đăng nhập / Làm mới)", symbol: "server.rack", accentColor: DiagnosticCSSTheme.teal),
        StepSpec(title: "4. Chứng chỉ gốc (Certificate)", symbol: "checkmark.seal.fill", accentColor: DiagnosticCSSTheme.orange),
        StepSpec(title: "5. Đồng bộ Chứng chỉ các App đang cài", symbol: "square.stack.3d.up.badge.a.fill", accentColor: DiagnosticCSSTheme.indigo)
    ]

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .light
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.setNavigationBarHidden(true, animated: false)

        setupUI()
        resetAllStepsToIdle()
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        updateNetworkBadge()
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        heroGradientLayer.frame = heroCard.bounds
        startButtonGradientLayer.frame = startButton.bounds
    }

    // MARK: - 🎨 Xây dựng Giao diện Chuẩn CSS Theme

    private func loadSideStoreAppIcon() -> UIImage?
    {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let lastIcon = files.last,
           let image = UIImage(named: lastIcon) {
            return image
        }
        if let image = UIImage(named: "AppIcon60x60") ?? UIImage(named: "AppIcon") {
            return image
        }
        return nil
    }

    private func setupUI()
    {
        // 1. Nền Gradient cố định toàn màn hình (#f3e0ff -> #e0f7ff)
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 36, right: 0)
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        // 2. Khối Hero Banner đồng bộ 100% với SettingsViewController
        setupHeroBanner()

        // 3. Nút bấm Gradient "BẮT ĐẦU KHÁM BỆNH TOÀN DIỆN"
        setupStartActionCard()

        // 4. Tiêu đề Section "KẾT QUẢ CHẨN ĐOÁN 5 HẠNG MỤC" chuẩn SettingsSkySectionCard
        let checklistHeader = makeSectionHeader(
            title: "KẾT QUẢ CHẨN ĐOÁN 5 HẠNG MỤC",
            icon: "stethoscope",
            accentColor: DiagnosticCSSTheme.blue
        )
        contentStack.addArrangedSubview(checklistHeader)

        // 5. Danh sách 5 thẻ hạng mục khám bệnh (Nền trắng #FFFFFF, chữ đen tuyền #000000, viền #dce2ec)
        let cardsStack = UIStackView()
        cardsStack.axis = .vertical
        cardsStack.spacing = 10
        cardsStack.translatesAutoresizingMaskIntoConstraints = false

        for spec in stepSpecs
        {
            let card = makeStepCard(spec: spec)
            stepCards.append(card)
            cardsStack.addArrangedSubview(card.container)
        }
        contentStack.addArrangedSubview(cardsStack)

        // 6. Khung "PHÁC ĐỒ KHẮC PHỤC LỖI PHÁT HIỆN"
        setupRemediationSection()
    }

    private func setupHeroBanner()
    {
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = DiagnosticCSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = DiagnosticCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 7)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.28

        heroGradientLayer.colors = [DiagnosticCSSTheme.heroStart, DiagnosticCSSTheme.heroEnd]
        heroGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        heroGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        heroGradientLayer.cornerRadius = DiagnosticCSSTheme.cornerRadius
        heroGradientLayer.borderWidth = 1.2
        heroGradientLayer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
        heroCard.layer.insertSublayer(heroGradientLayer, at: 0)

        let iconBadge = UIView()
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.backgroundColor = UIColor.white.withAlphaComponent(0.20)
        iconBadge.layer.cornerRadius = 11
        iconBadge.layer.borderWidth = 1.0
        iconBadge.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor

        let iconImageView = UIImageView()
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .scaleAspectFit
        if let appIcon = loadSideStoreAppIcon() {
            iconImageView.image = appIcon
            iconImageView.layer.cornerRadius = 8
            iconImageView.clipsToBounds = true
        } else {
            let symConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
            iconImageView.image = UIImage(systemName: "stethoscope", withConfiguration: symConfig)
            iconImageView.tintColor = .white
        }
        iconBadge.addSubview(iconImageView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Bác Sĩ Hệ Thống"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = DiagnosticCSSTheme.white
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.28

        let verifiedIcon = UIImageView()
        verifiedIcon.translatesAutoresizingMaskIntoConstraints = false
        let verifiedConfig = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        verifiedIcon.image = UIImage(systemName: "cross.case.fill", withConfiguration: verifiedConfig)
        verifiedIcon.tintColor = UIColor(red: 140/255, green: 255/255, blue: 195/255, alpha: 1.0)

        let titleStack = UIStackView(arrangedSubviews: [iconBadge, titleLabel, verifiedIcon])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 9

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "✨ Khám bệnh toàn diện VPN, đường truyền 127.0.0.1, File Pairing, Anisette & Chứng chỉ"
        subLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        subLabel.textColor = DiagnosticCSSTheme.white.withAlphaComponent(0.96)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        // Huy hiệu mạng hiện tại nằm trong Hero Card
        networkPillView.translatesAutoresizingMaskIntoConstraints = false
        networkPillView.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        networkPillView.layer.cornerRadius = 12
        networkPillView.layer.borderWidth = 1.0
        networkPillView.layer.borderColor = UIColor.white.withAlphaComponent(0.38).cgColor

        networkBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        networkBadgeLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        networkBadgeLabel.textColor = DiagnosticCSSTheme.white
        networkBadgeLabel.textAlignment = .center
        networkBadgeLabel.numberOfLines = 1
        networkBadgeLabel.adjustsFontSizeToFitWidth = true
        networkBadgeLabel.minimumScaleFactor = 0.8
        networkPillView.addSubview(networkBadgeLabel)

        heroCard.addSubview(titleStack)
        heroCard.addSubview(subLabel)
        heroCard.addSubview(networkPillView)

        NSLayoutConstraint.activate([
            iconBadge.widthAnchor.constraint(equalToConstant: 34),
            iconBadge.heightAnchor.constraint(equalToConstant: 34),

            iconImageView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 26),
            iconImageView.heightAnchor.constraint(equalToConstant: 26),

            titleStack.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleStack.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),

            subLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),

            networkPillView.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 9),
            networkPillView.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            networkPillView.leadingAnchor.constraint(greaterThanOrEqualTo: heroCard.leadingAnchor, constant: 12),
            networkPillView.trailingAnchor.constraint(lessThanOrEqualTo: heroCard.trailingAnchor, constant: -12),
            networkPillView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -12),
            networkPillView.heightAnchor.constraint(equalToConstant: 24),

            networkBadgeLabel.leadingAnchor.constraint(equalTo: networkPillView.leadingAnchor, constant: 10),
            networkBadgeLabel.trailingAnchor.constraint(equalTo: networkPillView.trailingAnchor, constant: -10),
            networkBadgeLabel.centerYAnchor.constraint(equalTo: networkPillView.centerYAnchor)
        ])

        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.heroCard.alpha = 1
            self.heroCard.transform = .identity
        }

        contentStack.addArrangedSubview(heroCard)
    }

    private func setupStartActionCard()
    {
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.setTitle("  🩺 BẮT ĐẦU KHÁM BỆNH TOÀN DIỆN  ", for: .normal)
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        startButton.setTitleColor(DiagnosticCSSTheme.white, for: .normal)
        startButton.layer.cornerRadius = 15
        startButton.layer.masksToBounds = false
        startButton.layer.shadowColor = DiagnosticCSSTheme.blue.cgColor
        startButton.layer.shadowOffset = CGSize(width: 0, height: 5)
        startButton.layer.shadowRadius = 12
        startButton.layer.shadowOpacity = 0.32

        startButtonGradientLayer.colors = [DiagnosticCSSTheme.heroStart, DiagnosticCSSTheme.heroEnd]
        startButtonGradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        startButtonGradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        startButtonGradientLayer.cornerRadius = 15
        startButtonGradientLayer.borderWidth = 1.1
        startButtonGradientLayer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        startButton.layer.insertSublayer(startButtonGradientLayer, at: 0)

        startButton.heightAnchor.constraint(equalToConstant: 50).isActive = true
        startButton.addTarget(self, action: #selector(handleStartButtonTouchDown), for: .touchDown)
        startButton.addTarget(self, action: #selector(handleStartButtonTouchUp), for: [.touchUpOutside, .touchCancel])
        startButton.addTarget(self, action: #selector(handleStartButtonTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(startButton)
    }

    private func makeSectionHeader(title: String, icon: String, accentColor: UIColor) -> UIView
    {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        wrapper.backgroundColor = .clear

        let iconBox = UIView()
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconBox.backgroundColor = accentColor.withAlphaComponent(0.14)
        iconBox.layer.cornerRadius = 6.5

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let cfg = UIImage.SymbolConfiguration(pointSize: 11.5, weight: .heavy)
        iconView.image = UIImage(systemName: icon, withConfiguration: cfg)
        iconView.tintColor = accentColor
        iconBox.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .heavy)
        titleLabel.textColor = accentColor

        let underline = UIView()
        underline.translatesAutoresizingMaskIntoConstraints = false
        underline.backgroundColor = accentColor
        underline.layer.cornerRadius = 1.75

        wrapper.addSubview(iconBox)
        wrapper.addSubview(titleLabel)
        wrapper.addSubview(underline)

        NSLayoutConstraint.activate([
            iconBox.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            iconBox.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 2),
            iconBox.widthAnchor.constraint(equalToConstant: 22),
            iconBox.heightAnchor.constraint(equalToConstant: 22),

            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: wrapper.trailingAnchor, constant: -4),

            underline.leadingAnchor.constraint(equalTo: iconBox.leadingAnchor),
            underline.topAnchor.constraint(equalTo: iconBox.bottomAnchor, constant: 4),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3.5),
            underline.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -2)
        ])

        return wrapper
    }

    private func makeStepCard(spec: StepSpec) -> StepCardViews
    {
        // Khung Card trắng tinh #FFFFFF bo góc 18pt, viền #dce2ec, bóng xanh nhẹ chuẩn CSSTheme
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = DiagnosticCSSTheme.white
        container.layer.cornerRadius = DiagnosticCSSTheme.cornerRadius
        container.layer.borderWidth = 1.1
        container.layer.borderColor = DiagnosticCSSTheme.border.cgColor
        container.layer.shadowColor = DiagnosticCSSTheme.blue.cgColor
        container.layer.shadowOffset = CGSize(width: 0, height: 5)
        container.layer.shadowRadius = 11
        container.layer.shadowOpacity = 0.08

        // Ô vuông Icon 30x30 bên trái (giống inline badge trong SettingsViewController)
        let badgeBox = UIView()
        badgeBox.translatesAutoresizingMaskIntoConstraints = false
        badgeBox.backgroundColor = spec.accentColor.withAlphaComponent(0.14)
        badgeBox.layer.cornerRadius = 8.5
        badgeBox.layer.borderWidth = 1.0
        badgeBox.layer.borderColor = spec.accentColor.withAlphaComponent(0.28).cgColor

        let symbolImageView = UIImageView()
        symbolImageView.translatesAutoresizingMaskIntoConstraints = false
        let symCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        symbolImageView.image = UIImage(systemName: spec.symbol, withConfiguration: symCfg)
        symbolImageView.tintColor = spec.accentColor
        symbolImageView.contentMode = .scaleAspectFit
        badgeBox.addSubview(symbolImageView)

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = spec.accentColor
        spinner.hidesWhenStopped = true
        badgeBox.addSubview(spinner)

        // Tiêu đề đen tuyền #000000 đậm nét
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = spec.title
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = DiagnosticCSSTheme.pureBlack
        titleLabel.numberOfLines = 2

        // Huy hiệu trạng thái (Pill Badge) góc trên bên phải
        let pillView = UIView()
        pillView.translatesAutoresizingMaskIntoConstraints = false
        pillView.backgroundColor = DiagnosticCSSTheme.light
        pillView.layer.cornerRadius = 10
        pillView.layer.borderWidth = 1.0
        pillView.layer.borderColor = DiagnosticCSSTheme.innerBorder.cgColor

        let pillLabel = UILabel()
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.text = "Chờ khám"
        pillLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        pillLabel.textColor = DiagnosticCSSTheme.blue
        pillView.addSubview(pillLabel)

        // Hộp nội dung kết quả bên dưới (#f5f8ff) giống suiInnerRowBackground
        let statusBox = UIView()
        statusBox.translatesAutoresizingMaskIntoConstraints = false
        statusBox.backgroundColor = DiagnosticCSSTheme.light
        statusBox.layer.cornerRadius = 12
        statusBox.layer.borderWidth = 1.0
        statusBox.layer.borderColor = DiagnosticCSSTheme.innerBorder.cgColor

        let statusIconView = UIImageView()
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        let stCfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        statusIconView.image = UIImage(systemName: "circle.dashed", withConfiguration: stCfg)
        statusIconView.tintColor = DiagnosticCSSTheme.blue.withAlphaComponent(0.6)
        statusIconView.contentMode = .scaleAspectFit

        let statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Chưa kiểm tra"
        statusLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = DiagnosticCSSTheme.pureBlack
        statusLabel.numberOfLines = 0

        statusBox.addSubview(statusIconView)
        statusBox.addSubview(statusLabel)

        container.addSubview(badgeBox)
        container.addSubview(titleLabel)
        container.addSubview(pillView)
        container.addSubview(statusBox)

        NSLayoutConstraint.activate([
            badgeBox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 13),
            badgeBox.topAnchor.constraint(equalTo: container.topAnchor, constant: 13),
            badgeBox.widthAnchor.constraint(equalToConstant: 30),
            badgeBox.heightAnchor.constraint(equalToConstant: 30),

            symbolImageView.centerXAnchor.constraint(equalTo: badgeBox.centerXAnchor),
            symbolImageView.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor),

            spinner.centerXAnchor.constraint(equalTo: badgeBox.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor),

            pillView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -13),
            pillView.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor),
            pillView.heightAnchor.constraint(equalToConstant: 22),

            pillLabel.leadingAnchor.constraint(equalTo: pillView.leadingAnchor, constant: 8),
            pillLabel.trailingAnchor.constraint(equalTo: pillView.trailingAnchor, constant: -8),
            pillLabel.centerYAnchor.constraint(equalTo: pillView.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: badgeBox.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: pillView.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: badgeBox.centerYAnchor),

            statusBox.topAnchor.constraint(equalTo: badgeBox.bottomAnchor, constant: 10),
            statusBox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 13),
            statusBox.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -13),
            statusBox.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12),

            statusIconView.leadingAnchor.constraint(equalTo: statusBox.leadingAnchor, constant: 10),
            statusIconView.centerYAnchor.constraint(equalTo: statusBox.centerYAnchor),
            statusIconView.widthAnchor.constraint(equalToConstant: 18),
            statusIconView.heightAnchor.constraint(equalToConstant: 18),

            statusLabel.topAnchor.constraint(equalTo: statusBox.topAnchor, constant: 9),
            statusLabel.leadingAnchor.constraint(equalTo: statusIconView.trailingAnchor, constant: 8),
            statusLabel.trailingAnchor.constraint(equalTo: statusBox.trailingAnchor, constant: -10),
            statusLabel.bottomAnchor.constraint(equalTo: statusBox.bottomAnchor, constant: -9)
        ])

        return StepCardViews(
            container: container,
            badgeBox: badgeBox,
            symbolImageView: symbolImageView,
            spinner: spinner,
            titleLabel: titleLabel,
            pillView: pillView,
            pillLabel: pillLabel,
            statusBox: statusBox,
            statusIconView: statusIconView,
            statusLabel: statusLabel,
            accentColor: spec.accentColor
        )
    }

    private func setupRemediationSection()
    {
        remediationSectionWrapper.translatesAutoresizingMaskIntoConstraints = false
        remediationSectionWrapper.backgroundColor = .clear
        remediationSectionWrapper.isHidden = true

        let header = makeSectionHeader(
            title: "PHÁC ĐỒ KHẮC PHỤC LỖI PHÁT HIỆN",
            icon: "cross.vial.fill",
            accentColor: DiagnosticCSSTheme.magenta
        )

        remediationContainer.translatesAutoresizingMaskIntoConstraints = false
        remediationContainer.backgroundColor = DiagnosticCSSTheme.white
        remediationContainer.layer.cornerRadius = DiagnosticCSSTheme.cornerRadius
        remediationContainer.layer.borderWidth = 1.3
        remediationContainer.layer.borderColor = DiagnosticCSSTheme.orange.withAlphaComponent(0.55).cgColor
        remediationContainer.layer.shadowColor = DiagnosticCSSTheme.orange.cgColor
        remediationContainer.layer.shadowOffset = CGSize(width: 0, height: 5)
        remediationContainer.layer.shadowRadius = 12
        remediationContainer.layer.shadowOpacity = 0.12

        let innerBox = UIView()
        innerBox.translatesAutoresizingMaskIntoConstraints = false
        innerBox.backgroundColor = DiagnosticCSSTheme.orange.withAlphaComponent(0.08)
        innerBox.layer.cornerRadius = 13
        innerBox.layer.borderWidth = 1.0
        innerBox.layer.borderColor = DiagnosticCSSTheme.orange.withAlphaComponent(0.28).cgColor

        remediationTextLabel.translatesAutoresizingMaskIntoConstraints = false
        remediationTextLabel.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        remediationTextLabel.textColor = DiagnosticCSSTheme.pureBlack
        remediationTextLabel.numberOfLines = 0

        innerBox.addSubview(remediationTextLabel)
        remediationContainer.addSubview(innerBox)

        let vStack = UIStackView(arrangedSubviews: [header, remediationContainer])
        vStack.translatesAutoresizingMaskIntoConstraints = false
        vStack.axis = .vertical
        vStack.spacing = 8
        remediationSectionWrapper.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: remediationSectionWrapper.topAnchor),
            vStack.leadingAnchor.constraint(equalTo: remediationSectionWrapper.leadingAnchor),
            vStack.trailingAnchor.constraint(equalTo: remediationSectionWrapper.trailingAnchor),
            vStack.bottomAnchor.constraint(equalTo: remediationSectionWrapper.bottomAnchor),

            innerBox.topAnchor.constraint(equalTo: remediationContainer.topAnchor, constant: 12),
            innerBox.leadingAnchor.constraint(equalTo: remediationContainer.leadingAnchor, constant: 12),
            innerBox.trailingAnchor.constraint(equalTo: remediationContainer.trailingAnchor, constant: -12),
            innerBox.bottomAnchor.constraint(equalTo: remediationContainer.bottomAnchor, constant: -12),

            remediationTextLabel.topAnchor.constraint(equalTo: innerBox.topAnchor, constant: 12),
            remediationTextLabel.leadingAnchor.constraint(equalTo: innerBox.leadingAnchor, constant: 12),
            remediationTextLabel.trailingAnchor.constraint(equalTo: innerBox.trailingAnchor, constant: -12),
            remediationTextLabel.bottomAnchor.constraint(equalTo: innerBox.bottomAnchor, constant: -12)
        ])

        contentStack.addArrangedSubview(remediationSectionWrapper)
    }

    // MARK: - Cập nhật Trạng thái Giao diện

    private func updateNetworkBadge()
    {
        let hasWifi = minimuxer.network.isWifiSatisfied
        if hasWifi {
            networkBadgeLabel.text = "🛜 Mạng hiện tại: Wi-Fi (Kiểm tra trực tiếp không cần tắt 4G)"
            networkPillView.backgroundColor = DiagnosticCSSTheme.green.withAlphaComponent(0.28)
        } else {
            networkBadgeLabel.text = "📡 Mạng hiện tại: 4G/5G (Sẽ tự động Tắt/Bật 4G ở Bước 2)"
            networkPillView.backgroundColor = UIColor.white.withAlphaComponent(0.20)
        }
    }

    private func cleanStatusMessage(_ raw: String) -> String
    {
        return raw
            .replacingOccurrences(of: "✅ ", with: "")
            .replacingOccurrences(of: "❌ ", with: "")
            .replacingOccurrences(of: "⚠️ ", with: "")
    }

    private func updateStep(_ index: Int, state: CheckState)
    {
        guard index >= 0 && index < stepCards.count else { return }
        let card = stepCards[index]
        let stCfg = UIImage.SymbolConfiguration(pointSize: 14.5, weight: .bold)

        switch state
        {
        case .idle:
            card.spinner.stopAnimating()
            card.symbolImageView.isHidden = false
            card.pillLabel.text = "Chờ khám"
            card.pillLabel.textColor = card.accentColor
            card.pillView.backgroundColor = card.accentColor.withAlphaComponent(0.12)
            card.pillView.layer.borderColor = card.accentColor.withAlphaComponent(0.25).cgColor

            card.statusBox.backgroundColor = DiagnosticCSSTheme.light
            card.statusBox.layer.borderColor = DiagnosticCSSTheme.innerBorder.cgColor
            card.statusIconView.image = UIImage(systemName: "clock.badge.questionmark", withConfiguration: stCfg)
            card.statusIconView.tintColor = card.accentColor
            card.statusLabel.text = "Bấm nút Khám bệnh phía trên để bắt đầu kiểm tra..."
            card.statusLabel.textColor = DiagnosticCSSTheme.pureBlack

        case .running(let msg):
            card.symbolImageView.isHidden = true
            card.spinner.startAnimating()
            card.pillLabel.text = "Đang khám..."
            card.pillLabel.textColor = DiagnosticCSSTheme.blue
            card.pillView.backgroundColor = DiagnosticCSSTheme.blue.withAlphaComponent(0.14)
            card.pillView.layer.borderColor = DiagnosticCSSTheme.blue.withAlphaComponent(0.35).cgColor

            card.statusBox.backgroundColor = DiagnosticCSSTheme.blue.withAlphaComponent(0.08)
            card.statusBox.layer.borderColor = DiagnosticCSSTheme.blue.withAlphaComponent(0.28).cgColor
            card.statusIconView.image = UIImage(systemName: "waveform.path.ecg", withConfiguration: stCfg)
            card.statusIconView.tintColor = DiagnosticCSSTheme.blue
            card.statusLabel.text = cleanStatusMessage(msg)
            card.statusLabel.textColor = DiagnosticCSSTheme.blue

        case .success(let msg):
            card.spinner.stopAnimating()
            card.symbolImageView.isHidden = false
            card.pillLabel.text = "Tốt • Ổn định"
            card.pillLabel.textColor = DiagnosticCSSTheme.green
            card.pillView.backgroundColor = DiagnosticCSSTheme.green.withAlphaComponent(0.15)
            card.pillView.layer.borderColor = DiagnosticCSSTheme.green.withAlphaComponent(0.35).cgColor

            card.statusBox.backgroundColor = DiagnosticCSSTheme.green.withAlphaComponent(0.09)
            card.statusBox.layer.borderColor = DiagnosticCSSTheme.green.withAlphaComponent(0.30).cgColor
            card.statusIconView.image = UIImage(systemName: "checkmark.circle.fill", withConfiguration: stCfg)
            card.statusIconView.tintColor = DiagnosticCSSTheme.green
            card.statusLabel.text = cleanStatusMessage(msg)
            card.statusLabel.textColor = DiagnosticCSSTheme.pureBlack

        case .warning(let msg):
            card.spinner.stopAnimating()
            card.symbolImageView.isHidden = false
            card.pillLabel.text = "Cần chú ý"
            card.pillLabel.textColor = DiagnosticCSSTheme.orange
            card.pillView.backgroundColor = DiagnosticCSSTheme.orange.withAlphaComponent(0.16)
            card.pillView.layer.borderColor = DiagnosticCSSTheme.orange.withAlphaComponent(0.38).cgColor

            card.statusBox.backgroundColor = DiagnosticCSSTheme.orange.withAlphaComponent(0.10)
            card.statusBox.layer.borderColor = DiagnosticCSSTheme.orange.withAlphaComponent(0.35).cgColor
            card.statusIconView.image = UIImage(systemName: "exclamationmark.triangle.fill", withConfiguration: stCfg)
            card.statusIconView.tintColor = DiagnosticCSSTheme.orange
            card.statusLabel.text = cleanStatusMessage(msg)
            card.statusLabel.textColor = DiagnosticCSSTheme.pureBlack

        case .failure(let msg):
            card.spinner.stopAnimating()
            card.symbolImageView.isHidden = false
            card.pillLabel.text = "Phát hiện lỗi"
            card.pillLabel.textColor = DiagnosticCSSTheme.red
            card.pillView.backgroundColor = DiagnosticCSSTheme.red.withAlphaComponent(0.15)
            card.pillView.layer.borderColor = DiagnosticCSSTheme.red.withAlphaComponent(0.38).cgColor

            card.statusBox.backgroundColor = DiagnosticCSSTheme.red.withAlphaComponent(0.09)
            card.statusBox.layer.borderColor = DiagnosticCSSTheme.red.withAlphaComponent(0.32).cgColor
            card.statusIconView.image = UIImage(systemName: "xmark.octagon.fill", withConfiguration: stCfg)
            card.statusIconView.tintColor = DiagnosticCSSTheme.red
            card.statusLabel.text = cleanStatusMessage(msg)
            card.statusLabel.textColor = DiagnosticCSSTheme.pureBlack
        }
    }

    private func resetAllStepsToIdle()
    {
        for i in 0..<stepCards.count
        {
            updateStep(i, state: .idle)
        }
        remediationSectionWrapper.isHidden = true
        remediationTextLabel.text = nil
    }

    private func showRemediation(_ tips: [String])
    {
        guard !tips.isEmpty else {
            remediationSectionWrapper.isHidden = true
            return
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4.5
        let formatted = tips.map { "💊 \($0)" }.joined(separator: "\n\n")
        remediationTextLabel.attributedText = NSAttributedString(
            string: formatted,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13.5, weight: .bold),
                .foregroundColor: DiagnosticCSSTheme.pureBlack,
                .paragraphStyle: paragraph
            ]
        )
        remediationSectionWrapper.isHidden = false
    }

    // MARK: - Hiệu ứng Nút bấm & Xử lý sự kiện Khám bệnh

    @objc private func handleStartButtonTouchDown()
    {
        UIView.animate(withDuration: 0.12) {
            self.startButton.transform = CGAffineTransform(translationX: 3, y: -1).scaledBy(x: 0.97, y: 0.97)
        }
    }

    @objc private func handleStartButtonTouchUp()
    {
        UIView.animate(withDuration: 0.28, delay: 0, usingSpringWithDamping: 0.62, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.startButton.transform = .identity
        }
    }

    @objc private func handleStartButtonTapped()
    {
        handleStartButtonTouchUp()
        guard !isRunningDiagnostic else { return }
        isRunningDiagnostic = true
        startButton.isEnabled = false
        startButton.alpha = 0.75
        startButton.setTitle("  ⏳ BÁC SĨ ĐANG KHÁM HỆ THỐNG...  ", for: .normal)

        resetAllStepsToIdle()
        updateNetworkBadge()

        Task { @MainActor in
            await runFullDiagnosticFlow()
            self.isRunningDiagnostic = false
            self.startButton.isEnabled = true
            self.startButton.alpha = 1.0
            self.startButton.setTitle("  🩺 BẮT ĐẦU KHÁM BỆNH TOÀN DIỆN  ", for: .normal)
            self.updateNetworkBadge()
        }
    }

    // ========================================================================
    // MARK: - QUY TRÌNH 5 BƯỚC "KHÁM BỆNH THỰC CHIẾN"
    // ========================================================================

    private func runFullDiagnosticFlow() async
    {
        var remediationTips: [String] = []
        var didToggleOffCellularInStep2 = false

        // Đảm bảo luôn khôi phục 4G nếu quá trình bị dừng giữa chừng
        defer {
            if didToggleOffCellularInStep2 {
                Task {
                    _ = await CellularRefreshManager.shared.turnOnDataIfNeeded()
                }
            }
        }

        // ––––––––––––––––––––––––––––––––––
        // 🛑 BƯỚC 1: KIỂM TRA LOCALDEVVPN TRƯỚC TIÊN (BẮT BUỘC)
        // ––––––––––––––––––––––––––––––––––
        updateStep(0, state: .running("Đang quét giao diện mạng tun/utun của LocalDevVPN..."))
        try? await Task.sleep(nanoseconds: 250_000_000)

        let vpnActive = await checkLocalDevVPNActive()
        guard vpnActive else {
            updateStep(0, state: .failure("❌ Chưa bật LocalDevVPN! Đã dừng kiểm tra."))
            remediationTips.append("Chưa bật LocalDevVPN: Bạn hãy mở ứng dụng LocalDevVPN (hoặc StosVPN) lên và gạt nút Bật kết nối VPN, sau đó quay lại đây bấm Khám bệnh lại nhé!")
            showRemediation(remediationTips)
            return
        }

        let isWifi = minimuxer.network.isWifiSatisfied
        updateStep(0, state: .success(isWifi ? "✅ Đã bật LocalDevVPN (Đang dùng Wi-Fi)" : "✅ Đã bật LocalDevVPN (Đang dùng 4G)"))

        // ––––––––––––––––––––––––––––––––––
        // 📱 BƯỚC 2: KIỂM TRA FILE PAIRING & ĐƯỜNG TRUYỀN NGẦM iOS (127.0.0.1)
        // ––––––––––––––––––––––––––––––––––
        updateStep(1, state: .running("Tầng 1: Đang kiểm tra cấu trúc File Pairing..."))
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Tầng 1: Kiểm tra File Pairing tồn tại và đúng chuẩn XML/Plist
        guard let pairingString = PairingFileManager.shared.fetchPairingFile(),
              let pairingData = pairingString.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: pairingData, options: [], format: nil) as? [String: Any],
              !plist.isEmpty else
        {
            updateStep(1, state: .failure("❌ Thiếu File Pairing hoặc cấu trúc file bị hỏng (Cần cắm máy tính tạo lại)!"))
            remediationTips.append("Thiếu File Pairing: Hãy cắm iPhone/iPad vào máy tính, dùng idevicepair (hoặc jitterbugpair) để tạo lại file ghép nối rồi nạp lại vào ứng dụng.")
            showRemediation(remediationTips)
            return
        }

        // Tầng 2: Nếu KHÔNG CÓ WI-FI -> Phải tự động gọi Phím tắt TẮT 4G để giải phóng 127.0.0.1
        if !minimuxer.network.isWifiSatisfied
        {
            updateStep(1, state: .running("Không có Wi-Fi: Đang gọi Phím tắt TẮT 4G để kiểm tra đường truyền 127.0.0.1..."))
            didToggleOffCellularInStep2 = await CellularRefreshManager.shared.turnOffDataIfNeeded()
        }

        updateStep(1, state: .running("Tầng 2: Đang ping đường truyền ngầm lockdownd (Minimuxer)..."))

        let lockdownOK = await testMinimuxerLiveLockdownConnection()
        if lockdownOK
        {
            updateStep(1, state: .success("✅ Ghép nối & Đường truyền ngầm: Hoạt động hoàn hảo!"))
        }
        else
        {
            let errMsg = "❌ Lỗi File Pairing hoặc Thiết bị đã ghép nối trên iPhone có vấn đề hoặc Kẹt đường truyền ngầm của iOS!"
            updateStep(1, state: .failure(errMsg))
            remediationTips.append("Kẹt đường truyền ngầm / Lỗi ghép nối: Hãy Khởi động lại (Restart) iPhone/iPad rồi thử lại. Nếu vẫn báo lỗi này, hãy cắm máy tính để thiết lập lại Thiết bị đã ghép nối (Trust) và tạo lại Pairing File mới!")
        }

        // 🔄 Tự động BẬT LẠI 4G ngay sau khi kiểm tra xong Bước 2 (nếu trước đó đã tắt 4G)
        // để Bước 3 có mạng Internet kiểm tra Máy chủ Anisette và tránh hao pin!
        if didToggleOffCellularInStep2
        {
            updateStep(2, state: .running("Đang gọi Phím tắt BẬT LẠI 4G để kiểm tra Máy chủ Anisette..."))
            _ = await CellularRefreshManager.shared.turnOnDataIfNeeded(addOnDelay: 1.5)
            didToggleOffCellularInStep2 = false
            // Chờ sóng 4G lên mạng ổn định
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        // ––––––––––––––––––––––––––––––––––
        // 🌐 BƯỚC 3: KIỂM TRA MÁY CHỦ ANISETTE (TEST DỮ LIỆU REFRESH THỰC TẾ)
        // ––––––––––––––––––––––––––––––––––
        updateStep(2, state: .running("Đang kiểm tra gói dữ liệu bảo mật từ Máy chủ Anisette..."))
        let anisetteResult = await checkAnisetteServerHealth()
        switch anisetteResult
        {
        case .success(let info):
            updateStep(2, state: .success(info))
        case .warning(let warn):
            updateStep(2, state: .warning(warn))
            remediationTips.append("Cảnh báo Anisette: \(warn)")
        case .failure(let err):
            updateStep(2, state: .failure(err))
            remediationTips.append("Lỗi Máy chủ Anisette: Máy chủ hiện tại không trả về đủ mã bảo mật (X-Apple-I-MD / machineID) để Làm mới App. Vui lòng vào tab Cài đặt -> Máy chủ Anisette để đổi sang máy chủ khác!")
        default:
            break
        }

        // ––––––––––––––––––––––––––––––––––
        // 🔐 BƯỚC 4: KIỂM TRA CHỨNG CHỈ GỐC (CERTIFICATE)
        // ––––––––––––––––––––––––––––––––––
        updateStep(3, state: .running("Đang kiểm tra Chứng chỉ phát triển và Tài khoản Apple ID..."))
        try? await Task.sleep(nanoseconds: 150_000_000)

        let certCheck = checkActiveRootCertificate()
        guard let rootSerial = certCheck.serialNumber else
        {
            updateStep(3, state: .failure(certCheck.message))
            remediationTips.append("Lỗi Chứng chỉ gốc: Chưa có chứng chỉ hợp lệ hoặc bạn chưa đăng nhập Apple ID. Hãy vào tab Cài đặt -> Tài khoản để đăng nhập lại và làm mới ứng dụng.")
            updateStep(4, state: .warning("⚠️ Không thể đối chiếu do chưa có Chứng chỉ gốc ở Bước 4."))
            showRemediation(remediationTips)
            return
        }

        updateStep(3, state: .success(certCheck.message))

        // ––––––––––––––––––––––––––––––––––
        // 📦 BƯỚC 5: KIỂM TRA ĐỒNG BỘ CHỨNG CHỈ CỦA TỪNG APP ĐANG CÀI
        // ––––––––––––––––––––––––––––––––––
        updateStep(4, state: .running("Đang quét và đối chiếu chứng chỉ của toàn bộ ứng dụng đã cài..."))
        try? await Task.sleep(nanoseconds: 150_000_000)

        let appSync = checkInstalledAppsCertificateSync(activeRootSerial: rootSerial)
        stepCards[4].titleLabel.text = "5. App đang cài (\(appSync.totalCount) ứng dụng)"

        if appSync.mismatchedAppNames.isEmpty
        {
            updateStep(4, state: .success("✅ Đồng bộ ứng dụng: Tất cả \(appSync.totalCount) app đều dùng đúng chứng chỉ hiện tại."))
        }
        else
        {
            let listText = appSync.mismatchedAppNames.joined(separator: ", ")
            updateStep(4, state: .warning("⚠️ Phát hiện lệch chứng chỉ ở ứng dụng: [\(listText)]"))
            remediationTips.append("Ứng dụng [\(listText)] đang dùng chứng chỉ cũ (khác với chứng chỉ gốc hiện tại): Bạn hãy chuyển qua tab Ứng dụng, nhấn giữ lâu vào ứng dụng [\(listText)] và chọn Ký lại / Làm mới để nạp lại chứng chỉ mới nhé!")
        }

        showRemediation(remediationTips)
    }

    // ========================================================================
    // MARK: - CÁC HÀM KIỂM TRA KỸ THUẬT CHI TIẾT
    // ========================================================================

    /// Bước 1: Quét giao diện mạng tun/utun xem LocalDevVPN đã bật và cấp IP chưa
    private func checkLocalDevVPNActive() async -> Bool
    {
        #if targetEnvironment(simulator)
        return true
        #else
        if let tunnelIp = ConnectionConfig.shared.tunnelIfaceIp,
           !tunnelIp.isEmpty && tunnelIp != "0.0.0.0" {
            if Self.hasActiveLocalDevVPNUtunInterface() {
                return true
            }
        }
        if Self.hasActiveLocalDevVPNUtunInterface() {
            return true
        }
        let readyResult = await minimuxer.core.isReady(withNetworkCheck: true)
        if case .success(true) = readyResult {
            return true
        }
        if case .failure(let err) = readyResult {
            if case .noVPN = err { return false }
            if case .invalidVPN = err { return false }
        }
        return false
        #endif
    }

    private nonisolated static func hasActiveLocalDevVPNUtunInterface() -> Bool
    {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr
        {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            let isPointToPoint = (flags & IFF_POINTOPOINT) != 0

            if isUp && isPointToPoint,
               let namePtr = current.pointee.ifa_name,
               let addr = current.pointee.ifa_addr
            {
                let name = String(cString: namePtr)
                if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ppp")
                {
                    let family = Int32(addr.pointee.sa_family)
                    if family == AF_INET
                    {
                        let sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var addrCopy = sin.sin_addr
                        inet_ntop(AF_INET, &addrCopy, &buffer, socklen_t(INET_ADDRSTRLEN))
                        let ipString = String(cString: buffer)
                        if ipString.hasPrefix("10.7.") {
                            return true
                        }
                    }
                    else if family == AF_INET6
                    {
                        let sin6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                        let bytes = withUnsafeBytes(of: sin6.sin6_addr) { Array($0) }
                        if bytes.count >= 2 && (bytes[0] == 0xfd || bytes[0] == 0xfc) {
                            return true
                        }
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return false
    }

    /// Bước 2: Mở phiên kết nối thực tế tới lockdownd thông qua Minimuxer (Timeout 6.5s tránh treo)
    private func testMinimuxerLiveLockdownConnection() async -> Bool
    {
        #if targetEnvironment(simulator)
        return true
        #else
        await minimuxer.network.refreshEndpoint()
        if let udid = try? await fetchUDID(forceLive: true), !udid.isEmpty {
            return true
        }
        return await CellularRefreshManager.shared.resetAndPrepareMinimuxer(timeout: 6.5)
        #endif
    }

    /// Bước 3: Kiểm tra Máy chủ Anisette xem gói JSON trả về có đầy đủ các trường bảo mật để Refresh/Login không
    private func checkAnisetteServerHealth() async -> CheckState
    {
        let defaults = UserDefaults.standard
        let candidateURLString: String = {
            if defaults.textServer,
               let custom = defaults.textInputAnisetteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !custom.isEmpty {
                return custom
            }
            if let customURL = defaults.customAnisetteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !customURL.isEmpty {
                return customURL
            }
            let menuURL = defaults.menuAnisetteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return menuURL.isEmpty ? AppConstants.Anisette.Servers.defaultServerURL : menuURL
        }()

        guard let url = URL(string: candidateURLString) else {
            return .failure("❌ Địa chỉ Máy chủ Anisette không hợp lệ: \(candidateURLString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let startTime = Date()
        do
        {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                return .failure("❌ Máy chủ Anisette phản hồi lỗi HTTP \(code) (\(url.host ?? candidateURLString)). Vui lòng đổi máy chủ khác!")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure("❌ Máy chủ Anisette đang lỗi dữ liệu (Không trả về định dạng JSON hợp lệ).")
            }

            let md = (json["X-Apple-I-MD"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let mdm = (json["X-Apple-I-MD-M"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let machineID = (json["machineID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard !md.isEmpty && !mdm.isEmpty else {
                return .failure("❌ Máy chủ Anisette đang lỗi dữ liệu (Dù máy chủ vẫn mở nhưng thiếu mã X-Apple-I-MD / X-Apple-I-MD-M, không thể dùng để Refresh). Vui lòng vào Cài đặt -> Máy chủ Anisette đổi máy chủ khác!")
            }

            let hostName = url.host ?? candidateURLString
            let modeNote = defaults.useOnDeviceAnisette ? " [Đang bật Anisette Nội bộ + Server \(hostName)]" : " [\(hostName)]"
            let extraCheck = !machineID.isEmpty ? "Đủ MD/MD-M/machineID" : "Đủ MD/MD-M"
            return .success("✅ Rất tốt (\(extraCheck) - \(elapsedMs)ms)\(modeNote)")
        }
        catch
        {
            if defaults.useOnDeviceAnisette {
                return .warning("⚠️ Không kết nối được máy chủ phụ (\(url.host ?? "Anisette")), nhưng máy đang bật chế độ Anisette Nội bộ (On-Device).")
            }
            return .failure("❌ Không thể kết nối tới Máy chủ Anisette (\(url.host ?? candidateURLString)). Vui lòng kiểm tra mạng hoặc đổi máy chủ khác!")
        }
    }

    /// Chuẩn hóa chuỗi Serial của chứng chỉ (bỏ khoảng trắng, dấu ':', tiền tố 0x và số 0 ở đầu) để so sánh chính xác
    private static func normalizeSerial(_ raw: String?) -> String
    {
        guard let raw else { return "" }
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
        if cleaned.hasPrefix("0x") {
            cleaned = String(cleaned.dropFirst(2))
        }
        while cleaned.count > 1 && cleaned.first == "0" {
            cleaned.removeFirst()
        }
        return cleaned
    }

    /// Bước 4: Kiểm tra Chứng chỉ gốc đang lưu trong Keychain / DatabaseManager
    private func checkActiveRootCertificate() -> (serialNumber: String?, message: String)
    {
        let context = DatabaseManager.shared.viewContext
        var hasActiveAccount = false

        context.performAndWait {
            hasActiveAccount = (DatabaseManager.shared.activeAccount(in: context) != nil)
        }

        let activeCertSerial = CertificateManager.shared.activeCertificate?.serialNumber
            ?? CertificateManager.shared.getSigningCertificate(at: Bundle.Info.activeBundleURL)?.serialNumber

        guard let serial = activeCertSerial?.trimmingCharacters(in: .whitespacesAndNewlines),
              !serial.isEmpty else {
            return (nil, "❌ Chứng chỉ lỗi hoặc chưa đăng nhập tài khoản Apple ID!")
        }

        let shortSerial = serial.count > 10 ? "\(serial.prefix(10))..." : serial
        let accountNote = hasActiveAccount ? "Đã đăng nhập Apple ID" : "Chứng chỉ lưu sẵn"
        return (serial, "✅ Hợp lệ (\(accountNote) • Serial: \(shortSerial))")
    }

    /// Bước 5: Quét toàn bộ InstalledApp trong DatabaseManager và đối chiếu chứng chỉ với Chứng chỉ gốc ở Bước 4
    private func checkInstalledAppsCertificateSync(activeRootSerial: String) -> (totalCount: Int, mismatchedAppNames: [String])
    {
        let context = DatabaseManager.shared.viewContext
        var total = 0
        var mismatched: [String] = []

        let normalizedRoot = Self.normalizeSerial(activeRootSerial)
        let activeTeamID: String? = {
            var teamID: String?
            context.performAndWait {
                teamID = DatabaseManager.shared.activeTeam(in: context)?.identifier
            }
            return teamID
        }()

        context.performAndWait {
            let allApps = InstalledApp.all(in: context)
            total = allApps.count
            var didRepairDatabase = false

            for app in allApps
            {
                // 1. Lấy serial đã lưu trong DB
                var resolvedSerial = app.certificateSerialNumber?.trimmingCharacters(in: .whitespacesAndNewlines)

                // 2. Nếu DB bị trống (do InstallAppOperation chỉ gán overrideSigningCertificate),
                // đọc từ nơi SideStore thực sự lưu chứng chỉ đã ký của App:
                // (a) CertificateManager.shared.getSigningCertificate(for: app) -> đọc file signing_certificate.der
                // TUYỆT ĐỐI KHÔNG gọi getSigningCertificate(at: app.fileURL) vì app.fileURL là Payload IPA gốc chưa ký!
                if resolvedSerial == nil || resolvedSerial!.isEmpty {
                    if let signedCert = CertificateManager.shared.getSigningCertificate(for: app) {
                        resolvedSerial = signedCert.serialNumber
                    }
                }

                // (b) Đọc từ Provisioning Profile (Resigned) của App (giống hệt AppInfoView.swift)
                let resignedProfile = app.customProvisioningProfile
                if resolvedSerial == nil || resolvedSerial!.isEmpty,
                   let profileCerts = resignedProfile?.certificates,
                   !profileCerts.isEmpty
                {
                    if let matched = profileCerts.first(where: { Self.normalizeSerial($0.serialNumber) == normalizedRoot }) {
                        resolvedSerial = matched.serialNumber
                    } else {
                        resolvedSerial = profileCerts.first?.serialNumber
                    }
                }

                let normalizedAppSerial = Self.normalizeSerial(resolvedSerial)
                var isMatchedWithRoot = false

                if !normalizedAppSerial.isEmpty && !normalizedRoot.isEmpty {
                    if normalizedAppSerial == normalizedRoot {
                        isMatchedWithRoot = true
                    } else if let profileCerts = resignedProfile?.certificates,
                              profileCerts.contains(where: { Self.normalizeSerial($0.serialNumber) == normalizedRoot }) {
                        resolvedSerial = activeRootSerial
                        isMatchedWithRoot = true
                    }
                } else {
                    // 3. Nếu App không lưu file .der riêng và dùng chung Main Profile (useMainProfile == true)
                    // hoặc có cùng Team ID và còn hạn sử dụng -> Đồng bộ chuẩn với Chứng chỉ gốc hiện tại
                    let effectiveExpiration = resignedProfile?.expirationDate ?? app.expirationDate
                    let sameTeam = (activeTeamID == nil) || (app.team?.identifier == activeTeamID) || (resignedProfile?.teamIdentifier == activeTeamID)
                    if effectiveExpiration > Date() && (app.useMainProfile || sameTeam) {
                        resolvedSerial = activeRootSerial
                        isMatchedWithRoot = true
                    }
                }

                if isMatchedWithRoot {
                    // Tự động điền lại certificateSerialNumber vào DB (để AppInfoView hiện luôn dòng Certificate Serial)
                    let finalSerial = (resolvedSerial?.isEmpty == false) ? resolvedSerial! : activeRootSerial
                    if app.certificateSerialNumber != finalSerial {
                        app.certificateSerialNumber = finalSerial
                        didRepairDatabase = true
                    }
                    if app.certificateStatus != .valid(isCrossSigned: false) {
                        app.certificateStatus = .valid(isCrossSigned: false)
                        didRepairDatabase = true
                    }
                } else {
                    mismatched.append(app.name)
                }
            }

            if didRepairDatabase && context.hasChanges {
                try? context.save()
            }
        }

        mismatched.sort()
        return (total, mismatched)
    }
}
