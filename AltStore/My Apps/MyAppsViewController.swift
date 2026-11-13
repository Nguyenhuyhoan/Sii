
//
//  MyAppsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/16/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
@preconcurrency import Intents
import SideSign
import SwiftUI
import MobileCoreServices
import Combine
import CoreData
import UniformTypeIdentifiers
import SemanticVersion

import Nuke

private let maximumCollapsedUpdatesCount = 2

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ VỚI TAB CÀI ĐẶT & CỐ ĐỊNH NỀN SÁNG)
private struct CSSTheme {
    static let white = UIColor.white
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0) // #f8f9fa
    static let border = UIColor(red: 230/255, green: 235/255, blue: 242/255, alpha: 1.0) // #e6ebf2
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0) // #007bff
    static let pillBg = UIColor(red: 238/255, green: 245/255, blue: 255/255, alpha: 1.0) // #eef5ff
    static let pillBorder = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.22)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0) // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0) // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0) // #dc3545
    static let redBg = UIColor(red: 255/255, green: 240/255, blue: 242/255, alpha: 1.0)
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0) // #ff00ff
    static let textPrimary = UIColor(red: 24/255, green: 28/255, blue: 36/255, alpha: 1.0) // #181c24
    static let textSecondary = UIColor(red: 92/255, green: 102/255, blue: 117/255, alpha: 1.0) // #5c6675

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.92).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.88).cgColor

    static let cornerRadius: CGFloat = 16.0
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG HOẶC ĐEN KHI CUỘN)
private final class MyAppsGradientBackgroundView: UIView {
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
        self.overrideUserInterfaceStyle = .light
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
        case noUpdates
        case updates
        case activeApps
        case inactiveApps
    }
}

// @livecontainer
@objc(MyAppsViewController)
class MyAppsViewController: UICollectionViewController
{
    private let coordinator = NSFileCoordinator()
    private let operationQueue = OperationQueue()
    
    private lazy var dataSource = self.makeDataSource()
    private lazy var noUpdatesDataSource = self.makeNoUpdatesDataSource()
    private lazy var updatesDataSource = self.makeUpdatesDataSource()
    private lazy var activeAppsDataSource = self.makeActiveAppsDataSource()
    private lazy var inactiveAppsDataSource = self.makeInactiveAppsDataSource()
    private lazy var unsupportedUpdates = Set<StoreApp>()
    
    private var prototypeUpdateCell: UpdateCollectionViewCell!
    private var sideloadingProgressView: UIProgressView!
    
    // State
    private var isUpdateSectionCollapsed = true
    private var expandedAppUpdates = Set<String>()
    private var isRefreshingAllApps = false
    private var refreshGroup: RefreshGroup?
    private var sideloadingProgress: Progress?
    private var dropDestinationIndexPath: IndexPath?
    private var isCheckingForUpdates = false
    private var didChangeActiveApps = false
    private var previousInactiveAppsCount = 0
    private var statusDotView: UIView?
    
    // Thành phần giao diện CSS Hero Banner & Nút điều hướng nổi
    private var heroContainerView: UIView?
    private var heroCardView: UIView?
    private var heroGradientLayer: CAGradientLayer?
    private var heroSideloadButton: UIButton?
    private var heroSideloadSpinner: UIActivityIndicatorView?
    private var heroRefreshAllButton: UIButton?
    private var floatingBackButton: UIButton?
    private let heroTopSpace: CGFloat = 104.0
    
    private var _imagePickerInstalledApp: InstalledApp?
    private var _viewDidAppear = false
    private var pendingImportURL: URL?
    
    private var minimuxerStatusCheckTask: Task<Void, Never>?
    
    // Cache
    private var cachedUpdateSizes = [String: CGSize]()
    
