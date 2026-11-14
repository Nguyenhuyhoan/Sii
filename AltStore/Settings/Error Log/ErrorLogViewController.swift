
//
//  ErrorLogViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/6/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
import Nuke
import SwiftUI

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ SETTINGS)
private struct ErrorLogCSSTheme {
    static let white = UIColor.white
    static let light = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0) // #f8f9fa
    static let border = UIColor(red: 233/255, green: 236/255, blue: 239/255, alpha: 1.0) // #e9ecef
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0) // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0) // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0) // #28a745
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0) // #ff00ff
    static let danger = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0) // #dc3545
    static let dark = UIColor(red: 52/255, green: 58/255, blue: 64/255, alpha: 1.0) // #343a40

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.92) -> rgba(111,66,193,.88))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.92).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.88).cgColor

    static let cornerRadius: CGFloat = 15.0
    /// Khoảng cách lề ngang chuẩn từ mép màn hình vào khung Banner & khung Lỗi
    static let cardHorizontalInset: CGFloat = 16.0
    /// Khoảng cách đệm từ viền khung lỗi vào chữ bên trong
    static let cardInnerPadding: CGFloat = 16.0
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH
private final class ErrorLogGradientBackgroundView: UIView {
    override class var layerClass: AnyClass {
        return CAGradientLayer.self
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
        self.isUserInteractionEnabled = false
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        gradientLayer.colors = [ErrorLogCSSTheme.bgGradientStart, ErrorLogCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

final class ErrorLogViewController: UITableViewController
{
    private lazy var dataSource = self.makeDataSource()
    private var expandedErrorIDs = Set<NSManagedObjectID>()
    
    private var heroGradientLayer: CAGradientLayer?
    private var floatingClearAllButton: UIButton?
    
    private var isScrolling = false {
        didSet {
            guard self.isScrolling != oldValue else { return }
            self.updateButtonInteractivity()
        }
    }

    private lazy var timeFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "vi_VN")
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()
    
    // Giữ nguyên @IBOutlet để Storyboard không bao giờ bị lỗi runtime
    @IBOutlet private var exportLogButton: UIBarButtonItem?
    @IBOutlet private var clearLogButton: UIBarButtonItem!
    
    private var _exportedLogURL: URL?
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Khóa giao diện Light Mode chuẩn CSS để không bao giờ bị hệ thống ép về nền đen
        self.overrideUserInterfaceStyle = .light
        self.view.overrideUserInterfaceStyle = .light
        self.tableView.overrideUserInterfaceStyle = .light
        
        // Ẩn tiêu đề mặc định để đồng bộ giao diện tràn viền với SettingsViewController
        self.title = nil
        self.navigationItem.title = nil
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        #endif
        
        // Đồng bộ lề ngang của TableView để cell.contentView trong kiểu .insetGrouped khớp 16pt với Banner
        self.tableView.cellLayoutMarginsFollowReadableWidth = false
        self.tableView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 0,
            leading: ErrorLogCSSTheme.cardHorizontalInset,
            bottom: 0,
            trailing: ErrorLogCSSTheme.cardHorizontalInset
        )
        
        self.tableView.dataSource = self.dataSource
        self.dataSource.contentView = self.tableView
        self.tableView.prefetchDataSource = self.dataSource
        
        self.exportLogButton?.activityIndicatorView.color = .white
        
        if #unavailable(iOS 15)
        {
            self.navigationItem.rightBarButtonItems = [self.clearLogButton]
        }
        
        self.tableView.contentInset.top = 0
        self.tableView.contentInset.bottom = 50
        if #available(iOS 15.0, tvOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 0
        }
        
        // ✨ KÍCH HOẠT GIAO DIỆN CSS THEME & NÚT XOÁ TẤT CẢ GÓC TRÊN PHẢI ✨
        self.applySmartWebCSSTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.enforceBrightGradientBackground()
        self.setupFloatingClearAllButton()
        self.updateFloatingClearAllButtonState()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.floatingClearAllButton?.removeFromSuperview()
        self.floatingClearAllButton = nil
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let heroHeader = self.tableView.tableHeaderView,
           let heroCard = heroHeader.subviews.first {
            self.heroGradientLayer?.frame = heroCard.bounds
        }
        self.enforceBrightGradientBackground()
        self.updateFloatingClearAllButtonState()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?)
    {
        guard let loggedError = sender as? LoggedError, segue.identifier == "showErrorDetails" else { return }
        
        let navigationController = segue.destination as! UINavigationController
        
        let errorDetailsViewController = navigationController.viewControllers.first as! ErrorDetailsViewController
        errorDetailsViewController.loggedError = loggedError
    }
    
    @IBAction private func unwindFromErrorDetails(_ segue: UIStoryboardSegue)
    {
    }
}

