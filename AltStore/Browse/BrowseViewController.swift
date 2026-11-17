

//
//  BrowseViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import Combine
import CoreData
import AltStoreCore
@preconcurrency import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI SETTINGS)
private struct BrowseCSSTheme {
    static let white = UIColor.white
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0) // #f8f9fa
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0) // #e9ecef
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0) // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0) // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0) // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0) // #dc3545
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0) // #343a40
    
    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor
    
    // Hero Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.92).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.88).cgColor
    
    static let cornerRadius: CGFloat = 15.0
}

// MARK: - 📦 DANH SÁCH KHO NGUỒN UY TÍN LỚN ĐƯỢC TÍCH HỢP SẴN
private struct TrustedRepoItem {
    let name: String
    let subtitle: String
    let urlString: String
}

private let kTrustedRepos: [TrustedRepoItem] = [
    TrustedRepoItem(
        name: "🌟 Kho Sii Store (Chọn Lọc)",
        subtitle: "Kho ứng dụng tuyển chọn ổn định từ GitHub",
        urlString: "https://raw.githubusercontent.com/Nguyenhuyhoan/Sii/main/khoapp.json"
    ),
    TrustedRepoItem(
        name: "🔥 Kho WuXu Library++ (Cực Lớn)",
        subtitle: "YouTube, Spotify, TikTok, Locket, Tiện ích Mod...",
        urlString: "https://wuxu1.github.io/wuxu-complete-plus.json"
    ),
    TrustedRepoItem(
        name: "💎 Kho Cypwn IPA Library",
        subtitle: "Hàng trăm Game & Ứng dụng Tweaked cao cấp",
        urlString: "https://ipa.cypwn.xyz/cypwn.json"
    ),
    TrustedRepoItem(
        name: "🚀 Kho SideStore Community",
        subtitle: "Công cụ hệ thống, giả lập & ứng dụng chuẩn",
        urlString: "https://community-apps.sidestore.io/sidecommunity.json"
    ),
    TrustedRepoItem(
        name: "🎮 Kho AltStore Official",
        subtitle: "Delta Emulator, Clip & các ứng dụng gốc",
        urlString: "https://cdn.altstore.io/file/altstore/apps.json"
    )
]

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG KHI CUỘN HOẶC XOAY MÀN HÌNH)
private final class BrowseCSSGradientBackgroundView: UIView {
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
        gradientLayer.colors = [BrowseCSSTheme.bgGradientStart, BrowseCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

class BrowseViewController: UICollectionViewController
{
    let source: Source?
    
    // Bộ lọc nguồn linh hoạt ngay trên trang Kho App (nil == Tất cả nguồn)
    private var selectedSourceFilter: Source? {
        didSet {
            self.cachedItemSizes.removeAll()
            self.updateDataSource()
            self.update()
        }
    }
    
    private(set) var category: StoreCategory? {
        didSet {
            self.cachedItemSizes.removeAll()
            self.updateDataSource()
            self.update()
            self.updateQuickCategoryPillsSelection()
        }
    }
    
    var searchPredicate: NSPredicate? {
        didSet {
            self.updateDataSource()
        }
    }
    
    private lazy var dataSource = self.makeDataSource()
    private lazy var placeholderView = PlaceholderView(frame: .zero)
    
    private let prototypeCell = AppCardCollectionViewCell(frame: .zero)
    private var sortButton: UIBarButtonItem?
    
    private var preferredAppSorting: AppSorting = UserDefaults.standard.preferredAppSorting
    
    private var cancellables = Set<AnyCancellable>()
    private var searchDebounceWorkItem: DispatchWorkItem?
    
    private var titleStackView: UIStackView!
    private var titleSourceIconView: AppIconImageView!
    private var titleCategoryIconView: UIImageView!
    private var titleLabel: UILabel!
    
    // MARK: - Thành phần Giao diện Hero Banner & Điều hướng nổi
    private var heroContainerView: UIView?
    private var heroCardView: UIView?
    private var heroGradientLayer: CAGradientLayer?
    private var heroTitleButton: UIButton?
    private var heroSubtitleLabel: UILabel?
    private var heroSortPopupButton: UIButton?
    private var heroManageSourcesButton: UIButton?
    private var heroSearchBar: UISearchBar?
    private var categoryScrollView: UIScrollView?
    private var categoryPillsStack: UIStackView?
    private var floatingBackButton: UIButton?
    private let heroHeaderHeight: CGFloat = 196.0
    
    private var animatedIndexPaths = Set<IndexPath>()
    private static var didAutoBootstrapTrustedSources = false
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif
    
    init?(source: Source?, coder: NSCoder)
    {
        self.source = source
        self.category = nil
        
        super.init(coder: coder)
    }
    
    init?(category: StoreCategory?, coder: NSCoder)
    {
        self.source = nil
        self.category = category
        
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder)
    {
        self.source = nil
        self.category = nil
        
        super.init(coder: coder)
    }
    
    private var cachedItemSizes = [String: CGSize]()
    
    @IBOutlet private var sourcesBarButtonItem: UIBarButtonItem!
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.navigationController?.tabBarItem.title = "Apps"
        self.tabBarItem.title = "Apps"
        
        self.title = nil
        self.navigationItem.title = nil
        self.navigationController?.delegate = self
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationController?.interactivePopGestureRecognizer?.delegate = self
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        #endif
        
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.keyboardDismissMode = .onDrag
        
        self.dataSource.searchableKeyPaths = [#keyPath(StoreApp.name),
                                               #keyPath(StoreApp.subtitle),
                                               #keyPath(StoreApp.developerName),
                                               #keyPath(StoreApp.bundleIdentifier)]
        
        self.prototypeCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.register(AppCardCollectionViewCell.self, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        
        let collectionViewLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        collectionViewLayout.minimumLineSpacing = 20
        collectionViewLayout.sectionInset = UIEdgeInsets(top: self.heroHeaderHeight + 14, left: 0, bottom: 45, right: 0)
        
        #if !os(tvOS)
        self.registerForPreviewing(with: self, sourceView: self.collectionView)
        
        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.updateSources()
        })
        refreshControl.tintColor = BrowseCSSTheme.purple
        refreshControl.layer.zPosition = 200
        self.collectionView.refreshControl = refreshControl
        #endif
        
        self.titleSourceIconView = AppIconImageView(style: .circular)
        
        self.titleCategoryIconView = UIImageView(frame: .zero)
        self.titleCategoryIconView.contentMode = .scaleAspectFit
        
        self.titleLabel = UILabel()
        self.titleLabel.font = UIFont.systemFont(ofSize: 21, weight: .heavy)
        self.titleLabel.textColor = BrowseCSSTheme.white
        self.titleLabel.layer.shadowColor = UIColor.black.cgColor
        self.titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        self.titleLabel.layer.shadowRadius = 4
        self.titleLabel.layer.shadowOpacity = 0.35
        
        self.titleStackView = UIStackView(arrangedSubviews: [self.titleSourceIconView, self.titleCategoryIconView, self.titleLabel])
        self.titleStackView.spacing = 8
        self.titleStackView.alignment = .center
        self.titleStackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            self.titleSourceIconView.heightAnchor.constraint(equalToConstant: 24),
            self.titleSourceIconView.widthAnchor.constraint(equalTo: self.titleSourceIconView.heightAnchor),
            self.titleCategoryIconView.heightAnchor.constraint(equalToConstant: 22),
            self.titleCategoryIconView.widthAnchor.constraint(equalToConstant: 22)
        ])
        
