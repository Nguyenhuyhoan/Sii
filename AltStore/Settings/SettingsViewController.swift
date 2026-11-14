
//
//  SettingsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SwiftUI
#if !os(tvOS)
import MessageUI
#endif
import Intents
#if !os(tvOS)
import IntentsUI
#endif

import SemanticVersion
import SideSign
import UniformTypeIdentifiers

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME
private struct CSSTheme {
    static let white = UIColor.white
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0) // #f8f9fa
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0) // #e9ecef
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0) // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0) // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0) // #28a745
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0) // #ff00ff
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0) // #343a40

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.9) -> rgba(111,66,193,.85))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.92).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.88).cgColor

    static let cornerRadius: CGFloat = 15.0
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG KHI CUỘN XUỐNG DƯỚI)
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
        gradientLayer.colors = [CSSTheme.bgGradientStart, CSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

extension SettingsViewController
{
    fileprivate enum Section: Int, CaseIterable
    {
        case signIn
        case account
        case patreon
        case display
        case appRefresh
        case instructions
        case techyThings
        case credits
        case betaTesting
        case advancedSettings
        case diagnostics
    }

    fileprivate enum AppRefreshRow: Int, CaseIterable
    {
        case backgroundRefresh
        case noIdleTimeout
        case addToSiri
        case disableAppLimit

        static var allCases: [AppRefreshRow] {
            return []
        }
    }

    fileprivate enum CreditsRow: Int, CaseIterable
    {
        case developer
        case operations
        case designer
        case softwareLicenses
    }

    fileprivate enum TechyThingsRow: Int, CaseIterable
    {
        case healthCheck
        case errorLog
        case storageExplorer
        case clearCache

        static var allCases: [TechyThingsRow] {
            return [.errorLog, .clearCache]
        }
    }

    fileprivate enum AdvancedSettingsRow: Int, CaseIterable
    {
        case sendFeedback           // row 0
        case refreshAttempts        // row 1
        case refreshSideJITServer   // row 2
        case pairingFileManagement  // row 3
        case anisetteServers        // row 4
        case connectionConfig       // row 5
        case networkDiscovery       // row 6
        case developerServices      // row 7
        case profileManagement      // row 8
        case certificateManagement  // row 9
        case backupAndRestore       // row 10
        case userCustomizations     // row 11

        static var allCases: [AdvancedSettingsRow] {
            var rows: [AdvancedSettingsRow] = [
                .refreshAttempts,
                .refreshSideJITServer
            ]
            if !UserDefaults.standard.useOnDeviceAnisette {
                rows.append(.anisetteServers)
            }
            rows.append(contentsOf: [
                .connectionConfig,
                .developerServices,
                .certificateManagement,
                .userCustomizations
            ])
            return rows
        }
    }

    fileprivate enum BetaTestingRow: Int, CaseIterable {
        case betaUpdates
        case betaTrack
    }

    fileprivate enum DiagnosticsRow: Int, CaseIterable
    {
        case developerOptions
        case experimentalFeatures
    }

    // MARK: - 📦 GỘP CÁC MỤC CÀI ĐẶT THIẾT YẾU & FIX LOGIN THÀNH 1 MỤC DUY NHẤT (ĐÃ XOÁ BETA UPDATES)
    fileprivate enum UnifiedSettingsItem: CaseIterable
    {
        case userCustomizations
        case anisetteServers
        case connectionConfig
        case developerServices
        case certificateManagement
        case refreshSideJITServer
        case refreshAttempts
        case errorLog
        case clearCache
        case softwareLicenses
        case developerOptions
        case experimentalFeatures

        static var activeItems: [UnifiedSettingsItem] {
            var items: [UnifiedSettingsItem] = [
                .userCustomizations
            ]
            // Tự động hiển thị Máy chủ Anisette khi tắt On-Device Anisette (hoặc luôn sẵn sàng cho bước 3 Fix Login)
            if !UserDefaults.standard.useOnDeviceAnisette {
                items.append(.anisetteServers)
            } else {
                // Luôn hiển thị để người dùng dễ dàng thấy ngay khi làm theo hướng dẫn Fix Login
                items.append(.anisetteServers)
            }
            items.append(contentsOf: [
                .connectionConfig,
                .developerServices,
                .certificateManagement,
                .refreshSideJITServer,
                .refreshAttempts,
                .errorLog,
                .clearCache,
                .softwareLicenses
            ])
            if UserDefaults.standard.isDebugModeEnabled {
                items.append(contentsOf: [.developerOptions, .experimentalFeatures])
            }
            return items
        }

        // Ánh xạ chính xác về IndexPath gốc trên Storyboard để giữ nguyên Cell, Icon và Segue
        var originalIndexPath: IndexPath {
            switch self {
            case .userCustomizations:
                return IndexPath(row: AdvancedSettingsRow.userCustomizations.rawValue, section: Section.advancedSettings.rawValue)
            case .anisetteServers:
                return IndexPath(row: AdvancedSettingsRow.anisetteServers.rawValue, section: Section.advancedSettings.rawValue)
            case .connectionConfig:
                return IndexPath(row: AdvancedSettingsRow.connectionConfig.rawValue, section: Section.advancedSettings.rawValue)
            case .developerServices:
                return IndexPath(row: AdvancedSettingsRow.developerServices.rawValue, section: Section.advancedSettings.rawValue)
            case .certificateManagement:
                return IndexPath(row: AdvancedSettingsRow.certificateManagement.rawValue, section: Section.advancedSettings.rawValue)
            case .refreshSideJITServer:
                return IndexPath(row: AdvancedSettingsRow.refreshSideJITServer.rawValue, section: Section.advancedSettings.rawValue)
            case .refreshAttempts:
                return IndexPath(row: AdvancedSettingsRow.refreshAttempts.rawValue, section: Section.advancedSettings.rawValue)
            case .errorLog:
                return IndexPath(row: TechyThingsRow.errorLog.rawValue, section: Section.techyThings.rawValue)
            case .clearCache:
                return IndexPath(row: TechyThingsRow.clearCache.rawValue, section: Section.techyThings.rawValue)
            case .softwareLicenses:
                return IndexPath(row: CreditsRow.softwareLicenses.rawValue, section: Section.credits.rawValue)
            case .developerOptions:
                return IndexPath(row: DiagnosticsRow.developerOptions.rawValue, section: Section.diagnostics.rawValue)
            case .experimentalFeatures:
                return IndexPath(row: DiagnosticsRow.experimentalFeatures.rawValue, section: Section.diagnostics.rawValue)
            }
        }
    }
}

final class SettingsViewController: UITableViewController
{
    private var activeTeam: ALTTeam?
    private var accountStatus: AccountVerificationRow.Status = .completed
    private var accountVerificationTask: Task<Void, Never>?

    // Trạng thái ẩn/hiện khung thông tin Tài khoản (Mặc định: Ẩn)
    private var isAccountDetailsExpanded: Bool = false

    private var prototypeHeaderFooterView: SettingsHeaderFooterView!
    private var heroGradientLayer: CAGradientLayer?

    // Nút quay lại nhỏ cố định ở góc trên bên trái khi vào mục con
    private var floatingBackButton: UIButton?

    // Giữ nguyên các @IBOutlet từ Storyboard để tránh lỗi NSUnknownKeyException khi khởi tạo Nib
    @IBOutlet private var betaTrackLabel: UILabel!
    @IBOutlet private var betaTrackPopupButton: UIButton!

    private var debugGestureCounter = 0
    private weak var debugGestureTimer: Timer?

    @IBOutlet private var accountNameLabel: UILabel!
    @IBOutlet private var accountEmailLabel: UILabel!
    @IBOutlet private var accountTypeLabel: UILabel!

    @IBOutlet private var backgroundRefreshSwitch: UISwitch!
    @IBOutlet private var noIdleTimeoutSwitch: UISwitch!
    @IBOutlet private var disableAppLimitSwitch: UISwitch!
    @IBOutlet private var betaUpdatesSwitch: UISwitch!
    @IBOutlet private var verboseOperationsLoggingSwitch: UISwitch!
    @IBOutlet private var altSignVerboseLoggingSwitch: UISwitch!
    @IBOutlet private var minimuxerVerboseLoggingSwitch: UISwitch!
    @IBOutlet private var rotateLogsOnStartupSwitch: UISwitch!
    @IBOutlet private var disableResponseCachingSwitch: UISwitch!

    @IBOutlet private var mastodonButton: UIButton!
    @IBOutlet private var threadsButton: UIButton!
    @IBOutlet private var twitterButton: UIButton!
    @IBOutlet private var githubButton: UIButton!

    @IBOutlet private var versionLabel: UILabel!
    @IBOutlet private var recreateDatabaseSwitch: UISwitch!

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    private static var exportDBInProgress = false
    private static var deleteDBInProgress = false

    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openPatreonSettings(_:)), name: AppDelegate.openPatreonSettingsDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SettingsViewController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }

    // Tắt cứng toàn bộ tính năng Làm mới ứng dụng và Beta Updates
    private func forceDisableUnusedSettings() {
        UserDefaults.standard.isBackgroundRefreshEnabled = false
        UserDefaults.standard.isIdleTimeoutDisableEnabled = false
        UserDefaults.standard.isAppLimitDisabled = false
        UserDefaults.standard.isBetaUpdatesEnabled = false

        self.backgroundRefreshSwitch?.isOn = false
        self.noIdleTimeoutSwitch?.isOn = false
        self.disableAppLimitSwitch?.isOn = false
        self.betaUpdatesSwitch?.isOn = false
    }

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Tắt cứng LÀM MỚI ỨNG DỤNG & BETA UPDATES
        self.forceDisableUnusedSettings()

        // Xóa bỏ tiêu đề "Cài đặt" và ẩn hoàn toàn thanh điều hướng
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        // Giữ tính năng vuốt từ cạnh trái màn hình để quay lại khi ẩn thanh điều hướng
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        #endif

        let nib = UINib(nibName: "SettingsHeaderFooterView", bundle: nil)
        self.prototypeHeaderFooterView = nib.instantiate(withOwner: nil, options: nil)[0] as? SettingsHeaderFooterView
        self.tableView.register(nib, forHeaderFooterViewReuseIdentifier: "HeaderFooterView")

        let debugModeGestureRecognizer = UISwipeGestureRecognizer(target: self, action: #selector(SettingsViewController.handleDebugModeGesture(_:)))
        debugModeGestureRecognizer.delegate = self
        debugModeGestureRecognizer.direction = .up
        #if !os(tvOS)
        debugModeGestureRecognizer.numberOfTouchesRequired = 3
        #endif
        self.tableView.addGestureRecognizer(debugModeGestureRecognizer)

        self.versionLabel.attributedText = getVersionAttributedString()
        self.versionLabel.isUserInteractionEnabled = true
        self.versionLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyVersionLabelTapped)))
        self.versionLabel.numberOfLines = 0
        self.versionLabel.lineBreakMode = .byWordWrapping
        self.versionLabel.setNeedsUpdateConstraints()

        self.tableView.contentInset.top = 0
        self.tableView.contentInset.bottom = 50
        if #available(iOS 15.0, tvOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 0
        }

        // ✨ KÍCH HOẠT GIAO DIỆN WEB CSS & VIỆT HÓA ✨
        self.applySmartWebCSSTheme()

        self.update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let heroHeader = self.tableView.tableHeaderView,
           let heroCard = heroHeader.subviews.first {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        // Đảm bảo ẩn thanh màu trắng và chữ Cài đặt ở trên cùng để tràn viền toàn màn hình
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.forceDisableUnusedSettings()
        self.update()
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.accountVerificationTask?.cancel()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let controller = segue.destination
        controller.title = nil
        controller.navigationItem.title = nil
        #if !os(tvOS)
        controller.navigationItem.largeTitleDisplayMode = .never
        #endif

        if segue.identifier == "anisetteServers" || segue.identifier == "developerServices" || segue.identifier == "profileManagement" || segue.identifier == "certificateManagement" || segue.identifier == "diagnostics" {
            self.show(controller, sender: nil)
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }
}

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ CỐ ĐỊNH Ở MỤC CON
extension SettingsViewController: UINavigationControllerDelegate {
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        // Luôn ẩn thanh điều hướng và tiêu đề ở cả trang chính lẫn mọi mục con
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
            btn.tintColor = CSSTheme.blue
            btn.backgroundColor = CSSTheme.white.withAlphaComponent(0.92)