// MARK: - ✨ HỆ THỐNG GIAO DIỆN CSS THEME & VIỆT HÓA THÔNG BÁO LỖI
private extension ErrorLogViewController
{
    func applySmartWebCSSTheme() {
        // 1. Đảm bảo nền Gradient sáng luôn hoạt động kể cả khi có hay không có dữ liệu
        self.enforceBrightGradientBackground()
        self.tableView.separatorStyle = .none
        
        // 2. Tạo Hero Banner kèm nút mở Nhật ký Console
        self.setupCSSHeroBanner()
    }
    
    /// Hàm giữ cho nền sáng Gradient không bao giờ bị biến thành nền đen khi xóa hết nhật ký
    func enforceBrightGradientBackground() {
        // Màu nền fallback sáng phòng trường hợp backgroundView bị thay thế tạm thời
        let fallbackBrightColor = UIColor(red: 235/255, green: 238/255, blue: 255/255, alpha: 1.0)
        self.view.backgroundColor = fallbackBrightColor
        self.tableView.backgroundColor = fallbackBrightColor
        
        // Nếu dataSource đang gắn PlaceholderView làm backgroundView (khi danh sách trống)
        if let placeholder = self.tableView.backgroundView, !(placeholder is ErrorLogGradientBackgroundView) {
            placeholder.overrideUserInterfaceStyle = .light
            placeholder.backgroundColor = .clear
            
            let bgTag = 991122
            if let existingGradient = placeholder.viewWithTag(bgTag) {
                existingGradient.frame = placeholder.bounds
                placeholder.sendSubviewToBack(existingGradient)
            } else {
                let gradientBg = ErrorLogGradientBackgroundView(frame: placeholder.bounds)
                gradientBg.tag = bgTag
                gradientBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                placeholder.insertSubview(gradientBg, at: 0)
            }
        } else if self.tableView.backgroundView == nil {
            let bgView = ErrorLogGradientBackgroundView(frame: UIScreen.main.bounds)
            bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.tableView.backgroundView = bgView
        }
    }
    
