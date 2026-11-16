
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

// MARK: - 🛡️ HỆ THỐNG CHẨN ĐOÁN 30 LỖI & BẢNG THÔNG BÁO CHUẨN GIAO DIỆN CSS THEME
extension PipelineExecutor {
    
    enum MonitoredPhase: Sendable {
        case authorization  // Giai đoạn 1: Xin cấp phép (10% - 30%)
        case systemPush     // Giai đoạn 2: Đẩy vào hệ thống (70% - 85%)
        
        var title: String {
            switch self {
            case .authorization:
                return "GIAI ĐOẠN 1: XIN CẤP PHÉP"
            case .systemPush:
                return "GIAI ĐOẠN 2: ĐẨY VÀO HỆ THỐNG"
            }
        }
        
        var subtitle: String {
            switch self {
            case .authorization:
                return "Giao tiếp máy chủ Apple Developer & Anisette (10% - 30%)"
            case .systemPush:
                return "Giao tiếp nội bộ VPN Loopback & iOS Lockdown (70% - 85%)"
            }
        }
        
        var icon: String {
            switch self {
            case .authorization:
                return "key.shield.fill"
            case .systemPush:
                return "arrow.up.doc.on.clipboard"
            }
        }
    }
    
    struct DiagnosticErrorItem: Sendable {
        let number: Int
        let title: String
        let cause: String
        let solution: String
    }
    
    /// Chỉ lọc các bước thuộc 2 giai đoạn: Xin cấp phép & Đẩy vào hệ thống
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
    
