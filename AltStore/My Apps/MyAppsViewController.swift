
//
//  MyAppsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/16/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import MobileCoreServices
import Combine

import AltStoreCore
import Roxas

extension MyAppsViewController
{
    private enum Section: Int, CaseIterable
    {
        case updates = 0
        case activeApps
        case inactiveApps
    }
    
    private enum Layout: String, CaseIterable
    {
        case row = "row"
        case card = "card"
        
        var icon: UIImage? {
            switch self
            {
            case .row: return UIImage(systemName: "rectangle.grid.1x2")
            case .card: return UIImage(systemName: "list.bullet")
            }
        }
        
        mutating func toggle()
        {
            switch self {
            case .row: self = .card
            case .card: self = .row
            }
        }
    }
}

final class MyAppsSectionHeaderView: UICollectionReusableView
{
    static let reuseIdentifier = "MyAppsSectionHeaderView"
    
    let titleLabel = UILabel()
    let underlineView = UIView()
    let actionButton = UIButton(type: .system)
    let activityIndicator = UIActivityIndicatorView(style: .medium)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = .clear
        
        let leftStack = UIStackView()
        leftStack.axis = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 6
        leftStack.translatesAutoresizingMaskIntoConstraints = false
        
        titleLabel.font = .systemFont(ofSize: 13.5, weight: .heavy)
        titleLabel.textColor = UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0)
        
        underlineView.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        underlineView.layer.cornerRadius = 1.5
        underlineView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            underlineView.widthAnchor.constraint(equalToConstant: 36),
            underlineView.heightAnchor.constraint(equalToConstant: 3)
        ])
        
        leftStack.addArrangedSubview(titleLabel)
        leftStack.addArrangedSubview(underlineView)
        addSubview(leftStack)
        
        actionButton.titleLabel?.font = .systemFont(ofSize: 12.5, weight: .bold)
        actionButton.setTitleColor(UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0), for: .normal)
        actionButton.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        actionButton.layer.cornerRadius = 14
        actionButton.layer.borderWidth = 1.0
        actionButton.layer.borderColor = UIColor.white.cgColor
        actionButton.layer.shadowColor = UIColor(red: 0.15, green: 0.10, blue: 0.38, alpha: 1.0).cgColor
        actionButton.layer.shadowOpacity = 0.06
        actionButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        actionButton.layer.shadowRadius = 6
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 13, bottom: 6, right: 13)
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(actionButton)
        
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            leftStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            leftStack.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            
            actionButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            actionButton.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            
            activityIndicator.centerXAnchor.constraint(equalTo: actionButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor)
        ])
    }
}

final class MyAppsTopBannerHeaderView: UICollectionReusableView
{
    static let reuseIdentifier = "MyAppsTopBannerHeaderView"
    
    private let bannerContainer = UIView()
    private let gradientLayer = CAGradientLayer()
    private let topRightGlowOrb = CAShapeLayer()
    private let bottomLeftGlowOrb = CAShapeLayer()
    let addIPAButton = UIButton(type: .system)
    var onAddIPATapped: (() -> Void)?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupBanner()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupBanner()
    }
    
    private func setupBanner() {
        backgroundColor = .clear
        
        bannerContainer.translatesAutoresizingMaskIntoConstraints = false
        bannerContainer.layer.cornerRadius = 18
        bannerContainer.layer.cornerCurve = .continuous
        bannerContainer.clipsToBounds = false
        bannerContainer.layer.shadowColor = UIColor(red: 0.0, green: 0.35, blue: 0.90, alpha: 1.0).cgColor
        bannerContainer.layer.shadowOpacity = 0.22
        bannerContainer.layer.shadowOffset = CGSize(width: 0, height: 8)
        bannerContainer.layer.shadowRadius = 18
        addSubview(bannerContainer)
        
        // Lớp nền chứa Gradient + Ánh sáng 3D (Ambient Orbs)
        let clipView = UIView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        clipView.layer.cornerRadius = 18
        clipView.layer.cornerCurve = .continuous
        clipView.layer.borderWidth = 1.0
        clipView.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        clipView.clipsToBounds = true
        bannerContainer.addSubview(clipView)
        
        gradientLayer.colors = [
            UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 0.44, green: 0.26, blue: 0.76, alpha: 1.0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        clipView.layer.addSublayer(gradientLayer)
        
        // 2 Vòng sáng 3D trang trí tạo chiều sâu sang trọng
        topRightGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.11).cgColor
        bottomLeftGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.08).cgColor
        clipView.layer.addSublayer(topRightGlowOrb)
        clipView.layer.addSublayer(bottomLeftGlowOrb)
        
        let titleStack = UIStackView()
        titleStack.axis = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 4
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = "Ứng dụng của tôi"
        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .white
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Quản lý, ký lại và cài đặt tệp IPA"
        subtitleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.90)
        
        titleStack.addArrangedSubview(titleLabel)
        titleStack.addArrangedSubview(subtitleLabel)
        bannerContainer.addSubview(titleStack)
        
        addIPAButton.setTitle("+ IPA", for: .normal)
        addIPAButton.setTitleColor(.white, for: .normal)
        addIPAButton.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .bold)
        addIPAButton.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        addIPAButton.layer.cornerRadius = 15
        addIPAButton.layer.borderWidth = 1.0
        addIPAButton.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        addIPAButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)
        addIPAButton.translatesAutoresizingMaskIntoConstraints = false
        addIPAButton.addTarget(self, action: #selector(handleAddTap), for: .touchUpInside)
        bannerContainer.addSubview(addIPAButton)
        
        NSLayoutConstraint.activate([
            bannerContainer.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            bannerContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            bannerContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            bannerContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            
            clipView.topAnchor.constraint(equalTo: bannerContainer.topAnchor),
            clipView.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor),
            clipView.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor),
            clipView.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor),
            
            titleStack.leadingAnchor.constraint(equalTo: bannerContainer.leadingAnchor, constant: 18),
            titleStack.topAnchor.constraint(equalTo: bannerContainer.topAnchor, constant: 16),
            titleStack.bottomAnchor.constraint(equalTo: bannerContainer.bottomAnchor, constant: -16),
            titleStack.trailingAnchor.constraint(lessThanOrEqualTo: addIPAButton.leadingAnchor, constant: -12),
            
            addIPAButton.trailingAnchor.constraint(equalTo: bannerContainer.trailingAnchor, constant: -16),
            addIPAButton.centerYAnchor.constraint(equalTo: bannerContainer.centerYAnchor)
        ])
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bannerContainer.bounds
        
        let b = bannerContainer.bounds
        topRightGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: b.width - 70, y: -35, width: 120, height: 120)).cgPath
        bottomLeftGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: -30, y: b.height - 45, width: 95, height: 95)).cgPath
    }
    
    @objc private func handleAddTap() {
        UIView.animate(withDuration: 0.1, animations: {
            self.addIPAButton.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0.8, options: .allowUserInteraction, animations: {
                self.addIPAButton.transform = .identity
            }, completion: nil)
        }
        onAddIPATapped?()
    }
}

final class MyAppsViewController: UICollectionViewController, PeekPopPreviewing, RunsAsync
{
    private lazy var dataSource = self.makeDataSource()
    private lazy var updatesDataSource = self.makeUpdatesDataSource()
    private lazy var installedAppsDataSource = self.makeInstalledAppsDataSource()
    private lazy var placeholderView = RSTPlaceholderView(frame: .zero)
    
