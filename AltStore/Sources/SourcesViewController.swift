
//
//  SourcesViewController.swift
//  AltStore
//
//  Created by Riley Testut on 9/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import SwiftUI
import CoreData
import Minimuxer
import SideSign
import ZIPFoundation

// MARK: - CSS Theme Palette (Clean Light Blue & White)
private enum SourcesCSSTheme {
    static let primaryBlue = Color(red: 0.04, green: 0.52, blue: 1.00)
    static let secondaryCyan = Color(red: 0.00, green: 0.78, blue: 0.98)
    static let deepIndigo = Color(red: 0.22, green: 0.35, blue: 0.95)
    static let pageBgTop = Color(red: 0.94, green: 0.97, blue: 1.00)
    static let pageBgBottom = Color(red: 0.88, green: 0.94, blue: 1.00)
    static let cardBg = Color.white
    static let cardBorder = Color(red: 0.04, green: 0.52, blue: 1.00).opacity(0.14)
    static let cardShadow = Color(red: 0.04, green: 0.35, blue: 0.75).opacity(0.08)
    static let textPrimary = Color(red: 0.07, green: 0.12, blue: 0.24)
    static let textSecondary = Color(red: 0.35, green: 0.43, blue: 0.56)
    static let successGreen = Color(red: 0.06, green: 0.72, blue: 0.48)
    static let warningOrange = Color(red: 0.98, green: 0.55, blue: 0.12)
    static let dangerRed = Color(red: 0.94, green: 0.24, blue: 0.30)

    static let uiPageBg = UIColor(red: 0.93, green: 0.97, blue: 1.00, alpha: 1.0)
    static let uiPrimaryBlue = UIColor(red: 0.04, green: 0.52, blue: 1.00, alpha: 1.0)
    static let uiTextPrimary = UIColor(red: 0.07, green: 0.12, blue: 0.24, alpha: 1.0)
}

// MARK: - Animated Background View
private struct SourcesCSSGradientBackgroundView: View {
    @State private var animateWave = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [SourcesCSSTheme.pageBgTop, Color.white, SourcesCSSTheme.pageBgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [SourcesCSSTheme.secondaryCyan.opacity(0.22), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 220
                    )
                )
                .frame(width: 420, height: 420)
                .offset(x: animateWave ? 110 : 60, y: animateWave ? -230 : -190)
                .animation(.easeInOut(duration: 5.5).repeatForever(autoreverses: true), value: animateWave)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [SourcesCSSTheme.primaryBlue.opacity(0.16), Color.clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 240
                    )
                )
                .frame(width: 450, height: 450)
                .offset(x: animateWave ? -120 : -70, y: animateWave ? 260 : 210)
                .animation(.easeInOut(duration: 6.5).repeatForever(autoreverses: true), value: animateWave)
        }
        .onAppear {
            animateWave = true
        }
    }
}

// MARK: - Bounce Button Style
private struct SourcesCSSBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

// MARK: - Installed App Entry Model for Fix Tool
private struct FixableInstalledApp: Identifiable, Equatable {
    let id: String // bundleIdentifier
    let name: String
    let bundleIdentifier: String
    let resignedBundleIdentifier: String
    let version: String
    let expirationDate: Date
    let refreshedDate: Date
    let certificateSerialNumber: String?
    let isCustomCertApp: Bool
    let isExpired: Bool
    let isRevokedOrOverloaded: Bool
    let iconImage: UIImage?
    let installedAppObjectID: NSManagedObjectID

    var daysRemaining: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expirationDate)
        return components.day ?? 0
    }

    var statusText: String {
        if isExpired {
            return "Đã hết hạn"
        } else if isRevokedOrOverloaded {
            return "Chứng chỉ thu hồi / Quá tải"
        } else if daysRemaining <= 2 {
            return "Sắp hết hạn (\(max(daysRemaining, 0)) ngày)"
        } else {
            return "Còn \(daysRemaining) ngày"
        }
    }

    var statusColor: Color {
        if isExpired || isRevokedOrOverloaded {
            return SourcesCSSTheme.dangerRed
        } else if daysRemaining <= 2 {
            return SourcesCSSTheme.warningOrange
        } else {
            return SourcesCSSTheme.successGreen
        }
    }

    static func == (lhs: FixableInstalledApp, rhs: FixableInstalledApp) -> Bool {
        lhs.id == rhs.id &&
        lhs.expirationDate == rhs.expirationDate &&
        lhs.refreshedDate == rhs.refreshedDate &&
        lhs.isExpired == rhs.isExpired &&
        lhs.isRevokedOrOverloaded == rhs.isRevokedOrOverloaded
    }
}