    /// Bộ phân tích và đối chiếu 30 lỗi chi tiết của 2 giai đoạn
    static func diagnoseError(_ error: Error, phase: MonitoredPhase) -> DiagnosticErrorItem {
        let nsError = error as NSError
        let code = nsError.code
        let domain = nsError.domain.lowercased()
        let desc = error.localizedDescription.lowercased()
        let fullText = "\(domain) \(code) \(desc) \(String(describing: error).lowercased())"
        
        switch phase {
        case .authorization:
            // 1. Failed to fetch Anisette data
            if fullText.contains("fetch anisette") || fullText.contains("anisette server") || fullText.contains("could not connect to anisette") {
                return DiagnosticErrorItem(
                    number: 1,
                    title: "Lỗi #1: Không thể lấy dữ liệu Anisette (Failed to fetch Anisette)",
                    cause: "Máy chủ Anisette bạn đang chọn bị sập hoặc không phản hồi.",
                    solution: "Vào mục Cài đặt -> Máy chủ Anisette -> Đổi sang máy chủ khác (khuyên dùng SideStore New) rồi bấm Chạy tiếp."
                )
            }
            // 2. Anisette Error (500/502/503)
            if fullText.contains("500") || fullText.contains("502") || fullText.contains("503") || fullText.contains("bad gateway") || fullText.contains("service unavailable") {
                return DiagnosticErrorItem(
                    number: 2,
                    title: "Lỗi #2: Máy chủ Anisette quá tải (HTTP 500/502/503)",
                    cause: "Máy chủ Anisette đang có quá nhiều người truy cập cùng lúc.",
                    solution: "Đợi khoảng 5-10 giây rồi bấm Chạy tiếp, hoặc đổi sang máy chủ Anisette khác trong Cài đặt."
                )
            }
            // 3. Invalid Anisette Data (-22421)
            if code == -22421 || fullText.contains("-22421") || fullText.contains("invalid anisette") || fullText.contains("machine data") {
                return DiagnosticErrorItem(
                    number: 3,
                    title: "Lỗi #3: Dữ liệu Anisette không hợp lệ (-22421)",
                    cause: "Dữ liệu giả lập máy Mac bị lỗi hoặc hết hạn, máy chủ Apple từ chối nhận.",
                    solution: "Tắt Use On-Device Anisette trong Cài đặt, chọn máy chủ SideStore (New) rồi bấm Chạy tiếp."
                )
            }
            // 4. Your session has expired (-29004)
            if code == -29004 || fullText.contains("-29004") || fullText.contains("session has expired") || fullText.contains("not authenticated") {
                return DiagnosticErrorItem(
                    number: 4,
                    title: "Lỗi #4: Phiên đăng nhập Apple ID đã hết hạn (-29004)",
                    cause: "Phiên xác thực với Apple đã quá hạn hoặc bị gián đoạn.",
                    solution: "Bấm Chạy tiếp để thử xác thực lại. Nếu vẫn lỗi, hãy bấm Dừng và đăng nhập lại Apple ID trong Cài đặt."
                )
            }
            // 5. Maximum number of App IDs reached
            if fullText.contains("maximum number of app ids") || fullText.contains("max quantity") || fullText.contains("10 app ids") || code == 9412 {
                return DiagnosticErrorItem(
                    number: 5,
                    title: "Lỗi #5: Đạt giới hạn tối đa 10 App ID trong 7 ngày",
                    cause: "Tài khoản Apple miễn phí chỉ được đăng ký tối đa 10 App ID mỗi tuần.",
                    solution: "Bấm Dừng và chờ App ID cũ hết hạn sau 7 ngày, hoặc dùng một tài khoản Apple ID phụ khác."
                )
            }
            // 6. Maximum number of apps installed (3 apps)
            if fullText.contains("maximum number of apps") || fullText.contains("3 apps") || fullText.contains("active apps limit") {
                return DiagnosticErrorItem(
                    number: 6,
                    title: "Lỗi #6: Vượt quá giới hạn 3 ứng dụng đang hoạt động",
                    cause: "Tài khoản miễn phí chỉ cho phép kích hoạt tối đa 3 ứng dụng cùng lúc trên thiết bị.",
                    solution: "Huỷ kích hoạt (Deactivate) bớt 1 ứng dụng trong tab Ứng dụng của tôi rồi thử lại."
                )
            }
            // 7. Apple ID Locked
            if fullText.contains("locked") || fullText.contains("-20209") || fullText.contains("security reasons") {
                return DiagnosticErrorItem(
                    number: 7,
                    title: "Lỗi #7: Tài khoản Apple ID bị khóa bảo mật",
                    cause: "Apple tạm khóa tài khoản do phát hiện đăng nhập từ địa chỉ IP lạ của máy chủ Anisette.",
                    solution: "Truy cập iforgot.apple.com để mở khóa tài khoản, sau đó quay lại bấm Chạy tiếp."
                )
            }
            // 8. Incorrect Credentials (-20101)
            if code == -20101 || fullText.contains("-20101") || fullText.contains("incorrect") || fullText.contains("invalid username or password") {
                return DiagnosticErrorItem(
                    number: 8,
                    title: "Lỗi #8: Sai thông tin đăng nhập Apple ID (-20101)",
                    cause: "Mật khẩu Apple ID không đúng hoặc bạn vừa đổi mật khẩu mới.",
                    solution: "Bấm Dừng, vào Cài đặt đăng xuất và đăng nhập lại bằng mật khẩu mới."
                )
            }
            // 9. 2FA Failed / Verification Code Error
            if fullText.contains("verification code") || fullText.contains("two-factor") || fullText.contains("2fa") || code == -21669 {
                return DiagnosticErrorItem(
                    number: 9,
                    title: "Lỗi #9: Xác thực 2 yếu tố (2FA) thất bại",
                    cause: "Mã xác thực 6 số nhập sai hoặc đã hết thời gian hiệu lực.",
                    solution: "Bấm Chạy tiếp để yêu cầu gửi lại mã xác thực mới và nhập chính xác."
                )
            }
            // 10. License Agreement Updated
            if fullText.contains("license agreement") || fullText.contains("PLA") || fullText.contains("terms") {
                return DiagnosticErrorItem(
                    number: 10,
                    title: "Lỗi #10: Cần chấp thuận Điều khoản Nhà phát triển mới",
                    cause: "Apple vừa cập nhật điều khoản Developer, yêu cầu xác nhận trước khi cấp chứng chỉ.",
                    solution: "Đăng nhập developer.apple.com để bấm Đồng ý điều khoản, sau đó quay lại bấm Chạy tiếp."
                )
            }
            // 11. Certificate Revoked
            if fullText.contains("revoked") || fullText.contains("certificate") && fullText.contains("invalid") || code == 7460 {
                return DiagnosticErrorItem(
                    number: 11,
                    title: "Lỗi #11: Chứng chỉ ký (Certificate) bị thu hồi hoặc lỗi",
                    cause: "Chứng chỉ hiện tại đã bị thu hồi trên máy chủ hoặc không khớp với khóa cá nhân.",
                    solution: "Bấm Chạy tiếp để SideStore tự động làm mới chứng chỉ, hoặc vào Quản lý chứng chỉ để thu hồi và tạo lại."
                )
            }
            // 12. App ID not available
            if fullText.contains("not available") || fullText.contains("already exists") || code == 9401 {
                return DiagnosticErrorItem(
                    number: 12,
                    title: "Lỗi #12: Mã định danh App ID bị trùng lặp (Not Available)",
                    cause: "Bundle ID của ứng dụng đã bị đăng ký trước bởi một tài khoản khác trên hệ thống Apple.",
                    solution: "Đảm bảo giữ tuỳ chọn nối thêm mã Team ID vào sau Bundle ID rồi bấm Chạy tiếp."
                )
            }
            // 13. SSL / TLS Handshake Failed
            if fullText.contains("ssl") || fullText.contains("tls") || code == -1200 || code == -1009 || fullText.contains("network connection") {
                return DiagnosticErrorItem(
                    number: 13,
                    title: "Lỗi #13: Lỗi kết nối mạng hoặc bắt tay bảo mật SSL/TLS",
                    cause: "Mạng Wi-Fi/4G hiện tại bị rớt hoặc chặn kết nối tới máy chủ Apple/Anisette.",
                    solution: "Kiểm tra lại kết nối Wi-Fi/4G, tắt các trình chặn quảng cáo rồi bấm Chạy tiếp."
                )
            }
            // 14. Apple Developer Maintenance
            if fullText.contains("maintenance") || fullText.contains("currently unavailable") {
                return DiagnosticErrorItem(
                    number: 14,
                    title: "Lỗi #14: Máy chủ Apple Developer đang bảo trì",
                    cause: "Hệ thống cấp phép của Apple đang trong thời gian bảo trì định kỳ.",
                    solution: "Đợi một lát rồi bấm Chạy tiếp, hoặc thử lại sau khi Apple hoàn tất bảo trì."
                )
            }
            // 15. Invalid Entitlements
            if fullText.contains("entitlement") || fullText.contains("feature") || fullText.contains("app group") {
                return DiagnosticErrorItem(
                    number: 15,
                    title: "Lỗi #15: Quyền hệ thống (Entitlements/App Group) không hợp lệ",
                    cause: "File IPA yêu cầu quyền cao cấp mà tài khoản Apple miễn phí không hỗ trợ.",
                    solution: "Bấm Chạy tiếp để thử bỏ qua quyền lỗi, hoặc chỉnh lại Entitlements khi cài đặt."
                )
            }
            
            // Dự phòng Giai đoạn 1
            return DiagnosticErrorItem(
                number: 1,
                title: "Lỗi Giai đoạn 1: Gián đoạn xin cấp phép từ Apple / Anisette",
                cause: "Quá trình xác thực chứng chỉ hoặc tải Provisioning Profile gặp sự cố (\(nsError.domain) - mã \(code)).",
                solution: "Kiểm tra lại mạng và máy chủ Anisette, sau đó bấm Chạy tiếp để thử lại bước này."
            )
            
        case .systemPush:
            // 16. Unable to connect to device
            if fullText.contains("unable to connect") || fullText.contains("no device") || fullText.contains("device not found") || fullText.contains("minimuxer") {
                return DiagnosticErrorItem(
                    number: 16,
                    title: "Lỗi #16: Không thể kết nối với thiết bị (Unable to connect)",
                    cause: "Bạn quên chưa bật VPN WireGuard/StosVPN hoặc thiết bị chưa kết nối Wi-Fi.",
                    solution: "Vuốt Trung tâm điều khiển hoặc mở app VPN bật kết nối lên, đảm bảo có Wi-Fi rồi bấm Chạy tiếp."
                )
            }
            // 17. Invalid Pairing File / Lockdown Error
            if fullText.contains("lockdown") || fullText.contains("invalid pairing") || fullText.contains("pair") && fullText.contains("invalid") || fullText.contains("hostid") {
                return DiagnosticErrorItem(
                    number: 17,
                    title: "Lỗi #17: File ghép đôi (Pairing File) bị hỏng hoặc hết hiệu lực",
                    cause: "File ghép đôi bị vô hiệu hóa do bạn vừa đổi mật khẩu màn hình khóa hoặc cập nhật iOS.",
                    solution: "Kiểm tra lại VPN rồi bấm Chạy tiếp. Nếu vẫn lỗi, bạn cần tạo và nạp lại Pairing File mới từ máy tính."
                )
            }
            // 18. Pairing File Not Found
            if fullText.contains("pairing file not found") || fullText.contains("missing pairing") || fullText.contains("no pairing") {
                return DiagnosticErrorItem(
                    number: 18,
                    title: "Lỗi #18: Chưa tìm thấy File ghép đôi (Pairing File Not Found)",
                    cause: "SideStore chưa được nạp file ghép đôi (.mobiledevicepairing) để giao tiếp với hệ thống.",
                    solution: "Nạp lại file ghép đôi vào SideStore rồi bấm Chạy tiếp."
                )
            }
            // 19. Local Network Permission Denied
            if fullText.contains("local network") || fullText.contains("necperror") || fullText.contains("permission denied") {
                return DiagnosticErrorItem(
                    number: 19,
                    title: "Lỗi #19: Chưa cấp quyền Mạng cục bộ (Local Network)",
                    cause: "Quyền Mạng cục bộ của SideStore trong Cài đặt iOS đang bị tắt.",
                    solution: "Mở Cài đặt iOS -> SideStore -> Bật 'Mạng cục bộ' (Local Network), sau đó quay lại bấm Chạy tiếp."
                )
            }
            // 20. VPN Conflict
            if fullText.contains("vpn") || fullText.contains("tunnel") || fullText.contains("interface") {
                return DiagnosticErrorItem(
                    number: 20,
                    title: "Lỗi #20: Xung đột cấu hình mạng ảo VPN",
                    cause: "Đang bật đè một VPN khác (1.1.1.1, AdGuard, Shadowrocket...) làm mất đường truyền Loopback.",
                    solution: "Tắt hết các VPN khác, chỉ bật duy nhất VPN của SideStore (StosVPN/WireGuard) rồi bấm Chạy tiếp."
                )
            }
            // 21. Connection Timed Out (mux error)
            if fullText.contains("timed out") || fullText.contains("timeout") || fullText.contains("mux") || fullText.contains("afc") || fullText.contains("broken pipe") {
                return DiagnosticErrorItem(
                    number: 21,
                    title: "Lỗi #21: Quá thời gian truyền dữ liệu qua VPN (Connection Timed Out)",
                    cause: "Đường truyền nội bộ bị nghẽn khi đang đẩy gói cài đặt hoặc file IPA dung lượng lớn vào iOS.",
                    solution: "Tắt đi bật lại VPN và Wi-Fi, giữ sáng màn hình rồi bấm Chạy tiếp để đẩy lại ngay bước này."
                )
            }
            // 22. Background Task Killed
            if fullText.contains("background") || fullText.contains("interrupted") || fullText.contains("connection reset") {
                return DiagnosticErrorItem(
                    number: 22,
                    title: "Lỗi #22: Kết nối bị ngắt do thoát ứng dụng hoặc tắt màn hình",
                    cause: "iOS tự động đóng băng đường truyền mạng khi SideStore bị đưa xuống nền.",
                    solution: "Giữ nguyên màn hình SideStore luôn sáng và bấm Chạy tiếp."
                )
            }
            // 23. Wi-Fi AP Isolation (Cellular Fallback)
            if fullText.contains("unreachable") || fullText.contains("no route to host") || code == -1004 {
                return DiagnosticErrorItem(
                    number: 23,
                    title: "Lỗi #23: Mạng Wi-Fi chặn giao tiếp nội bộ (AP Isolation) hoặc mất Wi-Fi",
                    cause: "Thiết bị đang không kết nối Wi-Fi hoặc mạng Wi-Fi công cộng chặn kết nối nội bộ.",
                    solution: "Kết nối vào mạng Wi-Fi cá nhân hoặc điểm truy cập cá nhân (Hotspot) rồi bấm Chạy tiếp."
                )
            }
            // 24. ApplicationVerificationFailed
            if fullText.contains("applicationverificationfailed") || fullText.contains("verification failed") || fullText.contains("0xe80080") {
                return DiagnosticErrorItem(
                    number: 24,
                    title: "Lỗi #24: Hệ thống iOS từ chối xác minh chữ ký (Verification Failed)",
                    cause: "Chữ ký số hoặc Provisioning Profile không khớp khi tiến trình installd của iOS kiểm tra.",
                    solution: "Bấm Chạy tiếp để thử cài lại. Nếu vẫn lỗi, hãy kiểm tra lại chứng chỉ trong mục Cài đặt."
                )
            }
            // 25. Mismatched Bundle ID
            if fullText.contains("mismatch") || fullText.contains("upgrade") || fullText.contains("already installed") {
                return DiagnosticErrorItem(
                    number: 25,
                    title: "Lỗi #25: Xung đột Bundle ID với ứng dụng đã cài trên máy",
                    cause: "Ứng dụng đang cài đè có Bundle ID hoặc Apple ID khác với phiên bản đã cài trước đó.",
                    solution: "Gỡ phiên bản cũ trên màn hình chính (nếu không cần giữ dữ liệu) rồi bấm Chạy tiếp."
                )
            }
            // 26. Storage Full (Disk Quota Exceeded)
            if fullText.contains("storage") || fullText.contains("disk") || fullText.contains("no space") || code == 28 {
                return DiagnosticErrorItem(
                    number: 26,
                    title: "Lỗi #26: Bộ nhớ iPhone/iPad bị đầy khi đang bung gói cài đặt",
                    cause: "Thiết bị không còn đủ dung lượng trống để hệ thống iOS giải nén và cài đặt ứng dụng.",
                    solution: "Giải phóng thêm dung lượng bộ nhớ trên máy rồi quay lại bấm Chạy tiếp."
                )
            }
            // 27. Minimum OS Version Mismatch
            if fullText.contains("minimum os") || fullText.contains("system version") || fullText.contains("incompatible") {
                return DiagnosticErrorItem(
                    number: 27,
                    title: "Lỗi #27: Phiên bản iOS hiện tại thấp hơn yêu cầu của IPA",
                    cause: "File IPA yêu cầu phiên bản hệ điều hành iOS cao hơn phiên bản máy bạn đang chạy.",
                    solution: "Bấm Dừng và sử dụng phiên bản IPA thấp hơn tương thích với iOS của bạn."
                )
            }
            // 28. Device Not Registered in Profile
            if fullText.contains("not registered") || fullText.contains("udid") || fullText.contains("0xe800801c") {
                return DiagnosticErrorItem(
                    number: 28,
                    title: "Lỗi #28: Mã UDID thiết bị chưa có trong Hồ sơ cấp phép",
                    cause: "Provisioning Profile vừa tải về chưa cập nhật kịp mã UDID của chiếc iPhone/iPad này.",
                    solution: "Bấm Chạy tiếp để hệ thống đẩy lại hồ sơ cấp phép vào thiết bị."
                )
            }
            // 29. Corrupted IPA Payload
            if fullText.contains("corrupt") || fullText.contains("invalid bundle") || fullText.contains("missing provisioning") {
                return DiagnosticErrorItem(
                    number: 29,
                    title: "Lỗi #29: Gói dữ liệu Payload của IPA bị lỗi cấu trúc",
                    cause: "Dữ liệu ứng dụng bị thiếu file thực thi hoặc hỏng cấu trúc trong quá trình truyền tải.",
                    solution: "Bấm Chạy tiếp để truyền lại gói dữ liệu. Nếu vẫn lỗi, hãy kiểm tra lại file IPA gốc."
                )
            }
            // 30. Developer Mode Disabled (iOS 16+)
            if fullText.contains("developer mode") || fullText.contains("chế độ nhà phát triển") {
                return DiagnosticErrorItem(
                    number: 30,
                    title: "Lỗi #30: Chưa bật Chế độ nhà phát triển (Developer Mode)",
                    cause: "Từ iOS 16 trở lên, Apple bắt buộc bật Chế độ nhà phát triển để chạy ứng dụng sideload.",
                    solution: "Vào Cài đặt iOS -> Quyền riêng tư & Bảo mật -> Bật Chế độ nhà phát triển."
                )
            }
            
            // Dự phòng Giai đoạn 2
            return DiagnosticErrorItem(
                number: 16,
                title: "Lỗi Giai đoạn 2: Gián đoạn khi đẩy ứng dụng vào hệ thống iOS",
                cause: "Đường truyền VPN Loopback hoặc dịch vụ cài đặt iOS gặp lỗi (\(nsError.domain) - mã \(code)).",
                solution: "Hãy kiểm tra lại VPN (StosVPN/WireGuard) và kết nối Wi-Fi, sau đó bấm Chạy tiếp để thử lại ngay bước này."
            )
        }
    }
    
