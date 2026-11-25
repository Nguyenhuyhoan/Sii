
//  AltStore/TabBarController.swift
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
import Darwin
import Minimuxer
import SideSign

extension TabBarController
{
    // Khôi phục đủ 5 Tab: Thay thế vị trí tab Browse (index 2) bằng tab Kiểm Tra (diagnostic)
    private enum Tab: Int, CaseIterable
    {
        case news        // 0: Tổng quan
        case sources     // 1: Sửa lỗi
        case diagnostic  // 2: Kiểm tra (Chẩn đoán hệ thống)
        case myApps      // 3: Ứng dụng
        case settings    // 4: Cài đặt
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?
    
    private var _viewDidAppear = false
    
    private var sourcesViewController: SourcesViewController!
    
    required init?(coder aDecoder: NSCoder)
    {
        super.init(coder: aDecoder)
        
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.importApp(_:)), name: AppDelegate.importAppDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.presentSources(_:)), name: AppDelegate.addSourceDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(TabBarController.openErrorLog(_:)), name: ToastView.openErrorLogNotification, object: nil)
    }
    
    override func viewDidLoad() 
    {
        super.viewDidLoad()
        debugLog("[TabBarController] viewDidLoad()")
        
        // 0. CỐ ĐỊNH GIAO DIỆN SÁNG (Light Mode)
        // Thuộc tính này sẽ áp dụng cho cả TabBarController và toàn bộ các NavigationController con bên trong.
        self.overrideUserInterfaceStyle = .light
        
        // 1. Thay thế tab Browse cũ (nằm ở vị trí index 2 trên Storyboard gốc) bằng Tab "Kiểm tra" (Chẩn đoán hệ thống)
        if var viewControllers = self.viewControllers, viewControllers.count == 5 {
            let diagnosticVC = SystemDiagnosticViewController()
            let diagnosticNav = UINavigationController(rootViewController: diagnosticVC)
            diagnosticNav.overrideUserInterfaceStyle = .light
            diagnosticNav.tabBarItem = UITabBarItem(
                title: "Kiểm tra",
                image: UIImage(systemName: "waveform.path.ecg"),
                selectedImage: UIImage(systemName: "waveform.path.ecg")
            )
            viewControllers[Tab.diagnostic.rawValue] = diagnosticNav
            self.viewControllers = viewControllers
        }
        
        // 2. Đổi tab News thành "Tổng quan"
        if let newsNav = self.viewControllers?[Tab.news.rawValue] as? UINavigationController
        {
            newsNav.tabBarItem.title = "Tổng quan"
            newsNav.tabBarItem.image = UIImage(systemName: "checkmark.shield")
            newsNav.tabBarItem.selectedImage = UIImage(systemName: "checkmark.shield.fill")
        }
        
        // 3. Đổi tab Sources (Nguồn) thành "Sửa lỗi" và cập nhật icon
        if let sourcesNav = self.viewControllers?[Tab.sources.rawValue] as? UINavigationController
        {
            sourcesNav.tabBarItem.title = "Sửa lỗi"
            sourcesNav.tabBarItem.image = UIImage(systemName: "wrench.and.screwdriver")
            sourcesNav.tabBarItem.selectedImage = UIImage(systemName: "wrench.and.screwdriver.fill")
            
            self.sourcesViewController = sourcesNav.viewControllers.first as? SourcesViewController
        }
        
        // 4. Đổi tab My Apps thành "Ứng dụng"
        if let myAppsNav = self.viewControllers?[Tab.myApps.rawValue] as? UINavigationController
        {
            myAppsNav.tabBarItem.title = "Ứng dụng"
        }
        
        // 5. Đổi tab Settings thành "Cài đặt"
        if let settingsNav = self.viewControllers?[Tab.settings.rawValue] as? UINavigationController
        {
            settingsNav.tabBarItem.title = "Cài đặt"
        }
        
        // 6. Đặt tab My Apps ("Ứng dụng") làm tab active mặc định khi mở app
        self.selectedIndex = Tab.myApps.rawValue
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        
        // Đảm bảo toàn bộ cửa sổ ứng dụng (bao gồm cả các Alert, Toast, Popup...) cũng luôn ở giao diện sáng
        self.view.window?.overrideUserInterfaceStyle = .light
        
        _viewDidAppear = true
        
        if let (identifier, sender) = self.initialSegue
        {
            self.initialSegue = nil
            self.performSegue(withIdentifier: identifier, sender: sender)
        }
    }
    
    override func performSegue(withIdentifier identifier: String, sender: Any?)
    {
        guard _viewDidAppear else {
            self.initialSegue = (identifier, sender)
            return
        }
        
        super.performSegue(withIdentifier: identifier, sender: sender)
    }
}

