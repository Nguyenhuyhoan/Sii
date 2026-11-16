
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
        
        for pipelineStep in pipelineSteps {
            let step = pipelineStep.step
            
            while true {
                do {
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
                    break
                } catch {
                    if Task.isCancelled || error is CancellationError {
                        throw error
                    }
                    
                    if let phase = Self.monitoredPhase(for: step) {
                        let shouldContinue = await Self.presentDiagnosticErrorAlert(
                            phase: phase,
                            stepName: "\(step)",
                            appName: operation.app.name,
                            error: error
                        )
                        if shouldContinue {
                            continue
                        } else {
                            throw OperationError.cancelled
                        }
                    } else {
                        throw error
                    }
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
                // Nếu đang cài IPA qua 4G, tự động ngắt 4G sang VPN nội bộ trước khi đẩy IPA
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

// MARK: - 🛡️ HỆ THỐNG CHẨN ĐOÁN CHÍNH XÁC 30 LỖI (15 LỖI XIN CẤP PHÉP + 15 LỖI ĐẨY HỆ THỐNG)
extension PipelineExecutor {
    
    enum MonitoredPhase: Sendable {
        case authorization  // PHẦN 1: Bước "Xin cấp phép" (Kẹt ở 10% - 30%): Giao tiếp Apple & Anisette
        case systemPush     // PHẦN 2: Bước "Đẩy vào hệ thống" (Kẹt ở 70% - 85%): Giao tiếp nội bộ qua VPN
        
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
    
    enum ErrorSourceBadge: String, Sendable {
        case vpn      = "LỖI VPN"
        case pairing  = "LỖI FILE PAIRING"
        case device   = "LỖI THIẾT BỊ GHÉP NỐI"
        case apple    = "LỖI APPLE / ANISETTE"
        case system   = "LỖI HỆ THỐNG iOS"
        
        var color: SwiftUI.Color {
            switch self {
            case .vpn:     return CSSErrorTheme.primary
            case .pairing: return CSSErrorTheme.red
            case .device:  return CSSErrorTheme.secondary
            case .apple:   return CSSErrorTheme.secondary
            case .system:  return CSSErrorTheme.red
            }
        }
    }
    
    struct DiagnosticErrorItem: Sendable {
        let badge: ErrorSourceBadge
        let title: String
        let cause: String
        let solution: String
    }
    
    /// Trạng thái thực tế của card mạng VPN (`utun`) trên iOS
    enum VPNHardwareState: Sendable {
        case connectedLocalDevVPN   // Đã bật đúng StosVPN / LocalDevVPN (có IP 10.7.x.x)
        case conflictOtherVPN       // Có utun VPN khác (1.1.1.1, AdGuard, Shadowrocket...) nhưng thiếu 10.7.x.x
        case disconnected           // Hoàn toàn chưa bật VPN nào
    }
    
    static func monitoredPhase(for step: PipelineStep) -> MonitoredPhase? {
        switch step {
        // PHẦN 1: Các bước kiểm tra điều kiện, xác thực Apple ID, Anisette, App ID & Chứng chỉ
        case .preflightChecks,
             .verifyCertificate,
             .fetchProvisioningProfiles,
             .prepareAppExtensionBundleIDs,
             .updateAppCertificate,
             .embedSigningCert:
            return .authorization
            
        // PHẦN 2: Các bước kiểm tra gói IPA, ký số và đẩy vào hệ điều hành iOS qua VPN
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
    
    // MARK: - 🔍 QUÉT TRỰC TIẾP CARD MẠNG `utun` ĐỂ PHÂN BIỆT: TẮT VPN vs XUNG ĐỘT VPN vs ĐÃ BẬT VPN
    static func inspectVPNHardwareState() -> VPNHardwareState {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return .disconnected
        }
        defer { freeifaddrs(ifaddr) }
        
        var hasLocalDevIP = false
        var hasOtherVPNTunnel = false
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        
        while let current = ptr {
            let interface = current.pointee
            let name = String(cString: interface.ifa_name)
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            
            if isUp, (name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")),
               let addr = interface.ifa_addr {
                let family = addr.pointee.sa_family
                if family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        // StosVPN / LocalDevVPN / SideStore WireGuard luôn dùng dải 10.7.x.x
                        if ip.hasPrefix("10.7.") {
                            hasLocalDevIP = true
                        } else if !ip.hasPrefix("169.254.") && !ip.hasPrefix("127.") {
                            // Đang có một VPN khác chiếm dụng giao diện utun (1.1.1.1, AdGuard, Shadowrocket...)
                            hasOtherVPNTunnel = true
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }
        
        if hasLocalDevIP {
            return .connectedLocalDevVPN
        } else if hasOtherVPNTunnel {
            return .conflictOtherVPN
        } else {
            return .disconnected
        }
    }
    
    /// Thu thập toàn bộ chuỗi mô tả lỗi sâu nhất (bao gồm cả `underlyingErrors` và `ALTWrappedError`)
    private static func extractFullErrorInfo(_ error: Error) -> (code: Int, domain: String, text: String) {
        let nsError = error as NSError
        let deepDesc = ErrorProcessing(.fullError, unique: true, recur: true).getDescription(error: nsError)
        let localDesc = ErrorProcessing(.localizedDescription, unique: true, recur: true).getDescription(error: nsError)
        
        var deepestCode = nsError.code
        var deepestDomain = nsError.domain
        var current: NSError? = nsError
        while let underlying = (current as? ALTWrappedError)?.wrappedError ?? (current?.underlyingError as? NSError) {
            deepestCode = underlying.code
            deepestDomain = underlying.domain
            current = underlying
        }
        
        let combined = "\(nsError.domain) \(deepestDomain) \(nsError.code) \(deepestCode) \(error.localizedDescription) \(localDesc) \(deepDesc) \(String(describing: error))".lowercased()
        return (deepestCode, deepestDomain.lowercased(), combined)
    }
    
    // MARK: - 🧠 BỘ CHẨN ĐOÁN CHÍNH XÁC 30 KỊCH BẢN LỖI
    static func diagnoseError(_ error: Error, phase: MonitoredPhase) -> DiagnosticErrorItem {
        let opError: OperationError? = {
            if let direct = error as? OperationError { return direct }
            if let minErr = error as? MinimuxerError { return minErr.asOperationError }
            return nil
        }()
        
        let info = Self.extractFullErrorInfo(error)
        let code = info.code
        let fullText = info.text
        
        let hasPairingFile = PairingFileManager.shared.hasPairingFile()
        let vpnState = Self.inspectVPNHardwareState()
        let isConnectionReset = fullText.contains("connectionreset") ||
                                fullText.contains("connection reset by peer") ||
                                fullText.contains("code: 54") ||
                                fullText.contains("os error 54")
        
        // =========================================================================
        // KIỂM TRA CÁC LỖI VERIFICATION (10. Mismatched Bundle ID, 12. Minimum OS, 15. Invalid Entitlements)
        // =========================================================================
        if let verifError = error as? VerificationError {
            switch verifError.code {
            case .iOSVersionNotSupported:
                // [PHẦN 2 - LỖI 12]: Minimum OS Version Mismatch
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "Không tương thích phiên bản iOS (Minimum OS Mismatch)",
                    cause: "File IPA yêu cầu phiên bản iOS cao hơn (hoặc khác với) phiên bản iOS hiện tại trên máy của bạn.",
                    solution: "Tải phiên bản IPA cũ hơn phù hợp với iOS của máy hoặc cập nhật iOS."
                )
            case .mismatchedBundleIdentifiers:
                // [PHẦN 2 - LỖI 10]: Mismatched Bundle ID
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "Lệch định danh ứng dụng (Mismatched Bundle ID)",
                    cause: "Cố gắng Làm mới / Cài đè ứng dụng nhưng Bundle ID hoặc Apple ID khác với lúc cài đặt ban đầu.",
                    solution: "Dùng đúng tài khoản Apple ID ban đầu hoặc gỡ ứng dụng cũ ra rồi cài mới lại."
                )
            case .undeclaredPermissions, .addedPermissions:
                // [PHẦN 1 - LỖI 15]: Invalid Entitlements
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Quyền hệ thống đặc biệt không hợp lệ (Invalid Entitlements)",
                    cause: "IPA yêu cầu quyền hệ thống cao cấp (Siri, iCloud đặc biệt...) mà tài khoản Apple miễn phí không được cấp.",
                    solution: "Chọn giữ/loại bỏ quyền mở rộng khi cài đặt hoặc dùng tài khoản Developer trả phí."
                )
            default:
                // [PHẦN 2 - LỖI 14]: Corrupted IPA Payload
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "Gói cài đặt IPA bị lỗi cấu trúc (Corrupted IPA Payload)",
                    cause: verifError.localizedDescription,
                    solution: "Tải lại file IPA từ nguồn uy tín rồi bấm Chạy tiếp."
                )
            }
        }
        
        // =========================================================================
        // PHẦN 1: 15 LỖI BƯỚC “XIN CẤP PHÉP” (Kẹt ở 10% - 30%)
        // Giao tiếp với máy chủ Apple và Anisette
        // =========================================================================
        if phase == .authorization {
            // [1.2] Anisette Error (500/502/503)
            if fullText.contains("anisette") && (fullText.contains("500") || fullText.contains("502") || fullText.contains("503") || fullText.contains("504") || fullText.contains("overload") || fullText.contains("bad gateway")) {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Máy chủ Anisette quá tải (Error 500/502/503)",
                    cause: "Server Anisette đang bị quá tải do có quá nhiều người dùng cùng lúc.",
                    solution: "Chờ vài giây rồi bấm Chạy tiếp, hoặc vào Cài đặt đổi sang Server Anisette khác."
                )
            }
            
            // [1.3] Invalid Anisette Data (-22421)
            if code == -22421 || fullText.contains("-22421") || fullText.contains("invalid anisette") || fullText.contains("machine data") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Dữ liệu Anisette không hợp lệ (Mã -22421)",
                    cause: "Dữ liệu giả lập máy Mac bị lỗi hoặc quá hạn, máy chủ Apple từ chối nhận.",
                    solution: "Vào Cài đặt -> Đặt lại dữ liệu ADI (Reset adi.pb) hoặc đổi Server Anisette khác rồi bấm Chạy tiếp."
                )
            }
            
            // [1.1] Failed to fetch Anisette data
            if fullText.contains("anisette") || fullText.contains("adi.pb") || fullText.contains("provisioning session") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Không lấy được dữ liệu Anisette (Failed to fetch Anisette)",
                    cause: "Server Anisette đang chọn bị sập hoặc không phản hồi.",
                    solution: "Vào Cài đặt đổi sang Server Anisette khác rồi bấm Chạy tiếp."
                )
            }
            
            // [1.4] Your session has expired (-29004)
            if opError == .notAuthenticated || code == -29004 || fullText.contains("-29004") || fullText.contains("session has expired") || fullText.contains("not signed in") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Phiên đăng nhập Apple ID đã hết hạn (-29004)",
                    cause: "Phiên đăng nhập Apple ID đã hết hạn hoặc bị đăng xuất, cần xác thực lại.",
                    solution: "Vào Cài đặt đăng nhập lại Apple ID rồi bấm Chạy tiếp."
                )
            }
            
            // [1.5] Maximum number of App IDs reached
            if code == 9412 || fullText.contains("maximum number of app ids") || fullText.contains("10 app ids") || fullText.contains("max quantity of app ids") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Hết 10 lượt đăng ký App ID trong tuần (Max App IDs)",
                    cause: "Đã dùng hết sạch 10 lượt đăng ký App ID trong 7 ngày của tài khoản Apple miễn phí.",
                    solution: "Chờ App ID cũ hết hạn sau 7 ngày hoặc đổi sang tài khoản Apple ID phụ khác."
                )
            }
            
            // [1.6] Maximum number of apps installed (3 apps)
            if fullText.contains("maximum number of installed apps") || fullText.contains("3 apps") || fullText.contains("more than 3") || fullText.contains("deactivate") || fullText.contains("active apps limit") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Đã kịch trần 3 ứng dụng hoạt động (Max 3 Apps)",
                    cause: "Tài khoản Apple miễn phí chỉ cho phép tối đa 3 ứng dụng hoạt động cùng lúc trên máy.",
                    solution: "Huỷ kích hoạt (Deactivate) hoặc gỡ bớt 1 ứng dụng đang cài rồi bấm Chạy tiếp."
                )
            }
            
            // [1.7] Apple ID Locked
            if code == -20209 || fullText.contains("-20209") || fullText.contains("locked") || fullText.contains("disabled for security") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Tài khoản Apple ID bị khóa bảo mật (Apple ID Locked)",
                    cause: "Tài khoản Apple bị khóa bảo mật do đăng nhập từ địa chỉ IP lạ (của máy chủ Anisette).",
                    solution: "Truy cập iforgot.apple.com để mở khóa tài khoản, sau đó đăng nhập lại và bấm Chạy tiếp."
                )
            }
            
            // [1.8] Incorrect Credentials (-20101)
            if code == -20101 || code == -22406 || fullText.contains("-20101") || fullText.contains("incorrect") || fullText.contains("invalid username or password") || fullText.contains("bad password") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Sai mật khẩu Apple ID (Incorrect Credentials -20101)",
                    cause: "Nhập sai mật khẩu Apple ID hoặc bạn vừa đổi mật khẩu nhưng chưa cập nhật trong ứng dụng.",
                    solution: "Vào Cài đặt đăng xuất và đăng nhập lại bằng mật khẩu Apple ID mới."
                )
            }
            
            // [1.9] 2FA Failed / Verification Code Error
            if code == -21669 || fullText.contains("verification code") || fullText.contains("two-factor") || fullText.contains("2fa") || fullText.contains("security code") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Lỗi mã xác thực 2 bước (2FA Verification Error)",
                    cause: "Nhập sai mã xác thực 2 yếu tố (2FA) hoặc mã xác thực đã hết hạn.",
                    solution: "Thử lại và nhập chính xác mã 6 số mới nhất vừa gửi về thiết bị."
                )
            }
            
            // [1.10] License Agreement Updated
            if fullText.contains("license agreement") || fullText.contains("terms") || fullText.contains("pla") || fullText.contains("accept the updated") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Cần đồng ý Điều khoản Apple mới (License Agreement)",
                    cause: "Apple vừa cập nhật điều khoản Developer mới, bắt buộc phải đồng ý trước khi ký ứng dụng.",
                    solution: "Truy cập developer.apple.com, đăng nhập Apple ID để bấm Đồng ý điều khoản rồi bấm Chạy tiếp."
                )
            }
            
            // [1.11] Certificate Revoked
            if case .certificateRevoked = opError {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chứng chỉ đã bị thu hồi (Certificate Revoked)",
                    cause: "Chứng chỉ hiện tại bị thu hồi hoặc bạn vừa bấm 'Revoke' trên một thiết bị/máy tính khác.",
                    solution: "Vào Cài đặt -> Chứng chỉ để làm mới/tạo lại chứng chỉ mới rồi bấm Chạy tiếp."
                )
            }
            if case .customCertificateRevoked = opError {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chứng chỉ đã bị thu hồi (Certificate Revoked)",
                    cause: "Chứng chỉ hiện tại đã bị thu hồi trên cổng Apple Developer.",
                    solution: "Vào Cài đặt -> Chứng chỉ để tạo lại hoặc đặt lại chứng chỉ rồi bấm Chạy tiếp."
                )
            }
            if fullText.contains("revoked") || fullText.contains("certificate expired") || fullText.contains("no signing certificate") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chứng chỉ bị thu hồi hoặc hết hạn (Certificate Revoked)",
                    cause: "Chứng chỉ hiện tại bị thu hồi hoặc bạn vừa bấm 'Revoke' trên thiết bị khác.",
                    solution: "Vào Cài đặt -> Chứng chỉ bấm Tạo lại chứng chỉ rồi bấm Chạy tiếp."
                )
            }
            
            // [1.12] App ID not available
            if code == 9401 || fullText.contains("not available") || fullText.contains("bundle identifier is not available") || fullText.contains("already in use") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Tên định danh bị trùng (App ID Not Available)",
                    cause: "Tên định danh (Bundle ID) của ứng dụng bị trùng với một người khác đã đăng ký trước trên Apple.",
                    solution: "Đổi Bundle ID tuỳ chỉnh khác khi cài đặt ứng dụng rồi thử lại."
                )
            }
            
            // [1.13] SSL / TLS Handshake Failed
            if code == -1200 || code == -1202 || code == -9806 || fullText.contains("ssl") || fullText.contains("tls") || fullText.contains("handshake") || fullText.contains("secure connection") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Lỗi kết nối bảo mật (SSL / TLS Handshake Failed)",
                    cause: "Mạng Wi-Fi / DNS đang dùng chặn kết nối bảo mật tới máy chủ Apple hoặc Anisette.",
                    solution: "Đổi sang mạng 4G hoặc mạng Wi-Fi khác (tắt các trình chặn quảng cáo/DNS) rồi bấm Chạy tiếp."
                )
            }
            
            // [1.14] Apple Developer Maintenance
            if fullText.contains("maintenance") || fullText.contains("unavailable") || fullText.contains("down for maintenance") || code == 503 {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Máy chủ Apple đang bảo trì (Developer Maintenance)",
                    cause: "Hệ thống máy chủ dành cho lập trình viên của Apple đang bảo trì định kỳ.",
                    solution: "Vui lòng đợi Apple hoàn tất bảo trì sau ít phút rồi bấm Chạy tiếp."
                )
            }
            
            // [1.15] Invalid Entitlements
            if fullText.contains("entitlement") || (fullText.contains("provisioning profile") && fullText.contains("capability")) {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Quyền hệ thống không được cấp (Invalid Entitlements)",
                    cause: "IPA yêu cầu quyền hệ thống cao cấp (như Siri, iCloud đặc biệt) mà tài khoản Free không được cấp.",
                    solution: "Xoá các quyền Entitlement đặc biệt của IPA hoặc tắt App Extensions rồi bấm Chạy tiếp."
                )
            }
        }
        
        // =========================================================================
        // PHẦN 2: 15 LỖI BƯỚC “ĐẨY VÀO HỆ THỐNG” (Kẹt ở 70% - 85%)
        // Giao tiếp nội bộ giữa SideStore và hệ điều hành iOS qua VPN
        // =========================================================================
        
        // [2.3] Pairing File Not Found (Kiểm tra trực tiếp file pairing trong máy)
        if !hasPairingFile || (opError != nil && { if case .pairingNotComplete = opError! { return true }; return false }()) {
            return DiagnosticErrorItem(
                badge: .pairing,
                title: "Chưa nạp File ghép đôi (Pairing File Not Found)",
                cause: "Chưa nạp file ghép đôi (.mobiledevicepairing / rppairing) vào SideStore hoặc bạn vừa xoá file.",
                solution: "Vào Cài đặt -> File ghép đôi để nạp file ghép đôi vào máy rồi bấm Chạy tiếp."
            )
        }
        
        // [2.4] Local Network Permission Denied
        if fullText.contains("local network") || fullText.contains("necperror") || fullText.contains("permission denied") || fullText.contains("no route to host") || code == 65 {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Chưa bật quyền Mạng cục bộ (Local Network Denied)",
                cause: "Quên bật quyền 'Mạng cục bộ' (Local Network) cho SideStore trong Cài đặt iOS.",
                solution: "Vào Cài đặt iOS -> SideStore -> Gạt bật 'Mạng cục bộ' rồi bấm Chạy tiếp."
            )
        }
        
        // [2.5] VPN Conflict (Quét thấy có VPN khác như 1.1.1.1/AdGuard/Shadowrocket đang bật đè làm mất IP 10.7.x.x)
        if vpnState == .conflictOtherVPN {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Xung đột ứng dụng VPN (VPN Conflict)",
                cause: "Đang bật đè một VPN khác (1.1.1.1, AdGuard, Shadowrocket...) làm mất tác dụng của StosVPN / LocalDevVPN.",
                solution: "Tắt toàn bộ các VPN khác (kể cả chế độ Kết nối theo yêu cầu), chỉ bật duy nhất StosVPN / LocalDevVPN rồi bấm Chạy tiếp."
            )
        }
        
        // [2.8] Wi-Fi AP Isolation (Cellular Fallback)
        if let opError, case .invalidVPN(let reason) = opError, reason.lowercased().contains("wireguard") {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Lỗi mạng 4G / Cách ly Wi-Fi (Cellular / AP Isolation)",
                cause: "Đang dùng mạng 4G với WireGuard hoặc dùng mạng Wi-Fi công cộng chặn giao tiếp nội bộ.",
                solution: "Kết nối mạng Wi-Fi cá nhân và dùng StosVPN / LocalDevVPN (hoặc bật chế độ Làm mới 4G) rồi bấm Chạy tiếp."
            )
        }
        if let opError, case .noConnection = opError {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Chưa kết nối Wi-Fi hoặc bị chặn mạng nội bộ (AP Isolation)",
                cause: "Đang dùng mạng 4G khi chưa bật chế độ 4G, hoặc mạng Wi-Fi công cộng chặn giao tiếp nội bộ.",
                solution: "Kết nối Wi-Fi ổn định (hoặc bật chế độ 4G trong Cài đặt), bật StosVPN rồi bấm Chạy tiếp."
            )
        }
        
        // [2.1] Unable to connect to device (Quét phần cứng thấy hoàn toàn chưa bật LocalDevVPN / StosVPN)
        if vpnState == .disconnected {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Chưa bật VPN (Unable to connect to device)",
                cause: "Quên chưa bật LocalDevVPN / StosVPN nên SideStore không tìm thấy đường truyền nội bộ (10.7.0.1).",
                solution: "Mở ứng dụng StosVPN hoặc LocalDevVPN, gạt bật kết nối lên rồi bấm Chạy tiếp."
            )
        }
        
        // [2.2] Invalid Pairing File / Lockdown Error (VPN ĐÃ BẬT nhưng bị Connection Reset OS code 54 hoặc Lockdown từ chối)
        if isConnectionReset ||
           fullText.contains("lockdown") ||
           fullText.contains("invalid pairing") ||
           fullText.contains("invalid hostid") ||
           fullText.contains("pair record") ||
           (opError != nil && { if case .invalidPairingFile = opError! { return true }; return false }()) {
            return DiagnosticErrorItem(
                badge: .device,
                title: "Thiết bị đã huỷ liên kết (Invalid Pairing / Lockdown Error)",
                cause: "VPN đã bật nhưng iOS từ chối kết nối (Code 54: Connection reset). Do bạn đã xoá thiết bị đã liên kết, đổi mật khẩu màn hình khóa hoặc mới cập nhật iOS.",
                solution: "Cắm iPhone vào máy tính, bấm 'Tin cậy', tạo lại File Pairing mới bằng iloader / idevicepair và nạp lại."
            )
        }
        
        // [2.6] Connection Timed Out (mux error)
        if opError == .timedOut || fullText.contains("timed out") || fullText.contains("timeout") || fullText.contains("mux error") || (fullText.contains("afc") && fullText.contains("broken pipe")) {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Nghẽn đường truyền nội bộ (Connection Timed Out)",
                cause: "Mạng nội bộ bị nghẽn hoặc quá hạn khi đang đẩy gói cài đặt IPA dung lượng lớn.",
                solution: "Tắt rồi bật lại StosVPN / LocalDevVPN, giữ sáng màn hình rồi bấm Chạy tiếp."
            )
        }
        
        // [2.7] Background Task Killed
        if fullText.contains("background") || fullText.contains("interrupted") || fullText.contains("connection abort") || code == 53 || code == -997 {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Bị ngắt do thoát ứng dụng (Background Task Killed)",
                cause: "Thoát SideStore ra ngoài hoặc để màn hình tự tắt khiến iOS ngắt kết nối truyền dữ liệu ngầm.",
                solution: "Giữ nguyên màn hình ứng dụng luôn sáng trong suốt quá trình cài đặt và bấm Chạy tiếp."
            )
        }
        
        // [2.10] Mismatched Bundle ID (Bắt từ thông báo lỗi của installd iOS)
        if fullText.contains("mismatchedbundleid") || fullText.contains("mismatchedapplicationidentifierentitlement") || fullText.contains("upgrade's application-identifier") || fullText.contains("already installed") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Trùng ứng dụng khác tài khoản (Mismatched Bundle ID)",
                cause: "Cố gắng Refresh / Cài đè một ứng dụng nhưng lại dùng Apple ID khác với lúc cài đặt ban đầu.",
                solution: "Sao lưu dữ liệu, xoá ứng dụng cũ trên màn hình chính đi rồi cài đặt lại."
            )
        }
        
        // [2.11] Storage Full (Disk Quota Exceeded)
        if code == 28 || fullText.contains("disk quota") || fullText.contains("no space left") || fullText.contains("storage") || fullText.contains("not enough space") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Bộ nhớ iPhone đã đầy (Storage Full)",
                cause: "Bộ nhớ iPhone bị đầy ở những giây cuối khi hệ điều hành giải nén gói IPA ra để cài đặt.",
                solution: "Dọn dẹp bớt dung lượng trống trên iPhone (tối thiểu 2-3 GB) rồi bấm Chạy tiếp."
            )
        }
        
        // [2.12] Minimum OS Version Mismatch (Bắt từ thông báo lỗi của installd iOS)
        if fullText.contains("minimumosversion") || fullText.contains("deviceosversiontoohigh") || fullText.contains("deviceosversiontoolow") || fullText.contains("requires ios") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Không hỗ trợ phiên bản iOS hiện tại (OS Version Mismatch)",
                cause: "File IPA yêu cầu phiên bản iOS cao hơn phiên bản iOS hiện tại trên máy của bạn.",
                solution: "Tải phiên bản IPA thấp hơn tương thích với máy hoặc cập nhật iOS."
            )
        }
        
        // [2.13] Device Not Registered in Profile
        if fullText.contains("not included in profile") || fullText.contains("device not registered") || fullText.contains("provisioneddevices") || fullText.contains("0xe800801c") || fullText.contains("no provisioning profile") {
            return DiagnosticErrorItem(
                badge: .device,
                title: "Thiết bị chưa có trong hồ sơ cấp phép (Device Not Registered)",
                cause: "File cấp phép (Provisioning Profile) tải về bị lỗi, không chứa mã UDID của chiếc iPhone hiện tại.",
                solution: "Kiểm tra lại File Pairing đúng của máy này, xoá Cache trong Cài đặt rồi bấm Chạy tiếp."
            )
        }
        
        // [2.14] Corrupted IPA Payload
        if fullText.contains("corrupt") || fullText.contains("invalid bundle") || fullText.contains("missing info.plist") || fullText.contains("missingappbundle") || fullText.contains("packageextractionfailed") || fullText.contains("zip") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Gói cài đặt IPA bị hỏng (Corrupted IPA Payload)",
                cause: "File IPA bị hỏng cấu trúc bên trong, khi đẩy vào tiến trình installd của iOS thì bị từ chối.",
                solution: "Kiểm tra hoặc tải lại file IPA nguyên vẹn khác rồi thử cài lại."
            )
        }
        
        // [2.15] Developer Mode Disabled (iOS 16+)
        if fullText.contains("developer mode") || fullText.contains("chế độ nhà phát triển") || fullText.contains("requires developer mode") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Chưa bật Chế độ nhà phát triển (Developer Mode Disabled)",
                cause: "Đẩy ứng dụng thành công nhưng bị chặn do quên bật 'Chế độ nhà phát triển' trên iOS 16+.",
                solution: "Vào Cài đặt iOS -> Quyền riêng tư & Bảo mật -> Bật 'Chế độ nhà phát triển' và khởi động lại máy."
            )
        }
        
        // [2.9] ApplicationVerificationFailed
        if fullText.contains("applicationverificationfailed") || fullText.contains("verification failed") || fullText.contains("0xe80080") || fullText.contains("code signature") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Lỗi xác minh chữ ký số (ApplicationVerificationFailed)",
                cause: "Chữ ký số ở bước trước bị sai lệch hoặc chứng chỉ bị lỗi, iOS kiểm tra phát hiện ra và từ chối cài.",
                solution: "Vào Cài đặt -> Chứng chỉ để làm mới lại chứng chỉ ký, sau đó bấm Chạy tiếp."
            )
        }
        
        // Bắt mã lỗi Minimuxer 39 (ProfileInstall) hoặc các lỗi kết nối thiết bị khi VPN đã bật
        if code == 39 || code == 8 || fullText.contains("profileinstall") || opError != nil {
            return DiagnosticErrorItem(
                badge: .device,
                title: "Thiết bị từ chối giao tiếp (Invalid Pairing / Lockdown Error)",
                cause: "VPN đã bật nhưng iOS từ chối lệnh cài đặt (Mã \(code)). Thường do bạn đã xoá thiết bị đã liên kết hoặc phiên ghép đôi bị kẹt.",
                solution: "Tắt bật lại LocalDevVPN / StosVPN rồi bấm Chạy tiếp. Nếu vẫn lỗi, hãy tạo lại File Pairing mới trên máy tính."
            )
        }
        
        // Nhánh dự phòng cuối cùng theo từng Giai đoạn
        switch phase {
        case .authorization:
            return DiagnosticErrorItem(
                badge: .apple,
                title: "Gián đoạn bước Xin cấp phép (Mã \(code))",
                cause: error.localizedDescription,
                solution: "Kiểm tra kết nối mạng / Server Anisette rồi bấm Chạy tiếp."
            )
        case .systemPush:
            return DiagnosticErrorItem(
                badge: .device,
                title: "Gián đoạn đẩy ứng dụng vào hệ thống (Mã \(code))",
                cause: error.localizedDescription,
                solution: "Kiểm tra lại LocalDevVPN / StosVPN và File Pairing rồi bấm Chạy tiếp."
            )
        }
    }
    
    /// Hiển thị Bảng Thông Báo Lỗi gọn đẹp với 2 nút: Dừng & Chạy tiếp
    @MainActor
    static func presentDiagnosticErrorAlert(
        phase: MonitoredPhase,
        stepName: String,
        appName: String,
        error: Error
    ) async -> Bool {
        guard let topVC = Self.topViewController() else {
            return false
        }
        
        let diagnosis = Self.diagnoseError(error, phase: phase)
        let nsError = error as NSError
        let rawDetail = "[\(nsError.domain) : \(nsError.code)] \(error.localizedDescription)"
        
        return await withCheckedContinuation { continuation in
            let lock = NSLock()
            var didResume = false
            
            let complete: (Bool) -> Void = { shouldContinue in
                let canResume = lock.withLock {
                    guard !didResume else { return false }
                    didResume = true
                    return true
                }
                guard canResume else { return }
                continuation.resume(returning: shouldContinue)
            }
            
            var hostingController: UIHostingController<CSSErrorPromptModalView>?
            
            let modalView = CSSErrorPromptModalView(
                phase: phase,
                stepName: stepName,
                appName: appName,
                diagnosis: diagnosis,
                rawErrorText: rawDetail,
                onContinue: {
                    if let hc = hostingController {
                        hc.dismiss(animated: true) { complete(true) }
                    } else {
                        complete(true)
                    }
                },
                onStop: {
                    if let hc = hostingController {
                        hc.dismiss(animated: true) { complete(false) }
                    } else {
                        complete(false)
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

// MARK: - 🎨 GIAO DIỆN BẢNG THÔNG BÁO GỌN ĐẸP, DỄ HIỂU (CHUẨN CSS THEME)
private enum CSSErrorTheme {
    static let cornerRadius: CGFloat = 15.0
    static let primary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)       // #007bff
    static let secondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)    // #6f42c1
    static let green = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)         // #28a745
    static let red = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)           // #dc3545
    static let pureBlack = SwiftUI.Color.black
    static let cardBackground = SwiftUI.Color.white
    static let innerRowBackground = SwiftUI.Color(red: 246/255, green: 248/255, blue: 251/255)
    static let border = SwiftUI.Color(red: 218/255, green: 224/255, blue: 233/255)
    static let innerBorder = SwiftUI.Color(red: 222/255, green: 228/255, blue: 236/255)
    
    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255),
                SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.94),
                SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.90)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct CSSErrorBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