    /// Hiển thị Bảng Thông Báo Lỗi chuẩn giao diện CSSTheme với 2 nút: Chạy tiếp & Dừng
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
                        hc.dismiss(animated: true) {
                            complete(true)
                        }
                    } else {
                        complete(true)
                    }
                },
                onStop: {
                    if let hc = hostingController {
                        hc.dismiss(animated: true) {
                            complete(false)
                        }
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

// MARK: - 🎨 GIAO DIỆN BẢNG THÔNG BÁO LỖI ĐỒNG BỘ 100% VỚI SETTINGSVIEWCONTROLLER (CSS THEME)
private enum CSSErrorTheme {
    static let cornerRadius: CGFloat = 15.0
    static let primary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)       // #007bff
    static let secondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)    // #6f42c1
    static let green = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)         // #28a745
    static let red = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)           // #dc3545
    static let magenta = SwiftUI.Color(red: 255/255, green: 0/255, blue: 255/255)       // #ff00ff
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
            .offset(x: configuration.isPressed ? 2 : 0, y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
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
            
            VStack(spacing: 14) {
                // 1. Khối Hero Banner đồng bộ với trang Cài đặt gốc
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: phase.icon)
                            .font(.system(size: 18, weight: .heavy))
                            .foregroundColor(.white)
                        
                        SwiftUI.Text(phase.title)
                            .font(.system(size: 16.5, weight: .heavy))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    
                    SwiftUI.Text(phase.subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(CSSErrorTheme.heroGradient)
                .clipShape(RoundedRectangle(cornerRadius: CSSErrorTheme.cornerRadius, style: .continuous))
                .shadow(color: CSSErrorTheme.primary.opacity(0.28), radius: 10, x: 0, y: 4)
                
                // 2. Thẻ thông tin Ứng dụng & Chẩn đoán lỗi (30 lỗi)
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(CSSErrorTheme.red.opacity(0.14))
                                .frame(width: 40, height: 40)
                            SwiftUI.Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(CSSErrorTheme.red)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            SwiftUI.Text(appName)
                                .font(.system(size: 15.5, weight: .heavy))
                                .foregroundColor(CSSErrorTheme.primary)
                                .lineLimit(1)
                            
                            SwiftUI.Text("Bước dừng: .\(stepName) • Mã danh mục #\(diagnosis.number)/30")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(CSSErrorTheme.secondary)
                        }
                        Spacer()
                    }
                    
                    Divider()
                    
                    // Tên lỗi trong 30 lỗi
                    VStack(alignment: .leading, spacing: 4) {
                        SwiftUI.Text(diagnosis.title)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundColor(CSSErrorTheme.pureBlack)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        SwiftUI.Text("• Nguyên nhân: \(diagnosis.cause)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(CSSErrorTheme.pureBlack.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CSSErrorTheme.innerRowBackground)
                    .cornerRadius(11)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(CSSErrorTheme.innerBorder, lineWidth: 1)
                    )
                    
                    // Cách khắc phục nhanh
                    HStack(alignment: .top, spacing: 8) {
                        SwiftUI.Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(CSSErrorTheme.green)
                            .padding(.top, 2)
                        
                        SwiftUI.Text("Khắc phục: \(diagnosis.solution)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(CSSErrorTheme.pureBlack)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(CSSErrorTheme.green.opacity(0.10))
                    .cornerRadius(11)
                    .overlay(
                        RoundedRectangle(cornerRadius: 11)
                            .stroke(CSSErrorTheme.green.opacity(0.35), lineWidth: 1)
                    )
                    
                    // Xem mã lỗi gốc hệ thống
                    VStack(alignment: .leading, spacing: 6) {
                        SwiftUI.Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showRawDetails.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                SwiftUI.Image(systemName: showRawDetails ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                    .font(.system(size: 13, weight: .bold))
                                SwiftUI.Text(showRawDetails ? "Ẩn chi tiết mã lỗi hệ thống" : "Xem chi tiết mã lỗi hệ thống")
                                    .font(.system(size: 12.5, weight: .bold))
                                Spacer()
                            }
                            .foregroundColor(CSSErrorTheme.primary)
                        }
                        
                        if showRawDetails {
                            ScrollView {
                                SwiftUI.Text(rawErrorText)
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(CSSErrorTheme.pureBlack.opacity(0.85))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 75)
                            .padding(8)
                            .background(CSSErrorTheme.innerRowBackground)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(CSSErrorTheme.innerBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(14)
                .background(CSSErrorTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: CSSErrorTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CSSErrorTheme.cornerRadius, style: .continuous)
                        .stroke(CSSErrorTheme.border, lineWidth: 1.0)
                )
                .shadow(color: CSSErrorTheme.primary.opacity(0.08), radius: 10, x: 0, y: 5)
                
                // 3. Hai nút điều khiển: DỪNG & CHẠY TIẾP
                HStack(spacing: 12) {
                    SwiftUI.Button {
                        onStop()
                    } label: {
                        HStack(spacing: 6) {
                            SwiftUI.Image(systemName: "stop.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            SwiftUI.Text("Dừng")
                                .font(.system(size: 15.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(CSSErrorTheme.red)
                        .cornerRadius(12)
                        .shadow(color: CSSErrorTheme.red.opacity(0.32), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(CSSErrorBounceButtonStyle())
                    
                    SwiftUI.Button {
                        onContinue()
                    } label: {
                        HStack(spacing: 6) {
                            SwiftUI.Image(systemName: "play.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            SwiftUI.Text("Chạy tiếp")
                                .font(.system(size: 15.5, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(CSSErrorTheme.primary)
                        .cornerRadius(12)
                        .shadow(color: CSSErrorTheme.primary.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(CSSErrorBounceButtonStyle())
                }
            }
            .padding(16)
            .background(CSSErrorTheme.pageGradient)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(CSSErrorTheme.border, lineWidth: 1.2)
            )
            .shadow(color: SwiftUI.Color.black.opacity(0.22), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 18)
        }
    }
}
