

//
//  RefreshAttemptsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/31/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TOÀN BỘ ỨNG DỤNG & CHỮ ĐEN TUYỀN)
private struct CSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                      // #000000 (Chữ đen tuyền độ tương phản tuyệt đối)
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)       // #f5f8ff (Đồng bộ innerRowBackground)
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)      // #dce2ec (Viền chuẩn toàn hệ thống)
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0) // #dee5f0
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)         // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)           // #dc3545
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0)       // #ff00ff
    static let dark = UIColor.black                                                           // #000000

    // Gradient Background (#f3e0ff -> #e0f7ff)
    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    // Hero Gradient (rgba(0,123,255,.95) -> rgba(111,66,193,.92))
    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.95).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.92).cgColor

    static let cornerRadius: CGFloat = 18.0
    static let innerCornerRadius: CGFloat = 14.0
    static let cardHorizontalInset: CGFloat = 16.0
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH (KHÔNG BỊ TRẮNG HAY ĐEN KHI CUỘN/XOÁ)
private final class CSSGradientBackgroundView: UIView {
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
        gradientLayer.colors = [CSSTheme.bgGradientStart, CSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - ➖ THANH GẠCH CHÂN GRADIENT XANH - TÍM (38x3.5pt ĐỒNG BỘ TOÀN HỆ THỐNG)
private final class RefreshAttemptAccentUnderlineView: UIView {
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
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        gradientLayer.colors = [CSSTheme.blue.cgColor, CSSTheme.purple.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        layer.cornerRadius = 1.75
        clipsToBounds = true
    }
}

// MARK: - 📋 CELL HIỂN THỊ LỊCH SỬ LÀM MỚI (GIỮ NGUYÊN @IBOUTLET GỐC TRÁNH CRASH STORYBOARD)
@objc(RefreshAttemptTableViewCell)
private final class RefreshAttemptTableViewCell: UITableViewCell
{
    @IBOutlet var successLabel: UILabel!
    @IBOutlet var dateLabel: UILabel!
    @IBOutlet var errorDescriptionLabel: UILabel!

    private let cardBackgroundView = UIView()
    private let separatorLine = UIView()

    override func awakeFromNib() {
        super.awakeFromNib()

        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear
        self.selectionStyle = .none

        // ✨ CĂN LỀ (PADDING) BÊN TRONG KHUNG CARD CHO CÁC CHỮ VÀ NGÀY THÁNG NĂM:
        // Khung Card cách lề màn hình 16pt + thêm 16pt lề trong = 32pt hai bên trái/phải.
        // Cách lề trên/dưới 14pt giúp nội dung và ngày tháng thoáng đãng, không bị sát viền.
        self.preservesSuperviewLayoutMargins = false
        self.contentView.preservesSuperviewLayoutMargins = false
        self.contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 14, leading: 32, bottom: 14, trailing: 32)

        // Khung Card màu trắng bên dưới nội dung đồng bộ chuẩn hệ thống
        cardBackgroundView.translatesAutoresizingMaskIntoConstraints = false
        cardBackgroundView.backgroundColor = CSSTheme.white
        if #available(iOS 13.0, *) {
            cardBackgroundView.layer.cornerCurve = .continuous
        }
        cardBackgroundView.layer.masksToBounds = false
        cardBackgroundView.layer.borderColor = CSSTheme.border.cgColor
        cardBackgroundView.layer.shadowColor = CSSTheme.blue.cgColor
        cardBackgroundView.layer.shadowOffset = CGSize(width: 0, height: 6)
        cardBackgroundView.layer.shadowRadius = 14
        cardBackgroundView.layer.shadowOpacity = 0.08
        self.contentView.insertSubview(cardBackgroundView, at: 0)

        // Đường kẻ phân cách giữa các dòng trong Card (căn thẳng hàng với lề chữ 16pt bên trong Card)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = CSSTheme.border
        self.contentView.addSubview(separatorLine)

        NSLayoutConstraint.activate([
            cardBackgroundView.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: CSSTheme.cardHorizontalInset),
            cardBackgroundView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -CSSTheme.cardHorizontalInset),
            cardBackgroundView.topAnchor.constraint(equalTo: self.contentView.topAnchor),
            cardBackgroundView.bottomAnchor.constraint(equalTo: self.contentView.bottomAnchor),

            separatorLine.leadingAnchor.constraint(equalTo: cardBackgroundView.leadingAnchor, constant: 16),
            separatorLine.trailingAnchor.constraint(equalTo: cardBackgroundView.trailingAnchor, constant: -16),
            separatorLine.bottomAnchor.constraint(equalTo: cardBackgroundView.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 1.0)
        ])

        // Làm đẹp các nhãn văn bản với chữ đen tuyền #000000
        if let sLabel = self.successLabel {
            sLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
            sLabel.layer.cornerRadius = 7
            sLabel.layer.masksToBounds = true
            sLabel.setContentHuggingPriority(.required, for: .horizontal)
        }

        if let dLabel = self.dateLabel {
            dLabel.font = UIFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .bold)
            dLabel.textColor = CSSTheme.purple
            dLabel.textAlignment = .right
        }

        if let eLabel = self.errorDescriptionLabel {
            eLabel.font = UIFont.systemFont(ofSize: 13.8, weight: .medium)
            eLabel.textColor = CSSTheme.pureBlack
            eLabel.numberOfLines = 0
        }
    }

    func applyCardCorners(row: Int, totalRows: Int) {
        var corners: CACornerMask = []
        if totalRows == 1 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        } else if row == 0 {
            corners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        } else if row == totalRows - 1 {
            corners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        }

        cardBackgroundView.layer.cornerRadius = corners.isEmpty ? 0 : CSSTheme.cornerRadius
        cardBackgroundView.layer.maskedCorners = corners
        cardBackgroundView.layer.borderWidth = totalRows == 1 ? 1.1 : 0.6
        separatorLine.isHidden = (row >= totalRows - 1)

        // Tăng thêm một chút khoảng đệm ở dòng đầu tiên và dòng cuối cùng của khung Card để bo góc đẹp hơn
        let topPadding: CGFloat = (row == 0) ? 16 : 13
        let bottomPadding: CGFloat = (row == totalRows - 1) ? 16 : 13
        self.contentView.directionalLayoutMargins = NSDirectionalEdgeInsets(top: topPadding, leading: 32, bottom: bottomPadding, trailing: 32)
    }
}

