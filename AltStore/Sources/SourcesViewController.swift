
//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 3/17/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CSS THEME (ĐỒNG BỘ TOÀN HỆ THỐNG)
private enum SourcesCSSTheme {
    static let primaryBlue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)      // #007bff
    static let primaryPurple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)   // #6f42c1
    static let primaryGreen = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)     // #28a745
    static let primaryRed = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)       // #dc3545
    static let darkText = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0)          // #343a40
    static let borderColor = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0)    // #e9ecef
    
    static let gradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0)  // #f3e0ff
    static let gradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0)    // #e0f7ff
}

/// View nền Gradient tự động cập nhật kích thước theo chuẩn CSS (`linear-gradient(90deg, #f3e0ff 0%, #e0f7ff 100%)`)
private final class SourcesGradientBackgroundView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
    }
    
    private var gradientLayer: CAGradientLayer {
        return self.layer as! CAGradientLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        gradientLayer.colors = [
            SourcesCSSTheme.gradientStart.cgColor,
            SourcesCSSTheme.gradientEnd.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
    }
}

@objc(SourcesFooterView)
private final class SourcesFooterView: TextCollectionReusableView
{
    @IBOutlet var activityIndicatorView: UIActivityIndicatorView!
    @IBOutlet var textView: UITextView!
}

private extension UIAction.Identifier
{
    static let showDetails = UIAction.Identifier("io.sidestore.showDetails")
    static let showError = UIAction.Identifier("io.sidestore.showError")
}

final class SourcesViewController: UICollectionViewController
{
    var deepLinkSourceURL: URL? {
        didSet {
            self.handleAddSourceDeepLink()
        }
    }
    
    private lazy var dataSource = self.makeDataSource()
    
    private weak var _installingApp: StoreApp?
    
    private var placeholderView: PlaceholderView!
    private var placeholderViewButton: UIButton!
    private var placeholderViewCenterYConstraint: NSLayoutConstraint!
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Ensure large titles
        #if !os(tvOS)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .automatic
        #endif

        // Đặt tiêu đề Tiếng Việt & Áp dụng màu chữ CSS
        navigationItem.title = "Nguồn"
        navigationController?.navigationBar.layoutMargins.left = 20
        self.applyCSSNavigationBarStyle()
        
        let layout = self.makeLayout()
        self.collectionView.collectionViewLayout = layout
        
        self.navigationController?.view.tintColor = SourcesCSSTheme.primaryBlue
        self.view.tintColor = SourcesCSSTheme.primaryBlue
        
        self.collectionView.register(AppBannerCollectionViewCell.self, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        self.collectionView.allowsSelectionDuringEditing = false
        
        // Áp dụng nền Gradient CSS (#f3e0ff -> #e0f7ff)
        let backgroundView = SourcesGradientBackgroundView(frame: .zero)
        self.collectionView.backgroundView = backgroundView
        
        self.placeholderView = PlaceholderView(frame: .zero)
        self.placeholderView.translatesAutoresizingMaskIntoConstraints = false
        self.placeholderView.textLabel.text = "Thêm Nhiều Nguồn Hơn!"
        self.placeholderView.detailTextLabel.text = "Các nguồn quyết định những ứng dụng nào sẽ xuất hiện trong SideStore. Bạn càng thêm nhiều nguồn, trải nghiệm sử dụng SideStore của bạn sẽ càng phong phú hơn.\n\nChưa biết bắt đầu từ đâu? Hãy thử thêm một trong các Nguồn Đề Xuất của chúng tôi!"
        self.placeholderView.detailTextLabel.textAlignment = .center
        
        // Đóng khung thẻ trắng nổi 3D cho PlaceholderView theo chuẩn CSS
        self.placeholderView.stackView.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        self.placeholderView.stackView.layer.cornerRadius = 22
        self.placeholderView.stackView.layer.cornerCurve = .continuous
        self.placeholderView.stackView.layer.borderWidth = 1.5
        self.placeholderView.stackView.layer.borderColor = SourcesCSSTheme.borderColor.cgColor
        self.placeholderView.stackView.layer.shadowColor = SourcesCSSTheme.primaryBlue.cgColor
        self.placeholderView.stackView.layer.shadowOpacity = 0.12
        self.placeholderView.stackView.layer.shadowRadius = 14
        self.placeholderView.stackView.layer.shadowOffset = CGSize(width: 0, height: 8)
        
        backgroundView.addSubview(self.placeholderView)
        
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .title3).bolded()
        self.placeholderView.textLabel.font = UIFont(descriptor: fontDescriptor, size: 0.0)
        self.placeholderView.textLabel.textColor = SourcesCSSTheme.primaryBlue
        