    /// Trang trí giao diện Placeholder (khi xóa hết nhật ký) hài hòa với nền sáng CSS
    func styleBrightPlaceholderView(_ placeholderView: PlaceholderView) {
        placeholderView.overrideUserInterfaceStyle = .light
        placeholderView.backgroundColor = .clear
        
        // Lót trực tiếp nền Gradient sáng vào dưới đáy của PlaceholderView
        let bgTag = 991122
        if placeholderView.viewWithTag(bgTag) == nil {
            let gradientBg = ErrorLogGradientBackgroundView(frame: UIScreen.main.bounds)
            gradientBg.tag = bgTag
            gradientBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            placeholderView.insertSubview(gradientBg, at: 0)
        }
        
        // Chỉnh màu chữ và kiểu dáng nổi bật, sắc nét trên nền sáng
        placeholderView.textLabel.text = "✓ Hệ Thống Hoạt Động Ổn Định"
        placeholderView.textLabel.textColor = ErrorLogCSSTheme.blue
        placeholderView.textLabel.font = UIFont.systemFont(ofSize: 19, weight: .heavy)
        
        placeholderView.detailTextLabel.text = "Nhật ký hiện đang trống.\nMọi sự cố phát sinh khi cài đặt IPA hoặc làm mới (Refresh) ứng dụng sẽ được ghi lại tại đây."
        placeholderView.detailTextLabel.textColor = ErrorLogCSSTheme.dark.withAlphaComponent(0.85)
        placeholderView.detailTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        
        // Tạo thẻ Card trắng bán trong suốt bao quanh cụm thông báo trống để chữ luôn rõ ràng, sang trọng
        if let stackView = placeholderView.textLabel.superview {
            let cardTag = 991133
            if placeholderView.viewWithTag(cardTag) == nil {
                let cardBg = UIView()
                cardBg.tag = cardTag
                cardBg.translatesAutoresizingMaskIntoConstraints = false
                cardBg.backgroundColor = ErrorLogCSSTheme.white.withAlphaComponent(0.88)
                cardBg.layer.cornerRadius = ErrorLogCSSTheme.cornerRadius + 3
                cardBg.layer.borderWidth = 1.0
                cardBg.layer.borderColor = ErrorLogCSSTheme.white.cgColor
                cardBg.layer.shadowColor = ErrorLogCSSTheme.blue.cgColor
                cardBg.layer.shadowOffset = CGSize(width: 0, height: 6)
                cardBg.layer.shadowRadius = 16
                cardBg.layer.shadowOpacity = 0.12
                cardBg.isUserInteractionEnabled = false
                
                placeholderView.insertSubview(cardBg, belowSubview: stackView)
                NSLayoutConstraint.activate([
                    cardBg.leadingAnchor.constraint(equalTo: stackView.leadingAnchor, constant: -20),
                    cardBg.trailingAnchor.constraint(equalTo: stackView.trailingAnchor, constant: 20),
                    cardBg.topAnchor.constraint(equalTo: stackView.topAnchor, constant: -24),
                    cardBg.bottomAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 24)
                ])
            }
        }
    }
    
    func setupCSSHeroBanner() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 148))
        headerContainer.backgroundColor = .clear
        
        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = ErrorLogCSSTheme.cornerRadius
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = ErrorLogCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        heroCard.layer.shadowRadius = 16
        heroCard.layer.shadowOpacity = 0.25
        
        let gradient = CAGradientLayer()
        gradient.colors = [ErrorLogCSSTheme.heroStart, ErrorLogCSSTheme.heroEnd]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        gradient.cornerRadius = ErrorLogCSSTheme.cornerRadius
        heroCard.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Nhật Ký Lỗi Hệ Thống"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
        titleLabel.textColor = ErrorLogCSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 1, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.35
        
        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Theo dõi và chẩn đoán chi tiết các sự cố phát sinh khi cài đặt IPA hoặc làm mới ứng dụng"
        subLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        subLabel.textColor = ErrorLogCSSTheme.white.withAlphaComponent(0.95)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2
        
        // Nút mở nhanh Console Log ngay trên Banner
        let consoleBtn = UIButton(type: .system)
        consoleBtn.translatesAutoresizingMaskIntoConstraints = false
        let termConfig = UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)
        consoleBtn.setImage(UIImage(systemName: "terminal.fill", withConfiguration: termConfig), for: .normal)
        consoleBtn.setTitle("  Xem Nhật Ký Console Chi Tiết  ", for: .normal)
        consoleBtn.tintColor = ErrorLogCSSTheme.white
        consoleBtn.setTitleColor(ErrorLogCSSTheme.white, for: .normal)
        consoleBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        consoleBtn.backgroundColor = UIColor.black.withAlphaComponent(0.24)
        consoleBtn.layer.cornerRadius = 13
        consoleBtn.layer.borderWidth = 1.0
        consoleBtn.layer.borderColor = ErrorLogCSSTheme.white.withAlphaComponent(0.4).cgColor
        consoleBtn.addTarget(self, action: #selector(handleConsoleButtonTapped), for: .touchUpInside)
        
        heroCard.addSubview(titleLabel)
        heroCard.addSubview(subLabel)
        heroCard.addSubview(consoleBtn)
        headerContainer.addSubview(heroCard)
        
        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: ErrorLogCSSTheme.cardHorizontalInset),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -ErrorLogCSSTheme.cardHorizontalInset),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 12),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -6),
            
            titleLabel.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 14),
            
            subLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subLabel.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 14),
            subLabel.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -14),
            
            consoleBtn.topAnchor.constraint(equalTo: subLabel.bottomAnchor, constant: 10),
            consoleBtn.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            consoleBtn.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }
        
        self.tableView.tableHeaderView = headerContainer
    }
    
    // MARK: - 🗑️ NÚT ICON XOÁ TẤT CẢ TRÊN CÙNG BÊN PHẢI (ĐỐI XỨNG VỚI NÚT BACK TRÁI)
    func setupFloatingClearAllButton() {
        guard let nav = self.navigationController else { return }
        if self.floatingClearAllButton == nil {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false
            
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            btn.setImage(UIImage(systemName: "trash.fill", withConfiguration: config), for: .normal)
            btn.tintColor = ErrorLogCSSTheme.danger
            btn.backgroundColor = ErrorLogCSSTheme.white.withAlphaComponent(0.94)
            
            // Nút tròn nhỏ 34x34 cố định góc trên bên phải, đối xứng hoàn toàn với nút Back
            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = ErrorLogCSSTheme.border.cgColor
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowRadius = 6
            btn.layer.shadowOpacity = 0.15
            
            btn.addTarget(self, action: #selector(handleFloatingClearAllTapped(_:)), for: .touchUpInside)
            nav.view.addSubview(btn)
            
            NSLayoutConstraint.activate([
                btn.trailingAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                btn.topAnchor.constraint(equalTo: nav.view.safeAreaLayoutGuide.topAnchor, constant: 6),
                btn.widthAnchor.constraint(equalToConstant: 34),
                btn.heightAnchor.constraint(equalToConstant: 34)
            ])
            
            self.floatingClearAllButton = btn
        }
        
        if let btn = self.floatingClearAllButton {
            nav.view.bringSubviewToFront(btn)
        }
    }
    
    func updateFloatingClearAllButtonState() {
        guard let btn = self.floatingClearAllButton else { return }
        let hasErrors = (self.dataSource.fetchedResultsController.fetchedObjects?.isEmpty == false)
        btn.isEnabled = hasErrors
        btn.tintColor = hasErrors ? ErrorLogCSSTheme.danger : UIColor.systemGray3
        btn.alpha = 1.0
    }
    
    @objc func handleFloatingClearAllTapped(_ sender: UIButton) {
        UIView.animate(withDuration: 0.12, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            UIView.animate(withDuration: 0.25) {
                sender.transform = .identity
            }
        }
        
        let alertController = UIAlertController(
            title: "Xóa toàn bộ nhật ký lỗi?",
            message: "Thao tác này sẽ xóa vĩnh viễn tất cả lịch sử báo lỗi cài đặt IPA và làm mới ứng dụng.",
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.sourceView = sender
        alertController.popoverPresentationController?.sourceRect = sender.bounds
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Xóa tất cả nhật ký", style: .destructive) { [weak self] _ in
            Task {
                await self?.clearLoggedErrors()
                await MainActor.run {
                    self?.enforceBrightGradientBackground()
                    self?.updateFloatingClearAllButtonState()
                }
            }
        })
        self.present(alertController, animated: true)
    }
    
    @objc func handleConsoleButtonTapped() {
        self.showConsoleLogs(self.clearLogButton)
    }
    
    // MARK: - 🇻🇳 BỘ DỊCH THÔNG MINH CÁC LỖI CÀI IPA & REFRESH SANG TIẾNG VIỆT
    func translateErrorFailureTitle(_ text: String?) -> String {
        guard let text = text, !text.isEmpty else {
            return "Thao tác thất bại"
        }
        
        var translated = text
        let exactDictionary: [String: String] = [
            "Operation Failed": "Thao tác thất bại",
            "Failed to Refresh App": "Không thể làm mới ứng dụng",
            "Failed to Refresh Apps": "Không thể làm mới các ứng dụng",
            "Failed to Install App": "Không thể cài đặt ứng dụng (IPA)",
            "Failed to Sideload App": "Không thể cài đặt ứng dụng (Sideload)",
            "Failed to Update App": "Không thể cập nhật ứng dụng",
            "Failed to Activate App": "Không thể kích hoạt ứng dụng",
            "Failed to Deactivate App": "Không thể hủy kích hoạt ứng dụng",
            "Failed to Backup App": "Không thể sao lưu ứng dụng",
            "Failed to Restore App": "Không thể khôi phục ứng dụng",
            "Failed to Enable JIT": "Không thể kích hoạt JIT",
            "Failed to Remove App": "Không thể gỡ bỏ ứng dụng",
            "Failed to Sign App": "Không thể ký chứng chỉ ứng dụng",
            "Failed to Verify App": "Không thể xác minh gói IPA",
            "Failed to Fetch Source": "Không thể tải dữ liệu nguồn (Source)",
            "Failed to Log In": "Đăng nhập tài khoản thất bại",
            "Failed to Sign In": "Đăng nhập ID Apple thất bại"
        ]
        
        if let exact = exactDictionary[translated] {
            return exact
        }
        
        let prefixReplacements: [(String, String)] = [
            ("Failed to Refresh ", "Lỗi làm mới "),
            ("Failed to Install ", "Lỗi cài đặt "),
            ("Failed to Sideload ", "Lỗi cài đặt IPA "),
            ("Failed to Update ", "Lỗi cập nhật "),
            ("Failed to Activate ", "Lỗi kích hoạt "),
            ("Failed to Deactivate ", "Lỗi tắt kích hoạt "),
            ("Failed to Backup ", "Lỗi sao lưu "),
            ("Failed to Restore ", "Lỗi khôi phục "),
            ("Failed to Remove ", "Lỗi gỡ cài đặt "),
            ("Failed to Enable JIT for ", "Lỗi bật JIT cho "),
            ("Could not install ", "Không thể cài đặt "),
            ("Could not refresh ", "Không thể làm mới ")
        ]
        
        for (enPrefix, viPrefix) in prefixReplacements {
            if translated.hasPrefix(enPrefix) {
                translated = viPrefix + translated.dropFirst(enPrefix.count)
                break
            }
        }
        
        return translated
    }
    
    func translateErrorDescriptionText(_ text: String) -> String {
        var result = text
        let phraseReplacements: [(String, String)] = [
            ("The operation couldn’t be completed.", "Thao tác không thể hoàn tất."),
            ("The operation couldn't be completed.", "Thao tác không thể hoàn tất."),
            ("Could not connect to server.", "Không thể kết nối tới máy chủ."),
            ("The Internet connection appears to be offline.", "Kết nối mạng có vẻ đang bị ngắt."),
            ("A server with the specified hostname could not be found.", "Không tìm thấy máy chủ với tên miền được chỉ định."),
            ("The request timed out.", "Yêu cầu kết nối đã quá thời gian chờ (Timeout)."),
            ("Make sure you are connected to Wi-Fi and your VPN/StosVPN/LocalDevVPN is enabled.", "Hãy đảm bảo bạn đang bật Wi-Fi và đã kết nối VPN (StosVPN / WireGuard / LocalDevVPN)."),
            ("Unable to connect to device.", "Không thể kết nối với thiết bị. Hãy kiểm tra lại VPN hoặc tệp Pairing."),
            ("Invalid pairing file", "Tệp ghép đôi (Pairing file) không hợp lệ hoặc đã hết hạn"),
            ("No pairing file found", "Không tìm thấy tệp ghép đôi (Pairing file)"),
            ("Your session has expired. Please sign in again.", "Phiên đăng nhập ID Apple đã hết hạn. Vui lòng đăng nhập lại."),
            ("Maximum number of App IDs reached", "Đã đạt giới hạn tối đa 10 App ID của tài khoản Apple miễn phí"),
            ("You cannot activate more than 3 apps", "Tài khoản miễn phí không thể kích hoạt quá 3 ứng dụng cùng lúc"),
            ("The app is invalid.", "Tệp ứng dụng (.ipa) không hợp lệ hoặc bị hỏng."),
            ("Failed to verify code signature", "Xác thực chữ ký số (Code Signature) thất bại"),
            ("Certificate has been revoked", "Chứng chỉ phát triển đã bị thu hồi (Revoked)"),
            ("Anisette error", "Lỗi máy chủ xác thực Anisette"),
            ("Failed to fetch Anisette data", "Không thể lấy dữ liệu xác thực Anisette")
        ]
        
        for (en, vi) in phraseReplacements {
            result = result.replacingOccurrences(of: en, with: vi)
        }
        return result
    }
    
    // MARK: - 🃏 BÓC TÁCH VÀ ÁP DỤNG CARD CSS CHO TỪNG DÒNG LỖI (RỘNG BẰNG BANNER + CĂN LỀ ĐẸP)
    func styleInnerCardOfErrorCell(_ cell: ErrorLogTableViewCell, at indexPath: IndexPath, totalRows: Int) {
        cell.backgroundColor = .clear
        cell.contentView.backgroundColor = .clear
        cell.contentView.clipsToBounds = false
        cell.clipsToBounds = false
        
        // 1. Căn lề bên trong Cell rộng rãi, cách đều mép khung lỗi để các chữ nhỏ không bị sát lề
        cell.preservesSuperviewLayoutMargins = false
        cell.contentView.preservesSuperviewLayoutMargins = false
        let innerPadding = ErrorLogCSSTheme.cardInnerPadding
        cell.contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: 14,
            leading: innerPadding,
            bottom: 14,
            trailing: innerPadding
        )
        
        // 2. Tạo khung Card trắng có chiều rộng bằng đúng khung chứa chữ "Nhật Ký Lỗi Hệ Thống"
        let cardTag = 8899
        let cardView: UIView
        if let existing = cell.contentView.viewWithTag(cardTag) {
            cardView = existing
        } else {
            let newCard = UIView()
            newCard.tag = cardTag
            newCard.translatesAutoresizingMaskIntoConstraints = false
            newCard.isUserInteractionEnabled = false
            cell.contentView.insertSubview(newCard, at: 0)
            cardView = newCard
        }
        
        // Neo trực tiếp chiều rộng của khung lỗi theo tableView.frameLayoutGuide (cách lề 16pt)
        // Giúp khung lỗi luôn rộng bằng hệt khung Banner "Nhật Ký Lỗi Hệ Thống" bất kể kiểu bảng là .insetGrouped hay .plain
        let widthConstraintID = "ErrorCardExactBannerWidth"
        if !self.tableView.constraints.contains(where: { $0.identifier == widthConstraintID && ($0.firstItem === cardView || $0.secondItem === cardView) }) {
            let lead = cardView.leadingAnchor.constraint(equalTo: self.tableView.frameLayoutGuide.leadingAnchor, constant: ErrorLogCSSTheme.cardHorizontalInset)
            lead.identifier = widthConstraintID
            lead.priority = .required
            
            let trail = cardView.trailingAnchor.constraint(equalTo: self.tableView.frameLayoutGuide.trailingAnchor, constant: -ErrorLogCSSTheme.cardHorizontalInset)
            trail.identifier = widthConstraintID
            trail.priority = .required
            
            let fallbackLead = cardView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor)
            fallbackLead.priority = UILayoutPriority(750)
            
            let fallbackTrail = cardView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor)
            fallbackTrail.priority = UILayoutPriority(750)
            
            let top = cardView.topAnchor.constraint(equalTo: cell.contentView.topAnchor)
            let bottom = cardView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor)
            
            NSLayoutConstraint.activate([lead, trail, fallbackLead, fallbackTrail, top, bottom])
        }
        
        cardView.backgroundColor = ErrorLogCSSTheme.white
        
        var corners: CACornerMask = []
        if totalRows == 1 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if indexPath.row == 0 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if indexPath.row == totalRows - 1 {
            corners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }
        
        cardView.layer.cornerRadius = corners.isEmpty ? 0 : ErrorLogCSSTheme.cornerRadius
        cardView.layer.maskedCorners = corners
        
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = ErrorLogCSSTheme.blue.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 4)
        cell.layer.shadowRadius = 10
        cell.layer.shadowOpacity = 0.07
        
        // 3. Đường kẻ phân cách tinh tế giữa các lỗi trong cùng một ngày (căn theo cardView)
        let sepTag = 8888
        cell.contentView.viewWithTag(sepTag)?.removeFromSuperview()
        if indexPath.row < totalRows - 1 {
            let sep = UIView()
            sep.tag = sepTag
            sep.backgroundColor = ErrorLogCSSTheme.border
            sep.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: innerPadding),
                sep.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -innerPadding),
                sep.bottomAnchor.constraint(equalTo: cardView.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 1.0)
            ])
        }
        
        // 4. Làm đẹp và căn lề thoáng cho các chữ bên trong Cell
        cell.errorFailureLabel.textColor = ErrorLogCSSTheme.dark
        cell.errorFailureLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
        
        cell.dateLabel.textColor = ErrorLogCSSTheme.blue
        cell.dateLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .semibold)
        
        // Tạo hiệu ứng Badge cho Mã lỗi (Error Code)
        cell.errorCodeLabel.textColor = ErrorLogCSSTheme.purple
        cell.errorCodeLabel.font = UIFont.monospacedSystemFont(ofSize: 11.5, weight: .bold)
        cell.errorCodeLabel.backgroundColor = ErrorLogCSSTheme.purple.withAlphaComponent(0.10)
        cell.errorCodeLabel.layer.cornerRadius = 6
        cell.errorCodeLabel.layer.masksToBounds = true
        
        // Căn lề chuẩn cho phần chữ mô tả lỗi để thẳng hàng với tiêu đề và cách đều lề khung
        cell.errorDescriptionTextView.textContainer.lineFragmentPadding = 0
        cell.errorDescriptionTextView.textContainerInset = UIEdgeInsets(top: 4, left: 2, bottom: 4, right: 2)
        cell.errorDescriptionTextView.textColor = ErrorLogCSSTheme.dark.withAlphaComponent(0.88)
        cell.errorDescriptionTextView.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        cell.errorDescriptionTextView.moreButton.setTitle("Xem thêm", for: .normal)
        cell.errorDescriptionTextView.moreButton.setTitleColor(ErrorLogCSSTheme.blue, for: .normal)
        cell.errorDescriptionTextView.moreButton.tintColor = ErrorLogCSSTheme.blue
        
        // Bo góc chuẩn iOS cho Icon ứng dụng bị lỗi
        cell.appIconImageView.layer.cornerRadius = 12
        cell.appIconImageView.layer.masksToBounds = true
        cell.appIconImageView.layer.borderColor = ErrorLogCSSTheme.border.cgColor
        cell.appIconImageView.layer.borderWidth = 1.0
        cell.appIconImageView.backgroundColor = ErrorLogCSSTheme.light
    }
}