// MARK: - 🚀 CONTROLLER LỊCH SỬ LÀM MỚI ỨNG DỤNG
final class RefreshAttemptsViewController: UITableViewController
{
    private lazy var dataSource = self.makeDataSource()
    private var heroGradientLayer: CAGradientLayer?
    private weak var heroClipView: UIView?

    // Nút Xoá Tất Cả cố định ở góc trên cùng bên phải
    private var floatingClearAllButton: UIButton?

    private lazy var dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "vi_VN")
        dateFormatter.dateFormat = "HH:mm • dd/MM/yyyy"
        return dateFormatter
    }()

    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Khóa cứng giao diện Light Mode để hệ thống không bao giờ đưa về nền đen
        self.overrideUserInterfaceStyle = .light
        self.view.overrideUserInterfaceStyle = .light
        self.tableView.overrideUserInterfaceStyle = .light

        // Ẩn tiêu đề mặc định để đồng bộ giao diện tràn viền của Settings
        self.title = nil
        self.navigationItem.title = nil
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        #endif

        self.tableView.dataSource = self.dataSource
        self.dataSource.contentView = self.tableView

        // Cho phép TableView tự tính toán chiều cao Cell mượt mà khi thêm lề trên/dưới
        self.tableView.rowHeight = UITableView.automaticDimension
        self.tableView.estimatedRowHeight = 76

        self.tableView.contentInset.top = 0
        self.tableView.contentInset.bottom = 50
        if #available(iOS 15.0, tvOS 15.0, *) {
            self.tableView.sectionHeaderTopPadding = 0
        }

        // ✨ KÍCH HOẠT GIAO DIỆN CSS THEME ✨
        self.applySmartWebCSSTheme()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        self.enforceBrightGradientBackground()
        self.setupFloatingClearAllButton(show: true)
        self.updateClearAllButtonState()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.setupFloatingClearAllButton(show: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let clipView = self.heroClipView {
            self.heroGradientLayer?.frame = clipView.bounds
        }
        self.enforceBrightGradientBackground()
    }

    deinit {
        self.floatingClearAllButton?.removeFromSuperview()
    }
}