    private var appIconBackgroundColors = [String: UIColor]()
    private var expandedAppUpdates = Set<String>()
    
    private var isRefreshingAllApps = false
    private var refreshAllAppsProgress: Progress?
    
    private varinstallingAppAlertWrapper: AlertViewControllerWrapper?
    private var installingAppHeaderView: AppBannerHeaderView?
    
    private var cancellables = Set<AnyCancellable>()
    private var updateCountObservation: NSKeyValueObservation?
    
    private var selectedLayout = Layout.row {
        didSet {
            self.updateLayout()
        }
    }
    
    private var isSupporter: Bool = true
    private let pageGradientLayer = CAGradientLayer()
    
    // MARK: - ViewController
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.overrideUserInterfaceStyle = .light
        
        // Nền Gradient chuẩn CSS Theme
        let bgView = UIView(frame: self.view.bounds)
        self.pageGradientLayer.colors = [
            UIColor(red: 0.953, green: 0.878, blue: 1.0, alpha: 1.0).cgColor, // #f3e0ff
            UIColor(red: 0.878, green: 0.969, blue: 1.0, alpha: 1.0).cgColor  // #e0f7ff
        ]
        self.pageGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        self.pageGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.pageGradientLayer.frame = self.view.bounds
        bgView.layer.insertSublayer(self.pageGradientLayer, at: 0)
        self.collectionView.backgroundView = bgView
        self.collectionView.backgroundColor = .clear
        
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        refreshControl.addTarget(self, action: #selector(MyAppsViewController.handleRefreshControl(_:)), for: . primaryActionTriggered)
        self.collectionView.refreshControl = refreshControl
        
        self.collectionView.register(AppBannerFooterView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionFooter, withReuseIdentifier: "FooterView")
        self.collectionView.register(MyAppsSectionHeaderView.self, forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: MyAppsSectionHeaderView.reuseIdentifier)
        self.collectionView.register(MyAppsTopBannerHeaderView.self, forSupplementaryViewOfKind: "TopBannerHeader", withReuseIdentifier: MyAppsTopBannerHeaderView.reuseIdentifier)
        
        self.collectionView.register(ModernAppCardCell.self, forCellWithReuseIdentifier: "AppCell")
        self.collectionView.register(ModernAppCardCell.self, forCellWithReuseIdentifier: "AppCardCell")
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        
        if let layout = self.collectionView.collectionViewLayout as? UICollectionViewFlowLayout
        {
            layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        }
        
        self.placeholderView.textLabel.isHidden = false
        self.placeholderView.detailTextLabel.isHidden = true
        self.placeholderView.activityIndicatorView.style = .medium
        
        self.registerForPreviewing()
        
        self.CheckPatreonStatus()
        
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.didImportApp(_:)), name: AppDelegate.importFileDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.willUpdateApp(_:)), name: AppManager.willUpdateAppNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.didRefreshApp(_:)), name: AppManager.didRefreshAppNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(MyAppsViewController.BeginInstallApp(_:)), name: AppManager.beginInstallAppNotification, object: nil)
        
        self.selectedLayout = .row
        self.update()
        
        // Ẩn thanh Navigation Bar mặc định để sử dụng Hero Banner đồng bộ
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.updateDataSource()
        self.CheckPatreonStatus()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.pageGradientLayer.frame = self.collectionView.bounds
    }
}

private extension MyAppsViewController
{
    func CheckPatreonStatus()
    {
        self.isSupporter = true
    }
    
    func makeDataSource() -> RSTCompositeCollectionViewPrefetchingDataSource<NSManagedObject, UIImage>
    {
        let dataSource = RSTCompositeCollectionViewPrefetchingDataSource<NSManagedObject, UIImage>(dataSources: [self.updatesDataSource, self.installedAppsDataSource])
        dataSource.proxy = self
        
        dataSource.cellConfigurationHandler = { [weak self] (cell, item, indexPath) in
            guard let self = self else { return }
            
            let cell = cell as! ModernAppCardCell
            let section = Section.allCases[indexPath.section]
            switch section
            {
            case .updates:
                let installedApp = item as! InstalledApp
                guard let update = installedApp.latestAvailableVersion else { break }
                
                cell.nameLabel.text = installedApp.name
                cell.bundleIDLabel.text = installedApp.bundleIdentifier
                cell.developerLabel.text = update.localizedVersion
                cell.versionLabel.text = (update.date as NSDate).relativeString()
                cell.updateBannerButton.isHidden = true
                
                cell.expirationPrefixLabel.text = "Cập nhật"
                cell.daysBadgeButton.setTitle("CẬP NHẬT", for: .normal)
                cell.daysBadgeButton.setTitleColor(UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0), for: .normal)
                cell.daysBadgeButton.backgroundColor = UIColor(red: 0.88, green: 0.94, blue: 1.0, alpha: 1.0)
                cell.daysBadgeButton.progress = AppManager.shared.updateProgress(for: installedApp)
                cell.daysBadgeButton.addTarget(self, action: #selector(MyAppsViewController.performAppAction(_:)), for: .primaryActionTriggered)
                
            case .activeApps, .inactiveApps:
                let installedApp = item as! InstalledApp
                cell.nameLabel.text = installedApp.name
                cell.bundleIDLabel.text = installedApp.bundleIdentifier
                cell.developerLabel.text = installedApp.storeApp?.developerName ?? "Ứng dụng tự cài (IPA)"
                cell.versionLabel.text = "Phiên bản \(installedApp.version)"
                
                let isActive = installedApp.isActive
                cell.rightColumnStack.isHidden = !isActive
                
                if let latestVersion = installedApp.latestAvailableVersion, installedApp.matches(latestVersion) == false {
                    cell.updateBannerButton.isHidden = false
                    cell.updateBannerButton.setTitle("Đã có bản cập nhật mới (\(latestVersion.localizedVersion)) - Chạm để cập nhật", for: .normal)
                    cell.updateButtonAction = { [weak self] in
                        self?.update(installedApp)
                    }
                } else {
                    cell.updateBannerButton.isHidden = true
                }
                
                let refreshProgress = AppManager.shared.refreshProgress(for: installedApp)
                let updateProgress = AppManager.shared.updateProgress(for: installedApp)
                let activeStatusProgress = [installedApp.bundleIdentifier].compactMap { self.activeStatusProgresses[$0] }.first
                cell.daysBadgeButton.progress = refreshProgress ?? updateProgress ?? activeStatusProgress
                
                let expirationDays = installedApp.expirationDate.numberOfCalendarDays(since: Date())
                if expirationDays > 0 {
                    cell.expirationPrefixLabel.text = "Hết hạn sau"
                    cell.daysBadgeButton.setTitle("\(expirationDays) NGÀY", for: .normal)
                    if expirationDays <= 2 {
                        cell.daysBadgeButton.backgroundColor = UIColor(red: 1.0, green: 0.90, blue: 0.90, alpha: 1.0)
                        cell.daysBadgeButton.setTitleColor(UIColor(red: 0.85, green: 0.15, blue: 0.20, alpha: 1.0), for: .normal)
                    } else {
                        cell.daysBadgeButton.backgroundColor = UIColor(red: 0.88, green: 0.98, blue: 0.92, alpha: 1.0)
                        cell.daysBadgeButton.setTitleColor(UIColor(red: 0.06, green: 0.55, blue: 0.36, alpha: 1.0), for: .normal)
                    }
                } else {
                    let formatter = DateComponentsFormatter()
                    formatter.unitsStyle = .full
                    formatter.allowedUnits = [.minute, .hour]
                    formatter.maximumUnitCount = 1
                    
                    let currentDate = Date()
                    if currentDate > installedApp.expirationDate {
                        cell.expirationPrefixLabel.text = "Trạng thái"
                        cell.daysBadgeButton.setTitle("HẾT HẠN", for: .normal)
                    } else if var timeLeftText = formatter.string(from: currentDate, to: installedApp.expirationDate) {
                        timeLeftText = timeLeftText
                            .replacingOccurrences(of: "hours", with: "GIỜ")
                            .replacingOccurrences(of: "hour", with: "GIỜ")
                            .replacingOccurrences(of: "minutes", with: "PHÚT")
                            .replacingOccurrences(of: "minute", with: "PHÚT")
                            .uppercased()
                        cell.expirationPrefixLabel.text = "Hết hạn sau"
                        cell.daysBadgeButton.setTitle(timeLeftText, for: .normal)
                    }
                    cell.daysBadgeButton.backgroundColor = UIColor(red: 1.0, green: 0.90, blue: 0.90, alpha: 1.0)
                    cell.daysBadgeButton.setTitleColor(UIColor(red: 0.85, green: 0.15, blue: 0.20, alpha: 1.0), for: .normal)
                }
                
                cell.daysBadgeButton.addTarget(self, action: #selector(MyAppsViewController.performAppAction(_:)), for: .primaryActionTriggered)
            }
            
            cell.iconImageView.image = nil
            cell.iconImageView.isIndicatingActivity = true
            
            cell.setNeedsLayout()
            cell.layoutIfNeeded()
        }
        
        dataSource.prefetchHandler = { (item, indexPath, completionHandler) in
            let installedApp = item as! InstalledApp
            let appID = installedApp.bundleIdentifier
            
            if indexPath.section == Section.updates.rawValue, let iconURL = installedApp.storeApp?.iconURL
            {
                return RSTAsyncBlockOperation() { (operation) in
                    ImageManager.shared.fetchImage(with: iconURL) { (result) in
                        guard !operation.isCancelled else { return operation.finish() }
                        switch result {
                        case .failure(let error): completionHandler(nil, error)
                        case .success((let image, _)): completionHandler(image, nil)
                        }
                    }
                }
            }
            else
            {
                return RSTAsyncBlockOperation { (operation) in
                    installedApp.ManagedObjectContext?.perform {
                        guard let icon = installedApp.icon?.resizing(toFill: CGSize(width: 100, height: 100)) else {
                            completionHandler(nil, nil)
                            return
                        }
                        if self.appIconBackgroundColors[appID] == nil {
                            self.appIconBackgroundColors[appID] = icon.averageColor()
                        }
                        completionHandler(icon, nil)
                    }
                }
            }
        }
        
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! ModernAppCardCell
            cell.iconImageView.isIndicatingActivity = false
            cell.iconImageView.image = image
            
            if error != nil {
                cell.iconImageView.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.12)
            } else {
                cell.iconImageView.backgroundColor = nil
            }
        }
        
