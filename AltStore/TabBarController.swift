

//  AltStore/TabBarController.swift
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

// MARK: - 🎨 BỘ GIAO DIỆN LIQUID GLASS (KÍNH LỎNG APPLE) & CHỮ ĐEN TUYỀN
private enum TabBarCSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                      // #000000 (Chữ & icon chưa chọn đen tuyền rõ nét)
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff (Màu tab đang chọn)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1
    static let cyanGlow = UIColor(red: 0/255, green: 198/255, blue: 255/255, alpha: 1.0)      // Ánh sáng khúc xạ kính lỏng
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)           // #dc3545 (Màu badge thông báo)
}

// MARK: - 💧 KHUNG NỀN DOCK KÍNH LỎNG 3D (LIQUID GLASS CAPSULE DOCK)
private final class LiquidGlassDockView: UIView {
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
    private let pearlTintLayer = CAGradientLayer()
    private let topSpecularSheen = CAGradientLayer()
    private let refractiveRimGradient = CAGradientLayer()
    private let refractiveRimMask = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLiquidGlass()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLiquidGlass()
    }

    private func setupLiquidGlass() {
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear

        // Đổ bóng khúc xạ ánh sáng xanh - tím mềm mại dưới đáy viên kính lỏng
        self.layer.shadowColor = TabBarCSSTheme.blue.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 8)
        self.layer.shadowRadius = 20
        self.layer.shadowOpacity = 0.16
        self.layer.masksToBounds = false

        // 1. Lớp kính mờ quang học bên trong
        blurView.frame = self.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.clipsToBounds = true
        if #available(iOS 13.0, *) {
            blurView.layer.cornerCurve = .continuous
        }
        self.addSubview(blurView)

        // 2. Lớp phủ trắng ngọc trai pha ánh xanh tím cực nhẹ giữ độ trong trẻo
        pearlTintLayer.colors = [
            UIColor.white.withAlphaComponent(0.78).cgColor,
            UIColor(red: 242/255, green: 247/255, blue: 255/255, alpha: 0.68).cgColor,
            UIColor(red: 246/255, green: 240/255, blue: 255/255, alpha: 0.72).cgColor
        ]
        pearlTintLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        pearlTintLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        blurView.contentView.layer.addSublayer(pearlTintLayer)

        // 3. Lớp phản chiếu ánh sáng vòm kính phía trên (Top Glossy Liquid Sheen)
        topSpecularSheen.colors = [
            UIColor.white.withAlphaComponent(0.88).cgColor,
            UIColor.white.withAlphaComponent(0.25).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        topSpecularSheen.locations = [0.0, 0.45, 1.0]
        topSpecularSheen.startPoint = CGPoint(x: 0.5, y: 0.0)
        topSpecularSheen.endPoint = CGPoint(x: 0.5, y: 1.0)
        blurView.contentView.layer.addSublayer(topSpecularSheen)

        // 4. Viền bo khúc xạ 3D quanh viên kính (Sáng rực ở góc đón nắng, dịu ở góc khuất)
        refractiveRimGradient.colors = [
            UIColor.white.withAlphaComponent(0.98).cgColor,
            TabBarCSSTheme.cyanGlow.withAlphaComponent(0.45).cgColor,
            TabBarCSSTheme.purple.withAlphaComponent(0.30).cgColor,
            UIColor.white.withAlphaComponent(0.85).cgColor
        ]
        refractiveRimGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        refractiveRimGradient.endPoint = CGPoint(x: 1.0, y: 1.0)

        refractiveRimMask.fillColor = UIColor.clear.cgColor
        refractiveRimMask.strokeColor = UIColor.white.cgColor
        refractiveRimMask.lineWidth = 1.4
        refractiveRimGradient.mask = refractiveRimMask
        blurView.contentView.layer.addSublayer(refractiveRimGradient)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let cornerRadius = min(26.0, bounds.height / 2.0)
        blurView.layer.cornerRadius = cornerRadius
        self.layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius).cgPath

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        pearlTintLayer.frame = bounds
        topSpecularSheen.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * 0.56)
        refractiveRimGradient.frame = bounds
        refractiveRimMask.frame = bounds
        refractiveRimMask.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 0.7, dy: 0.7),
            cornerRadius: cornerRadius - 0.7
        ).cgPath
        CATransaction.commit()
    }
}

