
//
//  PipelineRunner.swift
//  AltStore
//
//  Created by SideStore Team.
//  Copyright © 2025 SideStore. All rights reserved.
//

import Foundation
import AltStoreCore
import Roxas
import minimuxer

@MainActor
final class PipelineRunner {
    static let shared = PipelineRunner()
    
    /// Thread-safe storage for active cancellation tasks keyed by operation UUID.
    private actor CancellationRegistry {
        private var tasks: [UUID: Task<Void, Never>] = [:]
        
        func register(_ task: Task<Void, Never>, for id: UUID) {
            tasks[id] = task
        }
        
        func cancelAll(for id: UUID) {
            tasks[id]?.cancel()
            tasks[id] = nil
        }
        
        func remove(for id: UUID) {
            tasks[id] = nil
        }
    }
    
    private let cancellationRegistry = CancellationRegistry()
    
    private init() {}
    
    func run(
        _ operation: AppOperation,
        in group: AppOperationGroup
    ) -> Progress {
        let operationProgress = Progress.discreteProgress(totalUnitCount: 0)
        operation.steps.forEach { step in
            let stepProgress = step.progress
            operationProgress.totalUnitCount += stepProgress.totalUnitCount
            operationProgress.addChild(stepProgress, withPendingUnitCount: stepProgress.totalUnitCount)
        }
        group.progress.addChild(operationProgress, withPendingUnitCount: 100)
        
        let operationID = operation.uuid
        let pipelineTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.performPipeline(for: operation, in: group, progress: operationProgress)
            await self?.cancellationRegistry.remove(for: operationID)
        }
        
        Task {
            await self.cancellationRegistry.register(pipelineTask, for: operationID)
        }
        
        operationProgress.cancellationHandler = { [weak self] in
            Task {
                await self?.cancellationRegistry.cancelAll(for: operationID)
            }
        }
        