    private var activeTeam: ALTTeam?
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.didFetchSource(_:)), name: AppManager.didFetchSourceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.appIDsViewControllerDidDismiss(_:)), name: AppIDsViewController.didDismissNotification, object: nil)
    }
    
    deinit {
        if !(minimuxerStatusCheckTask?.isCancelled == true) {
            minimuxerStatusCheckTask?.cancel()
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Cố định toàn bộ màn hình ở giao diện Sáng (Light Mode) để không bao giờ bị chuyển sang nền đen
        self.overrideUserInterfaceStyle = .light
        self.view.overrideUserInterfaceStyle = .light
        self.collectionView.overrideUserInterfaceStyle = .light
        
        // Ẩn hoàn toàn thanh điều hướng trắng ở trên cùng để đồng bộ với Tab Cài đặt
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        #endif
        
        // Cho phép can thiệp các callback từ FetchedResultsController.
        self.updatesDataSource.fetchedResultsController.delegate = self
        self.activeAppsDataSource.fetchedResultsController.delegate = self
        self.inactiveAppsDataSource.fetchedResultsController.delegate = self
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        #if !os(tvOS)
        self.collectionView.dragDelegate = self
        self.collectionView.dropDelegate = self
        self.collectionView.dragInteractionEnabled = false
        #endif
                
        self.prototypeUpdateCell = UpdateCollectionViewCell.instantiate(with: UpdateCollectionViewCell.nib)
        self.prototypeUpdateCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        self.prototypeUpdateCell.overrideUserInterfaceStyle = .light
        
        self.collectionView.register(UpdateCollectionViewCell.nib, forCellWithReuseIdentifier: "UpdateCell")
        self.collectionView.register(UpdatesCollectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "UpdatesHeader")
        self.collectionView.register(InstalledAppsCollectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ActiveAppsHeader")
        self.collectionView.register(InstalledAppsCollectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "InactiveAppsHeader")
        
        #if !os(tvOS)
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = CSSTheme.blue
        refreshControl.addTarget(self, action: #selector(MyAppsViewController.checkForUpdates(_:)), for: .primaryActionTriggered)
        self.collectionView.refreshControl = refreshControl
        #endif
        
        #if !os(tvOS)
        self.sideloadingProgressView = UIProgressView(progressViewStyle: .bar)
        #else
        self.sideloadingProgressView = UIProgressView(progressViewStyle: .default)
        #endif
        self.sideloadingProgressView.translatesAutoresizingMaskIntoConstraints = false
        self.sideloadingProgressView.progressTintColor = CSSTheme.green
        self.sideloadingProgressView.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        self.sideloadingProgressView.progress = 0
        self.sideloadingProgressView.isHidden = true
        
        // ✨ KÍCH HOẠT GIAO DIỆN WEB CSS & VIỆT HÓA ✨
        self.applySmartWebCSSTheme()
        
        #if !os(tvOS)
        self.registerForPreviewing(with: self, sourceView: self.collectionView)
        #endif
        
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.didChangeAppIcon(_:)), name: UIApplication.didChangeAppIconNotification, object: nil)
        
        if minimuxerStatusCheckTask == nil {
            minimuxerStatusCheckTask = Task {
                let status = await isMinimuxerReady()
                updateStatusDot(isReady: status.isSuccess)
                // Lắng nghe trạng thái minimuxer theo thời gian thực
                for await result in minimuxerStatusPublisher.values {
                    guard !Task.isCancelled else { break }
                    updateStatusDot(isReady: result.isSuccess)
                }
            }
        }
        
        Task { @MainActor [weak self] in
            self?.activeTeam = try? await AuthManager.shared.getAuthenticatedTeam()
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewIsAppearing(_ animated: Bool)
    {
        super.viewIsAppearing(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            let team = try? await AuthManager.shared.getAuthenticatedTeam()
            if self.activeTeam != team
            {
                self.activeTeam = team
                self.collectionView.reloadData()
            }
        }
        
        self.collectionView.reloadData()
        
        self.update()
        
        self.fetchAppIDs()
        
        self.previousInactiveAppsCount = self.inactiveAppsDataSource.itemCount
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        if let heroContainer = self.heroContainerView {
            heroContainer.frame = CGRect(x: 0, y: -self.heroTopSpace, width: self.collectionView.bounds.width, height: self.heroTopSpace)
        }
        if let heroCard = self.heroCardView {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        _viewDidAppear = true

        if let pendingURL = self.pendingImportURL {
            self.pendingImportURL = nil
            self.presentImportDialog(for: pendingURL)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
    }

    private func updateStatusDot(isReady: Bool)
    {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let dot = self.statusDotView else { return }
            
            let targetColor: UIColor = isReady ? CSSTheme.green : CSSTheme.magenta
            
            if dot.alpha == 0.0 {
                dot.backgroundColor = targetColor
                UIView.animate(withDuration: 0.35, delay: 0.1, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.8, options: [], animations: {
                    dot.transform = .identity
                    dot.alpha = 1.0
                }, completion: nil)
            } else if dot.backgroundColor != targetColor {
                UIView.animate(withDuration: 0.25, delay: 0.0, options: [.beginFromCurrentState, .curveEaseInOut]) {
                    dot.backgroundColor = targetColor
                    dot.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                } completion: { _ in
                    UIView.animate(withDuration: 0.15, delay: 0.0, options: .curveEaseInOut) {
                        dot.transform = .identity
                    }
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        let controller = segue.destination
        controller.title = nil
        controller.navigationItem.title = nil
        #if !os(tvOS)
        controller.navigationItem.largeTitleDisplayMode = .never
        #endif
        
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "showApp", "showUpdate":
            guard let cell = sender as? UICollectionViewCell, let indexPath = self.collectionView.indexPath(for: cell) else { return }
            
            let installedApp = self.dataSource.item(at: indexPath)
            
            let appViewController = segue.destination as! AppViewController
            appViewController.app = installedApp.storeApp
            
        case "showAppIDs":
            let navigationController = segue.destination as? UINavigationController
            let appIDsViewController = navigationController?.viewControllers.first as? AppIDsViewController
            appIDsViewController?.activeTeam = self.activeTeam
            
        default: break
        }
    }
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool
    {
        guard identifier == "showApp" else { return true }
        
        guard let cell = sender as? UICollectionViewCell, let indexPath = self.collectionView.indexPath(for: cell) else { return true }
        
        let installedApp = self.dataSource.item(at: indexPath)
        return !installedApp.isSideloaded
    }
    
    @IBAction func unwindToMyAppsViewController(_ segue: UIStoryboardSegue)
    {
    }
}

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ CỐ ĐỊNH Ở MỤC CON
extension MyAppsViewController: UINavigationControllerDelegate, UIGestureRecognizerDelegate {
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

// MARK: - ✨ HỆ THỐNG RENDER CSS THÔNG MINH & VIỆT HÓA TOÀN DIỆN (CỐ ĐỊNH NỀN SÁNG TRẮNG)
private extension MyAppsViewController {

    func applySmartWebCSSTheme() {
        // 1. Nền Gradient cố định toàn màn hình
        let bgView = MyAppsGradientBackgroundView(frame: UIScreen.main.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.collectionView.backgroundView = bgView
        self.collectionView.backgroundColor = .clear
        
        // 2. Dành không gian phía trên cho khối .hero Banner và dưới đáy cho TabBar
        self.collectionView.contentInset.top = self.heroTopSpace
        self.collectionView.contentInset.bottom = 40
        
        // 3. Khởi tạo khối .hero Banner kèm nút "+ Cài IPA" và "Làm mới"
        setupCSSHeroBanner()
        
        // 4. Đồng bộ màu Badge trên TabBar
        #if !os(tvOS)
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = CSSTheme.blue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif
        self.navigationController?.tabBarItem.title = "Ứng dụng"
    }

    func setupCSSHeroBanner() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: -self.heroTopSpace, width: self.collectionView.bounds.width, height: self.heroTopSpace))
        headerContainer.backgroundColor = .clear
        headerContainer.autoresizingMask = [.flexibleWidth]
        headerContainer.overrideUserInterfaceStyle = .light
        self.heroContainerView = headerContainer
        
        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = CSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = CSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.25
        self.heroCardView = heroCard
        
        let gradient = CAGradientLayer()
        gradient.colors = [CSSTheme.heroStart, CSSTheme.heroEnd]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = CSSTheme.cornerRadius
        heroCard.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient
        
        // Tiêu đề chính + Chấm trạng thái Minimuxer
        let titleStack = UIStackView()
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.alignment = .center
        titleStack.spacing = 7
        
        let titleLabel = UILabel()
        titleLabel.text = "Ứng dụng của tôi"
        titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .heavy)
        titleLabel.textColor = CSSTheme.white
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.35
        
        let dot = UIView()
        dot.translatesAutoresizingMaskIntoConstraints = false
        dot.layer.cornerRadius = 4.5
        dot.backgroundColor = CSSTheme.green
        dot.layer.borderWidth = 1.5
        dot.layer.borderColor = CSSTheme.white.cgColor
        dot.transform = CGAffineTransform(scaleX: 0.01, y: 0.01)
        dot.alpha = 0.0
        self.statusDotView = dot
        
        NSLayoutConstraint.activate([
            dot.widthAnchor.constraint(equalToConstant: 9),
            dot.heightAnchor.constraint(equalToConstant: 9)
        ])
        
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(dot)
        
        // Phụ đề hướng dẫn
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Quản lý, cài đặt tệp .ipa & gia hạn ứng dụng dễ dàng"
        subLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        subLabel.textColor = CSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 1
        subLabel.adjustsFontSizeToFitWidth = true
        
        // Nút "+ Cài IPA" bên trái Hero Card
        let addBtn = UIButton(type: .system)
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        let plusConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        addBtn.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: plusConfig), for: .normal)
        addBtn.setTitle(" Cài IPA", for: .normal)
        addBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        addBtn.tintColor = CSSTheme.blue
        addBtn.setTitleColor(CSSTheme.blue, for: .normal)
        addBtn.backgroundColor = CSSTheme.white
        addBtn.layer.cornerRadius = 14
        addBtn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 11)
        addBtn.layer.shadowColor = UIColor.black.cgColor
        addBtn.layer.shadowOffset = CGSize(width: 0, height: 2)
        addBtn.layer.shadowRadius = 4
        addBtn.layer.shadowOpacity = 0.18
        addBtn.addTarget(self, action: #selector(handleHeroSideloadButtonTap(_:)), for: .touchUpInside)
        self.heroSideloadButton = addBtn
        
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = CSSTheme.blue
        spinner.hidesWhenStopped = true
        addBtn.addSubview(spinner)
        self.heroSideloadSpinner = spinner
        
        // Nút "Làm mới" nhanh bên phải Hero Card
        let refreshBtn = UIButton(type: .system)
        refreshBtn.translatesAutoresizingMaskIntoConstraints = false
        let refConfig = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)
        refreshBtn.setImage(UIImage(systemName: "arrow.clockwise", withConfiguration: refConfig), for: .normal)
        refreshBtn.tintColor = CSSTheme.white
        refreshBtn.backgroundColor = CSSTheme.white.withAlphaComponent(0.22)
        refreshBtn.layer.cornerRadius = 14
        refreshBtn.layer.borderWidth = 1.0
        refreshBtn.layer.borderColor = CSSTheme.white.withAlphaComponent(0.45).cgColor
        refreshBtn.addTarget(self, action: #selector(handleHeroRefreshAllTap(_:)), for: .touchUpInside)
        self.heroRefreshAllButton = refreshBtn
        
        // Gắn thanh tiến trình cài đặt vào cạnh dưới Hero Card
        self.sideloadingProgressView.layer.cornerRadius = 2
        self.sideloadingProgressView.clipsToBounds = true
        
        heroCard.addSubview(titleStack)
        heroCard.addSubview(subLabel)
        heroCard.addSubview(addBtn)
        heroCard.addSubview(refreshBtn)
        heroCard.addSubview(self.sideloadingProgressView)
        headerContainer.addSubview(heroCard)
        self.collectionView.addSubview(headerContainer)
        
        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -6),
            
            addBtn.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            addBtn.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 12),
            addBtn.heightAnchor.constraint(equalToConstant: 28),
            
            spinner.centerXAnchor.constraint(equalTo: addBtn.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: addBtn.centerYAnchor),
            
            refreshBtn.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            refreshBtn.centerYAnchor.constraint(equalTo: addBtn.centerYAnchor),
            refreshBtn.widthAnchor.constraint(equalToConstant: 32),
            refreshBtn.heightAnchor.constraint(equalToConstant: 28),
            
            titleStack.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor, constant: 14),
            titleStack.centerYAnchor.constraint(equalTo: addBtn.centerYAnchor),
            
            subLabel.topAnchor.constraint(equalTo: addBtn.bottomAnchor, constant: 12),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            
            self.sideloadingProgressView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            self.sideloadingProgressView.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            self.sideloadingProgressView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -3),
            self.sideloadingProgressView.heightAnchor.constraint(equalToConstant: 3)
        ])
        
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
    }

    func setSideloadingActivity(_ isIndicating: Bool) {
        self.navigationItem.leftBarButtonItem?.isIndicatingActivity = isIndicating
        guard let btn = self.heroSideloadButton, let spinner = self.heroSideloadSpinner else { return }
        if isIndicating {
            btn.setTitle("         ", for: .normal)
            btn.setImage(nil, for: .normal)
            spinner.startAnimating()
            btn.isUserInteractionEnabled = false
        } else {
            spinner.stopAnimating()
            let plusConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
            btn.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: plusConfig), for: .normal)
            btn.setTitle(" Cài IPA", for: .normal)
            btn.isUserInteractionEnabled = true
        }
    }

    @objc func handleHeroSideloadButtonTap(_ sender: UIButton) {
        animateButtonBounce(sender)
        let barButton = self.navigationItem.leftBarButtonItem ?? UIBarButtonItem()
        self.sideloadApp(barButton)
    }

    @objc func handleHeroRefreshAllTap(_ sender: UIButton) {
        animateButtonBounce(sender)
        let barButton = self.navigationItem.rightBarButtonItem ?? UIBarButtonItem()
        self.refreshAllApps(barButton)
    }

    func animateButtonBounce(_ sender: UIView) {
        UIView.animate(withDuration: 0.12, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                sender.transform = .identity
            }
        }
    }

    // Dịch tự động các chuỗi thời gian hết hạn của nút ứng dụng sang tiếng Việt
    func translateDynamicAppText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return text }
        
        let staticMap: [String: String] = [
            "Expires in": "Hết hạn sau",
            "Expired": "Đã hết hạn",
            "EXPIRED": "ĐÃ HẾT HẠN",
            "Revoked": "Đã thu hồi",
            "REVOKED": "ĐÃ THU HỒI",
            "ACTIVATE": "KÍCH HOẠT",
            "Activate": "Kích hoạt",
            "UPDATE": "CẬP NHẬT",
            "Update": "Cập nhật",
            "OPEN": "MỞ",
            "Open": "Mở",
            "MORE": "THÊM",
            "More": "Xem thêm",
            "LESS": "THU GỌN",
            "Less": "Thu gọn"
        ]
        if let mapped = staticMap[trimmed] {
            return mapped
        }
        
        var result = trimmed
        result = result.replacingOccurrences(of: "DAYS", with: "NGÀY")
        result = result.replacingOccurrences(of: "DAY", with: "NGÀY")
        result = result.replacingOccurrences(of: "days", with: "ngày")
        result = result.replacingOccurrences(of: "day", with: "ngày")
        result = result.replacingOccurrences(of: "HRS", with: "GIỜ")
        result = result.replacingOccurrences(of: "HR", with: "GIỜ")
        result = result.replacingOccurrences(of: "hours", with: "giờ")
        result = result.replacingOccurrences(of: "hour", with: "giờ")
        result = result.replacingOccurrences(of: "MINS", with: "PHÚT")
        result = result.replacingOccurrences(of: "MIN", with: "PHÚT")
        result = result.replacingOccurrences(of: "minutes", with: "phút")
        result = result.replacingOccurrences(of: "minute", with: "phút")
        return result
    }

    // Triệt tiêu hoàn toàn mọi lớp nền tối/blur của hệ thống hoặc của AppBannerView và cố định nền sáng trắng
    func applyWhiteCardAndBlackText(in rootView: UIView) {
        rootView.overrideUserInterfaceStyle = .light
        for subview in rootView.subviews {
            subview.overrideUserInterfaceStyle = .light
            
            // Vô hiệu hóa triệt để UIVisualEffectView (nguyên nhân chính gây ra nền đen khi load icon tối màu hoặc Dark Mode)
            if let effectView = subview as? UIVisualEffectView {
                effectView.effect = nil
                effectView.backgroundColor = .clear
                effectView.contentView.backgroundColor = .clear
                effectView.isHidden = true
                effectView.alpha = 0
                continue
            }
            
            // Nếu có view nền phụ bên dưới (không phải nút hay ảnh), ép về trong suốt để lộ nền trắng cố định của thẻ
            if !(subview is UIControl) && !(subview is UIImageView) && !(subview is UILabel) && !(subview is UITextView) && !(subview is UIStackView) {
                if subview.backgroundColor != nil && subview.backgroundColor != .clear && subview.backgroundColor != CSSTheme.white {
                    subview.backgroundColor = .clear
                }
            }
            
            if let label = subview as? UILabel {
                label.textColor = CSSTheme.textPrimary
            } else if let textView = subview as? UITextView {
                textView.textColor = CSSTheme.textPrimary
                textView.backgroundColor = .clear
            } else if let button = subview as? UIButton {
                let titleText = (button.title(for: .normal) ?? "").uppercased()
                let isWarning = titleText.contains("HẾT HẠN") || titleText.contains("THU HỒI") || titleText.contains("EXPIRED") || titleText.contains("REVOKED")
                let tint = isWarning ? CSSTheme.red : CSSTheme.blue
                
                button.tintColor = tint
                button.setTitleColor(tint, for: .normal)
                button.setTitleColor(tint.withAlphaComponent(0.7), for: .highlighted)
                button.setTitleColor(tint, for: .selected)
                button.titleLabel?.textColor = tint
                button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                
                if button is PillButton {
                    button.backgroundColor = isWarning ? CSSTheme.redBg : CSSTheme.pillBg
                    button.layer.borderWidth = 1.0
                    button.layer.borderColor = isWarning ? CSSTheme.red.withAlphaComponent(0.28).cgColor : CSSTheme.pillBorder.cgColor
                }
            }
            
            applyWhiteCardAndBlackText(in: subview)
        }
    }

    // Làm đẹp từng thẻ Ứng dụng: Cố định nền trắng sáng gốc, bo góc mượt, bóng đổ xanh dịu và tinh chỉnh chữ/icon
    func styleAppCardCell(_ cell: UICollectionViewCell) {
        cell.overrideUserInterfaceStyle = .light
        cell.contentView.overrideUserInterfaceStyle = .light
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.backgroundView = nil
        cell.selectedBackgroundView = nil
        
        // Đổ bóng xanh dịu hiện đại
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = CSSTheme.blue.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 5)
        cell.layer.shadowRadius = 12
        cell.layer.shadowOpacity = 0.08
        
        if let appCell = cell as? InstalledAppCollectionViewCell {
            let banner = appCell.bannerView!
            banner.overrideUserInterfaceStyle = .light
            banner.backgroundColor = CSSTheme.white
            banner.tintColor = CSSTheme.blue
            banner.layer.cornerRadius = CSSTheme.cornerRadius
            banner.layer.cornerCurve = .continuous
            banner.layer.masksToBounds = true
            banner.layer.borderWidth = 1.0
            banner.layer.borderColor = CSSTheme.border.cgColor
            
            if let btnTitle = banner.button.title(for: .normal) {
                banner.button.setTitle(translateDynamicAppText(btnTitle), for: .normal)
            }
            
            // Đệ quy dọn sạch mọi lớp nền đen/blur và chuẩn hóa nút bấm
            applyWhiteCardAndBlackText(in: banner)
            
            // Tinh chỉnh phân cấp Typography & Icon sau khi dọn nền
            banner.titleLabel.textColor = CSSTheme.textPrimary
            banner.titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            banner.subtitleLabel.textColor = CSSTheme.textSecondary
            banner.subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            banner.buttonLabel.textColor = CSSTheme.textSecondary
            banner.buttonLabel.font = UIFont.systemFont(ofSize: 10.5, weight: .semibold)
            
            banner.iconImageView.backgroundColor = CSSTheme.light
            banner.iconImageView.layer.cornerRadius = 13.5
            banner.iconImageView.layer.cornerCurve = .continuous
            banner.iconImageView.layer.masksToBounds = true
            banner.iconImageView.layer.borderWidth = 0.8
            banner.iconImageView.layer.borderColor = CSSTheme.border.cgColor
            
        } else if let updateCell = cell as? UpdateCollectionViewCell {
            updateCell.contentView.backgroundColor = CSSTheme.white
            updateCell.contentView.layer.cornerRadius = CSSTheme.cornerRadius
            updateCell.contentView.layer.cornerCurve = .continuous
            updateCell.contentView.layer.masksToBounds = true
            updateCell.contentView.layer.borderWidth = 1.0
            updateCell.contentView.layer.borderColor = CSSTheme.border.cgColor
            
            let banner = updateCell.bannerView!
            banner.overrideUserInterfaceStyle = .light
            banner.backgroundColor = CSSTheme.white
            banner.tintColor = CSSTheme.blue
            banner.layer.cornerRadius = CSSTheme.cornerRadius
            banner.layer.cornerCurve = .continuous
            banner.layer.masksToBounds = true
            banner.layer.borderWidth = 0.0
            
            if let btnTitle = banner.button.title(for: .normal) {
                banner.button.setTitle(translateDynamicAppText(btnTitle), for: .normal)
            }
            if let toggleTitle = updateCell.versionDescriptionTextView.toggleButton.title(for: .normal) {
                updateCell.versionDescriptionTextView.toggleButton.setTitle(translateDynamicAppText(toggleTitle), for: .normal)
            }
            
            applyWhiteCardAndBlackText(in: updateCell.contentView)
            
            banner.titleLabel.textColor = CSSTheme.textPrimary
            banner.titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            banner.subtitleLabel.textColor = CSSTheme.textSecondary
            banner.subtitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
            
            banner.iconImageView.backgroundColor = CSSTheme.light
            banner.iconImageView.layer.cornerRadius = 13.5
            banner.iconImageView.layer.cornerCurve = .continuous
            banner.iconImageView.layer.masksToBounds = true
            banner.iconImageView.layer.borderWidth = 0.8
            banner.iconImageView.layer.borderColor = CSSTheme.border.cgColor
            
            updateCell.versionDescriptionTextView.textView.textColor = CSSTheme.textSecondary
            updateCell.versionDescriptionTextView.toggleButton.setTitleColor(CSSTheme.blue, for: .normal)
        }
    }

    // Gắn thanh gạch chân màu xanh (.features h2::after) dưới tiêu đề các mục giống Tab Cài đặt
    func styleSectionHeader(_ headerView: InstalledAppsCollectionHeaderView) {
        headerView.overrideUserInterfaceStyle = .light
        headerView.textLabel.textColor = CSSTheme.blue
        headerView.textLabel.font = UIFont.systemFont(ofSize: 16, weight: .heavy)
        
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
            underline.topAnchor.constraint(equalTo: headerView.textLabel.bottomAnchor, constant: 2),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3)
        ])
    }
}