// MARK: - ✨ THIẾT KẾ GIAO DIỆN CSS & NÚT XOÁ TẤT CẢ CỐ ĐỊNH
private extension RefreshAttemptsViewController
{
    func applySmartWebCSSTheme() {
        // 1. Khóa nền Gradient sáng cố định trong mọi trạng thái
        self.enforceBrightGradientBackground()
        self.tableView.separatorStyle = .none

        // 2. Tạo khối Hero Banner phía trên
        setupCSSHeroBanner()
    }

    /// Đảm bảo nền sáng Gradient luôn hiển thị 100%, kể cả khi xoá hết dữ liệu và PlaceholderView xuất hiện
    func enforceBrightGradientBackground() {
        let fallbackBrightColor = UIColor(red: 235/255, green: 238/255, blue: 255/255, alpha: 1.0)
        self.view.backgroundColor = fallbackBrightColor
        self.tableView.backgroundColor = fallbackBrightColor

        if let placeholder = self.tableView.backgroundView, !(placeholder is CSSGradientBackgroundView) {
            placeholder.overrideUserInterfaceStyle = .light
            placeholder.backgroundColor = .clear

            let bgTag = 992211
            if let existingGradient = placeholder.viewWithTag(bgTag) {
                existingGradient.frame = placeholder.bounds
                placeholder.sendSubviewToBack(existingGradient)
            } else {
                let gradientBg = CSSGradientBackgroundView(frame: placeholder.bounds)
                gradientBg.tag = bgTag
                gradientBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                placeholder.insertSubview(gradientBg, at: 0)
            }
        } else if self.tableView.backgroundView == nil {
            let bgView = CSSGradientBackgroundView(frame: UIScreen.main.bounds)
            bgView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.tableView.backgroundView = bgView
        }
    }