extension TabBarController
{
    @objc func presentSources(_ sender: Any)
    {
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true) {
                self.presentSources(sender)
            }
            
            return
        }
                
        if let notification = (sender as? Notification), let sourceURL = notification.userInfo?[AppDelegate.addSourceDeepLinkURLKey] as? URL
        {
            self.sourcesViewController?.deepLinkSourceURL = sourceURL
        }
        
        self.selectedIndex = Tab.sources.rawValue
    }
}

private extension TabBarController
{
    @objc func importApp(_ notification: Notification)
    {
        self.selectedIndex = Tab.myApps.rawValue
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = Tab.settings.rawValue
    }
}

// ============================================================================
// MARK: - MÀN HÌNH CHẨN ĐOÁN HỆ THỐNG (TAB THỨ 5 - "KIỂM TRA")
// ============================================================================

@MainActor
private final class SystemDiagnosticViewController: UIViewController
{
    private enum CheckState
    {
        case idle
        case running(String)
        case success(String)
        case warning(String)
        case failure(String)
    }

    private struct StepCardViews
    {
        let container: UIView
        let iconView: UIImageView
        let spinner: UIActivityIndicatorView
        let titleLabel: UILabel
        let statusLabel: UILabel
    }

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let startButton = UIButton(type: .system)
    private let networkBadgeLabel = UILabel()

    private var stepCards: [StepCardViews] = []

    private let remediationContainer = UIView()
    private let remediationTextLabel = UILabel()

    private var isRunningDiagnostic = false

    private let stepTitles: [String] = [
        "1. Kết nối LocalDevVPN",
        "2. Đường truyền ngầm & File Pairing",
        "3. Máy chủ Anisette (Đăng nhập / Làm mới)",
        "4. Chứng chỉ gốc (Certificate)",
        "5. Đồng bộ Chứng chỉ các App đang cài"
    ]

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .light
        self.title = "Chẩn đoán Hệ thống"
        self.view.backgroundColor = UIColor.systemGroupedBackground

