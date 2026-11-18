//
//  AppDelegate.swift
//  AltStore
//
//  Created by Riley Testut on 5/2/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import UIKit
import Intents
import Minimuxer
import AltStoreCore
import AltSign

extension AppDelegate {
    func startMinimuxer(pairing_file: Data? = UserDefaults.standard.pairingFile) {
        let documentsDirectory = FileManager.default.documentsDirectory.path
        
        guard let pairing_file else {
            return
        }

        // LỚP BẢO VỆ SỚM: Ngay khi có Pairing File, trích xuất và lưu UDID vào bộ nhớ đệm ngay lập tức (Offline 0ms)
        if let extractedUDID = CellularRefreshManager.shared.extractUDIDFromPairingFileData(pairing_file) {
            UserDefaults.standard.cachedDeviceUDID = extractedUDID
        } else {
            CellularRefreshManager.shared.syncOfflineCachedUDID()
        }

        do {
            try Minimuxer.startWithLogger(pairing_file, logPath: documentsDirectory, consoleLogging: true)
            // Nếu Minimuxer phản hồi UDID trực tiếp thì cập nhật chuẩn xác vào bộ nhớ đệm
            if let udid = try? Minimuxer.fetchDeviceUDID(), !udid.isEmpty {
                UserDefaults.standard.cachedDeviceUDID = udid
            }
        } catch {
            self.presentMinimuxerError(error: error)
        }
    }
    
    func presentMinimuxerError(error: Error){
        let toastView = ToastView(title: error.localizedDescription, detail: nil)
        toastView.addTarget(nil, action: #selector(AppDelegate.resetPairingFile), for: .touchUpInside)
        toastView.show(in: self.window?.rootViewController?.view ?? UIView(), duration: 5.0)
    }

    @objc
    public func resetPairingFile() {
        isImportingPairingFile = true
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        documentPicker.delegate = self

        // Navigate the view hierarchy to find a suitable view controller to present from
        var currentController = self.window?.rootViewController
        while let presentedController = currentController?.presentedViewController {
            currentController = presentedController
        }

        currentController?.present(documentPicker, animated: true, completion: nil)
    }
}

@UIApplicationMain
final class AppDelegate: UIResponder, UIApplicationDelegate, UIDocumentPickerDelegate
{
    var window: UIWindow?
    var isImportingPairingFile = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        UserDefaults.standard.registerDefaults()
        
        // Đồng bộ sớm UDID từ bộ nhớ/Pairing File ngay khi ứng dụng vừa khởi chạy
        CellularRefreshManager.shared.syncOfflineCachedUDID()

        if !UserDefaults.standard.firstLaunch.boolValue {
            // Reset sensitive values cleanly on first launch
            UserDefaults.standard.firstLaunch = true
        }
        
        self.setTintColor()
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration
    {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>)
    {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }

    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    {
        guard UserDefaults.standard.isBackgroundRefreshEnabled else {
            completionHandler(.noData)
            return
        }
        Task{
            let result = await AppManager.shared.backgroundRefresh()
            switch result{
            case .success:
                completionHandler(.newData)
            case .failure(_):
                completionHandler(.failed)
            }
        }
    }
    
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any?
    {
        switch intent
        {
        case is RefreshAllIntent: return RefreshAllIntentHandler()
        default: return nil
        }
    }
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard isImportingPairingFile else { return }
        isImportingPairingFile = false
        
        guard let url = urls.first else {
            return
        }
        
        do {
            let fileData = try Data(contentsOf: url)
            UserDefaults.standard.pairingFile = fileData
            startMinimuxer(pairing_file: fileData)
        } catch {
            presentMinimuxerError(error: error)
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        isImportingPairingFile = false
    }
}

private extension AppDelegate
{
    func setTintColor()
    {
        UIView.appearance().tintColor = .altPrimary
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        }
    }
}
