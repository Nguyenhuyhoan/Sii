

//
//  MyAppsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/16/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
importMobileCoreServices
import Combine

import AltStoreCore
import Roxas

import Minimuxer

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI SETTINGSVIEWCONTROLLER)
private struct CSSTheme {
    static let white = UIColor.white
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0) // #f8f9fa
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0) // #e9ecef
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0) // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0) // #6f42c1
    static let indigo = UIColor(red: 88/255, green: 86/255, blue: 214/255, alpha: 1.0) // #5856d6
    static let teal = UIColor(red: 23/255, green: 162/255, blue: 184/255, alpha: 1.0) // #17a2b8
    static let orange = UIColor(red: 253/255, green: 126/255, blue: 20/255, alpha: 1.0) // #fd7e14
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0) // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0) // #dc3545
    static let magenta = UIColor(red: 232/255, green: 30/255, blue: 99/255, alpha: 1.0) // #e91e63
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0) // #343a40
    static let pureBlack = UIColor.black

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.94) -> rgba(111,66,193,.90))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.94).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.90).cgColor

    static let cornerRadius: CGFloat = 16.0
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

extension MyAppsViewController
{
    private enum Section: Int, CaseIterable
    {
        case updates
        case activeApps
        case inactiveApps
        case appIDs
    }
    
    private enum ActiveItems: Int, CaseIterable
    {
        case activeFetchResults
        case freeAccountHeader
    }
}

final class MyAppsViewController: UICollectionViewController
{
    // MARK: - State
    private lazy var dataSource = self.makeDataSource()
    private lazy var updatesDataSource = self.makeUpdatesDataSource()
    private lazy var activeAppsDataSource = self.makeActiveAppsDataSource()
    private lazy var inactiveAppsDataSource = self.makeInactiveAppsDataSource()
    private lazy var appIDsDataSource = self.makeAppIDsDataSource()
    
    // View Components
    private lazy var placeholderView = RSTPlaceholderView(frame: .zero)
    private let sideloadingProgressView = UIProgressView(progressViewStyle: .bar)
    
    // Giao diện CSS Hero Card & Nút Điều Hướng Nổi
    private var heroGradientLayer: CAGradientLayer?
    private var heroStatusDotView: UIView?
    private var heroStatusTextLabel: UILabel?
    private var heroAddIPAButton: UIButton?
    private var heroLiveContainerButton: UIButton?
    private var heroLoadingSpinner: UIActivityIndicatorView?
    private var floatingBackButton: UIButton?
    
    private var prototypeUpdateCell:UpdateCollectionViewCell!
    
    private var collapsedTextIds = Set<String>()
    private var updateContentHeights = [String: (collapsedHeight: CGFloat, expandedHeight: CGFloat)]()
    
    private var team: Team?
    private var sideloadingProgress: Progress?
    
    private var cancellables = Set<AnyCancellable>()
    
    private var isImportingApp = false
    
    private var isInactiveAppsCollapsed: Bool = false
    private var isAppIDsCollapsed: Bool = true
    
    private var statusUpdateTimer: Timer?
    private var lastStatusState: Bool?
    
    // MARK: - Outlets
    @IBOutlet private varaddButton: UIBarButtonItem!
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif
    
    // MARK: - ViewController
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Ép toàn bộ trang luôn dùng giao diện Sáng (Không bị biến thành nền đen khi máy bật Dark Mode)
        self.overrideUserInterfaceStyle = .light
        self.navigationController?.overrideUserInterfaceStyle = .light
        self.tabBarController?.overrideUserInterfaceStyle = .light
        
        // Ẩn thanh Navigation Bar để đồng bộ hoàn toàn với SettingsViewController
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        #endif
        
        let updateCellNib = UINib(nibName: "UpdateCollectionViewCell", bundle: nil)
        self.collectionView.register(updateCellNib, forCellWithReuseIdentifier: "UpdateCell")
        self.collectionView.register(SectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HeaderView")
        self.collectionView.register(InstalledAppDirectHeaderCollectionReusableView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "FreeCompleteHeader")
        
        self.prototypeUpdateCell = updateCellNib.instantiate(withOwner: nil, options: nil)[0] as? UpdateCollectionViewCell
        self.prototypeUpdateCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        
        self.placeholderView.tintColor = CSSTheme.blue
        self.placeholderView.textLabel.textColor = CSSTheme.pureBlack
        self.placeholderView.detailTextLabel.textColor = CSSTheme.pureBlack
        self.collectionView.backgroundView = self.placeholderView
        
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = CSSTheme.blue
        refreshControl.addTarget(self, action: #selector(MyAppsViewController.refreshInstalledApps(_:)), for: .primaryActionTriggered)
        self.collectionView.refreshControl = refreshControl
        
        // Chừa khoảng trống phía trên cùng cho khối Hero Card (cao 148pt) và dưới cùng cho TabBar
        self.collectionView.contentInset = UIEdgeInsets(top: 156, left: 0, bottom: 50, right: 0)
        
        // ✨ KÍCH HOẠT GIAO DIỆN WEB CSS ĐỒNG BỘ VỚI SETTINGSVIEWCONTROLLER ✨
        self.applySmartWebCSSTheme()
        
        self.fetchTeam()
        self.updateDataSource()
        
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.didImportApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.ManagedObjectContextDidSave(_:)), name: .NSManagedObjectContextDidSave, object: nil)
        
        letcontextMenuInteraction = UIContextMenuInteraction(delegate: self)
        self.navigationController?.navigationBar.addInteraction(contextMenuInteraction)
        