// MARK: - 🫧 VIÊN GIỌT NƯỚC KÍNH LỎNG TRƯỢT THEO TAB ĐANG CHỌN (ACTIVE LIQUID PILL)
private final class LiquidGlassActivePillView: UIView {
    private let bgGradient = CAGradientLayer()
    private let topGlossLayer = CAGradientLayer()
    private let rimLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupPill()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupPill()
    }

    private func setupPill() {
        self.isUserInteractionEnabled = false
        self.backgroundColor = .clear

        // Ánh phát sáng xanh dịu dưới tab đang chọn
        self.layer.shadowColor = TabBarCSSTheme.blue.cgColor
        self.layer.shadowOffset = CGSize(width: 0, height: 4)
        self.layer.shadowRadius = 10
        self.layer.shadowOpacity = 0.20

        // Nền giọt nước ánh xanh - tím trong suốt
        bgGradient.colors = [
            TabBarCSSTheme.blue.withAlphaComponent(0.16).cgColor,
            TabBarCSSTheme.cyanGlow.withAlphaComponent(0.12).cgColor,
            TabBarCSSTheme.purple.withAlphaComponent(0.14).cgColor
        ]
        bgGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        bgGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        if #available(iOS 13.0, *) {
            bgGradient.cornerCurve = .continuous
        }
        self.layer.addSublayer(bgGradient)

        // Ánh phản quang mặt trên của giọt nước
        topGlossLayer.colors = [
            UIColor.white.withAlphaComponent(0.90).cgColor,
            UIColor.white.withAlphaComponent(0.10).cgColor
        ]
        topGlossLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        topGlossLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        if #available(iOS 13.0, *) {
            topGlossLayer.cornerCurve = .continuous
        }
        self.layer.addSublayer(topGlossLayer)

        // Viền sáng trắng bảo vệ giọt nước
        rimLayer.fillColor = UIColor.clear.cgColor
        rimLayer.strokeColor = UIColor.white.withAlphaComponent(0.95).cgColor
        rimLayer.lineWidth = 1.2
        self.layer.addSublayer(rimLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0 else { return }

        let radius = bounds.height / 2.0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bgGradient.frame = bounds
        bgGradient.cornerRadius = radius

        let glossBounds = CGRect(x: 2, y: 1.5, width: max(0, bounds.width - 4), height: bounds.height * 0.48)
        topGlossLayer.frame = glossBounds
        topGlossLayer.cornerRadius = glossBounds.height / 2.0

        rimLayer.frame = bounds
        rimLayer.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 0.6, dy: 0.6), cornerRadius: radius - 0.6).cgPath
        CATransaction.commit()
    }
}

extension TabBarController
{
    // Đã xóa case browse để index của myApps (2) và settings (3) khớp với mảng viewControllers sau khi xóa
    private enum Tab: Int, CaseIterable
    {
        case news      // 0: Tổng quan
        case sources   // 1: Sửa lỗi
        case myApps    // 2: Ứng dụng
        case settings  // 3: Cài đặt
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?
    
    private var _viewDidAppear = false
    
    private var sourcesViewController: SourcesViewController!
    
    // Các lớp giao diện Kính lỏng (Liquid Glass)
    private let liquidGlassDockView = LiquidGlassDockView()
    private let activeLiquidPillView = LiquidGlassActivePillView()
    