private extension MyAppsViewController
{
    func makeDataSource() -> CompositeCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let dataSource = CompositeCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(dataSources: [self.noUpdatesDataSource, self.updatesDataSource, self.activeAppsDataSource, self.inactiveAppsDataSource])
        dataSource.proxy = self
        return dataSource
    }
    
    // Đã xóa bỏ hoàn toàn khung "Mọi ứng dụng đều đã được cập nhật mới nhất"
    func makeNoUpdatesDataSource() -> DynamicCollectionViewDataSource<InstalledApp>
    {
        let dynamicDataSource = DynamicCollectionViewDataSource<InstalledApp>()
        dynamicDataSource.numberOfSectionsHandler = { 1 }
        dynamicDataSource.numberOfItemsHandler = { _ in 0 }
        dynamicDataSource.cellIdentifierHandler = { _ in "NoUpdatesCell" }
        dynamicDataSource.dynamicCellConfigurationHandler = { _, _ in }
        return dynamicDataSource
    }
    
    func makeUpdatesDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest = InstalledApp.supportedUpdatesFetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.storeApp?.latestSupportedVersion?.date, ascending: false),
                                        NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.liveFetchLimit = maximumCollapsedUpdatesCount
        dataSource.cellIdentifierHandler = { _ in "UpdateCell" }
        dataSource.cellConfigurationHandler = { [weak self] (cell, installedApp, indexPath) in
            guard let self = self else { return }
            guard let app = installedApp.storeApp, let latestSupportedVersion = app.latestSupportedVersion else { return }
            
            let cell = cell as! UpdateCollectionViewCell
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            
            cell.tintColor = CSSTheme.blue
            cell.versionDescriptionTextView.maximumNumberOfLines = 3
            cell.versionDescriptionTextView.text = latestSupportedVersion.localizedDescription ?? "Không có mô tả chi tiết cho bản cập nhật này."
            
            if cell.bundleIdentifier != app.bundleIdentifier
            {
                cell.bundleIdentifier = app.bundleIdentifier
                cell.bannerView.iconImageView.image = nil
                cell.bannerView.iconImageView.isIndicatingActivity = true
            }
            
            cell.bannerView.button.isIndicatingActivity = false
            cell.bannerView.configure(for: app, action: .update)
            cell.bannerView.button.setTitle("CẬP NHẬT", for: .normal)
            
            var versionText = latestSupportedVersion.localizedVersion

            // Nếu là bản thân SideStore, lược bỏ số build để gọn gàng
            if app.bundleIdentifier == Bundle.Info.appbundleIdentifier,
               let version = SemanticVersion(latestSupportedVersion.version)
            {
                versionText = SemanticVersion(version.major, version.minor, version.patch, version.preRelease).description
            }
            
            cell.bannerView.subtitleLabel.text = String(format: "Phiên bản %@", versionText)

            let appName: String
            
            if ReleaseTrackType.betaTracks.contains(latestSupportedVersion.channel)
            {
                appName = String(format: "%@ (Thử nghiệm)", app.name)
            }
            else
            {
                appName = app.name
            }
            
            let versionDate = Date().relativeDateString(since: latestSupportedVersion.date)
            cell.bannerView.accessibilityLabel = String(format: "Bản cập nhật %@ %@. Phát hành vào %@.", appName, latestSupportedVersion.localizedVersion, versionDate)
            
            cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.updateApp(_:)), for: .primaryActionTriggered)
            cell.bannerView.button.accessibilityLabel = String(format: "Cập nhật %@", installedApp.name)
            
            if self.expandedAppUpdates.contains(app.bundleIdentifier)
            {
                cell.mode = .expanded
            }
            else
            {
                cell.mode = .collapsed
            }
            
            cell.versionDescriptionTextView.toggleButton.addTarget(self, action: #selector(MyAppsViewController.toggleUpdateCellMode(_:)), for: .primaryActionTriggered)

            self.styleAppCardCell(cell)
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
        }
        dataSource.prefetchHandler = { (installedApp, indexPath) in
            guard let iconURL = installedApp.storeApp?.iconURL else { return nil }
            return try await ImagePipeline.shared.image(for: iconURL)
        }
        dataSource.prefetchCompletionHandler = { [weak self] (cell, image, indexPath, error) in
            let cell = cell as! UpdateCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
            
            // Ép lại nền trắng sáng ngay sau khi gán ảnh icon để tránh AppBannerView tự đổi màu nền sang đen
            self?.styleAppCardCell(cell)
            
            if let error = error
            {
                debugLog("Error loading image: \(error)")
            }
        }
        
        return dataSource
    }
    
    func makeActiveAppsDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest = InstalledApp.activeAppsFetchRequest()
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(InstalledApp.storeApp)]
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.expirationDate, ascending: true),
                                        NSSortDescriptor(keyPath: \InstalledApp.refreshedDate, ascending: false),
                                        NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellIdentifierHandler = { _ in "AppCell" }
        dataSource.cellConfigurationHandler = { [weak self] (cell, installedApp, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! InstalledAppCollectionViewCell
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            cell.tintColor = CSSTheme.blue
            
            cell.deactivateBadge?.isHidden = false
            
            if let dropIndexPath = self.dropDestinationIndexPath, dropIndexPath.section == Section.activeApps.rawValue && dropIndexPath.item == indexPath.item
            {
                cell.bannerView.alpha = 0.4
                
                cell.deactivateBadge?.alpha = 1.0
                cell.deactivateBadge?.transform = .identity
            }
            else
            {
                cell.bannerView.alpha = 1.0
                
                cell.deactivateBadge?.alpha = 0.0
                cell.deactivateBadge?.transform = CGAffineTransform.identity.scaledBy(x: 0.33, y: 0.33)
            }
            
            cell.bannerView.button.configure(for: installedApp)
            let rawButtonTitle = cell.bannerView.button.title(for: .normal) ?? ""
            let translatedButtonTitle = self.translateDynamicAppText(rawButtonTitle)
            cell.bannerView.button.isIndicatingActivity = false
            cell.bannerView.configure(for: installedApp, action: .custom(translatedButtonTitle))
            
            if cell.bundleIdentifier != installedApp.bundleIdentifier
            {
                cell.bundleIdentifier = installedApp.bundleIdentifier
                cell.bannerView.iconImageView.image = nil
                cell.bannerView.iconImageView.isIndicatingActivity = true
            }
            
            let currentDate = Date()
            let isExpired = currentDate > installedApp.expirationDate
            cell.bannerView.buttonLabel.isHidden = isExpired || installedApp.certificateStatus == .revoked
            cell.bannerView.buttonLabel.text = "Hết hạn sau"
            
            cell.bannerView.button.removeTarget(self, action: nil, for: .primaryActionTriggered)
            cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.refreshApp(_:)), for: .primaryActionTriggered)
            
            cell.bannerView.button.accessibilityLabel = String(format: "Làm mới %@", installedApp.name)
            
            if let storeApp = installedApp.storeApp, storeApp.isPledgeRequired, !storeApp.isPledged
            {
                cell.bannerView.button.isEnabled = false
                cell.bannerView.button.alpha = 0.5
            }
            else
            {
                cell.bannerView.button.isEnabled = true
                cell.bannerView.button.alpha = 1.0
            }
            
            self.styleAppCardCell(cell)
            cell.layoutIfNeeded()
            
            if let progress = AppManager.shared.refreshProgress(for: installedApp), progress.fractionCompleted < 1.0
            {
                cell.bannerView.button.progress = progress
            }
            else
            {
                cell.bannerView.button.progress = nil
            }
        }
        dataSource.prefetchHandler = { (item, indexPath) in
            return try await item.loadIcon()
        }
        dataSource.prefetchCompletionHandler = { [weak self] (cell, image, indexPath, error) in
            let cell = cell as! InstalledAppCollectionViewCell
            cell.bannerView.iconImageView.image = image
            cell.bannerView.iconImageView.isIndicatingActivity = false
            
            // Khoá cứng nền trắng ngay khi tải xong Icon ứng dụng
            self?.styleAppCardCell(cell)
        }
        
        return dataSource
    }
    
    func makeInactiveAppsDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest = InstalledApp.fetchRequest() as NSFetchRequest<InstalledApp>
        fetchRequest.relationshipKeyPathsForPrefetching = [#keyPath(InstalledApp.storeApp)]
        fetchRequest.predicate = NSPredicate(format: "%K == NO", #keyPath(InstalledApp.isActive))
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.expirationDate, ascending: true),
                                        NSSortDescriptor(keyPath: \InstalledApp.refreshedDate, ascending: false),
                                        NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellIdentifierHandler = { _ in "AppCell" }
        dataSource.cellConfigurationHandler = { [weak self] (cell, installedApp, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! InstalledAppCollectionViewCell
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            cell.tintColor = CSSTheme.blue
            
            if cell.bundleIdentifier != installedApp.bundleIdentifier
            {
                cell.bundleIdentifier = installedApp.bundleIdentifier
                cell.bannerView.iconImageView.image = nil
                cell.bannerView.iconImageView.isIndicatingActivity = true
            }
            cell.bannerView.buttonLabel.isHidden = true
            cell.bannerView.alpha = 1.0
            
            cell.deactivateBadge?.isHidden = true
            cell.deactivateBadge?.alpha = 0.0
            cell.deactivateBadge?.transform = CGAffineTransform.identity.scaledBy(x: 0.5, y: 0.5)
            
            cell.bannerView.button.isIndicatingActivity = false
            cell.bannerView.configure(for: installedApp, action: .custom("KÍCH HOẠT"))
            
            cell.bannerView.button.tintColor = CSSTheme.blue
            cell.bannerView.button.removeTarget(self, action: nil, for: .primaryActionTriggered)
            cell.bannerView.button.addTarget(self, action: #selector(MyAppsViewController.activateApp(_:)), for: .primaryActionTriggered)
            cell.bannerView.button.accessibilityLabel = String(format: "Kích hoạt %@", installedApp.name)
            
            if let storeApp = installedApp.storeApp, storeApp.isPledgeRequired, !storeApp.isPledged
            {
                cell.bannerView.button.isEnabled = false
                cell.bannerView.button.alpha = 0.5
            }
            else
            {
                cell.bannerView.button.isEnabled = true
                cell.bannerView.button.alpha = 1.0
            }
            
            self.styleAppCardCell(cell)
            cell.layoutIfNeeded()
            
            cell.bannerView.button.progress = nil
            
            if let progress = AppManager.shared.refreshProgress(for: installedApp), progress.fractionCompleted < 1.0
            {
                cell.bannerView.button.progress = progress
            }
            else
            {
                cell.bannerView.button.progress = nil
            }
        }
        dataSource.prefetchHandler = { (item, indexPath) in
            return try await item.loadIcon()
        }
        dataSource.prefetchCompletionHandler = { [weak self] (cell, image, indexPath, error) in
            let cell = cell as! InstalledAppCollectionViewCell
            cell.bannerView.iconImageView.image = image
            cell.bannerView.iconImageView.isIndicatingActivity = false
            
            // Khoá cứng nền trắng ngay khi tải xong Icon ứng dụng
            self?.styleAppCardCell(cell)
        }
        
        return dataSource
    }
    
    func updateDataSource()
    {
        do
        {
            if self.updatesDataSource.fetchedResultsController.fetchedObjects == nil
            {
                try self.updatesDataSource.fetchedResultsController.performFetch()
            }
        }
        catch
        {
            debugLog("[SideStore] Failed to fetch updates: \(error)")
        }
    }
}

private extension MyAppsViewController
{
    func update()
    {
        self.updateUnsupportedUpdates()
        
        if self.updatesDataSource.itemCount > 0
        {
            self.navigationController?.tabBarItem.badgeValue = String(describing: self.updatesDataSource.itemCount)
            UIApplication.shared.applicationIconBadgeNumber = Int(self.updatesDataSource.itemCount)
        }
        else
        {
            self.navigationController?.tabBarItem.badgeValue = nil
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
    
    func updateUnsupportedUpdates()
    {
        let predicate = NSPredicate(format: "%K == YES AND %K != nil", #keyPath(InstalledApp.isActive), #keyPath(InstalledApp.storeApp))
        let activeSourceApps = InstalledApp.all(satisfying: predicate, in: DatabaseManager.shared.viewContext)
                    
        let unsupportedUpdates = activeSourceApps.compactMap { (installedApp) -> StoreApp? in
            guard let storeApp = installedApp.storeApp, let appVersion = storeApp.latestAvailableVersion, !appVersion.isSupported else { return nil }
            return storeApp
        }
        
        self.unsupportedUpdates = Set(unsupportedUpdates)
    }
    
    func fetchAppIDs()
    {
        AppManager.shared.syncAppIDs { (result) in
            do
            {
                try result.get()
            }
            catch
            {
                debugLog("Failed to fetch App IDs. \(error)")
            }
        }
    }
    
    @objc private func appIDsViewControllerDidDismiss(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.fetchAppIDs()
        }
    }
    
    func refresh(_ installedApps: [InstalledApp], completionHandler: @escaping ([String : Result<InstalledApp, Error>]) -> Void)
    {
        let group = AppManager.shared.refresh(installedApps, presentingViewController: self, group: self.isRefreshingAllApps ? self.refreshGroup : nil)
        group.completionHandler = { (results) in
            DispatchQueue.main.async {
                let failures = results.compactMapValues { (result) -> Error? in
                    switch result
                    {
                    case .failure(let error) where error is CancellationError: return nil
                    case .failure(let error): return error
                    case .success: return nil
                    }
                }
                
                guard !failures.isEmpty else { return }
                
                if let failure = failures.first, results.count == 1
                {
                    ToastView(error: failure.value).show(in: self)
                }
                else
                {
                    let localizedText: String
                    
                    if failures.count == 1
                    {
                        localizedText = "Không thể làm mới 1 ứng dụng."
                    }
                    else
                    {
                        localizedText = String(format: "Không thể làm mới %@ ứng dụng.", NSNumber(value: failures.count))
                    }
                    
                    let error = failures.first?.value as NSError?
                    let detailText = error?.localizedFailure ?? error?.localizedFailureReason ?? error?.localizedDescription
                    
                    let toastView = ToastView(text: localizedText, detailText: detailText, opensLog: true)
                    toastView.preferredDuration = 4.0
                    toastView.show(in: self)
                }
            }
            
            self.refreshGroup = nil
            completionHandler(results)
        }
        
        self.refreshGroup = group
        
        if self.isRefreshingAllApps
        {
            self.reconfigureVisibleCells()
        }
    }
}

private extension MyAppsViewController
{
    @IBAction func toggleAppUpdates(_ sender: UIButton)
    {
        let visibleCells = self.collectionView.visibleCells
        
        self.collectionView.performBatchUpdates({
            
            self.isUpdateSectionCollapsed.toggle()
            
            UIView.animate(withDuration: 0.3, animations: {
                if self.isUpdateSectionCollapsed
                {
                    self.updatesDataSource.liveFetchLimit = maximumCollapsedUpdatesCount
                    self.expandedAppUpdates.removeAll()
                    
                    for case let cell as UpdateCollectionViewCell in visibleCells
                    {
                        cell.mode = .collapsed
                    }
                    
                    self.cachedUpdateSizes.removeAll()
                    
                    sender.titleLabel?.transform = .identity
                }
                else
                {
                    self.updatesDataSource.liveFetchLimit = 0
                    
                    sender.titleLabel?.transform = CGAffineTransform.identity.rotated(by: .pi)
                }
            })
            
            self.collectionView.collectionViewLayout.invalidateLayout()
            
        }, completion: nil)
    }
    
    @IBAction func toggleUpdateCellMode(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let installedApp = self.dataSource.item(at: indexPath)
        
        let cell = self.collectionView.cellForItem(at: indexPath) as? UpdateCollectionViewCell
        
        if self.expandedAppUpdates.contains(installedApp.bundleIdentifier)
        {
            self.expandedAppUpdates.remove(installedApp.bundleIdentifier)
            cell?.mode = .collapsed
        }
        else
        {
            self.expandedAppUpdates.insert(installedApp.bundleIdentifier)
            cell?.mode = .expanded
        }
        
        self.cachedUpdateSizes[installedApp.bundleIdentifier] = nil
        
        UIView.animate(withDuration: 0.25) {
            self.collectionView.performBatchUpdates({
                self.collectionView.collectionViewLayout.invalidateLayout()
            }, completion: nil)
        }
    }
    
    @IBAction func refreshApp(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let installedApp = self.dataSource.item(at: indexPath)
        self.refresh(installedApp)
    }
    
    @IBAction func refreshAllApps(_ sender: UIBarButtonItem)
    {
        Task { @MainActor in
            let installedApps = InstalledApp.fetchAppsForRefreshingAll(in: DatabaseManager.shared.viewContext)
            guard !installedApps.isEmpty else {
                let error: Error
                
                if let altstoreApp = InstalledApp.fetchAltStore(in: DatabaseManager.shared.viewContext),
                   let storeApp = altstoreApp.storeApp, storeApp.isPledgeRequired && !storeApp.isPledged
                {
                    error = OperationError.pledgeInactive(appName: altstoreApp.name)
                }
                else
                {
                    error = OperationError.noInstalledApps
                }
                
                let toastView = ToastView(error: error)
                toastView.show(in: self)
                return
            }
            
            self.isRefreshingAllApps = true
            if let activeAppsHeader = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: Section.activeApps.rawValue)) as? InstalledAppsCollectionHeaderView {
                activeAppsHeader.button.isIndicatingActivity = true
                activeAppsHeader.button.accessibilityLabel = "Đang làm mới"
            }
            self.reconfigureVisibleCells()
            
            self.refresh(installedApps) { (result) in
                DispatchQueue.main.async {
                    self.isRefreshingAllApps = false
                    if let activeAppsHeader = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: Section.activeApps.rawValue)) as? InstalledAppsCollectionHeaderView {
                        activeAppsHeader.button.isIndicatingActivity = false
                        activeAppsHeader.button.accessibilityLabel = nil
                    }
                    self.reconfigureVisibleCells()
                }
            }
            
            #if !os(tvOS)
            let interaction = INInteraction.refreshAllApps()
            do {
                try await interaction.donate()
            } catch {
                debugLog("Donate intent failed \(interaction.intent). \(error)")
            }
            #endif
        }
    }
    
    @IBAction func updateApp(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let installedApp = self.dataSource.item(at: indexPath)
        
        let previousProgress = AppManager.shared.installationProgress(for: installedApp)
        guard previousProgress == nil else {
            previousProgress?.cancel()
            return
        }
        
        let progress = AppManager.shared.update(installedApp, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(let error) where error is CancellationError:
                    self.collectionView.reloadItems(at: [indexPath])
                    
                case .failure(let error):
                    ToastView(error: error, opensLog: true).show(in: self)
                    
                    self.collectionView.reloadItems(at: [indexPath])
                    
                case .success:
                    debugLog("Updated app: \(installedApp.bundleIdentifier)")
                }
                
                self.update()
            }
        }
        
        if let pillButton = sender as? PillButton
        {
            pillButton.progress = progress
        }
    }
    
    @IBAction func sideloadApp(_ sender: UIBarButtonItem)
    {
        InstallAppDialog.presentSourceSelection(
            from: self,
            barButtonItem: sender,
            onChooseFiles: { [weak self] in
                #if !os(tvOS)
                self?.presentDocumentPicker()
                #else
                self?.presentTVWebTransfer()
                #endif
            },
            onConfirm: { [weak self] url in
                self?.sideloadApp(at: url) { _ in }
            }
        )
    }
    
    #if !os(tvOS)
    private func presentDocumentPicker()
    {
        let supportedTypes = UTType.types(tag: "ipa", tagClass: .filenameExtension, conformingTo: nil)
        
        let documentPickerViewController = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes, asCopy: true)
        documentPickerViewController.delegate = self
        self.present(documentPickerViewController, animated: true, completion: nil)
    }
    #else
    private func presentTVWebTransfer()
    {
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["ipa"],
            title: "Cài đặt tệp IPA",
            presentingVC: self
        ) { [weak self] fileURL in
            guard let fileURL = fileURL, let self else { return }
            InstallAppDialog.present(ipaURL: fileURL, from: self) { [weak self] in
                self?.sideloadApp(at: fileURL) { result in
                    debugLog("Sideloaded app at \(fileURL) with result: \(result)")
                }
            }
        }
    }
    #endif
    
    func sideloadApp(at url: URL, completion: @escaping (Result<Void, Error>) -> Void)
    {
        self.pendingImportURL = nil
        self.setSideloadingActivity(true)
        
        let group = AppManager.shared.install(.url(url), presentingViewController: self) { [weak self] result in
            Task { @MainActor in
                self?.setSideloadingActivity(false)
                self?.sideloadingProgressView.observedProgress = nil
                self?.sideloadingProgressView.setHidden(true, animated: true)
                
                switch result {
                case .success(let installedApp):
                    completion(.success(()))
                    installedApp.managedObjectContext?.perform {
                        debugLog("Successfully installed app: \(installedApp.bundleIdentifier)")
                    }
                case .failure(let error):
                    if error is CancellationError {
                        completion(.failure(OperationError.cancelled))
                    } else {
                        if let self {
                            ToastView(error: error, opensLog: true).show(in: self)
                        }
                        completion(.failure(error))
                    }
                }
            }
        }
        
        self.sideloadingProgress = group.progress
        self.sideloadingProgressView.progress = 0
        self.sideloadingProgressView.isHidden = false
        self.sideloadingProgressView.observedProgress = group.progress
    }
    
    @IBAction func activateApp(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let installedApp = self.dataSource.item(at: indexPath)
        self.activate(installedApp)
    }
    
    @IBAction func deactivateApp(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let installedApp = self.dataSource.item(at: indexPath)
        self.deactivate(installedApp)
    }
    
    @objc func presentInactiveAppsAlert()
    {
        var message: String
        
        if UserDefaults.standard.activeAppLimitIncludesExtensions
        {
            message = "Tài khoản ID Apple miễn phí chỉ được phép kích hoạt tối đa 3 ứng dụng và tiện ích mở rộng (App Extensions) cùng lúc. Các ứng dụng không hoạt động sẽ không tính vào giới hạn này, nhưng bạn cần kích hoạt lại chúng khi muốn mở."
        }
        else
        {
            message = "Tài khoản ID Apple miễn phí chỉ được phép kích hoạt tối đa 3 ứng dụng cùng lúc. Các ứng dụng không hoạt động sẽ được tự động sao lưu dữ liệu và tạm gỡ khỏi màn hình chính để nhường chỗ, và sẽ được cài đặt lại nguyên vẹn dữ liệu khi bạn kích hoạt lại."
            
            if UserDefaults.standard.isAppLimitDisabled
            {
                message += "\n\n"
                message += "Nếu bạn đang bật tính năng mở khóa giới hạn 3 ứng dụng (MacDirtyCow / SparseRestore), bạn có thể kích hoạt tối đa lên đến 10 ứng dụng và tiện ích mở rộng."
            }
        }
                
        let alertController = UIAlertController(title: "Ứng dụng không hoạt động là gì?", message: message, preferredStyle: .alert)
        alertController.addAction(.ok)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func updateCell(at indexPath: IndexPath)
    {
        guard let cell = collectionView.cellForItem(at: indexPath) as? InstalledAppCollectionViewCell else { return }
        
        let installedApp = self.dataSource.item(at: indexPath)
        self.dataSource.cellConfigurationHandler(cell, installedApp, indexPath)
        
        cell.bannerView.iconImageView.isIndicatingActivity = false
        self.styleAppCardCell(cell)
    }
    
    func reconfigureVisibleCells()
    {
        for indexPath in self.collectionView.indexPathsForVisibleItems
        {
            guard let section = Section(rawValue: indexPath.section) else { continue }
            switch section
            {
            case .activeApps, .inactiveApps:
                self.updateCell(at: indexPath)
            default:
                break
            }
        }
    }
    
    @objc func showHiddenUpdatesAlert(_ sender: UIButton)
    {
        guard !self.unsupportedUpdates.isEmpty else { return }
        
        let sortedHiddenUpdates = self.unsupportedUpdates.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        
        let title = sortedHiddenUpdates.count == 1 ? "Có 1 bản cập nhật không tương thích" : String(format: "Có %@ bản cập nhật không tương thích", sortedHiddenUpdates.count as NSNumber)
        var message = String(format: "Các bản cập nhật dưới đây không hỗ trợ phiên bản iOS %@. Vui lòng cập nhật thiết bị lên phiên bản iOS phù hợp để cài đặt chúng.", ProcessInfo.processInfo.operatingSystemVersion.stringValue)
        message += "\n"
        
        for storeApp in sortedHiddenUpdates
        {
            var title = storeApp.name
            if let appVersion = storeApp.latestAvailableVersion
            {
                title += " " + appVersion.localizedVersion
                
                var osVersion: String? = nil
                if let minOSVersion = appVersion.minOSVersion, !ProcessInfo.processInfo.isOperatingSystemAtLeast(minOSVersion)
                {
                    osVersion = String(format: "Yêu cầu iOS %@ trở lên", minOSVersion.stringValue)
                }
                else if let maxOSVersion = appVersion.maxOSVersion, ProcessInfo.processInfo.operatingSystemVersion > maxOSVersion
                {
                    osVersion = String(format: "Yêu cầu iOS %@ trở xuống", maxOSVersion.stringValue)
                }
                
                if let osVersion
                {
                    title += " (" + osVersion + ")"
                }
            }
            
            message += "\n• " + title
        }
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(.ok)
        
        self.present(alertController, animated: true)
    }
}

