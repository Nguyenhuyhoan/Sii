
//
//  PipelineExecutor.swift
//  SideStore
//
//  Created by Magesh K on 3/8/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

@preconcurrency import UIKit
import SwiftUI
import Foundation
import CoreData
import Darwin
import SideSign
import Minimuxer

final class PipelineExecutor: @unchecked Sendable {
    static let shared = PipelineExecutor()
    private init() {}

    // Executes a flat list of `PipelineExecutionStep` items sequentially.
    // NOTE: Each pipeline step is an atomic operation unit and CANNOT execute another pipeline step
    //       nor trigger any standalone steps. Recursive step nesting or sub-pipeline invocation is strictly disallowed.
    @discardableResult
    func executePipeline(
        steps pipelineSteps: [PipelineExecutionStep],
        context: InstallAppOperationContext,
        operation: AppOperation,
        group: RefreshGroup,
        downloadingApp: AppProtocol,
        permissionsMode: PermissionReviewMode,
        operationProgress: Progress?
    ) async throws -> InstalledApp {
        var finalApp: InstalledApp?
        var didTurnOffCellularInSinglePipeline = false
        
        defer {
            // Đảm bảo trả lại trạng thái cờ sau khi kết thúc pipeline
            if didTurnOffCellularInSinglePipeline && !group.isCellularRefreshGroup {
                Task {
                    await CellularRefreshManager.shared.turnOnDataIfNeeded()
                }
            }
        }
        
        for pipelineStep in pipelineSteps {
            let step = pipelineStep.step
            
            do {
                if step == .sendApp || (step == .refreshApp && !group.isCellularRefreshGroup) {
                    if CellularRefreshManager.shared.isCellularMode {
                        didTurnOffCellularInSinglePipeline = true
                    }
                }
                
                if let result = try await executeStep(
                    step,
                    context: context,
                    appOperation: operation,
                    group: group,
                    downloadingApp: downloadingApp,
                    permissionsMode: permissionsMode,
                    progress: operationProgress
                ) {
                    finalApp = result
                }
            } catch {
                if Self.isCancellationError(error) {
                    throw OperationError.cancelled
                }
                
                if let phase = Self.monitoredPhase(for: step) {
                    let actionTitle = Self.actionFailureTitle(for: operation)
                    
                    // 1. Lưu lỗi trực tiếp vào CoreData (LoggedError) để hiển thị trong ErrorLogViewController
                    await Self.recordDiagnosticErrorToDatabase(
                        for: group,
                        error: error,
                        phase: phase,
                        stepName: "\(step)",
                        operation: operation
                    )
                    
                    // 2. Hiển thị bảng thông báo lỗi CSS duy nhất 1 lần với Chi tiết kỹ thuật trực tiếp
                    await Self.presentDiagnosticErrorAlertOnce(
                        for: group,
                        phase: phase,
                        stepName: "\(step)",
                        appName: actionTitle,
                        error: error
                    )
                    
                    // 3. Ném lỗi cancelled để chặn Alert mặc định của hệ thống hiện trùng lặp
                    throw OperationError.cancelled
                } else {
                    throw error
                }
            }
        }
        
        guard let resultApp = finalApp ?? context.installedApp ?? (operation.app as? InstalledApp) else {
            throw OperationError.invalidParameters("Could not resolve installed app for '\(operation.app.name)'")
        }
        return resultApp
    }

