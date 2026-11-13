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