private extension MyAppsViewController
{
    func open(_ installedApp: InstalledApp)
    {
        UIApplication.shared.open(installedApp.openAppURL) { success in
            guard !success else { return }
            
            ToastView(error: OperationError.openAppFailed(name: installedApp.name), opensLog: true).show(in: self)
        }
    }
    
    func refresh(_ installedApp: InstalledApp)
    {
        Task { @MainActor in
            let previousProgress = AppManager.shared.refreshProgress(for: installedApp)
            guard previousProgress == nil else { return }
            
            self.refresh([installedApp]) { (results) in
                if results.values.contains(where: { $0.error != nil })
                {
                    DispatchQueue.main.async {
                        self.reconfigureVisibleCells()
                    }
                }
                
                debugLog("Finished refreshing with results: \(results.map { ($0, $1.error?.localizedDescription ?? "success") })")
            }
        }
    }
    
    func resign(_ installedApp: InstalledApp, alternateIconMode: AlternateIconMode = .preserve)
    {
        Task { @MainActor in
            let previousProgress = AppManager.shared.refreshProgress(for: installedApp)
            guard previousProgress == nil else { return }
            
            AppManager.shared.resign(installedApp, alternateIconMode: alternateIconMode, presentingViewController: self) { (result) in
                switch result
                {
                case .failure(let error) where error is CancellationError:
                    debugLog("Resign app cancelled by user.")
                    DispatchQueue.main.async {
                        self.reconfigureVisibleCells()
                    }
                case .failure(let error):
                    debugLog("Failed to resign app: \(error)")
                    DispatchQueue.main.async {
                        ToastView(error: error, opensLog: true).show(in: self)
                        self.reconfigureVisibleCells()
                    }
                case .success(let app):
                    debugLog("Successfully resigned app: \(app.name)")
                }
            }
        }
    }
    
