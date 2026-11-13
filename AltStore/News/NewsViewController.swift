//
//  NewsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SafariServices
import CoreData
@preconcurrency import Nuke

extension NewsViewController
{
    private enum Section: Int, CaseIterable
    {
        case updates
        case news
    }
}

class NewsViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    private lazy var newsDataSource = self.makeNewsDataSource()
    private lazy var updatesDataSource = self.makeUpdatesDataSource()
    
    private lazy var placeholderView = PlaceholderView(frame: .zero)
    
    private var isFetching = false
    
    private var prototypeNewsCell: NewsCollectionViewCell!
    
    // MARK: - UIViewController -
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = AppStrings.News.title
        
        self.view.applyCSSBodyGradient()
        self.collectionView.backgroundColor = .clear
        self.applyCSSNavigationBar(tintColor: AppUI.Colors.blue, transparentEdge: true)
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        
        self.prototypeNewsCell = NewsCollectionViewCell.instantiate(with: NewsCollectionViewCell.nib!)
        self.prototypeNewsCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.register(NewsCollectionViewCell.nib, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        self.collectionView.register(AppBannerCollectionViewCell.nib, forCellWithReuseIdentifier: "AppBannerCell")
        
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = AppUI.Colors.blue
        refreshControl.addTarget(self, action: #selector(NewsViewController.fetchNews(_:)), for: .valueChanged)
        self.collectionView.refreshControl = refreshControl
        
        self.placeholderView.textLabel.isHidden = true
        self.placeholderView.detailTextLabel.isHidden = false
        self.placeholderView.detailTextLabel.textColor = AppUI.Colors.dark
        self.placeholderView.activityIndicatorView.color = AppUI.Colors.blue
        
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        #if !os(tvOS)
        if self.traitCollection.forceTouchCapability == .available
        {
            self.registerForPreviewing(with: self, sourceView: self.collectionView)
        }
        #endif

        NotificationCenter.default.addObserver(self, selector: #selector(NewsViewController.didFetchSource(_:)), name: AppManager.didFetchSourceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NewsViewController.didAddSource(_:)), name: AppManager.didAddSourceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(NewsViewController.didRemoveSource(_:)), name: AppManager.didRemoveSourceNotification, object: nil)
        
        self.updateDataSource()
        self.update()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.view.updateCSSBodyGradientFrame()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchNews(nil)
        self.applyCSSNavigationBar(tintColor: AppUI.Colors.blue, transparentEdge: true)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?)
    {
        super.traitCollectionDidChange(previousTraitCollection)
        
        self.collectionView.collectionViewLayout.invalidateLayout()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
}

private extension NewsViewController
{
    func makeDataSource() -> CompositeCollectionViewPrefetchingDataSource<NSManagedObject, UIImage>
    {
        let updatesDS = self.updatesDataSource as! CollectionViewPrefetchingDataSource<NSManagedObject, UIImage>
        let newsDS = self.newsDataSource as! CollectionViewPrefetchingDataSource<NSManagedObject, UIImage>
        
        let dataSource = CompositeCollectionViewPrefetchingDataSource<NSManagedObject, UIImage>(dataSources: [updatesDS, newsDS])
        dataSource.placeholderView = self.placeholderView
        
        return dataSource
    }
    
    func makeNewsDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<NewsItem, UIImage>
    {
        let fetchRequest = NewsItem.fetchRequest() as NSFetchRequest<NewsItem>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \NewsItem.date, ascending: false),
                                        NSSortDescriptor(keyPath: \NewsItem.sortIndex, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<NewsItem, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellConfigurationHandler = { [weak self] (cell, newsItem, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! NewsCollectionViewCell
            self.configure(cell, with: newsItem)
            
            if newsItem.imageURL != nil
            {
                cell.imageView.isHidden = false
                cell.imageView.image = nil
                cell.imageView.isIndicatingActivity = true
            }
            else
            {
                cell.imageView.isHidden = true
                cell.imageView.image = nil
                cell.imageView.isIndicatingActivity = false
            }
        }
        dataSource.prefetchHandler = { (newsItem, indexPath) in
            guard let imageURL = newsItem.imageURL else { return nil }
            return try await ImagePipeline.shared.image(for: imageURL)
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! NewsCollectionViewCell
            cell.imageView.isIndicatingActivity = false
            cell.imageView.image = image
            
            if let error = error
            {
                debugLog("Error loading news image: \(error)")
            }
        }
        
        return dataSource
    }
    
    func makeUpdatesDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest = InstalledApp.supportedUpdatesFetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.refreshedDate, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let updatesDataSource = FetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        updatesDataSource.liveFetchLimit = 1
        updatesDataSource.cellIdentifierHandler = { _ in "AppBannerCell" }
        updatesDataSource.cellConfigurationHandler = { (cell, installedApp, indexPath) in
            guard let storeApp = installedApp.storeApp else { return }
            
            let cell = cell as! AppBannerCollectionViewCell
            cell.bannerView.tintColor = storeApp.tintColor ?? AppUI.Colors.blue
            cell.bannerView.titleLabel.text = storeApp.name
            cell.bannerView.subtitleLabel.text = AppStrings.MyApps.updatesAvailable
            cell.bannerView.button.setTitle(AppStrings.Common.update.uppercased(), for: .normal)
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            cell.bannerView.accessibilityHint = "View recently updated apps."
            
            cell.bannerView.button.isUserInteractionEnabled = false
            cell.bannerView.button.accessibilityTraits.insert(.notEnabled)
            
            cell.layoutIfNeeded()
        }
        updatesDataSource.prefetchHandler = { (installedApp, indexPath) in
            guard let iconURL = installedApp.storeApp?.iconURL else { return nil }
            return try await ImagePipeline.shared.image(for: iconURL)
        }
        updatesDataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! AppBannerCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
        }
        
        return updatesDataSource
    }
    
    func configure(_ cell: NewsCollectionViewCell, with newsItem: NewsItem)
    {
        cell.titleLabel.text = newsItem.title
        cell.captionLabel.text = newsItem.caption
        cell.contentView.backgroundColor = newsItem.tintColor ?? AppUI.Colors.blue
        
        if newsItem.externalURL != nil || newsItem.storeApp != nil
        {
            cell.isUserInteractionEnabled = true
        }
        else
        {
            cell.isUserInteractionEnabled = false
        }
    }
}

private extension NewsViewController
{
    func updateDataSource()
    {
        let predicate = NewsItem.visibleNewsItemsPredicate
        self.newsDataSource.predicate = predicate
    }
    
    func update()
    {
        if self.isFetching
        {
            self.placeholderView.activityIndicatorView.startAnimating()
            
            self.placeholderView.textLabel.isHidden = true
            self.placeholderView.detailTextLabel.isHidden = false
            
            self.placeholderView.detailTextLabel.text = AppStrings.News.fetchingNews
        }
    }
    
    @objc func fetchNews(_ sender: UIRefreshControl?)
    {
        guard !self.isFetching else { return }
        self.isFetching = true
        
        if self.dataSource.itemCount == 0
        {
            self.update()
        }
        
        AppManager.shared.updateAllSources { (result) in
            DispatchQueue.main.async {
                self.isFetching = false
                
                switch result
                {
                case .success:
                    self.placeholderView.textLabel.text = AppStrings.News.noNewsAvailable
                    self.placeholderView.detailTextLabel.text = nil
                    
                    self.placeholderView.textLabel.isHidden = false
                    self.placeholderView.detailTextLabel.isHidden = true
                    
                case .failure(let error):
                    if self.dataSource.itemCount > 0
                    {
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentSources), for: .touchUpInside)
                        toastView.show(in: self)
                    }
                    
                    self.placeholderView.textLabel.text = AppStrings.News.unableToFetchNews
                    self.placeholderView.detailTextLabel.text = error.localizedDescription
                    
                    self.placeholderView.textLabel.isHidden = false
                    self.placeholderView.detailTextLabel.isHidden = false
                }
                
                self.placeholderView.activityIndicatorView.stopAnimating()
                self.collectionView.refreshControl?.endRefreshing()
                
                self.collectionView.reloadData()
            }
        }
    }
    
    @objc func didFetchSource(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.updateDataSource()
        }
    }
    
    @objc func didAddSource(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.updateDataSource()
            self.collectionView.reloadData()
        }
    }
    
    @objc func didRemoveSource(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.updateDataSource()
            self.collectionView.reloadData()
        }
    }
    
    func viewController(for newsItem: NewsItem) -> UIViewController?
    {
        if let externalURL = newsItem.externalURL
        {
            let safariViewController = SFSafariViewController(url: externalURL)
            safariViewController.preferredControlTintColor = newsItem.tintColor ?? AppUI.Colors.blue
            return safariViewController
        }
        else if let storeApp = newsItem.storeApp
        {
            let appViewController = AppViewController.makeAppViewController(app: storeApp)
            return appViewController
        }
        else
        {
            return nil
        }
    }
}

