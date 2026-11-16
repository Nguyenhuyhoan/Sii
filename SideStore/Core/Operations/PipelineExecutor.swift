
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
            } catch {
                if Self.isCancellationError(error) {
                    throw OperationError.cancelled
                }
                
                if let phase = Self.monitoredPhase(for: step) {
                    await Self.presentDiagnosticErrorAlertOnce(
                        for: group,
                        phase: phase,
                        stepName: "\(step)",
                        appName: operation.app.name,
                        error: error
                    )
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

// MARK: - 🛡️ HỆ THỐNG CHẨN ĐOÁN LỖI (CHỈ HIỆN ĐÚNG 1 LẦN DUY NHẤT)
extension PipelineExecutor {
    
    // MARK: - 🔒 CHỐT CHẶN HIỂN THỊ 1 LẦN DUY NHẤT
    private static let alertStateLock = NSLock()
    private static var alertedGroupIDs: Set<ObjectIdentifier> = []
    private static var isPresentingDiagnosticAlert: Bool = false
    private static var lastAlertDismissTimestamp: CFAbsoluteTime = 0
    
    /// Kiểm tra xem lỗi có phải là lỗi đã bị huỷ (bao gồm cả `OperationError.cancelled` vốn trả về `CancellationError`)
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
    
    /// Đánh dấu và kiểm tra quyền hiển thị thông báo cho 1 `RefreshGroup` (Chỉ cho phép đúng 1 lần)
    private static func tryAcquireAlertPresentation(for group: RefreshGroup?) -> Bool {
        return alertStateLock.withLock {
            // 1. Nếu đang có 1 bảng thông báo hiện trên màn hình -> chặn tuyệt đối
            if isPresentingDiagnosticAlert {
                return false
            }
            // 2. Nếu group này đã từng hiện thông báo rồi -> chặn tuyệt đối
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
                // Nếu không truyền group, chống hiện trùng lặp trong khoảng 2.5 giây sau khi vừa bấm tắt
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
        case vpn      = "LỖI VPN / MẠNG"
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
    }
    
    /// Trạng thái thực tế của card mạng (`utun`, `pdp_ip`, `en0`) trên iOS
    enum VPNHardwareState: Sendable {
        case connectedLocalDevVPN           // Đã bật đúng LocalDevVPN / StosVPN (có IP 10.7.x.x)
        case disconnectedOnCellularOnly     // Đang bật 4G/5G (không Wi-Fi) nhưng đã tắt LocalDevVPN
        case disconnected                   // Đã tắt LocalDevVPN (đang dùng Wi-Fi hoặc mất mạng)
    }
    
    static func monitoredPhase(for step: PipelineStep) -> MonitoredPhase? {
        switch step {
        // PHẦN 1: Các bước tải ứng dụng, kiểm tra điều kiện, xác thực Apple ID, Anisette, App ID & Chứng chỉ
        case .preflightChecks,
             .downloadApp,
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
    
    // MARK: - 🌐 BỘ DỊCH CÁC CÂU THÔNG BÁO MẶC ĐỊNH CỦA HỆ ĐIỀU HÀNH iOS SANG TIẾNG VIỆT
    static func translateSystemNetworkError(_ text: String) -> String {
        var result = text
        let replacements: [(String, String)] = [
            ("The Internet connection appears to be offline.", "Không có kết nối Internet (Thiết bị đang ngoại tuyến hoặc mạng đã bị ngắt)."),
            ("The internet connection appears to be offline.", "Không có kết nối Internet (Thiết bị đang ngoại tuyến hoặc mạng đã bị ngắt)."),
            ("The Internet connection appears to be offline", "Không có kết nối Internet (Thiết bị đang ngoại tuyến hoặc mạng đã bị ngắt)"),
            ("The network connection was lost.", "Kết nối mạng đã bị ngắt đột ngột trong lúc truyền dữ liệu."),
            ("The request timed out.", "Quá thời gian chờ phản hồi từ máy chủ (Mạng yếu hoặc bị nghẽn)."),
            ("A server with the specified hostname could not be found.", "Không thể phân giải tên miền máy chủ (Lỗi DNS hoặc mất kết nối Internet)."),
            ("Could not connect to the server.", "Không thể kết nối tới máy chủ."),
            ("A data connection is not currently allowed.", "Kết nối dữ liệu di động hiện đang bị chặn hoặc chưa được cấp quyền."),
            ("An SSL error has occurred and a secure connection to the server cannot be made.", "Lỗi bảo mật SSL: Không thể thiết lập kết nối an toàn tới máy chủ.")
        ]
        
        for (english, vietnamese) in replacements {
            if result.localizedCaseInsensitiveContains(english) {
                result = result.replacingOccurrences(of: english, with: vietnamese, options: .caseInsensitive)
            }
        }
        return result
    }
    
    // MARK: - 🔍 QUÉT TRỰC TIẾP CARD MẠNG ĐỂ NHẬN DIỆN: ĐANG BẬT 4G NHƯNG TẮT LOCALDEVVPN (KHÔNG WIFI)
    static func inspectVPNHardwareState() -> VPNHardwareState {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return .disconnected
        }
        defer { freeifaddrs(ifaddr) }
        
        var hasLocalDevIP = false
        var hasCellularIP = false
        var hasWiFiIP = false
        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        
        while let current = ptr {
            let interface = current.pointee
            let name = String(cString: interface.ifa_name)
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            
            if isUp, let addr = interface.ifa_addr {
                let family = addr.pointee.sa_family
                if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                   &hostname, socklen_t(hostname.count),
                                   nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        
                        // Kiểm tra LocalDevVPN / StosVPN (luôn cấp IP 10.7.x.x trên utun)
                        if (name.hasPrefix("utun") || name.hasPrefix("ipsec") || name.hasPrefix("ppp")),
                           ip.hasPrefix("10.7.") {
                            hasLocalDevIP = true
                        }
                        
                        // Kiểm tra Wi-Fi (en0)
                        if name == "en0" && family == UInt8(AF_INET) && !ip.hasPrefix("169.254.") {
                            hasWiFiIP = true
                        }
                        
                        // Kiểm tra dữ liệu di động 4G/5G (pdp_ip0, pdp_ip1...)
                        if name.hasPrefix("pdp_ip") && !ip.hasPrefix("169.254.") && !ip.hasPrefix("fe80") {
                            hasCellularIP = true
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }
        
        if hasLocalDevIP {
            return .connectedLocalDevVPN
        } else if hasCellularIP && !hasWiFiIP {
            return .disconnectedOnCellularOnly
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
    
    // MARK: - 🧠 BỘ CHẨN ĐOÁN LỖI (ĐÃ DỊCH TOÀN BỘ LỖI MẠNG OFFLINE CỦA iOS SANG TIẾNG VIỆT)
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
        // KIỂM TRA LỖI MẤT KẾT NỐI INTERNET CỦA HỆ ĐIỀU HÀNH iOS (-1009, -1020, -1005...)
        // =========================================================================
        if code == -1009 ||
           code == NSURLErrorNotConnectedToInternet ||
           fullText.contains("appears to be offline") ||
           fullText.contains("internet connection appears to be offline") ||
           fullText.contains("notconnectedtointernet") ||
           fullText.contains("-1009") {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Không có kết nối Internet (Ngoại tuyến -1009)",
                cause: "Thiết bị đang mất kết nối mạng Internet (Wi-Fi/4G đã tắt, vừa bị ngắt 4G khi đang gọi máy chủ Apple/Anisette, hoặc cấu hình VPN đang chặn đường truyền Internet)."
            )
        }
        
        if code == -1020 ||
           code == NSURLErrorDataNotAllowed ||
           fullText.contains("data connection is not currently allowed") ||
           fullText.contains("-1020") {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Dữ liệu di động bị chặn cho ứng dụng (Mã -1020)",
                cause: "Quyền sử dụng Dữ liệu di động (4G/5G) của ứng dụng đang bị tắt trong Cài đặt iOS hoặc sóng di động đang bị khóa dữ liệu."
            )
        }
        
        if code == -1003 ||
           code == NSURLErrorCannotFindHost ||
           fullText.contains("specified hostname could not be found") ||
           fullText.contains("-1003") {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Không tìm thấy máy chủ (Lỗi DNS -1003)",
                cause: "Không thể phân giải tên miền tới máy chủ Apple hoặc Anisette do mất mạng Internet hoặc bị lỗi DNS."
            )
        }
        
        if code == -1005 ||
           code == NSURLErrorNetworkConnectionLost ||
           fullText.contains("network connection was lost") ||
           fullText.contains("-1005") {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Kết nối mạng bị ngắt giữa chừng (Mã -1005)",
                cause: "Đường truyền Internet hoặc VPN bị ngắt đột ngột ngay trong lúc đang tải hoặc xác thực dữ liệu."
            )
        }
        
        // =========================================================================
        // KIỂM TRA CÁC LỖI VERIFICATION
        // =========================================================================
        if let verifError = error as? VerificationError {
            switch verifError.code {
            case .iOSVersionNotSupported:
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "Không tương thích phiên bản iOS (Minimum OS Mismatch)",
                    cause: "File IPA yêu cầu phiên bản iOS cao hơn (hoặc khác với) phiên bản iOS hiện tại trên máy của bạn."
                )
            case .mismatchedBundleIdentifiers:
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "Lệch định danh ứng dụng (Mismatched Bundle ID)",
                    cause: "Cố gắng Làm mới / Cài đè ứng dụng nhưng Bundle ID hoặc Apple ID khác với lúc cài đặt ban đầu."
                )
            case .undeclaredPermissions, .addedPermissions:
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Quyền hệ thống đặc biệt không hợp lệ (Invalid Entitlements)",
                    cause: "IPA yêu cầu quyền hệ thống cao cấp (Siri, iCloud đặc biệt...) mà tài khoản Apple miễn phí không được cấp."
                )
            default:
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "Gói cài đặt IPA bị lỗi cấu trúc (Corrupted IPA Payload)",
                    cause: Self.translateSystemNetworkError(verifError.localizedDescription)
                )
            }
        }
        
        // =========================================================================
        // PHẦN 1: BƯỚC “XIN CẤP PHÉP” (Kẹt ở 10% - 30%)
        // =========================================================================
        if phase == .authorization {
            if code == -1001 || code == NSURLErrorTimedOut || fullText.contains("request timed out") {
                return DiagnosticErrorItem(
                    badge: .vpn,
                    title: "Quá thời gian kết nối máy chủ (Timed Out -1001)",
                    cause: "Mạng Internet quá yếu hoặc máy chủ Apple / Anisette phản hồi quá chậm khiến yêu cầu bị hết hạn."
                )
            }
            
            if code == -1004 || code == NSURLErrorCannotConnectToHost || fullText.contains("could not connect to the server") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Không thể kết nối tới máy chủ (Mã -1004)",
                    cause: "Máy chủ Anisette hoặc Apple hiện không phản hồi hoặc đang bị chặn kết nối."
                )
            }
            
            if fullText.contains("anisette") && (fullText.contains("500") || fullText.contains("502") || fullText.contains("503") || fullText.contains("504") || fullText.contains("overload") || fullText.contains("bad gateway")) {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Máy chủ Anisette quá tải (Error 500/502/503)",
                    cause: "Server Anisette đang bị quá tải do có quá nhiều người dùng cùng lúc."
                )
            }
            
            if code == -22421 || fullText.contains("-22421") || fullText.contains("invalid anisette") || fullText.contains("machine data") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Dữ liệu Anisette không hợp lệ (Mã -22421)",
                    cause: "Dữ liệu giả lập máy Mac bị lỗi hoặc quá hạn, máy chủ Apple từ chối nhận."
                )
            }
            
            if fullText.contains("anisette") || fullText.contains("adi.pb") || fullText.contains("provisioning session") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Không lấy được dữ liệu Anisette (Failed to fetch Anisette)",
                    cause: "Server Anisette đang chọn bị sập hoặc không phản hồi."
                )
            }
            
            if opError == .notAuthenticated || code == -29004 || fullText.contains("-29004") || fullText.contains("session has expired") || fullText.contains("not signed in") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Phiên đăng nhập Apple ID đã hết hạn (-29004)",
                    cause: "Phiên đăng nhập Apple ID đã hết hạn hoặc bị đăng xuất, cần xác thực lại."
                )
            }
            
            if code == 9412 || fullText.contains("maximum number of app ids") || fullText.contains("10 app ids") || fullText.contains("max quantity of app ids") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Hết 10 lượt đăng ký App ID trong tuần (Max App IDs)",
                    cause: "Đã dùng hết sạch 10 lượt đăng ký App ID trong 7 ngày của tài khoản Apple miễn phí."
                )
            }
            
            if fullText.contains("maximum number of installed apps") || fullText.contains("3 apps") || fullText.contains("more than 3") || fullText.contains("deactivate") || fullText.contains("active apps limit") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Đã kịch trần 3 ứng dụng hoạt động (Max 3 Apps)",
                    cause: "Tài khoản Apple miễn phí chỉ cho phép tối đa 3 ứng dụng hoạt động cùng lúc trên máy."
                )
            }
            
            if code == -20209 || fullText.contains("-20209") || fullText.contains("locked") || fullText.contains("disabled for security") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Tài khoản Apple ID bị khóa bảo mật (Apple ID Locked)",
                    cause: "Tài khoản Apple bị khóa bảo mật do đăng nhập từ địa chỉ IP lạ (của máy chủ Anisette)."
                )
            }
            
            if code == -20101 || code == -22406 || fullText.contains("-20101") || fullText.contains("incorrect") || fullText.contains("invalid username or password") || fullText.contains("bad password") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Sai mật khẩu Apple ID (Incorrect Credentials -20101)",
                    cause: "Nhập sai mật khẩu Apple ID hoặc bạn vừa đổi mật khẩu nhưng chưa cập nhật trong ứng dụng."
                )
            }
            
            if code == -21669 || fullText.contains("verification code") || fullText.contains("two-factor") || fullText.contains("2fa") || fullText.contains("security code") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Lỗi mã xác thực 2 bước (2FA Verification Error)",
                    cause: "Nhập sai mã xác thực 2 yếu tố (2FA) hoặc mã xác thực đã hết hạn."
                )
            }
            
            if fullText.contains("license agreement") || fullText.contains("terms") || fullText.contains("pla") || fullText.contains("accept the updated") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Cần đồng ý Điều khoản Apple mới (License Agreement)",
                    cause: "Apple vừa cập nhật điều khoản Developer mới, bắt buộc phải đồng ý trước khi ký ứng dụng."
                )
            }
            
            if case .certificateRevoked = opError {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chứng chỉ đã bị thu hồi (Certificate Revoked)",
                    cause: "Chứng chỉ hiện tại bị thu hồi hoặc bạn vừa bấm 'Revoke' trên một thiết bị/máy tính khác."
                )
            }
            if case .customCertificateRevoked = opError {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chứng chỉ đã bị thu hồi (Certificate Revoked)",
                    cause: "Chứng chỉ hiện tại đã bị thu hồi trên cổng Apple Developer."
                )
            }
            if fullText.contains("revoked") || fullText.contains("certificate expired") || fullText.contains("no signing certificate") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chứng chỉ bị thu hồi hoặc hết hạn (Certificate Revoked)",
                    cause: "Chứng chỉ hiện tại bị thu hồi hoặc bạn vừa bấm 'Revoke' trên thiết bị khác."
                )
            }
            
            if code == 9401 || fullText.contains("not available") || fullText.contains("bundle identifier is not available") || fullText.contains("already in use") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Tên định danh bị trùng (App ID Not Available)",
                    cause: "Tên định danh (Bundle ID) của ứng dụng bị trùng với một người khác đã đăng ký trước trên Apple."
                )
            }
            
            if code == -1200 || code == -1202 || code == -9806 || fullText.contains("ssl") || fullText.contains("tls") || fullText.contains("handshake") || fullText.contains("secure connection") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Lỗi kết nối bảo mật (SSL / TLS Handshake Failed)",
                    cause: "Mạng đang dùng chặn kết nối bảo mật tới máy chủ Apple hoặc Anisette."
                )
            }
            
            if fullText.contains("maintenance") || fullText.contains("unavailable") || fullText.contains("down for maintenance") || code == 503 {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Máy chủ Apple đang bảo trì (Developer Maintenance)",
                    cause: "Hệ thống máy chủ dành cho lập trình viên của Apple đang bảo trì định kỳ."
                )
            }
            
            if fullText.contains("entitlement") || (fullText.contains("provisioning profile") && fullText.contains("capability")) {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Quyền hệ thống không được cấp (Invalid Entitlements)",
                    cause: "IPA yêu cầu quyền hệ thống cao cấp (như Siri, iCloud đặc biệt) mà tài khoản Free không được cấp."
                )
            }
        }
        
        // =========================================================================
        // PHẦN 2: BƯỚC “ĐẨY VÀO HỆ THỐNG” (Kẹt ở 70% - 85%)
        // =========================================================================
        
        // [2.3] Pairing File Not Found
        if !hasPairingFile || (opError != nil && { if case .pairingNotComplete = opError! { return true }; return false }()) {
            return DiagnosticErrorItem(
                badge: .pairing,
                title: "Chưa nạp File ghép đôi (Pairing File Not Found)",
                cause: "Chưa nạp file ghép đôi (.mobiledevicepairing / rppairing) vào ứng dụng hoặc file đã bị xoá."
            )
        }
        
        // [2.4] Local Network Permission Denied
        if fullText.contains("local network") || fullText.contains("necperror") || fullText.contains("permission denied") || fullText.contains("no route to host") || code == 65 {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Chưa bật quyền Mạng cục bộ (Local Network Denied)",
                cause: "Quyền 'Mạng cục bộ' (Local Network) trong Cài đặt iOS đang bị tắt."
            )
        }
        
        // [2.5] Đã bật 4G nhưng tắt LocalDevVPN (không Wi-Fi)
        if vpnState == .disconnectedOnCellularOnly {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Đang bật 4G nhưng đã tắt LocalDevVPN (Không có Wi-Fi)",
                cause: "Máy đang sử dụng dữ liệu di động 4G (không có Wi-Fi) nhưng đã tắt LocalDevVPN nên không có đường truyền nội bộ (10.7.0.1) để đẩy vào hệ thống."
            )
        }
        
        // [2.1] Đã tắt LocalDevVPN (trên Wi-Fi hoặc mất kết nối VPN)
        if vpnState == .disconnected {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Chưa bật LocalDevVPN (Unable to connect to device)",
                cause: "LocalDevVPN đang tắt nên không tìm thấy đường truyền nội bộ (10.7.0.1) để giao tiếp với thiết bị."
            )
        }
        
        // [2.8] Lỗi mạng 4G / Cách ly Wi-Fi
        if let opError, case .invalidVPN(let reason) = opError, reason.lowercased().contains("wireguard") {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Đang bật 4G nhưng thiếu kết nối LocalDevVPN",
                cause: "Đang dùng mạng 4G nhưng chưa chuyển sang đường truyền nội bộ LocalDevVPN để đẩy ứng dụng."
            )
        }
        if let opError, case .noConnection = opError {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Đang bật 4G (Không Wi-Fi) hoặc tắt LocalDevVPN",
                cause: "Thiết bị đang bật 4G (không có Wi-Fi) và chưa kết nối LocalDevVPN."
            )
        }
        
        // [2.2] Invalid Pairing File / Lockdown Error
        if isConnectionReset ||
           fullText.contains("lockdown") ||
           fullText.contains("invalid pairing") ||
           fullText.contains("invalid hostid") ||
           fullText.contains("pair record") ||
           (opError != nil && { if case .invalidPairingFile = opError! { return true }; return false }()) {
            return DiagnosticErrorItem(
                badge: .device,
                title: "Thiết bị đã huỷ liên kết (Invalid Pairing / Lockdown Error)",
                cause: "LocalDevVPN đã bật nhưng iOS từ chối kết nối (Code 54: Connection reset). Do đã xoá thiết bị liên kết, đổi mật khẩu màn hình khóa hoặc mới cập nhật iOS."
            )
        }
        
        // [2.6] Connection Timed Out (mux error)
        if opError == .timedOut || fullText.contains("timed out") || fullText.contains("timeout") || fullText.contains("mux error") || (fullText.contains("afc") && fullText.contains("broken pipe")) {
            return DiagnosticErrorItem(
                badge: .vpn,
                title: "Nghẽn đường truyền nội bộ (Connection Timed Out)",
                cause: "Mạng nội bộ bị nghẽn hoặc quá hạn khi đang đẩy gói cài đặt IPA."
            )
        }
        
        // [2.7] Background Task Killed
        if fullText.contains("background") || fullText.contains("interrupted") || fullText.contains("connection abort") || code == 53 || code == -997 {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Bị ngắt do thoát ứng dụng (Background Task Killed)",
                cause: "Thoát ứng dụng ra ngoài hoặc màn hình tự tắt khiến iOS ngắt kết nối truyền dữ liệu ngầm."
            )
        }
        
        // [2.10] Mismatched Bundle ID
        if fullText.contains("mismatchedbundleid") || fullText.contains("mismatchedapplicationidentifierentitlement") || fullText.contains("upgrade's application-identifier") || fullText.contains("already installed") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Trùng ứng dụng khác tài khoản (Mismatched Bundle ID)",
                cause: "Cố gắng Refresh / Cài đè một ứng dụng nhưng lại dùng Apple ID khác với lúc cài đặt ban đầu."
            )
        }
        
        // [2.11] Storage Full
        if code == 28 || fullText.contains("disk quota") || fullText.contains("no space left") || fullText.contains("storage") || fullText.contains("not enough space") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Bộ nhớ iPhone đã đầy (Storage Full)",
                cause: "Bộ nhớ iPhone bị đầy khi hệ điều hành giải nén gói IPA ra để cài đặt."
            )
        }
        
        // [2.12] Minimum OS Version Mismatch
        if fullText.contains("minimumosversion") || fullText.contains("deviceosversiontoohigh") || fullText.contains("deviceosversiontoolow") || fullText.contains("requires ios") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Không hỗ trợ phiên bản iOS hiện tại (OS Version Mismatch)",
                cause: "File IPA yêu cầu phiên bản iOS cao hơn phiên bản iOS hiện tại trên máy của bạn."
            )
        }
        
        // [2.13] Device Not Registered in Profile
        if fullText.contains("not included in profile") || fullText.contains("device not registered") || fullText.contains("provisioneddevices") || fullText.contains("0xe800801c") || fullText.contains("no provisioning profile") {
            return DiagnosticErrorItem(
                badge: .device,
                title: "Thiết bị chưa có trong hồ sơ cấp phép (Device Not Registered)",
                cause: "File cấp phép (Provisioning Profile) tải về không chứa mã UDID của chiếc iPhone hiện tại."
            )
        }
        
        // [2.14] Corrupted IPA Payload
        if fullText.contains("corrupt") || fullText.contains("invalid bundle") || fullText.contains("missing info.plist") || fullText.contains("missingappbundle") || fullText.contains("packageextractionfailed") || fullText.contains("zip") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Gói cài đặt IPA bị hỏng (Corrupted IPA Payload)",
                cause: "File IPA bị hỏng cấu trúc bên trong, khi đẩy vào tiến trình installd của iOS thì bị từ chối."
            )
        }
        
        // [2.15] Developer Mode Disabled (iOS 16+)
        if fullText.contains("developer mode") || fullText.contains("chế độ nhà phát triển") || fullText.contains("requires developer mode") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Chưa bật Chế độ nhà phát triển (Developer Mode Disabled)",
                cause: "Đẩy ứng dụng thành công nhưng bị chặn do chưa bật 'Chế độ nhà phát triển' trên iOS 16+."
            )
        }
        
        // [2.9] ApplicationVerificationFailed
        if fullText.contains("applicationverificationfailed") || fullText.contains("verification failed") || fullText.contains("0xe80080") || fullText.contains("code signature") {
            return DiagnosticErrorItem(
                badge: .system,
                title: "Lỗi xác minh chữ ký số (ApplicationVerificationFailed)",
                cause: "Chữ ký số ở bước trước bị sai lệch hoặc chứng chỉ bị lỗi, iOS kiểm tra phát hiện ra và từ chối cài."
            )
        }
        
        // Bắt mã lỗi Minimuxer 39 (ProfileInstall) hoặc các lỗi kết nối thiết bị khi VPN đã bật
        if code == 39 || code == 8 || fullText.contains("profileinstall") || opError != nil {
            return DiagnosticErrorItem(
                badge: .device,
                title: "Thiết bị từ chối giao tiếp (Invalid Pairing / Lockdown Error)",
                cause: "LocalDevVPN đã bật nhưng iOS từ chối lệnh cài đặt (Mã \(code)). Thường do đã xoá thiết bị đã liên kết hoặc phiên ghép đôi bị kẹt."
            )
        }
        
        // Nhánh dự phòng cuối cùng theo từng Giai đoạn (Đã dịch tự động các câu thông báo mạng tiếng Anh của iOS)
        let translatedFallback = Self.translateSystemNetworkError(error.localizedDescription)
        switch phase {
        case .authorization:
            return DiagnosticErrorItem(
                badge: .apple,
                title: "Gián đoạn bước Xin cấp phép (Mã \(code))",
                cause: translatedFallback
            )
        case .systemPush:
            return DiagnosticErrorItem(
                badge: .device,
                title: "Gián đoạn đẩy ứng dụng vào hệ thống (Mã \(code))",
                cause: translatedFallback
            )
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
        // Nếu lỗi là Cancelled thì không bao giờ hiện bảng báo lỗi
        guard !Self.isCancellationError(error) else {
            return
        }
        
        // Chốt chặn: Đảm bảo chỉ hiện 1 lần duy nhất cho mỗi đợt thao tác (group)
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
        
        let diagnosis = Self.diagnoseError(error, phase: phase)
        let nsError = error as NSError
        let translatedDesc = Self.translateSystemNetworkError(error.localizedDescription)
        let rawDetail = "[\(nsError.domain) : \(nsError.code)] \(translatedDesc)"
        
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
                appName: appName,
                diagnosis: diagnosis,
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
    
    /// Giữ hàm tương thích nếu được gọi từ nơi không truyền `group`
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

// MARK: - 🎨 GIAO DIỆN BẢNG THÔNG BÁO GỌN ĐẸP (1 NÚT "TẮT THÔNG BÁO", KHÔNG HƯỚNG DẪN FIX LỖI)
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
    let onDismiss: () -> Void
    
    @State private var showRawDetails: Bool = false
    @State private var didTapDismiss: Bool = false
    
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
                
                // 2. Nội dung chẩn đoán rõ ràng (Không có hướng dẫn fix lỗi)
                VStack(alignment: .leading, spacing: 10) {
                    // Tên App + Nhãn phân loại lỗi
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
                
                // 3. Một nút duy nhất: Tắt Thông Báo
                SwiftUI.Button {
                    guard !didTapDismiss else { return }
                    didTapDismiss = true
                    onDismiss()
                } label: {
                    HStack(spacing: 6) {
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