private struct CSSErrorPromptModalView: SwiftUI.View {
    let phase: PipelineExecutor.MonitoredPhase
    let stepName: String
    let appName: String
    let diagnosis: PipelineExecutor.DiagnosticErrorItem
    let rawErrorText: String
    let onContinue: () -> Void
    let onStop: () -> Void
    
    @State private var showRawDetails: Bool = false
    
    var body: some SwiftUI.View {
        ZStack {
            SwiftUI.Color.black.opacity(0.45)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                // 1. Header gọn gàng
                HStack(spacing: 8) {
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
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // 2. Nội dung chẩn đoán rõ ràng
                VStack(alignment: .leading, spacing: 10) {
                    // Tên App + Nhãn phân loại lỗi (VPN / Pairing / Thiết bị)
                    HStack {
                        SwiftUI.Text(appName)
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundColor(CSSErrorTheme.primary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        SwiftUI.Text(diagnosis.badge.rawValue)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(diagnosis.badge.color)
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // Lỗi & Nguyên nhân
                    VStack(alignment: .leading, spacing: 4) {
                        SwiftUI.Text(diagnosis.title)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(CSSErrorTheme.pureBlack)
                        
                        SwiftUI.Text(diagnosis.cause)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(CSSErrorTheme.pureBlack.opacity(0.78))
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CSSErrorTheme.innerRowBackground)
                    .cornerRadius(10)
                    
                    // Cách xử lý ngắn gọn
                    HStack(alignment: .top, spacing: 8) {
                        SwiftUI.Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CSSErrorTheme.green)
                            .padding(.top, 1)
                        
                        SwiftUI.Text(diagnosis.solution)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(CSSErrorTheme.pureBlack)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CSSErrorTheme.green.opacity(0.10))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CSSErrorTheme.green.opacity(0.3), lineWidth: 1)
                    )
                    
                    // Chi tiết kỹ thuật (ẩn mặc định cho gọn)
                    SwiftUI.Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            showRawDetails.toggle()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            SwiftUI.Image(systemName: showRawDetails ? "chevron.down" : "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                            SwiftUI.Text("Mã lỗi kỹ thuật (.\(stepName))")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(CSSErrorTheme.secondary)
                    }
                    
                    if showRawDetails {
                        ScrollView {
                            SwiftUI.Text(rawErrorText)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(CSSErrorTheme.pureBlack.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 65)
                        .padding(8)
                        .background(CSSErrorTheme.innerRowBackground)
                        .cornerRadius(8)
                    }
                }
                .padding(13)
                .background(CSSErrorTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: CSSErrorTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CSSErrorTheme.cornerRadius, style: .continuous)
                        .stroke(CSSErrorTheme.border, lineWidth: 1)
                )
                
                // 3. Hai nút: Dừng & Chạy tiếp
                HStack(spacing: 10) {
                    SwiftUI.Button(action: onStop) {
                        HStack(spacing: 6) {
                            SwiftUI.Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            SwiftUI.Text("Dừng")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CSSErrorTheme.red)
                        .cornerRadius(11)
                    }
                    .buttonStyle(CSSErrorBounceButtonStyle())
                    
                    SwiftUI.Button(action: onContinue) {
                        HStack(spacing: 6) {
                            SwiftUI.Image(systemName: "arrow.clockwise.circle.fill")
                                .font(.system(size: 15, weight: .bold))
                            SwiftUI.Text("Chạy tiếp")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(CSSErrorTheme.primary)
                        .cornerRadius(11)
                    }
                    .buttonStyle(CSSErrorBounceButtonStyle())
                }
            }
            .padding(14)
            .background(CSSErrorTheme.pageGradient)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CSSErrorTheme.border, lineWidth: 1.2)
            )
            .shadow(color: SwiftUI.Color.black.opacity(0.22), radius: 18, x: 0, y: 8)
            .padding(.horizontal, 20)
        }
    }
}