extension NewsViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let width = collectionView.bounds.width - (collectionView.layoutMargins.left + collectionView.layoutMargins.right)
        
        switch Section.allCases[indexPath.section]
        {
        case .updates:
            return CGSize(width: width, height: 88)
            
        case .news:
            let item = self.newsDataSource.item(at: indexPath)
            
            let previousWidthConstraint = self.prototypeNewsCell.contentView.constraints.first { $0.firstAttribute == .width }
            previousWidthConstraint?.isActive = false
            
            let widthConstraint = self.prototypeNewsCell.contentView.widthAnchor.constraint(equalToConstant: width)
            widthConstraint.isActive = true
            
            self.configure(self.prototypeNewsCell, with: item)
            self.prototypeNewsCell.imageView.isHidden = (item.imageURL == nil)
            
            let size = self.prototypeNewsCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            return size
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        let topInset: CGFloat = (section == Section.updates.rawValue) ? 10 : 20
        let bottomInset: CGFloat = (section == Section.updates.rawValue) ? 15 : 20
        
        return UIEdgeInsets(top: topInset, left: collectionView.layoutMargins.left, bottom: bottomInset, right: collectionView.layoutMargins.right)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        switch Section.allCases[indexPath.section]
        {
        case .updates:
            self.tabBarController?.selectedIndex = 2
            
            if let navigationController = self.tabBarController?.selectedViewController as? UINavigationController
            {
                navigationController.popToRootViewController(animated: false)
            }
            
        case .news:
            let newsItem = self.newsDataSource.item(at: indexPath)
            guard let viewController = self.viewController(for: newsItem) else { return }
            
            if newsItem.externalURL != nil
            {
                self.present(viewController, animated: true, completion: nil)
            }
            else if newsItem.storeApp != nil
            {
                self.navigationController?.pushViewController(viewController, animated: true)
            }
        }
    }
}