        setupUI()
        resetAllStepsToIdle()
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        updateNetworkBadge()
    }

    // MARK: - Giao diện (UI)

    private func setupUI()
    {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -28),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32)
        ])

        // 1. Header Card
        let headerCard = UIView()
        headerCard.backgroundColor = .secondarySystemGroupedBackground
        headerCard.layer.cornerRadius = 14
        headerCard.layer.cornerCurve = .continuous

        let shieldIcon = UIImageView(image: UIImage(systemName: "checkmark.shield.fill"))
        shieldIcon.tintColor = .systemBlue
        shieldIcon.contentMode = .scaleAspectFit
        shieldIcon.translatesAutoresizingMaskIntoConstraints = false

        let headerTitle = UILabel()
        headerTitle.text = "KHÁM BỆNH HỆ THỐNG TOÀN DIỆN"
        headerTitle.font = .systemFont(ofSize: 16, weight: .bold)
        headerTitle.textColor = .label

        let headerSubtitle = UILabel()
        headerSubtitle.text = "Kiểm tra VPN, đường truyền ngầm 127.0.0.1, File Pairing, Anisette và độ đồng bộ chứng chỉ của từng ứng dụng."
        headerSubtitle.font = .systemFont(ofSize: 13, weight: .regular)
        headerSubtitle.textColor = .secondaryLabel
        headerSubtitle.numberOfLines = 0

        networkBadgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        networkBadgeLabel.textColor = .systemBlue
        networkBadgeLabel.numberOfLines = 1

        let headerTextStack = UIStackView(arrangedSubviews: [headerTitle, headerSubtitle, networkBadgeLabel])
        headerTextStack.axis = .vertical
        headerTextStack.spacing = 4
        headerTextStack.translatesAutoresizingMaskIntoConstraints = false

        headerCard.addSubview(shieldIcon)
        headerCard.addSubview(headerTextStack)

        NSLayoutConstraint.activate([
            shieldIcon.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 16),
            shieldIcon.centerYAnchor.constraint(equalTo: headerCard.centerYAnchor),
            shieldIcon.widthAnchor.constraint(equalToConstant: 38),
            shieldIcon.heightAnchor.constraint(equalToConstant: 38),

            headerTextStack.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 14),
            headerTextStack.leadingAnchor.constraint(equalTo: shieldIcon.trailingAnchor, constant: 14),
            headerTextStack.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -16),
            headerTextStack.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -14)
        ])

        contentStack.addArrangedSubview(headerCard)

        // 2. Nút to "BẮT ĐẦU KIỂM TRA TỔNG QUÁT"
        startButton.setTitle("BẮT ĐẦU KIỂM TRA TỔNG QUÁT", for: .normal)
        startButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 14
        startButton.layer.cornerCurve = .continuous
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        startButton.addTarget(self, action: #selector(handleStartButtonTapped), for: .touchUpInside)

        contentStack.addArrangedSubview(startButton)

        // 3. Tiêu đề danh sách
        let sectionLabel = UILabel()
        sectionLabel.text = "📋 KẾT QUẢ CHI TIẾT 5 HẠNG MỤC:"
        sectionLabel.font = .systemFont(ofSize: 13, weight: .bold)
        sectionLabel.textColor = .secondaryLabel
        contentStack.addArrangedSubview(sectionLabel)

        // 4. Tạo 5 thẻ hạng mục kiểm tra
        for title in stepTitles
        {
            let card = makeStepCard(title: title)
            stepCards.append(card)
            contentStack.addArrangedSubview(card.container)
        }

        // 5. Khung Hướng dẫn khắc phục lỗi phát hiện
        remediationContainer.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.12)
        remediationContainer.layer.cornerRadius = 14
        remediationContainer.layer.cornerCurve = .continuous
        remediationContainer.layer.borderWidth = 1
        remediationContainer.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.35).cgColor
        remediationContainer.isHidden = true

        let remTitle = UILabel()
        remTitle.text = "💡 HƯỚNG DẪN KHẮC PHỤC LỖI PHÁT HIỆN:"
        remTitle.font = .systemFont(ofSize: 14, weight: .bold)
        remTitle.textColor = .systemOrange

        remediationTextLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        remediationTextLabel.textColor = .label
        remediationTextLabel.numberOfLines = 0

        let remStack = UIStackView(arrangedSubviews: [remTitle, remediationTextLabel])
        remStack.axis = .vertical
        remStack.spacing = 8
        remStack.translatesAutoresizingMaskIntoConstraints = false

        remediationContainer.addSubview(remStack)
        NSLayoutConstraint.activate([
            remStack.topAnchor.constraint(equalTo: remediationContainer.topAnchor, constant: 14),
            remStack.leadingAnchor.constraint(equalTo: remediationContainer.leadingAnchor, constant: 16),
            remStack.trailingAnchor.constraint(equalTo: remediationContainer.trailingAnchor, constant: -16),
            remStack.bottomAnchor.constraint(equalTo: remediationContainer.bottomAnchor, constant: -14)
        ])

        contentStack.addArrangedSubview(remediationContainer)
    }

    private func makeStepCard(title: String) -> StepCardViews
    {
        let container = UIView()
        container.backgroundColor = .secondarySystemGroupedBackground
        container.layer.cornerRadius = 12
        container.layer.cornerCurve = .continuous

        let iconView = UIImageView(image: UIImage(systemName: "circle.dashed"))
        iconView.tintColor = .systemGray3
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0

        let statusLabel = UILabel()
        statusLabel.text = "Chưa kiểm tra"
        statusLabel.font = .systemFont(ofSize: 13, weight: .regular)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        let textStack = UIStackView(arrangedSubviews: [titleLabel, statusLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(iconView)
        container.addSubview(spinner)
        container.addSubview(textStack)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            iconView.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            iconView.widthAnchor.constraint(equalToConstant: 24),
            iconView.heightAnchor.constraint(equalToConstant: 24),

            spinner.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            textStack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            textStack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        return StepCardViews(
            container: container,
            iconView: iconView,
            spinner: spinner,
            titleLabel: titleLabel,
            statusLabel: statusLabel
        )
    }

    private func updateNetworkBadge()
    {
        let hasWifi = minimuxer.network.isWifiSatisfied
        if hasWifi {
            networkBadgeLabel.text = "🛜 Mạng hiện tại: Wi-Fi (Kiểm tra trực tiếp không cần tắt 4G)"
            networkBadgeLabel.textColor = .systemGreen
        } else {
            networkBadgeLabel.text = "📡 Mạng hiện tại: Di động 4G/5G (Sẽ tự động Tắt/Bật 4G ở Bước 2)"
            networkBadgeLabel.textColor = .systemBlue
        }
    }

    private func updateStep(_ index: Int, state: CheckState)
    {
        guard index >= 0 && index < stepCards.count else { return }
        let card = stepCards[index]

        switch state
        {
        case .idle:
            card.spinner.stopAnimating()
            card.iconView.isHidden = false
            card.iconView.image = UIImage(systemName: "circle.dashed")
            card.iconView.tintColor = .systemGray3
            card.statusLabel.text = "Chờ kiểm tra..."
            card.statusLabel.textColor = .secondaryLabel

        case .running(let msg):
            card.iconView.isHidden = true
            card.spinner.startAnimating()
            card.statusLabel.text = msg
            card.statusLabel.textColor = .systemBlue

        case .success(let msg):
            card.spinner.stopAnimating()
            card.iconView.isHidden = false
            card.iconView.image = UIImage(systemName: "checkmark.circle.fill")
            card.iconView.tintColor = .systemGreen
            card.statusLabel.text = msg
            card.statusLabel.textColor = UIColor(red: 0.1, green: 0.55, blue: 0.2, alpha: 1.0)

        case .warning(let msg):
            card.spinner.stopAnimating()
            card.iconView.isHidden = false
            card.iconView.image = UIImage(systemName: "exclamationmark.triangle.fill")
            card.iconView.tintColor = .systemOrange
            card.statusLabel.text = msg
            card.statusLabel.textColor = .systemOrange

        case .failure(let msg):
            card.spinner.stopAnimating()
            card.iconView.isHidden = false
            card.iconView.image = UIImage(systemName: "xmark.circle.fill")
            card.iconView.tintColor = .systemRed
            card.statusLabel.text = msg
            card.statusLabel.textColor = .systemRed
        }
    }

    private func resetAllStepsToIdle()
    {
        for i in 0..<stepCards.count
        {
            updateStep(i, state: .idle)
        }
        remediationContainer.isHidden = true
        remediationTextLabel.text = nil
    }

    private func showRemediation(_ tips: [String])
    {
        guard !tips.isEmpty else {
            remediationContainer.isHidden = true
            return
        }
        remediationTextLabel.text = tips.map { "• \($0)" }.joined(separator: "\n\n")
        remediationContainer.isHidden = false
    }

    // MARK: - Xử lý sự kiện bấm nút Kiểm Tra

    @objc private func handleStartButtonTapped()
    {
        guard !isRunningDiagnostic else { return }
        isRunningDiagnostic = true
        startButton.isEnabled = false
        startButton.alpha = 0.6
        startButton.setTitle("⏳ ĐANG KHÁM BỆNH HỆ THỐNG...", for: .normal)

        resetAllStepsToIdle()
        updateNetworkBadge()

        Task { @MainActor in
            await runFullDiagnosticFlow()
            self.isRunningDiagnostic = false
            self.startButton.isEnabled = true
            self.startButton.alpha = 1.0
            self.startButton.setTitle("BẮT ĐẦU KIỂM TRA TỔNG QUÁT", for: .normal)
            self.updateNetworkBadge()
        }
    }

    // ========================================================================
    // MARK: - QUY TRÌNH 6 BƯỚC "KHÁM BỆNH THỰC CHIẾN"
    // ========================================================================

    private func runFullDiagnosticFlow() async
    {
        var remediationTips: [String] = []
        var didToggleOffCellularInStep2 = false

        // Đảm bảo luôn khôi phục 4G nếu quá trình bị dừng giữa chừng
        defer {
            if didToggleOffCellularInStep2 {
                Task {
                    _ = await CellularRefreshManager.shared.turnOnDataIfNeeded()
                }
            }
        }

        // --------------------------------------------------------------------
        // 🛑 BƯỚC 1: KIỂM TRA LOCALDEVVPN TRƯỚC TIÊN (BẮT BUỘC)
        // --------------------------------------------------------------------
        updateStep(0, state: .running("Đang quét giao diện mạng tun/utun của LocalDevVPN..."))
        try? await Task.sleep(nanoseconds: 250_000_000)

        let vpnActive = await checkLocalDevVPNActive()
        guard vpnActive else {
            updateStep(0, state: .failure("❌ Chưa bật LocalDevVPN! Đã dừng kiểm tra."))
            remediationTips.append("Chưa bật LocalDevVPN: Bạn hãy mở ứng dụng LocalDevVPN (hoặc StosVPN) lên và gạt nút Bật kết nối VPN, sau đó quay lại đây bấm Kiểm tra lại nhé!")
            showRemediation(remediationTips)
            return
        }

        let isWifi = minimuxer.network.isWifiSatisfied
        updateStep(0, state: .success(isWifi ? "✅ Đã bật LocalDevVPN (Đang dùng Wi-Fi)" : "✅ Đã bật LocalDevVPN (Đang dùng 4G)"))

        // --------------------------------------------------------------------
        // 📱 BƯỚC 2: KIỂM TRA FILE PAIRING & ĐƯỜNG TRUYỀN NGẦM iOS (127.0.0.1)
        // --------------------------------------------------------------------
        updateStep(1, state: .running("Tầng 1: Đang kiểm tra cấu trúc File Pairing..."))
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Tầng 1: Kiểm tra File Pairing tồn tại và đúng chuẩn XML/Plist
        guard let pairingString = PairingFileManager.shared.fetchPairingFile(),
              let pairingData = pairingString.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: pairingData, options: [], format: nil) as? [String: Any],
              !plist.isEmpty else
        {
            updateStep(1, state: .failure("❌ Thiếu File Pairing hoặc cấu trúc file bị hỏng (Cần cắm máy tính tạo lại)!"))
            remediationTips.append("Thiếu File Pairing: Hãy cắm iPhone/iPad vào máy tính, dùng idevicepair (hoặc جitterbugpair) để tạo lại file ghép nối rồi nạp lại vào ứng dụng.")
            showRemediation(remediationTips)
            return
        }

        // Tầng 2: Nếu KHÔNG CÓ WI-FI -> Phải tự động gọi Phím tắt TẮT 4G để giải phóng 127.0.0.1
        if !minimuxer.network.isWifiSatisfied
        {
            updateStep(1, state: .running("Không có Wi-Fi: Đang gọi Phím tắt TẮT 4G để kiểm tra đường truyền 127.0.0.1..."))
            didToggleOffCellularInStep2 = await CellularRefreshManager.shared.turnOffDataIfNeeded()
        }

        updateStep(1, state: .running("Tầng 2: Đang ping đường truyền ngầm lockdownd (Minimuxer)..."))

        let lockdownOK = await testMinimuxerLiveLockdownConnection()
        if lockdownOK
        {
            updateStep(1, state: .success("✅ Ghép nối & Đường truyền ngầm: Hoạt động hoàn hảo!"))
        }
        else
        {
            let errMsg = "❌ Lỗi File Pairing hoặc Thiết bị đã ghép nối trên iPhone có vấn đề hoặc Kẹt đường truyền ngầm của iOS!"
            updateStep(1, state: .failure(errMsg))
            remediationTips.append("Kẹt đường truyền ngầm / Lỗi ghép nối: Hãy Khởi động lại (Restart) iPhone/iPad rồi thử lại. Nếu vẫn báo lỗi này, hãy cắm máy tính để thiết lập lại Thiết bị đã ghép nối (Trust) và tạo lại Pairing File mới!")
        }

        // 🔄 Tự động BẬT LẠI 4G ngay sau khi kiểm tra xong Bước 2 (nếu trước đó đã tắt 4G)
        // để Bước 3 có mạng Internet kiểm tra Máy chủ Anisette và tránh hao pin!
        if didToggleOffCellularInStep2
        {
            updateStep(2, state: .running("Đang gọi Phím tắt BẬT LẠI 4G để kiểm tra Máy chủ Anisette..."))
            _ = await CellularRefreshManager.shared.turnOnDataIfNeeded(addOnDelay: 1.5)
            didToggleOffCellularInStep2 = false
            // Chờ sóng 4G lên mạng ổn định (tối đa 4 giây)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        // --------------------------------------------------------------------
        // 🌐 BƯỚC 3: KIỂM TRA MÁY CHỦ ANISETTE (TEST DỮ LIỆU REFRESH THỰC TẾ)
        // --------------------------------------------------------------------
        updateStep(2, state: .running("Đang kiểm tra gói dữ liệu bảo mật từ Máy chủ Anisette..."))
        let anisetteResult = await checkAnisetteServerHealth()
        switch anisetteResult
        {
        case .success(let info):
            updateStep(2, state: .success(info))
        case .warning(let warn):
            updateStep(2, state: .warning(warn))
            remediationTips.append("Cảnh báo Anisette: \(warn)")
        case .failure(let err):
            updateStep(2, state: .failure(err))
            remediationTips.append("Lỗi Máy chủ Anisette: Máy chủ hiện tại không trả về đủ mã bảo mật (X-Apple-I-MD / machineID) để Làm mới App. Vui lòng vào tab Cài đặt -> Anisette Server để đổi sang máy chủ khác!")
        default:
            break
        }

        // --------------------------------------------------------------------
        // 🔐 BƯỚC 4: KIỂM TRA CHỨNG CHỈ GỐC (CERTIFICATE)
        // --------------------------------------------------------------------
        updateStep(3, state: .running("Đang kiểm tra Chứng chỉ phát triển và Tài khoản Apple ID..."))
        try? await Task.sleep(nanoseconds: 150_000_000)

        let certCheck = checkActiveRootCertificate()
        guard let rootSerial = certCheck.serialNumber else
        {
            updateStep(3, state: .failure(certCheck.message))
            remediationTips.append("Lỗi Chứng chỉ gốc: Chưa có chứng chỉ hợp lệ hoặc bạn chưa đăng nhập Apple ID. Hãy vào tab Cài đặt -> Tài khoản để đăng nhập lại và làm mới ứng dụng.")
            updateStep(4, state: .warning("⚠️ Không thể đối chiếu do chưa có Chứng chỉ gốc ở Bước 4."))
            showRemediation(remediationTips)
            return
        }

        updateStep(3, state: .success(certCheck.message))

        // --------------------------------------------------------------------
        // 📦 BƯỚC 5: KIỂM TRA ĐỒNG BỘ CHỨNG CHỈ CỦA TỪNG APP ĐANG CÀI
        // --------------------------------------------------------------------
        updateStep(4, state: .running("Đang quét và đối chiếu chứng chỉ của toàn bộ ứng dụng đã cài..."))
        try? await Task.sleep(nanoseconds: 150_000_000)

        let appSync = checkInstalledAppsCertificateSync(activeRootSerial: rootSerial)
        stepCards[4].titleLabel.text = "5. App đang cài (\(appSync.totalCount) ứng dụng)"

        if appSync.mismatchedAppNames.isEmpty
        {
            updateStep(4, state: .success("✅ Đồng bộ ứng dụng: Tất cả \(appSync.totalCount) app đều dùng đúng chứng chỉ hiện tại."))
        }
        else
        {
            let listText = appSync.mismatchedAppNames.joined(separator: ", ")
            updateStep(4, state: .warning("⚠️ Phát hiện lệch chứng chỉ ở ứng dụng: [\(listText)]"))
            remediationTips.append("Ứng dụng [\(listText)] đang dùng chứng chỉ cũ (khác với chứng chỉ gốc hiện tại): Bạn hãy chuyển qua tab Ứng dụng (My Apps), nhấn giữ lâu vào ứng dụng [\(listText)] và chọn Ký lại / Làm mới để nạp lại chứng chỉ mới nhé!")
        }

        showRemediation(remediationTips)
    }

    // ========================================================================
    // MARK: - CÁC HÀM KIỂM TRA KỸ THUẬT CHI TIẾT
    // ========================================================================

    /// Bước 1: Quét giao diện mạng tun/utun xem LocalDevVPN đã bật và cấp IP chưa
    private func checkLocalDevVPNActive() async -> Bool
    {
        #if targetEnvironment(simulator)
        return true
        #else
        // Kiểm tra trực tiếp IP tunnel từ ConnectionConfig hoặc bảng giao diện mạng ifaddrs
        let tunnelIp = ConnectionConfig.shared.tunnelIfaceIp
        if !tunnelIp.isEmpty && tunnelIp != "0.0.0.0" {
            if Self.hasActiveLocalDevVPNUtunInterface() {
                return true
            }
        }
        if Self.hasActiveLocalDevVPNUtunInterface() {
            return true
        }
        // Fallback kiểm tra qua Minimuxer
        let readyResult = await minimuxer.core.isReady(withNetworkCheck: true)
        if case .success(true) = readyResult {
            return true
        }
        if case .failure(let err) = readyResult {
            if case .noVPN = err { return false }
            if case .invalidVPN = err { return false }
        }
        return false
        #endif
    }

    private nonisolated static func hasActiveLocalDevVPNUtunInterface() -> Bool
    {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr
        {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            let isPointToPoint = (flags & IFF_POINTOPOINT) != 0

            if isUp && isPointToPoint,
               let namePtr = current.pointee.ifa_name,
               let addr = current.pointee.ifa_addr
            {
                let name = String(cString: namePtr)
                if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ppp")
                {
                    let family = Int32(addr.pointee.sa_family)
                    if family == AF_INET
                    {
                        let sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var addrCopy = sin.sin_addr
                        inet_ntop(AF_INET, &addrCopy, &buffer, socklen_t(INET_ADDRSTRLEN))
                        let ipString = String(cString: buffer)
                        // LocalDevVPN / StosVPN / SideStore loopback VPN dùng dải 10.7.0.x
                        if ipString.hasPrefix("10.7.") {
                            return true
                        }
                    }
                    else if family == AF_INET6
                    {
                        let sin6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                        let bytes = withUnsafeBytes(of: sin6.sin6_addr) { Array($0) }
                        // fd00:: / fe80:: trên cổng utun khi bật IPv6 tunnel
                        if bytes.count >= 2 && (bytes[0] == 0xfd || bytes[0] == 0xfc) {
                            return true
                        }
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return false
    }

    /// Bước 2: Mở phiên kết nối thực tế tới lockdownd thông qua Minimuxer (Timeout 7s tránh treo)
    private func testMinimuxerLiveLockdownConnection() async -> Bool
    {
        #if targetEnvironment(simulator)
        return true
        #else
        // Thử lấy trực tiếp UDID live trước
        await minimuxer.network.refreshEndpoint()
        if let udid = try? await fetchUDID(forceLive: true), !udid.isEmpty {
            return true
        }
        // Nếu chưa thông, khởi động lại phiên Minimuxer với File Pairing hiện tại và chờ tối đa 6.5 giây
        return await CellularRefreshManager.shared.resetAndPrepareMinimuxer(timeout: 6.5)
        #endif
    }

    /// Bước 3: Kiểm tra Máy chủ Anisette xem gói JSON trả về có đầy đủ các trường bảo mật để Refresh/Login không
    private func checkAnisetteServerHealth() async -> CheckState
    {
        let defaults = UserDefaults.standard
        let candidateURLString: String = {
            if defaults.textServer,
               let custom = defaults.textInputAnisetteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !custom.isEmpty {
                return custom
            }
            if let customURL = defaults.customAnisetteURL?.trimmingCharacters(in: .whitespacesAndNewlines),
               !customURL.isEmpty {
                return customURL
            }
            let menuURL = defaults.menuAnisetteURL.trimmingCharacters(in: .whitespacesAndNewlines)
            return menuURL.isEmpty ? AppConstants.Anisette.Servers.defaultServerURL : menuURL
        }()

        guard let url = URL(string: candidateURLString) else {
            return .failure("❌ Địa chỉ Máy chủ Anisette không hợp lệ: \(candidateURLString)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        let startTime = Date()
        do
        {
            let (data, response) = try await URLSession.shared.data(for: request)
            let elapsedMs = Int(Date().timeIntervalSince(startTime) * 1000)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                let code = (response as? HTTPURLResponse)?.statusCode ?? -1
                return .failure("❌ Máy chủ Anisette phản hồi lỗi HTTP \(code) (\(url.host ?? candidateURLString)). Vui lòng đổi máy chủ khác!")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return .failure("❌ Máy chủ Anisette đang lỗi dữ liệu (Không trả về định dạng JSON hợp lệ).")
            }

            // Kiểm tra các khóa bảo mật sống còn của Apple để Đăng nhập & Làm mới App
            let md = (json["X-Apple-I-MD"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let mdm = (json["X-Apple-I-MD-M"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let machineID = (json["machineID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // Hỗ trợ cả Anisette v1/v2 (có machineID + X-Apple-I-MD + X-Apple-I-MD-M) và v3 (có X-Apple-I-MD + X-Apple-I-MD-M)
            guard !md.isEmpty && !mdm.isEmpty else {
                return .failure("❌ Máy chủ Anisette đang lỗi dữ liệu (Dù máy chủ vẫn mở nhưng thiếu mã X-Apple-I-MD / X-Apple-I-MD-M, không thể dùng để Refresh). Vui lòng vào Cài đặt -> Anisette Server đổi máy chủ khác!")
            }

            let hostName = url.host ?? candidateURLString
            let modeNote = defaults.useOnDeviceAnisette ? " [Đang bật Anisette Nội bộ + Server \(hostName)]" : " [\(hostName)]"
            let extraCheck = !machineID.isEmpty ? "Đủ MD/MD-M/machineID" : "Đủ MD/MD-M"
            return .success("✅ Rất tốt (\(extraCheck) - \(elapsedMs)ms)\(modeNote)")
        }
        catch
        {
            if defaults.useOnDeviceAnisette {
                return .warning("⚠️ Không kết nối được máy chủ phụ (\(url.host ?? "Anisette")), nhưng máy đang bật chế độ Anisette Nội bộ (On-Device).")
            }
            return .failure("❌ Không thể kết nối tới Máy chủ Anisette (\(url.host ?? candidateURLString)). Vui lòng kiểm tra mạng hoặc đổi máy chủ khác!")
        }
    }

    /// Bước 4: Kiểm tra Chứng chỉ gốc đang lưu trong Keychain / DatabaseManager
    private func checkActiveRootCertificate() -> (serialNumber: String?, message: String)
    {
        let context = DatabaseManager.shared.viewContext
        var teamInfo = ""
        var activeCertSerial: String?
        var activeCertName: String?

        context.performAndWait {
            if let team = DatabaseManager.shared.activeTeam(in: context) {
                teamInfo = "Team: \(team.name) (\(team.identifier))"
                if let cert = team.activeCertificate {
                    activeCertSerial = cert.serialNumber
                    activeCertName = cert.name
                }
            }
        }

        // Ưu tiên lấy serial từ CertificateManager.shared.activeCertificate hoặc từ chính gói bundle của SideStore
        if let keychainCert = CertificateManager.shared.activeCertificate {
            activeCertSerial = keychainCert.serialNumber
            if activeCertName == nil {
                activeCertName = keychainCert.name
            }
        } else if activeCertSerial == nil,
                  let bundleCert = CertificateManager.shared.getSigningCertificate(at: Bundle.Info.activeBundleURL) {
            activeCertSerial = bundleCert.serialNumber
            activeCertName = bundleCert.name
        }

        guard let serial = activeCertSerial?.trimmingCharacters(in: .whitespacesAndNewlines),
              !serial.isEmpty else {
            return (nil, "❌ Chứng chỉ lỗi hoặc chưa đăng nhập tài khoản Apple ID!")
        }

        let shortSerial = serial.count > 10 ? "\(serial.prefix(10))..." : serial
        let detail = [teamInfo, "Serial: \(shortSerial)"].filter { !$0.isEmpty }.joined(separator: " • ")
        return (serial, "✅ Hợp lệ (\(detail))")
    }

    /// Bước 5: Quét toàn bộ InstalledApp trong DatabaseManager và đối chiếu chứng chỉ với Chứng chỉ gốc ở Bước 4
    private func checkInstalledAppsCertificateSync(activeRootSerial: String) -> (totalCount: Int, mismatchedAppNames: [String])
    {
        let context = DatabaseManager.shared.viewContext
        var total = 0
        var mismatched: [String] = []

        let normalizedRoot = activeRootSerial.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        context.performAndWait {
            let allApps = InstalledApp.all(in: context)
            total = allApps.count

            for app in allApps
            {
                let appSerial = app.certificateSerialNumber?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                var isMismatch = false

                if appSerial.isEmpty || appSerial != normalizedRoot {
                    isMismatch = true
                }

                if case .valid(let isCrossSigned) = app.certificateStatus, isCrossSigned {
                    isMismatch = true
                } else if app.certificateStatus != .valid(isCrossSigned: false) {
                    isMismatch = true
                }

                if isMismatch {
                    mismatched.append(app.name)
                }
            }
        }

        mismatched.sort()
        return (total, mismatched)
    }
}