        self.applySmartWebCSSTheme()
        
        self.prepareAppSorting()
        self.preparePipeline()
        
        self.updateDataSource()
        self.update()
        
        self.bootstrapDefaultTrustedSourcesIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let heroContainer = self.heroContainerView {
            let targetFrame = CGRect(x: 0, y: 0, width: self.collectionView.bounds.width, height: self.heroHeaderHeight)
            if heroContainer.frame != targetFrame {
                heroContainer.frame = targetFrame
                heroContainer.layoutIfNeeded()
            }
            heroContainer.layer.zPosition = 100
            self.collectionView.bringSubviewToFront(heroContainer)
        }
        if let heroCard = self.heroCardView {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
        
        self.placeholderView.layoutMargins = UIEdgeInsets(top: self.heroHeaderHeight + 24, left: 24, bottom: 24, right: 24)
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.cachedItemSizes.removeAll()
        coordinator.animate(alongsideTransition: { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        })
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        if let nav = self.navigationController {
            let isRoot = (self === nav.viewControllers.first)
            self.updateFloatingBackButton(in: nav, show: !isRoot)
        }
        self.update()
    }
    
    override func viewDidDisappear(_ animated: Bool) 
    {
        super.viewDidDisappear(animated)
        self.navigationController?.navigationBar.tintColor = nil
    }
}

// MARK: - 🧭 QUẢN LÝ ẨN THANH ĐIỀU HƯỚNG & NÚT QUAY LẠI NHỎ CỐ ĐỊNH Ở MỤC CON
extension BrowseViewController: UINavigationControllerDelegate, UIGestureRecognizerDelegate {
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
            btn.tintColor = BrowseCSSTheme.blue
            btn.backgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.92)
            
            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = BrowseCSSTheme.border.cgColor
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

// MARK: - ✨ HỆ THỐNG RENDER CSS THÔNG MINH, QUẢN LÝ NGUỒN UY TÍN & BỘ LỌC NHANH
private extension BrowseViewController {
    
    var activeSourceFilter: Source? {
        return self.source ?? self.selectedSourceFilter
    }
    
    func applySmartWebCSSTheme() {
        let bgView = BrowseCSSGradientBackgroundView(frame: UIScreen.main.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.collectionView.backgroundView = bgView
        self.collectionView.backgroundColor = .clear
        
        setupCSSHeroBanner()
        
        let placeholderBg = BrowseCSSGradientBackgroundView(frame: UIScreen.main.bounds)
        placeholderBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.placeholderView.insertSubview(placeholderBg, at: 0)
        self.placeholderView.backgroundColor = .clear
        self.placeholderView.textLabel.textColor = BrowseCSSTheme.blue
        self.placeholderView.textLabel.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        self.placeholderView.detailTextLabel.textColor = BrowseCSSTheme.dark.withAlphaComponent(0.78)
        self.placeholderView.detailTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        self.placeholderView.activityIndicatorView.color = BrowseCSSTheme.purple
        
        #if !os(tvOS)
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = BrowseCSSTheme.blue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif
    }
    
    func setupCSSHeroBanner() {
        self.heroContainerView?.removeFromSuperview()
        
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.collectionView.bounds.width, height: self.heroHeaderHeight))
        headerContainer.backgroundColor = .clear
        headerContainer.layer.zPosition = 100
        
        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = BrowseCSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = BrowseCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.25
        
        let gradient = CAGradientLayer()
        gradient.colors = [BrowseCSSTheme.heroStart, BrowseCSSTheme.heroEnd]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = BrowseCSSTheme.cornerRadius
        heroCard.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient
        self.heroCardView = heroCard
        
