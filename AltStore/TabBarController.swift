
//
//  TabBarController.swift
//  AltStore
//
//  Created by Riley Testut on 9/17/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import AltStoreCore

class TabBarController: UITabBarController
{
    private var hasSelectedInitialTab = false
    private let selectionFeedback = UISelectionFeedbackGenerator()

    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.delegate = self
        // Khóa cứng giao diện Sáng (Light Mode) để đồng bộ tuyệt đối với CSS Theme
        self.overrideUserInterfaceStyle = .light
        self.selectionFeedback.prepare()
        
        // 1. Thiết lập giao diện TabBar Kính Mờ Thanh Lịch (Glassmorphism)
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        appearance.backgroundColor = UIColor.white.withAlphaComponent(0.82)
        
        // Đường viền mảnh bắt sáng tinh tế phía trên thanh TabBar
        appearance.shadowColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 0.12)
        
        let normalColor = UIColor(red: 0.44, green: 0.49, blue: 0.58, alpha: 1.0)
        let selectedColor = UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = normalColor
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: normalColor,
            .font: UIFont.systemFont(ofSize: 10.5, weight: .medium)
        ]
        itemAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
        
        itemAppearance.selected.iconColor = selectedColor
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 10.5, weight: .bold)
        ]
        itemAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
        
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance
        
        self.tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            self.tabBar.scrollEdgeAppearance = appearance
        }
        
        self.tabBar.tintColor = selectedColor
        self.tabBar.unselectedItemTintColor = normalColor
        
        // Đổ bóng màu Indigo mềm hướng lên trên tạo chiều sâu nổi 3D thanh lịch
        self.tabBar.layer.shadowColor = UIColor(red: 0.15, green: 0.10, blue: 0.38, alpha: 1.0).cgColor
        self.tabBar.layer.shadowOpacity = 0.065
        self.tabBar.layer.shadowOffset = CGSize(width: 0, height: -4)
        self.tabBar.layer.shadowRadius = 14
        
        // 2. Cấu hình danh sách 4 Tab chính: Tổng quan - Sửa lỗi - Ứng dụng - Cài đặt
        if let viewControllers = self.viewControllers, viewControllers.count >= 4 {
            let nav0 = viewControllers[0] // Tổng quan (News)
            let nav1 = viewControllers[1] // Sửa lỗi (Sources)
            let nav2 = viewControllers[2] // Ứng dụng (My Apps)
            let nav3 = viewControllers[settingsTabIndex(for: viewControllers)] // Cài đặt (Settings)
            
            nav0.tabBarItem = UITabBarItem(
                title: "Tổng quan",
                image: UIImage(systemName: "sparkles.rectangle.stack"),
                selectedImage: UIImage(systemName: "sparkles.rectangle.stack.fill")
            )
            
            nav1.tabBarItem = UITabBarItem(
                title: "Sửa lỗi",
                image: UIImage(systemName: "wrench.and.screwdriver"),
                selectedImage: UIImage(systemName: "wrench.and.screwdriver.fill")
            )
            
            nav2.tabBarItem = UITabBarItem(
                title: "Ứng dụng",
                image: UIImage(systemName: "square.stack.3d.up"),
                selectedImage: UIImage(systemName: "square.stack.3d.up.fill")
            )
            
            nav3.tabBarItem = UITabBarItem(
                title: "Cài đặt",
                image: UIImage(systemName: "gearshape"),
                selectedImage: UIImage(systemName: "gearshape.fill")
            )
            
            self.viewControllers = [nav0, nav1, nav2, nav3]
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(importFile(_:)), name: AppDelegate.importFileDeepLinkNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(addSource(_:)), name: AppDelegate.addSourceDeepLinkNotification, object: nil)
    }
    
    private func settingsTabIndex(for vcs: [UIViewController]) -> Int {
        return vcs.count >= 5 ? 4 : 3
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        
        if !self.hasSelectedInitialTab
        {
            self.hasSelectedInitialTab = true
            // Mặc định mở thẳng vào tab "Ứng dụng" (index 2)
            self.selectedIndex = 2
        }
    }
}

// MARK: - UITabBarControllerDelegate (Haptic & Spring Bounce Animation)
extension TabBarController: UITabBarControllerDelegate
{
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController)
    {
        // Phản hồi xúc giác nhẹ nhàng khi chuyển tab
        selectionFeedback.selectionChanged()
        selectionFeedback.prepare()
        
        // Hiệu ứng nhấn đàn hồi (Spring Bounce) trên icon của tab vừa chọn
        guard let index = tabBarController.viewControllers?.firstIndex(of: viewController) else { return }
        let tabBarButtons = tabBarController.tabBar.subviews
            .filter { String(describing: type(of: $0)).contains("UITabBarButton") }
            .sorted { $0.frame.minX < $1.frame.minX }
        
        guard index < tabBarButtons.count else { return }
        let targetButton = tabBarButtons[index]
        
        UIView.animate(withDuration: 0.10, delay: 0, options: [.allowUserInteraction, .curveEaseOut], animations: {
            targetButton.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
        }) { _ in
            UIView.animate(withDuration: 0.38, delay: 0, usingSpringWithDamping: 0.52, initialSpringVelocity: 0.8, options: [.allowUserInteraction], animations: {
                targetButton.transform = .identity
            }, completion: nil)
        }
    }
}

// MARK: - Deep Link Handlers
private extension TabBarController
{
    @objc func importFile(_ notification: Notification)
    {
        guard let viewControllers = self.viewControllers, viewControllers.count > 2 else { return }
        let navigationController = viewControllers[2]
        
        let myAppsViewController = (navigationController as? UINavigationController)?.viewControllers.first as? MyAppsViewController
        myAppsViewController?.loadViewIfNeeded()
        
        self.selectedViewController = navigationController
    }
    
    @objc func addSource(_ notification: Notification)
    {
        guard let viewControllers = self.viewControllers, viewControllers.count > 1 else { return }
        let navigationController = viewControllers[1]
        
        let sourcesViewController = (navigationController as? UINavigationController)?.viewControllers.first as? SourcesViewController
        sourcesViewController?.loadViewIfNeeded()
        
        self.selectedViewController = navigationController
    }
}
