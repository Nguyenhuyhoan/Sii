
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
    
    // Hero Gradient (rgba(0,123,255,.85) -> rgba(111,66,193,.75))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.9).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.85).cgColor
    
    static let cornerRadius: CGFloat = 15.0
}

extension SettingsViewController
{
    private enum Section: Int, CaseIterable
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
    
    private enum AppRefreshRow: Int, CaseIterable
    {
        case backgroundRefresh
        case noIdleTimeout
        case addToSiri
        case disableAppLimit
        
        static var allCases: [AppRefreshRow] {
            var c: [AppRefreshRow] = [.backgroundRefresh, .noIdleTimeout, .addToSiri]
            if UserDefaults.standard.isCowExploitSupported || !ProcessInfo().sparseRestorePatched
            {
                c.append(.disableAppLimit)
            }
            return c
        }
    }
    
    private enum CreditsRow: Int, CaseIterable
    {
        case developer
        case operations
        case designer
        case softwareLicenses
    }
    
    private enum TechyThingsRow: Int, CaseIterable
    {
        case healthCheck
        case errorLog
        case storageExplorer
        case clearCache
    }
    
    private enum AdvancedSettingsRow: Int, CaseIterable
    {
        case sendFeedback
        case refreshAttempts
        case refreshSideJITServer
        case pairingFileManagement
        case anisetteServers
        case connectionConfig
        case networkDiscovery
        case developerServices
        case profileManagement
        case certificateManagement
        case backupAndRestore
        case userCustomizations
        
        static var allCases: [AdvancedSettingsRow] {
            var rows: [AdvancedSettingsRow] = [.sendFeedback, .refreshAttempts, .refreshSideJITServer, .pairingFileManagement]
            if !UserDefaults.standard.useOnDeviceAnisette {
                rows.append(.anisetteServers)
            }
            rows.append(contentsOf: [
                .connectionConfig,
                .networkDiscovery,
                .developerServices,
                .profileManagement,
                .certificateManagement,
                .backupAndRestore,
                .userCustomizations
            ])
            return rows
        }
    }
    
    private enum BetaTestingRow: Int, CaseIterable {
        case betaUpdates
        case betaTrack
    }
    
    private enum DiagnosticsRow: Int, CaseIterable
    {
        case developerOptions
        case experimentalFeatures
    }
}

final class SettingsViewController: UITableViewController
{
    private var activeTeam: ALTTeam?
    private var accountStatus: AccountVerificationRow.Status = .completed
    private var accountVerificationTask: Task<Void, Never>?
    
    private var prototypeHeaderFooterView: SettingsHeaderFooterView!
    private var heroGradientLayer: CAGradientLayer?
    
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
    
    private func handleReleaseChannelSelection(_ channel: String) {
        UserDefaults.standard.betaUdpatesTrack = channel
        updateReleaseChannelButtonTitle()
    }
    
    private func updateReleaseChannelButtonTitle() {
        let channel = UserDefaults.standard.betaUdpatesTrack ?? UserDefaults.defaultBetaUpdatesTrack
        betaTrackPopupButton.setTitle(channel, for: .normal)
    }
    
    private func configureReleaseChannelButton() {
        let currentTrack = UserDefaults.standard.betaUdpatesTrack
        var trackOptions: [String] = ReleaseTrackType.betaTracks.map {$0.rawValue}
        
        if let currentTrack{
            trackOptions = [currentTrack] + trackOptions.filter { $0 != currentTrack }
        }
        
        let items = trackOptions.map{ channel in
            UIAction(title: channel, handler: { [weak self] _ in
                self?.handleReleaseChannelSelection(channel)
            })
        }
        
        let menu = UIMenu(title: "", options: [.singleSelection, .displayInline], children: items)
        #if !os(tvOS)
        betaTrackPopupButton.menu = menu
        #else
        if #available(tvOS 17.0, *) {
            betaTrackPopupButton.menu = menu
        }
        #endif
        
        updateReleaseChannelButtonTitle()
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
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
        
        self.tableView.contentInset.bottom = 50
        
        // ✨ KÍCH HOẠT GIAO DIỆN WEB CSS ✨
        self.applySmartWebCSSTheme()
        