        AppManager.shared.$refreshAppsProgress
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.collectionView.refreshControl?.endRefreshing()
            }
            .store(in: &self.cancellables)
        
        DatabaseManager.shared.$isStarted
            .receive(on: RunLoop.main)
            .first { $0 }
            .sink { [weak self] (isStarted) in
                self?.collectionView.reloadData()
            }
            .store(in: &self.cancellables)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.overrideUserInterfaceStyle = .light
        self.navigationController?.overrideUserInterfaceStyle = .light
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        
        self.updateNavigationBarItems()
        self.updateStatusDotState(animated: false)
        self.startStatusMonitoring()
        self.restoreVisibleCardsWhiteBackground()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        self.restoreVisibleCardsWhiteBackground()
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        self.stopStatusMonitoring()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        if let heroCard = self.collectionView.viewWithTag(9501) {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
        self.restoreVisibleCardsWhiteBackground()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        guard previousTraitCollection?.ForceTouchCapability != self.traitCollection.ForceTouchCapability else { return }
        self.collectionView.reloadSections(IndexSet(integer: Section.activeApps.rawValue))
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        let destination = segue.destination
        destination.title = nil
        destination.navigationItem.title = nil
        #if !os(tvOS)
        destination.navigationItem.largeTitleDisplayMode = .never
        #endif
        
        switch segue.identifier
        {
        case "showApp":
            guard let cell = sender as? UICollectionViewCell,
                  let indexPath = self.collectionView.indexPath(for: cell) else { return }
            
            let installedApp: InstalledApp
            switch Section.allCases[indexPath.section]
            {
            case .updates: installedApp = self.updatesDataSource.item(at: indexPath)
            case .activeApps: installedApp = self.activeAppsDataSource.item(at: indexPath)
            case .inactiveApps: installedApp = self.inactiveAppsDataSource.item(at: indexPath)
            case .appIDs: return
            }
            
            guard let app = installedApp.storeApp else { return }
            
            let appViewController = segue.destination as! AppViewController
            appViewController.app = app
            
        case "showAppIDs":
            let appIDsViewController = (segue.destination as! UINavigationController).topViewController as! AppIDsViewController
            appIDsViewController.team = self.team
            
        default: break
        }
    }
    
    @IBAction private func unwindToMyApps(_ segue: UIStoryboardSegue)
    {
    }
}

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ CỐ ĐỊNH Ở MỤC CON (GIỐNG SETTINGSVIEWCONTROLLER)
extension MyAppsViewController: UINavigationControllerDelegate, UIGestureRecognizerDelegate
{
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool)
    {
        navigationController.setNavigationBarHidden(true, animated: false)
        viewController.title = nil
        viewController.navigationItem.title = nil
        #if !os(tvOS)
        viewController.navigationItem.largeTitleDisplayMode = .never
        #endif
        
        let isRoot = (viewController === navigationController.viewControllers.first)
        updateFloatingBackButton(in: navigationController, show: !isRoot)
    }
    
    private func updateFloatingBackButton(in nav: UINavigationController, show: Bool)
    {
        if self.floatingBackButton == nil {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            
            let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            btn.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
            btn.tintColor = CSSTheme.blue
            btn.backgroundColor = CSSTheme.white.withAlphaComponent(0.92)
            
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
    
    @objc private func handleFloatingBackTap()
    {
        self.navigationController?.popViewController(animated: true)
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool
    {
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

// MARK: - ✨ HỆ THỐNG RENDER CSS, HERO BANNER & THẺ ỨNG DỤNG ĐỒNG BỘ 100% VỚI SETTINGSVIEWCONTROLLER
private extension MyAppsViewController
{
    func applySmartWebCSSTheme()
    {
        // 1. Nền Gradient cố định: Không bao giờ bị trắng hoặc đen khi lướt xuống dưới
        let gradientBg = CSSGradientBackgroundView(frame: UIScreen.main.bounds)
        gradientBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gradientBg.insertSubview(self.placeholderView, at: 0)
        self.placeholderView.frame = gradientBg.bounds
        self.placeholderView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.collectionView.backgroundView = gradientBg
        self.collectionView.backgroundColor = .clear
        self.view.backgroundColor = .clear
        
        // 2. Tạo khối .hero Banner sang trọng giống hệt SettingsViewController + nút cài IPA & LiveContainer
        self.setupCSSHeroBanner()
        
        // 3. Cấu hình TabBar đồng bộ màu
        #if !os(tvOS)
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = CSSTheme.blue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif
    }
    
    func loadSideStoreAppIcon() -> UIImage?
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
    
    // Tạo khối .hero Banner có gắn Icon SideStore, Huy hiệu xác thực, Trạng thái Minimuxer, nút + IPA và nút LiveContainer
    func setupCSSHeroBanner()
    {
        self.collectionView.viewWithTag(9501)?.removeFromSuperview()
        
        let heroCard = UIView()
        heroCard.tag = 9501
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = CSSTheme.cornerRadius + 2
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = CSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 7)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.28
        
        let gradient = CAGradientLayer()
        gradient.colors = [CSSTheme.heroStart, CSSTheme.heroEnd]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = CSSTheme.cornerRadius + 2
        gradient.borderWidth = 1.0
        gradient.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        heroCard.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient
        
        // 1. Icon SideStore bo góc giống SettingsViewController
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
            iconImageView.image = UIImage(systemName: "cube.box.fill", withConfiguration: symConfig)
            iconImageView.tintColor = .white
        }
        iconBadge.addSubview(iconImageView)
        
        // 2. Tiêu đề SideStore & Huy hiệu xác thực
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "SideStore"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = CSSTheme.white
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.28
        
        let verifiedIcon = UIImageView()
        verifiedIcon.translatesAutoresizingMaskIntoConstraints = false
        let verifiedConfig = UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
        verifiedIcon.image = UIImage(systemName: "checkmark.seal.fill", withConfiguration: verifiedConfig)
        verifiedIcon.tintColor = UIColor(red: 140/255, green: 255/255, blue: 195/255, alpha: 1.0)
        
        // 3. Viên thuốc hiển thị trạng thái kết nối Minimuxer thời gian thực
        let statusPill = UIView()
        statusPill.translatesAutoresizingMaskIntoConstraints = false
        statusPill.backgroundColor = UIColor.black.withAlphaComponent(0.22)
        statusPill.layer.cornerRadius = 11
        statusPill.layer.borderWidth = 1.0
        statusPill.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.frame = CGRect(x: 0, y: 0, width: 8, height: 8)
        dot.layer.cornerRadius = 4
        dot.backgroundColor = minimuxer.ready() ? CSSTheme.green : CSSTheme.red
        self.heroStatusDotView = dot
        
        let statusLbl = UILabel()
        statusLbl.translatesAutoresizingMaskIntoConstraints = false
        statusLbl.text = minimuxer.ready() ? "Sẵn sàng" : "Chưa kết nối"
        statusLbl.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        statusLbl.textColor = CSSTheme.white
        self.heroStatusTextLabel = statusLbl
        
        statusPill.addSubview(dot)
        statusPill.addSubview(statusLbl)
        
        let titleStack = UIStackView(arrangedSubviews: [iconBadge, titleLabel, verifiedIcon])
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 8
        
        // 4. Phụ đề hướng dẫn
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "📦 Quản lý, tự động gia hạn & cài đặt ứng dụng (.ipa) trực tiếp"
        subLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        subLabel.textColor = CSSTheme.white.withAlphaComponent(0.95)
        subLabel.numberOfLines = 1
        subLabel.adjustsFontSizeToFitWidth = true
        subLabel.minimumScaleFactor = 0.85
        
        // 5. Hàng nút tác vụ nhanh trên Hero Banner (+ Cài đặt .IPA & LiveContainer)
        let ipaBtn = UIButton(type: .system)
        ipaBtn.translatesAutoresizingMaskIntoConstraints = false
        let plusConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .bold)
        ipaBtn.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: plusConfig), for: .normal)
        ipaBtn.setTitle(" Cài đặt tệp .IPA", for: .normal)
        ipaBtn.tintColor = CSSTheme.blue
        ipaBtn.setTitleColor(CSSTheme.blue, for: .normal)
        ipaBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        ipaBtn.backgroundColor = CSSTheme.white
        ipaBtn.layer.cornerRadius = 15
        ipaBtn.layer.shadowColor = UIColor.black.cgColor
        ipaBtn.layer.shadowOffset = CGSize(width: 0, height: 3)
        ipaBtn.layer.shadowRadius = 6
        ipaBtn.layer.shadowOpacity = 0.18
        ipaBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 14, bottom: 0, right: 14)
        ipaBtn.addTarget(self, action: #selector(handleHeroImportIPATap), for: .touchUpInside)
        self.heroAddIPAButton = ipaBtn
        
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = CSSTheme.white
        spinner.hidesWhenStopped = true
        self.heroLoadingSpinner = spinner
        
        let lcBtn = UIButton(type: .system)
        lcBtn.translatesAutoresizingMaskIntoConstraints = false
        let lcConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .bold)
        lcBtn.setImage(UIImage(systemName: "shippingbox.fill", withConfiguration: lcConfig), for: .normal)
        lcBtn.setTitle(" LiveContainer", for: .normal)
        lcBtn.tintColor = CSSTheme.white
        lcBtn.setTitleColor(CSSTheme.white, for: .normal)
        lcBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        lcBtn.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        lcBtn.layer.cornerRadius = 15
        lcBtn.layer.borderWidth = 1.0
        lcBtn.layer.borderColor = UIColor.white.withAlphaComponent(0.42).cgColor
        lcBtn.contentEdgeInsets = UIEdgeInsets(top: 0, left: 13, bottom: 0, right: 13)
        lcBtn.addTarget(self, action: #selector(handleHeroLiveContainerTap), for: .touchUpInside)
        self.heroLiveContainerButton = lcBtn
        
        let actionStack = UIStackView(arrangedSubviews: [ipaBtn, lcBtn])
        actionStack.translatesAutoresizingMaskIntoConstraints = false
        actionStack.axis = .horizontal
        actionStack.spacing = 10
        actionStack.alignment = .center
        actionStack.distribution = .fillEqually
        
        // 6. Thanh tiến trình Sideloading nằm gọn dưới đáy Hero Card
        self.sideloadingProgressView.translatesAutoresizingMaskIntoConstraints = false
        self.sideloadingProgressView.progressTintColor = UIColor(red: 140/255, green: 255/255, blue: 195/255, alpha: 1.0)
        self.sideloadingProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        self.sideloadingProgressView.layer.cornerRadius = 2
        self.sideloadingProgressView.clipsToBounds = true
        
        heroCard.addSubview(titleStack)
        heroCard.addSubview(statusPill)
        heroCard.addSubview(subLabel)
        heroCard.addSubview(actionStack)
        heroCard.addSubview(spinner)
        heroCard.addSubview(self.sideloadingProgressView)
        
        self.collectionView.addSubview(heroCard)
        
        NSLayoutConstraint.activate([
            heroCard.topAnchor.constraint(equalTo: self.collectionView.topAnchor, constant: -146),
            heroCard.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            heroCard.heightAnchor.constraint(equalToConstant: 136),
            
            iconBadge.widthAnchor.constraint(equalToConstant: 32),
            iconBadge.heightAnchor.constraint(equalToConstant: 32),
            
            iconImageView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 24),
            iconImageView.heightAnchor.constraint(equalToConstant: 24),
            
            titleStack.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 13),
            titleStack.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            
            statusPill.centerYAnchor.constraint(equalTo: titleStack.centerYAnchor),
            statusPill.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            statusPill.heightAnchor.constraint(equalToConstant: 22),
            
            dot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 8),
            dot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            dot.widthAnchor.constraint(equalToConstant: 8),
            dot.heightAnchor.constraint(equalToConstant: 8),
            
            statusLbl.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 5),
            statusLbl.trailingAnchor.constraint(equalTo: statusPill.trailingAnchor, constant: -8),
            statusLbl.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            
            subLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 7),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            
            actionStack.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 10),
            actionStack.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            actionStack.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            actionStack.heightAnchor.constraint(equalToConstant: 32),
            
            ipaBtn.heightAnchor.constraint(equalToConstant: 32),
            lcBtn.heightAnchor.constraint(equalToConstant: 32),
            
            spinner.centerXAnchor.constraint(equalTo: ipaBtn.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: ipaBtn.centerYAnchor),
            
            self.sideloadingProgressView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            self.sideloadingProgressView.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            self.sideloadingProgressView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -5),
            self.sideloadingProgressView.heightAnchor.constraint(equalToConstant: 3)
        ])
        
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
    }
    
    @objc func handleHeroImportIPATap()
    {
        self.importApp()
    }
    
    // Chuyển nhanh sang LiveContainer với 4 tầng dự phòng thông minh
    @objc func handleHeroLiveContainerTap()
    {
        // Tầng 1: Gọi selector runtime nếu được hook bởi LiveContainer
        let escapeSelector = NSSelectorFromString("escapeButtonTapped:")
        if self.responds(to: escapeSelector) {
            _ = self.perform(escapeSelector, with: self.heroLiveContainerButton)
            return
        }
        
        // Tầng 2: Tìm trong UIBarButtonItem gốc nếu có
        for item in (self.navigationItem.leftBarButtonItems ?? []) + (self.navigationItem.rightBarButtonItems ?? []) {
            if let action = item.action, let target = item.target, target !== self {
                UIApplication.shared.sendAction(action, to: target, from: item, for: nil)
                return
            }
        }
        
        // Tầng 3: Gọi trực tiếp qua LCSharedUtils
        if let lcUtils = NSClassFromString("LCSharedUtils") as? NSObject.Type {
            let launchSel = NSSelectorFromString("launchToGuestApp")
            if lcUtils.responds(to: launchSel) {
                _ = lcUtils.perform(launchSel)
                return
            }
        }
        
        // Tầng 4: Mở qua URL Scheme livecontainer://
        if let url = URL(string: "livecontainer://"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }
        
        let toast = ToastView(text: "Chưa phát hiện LiveContainer", detailText: "Hãy mở ứng dụng bên trong môi trường LiveContainer hoặc cài đặt LiveContainer.")
        toast.show(in: self)
    }
    
    // Tạo tiêu đề Section có gắn SF Symbol phía trước + gạch chân 38x3pt giống hệt SettingsViewController
    func styleSectionHeaderView(_ headerView: SectionHeaderView, iconName: String, title: String)
    {
        headerView.overrideUserInterfaceStyle = .light
        headerView.backgroundColor = .clear
        
        let attachment = NSTextAttachment()
        let config = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .heavy)
        attachment.image = UIImage(systemName: iconName, withConfiguration: config)?.withTintColor(CSSTheme.blue, renderingMode: .alwaysOriginal)
        
        let attr = NSMutableAttributedString(attachment: attachment)
        attr.append(NSAttributedString(
            string: "  " + title.uppercased(),
            attributes: [
                .font: UIFont.systemFont(ofSize: 14.5, weight: .heavy),
                .foregroundColor: CSSTheme.blue
            ]
        ))
        headerView.textLabel.attributedText = attr
        
        let underlineTag = 9991
        headerView.viewWithTag(underlineTag)?.removeFromSuperview()
        let underline = UIView()
        underline.tag = underlineTag
        underline.backgroundColor = CSSTheme.blue
        underline.layer.cornerRadius = 1.5
        underline.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(underline)
        
        NSLayoutConstraint.activate([
            underline.leadingAnchor.constraint(equalTo: headerView.textLabel.leadingAnchor),
            underline.topAnchor.constraint(equalTo: headerView.textLabel.bottomAnchor, constant: 3),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
    
    // Trang trí nút hành động ở góc phải Header (Làm mới tất cả / Hiện ▼ / Ẩn ▲) giống nút ở SettingsViewController
    func styleHeaderActionButton(_ button: UIButton, title: String, iconName: String? = nil, isPurple: Bool = false)
    {
        let bgColor = isPurple ? CSSTheme.purple : CSSTheme.blue
        if let iconName = iconName {
            let config = UIImage.SymbolConfiguration(pointSize: 10.5, weight: .bold)
            button.setImage(UIImage(systemName: iconName, withConfiguration: config), for: .normal)
        } else {
            button.setImage(nil, for: .normal)
        }
        button.setTitle(title, for: .normal)
        button.tintColor = CSSTheme.white
        button.setTitleColor(CSSTheme.white, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        button.backgroundColor = bgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        button.layer.cornerRadius = 12
        button.layer.shadowColor = bgColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 4
        button.layer.shadowOpacity = 0.25
    }
    
    // Biến các Cell ứng dụng thành Card trắng (#FFFFFF), viền mảnh, đổ bóng xanh và chữ đen rõ nét
    func styleAppCardCell(_ cell: UICollectionViewCell)
    {
        cell.overrideUserInterfaceStyle = .light
        cell.contentView.overrideUserInterfaceStyle = .light
        cell.backgroundColor = .clear
        
        cell.contentView.backgroundColor = CSSTheme.white
        cell.contentView.layer.cornerRadius = CSSTheme.cornerRadius
        cell.contentView.layer.borderWidth = 1.0
        cell.contentView.layer.borderColor = CSSTheme.border.cgColor
        cell.contentView.layer.masksToBounds = true
        
        cell.layer.cornerRadius = CSSTheme.cornerRadius
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = CSSTheme.blue.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 5)
        cell.layer.shadowRadius = 10
        cell.layer.shadowOpacity = 0.08
        
        self.applyWhiteCardAndBlackText(in: cell.contentView)
    }
    
    // Làm đẹp nút trạng thái (7 NGÀY, CẬP NHẬT, HẾT HẠN...) luôn nền màu + chữ trắng
    func stylePillButton(_ button: PillButton, tintColor: UIColor = CSSTheme.blue)
    {
        button.overrideUserInterfaceStyle = .light
        button.tintColor = tintColor
        button.backgroundColor = tintColor
        button.layer.backgroundColor = tintColor.cgColor
        button.layer.cornerRadius = 13
        button.layer.masksToBounds = false
        
        let states: [UIControl.State] = [.normal, .highlighted, .selected, .disabled, .focused]
        for state in states {
            button.setTitleColor(CSSTheme.white, for: state)
        }
        button.titleLabel?.textColor = CSSTheme.white
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .heavy)
        
        button.layer.shadowColor = tintColor.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 3)
        button.layer.shadowRadius = 6
        button.layer.shadowOpacity = 0.28
    }
    
    // Loại bỏ hoàn toàn lớp mờ tối (UIVisualEffectView) của AltStore gây đen nền khi icon ứng dụng màu tối
    func applyWhiteCardAndBlackText(in view: UIView)
    {
        for subview in view.subviews
        {
            if subview is PillButton || subview is UIProgressView {
                continue
            }
            
            if let effectView = subview as? UIVisualEffectView {
                effectView.effect = nil
                effectView.backgroundColor = CSSTheme.white
                effectView.contentView.backgroundColor = CSSTheme.white
            }
            else if let imageView = subview as? UIImageView {
                if imageView.bounds.width > 120 && imageView.bounds.height > 40 {
                    imageView.isHidden = true
                    imageView.alpha = 0
                } else if imageView.bounds.width >= 40 && imageView.bounds.width <= 90 {
                    // Bo góc mượt cho Icon ứng dụng
                    imageView.layer.cornerRadius = 13
                    imageView.layer.borderWidth = 0.8
                    imageView.layer.borderColor = CSSTheme.border.cgColor
                    imageView.clipsToBounds = true
                }
            }
            else if !(subview is UIButton) && !(subview is UILabel) {
                if let bg = subview.backgroundColor, bg != .clear {
                    var white: CGFloat = 1.0
                    var alpha: CGFloat = 0.0
                    if bg.getWhite(&white, alpha: &alpha), white < 0.85, alpha > 0.05 {
                        subview.backgroundColor = CSSTheme.white
                    }
                }
            }
            
            if let label = subview as? UILabel {
                if !(label.superview is PillButton) && !(label.superview is UIButton) {
                    if let rawText = label.text, !rawText.isEmpty {
                        label.text = translateDynamicAppText(rawText)
                    }
                    label.textColor = CSSTheme.pureBlack
                }
            }
            else if let textView = subview as? UITextView {
                textView.textColor = CSSTheme.pureBlack
                textView.backgroundColor = .clear
            }
            else if let button = subview as? UIButton {
                let currentTitle = button.title(for: .normal)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if currentTitle == "More" || currentTitle == "Xem thêm" {
                    button.setTitle("Xem thêm", for: .normal)
                    button.setTitleColor(CSSTheme.blue, for: .normal)
                    button.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .bold)
                } else if !currentTitle.isEmpty {
                    let vnTitle = translateDynamicAppText(currentTitle)
                    let states: [UIControl.State] = [.normal, .highlighted, .selected, .disabled]
                    for st in states {
                        button.setTitle(vnTitle, for: st)
                        button.setTitleColor(CSSTheme.white, for: st)
                    }
                    button.titleLabel?.textColor = CSSTheme.white
                }
            }
            
            applyWhiteCardAndBlackText(in: subview)
        }
    }
    
    func restoreVisibleCardsWhiteBackground()
    {
        for cell in self.collectionView.visibleCells {
            self.styleAppCardCell(cell)
        }
    }
    
    // Dịch tự động các chuỗi thời gian và trạng thái ứng dụng sang Tiếng Việt
    func translateDynamicAppText(_ text: String) -> String
    {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let exactMap: [String: String] = [
            "UPDATE": "CẬP NHẬT",
            "Update": "Cập nhật",
            "EXPIRED": "ĐÃ HẾT HẠN",
            "Expired": "Đã hết hạn",
            "DEACTIVATED": "ĐÃ TẠM TẮT",
            "Deactivated": "Đã tạm tắt",
            "REVOKED": "BỊ THU HỒI",
            "Revoked": "Bị thu hồi",
            "OPEN": "MỞ",
            "Open": "Mở",
            "More": "Xem thêm",
            "Yesterday": "Hôm qua",
            "Today": "Hôm nay",
            "Now": "Vừa xong"
        ]
        if let matched = exactMap[result] {
            return matched
        }
        
        result = result.replacingOccurrences(of: "DAYS", with: "NGÀY")
        result = result.replacingOccurrences(of: "DAY", with: "NGÀY")
        result = result.replacingOccurrences(of: "days", with: "ngày")
        result = result.replacingOccurrences(of: "day", with: "ngày")
        result = result.replacingOccurrences(of: "HOURS", with: "GIỜ")
        result = result.replacingOccurrences(of: "HOUR", with: "GIỜ")
        result = result.replacingOccurrences(of: "hours", with: "giờ")
        result = result.replacingOccurrences(of: "hour", with: "giờ")
        result = result.replacingOccurrences(of: "MINUTES", with: "PHÚT")
        result = result.replacingOccurrences(of: "MINUTE", with: "PHÚT")
        result = result.replacingOccurrences(of: "minutes", with: "phút")
        result = result.replacingOccurrences(of: "minute", with: "phút")
        result = result.replacingOccurrences(of: "Expires in ", with: "Hết hạn sau ")
        result = result.replacingOccurrences(of: "Version ", with: "Phiên bản ")
        
        return result
    }
}