        let titleOverlayButton = UIButton(type: .system)
        titleOverlayButton.translatesAutoresizingMaskIntoConstraints = false
        titleOverlayButton.backgroundColor = .clear
        titleOverlayButton.addTarget(self, action: #selector(presentTrustedSourcesSheet), for: .touchUpInside)
        self.heroTitleButton = titleOverlayButton
        
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Kho ứng dụng chọn lọc • Bấm + Nguồn để nạp thêm kho lớn"
        subLabel.font = UIFont.systemFont(ofSize: 12.0, weight: .medium)
        subLabel.textColor = BrowseCSSTheme.white.withAlphaComponent(0.92)
        subLabel.numberOfLines = 1
        self.heroSubtitleLabel = subLabel
        
        let sourceBtn = UIButton(type: .system)
        sourceBtn.translatesAutoresizingMaskIntoConstraints = false
        self.heroManageSourcesButton = sourceBtn
        styleManageSourcesButton()
        sourceBtn.addTarget(self, action: #selector(presentTrustedSourcesSheet), for: .touchUpInside)
        
        let sortBtn = UIButton(type: .system)
        sortBtn.translatesAutoresizingMaskIntoConstraints = false
        self.heroSortPopupButton = sortBtn
        styleSortPopupButton()
        
        let topButtonsStack = UIStackView(arrangedSubviews: [sourceBtn, sortBtn])
        topButtonsStack.translatesAutoresizingMaskIntoConstraints = false
        topButtonsStack.spacing = 6
        topButtonsStack.alignment = .center
        
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Tìm nhanh tên app, công cụ, game..."
        searchBar.delegate = self
        searchBar.tintColor = BrowseCSSTheme.purple
        #if !os(tvOS)
        let textField = searchBar.searchTextField
        textField.backgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.95)
        textField.textColor = BrowseCSSTheme.dark
        textField.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
        textField.layer.cornerRadius = 10
        textField.layer.masksToBounds = true
        textField.leftView?.tintColor = BrowseCSSTheme.blue
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        textField.attributedPlaceholder = NSAttributedString(
            string: "Tìm nhanh tên app, công cụ, game...",
            attributes: [.foregroundColor: BrowseCSSTheme.dark.withAlphaComponent(0.5)]
        )
        #endif
        self.heroSearchBar = searchBar
        
        let catScroll = UIScrollView()
        catScroll.translatesAutoresizingMaskIntoConstraints = false
        catScroll.showsHorizontalScrollIndicator = false
        catScroll.showsVerticalScrollIndicator = false
        
        let catStack = UIStackView()
        catStack.translatesAutoresizingMaskIntoConstraints = false
        catStack.axis = .horizontal
        catStack.spacing = 8
        catStack.alignment = .center
        catScroll.addSubview(catStack)
        self.categoryScrollView = catScroll
        self.categoryPillsStack = catStack
        
        heroCard.addSubview(self.titleStackView)
        heroCard.addSubview(titleOverlayButton)
        heroCard.addSubview(subLabel)
        heroCard.addSubview(topButtonsStack)
        heroCard.addSubview(searchBar)
        heroCard.addSubview(catScroll)
        headerContainer.addSubview(heroCard)
        self.collectionView.addSubview(headerContainer)
        self.heroContainerView = headerContainer
        
        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 14),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -14),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4),
            
            self.titleStackView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            self.titleStackView.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 12),
            self.titleStackView.trailingAnchor.constraint(lessThanOrEqualTo: topButtonsStack.leadingAnchor, constant: -6),
            
            titleOverlayButton.leadingAnchor.constraint(equalTo: self.titleStackView.leadingAnchor),
            titleOverlayButton.trailingAnchor.constraint(equalTo: self.titleStackView.trailingAnchor),
            titleOverlayButton.topAnchor.constraint(equalTo: self.titleStackView.topAnchor),
            titleOverlayButton.bottomAnchor.constraint(equalTo: self.titleStackView.bottomAnchor),
            
            topButtonsStack.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            topButtonsStack.centerYAnchor.constraint(equalTo: self.titleStackView.centerYAnchor),
            
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            subLabel.topAnchor.constraint(equalTo: self.titleStackView.bottomAnchor, constant: 3),
            
            searchBar.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 6),
            searchBar.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -6),
            searchBar.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 2),
            searchBar.heightAnchor.constraint(equalToConstant: 40),
            
            catScroll.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            catScroll.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            catScroll.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 2),
            catScroll.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -8),
            catScroll.heightAnchor.constraint(equalToConstant: 30),
            
            catStack.leadingAnchor.constraint(equalTo: catScroll.contentLayoutGuide.leadingAnchor),
            catStack.trailingAnchor.constraint(equalTo: catScroll.contentLayoutGuide.trailingAnchor),
            catStack.topAnchor.constraint(equalTo: catScroll.contentLayoutGuide.topAnchor),
            catStack.bottomAnchor.constraint(equalTo: catScroll.contentLayoutGuide.bottomAnchor),
            catStack.heightAnchor.constraint(equalTo: catScroll.frameLayoutGuide.heightAnchor)
        ])
        
        buildQuickCategoryPills()
        
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.45, delay: 0.03, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
    }
    
    func buildQuickCategoryPills() {
        guard let stack = self.categoryPillsStack else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let items: [(title: String, category: StoreCategory?)] = [
            ("✨ Tất cả", nil),
            ("🛠 Tiện ích", .utilities),
            ("💬 Mạng xã hội", .social),
            ("🎬 Giải trí", .entertainment),
            ("🎮 Trò chơi", .games),
            ("🕹 Giả lập", .emulators),
            ("📸 Ảnh & Video", .photoAndVideo),
            ("📦 Khác", .other)
        ]
        
        for (index, item) in items.enumerated() {
            let pill = UIButton(type: .system)
            pill.tag = index
            pill.setTitle(item.title, for: .normal)
            pill.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            pill.layer.cornerRadius = 13
            pill.contentEdgeInsets = UIEdgeInsets(top: 5, left: 11, bottom: 5, right: 11)
            pill.addAction(UIAction { [weak self] _ in
                guard let self else { return }
                #if !os(tvOS)
                UISelectionFeedbackGenerator().selectionChanged()
                #endif
                if item.category == nil {
                    self.selectedSourceFilter = nil
                }
                self.category = item.category
            }, for: .touchUpInside)
            stack.addArrangedSubview(pill)
        }
        
        updateQuickCategoryPillsSelection()
    }
    
    func updateQuickCategoryPillsSelection() {
        guard let stack = self.categoryPillsStack else { return }
        let categories: [StoreCategory?] = [nil, .utilities, .social, .entertainment, .games, .emulators, .photoAndVideo, .other]
        
        for (idx, view) in stack.arrangedSubviews.enumerated() {
            guard let btn = view as? UIButton, idx < categories.count else { continue }
            let isSelected = (categories[idx] == self.category)
            UIView.animate(withDuration: 0.2) {
                if isSelected {
                    btn.backgroundColor = BrowseCSSTheme.white
                    btn.setTitleColor(BrowseCSSTheme.purple, for: .normal)
                    btn.layer.borderWidth = 0
                } else {
                    btn.backgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.18)
                    btn.setTitleColor(BrowseCSSTheme.white, for: .normal)
                    btn.layer.borderWidth = 1.0
                    btn.layer.borderColor = BrowseCSSTheme.white.withAlphaComponent(0.35).cgColor
                }
            }
        }
    }
    
    func styleManageSourcesButton() {
        guard let btn = self.heroManageSourcesButton else { return }
        if #available(iOS 15.0, tvOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = BrowseCSSTheme.green
            config.baseForegroundColor = BrowseCSSTheme.white
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            
            var attrTitle = AttributedString("+ Nguồn")
            attrTitle.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            config.attributedTitle = attrTitle
            btn.configuration = config
        } else {
            btn.backgroundColor = BrowseCSSTheme.green
            btn.setTitle("+ Nguồn", for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            btn.layer.cornerRadius = 14
            btn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        }
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 4
        btn.layer.shadowOpacity = 0.2
    }
    
    // MARK: - 🚀 TRUNG TÂM QUẢN LÝ NGUỒN, LỌC THEO NGUỒN & CÀI TRỰC TIẾP IPA TỪ URL (DÙNG CHUẨN API COREDATA CỦA SIDESTORE)
    func fetchInstalledSources() -> [Source] {
        let request = Source.fetchRequest() as NSFetchRequest<Source>
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Source.name, ascending: true)]
        return (try? DatabaseManager.shared.viewContext.fetch(request)) ?? []
    }
    
    func addSourceDirectly(url: URL, completion: (@Sendable (Result<Source, Error>) -> Void)? = nil) {
        AppManager.shared.fetchSource(sourceURL: url) { result in
            switch result {
            case .failure(let error):
                completion?(.failure(error))
            case .success(let source):
                guard let context = source.managedObjectContext else { return }
                context.perform {
                    do {
                        try context.save()
                        completion?(.success(source))
                    } catch {
                        completion?(.failure(error))
                    }
                }
            }
        }
    }
    
    func removeSourceDirectly(_ source: Source, completion: (@Sendable () -> Void)? = nil) {
        DatabaseManager.shared.persistentContainer.performBackgroundTask { context in
            let objectID = source.objectID
            if let bgSource = try? context.existingObject(with: objectID) {
                context.delete(bgSource)
                try? context.save()
            }
            completion?()
        }
    }
    
    func bootstrapDefaultTrustedSourcesIfNeeded() {
        guard !Self.didAutoBootstrapTrustedSources else { return }
        Self.didAutoBootstrapTrustedSources = true
        
        let countRequest = StoreApp.fetchRequest() as NSFetchRequest<StoreApp>
        let currentCount = (try? DatabaseManager.shared.viewContext.count(for: countRequest)) ?? 0
        guard currentCount == 0 else { return }
        
        let starterURLs = [
            "https://raw.githubusercontent.com/Nguyenhuyhoan/Sii/main/khoapp.json",
            "https://wuxu1.github.io/wuxu-complete-plus.json",
            "https://community-apps.sidestore.io/sidecommunity.json"
        ]
        
        let group = DispatchGroup()
        for urlString in starterURLs {
            guard let url = URL(string: urlString) else { continue }
            group.enter()
            self.addSourceDirectly(url: url) { _ in
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            self?.updateSources()
        }
    }
    
    @objc func presentTrustedSourcesSheet() {
        let installedSources = fetchInstalledSources()
        let installedURLs = Set(installedSources.map { $0.sourceURL.absoluteString.lowercased() })
        
        let alert = UIAlertController(
            title: "📦 Trung Tâm Kho Ứng Dụng",
            message: "Bạn có thể lọc xem riêng từng kho, bật thêm kho lớn, hoặc cài trực tiếp file .IPA từ đường dẫn:",
            preferredStyle: .actionSheet
        )
        
        if !installedSources.isEmpty {
            let filterTitle = (self.selectedSourceFilter == nil)
                ? "🔍 Lọc theo từng Nguồn đang có (\(installedSources.count) nguồn)..."
                : "🔄 Bỏ lọc nguồn (Hiện tất cả \(installedSources.count) nguồn)"
            
            alert.addAction(UIAlertAction(title: filterTitle, style: .default) { [weak self] _ in
                guard let self else { return }
                if self.selectedSourceFilter != nil {
                    self.selectedSourceFilter = nil
                } else {
                    self.presentFilterByInstalledSourceSheet(installedSources)
                }
            })
        }
        
        for repo in kTrustedRepos {
            let isAdded = installedURLs.contains(repo.urlString.lowercased())
            let prefix = isAdded ? "✅ " : "➕ "
            let action = UIAlertAction(title: prefix + repo.name, style: .default) { [weak self] _ in
                self?.addTrustedSourceURL(repo.urlString, name: repo.name)
            }
            alert.addAction(action)
        }
        
        alert.addAction(UIAlertAction(title: "⚡ Bật Tất Cả Kho Uy Tín Lớn", style: .default) { [weak self] _ in
            self?.addAllTrustedRepos()
        })
        
        alert.addAction(UIAlertAction(title: "🔗 Dán Link Nguồn JSON bất kỳ...", style: .default) { [weak self] _ in
            self?.promptCustomSourceURL()
        })
        
        alert.addAction(UIAlertAction(title: "📲 Cài đặt trực tiếp từ Link .IPA...", style: .default) { [weak self] _ in
            self?.promptDirectIPAURLInstall()
        })
        
        alert.addAction(UIAlertAction(title: "🔄 Làm Mới Toàn Bộ Kho App", style: .default) { [weak self] _ in
            self?.collectionView.refreshControl?.beginRefreshing()
            self?.updateSources()
        })
        
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        
        if let popover = alert.popoverPresentationController, let btn = self.heroManageSourcesButton {
            popover.sourceView = btn
            popover.sourceRect = btn.bounds
        }
        
        self.present(alert, animated: true)
    }
    
    func presentFilterByInstalledSourceSheet(_ sources: [Source]) {
        let sheet = UIAlertController(
            title: "🔍 Chọn Nguồn Muốn Xem",
            message: "Bấm vào tên nguồn để chỉ hiển thị ứng dụng của nguồn đó, hoặc quản lý xóa nguồn:",
            preferredStyle: .actionSheet
        )
        
        sheet.addAction(UIAlertAction(title: "✨ Hiện Tất Cả Các Nguồn", style: .default) { [weak self] _ in
            self?.selectedSourceFilter = nil
        })
        
        for src in sources {
            let count = src.apps.count
            let isCurrent = (self.selectedSourceFilter == src)
            let prefix = isCurrent ? "✓ " : "📦 "
            sheet.addAction(UIAlertAction(title: "\(prefix)\(src.name) (\(count) apps)", style: .default) { [weak self] _ in
                self?.selectedSourceFilter = src
            })
        }
        
        if sources.count > 1 {
            sheet.addAction(UIAlertAction(title: "🗑 Xóa bớt nguồn không dùng...", style: .destructive) { [weak self] _ in
                self?.presentRemoveSourceSheet(sources)
            })
        }
        
        sheet.addAction(UIAlertAction(title: "Quay lại", style: .cancel))
        
        if let popover = sheet.popoverPresentationController, let btn = self.heroManageSourcesButton {
            popover.sourceView = btn
            popover.sourceRect = btn.bounds
        }
        self.present(sheet, animated: true)
    }
    
    func presentRemoveSourceSheet(_ sources: [Source]) {
        let sheet = UIAlertController(
            title: "🗑 Xóa Nguồn Ứng Dụng",
            message: "Chọn nguồn bạn muốn gỡ khỏi Kho App:",
            preferredStyle: .actionSheet
        )
        
        for src in sources where src.identifier != Source.altStoreIdentifier {
            sheet.addAction(UIAlertAction(title: "Xóa: \(src.name)", style: .destructive) { [weak self] _ in
                guard let self else { return }
                let srcName = src.name
                if self.selectedSourceFilter == src {
                    self.selectedSourceFilter = nil
                }
                self.removeSourceDirectly(src) {
                    DispatchQueue.main.async {
                        self.heroSubtitleLabel?.text = "🗑 Đã xóa nguồn \(srcName)"
                        self.updateDataSource()
                        self.update()
                    }
                }
            })
        }
        
        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let popover = sheet.popoverPresentationController, let btn = self.heroManageSourcesButton {
            popover.sourceView = btn
            popover.sourceRect = btn.bounds
        }
        self.present(sheet, animated: true)
    }
    
    func addTrustedSourceURL(_ urlString: String, name: String) {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        
        self.heroSubtitleLabel?.text = "⏳ Đang nạp \(name)..."
        self.addSourceDirectly(url: url) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success:
                    self.heroSubtitleLabel?.text = "✅ Đã nạp thành công \(name)!"
                case .failure:
                    self.heroSubtitleLabel?.text = "🔄 Đang đồng bộ lại \(name)..."
                }
                self.updateSources()
            }
        }
    }
    
    func addAllTrustedRepos() {
        self.heroSubtitleLabel?.text = "⏳ Đang nạp toàn bộ kho ứng dụng lớn..."
        let group = DispatchGroup()
        for repo in kTrustedRepos {
            guard let url = URL(string: repo.urlString) else { continue }
            group.enter()
            self.addSourceDirectly(url: url) { _ in
                group.leave()
            }
        }
        group.notify(queue: .main) { [weak self] in
            guard let self else { return }
            self.heroSubtitleLabel?.text = "✅ Đã kích hoạt toàn bộ kho ứng dụng!"
            self.updateSources()
        }
    }
    
    func promptCustomSourceURL() {
        let alert = UIAlertController(
            title: "🔗 Thêm Nguồn Ứng Dụng",
            message: "Dán đường dẫn nguồn (.json) để nạp thêm ứng dụng vào kho:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "https://.../apps.json"
            tf.keyboardType = .URL
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               clip.hasPrefix("http"), !clip.lowercased().hasSuffix(".ipa") {
                tf.text = clip
            }
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Thêm Nguồn", style: .default) { [weak self] _ in
            guard let text = alert.textFields?.first?.text, !text.isEmpty else { return }
            self?.addTrustedSourceURL(text, name: "Nguồn mới")
        })
        self.present(alert, animated: true)
    }
    
    func promptDirectIPAURLInstall() {
        let alert = UIAlertController(
            title: "📲 Cài Trực Tiếp Từ Link .IPA",
            message: "Dán đường dẫn tải trực tiếp file .ipa để hệ thống tự tải về và ký cài đặt:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "https://.../app.ipa"
            tf.keyboardType = .URL
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               clip.hasPrefix("http") {
                tf.text = clip
            }
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Tải & Cài Đặt", style: .default) { [weak self] _ in
            guard let self,
                  let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let remoteURL = URL(string: text) else { return }
            self.downloadAndInstallRemoteIPA(from: remoteURL)
        })
        self.present(alert, animated: true)
    }
    
    func downloadAndInstallRemoteIPA(from remoteURL: URL) {
        self.heroSubtitleLabel?.text = "⬇️ Đang tải file IPA từ đường dẫn..."
        
        Task {
            do {
                let (tempLocation, _) = try await URLSession.shared.download(from: remoteURL)
                let fileName = remoteURL.lastPathComponent.hasSuffix(".ipa") ? remoteURL.lastPathComponent : "DirectInstallApp.ipa"
                let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + fileName)
                try? FileManager.default.removeItem(at: destinationURL)
                try FileManager.default.moveItem(at: tempLocation, to: destinationURL)
                
                await MainActor.run {
                    self.heroSubtitleLabel?.text = "⚙️ Đang ký và cài đặt ứng dụng..."
                    _ = AppManager.shared.install(.url(destinationURL), presentingViewController: self) { [weak self] result in
                        DispatchQueue.main.async {
                            try? FileManager.default.removeItem(at: destinationURL)
                            guard let self else { return }
                            switch result {
                            case .success(let installedApp):
                                self.heroSubtitleLabel?.text = "✅ Đã cài đặt thành công \(installedApp.name)!"
                            case .failure(let error):
                                self.heroSubtitleLabel?.text = "⚠️ Cài đặt thất bại: \(error.localizedDescription)"
                                let toastView = ToastView(error: error, opensLog: true)
                                toastView.show(in: self)
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.heroSubtitleLabel?.text = "⚠️ Không thể tải file IPA từ link này."
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                }
            }
        }
    }
    
    func styleSortPopupButton() {
        guard let btn = self.heroSortPopupButton else { return }
        
        if #available(iOS 15.0, tvOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.95)
            config.baseForegroundColor = BrowseCSSTheme.blue
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 9)
            
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)
            config.image = UIImage(systemName: "arrow.up.arrow.down", withConfiguration: iconConfig)
            config.imagePlacement = .trailing
            config.imagePadding = 4
            
            config.background.strokeColor = BrowseCSSTheme.white
            config.background.strokeWidth = 1.0
            
            btn.configuration = config
        } else {
            btn.backgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.95)
            btn.setTitleColor(BrowseCSSTheme.blue, for: .normal)
            btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            btn.layer.cornerRadius = 14
            btn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        }
        
        btn.layer.shadowColor = UIColor.black.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 2)
        btn.layer.shadowRadius = 5
        btn.layer.shadowOpacity = 0.18
        btn.setContentHuggingPriority(.required, for: .horizontal)
        btn.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        updateSortButtonTitle()
    }
    
    func updateSortButtonTitle() {
        guard let btn = self.heroSortPopupButton else { return }
        let displayTitle = translateSortingName(self.preferredAppSorting)
        
        if #available(iOS 15.0, tvOS 15.0, *), var config = btn.configuration {
            var attrTitle = AttributedString(displayTitle)
            attrTitle.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
            attrTitle.foregroundColor = BrowseCSSTheme.blue
            config.attributedTitle = attrTitle
            btn.configuration = config
        } else {
            btn.setTitle(displayTitle, for: .normal)
        }
        btn.sizeToFit()
    }
    
    func translateStaticText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dictionary: [String: String] = [
            "Browse": "Kho App",
            "No Apps": "Chưa có ứng dụng phù hợp",
            "Loading...": "Đang đồng bộ kho ứng dụng...",
            "Loading…": "Đang đồng bộ kho ứng dụng…",
            "Unable to Fetch Apps": "Chưa thể tải hết kho ứng dụng",
            "Please make sure your spelling is correct, or try searching for another app.": "Kiểm tra lại từ khóa tìm kiếm, hoặc bấm nút '+ Nguồn' ở góc trên để nạp thêm kho ứng dụng lớn.",
            "Sort by…": "Sắp xếp theo…",
            "Sort by...": "Sắp xếp theo...",
            "FREE": "CÀI ĐẶT",
            "GET": "CÀI ĐẶT",
            "OPEN": "MỞ",
            "UPDATE": "CẬP NHẬT",
            "INSTALL": "CÀI ĐẶT",
            "BETA": "THỬ NGHIỆM"
        ]
        return dictionary[trimmed] ?? text
    }
    
    func translateSortingName(_ sorting: AppSorting) -> String {
        switch sorting {
        case .default: return "Mặc định"
        case .name: return "Tên A-Z"
        case .developer: return "Tác giả"
        case .lastUpdated: return "Mới nhất"
        }
    }
    
    func translateCategoryName(_ category: StoreCategory) -> String {
        let raw = category.rawValue.lowercased()
        switch raw {
        case "games": return "Trò chơi"
        case "utilities": return "Tiện ích"
        case "social", "socialnetworking": return "Mạng xã hội"
        case "entertainment": return "Giải trí"
        case "lifestyle": return "Phong cách sống"
        case "photoandvideo", "photovideo": return "Ảnh & Video"
        case "developer": return "Nhà phát triển"
        case "emulators", "emulator": return "Trình giả lập"
        case "other": return "Danh mục khác"
        default: return translateStaticText(category.localizedName)
        }
    }
    
    func translateLabelsInsideCard(_ view: UIView) {
        for subview in view.subviews {
            if let pillBtn = subview as? UIButton {
                if let title = pillBtn.title(for: .normal), !title.isEmpty {
                    let translated = translateStaticText(title.uppercased())
                    if translated != title.uppercased() {
                        pillBtn.setTitle(translated, for: .normal)
                    }
                }
            } else if let label = subview as? UILabel, let text = label.text, !text.isEmpty {
                let translated = translateStaticText(text)
                if translated != text {
                    label.text = translated
                }
            }
            translateLabelsInsideCard(subview)
        }
    }
    
    func styleAppCardCell(_ cell: AppCardCollectionViewCell, with tintColor: UIColor) {
        cell.bannerView.layer.cornerRadius = BrowseCSSTheme.cornerRadius
        cell.bannerView.layer.masksToBounds = true
        cell.bannerView.layer.borderWidth = 1.5
        cell.bannerView.layer.borderColor = BrowseCSSTheme.white.withAlphaComponent(0.85).cgColor
        
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = tintColor.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 8)
        cell.layer.shadowRadius = 16
        cell.layer.shadowOpacity = 0.22
        
        if let btn = cell.bannerView.button {
            btn.layer.shadowColor = tintColor.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 4)
            btn.layer.shadowRadius = 8
            btn.layer.shadowOpacity = 0.35
            
            btn.removeTarget(self, action: #selector(animatePillButtonPress(_:)), for: .touchDown)
            btn.removeTarget(self, action: #selector(animatePillButtonRelease(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
            btn.addTarget(self, action: #selector(animatePillButtonPress(_:)), for: .touchDown)
            btn.addTarget(self, action: #selector(animatePillButtonRelease(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        }
        
        translateLabelsInsideCard(cell.bannerView)
    }
    
    @objc func animatePillButtonPress(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12) {
            sender.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
        }
    }
    
    @objc func animatePillButtonRelease(_ sender: UIButton) {
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            sender.transform = .identity
        }
    }
}