private extension ErrorLogViewController
{
    func makeDataSource() -> FetchedResultsTableViewPrefetchingDataSource<LoggedError, UIImage>
    {
        let fetchRequest = LoggedError.fetchRequest() as NSFetchRequest<LoggedError>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LoggedError.date, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext, sectionNameKeyPath: #keyPath(LoggedError.localizedDateString), cacheName: nil)
        
        let dataSource = FetchedResultsTableViewPrefetchingDataSource<LoggedError, UIImage>(fetchedResultsController: fetchedResultsController)
        dataSource.proxy = self
        dataSource.rowAnimation = .fade
        dataSource.cellConfigurationHandler = { [weak self] (cell, loggedError, indexPath) in
            guard let self else { return }
            
            let cell = cell as! ErrorLogTableViewCell
            cell.dateLabel.text = self.timeFormatter.string(from: loggedError.date)
            cell.errorFailureLabel.text = self.translateErrorFailureTitle(loggedError.localizedFailure)
            cell.errorCodeLabel.text = "  \(loggedError.error.localizedErrorCode)  "
            
            let nsError = loggedError.error as NSError
            let rawDescription = [nsError.localizedDescription, nsError.localizedRecoverySuggestion].compactMap { $0 }.joined(separator: "\n\n")
            let errorDescription = self.translateErrorDescriptionText(rawDescription)
            
            cell.errorDescriptionTextView.text = errorDescription
            cell.errorDescriptionTextView.maximumNumberOfLines = 5
            cell.errorDescriptionTextView.isCollapsed = !self.expandedErrorIDs.contains(loggedError.objectID)
            cell.errorDescriptionTextView.moreButton.addTarget(self, action: #selector(ErrorLogViewController.toggleCollapsingCell(_:)), for: .primaryActionTriggered)
            
            cell.appIconImageView.image = UIImage(systemName: "exclamationmark.triangle.fill")?.withTintColor(ErrorLogCSSTheme.purple.withAlphaComponent(0.75), renderingMode: .alwaysOriginal)
            cell.appIconImageView.contentMode = .scaleAspectFit
            cell.appIconImageView.isIndicatingActivity = true
            
            cell.menuButton.isHidden = true
            if #available(tvOS 17.0, *) {
                cell.menuButton.menu = nil
            }
            cell.selectionStyle = .none

            cell.accessibilityLabel = [cell.errorFailureLabel.text, cell.dateLabel.text, cell.errorCodeLabel.text, cell.errorDescriptionTextView.text].compactMap { $0 }.joined(separator: ". ")
            cell.errorDescriptionTextView.accessibilityLabel = cell.errorDescriptionTextView.text
            
            self.updateFloatingClearAllButtonState()
        }
        dataSource.prefetchHandler = { (loggedError, indexPath) in
            let (installedApp, iconURL) = await loggedError.managedObjectContext?.perform {
                (loggedError.installedApp, loggedError.storeApp?.iconURL)
            } ?? (nil, nil)
            
            if let installedApp {
                return try await installedApp.loadIcon()
            } else if let iconURL {
                return try await ImagePipeline.shared.image(for: iconURL)
            } else {
                return nil
            }
        }
        dataSource.prefetchCompletionHandler = { (cell, image, indexPath, error) in
            let cell = cell as! ErrorLogTableViewCell
            if let image = image {
                cell.appIconImageView.contentMode = .scaleAspectFill
                cell.appIconImageView.image = image
            } else {
                cell.appIconImageView.contentMode = .center
                let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .bold)
                cell.appIconImageView.image = UIImage(systemName: "app.badge.checkmark", withConfiguration: config)?.withTintColor(ErrorLogCSSTheme.blue, renderingMode: .alwaysOriginal)
            }
            cell.appIconImageView.isIndicatingActivity = false
        }
        