    func reinstallFromCache(_ installedApp: InstalledApp)
    {
        InstallAppDialog.present(installedApp: installedApp, from: self) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                let previousProgress = AppManager.shared.installationProgress(for: installedApp)
                guard previousProgress == nil else {
                    previousProgress?.cancel()
                    return
                }
                
                AppManager.shared.reinstall(installedApp, presentingViewController: self) { [weak self] (result) in
                    Task { @MainActor in
                        switch result
                        {
                        case .failure(let error) where error is CancellationError:
                            debugLog("Reinstall from cache cancelled.")
                            self?.reconfigureVisibleCells()
                        case .failure(let error):
                            debugLog("Failed to reinstall from cache: \(error)")
                            if let self {
                                ToastView(error: error, opensLog: true).show(in: self)
                            }
                            self?.reconfigureVisibleCells()
                        case .success(let app):
                            debugLog("Successfully reinstalled app from cache: \(app.name)")
                            self?.reconfigureVisibleCells()
                        }
                    }
                }
                self.reconfigureVisibleCells()
            }
        }
    }
    
    func reinstallFromSource(_ storeApp: StoreApp)
    {
        InstallAppDialog.present(storeApp: storeApp, from: self) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                let previousProgress = AppManager.shared.installationProgress(for: storeApp)
                guard previousProgress == nil else {
                    previousProgress?.cancel()
                    return
                }
                
                _ = AppManager.shared.install(.app(storeApp), presentingViewController: self) { [weak self] (result) in
                    Task { @MainActor in
                        switch result
                        {
                        case .failure(let error) where error is CancellationError:
                            debugLog("Reinstall from source cancelled.")
                            self?.reconfigureVisibleCells()
                        case .failure(let error):
                            debugLog("Failed to reinstall from source: \(error)")
                            if let self {
                                ToastView(error: error, opensLog: true).show(in: self)
                            }
                            self?.reconfigureVisibleCells()
                        case .success(let app):
                            debugLog("Successfully reinstalled app from source: \(app.name)")
                            self?.reconfigureVisibleCells()
                        }
                    }
                }
                self.reconfigureVisibleCells()
            }
        }
    }
    
    func activate(_ installedApp: InstalledApp)
    {
        Task { @MainActor in
            func finish(_ result: Result<InstalledApp, Error>)
            {
                do
                {
                    let app = try result.get()
                    app.managedObjectContext?.perform {
                        app.isActive = true
                        try? app.managedObjectContext?.save()
                    }
                }
                catch is CancellationError
                {
                    // Bỏ qua khi người dùng hủy
                }
                catch
                {
                    debugLog("Failed to activate app: \(error)")
                    
                    DispatchQueue.main.async {
                        ToastView(error: error, opensLog: true).show(in: self)
                    }
                }
            }
                    
            if !UserDefaults.standard.isAppLimitDisabled && UserDefaults.standard.activeAppsLimit != nil
            {
                self.promptToDeactivateApp(for: installedApp) { result in
                    installedApp.managedObjectContext?.perform {
                        switch result
                        {
                        case .failure(let error):
                            finish(.failure(error))
                            
                        case .success:
                            AppManager.shared.activate(installedApp, presentingViewController: self, completionHandler: finish(_:))
                        }
                    }
                }
            }
            else
            {
                AppManager.shared.activate(installedApp, presentingViewController: self, completionHandler: finish(_:))
            }
        }
    }

    private func promptToDeactivateApp(for installedApp: InstalledApp, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let deactivationCandidates = AppManager.shared.appsToDeactivate(for: installedApp) else {
            return completion(.success(()))
        }

        let title: String
        let message: String

        if UserDefaults.standard.activeAppLimitIncludesExtensions {
            if installedApp.appExtensions.isEmpty {
                title = "Không thể kích hoạt quá 3 ứng dụng"
                message = "Tài khoản ID Apple miễn phí bị giới hạn tối đa 3 ứng dụng và tiện ích mở rộng hoạt động cùng lúc. Vui lòng chọn một ứng dụng bên dưới để tạm ngưng kích hoạt."
            } else {
                title = "Vượt quá giới hạn 3 ứng dụng & tiện ích"
                let extCount = installedApp.appExtensions.count
                message = String(format: "Tài khoản ID Apple miễn phí chỉ cho phép tối đa 3 ứng dụng và tiện ích mở rộng hoạt động, trong khi \"%@\" bao gồm thêm %@ tiện ích mở rộng. Vui lòng chọn ứng dụng để tạm ngưng kích hoạt.", installedApp.name, NSNumber(value: extCount))
            }
        } else {
            title = "Không thể kích hoạt quá 3 ứng dụng"
            message = "Tài khoản ID Apple miễn phí bị giới hạn tối đa 3 ứng dụng hoạt động cùng lúc. Vui lòng chọn một ứng dụng bên dưới để tạm ngưng kích hoạt."
        }

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
            completion(.failure(OperationError.cancelled))
        })

        for activeApp in deactivationCandidates {
            alertController.addAction(UIAlertAction(title: activeApp.name, style: .default) { [weak self] _ in
                guard let self else { return }
                activeApp.isActive = false

                AppManager.shared.deactivate(activeApp, presentingViewController: self) { result in
                    switch result {
                    case .failure(let error):
                        activeApp.managedObjectContext?.perform {
                            activeApp.isActive = true
                            completion(.failure(error))
                        }
                    case .success:
                        self.promptToDeactivateApp(for: installedApp, completion: completion)
                    }
                }
            })
        }

        self.present(alertController, animated: true)
    }
    
    func deactivate(_ installedApp: InstalledApp, completionHandler: ((Result<InstalledApp, Error>) -> Void)? = nil)
    {
        guard installedApp.isActive else { return }
        
        Task { @MainActor in
            AppManager.shared.deactivate(installedApp, presentingViewController: self) { (result) in
                do
                {
                    let app = try result.get()
                    try? app.managedObjectContext?.save()
                    
                    debugLog("Finished deactivating app: \(app.bundleIdentifier)")
                }
                catch is CancellationError
                {
                    // Bỏ qua
                }
                catch
                {
                    debugLog("Failed to deactivate app: \(error)")
                    
                    DispatchQueue.main.async {
                        ToastView(error: error, opensLog: true).show(in: self)
                    }
                }
                
                completionHandler?(result)
            }
        }
    }
    
    func deleteApp(_ installedApp: InstalledApp, completionHandler: ((Result<InstalledApp, Error>) -> Void)? = nil)
    {
        guard installedApp.isActive else { return }
        
        let appName = installedApp.name
        let title = String(format: "Xóa ứng dụng “%@”?", appName)
        
        let message = String(format: "Thao tác này sẽ gỡ “%@” khỏi SideStore và xóa toàn bộ dữ liệu sao lưu của ứng dụng này.", appName)
        
        let contentVC = DeleteAppAlertViewController()
        
        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        alertController.setValue(contentVC, forKey: "contentViewController")
        
        let cancelAction = UIAlertAction(title: "Hủy", style: .cancel, handler: nil)
        
        let actionTitleForState: (Bool) -> String = { isChecked in
            isChecked ? "Xóa hoàn toàn" : "Gỡ khỏi danh sách"
        }
        
        let confirmAction = UIAlertAction(title: actionTitleForState(contentVC.isChecked), style: .destructive) { [weak self] _ in
            guard let self else { return }
            let deleteFromDevice = contentVC.isChecked
            
            Task { @MainActor in
                if deleteFromDevice {
                    AppManager.shared.deleteApp(installedApp, presentingViewController: self) { (result) in
                        do
                        {
                            let app = try result.get()
                            try? app.managedObjectContext?.save()
                            
                            debugLog("Finished deleting app: \(app.bundleIdentifier)")
                        }
                        catch is CancellationError
                        {
                            // Bỏ qua
                        }
                        catch
                        {
                            debugLog("Failed to delete app: \(error)")
                            
                            DispatchQueue.main.async {
                                ToastView(error: error, opensLog: true).show(in: self)
                            }
                        }
                        
                        completionHandler?(result)
                    }
                } else {
                    AppManager.shared.removeApp(installedApp, presentingViewController: self) { (result) in
                        switch result
                        {
                        case .success:
                            debugLog("Finished removing app: \(installedApp.bundleIdentifier)")
                            completionHandler?(.success(installedApp))
                        case .failure(let error):
                            debugLog("Failed to remove app: \(error)")
                            
                            DispatchQueue.main.async {
                                ToastView(error: error, opensLog: true).show(in: self)
                            }
                            completionHandler?(.failure(error))
                        }
                    }
                }
            }
        }
        
        contentVC.onToggle = { [weak confirmAction] isChecked in
            confirmAction?.setValue(actionTitleForState(isChecked), forKey: "title")
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(confirmAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func remove(_ installedApp: InstalledApp)
    {
        let title = String(format: "Gỡ “%@” khỏi SideStore?", installedApp.name)
        let message: String
        
        if UserDefaults.standard.isLegacyDeactivationSupported
        {
            message = "Bạn cũng cần xóa biểu tượng ứng dụng trên Màn hình chính để gỡ cài đặt hoàn toàn."
        }
        else
        {
            message = "Thao tác này cũng sẽ xóa toàn bộ dữ liệu sao lưu của ứng dụng này."
        }

        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Gỡ bỏ", style: .destructive, handler: { (action) in
            AppManager.shared.removeDeactivatedApp(installedApp) { (result) in
                switch result
                {
                case .success: break
                case .failure(let error):
                    DispatchQueue.main.async {
                        ToastView(error: error, opensLog: true).show(in: self)
                    }
                }
            }
        }))
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func backup(_ installedApp: InstalledApp)
    {
        debugLog("[UI] User clicked 'Back Up' for app: \(installedApp.bundleIdentifier)")
        Task { @MainActor in
            let title = "Bắt đầu sao lưu?"
            let message = "Thao tác này sẽ ghi đè lên bản sao lưu trước đó. Vui lòng giữ SideStore luôn mở cho đến khi quá trình sao lưu hoàn tất."

            let alertController = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel))
            
            let actionTitle = String(format: "Sao lưu %@", installedApp.name)
            alertController.addAction(UIAlertAction(title: actionTitle, style: .default, handler: { (action) in
                debugLog("[UI] User confirmed backup dialog for app: \(installedApp.bundleIdentifier). Triggering AppManager.shared.backup.")
                AppManager.shared.backup(installedApp, presentingViewController: self) { (result) in
                    do
                    {
                        let app = try result.get()
                        try? app.managedObjectContext?.save()
                        
                        debugLog("Finished backing up app: \(app.bundleIdentifier)")
                    }
                    catch
                    {
                        debugLog("Failed to back up app: \(error)")
                        
                        DispatchQueue.main.async {
                            ToastView(error: error, opensLog: true).show(in: self)

                            self.reconfigureVisibleCells()
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.reconfigureVisibleCells()
                }
            }))
            
            if let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            }
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func importBackup(for installedApp: InstalledApp, isZip: Bool = false){
        ImportExport.importBackup(presentingViewController: self, for: installedApp, isZip: isZip) { result in
            var toast: ToastView
            switch(result){
            case .failure(let error):
                toast = ToastView(error: error, opensLog: false)
                break
            case .success:
                toast = ToastView(text: "Đã nhập bản sao lưu cho \(installedApp.name)",
                                  detailText: "Sử dụng tùy chọn 'Khôi phục bản sao lưu' để nạp dữ liệu vừa nhập vào ứng dụng.")
            }
            DispatchQueue.main.async {
                toast.show(in: self)
            }
        }
    }
    
    private func getPreviousBackupURL(_ installedApp: InstalledApp) -> URL
    {
        let backupURL = FileManager.default.backupDirectoryURL(for: installedApp)!
        let backupBakURL = ImportExport.getPreviousBackupURL(backupURL)
        return backupBakURL
    }
    
    func restorePreviousBackup(for installedApp: InstalledApp){
        let backupURL = FileManager.default.backupDirectoryURL(for: installedApp)!
        let backupBakURL = ImportExport.getPreviousBackupURL(backupURL)
        
        if(FileManager.default.fileExists(atPath: backupURL.path)){
            try! FileManager.default.removeItem(at: backupURL)
        }
        
        try! FileManager.default.copyItem(at: backupBakURL, to: backupURL)
        
        restore(installedApp)
    }
    
    func restore(_ installedApp: InstalledApp)
    {
        Task { @MainActor in
            let message = String(format: "Thao tác này sẽ thay thế toàn bộ dữ liệu hiện tại trong ứng dụng %@.", installedApp.name)
            let alertController = UIAlertController(title: "Bạn có chắc chắn muốn khôi phục bản sao lưu này không?", message: message, preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel))
            alertController.addAction(UIAlertAction(title: "Khôi phục bản sao lưu", style: .destructive, handler: { (action) in
                AppManager.shared.restore(installedApp, presentingViewController: self) { (result) in
                    do
                    {
                        let app = try result.get()
                        try? app.managedObjectContext?.save()
                        
                        debugLog("Finished restoring app: \(app.bundleIdentifier)")
                    }
                    catch
                    {
                        debugLog("Failed to restore app: \(error)")
                        
                        DispatchQueue.main.async {
                            ToastView(error: error, opensLog: true).show(in: self)
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.collectionView.reloadSections([Section.activeApps.rawValue])
                }
            }))
            
            if let popoverController = alertController.popoverPresentationController {
                popoverController.sourceView = self.view
                popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            }
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    func exportBackup(for installedApp: InstalledApp, asZip: Bool = false)
    {
        guard let backupURL = FileManager.default.backupDirectoryURL(for: installedApp) else { return }
        
        #if !os(tvOS)
        let exportURL: URL
        if asZip {
            let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(installedApp.name) Backup.zip")
            do {
                try FileManager.default.zipDirectory(at: backupURL, to: zipURL)
                exportURL = zipURL
            } catch {
                ToastView(error: error, opensLog: true).show(in: self)
                return
            }
        } else {
            exportURL = backupURL
        }
        
        let documentPicker = UIDocumentPickerViewController(forExporting: [exportURL], asCopy: true)
        self.present(documentPicker, animated: true, completion: nil)
        #else
        TVWebFileTransferManager.shared.startExport(fileURL: backupURL, title: "Xuất bản sao lưu ứng dụng", presentingVC: self)
        #endif
    }
    
    func deleteBackup(for installedApp: InstalledApp)
    {
        let alertController = UIAlertController(
            title: String(format: "Xóa bản sao lưu của “%@”?", installedApp.name),
            message: "Bạn có chắc chắn muốn xóa bản sao lưu của ứng dụng này không? Hành động này không thể hoàn tác.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alertController.addAction(UIAlertAction(title: "Xóa bản sao lưu", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            do
            {
                try FileManager.default.deleteBackup(for: installedApp)
                self.collectionView.reloadData()
            }
            catch
            {
                debugLog("Failed to delete backup for \(installedApp.bundleIdentifier): \(error)")
                ToastView(error: error, opensLog: true).show(in: self)
            }
        })
        self.present(alertController, animated: true)
    }
    
    func showAppInfo(_ installedApp: InstalledApp)
    {
        let appInfoView = AppInfoView(installedApp: installedApp)
        let hostingController = UIHostingController(rootView: appInfoView)
        self.present(hostingController, animated: true, completion: nil)
    }
    
    func chooseIcon(for installedApp: InstalledApp)
    {
        #if !os(tvOS)
        self._imagePickerInstalledApp = installedApp
        
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = true
        self.present(imagePicker, animated: true, completion: nil)
        #else
        TVWebFileTransferManager.shared.startImport(
            acceptedExtensions: ["png", "jpg", "jpeg"],
            title: "Tải lên biểu tượng ứng dụng tùy chỉnh",
            presentingVC: self
        ) { [weak self] fileURL in
            guard let self = self, let fileURL = fileURL else { return }
            if let data = try? Data(contentsOf: fileURL), let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.changeIcon(for: installedApp, to: image)
                }
            }
        }
        #endif
    }
    
    func changeIcon(for installedApp: InstalledApp, to image: UIImage?)
    {
        self.activeAppsDataSource.prefetchItemCache.removeObject(forKey: installedApp)
        self.inactiveAppsDataSource.prefetchItemCache.removeObject(forKey: installedApp)
        
        if let image = image
        {
            guard let icon = image.resizing(toFill: CGSize(width: 256, height: 256)),
                  let iconData = icon.pngData()
            else { return }
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Staged_\(installedApp.bundleIdentifier)_Icon.png")
            do
            {
                try iconData.write(to: tempURL, options: .atomic)
                self.resign(installedApp, alternateIconMode: .set(tempURL))
            }
            catch
            {
                debugLog("Failed to write temporary icon file: \(error)")
                ToastView(error: error, opensLog: true).show(in: self)
                return
            }
        }
        else
        {
            self.resign(installedApp, alternateIconMode: .remove)
        }
    }
    
    func enableJIT(for installedApp: InstalledApp) {
        AppManager.shared.enableJIT(for: installedApp) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    break
                case .failure(let error):
                    ToastView(error: error, opensLog: true).show(in: self)
                    AppManager.shared.log(error, operation: .enableJIT, app: installedApp)
                }
            }
        }
    }
}