    private func executeStep(
        _ step: PipelineStep,
        context: InstallAppOperationContext,
        appOperation: AppOperation,
        group: RefreshGroup,
        downloadingApp: AppProtocol,
        permissionsMode: PermissionReviewMode,
        progress: Progress?
    ) async throws -> InstalledApp? {
        var result: Any? = "()"
        var loggerType: any OperationLogging.Type
        
        defer {
            logOperationResult(result: result, loggerType: loggerType, operation: step)
        }

        do {
            switch step {
            case .preflightChecks:
                loggerType = PreflightChecksOperation.self
                let handler = context.handler.preflightChecksHandler
                let step = try PreflightChecksOperation(operations: [appOperation],
                                                        handler: handler,
                                                        context: group.context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .userCustomization:
                loggerType = UserCustomizationOperation.self
                let step = try UserCustomizationOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .downloadApp:
                loggerType = DownloadAppOperation.self
                let downloadedAppURL = context.temporaryDirectory.appendingPathComponent("App.app")
                let step = try DownloadAppOperation(app: downloadingApp,
                                                    destinationURL: downloadedAppURL,
                                                    context: context)
                let downloadedAppBundle = try await step.execute(parentProgress: progress)
                context.targetAppBundle = downloadedAppBundle
                result = downloadedAppBundle
                return nil
                
            case .verifyApp:
                loggerType = VerifyAppOperation.self
                let step = try VerifyAppOperation(permissionsMode: permissionsMode, context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .cacheApp:
                loggerType = CacheAppOperation.self
                let step = try CacheAppOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .stageApp:
                loggerType = StageAppOperation.self
                let step = try StageAppOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .removeAppExtensions:
                loggerType = RemoveAppExtensionsOperation.self
                let localAppExtensions = (appOperation.app as? ALTApplication)?.appExtensions
                let step = try RemoveAppExtensionsOperation(context: context, localAppExtensions: localAppExtensions)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .fetchProvisioningProfiles:
                loggerType = FetchProvisioningProfilesOperation.self
                let step = try FetchProvisioningProfilesOperation(context: context)
                let profiles = try await step.execute(parentProgress: progress)
                context.provisioningProfiles = profiles
                result = profiles
                return nil
                
            case .prepareAppExtensionBundleIDs:
                loggerType = PrepareAppExtensionBundleIDsOperation.self
                let step = try PrepareAppExtensionBundleIDsOperation(context: context)
                try await step.execute(parentProgress: progress)
                return nil
                
            case .changeAppIcon:
                loggerType = ChangeAppIconOperation.self
                let step = try ChangeAppIconOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .resignApp:
                loggerType = ResignAppOperation.self
                let step = try ResignAppOperation(context: context)
                let resignedAppBundle = try await step.execute(parentProgress: progress)
                context.resignedAppBundle = resignedAppBundle
                result = resignedAppBundle
                return nil
                
            case .exportResignedIPA:
                loggerType = ExportResignedIpaOperation.self
                let step = try ExportResignedIpaOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .createIPA:
                loggerType = CreateIpaOperation.self
                let step = try CreateIpaOperation(context: context)
                let ipaURL = try await step.execute(parentProgress: progress)
                context.ipaURL = ipaURL
                result = ipaURL
                return nil
                
            case .sendApp:
                loggerType = SendAppOperation.self
                // Nếu đang trên 4G, ép làm mới kết nối Minimuxer thẳng sang LocalDevVPN (10.7.0.1) trước khi đẩy IPA
                if CellularRefreshManager.shared.isCellularMode {
                    _ = await CellularRefreshManager.shared.turnOffDataIfNeeded()
                }
                let step = try SendAppOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .installApp:
                loggerType = InstallAppOperation.self
                let step = try InstallAppOperation(context: context, app: appOperation.app)
                let installedApp = try await step.execute(parentProgress: progress)
                context.installedApp = installedApp
                result = installedApp
                if let index = UserDefaults.standard.legacySideloadedApps?.firstIndex(of: installedApp.bundleIdentifier) {
                    UserDefaults.standard.legacySideloadedApps?.remove(at: index)
                }
                return installedApp
                
            case .stageBackupApp:
                loggerType = StageBackupAppOperation.self
                let installedApp = appOperation.app as? InstalledApp
                let step = try StageBackupAppOperation(app: installedApp, context: context)
                let resultApp = try await step.execute(parentProgress: progress)
                context.installedApp = resultApp
                result = resultApp
                return resultApp
                
            case .refreshApp:
                loggerType = RefreshAppOperation.self
                // Nếu đang Refresh 1 app lẻ trên 4G, ép làm mới kết nối Minimuxer sang LocalDevVPN (10.7.0.1)
                if !group.isCellularRefreshGroup && CellularRefreshManager.shared.isCellularMode {
                    _ = await CellularRefreshManager.shared.turnOffDataIfNeeded()
                }
                let step = try RefreshAppOperation(context: context)
                let installedApp = try await step.execute(parentProgress: progress)
                context.installedApp = installedApp
                result = installedApp
                return installedApp
                
            case .backupAppData:
                loggerType = PerformBackupRestoreOperation.self
                let step = try PerformBackupRestoreOperation(action: .backup, context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .restoreAppData:
                loggerType = PerformBackupRestoreOperation.self
                let step = try PerformBackupRestoreOperation(action: .restore, context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .removeBackupData:
                loggerType = RemoveBackupDataOperation.self
                let step = try RemoveBackupDataOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .uninstallApp:
                loggerType = UninstallAppOperation.self
                let step = try UninstallAppOperation(context: context)
                let installedApp = try await step.execute(parentProgress: progress)
                context.installedApp = installedApp
                result = installedApp
                return installedApp

            case .markAppInactive:
                loggerType = MarkAppInactiveOperation.self
                let step = try MarkAppInactiveOperation(context: context)
                let installedApp = try await step.execute(parentProgress: progress)
                context.installedApp = installedApp
                result = installedApp
                return installedApp
                
            case .removeApp:
                loggerType = RemoveAppOperation.self
                let step = try RemoveAppOperation(context: context)
                let installedApp = try await step.execute(parentProgress: progress)
                context.installedApp = installedApp
                result = installedApp
                return installedApp
                
            case .deactivateApp:
                loggerType = DeactivateAppOperation.self
                let app = appOperation.app as? InstalledApp
                let step = try DeactivateAppOperation(app: app, context: context)
                let installedApp = try await step.execute(parentProgress: progress)
                context.installedApp = installedApp
                result = installedApp
                return installedApp
                
            case .cleanStagedApp:
                loggerType = CleanStagedAppOperation.self
                let step = try CleanStagedAppOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .verifyCertificate:
                loggerType = VerifyCertificateOperation.self
                var willResign = true
                if case .refresh = appOperation { willResign = false }
                let step = try VerifyCertificateOperation(context: context, willResign: willResign)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .updateAppCertificate:
                loggerType = UpdateAppCertificateOperation.self
                let step = try UpdateAppCertificateOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
                
            case .embedSigningCert:
                loggerType = EmbedSigningCertOperation.self
                let step = try EmbedSigningCertOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil

            case .cacheSigningCert:
                loggerType = CacheSigningCertOperation.self
                let step = try CacheSigningCertOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil

            case .cacheResignedMetadata:
                loggerType = CacheResignedMetadataOperation.self
                let step = try CacheResignedMetadataOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil

            case .patchInfoPlist:
                loggerType = PatchInfoPlistOperation.self
                let step = try PatchInfoPlistOperation(context: context)
                result = try await step.execute(parentProgress: progress)
                return nil
            }
        } catch {
            result = error
            throw error
        }
    }

    private func logOperationResult(result: Any?, loggerType: any OperationLogging.Type, operation: any OperationStep) {
        if UserDefaults.standard.isVerboseOperationsLoggingEnabled &&
           OperationsLoggingControl.isLoggingEnabled(for: loggerType.self)
        {
            let resultStatus = (result is Error) ? "FAILURE" : "SUCCESS"
            debugLog(
            """
            [PipelineExecutor] ====> OPERATION: .\(operation) completed with: \(resultStatus) <====
                • Component: '\(loggerType)'
                • Result: \(result ?? "nil")
                
            """
            )
        }
    }
}

// MARK: - 🛡️ HỆ THỐNG THÔNG BÁO LỖI TRỰC TIẾP (KHÔNG ĐOÁN MÒ, HIỆN RÕ CHI TIẾT KỸ THUẬT)
extension PipelineExecutor {

    // MARK: - 🔒 CHỐT CHẶN HIỂN THỊ & LƯU LOG 1 LẦN DUY NHẤT
    private static let alertStateLock = NSLock()
    private static var alertedGroupIDs: Set<ObjectIdentifier> = []
    private static var loggedDatabaseGroupIDs: Set<ObjectIdentifier> = []
    private static var loggedDatabaseGroupKeys: Set<String> = []
    private static var isPresentingDiagnosticAlert: Bool = false
    private static var lastAlertDismissTimestamp: CFAbsoluteTime = 0
    private static var lastDatabaseLogTimestamp: CFAbsoluteTime = 0

    /// Kiểm tra xem lỗi có phải là lỗi đã bị huỷ (bao gồm cả `OperationError.cancelled`)
    static func isCancellationError(_ error: Error) -> Bool {
        if Task.isCancelled || error is CancellationError {
            return true
        }
        let nsErr = error as NSError
        let cancelledNSError = (OperationError.cancelled as Error) as NSError
        if (nsErr.domain == NSCocoaErrorDomain && nsErr.code == NSUserCancelledError) ||
           (nsErr.domain == NSURLErrorDomain && nsErr.code == NSURLErrorCancelled) ||
           (nsErr.domain == cancelledNSError.domain && nsErr.code == cancelledNSError.code) {
            return true
        }
        if let opErr = error as? OperationError, String(describing: opErr).lowercased() == "cancelled" {
            return true
        }
        if let minErr = error as? MinimuxerError, String(describing: minErr).lowercased() == "cancelled" {
            return true
        }
        return false
    }

    /// Kiểm tra xem `RefreshGroup` này đã từng hiển thị bảng thông báo lỗi hay chưa
    static func hasPresentedAlert(for group: RefreshGroup) -> Bool {
        let groupID = ObjectIdentifier(group)
        return alertStateLock.withLock {
            alertedGroupIDs.contains(groupID)
        }
    }

    private static func tryAcquireAlertPresentation(for group: RefreshGroup?) -> Bool {
        return alertStateLock.withLock {
            if isPresentingDiagnosticAlert {
                return false
            }
            if let group = group {
                let groupID = ObjectIdentifier(group)
                if alertedGroupIDs.contains(groupID) {
                    return false
                }
                if alertedGroupIDs.count > 64 {
                    alertedGroupIDs.removeAll()
                }
                alertedGroupIDs.insert(groupID)
            } else {
                let now = CFAbsoluteTimeGetCurrent()
                if now - lastAlertDismissTimestamp < 2.5 {
                    return false
                }
            }
            isPresentingDiagnosticAlert = true
            return true
        }
    }

    private static func releaseAlertPresentation() {
        alertStateLock.withLock {
            isPresentingDiagnosticAlert = false
            lastAlertDismissTimestamp = CFAbsoluteTimeGetCurrent()
        }
    }

    private static func tryAcquireDatabaseLog(for group: RefreshGroup?, identifierKey: String) -> Bool {
        return alertStateLock.withLock {
            if let group = group {
                let groupID = ObjectIdentifier(group)
                if loggedDatabaseGroupIDs.contains(groupID) {
                    return false
                }
                if loggedDatabaseGroupIDs.count > 64 {
                    loggedDatabaseGroupIDs.removeAll()
                }
                loggedDatabaseGroupIDs.insert(groupID)
                return true
            } else {
                let now = CFAbsoluteTimeGetCurrent()
                let key = "no_group_\(identifierKey)"
                if loggedDatabaseGroupKeys.contains(key) && (now - lastDatabaseLogTimestamp < 3.0) {
                    return false
                }
                if loggedDatabaseGroupKeys.count > 128 {
                    loggedDatabaseGroupKeys.removeAll()
                }
                loggedDatabaseGroupKeys.insert(key)
                lastDatabaseLogTimestamp = now
                return true
            }
        }
    }

    enum MonitoredPhase: Sendable {
        case authorization  // BƯỚC 1: Xin cấp phép & Chuẩn bị (10% - 30%)
        case systemPush     // BƯỚC 2: Ký & Đẩy vào hệ thống (70% - 85%)
        
        var title: String {
            switch self {
            case .authorization: return "BƯỚC 1: XIN CẤP PHÉP (10% - 30%)"
            case .systemPush:    return "BƯỚC 2: ĐẨY VÀO HỆ THỐNG (70% - 85%)"
            }
        }
        
        var icon: String {
            switch self {
            case .authorization: return "key.shield.fill"
            case .systemPush:    return "iphone.radiowaves.left.and.right"
            }
        }
    }

    static func monitoredPhase(for step: PipelineStep) -> MonitoredPhase? {
        switch step {
        case .preflightChecks,
             .downloadApp,
             .verifyCertificate,
             .fetchProvisioningProfiles,
             .prepareAppExtensionBundleIDs,
             .updateAppCertificate,
             .embedSigningCert:
            return .authorization
            
        case .verifyApp,
             .stageApp,
             .resignApp,
             .createIPA,
             .sendApp,
             .installApp,
             .refreshApp:
            return .systemPush
            
        default:
            return nil
        }
    }

    // MARK: - 🏷️ TẠO TIÊU ĐỀ TRỰC DIỆN: "Không thể cài đặt...", "Không thể làm mới..."
    static func actionFailureTitle(for operation: AppOperation) -> String {
        let appName = operation.app.name
        switch operation {
        case .install, .reinstall:
            return "Không thể cài đặt \(appName)"
        case .refresh:
            return "Không thể làm mới \(appName)"
        case .update:
            return "Không thể cập nhật \(appName)"
        case .activate:
            return "Không thể kích hoạt \(appName)"
        case .deactivate, .deleteApp:
            return "Không thể tắt kích hoạt \(appName)"
        case .backup:
            return "Không thể sao lưu \(appName)"
        case .restore:
            return "Không thể khôi phục \(appName)"
        case .resign:
            return "Không thể ký lại \(appName)"
        case .removeApp, .removeDeactivatedApp:
            return "Không thể gỡ cài đặt \(appName)"
        }
    }

    static func normalizedFailureTitle(appNameOrTitle: String, stepName: String) -> String {
        let trimmed = appNameOrTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        
        if lower.hasPrefix("không thể") {
            return trimmed
        }
        if lower.hasPrefix("lỗi ") {
            let stripped = String(trimmed.dropFirst(4))
            return "Không thể \(stripped)"
        }
        if lower.hasPrefix("làm mới") || lower.hasPrefix("cài đặt") || lower.hasPrefix("cập nhật") {
            return "Không thể \(trimmed)"
        }
        if stepName.lowercased().contains("refresh") || stepName.lowercased().contains("batch") {
            return "Không thể làm mới \(trimmed)"
        }
        return "Không thể cài đặt \(trimmed)"
    }

    /// Trích xuất đầy đủ chi tiết kỹ thuật thực tế của lỗi (bao gồm cả lỗi con bên trong)
    static func extractTechnicalDetails(_ error: Error) -> (code: Int, domain: String, detailText: String) {
        let nsError = error as NSError
        var deepestCode = nsError.code
        var deepestDomain = nsError.domain
        
        var current: NSError? = nsError
        while let currentError = current {
            if let wrapped = (currentError as? ALTWrappedError)?.wrappedError {
                deepestCode = wrapped.code
                deepestDomain = wrapped.domain
                current = wrapped
            } else if let underlying = currentError.underlyingError as NSError? {
                deepestCode = underlying.code
                deepestDomain = underlying.domain
                current = underlying
            } else {
                break
            }
        }
        
        let fullErrorDesc = ErrorProcessing(.fullError, unique: true, recur: true)
            .getDescription(error: nsError)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        let localizedDesc = nsError.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let resolvedText: String
        if !fullErrorDesc.isEmpty {
            resolvedText = fullErrorDesc
        } else if !localizedDesc.isEmpty {
            resolvedText = localizedDesc
        } else {
            resolvedText = String(describing: error)
        }
        
        return (deepestCode, deepestDomain, resolvedText)
    }

    // MARK: - 💾 LƯU TRỰC TIẾP LỖI VÀO COREDATA (`LoggedError`) CHO `ErrorLogViewController`
    static func recordDiagnosticErrorToDatabase(
        for group: RefreshGroup?,
        error: Error,
        phase: MonitoredPhase,
        stepName: String,
        operation: AppOperation
    ) async {
        let appBundleID = operation.bundleIdentifier
        let appName = operation.app.name
        let loggedOp: LoggedError.Operation = operation.loggedErrorOperation
        let failureTitle = Self.actionFailureTitle(for: operation)
        let fallbackApp = AnyApp(from: operation.app)
        
        await Self.recordDiagnosticErrorToDatabaseCore(
            for: group,
            error: error,
            phase: phase,
            stepName: stepName,
            appName: appName,
            bundleIdentifier: appBundleID,
            failureTitle: failureTitle,
            loggedOperation: loggedOp,
            fallbackApp: fallbackApp
        )
    }

    private static func recordDiagnosticErrorToDatabaseCore(
        for group: RefreshGroup?,
        error: Error,
        phase: MonitoredPhase,
        stepName: String,
        appName: String,
        bundleIdentifier: String?,
        failureTitle: String,
        loggedOperation: LoggedError.Operation,
        fallbackApp: AnyApp?
    ) async {
        guard !Self.isCancellationError(error) else { return }
        
        let identifierKey = bundleIdentifier ?? appName
        guard Self.tryAcquireDatabaseLog(for: group, identifierKey: identifierKey) else {
            return
        }
        
        let nsError = error as NSError
        let techInfo = Self.extractTechnicalDetails(error)
        
        let cleanDomain = nsError.domain.isEmpty ? techInfo.domain : nsError.domain
        let cleanCode = (nsError.code != 0) ? nsError.code : techInfo.code
        
        // Chỉ lưu chuỗi String chuẩn NSSecureCoding vào userInfo để CoreData lưu an toàn 100%
        let cleanUserInfo: [String: Any] = [
            NSLocalizedFailureErrorKey: failureTitle,
            NSLocalizedFailureReasonErrorKey: failureTitle,
            NSLocalizedDescriptionKey: failureTitle,
            NSLocalizedRecoverySuggestionErrorKey: "Chi tiết kỹ thuật (.\(stepName)):\n\(techInfo.detailText)"
        ]
        
        let enrichedError = NSError(domain: cleanDomain, code: cleanCode, userInfo: cleanUserInfo)
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DatabaseManager.shared.persistentContainer.performBackgroundTask { bgContext in
                bgContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
                
                var matchedInstalledApp: InstalledApp? = nil
                var matchedStoreApp: StoreApp? = nil
                
                if let bundleID = bundleIdentifier, !bundleID.isEmpty {
                    let installedFetch: NSFetchRequest<InstalledApp> = InstalledApp.fetchRequest()
                    installedFetch.predicate = NSPredicate(format: "%K == %@", #keyPath(InstalledApp.bundleIdentifier), bundleID)
                    installedFetch.fetchLimit = 1
                    matchedInstalledApp = (try? bgContext.fetch(installedFetch))?.first
                    
                    if matchedInstalledApp == nil {
                        let storeFetch: NSFetchRequest<StoreApp> = StoreApp.fetchRequest()
                        storeFetch.predicate = NSPredicate(format: "%K == %@", #keyPath(StoreApp.bundleIdentifier), bundleID)
                        storeFetch.fetchLimit = 1
                        matchedStoreApp = (try? bgContext.fetch(storeFetch))?.first
                    }
                }
                
                if matchedInstalledApp == nil && matchedStoreApp == nil {
                    let byNameFetch: NSFetchRequest<InstalledApp> = InstalledApp.fetchRequest()
                    byNameFetch.predicate = NSPredicate(format: "%K ==[c] %@", #keyPath(InstalledApp.name), appName)
                    byNameFetch.fetchLimit = 1
                    matchedInstalledApp = (try? bgContext.fetch(byNameFetch))?.first
                    
                    if matchedInstalledApp == nil {
                        let anyInstalledFetch: NSFetchRequest<InstalledApp> = InstalledApp.fetchRequest()
                        anyInstalledFetch.predicate = NSPredicate(format: "%K == YES", #keyPath(InstalledApp.isActive))
                        anyInstalledFetch.fetchLimit = 1
                        matchedInstalledApp = (try? bgContext.fetch(anyInstalledFetch))?.first
                    }
                    
                    if matchedInstalledApp == nil {
                        let firstInstalledFetch: NSFetchRequest<InstalledApp> = InstalledApp.fetchRequest()
                        firstInstalledFetch.fetchLimit = 1
                        matchedInstalledApp = (try? bgContext.fetch(firstInstalledFetch))?.first
                    }
                }
                
                let resolvedApp: any AppProtocol
                if let installed = matchedInstalledApp {
                    resolvedApp = installed
                } else if let store = matchedStoreApp {
                    resolvedApp = store
                } else if let fallback = fallbackApp {
                    resolvedApp = fallback
                } else {
                    resolvedApp = AnyApp(
                        name: appName,
                        bundleIdentifier: bundleIdentifier ?? "com.sidestore.batch.operation",
                        url: URL(fileURLWithPath: "/"),
                        storeApp: nil
                    )
                }
                
                _ = LoggedError(
                    error: enrichedError,
                    app: resolvedApp,
                    date: Date(),
                    operation: loggedOperation,
                    context: bgContext
                )
                
                do {
                    try bgContext.save()
                    debugLog("[PipelineExecutor] ✅ Đã lưu '\(failureTitle)' (.\(stepName)) vào Nhật Ký Lỗi Hệ Thống.")
                } catch {
                    debugLog("[PipelineExecutor] ❌ Không thể lưu LoggedError vào CoreData: \(error)")
                }
                
                continuation.resume()
            }
        }
    }

    /// Hiển thị Bảng Thông Báo Lỗi **CHỈ 1 LẦN DUY NHẤT** cho mỗi `RefreshGroup`
    @MainActor
    static func presentDiagnosticErrorAlertOnce(
        for group: RefreshGroup?,
        phase: MonitoredPhase,
        stepName: String,
        appName: String,
        error: Error
    ) async {
        guard !Self.isCancellationError(error) else {
            return
        }
        
        let displayFailureTitle = Self.normalizedFailureTitle(appNameOrTitle: appName, stepName: stepName)
        
        let inferredOperation: LoggedError.Operation = {
            if stepName.lowercased().contains("refresh") || stepName.lowercased().contains("batch") || displayFailureTitle.lowercased().contains("làm mới") {
                return .refresh
            }
            return .install
        }()
        
        // Đảm bảo lỗi từ cả các bước ngoài executePipeline (như .injectBatchProfiles) cũng được lưu vào CoreData
        await Self.recordDiagnosticErrorToDatabaseCore(
            for: group,
            error: error,
            phase: phase,
            stepName: stepName,
            appName: appName,
            bundleIdentifier: nil,
            failureTitle: displayFailureTitle,
            loggedOperation: inferredOperation,
            fallbackApp: nil
        )
        
        guard Self.tryAcquireAlertPresentation(for: group) else {
            debugLog("[PipelineExecutor] Suppressed duplicate diagnostic alert for step: \(stepName)")
            return
        }
        
        defer {
            Self.releaseAlertPresentation()
        }
        
        guard let topVC = Self.topViewController() else {
            return
        }
        
        let techInfo = Self.extractTechnicalDetails(error)
        let rawDetail = "[\(techInfo.domain) : \(techInfo.code)]\n\(techInfo.detailText)"
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let lock = NSLock()
            var didResume = false
            
            let complete: () -> Void = {
                let canResume = lock.withLock {
                    guard !didResume else { return false }
                    didResume = true
                    return true
                }
                guard canResume else { return }
                continuation.resume()
            }
            
            var hostingController: UIHostingController<CSSErrorPromptModalView>?
            
            let modalView = CSSErrorPromptModalView(
                phase: phase,
                stepName: stepName,
                failureTitle: displayFailureTitle,
                rawErrorText: rawDetail,
                onDismiss: {
                    if let hc = hostingController {
                        hc.dismiss(animated: true) { complete() }
                    } else {
                        complete()
                    }
                }
            )
            
            let hc = UIHostingController(rootView: modalView)
            hc.modalPresentationStyle = .overFullScreen
            hc.modalTransitionStyle = .crossDissolve
            hc.view.backgroundColor = .clear
            hc.overrideUserInterfaceStyle = .light
            hostingController = hc
            
            topVC.present(hc, animated: true)
        }
    }

    @MainActor
    static func presentDiagnosticErrorAlert(
        phase: MonitoredPhase,
        stepName: String,
        appName: String,
        error: Error
    ) async {
        await presentDiagnosticErrorAlertOnce(
            for: nil,
            phase: phase,
            stepName: stepName,
            appName: appName,
            error: error
        )
    }

    @MainActor
    private static func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let baseVC = base ?? UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        
        if let nav = baseVC as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = baseVC as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = baseVC?.presentedViewController {
            return topViewController(base: presented)
        }
        return baseVC
    }
}

// MARK: - 🎨 GIAO DIỆN BẢNG THÔNG BÁO (HIỂN THỊ TRỰC TIẾP TIÊU ĐỀ & CHI TIẾT KỸ THUẬT)
private enum CSSErrorTheme {
    static let cornerRadius: CGFloat = 15.0
    static let primary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)       // #007bff
    static let secondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)    // #6f42c1
    static let red = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)           // #dc3545
    static let pureBlack = SwiftUI.Color.black
    static let cardBackground = SwiftUI.Color.white
    static let innerRowBackground = SwiftUI.Color(red: 246/255, green: 248/255, blue: 251/255)
    static let border = SwiftUI.Color(red: 218/255, green: 224/255, blue: 233/255)

    static var pageGradient: SwiftUI.LinearGradient {
        SwiftUI.LinearGradient(
            colors: [
                SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255),
                SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var heroGradient: SwiftUI.LinearGradient {
        SwiftUI.LinearGradient(
            colors: [
                SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.94),
                SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct CSSErrorBounceButtonStyle: SwiftUI.ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

private struct CSSErrorPromptModalView: SwiftUI.View {
    let phase: PipelineExecutor.MonitoredPhase
    let stepName: String
    let failureTitle: String
    let rawErrorText: String
    let onDismiss: () -> Void

    @State private var didTapDismiss: Bool = false

    var body: some SwiftUI.View {
        SwiftUI.ZStack {
            SwiftUI.Color.black.opacity(0.45)
                .ignoresSafeArea()
            
            SwiftUI.VStack(spacing: 12) {
                headerBannerView
                technicalCardView
                dismissButtonView
            }
            .padding(14)
            .background(CSSErrorTheme.pageGradient)
            .clipShape(SwiftUI.RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                SwiftUI.RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CSSErrorTheme.border, lineWidth: 1.2)
            )
            .shadow(color: SwiftUI.Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 20)
        }
    }

    private var headerBannerView: some SwiftUI.View {
        SwiftUI.HStack(spacing: 8) {
            SwiftUI.Image(systemName: phase.icon)
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(.white)
            
            SwiftUI.Text(phase.title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(CSSErrorTheme.heroGradient)
        .clipShape(SwiftUI.RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var technicalCardView: some SwiftUI.View {
        SwiftUI.VStack(alignment: .leading, spacing: 10) {
            SwiftUI.HStack(alignment: .center, spacing: 8) {
                SwiftUI.Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CSSErrorTheme.red)
                
                SwiftUI.Text(failureTitle)
                    .font(.system(size: 15.5, weight: .heavy))
                    .foregroundColor(CSSErrorTheme.pureBlack)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            SwiftUI.Divider()
            
            SwiftUI.Text("Chi tiết kỹ thuật (.\(stepName)):")
                .font(.system(size: 12.5, weight: .bold))
                .foregroundColor(CSSErrorTheme.secondary)
            
            SwiftUI.ScrollView {
                SwiftUI.Text(rawErrorText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(CSSErrorTheme.pureBlack.opacity(0.88))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 160)
            .padding(10)
            .background(CSSErrorTheme.innerRowBackground)
            .cornerRadius(10)
        }
        .padding(13)
        .background(CSSErrorTheme.cardBackground)
        .clipShape(SwiftUI.RoundedRectangle(cornerRadius: CSSErrorTheme.cornerRadius, style: .continuous))
        .overlay(
            SwiftUI.RoundedRectangle(cornerRadius: CSSErrorTheme.cornerRadius, style: .continuous)
                .stroke(CSSErrorTheme.border, lineWidth: 1)
        )
    }

    private var dismissButtonView: some SwiftUI.View {
        SwiftUI.Button {
            guard !didTapDismiss else { return }
            didTapDismiss = true
            onDismiss()
        } label: {
            SwiftUI.HStack(spacing: 6) {
                SwiftUI.Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                SwiftUI.Text("Tắt Thông Báo")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(CSSErrorTheme.red)
            .cornerRadius(11)
        }
        .buttonStyle(CSSErrorBounceButtonStyle())
        .disabled(didTapDismiss)
    }
}
