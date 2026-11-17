
//
//  AppManager.swift
//  AltStore
//
//  Created by Riley Testut on 5/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import UserNotifications
import Intents

import Minimuxer
import SideSign

import Combine

extension Notification.Name
{
    static let AppManagerDidAuthenticateWithServer = Notification.Name("io.sidestore.AppManager.DidAuthenticateWithServer")
    static let AppManagerDidAddInstallationProgress = Notification.Name("io.sidestore.AppManager.DidAddInstallationProgress")
    static let AppManagerDidImportAccount = Notification.Name("io.sidestore.AppManager.DidImportAccount")
}

final class AppManager: NSObject, ObservableObject, OperationLogging
{
    static let shared = AppManager()

    private let serializer = TaskChainSerializer()
    private let coalescer = TaskChainCoalescer()

    private var _installationProgress = [String: Progress]()
    private var _refreshProgress = [String: Progress]()

    private let progressQueue = DispatchQueue(label: "io.sidestore.AppManager.progressQueue")

    private override init()
    {
        super.init()
    }
    
    func initialize()
    {
        NotificationCenter.default.addObserver(self, selector: #selector(AppManager.willEnterForeground(_:)), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    var isActivatingApp = false
}

extension AppManager
{
    // MARK: - Installation -
    @discardableResult
    func install<T: AppProtocol>(_ app: T, presentingViewController: PresenterProvider, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let group = self.install([app], presentingViewController: presentingViewController) { (results) in
            guard let (_, result) = results.first else { return }
            completionHandler(result)
        }

        return group
    }
    
    @discardableResult
    private func install<T: AppProtocol>(_ apps: [T], presentingViewController: PresenterProvider, completionHandler: @escaping ([String: Result<InstalledApp, Error>]) -> Void) -> RefreshGroup
    {
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: completionHandler
        )
        
        let operations = apps.map { app in
            let bundleIdentifier = app.bundleIdentifier
            
            let context = InstallAppOperationContext(
                bundleIdentifier: bundleIdentifier,
                authenticatedContext: group.context
            )

            let progress = group.progress(for: bundleIdentifier)
            self.setInstallationProgress(progress, for: bundleIdentifier)
            
            return AppOperation(
                for: app,
                type: .install,
                context: context,
                progress: progress,
                group: group,
                preAction: {},
                postAction: { [weak self] in
                    self?.setInstallationProgress(nil, for: bundleIdentifier)
                }
            )
        }
        
        self.debugLog("[AppManager.install(apps)]: Queued operations count: \(operations.count)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processInstallAppOperations(operations, group: group)
            }
        }
        return group
    }
    
