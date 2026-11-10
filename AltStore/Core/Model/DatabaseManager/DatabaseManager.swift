//
//  DatabaseManager.swift
//  AltStore
//
//  Created by Riley Testut on 5/20/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData
import SideSign

extension CFNotificationName
{
    fileprivate static let willMigrateDatabase = CFNotificationName("com.rileytestut.AltStore.WillMigrateDatabase" as CFString)
}

private let ReceivedWillMigrateDatabaseNotification: @convention(c) (CFNotificationCenter?, UnsafeMutableRawPointer?, CFNotificationName?, UnsafeRawPointer?, CFDictionary?) -> Void = { (center, observer, name, object, userInfo) in
    DatabaseManager.shared.receivedWillMigrateDatabaseNotification()
}

public class DatabaseManager: @unchecked Sendable
{
    public static private(set) var shared = DatabaseManager()
    
    public let persistentContainer: PersistentContainer
    
    private let lock = NSLock()
    private var _isStarted = false
    public var isStarted: Bool {
        self.lock.withLock { self._isStarted }
    }
    
    private var startTask: Task<Void, Error>?
    private var ignoreWillMigrateDatabaseNotification = false

    private init()
    {
        self.persistentContainer = PersistentContainer(name: AppConstants.Database.name, bundle: Bundle(for: DatabaseManager.self))
        self.persistentContainer.preferredMergePolicy = MergePolicy()
        
        let observer = Unmanaged.passUnretained(self).toOpaque()
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer, ReceivedWillMigrateDatabaseNotification, CFNotificationName.willMigrateDatabase.rawValue, nil, .deliverImmediately)
    }
    
    public class func deleteDatabase() -> Bool
    {
        do {
            let container = Self.shared.persistentContainer
            let databaseStore = container.persistentStoreCoordinator.persistentStores.first
            let databaseStoreURL = databaseStore?.url ?? PersistentContainer.defaultDirectoryURL().appendingPathComponent(AppConstants.Database.fileName)
            
            Self.shared.persistentContainer.viewContext.reset()

            for store in Self.shared.persistentContainer.persistentStoreCoordinator.persistentStores {
                try? Self.shared.persistentContainer.persistentStoreCoordinator.remove(store)
            }

            if FileManager.default.fileExists(atPath: databaseStoreURL.path) {
                try Self.shared.persistentContainer.persistentStoreCoordinator.destroyPersistentStore(
                    at: databaseStoreURL,
                    ofType: NSSQLiteStoreType,
                    options: nil
                )
                try? FileManager.default.removeItem(at: databaseStoreURL)
            }
            return true
        } catch {
            return false
        }
    }
    
    public class func recreateDatabase() {
        _ = Self.deleteDatabase()
        Self.shared = DatabaseManager()
    }

    public func start() async throws
    {
        if self.isStarted { return }
        
        let task = self.lock.withLock {
            if let startTask { return startTask }
            let task = Task<Void, Error>.detached(priority: .userInitiated) { try await self.performStart() }
            self.startTask = task
            return task
        }
        
        do {
            try await task.value
            self.lock.withLock { self._isStarted = true }
        } catch {
            self.lock.withLock { self.startTask = nil }
            throw error
        }
    }

    private func performStart() async throws
    {
        if self.persistentContainer.isMigrationRequired
        {
            self.ignoreWillMigrateDatabaseNotification = true
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), .willMigrateDatabase, nil, nil, true)
        }

        try await self.persistentContainer.loadPersistentStores()
        try await self.prepareDatabase()
    }

    public func purgeLoggedErrors(before date: Date? = nil) async throws
    {
        try await self.persistentContainer.performBackgroundTask { context in
            let predicate = date.map { NSPredicate(format: "%K <= %@", #keyPath(LoggedError.date), $0 as NSDate) }
            let loggedErrors = LoggedError.all(satisfying: predicate, in: context, requestProperties: [\.returnsObjectsAsFaults: true])
            loggedErrors.forEach { context.delete($0) }
            try context.save()
        }
    }

    public func updateFeaturedSortIDs() async
    {
        // ĐÃ TẮT HOÀN TOÀN: Không bao giờ lôi toàn bộ Nguồn và App trong DB ra gán lại UUID ngẫu nhiên rồi save() nữa!
        return
    }

    public var viewContext: NSManagedObjectContext {
        return self.persistentContainer.viewContext
    }
    
    public func activeAccount(in context: NSManagedObjectContext) -> Account?
    {
        let predicate = NSPredicate(format: "%K == YES", #keyPath(Account.isActiveAccount))
        return Account.first(satisfying: predicate, in: context)
    }
    
    public func activeTeam(in context: NSManagedObjectContext) -> Team?
    {
        let predicate = NSPredicate(format: "%K == YES", #keyPath(Team.isActiveTeam))
        return Team.first(satisfying: predicate, in: context)
    }

    private func prepareDatabase() async throws
    {
        guard !Bundle.isAppExtension() else { return }
        
        let context = self.persistentContainer.newBackgroundContext()
        try await context.perform {
            guard let localAppBundle = ALTApplication(fileURL: Bundle.Info.activeBundleURL) else { return }
            
            #if !targetEnvironment(simulator)
            guard localAppBundle.provisioningProfile != nil else {
                throw ALTError(.invalidApp)
            }
            #endif
            
            let altStoreSource: Source
            if let source = Source.first(satisfying: NSPredicate(format: "%K == %@", #keyPath(Source.identifier), Source.altStoreIdentifier), in: context) {
                altStoreSource = source
            } else {
                altStoreSource = Source.makeAltStoreSource(in: context)
            }
            
            try! altStoreSource.setSourceURL(Source.altStoreSourceURL)
            
            let storeApp: StoreApp
            if let app = StoreApp.first(satisfying: NSPredicate(format: "%K == %@", #keyPath(StoreApp.bundleIdentifier), StoreApp.altstoreAppID), in: context) {
                storeApp = app
            } else {
                storeApp = StoreApp.makeAltStoreApp(version: localAppBundle.version, buildVersion: nil, in: context)
                storeApp.source = altStoreSource
            }
                        
            let serialNumber = CertificateManager.shared.activeCertificate?.serialNumber
                ?? CertificateManager.shared.getSigningCertificate(at: Bundle.Info.activeBundleURL)?.serialNumber
            
            let installedApp: InstalledApp
            if let app = storeApp.installedApp {
                installedApp = app
            } else {
                installedApp = try InstalledApp(
                    resignedAppBundle: localAppBundle,
                    originalBundleIdentifier: StoreApp.altstoreAppID,
                    certificateSerialNumber: serialNumber,
                    storeBuildVersion: nil,
                    context: context
                )
                
                repeat {
                    guard let pluginURL = Bundle.main.builtInPlugInsURL,
                          let pluginFolders = try? FileManager.default.contentsOfDirectory(at: pluginURL, includingPropertiesForKeys: nil),
                          let pluginFolder = pluginFolders.first,
                          let altPluginAppBundle = ALTApplication(fileURL: pluginFolder) else {
                        installedApp.useMainProfile = true
                        break
                    }
                    
                    let entitlements = altPluginAppBundle.entitlements
                    guard let appId = entitlements[ALTEntitlement.applicationIdentifier] as? String else {
                        installedApp.useMainProfile = false
                        break
                    }
                    
                    installedApp.useMainProfile = appId.hasSuffix(Bundle.Info.activeBundleIdentifier)
                } while(false)
                
                installedApp.storeApp = storeApp
                if installedApp.releaseTrack == nil,
                   let trackEntity = storeApp.latestSupportedVersion?.releaseTrack {
                    installedApp.releaseTrack = trackEntity
                }
            }
            
            /* App Extensions */
            var installedExtensions = Set<InstalledExtension>()
            for appExtension in localAppBundle.appExtensions
            {
                let resignedBundleID = appExtension.bundleIdentifier
                let originalBundleID = resignedBundleID.replacingOccurrences(of: localAppBundle.bundleIdentifier, with: StoreApp.altstoreAppID)
                
                let installedExtension: InstalledExtension
                if let existing = installedApp.appExtensions.first(where: { $0.bundleIdentifier == originalBundleID }) {
                    installedExtension = existing
                } else {
                    installedExtension = try InstalledExtension(resignedAppExtensionBundle: appExtension, originalBundleIdentifier: originalBundleID, context: context)
                }
                installedExtension.update(resignedAppExtensionBundle: appExtension)
                installedExtensions.insert(installedExtension)
            }
            installedApp.appExtensions = installedExtensions
            
            // ĐÃ XÓA BỎ HOÀN TOÀN ĐOẠN COPY BỘ CÀI SIDESTORE RA THƯ MỤC TẠM VÀ BĂM LẠI MỖI KHI MỞ APP!
            // Chỉ thực hiện đúng 1 lần duy nhất nếu chưa từng có fingerprint hoặc vừa cập nhật phiên bản SideStore mới:
            if installedApp.appBundleFingerprint == nil || installedApp.version != localAppBundle.version {
                let bundleURL = Bundle.Info.activeBundleURL
                let altstoreAppID = StoreApp.altstoreAppID
                let extensionBundleIDMap = installedExtensions.reduce(into: [String: String]()) { dict, ext in
                    dict[ext.resignedBundleIdentifier] = ext.bundleIdentifier
                }
                
                FileManager.default.prepareTemporaryURL { temporaryFileURL in
                    do {
                        try FileManager.default.copyItem(at: bundleURL, to: temporaryFileURL)
                        guard let tempAppBundle = ALTApplication(fileURL: temporaryFileURL) else { throw ALTError(.invalidApp) }
                        try tempAppBundle.updateInfoPlist(with: [kCFBundleIdentifierKey as String: altstoreAppID])
                        for appExtension in tempAppBundle.appExtensions {
                            guard let originalBundleID = extensionBundleIDMap[appExtension.bundleIdentifier] else { throw ALTError(.invalidApp) }
                            try appExtension.updateInfoPlist(with: [kCFBundleIdentifierKey as String: originalBundleID])
                        }
                        let (signature, _) = try CacheAppOperation.cachePayload(for: temporaryFileURL)
                        installedApp.appBundleFingerprint = signature
                    } catch {}
                }
            }
            
            let cachedRefreshedDate = installedApp.refreshedDate
            let cachedExpirationDate = installedApp.expirationDate
                        
            self.reconcileSelfFromSelfBinary(installedApp: installedApp, localAppBundle: localAppBundle, serialNumber: serialNumber)
            
            if installedApp.refreshedDate < cachedRefreshedDate
            {
                installedApp.refreshedDate = cachedRefreshedDate
                installedApp.expirationDate = cachedExpirationDate
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    private func reconcileSelfFromSelfBinary(installedApp: InstalledApp, localAppBundle: ALTApplication, serialNumber: String?) {
        installedApp.name = localAppBundle.name
        installedApp.resignedBundleIdentifier = localAppBundle.bundleIdentifier
        installedApp.version = localAppBundle.version
        installedApp.buildVersion = localAppBundle.buildVersion
        
        // TỐI ƯU: Không đọc và phân tích lại file nhị phân Mach-O lần thứ 2 nữa, dùng luôn serialNumber đã lấy ở trên!
        let effectiveSerial = serialNumber
        installedApp.certificateSerialNumber = effectiveSerial
        
        let activeKeychainSerial = CertificateManager.shared.activeCertificate?.serialNumber
        let isCross = (activeKeychainSerial != nil && !activeKeychainSerial!.isEmpty && effectiveSerial != nil && effectiveSerial != activeKeychainSerial)
        installedApp.certificateStatus = .valid(isCrossSigned: isCross)
        
        if let provisioningProfile = localAppBundle.provisioningProfile {
            installedApp.refreshedDate = provisioningProfile.creationDate
            installedApp.expirationDate = provisioningProfile.expirationDate
        }
    }
    
    fileprivate func receivedWillMigrateDatabaseNotification()
    {
        defer { self.ignoreWillMigrateDatabaseNotification = false }
        guard !self.ignoreWillMigrateDatabaseNotification else { return }
        exit(104)
    }
}