// MARK: - Fix Process Sheet View (Sửa lỗi Hết Hạn / Quá Tải / Thu Hồi)
private struct FixProcessSheetView: View {
    let app: FixableInstalledApp
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 0
    @State private var progressValue: Double = 0.0
    @State private var statusTitle: String = "Đang khởi tạo trình sửa lỗi..."
    @State private var statusDetail: String = "Chuẩn bị kiểm tra cấu hình ứng dụng và chứng chỉ..."
    @State private var isFinished: Bool = false
    @State private var errorMessage: String? = nil
    @State private var appearAnim: Bool = false

    private let steps = [
        "Kiểm tra cấu hình & Định danh ứng dụng",
        "Đóng gói dữ liệu mồi siêu nhẹ (Bảo toàn dữ liệu)",
        "Cấp lại Chứng chỉ & Hồ sơ cấu hình mới",
        "Kích hoạt lại ứng dụng trên hệ thống"
    ]

    var body: some View {
        ZStack {
            SourcesCSSGradientBackgroundView()

            VStack(spacing: 22) {
                Capsule()
                    .fill(SourcesCSSTheme.primaryBlue.opacity(0.25))
                    .frame(width: 44, height: 5)
                    .padding(.top, 12)

                // App Header Card
                HStack(spacing: 14) {
                    if let icon = app.iconImage {
                        Image(uiImage: icon)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(SourcesCSSTheme.primaryBlue.opacity(0.2), lineWidth: 1)
                            )
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(SourcesCSSTheme.primaryBlue.opacity(0.12))
                                .frame(width: 64, height: 64)
                            Image(systemName: "app.badge.checkmark.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(SourcesCSSTheme.primaryBlue)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(SourcesCSSTheme.textPrimary)
                            .lineLimit(1)

                        Text(app.bundleIdentifier)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(SourcesCSSTheme.textSecondary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Image(systemName: app.isCustomCertApp ? "signature" : "person.badge.shield.checkmark.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(app.isCustomCertApp ? "Chế độ: Chứng chỉ P12 / Riêng" : "Chế độ: ID Apple / Free Cert")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(SourcesCSSTheme.primaryBlue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(SourcesCSSTheme.primaryBlue.opacity(0.10)))
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: SourcesCSSTheme.cardShadow, radius: 12, x: 0, y: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(SourcesCSSTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                // Progress Ring & Status Card
                VStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .stroke(SourcesCSSTheme.primaryBlue.opacity(0.12), lineWidth: 10)
                            .frame(width: 110, height: 110)

                        Circle()
                            .trim(from: 0, to: CGFloat(min(max(progressValue, 0.0), 1.0)))
                            .stroke(
                                LinearGradient(
                                    colors: errorMessage != nil
                                        ? [SourcesCSSTheme.dangerRed, SourcesCSSTheme.warningOrange]
                                        : (isFinished
                                            ? [SourcesCSSTheme.successGreen, SourcesCSSTheme.secondaryCyan]
                                            : [SourcesCSSTheme.primaryBlue, SourcesCSSTheme.secondaryCyan]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .frame(width: 110, height: 110)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.35), value: progressValue)

                        if let _ = errorMessage {
                            Image(systemName: "xmark.octagon.fill")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(SourcesCSSTheme.dangerRed)
                        } else if isFinished {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(SourcesCSSTheme.successGreen)
                        } else {
                            VStack(spacing: 2) {
                                Text("\(Int(progressValue * 100))%")
                                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                                    .foregroundColor(SourcesCSSTheme.primaryBlue)
                                Text("ĐANG SỬA")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(SourcesCSSTheme.textSecondary)
                            }
                        }
                    }
                    .padding(.top, 6)

                    VStack(spacing: 6) {
                        Text(statusTitle)
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(errorMessage != nil ? SourcesCSSTheme.dangerRed : SourcesCSSTheme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(errorMessage ?? statusDetail)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(errorMessage != nil ? SourcesCSSTheme.dangerRed.opacity(0.9) : SourcesCSSTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    // Checklist Steps
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(0..<steps.count, id: \.self) { index in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(stepCircleColor(for: index))
                                        .frame(width: 22, height: 22)

                                    if index < currentStep || isFinished {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    } else if index == currentStep && errorMessage != nil {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    } else {
                                        Text("\(index + 1)")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(index == currentStep ? .white : SourcesCSSTheme.textSecondary)
                                    }
                                }

                                Text(steps[index])
                                    .font(.system(size: 13, weight: index == currentStep ? .bold : .medium, design: .rounded))
                                    .foregroundColor(index <= currentStep ? SourcesCSSTheme.textPrimary : SourcesCSSTheme.textSecondary.opacity(0.7))

                                Spacer()
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(SourcesCSSTheme.pageBgTop.opacity(0.7))
                    )
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white)
                        .shadow(color: SourcesCSSTheme.cardShadow, radius: 14, x: 0, y: 6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(SourcesCSSTheme.cardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Spacer()

                // Action Button
                if isFinished || errorMessage != nil {
                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isFinished ? "checkmark.circle.fill" : "arrow.uturn.left.circle.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(isFinished ? "HOÀN TẤT & ĐÓNG" : "ĐÓNG LẠI")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(
                                colors: isFinished
                                    ? [SourcesCSSTheme.successGreen, SourcesCSSTheme.secondaryCyan]
                                    : [SourcesCSSTheme.primaryBlue, SourcesCSSTheme.deepIndigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: SourcesCSSTheme.primaryBlue.opacity(0.25), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(SourcesCSSBounceButtonStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            guard !appearAnim else { return }
            appearAnim = true
            startFixWorkflow()
        }
    }

    private func stepCircleColor(for index: Int) -> Color {
        if index < currentStep || isFinished {
            return SourcesCSSTheme.successGreen
        } else if index == currentStep {
            return errorMessage != nil ? SourcesCSSTheme.dangerRed : SourcesCSSTheme.primaryBlue
        } else {
            return SourcesCSSTheme.primaryBlue.opacity(0.12)
        }
    }

    // MARK: - Core Fix Engine
    private func startFixWorkflow() {
        Task {
            do {
                await MainActor.run {
                    self.currentStep = 0
                    self.progressValue = 0.15
                    self.statusTitle = "Đang kiểm tra ứng dụng..."
                    self.statusDetail = "Đọc cấu hình gốc và xác định phương thức sửa lỗi tối ưu..."
                }
                try await Task.sleep(nanoseconds: 250_000_000)

                // Fetch InstalledApp on MainActor
                let installedApp: InstalledApp? = await MainActor.run {
                    try? DatabaseManager.shared.viewContext.existingObject(with: app.installedAppObjectID) as? InstalledApp
                }

                guard let installedApp = installedApp else {
                    throw NSError(domain: "FixError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy dữ liệu ứng dụng trong cơ sở dữ liệu."])
                }

                // Kiểm tra xem có Chứng chỉ Riêng (P12) đang được kích hoạt hoặc ứng dụng thuộc diện Chứng chỉ Riêng không
                let activeCustomCert = CustomCertManager.shared.getActiveCert()
                if app.isCustomCertApp || activeCustomCert != nil {
                    if let certEntry = activeCustomCert ?? CustomCertManager.shared.savedCerts.first(where: { !$0.isExpired && !$0.isRevoked }) {
                        try await performCustomCertDirectRefix(for: installedApp, certEntry: certEntry)
                        return
                    }
                }

                // Luồng sửa lỗi bằng gói IPA mồi siêu nhẹ (Minimal Fix IPA) + Pipeline kích hoạt lại
                await MainActor.run {
                    self.currentStep = 1
                    self.progressValue = 0.40
                    self.statusTitle = "Đang tạo gói mồi bảo toàn dữ liệu..."
                    self.statusDetail = "Trích xuất Info.plist & tạo bộ khung siêu nhẹ để giữ nguyên dữ liệu ứng dụng..."
                }

                let minimalIPAURL = try await createMinimalFixIPA(for: installedApp)
                defer {
                    try? FileManager.default.removeItem(at: minimalIPAURL.deletingLastPathComponent())
                }

                await MainActor.run {
                    self.currentStep = 2
                    self.progressValue = 0.65
                    self.statusTitle = "Đang cấp lại Chứng chỉ & Hồ sơ..."
                    self.statusDetail = "Kết nối máy chủ xác thực và ký lại định danh cho \(app.name)..."
                }

                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    Task { @MainActor in
                        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let rootVC = windowScene.windows.first?.rootViewController else {
                            continuation.resume(throwing: NSError(domain: "FixError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy giao diện điều khiển để thực hiện sửa lỗi."]))
                            return
                        }

                        var topVC = rootVC
                        while let presented = topVC.presentedViewController {
                            topVC = presented
                        }

                        let group = AppManager.shared.install(minimalIPAURL, presentingViewController: topVC) { result in
                            switch result {
                            case .success:
                                continuation.resume(returning: ())
                            case .failure(let error):
                                continuation.resume(throwing: error)
                            }
                        }

                        // Theo dõi tiến trình thực tế
                        Task {
                            while !group.progress.isFinished && !group.progress.isCancelled {
                                let frac = group.progress.fractionCompleted
                                await MainActor.run {
                                    self.progressValue = min(0.65 + (frac * 0.30), 0.95)
                                    if frac > 0.5 {
                                        self.currentStep = 3
                                        self.statusTitle = "Đang kích hoạt lại trên thiết bị..."
                                        self.statusDetail = "Ghi đè chứng chỉ mới mà không làm mất dữ liệu..."
                                    }
                                }
                                try? await Task.sleep(nanoseconds: 200_000_000)
                            }
                        }
                    }
                }

                await MainActor.run {
                    self.currentStep = 3
                    self.progressValue = 1.0
                    self.isFinished = true
                    self.statusTitle = "Sửa lỗi thành công!"
                    self.statusDetail = "Ứng dụng \(app.name) đã được khôi phục hoạt động bình thường và giữ nguyên toàn bộ dữ liệu."
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.statusTitle = "Không thể hoàn tất sửa lỗi"
                }
            }
        }
    }

    // MARK: - Custom Cert Direct Refix (Ký lại trực tiếp bằng P12 + MobileProvision mới)
    private func performCustomCertDirectRefix(for installedApp: InstalledApp, certEntry: CustomCertEntry) async throws {
        await MainActor.run {
            self.currentStep = 1
            self.progressValue = 0.35
            self.statusTitle = "Đang nạp Chứng chỉ P12 & Hồ sơ..."
            self.statusDetail = "Sử dụng chứng chỉ: \(certEntry.name)..."
        }

        guard let p12Data = try? Data(contentsOf: certEntry.p12URL),
              let certificate = ALTCertificate(p12Data: p12Data, password: certEntry.password) else {
            throw NSError(domain: "FixError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Không thể giải mã chứng chỉ P12. Vui lòng kiểm tra lại trong mục Quản lý Chứng chỉ."])
        }

        guard let profile = ALTProvisioningProfile(url: certEntry.provisionURL) else {
            throw NSError(domain: "FixError", code: 402, userInfo: [NSLocalizedDescriptionKey: "Không thể đọc file .mobileprovision của chứng chỉ."])
        }

        let sourceAppBundleURL = await MainActor.run { installedApp.fileURL }
        guard FileManager.default.fileExists(atPath: sourceAppBundleURL.path) else {
            throw NSError(domain: "FixError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy bản lưu .app của ứng dụng để ký lại."])
        }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("DirectFix_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let tempAppBundleURL = tempDir.appendingPathComponent(sourceAppBundleURL.lastPathComponent)
        try FileManager.default.copyItem(at: sourceAppBundleURL, to: tempAppBundleURL)

        await MainActor.run {
            self.currentStep = 2
            self.progressValue = 0.65
            self.statusTitle = "Đang ký lại ứng dụng..."
            self.statusDetail = "Nhúng hồ sơ cấu hình mới và tái ký chữ ký số..."
        }

        let dummyAccount = ALTAccount()
        let team = ALTTeam(name: certEntry.teamName, identifier: certEntry.teamID, type: .unknown, account: dummyAccount)
        let signer = ALTSigner(team: team, certificate: certificate)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let progress = signer.signApp(at: tempAppBundleURL, provisioningProfiles: [profile]) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if !success {
                    continuation.resume(throwing: NSError(domain: "FixError", code: 500, userInfo: [NSLocalizedDescriptionKey: "Quá trình ký lại bằng chứng chỉ P12 thất bại."]))
                } else {
                    continuation.resume(returning: ())
                }
            }
            _ = progress
        }

        await MainActor.run {
            self.currentStep = 3
            self.progressValue = 0.85
            self.statusTitle = "Đang cài đặt đè khôi phục trạng thái..."
            self.statusDetail = "Truyền gói đã ký qua kết nối cục bộ và giữ nguyên dữ liệu..."
        }

        let targetBundleID = await MainActor.run { installedApp.resignedBundleIdentifier }
        await CellularRefreshManager.shared.turnOffDataIfNeeded()
        do {
            try await sendAppBundleAfc(targetBundleID, at: tempAppBundleURL)
            try await installAppBundle(targetBundleID, appName: tempAppBundleURL.lastPathComponent)
            await CellularRefreshManager.shared.turnOnDataIfNeeded()
        } catch {
            await CellularRefreshManager.shared.turnOnDataIfNeeded()
            throw error
        }

        // Cập nhật lại bản lưu .app và Database
        await MainActor.run {
            if FileManager.default.fileExists(atPath: sourceAppBundleURL.path) {
                try? FileManager.default.removeItem(at: sourceAppBundleURL)
            }
            try? FileManager.default.copyItem(at: tempAppBundleURL, to: sourceAppBundleURL)

            installedApp.refreshedDate = Date()
            installedApp.expirationDate = profile.expirationDate
            installedApp.certificateSerialNumber = certificate.serialNumber
            try? DatabaseManager.shared.viewContext.save()

            self.progressValue = 1.0
            self.isFinished = true
            self.statusTitle = "Sửa lỗi Chứng chỉ thành công!"
            self.statusDetail = "Đã ký lại và kích hoạt \(app.name) với chứng chỉ '\(certEntry.name)' mà không mất dữ liệu."
        }
    }

    // MARK: - Create Minimal Fix IPA (Siêu nhẹ - Bảo toàn dữ liệu)
    private func createMinimalFixIPA(for installedApp: InstalledApp) async throws -> URL {
        let sourceBundleURL = await MainActor.run { installedApp.fileURL }
        let infoPlistURL = sourceBundleURL.appendingPathComponent("Info.plist")

        guard FileManager.default.fileExists(atPath: infoPlistURL.path),
              let plistData = try? Data(contentsOf: infoPlistURL),
              let plistDict = (try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil)) as? [String: Any] else {
            throw NSError(domain: "FixError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Không thể đọc Info.plist của ứng dụng đã cài."])
        }

        let tempBase = FileManager.default.temporaryDirectory.appendingPathComponent("MinimalFix_\(UUID().uuidString)")
        let payloadDir = tempBase.appendingPathComponent("Payload")
        let appFolderName = sourceBundleURL.lastPathComponent.hasSuffix(".app") ? sourceBundleURL.lastPathComponent : "App.app"
        let minimalAppDir = payloadDir.appendingPathComponent(appFolderName)

        try FileManager.default.createDirectory(at: minimalAppDir, withIntermediateDirectories: true)

        // 1. Copy Info.plist
        try plistData.write(to: minimalAppDir.appendingPathComponent("Info.plist"), options: .atomic)

        // 2. Tạo PkgInfo chuẩn
        let pkgInfoData = Data("APPL????".utf8)
        try pkgInfoData.write(to: minimalAppDir.appendingPathComponent("PkgInfo"), options: .atomic)

        // 3. Nếu có file thực thi chính, copy file thực thi gốc (hoặc tạo khung thực thi hợp lệ cho ALTSigner)
        if let executableName = plistDict["CFBundleExecutable"] as? String {
            let sourceExecURL = sourceBundleURL.appendingPathComponent(executableName)
            let destExecURL = minimalAppDir.appendingPathComponent(executableName)
            if FileManager.default.fileExists(atPath: sourceExecURL.path) {
                try FileManager.default.copyItem(at: sourceExecURL, to: destExecURL)
            } else {
                let dummyExec = Data(count: 64)
                try dummyExec.write(to: destExecURL, options: .atomic)
            }
        }

        // 4. Đóng gói thành file .ipa không nén (compressionLevel: .none) để đạt tốc độ tức thì
        let ipaURL = tempBase.appendingPathComponent("MinimalFix.ipa")
        try FileManager.default.zipItem(at: payloadDir, to: ipaURL, shouldKeepParent: true, compressionMethod: .none)

        return ipaURL
    }
}

// MARK: - Main SwiftUI View for Fix Tool (Tab Sửa Lỗi)
private struct FixMainSwiftUIView: View {
    @State private var installedApps: [FixableInstalledApp] = []
    @State private var selectedFilter: Int = 0 // 0: Tất cả, 1: Cần sửa ngay, 2: Đang hoạt động
    @State private var searchText: String = ""
    @State private var selectedAppForFix: FixableInstalledApp? = nil
    @State private var showCertManagerInfo: Bool = false

    private var filteredApps: [FixableInstalledApp] {
        installedApps.filter { app in
            let matchesSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                app.name.localizedCaseInsensitiveContains(searchText) ||
                app.bundleIdentifier.localizedCaseInsensitiveContains(searchText)

            guard matchesSearch else { return false }

            switch selectedFilter {
            case 1:
                return app.isExpired || app.isRevokedOrOverloaded || app.daysRemaining <= 2
            case 2:
                return !app.isExpired && !app.isRevokedOrOverloaded && app.daysRemaining > 2
            default:
                return true
            }
        }
    }

    private var needsFixCount: Int {
        installedApps.filter { $0.isExpired || $0.isRevokedOrOverloaded || $0.daysRemaining <= 2 }.count
    }

    var body: some View {
        ZStack {
            SourcesCSSGradientBackgroundView()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    headerBannerCard
                    diagnosticSummaryCard
                    filterSegmentBar
                    appListSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
        }
        .sheet(item: $selectedAppForFix) { targetApp in
            FixProcessSheetView(app: targetApp) {
                loadInstalledApps()
            }
        }
        .onAppear {
            loadInstalledApps()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            loadInstalledApps()
        }
    }

    // MARK: - Header Banner Card
    private var headerBannerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [SourcesCSSTheme.primaryBlue, SourcesCSSTheme.secondaryCyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: SourcesCSSTheme.primaryBlue.opacity(0.3), radius: 8, x: 0, y: 4)

                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("TRUNG TÂM SỬA LỖI ỨNG DỤNG")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(SourcesCSSTheme.textPrimary)

                    Text("Khắc phục Hết Hạn • Quá Tải • Thu Hồi Chứng Chỉ")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(SourcesCSSTheme.primaryBlue)
                }

                Spacer()

                Button {
                    loadInstalledApps()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(SourcesCSSTheme.primaryBlue)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(SourcesCSSTheme.primaryBlue.opacity(0.10)))
                }
                .buttonStyle(SourcesCSSBounceButtonStyle())
            }

            Text("Công cụ tự động tái kích hoạt chứng chỉ và ghi đè cấu hình trực tiếp lên ứng dụng đã cài trên máy mà không làm mất dữ liệu (Save Game, Tài khoản, Cài đặt).")
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundColor(SourcesCSSTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white)
                .shadow(color: SourcesCSSTheme.cardShadow, radius: 14, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(SourcesCSSTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Diagnostic Summary Card
    private var diagnosticSummaryCard: some View {
        HStack(spacing: 12) {
            summaryStatBox(
                title: "Tổng ứng dụng",
                value: "\(installedApps.count)",
                icon: "square.stack.3d.up.fill",
                color: SourcesCSSTheme.primaryBlue
            )

            summaryStatBox(
                title: "Cần sửa lỗi",
                value: "\(needsFixCount)",
                icon: needsFixCount > 0 ? "exclamationmark.triangle.fill" : "checkmark.shield.fill",
                color: needsFixCount > 0 ? SourcesCSSTheme.dangerRed : SourcesCSSTheme.successGreen
            )

            summaryStatBox(
                title: "Chứng chỉ P12",
                value: CustomCertManager.shared.getActiveCert() != nil ? "Đang bật" : "Mặc định",
                icon: "signature",
                color: SourcesCSSTheme.deepIndigo
            )
        }
    }

    private func summaryStatBox(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundColor(SourcesCSSTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(SourcesCSSTheme.textSecondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
                .shadow(color: SourcesCSSTheme.cardShadow, radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Filter Segment & Search Bar
    private var filterSegmentBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(SourcesCSSTheme.primaryBlue)
                    .font(.system(size: 14, weight: .bold))

                TextField("Tìm ứng dụng cần sửa lỗi...", text: $searchText)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(SourcesCSSTheme.textPrimary)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(SourcesCSSTheme.textSecondary.opacity(0.6))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(SourcesCSSTheme.cardBorder, lineWidth: 1)
            )

            HStack(spacing: 8) {
                filterPillButton(title: "Tất cả (\(installedApps.count))", index: 0)
                filterPillButton(title: "Cần sửa (\(needsFixCount))", index: 1)
                filterPillButton(title: "Ổn định", index: 2)
            }
        }
    }

    private func filterPillButton(title: String, index: Int) -> some View {
        let isSelected = selectedFilter == index
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selectedFilter = index
            }
        } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : SourcesCSSTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isSelected
                                ? LinearGradient(colors: [SourcesCSSTheme.primaryBlue, SourcesCSSTheme.secondaryCyan], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.white, Color.white], startPoint: .leading, endPoint: .trailing)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.clear : SourcesCSSTheme.cardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(SourcesCSSBounceButtonStyle())
    }

    // MARK: - App List Section
    private var appListSection: some View {
        VStack(spacing: 12) {
            if filteredApps.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(SourcesCSSTheme.primaryBlue.opacity(0.45))

                    Text(installedApps.isEmpty ? "Chưa có ứng dụng nào được cài đặt" : "Không có ứng dụng nào trong danh mục này")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(SourcesCSSTheme.textPrimary)

                    Text("Các ứng dụng bạn đã cài đặt trong máy sẽ tự động hiển thị tại đây để sửa lỗi bất cứ lúc nào.")
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .foregroundColor(SourcesCSSTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(SourcesCSSTheme.cardBorder, lineWidth: 1)
                )
            } else {
                ForEach(filteredApps) { app in
                    fixableAppCard(app)
                }
            }
        }
    }

