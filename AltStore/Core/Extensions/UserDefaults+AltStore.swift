//
//  UserDefaults+AltStore.swift
//  AltStore
//
//  Created by Riley Testut on 5/28/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import Foundation

public extension UserDefaults
{
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
    
    // MARK: - Custom Install Pipeline & Advanced Features
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

    var isDeveloper: Bool {
        if let _ = Bundle.main.infoDictionary?["ALTDeviceID"]
        {
            return true
        }
        
        return false
    }
    
    internal(set) var patchedApps: Set<String> {
        get {
            let array = self.array(forKey: #function) as? [String] ?? []
            return Set(array)
        }
        set {
            let array = Array(newValue)
            self.set(array, forKey: #function)
        }
    }
    
    enum SideJITServerAddressType: String, CaseIterable, CustomStringConvertible {
        case ip = "IP"
        case url = "URL"
        
        public var description: String {
            self.rawValue
        }
    }
    
    var sidejittype: SideJITServerAddressType {
        get {
            guard let strValue = string(forKey: "ALTJITServerType") else {
                return .url // return Default on failure
            }
            return SideJITServerAddressType(rawValue: strValue) ?? .url
        }
        set {
            set(newValue.rawValue, forKey: "ALTJITServerType")
        }
    }

    var sidejitserver: String? {
        get {
            switch self.sidejittype {
            case .ip:
                return string(forKey: "ALTJITServerIP")
            case .url:
                return string(forKey: "ALTJITServerURL")
            }
        }
    }
    
    enum SigningServerType: String, CaseIterable, CustomStringConvertible {
        case local = "Local"
        case remote = "Remote"
        
        public var description: String {
            self.rawValue
        }
    }
    
    var signingServerType: SigningServerType {
        get {
            guard let strValue = string(forKey: "ALTSigningServerType") else {
                return .local   // return Default on failure
            }
            return SigningServerType(rawValue: strValue) ?? .local
        }
        set {
            set(newValue.rawValue, forKey: "ALTSigningServerType")
        }
    }

    var signingServerAddress: String? {
        get {
            switch self.signingServerType {
            case .local:
                return self.localSigningServerAddress
            case .remote:
                return self.remoteSigningServerAddress
            }
        }
    }
    
    private static let defaultLocalSigningServer = "http://127.0.0.1:51423"
    var localSigningServerAddress: String? {
        get {
            let address = string(forKey: "ALTLocalSigningServerAddress") ?? Self.defaultLocalSigningServer
            return !address.isEmpty ? address : Self.defaultLocalSigningServer
        }
    }
    
    var remoteSigningServerAddress: String? {
        get {
            return string(forKey: "ALTRemoteSigningServerAddress")
        }
    }
    
    struct AnisetteURLData: Codable, Hashable {
        struct Server: Codable, Hashable {
            var name: String
            var address: String
        }
        var servers: [Server]
    }
    
    struct SourcesIndexData: Codable, Hashable {
        struct RecommendedSources: Codable, Hashable {
            var name: String
            var url: String
            
            enum CodingKeys: String, CodingKey {
                case name = "Name"
                case url = "URL"
            }
        }
        var index: [RecommendedSources]
        var community: [RecommendedSources]?
        
        enum CodingKeys: String, CodingKey {
            case index = "Index"
            case community = "Community"
        }
    }
    
    // fetch blocking the calling sequence
    func getDefaultAnisetteURL() -> String{
        // Note the source contains a placeholder string representing the official source URL, which takes no effect
        // it requires user action to select it from picker and that logic handles replacing the actual logic
        
        let OfficialAnisetteServerGenerator: () -> String = {
            return "https://ani.sidestore.io"
        }

        // fetch the dynamic list of servers and pick the first item directly if possible
        let defaultServer: String = {
            guard let url = URL(string: "https://raw.githubusercontent.com/SideStore/SideStore/develop/TrustedSources/anisette-servers.json") else {
                return OfficialAnisetteServerGenerator()
            }
            
            var retUrl: String = OfficialAnisetteServerGenerator()
            let semaphore = DispatchSemaphore(value: 0)

            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                if let error = error {
                    print("Error fetching data: \(error)")
                    semaphore.signal()
                    return
                }

                guard let data = data else {
                    print("No data returned")
                    semaphore.signal()
                    return
                }

                do {
                    let anisetteList = try JSONDecoder().decode(AnisetteURLData.self, from: data)
                    retUrl = anisetteList.servers.first?.address ?? OfficialAnisetteServerGenerator()
                } catch {
                    print("Error decoding JSON: \(error)")
                }

                semaphore.signal()
            }

            task.resume()
            semaphore.wait()
            return retUrl
        }()
        return defaultServer
    }
    
    func registerDefaults()
    {
        var defaults: [String: Any] = [#keyPath(UserDefaults.isBackgroundRefreshEnabled): true,
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
                                       #keyPath(UserDefaults.isCustomPipelineEnabled): false,
                                       #keyPath(UserDefaults.isPipelineLiveMonitorEnabled): false,
                                       #keyPath(UserDefaults.isBundleIDVerificationEnabled): false,
                                       #keyPath(UserDefaults.isUserCustomizationEnabled): false,
                                       #keyPath(UserDefaults.isCustomAppNameEnabled): true,
                                       #keyPath(UserDefaults.isCustomBundleIDEnabled): true,
                                       #keyPath(UserDefaults.isExtensionMgmtEnabled): true,
                                       #keyPath(UserDefaults.isInfoPlistEditorEnabled): false,
                                       #keyPath(UserDefaults.isRemoveAppPlaceholdersEnabled): false,
                                       #keyPath(UserDefaults.isSmartBundleIDReuseEnabled): false,
                                       #keyPath(UserDefaults.autoSaveInstalledIPAs): false]
        
        if self.isDeveloper
        {
            defaults[#keyPath(UserDefaults.isDebugModeEnabled)] = true
        }
        
        UserDefaults.standard.register(defaults: defaults)
        UserDefaults.shared.register(defaults: defaults)
    }
}
