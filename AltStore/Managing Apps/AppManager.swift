
//
//  AppManager.swift
//  AltStore
//
//  Created by Riley Testut on 5/29/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import CoreData
import MobileCoreServices
import Combine
import UIKit
import UniformTypeIdentifiers

import AltStoreCore
import SideSign
import Minimuxer
import SemanticVersion

import Roxas

extension AppManager
{
    static let didInstallAppNotification = Notification.Name("com.altstore.AppManager.didInstallApp")
    static let didImportAppNotification = Notification.Name("com.altstore.AppManager.didImportApp")
    static let didEnterServerHexURLNotification = Notification.Name("com.altstore.AppManager.didEnterServerHexURL")
}

final class AppManager: NSObject
{
    static let shared = AppManager()

    private var _pipelineRunner = PipelineRunner()
    
    @Published
    private(set) var installationProgress = [String: Progress]()
    
    @Published
    private(set) var refreshProgress = [String: Progress]()
    
    // TỐI ƯU 1: Dùng NSLock siêu nhẹ ở tầng thấp thay cho DispatchQueue.sync để không bao giờ gây khựng Main Thread
    private let progressLock = NSLock()
    private let operationQueue = OperationQueue()
    
    private var cancellables = Set<AnyCancellable>()
    private var sourceUpdateCancellable: AnyCancellable?
    
    private override init()
    {
        super.init()
        
        self.operationQueue.name = "com.altstore.AppManager.operationQueue"
        // Giới hạn tác vụ chạy song song và ép chạy trên nhân tiết kiệm điện (Utility) để máy không bị nóng
        self.operationQueue.qualityOfService = .utility
        self.operationQueue.maxConcurrentOperationCount = 4
        
        // TỐI ƯU 2: Dùng .removeDuplicates() để chỉ cập nhật trạng thái khi danh sách BundleID thực sự thay đổi,
        // tuyệt đối không quét RAM hàng trăm lần mỗi giây khi thanh phần trăm Progress nhảy.
        self.$refreshProgress
            .map { Set($0.keys) }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { bundleIDs in
                for obj in DatabaseManager.shared.viewContext.registeredObjects {
                    guard let installedApp = obj as? InstalledApp else { continue }
                    let isRefreshing = bundleIDs.contains(installedApp.bundleIdentifier)
                    if installedApp.isRefreshing != isRefreshing {
                        installedApp.isRefreshing = isRefreshing
                    }
                }
            }
            .store(in: &self.cancellables)
    }
    
    func clearOperationCaches() {
        let context = OperationContext()
        do {
            try FileManager.default.removeItem(at: context.temporaryDirectory)
        } catch {}
    }
}

extension AppManager
{
    func update()
    {
        guard let installedApp = InstalledApp.fetchAltStore(in: DatabaseManager.shared.viewContext), let storeApp = installedApp.storeApp else { return }
        
        self.install(storeApp, presentingViewController: nil) { _ in }
    }
    