// MARK: - 🔍 XỬ LÝ TÌM KIẾM TRỰC TIẾP TRÊN KHỐI HERO BANNER (CÓ DEBOUNCE CHỐNG LAG)
extension BrowseViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        self.searchDebounceWorkItem?.cancel()
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchPredicate = nil
            self.update()
            return
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let subpredicates = [
                NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.name), trimmed),
                NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.subtitle), trimmed),
                NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.developerName), trimmed),
                NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.bundleIdentifier), trimmed)
            ]
            self.searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
            self.update()
        }
        
        self.searchDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = nil
        self.searchPredicate = nil
        searchBar.resignFirstResponder()
        self.update()
    }
}

private extension BrowseViewController
{
    func preparePipeline()
    {
        AppManager.shared.$updateSourcesResult
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &self.cancellables)
    }
    
    func makeFetchRequest() -> NSFetchRequest<StoreApp>
    {
        let fetchRequest = StoreApp.fetchRequest() as NSFetchRequest<StoreApp>
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.fetchBatchSize = 25
        
        var predicates: [NSPredicate] = [StoreApp.visibleAppsPredicate]
        
        if let activeSource = self.activeSourceFilter
        {
            predicates.append(NSPredicate(format: "%K == %@", #keyPath(StoreApp._source), activeSource))
        }
        
        if let category = self.category
        {
            let categoryPredicate = switch category {
            case .other: StoreApp.otherCategoryPredicate
            default: NSPredicate(format: "%K == %@", #keyPath(StoreApp._category), category.rawValue)
            }
            predicates.append(categoryPredicate)
        }
        
        fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        
        var sortDescriptors = [NSSortDescriptor(keyPath: \StoreApp.name, ascending: true),
                               NSSortDescriptor(keyPath: \StoreApp.bundleIdentifier, ascending: true),
                               NSSortDescriptor(keyPath: \StoreApp.sourceIdentifier, ascending: true)]
        
        switch self.preferredAppSorting
        {
        case .default:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.sortIndex, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
            
        case .name:
            break
            
        case .developer:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.developerName, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
            
        case .lastUpdated:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.latestSupportedVersion?.date, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
        }
        
        fetchRequest.sortDescriptors = sortDescriptors
        
        return fetchRequest
    }
    
    func makeDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>
    {
        let fetchRequest = self.makeFetchRequest()
        
        let context = self.activeSourceFilter?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: context)
        dataSource.placeholderView = self.placeholderView
        dataSource.cellConfigurationHandler = { [weak self] (cell, app, indexPath) in
            guard let self else { return }
            
            let cell = cell as! AppCardCollectionViewCell
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            
            let showSourceIcon = (self.activeSourceFilter == nil)
            cell.configure(for: app, showSourceIcon: showSourceIcon)
            
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            
            cell.bannerView.button?.addTarget(self, action: #selector(BrowseViewController.performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.button?.activityIndicatorView.style = .medium
            cell.bannerView.button?.activityIndicatorView.color = .white
            
            let tintColor = app.tintColor ?? BrowseCSSTheme.blue
            cell.tintColor = tintColor
            
            self.styleAppCardCell(cell, with: tintColor)
        }
        dataSource.prefetchHandler = { (storeApp, indexPath) in
            let image = try await ImagePipeline.shared.image(for: storeApp.iconURL)
            return await Task.detached(priority: .userInitiated) {
                _ = image.isPredominantlyLight
                _ = image.withDropShadow(color: .black, radius: 4, offset: CGSize(width: 0, height: 1.5), opacity: 0.25)
                return image
            }.value
        }
        dataSource.prefetchCompletionHandler = { [weak dataSource] (cell, image, indexPath, error) in
            let cell = cell as! AppCardCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
            
            if let error = error, let dataSource
            {
                let app = dataSource.item(at: indexPath)
                debugLog("Không thể tải biểu tượng ứng dụng từ \(app.iconURL). \(error.localizedDescription)")
            }
        }
        
        return dataSource
    }
    
    func updateDataSource()
    {
        let fetchRequest = self.makeFetchRequest()
        
        let context = self.activeSourceFilter?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.dataSource.fetchedResultsController = fetchedResultsController
        
        self.dataSource.predicate = self.searchPredicate
        
        if let heroContainer = self.heroContainerView {
            self.collectionView.bringSubviewToFront(heroContainer)
        }
    }
    
    func updateSources()
    {
        AppManager.shared.updateAllSources { [weak self] result in
            guard let self else { return }
            #if !os(tvOS)
            self.collectionView.refreshControl?.endRefreshing()
            #endif
            
            self.update()
            
            guard case .failure(let error) = result else { return }
            
            if self.dataSource.itemCount > 0
            {
                let toastView = ToastView(error: error)
                toastView.show(in: self)
            }
        }
    }
    
    func update()
    {
        if self.searchPredicate != nil
        {
            self.placeholderView.textLabel.text = "Không tìm thấy ứng dụng"
            self.placeholderView.textLabel.isHidden = false
            
            self.placeholderView.detailTextLabel.text = "Thử tìm từ khóa khác hoặc bấm '+ Nguồn' ở góc trên để nạp thêm kho ứng dụng lớn."
            self.placeholderView.detailTextLabel.isHidden = false
            
            self.placeholderView.activityIndicatorView.stopAnimating()
        }
        else
        {
            switch AppManager.shared.updateSourcesResult
            {
            case nil:
                self.placeholderView.textLabel.isHidden = true
                self.placeholderView.detailTextLabel.isHidden = false
                self.placeholderView.detailTextLabel.text = "Đang đồng bộ kho ứng dụng..."
                self.placeholderView.activityIndicatorView.startAnimating()
                
            case .failure(let error):
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = false
                self.placeholderView.textLabel.text = "Kho ứng dụng đang trống"
                self.placeholderView.detailTextLabel.text = "Bấm nút '+ Nguồn' màu xanh ở góc trên để bật Kho App Uy Tín ngay!\n(\(error.localizedDescription))"
                self.placeholderView.activityIndicatorView.stopAnimating()
                
            case .success:
                self.placeholderView.textLabel.text = "Chưa có ứng dụng trong mục này"
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.text = "Bấm vào '✨ Tất cả' hoặc bấm nút '+ Nguồn' màu xanh ở góc trên để nạp Kho App Uy Tín!"
                self.placeholderView.detailTextLabel.isHidden = false
                self.placeholderView.activityIndicatorView.stopAnimating()
            }
        }
        
        let tintColor: UIColor
        let headerTitle: String
        let headerSubtitle: String
        
        let totalCount = self.dataSource.itemCount
        
        if let activeSource = self.activeSourceFilter
        {
            tintColor = activeSource.effectiveTintColor?.adjustedForDisplay ?? BrowseCSSTheme.blue
            headerTitle = activeSource.name
            headerSubtitle = "Đang lọc \(totalCount) ứng dụng từ \(activeSource.name) • Bấm tiêu đề để đổi"
            
            self.titleSourceIconView.backgroundColor = tintColor
            self.titleSourceIconView.isHidden = false
            self.titleCategoryIconView.isHidden = true
            
            if let iconURL = activeSource.effectiveIconURL
            {
                Task { [weak self] in
                    do
                    {
                        let image = try await ImagePipeline.shared.image(for: iconURL)
                        guard let self else { return }
                        self.titleSourceIconView.image = image
                        self.titleSourceIconView.backgroundColor = .white
                    }
                    catch
                    {
                        debugLog("Không thể tải biểu tượng nguồn tại \(iconURL). \(error.localizedDescription)")
                    }
                }
            }
        }
        else if let category = self.category
        {
            tintColor = category.tintColor
            headerTitle = translateCategoryName(category)
            headerSubtitle = "Đang lọc \(totalCount) ứng dụng mục \(translateCategoryName(category))"
            
            let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(.white, renderingMode: .alwaysOriginal)
            self.titleCategoryIconView.image = image
            self.titleCategoryIconView.isHidden = false
            self.titleSourceIconView.isHidden = true
        }
        else
        {
            tintColor = BrowseCSSTheme.blue
            headerTitle = "Kho App"
            headerSubtitle = totalCount > 0
                ? "Sẵn sàng \(totalCount) ứng dụng • Bấm + Nguồn để nạp thêm hoặc cài IPA"
                : "Bấm '+ Nguồn' góc phải để bật kho ứng dụng uy tín"
            
            self.titleSourceIconView.isHidden = true
            self.titleCategoryIconView.isHidden = true
        }
        
        self.title = nil
        self.navigationItem.title = nil
        
        self.titleLabel.text = headerTitle
        self.titleLabel.textColor = BrowseCSSTheme.white
        self.heroSubtitleLabel?.text = headerSubtitle
        self.view.tintColor = tintColor
        self.updateSortButtonTitle()
        
        if let heroContainer = self.heroContainerView {
            self.collectionView.bringSubviewToFront(heroContainer)
        }
    }
    
    func prepareAppSorting()
    {
        if self.preferredAppSorting == .default && self.activeSourceFilter == nil
        {
            self.preferredAppSorting = .lastUpdated
        }
        
        let children = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else { return completion([]) }
            
            var sortingOptions = AppSorting.allCases
            if self.activeSourceFilter == nil
            {
                sortingOptions = sortingOptions.filter { $0 != .default }
            }
            
            let actions = sortingOptions.map { sorting in
                let state: UIMenuElement.State = (sorting == self.preferredAppSorting) ? .on : .off
                let action = UIAction(title: self.translateSortingName(sorting), image: nil, state: state) { [weak self] _ in
                    guard let self else { return }
                    self.preferredAppSorting = sorting
                    UserDefaults.standard.preferredAppSorting = sorting
                    self.updateSortButtonTitle()
                    self.updateDataSource()
                }
                
                return action
            }
            
            completion(actions)
        }
        
        var menuOptions: UIMenu.Options = [.displayInline]
        if #available(iOS 15.0, tvOS 15.0, *) {
            menuOptions.insert(.singleSelection)
        }
        
        let sortMenu = UIMenu(title: "Sắp xếp kho ứng dụng…", options: menuOptions, children: [children])
        let sortIcon = UIImage(systemName: "arrow.up.arrow.down.circle.fill")
        
        let sortButton = UIBarButtonItem(title: "Sắp xếp theo…", image: sortIcon, primaryAction: nil, menu: sortMenu)
        self.sortButton = sortButton
        self.navigationItem.rightBarButtonItems = [sortButton]
        
        #if !os(tvOS)
        self.heroSortPopupButton?.menu = sortMenu
        self.heroSortPopupButton?.showsMenuAsPrimaryAction = true
        #else
        if #available(tvOS 17.0, *) {
            self.heroSortPopupButton?.menu = sortMenu
        }
        #endif
        
        self.updateSortButtonTitle()
    }
}