extension NewsViewController: UIViewControllerPreviewingDelegate
{
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard
            let indexPath = self.collectionView.indexPathForItem(at: location),
            let cell = self.collectionView.cellForItem(at: indexPath)
        else { return nil }
        
        previewingContext.sourceRect = cell.frame
        
        let newsItem = self.newsDataSource.item(at: indexPath)
        return self.viewController(for: newsItem)
    }
    
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        if viewControllerToCommit is SFSafariViewController
        {
            self.present(viewControllerToCommit, animated: true, completion: nil)
        }
        else
        {
            self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
        }
    }
}

4. File SourcesViewController.swift

(Đã xóa import AltStoreCore & import Roxas, cập nhật DataSource và Nuke.ImagePipeline)

//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/8/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
import SafariServices
@preconcurrency import Nuke

extension SourcesViewController
{
    private enum Section: Int, CaseIterable
    {
        case existingSources
        case recommendedSources
    }
}

final class SourcesViewController: UICollectionViewController
{
    // MARK: - Properties
    private lazy var dataSource = self.makeDataSource()
    private lazy var existingSourcesDataSource = self.makeExistingSourcesDataSource()
    private lazy var recommendedSourcesDataSource = self.makeRecommendedSourcesDataSource()
    
    private lazy var placeholderView = PlaceholderView(frame: .zero)
    
    private var isFetchingRecommendedSources = false
    private var fetchError: Error?
    
    private var addingSourceIndexPath: IndexPath?
    
    // MARK: - UIViewController
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = AppStrings.Sources.title
        
