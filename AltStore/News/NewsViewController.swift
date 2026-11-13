
//
//  NewsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SafariServices
import CoreData
import Combine
import Network
import Minimuxer
import SwiftUI
import Nuke

extension NewsViewController
{
    private enum Section: Int, CaseIterable
    {
        case announcements
        case news
    }
    
    // Necessary until Xcode 11 beta 7 properly resolves ambiguous method requirement compilation error.
    fileprivate static var sectionCount: Int {
        return Section.allCases.count
    }
}

class NewsViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    private lazy var announcementsDataSource = self.makeAnnouncementsDataSource()
    private lazy var newsDataSource = self.makeNewsDataSource()
    
    private lazy var placeholderView =PlaceholderView(textViewType: UILabel.self, detailTextViewType: UIButton.self)
    
    private var isPresentingViewController = false
    
    private var expandedAnnouncements = Set<NewsItem>()
    
    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        return dateFormatter
    }()

    // Add publisher to observe AppManager's state
    private var cancellables = Set<AnyCancellable>()
    private var pathMonitor: NWPathMonitor?

    private let appManager = AppManager.shared
    private var hasInitiallyLoaded = false

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Ensure network observer is set up during initial load
        self.setupNetworkObserver()
        
        self.collectionView.backgroundColor = .altBackground
        
        self.collectionView.register(NewsCollectionViewCell.self, forCellWithReuseIdentifier: "NewsCell")
        self.collectionView.register(AnnouncementCollectionViewCell.self, forCellWithReuseIdentifier: "AnnouncementCell")
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(NewsViewController.fetchPatrons(_:)), for: .valueChanged)
        self.collectionView.refreshControl = refreshControl
        
        if let flowLayout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        {
            flowLayout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        }
        
        self.navigationController?.navigationBar.prefersLargeTitles = true
        
        self.dataSource. fetchedResultsController.ManagedObjectContext = DatabaseManager.shared.viewContext

        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchNews()
        
        self.isPresentingViewController = false
        
        self.updateDataSource()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if !hasInitiallyLoaded {
            hasInitiallyLoaded = true
            fetchNews()
        }
        update()  // call update directly without delay since setup happens in viewDidLoad
    }
    
    deinit {
        pathMonitor?.cancel()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let identifier = segue.identifier else { return }
        
        switch identifier
        {
        case "showApp":
            guard let app = sender as? StoreApp else { break }
            
            let appViewController = segue.destination as! AppViewController
            appViewController.app = app
            
        default: break
        }
    }
}