        let placeholderView = PlaceholderView()
        self.styleBrightPlaceholderView(placeholderView)
        dataSource.placeholderView = placeholderView
        
        return dataSource
    }
}

private extension ErrorLogViewController
{
    @IBAction func toggleCollapsingCell(_ sender: UIButton)
    {
        let point = self.tableView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.tableView.indexPathForRow(at: point), let cell = self.tableView.cellForRow(at: indexPath) as? ErrorLogTableViewCell else { return }
        
        let loggedError = self.dataSource.item(at: indexPath)
        
        if cell.errorDescriptionTextView.isCollapsed
        {
            self.expandedErrorIDs.remove(loggedError.objectID)
        }
        else
        {
            self.expandedErrorIDs.insert(loggedError.objectID)
        }
        
        self.tableView.performBatchUpdates {
            cell.layoutIfNeeded()
        }
    }
    
    enum LogView: String {
        case consoleLog = "console-log"

        func getLogPath() -> URL {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            return appDelegate.consoleLog.logFileURL
        }
    }
    
    @IBAction func showConsoleLogs(_ sender: UIBarButtonItem) {
        let consoleLogView = ConsoleLogView(logURL: (UIApplication.shared.delegate as! AppDelegate).consoleLog.logFileURL)
        let consoleLogController = UIHostingController(rootView: consoleLogView)
        
        #if !os(tvOS)
        consoleLogController.modalPresentationStyle = .pageSheet
        if let sheet = consoleLogController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.selectedDetentIdentifier = .large
        }
        #endif
        
