
//
//  NewsViewController.swift
//  AltStore
//
//  Created by Riley Testut on 8/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import SafariServices
import AVKit
import Network
import AltStoreCore

final class NewsViewController: UICollectionViewController
{
    // MARK: - Gradient Background & Dynamic Status UI
    private let pageGradientLayer = CAGradientLayer()
    private let impactFeedback = UIImpactFeedbackGenerator(style: .light)
    
    private weak var pairingSubtitleLabel: UILabel?
    private weak var pairingBadgeLabel: UILabel?
    private weak var pairingBadgeContainer: UIView?
    
    private weak var vpnSubtitleLabel: UILabel?
    private weak var vpnBadgeLabel: UILabel?
    private weak var vpnBadgeContainer: UIView?
    
    // MARK: - Lifecycle
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        // Khóa cứng giao diện Sáng (Light Mode) để đồng bộ hoàn toàn với CSS
        self.overrideUserInterfaceStyle = .light
        self.impactFeedback.prepare()
        
        // Ẩn toàn bộ nội dung mặc định của CollectionView để dựng Dashboard Tổng Quan hiện đại
        self.collectionView.dataSource = nil
        self.collectionView.delegate = nil
        self.collectionView.isScrollEnabled = false
        self.collectionView.backgroundColor = .clear
        
