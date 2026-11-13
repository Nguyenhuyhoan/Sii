
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

// MARK: - 🎨 BỘ GIAO DIỆN CSS THEME (ĐỒNG BỘ VỚI SETTINGS)
private struct BrowseCSSTheme {
    static let white = UIColor.white
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0) // #f8f9fa
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0) // #e9ecef
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0) // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0) // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0) // #28a745
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0) // #ff00ff
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0) // #343a40
    
    // Gradient Background Colors (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor
    
    static let cornerRadius: CGFloat = 15.0
}

class BrowseViewController: UICollectionViewController
{
    // Nil == Show apps from all sources.
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
        
        self.collectionView.alwaysBounceVertical = true
        
        self.dataSource.searchableKeyPaths = [#keyPath(StoreApp.name),
                                               #keyPath(StoreApp.subtitle),
                                               #keyPath(StoreApp.developerName),
                                               #keyPath(StoreApp.bundleIdentifier)]
        #if !os(tvOS)
        self.navigationItem.searchController = self.dataSource.searchController
        #endif
        
        self.prototypeCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.register(AppCardCollectionViewCell.self, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        
        let collectionViewLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        collectionViewLayout.minimumLineSpacing = 22 // Khoảng cách vừa vặn, hiện đại hơn
        collectionViewLayout.sectionInset = UIEdgeInsets(top: 15, left: 0, bottom: 30, right: 0)
        
        #if !os(tvOS)
        self.registerForPreviewing(with: self, sourceView: self.collectionView)
        
        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.updateSources()
        })
        refreshControl.tintColor = BrowseCSSTheme.purple
        self.collectionView.refreshControl = refreshControl
        #endif
        
        #if !os(tvOS)
        if self.category != nil, #available(iOS 16, *)
        {
            let categoriesMenu = UIMenu(children: [
                UIDeferredMenuElement.uncached { [weak self] completion in
                    let actions = self?.makeCategoryActions() ?? []
                    completion(actions)
                }
            ])
            
            self.navigationItem.titleMenuProvider = { _ in categoriesMenu }
        }
        #endif
        
        self.titleSourceIconView = AppIconImageView(style: .circular)
        
        self.titleCategoryIconView = UIImageView(frame: .zero)
        self.titleCategoryIconView.contentMode = .scaleAspectFit
        
        self.titleLabel = UILabel()
        self.titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        self.titleLabel.textColor = BrowseCSSTheme.blue
        
        self.titleStackView = UIStackView(arrangedSubviews: [self.titleSourceIconView, self.titleCategoryIconView, self.titleLabel])
        self.titleStackView.spacing = 6
        self.titleStackView.alignment = .center
        self.titleStackView.translatesAutoresizingMaskIntoConstraints = false
        
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        
        if #available(iOS 16, *)
        {
            self.navigationItem.preferredSearchBarPlacement = .automatic
        }
        #endif
        
        self.prepareAppSorting()
        self.preparePipeline()
        
        NSLayoutConstraint.activate([
            self.titleSourceIconView.heightAnchor.constraint(equalToConstant: 26),
            self.titleSourceIconView.widthAnchor.constraint(equalTo: self.titleSourceIconView.heightAnchor),
            self.titleCategoryIconView.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        // ✨ ÁP DỤNG GIAO DIỆN CSS ✨
        self.applyBeautifulCSSTheme()
        
        self.updateDataSource()
        self.update()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Cập nhật khung nền Gradient khi xoay màn hình
        if let bgView = self.collectionView.backgroundView,
           let gradientLayer = bgView.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = self.collectionView.bounds
        }
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.update()
    }
    
    override func viewDidDisappear(_ animated: Bool) 
    {
        super.viewDidDisappear(animated)
        self.navigationController?.navigationBar.tintColor = nil
    }
}

// MARK: - ✨ HÀM CẤU HÌNH GIAO DIỆN CSS CHO BROWSE
private extension BrowseViewController {
    