        return operationProgress
    }
    
    // MARK: - Execution
    
    private func performPipeline(
        for operation: AppOperation,
        in group: AppOperationGroup,
        progress: Progress
    ) async {
        let context = AppOperationContext(
            bundleIdentifier: operation.app.bundleIdentifier,
            sharedContext: group.context,
            dbBackgroundContext: group.dbContext
        )
        
        if let app = operation.app as? InstalledApp {
            context.installedApp = app
            
            let dbContext = group.dbContext
            let (fingerprint, resignedID, customID, fileURL) = await dbContext.perform {
                if !app.useMainProfile {
                    app.useMainProfile = true
                }
                return (
                    app.appBundleFingerprint,
                    app.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                    app.customBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                    app.fileURL
                )
            }
            
            context.appBundleFingerprint = fingerprint
            // Ép cứng luôn dùng Profile của App chính, không bao giờ tạo thêm App ID cho Extensions khi Refresh
            context.useMainProfile = true
            
            // QUAN TRỌNG: Ưu tiên dùng chính xác resignedBundleIdentifier đang sống trên máy khi Refresh
            // để tuyệt đối không bị mất đuôi TeamID gây lỗi 9120!
            if !resignedID.isEmpty {
                context.customBundleIdentifier = resignedID
                context.appendTeamID = false
            } else if let customID, !customID.isEmpty {
                context.customBundleIdentifier = customID
                context.appendTeamID = true
            }
            
            context.targetAppBundle = ALTApplication(fileURL: fileURL)
        } else if let storeApp = operation.app as? StoreApp {
            let dbContext = group.dbContext
            let installedApp = await dbContext.perform {
                storeApp.installedApp
            }
            context.installedApp = installedApp
            if let installedApp {
                let (fingerprint, resignedID, customID) = await dbContext.perform {
                    if !installedApp.useMainProfile {
                        installedApp.useMainProfile = true
                    }
                    return (
                        installedApp.appBundleFingerprint,
                        installedApp.resignedBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines),
                        installedApp.customBundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                }
                context.appBundleFingerprint = fingerprint
                context.useMainProfile = true
                if !resignedID.isEmpty {
                    context.customBundleIdentifier = resignedID
                    context.appendTeamID = false
                } else {
                    context.customBundleIdentifier = customID
                }
                context.isStoreUpdate = true
            }
        }
        
        if let backupAction = operation.backupAction {
            context.backupOperationAction = backupAction
        }
        
        switch operation.type {
        case .install(let source):
            switch source {
            case .url(let url):
                context.sourceFileURL = url
            case .app(let storeApp):
                context.storeApp = storeApp
            case .application(let app):
                context.targetAppBundle = app
            }
            context.useMainProfile = true
        case .update, .restore, .removeAppExtensions:
            if let storeApp = operation.app as? StoreApp {
                context.storeApp = storeApp
            }
            context.useMainProfile = true
        case .refresh, .resign:
            context.useMainProfile = true
        case .backup, .activate, .deactivate, .export:
            break
        }
        
        await self.logStart(for: operation)
        
        let needsMinimuxer: Bool = {
            switch operation.type {
            case .install, .update, .refresh, .resign, .activate, .deactivate, .backup, .restore, .removeAppExtensions:
                return true
            case .export:
                return false
            }
        }()
        
        do {
            if needsMinimuxer {
                try await self.ensureMinimuxerReady(for: operation, context: context)
            }
            
            for step in operation.steps {
                try Task.checkCancellation()
                if progress.isCancelled {
                    throw CancellationError()
                }
                
                try await self.runStep(step, context: context, operation: operation)
            }
            
            try Task.checkCancellation()
            if progress.isCancelled {
                throw CancellationError()
            }
        } catch {
            context.error = error
        }
        
        await self.finishOperation(operation, in: group, context: context, progress: progress)
    }
    
    // MARK: - Minimuxer Readiness Gate
    
    private func ensureMinimuxerReady(
        for operation: AppOperation,
        context: AppOperationContext
    ) async throws {
        if Minimuxer.shared.isReady {
            return
        }
        
        // KHI BẮT ĐẦU CHUỖI LÀM MỚI BẰNG 4G:
        // Không đòi hỏi VPN / WiFi ở bước đầu này vì bước FetchProvisioningProfilesOperation
        // sẽ kết nối thẳng lên Apple Server bằng mạng 4G bình thường.
        // Đến bước InjectBatchProfilesOperation (hoặc InstallAppOperation), hệ thống sẽ tự kích hoạt
        // Local Stub / Minimuxer ngay sau khi đã tải xong toàn bộ Profile từ Apple!
        if case .refresh = operation.type, CellularRefreshManager.shared.isEnabled {
            let status = Minimuxer.shared.status
            if status == .notStarted {
                try? Minimuxer.shared.startWithLogger()
            }
            Logger.sidestore.info("[PipelineRunner] Cellular Refresh mode active: bypassing initial VPN/WiFi readiness gate so Apple Portal fetch can proceed over 4G.")
            return
        }
        
        let status = Minimuxer.shared.status
        if status == .notStarted {
            do {
                try Minimuxer.shared.startWithLogger()
            } catch {
                Logger.sidestore.error("Failed to start minimuxer before pipeline: \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
        
        let isReady = await Minimuxer.shared.waitForReady(timeout: 8.0)
        if !isReady {
            try Task.checkCancellation()
            
            do {
                try Minimuxer.shared.ensureReadyForOperations()
            } catch {
                Logger.sidestore.warning("Minimuxer did not become ready within timeout for \(operation.app.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
                throw error
            }
        }
    }
    
    // MARK: - Step Runner
    
    private func runStep(
        _ step: AppOperationStep,
        context: AppOperationContext,
        operation: AppOperation
    ) async throws {
        let stepName = String(describing: step)
        Logger.sidestore.debug("[Pipeline] Starting step \(stepName, privacy: .public) for \(operation.app.name, privacy: .public)")
        
        let op = step.makeOperation(context: context)
        
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                let resumeGate = ContinuationGate(continuation)
                
                op.resultHandler = { result in
                    switch result {
                    case .success:
                        resumeGate.resume()
                    case .failure(let error):
                        resumeGate.resume(throwing: error)
                    }
                }
                
                if Task.isCancelled {
                    op.cancel()
                    resumeGate.resume(throwing: CancellationError())
                    return
                }
                
                AppManager.shared.LegacyOperationQueueAdd(op)
            }
        } onCancel: {
            op.cancel()
        }
        
        if let contextError = context.error {
            throw contextError
        }
        
        Logger.sidestore.debug("[Pipeline] Completed step \(stepName, privacy: .public) for \(operation.app.name, privacy: .public)")
    }
    
    // MARK: - Finalize
    
    private func finishOperation(
        _ operation: AppOperation,
        in group: AppOperationGroup,
        context: AppOperationContext,
        progress: Progress
    ) async {
        // Clean up temporary directory
        do {
            if FileManager.default.fileExists(atPath: context.temporaryDirectory.path) {
                try FileManager.default.removeItem(at: context.temporaryDirectory)
            }
        } catch {
            Logger.sidestore.error("Failed to remove temporary directory after operation: \(error.localizedDescription, privacy: .public)")
        }
        
        let finalResult: Result<InstalledApp?, Error>
        
        if let error = context.error {
            finalResult = .failure(error)
            await self.logFailure(for: operation, error: error, context: context)
        } else {
            let remainingUnits = max(0, progress.totalUnitCount - progress.completedUnitCount)
            if remainingUnits > 0 {
                progress.completedUnitCount = progress.totalUnitCount
            }
            
            finalResult = .success(context.installedApp)
            await self.logSuccess(for: operation, context: context)
        }
        
        // Save installedApp changes on background context
        let installedApp = context.installedApp
        let opType = operation.type
        let opError = context.error
        await context.dbBackgroundContext.perform {
            if let installedApp, let managedObjectContext = installedApp.managedObjectContext {
                do {
                    if opError == nil {
                        switch opType {
                        case .install, .update, .refresh, .resign:
                            installedApp.refreshedDate = Date()
                        case .activate:
                            installedApp.isActive = true
                        case .deactivate:
                            installedApp.isActive = false
                        case .removeAppExtensions:
                            installedApp.useMainProfile = true
                        case .backup, .restore, .export:
                            break
                        }
                    }
                    
                    if managedObjectContext.hasChanges {
                        try managedObjectContext.save()
                    }
                } catch {
                    Logger.sidestore.error("Failed to save context in PipelineRunner finishOperation: \(error.localizedDescription, privacy: .public)")
                }
            }
        }
        
        // Store result on group
        let appBundleID = operation.app.bundleIdentifier
        await MainActor.run {
            group.set(finalResult, forAppWithBundleID: appBundleID)
            operation.finish(with: finalResult)
        }
        
        // Post notifications
        self.postNotifications(for: operation, result: finalResult, context: context)
    }
    
    // MARK: - Notifications & Logging
    
    private func postNotifications(
        for operation: AppOperation,
        result: Result<InstalledApp?, Error>,
        context: AppOperationContext
    ) {
        guard case .success(let installedApp) = result, let installedApp else { return }
        
        let objectID = installedApp.objectID
        Task { @MainActor in
            guard let mainApp = DatabaseManager.shared.viewContext.object(with: objectID) as? InstalledApp else { return }
            
            switch operation.type {
            case .install:
                NotificationCenter.default.post(name: AppManager.didInstallAppNotification, object: mainApp)
            case .update:
                NotificationCenter.default.post(name: AppManager.didUpdateAppNotification, object: mainApp)
            case .refresh, .resign:
                NotificationCenter.default.post(name: AppManager.didRefreshAppNotification, object: mainApp)
            case .activate:
                NotificationCenter.default.post(name: AppManager.didActivateAppNotification, object: mainApp)
            case .deactivate:
                NotificationCenter.default.post(name: AppManager.didDeactivateAppNotification, object: mainApp)
            case .backup:
                NotificationCenter.default.post(name: AppManager.didBackupAppNotification, object: mainApp)
            case .restore:
                NotificationCenter.default.post(name: AppManager.didRestoreAppNotification, object: mainApp)
            case .removeAppExtensions, .export:
                break
            }
        }
    }
    
    private func logStart(for operation: AppOperation) async {
        let appName = operation.app.name
        let bundleID = operation.app.bundleIdentifier
        Logger.sidestore.notice("Starting \(String(describing: operation.type), privacy: .public) pipeline for \(appName, privacy: .public) (\(bundleID, privacy: .public))")
    }
    
    private func logSuccess(for operation: AppOperation, context: AppOperationContext) async {
        let appName = operation.app.name
        let bundleID = operation.app.bundleIdentifier
        Logger.sidestore.notice("Successfully finished \(String(describing: operation.type), privacy: .public) pipeline for \(appName, privacy: .public) (\(bundleID, privacy: .public))")
        
        guard !context.isQuietRefresh else { return }
        
        await context.dbBackgroundContext.perform {
            let loggedError = LoggedError(
                error: OperationSuccessDummyError(),
                app: context.installedApp,
                appBundleID: bundleID,
                appName: appName,
                type: operation.type.loggedOperationType,
                result: .success,
                context: context.dbBackgroundContext
            )
            _ = loggedError
            try? context.dbBackgroundContext.save()
        }
    }
    
    private func logFailure(for operation: AppOperation, error: Error, context: AppOperationContext) async {
        let appName = operation.app.name
        let bundleID = operation.app.bundleIdentifier
        Logger.sidestore.error("Pipeline \(String(describing: operation.type), privacy: .public) failed for \(appName, privacy: .public) (\(bundleID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        
        await context.dbBackgroundContext.perform {
            let nsError = error as NSError
            let isCancelled = (error is CancellationError) || (nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError)
            guard !isCancelled else { return }
            
            let loggedError = LoggedError(
                error: nsError,
                app: context.installedApp,
                appBundleID: bundleID,
                appName: appName,
                type: operation.type.loggedOperationType,
                result: .failure,
                context: context.dbBackgroundContext
            )
            _ = loggedError
            try? context.dbBackgroundContext.save()
        }
    }
}

// MARK: - Helpers

private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    
    init(_ continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }
    
    func resume() {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume()
    }
    
    func resume(throwing error: Error) {
        lock.lock()
        let cont = continuation
        continuation = nil
        lock.unlock()
        cont?.resume(throwing: error)
    }
}

private struct OperationSuccessDummyError: LocalizedError {
    var errorDescription: String? { nil }
}

private extension AppOperationType {
    var loggedOperationType: LoggedOperationType {
        switch self {
        case .install: return .install
        case .update: return .update
        case .refresh, .resign: return .refresh
        case .activate: return .activate
        case .deactivate: return .deactivate
        case .backup: return .backup
        case .restore: return .restore
        case .removeAppExtensions: return .update
        case .export: return .backup
        }
    }
}

extension AppManager {
    fileprivate func LegacyOperationQueueAdd(_ operation: Operation) {
        self.operationQueue.addOperation(operation)
    }
}