private extension MyAppsViewController
{
    @objc func didFetchSource(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.update()
        }
    }
    
    @objc func importApp(_ notification: Notification)
    {
        self.loadViewIfNeeded()
        
        guard let url = notification.userInfo?[AppDelegate.importAppDeepLinkURLKey] as? URL else { return }
        
        guard self.view.window != nil && self._viewDidAppear else {
            self.pendingImportURL = url
            return
        }
        
        self.presentImportDialog(for: url)
    }

    private func presentImportDialog(for url: URL)
    {
        InstallAppDialog.present(
            ipaURL: url,
            from: self,
            onConfirm: { [weak self] in
                self?.sideloadApp(at: url) { _ in }
            },
            onCancel: {}
        )
    }
    
    #if !os(tvOS)
    @objc func checkForUpdates(_ sender: UIRefreshControl)
    {
        self.performCheckForUpdates {
            sender.endRefreshing()
        }
    }
    #else
    @objc func checkForUpdates()
    {
        self.performCheckForUpdates(completion: nil)
    }
    #endif
    
    private func performCheckForUpdates(completion: (() -> Void)? = nil)
    {
        guard !self.isCheckingForUpdates else { return }
        self.isCheckingForUpdates = true
        
        Task.detached {
            do
            {
                async let result = try await AppManager.shared.fetchSources()
                                
                for await _ in NotificationCenter.default.notifications(named: AppManager.didFetchSourceNotification).map({ $0.name })
                {
                    break
                }
                
                do
                {
                    do
                    {
                        let (_, context) = try await result
                        
                        try await context.performAsync {
                            try context.save()
                        }
                    }
                    catch let error as AppManager.FetchSourcesError
                    {
                        debugLog("\(error)")
                        try await error.managedObjectContext?.performAsync {
                            try error.managedObjectContext?.save()
                        }
                        
                        throw error
                    }
                }
                catch let mergeError as MergeError
                {
                    guard let sourceID = mergeError.sourceID else { throw mergeError }
                    
                    let sanitizedError = (mergeError as NSError).sanitizedForSerialization()
                    await DatabaseManager.shared.persistentContainer.performBackgroundTask { context in
                        do
                        {
                            guard let source = Source.first(satisfying: NSPredicate(format: "%K == %@", #keyPath(Source.identifier), sourceID), in: context) else { return }
                            
                            source.error = sanitizedError
                            try context.save()
                        }
                        catch
                        {
                            debugLog("[SideStore] Failed to assign error \(sanitizedError.localizedErrorCode) to source \(sourceID). \(error)")
                        }
                    }
                    
                    throw mergeError
                }
            }
            catch let error as NSError
            {
                debugLog("\(error)")
                await MainActor.run {
                    let toastView = ToastView(error: error.withLocalizedTitle("Không thể kiểm tra cập nhật"))
                    toastView.addTarget(nil, action: #selector(TabBarController.presentSources), for: .touchUpInside)
                    toastView.show(in: self)
                }
            }
            
            await MainActor.run {
                self.isCheckingForUpdates = false
                self.update()
                completion?()
            }
        }
    }
    
    @objc func didChangeAppIcon(_ notification: Notification)
    {
        guard let altStoreApp = InstalledApp.fetchAltStore(in: DatabaseManager.shared.viewContext) else { return }
        
        self.activeAppsDataSource.prefetchItemCache.removeObject(forKey: altStoreApp)
        self.inactiveAppsDataSource.prefetchItemCache.removeObject(forKey: altStoreApp)
        
        if let indexPath = self.activeAppsDataSource.fetchedResultsController.indexPath(forObject: altStoreApp)
        {
            let indexPath = IndexPath(item: indexPath.item, section: Section.activeApps.rawValue)
            
            self.collectionView.reconfigureItems(at: [indexPath])
        }
        
        if let indexPath = self.inactiveAppsDataSource.fetchedResultsController.indexPath(forObject: altStoreApp)
        {
            let indexPath = IndexPath(item: indexPath.item, section: Section.inactiveApps.rawValue)
            
            self.collectionView.reconfigureItems(at: [indexPath])
        }
    }
}

extension MyAppsViewController
{
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        // Đảm bảo mỗi khi cell hiển thị trên màn hình (kể cả khi cuộn nhanh hoặc tái sử dụng), nền luôn được khóa trắng sáng
        self.styleAppCardCell(cell)
    }

    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let section = Section(rawValue: indexPath.section)!
        
        switch section
        {
        case .noUpdates: return UICollectionReusableView()
        case .updates:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "UpdatesHeader", for: indexPath) as! UpdatesCollectionHeaderView
            
            UIView.performWithoutAnimation {
                headerView.overrideUserInterfaceStyle = .light
                headerView.button.backgroundColor = CSSTheme.blue.withAlphaComponent(0.15)
                headerView.button.setTitle("▾", for: .normal)
                headerView.button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 28)
                headerView.button.setTitleColor(CSSTheme.blue, for: .normal)
                headerView.button.addTarget(self, action: #selector(MyAppsViewController.toggleAppUpdates), for: .primaryActionTriggered)
                
                if self.isUpdateSectionCollapsed
                {
                    headerView.button.titleLabel?.transform = .identity
                }
                else
                {
                    headerView.button.titleLabel?.transform = CGAffineTransform.identity.rotated(by: .pi)
                }
                
                headerView.isHidden = (self.updatesDataSource.fetchedResultsController.fetchedObjects?.count ?? 0 <= maximumCollapsedUpdatesCount)
                
                headerView.button.layoutIfNeeded()
            }
            
            return headerView
            
        case .activeApps where kind == UICollectionView.elementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "ActiveAppsHeader", for: indexPath) as! InstalledAppsCollectionHeaderView
            
            UIView.performWithoutAnimation {
                headerView.layoutMargins.left = self.view.layoutMargins.left
                headerView.layoutMargins.right = self.view.layoutMargins.right
                
                if UserDefaults.standard.activeAppsLimit == nil || UserDefaults.standard.isAppLimitDisabled
                {
                    headerView.textLabel.text = "ĐÃ CÀI ĐẶT"
                }
                else
                {
                    headerView.textLabel.text = "ĐANG HOẠT ĐỘNG"
                }
                
                self.styleSectionHeader(headerView)
                
                headerView.button.isIndicatingActivity = false
                headerView.button.activityIndicatorView.color = CSSTheme.blue
                headerView.button.setTitle("  Làm mới tất cả  ", for: .normal)
                headerView.button.setTitleColor(CSSTheme.blue, for: .normal)
                headerView.button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
                headerView.button.backgroundColor = CSSTheme.white.withAlphaComponent(0.92)
                headerView.button.layer.cornerRadius = 12
                headerView.button.layer.borderWidth = 1.0
                headerView.button.layer.borderColor = CSSTheme.blue.withAlphaComponent(0.28).cgColor
                headerView.button.addTarget(self, action: #selector(MyAppsViewController.refreshAllApps(_:)), for: .primaryActionTriggered)
                
                headerView.button.layoutIfNeeded()
                
                if self.isRefreshingAllApps
                {
                    headerView.button.isIndicatingActivity = true
                    headerView.button.accessibilityLabel = "Đang làm mới"
                    headerView.button.accessibilityTraits.remove(.notEnabled)
                }
                else
                {
                    headerView.button.isIndicatingActivity = false
                    headerView.button.accessibilityLabel = nil
                }
            }
            
            return headerView
            
        case .inactiveApps where kind == UICollectionView.elementKindSectionHeader:
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "InactiveAppsHeader", for: indexPath) as! InstalledAppsCollectionHeaderView
            
            UIView.performWithoutAnimation {
                headerView.layoutMargins.left = self.view.layoutMargins.left
                headerView.layoutMargins.right = self.view.layoutMargins.right
                
                headerView.textLabel.text = "KHÔNG HOẠT ĐỘNG"
                self.styleSectionHeader(headerView)
                
                headerView.button.setTitle(nil, for: .normal)
                headerView.button.setImage(UIImage(systemName: "questionmark.circle.fill"), for: .normal)
                headerView.button.tintColor = CSSTheme.purple
                headerView.button.backgroundColor = .clear
                headerView.button.layer.borderWidth = 0
                headerView.button.addTarget(self, action: #selector(MyAppsViewController.presentInactiveAppsAlert), for: .primaryActionTriggered)
                
                headerView.isHidden = (self.inactiveAppsDataSource.itemCount == 0)
            }
            
            return headerView
            
        case .activeApps, .inactiveApps:
            let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "InstalledAppsFooter", for: indexPath) as! InstalledAppsCollectionFooterView
            
            footerView.overrideUserInterfaceStyle = .light
            footerView.textLabel.textColor = CSSTheme.purple
            footerView.textLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
            footerView.button?.tintColor = CSSTheme.blue
            
            guard let team = self.activeTeam else { return footerView }
            switch team.type
            {
            case .free:
                guard let managedTeam = Team.first(satisfying: NSPredicate(format: "%K == %@", #keyPath(Team.identifier), team.identifier), in: DatabaseManager.shared.viewContext) else { return footerView }
                let registeredAppIDs = managedTeam.appIDs.count
                
                let maximumAppIDCount = 10
                let remainingAppIDs = maximumAppIDCount - registeredAppIDs
                
                footerView.textLabel.text = String(format: "Còn lại %@ App ID khả dụng", NSNumber(value: remainingAppIDs))
                footerView.textLabel.isHidden = remainingAppIDs < 0
                
            case .individual, .organization, .unknown: footerView.textLabel.isHidden = true
            @unknown default: break
            }
            
            return footerView
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    cell.transform = .identity
                }
            }
        }
        
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .updates:
            guard let cell = collectionView.cellForItem(at: indexPath) else { break }
            self.performSegue(withIdentifier: "showUpdate", sender: cell)
            
        default: break
        }
    }
}

