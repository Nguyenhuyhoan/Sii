//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/23/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import UIKit
import SwiftUI
import CoreData
import Combine
import Nuke

final class SourcesViewController: UICollectionViewController {
    private lazy var dataSource = makeDataSource()
    private lazy var placeholderView = PlaceholderView(frame: .zero)

    private var cancellables = Set<AnyCancellable>()
    private var prototypeCell: SourceCollectionViewCell!
    private var cachedItemSizes = [String: CGSize]()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Đồng bộ thanh Navigation Bar kính mờ (.site-header) và nền Gradient từ ThemeManager
        applyCSSNavigationBar(tintColor: AppUI.Colors.blue, transparentEdge: true)
        view.backgroundColor = .clear
        view.applyCSSBodyGradient()

        prototypeCell = SourceCollectionViewCell.instantiate()
        prototypeCell.contentView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.register(SourceCollectionViewCell.nib, forCellWithReuseIdentifier: RSTCellContentGenericCellIdentifier)
        collectionView.dataSource = dataSource
        collectionView.prefetchDataSource = dataSource

        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.updateSources()
        })
        refreshControl.tintColor = AppUI.Colors.blue
        collectionView.refreshControl = refreshControl

        // Khung PlaceholderView chuẩn thẻ CSS từ ThemeManager
        placeholderView.textLabel.applySectionTitle(text: AppStrings.Sources.noSources)
        placeholderView.textLabel.isHidden = false
        placeholderView.detailTextLabel.text = AppStrings.Sources.YouHaveNotAddedAnySources
        placeholderView.detailTextLabel.textColor = AppUI.Colors.dark
        placeholderView.detailTextLabel.isHidden = false
        placeholderView.activityIndicatorView.stopAnimating()

        // Nút bấm chuẩn CSS (.btn) có đổ bóng xanh và hiệu ứng nhún từ ThemeManager
        let button = UIButton(type: .system, primaryAction: UIAction { [weak self] _ in
            self?.showAddSourceView()
        })
        button.applyCSSButton(
            title: AppStrings.Sources.viewRecommendedSources,
            style: .primaryBlue,
            fontSize: 16,
            contentInsets: NSDirectionalEdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22)
        )

        placeholderView.stackView.spacing = 20
        placeholderView.stackView.addArrangedSubview(button)
        placeholderView.stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24)
        placeholderView.stackView.isLayoutMarginsRelativeArrangement = true
        placeholderView.stackView.applyCSSCardStyle()

        preparePipeline()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.updateCSSBodyGradientFrame()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if dataSource.itemCount == 0 {
            updateSources()
        }
    }
}

private extension SourcesViewController {
    func preparePipeline() {
        AppManager.shared.$updateSourcesResult
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)
    }

    func makeDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage> {
        let fetchRequest = Source.fetchRequest() as NSFetchRequest<Source>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Source.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false

        let dataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.placeholderView = placeholderView
        dataSource.cellConfigurationHandler = { [weak self] (cell, source, _) in
            guard let self else { return }
            let cell = cell as! SourceCollectionViewCell
            cell.backgroundColor = .clear
            cell.contentView.backgroundColor = .clear
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right

            cell.configure(for: source)
            cell.bannerView.applyCSSBannerShadow()

            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            cell.bannerView.button.isHidden = true
            cell.tintColor = source.effectiveTintColor ?? AppUI.Colors.blue
        }
        dataSource.prefetchHandler = { (source, _, completionHandler) in
            guard let iconURL = source.effectiveIconURL else { return nil }
            return RSTAsyncBlockOperation { operation in
                ImagePipeline.shared.loadImage(with: iconURL, progress: nil) { result in
                    guard !operation.isCancelled else { return operation.finish() }
                    switch result {
                    case .success(let response): completionHandler(response.image, nil)
                    case .failure(let error): completionHandler(nil, error)
                    }
                    operation.finish()
                }
            }
        }
        dataSource.prefetchCompletionHandler = { (cell, image, _, error) in
            let cell = cell as! SourceCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
            if let error { print("Error loading image:", error) }
        }
        return dataSource
    }

    func update() {
        cachedItemSizes = [:]
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func updateSources() {
        AppManager.shared.updateAllSources { [weak self] result in
            guard let self else { return }
            self.collectionView.refreshControl?.endRefreshing()
            if case .failure(let error) = result {
                ToastView(error: error, opensLog: true).show(in: self)
            }
            self.update()
        }
    }

    @IBAction func showAddSourceView() {
        let addSourceView = AddSourceView { [weak self] in
            self?.dismiss(animated: true)
        }
        let hostingController = UIHostingController(rootView: addSourceView)
        present(hostingController, animated: true)
    }

    @IBAction func copySourcesToClipboard(_ sender: UIBarButtonItem) {
        let sourceURLs = dataSource.items.map { $0.sourceURL.absoluteString }
        guard !sourceURLs.isEmpty else { return }

        UIPasteboard.general.string = sourceURLs.joined(separator: "\n")

        let alert = UIAlertController(
            title: AppStrings.Sources.copiedToClipboardTitle,
            message: AppStrings.Sources.copiedToClipboardMessage(count: sourceURLs.count),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: RSTSystemLocalizedString("OK"), style: .default))
        present(alert, animated: true)
    }
}

extension SourcesViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let source = dataSource.item(at: indexPath)
        if let previousSize = cachedItemSizes[source.identifier] { return previousSize }

        dataSource.cellConfigurationHandler(prototypeCell, source, indexPath)
        let horizontalInsets = view.layoutMargins.left + view.layoutMargins.right
        let widthConstraint = prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionView.bounds.width - horizontalInsets)
        widthConstraint.isActive = true
        defer { widthConstraint.isActive = false }

        prototypeCell.frame.size.width = widthConstraint.constant
        prototypeCell.layoutIfNeeded()

        let itemSize = prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        cachedItemSizes[source.identifier] = itemSize
        return itemSize
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let source = dataSource.item(at: indexPath)
        let sourceDetailsView = SourceDetailsView(source: source)
        let hostingController = UIHostingController(rootView: sourceDetailsView)
        navigationController?.pushViewController(hostingController, animated: true)
    }

    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let source = dataSource.item(at: indexPath)
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: {
            UIHostingController(rootView: SourceDetailsView(source: source))
        }) { [weak self] _ in
            let copyAction = UIAction(title: AppStrings.Sources.copyURL, image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = source.sourceURL
            }
            guard source.identifier != Source.altStoreIdentifier else {
                return UIMenu(title: "", children: [copyAction])
            }
            let removeAction = UIAction(title: AppStrings.Common.remove(), image: UIImage(systemName: "trash"), attributes: [.destructive]) { _ in
                self?.remove(source)
            }
            return UIMenu(title: "", children: [copyAction, removeAction])
        }
    }

    override func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        let source = dataSource.item(at: indexPath)
        animator.addCompletion {
            let hostingController = UIHostingController(rootView: SourceDetailsView(source: source))
            self.navigationController?.pushViewController(hostingController, animated: true)
        }
    }

    private func remove(_ source: Source) {
        AppManager.shared.remove(source, presentingViewController: self) { [weak self] result in
            guard let self else { return }
            DispatchQueue.main.async {
                switch result {
                case .failure(OperationError.cancelled): break
                case .failure(let error):
                    ToastView(error: error, opensLog: true).show(in: self)
                case .success:
                    self.update()
                }
            }
        }
    }
}
