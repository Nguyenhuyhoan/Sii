
//  AltStore/TabBarController.swift
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME CHO TAB BAR (ĐỒNG BỘ 100% VỚI TOÀN BỘ ỨNG DỤNG & CHỮ ĐEN TUYỀN)
private enum TabBarCSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                      // #000000 (Chữ & icon chưa chọn đen tuyền rõ nét)
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)       // #f5f8ff
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)      // #dce2ec (Viền chuẩn toàn hệ thống)
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)          // #007bff (Màu tab đang chọn)
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)       // #6f42c1
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)           // #dc3545 (Màu badge thông báo)
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
    
    private let topAccentLine = CAGradientLayer()
    
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
        let selectedSymbolConfig = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        
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
        
        // ✨ KÍCH HOẠT GIAO DIỆN TAB BAR CHUẨN CSS THEME ✨
        self.applySmartWebCSSTabBarTheme()
    }
    
    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.topAccentLine.frame = CGRect(x: 0, y: 0, width: self.tabBar.bounds.width, height: 1.2)
    }
    
    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        debugLog("[TabBarController] viewDidAppear() — TabBarController is now visible")
        
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
    
    override func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem)
    {
        #if !os(tvOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
        
        // Hiệu ứng nảy lò xo mượt mà cho tab vừa được chạm
        guard let items = tabBar.items, let index = items.firstIndex(of: item) else { return }
        let tabBarButtons = tabBar.subviews
            .filter { String(describing: type(of: $0)).contains("UITabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }
        
        guard index < tabBarButtons.count else { return }
        let targetButton = tabBarButtons[index]
        
        UIView.animate(withDuration: 0.11, animations: {
            targetButton.transform = CGAffineTransform(scaleX: 0.91, y: 0.91)
        }) { _ in
            UIView.animate(
                withDuration: 0.34,
                delay: 0,
                usingSpringWithDamping: 0.56,
                initialSpringVelocity: 0.6,
                options: [.curveEaseOut, .allowUserInteraction],
                animations: {
                    targetButton.transform = .identity
                },
                completion: nil
            )
        }
    }
}

// MARK: - ✨ THIẾT KẾ THANH TAB BAR CHUẨN CSS THEME
private extension TabBarController
{
    func applySmartWebCSSTabBarTheme()
    {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = TabBarCSSTheme.white.withAlphaComponent(0.97)
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.shadowColor = TabBarCSSTheme.border
        
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
            // Trạng thái chưa chọn: Chữ và icon Đen Tuyền (#000000) rõ nét
            itemAppearance.normal.iconColor = TabBarCSSTheme.pureBlack
            itemAppearance.normal.titleTextAttributes = [
                .foregroundColor: TabBarCSSTheme.pureBlack,
                .font: normalFont
            ]
            itemAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1.5)
            
            // Trạng thái đang chọn: Chữ và icon Xanh chủ đạo (#007BFF)
            itemAppearance.selected.iconColor = TabBarCSSTheme.blue
            itemAppearance.selected.titleTextAttributes = [
                .foregroundColor: TabBarCSSTheme.blue,
                .font: selectedFont
            ]
            itemAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1.5)
            
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
        
        self.tabBar.tintColor = TabBarCSSTheme.blue
        self.tabBar.unselectedItemTintColor = TabBarCSSTheme.pureBlack
        self.tabBar.isTranslucent = true
        
        // Đổ bóng xanh dịu nhẹ hướng lên trên đồng bộ với các khung Card
        self.tabBar.layer.shadowColor = TabBarCSSTheme.blue.cgColor
        self.tabBar.layer.shadowOffset = CGSize(width: 0, height: -4)
        self.tabBar.layer.shadowRadius = 14
        self.tabBar.layer.shadowOpacity = 0.08
        self.tabBar.layer.masksToBounds = false
        
        // Đường viền mảnh chuẩn #DCE2EC pha ánh xanh nhẹ phía trên thanh Tab Bar
        self.topAccentLine.colors = [
            TabBarCSSTheme.border.cgColor,
            TabBarCSSTheme.blue.withAlphaComponent(0.22).cgColor,
            TabBarCSSTheme.purple.withAlphaComponent(0.22).cgColor,
            TabBarCSSTheme.border.cgColor
        ]
        self.topAccentLine.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.topAccentLine.endPoint = CGPoint(x: 1.0, y: 0.5)
        if self.topAccentLine.superlayer == nil {
            self.tabBar.layer.addSublayer(self.topAccentLine)
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