        self.placeholderView.detailTextLabel.font = UIFont.preferredFont(forTextStyle: .body)
        self.placeholderView.detailTextLabel.textColor = SourcesCSSTheme.darkText.withAlphaComponent(0.85)
        self.placeholderView.detailTextLabel.textAlignment = .center
        
        self.placeholderViewButton = UIButton(type: .system, primaryAction: UIAction(title: "Xem Các Nguồn Đề Xuất") { [weak self] _ in
            self?.performSegue(withIdentifier: "addSource", sender: nil)
        })
        
        // Thiết kế nút bấm "Xem Các Nguồn Đề Xuất" chuẩn CSS Pill Button + Glow Shadow
        var buttonConfig = UIButton.Configuration.filled()
        buttonConfig.title = "Xem Các Nguồn Đề Xuất"
        buttonConfig.baseBackgroundColor = SourcesCSSTheme.primaryBlue
        buttonConfig.baseForegroundColor = .white
        buttonConfig.cornerStyle = .capsule
        buttonConfig.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        buttonConfig.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            return outgoing
        }
        self.placeholderViewButton.configuration = buttonConfig
        self.placeholderViewButton.layer.shadowColor = SourcesCSSTheme.primaryBlue.cgColor
        self.placeholderViewButton.layer.shadowOpacity = 0.35
        self.placeholderViewButton.layer.shadowRadius = 8
        self.placeholderViewButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        // Hiệu ứng nhún đàn hồi khi bấm nút
        self.placeholderViewButton.addTarget(self, action: #selector(animateButtonPressDown(_:)), for: [.touchDown, .touchDragEnter])
        self.placeholderViewButton.addTarget(self, action: #selector(animateButtonRelease(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
        
        self.placeholderView.stackView.spacing = 16
        self.placeholderView.stackView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 20, bottom: 24, trailing: 20)
        self.placeholderView.stackView.isLayoutMarginsRelativeArrangement = true
        self.placeholderView.stackView.addArrangedSubview(self.placeholderViewButton)
        
        self.placeholderViewCenterYConstraint = self.placeholderView.safeAreaLayoutGuide.centerYAnchor.constraint(equalTo: backgroundView.centerYAnchor, constant: 0)
        
        NSLayoutConstraint.activate([
            self.placeholderViewCenterYConstraint,
            self.placeholderView.centerXAnchor.constraint(equalTo: backgroundView.centerXAnchor),
            self.placeholderView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor, constant: 20),
            self.placeholderView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor, constant: -20),
            
            self.placeholderView.topAnchor.constraint(equalTo: self.placeholderView.stackView.topAnchor),
            self.placeholderView.bottomAnchor.constraint(equalTo: self.placeholderView.stackView.bottomAnchor),
        ])

        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        NotificationCenter.default.addObserver(self, selector: #selector(SourcesViewController.showInstallingAppToastView(_:)), name: AppManager.willInstallAppFromNewSourceNotification, object: nil)
        
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.applyCSSNavigationBarStyle()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        
        self.handleAddSourceDeepLink()
    }
    
    override func viewDidLayoutSubviews() 
    {
        super.viewDidLayoutSubviews()
        
        // Vertically center placeholder view in gap below first item.
        
        let indexPath = IndexPath(item: 0, section: 0)
        guard let layoutAttributes = self.collectionView.layoutAttributesForItem(at: indexPath) else { return }
        
        let maxY = layoutAttributes.frame.maxY
        
        let constant = maxY / 2
        if self.placeholderViewCenterYConstraint.constant != constant
        {
            self.placeholderViewCenterYConstraint.constant = constant
        }
    }
    
    private func applyCSSNavigationBarStyle()
    {
        guard let navBar = self.navigationController?.navigationBar else { return }
        navBar.tintColor = SourcesCSSTheme.primaryBlue
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.75)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.titleTextAttributes = [
            .foregroundColor: SourcesCSSTheme.primaryBlue,
            .font: UIFont.systemFont(ofSize: 18, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: SourcesCSSTheme.primaryBlue,
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy)
        ]
        
        navBar.standardAppearance = appearance
        navBar.compactAppearance = appearance
        
        let scrollEdgeAppearance = UINavigationBarAppearance()
        scrollEdgeAppearance.configureWithTransparentBackground()
        scrollEdgeAppearance.titleTextAttributes = appearance.titleTextAttributes
        scrollEdgeAppearance.largeTitleTextAttributes = appearance.largeTitleTextAttributes
        navBar.scrollEdgeAppearance = scrollEdgeAppearance
    }
    
    @objc private func animateButtonPressDown(_ sender: UIButton)
    {
        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }
    
    @objc private func animateButtonRelease(_ sender: UIButton)
    {
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
            sender.transform = .identity
        }
    }
}