// MARK: - 🟢 THEO DÕI TRẠNG THÁI KẾT NỐI MINIMUXER THỜI GIAN THỰC TRÊN HERO BANNER
private extension MyAppsViewController
{
    func updateNavigationBarItems()
    {
        if self.sideloadingProgress != nil || self.isImportingApp
        {
            self.heroAddIPAButton?.setTitle("", for: .normal)
            self.heroAddIPAButton?.setImage(nil, for: .normal)
            self.heroAddIPAButton?.isEnabled = false
            self.heroLoadingSpinner?.startAnimating()
        }
        else
        {
            self.heroLoadingSpinner?.stopAnimating()
            let plusConfig = UIImage.SymbolConfiguration(pointSize: 12.5, weight: .bold)
            self.heroAddIPAButton?.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: plusConfig), for: .normal)
            self.heroAddIPAButton?.setTitle(" Cài đặt tệp .IPA", for: .normal)
            self.heroAddIPAButton?.isEnabled = true
        }
    }
    
    func startStatusMonitoring()
    {
        self.stopStatusMonitoring()
        self.statusUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusDotState(animated: true)
        }
    }
    
    func stopStatusMonitoring()
    {
        self.statusUpdateTimer?.invalidate()
        self.statusUpdateTimer = nil
    }
    
    func updateStatusDotState(animated: Bool = true)
    {
        let isReady = minimuxer.ready()
        if let lastState = self.lastStatusState, lastState == isReady {
            return
        }
        self.lastStatusState = isReady
        
        let targetColor: UIColor = isReady ? CSSTheme.green : CSSTheme.red
        let targetText: String = isReady ? "Sẵn sàng" : "Chưa kết nối"
        
        if animated
        {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseInOut, .allowUserInteraction], animations: {
                self.heroStatusDotView?.backgroundColor = targetColor
                self.heroStatusDotView?.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
                self.heroStatusTextLabel?.text = targetText
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    self.heroStatusDotView?.transform = .identity
                }
            }
        }
        else
        {
            self.heroStatusDotView?.backgroundColor = targetColor
            self.heroStatusTextLabel?.text = targetText
        }
    }
}