        let placeholderView = RSTPlaceholderView()
        placeholderView.textLabel.text = "Chưa có ứng dụng nào"
        placeholderView.textLabel.textColor = UIColor(red: 0.15, green: 0.18, blue: 0.25, alpha: 1.0)
        placeholderView.detailTextLabel.text = "Chạm vào nút '+ IPA' ở góc trên bên phải để cài đặt ứng dụng đầu tiên của bạn."
        placeholderView.detailTextLabel.textColor = UIColor(red: 0.42, green: 0.46, blue: 0.52, alpha: 1.0)
        dataSource.placeholderView = placeholderView
        
        return dataSource
    }
    
    func makeUpdatesDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest = InstalledApp.updatesFetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: #keyPath(InstalledApp.storeApp.latestSupportedVersion.date), ascending: false),
                                        NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        // Đã gộp thông báo cập nhật trực tiếp vào từng thẻ ứng dụng nên ẩn section riêng này để giao diện gọn gàng
        fetchRequest.predicate = NSPredicate(value: false)
        
        let updatesDataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        return updatesDataSource
    }
    
    func makeInstalledAppsDataSource() -> RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>
    {
        let fetchRequest: NSFetchRequest<InstalledApp> = InstalledApp.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "(%K == NO) AND NOT (%K IN %@)",
                                             #keyPath(InstalledApp.isSideloaded),
                                             #keyPath(InstalledApp.bundleIdentifier), [StoreApp.altStoreAppID])
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \InstalledApp.isActive, ascending: false),
                                        NSSortDescriptor(keyPath: \InstalledApp.name, ascending: true)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let installedAppsDataSource = RSTFetchedResultsCollectionViewPrefetchingDataSource<InstalledApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(InstalledApp.isActive))
        return installedAppsDataSource
    }
    
    func makeLayout() -> UICollectionViewCompositionalLayout
    {
        let config = UICollectionViewCompositionalLayoutConfiguration()
        let topBannerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(88))
        let topBannerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: topBannerSize, elementKind: "TopBannerHeader", alignment: .top)
        config.boundarySupplementaryItems = [topBannerItem]
        
        let layout = UICollectionViewCompositionalLayout(sectionProvider: { [weak self] (sectionIndex, layoutEnvironment) -> NSCollectionLayoutSection? in
            guard let self = self else { return nil }
            guard sectionIndex < Section.allCases.count else { return nil }
            
            let sectionType = Section.allCases[sectionIndex]
            if sectionType == .updates {
                let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(0.1))
                let item = NSCollectionLayoutItem(layoutSize: itemSize)
                let group = NSCollectionLayoutGroup.horizontal(layoutSize: itemSize, subitems: [item])
                return NSCollectionLayoutSection(group: group)
            }
            
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(98))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .estimated(98))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            
            let layoutSection = NSCollectionLayoutSection(group: group)
            layoutSection.interGroupSpacing = 6
            layoutSection.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 0, bottom: 20, trailing: 0)
            
            let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(46))
            let headerItem = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize, elementKind: UICollectionView.elementKindSectionHeader, alignment: .top)
            layoutSection.boundarySupplementaryItems = [headerItem]
            
            return layoutSection
        }, configuration: config)
        
        return layout
    }
    
    func updateLayout()
    {
        self.collectionView.collectionViewLayout = self.makeLayout()
        self.collectionView.reloadData()
    }
    
    func updateDataSource()
    {
        var predicates = [NSPredicate]()
        
        if !UserDefaults.standard.isLegacyDeactivationSupported
        {
            let activeAppsPredicate = NSPredicate(format: "%K == YES", #keyPath(InstalledApp.isActive))
            predicates.append(activeAppsPredicate)
        }
        
        if !self.isSupporter
        {
            let nonSideloadedAppsPredicate = NSPredicate(format: "(%K == NO) AND NOT (%K IN %@)",
                                                         #keyPath(InstalledApp.isSideloaded),
                                                         #keyPath(InstalledApp.bundleIdentifier), [StoreApp.altStoreAppID])
            predicates.append(nonSideloadedAppsPredicate)
        }
        
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        self.installedAppsDataSource.predicate = predicate
    }
    
    func update()
    {
        // Đã chuyển sang Hero Banner đồng bộ ở trên cùng
    }
    
    @IBAction func toggleLayout(_ sender: UIBarButtonItem)
    {
        self.selectedLayout.toggle()
        self.update()
    }
    
    @objc func handleRefreshControl(_ sender: UIRefreshControl)
    {
        AppManager.shared.fetchSources() { (result) in
            DispatchQueue.main.async {
                sender.endRefreshing()
                
                switch result
                {
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.show(in: self)
                    
                case .success((_, let context)):
                    do
                    {
                        try context.save()
                    }
                    catch
                    {
                        let toastView = ToastView(error: error)
                        toastView.show(in: self)
                    }
                }
                
                self.collectionView.reloadData()
            }
        }
    }
    
    @objc func performAppAction(_ sender: PillButton)
    {
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let installedApp = self.dataSource.item(at: indexPath) as! InstalledApp
        
        let section = Section.allCases[indexPath.section]
        switch section
        {
        case .updates: self.update(installedApp)
        case .activeApps: self.refresh([installedApp])
        case .inactiveApps: self.activate(installedApp)
        }
    }
    
    @objc func refreshAllApps(_ sender: UIButton)
    {
        guard let activeApps = self.installedAppsDataSource.fetchedResultsController.sections?.first?.objects as? [InstalledApp] else { return }
        
        self.isRefreshingAllApps = true
        self.collectionView.reloadSections(IndexSet(integer: Section.activeApps.rawValue))
        
        let group = AppManager.shared.refresh(activeApps, presentingViewController: self)
        self.refreshAllAppsProgress = group.progress
        
        group.completionHandler = { (results) in
            DispatchQueue.main.async {
                self.isRefreshingAllApps = false
                self.refreshAllAppsProgress = nil
                self.collectionView.reloadSections(IndexSet(integer: Section.activeApps.rawValue))
                
                var errors = [Error]()
                for (_, result) in results
                {
                    guard case .failure(let error) = result else { continue }
                    errors.append(error)
                }
                
                if let error = errors.first
                {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                }
            }
        }
    }
    
    func refresh(_ installedApps: [InstalledApp])
    {
        var indexPaths = [IndexPath]()
        
        for app in installedApps
        {
            guard let indexPath = self.installedAppsDataSource.fetchedResultsController.indexPath(forObject: app) else { continue }
            indexPaths.append(IndexPath(item: indexPath.item, section: indexPath.section + 1))
        }
        
        let group = AppManager.shared.refresh(installedApps, presentingViewController: self)
        group.completionHandler = { (results) in
            DispatchQueue.main.async {
                var errors = [Error]()
                
                for (_, result) in results
                {
                    guard case .failure(let error) = result else { continue }
                    errors.append(error)
                }
                
                if let error = errors.first
                {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                }
                
                self.collectionView.reloadSections(IndexSet(integer: Section.activeApps.rawValue))
            }
        }
        
        self.collectionView.reloadItems(at: indexPaths)
    }
    
    func update(_ installedApp: InstalledApp)
    {
        let previousVersion = installedApp.version
        
        AppManager.shared.update(installedApp, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(OperationError.cancelled): break
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                    
                case .success:
                    print("Updated app:", installedApp.bundleIdentifier, "from version:", previousVersion, "to version:", installedApp.version)
                }
                
                self.collectionView.reloadData()
            }
        }
        
        self.collectionView.reloadData()
    }
    
    @objc func willUpdateApp(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    @objc func didRefreshApp(_ notification: Notification)
    {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    func open(_ installedApp: InstalledApp, completionHandler: ((Result<Void, Error>) -> Void)? = nil)
    {
        UIApplication.shared.open(installedApp.openAppURL) { (success) in
            if success
            {
                completionHandler?(.success(()))
            }
            else
            {
                completionHandler?(.failure(OperationError.openAppFailed(name: installedApp.name)))
            }
        }
    }
}

private var activeStatusProgresses = [String: Progress]()
private extension MyAppsViewController
{
    var activeStatusProgresses: [String: Progress] {
        get { return AltStore.activeStatusProgresses }
        set { AltStore.activeStatusProgresses = newValue }
    }
    
    @IBAction func importApp(_ sender: UIBarButtonItem)
    {
        let importController = UIDocumentPickerViewController(documentTypes: ["com.rileytestut.ipa", kUTTypeArchive as String], in: .import)
        importController.delegate = self
        self.present(importController, animated: true, completion: nil)
    }
    
    func promptImportApp()
    {
        let importController = UIDocumentPickerViewController(documentTypes: ["com.rileytestut.ipa", kUTTypeArchive as String], in: .import)
        importController.delegate = self
        self.present(importController, animated: true, completion: nil)
    }
    
    @objc func didImportApp(_ notification: Notification)
    {
        guard let fileURL = notification.userInfo?[AppDelegate.importFileDeepLinkURLKey] as? URL else { return }
        self.installApp(at: fileURL)
    }

    @objc func BeginInstallApp(_ notification: Notification)
    {
        guard let fileURL = notification.object as? URL else { return }
        self.installApp(at: fileURL)
    }
    
    func installApp(at fileURL: URL)
    {
        async {
            let cleanUp = {
                try? FileManager.default.removeItem(at: fileURL)
                await MainActor.run {
                    self.installingAppHeaderView = nil
                    self.varinstallingAppAlertWrapper = nil
                }
            }
            
            do {
                let isDirectory: Bool = try {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    return resourceValues.isDirectory ?? false
                }()
                
                let appBundleURL: URL
                let temporaryDirectory = FileManager.default.uniqueTemporaryURL()
                try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true, attributes: nil)
                defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
                
                if isDirectory {
                    appBundleURL = fileURL
                } else {
                    appBundleURL = try await Task.detached{
                        try FileManager.default.unzipAppBundle(at: fileURL, toDirectory: temporaryDirectory)
                    }.value
                }
                
                guard let application = Application(fileURL: appBundleURL) else { throw OperationError.invalidApp }
                
                guard await InstallAppDialog.shared.show(application: application, presentingViewController: self) else {
                    return try await cleanUp()
                }
                
                let progress: Progress = await MainActor.run{
                    let progress = Progress.discreteProgress(totalUnitCount: 100)
                    let wrapper = AlertViewControllerWrapper(
                        title: NSLocalizedString("Đang cài đặt ứng dụng", comment: ""),
                        message: nil,
                        preferredStyle: .alert,
                        progress: progress
                    )
                    self.varinstallingAppAlertWrapper = wrapper
                    
                    let headerView = wrapper.configureHeaderView(for: application)
                    self.installingAppHeaderView = headerView
                    
                    self.present(wrapper.alertController, animated: true)
                    return progress
                }

                let group = AppManager.shared.install(application, presentingViewController: self)
                progress.addChild(group.progress, withPendingUnitCount: 100)

                group.completionHandler = { result in
                    DispatchQueue.main.async {
                        self.varinstallingAppAlertWrapper?.ensureDismissed() {
                            switch result
                            {
                            case .failure(OperationError.cancelled): break
                            case .failure(let error):
                                let toastView = ToastView(error: error)
                                toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                                toastView.show(in: self)
                            case .success: print("Installed app:", application.bundleIdentifier)
                            }
                            
                            cleanUp()
                            self.collectionView.reloadData()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self.navigationController?.view ?? self.view, duration: 4.0)
                }
                try? await cleanUp()
            }
        }
    }
    
    func activate(_ installedApp: InstalledApp)
    {
        let progress = AppManager.shared.activate(installedApp, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                self.activeStatusProgresses[installedApp.bundleIdentifier] = nil
                
                if case .failure(let error) = result
                {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                }
                
                self.collectionView.reloadData()
            }
        }
        
        self.activeStatusProgresses[installedApp.bundleIdentifier] = progress
        self.collectionView.reloadData()
    }
    
    func deactivate(_ installedApp: InstalledApp)
    {
        let progress = AppManager.shared.deactivate(installedApp, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                self.activeStatusProgresses[installedApp.bundleIdentifier] = nil
                
                if case .failure(let error) = result
                {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                }
                
                self.collectionView.reloadData()
            }
        }
        
        self.activeStatusProgresses[installedApp.bundleIdentifier] = progress
        self.collectionView.reloadData()
    }
    
    func remove(_ installedApp: InstalledApp)
    {
        let deleteAlertViewController = DeleteAppAlertViewController(installedApp: installedApp) { [weak self] shouldDeleteConfirmed, shouldDeleteAppID in
            guard let self else { return }

            if shouldDeleteConfirmed {
                AppManager.shared.remove(installedApp, shouldKeepAppId: !shouldDeleteAppID) { (result) in
                    DispatchQueue.main.async {
                        self.activeStatusProgresses[installedApp.bundleIdentifier] = nil
                        
                        if case .failure(let error) = result
                        {
                            let toastView = ToastView(error: error)
                            toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                            toastView.show(in: self)
                        }
                        self.collectionView.reloadData()
                    }
                }
            }
        }
        
        self.present(deleteAlertViewController.alertController, animated: true, completion: nil)
    }
    
    func backup(_ installedApp: InstalledApp)
    {
        let progress = AppManager.shared.backup(installedApp, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                self.activeStatusProgresses[installedApp.bundleIdentifier] = nil
                
                if case .failure(let error) = result
                {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                }
                
                self.collectionView.reloadData()
            }
        }
        
        self.activeStatusProgresses[installedApp.bundleIdentifier] = progress
        self.collectionView.reloadData()
    }
    
    func restore(_ installedApp: InstalledApp)
    {
        let progress = AppManager.shared.restore(installedApp, presentingViewController: self) { (result) in
            DispatchQueue.main.async {
                self.activeStatusProgresses[installedApp.bundleIdentifier] = nil
                
                if case .failure(let error) = result
                {
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                }
                
                self.collectionView.reloadData()
            }
        }
        
        self.activeStatusProgresses[installedApp.bundleIdentifier] = progress
        self.collectionView.reloadData()
    }
    
    func enableJIT(for installedApp: InstalledApp)
    {
        AppManager.shared.enableJIT(for: installedApp) { (result) in
            DispatchQueue.main.async {
                switch result
                {
                case .failure(let error):
                    let toastView = ToastView(error: error)
                    toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                    toastView.show(in: self)
                    
                case .success:
                    print("Successfully enabled JIT for \(installedApp.name)!")
                }
            }
        }
    }
}