            // Nút tròn nhỏ 34x34 cố định
            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = CSSTheme.border.cgColor
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
}

// MARK: - ✨ HỆ THỐNG RENDER CSS THÔNG MINH, THẺ TRI ÂN & VIỆT HÓA TOÀN DIỆN
private extension SettingsViewController {

    private func applySmartWebCSSTheme() {
        // 1. Nền Body cố định: Không bao giờ bị trắng khi lướt xuống dưới
        let bgView = CSSGradientBackgroundView(frame: UIScreen.main.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.tableView.backgroundView = bgView
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none

        // 2. Tạo khối .hero Banner nằm sát phía trên
        setupCSSHeroBanner()

        // 3. Tạo Footer hiển thị Lời cảm ơn chân thành & Phiên bản
        setupCreditsAndVersionFooterView()

        // 4. Cấu hình TabBar đồng bộ màu
        #if !os(tvOS)
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = CSSTheme.blue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif

        // 5. Làm đẹp các công tắc UISwitch (Đổ bóng Neon)
        let switches = [
            self.backgroundRefreshSwitch, self.noIdleTimeoutSwitch, self.disableAppLimitSwitch,
            self.betaUpdatesSwitch, self.verboseOperationsLoggingSwitch, self.altSignVerboseLoggingSwitch,
            self.minimuxerVerboseLoggingSwitch, self.rotateLogsOnStartupSwitch,
            self.disableResponseCachingSwitch, self.recreateDatabaseSwitch
        ]

        for sw in switches {
            guard let sw = sw else { continue }
            sw.onTintColor = CSSTheme.blue
            sw.thumbTintColor = CSSTheme.white
            sw.layer.shadowColor = CSSTheme.blue.cgColor
            sw.layer.shadowOffset = CGSize(width: 0, height: 3)
            sw.layer.shadowRadius = 6
            sw.layer.shadowOpacity = 0.28
        }
    }

    // Tạo khối .hero nằm sát phía trên và đã Việt hóa
    private func setupCSSHeroBanner() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 104))
        headerContainer.backgroundColor = .clear

        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = CSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = CSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.25

        let gradient = CAGradientLayer()
        gradient.colors = [CSSTheme.heroStart, CSSTheme.heroEnd]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = CSSTheme.cornerRadius
        heroCard.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "SideStore"
        titleLabel.font = UIFont.systemFont(ofSize: 25, weight: .heavy)
        titleLabel.textColor = CSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.35

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Tùy chỉnh, khắc phục đăng nhập & quản lý hệ thống ứng dụng"
        subLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        subLabel.textColor = CSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        heroCard.addSubview(titleLabel)
        heroCard.addSubview(subLabel)
        headerContainer.addSubview(heroCard)

        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -6),

            titleLabel.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),

            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12)
        ])

        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }

        self.tableView.tableHeaderView = headerContainer
    }

    // MARK: - 💖 CHÂN TRANG: LỜI CẢM ƠN CHÂN THÀNH & PHIÊN BẢN HỆ THỐNG
    private func setupCreditsAndVersionFooterView() {
        let footerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 245))
        footerContainer.backgroundColor = .clear

        // Khung Card Lời Cảm Ơn
        let gratitudeCard = UIView()
        gratitudeCard.translatesAutoresizingMaskIntoConstraints = false
        gratitudeCard.backgroundColor = CSSTheme.white.withAlphaComponent(0.92)
        gratitudeCard.layer.cornerRadius = CSSTheme.cornerRadius
        gratitudeCard.layer.borderWidth = 1.0
        gratitudeCard.layer.borderColor = CSSTheme.border.cgColor
        gratitudeCard.layer.shadowColor = CSSTheme.purple.cgColor
        gratitudeCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        gratitudeCard.layer.shadowRadius = 12
        gratitudeCard.layer.shadowOpacity = 0.08

        let thanksTitleLabel = UILabel()
        thanksTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        thanksTitleLabel.text = "💖 LỜI CẢM ƠN CHÂN THÀNH"
        thanksTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        thanksTitleLabel.textColor = CSSTheme.purple
        thanksTitleLabel.textAlignment = .center

        let thanksBodyLabel = UILabel()
        thanksBodyLabel.translatesAutoresizingMaskIntoConstraints = false
        thanksBodyLabel.numberOfLines = 0
        thanksBodyLabel.textAlignment = .center

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.alignment = .center
        bodyParagraph.lineSpacing = 4

        let bodyText = NSMutableAttributedString(
            string: "Xin gửi lời tri ân sâu sắc nhất đến:\n",
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: CSSTheme.dark.withAlphaComponent(0.85),
                .paragraphStyle: bodyParagraph
            ]
        )
        bodyText.append(NSAttributedString(
            string: "• Đội ngũ Phát triển & Vận hành: ",
            attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: CSSTheme.dark, .paragraphStyle: bodyParagraph]
        ))
        bodyText.append(NSAttributedString(
            string: "SideStore Team (@sidestoreio)\n",
            attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: CSSTheme.blue, .paragraphStyle: bodyParagraph]
        ))
        bodyText.append(NSAttributedString(
            string: "• Thiết kế giao diện gốc: ",
            attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: CSSTheme.dark, .paragraphStyle: bodyParagraph]
        ))
        bodyText.append(NSAttributedString(
            string: "@lit_ritt\n",
            attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: CSSTheme.purple, .paragraphStyle: bodyParagraph]
        ))
        bodyText.append(NSAttributedString(
            string: "• Tác giả nền tảng AltStore: ",
            attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .medium), .foregroundColor: CSSTheme.dark, .paragraphStyle: bodyParagraph]
        ))
        bodyText.append(NSAttributedString(
            string: "Riley Testut & Cộng đồng Mã nguồn mở",
            attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .semibold), .foregroundColor: CSSTheme.blue, .paragraphStyle: bodyParagraph]
        ))

        thanksBodyLabel.attributedText = bodyText

        // Hàng nút tương tác nhanh đến những người đóng góp
        let buttonsStack = UIStackView()
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        buttonsStack.axis = .horizontal
        buttonsStack.alignment = .center
        buttonsStack.distribution = .equalSpacing
        buttonsStack.spacing = 8

        let sideStoreBtn = makeCreditBadgeButton(title: " @sidestoreio ", color: CSSTheme.blue, action: #selector(creditSideStoreTapped))
        let designerBtn = makeCreditBadgeButton(title: " @lit_ritt ", color: CSSTheme.purple, action: #selector(creditDesignerTapped))
        let githubBtn = makeCreditBadgeButton(title: " GitHub ", color: CSSTheme.dark, action: #selector(followAltStoreGitHub))

        buttonsStack.addArrangedSubview(sideStoreBtn)
        buttonsStack.addArrangedSubview(designerBtn)
        buttonsStack.addArrangedSubview(githubBtn)

        gratitudeCard.addSubview(thanksTitleLabel)
        gratitudeCard.addSubview(thanksBodyLabel)
        gratitudeCard.addSubview(buttonsStack)

        // Nhãn Phiên bản ở dưới cùng
        let vLabel = UILabel()
        vLabel.tag = 7771
        vLabel.translatesAutoresizingMaskIntoConstraints = false
        vLabel.attributedText = getVersionAttributedString()
        vLabel.numberOfLines = 0
        vLabel.textAlignment = .center
        vLabel.isUserInteractionEnabled = true
        vLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(copyVersionLabelTapped)))

        footerContainer.addSubview(gratitudeCard)
        footerContainer.addSubview(vLabel)

        NSLayoutConstraint.activate([
            gratitudeCard.topAnchor.constraint(equalTo: footerContainer.topAnchor, constant: 10),
            gratitudeCard.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 20),
            gratitudeCard.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -20),

            thanksTitleLabel.topAnchor.constraint(equalTo: gratitudeCard.topAnchor, constant: 12),
            thanksTitleLabel.leadingAnchor.constraint(equalTo: gratitudeCard.leadingAnchor, constant: 12),
            thanksTitleLabel.trailingAnchor.constraint(equalTo: gratitudeCard.trailingAnchor, constant: -12),

            thanksBodyLabel.topAnchor.constraint(equalTo: thanksTitleLabel.bottomAnchor, constant: 6),
            thanksBodyLabel.leadingAnchor.constraint(equalTo: gratitudeCard.leadingAnchor, constant: 12),
            thanksBodyLabel.trailingAnchor.constraint(equalTo: gratitudeCard.trailingAnchor, constant: -12),

            buttonsStack.topAnchor.constraint(equalTo: thanksBodyLabel.bottomAnchor, constant: 10),
            buttonsStack.centerXAnchor.constraint(equalTo: gratitudeCard.centerXAnchor),
            buttonsStack.bottomAnchor.constraint(equalTo: gratitudeCard.bottomAnchor, constant: -12),

            vLabel.topAnchor.constraint(equalTo: gratitudeCard.bottomAnchor, constant: 14),
            vLabel.centerXAnchor.constraint(equalTo: footerContainer.centerXAnchor),
            vLabel.leadingAnchor.constraint(equalTo: footerContainer.leadingAnchor, constant: 16),
            vLabel.trailingAnchor.constraint(equalTo: footerContainer.trailingAnchor, constant: -16)
        ])

        self.tableView.tableFooterView = footerContainer
    }

    private func makeCreditBadgeButton(title: String, color: UIColor, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(title, for: .normal)
        btn.setTitleColor(color, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        btn.backgroundColor = color.withAlphaComponent(0.1)
        btn.layer.cornerRadius = 10
        btn.layer.borderWidth = 1.0
        btn.layer.borderColor = color.withAlphaComponent(0.25).cgColor
        btn.contentEdgeInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        btn.addTarget(self, action: action, for: .touchUpInside)
        return btn
    }

    @objc private func creditSideStoreTapped() {
        self.openTwitter(username: "sidestoreio")
    }

    @objc private func creditDesignerTapped() {
        self.openTwitter(username: "lit_ritt")
    }

    // Bóc tách lớp nền của InsetGroupTableViewCell để ép nhận diện CSS Card
    private func styleInnerCardOfCell(_ cell: UITableViewCell, at indexPath: IndexPath, totalRows: Int) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear

        let targetCardView: UIView = cell.subviews.first(where: {
            $0 !== cell.contentView && $0.frame.width > 100 && !($0 is UIButton)
        }) ?? cell.contentView

        targetCardView.backgroundColor = CSSTheme.white

        var corners: CACornerMask = []
        if totalRows == 1 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if indexPath.row == 0 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if indexPath.row == totalRows - 1 {
            corners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }

        targetCardView.layer.cornerRadius = corners.isEmpty ? 0 : CSSTheme.cornerRadius
        targetCardView.layer.maskedCorners = corners

        cell.layer.masksToBounds = false
        cell.layer.shadowColor = CSSTheme.blue.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 5)
        cell.layer.shadowRadius = 10
        cell.layer.shadowOpacity = 0.07

        let sepTag = 8888
        cell.contentView.viewWithTag(sepTag)?.removeFromSuperview()
        if indexPath.row < totalRows - 1 {
            let sep = UIView()
            sep.tag = sepTag
            sep.backgroundColor = CSSTheme.border
            sep.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 20),
                sep.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -20),
                sep.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1.0)
            ])
        }

        // Việt hóa và làm đẹp toàn bộ chữ bên trong Cell
        translateAndStyleLabelsInside(view: cell.contentView, section: Section.allCases[indexPath.section], row: indexPath.row)
    }

    // Bộ từ điển dịch tự động 100% các chuỗi tĩnh từ Storyboard & Hệ thống sang Tiếng Việt
    private func translateStaticText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dictionary: [String: String] = [
            // Tài khoản & Đăng nhập
            "Sign in with Apple ID": "Đăng nhập bằng ID Apple",
            "Sign In with Apple ID": "Đăng nhập bằng ID Apple",
            "Sign In": "Đăng nhập",
            "Name": "Họ tên",
            "Email": "Email",
            "Type": "Loại tài khoản",
            "Free Developer Account": "Tài khoản Nhà phát triển Miễn phí",
            "Regular Account": "Tài khoản Miễn phí",
            "Developer Account": "Tài khoản Nhà phát triển",
            "Paid Developer Account": "Tài khoản Nhà phát triển Trả phí",
            "Individual": "Cá nhân",
            "Organization": "Tổ chức",
            "Unknown": "Không xác định",

            // Các mục Fix Login & Cài đặt nâng cao
            "User Customizations": "Tùy chỉnh người dùng (User Customizations)",
            "Anisette Servers": "Máy chủ Anisette (Anisette Servers)",
            "Connection Configuration": "Cấu hình kết nối mạng",
            "Developer Portal Services": "Dịch vụ Cổng Nhà phát triển",
            "Developer Services": "Dịch vụ Nhà phát triển",
            "Certificate Management": "Quản lý chứng chỉ (Certificates)",
            "Certificates Management": "Quản lý chứng chỉ (Certificates)",
            "Refresh SideJITServer": "Cấu hình máy chủ SideJITServer",
            "SideJITServer": "Cấu hình máy chủ SideJITServer",
            "View Refresh Attempts": "Lịch sử làm mới ứng dụng",
            "Refresh Attempts": "Lịch sử làm mới ứng dụng",

            // Công cụ kỹ thuật & Giấy phép
            "Error Log": "Nhật ký lỗi hệ thống",
            "View Error Log": "Xem nhật ký lỗi hệ thống",
            "Clear Cache": "Xóa bộ nhớ đệm (Cache)",
            "Software Licenses": "Giấy phép phần mềm mã nguồn mở",

            // Chẩn đoán & Gỡ lỗi (Debug)
            "Developer Options": "Tùy chọn nhà phát triển",
            "Experimental Features": "Tính năng thử nghiệm",
            "Verbose Operations Logging": "Ghi nhật ký hoạt động chi tiết",
            "AltSign Verbose Logging": "Ghi nhật ký AltSign chi tiết",
            "Minimuxer Verbose Logging": "Ghi nhật ký Minimuxer chi tiết",
            "Rotate Logs on Startup": "Xoay vòng nhật ký khi khởi động",
            "Disable Response Caching": "Tắt lưu đệm phản hồi mạng",
            "Recreate Database on Next Start": "Tạo lại cơ sở dữ liệu ở lần mở tới"
        ]

        return dictionary[trimmed] ?? text
    }

    private func translateAndStyleLabelsInside(view: UIView, section: Section, row: Int) {
        let activeItems = UnifiedSettingsItem.activeItems
        let isClearCacheRow = (section == .advancedSettings && activeItems.indices.contains(row) && activeItems[row] == .clearCache)
        let isFixLoginHighlightRow = (section == .advancedSettings && activeItems.indices.contains(row) && (activeItems[row] == .userCustomizations || activeItems[row] == .anisetteServers))

        for subview in view.subviews {
            if let label = subview as? UILabel {
                if subview.superview is UIButton {
                    continue
                }

                // Dịch văn bản sang tiếng Việt nếu khớp từ điển
                if let currentText = label.text, !currentText.isEmpty {
                    label.text = translateStaticText(currentText)
                }

                if label == self.accountNameLabel || label == self.accountEmailLabel || label == self.accountTypeLabel {
                    if label == self.accountTypeLabel, let typeText = label.text {
                        label.text = translateStaticText(typeText)
                    }
                    label.textColor = (label == self.accountNameLabel) ? CSSTheme.blue : CSSTheme.purple
                    label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                } else if section == .signIn {
                    label.textColor = CSSTheme.blue
                    label.font = UIFont.systemFont(ofSize: 17, weight: .bold)
                } else if isClearCacheRow {
                    label.textColor = CSSTheme.magenta
                    label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
                } else if isFixLoginHighlightRow {
                    label.textColor = .black
                    label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
                } else if label.textColor == .systemRed {
                    label.textColor = CSSTheme.magenta
                } else {
                    label.textColor = .black
                    if label.font.pointSize >= 16 {
                        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                    }
                }
            }
            translateAndStyleLabelsInside(view: subview, section: section, row: row)
        }
    }

    // Xử lý bấm nút "Tài Khoản" để ẩn/hiện khung thông tin tài khoản
    @objc private func toggleAccountDetailsVisibility(_ sender: UIButton) {
        self.isAccountDetailsExpanded.toggle()

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseInOut) {
            self.tableView.beginUpdates()
            self.tableView.endUpdates()

            // Cập nhật tiêu đề nút Tài Khoản ngay lập tức
            if let headerView = self.tableView.headerView(forSection: Section.account.rawValue) as? SettingsHeaderFooterView {
                self.prepare(headerView, for: .account, isHeader: true)
            }

            // Ẩn/hiện mượt các dòng tài khoản
            for row in 0..<3 {
                if let cell = self.tableView.cellForRow(at: IndexPath(row: row, section: Section.account.rawValue)) {
                    cell.alpha = self.isAccountDetailsExpanded ? 1.0 : 0.0
                    cell.isHidden = !self.isAccountDetailsExpanded
                }
            }
        }
    }
}