        // Ẩn thanh Navigation Bar để giao diện tràn viền hiện đại giống hệt CSS
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
        setupBackgroundGradient()
        setupDashboardUI()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshSystemStatus()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        pageGradientLayer.frame = self.view.bounds
    }
    
    // MARK: - Background Gradient (#f3e0ff -> #e0f7ff)
    private func setupBackgroundGradient()
    {
        pageGradientLayer.colors = [
            UIColor(red: 0.953, green: 0.878, blue: 1.0, alpha: 1.0).cgColor, // #f3e0ff
            UIColor(red: 0.878, green: 0.969, blue: 1.0, alpha: 1.0).cgColor  // #e0f7ff
        ]
        pageGradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        pageGradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        pageGradientLayer.frame = self.view.bounds
        self.view.layer.insertSublayer(pageGradientLayer, at: 0)
    }
    
    // MARK: - Build Main Dashboard UI
    private func setupDashboardUI()
    {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        self.view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let mainStack = UIStackView()
        mainStack.axis = .vertical
        mainStack.spacing = 18
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -32)
        ])
        
        // 1. HERO HEADER BANNER (.header trong CSS + Ánh sáng 3D)
        mainStack.addArrangedSubview(makeHeroBanner())
        
        // 2. SECTION: TRẠNG THÁI HỆ THỐNG
        mainStack.addArrangedSubview(makeSectionHeader(title: "TRẠNG THÁI HỆ THỐNG"))
        mainStack.addArrangedSubview(makeSystemStatusCard())
        
        // 3. SECTION: PHÍM TẮT & LÀM MỚI TỰ ĐỘNG 4G
        mainStack.addArrangedSubview(makeSectionHeader(title: "PHÍM TẮT & LÀM MỚI 4G"))
        mainStack.addArrangedSubview(makeShortcutsCard())
        
        // 4. SECTION: HƯỚNG DẪN TỰ ĐỘNG HÓA 2 LẦN / NGÀY
        mainStack.addArrangedSubview(makeSectionHeader(title: "HƯỚNG DẪN TỰ ĐỘNG HÓA"))
        mainStack.addArrangedSubview(makeAutomationGuideCard())
        
        // 5. SECTION: VIDEO HƯỚNG DẪN CHI TIẾT
        mainStack.addArrangedSubview(makeSectionHeader(title: "VIDEO HƯỚNG DẪN"))
        mainStack.addArrangedSubview(makeVideoTutorialCard())
    }
    
    // MARK: - 1. Hero Header Banner (Gradient #007bff -> #6f42c1 + Ambient 3D Orbs)
    private func makeHeroBanner() -> UIView
    {
        let container = GradientBannerView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.layer.cornerRadius = 18
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor(red: 0.0, green: 0.35, blue: 0.90, alpha: 1.0).cgColor
        container.layer.shadowOpacity = 0.22
        container.layer.shadowOffset = CGSize(width: 0, height: 8)
        container.layer.shadowRadius = 18
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        
        let badge = UILabel()
        badge.text = "✨ HỆ THỐNG TỰ ĐỘNG GIA HẠN"
        badge.font = .systemFont(ofSize: 10.5, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        badge.layer.cornerRadius = 9
        badge.layer.borderWidth = 0.5
        badge.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        badge.clipsToBounds = true
        badge.textAlignment = .center
        
        let badgeWrapper = UIView()
        badgeWrapper.translatesAutoresizingMaskIntoConstraints = false
        badge.translatesAutoresizingMaskIntoConstraints = false
        badgeWrapper.addSubview(badge)
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: badgeWrapper.topAnchor),
            badge.bottomAnchor.constraint(equalTo: badgeWrapper.bottomAnchor),
            badge.leadingAnchor.constraint(equalTo: badgeWrapper.leadingAnchor),
            badge.trailingAnchor.constraint(equalTo: badgeWrapper.trailingAnchor),
            badge.widthAnchor.constraint(equalToConstant: 215),
            badge.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        let titleLabel = UILabel()
        titleLabel.text = "Chào mừng đến SideStore"
        titleLabel.font = .systemFont(ofSize: 21, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Quản lý chứng chỉ, ghép đôi iOS 27 & tự động làm mới ứng dụng qua Wi-Fi / 4G"
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        
        stack.addArrangedSubview(badgeWrapper)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18)
        ])
        
        return container
    }
    
    // MARK: - Section Title Header with Blue Underline (.category-section h2::after)
    private func makeSectionHeader(title: String) -> UIView
    {
        let wrapper = UIView()
        wrapper.translatesAutoresizingMaskIntoConstraints = false
        
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 13.5, weight: .heavy)
        label.textColor = UIColor(red: 0.12, green: 0.15, blue: 0.22, alpha: 1.0)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        let underline = UIView()
        underline.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0) // #007bff
        underline.layer.cornerRadius = 1.5
        underline.translatesAutoresizingMaskIntoConstraints = false
        
        wrapper.addSubview(label)
        wrapper.addSubview(underline)
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor),
            
            underline.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 5),
            underline.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            underline.widthAnchor.constraint(equalToConstant: 38),
            underline.heightAnchor.constraint(equalToConstant: 3),
            underline.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor)
        ])
        
        return wrapper
    }
    
    // MARK: - 2. System Status Card (3 Rows: Pairing, LocalDevVPN, 4G Support)
    private func makeSystemStatusCard() -> UIView
    {
        let card = makeWhiteCardContainer()
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4)
        ])
        
        // Row 1: Hồ sơ ghép đôi (Pairing File)
        let pairingRow = makeStatusRow(
            iconName: "iphone.and.arrow.forward",
            iconTint: UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
            iconBg: UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0),
            title: "Hồ sơ ghép đôi (Pairing File)",
            subtitle: "Đang kiểm tra trạng thái...",
            badgeText: "KIỂM TRA",
            action: #selector(handlePairingRowTap)
        )
        self.pairingSubtitleLabel = pairingRow.subtitleLabel
        self.pairingBadgeLabel = pairingRow.badgeLabel
        self.pairingBadgeContainer = pairingRow.badgeContainer
        
        // Row 2: Kết nối LocalDevVPN
        let vpnRow = makeStatusRow(
            iconName: "network.badge.shield.half.filled",
            iconTint: UIColor(red: 0.16, green: 0.65, blue: 0.27, alpha: 1.0),
            iconBg: UIColor(red: 0.90, green: 0.98, blue: 0.92, alpha: 1.0),
            title: "Kết nối LocalDevVPN",
            subtitle: "Đang kiểm tra đường hầm...",
            badgeText: "KIỂM TRA",
            action: #selector(handleVPNRowTap)
        )
        self.vpnSubtitleLabel = vpnRow.subtitleLabel
        self.vpnBadgeLabel = vpnRow.badgeLabel
        self.vpnBadgeContainer = vpnRow.badgeContainer
        
        // Row 3: Làm mới qua mạng di động 4G
        let cellularRow = makeStatusRow(
            iconName: "antenna.radiowaves.left.and.right",
            iconTint: UIColor(red: 0.44, green: 0.26, blue: 0.76, alpha: 1.0),
            iconBg: UIColor(red: 0.95, green: 0.90, blue: 1.0, alpha: 1.0),
            title: "Làm mới qua mạng di động (4G)",
            subtitle: "Hỗ trợ gia hạn mọi lúc không cần Wi-Fi",
            badgeText: "SẴN SÀNG",
            action: #selector(handleCellularRowTap)
        )
        cellularRow.badgeContainer.backgroundColor = UIColor(red: 0.93, green: 0.89, blue: 1.0, alpha: 1.0)
        cellularRow.badgeLabel.textColor = UIColor(red: 0.44, green: 0.26, blue: 0.76, alpha: 1.0)
        
        stack.addArrangedSubview(pairingRow.view)
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(vpnRow.view)
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(cellularRow.view)
        
        return card
    }
    
    private func makeStatusRow(
        iconName: String,
        iconTint: UIColor,
        iconBg: UIColor,
        title: String,
        subtitle: String,
        badgeText: String,
        action: Selector
    ) -> (view: UIView, subtitleLabel: UILabel, badgeLabel: UILabel, badgeContainer: UIView)
    {
        let rowButton = SpringRowControl()
        rowButton.translatesAutoresizingMaskIntoConstraints = false
        rowButton.addTarget(self, action: action, for: .touchUpInside)
        
        let iconBox = UIView()
        iconBox.backgroundColor = iconBg
        iconBox.layer.cornerRadius = 12
        iconBox.layer.cornerCurve = .continuous
        iconBox.isUserInteractionEnabled = false
        iconBox.translatesAutoresizingMaskIntoConstraints = false
        
        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor = iconTint
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBox.addSubview(iconView)
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
        subtitleLabel.textColor = UIColor(red: 0.42, green: 0.47, blue: 0.55, alpha: 1.0)
        subtitleLabel.numberOfLines = 2
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        
        let badgeContainer = UIView()
        badgeContainer.backgroundColor = UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
        badgeContainer.layer.cornerRadius = 9
        badgeContainer.isUserInteractionEnabled = false
        badgeContainer.translatesAutoresizingMaskIntoConstraints = false
        
        let badgeLabel = UILabel()
        badgeLabel.text = badgeText
        badgeLabel.font = .systemFont(ofSize: 10.5, weight: .bold)
        badgeLabel.textColor = iconTint
        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeContainer.addSubview(badgeLabel)
        
        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.tintColor = UIColor(red: 0.68, green: 0.72, blue: 0.78, alpha: 1.0)
        chevron.contentMode = .scaleAspectFit
        chevron.isUserInteractionEnabled = false
        chevron.translatesAutoresizingMaskIntoConstraints = false
        
        rowButton.addSubview(iconBox)
        rowButton.addSubview(textStack)
        rowButton.addSubview(badgeContainer)
        rowButton.addSubview(chevron)
        
        NSLayoutConstraint.activate([
            iconBox.leadingAnchor.constraint(equalTo: rowButton.leadingAnchor, constant: 14),
            iconBox.centerYAnchor.constraint(equalTo: rowButton.centerYAnchor),
            iconBox.widthAnchor.constraint(equalToConstant: 42),
            iconBox.heightAnchor.constraint(equalToConstant: 42),
            
            iconView.centerXAnchor.constraint(equalTo: iconBox.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBox.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 21),
            iconView.heightAnchor.constraint(equalToConstant: 21),
            
            textStack.topAnchor.constraint(equalTo: rowButton.topAnchor, constant: 13),
            textStack.leadingAnchor.constraint(equalTo: iconBox.trailingAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: rowButton.bottomAnchor, constant: -13),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: badgeContainer.leadingAnchor, constant: -8),
            
            badgeContainer.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -8),
            badgeContainer.centerYAnchor.constraint(equalTo: rowButton.centerYAnchor),
            
            badgeLabel.topAnchor.constraint(equalTo: badgeContainer.topAnchor, constant: 4.5),
            badgeLabel.bottomAnchor.constraint(equalTo: badgeContainer.bottomAnchor, constant: -4.5),
            badgeLabel.leadingAnchor.constraint(equalTo: badgeContainer.leadingAnchor, constant: 8.5),
            badgeLabel.trailingAnchor.constraint(equalTo: badgeContainer.trailingAnchor, constant: -8.5),
            
            chevron.trailingAnchor.constraint(equalTo: rowButton.trailingAnchor, constant: -14),
            chevron.centerYAnchor.constraint(equalTo: rowButton.centerYAnchor),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 12)
        ])
        
        return (rowButton, subtitleLabel, badgeLabel, badgeContainer)
    }
    
    // MARK: - 3. Shortcuts Card (6:00 AM & 15:00 PM iCloud Links)
    private func makeShortcutsCard() -> UIView
    {
        let card = makeWhiteCardContainer()
        
        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 12
        vStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vStack)
        
        let descLabel = UILabel()
        descLabel.text = "Tải 2 phím tắt chuyên dụng dưới đây để tự động bật VPN, làm mới toàn bộ ứng dụng qua Wi-Fi hoặc mạng di động 4G ở chế độ nền:"
        descLabel.font = .systemFont(ofSize: 13.5, weight: .regular)
        descLabel.textColor = UIColor(red: 0.25, green: 0.29, blue: 0.35, alpha: 1.0)
        descLabel.numberOfLines = 0
        
        let btn1 = makeGradientActionButton(
            icon: "sunrise.fill",
            title: "Phím tắt Làm Mới 1 (Khung 6:00 Sáng)",
            subtitle: "Chạm để nhận phím tắt tự động số 1",
            colors: [
                UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0),
                UIColor(red: 0.0, green: 0.34, blue: 0.75, alpha: 1.0)
            ],
            action: #selector(openShortcut1)
        )
        
        let btn2 = makeGradientActionButton(
            icon: "sun.max.fill",
            title: "Phím tắt Làm Mới 2 (Khung 15:00 Chiều)",
            subtitle: "Chạm để nhận phím tắt tự động số 2",
            colors: [
                UIColor(red: 0.44, green: 0.26, blue: 0.76, alpha: 1.0),
                UIColor(red: 0.32, green: 0.16, blue: 0.62, alpha: 1.0)
            ],
            action: #selector(openShortcut2)
        )
        
        vStack.addArrangedSubview(descLabel)
        vStack.addArrangedSubview(btn1)
        vStack.addArrangedSubview(btn2)
        
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    // MARK: - 4. Automation Guide Card (6:00 & 15:00 Step-by-Step)
    private func makeAutomationGuideCard() -> UIView
    {
        let card = makeWhiteCardContainer()
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        
        let headerBox = UIView()
        headerBox.backgroundColor = UIColor(red: 0.94, green: 0.97, blue: 1.0, alpha: 1.0)
        headerBox.layer.cornerRadius = 11
        headerBox.layer.borderWidth = 1
        headerBox.layer.borderColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.18).cgColor
        headerBox.translatesAutoresizingMaskIntoConstraints = false
        
        let headerLabel = UILabel()
        headerLabel.text = "💡 Đặt hẹn giờ chạy tự động 2 lần/ngày lúc 6:00 sáng và 15:00 chiều giúp ứng dụng luôn giữ mức 7 ngày, không bao giờ lo hết hạn!"
        headerLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        headerLabel.textColor = UIColor(red: 0.0, green: 0.36, blue: 0.75, alpha: 1.0)
        headerLabel.numberOfLines = 0
        headerLabel.translatesAutoresizingMaskIntoConstraints = false
        headerBox.addSubview(headerLabel)
        
        NSLayoutConstraint.activate([
            headerLabel.topAnchor.constraint(equalTo: headerBox.topAnchor, constant: 10),
            headerLabel.leadingAnchor.constraint(equalTo: headerBox.leadingAnchor, constant: 12),
            headerLabel.trailingAnchor.constraint(equalTo: headerBox.trailingAnchor, constant: -12),
            headerLabel.bottomAnchor.constraint(equalTo: headerBox.bottomAnchor, constant: -10)
        ])
        
        stack.addArrangedSubview(headerBox)
        stack.addArrangedSubview(makeStepRow(
            number: "1",
            title: "Mở ứng dụng Phím tắt (Shortcuts)",
            detail: "Chuyển sang tab 'Tự động hóa' (Automation) ở thanh công cụ dưới cùng, sau đó bấm dấu '+' tạo mục mới."
        ))
        stack.addArrangedSubview(makeStepRow(
            number: "2",
            title: "Tạo lịch hẹn giờ 6:00 Sáng",
            detail: "Chọn 'Thời gian trong ngày' -> Đặt 06:00 -> Chọn 'Hàng ngày' và tích vào 'Chạy ngay lập tức' (Run Immediately) -> Chọn Phím tắt Làm Mới 1."
        ))
        stack.addArrangedSubview(makeStepRow(
            number: "3",
            title: "Tạo lịch hẹn giờ 15:00 Chiều",
            detail: "Làm tương tự thêm 1 mục Tự động hóa nữa vào lúc 15:00 chiều -> Chọn 'Chạy ngay lập tức' -> Chọn Phím tắt Làm Mới 2."
        ))
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    private func makeStepRow(number: String, title: String, detail: String) -> UIView
    {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        
        let badge = UILabel()
        badge.text = number
        badge.font = .systemFont(ofSize: 13, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        badge.layer.cornerRadius = 13
        badge.clipsToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14.5, weight: .bold)
        titleLabel.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
        titleLabel.numberOfLines = 0
        
        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .systemFont(ofSize: 13, weight: .regular)
        detailLabel.textColor = UIColor(red: 0.35, green: 0.39, blue: 0.45, alpha: 1.0)
        detailLabel.numberOfLines = 0
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(detailLabel)
        
        container.addSubview(badge)
        container.addSubview(textStack)
        
        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            badge.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            badge.widthAnchor.constraint(equalToConstant: 26),
            badge.heightAnchor.constraint(equalToConstant: 26),
            
            textStack.topAnchor.constraint(equalTo: container.topAnchor),
            textStack.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textStack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    // MARK: - 5. Video Tutorial Card
    private func makeVideoTutorialCard() -> UIView
    {
        let card = makeWhiteCardContainer()
        
        let vStack = UIStackView()
        vStack.axis = .vertical
        vStack.spacing = 12
        vStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vStack)
        
        let descLabel = UILabel()
        descLabel.text = "Xem video hướng dẫn trực quan từng bước cách thêm Phím tắt và thiết lập Tự động hóa làm mới 2 lần/ngày:"
        descLabel.font = .systemFont(ofSize: 13.5, weight: .regular)
        descLabel.textColor = UIColor(red: 0.25, green: 0.29, blue: 0.35, alpha: 1.0)
        descLabel.numberOfLines = 0
        
        let playButton = makeGradientActionButton(
            icon: "play.rectangle.fill",
            title: "Xem Video Hướng Dẫn Cài Đặt",
            subtitle: "Phát trực tiếp trình phát video HD",
            colors: [
                UIColor(red: 0.90, green: 0.22, blue: 0.35, alpha: 1.0),
                UIColor(red: 0.44, green: 0.26, blue: 0.76, alpha: 1.0)
            ],
            action: #selector(playTutorialVideo)
        )
        
        vStack.addArrangedSubview(descLabel)
        vStack.addArrangedSubview(playButton)
        
        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])
        
        return card
    }
    
    // MARK: - Reusable UI Helpers (Viền kính ngọc trai + Bóng đổ Indigo)
    private func makeWhiteCardContainer() -> UIView
    {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1.0
        card.layer.borderColor = UIColor.white.cgColor
        card.layer.shadowColor = UIColor(red: 0.15, green: 0.10, blue: 0.38, alpha: 1.0).cgColor
        card.layer.shadowOpacity = 0.065
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.layer.shadowRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        return card
    }
    
    private func makeDivider() -> UIView
    {
        let divider = UIView()
        divider.backgroundColor = UIColor(red: 0.92, green: 0.94, blue: 0.97, alpha: 1.0)
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }
    
    private func makeGradientActionButton(
        icon: String,
        title: String,
        subtitle: String,
        colors: [UIColor],
        action: Selector
    ) -> UIControl
    {
        let button = GradientControlButton(colors: colors)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.cornerRadius = 14
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = .white
        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        
        let textStack = UIStackView()
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 14.5, weight: .bold)
        titleLabel.textColor = .white
        
        let subLabel = UILabel()
        subLabel.text = subtitle
        subLabel.font = .systemFont(ofSize: 12, weight: .medium)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.88)
        
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subLabel)
        
        let arrow = UIImageView(image: UIImage(systemName: "arrow.up.right.circle.fill"))
        arrow.tintColor = UIColor.white.withAlphaComponent(0.92)
        arrow.contentMode = .scaleAspectFit
        arrow.isUserInteractionEnabled = false
        arrow.translatesAutoresizingMaskIntoConstraints = false
        
        button.addSubview(iconView)
        button.addSubview(textStack)
        button.addSubview(arrow)
        
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),
            
            textStack.topAnchor.constraint(equalTo: button.topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -12),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: arrow.leadingAnchor, constant: -8),
            
            arrow.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            arrow.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            arrow.widthAnchor.constraint(equalToConstant: 22),
            arrow.heightAnchor.constraint(equalToConstant: 22)
        ])
        
        return button
    }
    
    // MARK: - Live System Status Checker
    private func refreshSystemStatus()
    {
        // 1. Kiểm tra Pairing File
        let isPairingPresent = checkPairingFileAvailable()
        if isPairingPresent {
            pairingSubtitleLabel?.text = "Đã nạp hồ sơ ghép đôi hợp lệ • Chạm để xem"
            pairingBadgeLabel?.text = "ĐÃ KÍCH HOẠT"
            pairingBadgeLabel?.textColor = UIColor(red: 0.08, green: 0.56, blue: 0.24, alpha: 1.0)
            pairingBadgeContainer?.backgroundColor = UIColor(red: 0.88, green: 0.97, blue: 0.90, alpha: 1.0)
        } else {
            pairingSubtitleLabel?.text = "Chưa tìm thấy tệp ghép đôi • Chạm để cài đặt"
            pairingBadgeLabel?.text = "CẦN CÀI ĐẶT"
            pairingBadgeLabel?.textColor = UIColor(red: 0.85, green: 0.38, blue: 0.0, alpha: 1.0)
            pairingBadgeContainer?.backgroundColor = UIColor(red: 1.0, green: 0.94, blue: 0.86, alpha: 1.0)
        }
        
        // 2. Kiểm tra LocalDevVPN / Tunnel
        let isVPNActive = checkTunnelInterfaceActive()
        if isVPNActive {
            vpnSubtitleLabel?.text = "LocalDevVPN đang bật và sẵn sàng làm mới"
            vpnBadgeLabel?.text = "ĐANG BẬT"
            vpnBadgeLabel?.textColor = UIColor(red: 0.08, green: 0.56, blue: 0.24, alpha: 1.0)
            vpnBadgeContainer?.backgroundColor = UIColor(red: 0.88, green: 0.97, blue: 0.90, alpha: 1.0)
        } else {
            vpnSubtitleLabel?.text = "Chạm để kiểm tra kết nối LocalDevVPN"
            vpnBadgeLabel?.text = "KIỂM TRA"
            vpnBadgeLabel?.textColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            vpnBadgeContainer?.backgroundColor = UIColor(red: 0.90, green: 0.95, blue: 1.0, alpha: 1.0)
        }
    }
    
    private func checkPairingFileAvailable() -> Bool
    {
        let fm = FileManager.default
        if let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let items = try? fm.contentsOfDirectory(atPath: docs.path) {
                if items.contains(where: { $0.lowercased().contains("pairing") || $0.lowercased().hasSuffix(".mobiledevicepairing") || $0.lowercased().hasSuffix(".plist") }) {
                    return true
                }
            }
        }
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            if let items = try? fm.contentsOfDirectory(atPath: appSupport.path) {
                if !items.isEmpty {
                    return true
                }
            }
        }
        if DatabaseManager.shared.activeTeam() != nil {
            return true
        }
        return false
    }
    
    private func checkTunnelInterfaceActive() -> Bool
    {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }
        
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            if isUp && (name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")) {
                if let addr = current.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if ip.hasPrefix("10.7.") || ip.hasPrefix("fd00:") {
                            return true
                        }
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return false
    }
    
    // MARK: - Actions & Detail Sheets
    @objc private func handlePairingRowTap()
    {
        impactFeedback.impactOccurred()
        refreshSystemStatus()
        let isReady = checkPairingFileAvailable()
        
        let sheet = SystemStatusDetailSheetViewController(
            badgeText: isReady ? "ĐÃ KÍCH HOẠT HỒ SƠ" : "HƯỚNG DẪN GHÉP ĐÔI",
            title: "Hồ sơ ghép đôi (Pairing File)",
            subtitle: isReady
                ? "Thiết bị của bạn đã có hồ sơ ghép đôi hợp lệ. Dưới đây là 2 cách tạo hoặc cấp lại Pairing File khi cần:"
                : "Bạn có thể tạo tệp ghép đôi trực tiếp trên điện thoại (bản iOS 27) hoặc tạo bằng máy tính:",
            sections: [
                .init(
                    icon: "iphone.gen3.radiowaves.left.and.right",
                    title: "Cách 1: Ghép đôi trực tiếp trên iPhone (Bản iOS 27)",
                    body: "• Nếu bạn đang sử dụng gói cài đặt iOS 27 trực tiếp trên điện thoại, bạn không cần máy tính.\n• Hãy mở ứng dụng hỗ trợ ghép đôi đi kèm bộ iOS 27 (như StosVPN / trình tạo Pairing trực tiếp), bấm 'Tạo / Xuất tệp ghép đôi' rồi chia sẻ (Share) thẳng vào SideStore."
                ),
                .init(
                    icon: "laptopcomputer.and.iphone",
                    title: "Cách 2: Tạo tệp ghép đôi qua Máy tính (Windows / Mac)",
                    body: "• Kết nối iPhone với máy tính qua cáp, bấm 'Tin cậy' (Trust) trên màn hình điện thoại.\n• Mở công cụ idevice_pair (hoặc JitterbugPair) trên máy tính và nhấn Tạo file Pairing.\n• Gửi file .mobiledevicepairing vừa tạo qua Zalo / AirDrop / Tệp về iPhone rồi mở trong SideStore."
                ),
                .init(
                    icon: "arrow.triangle.2.circlepath.doc.on.clipboard",
                    title: "Cách thay đổi tệp ghép đôi mới",
                    body: "Khi bạn cập nhật iOS hoặc muốn nạp lại tệp mới, vào mục 'Cài đặt' của SideStore -> Chọn 'Đặt lại tệp ghép đôi' (Reset Pairing File) và chọn tệp mới."
                )
            ]
        )
        presentCustomSheet(sheet)
    }
    
    @objc private func handleVPNRowTap()
    {
        impactFeedback.impactOccurred()
        refreshSystemStatus()
        let isVPNActive = checkTunnelInterfaceActive()
        
        let sheet = SystemStatusDetailSheetViewController(
            badgeText: isVPNActive ? "LOCALDEVVPN ĐANG BẬT" : "CHƯA BẬT LOCALDEVVPN",
            title: "Kiểm tra kết nối LocalDevVPN",
            subtitle: isVPNActive
                ? "Tuyệt vời! Đường hầm LocalDevVPN đang hoạt động ổn định. Bạn có thể gia hạn và cài đặt ứng dụng ngay bây giờ."
                : "Hiện chưa phát hiện đường hầm LocalDevVPN đang bật. Hãy làm theo hướng dẫn dưới đây:",
            sections: [
                .init(
                    icon: "shield.lefthalf.filled.badge.checkmark",
                    title: "1. Bật ứng dụng LocalDevVPN / StosVPN",
                    body: "• Mở ứng dụng LocalDevVPN (hoặc StosVPN) trên màn hình chính iPhone của bạn.\n• Gạt công tắc sang trạng thái 'Connected' (Đã kết nối) trước khi bấm làm mới ứng dụng trong SideStore."
                ),
                .init(
                    icon: "bolt.horizontal.circle.fill",
                    title: "2. Tự động bật/tắt thông minh qua Phím tắt",
                    body: "• Khi bạn cài 2 Phím tắt Làm Mới ở màn hình Tổng quan, phím tắt sẽ tự động kích hoạt LocalDevVPN, làm mới toàn bộ ứng dụng rồi tự tắt khi hoàn tất."
                )
            ]
        )
        presentCustomSheet(sheet)
    }
    
    @objc private func handleCellularRowTap()
    {
        impactFeedback.impactOccurred()
        let sheet = SystemStatusDetailSheetViewController(
            badgeText: "HỖ TRỢ MẠNG DI ĐỘNG 4G / 5G",
            title: "Làm mới ứng dụng qua 4G",
            subtitle: "Không cần kết nối Wi-Fi, bạn vẫn có thể ký lại và gia hạn 7 ngày cho mọi ứng dụng ở bất cứ đâu:",
            sections: [
                .init(
                    icon: "antenna.radiowaves.left.and.right.circle.fill",
                    title: "1. Cơ chế hoạt động trên 4G / LTE",
                    body: "• Kết hợp cùng LocalDevVPN, SideStore tạo một đường hầm cục bộ ngay trên iPhone, giúp làm mới ứng dụng trực tiếp bằng dữ liệu di động 4G/5G."
                ),
                .init(
                    icon: "clock.badge.checkmark.fill",
                    title: "2. Kết hợp Tự động hóa 6:00 & 15:00",
                    body: "• Dù lúc 6:00 sáng hay 15:00 chiều bạn đang ở ngoài đường dùng mạng 4G, Phím tắt Tự động hóa vẫn chạy ngầm thành công và gia hạn đủ 7 ngày cho toàn bộ ứng dụng."
                )
            ]
        )
        presentCustomSheet(sheet)
    }
    
    private func presentCustomSheet(_ viewController: UIViewController)
    {
        if #available(iOS 15.0, *), let sheet = viewController.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        self.present(viewController, animated: true)
    }
    
    // MARK: - Open Shortcut Links & Video Player
    @objc private func openShortcut1()
    {
        impactFeedback.impactOccurred()
        guard let url = URL(string: "https://www.icloud.com/shortcuts/440b8935d5e14e55a4fb1bf6d78a6a12") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    @objc private func openShortcut2()
    {
        impactFeedback.impactOccurred()
        guard let url = URL(string: "https://www.icloud.com/shortcuts/7672dc8aa4a04fdba3decaccd32be24e") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    @objc private func playTutorialVideo()
    {
        impactFeedback.impactOccurred()
        guard let videoURL = URL(string: "https://raw.githubusercontent.com/dabeecao/video/main/huongdansidestore.mp4") else { return }
        let player = AVPlayer(url: videoURL)
        let playerVC = AVPlayerViewController()
        playerVC.player = player
        playerVC.modalPresentationStyle = .fullScreen
        self.present(playerVC, animated: true) {
            player.play()
        }
    }
}

// MARK: - Custom Gradient Views & Controls (Ánh sáng 3D + Nhấn đàn hồi)
private final class GradientBannerView: UIView
{
    private let gradientLayer = CAGradientLayer()
    private let topRightGlowOrb = CAShapeLayer()
    private let bottomLeftGlowOrb = CAShapeLayer()
    
    override init(frame: CGRect)
    {
        super.init(frame: frame)
        self.clipsToBounds = true
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        
        gradientLayer.colors = [
            UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0).cgColor,   // #007bff
            UIColor(red: 0.435, green: 0.259, blue: 0.757, alpha: 1.0).cgColor // #6f42c1
        ]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.layer.insertSublayer(gradientLayer, at: 0)
        
        // 2 Vòng sáng 3D trang trí tạo chiều sâu sang trọng
        topRightGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.11).cgColor
        bottomLeftGlowOrb.fillColor = UIColor.white.withAlphaComponent(0.08).cgColor
        self.layer.insertSublayer(topRightGlowOrb, above: gradientLayer)
        self.layer.insertSublayer(bottomLeftGlowOrb, above: gradientLayer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        gradientLayer.frame = self.bounds
        let b = self.bounds
        topRightGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: b.width - 75, y: -40, width: 135, height: 135)).cgPath
        bottomLeftGlowOrb.path = UIBezierPath(ovalIn: CGRect(x: -35, y: b.height - 50, width: 105, height: 105)).cgPath
    }
}

