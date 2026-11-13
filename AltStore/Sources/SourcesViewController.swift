//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/8/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
import SafariServices

import AltStoreCore
import Roxas

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
    
    private lazy var placeholderView = RSTPlaceholderView(frame: .zero)
    
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
        
        self.collectionView.register(CollectionSectionHeaderView.nib, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "Header")
        
        self.placeholderView.textLabel.isHidden = true
        self.placeholderView.detailTextLabel.isHidden = false
        self.placeholderView.detailTextLabel.textColor = AppUI.Colors.textSecondary
        self.placeholderView.activityIndicatorView.color = AppUI.Colors.primaryPurple
        
        let addSourceBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(SourcesViewController.promptToAddSource))
        self.navigationItem.leftBarButtonItem = addSourceBarButtonItem
        
        NotificationCenter.default.addObserver(self, selector: #selector(SourcesViewController.didAddSource(_:)), name: AppManager.didAddSourceNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SourcesViewController.didRemoveSource(_:)), name: AppManager.didRemoveSourceNotification, object: nil)
        
        // Lắng nghe thay đổi màu sắc chủ đề từ cài đặt
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
            
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(44))
            let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.interGroupSpacing = 12
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 16, bottom: 16, trailing: 16)
            
            switch sectionType
            {
            case .existingSources:
                break
                
            case .recommendedSources:
                if !self.recommendedSourcesDataSource.items.isEmpty
                {
                    layoutSection.boundarySupplementaryItems = [header]
                }
            }
            
            return layoutSection
        }, configuration: layoutConfig)
        
        return layout
    }
    
    func makeDataSource() -> RSTCompositeCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let dataSource = RSTCompositeCollectionViewPrefetchingDataSource<Source, UIImage>(dataSources: [self.existingSourcesDataSource, self.recommendedSourcesDataSource])
        dataSource.placeholderView = self.placeholderView
        dataSource.cellConfigurationHandler = { [weak self] (cell, source, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! AppBannerCollectionViewCell
            cell.bannerView.style = .source
            
            // Áp dụng CSS Card Style (Nền trắng, bo góc 18px, đổ bóng chuẩn CSS)
            cell.contentView.applyCSSCardStyle(cornerRadius: AppUI.Layout.cardCornerRadius)
            
            cell.bannerView.titleLabel.text = source.name
            cell.bannerView.subtitleLabel.text = source.sourceURL.host ?? source.sourceURL.absoluteString
            cell.bannerView.iconImageView.image = UIImage(named: "DefaultSourceIcon")
            
            let tintColor = source.effectiveTintColor ?? AppUI.Colors.primaryPurple
            cell.bannerView.tintColor = tintColor
            
            switch Section.allCases[indexPath.section]
            {
            case .existingSources:
                cell.bannerView.button.isHidden = (source.identifier == Source.altStoreIdentifier)
                cell.bannerView.button.setTitle("–", for: .normal)
                cell.bannerView.button.accessibilityLabel = AppStrings.Common.remove
                
                cell.bannerView.button.backgroundColor = AppUI.Colors.dangerRed.withAlphaComponent(0.15)
                cell.bannerView.button.setTitleColor(AppUI.Colors.dangerRed, for: .normal)
                cell.bannerView.button.layer.cornerRadius = 14
                
                cell.buttonActionHandler = { [weak self] (sender) in
                    self?.confirmRemove(source)
                }
                
            case .recommendedSources:
                cell.bannerView.button.isHidden = false
                cell.bannerView.button.setTitle("+", for: .normal)
                cell.bannerView.button.accessibilityLabel = AppStrings.Common.add
                
                cell.bannerView.button.backgroundColor = AppUI.Colors.primaryPurple.withAlphaComponent(0.15)
                cell.bannerView.button.setTitleColor(AppUI.Colors.primaryPurple, for: .normal)
                cell.bannerView.button.layer.cornerRadius = 14
                
                cell.buttonActionHandler = { [weak self] (sender) in
                    self?.addSource(at: source.sourceURL, indexPath: indexPath)
                }
            }
            
            if self.addingSourceIndexPath == indexPath
            {
                cell.bannerView.isIndicatingActivity = true
            }
            else
            {
                cell.bannerView.isIndicatingActivity = false
            }
            
            cell.layoutIfNeeded()
        }
        dataSource.prefetchHandler = { (source, indexPath, completionHandler) in
            return RSTAsyncBlockOperation() { (operation) in
                source.managedObjectContext?.perform {
                    guard let imageURL = source.effectiveIconURL else { return completionHandler(nil, nil) }
                    
                    ImageLoader.shared.loadImage(with: imageURL) { (result) in
                        guard !operation.isCancelled else {
                            operation.finish()
                            return
                        }
                        
                        switch result
                        {
                        case .success(let image): completionHandler(image, nil)
                        case .failure(let error): completionHandler(nil, error)
                        }
                        
                        operation.finish()
                    }
                }
            }
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! AppBannerCollectionViewCell
            if let image = image
            {
                cell.bannerView.iconImageView.image = image
            }
            
            if let error = error
            {
                Logger.main.error("Failed to load source icon. \(error.localizedDescription, privacy: .public)")
            }
        }
        
        return dataSource
    }
    
    func makeExistingSourcesDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let fetchRequest = Source.fetchRequest() as! NSFetchRequest<Source>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Source.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let dataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        return dataSource
    }
    
    func makeRecommendedSourcesDataSource() -> RSTArrayCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let dataSource = RSTArrayCollectionViewPrefetchingDataSource<Source, UIImage>(items: [])
        return dataSource
    }
}