    // MARK: - Refreshing -
    @discardableResult
    func refresh(_ installedApps: [InstalledApp],
                 presentingViewController: PresenterProvider?,
                 group: RefreshGroup? = nil,
                 isBackgroundRefresh: Bool = false,
                 completionHandler: @escaping ([String: Result<InstalledApp, Error>]) -> Void
    ) -> RefreshGroup
    {
        let group = group ?? RefreshGroup(
            context: OperationContext(
                isBackgroundRefresh: isBackgroundRefresh,
                handler: OperationContextHandler(presenterProvider: presentingViewController)
            ),
            completionHandler: completionHandler
        )
        let operations = installedApps.map { (installedApp) -> AppOperation in
            let bundleIdentifier = installedApp.bundleIdentifier
            
            let context = RefreshAppOperationContext(
                bundleIdentifier: bundleIdentifier,
                installedApp: installedApp,
                authenticatedContext: group.context
            )

            let progress = group.progress(for: bundleIdentifier)
            self.setRefreshProgress(progress, for: bundleIdentifier)
            
            return AppOperation(
                for: installedApp,
                type: .refresh,
                context: context,
                progress: progress,
                group: group,
                preAction: {},
                postAction: { [weak self] in
                    self?.setRefreshProgress(nil, for: bundleIdentifier)
                }
            )
        }
        
        self.debugLog("[AppManager.refresh]: Queued operations count: \(operations.count)")

        let sortedOperations = operations.sorted { (a, b) in
            func isAltStoreAppID(_ id: String) -> Bool {
                return id == StoreApp.altstoreAppID || id == Bundle.main.bundleIdentifier
            }

            let aIsAltStore = isAltStoreAppID(a.app.bundleIdentifier)
            let bIsAltStore = isAltStoreAppID(b.app.bundleIdentifier)
            if aIsAltStore != bIsAltStore
            {
                // SideStore should ALWAYS BE DONE LAST because it'll close the app on refresh
                return bIsAltStore
            }
            
            guard let appA = a.app as? InstalledApp, let appB = b.app as? InstalledApp else { return false }
            if appA.refreshedDate != appB.refreshedDate
            {
                return appA.refreshedDate < appB.refreshedDate
            }
            
            return appA.bundleIdentifier < appB.bundleIdentifier
        }
        
        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processRefreshAppOperations(sortedOperations, group: group)
            }
        }
        
        return group
    }
    
    // MARK: - Activate -
    @discardableResult
    func activate(_ installedApp: InstalledApp, presentingViewController: PresenterProvider?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { (results) in
                guard let result = results[bundleIdentifier] else { return }
                completionHandler(result)
            }
        )
        
        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )

        let progress = group.progress(for: bundleIdentifier)
        self.setRefreshProgress(progress, for: bundleIdentifier)
        
        let operation = AppOperation(
            for: installedApp,
            type: .activate,
            context: context,
            progress: progress,
            group: group,
            preAction: { [weak self] in
                self?.isActivatingApp = true
            },
            postAction: { [weak self] in
                self?.isActivatingApp = false
                self?.setRefreshProgress(nil, for: bundleIdentifier)
            }
        )
        
        self.debugLog("[AppManager.activate]: Queued operation for: \(installedApp.bundleIdentifier)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processActivateAppOperation(operation, group: group)
            }
        }
        return group
    }
    
    // MARK: - Deactivate -
    @discardableResult
    func deactivate(_ installedApp: InstalledApp, presentingViewController: PresenterProvider?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { (results) in
                guard let result = results[bundleIdentifier] else { return }
                completionHandler(result)
            }
        )
        
        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )
        
        let progress = group.progress(for: bundleIdentifier)
        self.setRefreshProgress(progress, for: bundleIdentifier)
        
        let operation = AppOperation(
            for: installedApp,
            type: .deactivate,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: { [weak self] in
                self?.setRefreshProgress(nil, for: bundleIdentifier)
            }
        )
        
        self.debugLog("[AppManager.deactivate]: Queued operation for: \(installedApp.bundleIdentifier)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processDeactivateAppOperation(operation, group: group)
            }
        }
        return group
    }
    
    // MARK: - Backup -
    @discardableResult
    func backup(_ installedApp: InstalledApp, presentingViewController: PresenterProvider?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { (results) in
                guard let result = results[bundleIdentifier] else { return }
                completionHandler(result)
            }
        )
        
        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )

        let progress = group.progress(for: bundleIdentifier)
        self.setRefreshProgress(progress, for: bundleIdentifier)
        
        let operation = AppOperation(
            for: installedApp,
            type: .backup,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: { [weak self] in
                self?.setRefreshProgress(nil, for: bundleIdentifier)
            }
        )
        
        self.debugLog("[AppManager.backup]: Queued operation for: \(installedApp.bundleIdentifier)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processBackupAppOperation(operation, group: group)
            }
        }
        return group
    }
    
    // MARK: - Restore -
    @discardableResult
    func restore(_ installedApp: InstalledApp, presentingViewController: PresenterProvider?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { (results) in
                guard let result = results[bundleIdentifier] else { return }
                completionHandler(result)
            }
        )
        
        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )
        
        let progress = group.progress(for: bundleIdentifier)
        self.setRefreshProgress(progress, for: bundleIdentifier)
        
        let operation = AppOperation(
            for: installedApp,
            type: .restore,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: { [weak self] in
                self?.setRefreshProgress(nil, for: bundleIdentifier)
            }
        )

        self.debugLog("[AppManager.restore]: Queued operation for: \(installedApp.bundleIdentifier)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processRestoreAppOperation(operation, group: group)
            }
        }
        return group
    }
    
    // MARK: - Sideload (.ipa) -
    func install(_ ipaURL: URL, presentingViewController: PresenterProvider, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { (results) in
                guard let (_, result) = results.first else { return }
                completionHandler(result)
            }
        )
        
        let bundleIdentifier = UUID().uuidString
        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            ipaURL: ipaURL,
            authenticatedContext: group.context
        )

        let progress = group.progress(for: bundleIdentifier)
        self.setInstallationProgress(progress, for: bundleIdentifier)

        let patchedApp = PatchedApplication(bundleIdentifier: bundleIdentifier, ipaURL: ipaURL)
        
        let operation = AppOperation(
            for: patchedApp,
            type: .sideload,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: { [weak self] in
                self?.setInstallationProgress(nil, for: bundleIdentifier)
            }
        )
        
        self.debugLog("[AppManager.install(ipaURL)]: Queued operation for ipaURL: \(ipaURL)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processInstallIpaOperation(operation, group: group)
            }
        }
        return group
    }
    
    // MARK: -Updating -
    @discardableResult
    func update<T: AppProtocol>(_ app: T, presentingViewController: PresenterProvider, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let group = self.update([app], presentingViewController: presentingViewController) { (results) in
            guard let (_, result) = results.first else { return }
            completionHandler(result)
        }
        return group
    }
    
    @discardableResult
    private func update<T: AppProtocol>(_ apps: [T], presentingViewController: PresenterProvider, completionHandler: @escaping ([String: Result<InstalledApp, Error>]) -> Void) -> RefreshGroup
    {
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: completionHandler
        )
        
        let operations = apps.map { app in
            let bundleIdentifier = app.bundleIdentifier
            
            let context = InstallAppOperationContext(
                bundleIdentifier: bundleIdentifier,
                authenticatedContext: group.context
            )

            let progress = group.progress(for: bundleIdentifier)
            self.setInstallationProgress(progress, for: bundleIdentifier)
            
            return AppOperation(
                for: app,
                type: .update,
                context: context,
                progress: progress,
                group: group,
                preAction: {},
                postAction: { [weak self] in
                    self?.setInstallationProgress(nil, for: bundleIdentifier)
                }
            )
        }
        
        self.debugLog("[AppManager.update]: Queued operations count: \(operations.count)")

        let sortedOperations = operations.sorted { (a, b) in
            func isAltStoreAppID(_ id: String) -> Bool {
                return id == StoreApp.altstoreAppID || id == Bundle.main.bundleIdentifier
            }

            let aIsAltStore = isAltStoreAppID(a.app.bundleIdentifier)
            let bIsAltStore = isAltStoreAppID(b.app.bundleIdentifier)
            if aIsAltStore != bIsAltStore
            {
                // SideStore should ALWAYS BE DONE LAST because it'll close the app on update
                return bIsAltStore
            }
            
            guard let appA = a.app as? InstalledApp, let appB = b.app as? InstalledApp else { return false }
            if appA.refreshedDate != appB.refreshedDate
            {
                return appA.refreshedDate < appB.refreshedDate
            }
            
            return appA.bundleIdentifier < appB.bundleIdentifier
        }

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processUpdateAppOperations(sortedOperations, group: group)
            }
        }
        return group
    }

    // MARK: - Uninstallation -
    func remove(_ installedApp: InstalledApp, includeBackup: Bool = false, presentingViewController: PresenterProvider, completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { results in
                guard let result = results[bundleIdentifier] else { return }
                switch result {
                case .success:
                    completionHandler(.success(()))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        )

        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )
        context.includeBackupData = includeBackup

        let progress = group.progress(for: bundleIdentifier)

        let operation = AppOperation(
            for: installedApp,
            type: .remove,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: {}
        )

        self.debugLog("[AppManager.remove]: Queued operation for: \(bundleIdentifier), includeBackup: \(includeBackup)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processRemoveAppOperation(operation, group: group)
            }
        }
    }

    func uninstall(_ installedApp: InstalledApp, includeBackup: Bool = false, presentingViewController: PresenterProvider, completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { results in
                guard let result = results[bundleIdentifier] else { return }
                switch result {
                case .success:
                    completionHandler(.success(()))
                case .failure(let error):
                    completionHandler(.failure(error))
                }
            }
        )

        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )
        context.includeBackupData = includeBackup

        let progress = group.progress(for: bundleIdentifier)

        let operation = AppOperation(
            for: installedApp,
            type: .uninstall,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: {}
        )

        self.debugLog("[AppManager.uninstall]: Queued operation for: \(bundleIdentifier), includeBackup: \(includeBackup)")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processUninstallAppOperation(operation, group: group)
            }
        }
    }

    // MARK: - Change App Icon -
    @discardableResult
    func changeIcon(for installedApp: InstalledApp, to iconURL: URL?, presentingViewController: PresenterProvider, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { results in
                guard let result = results[bundleIdentifier] else { return }
                completionHandler(result)
            }
        )

        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )
        context.alternateIconMode = iconURL.map { .set($0) } ?? .remove

        let progress = group.progress(for: bundleIdentifier)
        self.setRefreshProgress(progress, for: bundleIdentifier)

        let operation = AppOperation(
            for: installedApp,
            type: .changeIcon,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: { [weak self] in
                self?.setRefreshProgress(nil, for: bundleIdentifier)
            }
        )

        self.debugLog("[AppManager.changeIcon]: Queued operation for: \(bundleIdentifier), iconURL: \(String(describing: iconURL))")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processChangeAppIconOperation(operation, group: group)
            }
        }
        return group
    }

    // MARK: - Update Certificate -
    @discardableResult
    func updateCertificate(for installedApp: InstalledApp, to certificate: ALTCertificate?, presentingViewController: PresenterProvider, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> RefreshGroup
    {
        let bundleIdentifier = installedApp.bundleIdentifier
        let group = RefreshGroup(
            context: OperationContext(handler: OperationContextHandler(presenterProvider: presentingViewController)),
            completionHandler: { results in
                guard let result = results[bundleIdentifier] else { return }
                completionHandler(result)
            }
        )

        let context = InstallAppOperationContext(
            bundleIdentifier: bundleIdentifier,
            installedApp: installedApp,
            authenticatedContext: group.context
        )
        context.overrideSigningCertificate = certificate

        let progress = group.progress(for: bundleIdentifier)
        self.setRefreshProgress(progress, for: bundleIdentifier)

        let operation = AppOperation(
            for: installedApp,
            type: .updateCertificate,
            context: context,
            progress: progress,
            group: group,
            preAction: {},
            postAction: { [weak self] in
                self?.setRefreshProgress(nil, for: bundleIdentifier)
            }
        )

        self.debugLog("[AppManager.updateCertificate]: Queued operation for: \(bundleIdentifier), certificate: \(certificate?.serialNumber ?? "default (Team's active)")")

        Task {
            await self.serializer.enqueue {
                await PipelineRunner.shared.processUpdateAppCertificateOperation(operation, group: group)
            }
        }
        return group
    }

    // MARK: - Clear App Cache -
    func clearAppCache(completionHandler: @escaping (Result<[String], Error>) -> Void)
    {
        self.debugLog("[AppManager.clearAppCache]: Starting cache clear")
        Task {
            await self.serializer.enqueue {
                let result = await PipelineRunner.shared.clearAppCache()
                await MainActor.run {
                    completionHandler(result)
                }
            }
        }
    }

    // MARK: - Sync AppIDs -
    func syncAppIDs(presentingViewController: PresenterProvider? = nil, completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        self.debugLog("[AppManager.syncAppIDs]: Starting AppID sync")
        let handler = OperationContextHandler(presenterProvider: presentingViewController)
        let context = StandaloneOperationContext(handler: handler)
        Task {
            await self.serializer.enqueue {
                let result = await PipelineRunner.shared.syncAppIDs(context: context)
                await MainActor.run {
                    completionHandler(result)
                }
            }
        }
    }

    // MARK: - Enable JIT -
    func enableJIT(for installedApp: InstalledApp, presentingViewController: PresenterProvider? = nil, completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let appName = context.performAndWait { installedApp.name }
        self.debugLog("[AppManager.enableJIT]: Enabling JIT for \(appName)")

        let handler = OperationContextHandler(presenterProvider: presentingViewController)
        let opContext = StandaloneOperationContext(handler: handler)
        
        Task {
            let result = await PipelineRunner.shared.enableJIT(for: installedApp, context: opContext)
            let mappedResult = self.getMappedError(for: installedApp, result: result, in: context)
            await MainActor.run {
                completionHandler(mappedResult)
            }
        }
    }
    
    private func getMappedError<T>(for installedApp: InstalledApp, result: Result<T, Error>, in context: NSManagedObjectContext) -> Result<T, Error>
    {
        return result.mapError { error in
            let appName = context.performAndWait {
                let installedApp = context.object(with: installedApp.objectID) as! InstalledApp
                return installedApp.name
            }
            
            switch error
            {
            case VerificationError.ResourceNotFound(let resource):
                switch resource
                {
                case .Application: return OperationError.appNotFound(name: appName)
                case .DeveloperDiskImage: return error
                }
                
            default: return error
            }
        }
    }
    
    // MARK: - Sources (Đã tối ưu hóa - Ngắt tải nguồn JSON ngầm vì Tab Nguồn nay là Tab Sửa Lỗi độc lập) -
    @discardableResult
    func updateAllSources() async -> Result<Void, Error> {
        return .success(())
    }

    func updateAllSources(completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        completionHandler(.success(()))
    }
    
    func fetchSource(sourceURL: URL) async throws -> (Source, NSManagedObjectContext) {
        let context = StandaloneOperationContext()
        let operation = try FetchSourceOperation(sourceURL: sourceURL, context: context)
        let source = try await operation.execute()
        guard let managedObjectContext = source.managedObjectContext else {
            throw OperationError.noSources
        }
        return (source, managedObjectContext)
    }
    
    func fetchSources(completion: @escaping (Result<Set<Source>, Error>) -> Void) -> Progress
    {
        let progress = Progress.discreteProgress(totalUnitCount: 1)
        progress.completedUnitCount = 1
        DispatchQueue.main.async {
            completion(.success([]))
        }
        return progress
    }

    // MARK: - Background Refresh -
    func backgroundRefresh(_ apps: [InstalledApp], PresentingViewController presenter: PresenterProvider? = nil, completionHandler: @escaping ([String: Result<InstalledApp, Error>]) -> Void)
    {
        self.debugLog("[AppManager.backgroundRefresh]: Starting background refresh for \(apps.count) apps")
        let handler = OperationContextHandler(presenterProvider: presenter)
        let context = StandaloneOperationContext(isBackgroundRefresh: true, handler: handler)
        Task {
            await self.serializer.enqueue {
                let results = await PipelineRunner.shared.backgroundRefresh(apps, context: context)
                await MainActor.run {
                    completionHandler(results)
                }
            }
        }
    }

    // MARK: - Authenticate -
    func authenticate(presentingViewController: PresenterProvider?, isRefresh: Bool = false, completionHandler: @escaping (Result<(ALTTeam, ALTCertificate, String), Error>) -> Void)
    {
        self.debugLog("[AppManager.authenticate]: Starting authentication (isRefresh: \(isRefresh))")
        let handler = OperationContextHandler(presenterProvider: presentingViewController)
        let context = StandaloneOperationContext(handler: handler)
        Task {
            await self.serializer.enqueue {
                let result = await PipelineRunner.shared.authenticate(context: context)
                await MainActor.run {
                    completionHandler(result)
                }
            }
        }
    }

    // MARK: -Import Account -
    @MainActor
    func importAccount(_ importedAccount: ImportedAccount, presentingViewController: UIViewController?) async -> Result<(Team, ALTCertificate), Error>
    {
        do {
            let result = try await AuthManager.shared.importAccount(importedAccount)
            NotificationCenter.default.post(name: .AppManagerDidImportAccount, object: self)
            return .success(result)
        } catch {
            return .failure(error)
        }
    }

    // MARK: - Progress -
    func installationProgress<T: AppProtocol>(for app: T) -> Progress?
    {
        return self.installationProgress(for: app.bundleIdentifier)
    }

    func installationProgress(for bundleIdentifier: String) -> Progress?
    {
        return self.progressQueue.sync {
            return self._installationProgress[bundleIdentifier]
        }
    }

    fileprivate func setInstallationProgress(_ progress: Progress?, for bundleIdentifier: String)
    {
        self.progressQueue.sync {
            self._installationProgress[bundleIdentifier] = progress
        }

        if progress != nil
        {
            NotificationCenter.default.post(name: .AppManagerDidAddInstallationProgress, object: self, userInfo: [AnyHashable("bundleIdentifier"): bundleIdentifier])
        }
    }

    func refreshProgress<T: AppProtocol>(for app: T) -> Progress?
    {
        return self.refreshProgress(for: app.bundleIdentifier)
    }

    func refreshProgress(for bundleIdentifier: String) -> Progress?
    {
        return self.progressQueue.sync {
            return self._refreshProgress[bundleIdentifier]
        }
    }

    fileprivate func setRefreshProgress(_ progress: Progress?, for bundleIdentifier: String)
    {
        self.progressQueue.sync {
            self._refreshProgress[bundleIdentifier] = progress
        }
    }
}

private extension AppManager
{
    @objc func willEnterForeground(_ notification: Notification)
    {
        guard DatabaseManager.shared.isStarted else { return }
        
        // Update known sources (Đã được tối ưu trả về ngay lập tức trong 0ms ở UpdateKnownSourcesOperation)
        Task {
            do {
                let (_, blockedSources) = try await UpdateKnownSourcesOperation().execute()
                await Source.deactivateApps(from: blockedSources)
            } catch {
                self.errorLog("Failed to update known sources. \(error.localizedDescription)")
            }
        }
    }
}