    func applyBeautifulCSSTheme() {
        // 1. Nền Gradient (#f3e0ff -> #e0f7ff)
        let bgView = UIView(frame: self.collectionView.bounds)
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = self.collectionView.bounds
        gradientLayer.colors = [BrowseCSSTheme.bgGradientStart, BrowseCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        bgView.layer.insertSublayer(gradientLayer, at: 0)
        
        self.collectionView.backgroundView = bgView
        self.collectionView.backgroundColor = .clear
        
        // 2. Làm đẹp PlaceholderView (Khi đang tải hoặc không có app)
        self.placeholderView.textLabel.textColor = BrowseCSSTheme.blue
        self.placeholderView.textLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        self.placeholderView.detailTextLabel.textColor = BrowseCSSTheme.dark.withAlphaComponent(0.7)
        self.placeholderView.activityIndicatorView.color = BrowseCSSTheme.purple
        
        // 3. Làm đẹp thanh tìm kiếm (Search Bar Glassmorphism)
        #if !os(tvOS)
        if let searchBar = self.navigationItem.searchController?.searchBar {
            searchBar.tintColor = BrowseCSSTheme.purple
            searchBar.searchTextField.backgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.85)
            searchBar.searchTextField.textColor = BrowseCSSTheme.dark
            searchBar.searchTextField.layer.cornerRadius = 12
            searchBar.searchTextField.layer.masksToBounds = true
            searchBar.searchTextField.layer.borderWidth = 1
            searchBar.searchTextField.layer.borderColor = BrowseCSSTheme.border.cgColor
        }
        #endif
    }
    
    func styleAppCardCell(_ cell: AppCardCollectionViewCell, with tintColor: UIColor) {
        // Bo góc 15px và viền trắng mờ cho Banner
        cell.bannerView.layer.cornerRadius = BrowseCSSTheme.cornerRadius
        cell.bannerView.layer.masksToBounds = true
        cell.bannerView.layer.borderWidth = 1.5
        cell.bannerView.layer.borderColor = BrowseCSSTheme.white.withAlphaComponent(0.75).cgColor
        
        // Đổ bóng phát sáng theo màu của App (giống box-shadow: 0 10px 20px var(--tab-shadow))
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = tintColor.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 8)
        cell.layer.shadowRadius = 16
        cell.layer.shadowOpacity = 0.22
        
        // Đổ bóng phát sáng cho nút Tải/Mở (PillButton)
        let btn = cell.bannerView.button
        btn.layer.shadowColor = tintColor.cgColor
        btn.layer.shadowOffset = CGSize(width: 0, height: 4)
        btn.layer.shadowRadius = 8
        btn.layer.shadowOpacity = 0.35
        