        self.update()
        configureReleaseChannelButton()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let bgView = self.tableView.backgroundView,
           let gradientLayer = bgView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = self.tableView.bounds
        }
        if let heroHeader = self.tableView.tableHeaderView,
           let heroCard = heroHeader.subviews.first {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(false, animated: animated)
        self.update()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.accountVerificationTask?.cancel()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "anisetteServers" || segue.identifier == "developerServices" || segue.identifier == "profileManagement" || segue.identifier == "certificateManagement" || segue.identifier == "diagnostics" {
            let controller = segue.destination
            
            #if !os(tvOS)
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
            appearance.backgroundColor = CSSTheme.white.withAlphaComponent(0.75)
            appearance.titleTextAttributes = [.foregroundColor: CSSTheme.blue]
            appearance.largeTitleTextAttributes = [.foregroundColor: CSSTheme.blue]
            
            controller.navigationItem.largeTitleDisplayMode = .always
            controller.navigationItem.standardAppearance = appearance
            controller.navigationItem.scrollEdgeAppearance = appearance
            #endif
            
            self.show(controller, sender: nil)
        } else {
            super.prepare(for: segue, sender: sender)
        }
    }
}

// MARK: - ✨ HỆ THỐNG RENDER CSS THÔNG MINH
private extension SettingsViewController {
    
    func applySmartWebCSSTheme() {
        // 1. Nền Body: linear-gradient(to right, #f3e0ff, #e0f7ff)
        let bgView = UIView(frame: self.tableView.bounds)
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = self.tableView.bounds
        gradientLayer.colors = [CSSTheme.bgGradientStart, CSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        bgView.layer.insertSublayer(gradientLayer, at: 0)
        
        self.tableView.backgroundView = bgView
        self.tableView.backgroundColor = .clear
        self.tableView.separatorStyle = .none // Tắt vạch kẻ mặc định xấu xí của iOS
        
        // 2. Tạo khối .hero Banner ở đầu trang cài đặt
        setupCSSHeroBanner()
        
        // 3. Thanh điều hướng kính mờ (.site-header / nav)
        #if !os(tvOS)
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundEffect = UIBlurEffect(style: .systemThinMaterialLight)
        navAppearance.backgroundColor = CSSTheme.white.withAlphaComponent(0.8)
        navAppearance.shadowColor = CSSTheme.magenta.withAlphaComponent(0.15)
        navAppearance.titleTextAttributes = [
            .foregroundColor: CSSTheme.blue,
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: CSSTheme.blue,
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy)
        ]
        
        self.navigationController?.navigationBar.standardAppearance = navAppearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = navAppearance
        self.navigationController?.navigationBar.tintColor = CSSTheme.blue
        #endif
        
        // 4. Làm đẹp các công tắc UISwitch (Đổ bóng Neon)
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
            sw.layer.shadowOffset = CGSize(width: 0, height: 4)
            sw.layer.shadowRadius = 8
            sw.layer.shadowOpacity = 0.3
        }
        
        // 5. Nút chọn kênh Beta (Chuẩn class .lang-btn trong CSS)
        if let btn = self.betaTrackPopupButton {
            btn.backgroundColor = CSSTheme.white
            btn.setTitleColor(CSSTheme.blue, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            btn.layer.cornerRadius = 10
            btn.layer.borderWidth = 1.5
            btn.layer.borderColor = CSSTheme.border.cgColor
            // box-shadow: 0 10px 20px rgba(255,0,255,.25)
            btn.layer.shadowColor = CSSTheme.magenta.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 6)
            btn.layer.shadowRadius = 12
            btn.layer.shadowOpacity = 0.28
            btn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        }
        
        // 6. Các nút Mạng xã hội (Chuẩn 4 màu của .tab-button[data-tab="1..4"] trong CSS)
        let socialButtons = [
            (self.mastodonButton, CSSTheme.magenta), // data-tab="1": #f0f
            (self.threadsButton, CSSTheme.purple),   // data-tab="2": --purple
            (self.twitterButton, CSSTheme.blue),     // data-tab="3": --blue
            (self.githubButton, CSSTheme.green)      // data-tab="4": --green
        ]
        
        for (button, color) in socialButtons {
            guard let btn = button else { continue }
            let image = btn.configuration?.background.image ?? btn.image(for: .normal)
            btn.configuration = nil
            btn.setImage(image?.withRenderingMode(.alwaysTemplate), for: .normal)
            btn.tintColor = color
            btn.imageView?.contentMode = .scaleAspectFit
            
            btn.backgroundColor = CSSTheme.white
            btn.layer.cornerRadius = CSSTheme.cornerRadius
            btn.layer.borderWidth = 2.0
            btn.layer.borderColor = CSSTheme.border.cgColor
            btn.layer.shadowColor = color.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 8)
            btn.layer.shadowRadius = 14
            btn.layer.shadowOpacity = 0.3
            
            btn.addTarget(self, action: #selector(animateButtonPress(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(animateButtonRelease(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
    }
    
