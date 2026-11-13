
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
    // Thứ tự ban đầu được nạp từ Storyboard
    private enum StoryboardTab: Int, CaseIterable
    {
        case news
        case sources
        case browse
        case myApps
        case settings
    }

    // Thứ tự 3 tab thực tế sau khi đã bỏ Sources và Browse
    private enum ActiveTab: Int
    {
        case overview = 0 // Tổng Quan
        case myApps   = 1 // My Apps
        case settings = 2 // Cài Đặt
    }
}

final class TabBarController: UITabBarController
{
    private var initialSegue: (identifier: String, sender: Any?)?
    
    private var _viewDidAppear = false
    
    private var sourcesViewController: SourcesViewController?
    
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
        
        guard let allControllers = self.viewControllers,
              allControllers.count > StoryboardTab.settings.rawValue else { return }
        
        // 1. Tab Tổng Quan (News cũ)
        let overviewNav = allControllers[StoryboardTab.news.rawValue]
        overviewNav.tabBarItem.title = "Tổng Quan"
        overviewNav.tabBarItem.image = UIImage(systemName: "checkmark.shield")
        overviewNav.tabBarItem.selectedImage = UIImage(systemName: "checkmark.shield.fill")
        
        // 2. Tab My Apps
        let myAppsNav = allControllers[StoryboardTab.myApps.rawValue]
        
        // 3. Tab Cài Đặt (Settings)
        let settingsNav = allControllers[StoryboardTab.settings.rawValue]
        settingsNav.tabBarItem.title = "Cài Đặt"
        settingsNav.tabBarItem.image = UIImage(systemName: "gearshape")
        settingsNav.tabBarItem.selectedImage = UIImage(systemName: "gearshape.fill")
        
        // Bỏ 2 tab Sources (Nguồn) và Browse khỏi thanh TabBar
        self.viewControllers = [overviewNav, myAppsNav, settingsNav]
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
        // Vì đã bỏ tab Nguồn nên nếu có deep link thêm nguồn thì chuyển về tab My Apps
        if let presentedViewController = self.presentedViewController
        {
            presentedViewController.dismiss(animated: true) {
                self.presentSources(sender)
            }
            
            return
        }
        
        self.selectedIndex = ActiveTab.myApps.rawValue
    }
}

private extension TabBarController
{
    @objc func importApp(_ notification: Notification)
    {
        self.selectedIndex = ActiveTab.myApps.rawValue
    }

    @objc func openErrorLog(_ notification: Notification)
    {
        self.selectedIndex = ActiveTab.settings.rawValue
    }
}
