
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

class BrowseViewController: UICollectionViewController {
    let source: Source?

    private(set) var category: StoreCategory? {
        didSet { updateDataSource(); update() }
    }

    var searchPredicate: NSPredicate? {
        didSet { updateDataSource() }
    }

    private lazy var dataSource = makeDataSource()
    private lazy var placeholderView = PlaceholderView(frame: .zero)

    private let prototypeCell = AppCardCollectionViewCell(frame: .zero)
    private var sortButton: UIBarButtonItem?
    private var preferredAppSorting: AppSorting = UserDefaults.standard.preferredAppSorting
    private var cancellables = Set<AnyCancellable>()

    private var titleStackView: UIStackView!
    private var titleSourceIconView: AppIconImageView!
    private var titleCategoryIconView: UIImageView!
    private var titleLabel: UILabel!
    private var cachedItemSizes = [String: CGSize]()

    @IBOutlet private var sourcesBarButtonItem: UIBarButtonItem!

    init?(source: Source?, coder: NSCoder) {
        self.source = source; self.category = nil
        super.init(coder: coder)
    }

    init?(category: StoreCategory?, coder: NSCoder) {
        self.source = nil; self.category = category
        super.init(coder: coder)
    }

    required init?(coder: NSCoder) {
        self.source = nil; self.category = nil
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear
        view.applyCSSBodyGradient()
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true

        // Áp dụng giao diện Thẻ chuẩn CSS từ ThemeManager cho Placeholder
        placeholderView.textLabel.applySectionTitle(text: "")
        placeholderView.detailTextLabel.textColor = AppUI.Colors.dark
        placeholderView.activityIndicatorView.color = AppUI.Colors.blue
        placeholderView.stackView.spacing = 12
        placeholderView.stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20)
        placeholderView.stackView.isLayoutMarginsRelativeArrangement = true
        placeholderView.stackView.applyCSSCardStyle()

        dataSource.searchableKeyPaths = [#keyPath(StoreApp.name), #keyPath(StoreApp.subtitle), #keyPath(StoreApp.developerName), #keyPath(StoreApp.bundleIdentifier)]
        #if !os(tvOS)
        navigationItem.searchController = dataSource.searchController
        #endif

        prototypeCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(AppCardCollectionViewCell.self, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        collectionView.dataSource = dataSource
        collectionView.prefetchDataSource = dataSource
        dataSource.contentView = collectionView

        (collectionViewLayout as! UICollectionViewFlowLayout).minimumLineSpacing = 24

        #if !os(tvOS)
        registerForPreviewing(with: self, sourceView: collectionView)
        let rc = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in self?.updateSources() })
        rc.tintColor = AppUI.Colors.blue
        collectionView.refreshControl = rc

        if category != nil, #available(iOS 16, *) {
            let categoriesMenu = UIMenu(children: [
                UIDeferredMenuElement.uncached { [weak self] completion in completion(self?.makeCategoryActions() ?? []) }
            ])
            navigationItem.titleMenuProvider = { _ in categoriesMenu }
        }
        #endif

        titleSourceIconView = AppIconImageView(style: .circular)
        titleCategoryIconView = UIImageView(frame: .zero)
        titleCategoryIconView.contentMode = .scaleAspectFit

        titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = AppUI.Colors.dark

        titleStackView = UIStackView(arrangedSubviews: [titleSourceIconView, titleCategoryIconView, titleLabel])
        titleStackView.spacing = 6
        titleStackView.translatesAutoresizingMaskIntoConstraints = false

        #if !os(tvOS)
        navigationItem.largeTitleDisplayMode = .never
        if #available(iOS 16, *) { navigationItem.preferredSearchBarPlacement = .automatic }
        #endif

        prepareAppSorting()
        preparePipeline()

        NSLayoutConstraint.activate([
            titleSourceIconView.heightAnchor.constraint(equalToConstant: 26),
            titleSourceIconView.widthAnchor.constraint(equalTo: titleSourceIconView.heightAnchor),
            titleCategoryIconView.heightAnchor.constraint(equalToConstant: 26)
        ])

        updateDataSource()
        update()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.updateCSSBodyGradientFrame()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        navigationController?.navigationBar.tintColor = nil
    }
}