        present(consoleLogController, animated: true, completion: nil)
    }
        
    @IBAction func clearLoggedErrors(_ sender: UIBarButtonItem)
    {
        let alertController = UIAlertController(
            title: "Bạn có chắc chắn muốn xóa toàn bộ nhật ký lỗi?",
            message: nil,
            preferredStyle: .actionSheet
        )
        alertController.popoverPresentationController?.barButtonItem = sender
        alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel, handler: nil))
        alertController.addAction(UIAlertAction(title: "Xóa tất cả nhật ký", style: .destructive) { _ in
            Task {
                await self.clearLoggedErrors()
                await MainActor.run {
                    self.enforceBrightGradientBackground()
                    self.updateFloatingClearAllButtonState()
                }
            }
        })
        self.present(alertController, animated: true)
    }
    
    func clearLoggedErrors() async
    {
        do
        {
            try await DatabaseManager.shared.purgeLoggedErrors()
        }
        catch
        {
            let alertController = UIAlertController(
                title: "Không thể xóa nhật ký lỗi",
                message: error.localizedDescription,
                preferredStyle: .alert
            )
            alertController.addAction(.ok)
            self.present(alertController, animated: true)
        }
    }
    
    func copyErrorMessage(for loggedError: LoggedError)
    {
        #if !os(tvOS)
        let nsError = loggedError.error as NSError
        let errorMessage = [nsError.localizedDescription, nsError.localizedRecoverySuggestion].compactMap { $0 }.joined(separator: "\n\n")
        
        UIPasteboard.general.string = errorMessage
        #endif
    }
    
    func copyErrorCode(for loggedError: LoggedError)
    {
        #if !os(tvOS)
        let errorCode = loggedError.error.localizedErrorCode
        UIPasteboard.general.string = errorCode
        #endif
    }
    
    func searchFAQ(for loggedError: LoggedError)
    {
        let staticURL = AppConstants.URLs.errorCodesDocumentation
        self.openWebURL(staticURL, preferredTintColor: ErrorLogCSSTheme.blue)
    }

    func viewMoreDetails(for loggedError: LoggedError) {
        self.performSegue(withIdentifier: "showErrorDetails", sender: loggedError)
    }
}