    // Tạo khối .hero giống hệt trên Web CSS
    func setupCSSHeroBanner() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 145))
        headerContainer.backgroundColor = .clear
        
        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = CSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = CSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 8)
        heroCard.layer.shadowRadius = 20
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
        titleLabel.font = UIFont.systemFont(ofSize: 28, weight: .heavy)
        titleLabel.textColor = CSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.35
        
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Customize & manage your sideloading experience"
        subLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        subLabel.textColor = CSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        
        heroCard.addSubview(titleLabel)
        heroCard.addSubview(subLabel)
        headerContainer.addSubview(heroCard)
        
        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -12),
            
            titleLabel.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor, constant: -12),
            
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12)
        ])
        
        // Hiệu ứng Fade-in & Slide-in như @keyframes trong CSS
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -15)
        UIView.animate(withDuration: 0.7, delay: 0.1, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
        
        self.tableView.tableHeaderView = headerContainer
    }
    
    // Bóc tách lớp nền của InsetGroupTableViewCell để ép nhận diện CSS Card
    func styleInnerCardOfCell(_ cell: UITableViewCell, at indexPath: IndexPath, totalRows: Int) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        
        // Tìm view nền thực sự bên trong InsetGroupTableViewCell của SideStore
        let targetCardView: UIView = cell.subviews.first(where: {
            $0 !== cell.contentView && $0.frame.width > 100 && !($0 is UIButton)
        }) ?? cell.contentView
        
        targetCardView.backgroundColor = CSSTheme.white
        
        // Bo góc thông minh: Dòng đầu bo trên, dòng cuối bo dưới, 1 dòng thì bo cả 4 góc
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
        
        // Đổ bóng chuẩn --shadow: 0 8px 20px rgba(0,0,0,.1)
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = CSSTheme.blue.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 6)
        cell.layer.shadowRadius = 12
        cell.layer.shadowOpacity = 0.08
        
        // Thêm vạch kẻ mảnh (#e9ecef) giữa các dòng trong cùng 1 Card
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
        
        // Đổi màu chữ và biến các dòng bấm được thành dạng Nút (.btn)
        styleLabelsInside(view: cell.contentView, section: Section.allCases[indexPath.section], row: indexPath.row)
    }
    
    func styleLabelsInside(view: UIView, section: Section, row: Int) {
        for subview in view.subviews {
            if let label = subview as? UILabel {
                if label == self.accountEmailLabel || label == self.accountTypeLabel {
                    label.textColor = CSSTheme.purple
                    label.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                } else if section == .signIn {
                    // Biến nút Sign In thành .btn-primary
                    label.textColor = CSSTheme.blue
                    label.font = UIFont.systemFont(ofSize: 17, weight: .bold)
                } else if section == .techyThings && row == TechyThingsRow.clearCache.rawValue {
                    // Nút Clear Cache nổi bật với màu hồng tím (#f0f)
                    label.textColor = CSSTheme.magenta
                    label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
                } else if label.textColor == .systemRed {
                    label.textColor = CSSTheme.magenta
                } else {
                    label.textColor = CSSTheme.dark
                    if label.font.pointSize >= 16 {
                        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
                    }
                }
            }
            styleLabelsInside(view: subview, section: section, row: row)
        }
    }
    
    @objc func animateButtonPress(_ sender: UIButton) {
        UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseInOut) {
            sender.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }
    }
    
    @objc func animateButtonRelease(_ sender: UIButton) {
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            sender.transform = .identity
        }
    }
}