private extension SourcesViewController
{
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
            cell.bannerView.isIndicatingActivity = true
        }
        
        AppManager.shared.fetchSource(sourceURL: sourceURL) { (result) in
            switch result
            {
            case .failure(let error):
                DispatchQueue.main.async {
                    self.finishAddingSource(with: .failure(error))
                }
                
            case .success((let source, let context)):
                context.perform {
                    func addSource()
                    {
                        do
                        {
                            try context.save()
                            
                            DispatchQueue.main.async {
                                self.finishAddingSource(with: .success(()))
                                
                                NotificationCenter.default.post(name: AppManager.didAddSourceNotification, object: self, userInfo: [AppManager.sourceNotificationKey: source])
                            }
                        }
                        catch
                        {
                            DispatchQueue.main.async {
                                self.finishAddingSource(with: .failure(error))
                            }
                        }
                    }
                    
                    let warningAlert = UIAlertController(title: AppStrings.Sources.untrustedSourceTitle, message: AppStrings.Sources.untrustedSourceMessage, preferredStyle: .alert)
                    warningAlert.addAction(UIAlertAction(title: AppStrings.Common.cancel, style: .cancel) { _ in
                        DispatchQueue.main.async {
                            self.finishAddingSource(with: .success(()))
                        }
                    })
                    warningAlert.addAction(UIAlertAction(title: AppStrings.Sources.addSource, style: .default) { _ in
                        context.perform {
                            addSource()
                        }
                    })
                    
                    DispatchQueue.main.async {
                        self.present(warningAlert, animated: true)
                    }
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
            cell.bannerView.isIndicatingActivity = false
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
        let sourceID = source.identifier
        
        AppManager.shared.removeSource(withIdentifier: sourceID) { (result) in
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
        self.isFetchingRecommendedSources = true
        self.fetchError = nil
        
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        
        // Không bắt buộc gọi từ xa nếu chưa cấu hình recommendedSourcesURL
        self.isFetchingRecommendedSources = false
        _ = context
    }
    
    func updateRecommendedSources(_ sources: [Source])
    {
        DatabaseManager.shared.viewContext.perform {
            do
            {
                let existingSources = try Source.all(in: DatabaseManager.shared.viewContext)
                let existingIdentifiers = Set(existingSources.map { $0.identifier })
                
                let filteredSources = sources.filter { !existingIdentifiers.contains($0.identifier) }
                self.recommendedSourcesDataSource.setItems(filteredSources)
            }
            catch
            {
                Logger.main.error("Failed to filter recommended sources. \(error.localizedDescription, privacy: .public)")
            }
        }
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

extension SourcesViewController
{
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "Header", for: indexPath) as! CollectionSectionHeaderView
        headerView.textLabel.text = AppStrings.Sources.recommendedSources
        headerView.textLabel.textColor = AppUI.Colors.textPrimary
        headerView.textLabel.font = .systemFont(ofSize: 18, weight: .bold)
        headerView.actionButton.isHidden = true
        return headerView
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let source = self.dataSource.item(at: indexPath)
        
        let sourceDetailsViewController = SourceDetailsViewController(source: source)
        let navigationController = UINavigationController(rootViewController: sourceDetailsViewController)
        navigationController.applyCSSNavigationBar()
        self.present(navigationController, animated: true)
    }
}