extension ErrorLogViewController
{
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        guard let errorCell = cell as? ErrorLogTableViewCell else { return }
        let totalRows = tableView.numberOfRows(inSection: indexPath.section)
        self.styleInnerCardOfErrorCell(errorCell, at: indexPath, totalRows: totalRows)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 38.0
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerTitle = self.tableView(tableView, titleForHeaderInSection: section) ?? ""
        
        let container = UIView()
        container.backgroundColor = .clear
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = headerTitle.uppercased()
        titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .heavy)
        titleLabel.textColor = ErrorLogCSSTheme.blue
        
        let underline = UIView()
        underline.translatesAutoresizingMaskIntoConstraints = false
        underline.backgroundColor = ErrorLogCSSTheme.blue
        underline.layer.cornerRadius = 1.5
        
        container.addSubview(titleLabel)
        container.addSubview(underline)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: ErrorLogCSSTheme.cardHorizontalInset + 4),
            titleLabel.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 2),
            
            underline.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            underline.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            underline.widthAnchor.constraint(equalToConstant: 36),
            underline.heightAnchor.constraint(equalToConstant: 3)
        ])
        
        return container
    }

    @available(tvOS 17.0, *)
    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration?
    {
        let loggedError = self.dataSource.item(at: indexPath)
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            return UIMenu(title: "Tùy chọn lỗi", children: [
                UIAction(title: "Sao chép nội dung lỗi", image: UIImage(systemName: "doc.on.doc")) { [weak self] _ in
                    self?.copyErrorMessage(for: loggedError)
                },
                UIAction(title: "Sao chép mã lỗi (Code)", image: UIImage(systemName: "number.square")) { [weak self] _ in
                    self?.copyErrorCode(for: loggedError)
                },
                UIAction(title: "Tra cứu hướng dẫn sửa lỗi (FAQ)", image: UIImage(systemName: "magnifyingglass")) { [weak self] _ in
                    self?.searchFAQ(for: loggedError)
                },
                UIAction(title: "Xem chi tiết kỹ thuật", image: UIImage(systemName: "ellipsis.circle")) { [weak self] _ in
                    self?.viewMoreDetails(for: loggedError)
                },
            ])
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let cell = tableView.cellForRow(at: indexPath) as? ErrorLogTableViewCell else { return }
        
        UIView.animate(withDuration: 0.12, animations: {
            cell.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
        }) { _ in
            UIView.animate(withDuration: 0.25) {
                cell.transform = .identity
            }
        }
        
        if !cell.errorDescriptionTextView.moreButton.isHidden
        {
            self.toggleCollapsingCell(cell.errorDescriptionTextView.moreButton)
        }
        else
        {
            let loggedError = self.dataSource.item(at: indexPath)
            self.viewMoreDetails(for: loggedError)
        }
    }
    
    #if !os(tvOS)
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration?
    {
        let deleteAction = UIContextualAction(style: .destructive, title: "Xóa") { [weak self] _, _, completion in
            guard let self = self else {
                completion(false)
                return
            }
            let loggedError = self.dataSource.item(at: indexPath)
            DatabaseManager.shared.persistentContainer.performBackgroundTask { context in
                do
                {
                    let loggedError = context.object(with: loggedError.objectID) as! LoggedError
                    context.delete(loggedError)
                    
                    try context.save()
                    DispatchQueue.main.async {
                        self.enforceBrightGradientBackground()
                        self.updateFloatingClearAllButtonState()
                        completion(true)
                    }
                }
                catch
                {
                    debugLog("[SideStore] Failed to delete LoggedError \(loggedError.objectID): \(error)")
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        }
        deleteAction.backgroundColor = ErrorLogCSSTheme.danger
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    #endif
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String?
    {
        let indexPath = IndexPath(row: 0, section: section)
        let loggedError = self.dataSource.item(at: indexPath)
        
        if Calendar.current.isDateInToday(loggedError.date)
        {
            return "Hôm nay"
        }
        else if Calendar.current.isDateInYesterday(loggedError.date)
        {
            return "Hôm qua"
        }
        else
        {
            return loggedError.localizedDateString
        }
    }
}

extension ErrorLogViewController
{
    override func scrollViewWillBeginDragging(_ scrollView: UIScrollView)
    {
        self.isScrolling = true
    }
    override func scrollViewDidEndDecelerating(_ scrollView: UIScrollView)
    {
        self.isScrolling = false
    }
    override func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool)
    {
        guard !decelerate else { return }
        self.isScrolling = false
    }
    private func updateButtonInteractivity()
    {
        if #available(tvOS 17.0, *) {
            for case let cell as ErrorLogTableViewCell in self.tableView.visibleCells
            {
                if self.isScrolling
                {
                    cell.menuButton.showsMenuAsPrimaryAction = false
                }
                else
                {
                    cell.menuButton.showsMenuAsPrimaryAction = true
                }
            }
        }
    }
}