    override var selectedIndex: Int {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateLiquidGlassPillPosition(animated: false)
            }
        }
    }
    
    override var selectedViewController: UIViewController? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                self?.updateLiquidGlassPillPosition(animated: false)
            }
        }
    }
    
    #if !os(tvOS)
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    #endif
    
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
        
        // Khóa cứng giao diện Light Mode đồng bộ toàn ứng dụng
        self.overrideUserInterfaceStyle = .light
        self.view.overrideUserInterfaceStyle = .light
        self.tabBar.overrideUserInterfaceStyle = .light
        
        // 1. Xóa tab Browse (nằm ở vị trí index 2 trên Storyboard gốc)
        if var viewControllers = self.viewControllers, viewControllers.count == 5 {
            viewControllers.remove(at: 2)
            self.viewControllers = viewControllers
        }
        
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 17.5, weight: .semibold)
        let selectedSymbolConfig = UIImage.SymbolConfiguration(pointSize: 18.5, weight: .bold)
        
        // 2. Đổi tab News thành "Tổng quan"
        if let newsNav = self.viewControllers?[Tab.news.rawValue] as? UINavigationController
        {
            newsNav.overrideUserInterfaceStyle = .light
            newsNav.tabBarItem.title = "Tổng quan"
            newsNav.tabBarItem.image = UIImage(systemName: "checkmark.shield", withConfiguration: symbolConfig)
            newsNav.tabBarItem.selectedImage = UIImage(systemName: "checkmark.shield.fill", withConfiguration: selectedSymbolConfig)
        }
        
        // 3. Đổi tab Sources (Nguồn) thành "Sửa lỗi" và cập nhật icon
        if let sourcesNav = self.viewControllers?[Tab.sources.rawValue] as? UINavigationController
        {
            sourcesNav.overrideUserInterfaceStyle = .light
            sourcesNav.tabBarItem.title = "Sửa lỗi"
            sourcesNav.tabBarItem.image = UIImage(systemName: "wrench.and.screwdriver", withConfiguration: symbolConfig)
            sourcesNav.tabBarItem.selectedImage = UIImage(systemName: "wrench.and.screwdriver.fill", withConfiguration: selectedSymbolConfig)
            
            self.sourcesViewController = sourcesNav.viewControllers.first as? SourcesViewController
        }
        
        // 4. Đổi tab My Apps thành "Ứng dụng"
        if let myAppsNav = self.viewControllers?[Tab.myApps.rawValue] as? UINavigationController
        {
            myAppsNav.overrideUserInterfaceStyle = .light
            myAppsNav.tabBarItem.title = "Ứng dụng"
            if myAppsNav.tabBarItem.image == nil {
                myAppsNav.tabBarItem.image = UIImage(systemName: "square.stack.3d.up", withConfiguration: symbolConfig)
                myAppsNav.tabBarItem.selectedImage = UIImage(systemName: "square.stack.3d.up.fill", withConfiguration: selectedSymbolConfig)
            }
        }
        
        // 5. Đổi tab Settings thành "Cài đặt"
        if let settingsNav = self.viewControllers?[Tab.settings.rawValue] as? UINavigationController
        {
            settingsNav.overrideUserInterfaceStyle = .light
            settingsNav.tabBarItem.title = "Cài đặt"
            if settingsNav.tabBarItem.image == nil {
                settingsNav.tabBarItem.image = UIImage(systemName: "gearshape", withConfiguration: symbolConfig)
                settingsNav.tabBarItem.selectedImage = UIImage(systemName: "gearshape.fill", withConfiguration: selectedSymbolConfig)
            }
        }
        
        // 6. Đặt tab My Apps ("Ứng dụng") làm tab active mặc định khi mở app
        self.selectedIndex = Tab.myApps.rawValue
        
        // ✨ KÍCH HOẠT HIỆU ỨNG KÍNH LỎNG APPLE (LIQUID GLASS) & BỎ GẠCH NGANG ✨
        self.applyAppleLiquidGlassTabBarTheme()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.layoutLiquidGlassComponents()
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        
        _viewDidAppear = true
        self.updateLiquidGlassPillPosition(animated: false)
        
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
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem)
    {
        #if !os(tvOS)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred()
        #endif
        
        guard let items = tabBar.items, let index = items.firstIndex(of: item) else { return }
        
        // Trượt viên giọt nước Kính lỏng sang tab vừa chọn
        self.updateLiquidGlassPillPosition(targetIndex: index, animated: true)
        
        // Hiệu ứng đàn hồi giọt nước cho nút Tab
        let tabBarButtons = self.sortedTabBarButtons()
        guard index < tabBarButtons.count else { return }
        let targetButton = tabBarButtons[index]
        
        UIView.animate(withDuration: 0.12, animations: {
            targetButton.transform = CGAffineTransform(scaleX: 0.88, y: 0.88)
        }) { _ in
            UIView.animate(
                withDuration: 0.42,
                delay: 0,
                usingSpringWithDamping: 0.52,
                initialSpringVelocity: 0.8,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    targetButton.transform = .identity
                },
                completion: nil
            )
        }
    }
}