    private func fixableAppCard(_ app: FixableInstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if let icon = app.iconImage {
                    Image(uiImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(SourcesCSSTheme.primaryBlue.opacity(0.15), lineWidth: 1)
                        )
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(SourcesCSSTheme.primaryBlue.opacity(0.12))
                            .frame(width: 56, height: 56)
                        Image(systemName: "app.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(SourcesCSSTheme.primaryBlue)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(app.name)
                            .font(.system(size: 15.5, weight: .bold, design: .rounded))
                            .foregroundColor(SourcesCSSTheme.textPrimary)
                            .lineLimit(1)

                        Text("v\(app.version)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(SourcesCSSTheme.primaryBlue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(SourcesCSSTheme.primaryBlue.opacity(0.10)))
                    }

                    Text(app.bundleIdentifier)
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .foregroundColor(SourcesCSSTheme.textSecondary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(app.statusColor)
                            .frame(width: 7, height: 7)

                        Text(app.statusText)
                            .font(.system(size: 11.5, weight: .bold, design: .rounded))
                            .foregroundColor(app.statusColor)
                    }
                }

                Spacer()
            }

            Divider()
                .background(SourcesCSSTheme.primaryBlue.opacity(0.10))

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.isCustomCertApp ? "Loại: Chứng chỉ P12 / Riêng" : "Loại: Chứng chỉ ID Apple")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(SourcesCSSTheme.textSecondary)
                }

                Spacer()

                Button {
                    selectedAppForFix = app
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("TIẾN HÀNH SỬA LỖI")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [SourcesCSSTheme.primaryBlue, SourcesCSSTheme.secondaryCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
                    .shadow(color: SourcesCSSTheme.primaryBlue.opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(SourcesCSSBounceButtonStyle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
                .shadow(color: SourcesCSSTheme.cardShadow, radius: 10, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(SourcesCSSTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - Load Installed Apps from CoreData
    private func loadInstalledApps() {
        let context = DatabaseManager.shared.viewContext
        context.perform {
            let fetchRequest = InstalledApp.fetchRequest() as! NSFetchRequest<InstalledApp>
            fetchRequest.returnsObjectsAsFaults = false

            guard let fetched = try? context.fetch(fetchRequest) else { return }

            let savedCustomCerts = CustomCertManager.shared.savedCerts
            let now = Date()

            var items: [FixableInstalledApp] = []
            for app in fetched {
                let isExpired = app.expirationDate <= now
                let certSerial = app.certificateSerialNumber
                let matchingCustomCert = savedCustomCerts.first(where: {
                    ($0.serialNumber != nil && $0.serialNumber == certSerial) ||
                    app.resignedBundleIdentifier.contains($0.teamID)
                })
                let isCustomCertApp = matchingCustomCert != nil || (app.team?.type == .unknown && certSerial != nil)
                let isRevoked = (matchingCustomCert?.isRevoked == true) || (app.certificateStatus == .revoked)

                let icon: UIImage?
                if app.hasAlternateIcon, let altIcon = UIImage(contentsOfFile: app.alternateIconURL.path) {
                    icon = altIcon
                } else {
                    icon = ALTApplication(fileURL: app.fileURL)?.icon
                }

                let item = FixableInstalledApp(
                    id: app.bundleIdentifier,
                    name: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    resignedBundleIdentifier: app.resignedBundleIdentifier,
                    version: app.version,
                    expirationDate: app.expirationDate,
                    refreshedDate: app.refreshedDate,
                    certificateSerialNumber: certSerial,
                    isCustomCertApp: isCustomCertApp,
                    isExpired: isExpired,
                    isRevokedOrOverloaded: isRevoked,
                    iconImage: icon,
                    installedAppObjectID: app.objectID
                )
                items.append(item)
            }

            // Ưu tiên đưa ứng dụng chính lên đầu, sau đó tới ứng dụng cần sửa lỗi
            items.sort { a, b in
                let aIsSelf = a.bundleIdentifier == StoreApp.altstoreAppID || a.bundleIdentifier == Bundle.main.bundleIdentifier
                let bIsSelf = b.bundleIdentifier == StoreApp.altstoreAppID || b.bundleIdentifier == Bundle.main.bundleIdentifier
                if aIsSelf != bIsSelf { return aIsSelf }

                let aNeedsFix = a.isExpired || a.isRevokedOrOverloaded || a.daysRemaining <= 2
                let bNeedsFix = b.isExpired || b.isRevokedOrOverloaded || b.daysRemaining <= 2
                if aNeedsFix != bNeedsFix { return aNeedsFix }

                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }

            DispatchQueue.main.async {
                self.installedApps = items
            }
        }
    }
}

// MARK: - SourcesViewController (UIKit Host for Fix Tool)
final class SourcesViewController: UICollectionViewController {
    @IBOutlet private var footerView: UIView!

    private var hostingController: UIHostingController<FixMainSwiftUIView>?

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Sửa Lỗi"
        self.navigationItem.largeTitleDisplayMode = .never
        self.navigationItem.rightBarButtonItems = []
        self.navigationItem.leftBarButtonItems = []

        self.view.backgroundColor = SourcesCSSTheme.uiPageBg
        self.collectionView.backgroundColor = .clear
        self.collectionView.isHidden = true

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = SourcesCSSTheme.uiPageBg
        appearance.titleTextAttributes = [
            .foregroundColor: SourcesCSSTheme.uiTextPrimary,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: SourcesCSSTheme.uiTextPrimary
        ]
        self.navigationController?.navigationBar.standardAppearance = appearance
        self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
        self.navigationController?.navigationBar.tintColor = SourcesCSSTheme.uiPrimaryBlue

        setupFixSwiftUIView()
    }

    private func setupFixSwiftUIView() {
        let swiftUIView = FixMainSwiftUIView()
        let host = UIHostingController(rootView: swiftUIView)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear

        self.addChild(host)
        self.view.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])

        host.didMove(toParent: self)
        self.hostingController = host
    }
}