// MARK: - Data Source
private extension MyAppsViewController
{
    func makeDataSource() -> RSTCompositeCollectionViewPrefetchingDataSource<NSManagedObject, UIImage>
    {
        let dataSource = RSTCompositeCollectionViewPrefetchingDataSource<NSManagedObject, UIImage>(dataSources: [self.updatesDataSource, self.activeAppsDataSource, self.inactiveAppsDataSource, self.appIDsDataSource])
        dataSource.proxy = self
        return dataSource
    }
    
    func makeUpdatesDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest: NSFetchRequest<InstalledApp> = InstalledApp.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == YES AND (%K < %K)", #keyPath(InstalledApp.isActive), #keyPath(InstalledApp.version), #keyPath(InstalledApp.storeApp.latestSupportedVersion.version))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.storeApp?.latestSupportedVersion?.date, ascending: false),
                                        NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let updatesDataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        updatesDataSource.cellConfigurationHandler = { [weak self] (cell, installedApp, indexPath) in
            guard let self = self else { return }
            guard let storeApp = installedApp.storeApp, let latestVersion = storeApp.latestSupportedVersion else { return }
            
            let cell = cell as! UpdateCollectionViewCell
            cell.TextView.text = latestVersion.localizedDescription ?? "Không có mô tả chi tiết cho bản cập nhật này."
            cell.TextView.isCollapsed = self.collapsedTextIds.contains(installedApp.bundleIdentifier)
            
            cell.expandButton.tag = indexPath.item
            cell.expandButton.addTarget(self, action: #selector(MyAppsViewController.toggleExpandTextView(_:)), for: .primaryActionTriggered)
            
            let previousIndexPath = IndexPath(item: indexPath.item, section: Section.updates.rawValue)
            
            cell.bannerView.appNameLabel.text = installedApp.name
            cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicated = true
            cell.bannerView.accessibilityLabel = nil
            
            cell.bannerView.subtitleLabel.text = self.localizedUpdateDateText(for: latestVersion)
            
            switch (installedApp.UpdateProgress, AppManager.shared.installationProgress(for: storeApp))
            {
            case (let progress?, _):
                if cell.bannerView.button.progress != progress
                {
                    cell.bannerView.button.progress = progress
                }
                cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.cancelUpdate(_:)), for: .primaryActionTriggered)
                
            case (nil, let progress?):
                cell.bannerView.button.progress = progress
                
            case (nil, nil):
                cell.bannerView.button.progress = nil
                cell.bannerView.button.setTitle("CẬP NHẬT", for: .normal)
                cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.updateApp(_:)), for: .primaryActionTriggered)
            }
            
            cell.mode = self.collapsedTextIds.contains(installedApp.bundleIdentifier) ? .collapsed : .expanded
            
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
            
            self.stylePillButton(cell.bannerView.button, tintColor: CSSTheme.blue)
            self.styleAppCardCell(cell)
        }
        updatesDataSource.prefetchHandler = { (installedApp, indexPath, completionHandler) in
            let bundleIdentifier = installedApp.bundleIdentifier
            return RSTAsyncBlockOperation() { (operation) in
                InstalledApp.fetchIcon(for: bundleIdentifier) { (result) in
                    guard !operation.isCancelled else { return }
                    switch result {
                    case .failure(let error): completionHandler(nil, error)
                    case .success(let image): completionHandler(image, nil)
                    }
                }
            }
        }
        updatesDataSource.prefetchCompletionHandler = { [weak self] (cell, image, indexPath, error) in
            let cell = cell as! UpdateCollectionViewCell
            cell.bannerView.iconImageView.image = image
            cell.bannerView.iconImageView.isIndicated = false
            self?.styleAppCardCell(cell)
        }
        
        return updatesDataSource
    }
    
    func makeActiveAppsDataSource() -> RSTCompositeCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchDataSource = self.makeActiveAppsFetchDataSource()
        let rawDataSource = RSTArrayCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(items: [])
        letcompositeDataSource = RSTCompositeCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(dataSources: [fetchDataSource, rawDataSource])
        
        return compositeDataSource
    }
    
    func makeActiveAppsFetchDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest = InstalledApp.InvokeActiveAppsFetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        
        let activeAppsDataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        activeAppsDataSource.cellIdentifierHandler = { _ in "AppCell" }
        activeAppsDataSource.cellConfigurationHandler = { [weak self] (cell, installedApp, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! InstalledAppCollectionViewCell
            cell.bannerView.appNameLabel.text = installedApp.name
            cell.bannerView.subtitleLabel.text = installedApp.developer ?? "Ứng dụng đã cài đặt"
            cell.bannerView.button.tag = indexPath.item
            cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.performAppAction(_:)), for: .primaryActionTriggered)
            
            if self.traitCollection.ForceTouchCapability == .available
            {
                let days = installedApp.expirationDate.numberOfCalendarDays(since: Date())
                cell.bannerView.accessibilityLabel = String(format: "%@ của %@. Hết hạn sau %@ ngày.", cell.bannerView.appNameLabel.text ?? "", cell.bannerView.subtitleLabel.text ?? "", NSNumber(value: days))
            }
            else
            {
                cell.bannerView.accessibilityLabel = nil
            }
            
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicated = true
            
            let days = installedApp.expirationDate.numberOfCalendarDays(since: Date())
            if days > 0
            {
                cell.bannerView.button.setTitle("\(days) NGÀY", for: .normal)
                self.stylePillButton(cell.bannerView.button, tintColor: CSSTheme.blue)
            }
            else
            {
                cell.bannerView.button.setTitle("HẾT HẠN", for: .normal)
                self.stylePillButton(cell.bannerView.button, tintColor: CSSTheme.red)
            }
            
            cell.bannerView.button.progress = installedApp.refreshingProgress
            
            if installedApp.certificateSerialNumber == self.team?.activeCertificate?.serialNumber || self.team?.activeCertificate?.serialNumber == nil
            {
                cell.revokedCertificateIndicator.isHidden = true
            }
            else
            {
                cell.revokedCertificateIndicator.isHidden = false
                self.stylePillButton(cell.bannerView.button, tintColor: CSSTheme.red)
            }
            
            cell.layoutIfNeeded()
            self.styleAppCardCell(cell)
        }
        activeAppsDataSource.prefetchHandler = { (installedApp, indexPath, completionHandler) in
            let bundleIdentifier = installedApp.bundleIdentifier
            return RSTAsyncBlockOperation() { (operation) in
                InstalledApp.fetchIcon(for: bundleIdentifier) { (result) in
                    guard !operation.isCancelled else { return }
                    switch result {
                    case .failure(let error): completionHandler(nil, error)
                    case .success(let image): completionHandler(image, nil)
                    }
                }
            }
        }
        activeAppsDataSource.prefetchCompletionHandler = { [weak self] (cell, image, indexPath, error) in
            let cell = cell as! InstalledAppCollectionViewCell
            cell.bannerView.iconImageView.image = image
            cell.bannerView.iconImageView.isIndicated = false
            self?.styleAppCardCell(cell)
        }
        
        return activeAppsDataSource
    }
    
    func makeInactiveAppsDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest: NSFetchRequest<InstalledApp> = InstalledApp.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K == NO AND %K == NO", #keyPath(InstalledApp.isActive), #keyPath(InstalledApp.isAltStoreApp))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.refreshedDate, ascending: true),
                                        NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let inactiveAppsDataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        inactiveAppsDataSource.cellIdentifierHandler = { _ in "AppCell" }
        inactiveAppsDataSource.cellConfigurationHandler = { [weak self] (cell, installedApp, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! InstalledAppCollectionViewCell
            cell.bannerView.appNameLabel.text = installedApp.name
            cell.bannerView.subtitleLabel.text = installedApp.developer ?? "Đang tạm tắt"
            cell.bannerView.button.tag = indexPath.item
            cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.accessibilityLabel = nil
            
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicated = true
            
            cell.bannerView.button.setTitle("KÍCH HOẠT", for: .normal)
            cell.bannerView.button.progress = installedApp.refreshingProgress
            
            self.stylePillButton(cell.bannerView.button, tintColor: CSSTheme.purple)
            
            cell.layoutIfNeeded()
            self.styleAppCardCell(cell)
        }
        inactiveAppsDataSource.prefetchHandler = { (installedApp, indexPath, completionHandler) in
            let bundleIdentifier = installedApp.bundleIdentifier
            return RSTAsyncBlockOperation() { (operation) in
                InstalledApp.fetchIcon(for: bundleIdentifier) { (result) in
                    guard !operation.isCancelled else { return }
                    switch result {
                    case .failure(let error): completionHandler(nil, error)
                    case .success(let image): completionHandler(image, nil)
                    }
                }
            }
        }
        inactiveAppsDataSource.prefetchCompletionHandler = { [weak self] (cell, image, indexPath, error) in
            let cell = cell as! InstalledAppCollectionViewCell
            cell.bannerView.iconImageView.image = image
            cell.bannerView.iconImageView.isIndicated = false
            self?.styleAppCardCell(cell)
        }
        
        return inactiveAppsDataSource
    }
    
    func makeAppIDsDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<AppID, UIImage>
    {
        let fetchRequest: NSFetchRequest<AppID> = AppID.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "%K != nil AND %K == YES", #keyPath(AppID.expirationDate), #keyPath(AppID.team.isActiveTeam))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \AppID.expirationDate, ascending: true),
                                        NSSortDescriptor(keyPath: \AppID.name, ascending: true),
                                        NSSortDescriptor(keyPath: \AppID.bundleIdentifier, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let appIDsDataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<AppID, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        appIDsDataSource.cellIdentifierHandler = { _ in "AppIDCell" }
        appIDsDataSource.cellConfigurationHandler = { [weak self] (cell, appID, indexPath) in
            guard let self = self else { return }
            let cell = cell as! AppIDCollectionViewCell
            cell.bannerView.nameLabel.text = appID.name
            cell.bannerView.bundleIDLabel.text = appID.bundleIdentifier
            cell.bannerView.button.isUserInteractionEnabled = false
            
            if let expirationDate = appID.expirationDate
            {
                let days = expirationDate.numberOfCalendarDays(since: Date())
                if days > 0
                {
                    cell.bannerView.button.setTitle("\(days) NGÀY", for: .normal)
                    self.stylePillButton(cell.bannerView.button, tintColor: CSSTheme.blue)
                }
                else
                {
                    cell.bannerView.button.setTitle("HẾT HẠN", for: .normal)
                    self.stylePillButton(cell.bannerView.button, tintColor: CSSTheme.red)
                }
                cell.bannerView.button.isHidden = false
            }
            else
            {
                cell.bannerView.button.isHidden = true
            }
            
            self.styleAppCardCell(cell)
        }
        
        return appIDsDataSource
    }
    
    func localizedUpdateDateText(for version: AppVersion) -> String
    {
        let date = version.date
        
        let fullDateFormatter = DateFormatter()
        fullDateFormatter.dateStyle = .medium
        fullDateFormatter.timeStyle = .none
        fullDateFormatter.locale = Locale(identifier: "vi_VN")
        
        var dateText = fullDateFormatter.string(from: date)
        
        if #available(iOS 13, *)
        {
            let relativeDateFormatter = RelativeDateTimeFormatter()
            relativeDateFormatter.dateTimeStyle = .named
            relativeDateFormatter.locale = Locale(identifier: "vi_VN")
            
            let relativeString = relativeDateFormatter.localizedString(for: date, relativeTo: Date())
            
            let calendar = Calendar.current
            if let daysSinceRelease = calendar.dateComponents([.day], from: date, to: Date()).day, daysSinceRelease >= 0
            {
                if daysSinceRelease <= 7
                {
                    dateText = relativeString
                }
            }
        }
        
        let localizedDateText = String(format: "Phiên bản %@ • %@", version.localizedVersion, dateText.capitalized)
        return localizedDateText
    }
}