        // Gắn hiệu ứng nhún khi bấm vào nút Tải/Mở
        btn.removeTarget(self, action: #selector(animatePillButtonPress(_:)), for: .touchDown)
        btn.removeTarget(self, action: #selector(animatePillButtonRelease(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        btn.addTarget(self, action: #selector(animatePillButtonPress(_:)), for: .touchDown)
        btn.addTarget(self, action: #selector(animatePillButtonRelease(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
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
            
            cell.bannerView.button.addTarget(self, action: #selector(BrowseViewController.performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.button.activityIndicatorView.style = .medium
            cell.bannerView.button.activityIndicatorView.color = .white
            
            let tintColor = app.tintColor ?? BrowseCSSTheme.blue
            cell.tintColor = tintColor
            
            // ✨ Áp dụng hiệu ứng Card 3D & Shadow theo màu của App ✨
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
                debugLog("Failed to load app icon from \(app.iconURL). \(error.localizedDescription)")
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
            self.placeholderView.textLabel.text = NSLocalizedString("No Apps", comment: "")
            self.placeholderView.textLabel.isHidden = false
            
            self.placeholderView.detailTextLabel.text = NSLocalizedString("Please make sure your spelling is correct, or try searching for another app.", comment: "")
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
                self.placeholderView.detailTextLabel.text = NSLocalizedString("Loading...", comment: "")
                self.placeholderView.activityIndicatorView.startAnimating()
                
            case .failure(let error):
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = false
                self.placeholderView.textLabel.text = NSLocalizedString("Unable to Fetch Apps", comment: "")
                self.placeholderView.detailTextLabel.text = error.localizedDescription
                self.placeholderView.activityIndicatorView.stopAnimating()
                
            case .success:
                self.placeholderView.textLabel.text = NSLocalizedString("No Apps", comment: "")
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = true
                self.placeholderView.activityIndicatorView.stopAnimating()
            }
        }
        
        let tintColor: UIColor
        
        if let source = self.source
        {
            tintColor = source.effectiveTintColor?.adjustedForDisplay ?? BrowseCSSTheme.blue
            
            self.title = source.name
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
                        debugLog("Failed to fetch source icon at \(iconURL). \(error.localizedDescription)")
                    }
                }
            }
        }
        else if let category = self.category
        {
            tintColor = category.tintColor
            
            self.title = category.localizedName
            
            let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
            self.titleCategoryIconView.image = image
            self.titleCategoryIconView.isHidden = false
            self.titleSourceIconView.isHidden = true
        }
        else
        {
            tintColor = BrowseCSSTheme.blue
            
            self.title = NSLocalizedString("Browse", comment: "")
            self.titleSourceIconView.isHidden = true
            self.titleCategoryIconView.isHidden = true
        }
        
        self.titleLabel.text = self.title
        self.titleLabel.textColor = tintColor
        self.titleStackView.sizeToFit()
        self.navigationItem.titleView = self.titleStackView
        
        self.view.tintColor = tintColor
        
        // ✨ CẤU HÌNH NAVIGATION BAR KÍNH MỜ (GLASSMORPHISM) ✨
        #if !os(tvOS)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.backgroundColor = BrowseCSSTheme.white.withAlphaComponent(0.75)
        appearance.titleTextAttributes = [
            .foregroundColor: tintColor,
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ]
        
        let edgeAppearance = appearance.copy()
        edgeAppearance.configureWithTransparentBackground()
        edgeAppearance.backgroundEffect = nil
        edgeAppearance.backgroundColor = .clear
        
        self.navigationItem.standardAppearance = appearance
        self.navigationItem.scrollEdgeAppearance = edgeAppearance
        #endif
        
        self.navigationController?.navigationBar.tintColor = tintColor
        
        if let sortButton
        {
            sortButton.image = sortButton.image?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        }
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
            
            var sortedCategories = Set(categories).sorted(by: { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending })
            if let otherIndex = sortedCategories.firstIndex(of: .other)
            {
                sortedCategories.move(fromOffsets: [otherIndex], toOffset: sortedCategories.count)
            }
            
            let actions = sortedCategories.map { category in
                let state: UIAction.State = (category == self.category) ? .on : .off
                let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(category.tintColor, renderingMode: .alwaysOriginal)
                return UIAction(title: category.localizedName, image: image, state: state) { _ in
                    handler(category)
                }
            }
            
            return actions
        }
        catch
        {
            debugLog("Failed to fetch categories. \(error.localizedDescription)")
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
                let action = UIAction(title: sorting.localizedName, image: nil, state: state) { action in
                    self.preferredAppSorting = sorting
                    UserDefaults.standard.preferredAppSorting = sorting
                    
                    self.updateDataSource()
                }
                
                return action
            }
            
            completion(actions)
        }
        
        let sortMenu = UIMenu(title: NSLocalizedString("Sort by…", comment: ""), options: [.singleSelection], children: [children])
        let sortIcon = UIImage(systemName: "arrow.up.arrow.down.circle.fill")
        
        let sortButton = UIBarButtonItem(title: NSLocalizedString("Sort by…", comment: ""), image: sortIcon, primaryAction: nil, menu: sortMenu)
        self.sortButton = sortButton
        
        self.navigationItem.rightBarButtonItems = [sortButton]
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
                debugLog("BrowseViewController.finish invoked with result: \(result) for \(app.bundleIdentifier)")
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(let error) where error is CancellationError: break
                    case .failure(let error):
                        let toastView = ToastView(error: error, opensLog: true)
                        toastView.show(in: self)
                        
                    case .success: debugLog("Installed app: \(app.bundleIdentifier)")
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
    
    // ✨ HIỆU ỨNG TRƯỢT LÊN (SLIDE-IN) KHI CUỘN DANH SÁCH (GIỐNG .gallery-item.is-visible) ✨
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
    
    // ✨ HIỆU ỨNG NHÚN KHI BẤM VÀO THẺ ỨNG DỤNG (GIỐNG .btn:active) ✨
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
        return appViewController
    }
    
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}