        // 1. Áp dụng CSS Body Gradient & Navigation Bar
        self.view.applyCSSBodyGradient()
        self.collectionView.backgroundColor = .clear
        self.navigationController?.applyCSSNavigationBar()
        
        let collectionViewLayout = self.makeLayout()
        self.collectionView.collectionViewLayout = collectionViewLayout
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        
        self.placeholderView.textLabel.isHidden = true
        self.placeholderView.detailTextLabel.isHidden = false
        self.placeholderView.detailTextLabel.textColor = AppUI.Colors.textSecondary
        self.placeholderView.activityIndicatorView.color = AppUI.Colors.primaryPurple
        
        let addSourceBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(SourcesViewController.promptToAddSource))
        self.navigationItem.leftBarButtonItem = addSourceBarButtonItem
        
        NotificationCenter.default.addObserver(self, selector: #selector(SourcesViewController.didAddSource(_:)), name: AppManager.didAddSourceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SourcesViewController.didRemoveSource(_:)), name: AppManager.didRemoveSourceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SourcesViewController.themeDidChange), name: .themeDidChange, object: nil)
        
        self.fetchRecommendedSources()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.navigationController?.applyCSSNavigationBar()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.view.updateCSSGradientFrame()
    }
    
    @objc private func themeDidChange()
    {
        self.view.applyCSSBodyGradient()
        self.navigationController?.applyCSSNavigationBar()
        self.collectionView.reloadData()
    }
}

private extension SourcesViewController
{
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let layoutConfig = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfig.interSectionSpacing = 20
        layoutConfig.contentInsetsReference = .safeArea
        
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            guard let sectionType = Section(rawValue: sectionIndex) else { return nil }
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.interGroupSpacing = 12
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 16, trailing: 16)
            
            switch sectionType
            {
            case .existingSources, .recommendedSources:
                break
            }
            
            return layoutSection
        }, configuration: layoutConfig)
        
        return layout
    }
    
    func makeDataSource() -> CompositeCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let dataSource = CompositeCollectionViewPrefetchingDataSource<Source, UIImage>(dataSources: [self.existingSourcesDataSource, self.recommendedSourcesDataSource])
        dataSource.placeholderView = self.placeholderView
        dataSource.cellConfigurationHandler = { [weak self] (cell, source, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! AppBannerCollectionViewCell
            
            // Áp dụng CSS Card Style (Nền trắng, bo góc 18px, đổ bóng chuẩn CSS)
            cell.contentView.applyCSSCardStyle(cornerRadius: AppUI.Layout.cardCornerRadius)
            
            cell.bannerView.titleLabel.text = source.name
            cell.bannerView.subtitleLabel.text = source.sourceURL.host ?? source.sourceURL.absoluteString
            cell.bannerView.iconImageView.image = nil
            
            let tintColor = source.effectiveTintColor ?? AppUI.Colors.primaryPurple
            cell.bannerView.tintColor = tintColor
            
            cell.bannerView.button.removeTarget(self, action: nil, for: .primaryActionTriggered)
            
            switch Section.allCases[indexPath.section]
            {
            case .existingSources:
                cell.bannerView.button.isHidden = (source.identifier == Source.altStoreIdentifier)
                cell.bannerView.button.setTitle("–", for: .normal)
                cell.bannerView.button.accessibilityLabel = AppStrings.Common.remove
                cell.bannerView.button.backgroundColor = AppUI.Colors.dangerRed.withAlphaComponent(0.15)
                cell.bannerView.button.setTitleColor(AppUI.Colors.dangerRed, for: .normal)
                cell.bannerView.button.layer.cornerRadius = 14
                cell.bannerView.button.addTarget(self, action: #selector(SourcesViewController.handleSourceActionButton(_:)), for: .primaryActionTriggered)
                
            case .recommendedSources:
                cell.bannerView.button.isHidden = false
                cell.bannerView.button.setTitle("+", for: .normal)
                cell.bannerView.button.accessibilityLabel = AppStrings.Common.add
                cell.bannerView.button.backgroundColor = AppUI.Colors.primaryPurple.withAlphaComponent(0.15)
                cell.bannerView.button.setTitleColor(AppUI.Colors.primaryPurple, for: .normal)
                cell.bannerView.button.layer.cornerRadius = 14
                cell.bannerView.button.addTarget(self, action: #selector(SourcesViewController.handleSourceActionButton(_:)), for: .primaryActionTriggered)
            }
            
            cell.bannerView.button.isIndicatingActivity = (self.addingSourceIndexPath == indexPath)
            cell.layoutIfNeeded()
        }
        dataSource.prefetchHandler = { (source, indexPath) in
            guard let imageURL = source.effectiveIconURL else { return nil }
            return try await ImagePipeline.shared.image(for: imageURL)
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! AppBannerCollectionViewCell
            if let image = image
            {
                cell.bannerView.iconImageView.image = image
            }
        }
        
        return dataSource
    }
    
    func makeExistingSourcesDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let fetchRequest = Source.fetchRequest() as NSFetchRequest<Source>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Source.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        return dataSource
    }
    
    func makeRecommendedSourcesDataSource() -> ArrayCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let dataSource = ArrayCollectionViewPrefetchingDataSource<Source, UIImage>(items: [])
        return dataSource
    }
}