private extension SettingsViewController
{
    private func getVersionAttributedString() -> NSAttributedString {
        let appVersion = Bundle.Info.activeBundleVersion
        let iosVersion = "iOS \(UIDevice.current.systemVersion) (\(ProcessInfo.processInfo.operatingSystemBuild))"
        
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
                .foregroundColor: CSSTheme.purple.withAlphaComponent(0.8),
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
            string: "Copied! ",
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
        self.versionLabel.attributedText = attributed
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.versionLabel.attributedText = self?.getVersionAttributedString()
        }
    }
    
    func update()
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
                self.accountTypeLabel.text = team.type.localizedDescription
                
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
        
        self.backgroundRefreshSwitch.isOn = UserDefaults.standard.isBackgroundRefreshEnabled
        self.noIdleTimeoutSwitch.isOn = UserDefaults.standard.isIdleTimeoutDisableEnabled
        self.disableAppLimitSwitch.isOn = UserDefaults.standard.isAppLimitDisabled
        
        self.betaUpdatesSwitch.isOn = UserDefaults.standard.isBetaUpdatesEnabled
        self.betaTrackPopupButton.isEnabled = UserDefaults.standard.isBetaUpdatesEnabled
        
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
        
        // ✨ Làm đẹp Tiêu đề chuẩn .features h2 và ::after trong CSS ✨
        settingsHeaderFooterView.primaryLabel.textColor = CSSTheme.blue
        settingsHeaderFooterView.primaryLabel.font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        settingsHeaderFooterView.secondaryLabel.textColor = CSSTheme.dark.withAlphaComponent(0.75)
        settingsHeaderFooterView.secondaryLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        
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
                underline.topAnchor.constraint(equalTo: settingsHeaderFooterView.primaryLabel.bottomAnchor, constant: 3),
                underline.widthAnchor.constraint(equalToConstant: 42),
                underline.heightAnchor.constraint(equalToConstant: 3)
            ])
        }
        
        settingsHeaderFooterView.layoutMargins.bottom = isHeader ? 8 : 10
        
        switch section
        {
        case .signIn:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("ACCOUNT", comment: "")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Sign in with your Apple ID to download apps from SideStore.", comment: "")
            }
            
        case .patreon:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("SUPPORT US", comment: "")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Support the SideStore Team by following our socials or becoming a patron!", comment: "")
            }
            
        case .account:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("ACCOUNT", comment: "")
            
            // Biến nút SIGN OUT thành nút .btn-secondary nổi bật
            let btn = settingsHeaderFooterView.button!
            btn.setTitle(NSLocalizedString("  SIGN OUT  ", comment: ""), for: .normal)
            btn.setTitleColor(CSSTheme.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            btn.backgroundColor = CSSTheme.magenta
            btn.layer.cornerRadius = 10
            btn.layer.shadowColor = CSSTheme.magenta.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 4)
            btn.layer.shadowRadius = 8
            btn.layer.shadowOpacity = 0.35
            btn.addTarget(self, action: #selector(SettingsViewController.signOut(_:)), for: .primaryActionTriggered)
            btn.isHidden = false
            
        case .appRefresh:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("REFRESHING APPS", comment: "")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Enable Background Refresh to automatically refresh apps in the background when connected to Wi-Fi. \n\nEnable Disable Idle Timeout to allow SideStore to keep your device awake during a refresh or install of any apps.", comment: "")
            }
            
        case .display:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("DISPLAY", comment: "")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Personalize your SideStore experience by choosing an alternate app icon.", comment: "")
            }
            
        case .instructions:
            break
            
        case .techyThings:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("TECHY THINGS", comment: "")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString("Free up disk space by removing non-essential data, such as temporary files and backups for uninstalled apps.", comment: "")
            }
            
        case .credits:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("CREDITS", comment: "")
            
        case .advancedSettings:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("ADVANCED SETTINGS", comment: "")
            
        case .betaTesting:
            if isHeader {
                settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("BETA TESTING", comment: "")
            } else {
                settingsHeaderFooterView.secondaryLabel.text = NSLocalizedString(
                    """
                    Opt in for beta testing to receive regular updates and early previews of upcoming releases.\n
                    Please note that these builds are experimental and may be unstable or break unexpectedly.
                    """,
                    comment: ""
                )
            }
            
        case .diagnostics:
            settingsHeaderFooterView.primaryLabel.text = NSLocalizedString("DIAGNOSTICS", comment: "")
        }
    }
    
    private func preferredHeight(for settingsHeaderFooterView: SettingsHeaderFooterView, in section: Section, isHeader: Bool) -> CGFloat
    {
        let widthConstraint = settingsHeaderFooterView.contentView.widthAnchor.constraint(equalToConstant: tableView.bounds.width)
        NSLayoutConstraint.activate([widthConstraint])
        defer { NSLayoutConstraint.deactivate([widthConstraint]) }
        
        self.prepare(settingsHeaderFooterView, for: section, isHeader: isHeader)
        
        let size = settingsHeaderFooterView.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return size.height + (isHeader ? 6 : 0)
    }
    
    private func isSectionHidden(_ section: Section) -> Bool
    {
        return false
    }
}

private extension SettingsViewController
{
    func signIn()
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
    
    @objc func signOut(_ sender: UIBarButtonItem)
    {
        debugLog("[SettingsVC] signOut() invoked by user action")
        let contentVC = SignOutAlertViewController()
        
        let alertController = UIAlertController(
            title: NSLocalizedString("Sign Out", comment: ""),
            message: NSLocalizedString("Are you sure you want to sign out? You will no longer be able to install or refresh apps once you sign out.", comment: ""),
            preferredStyle: .alert
        )
        
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel, handler: nil)
        