private final class SpringRowControl: UIControl
{
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.6, options: [.allowUserInteraction, .beginFromCurrentState], animations: {
                self.backgroundColor = self.isHighlighted ? UIColor(red: 0.94, green: 0.96, blue: 1.0, alpha: 0.7) : .clear
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.98, y: 0.98) : .identity
            }, completion: nil)
        }
    }
}

private final class GradientControlButton: UIControl
{
    private let gradientLayer = CAGradientLayer()
    
    init(colors: [UIColor])
    {
        super.init(frame: .zero)
        self.layer.borderWidth = 1.0
        self.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
        gradientLayer.colors = colors.map { $0.cgColor }
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.layer.insertSublayer(gradientLayer, at: 0)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews()
    {
        super.layoutSubviews()
        gradientLayer.frame = self.bounds
    }
    
    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.22, delay: 0, usingSpringWithDamping: 0.68, initialSpringVelocity: 0.6, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.alpha = self.isHighlighted ? 0.90 : 1.0
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
            }
        }
    }
}

// MARK: - Detail Sheet View Controller (Đồng bộ CSS Gradient & Card)
private final class SystemStatusDetailSheetViewController: UIViewController
{
    struct InfoSection {
        let icon: String
        let title: String
        let body: String
    }
    
    private let badgeText: String
    private let sheetTitle: String
    private let sheetSubtitle: String
    private let sections: [InfoSection]
    private let bgGradient = CAGradientLayer()
    