private extension MyAppsViewController
{
    func fetchTeam()
    {
        self.team = DatabaseManager.shared.activeTeam()
        
        if self.team?.type == .free
        {
            let rawDataSource = self.activeAppsDataSource.dataSources[ActiveItems.freeAccountHeader.rawValue]
            if self.dataSource.dataSources.contains(rawDataSource)
            {
                self.activeAppsDataSource.remove(rawDataSource)
            }
            
            if self.inactiveAppsDataSource.itemCount > 0 && !self.dataSource.dataSources.contains(self.inactiveAppsDataSource)
            {
                self.dataSource.add(self.inactiveAppsDataSource)
            }
            else if self.inactiveAppsDataSource.itemCount == 0 && self.dataSource.dataSources.contains(self.inactiveAppsDataSource)
            {
                self.dataSource.remove(self.inactiveAppsDataSource)
            }
            
            self.updateDataSource()
        }
        else
        {
            if self.dataSource.dataSources.contains(self.inactiveAppsDataSource)
            {
                self.dataSource.remove(self.inactiveAppsDataSource)
            }
            
            self.updateDataSource()
        }
        
        self.collectionView.reloadData()
    }
    
    func updateDataSource()
    {
        if self.updatesDataSource.itemCount > 0 || self.activeAppsDataSource.itemCount > 0 || self.inactiveAppsDataSource.itemCount > 0
        {
            self.placeholderView.isHidden = true
        }
        else
        {
            self.placeholderView.isHidden = false
            self.placeholderView.textLabel.text = "Chưa có ứng dụng nào"
            self.placeholderView.detailTextLabel.text = "Nhấn vào nút “+ Cài đặt tệp .IPA” trên thẻ tiêu đề để cài đặt ứng dụng đầu tiên của bạn."
        }
    }
    
