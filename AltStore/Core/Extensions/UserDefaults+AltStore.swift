
//
//  UserDefaults+AltStore.swift
//  AltStore
//
//  Created by Riley Testut on 6/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import AltStoreCore

public extension UserDefaults {
    static let shared = UserDefaults(suiteName: Bundle.main.altstoreAppGroup)!
    
    @NSManaged var firstLaunch: Date?
    @NSManaged var presentedLaunchReminderNotification: Bool
    
    @NSManaged var isBackgroundRefreshEnabled: Bool
    @NSManaged var isDebugModeEnabled: Bool
    @NSManaged var isExportModeEnabled: Bool
    
    @NSManaged var activePatreonAccountID: String?
    @NSManaged var isBetaTester: Bool
    
    @NSManaged var responseCachingEnabled: Bool
    @NSManaged var patreonTier: Int
    
    @NSManaged var menuBarAppShown: Bool
    @NSManaged var menuBarAppStatusItemShown: Bool
    
    @NSManaged var preferredServerID: String?
    @NSManaged var isServerDiscoverable: Bool
    
    @NSManaged var trustedSources: [String]?
    @NSManaged var blockedSources: [String]?
    
    @NSManaged var lastUpdatedSourcesDate: Date?
    
    @NSManaged var isAppLimitDisabled: Bool
    
    @NSManaged var activeAnisetteURL: String
    @NSManaged var customAnisetteURL: String?
    @NSManaged var anisetteURLList: [String]?
    
    @NSManaged var isLegacyDecompressionEnabled: Bool
    
    @NSManaged var isFetchSourcesIndexEnabled: Bool
    @NSManaged var sourcesIndexURL: String?
    @NSManaged var customSourcesIndexURL: String?
    
    @NSManaged var isWLANRefreshEnabled: Bool
    @NSManaged var isBackgroundRefreshWithinAppEnabled: Bool
    
    @NSManaged var autoFixAppGroupIDs: Bool
    @NSManaged var autoUseExistingAppIDs: Bool
    
    @NSManaged var isJITLessTestCompleted: Bool
    @NSManaged var isJITLessEnabled: Bool
    @NSManaged var isJITLessSetupShown: Bool
    
    @NSManaged var isUsingSideStoreAnisette: Bool
    @NSManaged var shouldCheckTrackers: Bool
    @NSManaged var shouldClearCacheOnLaunch: Bool
    
    @NSManaged var appTintColorHex: String?
    @NSManaged var appLanguageCode: String?
    
    // MARK: - Custom Install Pipeline & Advanced Features (SideStore Customizations)
    
    @NSManaged var isCustomPipelineEnabled: Bool
    @NSManaged var isPipelineLiveMonitorEnabled: Bool
    @NSManaged var isBundleIDVerificationEnabled: Bool
    @NSManaged var isUserCustomizationEnabled: Bool
    @NSManaged var isCustomAppNameEnabled: Bool
    @NSManaged var isCustomBundleIDEnabled: Bool
    @NSManaged var isExtensionMgmtEnabled: Bool
    @NSManaged var isInfoPlistEditorEnabled: Bool
    @NSManaged var isRemoveAppPlaceholdersEnabled: Bool
    @NSManaged var isSmartBundleIDReuseEnabled: Bool
    @NSManaged var customPipelineOrder: [String]?
    @NSManaged var customPipelineDisabledSteps: [String]?
    
    // MARK: - Local IPA Library & Export Options
    
    @NSManaged var autoSaveInstalledIPAs: Bool
    @NSManaged var customDocumentsDisplayName: String?
    
    func registerDefaults() {
        var defaults: [String: Any] = [
            #keyPath(UserDefaults.isBackgroundRefreshEnabled): true,
            #keyPath(UserDefaults.isWLANRefreshEnabled): true,
            #keyPath(UserDefaults.isBackgroundRefreshWithinAppEnabled): true,
            #keyPath(UserDefaults.responseCachingEnabled): true,
            #keyPath(UserDefaults.isServerDiscoverable): true,
            #keyPath(UserDefaults.activeAnisetteURL): "https://ani.sidestore.io",
            #keyPath(UserDefaults.isFetchSourcesIndexEnabled): true,
            #keyPath(UserDefaults.sourcesIndexURL): "https://raw.githubusercontent.com/SideStore/SideStore-Index/main/index.json",
            #keyPath(UserDefaults.autoFixAppGroupIDs): true,
            #keyPath(UserDefaults.autoUseExistingAppIDs): true,
            #keyPath(UserDefaults.isUsingSideStoreAnisette): false,
            #keyPath(UserDefaults.shouldCheckTrackers): true,
            #keyPath(UserDefaults.shouldClearCacheOnLaunch): false,
            
            // Custom Install Pipeline & Advanced Features (SideStore Customizations)
            #keyPath(UserDefaults.isCustomPipelineEnabled): false,
            #keyPath(UserDefaults.isPipelineLiveMonitorEnabled): false,
            #keyPath(UserDefaults.isBundleIDVerificationEnabled): false, // Mặc định TẮT kiểm tra ID gói
            #keyPath(UserDefaults.isUserCustomizationEnabled): false,
            #keyPath(UserDefaults.isCustomAppNameEnabled): true,
            #keyPath(UserDefaults.isCustomBundleIDEnabled): true,
            #keyPath(UserDefaults.isExtensionMgmtEnabled): true,
            #keyPath(UserDefaults.isInfoPlistEditorEnabled): false,
            #keyPath(UserDefaults.isRemoveAppPlaceholdersEnabled): false,
            #keyPath(UserDefaults.isSmartBundleIDReuseEnabled): false,
            
            // Local IPA Library
            #keyPath(UserDefaults.autoSaveInstalledIPAs): false
        ]
        
        #if targetEnvironment(macCatalyst)
        defaults[#keyPath(UserDefaults.menuBarAppShown)] = true
        defaults[#keyPath(UserDefaults.menuBarAppStatusItemShown)] = true
        #endif
        
        self.register(defaults: defaults)
    }
}