extension MyAppsViewController
{
    override func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView
    {
        if kind == "TopBannerHeader" {
            let banner = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: MyAppsTopBannerHeaderView.reuseIdentifier, for: indexPath) as! MyAppsTopBannerHeaderView
            banner.onAddIPATapped = { [weak self] in
                self?.promptImportApp()
            }
            return banner
        }
        
        if kind == UICollectionView.elementKindSectionFooter {
            let footerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: "FooterView", for: indexPath) as! AppBannerFooterView
            footerView.button.isHidden = true
            return footerView
        }
        
        let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: kind, withReuseIdentifier: MyAppsSectionHeaderView.reuseIdentifier, for: indexPath) as! MyAppsSectionHeaderView
        
        let itemCount = self.dataSource.collectionView(collectionView, numberOfItemsInSection: indexPath.section)
        let section = Section.allCases[indexPath.section]
        
        headerView.actionButton.removeTarget(self, action: nil, for: .primaryActionTriggered)
        
        switch section
        {
        case .updates:
            headerView.titleLabel.text = "CẬP NHẬT (\(itemCount))"
            headerView.actionButton.isHidden = true
            headerView.activityIndicator.stopAnimating()
            
        case .activeApps:
            headerView.actionButton.setTitle("Làm mới tất cả", for: .normal)
            headerView.actionButton.addTarget(self, action: #selector(MyAppsViewController.refreshAllApps(_:)), for: .primaryActionTriggered)
            
            if UserDefaults.standard.isLegacyDeactivationSupported, let team = DatabaseManager.shared.activeTeam(), team.type == .free {
                headerView.titleLabel.text = "ĐANG HOẠT ĐỘNG (\(itemCount)/3)"
            } else {
                headerView.titleLabel.text = "ĐANG HOẠT ĐỘNG (\(itemCount))"
            }
            
            if self.isRefreshingAllApps {
                headerView.actionButton.isHidden = true
                headerView.activityIndicator.startAnimating()
            } else {
                headerView.actionButton.isHidden = (itemCount == 0)
                headerView.activityIndicator.stopAnimating()
            }
            
        case .inactiveApps:
            headerView.titleLabel.text = "ĐÃ TẮT (\(itemCount))"
            headerView.actionButton.isHidden = true
            headerView.activityIndicator.stopAnimating()
        }
        
        return headerView
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        collectionView.deselectItem(at: indexPath, animated: true)
        
        let installedApp = self.dataSource.item(at: indexPath) as! InstalledApp
        guard installedApp.isActive else { return }
        
        let alert = UIAlertController(title: installedApp.name, message: "Phiên bản \(installedApp.version) • \(installedApp.bundleIdentifier)", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Mở ứng dụng", style: .default) { [weak self] _ in
            self?.open(installedApp)
        })
        
        alert.addAction(UIAlertAction(title: "Làm mới ngay (Gia hạn 7 ngày)", style: .default) { [weak self] _ in
            self?.refresh([installedApp])
        })
        
        alert.addAction(UIAlertAction(title: "Bật tăng tốc JIT", style: .default) { [weak self] _ in
            self?.enableJIT(for: installedApp)
        })
        
        if let latestVersion = installedApp.latestAvailableVersion, !installedApp.matches(latestVersion) {
            alert.addAction(UIAlertAction(title: "Cập nhật lên bản \(latestVersion.localizedVersion)", style: .default) { [weak self] _ in
                self?.update(installedApp)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Xóa ứng dụng", style: .destructive) { [weak self] _ in
            self?.remove(installedApp)
        })
        
        alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        
        if let popover = alert.popoverPresentationController, let cell = collectionView.cellForItem(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        
        self.present(alert, animated: true)
    }
}

