
//  AltStore/TabBarController.swift
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit

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
        
        // 1. Xóa tab Browse (nằm ở vị trí index 2 trên Storyboard gốc)
        if var viewControllers = self.viewControllers, viewControllers.count == 5 {
            viewControllers.remove(at: 2)
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