private extension SettingsViewController
{
    private func getVersionAttributedString() -> NSAttributedString {
        var appVersion = Bundle.Info.activeBundleVersion
        appVersion = appVersion.replacingOccurrences(of: "Version ", with: "Phiên bản ")
        let iosVersion = "iOS \(UIDevice.current.systemVersion) (Bản dựng \(ProcessInfo.processInfo.operatingSystemBuild))"

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 5

        let fullString = NSMutableAttributedString()

        let appVersionAttr = NSAttributedString(
            string: appVersion,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                .foregroundColor: CSSTheme.blue,
                .paragraphStyle: paragraphStyle
            ]
        )

        let iosVersionAttr = NSAttributedString(
            string: "\n" + iosVersion,
            attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: CSSTheme.purple.withAlphaComponent(0.85),
                .paragraphStyle: paragraphStyle
            ]
        )

        fullString.append(appVersionAttr)
        fullString.append(iosVersionAttr)
        return fullString
    }

    @objc private func copyVersionLabelTapped() {
        let appVersion = Bundle.Info.activeBundleVersion
        let iosVersion = "iOS \(UIDevice.current.systemVersion) (\(ProcessInfo.processInfo.operatingSystemBuild))"
        let fullText = "\(appVersion)\n\(iosVersion)"
        #if !os(tvOS)
        UIPasteboard.general.string = fullText.hasPrefix("Version ") ? String(fullText.dropFirst("Version ".count)) : fullText
        #endif

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        let attributed = NSMutableAttributedString(
            string: "Đã sao chép phiên bản! ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                .foregroundColor: CSSTheme.blue,
                .paragraphStyle: paragraphStyle
            ]
        )
        attributed.append(NSAttributedString(string: "✓", attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .bold),
            .foregroundColor: CSSTheme.green
        ]))

        self.versionLabel?.attributedText = attributed
        if let footerLabel = self.tableView.tableFooterView?.viewWithTag(7771) as? UILabel {
            footerLabel.attributedText = attributed
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            let normalAttr = self.getVersionAttributedString()
            self.versionLabel?.attributedText = normalAttr
            if let footerLabel = self.tableView.tableFooterView?.viewWithTag(7771) as? UILabel {
                footerLabel.attributedText = normalAttr
            }
        }
    }

    private func update()
    {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let currentActiveTeam = try? await AuthManager.shared.getAuthenticatedTeam()
            let appleID = AuthManager.shared.currentAppleID
            verboseLog("[SettingsVC] update() called. activeTeam: \(currentActiveTeam?.identifier ?? "nil"), account: \(appleID ?? "nil")")

            if let team = currentActiveTeam, AuthManager.shared.isAuthenticated
            {
                self.accountNameLabel.text = team.name
                self.accountEmailLabel.text = appleID
                self.accountTypeLabel.text = self.translateStaticText(team.type.localizedDescription)

                self.activeTeam = team
                self.startAccountVerification(for: team)
            }
            else
            {
                self.activeTeam = nil
                self.accountVerificationTask?.cancel()
                self.accountVerificationTask = nil
                self.accountStatus = .completed
                self.updateAccountCardRowStyles()
            }
            self.tableView.reloadData()
        }

        // Đảm bảo LÀM MỚI ỨNG DỤNG & BETA luôn tắt cứng
        self.forceDisableUnusedSettings()

        self.disableResponseCachingSwitch?.isOn = UserDefaults.standard.responseCachingDisabled
        self.verboseOperationsLoggingSwitch?.isOn = UserDefaults.standard.isVerboseOperationsLoggingEnabled
        self.altSignVerboseLoggingSwitch?.isOn = UserDefaults.standard.isAltSignVerboseLoggingEnabled
        self.minimuxerVerboseLoggingSwitch?.isOn = UserDefaults.standard.isMinimuxerVerboseLoggingEnabled
        self.rotateLogsOnStartupSwitch?.isOn = UserDefaults.standard.isRotateLogsOnStartupEnabled
        self.recreateDatabaseSwitch?.isOn = UserDefaults.standard.recreateDatabaseOnNextStart

        if self.isViewLoaded
        {
            self.tableView.reloadData()
        }
    }

    private func startAccountVerification(for team: ALTTeam)
    {
        self.accountVerificationTask?.cancel()
        self.accountVerificationTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            if !UserDefaults.standard.isDeviceRegistered {
                self.accountStatus = .checking
                self.tableView.reloadData()
                self.updateAccountCardRowStyles()
            }
            let status = await AccountVerificationRow.verifyStatus(for: team)
            if !Task.isCancelled {
                self.accountStatus = status
                self.tableView.reloadData()
                self.updateAccountCardRowStyles()
            }
        }
    }

    private func updateAccountCardRowStyles()
    {
        guard self.isViewLoaded else { return }
        let typeIndexPath = IndexPath(row: 2, section: Section.account.rawValue)
        if let typeCell = self.tableView.cellForRow(at: typeIndexPath) as? InsetGroupTableViewCell {
            typeCell.style = (self.accountStatus == .completed) ? .bottom : .middle
        }
    }

    private func resolvePendingAccountActions()
    {
        guard let team = self.activeTeam else { return }
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await AccountVerificationRow.resolvePendingActions(for: self.accountStatus, team: team, presentingViewController: self)
            self.startAccountVerification(for: team)
        }
    }

    private func prepare(_ settingsHeaderFooterView: SettingsHeaderFooterView, for section: Section, isHeader: Bool)
    {
        settingsHeaderFooterView.primaryLabel.isHidden = !isHeader
        settingsHeaderFooterView.secondaryLabel.isHidden = isHeader
        settingsHeaderFooterView.button.isHidden = true

        settingsHeaderFooterView.primaryLabel.textColor = CSSTheme.blue
        settingsHeaderFooterView.primaryLabel.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        settingsHeaderFooterView.secondaryLabel.textColor = CSSTheme.dark.withAlphaComponent(0.78)
        settingsHeaderFooterView.secondaryLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)

        // Xóa nút Tài Khoản cũ nếu được tái sử dụng cho section khác
        let toggleAccountTag = 9992
        settingsHeaderFooterView.contentView.viewWithTag(toggleAccountTag)?.removeFromSuperview()

        // Vẽ thanh gạch chân màu xanh (.features h2::after) dưới mỗi tiêu đề
        let underlineTag = 9991
        settingsHeaderFooterView.contentView.viewWithTag(underlineTag)?.removeFromSuperview()
        if isHeader {
            let underline = UIView()
            underline.tag = underlineTag
            underline.backgroundColor = CSSTheme.blue
            underline.layer.cornerRadius = 1.5
            underline.translatesAutoresizingMaskIntoConstraints = false
            settingsHeaderFooterView.contentView.addSubview(underline)
            NSLayoutConstraint.activate([
                underline.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.leadingAnchor),
                underline.topAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.bottomAnchor, constant: 2),
                underline.widthAnchor.constraint(equalToConstant: 38),
                underline.heightAnchor.constraint(equalToConstant: 3)
            ])
        }

        settingsHeaderFooterView.layoutMargins.bottom = isHeader ? 6 : 8

        switch section
        {
        case .signIn:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = "TÀI KHOẢN"
            } else {
                settingsHeaderFooterView.secondaryLabel.text = "Đăng nhập bằng ID Apple của bạn để tải xuống và làm mới ứng dụng. Nếu gặp lỗi đăng nhập, hãy cấu hình trong mục Tùy chỉnh người dùng và Máy chủ Anisette bên dưới."
            }

        case .account:
            settingsHeaderFooterView.primaryLabel.text = "TÀI KHOẢN"

            // 1. Nút "Tài Khoản" nhỏ gọn để bấm Ẩn/Hiện thông tin nhạy cảm
            let toggleBtn = UIButton(type: .system)
            toggleBtn.tag = toggleAccountTag
            toggleBtn.translatesAutoresizingMaskIntoConstraints = false
            let toggleTitle = self.isAccountDetailsExpanded ? "  Ẩn Tài Khoản ▲  " : "  Tài Khoản ▼  "
            toggleBtn.setTitle(toggleTitle, for: .normal)
            toggleBtn.setTitleColor(CSSTheme.white, for: .normal)
            toggleBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            toggleBtn.backgroundColor = self.isAccountDetailsExpanded ? CSSTheme.purple : CSSTheme.blue
            toggleBtn.layer.cornerRadius = 12
            toggleBtn.layer.shadowColor = CSSTheme.blue.cgColor
            toggleBtn.layer.shadowOffset = CGSize(width: 0, height: 2)
            toggleBtn.layer.shadowRadius = 4
            toggleBtn.layer.shadowOpacity = 0.25
            toggleBtn.addTarget(self, action: #selector(toggleAccountDetailsVisibility(_:)), for: .touchUpInside)

            settingsHeaderFooterView.contentView.addSubview(toggleBtn)

            // 2. Nút "ĐĂNG XUẤT" nhỏ gọn nằm bên phải
            let signOutBtn = settingsHeaderFooterView.button!
            signOutBtn.removeTarget(nil, action: nil, for: .allEvents)
            signOutBtn.setTitle("  ĐĂNG XUẤT  ", for: .normal)
            signOutBtn.setTitleColor(CSSTheme.white, for: .normal)
            signOutBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
            signOutBtn.backgroundColor = CSSTheme.magenta
            signOutBtn.layer.cornerRadius = 12
            signOutBtn.layer.shadowColor = CSSTheme.magenta.cgColor
            signOutBtn.layer.shadowOffset = CGSize(width: 0, height: 2)
            signOutBtn.layer.shadowRadius = 5
            signOutBtn.layer.shadowOpacity = 0.3
            signOutBtn.addTarget(self, action: #selector(SettingsViewController.signOut(_:)), for: .primaryActionTriggered)
            signOutBtn.isHidden = false

            NSLayoutConstraint.activate([
                toggleBtn.leadingAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.trailingAnchor, constant: 10),
                toggleBtn.centerYAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.centerYAnchor),
                toggleBtn.heightAnchor.constraint(equalToConstant: 24)
            ])

        case .advancedSettings:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = "TRUNG TÂM CÀI ĐẶT & HỆ THỐNG"
            } else {
                settingsHeaderFooterView.secondaryLabel.text = "Quản lý Máy chủ Anisette, Tùy chỉnh người dùng (Reset adi.pb / Đồng bộ cấu hình), Chứng chỉ và dọn dẹp bộ nhớ đệm để tối ưu hóa hoạt động của SideStore."
            }

        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            break
        }
    }

    private func preferredHeight(for settingsHeaderFooterView: SettingsHeaderFooterView, in section: Section, isHeader: Bool) -> CGFloat
    {
        let widthConstraint = settingsHeaderFooterView.contentView.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        NSLayoutConstraint.activate([widthConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint]) }

        self.prepare(settingsHeaderFooterView, for: section, isHeader: isHeader)

        let size = settingsHeaderFooterView.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        if section == .account && isHeader {
            return max(34, size.height)
        }
        return size.height + (isHeader ? 4 : 0)
    }

    // Chỉ giữ lại phần Đăng nhập/Tài khoản và 1 mục gộp chung duy nhất (.advancedSettings)
    private func isSectionHidden(_ section: Section) -> Bool
    {
        switch section {
        case .signIn, .account, .advancedSettings:
            return false
        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            return true
        }
    }
}