        let signOutAction = UIAlertAction(title: NSLocalizedString("Sign Out", comment: ""), style: .destructive) { [weak self] _ in
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
    
    @IBAction func toggleDisableAppLimit(_ sender: UISwitch) {
        if UserDefaults.standard.isCowExploitSupported || !ProcessInfo().sparseRestorePatched {
            UserDefaults.standard.isAppLimitDisabled = sender.isOn
            if UserDefaults.standard.activeAppsLimit != nil
            {
                UserDefaults.standard.activeAppsLimit = InstalledApp.freeAccountActiveAppsLimit
            }
        }
    }
    
    @IBAction func toggleVerboseOperationsLogging(_ sender: UISwitch) {
        UserDefaults.standard.isVerboseOperationsLoggingEnabled = sender.isOn
    }
    
    @IBAction func toggleAltSignVerboseLogging(_ sender: UISwitch) {
        UserDefaults.standard.isAltSignVerboseLoggingEnabled = sender.isOn
        AltSign.setLogging(sender.isOn)
    }
    
    @IBAction func toggleMinimuxerVerboseLogging(_ sender: UISwitch) {
        UserDefaults.standard.isMinimuxerVerboseLoggingEnabled = sender.isOn
        minimuxerSetLogging(sender.isOn)
    }
    
    @IBAction func toggleRotateLogsOnStartup(_ sender: UISwitch) {
        UserDefaults.standard.isRotateLogsOnStartupEnabled = sender.isOn
        let suffixFormat: SuffixFormat = sender.isOn ? .timestamp : .none
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.consoleLog.updateConfiguration(baseName: "console", suffixFormat: suffixFormat, policy: .immediate)
    }
    
    @IBAction func toggleRecreateDatabaseSwitch(_ sender: UISwitch) {
        UserDefaults.standard.recreateDatabaseOnNextStart = sender.isOn
        guard sender.isOn else { return }
        
        DispatchQueue.global().async {
            for time in (1...3).reversed() {
                DispatchQueue.main.async {
                    guard UserDefaults.standard.recreateDatabaseOnNextStart else { return }
                    let toast = ToastView(text: "Database Delete Scheduled on Next Launch", detailText: "App is closing in \(time) seconds...")
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
    
    @IBAction func toggleEnableBetaUpdates(_ sender: UISwitch) {
        betaTrackLabel.isEnabled = sender.isOn
        betaTrackPopupButton.isEnabled = sender.isOn
        UserDefaults.standard.isBetaUpdatesEnabled = sender.isOn
    }
    
    @IBAction func toggleIsBackgroundRefreshEnabled(_ sender: UISwitch) {
        UserDefaults.standard.isBackgroundRefreshEnabled = sender.isOn
    }
    
    @IBAction func toggleNoIdleTimeoutEnabled(_ sender: UISwitch) {
        UserDefaults.standard.isIdleTimeoutDisableEnabled = sender.isOn
    }
    
    @IBAction func toggleDisableResponseCaching(_ sender: UISwitch) {
        UserDefaults.standard.responseCachingDisabled = sender.isOn
    }
    
    #if !os(tvOS)
    func addRefreshAppsShortcut()
    {
        guard let shortcut = INShortcut(intent: INInteraction.refreshAllApps().intent) else { return }
        let viewController = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        viewController.delegate = self
        viewController.modalPresentationStyle = .formSheet
        self.present(viewController, animated: true, completion: nil)
    }
    #endif
    
    func clearCache()
    {
        let makeCacheTitle: (String) -> String = { sizeString in
            String(format: NSLocalizedString("Are you sure you want to clear SideStore's cache?\n\nCache Size: %@", comment: ""), sizeString)
        }
        let alertController = UIAlertController(title: makeCacheTitle(NSLocalizedString("Calculating…", comment: "")),
                                                message: NSLocalizedString("This will remove all temporary files as well as backups for uninstalled apps.", comment: ""),
                                                preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: UIAlertAction.cancel.title, style: UIAlertAction.cancel.style) { [weak self] _ in
            self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
        })
        alertController.addAction(UIAlertAction(title: NSLocalizedString("Clear Cache", comment: ""), style: .destructive) { [weak self] _ in
            AppManager.shared.clearAppCache { result in
                DispatchQueue.main.async {
                    self?.tableView.indexPathForSelectedRow.map { self?.tableView.deselectRow(at: $0, animated: true) }
                    switch result {
                    case .success: break
                    case .failure(let error):
                        let alertController = UIAlertController(title: NSLocalizedString("Unable to Clear Cache", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
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
    
    @IBAction func handleDebugModeGesture(_ gestureRecognizer: UISwipeGestureRecognizer)
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
    
    func openTwitter(username: String)
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
    
    func openMastodon(username: String)
    {
        let components = username.split(separator: "@")
        guard components.count == 2 else { return }
        let server = String(components[1])
        let username = "@" + String(components[0])
        guard let serverURL = URL(string: "https://" + server) else { return }
        let mastodonURL = serverURL.appendingPathComponent(username)
        UIApplication.shared.open(mastodonURL, options: [:])
    }
    
    func openThreads(username: String)
    {
        let safariURL = URL(string: "https://www.threads.net/@" + username)!
        UIApplication.shared.open(safariURL, options: [:])
    }
    
    @IBAction func followAltStoreMastodon() { self.openMastodon(username: "@sidestoreio@fosstodon.org") }
    @IBAction func followAltStoreThreads() { self.openThreads(username: "sidestore.io") }
    @IBAction func followAltStoreTwitter() { self.openTwitter(username: "sidestoreio") }
    @IBAction func followAltStoreGitHub() { UIApplication.shared.open(AppConstants.URLs.sideStoreGitHub, options: [:]) }
}

private extension SettingsViewController
{
    @objc func openPatreonSettings(_ notification: Notification)
    {
        guard self.presentedViewController == nil else { return }
        UIView.performWithoutAnimation {
            self.navigationController?.popViewController(animated: false)
            self.performSegue(withIdentifier: "showPatreon", sender: nil)
        }
    }
    
    @objc func openErrorLog(_: Notification) {
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
        var numberOfSections = super.numberOfSections(in: tableView)
        if !UserDefaults.standard.isDebugModeEnabled {
            numberOfSections -= 1
        }
        return numberOfSections
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat
    {
        if Section.allCases[indexPath.section] == .account && indexPath.row == 3 {
            return AccountVerificationRow.preferredHeight
        }
        let effectiveIndexPath: IndexPath
        if Section.allCases[indexPath.section] == .advancedSettings {
            let row = AdvancedSettingsRow.allCases[indexPath.row]
            effectiveIndexPath = IndexPath(row: row.rawValue, section: indexPath.section)
        } else {
            effectiveIndexPath = indexPath
        }
        return super.tableView(tableView, heightForRowAt: effectiveIndexPath)
    }
    
    // ✨ CAN THIỆP SÂU VÀO TỪNG CELL ĐỂ ÁP DỤNG CARD THEME ✨
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath)
    {
        let section = Section.allCases[indexPath.section]
        let totalRows = self.tableView(tableView, numberOfRowsInSection: indexPath.section)
        
        if section == .account {
            if indexPath.row == 2, let insetCell = cell as? InsetGroupTableViewCell {
                insetCell.style = (self.accountStatus == .completed) ? .bottom : .middle
            } else if indexPath.row == 3, let actionCell = cell as? AccountVerificationRow {
                actionCell.style = .bottom
                actionCell.backgroundColor = .clear
                actionCell.contentView.backgroundColor = .clear
                actionCell.backgroundConfiguration = .clear()
                return
            }
        }
        
        // Không đóng khung phần chữ version và dải nút mạng xã hội
        if section == .instructions || (section == .patreon && indexPath.row > 0) {
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.subviews.forEach { if $0 !== cell.contentView { $0.backgroundColor = .clear } }
            return
        }
        
        // Áp dụng cấu trúc Card CSS cho tất cả các dòng còn lại
        self.styleInnerCardOfCell(cell, at: indexPath, totalRows: totalRows)
    }
    
    override func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int
    {
        if Section.allCases[indexPath.section] == .account && indexPath.row == 3 {
            return 0
        }
        let effectiveIndexPath: IndexPath
        if Section.allCases[indexPath.section] == .advancedSettings {
            let row = AdvancedSettingsRow.allCases[indexPath.row]
            effectiveIndexPath = IndexPath(row: row.rawValue, section: indexPath.section)
        } else {
            effectiveIndexPath = indexPath
        }
        return super.tableView(tableView, indentationLevelForRowAt: effectiveIndexPath)
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 0
        case .signIn: return (self.activeTeam == nil) ? 1 : 0
        case .account: return (self.activeTeam == nil) ? 0 : (self.accountStatus == .completed ? 3 : 4)
        case .appRefresh: return AppRefreshRow.allCases.count
        case .advancedSettings: return AdvancedSettingsRow.allCases.count
        default: return super.tableView(tableView, numberOfRowsInSection: section.rawValue)
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        if Section.allCases[indexPath.section] == .account && indexPath.row == 3 {
            let cell = tableView.dequeueReusableCell(withIdentifier: AccountVerificationRow.reuseIdentifier) as? AccountVerificationRow
                ?? AccountVerificationRow()
            cell.configure(with: self.accountStatus)
            cell.style = .bottom
            return cell
        }
        
        let effectiveIndexPath: IndexPath
        if Section.allCases[indexPath.section] == .advancedSettings {
            let row = AdvancedSettingsRow.allCases[indexPath.row]
            effectiveIndexPath = IndexPath(row: row.rawValue, section: indexPath.section)
        } else {
            effectiveIndexPath = indexPath
        }
        let cell = super.tableView(tableView, cellForRowAt: effectiveIndexPath)
        
        if Section.allCases[indexPath.section] == .account {
            if indexPath.row == 2 {
                if let insetCell = cell as? InsetGroupTableViewCell {
                    insetCell.style = (self.accountStatus == .completed) ? .bottom : .middle
                }
            }
        }
        
        if AppRefreshRow.AllCases().count == 1
        {
            if let cell = cell as? InsetGroupTableViewCell,
               indexPath.section == Section.appRefresh.rawValue,
               indexPath.row == AppRefreshRow.backgroundRefresh.rawValue
            {
                cell.style = .single
            }
        }
        
        if let cell = cell as? InsetGroupTableViewCell,
           indexPath.section == Section.appRefresh.rawValue,
           indexPath.row == AppRefreshRow.allCases.count-1
        {
            cell.setValue(3, forKey: "style")
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
        case .signIn, .account, .patreon, .display, .appRefresh, .techyThings, .credits, .advancedSettings, .betaTesting, .diagnostics:
            let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(headerView, for: section, isHeader: true)
            return headerView
            
        case .instructions: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView?
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return nil
        case .signIn where self.activeTeam != nil: return nil
        case .signIn, .patreon, .display, .appRefresh, .techyThings, .betaTesting:
            let footerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "HeaderFooterView") as! SettingsHeaderFooterView
            self.prepare(footerView, for: section, isHeader: false)
            return footerView
            
        case .account, .credits, .advancedSettings, .instructions, .diagnostics: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 1.0
        case .signIn where self.activeTeam != nil: return 1.0
        case .account where self.activeTeam == nil: return 1.0
        case .signIn, .account, .patreon, .display, .appRefresh, .techyThings, .credits, .advancedSettings, .betaTesting, .diagnostics:
            return self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: true)
        case .instructions: return 0.0
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat
    {
        let section = Section.allCases[section]
        switch section
        {
        case _ where isSectionHidden(section): return 1.0
        case .signIn where self.activeTeam != nil: return 1.0
        case .account where self.activeTeam == nil: return 1.0
        case .signIn, .patreon, .display, .appRefresh, .techyThings, .betaTesting:
            return self.preferredHeight(for: self.prototypeHeaderFooterView, in: section, isHeader: false)
        case .account, .credits, .advancedSettings, .instructions, .diagnostics: return 0.0
        }
    }
}

extension SettingsViewController
{
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        // ✨ Hiệu ứng nhún và trượt nhẹ sang phải 4px giống `nav a:hover { transform: translateX(6px); }` ✨
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
        case .signIn: self.signIn()
        case .account:
            if indexPath.row == 3 {
                tableView.deselectRow(at: indexPath, animated: true)
                self.resolvePendingAccountActions()
            }
        case .appRefresh:
            let row = AppRefreshRow.allCases[indexPath.row]
            switch row
            {
            case .backgroundRefresh, .noIdleTimeout, .disableAppLimit: break
            case .addToSiri:
                #if !os(tvOS)
                self.addRefreshAppsShortcut()
                #endif
            }
            
        case .techyThings:
            let row = TechyThingsRow.allCases[indexPath.row]
            switch row
            {
            case .healthCheck:
                let healthCheckView = HealthCheckView()
                let vc = UIHostingController(rootView: healthCheckView)
                navigationController?.pushViewController(vc, animated: true)
                
            case .errorLog: break
            case .storageExplorer:
                StorageExplorerView.clearCache()
                func makeExplorerVC(url: URL? = nil) -> UIViewController {
                    let onSelectFolder: (URL) -> Void = { [weak self] targetURL in
                        guard let self = self else { return }
                        let childVC = makeExplorerVC(url: targetURL)
                        self.navigationController?.pushViewController(childVC, animated: true)
                    }
                    if let url = url {
                        let view = DirectoryExplorerView(url: url, onSelectFolder: onSelectFolder)
                        return UIHostingController(rootView: view)
                    } else {
                        let view = StorageExplorerView(onSelectFolder: onSelectFolder)
                        return UIHostingController(rootView: view)
                    }
                }
                let vc = makeExplorerVC()
                navigationController?.pushViewController(vc, animated: true)
                
            case .clearCache: self.clearCache()
            }
            
        case .credits:
            let row = CreditsRow.allCases[indexPath.row]
            switch row
            {
            case .developer, .operations: self.openTwitter(username: "sidestoreio")
            case .designer: self.openTwitter(username: "lit_ritt")
            case .softwareLicenses: break
            }
            if let selectedIndexPath = self.tableView.indexPathForSelectedRow {
                self.tableView.deselectRow(at: selectedIndexPath, animated: true)
            }
            
        case .advancedSettings:
            let row = AdvancedSettingsRow.allCases[indexPath.row]
            switch row
            {
            case .sendFeedback:
                let alertController = UIAlertController(title: "Send Feedback", message: "Choose a method to send feedback:", preferredStyle: .actionSheet)
                alertController.addAction(UIAlertAction(title: "GitHub", style: .default) { _ in
                    self.openWebURL(AppConstants.URLs.sideStoreIssues, preferredTintColor: CSSTheme.blue)
                })
                alertController.addAction(UIAlertAction(title: "Discord", style: .default) { _ in
                    self.openWebURL(AppConstants.URLs.sideStoreDiscord, preferredTintColor: CSSTheme.purple)
                })
                #if !os(tvOS)
                alertController.addAction(UIAlertAction(title: "Send Email", style: .default) { _ in
                    if MFMailComposeViewController.canSendMail() {
                        let mailViewController = MFMailComposeViewController()
                        mailViewController.mailComposeDelegate = self
                        mailViewController.setToRecipients(["support@sidestore.io"])
                        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                            mailViewController.setSubject("SideStore Beta \(version) Feedback")
                        } else {
                            mailViewController.setSubject("SideStore Beta Feedback")
                        }
                        self.present(mailViewController, animated: true, completion: nil)
                    } else {
                        let toastView = ToastView(text: NSLocalizedString("Cannot Send Mail", comment: ""), detailText: nil)
                        toastView.show(in: self)
                    }
                })
                #endif
                alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                if let popoverController = alertController.popoverPresentationController {
                    popoverController.sourceView = self.view
                    popoverController.sourceRect = self.view.bounds
                }
                self.present(alertController, animated: true, completion: nil)
                
            case .refreshSideJITServer:
                let vc = UIHostingController(rootView: SideJITServerConfigView())
                self.navigationController?.pushViewController(vc, animated: true)
                
            case .pairingFileManagement:
                let vc = UIHostingController(rootView: PairingFileManagementView())
                self.navigationController?.pushViewController(vc, animated: true)
                
            case .anisetteServers:
                let anisetteServersView = AnisetteServersView(
                    selected: UserDefaults.standard.menuAnisetteURL,
                    onResetAdiPb: { [weak self] in
                        guard let self = self else { return }
                        ToastView(text: "Cleared adi.pb!", detailText: "You will need to log back into Apple ID in SideStore.").show(in: self)
                    }
                )
                let vc = UIHostingController(rootView: anisetteServersView)
                self.prepare(for: UIStoryboardSegue(identifier: "anisetteServers", source: self, destination: vc), sender: nil)
                
            case .connectionConfig:
                let vc = UIHostingController(rootView: ConnectionConfigView())
                navigationController?.pushViewController(vc, animated: true)
                
            case .networkDiscovery:
                let vc = UIHostingController(rootView: BonjourDiscoveryView())
                vc.title = NSLocalizedString("Network Discovery", comment: "")
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: vc), sender: nil)
                
            case .developerServices:
                let vc = UIHostingController(rootView: DeveloperServicesView(presentingViewController: self))
                self.prepare(for: UIStoryboardSegue(identifier: "developerServices", source: self, destination: vc), sender: nil)
                
            case .profileManagement:
                let vc = UIHostingController(rootView: ProfileManagementView(presentingViewController: self))
                self.prepare(for: UIStoryboardSegue(identifier: "profileManagement", source: self, destination: vc), sender: nil)
                
            case .certificateManagement:
                let vc = UIHostingController(rootView: CertificatesView(presentingViewController: self))
                self.prepare(for: UIStoryboardSegue(identifier: "certificateManagement", source: self, destination: vc), sender: nil)
                
            case .backupAndRestore:
                let vc = UIHostingController(rootView: BackupAndRestoreView())
                vc.title = NSLocalizedString("Backup & Restore", comment: "")
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: vc), sender: nil)
                
            case .userCustomizations:
                let vc = UIHostingController(rootView: UserCustomizationsView())
                vc.title = NSLocalizedString("User Customizations", comment: "")
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: vc), sender: nil)
                
            case .refreshAttempts: break
            }
            
        case .diagnostics:
            let row = DiagnosticsRow.allCases[indexPath.row]
            switch row {
            case .developerOptions:
                let hostingController = UIHostingController(rootView: DeveloperOptionsView())
                hostingController.title = NSLocalizedString("Developer Options", comment: "")
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: hostingController), sender: nil)
            case .experimentalFeatures:
                let hostingController = UIHostingController(rootView: ExperimentalFeaturesView())
                hostingController.title = NSLocalizedString("Experimental Features", comment: "")
                self.prepare(for: UIStoryboardSegue(identifier: "diagnostics", source: self, destination: hostingController), sender: nil)
            }
            
        case .patreon, .display, .instructions, .betaTesting: break
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