    func perform(_ action: Action, for app: InstalledApp)
    {
        switch action
        {
        case .update:
            guard let storeApp = app.storeApp else { return }
            AppManager.shared.update(storeApp, presentingViewController: self) { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(OperationError.cancelled): break
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                        
                    case .success: print("Cập nhật thành công ứng dụng:", storeApp.bundleIdentifier)
                    }
                    
                    self.collectionView.reloadData()
                }
            }
            
        case .refresh:
            let group = AppManager.shared.refresh([app], presentingViewController: self)
            group.completionHandler = { (results) in
                DispatchQueue.main.async {
                    if case .failure(let error)? = results[app.bundleIdentifier]
                    {
                        guard case .cancelled = error as? OperationError else {
                            let toastView = ToastView(error: error)
                            toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                            toastView.show(in: self)
                            return
                        }
                    }
                    self.collectionView.reloadData()
                }
            }
            
        case .activate:
            AppManager.shared.activate(app, presentingViewController: self) { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(OperationError.cancelled): break
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                        
                    case .success: print("Đã kích hoạt thành công ứng dụng:", app.bundleIdentifier)
                    }
                    
                    self.collectionView.reloadData()
                }
            }
            
        case .deactivate:
            AppManager.shared.deactivate(app, presentingViewController: self) { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(OperationError.cancelled): break
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                        
                    case .success: print("Đã tạm tắt ứng dụng:", app.bundleIdentifier)
                    }
                    
                    self.collectionView.reloadData()
                }
            }
            
        case .remove:
            let title = String(format: "Xóa “%@”?", app.name)
            let message = "Bạn có chắc chắn muốn xóa ứng dụng này không? Toàn bộ dữ liệu liên quan sẽ bị xóa vĩnh viễn."
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "Xóa ứng dụng", style: .destructive) { (action) in
                AppManager.shared.remove(app) { (result) in
                    DispatchQueue.main.async {
                        switch result
                        {
                        case .failure(let error):
                            let toastView = ToastView(error: error)
                            toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                            toastView.show(in: self)
                            
                        case .success:
                            self.fetchTeam()
                        }
                    }
                }
            })
            alertController.addAction(.cancel)
            self.present(alertController, animated: true, completion: nil)
            
        case .open:
            UIApplication.shared.open(app.openAppURL)
            
        case .backup:
            AppManager.shared.backup(app, presentingViewController: self) { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(OperationError.cancelled): break
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                        
                    case .success: print("Đã sao lưu ứng dụng:", app.bundleIdentifier)
                    }
                    
                    self.collectionView.reloadData()
                }
            }
            
        case .restore:
            AppManager.shared.restore(app, presentingViewController: self) { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(OperationError.cancelled): break
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                        
                    case .success: print("Đã khôi phục ứng dụng:", app.bundleIdentifier)
                    }
                    
                    self.collectionView.reloadData()
                }
            }
            
        case .enableJit:
            AppManager.shared.enableJIT(for: app) { (result) in
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                        
                    case .success:
                        print("Đã kích hoạt JIT cho ứng dụng:", app.name)
                    }
                }
            }
        }
    }
    
    @IBAction func importApp()
    {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["com.apple.itunes.ipa"], in: .import)
        documentPicker.delegate = self
        documentPicker.overrideUserInterfaceStyle = .light
        self.present(documentPicker, animated: true, completion: nil)
    }
    
    func importApp(at fileURL: URL, completionHandler: ((Bool) -> Void)? = nil)
    {
        self.sideloadingProgress = AppManager.shared.install(at: fileURL, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(OperationError.cancelled): break
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                    
                case .success(let app):
                    print("Đã cài đặt ứng dụng:", app.bundleIdentifier)
                }
                
                self.sideloadingProgress = nil
                self.sideloadingProgressView.setProgress(0, animated: false)
                
                self.updateNavigationBarItems()
                self.fetchTeam()
                
                if case .success = result {
                    completionHandler?(true)
                } else {
                    completionHandler?(false)
                }
            }
        }
        
        self.sideloadingProgressView.isHidden = false
        self.sideloadingProgressView.setProgress(0, animated: false)
        self.sideloadingProgressView.observedProgress = self.sideloadingProgress
        
        self.updateNavigationBarItems()
    }
    
    @objc func didImportApp(_ notification: Notification)
    {
        guard let fileURL = notification.userInfo?[AppDelegate.importAppDeepLinkURLKey] as? URL else { return }
        self.importApp(at: fileURL)
    }
    
    @objc func ManagedObjectContextDidSave(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.fetchTeam()
        }
    }
}

// MARK: - Actions
private extension MyAppsViewController
{
    @objc func performAppAction(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        switch Section.allCases[indexPath.section]
        {
        case .updates: break
        case .activeApps:
            let app = self.activeAppsDataSource.item(at: indexPath)
            self.perform(.refresh, for: app)
            self.collectionView.reloadItems(at: [indexPath])
            
        case .inactiveApps:
            let app = self.inactiveAppsDataSource.item(at: indexPath)
            self.perform(.activate, for: app)
            self.collectionView.reloadItems(at: [indexPath])
            
        case .appIDs: break
        }
    }
    
    @objc func refreshAllApps(_ sender: UIButton)
    {
        let installedApps = InstalledApp.fetchAppsForRefreshingAll(in: DatabaseManager.shared.viewContext)
        
        let group = AppManager.shared.refresh(installedApps, presentingViewController: self)
        group.completionHandler = { (results) in
            DispatchQueue.main.async {
                self.collectionView.refreshControl?.endRefreshing()
                
                var failingResults = [String: Error]()
                for (bundleID, result) in results
                {
                    guard case .failure(let error) = result else { continue }
                    guard case .cancelled = error as? OperationError else {
                        failingResults[bundleID] = error
                        continue
                    }
                }
                
                if let (_, error) = failingResults.first
                {
                    let toastView: ToastView
                    if failingResults.count == 1
                    {
                        toastView = ToastView(error: error)
                    }
                    else
                    {
                        let localizedText = String(format: "Không thể làm mới %@ ứng dụng.", NSNumber(value: failingResults.count))
                        toastView = ToastView(text: localizedText, detailText: error.localizedDescription)
                    }
                    
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                }
            }
        }
        
        self.collectionView.reloadSections(IndexSet([Section.activeApps.rawValue]))
    }
    