    @discardableResult
    func install(_ app: AppProtocol, presentingViewController: UIViewController?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> Progress
    {
        let group = InstallAppOptions()
        return self.install(
            [app],
            presentingViewController: presentingViewController,
            group: group) { (results) in
            guard let (_, result) = results.first else { return }
            completionHandler(result)
        }
    }
    
    @discardableResult
    func activate(_ installedApp: InstalledApp, presentingViewController: UIViewController?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> Progress
    {
        let group = InstallAppOptions()
        group.isActivating = true
        
        return self.install([installedApp], presentingViewController: presentingViewController, group: group) { (results) in
            guard let (_, result) = results.first else { return }
            completionHandler(result)
        }
    }
    
    @discardableResult
    func deactivate(_ installedApp: InstalledApp, presentingViewController: UIViewController?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> Progress
    {
        let group = DeactivateAppOperationGroup()
        let pipeline = PipelineFactory.deactivatePipeline()
        
        Task {
            await self._pipelineRunner.execute(
                apps: [installedApp],
                pipeline: pipeline,
                group: group,
                presentingViewController: presentingViewController,
                completionHandler: { results in
                    guard let (_, result) = results.first else { return }
                    completionHandler(result)
                }
            )
        }
        return group.progress
    }
    
    @discardableResult
    func backup(_ installedApp: InstalledApp, presentingViewController: UIViewController?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> Progress
    {
        let group = BackupRestoreAppOperationGroup()
        let pipeline = PipelineFactory.backupPipeline()
        
        Task {
            await self._pipelineRunner.execute(
                apps: [installedApp],
                pipeline: pipeline,
                group: group,
                presentingViewController: presentingViewController,
                completionHandler: { results in
                    guard let (_, result) = results.first else { return }
                    completionHandler(result)
                }
            )
        }
        return group.progress
    }
    
    @discardableResult
    func restore(_ installedApp: InstalledApp, presentingViewController: UIViewController?, completionHandler: @escaping (Result<InstalledApp, Error>) -> Void) -> Progress
    {
        let group = BackupRestoreAppOperationGroup()
        let pipeline = PipelineFactory.restorePipeline()
        
        Task {
            await self._pipelineRunner.execute(
                apps: [installedApp],
                pipeline: pipeline,
                group: group,
                presentingViewController: presentingViewController,
                completionHandler: { results in
                    guard let (_, result) = results.first else { return }
                    completionHandler(result)
                }
            )
        }
        return group.progress
    }

    @discardableResult
    func remove(_ installedApp: InstalledApp, presentingViewController: UIViewController? = nil, completionHandler: @escaping (Result<Void, Error>) -> Void) -> Progress
    {
        let group = RemoveAppOperationGroup()
        let pipeline = PipelineFactory.removePipeline()
        
        Task {
            await self._pipelineRunner.execute(
                apps: [installedApp],
                pipeline: pipeline,
                group: group,
                presentingViewController: presentingViewController,
                completionHandler: { results in
                    guard let (_, result) = results.first else { return }
                    completionHandler(result)
                }
            )
        }
        return group.progress
    }
    
    @discardableResult
    func refresh(_ installedApps: [InstalledApp], presentingViewController: UIViewController?, group: RefreshAppOptions = RefreshAppOptions(), completionHandler: @escaping ([String : Result<InstalledApp, Error>]) -> Void) -> RefreshAppOptions
    {
        group.isRefreshing = true
        let pipeline = PipelineFactory.refreshPipeline(group: group)
        
        Task {
            await self._pipelineRunner.execute(
                apps: installedApps,
                pipeline: pipeline,
                group: group,
                presentingViewController: presentingViewController,
                completionHandler: completionHandler
            )
        }
        return group
    }
    
    func enableJIT(for installedApp: InstalledApp, completionHandler: @escaping (Result<Void, Error>) -> Void)
    {
        let context = OperationContext()
        context.bundleIdentifier = installedApp.bundleIdentifier
        
        let backgroundContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let fetchOperation = FetchInstalledAppsOperation(bundleIdentifiers: [installedApp.bundleIdentifier], context: context, managedObjectContext: backgroundContext)
        let enableJITOperation = EnableJITOperation(context: context)
        enableJITOperation.addDependency(fetchOperation)
        
        enableJITOperation.resultHandler = { result in
            DispatchQueue.main.async {
                completionHandler(result)
            }
        }
        
        self.operationQueue.addOperations([fetchOperation, enableJITOperation], waitUntilFinished: false)
    }

    func updatePatreonAccounts(PresentingViewController: UIViewController? = nil, completion: @escaping (Result<Void, Error>) -> Void)
    {
        let operation = UpdatePatreonAccountsOperation()
        operation.resultHandler = { result in
            completion(result)
        }
        
        self.operationQueue.addOperation(operation)
    }

    func refreshKnownSources(completion: @escaping (Result<([Source], [KnownSource]), Error>) -> Void)
    {
        let operation = FetchKnownSourcesOperation()
        operation.resultHandler = { result in
            completion(result)
        }
        
        self.operationQueue.addOperation(operation)
    }
    
    func syncAppIDs(presentingViewController: UIViewController? = nil) async throws
    {
        let context = OperationContext()
        context.presentingViewController = presentingViewController

        let operation = SyncAppIDsOperation(context: context)

        return try await withCheckedThrowingContinuation { continuation in
            operation.resultHandler = { result in
                continuation.resume(with: result)
            }
            self.operationQueue.addOperation(operation)
        }
    }
    
    func updateAllSources(completion: @escaping (Result<Void, Error>) -> Void)
    {
        // TỐI ƯU 3: Hạ priority từ .userInitiated xuống .utility để chip xử lý trên nhân tiết kiệm điện (E-core), giảm nóng máy khi tải nhiều nguồn
        Task<Void, Never>.detached(priority: .utility) {
            do
            {
                async let blockedSourcesResult = self.fetchSourcelist(for: .blocked)
                async let recommendedSourcesResult = self.fetchSourcelist(for: .recommended)
                
                var fetchErrors = [Error]()
                
                let blockedSources: [KnownSource]?
                do {
                    blockedSources = try await blockedSourcesResult
                } catch {
                    blockedSources = nil
                    fetchErrors.append(error)
                }
                
                let recommendedSources: [KnownSource]?
                do {
                    recommendedSources = try await recommendedSourcesResult
                } catch {
                    recommendedSources = nil
                    fetchErrors.append(error)
                }
                
                try await self.updateSources(blockedSources: blockedSources, recommendedSources: recommendedSources)
                
                if let error = fetchErrors.first
                {
                    throw error
                }
                
                await MainActor.run {
                    completion(.success(()))
                }
            }
            catch
            {
                await MainActor.run {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func fetchSource(sourceURL: URL) async throws -> (Source, NSManagedObjectContext)
    {
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        
        let fetchSourcesOperation = FetchSourceOperation(sourceURL: sourceURL, managedObjectContext: context)
        let source = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Source, Error>) in
            fetchSourcesOperation.resultHandler = { result in
                continuation.resume(with: result)
            }
            
            self.operationQueue.addOperation(fetchSourcesOperation)
        }
        
        return (source, context)
    }
    
    @MainActor
    func add(source: Source, message: String?, presentingViewController: UIViewController) async throws -> Bool
    {
        guard let context = source.managedObjectContext else { return false }
        let sourceURL = source.sourceURL
        
        let blockedSources = try? await self.fetchSourcelist(for: .blocked)
        if let blockedSources, !blockedSources.isEmpty
        {
            let matchingBlockedSource = try await context.perform { () -> KnownSource? in
                let blockedSource = blockedSources.first { blockedSource in
                    if let sourceID = blockedSource.identifier, sourceID == source.identifier
                    {
                        return true
                    }
                    else if let blockedSourceURL = blockedSource.sourceURL, blockedSourceURL.Normalized() == sourceURL.Normalized()
                    {
                        return true
                    }
                    return false
                }
                return blockedSource
            }
            
            if let matchingBlockedSource
            {
                throw OperationError.blockedSource(sourceName: source.name, reason: matchingBlockedSource.reason)
            }
        }
        
        let existingSource = try await DatabaseManager.shared.viewContext.perform {
            let predicate = NSPredicate(format: "%K == %@ OR %K == %@",
                                        #keyPath(Source.identifier), source.identifier,
                                        #keyPath(Source.sourceURL), source.sourceURL as CVarArg)
            let existingSource = Source.first(satisfying: predicate, in: DatabaseManager.shared.viewContext)
            return existingSource
        }
        guard existingSource == nil else { throw SourceError.duplicate(source, existingSource: existingSource!) }
        
        let addSourcePreviewViewController = UIStoryboard(name: "Browse", bundle: nil).instantiateViewController(identifier: "addSourcePreviewNavigationController") { (coder) -> UIViewController? in
            let previewViewController = AddSourcePreviewViewController(source: source, message: message, coder: coder)
            return previewViewController
        }
        presentingViewController.present(addSourcePreviewViewController, animated: true)

        var cancellable: AnyCancellable?
        defer { cancellable?.cancel() }
        
        let shouldAddSource = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            let previewViewController = (addSourcePreviewViewController as! UINavigationController).viewControllers.first as! AddSourcePreviewViewController
            previewViewController.completionHandler = { shouldAddSource in
                continuation.resume(returning: shouldAddSource)
            }
            
            cancellable = NotificationCenter.default.publisher(for: UIPresentationController.dismissalTransitionDidEndNotification, object: addSourcePreviewViewController)
                .sink { (notification) in
                    guard let presentationController = notification.object as? UIPresentationController, presentationController.presentedViewController == addSourcePreviewViewController else { return }
                    guard addSourcePreviewViewController.presentingViewController == nil else { return }
                    
                    continuation.resume(returning: false)
                }
        }
        
        if presentedViewController(for: presentingViewController) == addSourcePreviewViewController
        {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                presentingViewController.dismiss(animated: true) {
                    continuation.resume()
                }
            }
        }
        
        guard shouldAddSource else { return false }
        
        try await context.perform {
            try context.save()
        }
        
        return true
    }
    
    func remove(_ source: Source) async throws
    {
        let sourceID = await DatabaseManager.shared.viewContext.perform { source.identifier }
        
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        try await context.perform {
            guard let source = Source.first(satisfying: NSPredicate(format: "%K == %@", #keyPath(Source.identifier), sourceID), in: context) else { return }
            
            for app in source.apps
            {
                app.source = nil
                app.sourceIdentifier = nil
                
                if app.installedApp == nil
                {
                    context.delete(app)
                }
            }
            
            for newsItem in source.newsItems
            {
                newsItem.source = nil
                newsItem.sourceIdentifier = nil
                
                context.delete(newsItem)
            }
            
            context.delete(source)
            
            try context.save()
        }
    }
}

private extension AppManager
{
    @discardableResult
    func install<T: AppProtocol>(_ apps: [T], presentingViewController: UIViewController?, group: InstallAppOptions = InstallAppOptions(), completionHandler: @escaping ([String : Result<InstalledApp, Error>]) -> Void) -> Progress
    {
        group.isRefreshing = false
        let pipeline = PipelineFactory.installPipeline(group: group)
        
        Task {
            await self._pipelineRunner.execute(
                apps: apps,
                pipeline: pipeline,
                group: group,
                presentingViewController: presentingViewController,
                completionHandler: completionHandler
            )
        }
        return group.progress
    }
}

extension AppManager {
    enum AppArchiveKind {
        case ipa
        case appBundle(URL)
    }

    struct AppMetadata {
        let name: String
        let bundleIdentifier: String
        let version: String
        let archiveKind: AppArchiveKind
    }

    func readAppMetadata(from url: URL) throws -> AppMetadata {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "ipa":
            let reader = try ZipReader(url: url)

            var appDirectoryName: String?
            var foundPlistData: Data?

            while let entry = try reader.goToNextFile() {
                let path = entry.path

                guard path.hasPrefix("Payload/"), path.hasSuffix("/Info.plist") else {
                    continue
                }

                let components = path.split(separator: "/")
                guard components.count == 3, components[1].hasSuffix(".app") else {
                    continue
                }

                appDirectoryName = String(components[1])
                foundPlistData = try reader.readCurrentFile()
                break
            }

            guard let plistData = foundPlistData else {
                throw ALTError(.invalidApp)
            }

            let plistObj = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)
            guard let plist = plistObj as? [String: Any] else {
                throw ALTError(.invalidApp)
            }

            guard let bundleID = plist[kCFBundleIdentifierKey as String] as? String else {
                throw ALTError(.missingInfoPlist)
            }

            let displayName = (plist["CFBundleDisplayName"] as? String)
                ?? (plist[kCFBundleNameKey as String] as? String)
                ?? (appDirectoryName as NSString?)?.deletingPathExtension
                ?? url.deletingPathExtension().lastPathComponent

            let version = (plist["CFBundleShortVersionString"] as? String)
                ?? (plist[kCFBundleVersionKey as String] as? String)
                ?? "0"

            return AppMetadata(
                name: displayName,
                bundleIdentifier: bundleID,
                version: version,
                archiveKind: .ipa
            )

        case "app":
            let infoPlistURL = url.appendingPathComponent("Info.plist")
            let data = try Data(contentsOf: infoPlistURL)

            let plistObj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let plist = plistObj as? [String: Any] else {
                throw ALTError(.invalidApp)
            }

            guard let bundleID = plist[kCFBundleIdentifierKey as String] as? String else {
                throw ALTError(.missingInfoPlist)
            }

            let displayName = (plist["CFBundleDisplayName"] as? String)
                ?? (plist[kCFBundleNameKey as String] as? String)
                ?? url.deletingPathExtension().lastPathComponent

            let version = (plist["CFBundleShortVersionString"] as? String)
                ?? (plist[kCFBundleVersionKey as String] as? String)
                ?? "0"

            return AppMetadata(
                name: displayName,
                bundleIdentifier: bundleID,
                version: version,
                archiveKind: .appBundle(url)
            )

        default:
            throw ALTError(.invalidApp)
        }
    }
    
    func importApp(from url: URL,
                   in context: NSManagedObjectContext,
                   mode: AppImportSourceMode = UserDefaults.standard.appImportSourceMode) async throws -> StoreApp {

        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let metadata = try readAppMetadata(from: url)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let importsDir = docs.appendingPathComponent("Imports", isDirectory: true)
        try FileManager.default.createDirectory(at: importsDir, withIntermediateDirectories: true)

        let baseName = "\(metadata.bundleIdentifier)-\(metadata.version)"
        let destIPAURL = importsDir.appendingPathComponent(baseName).appendingPathExtension("ipa")

        if FileManager.default.fileExists(atPath: destIPAURL.path) {
            try FileManager.default.removeItem(at: destIPAURL)
        }

        switch metadata.archiveKind {
        case .ipa:
            try FileManager.default.copyItem(at: url, to: destIPAURL)

        case .appBundle(let appBundleURL):
            let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempRoot) }

            let payloadDir = tempRoot.appendingPathComponent("Payload", isDirectory: true)
            try FileManager.default.createDirectory(at: payloadDir, withIntermediateDirectories: true)

            let destAppDir = payloadDir.appendingPathComponent(appBundleURL.lastPathComponent, isDirectory: true)
            try FileManager.default.copyItem(at: appBundleURL, to: destAppDir)

            let zippedIPA = try FileManager.default.zipAppBundle(at: payloadDir)
            try FileManager.default.moveItem(at: zippedIPA, to: destIPAURL)
        }

        let storeApp: StoreApp = try await context.perform {
            let source = try Source.fetchOrCreateImportsSource(in: context)

            let appPredicate = NSPredicate(
                format: "%K == %@ AND %K == %@",
                #keyPath(StoreApp.bundleIdentifier), metadata.bundleIdentifier,
                #keyPath(StoreApp.sourceIdentifier), Source.importsIdentifier
            )

            let storeApp: StoreApp
            if let existing = StoreApp.first(satisfying: appPredicate, in: context) {
                storeApp = existing
            } else {
                storeApp = StoreApp(context: context)
                storeApp.bundleIdentifier = metadata.bundleIdentifier
                storeApp.sourceIdentifier = Source.importsIdentifier
                storeApp.source = source

                storeApp.developerName = "Imported"
                storeApp.localizedDescription = "Locally imported IPA."
                storeApp.subtitle = "Imported IPA"
            }

            storeApp.name = metadata.name

            let versionString = metadata.version
            let buildVersion = "1"

            let versionPredicate = NSPredicate(
                format: "%K == %@ AND %K == %@ AND %K == %@ AND %K == %@",
                #keyPath(AppVersion.appBundleID), metadata.bundleIdentifier,
                #keyPath(AppVersion.sourceID), Source.importsIdentifier,
                #keyPath(AppVersion.version), versionString,
                #keyPath(AppVersion.buildVersion), buildVersion
            )

            let appVersion: AppVersion
            if let existingVersion = AppVersion.first(satisfying: versionPredicate, in: context) {
                appVersion = existingVersion
            } else {
                appVersion = AppVersion(context: context)
                appVersion.appBundleID = metadata.bundleIdentifier
                appVersion.sourceID = Source.importsIdentifier
                appVersion.version = versionString
                appVersion.buildVersion = buildVersion
                appVersion.date = Date()
                appVersion.app = storeApp
            }

            appVersion.downloadURL = destIPAURL
            if let attrs = try? FileManager.default.attributesOfItem(atPath: destIPAURL.path),
               let fileSize = attrs[.size] as? NSNumber {
                appVersion.size = fileSize.int64Value
            }

            let versions = storeApp.mutableOrderedSetValue(forKey: #keyPath(StoreApp.versions))
            if !versions.contains(appVersion) {
                versions.add(appVersion)
            }

            return storeApp
        }

        return storeApp
    }
}

extension AppManager {
    // TỐI ƯU 4: Chuyển sang cơ chế kiểm tra UTType nội bộ siêu nhẹ (như File 1),
    // Loại bỏ hoàn toàn FetchInstalledAppsOperation (vốn phải bật kết nối Minimuxer/VPN gây hao pin và nóng máy lúc mở app).
    func reconcileInstalledApps() async {
        let isBusy = self.progressLock.withLock {
            !self.installationProgress.isEmpty || !self.refreshProgress.isEmpty
        }
        guard !isBusy else { return }

        #if !targetEnvironment(simulator)
        do {
            let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            try await context.perform {
                let dbApps = InstalledApp.all(in: context)
                for app in dbApps {
                    if app.bundleIdentifier == StoreApp.altstoreAppID { continue }
                    guard app.isActive else { continue }
                    
                    let isBeingManaged = self.progressLock.withLock {
                        self.installationProgress.keys.contains(app.bundleIdentifier) ||
                        self.refreshProgress.keys.contains(app.bundleIdentifier)
                    }
                    guard !isBeingManaged else { continue }
                    
                    let isDeclared = UTType(app.installedAppUTI)?.isDeclared ?? false
                    if !isDeclared {
                        for appExtension in app.appExtensions {
                            context.delete(appExtension)
                        }
                        context.delete(app)
                        try? FileManager.default.removeItem(at: app.fileURL)
                        try? FileManager.default.removeItem(at: app.refreshedIPAURL)
                    }
                }
                
                if context.hasChanges {
                    try context.save()
                }
            }
        } catch {}
        #endif
    }
}

private extension AppManager
{
    private func presentedViewController(for viewController: UIViewController) -> UIViewController?
    {
        var presentedViewController = viewController.presentedViewController
        while let nextPresentedViewController = presentedViewController?.presentedViewController
        {
            presentedViewController = nextPresentedViewController
        }
        
        return presentedViewController
    }
    
    func fetchSourcelist(for listType: FetchSourcelistOperation.ListType) async throws -> [KnownSource]
    {
        let fetchSourcelistOperation = FetchSourcelistOperation(type: listType)
        
        let sources = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[KnownSource], Error>) in
            fetchSourcelistOperation.resultHandler = { result in
                continuation.resume(with: result)
            }
            
            self.operationQueue.addOperation(fetchSourcelistOperation)
        }
        
        return sources
    }
    
    func updateSources(blockedSources: [KnownSource]?, recommendedSources: [KnownSource]?) async throws
    {
        let context = DatabaseManager.shared.persistentContainer.newBackgroundContext()
        let sourceURLs = await context.perform {
            let sources = Source.all(in: context)
            return sources.map { $0.sourceURL }
        }
        
        let fetchSourcesOperation = FetchSourcesOperation(sourceURLs: sourceURLs, managedObjectContext: context)
        let fetchedSourcesResult = await withCheckedContinuation { (continuation: CheckedContinuation<Result<[URL: Source], Error>, Never>) in
            fetchSourcesOperation.resultHandler = { result in
                continuation.resume(returning: result)
            }
            
            self.operationQueue.addOperation(fetchSourcesOperation)
        }
        
        try await context.perform {
            let fetchedSources = try fetchedSourcesResult.get()
            
            var sourcesByID = [String: Source]()
            var sourcesByNormalizedURL = [String: Source]()
            for (sourceURL, source) in fetchedSources
            {
                sourcesByID[source.identifier] = source
                sourcesByNormalizedURL[sourceURL.Normalized()] = source
            }
            
            if let blockedSources, !blockedSources.isEmpty
            {
                for blockedSource in blockedSources
                {
                    let source = blockedSource.identifier.flatMap { sourcesByID[$0] } ?? blockedSource.sourceURL.flatMap { sourcesByNormalizedURL[$0.Normalized()] }
                    guard let source else { continue }
                    
                    source.managedObjectContext?.delete(source)
                    
                    for app in source.apps where app.installedApp != nil
                    {
                        app.source = nil
                        app.sourceIdentifier = nil
                    }
                    
                    let existingApps = StoreApp.all(satisfying: NSPredicate(format: "%K == %@", #keyPath(StoreApp.sourceIdentifier), source.identifier), in: context)
                    for app in existingApps where app.installedApp != nil
                    {
                        app.source = nil
                        app.sourceIdentifier = nil
                    }
                }
            }
            
            if let recommendedSources
            {
                for recommendedSource in recommendedSources
                {
                    let source = recommendedSource.identifier.flatMap { sourcesByID[$0] } ?? recommendedSource.sourceURL.flatMap { sourcesByNormalizedURL[$0.Normalized()] }
                    source?.isRecommended = true
                }
            }
            
            let sources = Source.all(in: context)
            var existingSourcesByID = Dictionary(grouping: sources, by: { $0.identifier }).compactMapValues { $0.first }
            
            for (_, fetchedSource) in fetchedSources where !fetchedSource.isDeleted
            {
                guard let existingSource = existingSourcesByID[fetchedSource.identifier] else { continue }
                
                for app in existingSource.apps where !fetchedSource.apps.contains(app)
                {
                    app.source = nil
                    app.sourceIdentifier = nil
                    
                    if app.installedApp == nil
                    {
                        context.delete(app)
                    }
                }
                
                for newsItem in existingSource.newsItems where !fetchedSource.newsItems.contains(newsItem)
                {
                    newsItem.source = nil
                    newsItem.sourceIdentifier = nil
                    
                    context.delete(newsItem)
                }
                
                if existingSource != fetchedSource
                {
                    context.delete(existingSource)
                }
                
                existingSourcesByID[fetchedSource.identifier] = nil
            }
            
            for source in existingSourcesByID.values
            {
                guard let blockedSources else { continue }
                
                let isBlocked = blockedSources.contains { blockedSource in
                    if let sourceID = blockedSource.identifier, sourceID == source.identifier
                    {
                        return true
                    }
                    else if let sourceURL = blockedSource.sourceURL, sourceURL.Normalized() == source.sourceURL.Normalized()
                    {
                        return true
                    }
                    
                    return false
                }
                
                guard isBlocked else { continue }
                
                for app in source.apps
                {
                    app.source = nil
                    app.sourceIdentifier = nil
                    
                    if app.installedApp == nil
                    {
                        context.delete(app)
                    }
                }
                
                for newsItem in source.newsItems
                {
                    newsItem.source = nil
                    newsItem.sourceIdentifier = nil
                    
                    context.delete(newsItem)
                }
                
                context.delete(source)
            }
            
            if context.hasChanges {
                try context.save()
            }
            // TỐI ƯU 5: Đã xóa bỏ vòng lặp gọi `DatabaseManager.shared.viewContext.refresh(...)` trên toàn bộ Sources và Apps,
            // giúp tránh tình trạng đứng/khựng màn hình sau khi cập nhật nguồn xong.
        }
    }
}

extension AppManager
{
    func log(_ error: Error, operation: LoggedError.Operation, app: AppProtocol)
    {
        // ĐÃ TẮT HOÀN TOÀN: Không tạo Background Context của CoreData để ghi lỗi xuống ổ cứng SQLite nữa!
        return
    }

    func updateRefreshProgress(_ bundleID: String, progress: Progress?) {
        self.progressLock.withLock {
            self.refreshProgress[bundleID] = progress
        }
    }
    
    func getRefreshProgress(_ bundleID: String) -> Progress? {
        return self.progressLock.withLock {
            return self.refreshProgress[bundleID]
        }
    }
    
    func updateInstallationProgress(_ bundleID: String, progress: Progress?) {
        self.progressLock.withLock {
            self.installationProgress[bundleID] = progress
        }
    }
    
    func getInstallationProgress(_ bundleID: String) -> Progress? {
        return self.progressLock.withLock {
            return self.installationProgress[bundleID]
        }
    }
}