extension MyAppsViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        let itemCount = self.dataSource.collectionView(collectionView, numberOfItemsInSection: section)
        if itemCount == 0
        {
            return .zero
        }
        else
        {
            return CGSize(width: collectionView.bounds.width, height: 46)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize
    {
        return .zero
    }
}

extension MyAppsViewController
{
    func previewViewController(at point: CGPoint) -> UIViewController?
    {
        return nil
    }
    
    @available(iOS 13.0, *)
    override func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        guard Section.allCases[indexPath.section] != .updates else { return nil }
        guard let installedApp = self.dataSource.item(at: indexPath) as? InstalledApp else { return nil }
        let appName = installedApp.name
        
        return UIContextMenuConfiguration(identifier: indexPath as NSIndexPath, previewProvider: { return nil }) { (suggestedActions) -> UIMenu? in
            
            let openAction = UIAction(title: NSLocalizedString("Mở ứng dụng", comment: ""), image: UIImage(systemName: "arrow.up.forward.app")) { [weak self] (action) in
                self?.open(installedApp)
            }
            
            let refreshAction = UIAction(title: NSLocalizedString("Làm mới (Gia hạn)", comment: ""), image: UIImage(systemName: "arrow.clockwise")) { [weak self] (action) in
                self?.refresh([installedApp])
            }
            
            let deactivateAction = UIAction(title: NSLocalizedString("Hủy kích hoạt", comment: ""), image: UIImage(systemName: "xmark.octagon"), attributes: [.destructive]) { [weak self] (action) in
                self?.deactivate(installedApp)
            }
            
            let activateAction = UIAction(title: NSLocalizedString("Kích hoạt", comment: ""), image: UIImage(systemName: "bolt")) { [weak self] (action) in
                self?.activate(installedApp)
            }
            
            let backupAction = UIAction(title: NSLocalizedString("Sao lưu dữ liệu", comment: ""), image: UIImage(systemName: "arrow.down.doc")) { [weak self] (action) in
                self?.backup(installedApp)
            }
            
            let restoreAction = UIAction(title: NSLocalizedString("Khôi phục dữ liệu", comment: ""), image: UIImage(systemName: "arrow.up.doc")) { [weak self] (action) in
                self?.restore(installedApp)
            }
            
            let removeAction = UIAction(title: NSLocalizedString("Xóa ứng dụng", comment: ""), image: UIImage(systemName: "trash"), attributes: [.destructive]) { [weak self] (action) in
                self?.remove(installedApp)
            }
            
            let enableJITAction = UIAction(title: NSLocalizedString("Bật tăng tốc JIT", comment: ""), image: UIImage(systemName: "cpu")) { [weak self] (action) in
                self?.enableJIT(for: installedApp)
            }
            
            let resignAction = UIAction(
                title: "Ký lại (Resign)",
                image: UIImage(systemName: "signature"),
                identifier: nil,
                discoverabilityTitle: nil,
                attributes: [],
                state: .off
            ) { [weak self] _ in
                self?.resignApp(installedApp)
            }
            
            let reinstallAction = UIAction(
                title: "Cài đặt lại (Reinstall)",
                image: UIImage(systemName: "arrow.triangle.2.circlepath.circle"),
                identifier: nil,
                discoverabilityTitle: nil,
                attributes: [],
                state: .off
            ) { [weak self] _ in
                self?.reinstallApp(installedApp)
            }

            var menuActions = [UIMenuElement]()
            if installedApp.isActive
            {
                let backupMenu = UIMenu(title: NSLocalizedString("Sao lưu & Khôi phục", comment: ""), image: UIImage(systemName: "externaldrive"), children: [backupAction, restoreAction])
                let profileMenu = self.getProfileAction(for: installedApp)

                menuActions.append(openAction)
                menuActions.append(refreshAction)
                menuActions.append(resignAction)
                menuActions.append(reinstallAction)
                menuActions.append(profileMenu)
                
                if !installedApp.isAltStoreApp
                {
                    menuActions.append(enableJITAction)
                    
                    let changeIconAction = self.changeIconMenuElement(for: installedApp)
                    menuActions.append(changeIconAction)
                    
                    let appInfoAction = self.getAppInfoMenuElement(for: installedApp)
                    menuActions.append(appInfoAction)
                    
                    if UserDefaults.standard.isLegacyDeactivationSupported
                    {
                        let removeMenu = UIMenu(title: "", options: .displayInline, children: [backupMenu, deactivateAction, removeAction])
                        menuActions.append(removeMenu)
                    }
                    else
                    {
                        let removeMenu = UIMenu(title: "", options: .displayInline, children: [removeAction])
                        menuActions.append(removeMenu)
                    }
                }
            }
            else
            {
                let removeMenu = UIMenu(title: "", options: .displayInline, children: [restoreAction, removeAction])
                menuActions = [activateAction, removeMenu]
            }
            
            return UIMenu(title: appName, children: menuActions)
        }
    }

    private func getAppInfoMenuElement(for installedApp: InstalledApp) -> UIMenuElement{
        return UIAction(
            title: "Thông tin chi tiết",
            image: UIImage(systemName: "info.circle"),
            identifier: nil,
            discoverabilityTitle: nil,
            attributes: [],
            state: .off
        ) { [weak self] _ in
            guard let self else { return }
            let controller = AppInfoView(for: installedApp).makeViewController()
            let nav = UINavigationController(rootViewController: controller)
            if #available(iOS 15.0, *), let sheet = nav.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
            }
            present(nav, animated: true, completion: nil)
        }
    }
    
    func getProfileAction(for installedApp: InstalledApp) -> UIMenuElement {
        let installProfileAction = UIAction(title: NSLocalizedString("Cài đặt hồ sơ", comment: ""), image: UIImage(systemName: "arrow.down.doc")) { [weak self] (action) in
            guard let self else { return }
            AppManager.shared.installProvisioningProfile(for: installedApp, presentingViewController: self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                    case .success:
                        break
                    }
                }
            }
        }
        
        let removeProfileAction = UIAction(title: NSLocalizedString("Xóa hồ sơ", comment: ""), image: UIImage(systemName: "trash"), attributes: [.destructive]) { [weak self] (action) in
            guard let self else { return }
            AppManager.shared.removeProvisioningProfile(for: installedApp, presentingViewController: self) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                    case .success:
                        break
                    }
                }
            }
        }
        return UIMenu(title: NSLocalizedString("Hồ sơ cấu hình (Profile)", comment: ""), image: UIImage(systemName: "doc.badge.gearshape"), children: [installProfileAction, removeProfileAction])
    }
    
    func changeIconMenuElement(for installedApp: InstalledApp) -> UIMenuElement {
        let changeAction = UIAction(title: "Chọn biểu tượng mới", image: UIImage(systemName: "photo.on.rectangle")) { [weak self] _ in
            self?.presentIconImporter(for: installedApp)
        }

        let resetAction = UIAction(title: "Khôi phục mặc định", image: UIImage(systemName: "arrow.uturn.backward"), attributes: [.destructive]) { [weak self] _ in
            self?.restoreDefaultIcon(for: installedApp)
        }
        
        var children = [changeAction]
        let hasCustomIcon = installedApp.hasAlternateIcon
        if hasCustomIcon {
            children.append(resetAction)
        }
        
        let menu = UIMenu(title: "Đổi biểu tượng (Icon)", image: UIImage(systemName: "app.badge"), children: children)
        return menu
    }
    
    func restoreDefaultIcon(for installedApp: InstalledApp) {
        self.changeIcon(for: installedApp, with: nil)
    }

    func presentIconImporter(for installedApp: InstalledApp) {
        let picker = ImagePicker.shared
        picker.present(from: self) { [weak self] image in
            guard let self = self, let image = image else { return }
            self.changeIcon(for: installedApp, with: image)
        }
    }
    
    func changeIcon(for installedApp: InstalledApp, with image: UIImage?) {
        let progress = Progress.discreteProgress(totalUnitCount: 100)
        let wrapper = AlertViewControllerWrapper(
            title: NSLocalizedString("Đang đổi biểu tượng", comment: ""),
            message: nil,
            preferredStyle: .alert,
            progress: progress
        )
        self.varinstallingAppAlertWrapper = wrapper
        
        let headerView = wrapper.configureHeaderView(for: installedApp.bundleURL)
        self.installingAppHeaderView = headerView

        if let image = image {
            headerView?.iconImageView.image = image
        }
        self.present(wrapper.alertController, animated: true)

        let group = AppManager.shared.changeIcon(installedApp, to: image, presentingViewController: self)
        progress.addChild(group.progress, withPendingUnitCount: 100)

        group.completionHandler = { result in
            DispatchQueue.main.async {
                let cleanup = {
                    self.installingAppHeaderView = nil
                    self.varinstallingAppAlertWrapper = nil
                    self.collectionView.reloadData()
                }
                
                self.varinstallingAppAlertWrapper?.ensureDismissed(){
                    if case .failure(let error) = result, case OperationError.cancelled = error {
                        // Ignore
                    } else if case .failure(let error) = result {
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                    }
                    cleanup()
                }
            }
        }
    }
    
    func resignApp(_ installedApp: InstalledApp) {
        self.refresh([installedApp])
    }
    
    func reinstallApp(_ installedApp: InstalledApp) {
        let progress = Progress.discreteProgress(totalUnitCount: 100)
        let wrapper = AlertViewControllerWrapper(
            title: NSLocalizedString("Đang cài đặt lại", comment: ""),
            message: nil,
            preferredStyle: .alert,
            progress: progress
        )
        self.varinstallingAppAlertWrapper = wrapper
        self.installingAppHeaderView = wrapper.configureHeaderView(for: installedApp.bundleURL)
        
        self.present(wrapper.alertController, animated: true)

        let group = AppManager.shared.reinstall(installedApp, presentingViewController: self)
        progress.addChild(group.progress, withPendingUnitCount: 100)
        
        group.completionHandler = { result in
            DispatchQueue.main.async {
                let cleanup = {
                    self.installingAppHeaderView = nil
                    self.varinstallingAppAlertWrapper = nil
                    self.collectionView.reloadData()
                }
                
                self.varinstallingAppAlertWrapper?.ensureDismissed(){
                    switch result {
                    case .failure(OperationError.cancelled): break
                    case .failure(let error):
                        let toastView = ToastView(error: error)
                        toastView.addTarget(nil, action: #selector(TabBarController.presentErrorLogs(_:)), for: .touchUpInside)
                        toastView.show(in: self)
                    case .success:
                        print("Reinstalled app:", installedApp.bundleIdentifier)
                    }
                    cleanup()
                }
            }
        }
    }

    @available(iOS 13.0, *)
    override func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    {
        return nil
    }
    
    @available(iOS 13.0, *)
    override func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview?
    {
        return nil
    }
    
    @available(iOS 13.0, *)
    override func collectionView(_ collectionView: UICollectionView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating)
    {
    }
}