private extension SettingsViewController
{
    private func signIn()
    {
        debugLog("[SettingsVC] signIn() invoked by user action")
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                let result = try await AuthManager.shared.signIn(presentingViewController: self)
                debugLog("[SettingsVC] signIn() authentication succeeded for team: \(result.team.name) (\(result.team.identifier))")
            } catch is CancellationError {
                debugLog("[SettingsVC] signIn() authentication cancelled by user")
            } catch {
                debugLog("[SettingsVC] signIn() authentication failed with error: \(error)")
                let toastView = ToastView(error: error)
                toastView.show(in: self.view)
            }

            debugLog("[SettingsVC] signIn() calling update()...")
            self.update()
        }
    }

    @objc private func signOut(_ sender: UIBarButtonItem)
    {
        debugLog("[SettingsVC] signOut() invoked by user action")
        let contentVC = SignOutAlertViewController()

        let alertController = UIAlertController(
            title: "Đăng xuất tài khoản",
            message: "Bạn có chắc chắn muốn đăng xuất không? Bạn sẽ không thể cài đặt hoặc làm mới ứng dụng sau khi đăng xuất.",
            preferredStyle: .alert
        )

        alertController.setValue(contentVC, forKey: "contentViewController")

        let cancelAction = UIAlertAction(title: "Hủy", style: .cancel, handler: nil)

        let signOutAction = UIAlertAction(title: "Đăng xuất", style: .destructive) { [weak self] _ in
            let keepCert = contentVC.isChecked
            let keepAnisette = contentVC.isKeepAnisetteChecked
            let keepAnisetteHeaders = contentVC.isKeepAnisetteHeadersChecked
            let keepSideSignHeaders = contentVC.isKeepSideSignHeadersChecked
            Task.detached { [weak self] in
                await AuthManager.shared.signOut(
                    keepCertificate: keepCert,
                    keepAnisetteData: keepAnisette,
                    keepAnisetteHeaders: keepAnisetteHeaders,
                    keepSideSignHeaders: keepSideSignHeaders
                )
                await MainActor.run {
                    self?.update()
                }
            }
        }

        alertController.addAction(cancelAction)
        alertController.addAction(signOutAction)

        self.present(alertController, animated: true, completion: nil)
    }

    // Khóa cứng trạng thái tắt cho các IBAction không dùng nhưng giữ kết nối Storyboard an toàn
    @IBAction private func toggleDisableAppLimit(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isAppLimitDisabled = false
    }

    @IBAction private func toggleIsBackgroundRefreshEnabled(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isBackgroundRefreshEnabled = false
    }

    @IBAction private func toggleNoIdleTimeoutEnabled(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isIdleTimeoutDisableEnabled = false
    }

    @IBAction private func toggleEnableBetaUpdates(_ sender: UISwitch) {
        sender.setOn(false, animated: false)
        UserDefaults.standard.isBetaUpdatesEnabled = false
    }

    @IBAction private func toggleVerboseOperationsLogging(_ sender: UISwitch) {
        UserDefaults.standard.isVerboseOperationsLoggingEnabled = sender.isOn
    }

    @IBAction private func toggleAltSignVerboseLogging(_ sender: UISwitch) {
        UserDefaults.standard.isAltSignVerboseLoggingEnabled = sender.isOn
        AltSign.setLogging(sender.isOn)
    }

    @IBAction private func toggleMinimuxerVerboseLogging(_ sender: UISwitch) {
        UserDefaults.standard.isMinimuxerVerboseLoggingEnabled = sender.isOn
        minimuxerSetLogging(sender.isOn)
    }

    @IBAction private func toggleRotateLogsOnStartup(_ sender: UISwitch) {
        UserDefaults.standard.isRotateLogsOnStartupEnabled = sender.isOn
        let suffixFormat: SuffixFormat = sender.isOn ? .timestamp : .none
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.consoleLog.updateConfiguration(baseName: "console", suffixFormat: suffixFormat, policy: .immediate)
    }

    @IBAction private func toggleRecreateDatabaseSwitch(_ sender: UISwitch) {
        UserDefaults.standard.recreateDatabaseOnNextStart = sender.isOn
        guard sender.isOn else { return }

        DispatchQueue.global().async {
            for time in (1...3).reversed() {
                DispatchQueue.main.async {
                    guard UserDefaults.standard.recreateDatabaseOnNextStart else { return }
                    let toast = ToastView(text: "Đã lên lịch xóa Cơ sở dữ liệu ở lần mở tới", detailText: "Ứng dụng sẽ đóng sau \(time) giây...")
                    toast.tintColor = CSSTheme.purple
                    toast.preferredDuration = 1
                    toast.show(in: self)
                }
                sleep(1)
            }

            DispatchQueue.main.async {
                guard UserDefaults.standard.recreateDatabaseOnNextStart else { return }
                exit(0)
            }
        }
    }

    @IBAction private func toggleDisableResponseCaching(_ sender: UISwitch) {
        UserDefaults.standard.responseCachingDisabled = sender.isOn
    }

    private func clearCache()
    {
        let makeCacheTitle: (String) -> String = { sizeString in
            String(format: "Bạn có chắc chắn muốn xóa bộ nhớ đệm của SideStore không?\n\nDung lượng đệm: %@", sizeString)
        }
        let alertController = UIAlertController(title: makeCacheTitle("Đang tính toán…"),
                                                message: "Thao tác này sẽ xóa toàn bộ tệp tạm thời cũng như bản sao lưu của các ứng dụng đã gỡ cài đặt.",
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel) { [weak self] _ in
            self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
        })
        alertController.addAction(UIAlertAction(title: "Xóa bộ nhớ đệm", style: .destructive) { [weak self] _ in
            AppManager.shared.clearAppCache { result in
                DispatchQueue.main.async {
                    self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
                    switch result {
                    case .success: break
                    case .failure(let error):
                        let alertController = UIAlertController(title: "Không thể xóa bộ nhớ đệm", message: error.localizedDescription, preferredStyle: .alert)
                        alertController.addAction(.ok)
                        self?.present(alertController, animated: true)
                    }
                }
            }
        })

        if let popoverController = alertController.popoverPresentationController {
            popoverController.sourceView = self.view
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }

        self.present(alertController, animated: true)

        CacheManager.shared.formattedCacheSize { [weak alertController] sizeString in
            DispatchQueue.main.async {
                alertController?.title = makeCacheTitle(sizeString)
            }
        }
    }

    @IBAction private func handleDebugModeGesture(_ gestureRecognizer: UISwipeGestureRecognizer)
    {
        self.debugGestureCounter += 1
        self.debugGestureTimer?.invalidate()

        if self.debugGestureCounter >= 3
        {
            self.debugGestureCounter = 0
            UserDefaults.standard.isDebugModeEnabled.toggle()
            self.tableView.reloadData()
        }
        else
        {
            self.debugGestureTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] (timer) in
                self?.debugGestureCounter = 0
            }
        }
    }

    private func openTwitter(username: String)
    {
        let twitterAppURL = URL(string: "twitter://user?screen_name=" + username)!
        UIApplication.shared.open(twitterAppURL, options: [:]) { (success) in
            if success {
                if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
                    self.tableView.deselectRow(at: selectedIndexPath, animated: true)
                }
            } else {
                let safariURL = URL(string: "https://twitter.com/" + username)!
                self.openWebURL(safariURL, preferredTintColor: CSSTheme.blue)
            }
        }
    }

    private func openMastodon(username: String)
    {
        let components = username.split(separator: "@")
        guard components.count == 2 else { return }
        let server = String(components[1])
        let username = "@" + String(components[0])
        guard let serverURL = URL(string: "https://" + server) else { return }
        let mastodonURL = serverURL.appendingPathComponent(username)
        UIApplication.shared.open(mastodonURL, options: [:])
    }

    private func openThreads(username: String)
    {
        let safariURL = URL(string: "https://www.threads.net/@" + username)!
        UIApplication.shared.open(safariURL, options: [:])
    }

    // Giữ nguyên các @IBAction kết nối với Storyboard để không bao giờ gây crash khi nạp Nib
    @IBAction private func followAltStoreMastodon() { self.openMastodon(username: "@sidestoreio@fosstodon.org") }
    @IBAction private func followAltStoreThreads() { self.openThreads(username: "sidestore.io") }
    @IBAction private func followAltStoreTwitter() { self.openTwitter(username: "sidestoreio") }
    @IBAction private func followAltStoreGitHub() { UIApplication.shared.open(AppConstants.URLs.sideStoreGitHub, options: [:]) }
}

