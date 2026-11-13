
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