    @objc func refreshInstalledApps(_ sender: UIRefreshControl)
    {
        AppManager.shared.updateInstalledApps { (result) in
            DispatchQueue.main.async {
                self.collectionView.refreshControl?.endRefreshing()
                
                switch result
                {
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLog(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                    
                case .success:
                    self.fetchTeam()
                }
            }
        }
    }
    
    @objc func updateApp(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let app = self.updatesDataSource.item(at: indexPath)
        self.perform(.update, for: app)
        
        self.collectionView.reloadItems(at: [indexPath])
    }
    
    @objc func cancelUpdate(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let app = self.updatesDataSource.item(at: indexPath)
        app.UpdateProgress?.cancel()
    }
    
    @objc func toggleExpandTextView(_ sender: UIButton)
    {
        let indexPath = IndexPath(item: sender.tag, section: Section.updates.rawValue)
        
        let installedApp = self.updatesDataSource.item(at: indexPath)
        if self.collapsedTextIds.contains(installedApp.bundleIdentifier)
        {
            self.collapsedTextIds.remove(installedApp.bundleIdentifier)
        }
        else
        {
            self.collapsedTextIds.insert(installedApp.bundleIdentifier)
        }
        
        self.collectionView.reloadItems(at: [indexPath])
    }
    
    @objc func toggleCollapseInactiveApps(_ sender: UIButton)
    {
        self.isInactiveAppsCollapsed.toggle()
        self.collectionView.reloadSections(IndexSet(integer: Section.inactiveApps.rawValue))
    }
    
    @objc func toggleCollapseAppIDs(_ sender: UIButton)
    {
        self.isAppIDsCollapsed.toggle()
        self.collectionView.reloadSections(IndexSet(integer: Section.appIDs.rawValue))
    }
}

// MARK: - UICollectionViewDataSource
extension MyAppsViewController
{
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let itemCount = self.dataSource.collectionView(collectionView, numberOfItemsInSection: section)
        
        switch Section.allCases[section]
        {
        case .updates, .activeApps: return itemCount
        case .inactiveApps: return self.isInactiveAppsCollapsed ? 0 : itemCount
        case .appIDs: return self.isAppIDsCollapsed ? 0 : itemCount
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        if kind == UICollectionView.elementKindSectionFooter
        {
            let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FreeCompleteHeader", for: indexPath) as! InstalledAppDirectHeaderCollectionReusableView
            view.overrideUserInterfaceStyle = .light
            view.button.overrideUserInterfaceStyle = .light
            view.button.backgroundColor = CSSTheme.white
            view.button.layer.cornerRadius = CSSTheme.cornerRadius
            view.button.layer.borderWidth = 1.0
            view.button.layer.borderColor = CSSTheme.border.cgColor
            view.button.layer.shadowColor = CSSTheme.blue.cgColor
            view.button.layer.shadowOffset = CGSize(width: 0, height: 4)
            view.button.layer.shadowRadius = 8
            view.button.layer.shadowOpacity = 0.07
            
            let remainingAppIDs = self.team?.remainingAppIDs.intValue ?? 0
            
            let textColor = CSSTheme.pureBlack
            let boldFont = UIFont.boldSystemFont(ofSize: 13)
            let regularFont = UIFont.systemFont(ofSize: 13)
            
            let attributedTitle = NSMutableAttributedString(string: "Tài khoản nhà phát triển miễn phí giới hạn tối đa ", attributes: [.font: regularFont, .foregroundColor: textColor])
            attributedTitle.append(NSAttributedString(string: "3 ứng dụng hoạt động", attributes: [.font: boldFont, .foregroundColor: CSSTheme.blue]))
            attributedTitle.append(NSAttributedString(string: " cùng lúc và ", attributes: [.font: regularFont, .foregroundColor: textColor]))
            attributedTitle.append(NSAttributedString(string: "10 App ID mỗi tuần.\n\n", attributes: [.font: boldFont, .foregroundColor: CSSTheme.blue]))
            
            attributedTitle.append(NSAttributedString(string: "Số App ID còn lại có thể đăng ký: ", attributes: [.font: regularFont, .foregroundColor: textColor]))
            attributedTitle.append(NSAttributedString(string: "\(remainingAppIDs)", attributes: [.font: boldFont, .foregroundColor: CSSTheme.purple]))
            
            view.button.setAttributedTitle(attributedTitle, for: .normal)
            view.button.addTarget(self, action: #selector(MyAppsViewController.presentAppIDs(_:)), for: .primaryActionTriggered)
            
            return view
        }
        
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "HeaderView", for: indexPath) as! SectionHeaderView
        headerView.actionButton.removeTarget(self, action: nil, for: .primaryActionTriggered)
        
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .updates:
            self.styleSectionHeaderView(headerView, iconName: "arrow.down.circle.fill", title: "BẢN CẬP NHẬT KHẢ DỤNG")
            headerView.helpButton.isHidden = true
            headerView.actionButton.isHidden = true
            
        case .activeApps:
            let activeCount = self.activeAppsDataSource.itemCount
            self.styleSectionHeaderView(headerView, iconName: "checkmark.seal.fill", title: "ĐANG HOẠT ĐỘNG (\(activeCount))")
            headerView.helpButton.isHidden = true
            headerView.actionButton.isHidden = false
            self.styleHeaderActionButton(headerView.actionButton, title: " Làm mới tất cả", iconName: "arrow.clockwise", isPurple: false)
            headerView.actionButton.addTarget(self, action: #selector(MyAppsViewController.refreshAllApps(_:)), for: .primaryActionTriggered)
            
        case .inactiveApps:
            let inactiveCount = self.inactiveAppsDataSource.itemCount
            self.styleSectionHeaderView(headerView, iconName: "moon.zzz.fill", title: "ĐANG TẠM TẮT (\(inactiveCount))")
            headerView.helpButton.isHidden = false
            headerView.helpButton.tintColor = CSSTheme.blue
            headerView.helpButton.addTarget(self, action: #selector(MyAppsViewController.presentInactiveAppsAlert(_:)), for: .primaryActionTriggered)
            headerView.actionButton.isHidden = false
            
            let isExpanded = !self.isInactiveAppsCollapsed
            let title = isExpanded ? " Ẩn ▲" : " Hiện ▼"
            let symbol = isExpanded ? "eye.slash.fill" : "eye.fill"
            self.styleHeaderActionButton(headerView.actionButton, title: title, iconName: symbol, isPurple: isExpanded)
            headerView.actionButton.addTarget(self, action: #selector(MyAppsViewController.toggleCollapseInactiveApps(_:)), for: .primaryActionTriggered)
            
        case .appIDs:
            let appIDsCount = self.appIDsDataSource.itemCount
            self.styleSectionHeaderView(headerView, iconName: "app.badge.checkmark.fill", title: "ĐỊNH DANH APP ID (\(appIDsCount))")
            headerView.helpButton.isHidden = false
            headerView.helpButton.tintColor = CSSTheme.blue
            headerView.helpButton.addTarget(self, action: #selector(MyAppsViewController.presentAppIDsAlert(_:)), for: .primaryActionTriggered)
            headerView.actionButton.isHidden = false
            
            let isExpanded = !self.isAppIDsCollapsed
            let title = isExpanded ? " Ẩn ▲" : " Hiện ▼"
            let symbol = isExpanded ? "eye.slash.fill" : "eye.fill"
            self.styleHeaderActionButton(headerView.actionButton, title: title, iconName: symbol, isPurple: isExpanded)
            headerView.actionButton.addTarget(self, action: #selector(MyAppsViewController.toggleCollapseAppIDs(_:)), for: .primaryActionTriggered)
        }
        
        return headerView
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        self.styleAppCardCell(cell)
    }
    
    // Hiệu ứng nhấn lò xo (Spring Bounce) mượt mà giống hệt SettingsViewController
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(translationX: 4, y: -2).scaledBy(x: 0.98, y: 0.98)
            }) { [weak self] _ in
                self?.styleAppCardCell(cell)
                UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut, animations: {
                    cell.transform = .identity
                }, completion: { [weak self] _ in
                    self?.styleAppCardCell(cell)
                })
            }
        }
    }
    
    @objc private func presentAppIDs(_ sender: UIButton)
    {
        self.performSegue(withIdentifier: "showAppIDs", sender: sender)
    }
    
    @objc private func presentInactiveAppsAlert(_ sender: UIButton)
    {
        let alertController = UIAlertController(title: "Ứng dụng đang tạm tắt", message: "Tài khoản nhà phát triển miễn phí chỉ cho phép tối đa 3 ứng dụng hoạt động cùng lúc. Khi bạn tạm tắt một ứng dụng, SideStore sẽ tự động sao lưu toàn bộ dữ liệu để bạn có thể kích hoạt lại bất cứ lúc nào mà không bị mất dữ liệu.", preferredStyle: .alert)
        alertController.addAction(.ok)
        self.present(alertController, animated: true, completion: nil)
    }
    
