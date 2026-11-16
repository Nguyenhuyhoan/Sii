
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

// MARK: - 🛡️ HỆ THỐNG CHẨN ĐOÁN CHÍNH XÁC (VPN / FILE PAIRING / THIẾT BỊ / APPLE)
extension PipelineExecutor {
    
    enum MonitoredPhase: Sendable {
        case authorization  // Giai đoạn 1: Xin cấp phép Apple / Anisette
        case systemPush     // Giai đoạn 2: Kết nối VPN / Pairing / Cài vào máy
        
        var title: String {
            switch self {
            case .authorization: return "XÁC THỰC APPLE & CHỨNG CHỈ"
            case .systemPush:    return "KẾT NỐI NỘI BỘ & CÀI ĐẶT"
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
        case device   = "LỖI THIẾT BỊ GHẾP NỐI"
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
    
    static func monitoredPhase(for step: PipelineStep) -> MonitoredPhase? {
        switch step {
        case .verifyCertificate, .fetchProvisioningProfiles, .prepareAppExtensionBundleIDs, .updateAppCertificate:
            return .authorization
        case .sendApp, .installApp, .refreshApp:
            return .systemPush
        default:
            return nil
        }
    }
    
    /// Chẩn đoán chính xác tuyệt đối dựa trên kiểu dữ liệu `OperationError`, `MinimuxerError` và `PairingFileManager`
    static func diagnoseError(_ error: Error, phase: MonitoredPhase) -> DiagnosticErrorItem {
        // Bóc tách MinimuxerError sang OperationError nếu có
        let opError: OperationError? = {
            if let direct = error as? OperationError { return direct }
            if let minErr = error as? MinimuxerError { return minErr.asOperationError }
            return nil
        }()
        
        let nsError = error as NSError
        let code = nsError.code
        let fullText = "\(nsError.domain) \(code) \(error.localizedDescription) \(String(describing: error))".lowercased()
        
        // =========================================================================
        // 1. BẮT TRỰC TIẾP THEO ENUM `OperationError` (CHÍNH XÁC 100%)
        // =========================================================================
        if let opError {
            switch opError {
            case .noVPN(let reason), .invalidVPN(let reason):
                let isWireGuard4G = reason.lowercased().contains("wireguard")
                return DiagnosticErrorItem(
                    badge: .vpn,
                    title: isWireGuard4G ? "WireGuard không hỗ trợ làm mới 4G" : "Chưa bật VPN hoặc sai cấu hình VPN",
                    cause: isWireGuard4G ? "iOS tự ngắt hầm WireGuard khi tắt dữ liệu di động." : "SideStore không tìm thấy đường truyền LocalDevVPN / StosVPN.",
                    solution: isWireGuard4G ? "Hãy đổi sang dùng StosVPN / LocalDevVPN rồi bấm Chạy tiếp." : "Mở StosVPN / LocalDevVPN bật kết nối lên (tắt các VPN khác) rồi bấm Chạy tiếp."
                )
                
            case .pairingNotComplete:
                return DiagnosticErrorItem(
                    badge: .pairing,
                    title: "Chưa nạp File ghép đôi (Pairing File)",
                    cause: "Trong SideStore hiện chưa có file ghép đôi (.mobiledevicepairing / rppairing).",
                    solution: "Vào Cài đặt -> File ghép đôi để nạp file mới rồi bấm Chạy tiếp."
                )
                
            case .invalidPairingFile:
                return DiagnosticErrorItem(
                    badge: .pairing,
                    title: "File ghép đôi (Pairing File) bị hỏng hoặc hết hạn",
                    cause: "iOS từ chối ghép nối (thường do vừa cập nhật iOS, đổi mật khẩu máy hoặc nhấn 'Không tin cậy').",
                    solution: "Cắm máy vào PC, tạo lại Pairing File mới bằng iloader / idevicepair và nạp lại."
                )
                
            case .unknownUDID:
                if !PairingFileManager.shared.hasPairingFile() {
                    return DiagnosticErrorItem(
                        badge: .pairing,
                        title: "Chưa có File ghép đôi (Không lấy được UDID)",
                        cause: "SideStore chưa có file ghép đôi để đọc mã UDID của máy.",
                        solution: "Nạp file ghép đôi vào SideStore rồi bấm Chạy tiếp."
                    )
                }
                return DiagnosticErrorItem(
                    badge: .device,
                    title: "Không đọc được mã UDID từ thiết bị",
                    cause: "Kết nối tới thiết bị bị nghẽn hoặc File Pairing đã mất hiệu lực.",
                    solution: "Tắt bật lại StosVPN rồi bấm Chạy tiếp. Nếu vẫn lỗi, hãy tạo lại File Pairing."
                )
                
            case .minimuxerNotStarted:
                if !PairingFileManager.shared.hasPairingFile() {
                    return DiagnosticErrorItem(
                        badge: .pairing,
                        title: "Chưa nạp File ghép đôi để khởi động dịch vụ",
                        cause: "Minimuxer không thể chạy vì thiếu File Pairing.",
                        solution: "Vào Cài đặt nạp lại File Pairing rồi bấm Chạy tiếp."
                    )
                }
                return DiagnosticErrorItem(
                    badge: .device,
                    title: "Dịch vụ ghép nối (Minimuxer) chưa sẵn sàng",
                    cause: "Tiến trình kết nối nội bộ chưa khởi chạy xong.",
                    solution: "Đảm bảo đã bật StosVPN rồi bấm Chạy tiếp."
                )
                
            case .noDevice, .notReachable, .noConnection:
                // Phân tích sâu xem lỗi là do thiếu Pairing, chưa bật VPN hay do Thiết bị
                if !PairingFileManager.shared.hasPairingFile() {
                    return DiagnosticErrorItem(
                        badge: .pairing,
                        title: "Thiếu File ghép đôi (Pairing File)",
                        cause: "Không tìm thấy file ghép đôi hợp lệ trong SideStore.",
                        solution: "Nạp lại file ghép đôi (.mobiledevicepairing) rồi bấm Chạy tiếp."
                    )
                }
                if fullText.contains("lockdown") || fullText.contains("hostid") || fullText.contains("invalid host") || fullText.contains("pairing") {
                    return DiagnosticErrorItem(
                        badge: .pairing,
                        title: "File ghép đôi bị thiết bị từ chối",
                        cause: "File Pairing hiện tại không còn khớp với iOS trên máy.",
                        solution: "Tạo và nạp lại File Pairing mới từ máy tính."
                    )
                }
                return DiagnosticErrorItem(
                    badge: .device,
                    title: "Không thể kết nối tới thiết bị ghép nối",
                    cause: "VPN chưa bật, hoặc đang dùng 4G nhưng chưa ngắt IP di động sang hầm VPN.",
                    solution: "Bật StosVPN (nếu dùng 4G hãy bật chế độ Làm mới 4G trong Cài đặt) rồi bấm Chạy tiếp."
                )
                
            case .timedOut:
                return DiagnosticErrorItem(
                    badge: .vpn,
                    title: "Quá thời gian truyền dữ liệu (Timeout)",
                    cause: "Đường truyền VPN nội bộ bị nghẽn khi đang đẩy dữ liệu vào máy.",
                    solution: "Tắt bật lại StosVPN, giữ sáng màn hình rồi bấm Chạy tiếp."
                )
                
            case .certificateExpired, .certificateRevoked, .customCertificateExpired, .customCertificateRevoked:
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chứng chỉ ký (Certificate) đã hết hạn hoặc bị thu hồi",
                    cause: "Chứng chỉ trên Apple Developer không còn hiệu lực.",
                    solution: "Bấm Chạy tiếp để làm mới chứng chỉ, hoặc vào Cài đặt -> Chứng chỉ để tạo lại."
                )
                
            case .notAuthenticated:
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Chưa đăng nhập tài khoản Apple ID",
                    cause: "Phiên đăng nhập Apple ID đã thoát hoặc hết hạn.",
                    solution: "Vào Cài đặt đăng nhập lại Apple ID rồi thử lại."
                )
                
            default:
                break
            }
        }
        
        // =========================================================================
        // 2. PHÂN TÍCH CHI TIẾT THEO GIAI ĐOẠN (NẾU LÀ LỖI TỪ BÊN NGOÀI / iOS / APPLE)
        // =========================================================================
        switch phase {
        case .authorization:
            if fullText.contains("anisette") || fullText.contains("500") || fullText.contains("502") || fullText.contains("503") || code == -22421 {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Lỗi máy chủ Anisette (Mã \(code))",
                    cause: "Máy chủ Anisette đang quá tải hoặc dữ liệu giả lập máy Mac bị lỗi.",
                    solution: "Vào Cài đặt đổi máy chủ Anisette khác (hoặc tắt On-Device Anisette) rồi bấm Chạy tiếp."
                )
            }
            if code == -29004 || fullText.contains("session has expired") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Phiên đăng nhập Apple ID hết hạn (-29004)",
                    cause: "Phiên làm việc với máy chủ Apple đã hết hiệu lực.",
                    solution: "Bấm Chạy tiếp để thử lại, hoặc đăng nhập lại Apple ID trong Cài đặt."
                )
            }
            if fullText.contains("maximum number of app ids") || code == 9412 {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Đã hết lượt đăng ký 10 App ID trong tuần",
                    cause: "Tài khoản Apple miễn phí chỉ cấp tối đa 10 App ID mỗi 7 ngày.",
                    solution: "Chờ App ID cũ hết hạn hoặc đổi sang tài khoản Apple ID phụ khác."
                )
            }
            if fullText.contains("locked") || code == -20209 {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Tài khoản Apple ID bị khóa bảo mật",
                    cause: "Apple tạm khóa tài khoản do đăng nhập qua IP của máy chủ Anisette.",
                    solution: "Mở khóa tại iforgot.apple.com rồi quay lại bấm Chạy tiếp."
                )
            }
            if code == -1009 || code == -1200 || fullText.contains("ssl") || fullText.contains("network") {
                return DiagnosticErrorItem(
                    badge: .apple,
                    title: "Mất kết nối mạng khi liên hệ máy chủ Apple",
                    cause: "Điện thoại đang tắt mạng Internet (4G/Wi-Fi) hoặc bị chặn kết nối tới Apple.",
                    solution: "Bật mạng Internet lên rồi bấm Chạy tiếp."
                )
            }
            return DiagnosticErrorItem(
                badge: .apple,
                title: "Gián đoạn xin cấp phép từ Apple (Mã \(code))",
                cause: error.localizedDescription,
                solution: "Kiểm tra kết nối mạng và bấm Chạy tiếp để thử lại bước này."
            )
            
        case .systemPush:
            // Kiểm tra trực tiếp file pairing trên máy trước tiên
            if !PairingFileManager.shared.hasPairingFile() {
                return DiagnosticErrorItem(
                    badge: .pairing,
                    title: "Chưa tìm thấy File ghép đôi (Pairing File)",
                    cause: "SideStore chưa được nạp file ghép đôi để giao tiếp với iOS.",
                    solution: "Nạp file ghép đôi vào SideStore rồi bấm Chạy tiếp."
                )
            }
            if fullText.contains("lockdown") || fullText.contains("invalid pairing") || fullText.contains("hostid") || fullText.contains("pair") {
                return DiagnosticErrorItem(
                    badge: .pairing,
                    title: "File ghép đôi (Pairing File) hết hiệu lực",
                    cause: "Thiết bị từ chối xác thực Lockdown với File Pairing hiện tại.",
                    solution: "Tạo lại File Pairing mới trên máy tính rồi nạp lại vào SideStore."
                )
            }
            if fullText.contains("local network") || fullText.contains("necperror") || fullText.contains("permission denied") {
                return DiagnosticErrorItem(
                    badge: .vpn,
                    title: "Chưa cấp quyền Mạng cục bộ (Local Network)",
                    cause: "Quyền Mạng cục bộ của SideStore trong Cài đặt iOS đang bị tắt.",
                    solution: "Vào Cài đặt iOS -> SideStore -> Bật 'Mạng cục bộ' rồi bấm Chạy tiếp."
                )
            }
            if fullText.contains("vpn") || fullText.contains("tunnel") {
                return DiagnosticErrorItem(
                    badge: .vpn,
                    title: "Lỗi kết nối hầm VPN nội bộ",
                    cause: "Chưa bật StosVPN/LocalDevVPN hoặc đang xung đột với ứng dụng VPN khác.",
                    solution: "Chỉ bật duy nhất StosVPN/LocalDevVPN rồi bấm Chạy tiếp."
                )
            }
            if fullText.contains("timed out") || fullText.contains("timeout") || fullText.contains("afc") || fullText.contains("broken pipe") {
                return DiagnosticErrorItem(
                    badge: .vpn,
                    title: "Ngắt quãng đường truyền VPN khi đẩy gói cài đặt",
                    cause: "Kết nối tới thiết bị bị nghẽn hoặc ứng dụng bị đưa xuống nền.",
                    solution: "Tắt bật lại StosVPN, giữ sáng màn hình rồi bấm Chạy tiếp."
                )
            }
            if fullText.contains("verification failed") || fullText.contains("applicationverificationfailed") || fullText.contains("0xe80080") {
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "iOS từ chối xác minh chữ ký ứng dụng",
                    cause: "Chữ ký hoặc Provisioning Profile không khớp với thiết bị (lỗi installd).",
                    solution: "Bấm Chạy tiếp để cài lại, hoặc làm mới lại chứng chỉ trong Cài đặt."
                )
            }
            if fullText.contains("storage") || fullText.contains("disk") || fullText.contains("no space") || code == 28 {
                return DiagnosticErrorItem(
                    badge: .system,
                    title: "Bộ nhớ thiết bị đã đầy",
                    cause: "Không đủ dung lượng trống để iOS giải nén và cài đặt ứng dụng.",
                    solution: "Xóa bớt dữ liệu không cần thiết rồi bấm Chạy tiếp."
                )
            }
            return DiagnosticErrorItem(
                badge: .device,
                title: "Không thể giao tiếp với thiết bị (Mã \(code))",
                cause: "Kết nối giữa SideStore và hệ thống iOS bị gián đoạn.",
                solution: "Kiểm tra lại StosVPN (hoặc nạp lại File Pairing nếu đã bật VPN) rồi bấm Chạy tiếp."
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