private extension SettingsViewController
{
    @objc private func openPatreonSettings(_ notification: Notification)
    {
        // Đã xoá ỦNG HỘ CHÚNG TÔI
    }

    @objc private func openErrorLog(_: Notification) {
        guard self.presentedViewController == nil else { return }
        self.navigationController?.popViewController(animated: false)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.performSegue(withIdentifier: "showErrorLog", sender: nil)
        }
    }
}

extension SettingsViewController
{
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        let section = Section.allCases[indexPath.section]
        if isSectionHidden(section) {
            return 0.0
        }

        if section == .account {
            // Nếu đang thu gọn khung Tài khoản, cho chiều cao 3 dòng Tên/Email/Loại về 0
            if indexPath.row < 3 && !self.isAccountDetailsExpanded {
                return 0.0
            }
            if indexPath.row == 3 {
                return AccountVerificationRow.preferredHeight
            }
        }

        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { return 0.0 }
            return super.tableView(tableView, heightForRowAt: activeItems[indexPath.row].originalIndexPath)
        }

        return super.tableView(tableView, heightForRowAt: indexPath)
    }

    // ✨ CAN THIỆP SÂU VÀO TỪNG CELL ĐỂ ÁP DỤNG CARD THEME & ẨN/HIỆN TÀI KHOẢN ✨
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        let totalRows = self.tableView(tableView, numberOfRowsInSection: indexPath.section)

        if section == .account {
            if indexPath.row < 3 {
                cell.clipsToBounds = true
                cell.isHidden = !self.isAccountDetailsExpanded
                cell.alpha = self.isAccountDetailsExpanded ? 1.0 : 0.0
            }

            if indexPath.row == 2, let insetCell = cell as? InsetGroupTableViewCell {
                insetCell.style = (self.accountStatus == .completed) ? .bottom : .middle
            } else if indexPath.row == 3, let actionCell = cell as? AccountVerificationRow {
                actionCell.style = self.isAccountDetailsExpanded ? .bottom : .single
                actionCell.backgroundColor = .clear
                actionCell.contentView.backgroundColor = .clear
                if #available(iOS 14.0, tvOS 14.0, *) {
                    actionCell.backgroundConfiguration = .clear()
                }
                return
            }
        }

        // Áp dụng cấu trúc Card CSS & Việt hóa cho tất cả các dòng
        self.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
    }

    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int
    {
        let section = Section.allCases[indexPath.section]
        if section == .account && indexPath.row == 3 {
            return 0
        }
        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { return 0 }
            return super.tableView(tableView, indentationLevelForRowAt: activeItems[indexPath.row].originalIndexPath)
        }
        return super.tableView(tableView, indentationLevelForRowAt: indexPath)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 0
        case .signIn: return (self.activeTeam == nil) ? 1 : 0
        case .account: return (self.activeTeam == nil) ? 0 : (self.accountStatus == .completed ? 3 : 4)
        case .advancedSettings: return UnifiedSettingsItem.activeItems.count
        default: return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let section = Section.allCases[indexPath.section]
        if section == .account && indexPath.row == 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: AccountVerificationRow.reuseIdentifier) as? AccountVerificationRow
                ?? AccountVerificationRow()
            cell.configure(with: self.accountStatus)
            cell.style = self.isAccountDetailsExpanded ? .bottom : .single
            return cell
        }

        let effectiveIndexPath: IndexPath
        if section == .advancedSettings {
            let activeItems = UnifiedSettingsItem.activeItems
            effectiveIndexPath = activeItems[indexPath.row].originalIndexPath
        } else {
            effectiveIndexPath = indexPath
        }

        let cell = super.tableView(tableView, cellForRowAt: effectiveIndexPath)

        if section == .account && indexPath.row == 2 {
            if let insetCell = cell as? InsetGroupTableViewCell {
                insetCell.style = (self.accountStatus == .completed) ? .bottom : .middle
            }
        }

        // Cập nhật lại bo góc (top/middle/bottom) cho mục gộp chung duy nhất
        if section == .advancedSettings,
           let insetCell = cell as? InsetGroupTableViewCell {
            let total = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
            if total == 1 {
                insetCell.style = .single
            } else if indexPath.row == 0 {
                insetCell.style = .top
            } else if indexPath.row == total - 1 {
                insetCell.style = .bottom
            } else {
                insetCell.style = .middle
            }
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView?
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return nil
        case .signIn where self.activeTeam != nil: return nil
        case .account where self.activeTeam == nil: return nil
        case .signIn, .account, .advancedSettings:
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(headerView, for: section, isHeader: true)
            return headerView

        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return nil
        case .signIn where self.activeTeam != nil: return nil
        case .signIn, .advancedSettings:
            let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(footerView, for: section, isHeader: false)
            return footerView

        case .account, .patreon, .display, .appRefresh, .credits, .techyThings, .instructions, .betaTesting, .diagnostics:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 0.01
        case .signIn where self.activeTeam != nil: return 0.01
        case .account where self.activeTeam == nil: return 0.01
        case .signIn, .account, .advancedSettings:
            return self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: true)
        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            return 0.01
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 0.01
        case .signIn where self.activeTeam != nil: return 0.01
        case .account where self.activeTeam == nil: return 0.01
        case .signIn, .advancedSettings:
            return self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: false)
        case .account, .patreon, .display, .appRefresh, .credits, .techyThings, .instructions, .betaTesting, .diagnostics:
            return 0.01
        }
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(translationX: 5, y: -2).scaledBy(x: 0.98, y: 0.98)
            }) { _ in
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                    cell.transform = .identity
                }, completion: nil)
            }
        }

        let section = Section.allCases[indexPath.section]
        verboseLog("[SettingsVC] didSelectRowAt: section \(section) (index \(indexPath.section)), row \(indexPath.row)")
        switch section
        {
        case .signIn:
            self.signIn()

        case .account:
            if indexPath.row == 3 {
                tableView.deselectRow(at: indexPath, animated: true)
                self.resolvePendingAccountActions()
            }

        case .advancedSettings:
            let activeItems = UnifiedSettingsItem.activeItems
            guard activeItems.indices.contains(indexPath.row) else { break }
            let item = activeItems[indexPath.row]

            switch item {
            case .userCustomizations:
                let userCustomizationsView = UserCustomizationsView()
                let vc = UIHostingController(rootView: userCustomizationsView)
                vc.view.backgroundColor = .settingsBackground
                vc.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: vc), sender: nil)

            case .anisetteServers:
                let anisetteServersView = AnisetteServersView(
                    selected: UserDefaults.standard.menuAnisetteURL,
                    onResetAdiPb: { [weak self] in
                        guard let self = self else { return }
                        ToastView(text: "Đã đặt lại adi.pb thành công!", detailText: "Vui lòng đăng nhập lại tài khoản ID Apple trong SideStore.")
                            .show(in: self)
                    }
                )
                let vc = UIHostingController(rootView: anisetteServersView)
                vc.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "anisetteServers", source: self, destination: vc), sender: nil)

            case .connectionConfig:
                let connectionConfigView = ConnectionConfigView()
                let vc = UIHostingController(rootView: connectionConfigView)
                vc.title = nil
                self.navigationController?.pushViewController(vc, animated: true)

            case .developerServices:
                let developerServicesView = DeveloperServicesView(presentingViewController: self)
                let vc = UIHostingController(rootView: developerServicesView)
                vc.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "developerServices", source: self, destination: vc), sender: nil)

            case .certificateManagement:
                let vc = UIHostingController(rootView: CertificatesView(presentingViewController: self))
                vc.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "certificateManagement", source: self, destination: vc), sender: nil)

            case .refreshSideJITServer:
                let vc = UIHostingController(rootView: SideJITServerConfigView())
                vc.title = nil
                self.navigationController?.pushViewController(vc, animated: true)

            case .refreshAttempts, .errorLog, .softwareLicenses:
                // Được kích hoạt tự động qua Storyboard Segue gắn liền trên Cell gốc
                break

            case .clearCache:
                self.clearCache()

            case .developerOptions:
                let hostingController = UIHostingController(rootView: DeveloperOptionsView())
                hostingController.view.backgroundColor = .settingsBackground
                hostingController.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: hostingController), sender: nil)

            case .experimentalFeatures:
                let hostingController = UIHostingController(rootView: ExperimentalFeaturesView())
                hostingController.view.backgroundColor = .settingsBackground
                hostingController.title = nil
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: hostingController), sender: nil)
            }

        case .patreon, .display, .appRefresh, .instructions, .techyThings, .credits, .betaTesting, .diagnostics:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}

#if !os(tvOS)
extension SettingsViewController: MFMailComposeViewControllerDelegate
{
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?)
    {
        if let error = error {
            let toastView = ToastView(error: error)
            toastView.show(in: self)
        }
        controller.dismiss(animated: true, completion: nil)
    }
}
#endif

extension SettingsViewController: UIGestureRecognizerDelegate
{
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        #if !os(tvOS)
        if gestureRecognizer === self.navigationController?.interactivePopGestureRecognizer {
            return (self.navigationController?.viewControllers.count ?? 0) > 1
        }
        #endif
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool
    {
        return true
    }
}

#if !os(tvOS)
extension SettingsViewController: INUIAddVoiceShortcutViewControllerDelegate
{
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?)
    {
        if let indexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        controller.dismiss(animated: true, completion: nil)
        guard let error = error else { return }
        let toastView = ToastView(error: error)
        toastView.show(in: self)
    }

    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController)
    {
        if let indexPath = self.tableView.indexPathForSelectedRow {
            self.tableView.deselectRow(at: indexPath, animated: true)
        }
        controller.dismiss(animated: true, completion: nil)
    }
}
#endif