private extension SourcesViewController
{
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        var configuration = UICollectionLayoutListConfiguration(appearance: .grouped)
        #if !os(tvOS)
        configuration.showsSeparators = false
        #endif
        configuration.backgroundColor = .clear
        
        #if !os(tvOS)
        configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
            guard let self else { return UISwipeActionsConfiguration(actions: []) }
            
            let source = self.dataSource.item(at: indexPath)
            var actions: [UIContextualAction] = []
            
            if source.identifier != Source.altStoreIdentifier
            {
                // Ngăn người dùng xoá nguồn mặc định của hệ thống.
                
                let removeAction = UIContextualAction(style: .destructive,
                                                      title: "Gỡ bỏ") { _, _, completion in
                    self.remove(source, completionHandler: completion)
                }
                removeAction.backgroundColor = SourcesCSSTheme.primaryRed
                removeAction.image = UIImage(systemName: "trash.fill")
                
                actions.append(removeAction)
            }
            
            if let error = source.error
            {
                let viewErrorAction = UIContextualAction(style: .normal,
                                                         title: "Xem lỗi") { _, _, completion in
                    self.present(error)
                    completion(true)
                }
                viewErrorAction.backgroundColor = .systemYellow
                viewErrorAction.image = UIImage(systemName: "exclamationmark.circle.fill")
                
                actions.append(viewErrorAction)
            }
            
            let config = UISwipeActionsConfiguration(actions: actions)
            config.performsFirstActionWithFullSwipe = false
            