private extension BrowseViewController
{
    @IBAction func performAppAction(_ sender: PillButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let app = self.dataSource.item(at: indexPath)
        
        if let installedApp = app.installedApp, !installedApp.hasUpdate
        {
            self.open(installedApp)
        }
        else
        {
            self.install(app, at: indexPath) { progress in
                sender.progress = progress
            }
        }
    }
    
    func install(_ app: StoreApp, at indexPath: IndexPath, progressUpdateHandler: @escaping (Progress) -> Void)
    {
        InstallAppDialog.present(storeApp: app, from: self) { [weak self] in
            guard let self else { return }
            let previousProgress = AppManager.shared.installationProgress(for: app)
            guard previousProgress == nil else {
                previousProgress?.cancel()
                return
            }
            
            if let installedApp = app.installedApp, installedApp.hasUpdate
            {
                let progress = AppManager.shared.update(installedApp, presentingViewController: self, completionHandler: finish(_:))
                progressUpdateHandler(progress)
            }
            else
            {
                let group = AppManager.shared.install(.app(app), presentingViewController: self, completionHandler: finish(_:))
                progressUpdateHandler(group.progress)
            }
            
            func finish(_ result: Result<InstalledApp, Error>)
            {
                debugLog("BrowseViewController.finish được gọi với kết quả: \(result) cho \(app.bundleIdentifier)")
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(let error) where error is CancellationError: break
                    case .failure(let error):
                        let toastView = ToastView(error: error, opensLog: true)
                        toastView.show(in: self)
                        
                    case .success: debugLog("Đã cài đặt ứng dụng thành công: \(app.bundleIdentifier)")
                    }
                    
                    UIView.performWithoutAnimation {
                        if let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: app)
                        {
                            self.collectionView.reloadItems(at: [indexPath])
                        }
                        else
                        {
                            self.collectionView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    func open(_ installedApp: InstalledApp)
    {
        UIApplication.shared.open(installedApp.openAppURL)
    }
}

extension BrowseViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let item = self.dataSource.item(at: indexPath)
        let itemID = item.globallyUniqueID ?? item.bundleIdentifier

        if let previousSize = self.cachedItemSizes[itemID]
        {
            return previousSize
        }
        
        self.dataSource.cellConfigurationHandler(self.prototypeCell, item, indexPath)
        
        let insets = (self.view.layoutMargins.left + self.view.layoutMargins.right)

        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionView.bounds.width - insets)
        widthConstraint.isActive = true
        defer { widthConstraint.isActive = false }

        self.prototypeCell.frame.size.width = widthConstraint.constant
        self.prototypeCell.layoutIfNeeded()
        
        let itemSize = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        self.cachedItemSizes[itemID] = itemSize
        return itemSize
    }
    
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        if !self.animatedIndexPaths.contains(indexPath) {
            self.animatedIndexPaths.insert(indexPath)
            
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 25).scaledBy(x: 0.97, y: 0.97)
            