extension MyAppsViewController
{
    private func contextMenu(for installedApp: InstalledApp) -> UIMenu
    {
        var actions = [UIMenuElement]()
        
        let openAction = UIAction(title: "Mở ứng dụng", image: UIImage(systemName: "arrow.up.forward.app")) { (action) in
            self.open(installedApp)
        }
        
        let openMenu = UIMenu(title: "", options: .displayInline, children: [openAction])
        
        let refreshAction = UIAction(title: "Làm mới (Gia hạn)", image: UIImage(systemName: "arrow.clockwise")) { (action) in
            self.refresh(installedApp)
        }
        
        let resignAction = UIAction(title: "Ký lại chứng chỉ", image: UIImage(systemName: "signature")) { (action) in
            self.resign(installedApp)
        }
        
        let reinstallFromCacheAction = UIAction(title: "Từ bộ nhớ đệm (Cache)", image: UIImage(systemName: "signature")) { (action) in
            self.reinstallFromCache(installedApp)
        }
        
        var reinstallSubmenuActions: [UIMenuElement] = [reinstallFromCacheAction]
        if let storeApp = installedApp.storeApp
        {
            let reinstallFromSourceAction = UIAction(title: "Tải lại từ Nguồn", image: UIImage(systemName: "icloud.and.arrow.down")) { [weak self] (action) in
                self?.reinstallFromSource(storeApp)
            }
            reinstallSubmenuActions.append(reinstallFromSourceAction)
        }
        let reinstallMenu = UIMenu(title: "Cài đặt lại", image: UIImage(systemName: "arrow.triangle.2.circlepath"), children: reinstallSubmenuActions)
        
        let activateAction = UIAction(title: "Kích hoạt", image: UIImage(systemName: "checkmark.circle")) { (action) in
            self.activate(installedApp)
        }
        
        let deactivateAction = UIAction(title: "Hủy kích hoạt", image: UIImage(systemName: "xmark.circle"), attributes: .destructive) { (action) in
            self.deactivate(installedApp)
        }
        
        let deleteAppAction = UIAction(title: "Xóa ứng dụng", image: UIImage(systemName: "trash"), attributes: .destructive) { (action) in
            self.deleteApp(installedApp)
        }
        
        let removeAction = UIAction(title: "Gỡ khỏi danh sách", image: UIImage(systemName: "trash"), attributes: .destructive) { (action) in
            self.remove(installedApp)
        }
        
        let jitAction = UIAction(title: "Bật tăng tốc JIT", image: UIImage(systemName: "bolt")) { (action) in
            self.enableJIT(for: installedApp)
        }
        
        let backupAction = UIAction(title: "Tạo bản sao lưu", image: UIImage(systemName: "doc.on.doc")) { (action) in
            self.backup(installedApp)
        }
        
        let exportRawBackupAction = UIAction(title: "Xuất thư mục gốc (Raw)", image: UIImage(systemName: "folder")) { (action) in
            self.exportBackup(for: installedApp, asZip: false)
        }
        
        let exportZipBackupAction = UIAction(title: "Xuất tệp nén (ZIP)", image: UIImage(systemName: "doc.zipper") ?? UIImage(systemName: "archivebox")) { (action) in
            self.exportBackup(for: installedApp, asZip: true)
        }
        
        let exportBackupMenu = UIMenu(title: "Xuất bản sao lưu", image: UIImage(systemName: "arrow.up.doc"), children: [exportRawBackupAction, exportZipBackupAction])
        
        let importRawBackupAction = UIAction(title: "Nhập thư mục gốc (Raw)", image: UIImage(systemName: "folder")) { (action) in
            self.importBackup(for: installedApp, isZip: false)
        }
        
        let importZipBackupAction = UIAction(title: "Nhập tệp nén (ZIP)", image: UIImage(systemName: "doc.zipper") ?? UIImage(systemName: "archivebox")) { (action) in
            self.importBackup(for: installedApp, isZip: true)
        }
        
        let importBackupMenu = UIMenu(title: "Nhập bản sao lưu", image: UIImage(systemName: "arrow.down.doc"), children: [importRawBackupAction, importZipBackupAction])
        
        let restoreBackupAction = UIAction(title: "Khôi phục bản sao lưu", image: UIImage(systemName: "arrow.down.doc")) { (action) in
            self.restore(installedApp)
        }

        let restorePreviousBackupAction = UIAction(title: "Khôi phục bản sao lưu liền trước", image: UIImage(systemName: "arrow.down.doc")) { (action) in
            self.restorePreviousBackup(for: installedApp)
        }
        
        let deleteBackupAction = UIAction(title: "Xóa bản sao lưu", image: UIImage(systemName: "trash"), attributes: .destructive) { (action) in
            self.deleteBackup(for: installedApp)
        }
        
        let chooseIconAction = UIAction(title: "Chọn từ Thư viện ảnh", image: UIImage(systemName: "photo")) { (action) in
            self.chooseIcon(for: installedApp)
        }
        
        let removeIconAction = UIAction(title: "Khôi phục biểu tượng gốc", image: UIImage(systemName: "trash"), attributes: [.destructive]) { (action) in
            self.changeIcon(for: installedApp, to: nil)
        }
        
        let infoAction = UIAction(title: "Thông tin chi tiết", image: UIImage(systemName: "info.circle")) { [weak self] (action) in
            self?.showAppInfo(installedApp)
        }
        
        var changeIconActions = [chooseIconAction]
        if installedApp.hasAlternateIcon
        {
            changeIconActions.append(removeIconAction)
        }
        
        let changeIconMenu = UIMenu(title: "Đổi biểu tượng (Icon)", image: UIImage(systemName: "photo"), children: changeIconActions)
        
        var backupSubmenuActions = [UIMenuElement]()
        
        if installedApp.isActive
        {
            backupSubmenuActions.append(backupAction)
        }
        else if UTType(installedApp.installedAppUTI) != nil, !UserDefaults.standard.isLegacyDeactivationSupported
        {
            backupSubmenuActions.append(backupAction)
        }
                
        if let backupDirectoryURL = FileManager.default.backupDirectoryURL(for: installedApp)
        {
            var backupExists = false
            var outError: NSError? = nil
            
            self.coordinator.coordinate(readingItemAt: backupDirectoryURL, options: [.withoutChanges], error: &outError) { (backupDirectoryURL) in

                #if DEBUG && targetEnvironment(simulator)
                backupExists = true
                #else
                backupExists = FileManager.default.fileExists(atPath: backupDirectoryURL.path)
                #endif
            }
            
            if backupExists
            {
                backupSubmenuActions.append(exportBackupMenu)
                
                if installedApp.isActive
                {
                    backupSubmenuActions.append(restoreBackupAction)
                }
                
                backupSubmenuActions.append(deleteBackupAction)
            }
            else if let error = outError
            {
                debugLog("Unable to check if backup exists: \(error)")
            }
        }
        
        if installedApp.isActive
        {
            backupSubmenuActions.append(importBackupMenu)
        }
        
        if FileManager.default.fileExists(atPath: getPreviousBackupURL(installedApp).path){
            backupSubmenuActions.append(restorePreviousBackupAction)
        }
        
        let backupMenu = UIMenu(title: "Sao lưu & Khôi phục", image: UIImage(systemName: "archivebox"), children: backupSubmenuActions)
        
        let setProfileAction = UIAction(title: "Đổi hồ sơ cấu hình (Profile)", image: UIImage(systemName: "doc.badge.gearshape")) { [weak self] _ in
            self?.presentSetProfileAlert(for: installedApp)
        }
        
        let resetProfileAction = UIAction(title: "Đặt lại hồ sơ mặc định", image: UIImage(systemName: "arrow.counterclockwise")) { [weak self] _ in
            self?.resetProfile(for: installedApp)
        }
        
        var profileSubmenuActions: [UIMenuElement] = [setProfileAction]
        if ProfileManager.shared.getAssignedProfile(for: installedApp.bundleIdentifier) != nil || installedApp.certificateSerialNumber != nil {
            profileSubmenuActions.append(resetProfileAction)
        }
        let profileMenu = UIMenu(title: "Hồ sơ cấu hình (Profile)", image: UIImage(systemName: "doc.plaintext"), children: profileSubmenuActions)
        
        if installedApp.resignedBundleIdentifier.isAltStoreAppID
        {
            actions = [refreshAction, resignAction, reinstallMenu, profileMenu, changeIconMenu]
        }
        else
        {
            if installedApp.isActive
            {
                actions.append(openMenu)
                actions.append(refreshAction)
                actions.append(resignAction)
                actions.append(reinstallMenu)
                actions.append(profileMenu)
            }
            else
            {
                actions.append(activateAction)
                actions.append(resignAction)
                actions.append(reinstallMenu)
                actions.append(profileMenu)
            }
            
            if installedApp.isActive
            {
                actions.append(jitAction)
            }
            
            actions.append(changeIconMenu)
            
            if !backupSubmenuActions.isEmpty
            {
                actions.append(backupMenu)
            }
            
            if installedApp.isActive
            {
                if installedApp.bundleIdentifier != StoreApp.altstoreAppID
                {
                    actions.append(deactivateAction)
                    actions.append(deleteAppAction)
                }
            }
            
            #if DEBUG && targetEnvironment(simulator)
            if installedApp.bundleIdentifier != StoreApp.altstoreAppID
            {
                actions.append(removeAction)
            }
            #else
            
            if (UserDefaults.standard.legacySideloadedApps ?? []).contains(installedApp.bundleIdentifier)
            {
                actions.append(removeAction)
            }
            else if !UserDefaults.standard.isLegacyDeactivationSupported && !installedApp.isActive
            {
                actions.append(removeAction)
            }
            
            #endif
        }
        
        actions.append(infoAction)
        
        let orderedActions = [
            openMenu,
            refreshAction,
            resignAction,
            reinstallMenu,
            profileMenu,
            activateAction,
            jitAction,
            changeIconMenu,
            backupMenu,
            infoAction,
            deactivateAction,
            deleteAppAction,
            removeAction,
        ]
        
        actions = orderedActions.filter{ action in actions.contains(action)}
        
        var title: String?
                
        if let storeApp = installedApp.storeApp, storeApp.isPledgeRequired, !storeApp.isPledged
        {
            let error = OperationError.pledgeInactive(appName: installedApp.name)
            title = error.localizedDescription
            
            let allowedActions: Set<UIMenuElement> = [
                openMenu,
                deactivateAction,
                removeAction,
                backupMenu,
                infoAction
            ]
            
            for action in actions where !allowedActions.contains(action)
            {
                if let action = action as? UIAction
                {
                    action.attributes = .disabled
                }
                else if let menu = action as? UIMenu
                {
                    for case let action as UIAction in menu.children
                    {
                        action.attributes = .disabled
                    }
                }
            }
        }
        
        let menu = UIMenu(title: title ?? "", children: actions)
        return menu
    }
    
    #if !os(tvOS)
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        guard !self.isRefreshingAllApps else { return nil }
        
        let section = Section(rawValue: indexPath.section)!
        switch section
        {
        case .updates, .noUpdates: return nil
        case .activeApps, .inactiveApps:
            let installedApp = self.dataSource.item(at: indexPath)
            guard !AppManager.shared.isActivelyManagingApp(withBundleID: installedApp.bundleIdentifier) else { return nil }
            
            return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: nil) { (suggestedActions) -> UIMenu? in
                let menu = self.contextMenu(for: installedApp)
                return menu
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    {
        guard let indexPath = configuration.identifier as? NSIndexPath else { return nil }
        guard let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? InstalledAppCollectionViewCell else { return nil }
        
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: cell.bannerView.bounds, cornerRadius: cell.bannerView.layer.cornerRadius)
        
        let preview = UITargetedPreview(view: cell.bannerView, parameters: parameters)
        return preview
    }
    