private extension SourcesViewController
{
    @objc func handleSourceActionButton(_ sender: UIButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        let source = self.dataSource.item(at: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .existingSources:
            self.confirmRemove(source)
        case .recommendedSources:
            self.addSource(at: source.sourceURL, indexPath: indexPath)
        }
    }
    
    @objc func promptToAddSource()
    {
        let alertController = UIAlertController(title: AppStrings.Sources.addSource, message: AppStrings.Sources.addSourceDescription, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "https://..."
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        
        alertController.addAction(UIAlertAction(title: AppStrings.Common.cancel, style: .cancel, handler: nil))
        
        let addAction = UIAlertAction(title: AppStrings.Common.add, style: .default) { [weak self, weak alertController] _ in
            guard let self = self, let text = alertController?.textFields?.first?.text else { return }
            
            let urls = text.components(separatedBy: .whitespacesAndNewlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .compactMap { URL(string: $0) }
            
            guard let firstURL = urls.first else { return }
            self.addSource(at: firstURL, indexPath: nil)
        }
        alertController.addAction(addAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func addSource(at sourceURL: URL, indexPath: IndexPath?)
    {
        self.addingSourceIndexPath = indexPath
        
        if let indexPath = indexPath, let cell = self.collectionView.cellForItem(at: indexPath) as? AppBannerCollectionViewCell
        {
            cell.bannerView.button.isIndicatingActivity = true
        }
        
        AppManager.shared.addSource(sourceURL: sourceURL) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result
                {
                case .failure(let error):
                    self.finishAddingSource(with: .failure(error))
                case .success:
                    self.finishAddingSource(with: .success(()))
                }
            }
        }
    }
    
    func finishAddingSource(with result: Result<Void, Error>)
    {
        let previousIndexPath = self.addingSourceIndexPath
        self.addingSourceIndexPath = nil
        
        if let indexPath = previousIndexPath, let cell = self.collectionView.cellForItem(at: indexPath) as? AppBannerCollectionViewCell
        {
            cell.bannerView.button.isIndicatingActivity = false
        }
        
        switch result
        {
        case .failure(let error):
            let toastView = ToastView(error: error)
            toastView.show(in: self)
            
        case .success:
            break
        }
    }
    
    func confirmRemove(_ source: Source)
    {
        let alertController = UIAlertController(title: AppStrings.Common.remove + " “\(source.name)”?", message: AppStrings.Sources.removeSourceConfirmation, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: AppStrings.Common.cancel, style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: AppStrings.Common.remove, style: .destructive) { [weak self] _ in
            self?.remove(source)
        })
        
        if let popover = alertController.popoverPresentationController
        {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func remove(_ source: Source)
    {
        AppManager.shared.remove(source) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                    
                case .success:
                    break
                }
            }
        }
    }
    
    func fetchRecommendedSources()
    {
        guard !self.isFetchingRecommendedSources else { return }
        self.isFetchingRecommendedSources = false
    }
    
    @objc func didAddSource(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    @objc func didRemoveSource(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    @IBSegueAction
    func makeNewsViewController(_ coder: NSCoder) -> UIViewController?
    {
        return NewsViewController(coder: coder)
    }
}