private extension BrowseViewController {
    func preparePipeline() {
        AppManager.shared.$updateSourcesResult
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)
    }

    func makeFetchRequest() -> NSFetchRequest<StoreApp> {
        let fetchRequest = StoreApp.fetchRequest() as NSFetchRequest<StoreApp>
        fetchRequest.returnsObjectsAsFaults = false

        let predicate = StoreApp.visibleAppsPredicate
        if let source {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [NSPredicate(format: "%K == %@", #keyPath(StoreApp._source), source), predicate])
        } else if let category {
            let catPredicate = (category == .other) ? StoreApp.otherCategoryPredicate : NSPredicate(format: "%K == %@", #keyPath(StoreApp._category), category.rawValue)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [catPredicate, predicate])
        } else {
            fetchRequest.predicate = predicate
        }

        var sortDescriptors = [
            NSSortDescriptor(keyPath: \StoreApp.name, ascending: true),
            NSSortDescriptor(keyPath: \StoreApp.bundleIdentifier, ascending: true),
            NSSortDescriptor(keyPath: \StoreApp.sourceIdentifier, ascending: true)
        ]

        switch preferredAppSorting {
        case .default: sortDescriptors.insert(NSSortDescriptor(keyPath: \StoreApp.sortIndex, ascending: preferredAppSorting.isAscending), at: 0)
        case .name: break
        case .developer: sortDescriptors.insert(NSSortDescriptor(keyPath: \StoreApp.developerName, ascending: preferredAppSorting.isAscending), at: 0)
        case .lastUpdated: sortDescriptors.insert(NSSortDescriptor(keyPath: \StoreApp.latestSupportedVersion?.date, ascending: preferredAppSorting.isAscending), at: 0)
        }

        fetchRequest.sortDescriptors = sortDescriptors
        return fetchRequest
    }

    func makeDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage> {
        let context = source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let ds = FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>(fetchRequest: makeFetchRequest(), managedObjectContext: context)
        ds.placeholderView = placeholderView
        ds.cellConfigurationHandler = { [weak self] (cell, app, _) in
            guard let self else { return }
            let cell = cell as! AppCardCollectionViewCell
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right

            cell.configure(for: app, showSourceIcon: self.source == nil)
            cell.bannerView.applyCSSBannerShadow()

            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true

            cell.bannerView.button.addTarget(self, action: #selector(performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.button.activityIndicatorView.style = .medium
            cell.bannerView.button.activityIndicatorView.color = AppUI.Colors.white
            cell.tintColor = app.tintColor ?? AppUI.Colors.blue
        }
        ds.prefetchHandler = { (storeApp, _) in
            let image = try await ImagePipeline.shared.image(for: storeApp.iconURL)
            return await Task.detached(priority: .userInitiated) {
                _ = image.isPredominantlyLight
                _ = image.withDropShadow(color: .black, radius: 4, offset: CGSize(width: 0, height: 1.5), opacity: 0.25)
                return image
            }.value
        }
        ds.prefetchCompletionHandler = { [weak ds] (cell, image, indexPath, error) in
            let cell = cell as! AppCardCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
            if let error, let ds {
                debugLog("Failed to load app icon from \(ds.item(at: indexPath).iconURL). \(error.localizedDescription)")
            }
        }
        return ds
    }

    func updateDataSource() {
        let context = source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        dataSource.fetchedResultsController = NSFetchedResultsController(fetchRequest: makeFetchRequest(), managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        dataSource.predicate = searchPredicate
    }

    func updateSources() {
        AppManager.shared.updateAllSources { result in
            #if !os(tvOS)
            self.collectionView.refreshControl?.endRefreshing()
            #endif
            if case .failure(let error) = result, self.dataSource.itemCount > 0 {
                let toastView = ToastView(error: error)
                toastView.addTarget(nil, action: #selector(TabBarController.presentSources), for: .touchUpInside)
                toastView.show(in: self)
            }
        }
    }

    func update() {
        if searchPredicate != nil {
            placeholderView.textLabel.text = AppStrings.Browse.noApps
            placeholderView.textLabel.isHidden = false
            placeholderView.detailTextLabel.text = AppStrings.Browse.searchNoAppsDetail
            placeholderView.detailTextLabel.isHidden = false
            placeholderView.activityIndicatorView.stopAnimating()
        } else {
            switch AppManager.shared.updateSourcesResult {
            case nil:
                placeholderView.textLabel.isHidden = true
                placeholderView.detailTextLabel.isHidden = false
                placeholderView.detailTextLabel.text = AppStrings.Browse.loading
                placeholderView.activityIndicatorView.startAnimating()
            case .failure(let error):
                placeholderView.textLabel.isHidden = false
                placeholderView.detailTextLabel.isHidden = false
                placeholderView.textLabel.text = AppStrings.Browse.unableToFetchApps
                placeholderView.detailTextLabel.text = error.localizedDescription
                placeholderView.activityIndicatorView.stopAnimating()
            case .success:
                placeholderView.textLabel.text = AppStrings.Browse.noApps
                placeholderView.textLabel.isHidden = false
                placeholderView.detailTextLabel.isHidden = true
                placeholderView.activityIndicatorView.stopAnimating()
            }
        }

        let tintColor: UIColor
        if let source {
            tintColor = source.effectiveTintColor?.adjustedForDisplay ?? AppUI.Colors.blue
            title = source.name
            titleSourceIconView.backgroundColor = tintColor
            titleSourceIconView.isHidden = false
            titleCategoryIconView.isHidden = true

            if let iconURL = source.effectiveIconURL {
                Task { [weak self] in
                    if let image = try? await ImagePipeline.shared.image(for: iconURL) {
                        self?.titleSourceIconView.image = image
                        self?.titleSourceIconView.backgroundColor = AppUI.Colors.white
                    }
                }
            }
        } else if let category {
            tintColor = category.tintColor
            title = category.localizedName
            titleCategoryIconView.image = UIImage(systemName: category.filledSymbolName)?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
            titleCategoryIconView.isHidden = false
            titleSourceIconView.isHidden = true
        } else {
            tintColor = AppUI.Colors.blue
            title = AppStrings.Browse.title
            titleSourceIconView.isHidden = true
            titleCategoryIconView.isHidden = true
        }

        titleLabel.text = title
        titleStackView.sizeToFit()
        navigationItem.titleView = titleStackView
        view.tintColor = tintColor

        // Đồng bộ thanh Navigation Bar kính mờ từ ThemeManager
        applyCSSNavigationBar(tintColor: tintColor, transparentEdge: true)

        if let sortButton {
            sortButton.image = sortButton.image?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        }
    }

    func makeCategoryActions() -> [UIAction] {
        let fetchRequest = NSFetchRequest<NSDictionary>(entityName: StoreApp.entity().name!)
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.returnsDistinctResults = true
        fetchRequest.propertiesToFetch = [#keyPath(StoreApp._category)]
        fetchRequest.predicate = StoreApp.visibleAppsPredicate

        guard let dictionaries = try? DatabaseManager.shared.viewContext.fetch(fetchRequest) else { return [] }
        let categories = dictionaries.map { ($0[#keyPath(StoreApp._category)] as? String).flatMap(StoreCategory.init(rawValue:)) ?? .other }

        var sorted = Set(categories).sorted { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }
        if let otherIdx = sorted.firstIndex(of: .other) { sorted.move(fromOffsets: [otherIdx], toOffset: sorted.count) }

        return sorted.map { cat in
            let image = UIImage(systemName: cat.filledSymbolName)?.withTintColor(cat.tintColor, renderingMode: .alwaysOriginal)
            return UIAction(title: cat.localizedName, image: image, state: (cat == self.category) ? .on : .off) { [weak self] _ in
                self?.category = cat
            }
        }
    }

    func prepareAppSorting() {
        if preferredAppSorting == .default && source == nil { preferredAppSorting = .lastUpdated }

        let children = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else { return completion([]) }
            let options = (self.source == nil) ? AppSorting.allCases.filter { $0 != .default } : AppSorting.allCases
            completion(options.map { sorting in
                UIAction(title: sorting.localizedName, state: (sorting == self.preferredAppSorting) ? .on : .off) { _ in
                    self.preferredAppSorting = sorting
                    UserDefaults.standard.preferredAppSorting = sorting
                    self.updateDataSource()
                }
            })
        }

        let sortMenu = UIMenu(title: AppStrings.Browse.sortBy, options: [.singleSelection], children: [children])
        let btn = UIBarButtonItem(title: AppStrings.Browse.sortBy, image: UIImage(systemName: "arrow.up.arrow.down"), primaryAction: nil, menu: sortMenu)
        sortButton = btn
        navigationItem.rightBarButtonItems = [btn]
    }

    @IBAction func performAppAction(_ sender: PillButton) {
        let point = collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = collectionView.indexPathForItem(at: point) else { return }
        let app = dataSource.item(at: indexPath)

        if let installedApp = app.installedApp, !installedApp.hasUpdate {
            UIApplication.shared.open(installedApp.openAppURL)
        } else {
            install(app, at: indexPath) { sender.progress = $0 }
        }
    }

    func install(_ app: StoreApp, at indexPath: IndexPath, progressUpdateHandler: @escaping (Progress) -> Void) {
        InstallAppDialog.present(storeApp: app, from: self) { [weak self] in
            guard let self else { return }
            if let prev = AppManager.shared.installationProgress(for: app) { prev.cancel(); return }

            func finish(_ result: Result<InstalledApp, Error>) {
                DispatchQueue.main.async {
                    if case .failure(let error) = result, !(error is CancellationError) {
                        ToastView(error: error, opensLog: true).show(in: self)
                    }
                    UIView.performWithoutAnimation {
                        if let ip = self.dataSource.fetchedResultsController.indexPath(forObject: app) {
                            self.collectionView.reloadItems(at: [ip])
                        } else {
                            self.collectionView.reloadData()
                        }
                    }
                }
            }

            if let installedApp = app.installedApp, installedApp.hasUpdate {
                progressUpdateHandler(AppManager.shared.update(installedApp, presentingViewController: self, completionHandler: finish(_:)))
            } else {
                progressUpdateHandler(AppManager.shared.install(.app(app), presentingViewController: self, completionHandler: finish(_:)).progress)
            }
        }
    }
}

extension BrowseViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let item = dataSource.item(at: indexPath)
        let itemID = item.globallyUniqueID ?? item.bundleIdentifier
        if let previousSize = cachedItemSizes[itemID] { return previousSize }

        dataSource.cellConfigurationHandler(prototypeCell, item, indexPath)
        let insets = view.layoutMargins.left + view.layoutMargins.right
        let widthConstraint = prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionView.bounds.width - insets)
        widthConstraint.isActive = true
        defer { widthConstraint.isActive = false }

        prototypeCell.frame.size.width = widthConstraint.constant
        prototypeCell.layoutIfNeeded()

        let itemSize = prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        cachedItemSizes[itemID] = itemSize
        return itemSize
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let appVC = AppViewController.makeAppViewController(app: dataSource.item(at: indexPath))
        (navigationController ?? presentingViewController?.navigationController)?.pushViewController(appVC, animated: true)
    }
}

extension BrowseViewController: UIViewControllerPreviewingDelegate {
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
        guard let indexPath = collectionView.indexPathForItem(at: location),
              let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        previewingContext.sourceRect = cell.frame
        return AppViewController.makeAppViewController(app: dataSource.item(at: indexPath))
    }

    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
        navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}