    override func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    {
        return self.collectionView(collectionView, previewForHighlightingContextMenuWithConfiguration: configuration)
    }
    #endif
}

extension MyAppsViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .noUpdates:
            return .zero
            
        case .updates:
            let item = self.dataSource.item(at: indexPath)
            
            if let previousHeight = self.cachedUpdateSizes[item.bundleIdentifier]
            {
                return previousHeight
            }
            
            self.prototypeUpdateCell.frame.size.width = collectionView.bounds.width
            
            self.dataSource.cellConfigurationHandler(self.prototypeUpdateCell, item, indexPath)
            
            let size = self.prototypeUpdateCell.systemLayoutSizeFitting(CGSize(width: collectionView.frame.width, height: UIView.layoutFittingCompressedSize.height),
                                                                        withHorizontalFittingPriority: .required,
                                                                        verticalFittingPriority: .fittingSizeLevel)
            
            self.cachedUpdateSizes[item.bundleIdentifier] = size
            return size
            
        case .activeApps, .inactiveApps:
            return CGSize(width: collectionView.bounds.width, height: 88)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        let section = Section.allCases[section]
        switch section
        {
        case .noUpdates: return .zero
        case .updates:
            let height: CGFloat = (self.updatesDataSource.fetchedResultsController.fetchedObjects?.count ?? 0 > maximumCollapsedUpdatesCount) ? 28 : 0
            return CGSize(width: collectionView.bounds.width, height: height)
            
        case .activeApps: return CGSize(width: collectionView.bounds.width, height: 34)
        case .inactiveApps where self.inactiveAppsDataSource.itemCount == 0: return .zero
        case .inactiveApps: return CGSize(width: collectionView.bounds.width, height: 34)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        let section = Section.allCases[section]
        
        func appIDsFooterSize() -> CGSize
        {
            guard let _ = self.activeTeam else { return .zero }
            return CGSize(width: collectionView.bounds.width, height: 60.5)
        }
        
        switch section
        {
        case .noUpdates: return .zero
        case .updates: return .zero
            
        case .activeApps where self.inactiveAppsDataSource.itemCount == 0: return appIDsFooterSize()
        case .activeApps: return .zero
            
        case .inactiveApps where self.inactiveAppsDataSource.itemCount == 0: return .zero
        case .inactiveApps: return appIDsFooterSize()
        }
    }
    
    func collectionView(_ myCV: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        let section = Section.allCases[section]
        switch section
        {
        case .noUpdates: return .zero
        case .updates where self.updatesDataSource.itemCount == 0: return .zero
        default: return UIEdgeInsets(top: 12, left: 0, bottom: 20, right: 0)
        }
    }
}

#if !os(tvOS)
extension MyAppsViewController: UICollectionViewDragDelegate
{
    func collectionView(_ collectionView: UICollectionView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem]
    {
        return []
    }
    
    func collectionView(_ collectionView: UICollectionView, dragPreviewParametersForItemAt indexPath: IndexPath) -> UIDragPreviewParameters?
    {
        guard let cell = collectionView.cellForItem(at: indexPath as IndexPath) as? InstalledAppCollectionViewCell else { return nil }
        
        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: cell.bannerView.frame, cornerRadius: cell.bannerView.layer.cornerRadius)
        
        return parameters
    }
    
    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession)
    {
        let previousDestinationIndexPath = self.dropDestinationIndexPath
        self.dropDestinationIndexPath = nil
        
        if let indexPath = previousDestinationIndexPath
        {
            self.updateCell(at: indexPath)
        }
    }
}

extension MyAppsViewController: UICollectionViewDropDelegate
{
    func collectionView(_ collectionView: UICollectionView, canHandle session: UIDropSession) -> Bool
    {
        return session.localDragSession != nil
    }
    
    func collectionView(_ collectionView: UICollectionView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UICollectionViewDropProposal
    {
        guard
            !UserDefaults.standard.isAppLimitDisabled,
            let activeAppsLimit = UserDefaults.standard.activeAppsLimit,
            let installedApp = session.items.first?.localObject as? InstalledApp
        else { return UICollectionViewDropProposal(operation: .cancel) }
        
        guard
            let activeAppsHeaderAttributes = collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: Section.activeApps.rawValue)),
            let inactiveAppsHeaderAttributes = collectionView.layoutAttributesForSupplementaryElement(ofKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: Section.inactiveApps.rawValue))
        else { return UICollectionViewDropProposal(operation: .cancel) }
        
        var dropDestinationIndexPath: IndexPath? = nil
        
        defer
        {
            if dropDestinationIndexPath != self.dropDestinationIndexPath
            {
                let previousIndexPath = self.dropDestinationIndexPath
                self.dropDestinationIndexPath = dropDestinationIndexPath
                
                let indexPaths = [previousIndexPath, dropDestinationIndexPath].compactMap { $0 }
                
                let propertyAnimator = UIViewPropertyAnimator(springTimingParameters: UISpringTimingParameters()) {
                    for indexPath in indexPaths
                    {
                        self.updateCell(at: indexPath)
                    }
                }
                propertyAnimator.startAnimation()
            }
        }
        
        let point = session.location(in: collectionView)
        
        if installedApp.isActive
        {
            if point.y > inactiveAppsHeaderAttributes.frame.minY
            {
                return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
            }
            else if point.y > activeAppsHeaderAttributes.frame.minY
            {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
            else
            {
                return UICollectionViewDropProposal(operation: .cancel)
            }
        }
        else
        {
            guard point.y > activeAppsHeaderAttributes.frame.minY else {
                return UICollectionViewDropProposal(operation: .cancel)
            }
            
            guard point.y < inactiveAppsHeaderAttributes.frame.minY else {
                return UICollectionViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
            }
            
            let activeAppsCount = (self.activeAppsDataSource.fetchedResultsController.fetchedObjects ?? []).map { $0.requiredActiveSlots }.reduce(0, +)
            let availableActiveApps = max(activeAppsLimit - activeAppsCount, 0)
            
            if installedApp.requiredActiveSlots <= availableActiveApps
            {
                return UICollectionViewDropProposal(operation: .copy, intent: .insertAtDestinationIndexPath)
            }
            else
            {
                guard let indexPath = collectionView.indexPathForItem(at: point), indexPath.section == Section.activeApps.rawValue else {
                    return UICollectionViewDropProposal(operation: .cancel)
                }
                
                let installedApp = self.dataSource.item(at: indexPath)
                guard installedApp.bundleIdentifier != StoreApp.altstoreAppID else {
                    return UICollectionViewDropProposal(operation: .forbidden, intent: .insertIntoDestinationIndexPath)
                }
                
                dropDestinationIndexPath = indexPath
                return UICollectionViewDropProposal(operation: .move, intent: .insertIntoDestinationIndexPath)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator)
    {
        guard let installedApp = coordinator.session.items.first?.localObject as? InstalledApp else { return }
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }
        
        if installedApp.isActive
        {
            guard destinationIndexPath.section == Section.inactiveApps.rawValue else { return }
            self.deactivate(installedApp)
        }
        else
        {
            guard destinationIndexPath.section == Section.activeApps.rawValue else { return }
            
            switch coordinator.proposal.intent
            {
            case .insertIntoDestinationIndexPath:
                installedApp.isActive = true
                
                let previousInstalledApp = self.dataSource.item(at: destinationIndexPath)
                self.deactivate(previousInstalledApp) { (result) in
                    installedApp.managedObjectContext?.perform {
                        switch result
                        {
                        case .failure: installedApp.isActive = false
                        case .success: self.activate(installedApp)
                        }
                    }
                }
                
            case .insertAtDestinationIndexPath:
                self.activate(installedApp)
                
            case .unspecified: break
            @unknown default: break
            }
        }
    }
}
#endif

extension MyAppsViewController: NSFetchedResultsControllerDelegate
{
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        guard let dataSource = self.dataSource(for: controller) else { return }
        
        if self.collectionView.window != nil
        {
            switch dataSource
            {
            case self.activeAppsDataSource: self.didChangeActiveApps = false
            case self.updatesDataSource where !_viewDidAppear:
                self.collectionView.performBatchUpdates(nil, completion: nil)
                
            default: break
            }
        }
        
        dataSource.controllerWillChangeContent(controller)
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType)
    {
        guard let dataSource = self.dataSource(for: controller) else { return }
        
        dataSource.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?)
    {
        guard let dataSource = self.dataSource(for: controller) else { return }
        
        switch dataSource
        {
        case self.activeAppsDataSource where type == .insert || type == .delete:
            self.didChangeActiveApps = true
            
        default: break
        }
        
        dataSource.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>)
    {
        guard let dataSource = self.dataSource(for: controller) else { return }
        
        if self.collectionView.window != nil
        {
            switch dataSource
            {
            case self.activeAppsDataSource, self.inactiveAppsDataSource:
                DispatchQueue.main.async {
                    let inactiveAppsCount = self.inactiveAppsDataSource.itemCount
                    if (inactiveAppsCount == 0) != (self.previousInactiveAppsCount == 0)
                    {
                        self.previousInactiveAppsCount = inactiveAppsCount
                        if let headerView = self.collectionView.supplementaryView(forElementKind: UICollectionView.elementKindSectionHeader, at: IndexPath(item: 0, section: Section.inactiveApps.rawValue)) {
                            headerView.isHidden = (inactiveAppsCount == 0)
                        }
                        self.collectionView.collectionViewLayout.invalidateLayout()
                    }
                    else
                    {
                        self.previousInactiveAppsCount = inactiveAppsCount
                    }
                    
                    if dataSource == self.activeAppsDataSource && self.didChangeActiveApps {
                        self.update()
                    }
                }
                
            case self.updatesDataSource:
                let previousUpdateCount = self.collectionView.numberOfItems(inSection: Section.updates.rawValue)
                let updateCount = Int(self.updatesDataSource.itemCount)
                
                if previousUpdateCount > 0 && updateCount == 0
                {
                    self.updateUnsupportedUpdates()
                }
            
            default: break
            }
        }
        
        dataSource.controllerDidChangeContent(controller)
    }
    
    private func dataSource(for controller: NSFetchedResultsController<NSFetchRequestResult>) -> FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>?
    {
        switch controller
        {
        case self.updatesDataSource.fetchedResultsController: return self.updatesDataSource
        case self.activeAppsDataSource.fetchedResultsController: return self.activeAppsDataSource
        case self.inactiveAppsDataSource.fetchedResultsController: return self.inactiveAppsDataSource
        default: return nil
        }
    }
}

#if !os(tvOS)
extension MyAppsViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let fileURL = urls.first else { return }
        
        InstallAppDialog.present(ipaURL: fileURL, from: self) { [weak self] in
            self?.sideloadApp(at: fileURL) { (result) in
                debugLog("Sideloaded app at \(fileURL) with result: \(result)")
            }
        }
    }
}
#endif

extension MyAppsViewController: UIViewControllerPreviewingDelegate
{
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard
            let indexPath = self.collectionView.indexPathForItem(at: location),
            let cell = self.collectionView.cellForItem(at: indexPath)
        else { return nil }
        
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .updates:
            previewingContext.sourceRect = cell.frame
            
            let app = self.dataSource.item(at: indexPath)
            guard let storeApp = app.storeApp else { return nil}
            
            let appViewController = AppViewController.makeAppViewController(app: storeApp)
            return appViewController
            
        default: return nil
        }
    }
    
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        let point = CGPoint(x: previewingContext.sourceRect.midX, y: previewingContext.sourceRect.midY)
        guard let indexPath = self.collectionView.indexPathForItem(at: point), let cell = self.collectionView.cellForItem(at: indexPath) else { return }
        
        self.performSegue(withIdentifier: "showUpdate", sender: cell)
    }
}

#if !os(tvOS)
extension MyAppsViewController: UIImagePickerControllerDelegate
{
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any])
    {
        defer {
            picker.dismiss(animated: true, completion: nil)
            self._imagePickerInstalledApp = nil
        }
        
        guard let image = info[.editedImage] as? UIImage, let installedApp = self._imagePickerInstalledApp else { return }
        self.changeIcon(for: installedApp, to: image)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        picker.dismiss(animated: true, completion: nil)
        self._imagePickerInstalledApp = nil
    }
}
#endif

extension MyAppsViewController {
    private func presentSetProfileAlert(for installedApp: InstalledApp) {
        let picker = SelectProfileViewController(installedApp: installedApp)
        picker.onSelectProfile = { [weak self] profile in
            self?.setProfile(profile, for: installedApp)
        }
        picker.present(from: self)
    }

    private func setProfile(_ profile: ALTProvisioningProfile, for installedApp: InstalledApp) {
        ProfileManager.shared.setAssignedProfile(profile, for: installedApp.bundleIdentifier)
        let matchingCert = ProfileManager.shared.getMatchingCertificate(for: profile)
        let context = DatabaseManager.shared.viewContext
        context.performAndWait {
            installedApp.certificateSerialNumber = matchingCert?.serialNumber
            try? context.save()
        }
        self.resign(installedApp)
    }

    private func resetProfile(for installedApp: InstalledApp) {
        ProfileManager.shared.setAssignedProfile(nil, for: installedApp.bundleIdentifier)
        let context = DatabaseManager.shared.viewContext
        context.performAndWait {
            installedApp.certificateSerialNumber = nil
            try? context.save()
        }
        self.resign(installedApp)
    }
}