// MARK: - 💧 THIẾT KẾ THANH TAB BAR KÍNH LỎNG APPLE (LIQUID GLASS - KHÔNG GẠCH NGANG)
private extension TabBarController
{
    func applyAppleLiquidGlassTabBarTheme()
    {
        let appearance = UITabBarAppearance()
        // Làm trong suốt hoàn toàn nền mặc định và XOÁ SẠCH đường gạch ngang của UITabBar
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()
        
        let normalFont: UIFont
        let selectedFont: UIFont
        if let roundedNormal = UIFont.systemFont(ofSize: 11.2, weight: .bold).fontDescriptor.withDesign(.rounded),
           let roundedSelected = UIFont.systemFont(ofSize: 11.5, weight: .heavy).fontDescriptor.withDesign(.rounded) {
            normalFont = UIFont(descriptor: roundedNormal, size: 11.2)
            selectedFont = UIFont(descriptor: roundedSelected, size: 11.5)
        } else {
            normalFont = UIFont.systemFont(ofSize: 11.2, weight: .bold)
            selectedFont = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
        }
        
        let itemAppearances = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance
        ]
        
        for itemAppearance in itemAppearances {
            // Trạng thái chưa chọn: Chữ và icon Đen Tuyền (#000000) rõ nét trên nền kính lỏng sáng
            itemAppearance.normal.iconColor = TabBarCSSTheme.pureBlack
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: TabBarCSSTheme.pureBlack,
                .font: normalFont
            ]
            itemAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -2.0)
            
            // Trạng thái đang chọn: Chữ và icon Xanh chủ đạo (#007BFF) nổi bật trong viên kính lỏng
            itemAppearance.selected.iconColor = TabBarCSSTheme.blue
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: TabBarCSSTheme.blue,
                .font: selectedFont
            ]
            itemAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -2.0)
            
            // Badge thông báo: Đỏ chuẩn hệ thống (#DC3545)
            itemAppearance.normal.badgeBackgroundColor = TabBarCSSTheme.red
            itemAppearance.selected.badgeBackgroundColor = TabBarCSSTheme.red
            itemAppearance.normal.badgeTextAttributes = [
                .foregroundColor: TabBarCSSTheme.white,
                .font: UIFont.systemFont(ofSize: 11, weight: .bold)
            ]
            itemAppearance.selected.badgeTextAttributes = [
                .foregroundColor: TabBarCSSTheme.white,
                .font: UIFont.systemFont(ofSize: 11, weight: .bold)
            ]
        }
        
        self.tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            self.tabBar.scrollEdgeAppearance = appearance
        }
        
        self.tabBar.backgroundImage = UIImage()
        self.tabBar.shadowImage = UIImage()
        self.tabBar.backgroundColor = .clear
        self.tabBar.tintColor = TabBarCSSTheme.blue
        self.tabBar.unselectedItemTintColor = TabBarCSSTheme.pureBlack
        self.tabBar.isTranslucent = true
        self.tabBar.layer.masksToBounds = false
        
        // Chèn khung Dock Kính lỏng và Viên giọt nước chọn tab vào tầng dưới cùng của TabBar
        if self.liquidGlassDockView.superview == nil {
            self.tabBar.insertSubview(self.liquidGlassDockView, at: 0)
        }
        if self.activeLiquidPillView.superview == nil {
            self.tabBar.insertSubview(self.activeLiquidPillView, aboveSubview: self.liquidGlassDockView)
        }
    }
    
    func sortedTabBarButtons() -> [UIView] {
        return self.tabBar.subviews
            .filter { String(describing: type(of: $0)).contains("UITabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }
    }
    
    func layoutLiquidGlassComponents() {
        // Ẩn mọi đường kẻ/nền mặc định nếu iOS tự sinh ra để đảm bảo không bao giờ có gạch ngang
        for subview in self.tabBar.subviews {
            let className = String(describing: type(of: subview))
            if className.contains("UIBarBackground") {
                subview.isHidden = true
            }
        }
        
        self.tabBar.sendSubviewToBack(self.activeLiquidPillView)
        self.tabBar.sendSubviewToBack(self.liquidGlassDockView)
        
        let buttons = self.sortedTabBarButtons()
        guard let firstBtn = buttons.first, let lastBtn = buttons.last else {
            self.liquidGlassDockView.frame = self.tabBar.bounds.insetBy(dx: 12, dy: 2)
            return
        }
        
        // Tính toán khung viên nang Kính lỏng ôm trọn cụm các nút Tab
        let combinedButtonsFrame = buttons.reduce(firstBtn.frame) { $0.union($1.frame) }
        let dockX = max(10.0, combinedButtonsFrame.minX - 6.0)
        let dockWidth = min(self.tabBar.bounds.width - 20.0, combinedButtonsFrame.width + 12.0)
        let dockY = max(0.0, combinedButtonsFrame.minY - 3.0)
        let dockHeight = max(52.0, combinedButtonsFrame.height + 6.0)
        
        self.liquidGlassDockView.frame = CGRect(x: dockX, y: dockY, width: dockWidth, height: dockHeight)
        
        if self.activeLiquidPillView.frame == .zero {
            self.updateLiquidGlassPillPosition(animated: false)
        } else {
            self.updateLiquidGlassPillPosition(animated: false)
        }
    }
    
    func updateLiquidGlassPillPosition(targetIndex: Int? = nil, animated: Bool) {
        let buttons = self.sortedTabBarButtons()
        let index = targetIndex ?? self.selectedIndex
        guard index >= 0, index < buttons.count else { return }
        
        let targetButton = buttons[index]
        let btnFrame = targetButton.frame
        guard btnFrame.width > 0, btnFrame.height > 0 else { return }
        
        let pillWidth = min(btnFrame.width - 8.0, 86.0)
        let pillHeight = max(44.0, min(btnFrame.height, 48.0))
        let targetPillFrame = CGRect(
            x: btnFrame.midX - pillWidth / 2.0,
            y: btnFrame.midY - pillHeight / 2.0,
            width: pillWidth,
            height: pillHeight
        )
        
        if animated {
            // Hiệu ứng biến dạng giọt nước lỏng khi trượt giữa các Tab
            UIView.animate(withDuration: 0.14, delay: 0, options: [.curveEaseIn, .beginFromCurrentState]) {
                self.activeLiquidPillView.transform = CGAffineTransform(scaleX: 1.12, y: 0.90)
            }
            UIView.animate(
                withDuration: 0.46,
                delay: 0.04,
                usingSpringWithDamping: 0.64,
                initialSpringVelocity: 0.85,
                options: [.curveEaseOut, .beginFromCurrentState]
            ) {
                self.activeLiquidPillView.frame = targetPillFrame
                self.activeLiquidPillView.transform = .identity
            }
        } else {
            self.activeLiquidPillView.transform = .identity
            self.activeLiquidPillView.frame = targetPillFrame
        }
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