            return config
        }
        #endif
        
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        return layout
    }
    
    func makeDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>
    {
        // TODO: @mahee96: Need implementation to keep SideStore-Official source always on top
        let fetchRequest = Source.fetchRequest() as NSFetchRequest<Source>
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \Source.name, ascending: true),
                                        
                                        // Can't sort by URLs or else app will crash.
                                        // NSSortDescriptor(keyPath: \Source.sourceURL, ascending: true),
                                        
                                        NSSortDescriptor(keyPath: \Source.identifier, ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<Source, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.proxy = self
        dataSource.cellConfigurationHandler = { [weak self] (cell, source, indexPath) in
            guard let self else { return }
                        
            let cell = cell as! AppBannerCollectionViewCell
            cell.layoutMargins.top = 6
            cell.layoutMargins.bottom = 6
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            
            cell.bannerView.configure(for: source)
            
            // Áp dụng đổ bóng CSS nhẹ nhàng cho từng thẻ nguồn
            cell.bannerView.layer.cornerRadius = 20
            cell.bannerView.layer.cornerCurve = .continuous
            cell.bannerView.layer.shadowColor = SourcesCSSTheme.primaryBlue.cgColor
            cell.bannerView.layer.shadowOpacity = 0.14
            cell.bannerView.layer.shadowRadius = 10
            cell.bannerView.layer.shadowOffset = CGSize(width: 0, height: 5)
            
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            
            let numberOfApps = source.apps.filter { StoreApp.visibleAppsPredicate.evaluate(with: $0) }.count
            
            UIView.performWithoutAnimation {
                cell.bannerView.button.style = .custom
                
                let contentWidth: CGFloat
                if let error = source.error
                {
                    let image = UIImage(systemName: "exclamationmark")?.withTintColor(.white, renderingMode: .alwaysOriginal)
                    cell.bannerView.button.setImage(image, for: .normal)
                    cell.bannerView.button.setTitle(nil, for: .normal)
                    cell.bannerView.button.tintColor = .systemYellow.withAlphaComponent(0.75)
                    contentWidth = image?.size.width ?? 7.0
                    
                    let action = UIAction(identifier: .showError) { _ in
                        self.present(error)
                    }
                    cell.bannerView.button.addAction(action, for: .primaryActionTriggered)
                    cell.bannerView.button.removeAction(identifiedBy: .showDetails, for: .primaryActionTriggered)
                }
                else
                {
                    let text = numberOfApps.description
                    cell.bannerView.button.setImage(nil, for: .normal)
                    cell.bannerView.button.setTitle(text, for: .normal)
                    cell.bannerView.button.tintColor = .white.withAlphaComponent(0.24)
                    
                    let font = UIFont.boldSystemFont(ofSize: 14)
                    contentWidth = (text as NSString).size(withAttributes: [.font: font]).width
                    
                    let action = UIAction(identifier: .showDetails) { _ in
                        self.showSourceDetails(for: source)
                    }
                    cell.bannerView.button.addAction(action, for: .primaryActionTriggered)
                    cell.bannerView.button.removeAction(identifiedBy: .showError, for: .primaryActionTriggered)
                }
                
                var config = cell.bannerView.button.configuration ?? UIButton.Configuration.plain()
                config.cornerStyle = .capsule
                let horizontalPadding = max(0, (31.0 - contentWidth) / 2.0)
                config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: horizontalPadding, bottom: 0, trailing: horizontalPadding)
                cell.bannerView.button.configuration = config
            }
            
            let dateText: String
            if let lastUpdatedDate = source.lastUpdatedDate
            {
                dateText = Date().relativeDateString(since: lastUpdatedDate, dateFormatter: Date.shortDateFormatter)
            }
            else
            {
                dateText = "Chưa từng"
            }
                            
            let text = String(format: "Cập nhật lần cuối: %@", dateText)
            cell.bannerView.subtitleLabel.text = text
            cell.bannerView.subtitleLabel.numberOfLines = 1
            
            let numberOfAppsText = "\(numberOfApps) ứng dụng"
            
            let accessibilityLabel = source.name + "\n" + text + ".\n" + numberOfAppsText
            cell.bannerView.accessibilityLabel = accessibilityLabel
                        
            if source.identifier != Source.altStoreIdentifier
            {
                cell.accessories = [.delete(displayed: .whenEditing)]
            }
            else
            {
                cell.accessories = []
            }
            
            cell.bannerView.accessibilityTraits.remove(.button)
            
            // Make sure refresh button is correct size.
            cell.layoutIfNeeded()
        }
        dataSource.prefetchHandler = { (source, indexPath) in
            guard let imageURL = source.effectiveIconURL else { return nil }
            return try await ImagePipeline.shared.image(for: imageURL)
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! AppBannerCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
            
            if let error = error
            {
                debugLog("Error loading image: \(error)")
            }
        }
        
        return dataSource
    }
    
    @IBSegueAction
    func makeSourceDetailViewController(_ coder: NSCoder, sender: Any?) -> UIViewController?
    {
        guard let source = sender as? Source else { return nil }
        
        let sourceDetailViewController = SourceDetailViewController(source: source, coder: coder)
        return sourceDetailViewController
    }
    
    @IBAction
    func unwindFromAddSource(_ segue: UIStoryboardSegue)
    {
    }
}

