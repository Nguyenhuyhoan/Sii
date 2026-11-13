//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 1/31/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
@preconcurrency import Nuke

class SourcesViewController: UICollectionViewController
{
    var deepLinkSourceURL: URL? {
        didSet {
            guard let deepLinkSourceURL = self.deepLinkSourceURL, self.isViewLoaded else { return }
            self.addSource(with: deepLinkSourceURL)
        }
    }
    
    private lazy var dataSource = self.makeDataSource()
    private lazy var placeholderView = PlaceholderView(frame: .zero)
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.title = AppStrings.Sources.title
        self.applyCSSNavigationBar(tintColor: AppUI.Colors.blue, transparentEdge: true)
        
        self.view.backgroundColor = .clear
        self.view.applyCSSBodyGradient()
        self.collectionView.backgroundColor = .clear
        
        let layout = self.makeLayout()
        self.collectionView.collectionViewLayout = layout
        
        self.collectionView.register(AppBannerCollectionViewCell.self, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        
        self.placeholderView.textLabel.text = AppStrings.Sources.noSources
        self.placeholderView.detailTextLabel.text = AppStrings.Sources.YouHaveNotAddedAnySources
        self.dataSource.placeholderView = self.placeholderView
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(SourcesViewController.addSourceButtonTapped))
        
        let exportBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(SourcesViewController.exportSources))
        self.navigationItem.leftBarButtonItem = exportBarButtonItem
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.view.updateCSSBodyGradientFrame()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.fetchSources()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        if let deepLinkSourceURL = self.deepLinkSourceURL {
            self.deepLinkSourceURL = nil
            self.addSource(with: deepLinkSourceURL)
        }
    }
}

private extension SourcesViewController
{
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(88))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(88))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 20, trailing: 15)
        
        return UICollectionViewCompositionalLayout(section: section)
    }
    
    func makeDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let fetchRequest = Source.fetchRequest() as NSFetchRequest<Source>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Source.name, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.cellIdentifierHandler = { _ in CellContentGenericCellIdentifier }
        dataSource.cellConfigurationHandler = { (cell, source, indexPath) in
            let cell = cell as! AppBannerCollectionViewCell
            cell.bannerView.titleLabel.text = source.name
            cell.bannerView.subtitleLabel.text = source.sourceURL.absoluteString
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            cell.bannerView.button.isHidden = true
            cell.bannerView.applyCSSBannerShadow()
        }
        dataSource.prefetchHandler = { (source, _) in
            guard let iconURL = source.effectiveIconURL else { return nil }
            return try await ImagePipeline.shared.image(for: iconURL)
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! AppBannerCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image ?? UIImage(named: "DefaultAppIcon")
        }
        
        return dataSource
    }
    
    func fetchSources()
    {
        AppManager.shared.updateAllSources { [weak self] (result) in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch result
                {
                case .failure(let error):
                    ToastView(error: error).show(in: self)
                case .success:
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    @objc func addSourceButtonTapped()
    {
        let alertController = UIAlertController(title: AppStrings.Sources.addSourceTitle, message: AppStrings.Sources.addSourceMessage, preferredStyle: .alert)
        alertController.addTextField { (textField) in
            textField.placeholder = "https://example.com/apps.json"
            textField.keyboardType = .URL
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
        }
        alertController.addAction(.cancel)
        
        let addAction = UIAlertAction(title: AppStrings.Common.add, style: .default) { [weak self] _ in
            guard let text = alertController.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }
            
            self?.addSources(from: text)
        }
        alertController.addAction(addAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func addSource(with url: URL)
    {
        self.addSources(from: url.absoluteString)
    }
    
    func addSources(from input: String)
    {
        let urls = input.components(separatedBy: .whitespacesAndNewlines)
            .compactMap { URL(string: $0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        
        guard !urls.isEmpty else {
            let alert = UIAlertController(title: AppStrings.Error.invalidURLTitle, message: AppStrings.Error.invalidURLMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: systemLocalizedString("OK"), style: .default))
            self.present(alert, animated: true)
            return
        }
        
        for url in urls {
            AppManager.shared.addSource(sourceURL: url, presentingViewController: self) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    switch result {
                    case .failure(let error):
                        ToastView(error: error).show(in: self)
                    case .success:
                        self.fetchSources()
                    }
                }
            }
        }
    }
    
    func confirmRemoveSource(_ source: Source, sourceView: UIView? = nil)
    {
        let alertController = UIAlertController(
            title: String(format: AppStrings.Sources.removeSourceConfirmTitle, source.name),
            message: AppStrings.Sources.removeSourceConfirmMessage,
            preferredStyle: .actionSheet
        )
        if let sourceView = sourceView {
            alertController.popoverPresentationController?.sourceView = sourceView
            alertController.popoverPresentationController?.sourceRect = sourceView.bounds
        } else {
            alertController.popoverPresentationController?.sourceView = self.view
            alertController.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        }
        
        alertController.addAction(UIAlertAction(title: AppStrings.Common.remove, style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            AppManager.shared.remove(source, presentingViewController: self) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if case .failure(let error) = result {
                        ToastView(error: error).show(in: self)
                    }
                }
            }
        })
        alertController.addAction(.cancel)
        self.present(alertController, animated: true)
    }
    
    @objc func exportSources()
    {
        let sources = self.dataSource.fetchedResultsController.fetchedObjects ?? []
        let urls = sources
            .filter { $0.identifier != Source.altStoreIdentifier }
            .map { $0.sourceURL.absoluteString }
            .joined(separator: "\n")
        
        UIPasteboard.general.string = urls
        
        let toastView = ToastView(
            text: AppStrings.Sources.copiedToClipboardTitle,
            detailText: AppStrings.Sources.copiedToClipboardMessage(count: sources.count)
        )
        toastView.show(in: self)
    }
}

extension SourcesViewController
{
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        let source = self.dataSource.item(at: indexPath)
        guard let browseVC = self.storyboard?.instantiateViewController(identifier: "browseViewController", creator: { coder in
            return BrowseViewController(source: source, coder: coder)
        }) else { return }
        
        self.navigationController?.pushViewController(browseVC, animated: true)
    }

    #if !os(tvOS)
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        let source = self.dataSource.item(at: indexPath)
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let copyAction = UIAction(title: AppStrings.Sources.copyURL, image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = source.sourceURL
            }
            
            var actions = [copyAction]
            
            if source.identifier != Source.altStoreIdentifier {
                let deleteAction = UIAction(title: AppStrings.Common.remove, image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                    self?.confirmRemoveSource(source, sourceView: collectionView.cellForItem(at: indexPath))
                }
                actions.append(deleteAction)
            }
            
            return UIMenu(title: source.name, children: actions)
        }
    }
    #endif
}