    /// Trang trí giao diện Placeholder (khi xóa hết lịch sử) nổi bật và hài hòa trên nền sáng CSS & chữ đen tuyền
    func styleBrightPlaceholderView(_ placeholderView: PlaceholderView) {
        placeholderView.overrideUserInterfaceStyle = .light
        placeholderView.backgroundColor = .clear

        // Chèn lớp nền Gradient sáng vào tầng đáy của PlaceholderView
        let bgTag = 992211
        if placeholderView.viewWithTag(bgTag) == nil {
            let gradientBg = CSSGradientBackgroundView(frame: UIScreen.main.bounds)
            gradientBg.tag = bgTag
            gradientBg.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            placeholderView.insertSubview(gradientBg, at: 0)
        }

        // Chỉnh màu chữ đen tuyền và xanh chủ đạo rõ nét trên nền sáng
        placeholderView.textLabel.text = "✓ Chưa Có Lịch Sử Làm Mới"
        placeholderView.textLabel.textColor = CSSTheme.blue
        if let roundedDesc = UIFont.systemFont(ofSize: 19, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            placeholderView.textLabel.font = UIFont(descriptor: roundedDesc, size: 19)
        } else {
            placeholderView.textLabel.font = UIFont.systemFont(ofSize: 19, weight: .heavy)
        }

        placeholderView.detailTextLabel.text = "Lịch sử làm mới hiện đang trống.\nKhi bạn sử dụng SideStore, hệ thống sẽ tự động ghi lại chi tiết các lần gia hạn ứng dụng tại đây."
        placeholderView.detailTextLabel.textColor = CSSTheme.pureBlack
        placeholderView.detailTextLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        // Tạo khung Card trắng chuẩn hệ thống phía sau chữ để cụm thông báo nổi bật, sang trọng
        if let stackView = placeholderView.textLabel.superview {
            let cardTag = 992233
            if placeholderView.viewWithTag(cardTag) == nil {
                let cardBg = UIView()
                cardBg.tag = cardTag
                cardBg.translatesAutoresizingMaskIntoConstraints = false
                cardBg.backgroundColor = CSSTheme.white
                cardBg.layer.cornerRadius = CSSTheme.cornerRadius
                if #available(iOS 13.0, *) {
                    cardBg.layer.cornerCurve = .continuous
                }
                cardBg.layer.borderWidth = 1.1
                cardBg.layer.borderColor = CSSTheme.border.cgColor
                cardBg.layer.shadowColor = CSSTheme.blue.cgColor
                cardBg.layer.shadowOffset = CGSize(width: 0, height: 6)
                cardBg.layer.shadowRadius = 14
                cardBg.layer.shadowOpacity = 0.09
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
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.bounds.width, height: 118))
        headerContainer.backgroundColor = .clear

        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = CSSTheme.cornerRadius
        if #available(iOS 13.0, *) {
            heroCard.layer.cornerCurve = .continuous
        }
        heroCard.layer.masksToBounds = false
        heroCard.layer.shadowColor = CSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 7)
        heroCard.layer.shadowRadius = 14
        heroCard.layer.shadowOpacity = 0.26

        let clipView = UIView()
        clipView.translatesAutoresizingMaskIntoConstraints = false
        clipView.layer.cornerRadius = CSSTheme.cornerRadius
        if #available(iOS 13.0, *) {
            clipView.layer.cornerCurve = .continuous
        }
        clipView.clipsToBounds = true
        clipView.layer.borderWidth = 1.2
        clipView.layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
        self.heroClipView = clipView

        let gradient = CAGradientLayer()
        gradient.colors = [CSSTheme.heroStart, CSSTheme.heroEnd]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        clipView.layer.insertSublayer(gradient, at: 0)
        self.heroGradientLayer = gradient

        // Vòng tròn kính mờ trang trí góc trên bên phải đồng bộ
        let decorCircle = UIView()
        decorCircle.translatesAutoresizingMaskIntoConstraints = false
        decorCircle.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        decorCircle.layer.cornerRadius = 55
        decorCircle.isUserInteractionEnabled = false
        clipView.addSubview(decorCircle)

        // Hàng Tiêu đề + Icon kính mờ
        let titleStack = UIStackView()
        titleStack.translatesAutoresizingMaskIntoConstraints = false
        titleStack.axis = .horizontal
        titleStack.spacing = 8
        titleStack.alignment = .center

        let iconBadge = UIView()
        iconBadge.translatesAutoresizingMaskIntoConstraints = false
        iconBadge.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        iconBadge.layer.cornerRadius = 15

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconSymConfig = UIImage.SymbolConfiguration(pointSize: 13.5, weight: .bold)
        iconView.image = UIImage(systemName: "clock.arrow.2.circlepath", withConfiguration: iconSymConfig)
            ?? UIImage(systemName: "arrow.clockwise.circle.fill", withConfiguration: iconSymConfig)
        iconView.tintColor = .white
        iconBadge.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Lịch Sử Làm Mới"
        if let roundedDesc = UIFont.systemFont(ofSize: 22, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 22)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .heavy)
        }
        titleLabel.textColor = CSSTheme.white
        titleLabel.textAlignment = .center
        titleLabel.layer.shadowColor = UIColor.black.cgColor
        titleLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        titleLabel.layer.shadowRadius = 4
        titleLabel.layer.shadowOpacity = 0.28

        titleStack.addArrangedSubview(iconBadge)
        titleStack.addArrangedSubview(titleLabel)

        let subLabel = UILabel()
        subLabel.translatesAutoresizingMaskIntoConstraints = false
        subLabel.text = "Theo dõi chi tiết các lần tự động gia hạn & làm mới ứng dụng"
        subLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        subLabel.textColor = CSSTheme.white.withAlphaComponent(0.96)
        subLabel.textAlignment = .center
        subLabel.numberOfLines = 2

        clipView.addSubview(titleStack)
        clipView.addSubview(subLabel)
        heroCard.addSubview(clipView)
        headerContainer.addSubview(heroCard)

        NSLayoutConstraint.activate([
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: CSSTheme.cardHorizontalInset),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -CSSTheme.cardHorizontalInset),
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -8),

            clipView.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor),
            clipView.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor),
            clipView.topAnchor.constraint(equalTo: heroCard.topAnchor),
            clipView.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor),

            decorCircle.widthAnchor.constraint(equalToConstant: 110),
            decorCircle.heightAnchor.constraint(equalToConstant: 110),
            decorCircle.trailingAnchor.constraint(equalTo: clipView.trailingAnchor, constant: 32),
            decorCircle.topAnchor.constraint(equalTo: clipView.topAnchor, constant: -42),

            iconBadge.widthAnchor.constraint(equalToConstant: 30),
            iconBadge.heightAnchor.constraint(equalToConstant: 30),
            iconView.centerXAnchor.constraint(equalTo: iconBadge.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBadge.centerYAnchor),

            titleStack.centerXAnchor.constraint(equalTo: clipView.centerXAnchor),
            titleStack.topAnchor.constraint(equalTo: clipView.topAnchor, constant: 15),

            subLabel.topAnchor.constraint(equalTo: titleStack.bottomAnchor, constant: 6),
            subLabel.leadingAnchor.constraint(equalTo: clipView.leadingAnchor, constant: 16),
            subLabel.trailingAnchor.constraint(equalTo: clipView.trailingAnchor, constant: -16)
        ])

        heroCard.alpha = 0
        heroCard.transform = CGAffineTransform(translationX: 0, y: -10)
        UIView.animate(withDuration: 0.5, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            heroCard.alpha = 1
            heroCard.transform = .identity
        }

        self.tableView.tableHeaderView = headerContainer
    }

    // Tạo nút Xoá tất cả (Icon thùng rác) cố định góc trên cùng bên phải, đối xứng với nút Back bên trái
    func setupFloatingClearAllButton(show: Bool) {
        guard let hostView = self.navigationController?.view ?? self.view else { return }

        if self.floatingClearAllButton == nil {
            let btn = UIButton(type: .system)
            btn.translatesAutoresizingMaskIntoConstraints = false

            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
            btn.setImage(UIImage(systemName: "trash.fill", withConfiguration: config), for: .normal)
            btn.tintColor = CSSTheme.red
            btn.backgroundColor = CSSTheme.white.withAlphaComponent(0.95)

            // Kích thước tròn 34x34 đồng bộ với nút Back của SettingsViewController
            btn.layer.cornerRadius = 17
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = CSSTheme.border.cgColor
            btn.layer.shadowColor = UIColor.black.cgColor
            btn.layer.shadowOffset = CGSize(width: 0, height: 2)
            btn.layer.shadowRadius = 6
            btn.layer.shadowOpacity = 0.14

            btn.addTarget(self, action: #selector(handleClearAllTapped), for: .touchUpInside)
            hostView.addSubview(btn)

            NSLayoutConstraint.activate([
                btn.trailingAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.trailingAnchor, constant: -16),
                btn.topAnchor.constraint(equalTo: hostView.safeAreaLayoutGuide.topAnchor, constant: 6),
                btn.widthAnchor.constraint(equalToConstant: 34),
                btn.heightAnchor.constraint(equalToConstant: 34)
            ])

            self.floatingClearAllButton = btn
        }

        guard let btn = self.floatingClearAllButton else { return }
        hostView.bringSubviewToFront(btn)

        UIView.animate(withDuration: 0.2) {
            btn.alpha = show ? 1.0 : 0.0
            btn.isHidden = !show
        }
    }

    func updateClearAllButtonState() {
        let count = self.dataSource.fetchedResultsController.fetchedObjects?.count ?? 0
        let hasItems = (count > 0)
        self.floatingClearAllButton?.isEnabled = hasItems
        self.floatingClearAllButton?.tintColor = hasItems ? CSSTheme.red : UIColor.systemGray3
    }

    @objc func handleClearAllTapped() {
        // Hiệu ứng nhấn nút
        if let btn = self.floatingClearAllButton {
            UIView.animate(withDuration: 0.1, animations: {
                btn.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
            }) { _ in
                UIView.animate(withDuration: 0.2) {
                    btn.transform = .identity
                }
            }
        }

        let count = self.dataSource.fetchedResultsController.fetchedObjects?.count ?? 0
        guard count > 0 else { return }

        let alert = UIAlertController(
            title: "Xoá toàn bộ lịch sử?",
            message: "Bạn có chắc chắn muốn xoá tất cả \(count) mục trong lịch sử làm mới ứng dụng không? Thao tác này không thể hoàn tác.",
            preferredStyle: .alert
        )
        alert.view.tintColor = CSSTheme.blue

        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Xoá tất cả", style: .destructive) { [weak self] _ in
            self?.performDeleteAllRefreshAttempts()
        })

        self.present(alert, animated: true, completion: nil)
    }

    func performDeleteAllRefreshAttempts() {
        let context = DatabaseManager.shared.viewContext
        context.perform { [weak self] in
            let fetchRequest = RefreshAttempt.fetchRequest() as NSFetchRequest<RefreshAttempt>
            if let attempts = try? context.fetch(fetchRequest), !attempts.isEmpty {
                for attempt in attempts {
                    context.delete(attempt)
                }
                try? context.save()
            }

            DispatchQueue.main.async {
                guard let self = self else { return }
                self.tableView.reloadData()
                self.enforceBrightGradientBackground()
                self.updateClearAllButtonState()

                let toast = ToastView(text: "Đã xoá toàn bộ lịch sử làm mới", detailText: nil)
                toast.tintColor = CSSTheme.blue
                toast.show(in: self.view)
            }
        }
    }
}