private extension SourcesViewController
{
    func handleAddSourceDeepLink()
    {
        Task {
            guard let url = self.deepLinkSourceURL, self.view.window != nil else { return }
            
            // Only handle deep link once.
            self.deepLinkSourceURL = nil
            
            self.navigationItem.leftBarButtonItem?.isIndicatingActivity = true
            
            func finish(_ result: Result<Void, Error>)
            {
                DispatchQueue.main.async {
                    switch result
                    {
                    case .success: break
                    case .failure(let error) where error is CancellationError: break
                        
                    case .failure(var error as SourceError):
                        let title = String(format: "Không thể thêm “%@” vào SideStore.", error.$source.name)
                        error.errorTitle = title
                        self.present(error)
                        
                    case .failure(let error as NSError):
                        self.present(error.withLocalizedTitle("Không thể thêm Nguồn"))
                    }
                    
                    self.navigationItem.leftBarButtonItem?.isIndicatingActivity = false
                }
            }
            
            do {
                let backgroundContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
                let source = try await AppManager.shared.fetchSource(sourceURL: url, managedObjectContext: backgroundContext)
                await MainActor.run {
                    showSourceDetails(for: source)
                }
                finish(.success(()))
            } catch {
                finish(.failure(error))
            }
        }
    }

    func present(_ error: Error)
    {
        if let transitionCoordinator = self.transitionCoordinator
        {
            transitionCoordinator.animate(alongsideTransition: nil) { _ in
                self.present(error)
            }
            
            return
        }
        
        let nsError = error as NSError
        let title = nsError.localizedTitle // OK if nil.
        let message = [nsError.localizedDescription, nsError.localizedDebugDescription, nsError.localizedRecoverySuggestion].compactMap { $0 }.joined(separator: "\n\n")
        
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(.ok)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func remove(_ source: Source, completionHandler: ((Bool) -> Void)? = nil)
    {
        Task {
            do
            {
                try await AppManager.shared.remove(source, presentingViewController: self)
                
                completionHandler?(true)
            }
            catch is CancellationError
            {
                completionHandler?(false)
            }
            catch
            {
                completionHandler?(false)
                self.present(error)
            }
        }
    }
    
    func showSourceDetails(for source: Source)
    {
        self.performSegue(withIdentifier: "showSourceDetails", sender: source)
    }
    
    func update()
    {
        let sources = self.dataSource.fetchedResultsController.fetchedObjects ?? []
        let hasOtherSources = sources.contains { $0.identifier != Source.altStoreIdentifier }
        
        if !hasOtherSources
        {
            // Hiển thị khung hướng dẫn thêm nguồn mới
            
            self.placeholderView.isHidden = false
            self.collectionView.alwaysBounceVertical = false
            
            self.setEditing(false, animated: true)
        }
        else
        {
            self.placeholderView.isHidden = true
            self.collectionView.alwaysBounceVertical = true
        }
    }
    
    @objc func showInstallingAppToastView(_ notification: Notification)
    {
        guard let app = notification.object as? StoreApp else { return }
        self._installingApp = app
        
        let text = String(format: "Đang tải xuống %@…", app.name)        
        let toastView = ToastView(text: text, detailText: "Nhấn để xem tiến trình.")
        toastView.addTarget(self, action: #selector(SourcesViewController.showAppDetail), for: .touchUpInside)
        toastView.show(in: self)
    }
    
    @objc func showAppDetail()
    {
        guard let app = self._installingApp else { return }
        self._installingApp = nil
        
        let appViewController = AppViewController.makeAppViewController(app: app)
        self.navigationController?.pushViewController(appViewController, animated: true)
    }
}

extension SourcesViewController
{
    override func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath)
    {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
            cell.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath)
    {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return }
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.65, initialSpringVelocity: 0.5, options: [.allowUserInteraction]) {
            cell.transform = .identity
        }
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        self.collectionView.deselectItem(at: indexPath, animated: true)
        
        let source = self.dataSource.item(at: indexPath)
        self.showSourceDetails(for: source)
    }
}

extension SourcesViewController: NSFetchedResultsControllerDelegate
{
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) 
    {
        self.dataSource.controllerWillChangeContent(controller)
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) 
    {
        self.dataSource.controllerDidChangeContent(controller)
        
        self.update()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) 
    {
        self.dataSource.controller(controller, didChange: anObject, at: indexPath, for: type, newIndexPath: newIndexPath)
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) 
    {
        self.dataSource.controller(controller, didChange: sectionInfo, atSectionIndex: sectionIndex, for: type)
    }
}