    init(badgeText: String, title: String, subtitle: String, sections: [InfoSection])
    {
        self.badgeText = badgeText
        self.sheetTitle = title
        self.sheetSubtitle = subtitle
        self.sections = sections
        super.init(nibName: nil, bundle: nil)
        self.overrideUserInterfaceStyle = .light
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        bgGradient.colors = [
            UIColor(red: 0.953, green: 0.878, blue: 1.0, alpha: 1.0).cgColor,
            UIColor(red: 0.878, green: 0.969, blue: 1.0, alpha: 1.0).cgColor
        ]
        bgGradient.startPoint = CGPoint(x: 0, y: 0)
        bgGradient.endPoint = CGPoint(x: 1, y: 1)
        bgGradient.frame = self.view.bounds
        self.view.layer.insertSublayer(bgGradient, at: 0)
        
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        self.view.addSubview(scrollView)
        
        let contentView = UIView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -28)
        ])
        
        // Header Banner
        let header = GradientBannerView()
        header.layer.cornerRadius = 18
        header.layer.cornerCurve = .continuous
        header.translatesAutoresizingMaskIntoConstraints = false
        
        let headerStack = UIStackView()
        headerStack.axis = .vertical
        headerStack.spacing = 6
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        
        let badgeLabel = UILabel()
        badgeLabel.text = badgeText
        badgeLabel.font = .systemFont(ofSize: 11, weight: .bold)
        badgeLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        
        let titleLabel = UILabel()
        titleLabel.text = sheetTitle
        titleLabel.font = .systemFont(ofSize: 19, weight: .bold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 0
        
        let subLabel = UILabel()
        subLabel.text = sheetSubtitle
        subLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        subLabel.numberOfLines = 0
        
        headerStack.addArrangedSubview(badgeLabel)
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(subLabel)
        header.addSubview(headerStack)
        
        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: header.topAnchor, constant: 16),
            headerStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            headerStack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16)
        ])
        
        stack.addArrangedSubview(header)
        
        for item in sections {
            let card = UIView()
            card.backgroundColor = UIColor.white.withAlphaComponent(0.95)
            card.layer.cornerRadius = 16
            card.layer.cornerCurve = .continuous
            card.layer.borderWidth = 1.0
            card.layer.borderColor = UIColor.white.cgColor
            card.layer.shadowColor = UIColor(red: 0.15, green: 0.10, blue: 0.38, alpha: 1.0).cgColor
            card.layer.shadowOpacity = 0.06
            card.layer.shadowOffset = CGSize(width: 0, height: 4)
            card.layer.shadowRadius = 10
            card.translatesAutoresizingMaskIntoConstraints = false
            
            let rowStack = UIStackView()
            rowStack.axis = .vertical
            rowStack.spacing = 6
            rowStack.translatesAutoresizingMaskIntoConstraints = false
            
            let topRow = UIStackView()
            topRow.axis = .horizontal
            topRow.spacing = 8
            topRow.alignment = .center
            
            let iconView = UIImageView(image: UIImage(systemName: item.icon))
            iconView.tintColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            iconView.contentMode = .scaleAspectFit
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.widthAnchor.constraint(equalToConstant: 20),
                iconView.heightAnchor.constraint(equalToConstant: 20)
            ])
            
            let itemTitle = UILabel()
            itemTitle.text = item.title
            itemTitle.font = .systemFont(ofSize: 15, weight: .bold)
            itemTitle.textColor = UIColor(red: 0.11, green: 0.13, blue: 0.20, alpha: 1.0)
            itemTitle.numberOfLines = 0
            
            topRow.addArrangedSubview(iconView)
            topRow.addArrangedSubview(itemTitle)
            
            let bodyLabel = UILabel()
            bodyLabel.text = item.body
            bodyLabel.font = .systemFont(ofSize: 13.5, weight: .regular)
            bodyLabel.textColor = UIColor(red: 0.30, green: 0.34, blue: 0.40, alpha: 1.0)
            bodyLabel.numberOfLines = 0
            
            rowStack.addArrangedSubview(topRow)
            rowStack.addArrangedSubview(bodyLabel)
            card.addSubview(rowStack)
            
            NSLayoutConstraint.activate([
                rowStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
                rowStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                rowStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
                rowStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
            ])
            
            stack.addArrangedSubview(card)
        }
        
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Đã hiểu", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .bold)
        closeButton.backgroundColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        closeButton.layer.cornerRadius = 14
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.heightAnchor.constraint(equalToConstant: 46).isActive = true
        closeButton.addTarget(self, action: #selector(dismissSheet), for: .touchUpInside)
        stack.addArrangedSubview(closeButton)
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        bgGradient.frame = self.view.bounds
    }
    
    @objc private func dismissSheet()
    {
        self.dismiss(animated: true)
    }
}