// MARK: - 📦 NGUỒN DỮ LIỆU & CẤU HÌNH TABLEVIEW
private extension RefreshAttemptsViewController
{
    func makeDataSource() -> FetchedResultsTableViewDataSource<RefreshAttempt>
    {
        let fetchRequest = RefreshAttempt.fetchRequest() as NSFetchRequest<RefreshAttempt>
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RefreshAttempt.date, ascending: false)]
        fetchRequest.returnsObjectsAsFaults = false

        let dataSource = FetchedResultsTableViewDataSource(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.shared.viewContext)
        dataSource.cellConfigurationHandler = { [weak self] (cell, attempt, indexPath) in
            let cell = cell as! RefreshAttemptTableViewCell

            // Thêm khoảng đệm nhẹ cho ngày tháng năm để nhìn cân đối hơn
            if let formattedDate = self?.dateFormatter.string(from: attempt.date) {
                cell.dateLabel.text = formattedDate
            } else {
                cell.dateLabel.text = nil
            }

            let descriptionText: String

            if attempt.isSuccess
            {
                cell.successLabel.text = "  ✓ Thành công  "
                cell.successLabel.textColor = CSSTheme.green
                cell.successLabel.backgroundColor = CSSTheme.green.withAlphaComponent(0.14)
                descriptionText = "Tất cả ứng dụng đã được gia hạn thành công."
            }
            else
            {
                cell.successLabel.text = "  ✕ Thất bại  "
                cell.successLabel.textColor = CSSTheme.red
                cell.successLabel.backgroundColor = CSSTheme.red.withAlphaComponent(0.14)
                descriptionText = attempt.errorDescription ?? "Đã xảy ra lỗi không xác định trong quá trình làm mới."
            }

            // Tạo khoảng cách dòng (lineSpacing) và chữ đen tuyền #000000 rõ nét
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 3.0
            paragraphStyle.paragraphSpacingBefore = 2.0

            cell.errorDescriptionLabel.attributedText = NSAttributedString(
                string: descriptionText,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 13.8, weight: .medium),
                    .foregroundColor: CSSTheme.pureBlack,
                    .paragraphStyle: paragraphStyle
                ]
            )
        }

        let placeholderView = PlaceholderView()
        self.styleBrightPlaceholderView(placeholderView)
        dataSource.placeholderView = placeholderView

        return dataSource
    }
}