private extension NewsViewController
{
    func makeDataSource() -> CompositeCollectionViewPrefetchingDataSource<NewsItem, UIImage>
    {
        let dataSource = CompositeCollectionViewPrefetchingDataSource<NewsItem, UIImage>(dataSources: [self.announcementsDataSource, self.newsDataSource])
        
        self.placeholderView.textLabel.isHidden = true
        
        self.placeholderView.detailTextLabel.titleLabel?.textAlignment = .center
        self.placeholderView.detailTextLabel.titleLabel?.numberOfLines = 0
        self.placeholderView.detailTextLabel.setTitleColor(.altPrimary, for: .normal)
        self.placeholderView.detailTextLabel.addTarget(self, action: #selector(NewsViewController.fetchNews), for: .touchUpInside)
        
        self.placeholderView.activityIndicatorView.color = .white
        
        dataSource.placeholderView = self.placeholderView
        
        return dataSource
    }
    
    func makeAnnouncementsDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<NewsItem, UIImage>
    {
        let fetchRequest = NewsItem.fetchRequest() as NSFetchRequest<NewsItem>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \NewsItem.date, ascending: false),
                                        NSSortDescriptor(keyPath: \NewsItem.sortIndex, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<NewsItem, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.predicate = NSPredicate(format: "%K == nil AND %K == nil", #keyPath(NewsItem.imageURL), #keyPath(NewsItem.app))
        dataSource.cellIdentifierHandler = { _ in "AnnouncementCell" }
        dataSource.cellConfigurationHandler = { [weak self] (cell, newsItem, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! AnnouncementCollectionViewCell
            cell.titleLabel.text = newsItem.title
            cell.captionLabel.text = newsItem.caption
            
            cell.contentBackgroundView.backgroundColor = newsItem.tintColor ?? .altPrimary
            cell.blurVisualEffectView.backgroundColor = newsItem.tintColor ?? .altPrimary
            
            cell.isCollapsed = !self.expandedAnnouncements.contains(newsItem)
            cell.accessibilityHint = cell.isCollapsed ? AppStrings.News.doubleTapToExpand : AppStrings.News.doubleTapToCollapse
            
            if newsItem.externalURL != nil
            {
                let image = UIImage(systemName: "safari")
                cell.actionButton.setImage(image, for: .normal)
                cell.actionButton.isHidden = false
                
                cell.actionButton.accessibilityLabel = String(format: AppStrings.News.openInBrowser, newsItem.title)
            }
            else if let storeApp = newsItem.app
            {
                let image = UIImage(systemName: "arrow.up.right.square.fill")
                cell.actionButton.setImage(image, for: .normal)
                cell.actionButton.isHidden = false
                
                cell.actionButton.accessibilityLabel = String(format: AppStrings.News.viewApp, storeApp.name)
            }
            else
            {
                cell.actionButton.isHidden = true
            }
            
            cell.actionButton.tag = indexPath.item
            cell.actionButton.addTarget(self, action: #selector(NewsViewController.performAnnouncementAction(_:)), for: .touchUpInside)
            
            cell.layoutIfNeeded()
        }
        
        return dataSource
    }
    
    func makeNewsDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<NewsItem, UIImage>
    {
        let fetchRequest = NewsItem.fetchRequest() as NSFetchRequest<NewsItem>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \NewsItem.date, ascending: false),
                                        NSSortDescriptor(keyPath: \NewsItem.sortIndex, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<NewsItem, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.predicate = NSPredicate(format: "%K != nil OR %K != nil", #keyPath(NewsItem.imageURL), #keyPath(NewsItem.app))
        dataSource.cellIdentifierHandler = { _ in "NewsCell" }
        dataSource.cellConfigurationHandler = { [weak self] (cell, newsItem, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! NewsCollectionViewCell
            cell.titleLabel.text = newsItem.title
            cell.captionLabel.text = newsItem.caption
            cell.dateLabel.text = self.dateFormatter.string(from: newsItem.date).uppercased()
            
            cell.contentBackgroundView.backgroundColor = newsItem.tintColor ?? .altPrimary
            cell.imageView.backgroundColor = newsItem.tintColor ?? .altPrimary
            
            cell.imageView.image = nil
            cell.imageView.isHidden = (newsItem.imageURL == nil)
            
            if let storeApp = newsItem.app
            {
                cell.appBannerView.isHidden = false
                cell.appBannerView.configure(for: storeApp)
                
                cell.appBannerView.button.tag = indexPath.item
                cell.appBannerView.button.addTarget(self, action: #selector(NewsViewController.performStoreAppAction(_:)), for: .touchUpInside)
                
                let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(NewsViewController.handleTapAppBanner(_:)))
                cell.appBannerView.addGestureRecognizer(tapGestureRecognizer)
                
                cell.appBannerView.iconImageView.image = nil
                cell.appBannerView.accessibilityTraits.insert(.button)
                
                if newsItem.externalURL == nil
                {
                    // Set cell's accessibilityHint since the entire cell navigates to the same place as appBannerView.
                    cell.accessibilityHint = String(format: AppStrings.News.opensProfilePage, storeApp.name)
                    cell.appBannerView.accessibilityHint = nil
                }
                else
                {
                    // Set appBannerView's accessibilityHint since tapping the cell goes to a different place.
                    cell.accessibilityHint = nil
                    cell.appBannerView.accessibilityHint = String(format: AppStrings.News.opensProfilePage, storeApp.name)
                }
            }
            else
            {
                cell.appBannerView.isHidden = true
                cell.accessibilityHint = nil
            }
            
            if newsItem.externalURL != nil
            {
                cell.accessibilityTraits.insert(.link)
            }
            else
            {
                cell.accessibilityTraits.remove(.link)
            }
            
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
        }
        dataSource.prefetchHandler = { (newsItem, indexPath, completionHandler) in
            let imageURL: URL?
            if let url = newsItem.imageURL
            {
                imageURL = url
            }
            else if let app = newsItem.app
            {
                imageURL = app.iconURL
            }
            else
            {
                imageURL = nil
            }
            
            guard let url = imageURL else { return nil }
            
            return RSTAsyncBlockOperation() { (operation) in
                ImagePipeline.shared.loadImage(with: url, progress: nil) { result in
                    guard !operation.isCancelled else { return operation.finish() }
                    
                    switch result
                    {
                    case .success(let response): completionHandler(response.image, nil)
                    case .failure(let error): completionHandler(nil, error)
                    }
                    
                    operation.finish()
                }
            }
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! NewsCollectionViewCell
            cell.imageView.image = image
            cell.appBannerView.iconImageView.image = image
            
            if let error = error
            {
                print("Error loading image:", error)
            }
        }
        
        return dataSource
    }
    
    func updateDataSource()
    {
        if Bundle.main.isMainAltStore
        {
            self.announcementsDataSource.predicate = NSPredicate(format: "(%K == nil AND %K == nil) AND (%K == %@)",
                                                                 #keyPath(NewsItem.imageURL),
                                                                 #keyPath(NewsItem.app),
                                                                 #keyPath(NewsItem.source.identifier),
                                                                 Source.altStoreIdentifier)
            
            // Don't restrict news items by Source because a visible NewsItem may link to an app from another (hidden) source.
            self.newsDataSource.predicate = NSPredicate(format: "(%K != nil OR %K != nil) AND (%K == NO)",
                                                        #keyPath(NewsItem.imageURL),
                                                        #keyPath(NewsItem.app),
                                                        #keyPath(NewsItem.isSilent))
        }
        else
        {
            let sourcesPredicate = NSPredicate(format: "%K != nil", #keyPath(NewsItem.source))
            
            self.announcementsDataSource.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "%K == nil AND %K == nil", #keyPath(NewsItem.imageURL), #keyPath(NewsItem.app)),
                sourcesPredicate
            ])
            
            self.newsDataSource.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "(%K != nil OR %K != nil) AND (%K == NO)", #keyPath(NewsItem.imageURL), #keyPath(NewsItem.app), #keyPath(NewsItem.isSilent)),
                sourcesPredicate
            ])
        }
    }
    
    func update()
    {
        if self.appManager.updateSourcesResult == nil
        {
            self.placeholderView.detailTextLabel.isHidden = true
            self.placeholderView.activityIndicatorView.startAnimating()
        }
        else
        {
            self.placeholderView.detailTextLabel.isHidden = false
            self.placeholderView.activityIndicatorView.stopAnimating()
            
            switch self.appManager.updateSourcesResult
            {
            case .none: break
            case .failure(let error)?:
                let title = String(format: AppStrings.News.failedToFetchNews, error.localizedDescription)
                self.placeholderView.detailTextLabel.setTitle(title, for: .normal)
                
            case .success?:
                self.placeholderView.detailTextLabel.setTitle(AppStrings.News.noNewsItems, for: .normal)
            }
        }
    }
    
    @objc func fetchNews()
    {
        self.update()
        
        AppManager.shared.updateAllSources { (result) in
            DispatchQueue.main.async {
                if case .failure(let error) = result, self.dataSource.itemCount > 0
                {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(self, action: #selector(NewsViewController.fetchNews), for: .touchUpInside)
                    toastView.show(in: self)
                }
                
                self.update()
                
                self.collectionView.reloadData()
            }
        }
    }
    
    @objc func fetchPatrons(_ sender: UIRefreshControl)
    {
        // Calling endRefreshing() synchronization in completion handler causes weird scroll view Offset issues.
        // Dispatching safely to next runloop passes prevents this.
        func endRefreshing()
        {
            DispatchQueue.main.async {
                sender.endRefreshing()
            }
        }
        
        PatreonAPI.shared.fetchPatrons { (result) in
            do
            {
                let patrons = try result.get()
                
                DatabaseManager.shared.persistentContainer.performBackgroundTask { (context) in
                    let existingPatrons = Patron.all(in: context)
                    
                    let patronIDs = Set(patrons.map { $0.id })
                    for patron in existingPatrons where !patronIDs.contains(patron.identifier)
                    {
                        context.delete(patron)
                    }
                    
                    do
                    {
                        try context.save()
                    }
                    catch
                    {
                        print("Failed to save Patrons.", error)
                    }
                    
                    endRefreshing()
                }
            }
            catch
            {
                print("Failed to fetch Patrons.", error)
                endRefreshing()
            }
        }
    }
    
    @objc func performAnnouncementAction(_ sender: UIButton)
    {
        let indexPath = IndexPath(item: sender.tag, section: Section.announcements.rawValue)
        let newsItem = self.dataSource.item(at: indexPath)
        
        if let externalURL = newsItem.externalURL
        {
            self.open(externalURL, newsItem: newsItem)
        }
        else if let app = newsItem.app
        {
            self.performSegue(withIdentifier: "showApp", sender: app)
        }
    }
    
    @objc func performStoreAppAction(_ sender: PillButton)
    {
        let indexPath = IndexPath(item: sender.tag, section: Section.news.rawValue)
        let newsItem = self.dataSource.item(at: indexPath)
        
        guard let storeApp = newsItem.app else { return }
        
        let previousProgress = AppManager.shared.installationProgress(for: storeApp)
        guard previousProgress == nil else {
            previousProgress?.cancel()
            return
        }
        
        if let installedApp = storeApp.installedApp, !installedApp.isUpdateAvailable
        {
            self.open(installedApp)
        }
        else
        {
            // View Controller should still install app even if another transition is occurring.
            self.install(storeApp, at: indexPath)
        }
    }
    
    @objc func handleTapAppBanner(_ recognizer: UITapGestureRecognizer)
    {
        let point = recognizer.location(in: self.collectionView)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let newsItem = self.dataSource.item(at: indexPath)
        guard let storeApp = newsItem.app else { return }
        
        self.performSegue(withIdentifier: "showApp", sender: storeApp)
    }
    
    func open(_ url: URL, newsItem: NewsItem)
    {
        guard !self.isPresentingViewController else { return }
        self.isPresentingViewController = true
        
        let safariViewController = SFSafariViewController(url: url)
        safariViewController.preferredControlTintColor = newsItem.tintColor ?? .altPrimary
        self.present(safariViewController, animated: true, completion: nil)
    }
    
    func install(_ storeApp: StoreApp, at indexPath: IndexPath)
    {
        Task<Void, Never> { @MainActor in
            let context = InstallAppOperationContext()
            let group = await AppManager.shared.installAsync(storeApp, presentingViewController: self, context: context)
            if let error = await group.results[storeApp.bundleIdentifier]?.error {
                print("Failed to install app \(storeApp.bundleIdentifier) from NewsViewController.", error)
            } else {
                print("Successfully installed app \(storeApp.bundleIdentifier)!")
            }
        }
    }
    
    func open(_ installedApp: InstalledApp)
    {
        UIApplication.shared.open(installedApp.openAppURL)
    }

    private func setupNetworkObserver() {
        // Observe changes to updateSourcesResult
        appManager.$updateSourcesResult
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.update()
            }
            .store(in: &cancellables)
        
        // Monitor network status changes
        let monitor = NWPathMonitor()
        self.pathMonitor = monitor
        
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                DispatchQueue.main.async {
                    self?.fetchNews()
                }
            }
        }
        
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
}

extension NewsViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        return CGSize(width: 88, height: 88)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets
    {
        guard self.collectionView(collectionView, numberOfItemsInSection: section) > 0 else { return .zero }
        
        let section = Section.allCases[section]
        switch section
        {
        case .announcements:
            return UIEdgeInsets(top: 12, left: 0, bottom: 8, right: 0)
            
        case .news:
            return UIEdgeInsets(top: 12, left: 0, bottom: 25, right: 0)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let newsItem = self.dataSource.item(at: indexPath)
        
        switch Section.allCases[indexPath.section]
        {
        case .announcements:
            let isCollapsed: Bool
            
            if self.expandedAnnouncements.contains(newsItem)
            {
                self.expandedAnnouncements.remove(newsItem)
                isCollapsed = true
            }
            else
            {
                self.expandedAnnouncements.insert(newsItem)
                isCollapsed = false
            }
                        
            guard let cell = collectionView.cellForItem(at: indexPath) as? AnnouncementCollectionViewCell else { break }
            
            let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 0.95) {
                // Create dynamic animation context so changes to cell.isCollapsed animate alongside collectionView.performBatchUpdates().
                collectionView.performBatchUpdates({
                    cell.isCollapsed = isCollapsed
                    cell.layoutIfNeeded()
                    
                    // Force layout within animation block to prevent stutter at end of animation.
                    collectionView.layoutIfNeeded()
                })
            }
            animator.startAnimation()
            
        case .news:
            if let externalURL = newsItem.externalURL
            {
                self.open(externalURL, newsItem: newsItem)
            }
            else if let storeApp = newsItem.app
            {
                self.performSegue(withIdentifier: "showApp", sender: storeApp)
            }
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath)
    {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        UIView.animate(withDuration: 0.2, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: {
            cell.contentView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }, completion: nil)
    }
    
    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath)
    {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        
        UIView.animate(withDuration: 0.25, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: {
            cell.contentView.transform = .identity
        }, completion: nil)
    }
}
