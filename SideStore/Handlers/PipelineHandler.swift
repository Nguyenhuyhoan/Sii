
//
//  PipelineHandler.swift
//  SideStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit
import SwiftUI
import SideSign

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI TOÀN BỘ ỨNG DỤNG & CHỮ ĐEN TUYỀN)
private struct PipelineCSSTheme {
    static let white = UIColor.white
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)      // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)   // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)     // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)       // #dc3545
    static let magenta = UIColor(red: 255/255, green: 0/255, blue: 255/255, alpha: 1.0)   // #ff00ff

    static let cornerRadius: CGFloat = 18.0
    static let innerCornerRadius: CGFloat = 14.0

    // SwiftUI Colors (Đồng bộ 100% với toàn bộ hệ thống & Chữ Đen Tuyền #000000)
    static let suiPrimary = SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255)
    static let suiSecondary = SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255)
    static let suiGreen = SwiftUI.Color(red: 40/255, green: 167/255, blue: 69/255)
    static let suiOrange = SwiftUI.Color(red: 253/255, green: 126/255, blue: 20/255)
    static let suiRed = SwiftUI.Color(red: 220/255, green: 53/255, blue: 69/255)
    static let suiMagenta = SwiftUI.Color(red: 255/255, green: 0/255, blue: 255/255)
    static let suiPureBlack = SwiftUI.Color.black                                         // #000000
    static let suiCardBackground = SwiftUI.Color.white
    static let suiInnerRowBackground = SwiftUI.Color(red: 245/255, green: 248/255, blue: 255/255) // #f5f8ff
    static let suiBorder = SwiftUI.Color(red: 220/255, green: 226/255, blue: 236/255)             // #dce2ec
    static let suiInnerBorder = SwiftUI.Color(red: 222/255, green: 229/255, blue: 240/255)        // #dee5f0

    static var suiPageGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 243/255, green: 224/255, blue: 255/255),
                SwiftUI.Color(red: 224/255, green: 247/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var suiHeroGradient: LinearGradient {
        LinearGradient(
            colors: [
                SwiftUI.Color(red: 0/255, green: 123/255, blue: 255/255).opacity(0.95),
                SwiftUI.Color(red: 111/255, green: 66/255, blue: 193/255).opacity(0.92)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var suiAccentUnderlineGradient: LinearGradient {
        LinearGradient(
            colors: [suiPrimary, suiSecondary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

private struct PipelineBounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some SwiftUI.View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .offset(x: configuration.isPressed ? 3 : 0, y: configuration.isPressed ? -1 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

// MARK: - 🛡️ KHUNG CHỌN APP ID THÔNG MINH HIỆN Ở GIỮA MÀN HÌNH KHI CÀI IPA MỚI
private struct SmartBundleIDCenterModalView: SwiftUI.View {
    let initialBundleID: String
    let appName: String
    let teamID: String
    let reusableAppIDs: [ReusableAppIDCandidate]
    let overwritableApps: [OverwritableAppCandidate]
    let onComplete: ((String, Bool)?) -> Void

    @State private var isManualExpanded: Bool = false
    @State private var customBundleIDText: String
    @State private var appendTeamID: Bool = true

    init(
        initialBundleID: String,
        appName: String,
        teamID: String,
        reusableAppIDs: [ReusableAppIDCandidate],
        overwritableApps: [OverwritableAppCandidate],
        onComplete: @escaping ((String, Bool)?) -> Void
    ) {
        self.initialBundleID = initialBundleID
        self.appName = appName
        self.teamID = teamID
        self.reusableAppIDs = reusableAppIDs
        self.overwritableApps = overwritableApps
        self.onComplete = onComplete
        self._customBundleIDText = State(initialValue: initialBundleID)
    }

    /// Đổi "Còn ... ngày" thành "...d" cực gọn
    private func remainingDaysText(for date: Date?) -> String {
        guard let date else { return "∞" }
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return "0d" }
        let days = Int(ceil(seconds / 86400.0))
        return "\(days)d"
    }

    /// Bỏ đuôi .TEAM_ID khỏi Bundle ID khi hiển thị trên UI để dễ nhìn và không tốn chỗ
    private func displayCleanBundleID(_ fullID: String) -> String {
        let trimmed = fullID.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTeam = teamID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTeam.isEmpty else { return trimmed }

        let suffix = ".\(cleanTeam)"
        if trimmed.lowercased().hasSuffix(suffix.lowercased()), trimmed.count > suffix.count {
            return String(trimmed.dropLast(suffix.count))
        }
        return trimmed
    }

    var body: some SwiftUI.View {
        ZStack {
            SwiftUI.Color.black.opacity(0.44)
                .ignoresSafeArea()

            VStack(spacing: 11) {
                // Banner tiêu đề chuẩn Hero (Đồng bộ 100% với vòng tròn kính mờ & viền sáng)
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(SwiftUI.Color.white.opacity(0.12))
                        .frame(width: 95, height: 95)
                        .offset(x: 28, y: -35)

                    VStack(spacing: 4) {
                        HStack(spacing: 7) {
                            ZStack {
                                Circle()
                                    .fill(SwiftUI.Color.white.opacity(0.22))
                                    .frame(width: 28, height: 28)
                                SwiftUI.Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            SwiftUI.Text(appName.isEmpty ? "Chọn Định Danh (App ID)" : "Cài đặt: \(appName)")
                                .font(.system(size: 17, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .shadow(color: SwiftUI.Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
                        }

                        SwiftUI.Text("Tự động gộp mọi tiện ích mở rộng vào 1 ID chính duy nhất")
                            .font(.system(size: 12.2, weight: .semibold))
                            .foregroundColor(SwiftUI.Color.white.opacity(0.96))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                }
                .background(PipelineCSSTheme.suiHeroGradient)
                .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous)
                        .stroke(SwiftUI.Color.white.opacity(0.32), lineWidth: 1.2)
                )
                .shadow(color: PipelineCSSTheme.suiPrimary.opacity(0.24), radius: 12, x: 0, y: 5)

                // Khối thẻ trắng chính chứa các lựa chọn ID
                VStack(spacing: 10) {
                    // Lựa chọn 1: Dùng ID gốc của IPA
                    SwiftUI.Button {
                        onComplete((initialBundleID, true))
                    } label: {
                        HStack(spacing: 9) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(PipelineCSSTheme.suiPrimary.opacity(0.14))
                                    .frame(width: 36, height: 36)
                                SwiftUI.Image(systemName: "plus.app.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(PipelineCSSTheme.suiPrimary)
                            }

                            VStack(alignment: .leading, spacing: 2.5) {
                                SwiftUI.Text("Dùng ID gốc của IPA")
                                    .font(.system(size: 14.5, weight: .bold))
                                    .foregroundColor(PipelineCSSTheme.suiPureBlack)

                                SwiftUI.Text(displayCleanBundleID(initialBundleID))
                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                    .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            SwiftUI.Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(PipelineCSSTheme.suiPrimary)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 10)
                        .background(PipelineCSSTheme.suiInnerRowBackground)
                        .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous)
                                .stroke(PipelineCSSTheme.suiPrimary.opacity(0.55), lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(PipelineBounceButtonStyle())

                    // Lựa chọn 2: Dùng lại ID cũ (10 ID từ Apple trừ đi app còn sống & mở rộng, trừ luôn SideStore và LC+SS & mở rộng)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(PipelineCSSTheme.suiGreen.opacity(0.15))
                                    .frame(width: 21, height: 21)
                                SwiftUI.Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(PipelineCSSTheme.suiGreen)
                            }
                            SwiftUI.Text("Dùng lại ID cũ")
                                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                .foregroundColor(PipelineCSSTheme.suiGreen)
                            Spacer()
                        }

                        if reusableAppIDs.isEmpty {
                            HStack(spacing: 8) {
                                SwiftUI.Image(systemName: "info.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(PipelineCSSTheme.suiSecondary)
                                SwiftUI.Text("Hiện không có ID cũ nào rảnh rỗi ngoài các ứng dụng đang hoạt động.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(PipelineCSSTheme.suiCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(PipelineCSSTheme.suiInnerBorder, lineWidth: 1)
                            )
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 6) {
                                    ForEach(reusableAppIDs) { candidate in
                                        SwiftUI.Button {
                                            onComplete((candidate.fullBundleIdentifier, false))
                                        } label: {
                                            HStack(spacing: 8) {
                                                ZStack {
                                                    Circle()
                                                        .fill(PipelineCSSTheme.suiGreen.opacity(0.14))
                                                        .frame(width: 26, height: 26)
                                                    SwiftUI.Image(systemName: "bolt.shield.fill")
                                                        .font(.system(size: 12.5, weight: .bold))
                                                        .foregroundColor(PipelineCSSTheme.suiGreen)
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    SwiftUI.Text(candidate.name)
                                                        .font(.system(size: 13.5, weight: .bold))
                                                        .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                                        .lineLimit(1)

                                                    SwiftUI.Text(displayCleanBundleID(candidate.fullBundleIdentifier))
                                                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                                        .lineLimit(2)
                                                        .minimumScaleFactor(0.72)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                                VStack(alignment: .trailing, spacing: 2) {
                                                    SwiftUI.Text("0 ID")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(PipelineCSSTheme.suiGreen)
                                                        .padding(.horizontal, 5)
                                                        .padding(.vertical, 1.5)
                                                        .background(
                                                            Capsule()
                                                                .fill(PipelineCSSTheme.suiGreen.opacity(0.15))
                                                        )

                                                    SwiftUI.Text(remainingDaysText(for: candidate.expirationDate))
                                                        .font(.system(size: 10.5, weight: .bold))
                                                        .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                                }
                                                .fixedSize()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 8)
                                            .background(PipelineCSSTheme.suiCardBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                    .stroke(PipelineCSSTheme.suiGreen.opacity(0.42), lineWidth: 1.1)
                                            )
                                        }
                                        .buttonStyle(PipelineBounceButtonStyle())
                                    }
                                }
                                .padding(1)
                            }
                            .frame(maxHeight: min(CGFloat(reusableAppIDs.count) * 60.0, 155.0))
                        }
                    }
                    .padding(9)
                    .background(PipelineCSSTheme.suiInnerRowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous)
                            .stroke(PipelineCSSTheme.suiInnerBorder, lineWidth: 1.1)
                    )

                    // Lựa chọn 3: Cài đè lên App (nằm ngay dưới "Dùng lại ID cũ", hiển thị các app có thể cài đè trừ SideStore và LC+SS)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(PipelineCSSTheme.suiOrange.opacity(0.16))
                                    .frame(width: 21, height: 21)
                                SwiftUI.Image(systemName: "arrow.down.doc.fill")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(PipelineCSSTheme.suiOrange)
                            }
                            SwiftUI.Text("Cài đè lên App")
                                .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                                .foregroundColor(PipelineCSSTheme.suiOrange)
                            Spacer()
                        }

                        if overwritableApps.isEmpty {
                            HStack(spacing: 8) {
                                SwiftUI.Image(systemName: "info.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(PipelineCSSTheme.suiSecondary)
                                SwiftUI.Text("Chưa có ứng dụng nào trên máy có thể cài đè.")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(PipelineCSSTheme.suiCardBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .stroke(PipelineCSSTheme.suiInnerBorder, lineWidth: 1)
                            )
                        } else {
                            ScrollView(.vertical, showsIndicators: true) {
                                VStack(spacing: 6) {
                                    ForEach(overwritableApps) { appCandidate in
                                        SwiftUI.Button {
                                            // KHI BẤM CHỌN APP ĐỂ CÀI ĐÈ:
                                            // Truyền fullBundleIdentifier của app bị cài đè để gán cho IPA mới và các mở rộng của IPA mới
                                            onComplete((appCandidate.fullBundleIdentifier, false))
                                        } label: {
                                            HStack(spacing: 8) {
                                                ZStack {
                                                    Circle()
                                                        .fill(PipelineCSSTheme.suiOrange.opacity(0.15))
                                                        .frame(width: 26, height: 26)
                                                    SwiftUI.Image(systemName: "square.and.arrow.down.on.square.fill")
                                                        .font(.system(size: 12, weight: .bold))
                                                        .foregroundColor(PipelineCSSTheme.suiOrange)
                                                }

                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack(spacing: 5) {
                                                        SwiftUI.Text(appCandidate.name)
                                                            .font(.system(size: 13.5, weight: .bold))
                                                            .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                                            .lineLimit(1)

                                                        if let ver = appCandidate.version, !ver.isEmpty {
                                                            SwiftUI.Text("v\(ver)")
                                                                .font(.system(size: 10.5, weight: .bold))
                                                                .foregroundColor(PipelineCSSTheme.suiSecondary)
                                                                .lineLimit(1)
                                                        }
                                                    }

                                                    SwiftUI.Text(displayCleanBundleID(appCandidate.fullBundleIdentifier))
                                                        .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                                                        .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                                        .lineLimit(2)
                                                        .minimumScaleFactor(0.72)
                                                        .fixedSize(horizontal: false, vertical: true)
                                                        .multilineTextAlignment(.leading)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                                VStack(alignment: .trailing, spacing: 2) {
                                                    SwiftUI.Text("Cài đè")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundColor(PipelineCSSTheme.suiOrange)
                                                        .padding(.horizontal, 5.5)
                                                        .padding(.vertical, 1.5)
                                                        .background(
                                                            Capsule()
                                                                .fill(PipelineCSSTheme.suiOrange.opacity(0.15))
                                                        )

                                                    SwiftUI.Text(remainingDaysText(for: appCandidate.expirationDate))
                                                        .font(.system(size: 10.5, weight: .bold))
                                                        .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                                }
                                                .fixedSize()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 8)
                                            .background(PipelineCSSTheme.suiCardBackground)
                                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                    .stroke(PipelineCSSTheme.suiOrange.opacity(0.45), lineWidth: 1.1)
                                            )
                                        }
                                        .buttonStyle(PipelineBounceButtonStyle())
                                    }
                                }
                                .padding(1)
                            }
                            .frame(maxHeight: min(CGFloat(overwritableApps.count) * 60.0, 145.0))
                        }
                    }
                    .padding(9)
                    .background(PipelineCSSTheme.suiInnerRowBackground)
                    .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous)
                            .stroke(PipelineCSSTheme.suiInnerBorder, lineWidth: 1.1)
                    )

                    // Lựa chọn 4: Tự nhập mã Bundle ID tùy chỉnh
                    VStack(spacing: 8) {
                        SwiftUI.Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isManualExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                SwiftUI.Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 13.5, weight: .bold))
                                    .foregroundColor(PipelineCSSTheme.suiSecondary)
                                SwiftUI.Text("Tự nhập Bundle ID tùy chỉnh khác")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                Spacer()
                                SwiftUI.Image(systemName: isManualExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(PipelineCSSTheme.suiSecondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 9)
                            .background(PipelineCSSTheme.suiInnerRowBackground)
                            .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous)
                                    .stroke(PipelineCSSTheme.suiInnerBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(PipelineBounceButtonStyle())

                        if isManualExpanded {
                            VStack(spacing: 8) {
                                TextField("com.example.app", text: $customBundleIDText)
                                    .textInputAutocapitalization(.never)
                                    .disableAutocorrection(true)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(PipelineCSSTheme.suiPureBlack)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8.5)
                                    .background(PipelineCSSTheme.suiCardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(PipelineCSSTheme.suiPrimary.opacity(0.45), lineWidth: 1)
                                    )

                                SwiftUI.Button {
                                    let trimmed = customBundleIDText.trimmingCharacters(in: .whitespacesAndNewlines)
                                    let rawID = trimmed.isEmpty ? initialBundleID : trimmed
                                    let sanitized = InfoPlistParser.sanitizeBundleID(rawID)
                                    onComplete((sanitized.isEmpty ? initialBundleID : sanitized, true))
                                } label: {
                                    SwiftUI.Text("Bắt đầu Cài Đặt")
                                        .font(.system(size: 13.5, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9.5)
                                        .background(PipelineCSSTheme.suiPrimary)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(PipelineBounceButtonStyle())
                            }
                            .padding(9)
                            .background(PipelineCSSTheme.suiInnerRowBackground)
                            .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous)
                                    .stroke(PipelineCSSTheme.suiInnerBorder, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(11)
                .background(PipelineCSSTheme.suiCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous)
                        .stroke(PipelineCSSTheme.suiBorder, lineWidth: 1.1)
                )
                .shadow(color: PipelineCSSTheme.suiPrimary.opacity(0.09), radius: 14, x: 0, y: 6)

                // Nút Hủy cài đặt
                SwiftUI.Button {
                    onComplete(nil)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        SwiftUI.Text("Hủy cài đặt")
                            .font(.system(size: 15.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [PipelineCSSTheme.suiRed, PipelineCSSTheme.suiMagenta.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
                    .shadow(color: PipelineCSSTheme.suiRed.opacity(0.32), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PipelineBounceButtonStyle())
            }
            .padding(12)
            .background(PipelineCSSTheme.suiPageGradient)
            .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius + 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius + 4, style: .continuous)
                    .stroke(SwiftUI.Color.white.opacity(0.88), lineWidth: 1.5)
            )
            .shadow(color: SwiftUI.Color.black.opacity(0.24), radius: 22, x: 0, y: 10)
            .frame(maxWidth: 420)
            .padding(.horizontal, 10)
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - 🧩 KHUNG LỰA CHỌN XỬ LÝ APP ID HIỆN Ở GIỮA MÀN HÌNH (CHỈ GỒM 4 CÁCH XỬ LÝ & NÚT HỦY)
private enum ExtensionAlertChoice {
    case keepAllMainProfile
    case keepAllSeparateAppIDs
    case removeAll
    case chooseCustom
    case cancel
}

private struct ExtensionDecisionCenterModalView: SwiftUI.View {
    let onSelect: (ExtensionAlertChoice) -> Void

    var body: some SwiftUI.View {
        ZStack {
            SwiftUI.Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                // Hero Banner đồng bộ cho khung lựa chọn Tiện ích mở rộng
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(SwiftUI.Color.white.opacity(0.12))
                        .frame(width: 85, height: 85)
                        .offset(x: 25, y: -30)

                    VStack(spacing: 3) {
                        HStack(spacing: 7) {
                            ZStack {
                                Circle()
                                    .fill(SwiftUI.Color.white.opacity(0.22))
                                    .frame(width: 26, height: 26)
                                SwiftUI.Image(systemName: "puzzlepiece.extension.fill")
                                    .font(.system(size: 12.5, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            SwiftUI.Text("Tiện Ích Mở Rộng (Extensions)")
                                .font(.system(size: 16.5, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: SwiftUI.Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
                        }
                        SwiftUI.Text("Chọn phương thức xử lý App ID cho các tiện ích đi kèm")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(SwiftUI.Color.white.opacity(0.95))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 11)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                }
                .background(PipelineCSSTheme.suiHeroGradient)
                .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous)
                        .stroke(SwiftUI.Color.white.opacity(0.32), lineWidth: 1.2)
                )
                .shadow(color: PipelineCSSTheme.suiPrimary.opacity(0.22), radius: 10, x: 0, y: 4)

                VStack(spacing: 9) {
                    optionButton(
                        icon: "shield.lefthalf.filled.badge.checkmark",
                        iconColor: PipelineCSSTheme.suiGreen,
                        title: "Giữ tất cả 1 cách thông minh",
                        subtitle: "Giữ nguyên tất cả tiện ích chỉ dùng 1 App ID",
                        borderColor: PipelineCSSTheme.suiGreen.opacity(0.55)
                    ) {
                        onSelect(.keepAllMainProfile)
                    }

                    optionButton(
                        icon: "key.radiowaves.forward.fill",
                        iconColor: PipelineCSSTheme.suiPrimary,
                        title: "Giữ tất cả và tạo App ID riêng",
                        subtitle: "Đăng ký từng App ID riêng cho mỗi tiện ích (Tốn nhiều ID)",
                        borderColor: PipelineCSSTheme.suiInnerBorder
                    ) {
                        onSelect(.keepAllSeparateAppIDs)
                    }

                    optionButton(
                        icon: "checklist",
                        iconColor: PipelineCSSTheme.suiSecondary,
                        title: "Tùy chọn từng tiện ích...",
                        subtitle: "Chọn các tiện ích muốn giữ hoặc gỡ bỏ",
                        borderColor: PipelineCSSTheme.suiInnerBorder
                    ) {
                        onSelect(.chooseCustom)
                    }

                    optionButton(
                        icon: "trash.fill",
                        iconColor: PipelineCSSTheme.suiRed,
                        title: "Gỡ bỏ tất cả tiện ích",
                        subtitle: "Chỉ cài ứng dụng chính, chỉ dùng 1 App ID",
                        borderColor: PipelineCSSTheme.suiRed.opacity(0.38)
                    ) {
                        onSelect(.removeAll)
                    }
                }
                .padding(12)
                .background(PipelineCSSTheme.suiCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius, style: .continuous)
                        .stroke(PipelineCSSTheme.suiBorder, lineWidth: 1.1)
                )
                .shadow(color: PipelineCSSTheme.suiPrimary.opacity(0.09), radius: 14, x: 0, y: 6)

                SwiftUI.Button {
                    onSelect(.cancel)
                } label: {
                    HStack(spacing: 8) {
                        SwiftUI.Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))
                        SwiftUI.Text("Hủy cài đặt")
                            .font(.system(size: 15.5, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12.5)
                    .background(
                        LinearGradient(
                            colors: [PipelineCSSTheme.suiRed, PipelineCSSTheme.suiMagenta.opacity(0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
                    .shadow(color: PipelineCSSTheme.suiRed.opacity(0.32), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(PipelineBounceButtonStyle())
            }
            .padding(14)
            .background(PipelineCSSTheme.suiPageGradient)
            .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius + 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PipelineCSSTheme.cornerRadius + 4, style: .continuous)
                    .stroke(SwiftUI.Color.white.opacity(0.88), lineWidth: 1.5)
            )
            .shadow(color: SwiftUI.Color.black.opacity(0.24), radius: 22, x: 0, y: 10)
            .frame(maxWidth: 380)
            .padding(.horizontal, 20)
        }
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private func optionButton(
        icon: String,
        iconColor: SwiftUI.Color,
        title: String,
        subtitle: String,
        borderColor: SwiftUI.Color,
        action: @escaping () -> Void
    ) -> some SwiftUI.View {
        SwiftUI.Button(action: action) {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 38, height: 38)
                    SwiftUI.Image(systemName: icon)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2.5) {
                    SwiftUI.Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(PipelineCSSTheme.suiPureBlack)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    SwiftUI.Text(subtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(PipelineCSSTheme.suiPureBlack)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                SwiftUI.Image(systemName: "chevron.right")
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(PipelineCSSTheme.suiPrimary)
            }
            .padding(11)
            .background(PipelineCSSTheme.suiInnerRowBackground)
            .clipShape(RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: PipelineCSSTheme.innerCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1.2)
            )
        }
        .buttonStyle(PipelineBounceButtonStyle())
    }
}

final class PipelineHandler: PipelineExecutionHandler,
                             PreflightChecksHandler,
                             EntitlementsReviewHandler,
                             ExtensionRemovalHandler,
                             UnsupportedVersionHandler,
                             InstallAppHandler,
                             UserCustomizationHandler,
                             Sendable
{
    var preflightChecksHandler: PreflightChecksHandler { self }
    var entitlementsReviewHandler: EntitlementsReviewHandler { self }
    var extensionRemovalHandler: ExtensionRemovalHandler { self }
    var unsupportedVersionHandler: UnsupportedVersionHandler { self }
    var installAppHandler: InstallAppHandler { self }
    var userCustomizationHandler: UserCustomizationHandler { self }

    let isResignActive: Bool
    private let presenterProvider: PresenterProvider?

    init(
        isResignActive: Bool = false,
        presenterProvider: PresenterProvider? = nil
    ) {
        self.isResignActive = isResignActive
        self.presenterProvider = presenterProvider
    }

    @MainActor
    private var isPresenterAvailable: Bool {
        return self.activePresenter != nil
    }

    @MainActor
    private var activePresenter: UIViewController? {
        return self.presenterProvider?()
    }

    @MainActor
    func resolveBundleIDMismatch(targetID: String, activeEffectiveID: String) async -> Bool {
        guard let presenter = self.activePresenter else {
            return false
        }
        
        let title = "Không Khớp Bundle ID"
        let message = String(
            format: "Ứng dụng bạn đang cài đặt có Bundle ID (%@) không khớp với ứng dụng đang hoạt động (%@). Bạn có muốn tiếp tục không?",
            targetID,
            activeEffectiveID
        )
        
        return await withCheckedContinuation { continuation in
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.view.tintColor = PipelineCSSTheme.blue
            alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alertController.addAction(UIAlertAction(title: "Tiếp tục", style: .default) { _ in
                continuation.resume(returning: true)
            })
            presenter.present(alertController, animated: true)
        }
    }

    @MainActor
    func reviewPermissions(_ permissions: [ALTEntitlement], for app: AppProtocol, mode: PermissionReviewMode) async throws {
        guard let presenter = self.activePresenter else {
            throw OperationError.invalidParameters("PipelineHandler: Không thể kiểm tra quyền vì màn hình hiển thị không khả dụng")
        }
        let reviewPermissionsViewController = ReviewPermissionsViewController(app: app, permissions: permissions, mode: mode)
        let navigationController = UINavigationController(rootViewController: reviewPermissionsViewController)
        
        defer {
            navigationController.dismiss(animated: true)
        }
        
        try await withCheckedThrowingContinuation { continuation in
            reviewPermissionsViewController.completionHandler = { result in
                continuation.resume(with: result)
            }
            
            presenter.present(navigationController, animated: true)
        }
    }

    // MARK: - ✨ KHUNG HIỆN Ở GIỮA MÀN HÌNH (CHỈ CHỨA 4 CÁCH XỬ LÝ APP ID & NÚT HỦY) ✨
    @MainActor
    func selectAppExtensionsToRemove(
        appBundle: ALTApplication,
        localAppExtensions: [ALTApplication],
        excessExtensions: Set<ALTApplication>
    ) async throws -> ExtensionRemovalDecision {
        guard let presenter = self.activePresenter else {
            return .removeSelected(excessExtensions)
        }
        
        let step1Choice: ExtensionAlertChoice = await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: (ExtensionAlertChoice) -> Void = { choice in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: choice)
            }

            var hostingController: UIHostingController<ExtensionDecisionCenterModalView>?

            let modalView = ExtensionDecisionCenterModalView { choice in
                if let hc = hostingController, hc.presentingViewController != nil {
                    hc.dismiss(animated: true) {
                        resumeOnce(choice)
                    }
                } else {
                    resumeOnce(choice)
                }
            }

            let hc = UIHostingController(rootView: modalView)
            hostingController = hc
            hc.overrideUserInterfaceStyle = .light
            hc.view.backgroundColor = .clear
            hc.modalPresentationStyle = .overFullScreen
            hc.modalTransitionStyle = .crossDissolve

            presenter.present(hc, animated: true) {
                if presenter.presentedViewController == nil && !hc.isViewLoaded {
                    resumeOnce(.cancel)
                }
            }
        }

        switch step1Choice {
        case .cancel:
            throw OperationError.cancelled
        case .keepAllMainProfile:
            return .keepAll(useMainProfile: true)
        case .keepAllSeparateAppIDs:
            return .keepAll(useMainProfile: false)
        case .removeAll:
            return .removeAll
        case .chooseCustom:
            return try await presentCustomExtensionPicker(for: appBundle, from: presenter)
        }
    }

    @MainActor
    private func presentCustomExtensionPicker(
        for appBundle: ALTApplication,
        from presenter: UIViewController
    ) async throws -> ExtensionRemovalDecision {
        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let resumeOnce: (Result<ExtensionRemovalDecision, Error>) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(with: result)
            }

            let popoverContentController = AppExtensionViewHostingController(extensions: appBundle.appExtensions) { selection in
                resumeOnce(.success(.removeSelected(Set(selection))))
            }
            popoverContentController.overrideUserInterfaceStyle = .light

            #if !os(tvOS)
            popoverContentController.modalPresentationStyle = .pageSheet
            if #available(iOS 15.0, *), let sheet = popoverContentController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
            presenter.present(popoverContentController, animated: true) {
                if presenter.presentedViewController == nil && !popoverContentController.isViewLoaded {
                    resumeOnce(.failure(OperationError.invalidParameters("Không thể mở danh sách tiện ích mở rộng.")))
                }
            }
            #else
            popoverContentController.modalPresentationStyle = .blurOverFullScreen
            presenter.present(popoverContentController, animated: true)
            #endif
        }
    }

    @MainActor
    func resolveUnsupportediOSVersion(errorDescription: String, appName: String, compatibleVersion: String) async throws -> Bool {
        guard let presenter = self.activePresenter else {
            return false
        }
        
        let title = "Phiên Bản iOS Không Hỗ Trợ"
        let message = errorDescription + "\n\n" + "Bạn có muốn tải xuống phiên bản cuối cùng tương thích với thiết bị này không?"
        
        return await withCheckedContinuation { continuation in
            let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alertController.view.tintColor = PipelineCSSTheme.blue
            alertController.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            alertController.addAction(UIAlertAction(title: String(format: "Tải %@ %@", appName, compatibleVersion), style: .default) { _ in
                continuation.resume(returning: true)
            })
            presenter.present(alertController, animated: true)
        }
    }

    func requestBackgroundSuspension() async {
        await withCheckedContinuation { continuation in
            Task { @MainActor in
                let alert = UIAlertController(
                    title: "Hoàn Tất Làm Mới",
                    message: """
                    Để hoàn tất quá trình làm mới, SideStore cần được chuyển xuống chạy nền. Bạn có thể tự thoát ra Màn hình chính hoặc bấm "Tiếp tục" bên dưới, sau đó mở lại SideStore.
                    """,
                    preferredStyle: .alert
                )
                alert.view.tintColor = PipelineCSSTheme.blue
                alert.addAction(UIAlertAction(title: "Tiếp tục", style: .default, handler: { _ in
                    continuation.resume()
                }))
                
                let presenter = self.activePresenter
                                ?? UIApplication.shared.connectedScenes
                                    .compactMap { ($0 as? UIWindowScene)?.keyWindow }
                                    .first?.rootViewController
                                    
                if var topVC = presenter {
                    while let presented = topVC.presentedViewController {
                        topVC = presented
                    }
                    topVC.present(alert, animated: true)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func suspendToHomeScreen() async {
        await CellularRefreshManager.shared.turnOnDataIfNeeded()
        await MainActor.run {
            _ = UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
        }
    }

    func isAppInForeground() async -> Bool {
        await MainActor.run {
            UIApplication.shared.applicationState == .active
        }
    }

    @MainActor
    func resolveInfoPlistCustomization(
        targets: [InfoPlistTarget],
        initialBundleID: String,
        appendTeamID: Bool,
        installedAppIdentities: [String: String],
        teamID: String
    ) async throws -> (modifiedPlists: [String: [String: any Sendable]], appendTeamID: Bool)? {
        debugLog("[PipelineHandler] resolveInfoPlistCustomization (targets: \(targets.count)): initialBundleID='\(initialBundleID)', teamID='\(teamID)', appendTeamID=\(appendTeamID)")
        guard let presenter = self.activePresenter else {
            debugLog("[PipelineHandler] resolveInfoPlistCustomization: activePresenter is nil!")
            var fallback: [String: [String: any Sendable]] = [:]
            for t in targets {
                fallback[t.id] = t.initialPlist
            }
            return (fallback, appendTeamID)
        }

        let result: (modifiedPlists: [String: [String: any Sendable]], appendTeamID: Bool)?
        if UserDefaults.standard.preferSheetForInfoPlistCustomization {
            result = await InfoPlistCustomizationSheetView.present(
                from: presenter,
                targets: targets,
                initialBundleID: initialBundleID,
                appendTeamID: appendTeamID,
                installedAppIdentities: installedAppIdentities,
                teamID: teamID
            )
        } else {
            result = await InfoPlistCustomizationView.present(
                from: presenter,
                targets: targets,
                initialBundleID: initialBundleID,
                appendTeamID: appendTeamID,
                installedAppIdentities: installedAppIdentities,
                teamID: teamID
            )
        }
        debugLog("[PipelineHandler] resolveInfoPlistCustomization result: \(result?.modifiedPlists.count ?? 0) target(s) returned, appendTeamID=\(result?.appendTeamID ?? false)")
        return result
    }

    @MainActor
    func resolveInfoPlistCustomization(
        initialPlist: [String: any Sendable],
        initialBundleID: String,
        appendTeamID: Bool,
        installedAppIdentities: [String: String],
        teamID: String
    ) async throws -> (modifiedPlist: [String: any Sendable], appendTeamID: Bool)? {
        let target = InfoPlistTarget(
            id: initialBundleID,
            name: (initialPlist["CFBundleDisplayName"] as? String) ?? (initialPlist["CFBundleName"] as? String) ?? initialBundleID,
            isExtension: false,
            initialPlist: initialPlist
        )
        guard let result = try await resolveInfoPlistCustomization(
            targets: [target],
            initialBundleID: initialBundleID,
            appendTeamID: appendTeamID,
            installedAppIdentities: installedAppIdentities,
            teamID: teamID
        ) else { return nil }
        let plist = result.modifiedPlists[initialBundleID] ?? initialPlist
        return (plist, result.appendTeamID)
    }

    @MainActor
    func resolveEntitlementsCustomization(
        targets: [EntitlementsTarget],
        teamType: ALTTeamType
    ) async throws -> [String: [String: any Sendable]]? {
        debugLog("[PipelineHandler] resolveEntitlementsCustomization: targets=\(targets.count), teamType=\(teamType.displayName)")
        guard let presenter = self.activePresenter else {
            debugLog("[PipelineHandler] resolveEntitlementsCustomization: activePresenter is nil!")
            var fallback: [String: [String: any Sendable]] = [:]
            for t in targets {
                fallback[t.id] = t.initialEntitlements
            }
            return fallback
        }

        let result: [String: [String: any Sendable]]?
        if UserDefaults.standard.preferSheetForEntitlementsCustomization {
            result = await EntitlementsCustomizationSheetView.present(
                from: presenter,
                targets: targets,
                teamType: teamType
            )
        } else {
            result = await EntitlementsCustomizationView.present(
                from: presenter,
                targets: targets,
                teamType: teamType
            )
        }
        debugLog("[PipelineHandler] resolveEntitlementsCustomization result: \(result?.count ?? 0) target(s) returned")
        return result
    }

    @MainActor
    func resolveEntitlementsCustomization(
        initialEntitlements: [String: any Sendable],
        bundleID: String,
        teamType: ALTTeamType
    ) async throws -> [String: any Sendable]? {
        let target = EntitlementsTarget(
            id: bundleID,
            name: bundleID,
            isExtension: false,
            initialEntitlements: initialEntitlements
        )
        let result = try await resolveEntitlementsCustomization(targets: [target], teamType: teamType)
        return result?[bundleID]
    }

    // MARK: - 🛡️ BẢNG CHỌN APP ID THÔNG MINH KHI CÀI ĐẶT IPA MỚI
    @MainActor
    func resolveBundleIDOverride(
        initialBundleID: String,
        appName: String,
        teamID: String,
        reusableAppIDs: [ReusableAppIDCandidate],
        overwritableApps: [OverwritableAppCandidate]
    ) async throws -> (customID: String, appendTeamID: Bool)? {
        let cleanInitialID: String = {
            let trimmed = initialBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
            let sanitized = InfoPlistParser.sanitizeBundleID(trimmed)
            return sanitized.isEmpty ? trimmed : sanitized
        }()

        guard let presenter = self.activePresenter else {
            return (cleanInitialID, true)
        }

        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let resumeOnce: ((String, Bool)?) -> Void = { value in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: value)
            }

            var hostingController: UIHostingController<SmartBundleIDCenterModalView>?

            let modalView = SmartBundleIDCenterModalView(
                initialBundleID: cleanInitialID,
                appName: appName,
                teamID: teamID,
                reusableAppIDs: reusableAppIDs,
                overwritableApps: overwritableApps
            ) { result in
                if let hc = hostingController, hc.presentingViewController != nil {
                    hc.dismiss(animated: true) {
                        resumeOnce(result)
                    }
                } else {
                    resumeOnce(result)
                }
            }

            let hc = UIHostingController(rootView: modalView)
            hostingController = hc
            hc.overrideUserInterfaceStyle = .light
            hc.view.backgroundColor = .clear
            hc.modalPresentationStyle = .overFullScreen
            hc.modalTransitionStyle = .crossDissolve

            presenter.present(hc, animated: true) {
                if presenter.presentedViewController == nil && !hc.isViewLoaded {
                    resumeOnce(nil)
                }
            }
        }
    }

    @MainActor
    func resolveBundleIDOverride(
        initialBundleID: String,
        appName: String,
        teamID: String,
        reusableAppIDs: [ReusableAppIDCandidate]
    ) async throws -> (customID: String, appendTeamID: Bool)? {
        try await resolveBundleIDOverride(
            initialBundleID: initialBundleID,
            appName: appName,
            teamID: teamID,
            reusableAppIDs: reusableAppIDs,
            overwritableApps: []
        )
    }

    @MainActor
    func resolveBundleIDOverride(initialBundleID: String) async throws -> (customID: String, appendTeamID: Bool)? {
        let team = try await AuthManager.shared.getAuthenticatedTeam()
        let teamID = team.identifier
        guard !teamID.isEmpty else {
            throw OperationError.invalidParameters("Mã định danh nhóm nhà phát triển (Team ID) đang trống.")
        }
        return try await resolveBundleIDOverride(
            initialBundleID: initialBundleID,
            appName: "",
            teamID: teamID,
            reusableAppIDs: [],
            overwritableApps: []
        )
    }

    @MainActor
    func resolveAppGroupMismatch(originalGroup: String, correctedGroup: String) async throws -> AppGroupResolution {
        guard let presenter = self.activePresenter else {
            return .correctAndProceed(correctedGroup)
        }
        
        let title = "Sai Lệch App Group"
        let message = String(
            format: "Nhóm ứng dụng '%@' không khớp kiểu chữ hoa/thường với Bundle ID. Bạn có muốn tự động sửa thành '%@' không?",
            originalGroup,
            correctedGroup
        )
        
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.view.tintColor = PipelineCSSTheme.blue
            
            alert.addAction(UIAlertAction(title: "Sửa & Tiếp tục", style: .default) { _ in
                continuation.resume(returning: .correctAndProceed(correctedGroup))
            })
            
            alert.addAction(UIAlertAction(title: "Giữ nguyên gốc", style: .destructive) { _ in
                continuation.resume(returning: .keepOriginal(originalGroup))
            })
            
            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(returning: .keepOriginal(originalGroup))
            })
            
            presenter.present(alert, animated: true)
        }
    }

    @MainActor
    func resolveAppIconCustomization(appName: String) async throws -> URL? {
        guard let presenter = self.activePresenter else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            let title = "Tùy Chỉnh Biểu Tượng"
            let message = String(format: "Bạn muốn chọn ảnh biểu tượng (Icon) mới cho '%@' hay giữ nguyên biểu tượng gốc?", appName)

            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.view.tintColor = PipelineCSSTheme.blue

            alert.addAction(UIAlertAction(title: "Chọn từ Thư viện ảnh", style: .default) { _ in
                #if !os(tvOS)
                let pickerDelegate = ImagePickerDelegateHandler { image in
                    guard let image = image,
                          let icon = image.resizing(toFill: CGSize(width: 256, height: 256)),
                          let iconData = icon.pngData() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CustomIcon_\(UUID().uuidString).png")
                    do {
                        try iconData.write(to: tempURL, options: .atomic)
                        continuation.resume(returning: tempURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                } onCancel: {
                    continuation.resume(returning: nil)
                }

                let imagePicker = UIImagePickerController()
                imagePicker.allowsEditing = true
                imagePicker.delegate = pickerDelegate
                objc_setAssociatedObject(imagePicker, "pickerDelegate", pickerDelegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                presenter.present(imagePicker, animated: true)
                #else
                TVWebFileTransferManager.shared.startImport(
                    acceptedExtensions: ["png", "jpg", "jpeg"],
                    title: "Tải lên Biểu tượng Tùy chỉnh",
                    presentingVC: presenter
                ) { fileURL in
                    guard let fileURL = fileURL,
                          let data = try? Data(contentsOf: fileURL),
                          let image = UIImage(data: data),
                          let icon = image.resizing(toFill: CGSize(width: 256, height: 256)),
                          let iconData = icon.pngData() else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("CustomIcon_\(UUID().uuidString).png")
                    do {
                        try iconData.write(to: tempURL, options: .atomic)
                        continuation.resume(returning: tempURL)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
                #endif
            })

            alert.addAction(UIAlertAction(title: "Giữ biểu tượng gốc", style: .default) { _ in
                continuation.resume(returning: nil)
            })

            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(throwing: OperationError.cancelled)
            })

            presenter.present(alert, animated: true)
        }
    }

    @MainActor
    func resolveProvisioningProfileCustomization(appName: String, bundleID: String) async throws -> ProfileCustomizationChoice? {
        guard let presenter = self.activePresenter else {
            return .defaultProfile
        }

        let allProfiles = ProfileManager.shared.getAllLocalProfiles()
        guard !allProfiles.isEmpty else {
            return .defaultProfile
        }

        return try await withCheckedThrowingContinuation { continuation in
            let title = "Chọn Hồ Sơ Cấu Hình"
            let message = String(format: "Chọn hồ sơ cấu hình (Provisioning Profile) cho '%@' (%@) hoặc dùng hồ sơ tự động mặc định.", appName, bundleID)

            let alert = UIAlertController(title: title, message: message, preferredStyle: .actionSheet)
            alert.view.tintColor = PipelineCSSTheme.blue

            alert.addAction(UIAlertAction(title: "Mặc định (Hồ sơ nhóm tự động)", style: .default) { _ in
                continuation.resume(returning: .defaultProfile)
            })

            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .none

            for profile in allProfiles {
                let isReady = ProfileManager.shared.isProfileReadyToSign(profile)
                let certInfo = isReady ? "✓ Sẵn sàng" : (profile.expirationDate < Date() ? "Hết hạn" : "Thiếu khóa")
                let profileTitle = "\(profile.name) (\(certInfo), HSD: \(formatter.string(from: profile.expirationDate)))"

                alert.addAction(UIAlertAction(title: profileTitle, style: .default) { _ in
                    continuation.resume(returning: .profile(profile))
                })
            }

            alert.addAction(UIAlertAction(title: "Hủy", style: .cancel) { _ in
                continuation.resume(throwing: OperationError.cancelled)
            })

            #if !os(tvOS)
            if let popover = alert.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            #endif

            presenter.present(alert, animated: true)
        }
    }
}

private final class ImagePickerDelegateHandler: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let onSelect: (UIImage?) -> Void
    let onCancel: () -> Void

    init(onSelect: @escaping (UIImage?) -> Void, onCancel: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage)
        picker.dismiss(animated: true) {
            self.onSelect(image)
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true) {
            self.onCancel()
        }
    }
}
