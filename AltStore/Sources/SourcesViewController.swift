
//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 1/31/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import CoreData
import Nuke

class SourcesViewController: UICollectionViewController
{
    private lazy var dataSource = self.makeDataSource()
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.collectionView.backgroundColor = .altBackground
        
        let layout = self.makeLayout()
        self.collectionView.collectionViewLayout = layout
        
        self.collectionView.register(SourceCollectionViewCell.self, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        self.collectionView.register(CollectionSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "HeaderView")
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(SourcesViewController.addSource))
        
        let exportBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(SourcesViewController.exportSources))
        self.navigationItem.leftBarButtonItem = exportBarButtonItem
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.fetchSources()
    }
}

private extension SourcesViewController
{
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        
        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(100))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 12
        section.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 15, bottom: 20, trailing: 15)
        
        let layout = UICollectionViewCompositionalLayout(section: section)
        return layout
    }
    
    func makeDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        let fetchRequest = Source.fetchRequest() as NSFetchRequest<Source>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Source.name, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.cellIdentifierHandler = { _ in CellContentGenericCellIdentifier }
        dataSource.cellConfigurationHandler = { (cell, source, indexPath) in
            let cell = cell as! SourceCollectionViewCell
            cell.nameLabel.text = source.name
            cell.subtitleLabel.text = source.sourceURL.absoluteString
            
            cell.iconImageView.image = nil
            cell.iconImageView.isHidden = false
            
            let isAltStoreSource = (source.identifier == Source.altStoreIdentifier)
            cell.deleteButton.isHidden = isAltStoreSource
            cell.deleteButton.tag = indexPath.item
            cell.deleteButton.addTarget(self, action: #selector(SourcesViewController.removeSource(_:)), for: .touchUpInside)
        }
        dataSource.prefetchHandler = { (source, _) in
            guard let iconURL = source.effectiveIconURL else { return nil }
            return try await ImagePipeline.shared.image(for: iconURL)
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! SourceCollectionViewCell
            cell.iconImageView.image = image ?? UIImage(named: "DefaultAppIcon")
        }
        
        let placeholderView = PlaceholderView.instantiate(with: PlaceholderView.nib!)
        placeholderView.textLabel.text = AppStrings.Sources.noSources
        placeholderView.detailTextLabel.text = AppStrings.Sources.YouHaveNotAddedAnySources
        dataSource.placeholderView = placeholderView
        
        return dataSource
    }
    
    func fetchSources()
    {
        AppManager.shared.updateAllSources { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                    
                case .success:
                    self.collectionView.reloadData()
                }
            }
        }
    }
    
    @objc func addSource()
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
        
        Task {
            for url in urls {
                do {
                    let source = try await AppManager.shared.addSource(sourceURL: url)
                    try await source.managedObjectContext?.perform {
                        try source.managedObjectContext?.save()
                    }
                } catch {
                    await MainActor.run {
                        let toastView = ToastView(error: error)
                        toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                    }
                }
            }
            
            await MainActor.run {
                self.fetchSources()
            }
        }
    }
    
    @objc func removeSource(_ sender: UIButton)
    {
        let indexPath = IndexPath(item: sender.tag, section: 0)
        let source = self.dataSource.item(at: indexPath)
        
        let alertController = UIAlertController(
            title: String(format: AppStrings.Sources.removeSourceConfirmTitle, source.name),
            message: AppStrings.Sources.removeSourceConfirmMessage,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.bounds
        alertController.addAction(UIAlertAction(title: AppStrings.Common.remove, style: .destructive) { _ in
            AppManager.shared.remove(source) { result in
                DispatchQueue.main.async {
                    if case .failure(let error) = result {
                        let toastView = ToastView(error: error)
                        toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
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
        toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
    }
}

extension SourcesViewController
{
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        let source = self.dataSource.item(at: indexPath)
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let copyAction = UIAction(title: AppStrings.Sources.copyURL, image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = source.sourceURL
            }
            
            var actions = [copyAction]
            
            if source.identifier != Source.altStoreIdentifier {
                let deleteAction = UIAction(title: AppStrings.Common.remove, image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                    guard let self = self else { return }
                    AppManager.shared.remove(source) { result in
                        DispatchQueue.main.async {
                            if case .failure(let error) = result {
                                let toastView = ToastView(error: error)
                                toastView.show(in: self.navigationController?.view ?? self.view, duration: 2.0)
                            }
                        }
                    }
                }
                actions.append(deleteAction)
            }
            
            return UIMenu(title: source.name, children: actions)
        }
    }
}
