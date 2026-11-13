
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
@preconcurrency import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI SETTINGS)
private struct BrowseCSSTheme {
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
    
    // Hero Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.92).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.88).cgColor
    
    static let cornerRadius: CGFloat = 15.0
}

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
    // Nil == Hiển thị ứng dụng từ tất cả các nguồn.
    let source: Source?
    
    private(set) var category: StoreCategory? {
        didSet {
            self.updateDataSource()
            self.update()
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
    
    private var titleStackView: UIStackView!
    private var titleSourceIconView: AppIconImageView!
    private var titleCategoryIconView: UIImageView!
    private var titleLabel: UILabel!
    
    // MARK: - Thành phần Giao diện Hero Banner & Điều hướng nổi (Giống Settings)
    private var heroContainerView: UIView?
    private var heroCardView: UIView?
    private var heroGradientLayer: CAGradientLayer?
    private var heroTitleButton: UIButton?
    private var heroSubtitleLabel: UILabel?
    private var heroSortPopupButton: UIButton?
    private var heroSearchBar: UISearchBar?
    private var floatingBackButton: UIButton?
    private let heroHeaderHeight: CGFloat = 152.0
    
    // Theo dõi các cell đã chạy animation để không bị lặp lại gây rối mắt
    private var animatedIndexPaths = Set<IndexPath>()
    
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
        
        // Ẩn hoàn toàn thanh điều hướng mặc định để tràn viền giống hệt tab Cài đặt
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
        collectionViewLayout.minimumLineSpacing = 22
        // Dành khoảng trống phía trên cho khối Hero Banner chuẩn CSS
        collectionViewLayout.sectionInset = UIEdgeInsets(top: self.heroHeaderHeight + 14, left: 0, bottom: 45, right: 0)
        
        #if !os(tvOS)
        self.registerForPreviewing(with: self, sourceView: self.collectionView)
        
        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.updateSources()
        })
        refreshControl.tintColor = BrowseCSSTheme.purple
        self.collectionView.refreshControl = refreshControl
        #endif
        
        self.titleSourceIconView = AppIconImageView(style: .circular)
        
        self.titleCategoryIconView = UIImageView(frame: .zero)
        self.titleCategoryIconView.contentMode = .scaleAspectFit
        
        self.titleLabel = UILabel()
        self.titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
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
            self.titleSourceIconView.heightAnchor.constraint(equalToConstant: 26),
            self.titleSourceIconView.widthAnchor.constraint(equalTo: self.titleSourceIconView.heightAnchor),
            self.titleCategoryIconView.heightAnchor.constraint(equalToConstant: 24),
            self.titleCategoryIconView.widthAnchor.constraint(equalToConstant: 24)
        ])
        
        // ✨ KÍCH HOẠT GIAO DIỆN WEB CSS & VIỆT HÓA ĐỒNG BỘ VỚI CÀI ĐẶT ✨
        self.applySmartWebCSSTheme()
        
        self.prepareAppSorting()
        self.preparePipeline()
        
        self.updateDataSource()
        self.update()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Đảm bảo khối Hero Banner luôn khớp chiều rộng màn hình và nằm cố định ở đầu danh sách
        if let heroContainer = self.heroContainerView {
            let targetFrame = CGRect(x: 0, y: 0, width: self.collectionView.bounds.width, height: self.heroHeaderHeight)
            if heroContainer.frame != targetFrame {
                heroContainer.frame = targetFrame
                heroContainer.layoutIfNeeded()
            }
        }
        if let heroCard = self.heroCardView {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        // Đảm bảo ẩn thanh màu trắng ở trên cùng để tràn viền toàn màn hình
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
        // Luôn ẩn thanh điều hướng và tiêu đề ở cả trang Duyệt lẫn trang Chi tiết ứng dụng
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
            
            // Nút tròn nhỏ 34x34 cố định giống hệt bên Settings
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

// MARK: - ✨ HỆ THỐNG RENDER CSS THÔNG MINH & VIỆT HÓA TOÀN DIỆN
private extension BrowseViewController {
    
    func applySmartWebCSSTheme() {
        // 1. Nền Body cố định: Không bao giờ bị trắng khi cuộn xuống dưới
        let bgView = BrowseCSSGradientBackgroundView(frame: UIScreen.main.bounds)
        bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.collectionView.backgroundView = bgView
        self.collectionView.backgroundColor = .clear
        
        // 2. Tạo khối .hero Banner nằm sát phía trên (Tích hợp Tìm kiếm & Sắp xếp)
        setupCSSHeroBanner()
        
        // 3. Làm đẹp PlaceholderView (Khi đang tải hoặc không có ứng dụng)
        self.placeholderView.textLabel.textColor = BrowseCSSTheme.blue
        self.placeholderView.textLabel.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        self.placeholderView.detailTextLabel.textColor = BrowseCSSTheme.dark.withAlphaComponent(0.78)
        self.placeholderView.detailTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        self.placeholderView.activityIndicatorView.color = BrowseCSSTheme.purple
        
        // 4. Cấu hình TabBar đồng bộ màu
        #if !os(tvOS)
        if let tabAppearance = self.tabBarController?.tabBar.standardAppearance {
            tabAppearance.stackedLayoutAppearance.normal.badgeBackgroundColor = BrowseCSSTheme.blue
            self.navigationController?.tabBarItem.scrollEdgeAppearance = tabAppearance
        }
        #endif
    }
    
    // Tạo khối .hero nằm sát phía trên, tích hợp Tiêu đề, Sắp xếp và Thanh tìm kiếm tiếng Việt
    func setupCSSHeroBanner() {
        self.heroContainerView?.removeFromSuperview()
        
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.collectionView.bounds.width, height: self.heroHeaderHeight))
        headerContainer.backgroundColor = .clear
        
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
        
        // Nút chọn Danh mục ẩn phía trên tiêu đề (nếu đang ở chế độ xem theo Danh mục)
        let titleOverlayButton = UIButton(type: .system)
        titleOverlayButton.translatesAutoresizingMaskIntoConstraints = false
        titleOverlayButton.backgroundColor = .clear
        self.heroTitleButton = titleOverlayButton
        
        // Phụ đề tiếng Việt
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Khám phá, tìm kiếm & cài đặt kho ứng dụng phong phú"
        subLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        subLabel.textColor = BrowseCSSTheme.white.withAlphaComponent(0.92)
        subLabel.numberOfLines = 1
        self.heroSubtitleLabel = subLabel
        
        // Nút Sắp xếp dạng viên thuốc (Giống nút chọn kênh Beta ở Settings)
        let sortBtn = UIButton(type: .system)
        sortBtn.translatesAutoresizingMaskIntoConstraints = false
        self.heroSortPopupButton = sortBtn
        styleSortPopupButton()
        
        // Thanh tìm kiếm tích hợp gọn trong Hero Card
        let searchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Tìm kiếm ứng dụng, nhà phát triển..."
        searchBar.delegate = self
        searchBar.tintColor = BrowseCSSTheme.purple
        #if !os(tvOS)
        let textField = searchBar.searchTextField
        textField.backgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.95)
        textField.textColor = BrowseCSSTheme.dark
        textField.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        textField.layer.cornerRadius = 10
        textField.layer.masksToBounds = true
        textField.leftView?.tintColor = BrowseCSSTheme.blue
        textField.attributedPlaceholder = NSAttributedString(
            string: "Tìm kiếm ứng dụng, nhà phát triển...",
            attributes: [.foregroundColor: BrowseCSSTheme.dark.withAlphaComponent(0.5)]
        )
        #endif
        self.heroSearchBar = searchBar
        
        heroCard.addSubview(self.titleStackView)
        heroCard.addSubview(titleOverlayButton)
        heroCard.addSubview(subLabel)
        heroCard.addSubview(sortBtn)
        heroCard.addSubview(searchBar)
        headerContainer.addSubview(heroCard)
        self.collectionView.addSubview(headerContainer)
        self.heroContainerView = headerContainer
        
        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 4),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -4),
            
            self.titleStackView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 16),
            self.titleStackView.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),
            self.titleStackView.trailingAnchor.constraint(lessThanOrEqualTo: sortBtn.leadingAnchor, constant: -8),
            
            titleOverlayButton.leadingAnchor.constraint(equalTo: self.titleStackView.leadingAnchor),
            titleOverlayButton.trailingAnchor.constraint(equalTo: self.titleStackView.trailingAnchor),
            titleOverlayButton.topAnchor.constraint(equalTo: self.titleStackView.topAnchor),
            titleOverlayButton.bottomAnchor.constraint(equalTo: self.titleStackView.bottomAnchor),
            
            sortBtn.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            sortBtn.centerYAnchor.constraint(equalTo: self.titleStackView.centerYAnchor),
            
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 16),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -16),
            subLabel.topAnchor.constraint(equalTo: self.titleStackView.bottomAnchor, constant: 4),
            
            searchBar.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -8),
            searchBar.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 4),
            searchBar.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -8),
            searchBar.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
    }
    
    // Thiết kế nút Sắp xếp dạng viên thuốc (Pill Button) đồng bộ với Settings
    func styleSortPopupButton() {
        guard let btn = self.heroSortPopupButton else { return }
        
        if #available(iOS 15.0, tvOS 15.0, *) {
            var config = UIButton.Configuration.filled()
            config.baseBackgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.95)
            config.baseForegroundColor = BrowseCSSTheme.blue
            config.cornerStyle = .capsule
            config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 10)
            
            let iconConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
            config.image = UIImage(systemName: "arrow.up.arrow.down", withConfiguration: iconConfig)
            config.imagePlacement = .trailing
            config.imagePadding = 5
            
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
            attrTitle.font = UIFont.systemFont(ofSize: 12, weight: .bold)
            attrTitle.foregroundColor = BrowseCSSTheme.blue
            config.attributedTitle = attrTitle
            btn.configuration = config
        } else {
            btn.setTitle(displayTitle, for: .normal)
        }
        btn.sizeToFit()
    }
    
    // Bộ từ điển dịch tự động sang Tiếng Việt
    func translateStaticText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let dictionary: [String: String] = [
            "Browse": "Khám Phá",
            "No Apps": "Không có ứng dụng",
            "Loading...": "Đang tải danh sách ứng dụng...",
            "Loading…": "Đang tải danh sách ứng dụng…",
            "Unable to Fetch Apps": "Không thể tải danh sách ứng dụng",
            "Please make sure your spelling is correct, or try searching for another app.": "Vui lòng kiểm tra lại chính tả từ khóa, hoặc thử tìm kiếm một ứng dụng khác.",
            "Sort by…": "Sắp xếp theo…",
            "Sort by...": "Sắp xếp theo...",
            "FREE": "NHẬN",
            "GET": "NHẬN",
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
        case .name: return "Tên ứng dụng"
        case .developer: return "Nhà phát triển"
        case .lastUpdated: return "Mới cập nhật"
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
    
    // Việt hóa các nhãn và nút bấm bên trong từng thẻ ứng dụng
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
        // Bo góc 15px và viền trắng sáng cho Banner
        cell.bannerView.layer.cornerRadius = BrowseCSSTheme.cornerRadius
        cell.bannerView.layer.masksToBounds = true
        cell.bannerView.layer.borderWidth = 1.5
        cell.bannerView.layer.borderColor = BrowseCSSTheme.white.withAlphaComponent(0.85).cgColor
        
        // Đổ bóng phát sáng theo màu của App
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = tintColor.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 8)
        cell.layer.shadowRadius = 16
        cell.layer.shadowOpacity = 0.22
        
        // Đổ bóng phát sáng và gắn hiệu ứng nhún cho nút Nhận/Mở (PillButton)
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
        
        // Việt hóa chữ trên nút hành động (FREE -> NHẬN, OPEN -> MỞ, UPDATE -> CẬP NHẬT)
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