extension MyAppsViewController: UIDocumentPickerDelegate
{
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL])
    {
        guard let url = urls.first else { return }
        self.installApp(at: url)
    }
}

// MARK: - ModernAppCardCell (Viền kính ngọc trai + Hiển thị Bundle ID + Thanh tiến trình 7 ngày + Nhấn đàn hồi)
@objc(ModernAppCardCell)
class ModernAppCardCell: UICollectionViewCell
{
    let cardView = UIView()
    let mainRowStack = UIStackView()
    
    let iconImageView = UIImageView()
    let textStack = UIStackView()
    let nameLabel = UILabel()
    let developerLabel = UILabel()
    let versionLabel = UILabel()
    
    // Nhãn hiển thị Bundle ID dưới mỗi ứng dụng đã cài
    let bundleIDContainer = UIView()
    let bundleIDLabel = UILabel()
    
    let rightColumnStack = UIStackView()
    let expirationPrefixLabel = UILabel()
    let daysBadgeButton = PillButton()
    
    // Thanh tiến trình thời hạn 7 ngày trực quan
    private let progressTrackView = UIView()
    private let progressFillView = UIView()
    private var progressWidthConstraint: NSLayoutConstraint?
    private var currentProgressFraction: CGFloat = 1.0
    
    let updateBannerButton = UIButton(type: .system)
    var updateButtonAction: (() -> Void)?
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.24, delay: 0, usingSpringWithDamping: 0.68, initialSpringVelocity: 0.6, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                self.cardView.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.968, y: 0.968) : .identity
                self.cardView.alpha = self.isHighlighted ? 0.94 : 1.0
            }, completion: nil)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if cardView.superview == nil {
            setupViews()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        let trackWidth = progressTrackView.bounds.width
        if trackWidth > 0 {
            progressWidthConstraint?.constant = trackWidth * max(0.10, min(1.0, currentProgressFraction))
        }
    }
    
    private func setupViews() {
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Thẻ kính ngọc trai (Specular White Rim + Indigo Shadow)
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        cardView.layer.cornerRadius = 18
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1.0
        cardView.layer.borderColor = UIColor.white.cgColor
        cardView.layer.shadowColor = UIColor(red: 0.15, green: 0.10, blue: 0.38, alpha: 1.0).cgColor
        cardView.layer.shadowOpacity = 0.065
        cardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        cardView.layer.shadowRadius = 14
        cardView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardView)
        
        let containerStack = UIStackView()
        containerStack.axis = .vertical
        containerStack.spacing = 10
        containerStack.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(containerStack)
        
        mainRowStack.axis = .horizontal
        mainRowStack.alignment = .center
        mainRowStack.spacing = 13
        containerStack.addArrangedSubview(mainRowStack)
        
        iconImageView.layer.cornerRadius = 14
        iconImageView.layer.cornerCurve = .continuous
        iconImageView.clipsToBounds = true
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.borderWidth = 0.5
        iconImageView.layer.borderColor = UIColor.black.withAlphaComponent(0.08).cgColor
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 56),
            iconImageView.heightAnchor.constraint(equalToConstant: 56)
        ])
        mainRowStack.addArrangedSubview(iconImageView)
        
        textStack.axis = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2.5
        
        nameLabel.font = .systemFont(ofSize: 15.5, weight: .bold)
        nameLabel.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
        nameLabel.numberOfLines = 1
        
        developerLabel.font = .systemFont(ofSize: 12, weight: .medium)
        developerLabel.textColor = UIColor(red: 0.44, green: 0.48, blue: 0.56, alpha: 1.0)
        developerLabel.numberOfLines = 1
        
        versionLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        versionLabel.textColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.88)
        versionLabel.numberOfLines = 1
        
        // Dòng hiển thị Bundle ID dưới mỗi ứng dụng đã cài (dạng Pill Monospace thanh lịch)
        bundleIDContainer.backgroundColor = UIColor(red: 0.94, green: 0.96, blue: 0.99, alpha: 1.0)
        bundleIDContainer.layer.cornerRadius = 6
        bundleIDContainer.layer.borderWidth = 0.5
        bundleIDContainer.layer.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.14).cgColor
        bundleIDContainer.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 13.0, *) {
            bundleIDLabel.font = .monospacedSystemFont(ofSize: 10.0, weight: .medium)
        } else {
            bundleIDLabel.font = .systemFont(ofSize: 10.0, weight: .medium)
        }
        bundleIDLabel.textColor = UIColor(red: 0.34, green: 0.40, blue: 0.52, alpha: 1.0)
        bundleIDLabel.numberOfLines = 1
        bundleIDLabel.lineBreakMode = .byTruncatingMiddle
        bundleIDLabel.adjustsFontSizeToFitWidth = true
        bundleIDLabel.minimumScaleFactor = 0.78
        bundleIDLabel.translatesAutoresizingMaskIntoConstraints = false
        bundleIDContainer.addSubview(bundleIDLabel)
        
        NSLayoutConstraint.activate([
            bundleIDLabel.topAnchor.constraint(equalTo: bundleIDContainer.topAnchor, constant: 2.5),
            bundleIDLabel.bottomAnchor.constraint(equalTo: bundleIDContainer.bottomAnchor, constant: -2.5),
            bundleIDLabel.leadingAnchor.constraint(equalTo: bundleIDContainer.leadingAnchor, constant: 6),
            bundleIDLabel.trailingAnchor.constraint(equalTo: bundleIDContainer.trailingAnchor, constant: -6)
        ])
        
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(developerLabel)
        textStack.addArrangedSubview(versionLabel)
        textStack.setCustomSpacing(4, after: versionLabel)
        textStack.addArrangedSubview(bundleIDContainer)
        mainRowStack.addArrangedSubview(textStack)
        
        rightColumnStack.axis = .vertical
        rightColumnStack.alignment = .trailing
        rightColumnStack.spacing = 5
        
        expirationPrefixLabel.font = .systemFont(ofSize: 10, weight: .semibold)
        expirationPrefixLabel.textColor = UIColor(red: 0.48, green: 0.52, blue: 0.60, alpha: 1.0)
        expirationPrefixLabel.text = "Hết hạn sau"
        
        daysBadgeButton.isUserInteractionEnabled = true
        daysBadgeButton.titleLabel?.font = .systemFont(ofSize: 11.5, weight: .bold)
        daysBadgeButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        daysBadgeButton.layer.cornerRadius = 11
        daysBadgeButton.clipsToBounds = true
        
        // Thanh tiến trình 7 ngày
        progressTrackView.backgroundColor = UIColor(red: 0.91, green: 0.93, blue: 0.96, alpha: 1.0)
        progressTrackView.layer.cornerRadius = 2
        progressTrackView.clipsToBounds = true
        progressTrackView.translatesAutoresizingMaskIntoConstraints = false
        
        progressFillView.backgroundColor = UIColor(red: 0.06, green: 0.72, blue: 0.50, alpha: 1.0)
        progressFillView.layer.cornerRadius = 2
        progressFillView.translatesAutoresizingMaskIntoConstraints = false
        progressTrackView.addSubview(progressFillView)
        
        let widthConstraint = progressFillView.widthAnchor.constraint(equalToConstant: 56)
        self.progressWidthConstraint = widthConstraint
        
        NSLayoutConstraint.activate([
            progressTrackView.widthAnchor.constraint(equalToConstant: 66),
            progressTrackView.heightAnchor.constraint(equalToConstant: 3.5),
            progressFillView.leadingAnchor.constraint(equalTo: progressTrackView.leadingAnchor),
            progressFillView.topAnchor.constraint(equalTo: progressTrackView.topAnchor),
            progressFillView.bottomAnchor.constraint(equalTo: progressTrackView.bottomAnchor),
            widthConstraint
        ])
        
        rightColumnStack.addArrangedSubview(expirationPrefixLabel)
        rightColumnStack.addArrangedSubview(daysBadgeButton)
        rightColumnStack.addArrangedSubview(progressTrackView)
        mainRowStack.addArrangedSubview(rightColumnStack)
        
        daysBadgeButton.addObserver(self, forKeyPath: "titleLabel.text", options: [.new, .initial], context: nil)
        
        updateBannerButton.isHidden = true
        updateBannerButton.backgroundColor = UIColor(red: 0.92, green: 0.96, blue: 1.0, alpha: 1.0)
        updateBannerButton.setTitleColor(UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0), for: .normal)
        updateBannerButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        updateBannerButton.layer.cornerRadius = 10
        updateBannerButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        updateBannerButton.addTarget(self, action: #selector(handleUpdateButtonTap), for: .touchUpInside)
        containerStack.addArrangedSubview(updateBannerButton)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            
            containerStack.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            containerStack.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            containerStack.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            containerStack.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
        ])
        
        daysBadgeButton.setContentHuggingPriority(.required, for: .horizontal)
        daysBadgeButton.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
    
    deinit {
        daysBadgeButton.removeObserver(self, forKeyPath: "titleLabel.text")
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "titleLabel.text" {
            updateProgressFromBadgeText(daysBadgeButton.title(for: .normal) ?? "")
        }
    }
    
    private func updateProgressFromBadgeText(_ text: String) {
        let upper = text.uppercased()
        let digits = upper.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        let number = Int(digits) ?? 0
        
        if upper.contains("HẾT HẠN") {
            currentProgressFraction = 0.10
            progressFillView.backgroundColor = UIColor(red: 0.90, green: 0.22, blue: 0.27, alpha: 1.0)
        } else if upper.contains("GIỜ") || upper.contains("PHÚT") {
            currentProgressFraction = 0.16
            progressFillView.backgroundColor = UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0)
        } else if upper.contains("NGÀY") {
            currentProgressFraction = CGFloat(min(7, max(1, number))) / 7.0
            if number >= 5 {
                progressFillView.backgroundColor = UIColor(red: 0.06, green: 0.72, blue: 0.50, alpha: 1.0) // Xanh ngọc an toàn
            } else if number >= 2 {
                progressFillView.backgroundColor = UIColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0) // Vàng cam lưu ý
            } else {
                progressFillView.backgroundColor = UIColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0) // Đỏ sắp hết hạn
            }
        } else {
            currentProgressFraction = 1.0
            progressFillView.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        }
        setNeedsLayout()
    }
    
    @objc private func handleUpdateButtonTap() {
        updateButtonAction?()
    }
    
    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes) -> UICollectionViewLayoutAttributes {
        let targetSize = CGSize(width: layoutAttributes.frame.width, height: 0)
        let size = contentView.systemLayoutSizeFitting(targetSize, withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        var newFrame = layoutAttributes.frame
        newFrame.size.height = ceil(size.height)
        layoutAttributes.frame = newFrame
        return layoutAttributes
    }
}

private extension AlertViewControllerWrapper {
    func configureHeaderView(for application: Application) -> AppBannerHeaderView {
        let headerView = AppBannerHeaderView(frame: .zero)
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.configure(with: application)
        self.setHeaderView(headerView)
        return headerView
    }
    
    func configureHeaderView(for bundleURL: URL) -> AppBannerHeaderView? {
        guard let application = Application(fileURL: bundleURL) else { return nil }
        return self.configureHeaderView(for: application)
    }
    
    func setHeaderView(_ headerView: UIView) {
        self.alertController.contentView.addSubview(headerView)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: self.alertController.contentView.topAnchor, constant: 2),
            headerView.bottomAnchor.constraint(equalTo: self.alertController.contentView.bottomAnchor),
            headerView.leadingAnchor.constraint(equalTo: self.alertController.contentView.leadingAnchor, constant: 0),
            headerView.trailingAnchor.constraint(equalTo: self.alertController.contentView.trailingAnchor, constant: 0),
            headerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 70)
        ])
    }
}