extension RefreshAttemptsViewController
{
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let count = tableView.numberOfRows(inSection: section)
        return count > 0 ? 44.0 : 0.0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let count = tableView.numberOfRows(inSection: section)
        guard count > 0 else { return nil }

        let container = UIView()
        container.backgroundColor = .clear

        let iconBox = UIView()
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        iconBox.backgroundColor = CSSTheme.blue.withAlphaComponent(0.14)
        iconBox.layer.cornerRadius = 6.5
        if #available(iOS 13.0, *) {
            iconBox.layer.cornerCurve = .continuous
        }

        let iconView = UIImageView()
        iconView.translatesAutoresizingMaskIntoConstraints = false
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 11.5, weight: .heavy)
        iconView.image = UIImage(systemName: "list.bullet.clipboard.fill", withConfiguration: iconConfig)
            ?? UIImage(systemName: "clock.fill", withConfiguration: iconConfig)
        iconView.tintColor = CSSTheme.blue
        iconBox.addSubview(iconView)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "NHẬT KÝ GIA HẠN (\(count))"
        if let roundedDesc = UIFont.systemFont(ofSize: 14, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            titleLabel.font = UIFont(descriptor: roundedDesc, size: 14)
        } else {
            titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .heavy)
        }
        titleLabel.textColor = CSSTheme.blue

        let underline = RefreshAttemptAccentUnderlineView()
        underline.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconBox)
        container.addSubview(titleLabel)
        container.addSubview(underline)

        NSLayoutConstraint.activate([
            iconBox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: CSSTheme.cardHorizontalInset + 4),
            iconBox.centerYAnchor.constraint(equalTo: container.centerYAnchor, constant: 1),
            iconBox.widthAnchor.constraint(equalToConstant: 22),
            iconBox.heightAnchor.constraint(equalToConstant: 22),

            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            titleLabel.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 7),
            titleLabel.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),

            underline.leadingAnchor.constraint(equalTo: iconBox.leadingAnchor),
            underline.topAnchor.constraint(equalTo: iconBox.bottomAnchor, constant: 4),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3.5)
        ])

        return container
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let totalRows = tableView.numberOfRows(inSection: indexPath.section)
        if let attemptCell = cell as? RefreshAttemptTableViewCell {
            attemptCell.applyCardCorners(row: indexPath.row, totalRows: totalRows)
        }
        self.updateClearAllButtonState()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.12, animations: {
                cell.transform = CGAffineTransform(translationX: 4, y: -1).scaledBy(x: 0.98, y: 0.98)
            }) { _ in
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5, options: .curveEaseOut) {
                    cell.transform = .identity
                }
            }
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