            UIView.animate(withDuration: 0.45, delay: 0.02, usingSpringWithDamping: 0.82, initialSpringVelocity: 0.5, options: [.curveEaseOut, .allowUserInteraction]) {
                cell.alpha = 1
                cell.transform = .identity
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.15, delay: 0, options: .curveEaseOut) {
                cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        if let cell = collectionView.cellForItem(at: indexPath) {
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                cell.transform = .identity
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let app = self.dataSource.item(at: indexPath)
        let appViewController = AppViewController.makeAppViewController(app: app)
        appViewController.title = nil
        appViewController.navigationItem.title = nil
        #if !os(tvOS)
        appViewController.navigationItem.largeTitleDisplayMode = .never
        #endif
        
        let navigationController = self.navigationController ?? self.presentingViewController?.navigationController
        navigationController?.pushViewController(appViewController, animated: true)
    }
}

extension BrowseViewController: UIViewControllerPreviewingDelegate
{
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard
            let indexPath = self.collectionView.indexPathForItem(at: location),
            let cell = self.collectionView.cellForItem(at: indexPath)
        else { return nil }
        
        previewingContext.sourceRect = cell.frame
        
        let app = self.dataSource.item(at: indexPath)
        
        let appViewController = AppViewController.makeAppViewController(app: app)
        appViewController.title = nil
        appViewController.navigationItem.title = nil
        return appViewController
    }
    
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        viewControllerToCommit.title = nil
        viewControllerToCommit.navigationItem.title = nil
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}