// MARK: - 🔍 XỬ LÝ TÌM KIẾM TRỰC TIẾP TRÊN KHỐI HERO BANNER
extension BrowseViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchPredicate = nil
            self.update()
            return
        }
        
        let subpredicates = [
            NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.name), trimmed),
            NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.subtitle), trimmed),
            NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.developerName), trimmed),
            NSPredicate(format: "%K CONTAINS[cd] %@", #keyPath(StoreApp.bundleIdentifier), trimmed)
        ]
        self.searchPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: subpredicates)
        self.update()
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
            .sink { [weak self] result in
                self?.update()
            }
            .store(in: &self.cancellables)
    }
    
    func makeFetchRequest() -> NSFetchRequest<StoreApp>
    {
        let fetchRequest = StoreApp.fetchRequest() as NSFetchRequest<StoreApp>
        fetchRequest.returnsObjectsAsFaults = false
        
        let predicate = StoreApp.visibleAppsPredicate
        
        if let source = self.source
        {
            let filterPredicate = NSPredicate(format: "%K == %@", #keyPath(StoreApp._source), source)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filterPredicate, predicate])
        }
        else if let category = self.category
        {
            let categoryPredicate = switch category {
            case .other: StoreApp.otherCategoryPredicate
            default: NSPredicate(format: "%K == %@", #keyPath(StoreApp._category), category.rawValue)
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [categoryPredicate, predicate])
        }
        else
        {
            fetchRequest.predicate = predicate
        }
        
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
        
        let context = self.source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: context)
        dataSource.placeholderView = self.placeholderView
        dataSource.cellConfigurationHandler = { [weak self] (cell, app, indexPath) in
            guard let self else { return }
            
            let cell = cell as! AppCardCollectionViewCell
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            
            let showSourceIcon = (self.source == nil)
            cell.configure(for: app, showSourceIcon: showSourceIcon)
            
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            
            cell.bannerView.button?.addTarget(self, action: #selector(BrowseViewController.performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.button?.activityIndicatorView.style = .medium
            cell.bannerView.button?.activityIndicatorView.color = .white
            
            let tintColor = app.tintColor ?? BrowseCSSTheme.blue
            cell.tintColor = tintColor
            
            // ✨ Áp dụng hiệu ứng Card CSS, Đổ bóng & Việt hóa cho thẻ ứng dụng ✨
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
        
        let context = self.source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.dataSource.fetchedResultsController = fetchedResultsController
        
        self.dataSource.predicate = self.searchPredicate
    }
    
    func updateSources()
    {
        AppManager.shared.updateAllSources { result in
            #if !os(tvOS)
            self.collectionView.refreshControl?.endRefreshing()
            #endif
            
            guard case .failure(let error) = result else { return }
            
            if self.dataSource.itemCount > 0
            {
                let toastView = ToastView(error: error)
                toastView.addTarget(nil, action: #selector(TabBarController.presentSources), for: .touchUpInside)
                toastView.show(in: self)
            }
        }
    }
    
    func update()
    {
        if self.searchPredicate != nil
        {
            self.placeholderView.textLabel.text = "Không có ứng dụng"
            self.placeholderView.textLabel.isHidden = false
            
            self.placeholderView.detailTextLabel.text = "Vui lòng kiểm tra lại chính tả từ khóa, hoặc thử tìm kiếm một ứng dụng khác."
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
                self.placeholderView.detailTextLabel.text = "Đang tải danh sách ứng dụng..."
                self.placeholderView.activityIndicatorView.startAnimating()
                
            case .failure(let error):
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = false
                self.placeholderView.textLabel.text = "Không thể tải danh sách ứng dụng"
                self.placeholderView.detailTextLabel.text = error.localizedDescription
                self.placeholderView.activityIndicatorView.stopAnimating()
                
            case .success:
                self.placeholderView.textLabel.text = "Không có ứng dụng"
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = true
                self.placeholderView.activityIndicatorView.stopAnimating()
            }
        }
        
        let tintColor: UIColor
        let headerTitle: String
        let headerSubtitle: String
        
        if let source = self.source
        {
            tintColor = source.effectiveTintColor?.adjustedForDisplay ?? BrowseCSSTheme.blue
            headerTitle = source.name
            headerSubtitle = "Danh sách các ứng dụng được cung cấp từ nguồn \(source.name)"
            
            self.titleSourceIconView.backgroundColor = tintColor
            self.titleSourceIconView.isHidden = false
            self.titleCategoryIconView.isHidden = true
            
            if let iconURL = source.effectiveIconURL
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
            headerTitle = translateCategoryName(category) + " ▾"
            headerSubtitle = "Chạm vào tên danh mục ở trên để chuyển nhanh sang danh mục khác"
            
            let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(.white, renderingMode: .alwaysOriginal)
            self.titleCategoryIconView.image = image
            self.titleCategoryIconView.isHidden = false
            self.titleSourceIconView.isHidden = true
            
            // Gắn menu chuyển đổi nhanh Danh mục lên tiêu đề Hero Banner
            #if !os(tvOS)
            let categoriesMenu = UIMenu(title: "Chọn danh mục ứng dụng", children: [
                UIDeferredMenuElement.uncached { [weak self] completion in
                    let actions = self?.makeCategoryActions() ?? []
                    completion(actions)
                }
            ])
            self.heroTitleButton?.menu = categoriesMenu
            self.heroTitleButton?.showsMenuAsPrimaryAction = true
            #endif
        }
        else
        {
            tintColor = BrowseCSSTheme.blue
            headerTitle = "Khám Phá"
            headerSubtitle = "Khám phá, tìm kiếm & cài đặt kho ứng dụng phong phú"
            
            self.titleSourceIconView.isHidden = true
            self.titleCategoryIconView.isHidden = true
        }
        
        // Không gán self.title để tránh làm xuất hiện chữ trên thanh điều hướng hệ thống
        self.title = nil
        self.navigationItem.title = nil
        
        self.titleLabel.text = headerTitle
        self.titleLabel.textColor = BrowseCSSTheme.white
        self.heroSubtitleLabel?.text = headerSubtitle
        self.view.tintColor = tintColor
        self.updateSortButtonTitle()
    }
    
    func makeCategoryActions() -> [UIAction]
    {
        let handler = { [weak self] (category: StoreCategory) in
            self?.category = category
        }
        
        let fetchRequest = NSFetchRequest(entityName: StoreApp.entity().name!) as NSFetchRequest<NSDictionary>
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.returnsDistinctResults = true
        fetchRequest.propertiesToFetch = [#keyPath(StoreApp._category)]
        fetchRequest.predicate = StoreApp.visibleAppsPredicate
        
        do
        {
            let dictionaries = try DatabaseManager.shared.viewContext.fetch(fetchRequest)
            
            let categories = dictionaries.map { $0[#keyPath(StoreApp._category)] as? String? ?? nil }.map { rawCategory -> StoreCategory in
                guard let rawCategory else { return .other }
                return StoreCategory(rawValue: rawCategory) ?? .other
            }
            
            var sortedCategories = Set(categories).sorted(by: {
                self.translateCategoryName($0).localizedStandardCompare(self.translateCategoryName($1)) == .orderedAscending
            })
            if let otherIndex = sortedCategories.firstIndex(of: .other)
            {
                sortedCategories.move(fromOffsets: [otherIndex], toOffset: sortedCategories.count)
            }
            
            let actions = sortedCategories.map { category in
                let state: UIAction.State = (category == self.category) ? .on : .off
                let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(category.tintColor, renderingMode: .alwaysOriginal)
                return UIAction(title: self.translateCategoryName(category), image: image, state: state) { _ in
                    handler(category)
                }
            }
            
            return actions
        }
        catch
        {
            debugLog("Không thể tải danh sách danh mục. \(error.localizedDescription)")
            return []
        }
    }
    
    func prepareAppSorting()
    {
        if self.preferredAppSorting == .default && self.source == nil
        {
            self.preferredAppSorting = .lastUpdated
        }
        
        let children = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else { return completion([]) }
            
            var sortingOptions = AppSorting.allCases
            if self.source == nil
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
        
        let sortMenu = UIMenu(title: "Sắp xếp ứng dụng theo…", options: menuOptions, children: [children])
        let sortIcon = UIImage(systemName: "arrow.up.arrow.down.circle.fill")
        
        let sortButton = UIBarButtonItem(title: "Sắp xếp theo…", image: sortIcon, primaryAction: nil, menu: sortMenu)
        self.sortButton = sortButton
        self.navigationItem.rightBarButtonItems = [sortButton]
        
        // Gắn menu Sắp xếp trực tiếp vào nút viên thuốc trên Hero Banner
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
    
    // ✨ HIỆU ỨNG TRƯỢT LÊN (SLIDE-IN) MƯỢT MÀ KHI CUỘN DANH SÁCH ✨
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        if !self.animatedIndexPaths.contains(indexPath) {
            self.animatedIndexPaths.insert(indexPath)
            
            cell.alpha = 0
            cell.transform = CGAffineTransform(translationX: 0, y: 25).scaledBy(x: 0.97, y: 0.97)
            
            UIView.animate(withDuration: 0.5, delay: 0.03, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.5, options: [.curveEaseOut, .allowUserInteraction]) {
                cell.alpha = 1
                cell.transform = .identity
            }
        }
    }
    
    // ✨ HIỆU ỨNG NHÚN KHI BẤM VÀO THẺ ỨNG DỤNG ✨
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