    @objc private func presentAppIDsAlert(_ sender: UIButton)
    {
        let alertController = UIAlertController(title: "Định danh App ID", message: "Mỗi ứng dụng và tiện ích mở rộng (App Extension) đều cần một định danh App ID riêng biệt trên hệ thống Apple. Với tài khoản miễn phí, bạn được phép tạo tối đa 10 App ID mới mỗi 7 ngày.", preferredStyle: .alert)
        alertController.addAction(.ok)
        self.present(alertController, animated: true, completion: nil)
    }
}

// MARK: - UICollectionViewDelegateFlowLayout
extension MyAppsViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let layout = collectionViewLayout as! UICollectionViewFlowLayout
        let horizontalPadding = collectionView.safeAreaInsets.left + collectionView.safeAreaInsets.right + layout.sectionInset.left + layout.sectionInset.right
        let width = (collectionView.bounds.width - horizontalPadding)
        
        switch Section.allCases[indexPath.section]
        {
        case .updates:
            let item = self.updatesDataSource.item(at: indexPath)
            
            let height: CGFloat
            if let (collapsedHeight, expandedHeight) = self.updateContentHeights[item.bundleIdentifier]
            {
                if self.collapsedTextIds.contains(item.bundleIdentifier)
                {
                    height = collapsedHeight
                }
                else
                {
                    height = expandedHeight
                }
            }
            else
            {
                let widthConstraint = self.prototypeUpdateCell.contentView.widthAnchor.constraint(equalToConstant: width)
                widthConstraint.isActive = true
                defer { widthConstraint.isActive = false }
                
                self.updatesDataSource.cellConfigurationHandler(self.prototypeUpdateCell, item, indexPath)
                
                self.prototypeUpdateCell.mode = .collapsed
                let collapsedSize = self.prototypeUpdateCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
                
                self.prototypeUpdateCell.mode = .expanded
                let expandedSize = self.prototypeUpdateCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
                
                self.updateContentHeights[item.bundleIdentifier] = (collapsedSize.height, expandedSize.height)
                
                if collapsedSize.height == expandedSize.height
                {
                    self.collapsedTextIds.remove(item.bundleIdentifier)
                }
                else
                {
                    self.collapsedTextIds.insert(item.bundleIdentifier)
                }
                
                height = collapsedSize.height
            }
            
            return CGSize(width: width, height: height)
            
        case .activeApps, .inactiveApps:
            return CGSize(width: width, height: 88)
            
        case .appIDs:
            return CGSize(width: width, height: 62)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        switch Section.allCases[section]
        {
        case .updates:
            guard self.updatesDataSource.itemCount > 0 else { return .zero }
            
        case .activeApps:
            guard self.activeAppsDataSource.itemCount > 0 else { return .zero }
            
        case .inactiveApps:
            guard self.inactiveAppsDataSource.itemCount > 0 && self.team?.type == .free else { return .zero }
            
        case .appIDs:
            guard self.appIDsDataSource.itemCount > 0 && self.team?.type == .free else { return .zero }
        }
        
        return CGSize(width: collectionView.bounds.width, height: 46)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        guard Section.allCases[section] == .activeApps && self.team?.type == .free && self.activeAppsDataSource.itemCount > 0 else { return .zero }
        
        return CGSize(width: collectionView.bounds.width, height: 112)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        let sectionType = Section.allCases[section]
        switch sectionType
        {
        case .updates where self.updatesDataSource.itemCount == 0,
             .activeApps where self.activeAppsDataSource.itemCount == 0,
             .inactiveApps where self.inactiveAppsDataSource.itemCount == 0 || self.isInactiveAppsCollapsed,
             .appIDs where self.appIDsDataSource.itemCount == 0 || self.isAppIDsCollapsed:
            return .zero
            
        default:
            return UIEdgeInsets(top: 10, left: 16, bottom: 20, right: 16)
        }
    }
}

// MARK: - UIDocumentPickerDelegate
extension MyAppsViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        self.importApp(at: url)
    }
}

// MARK: - UIContextMenuInteractionDelegate (Menu ngữ cảnh Tiếng Việt)
extension MyAppsViewController: UIContextMenuInteractionDelegate
{
    private enum Action: String, CaseIterable
    {
        case update
        case refresh
        case activate
        case deactivate
        case remove
        case open
        case backup
        case restore
        case enableJit
        
        var title: String {
            switch self
            {
            case .update: return "Cập nhật ứng dụng"
            case .refresh: return "Làm mới thời hạn"
            case .activate: return "Kích hoạt ứng dụng"
            case .deactivate: return "Tạm tắt ứng dụng"
            case .remove: return "Xóa ứng dụng"
            case .open: return "Mở ứng dụng"
            case .backup: return "Sao lưu dữ liệu"
            case .restore: return "Khôi phục dữ liệu"
            case .enableJit: return "Bật tăng tốc SideJIT"
            }
        }
        
        var systemImageName: String {
            switch self
            {
            case .update: return "arrow.up.circle"
            case .refresh: return "arrow.clockwise"
            case .activate: return "bolt.fill"
            case .deactivate: return "bolt.slash.fill"
            case .remove: return "trash"
            case .open: return "arrow.up.forward.app"
            case .backup: return "arrow.down.doc"
            case .restore: return "arrow.up.doc"
            case .enableJit: return "cpu"
            }
        }
    }
    
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration?
    {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { (suggestedActions) -> UIMenu? in
            let refreshAllAction = UIAction(title: "Làm mới tất cả ứng dụng", image: UIImage(systemName: "arrow.clockwise")) { [weak self] (action) in
                guard let self = self else { return }
                self.refreshAllApps(UIButton())
            }
            
            let importIPAAction = UIAction(title: "Cài đặt tệp .IPA", image: UIImage(systemName: "plus.circle")) { [weak self] _ in
                self?.importApp()
            }
            
            return UIMenu(title: "Tác vụ nhanh", image: nil, identifier: nil, options: [], children: [importIPAAction, refreshAllAction])
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        let section = Section.allCases[indexPath.section]
        guard section == .activeApps || section == .inactiveApps else { return nil }
        
        let app: InstalledApp
        switch section
        {
        case .activeApps: app = self.activeAppsDataSource.item(at: indexPath)
        case .inactiveApps: app = self.inactiveAppsDataSource.item(at: indexPath)
        default: return nil
        }
        
        return UIContextMenuConfiguration(identifier: indexPath as NSCopying, previewProvider: nil) { [weak self] _ in
            guard let self = self else { return nil }
            
            var actions = [UIMenuElement]()
            
            if app.isActive
            {
                let openAction = UIAction(title: Action.open.title, image: UIImage(systemName: Action.open.systemImageName)) { _ in
                    self.perform(.open, for: app)
                }
                let refreshAction = UIAction(title: Action.refresh.title, image: UIImage(systemName: Action.refresh.systemImageName)) { _ in
                    self.perform(.refresh, for: app)
                }
                let jitAction = UIAction(title: Action.enableJit.title, image: UIImage(systemName: Action.enableJit.systemImageName)) { _ in
                    self.perform(.enableJit, for: app)
                }
                actions.append(UIMenu(title: "", options: .displayInline, children: [openAction, refreshAction, jitAction]))
                
                if !app.isAltStoreApp
                {
                    let backupAction = UIAction(title: Action.backup.title, image: UIImage(systemName: Action.backup.systemImageName)) { _ in
                        self.perform(.backup, for: app)
                    }
                    let restoreAction = UIAction(title: Action.restore.title, image: UIImage(systemName: Action.restore.systemImageName)) { _ in
                        self.perform(.restore, for: app)
                    }
                    actions.append(UIMenu(title: "", options: .displayInline, children: [backupAction, restoreAction]))
                    
                    if self.team?.type == .free
                    {
                        let deactivateAction = UIAction(title: Action.deactivate.title, image: UIImage(systemName: Action.deactivate.systemImageName)) { _ in
                            self.perform(.deactivate, for: app)
                        }
                        actions.append(UIMenu(title: "", options: .displayInline, children: [deactivateAction]))
                    }
                }
            }
            else
            {
                let activateAction = UIAction(title: Action.activate.title, image: UIImage(systemName: Action.activate.systemImageName)) { _ in
                    self.perform(.activate, for: app)
                }
                actions.append(UIMenu(title: "", options: .displayInline, children: [activateAction]))
            }
            
            if !app.isAltStoreApp
            {
                let removeAction = UIAction(title: Action.remove.title, image: UIImage(systemName: Action.remove.systemImageName), attributes: .destructive) { _ in
                    self.perform(.remove, for: app)
                }
                actions.append(UIMenu(title: "", options: .displayInline, children: [removeAction]))
            }
            
            return UIMenu(title: app.name, children: actions)
        }
    }
}
