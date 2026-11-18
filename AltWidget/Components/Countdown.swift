
//
//  Countdown.swift
//  AltWidgetExtension
//
//  Created by Riley Testut on 7/6/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import WidgetKit

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME CHO WIDGET (CỐ ĐỊNH LIGHT MODE 100%)
enum WidgetCSSTheme {
    // Toàn bộ màu sắc được khóa cứng bằng RGB tĩnh, không bị biến đổi khi iOS bật Dark Mode
    static let primaryBlue = Color(red: 0/255, green: 123/255, blue: 255/255)          // #007bff
    static let secondaryPurple = Color(red: 111/255, green: 66/255, blue: 193/255)     // #6f42c1
    static let successGreen = Color(red: 40/255, green: 167/255, blue: 69/255)         // #28a745
    static let warningOrange = Color(red: 253/255, green: 126/255, blue: 20/255)       // #fd7e14
    static let dangerRed = Color(red: 220/255, green: 53/255, blue: 69/255)            // #dc3545
    static let neonMagenta = Color(red: 255/255, green: 0/255, blue: 255/255)          // #ff00ff
    static let darkText = Color(red: 52/255, green: 58/255, blue: 64/255)              // #343a40

    // Nền trắng tinh khiết 100% (không trong suốt) để chặn hoàn toàn màu tối của hệ thống
    static let cardBackground = Color(red: 255/255, green: 255/255, blue: 255/255)     // #ffffff
    static let innerRowBackground = Color(red: 246/255, green: 248/255, blue: 251/255) // #f6f8fb
    static let border = Color(red: 218/255, green: 224/255, blue: 233/255)             // #dae0e9
    static let cornerRadius: CGFloat = 15.0

    // Nền trang Gradient Sáng (#f3e0ff -> #e0f7ff) giống hệt SettingsViewController
    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 243/255, green: 224/255, blue: 255/255),
                Color(red: 224/255, green: 247/255, blue: 255/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Hero Gradient (Xanh #007bff -> Tím #6f42c1)
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [primaryBlue, secondaryPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - ✨ TIỆN ÍCH MỞ RỘNG KHOÁ CỨNG CHẾ ĐỘ SÁNG CHO WIDGET
extension View {
    /// Áp dụng nền Gradient Sáng (#f3e0ff -> #e0f7ff) và khóa cứng Light Mode cho toàn bộ Widget
    @ViewBuilder
    func widgetCSSPageBackground() -> some View {
        if #available(iOS 17.0, *) {
            self
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
                .containerBackground(for: .widget) {
                    WidgetCSSTheme.pageGradient
                        .environment(\.colorScheme, .light)
                }
        } else {
            self
                .environment(\.colorScheme, .light)
                .preferredColorScheme(.light)
                .background(WidgetCSSTheme.pageGradient)
        }
    }

    /// Bọc nội dung vào thẻ Card màu trắng đặc, viền mảnh #dae0e9, đổ bóng xanh dịu và khóa cứng Light Mode
    func widgetCSSCard(cornerRadius: CGFloat = WidgetCSSTheme.cornerRadius, padding: CGFloat = 12) -> some View {
        self
            .environment(\.colorScheme, .light)
            .preferredColorScheme(.light)
            .padding(padding)
            .background(WidgetCSSTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(WidgetCSSTheme.border, lineWidth: 1.0)
            )
            .shadow(color: WidgetCSSTheme.primaryBlue.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

// MARK: - ⏱️ GIAO DIỆN ĐẾM NGƯỢC THÔNG MINH CHUẨN CSS THEME (LUÔN SÁNG)
struct Countdown: View
{
    var startDate: Date?
    var endDate: Date?
    var currentDate: Date = Date()
    
    var strokeWidth: Double = 3.6
    
    @Environment(\.font) private var font
    
    // Kiểm tra đã hết hạn hay chưa
    private var isExpired: Bool {
        guard let endDate = self.endDate else { return true }
        return endDate <= self.currentDate
    }
    
    // Chuỗi hiển thị Ngày - Giờ
    private var remainingTimeText: String {
        guard let endDate = self.endDate, !isExpired else {
            return "0d 0h"
        }
        let remaining = endDate.remainingDaysAndHours(since: self.currentDate)
        return "\(remaining.days)d \(remaining.hours)h"
    }
    
    // Tính thanh tiến trình chính xác theo từng giây (từ 0.0 đến 1.0)
    private var fractionComplete: CGFloat {
        guard let startDate = self.startDate, let endDate = self.endDate else { return 1.0 }
        
        let totalTime = endDate.timeIntervalSince(startDate)
        let remainingTime = endDate.timeIntervalSince(self.currentDate)
        
        guard totalTime > 0 else { return 0.0 }
        
        let fraction = CGFloat(remainingTime / totalTime)
        return min(max(fraction, 0.0), 1.0)
    }
    
    // Màu sắc chính tự động biến đổi thông minh theo thời lượng còn lại
    private var statusAccentColor: Color {
        if isExpired {
            return WidgetCSSTheme.dangerRed
        } else if fractionComplete <= 0.25 {
            // Sắp hết hạn (dưới 25% thời gian ~ còn dưới 2 ngày)
            return WidgetCSSTheme.warningOrange
        } else {
            return WidgetCSSTheme.primaryBlue
        }
    }
    
    // Dải màu Gradient cho viền tiến trình (Progress Ring)
    private var statusRingGradient: LinearGradient {
        if isExpired {
            return LinearGradient(
                colors: [WidgetCSSTheme.dangerRed, WidgetCSSTheme.neonMagenta],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if fractionComplete <= 0.25 {
            return LinearGradient(
                colors: [WidgetCSSTheme.warningOrange, WidgetCSSTheme.dangerRed],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return WidgetCSSTheme.heroGradient
        }
    }
    
    // Icon nhỏ minh họa trạng thái trực quan
    private var statusSymbolName: String {
        if isExpired {
            return "exclamationmark.triangle.fill"
        } else if fractionComplete <= 0.25 {
            return "clock.badge.exclamationmark.fill"
        } else {
            return "bolt.shield.fill"
        }
    }
        
    @ViewBuilder
    private func progressRing(progress: CGFloat, isTrack: Bool) -> some View
    {
        let strokeStyle = StrokeStyle(lineWidth: self.strokeWidth, lineCap: .round, lineJoin: .round)
        
        if isTrack {
            Capsule(style: .continuous)
                .stroke(WidgetCSSTheme.border, style: strokeStyle)
        } else {
            Capsule(style: .continuous)
                .trim(from: 0.0, to: max(progress, 0.03))
                .stroke(statusRingGradient, style: strokeStyle)
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: statusSymbolName)
                .font(.system(size: 10.5, weight: .heavy))
                .foregroundColor(statusAccentColor)
            
            Text(remainingTimeText)
                .font((font ?? .system(size: 13.5, weight: .heavy, design: .rounded)).monospacedDigit())
                .fontWeight(.heavy)
                .foregroundStyle(statusRingGradient)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .opacity(endDate != nil ? 1 : 0)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(
            ZStack {
                // Lớp nền thẻ trắng đặc 100% chuẩn CSS Card (Chặn hoàn toàn nền đen của Dark Mode)
                Capsule(style: .continuous)
                    .fill(WidgetCSSTheme.cardBackground)
                
                // Lớp phủ màu siêu nhẹ tạo chiều sâu hiện đại
                Capsule(style: .continuous)
                    .fill(statusRingGradient.opacity(0.08))
            }
        )
        .overlay(
            ZStack {
                // Đường ray nền xám sáng mảnh (#dae0e9)
                progressRing(progress: 1.0, isTrack: true)
                
                // Thanh tiến trình Gradient Xanh -> Tím (hoặc Cam/Đỏ khi sắp hết hạn)
                progressRing(progress: fractionComplete, isTrack: false)
            }
        )
        .shadow(color: statusAccentColor.opacity(0.18), radius: 5, x: 0, y: 2)
        // Khóa cứng giao diện Sáng (Light Mode) bất kể cài đặt hệ thống
        .environment(\.colorScheme, .light)
        .preferredColorScheme(.light)
    }
}

struct Countdown_Previews: PreviewProvider {
    static var previews: some View {
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        Group {
            // Kiểm tra hiển thị khi hệ thống bật Dark Mode -> Vẫn giữ nguyên giao diện Sáng
            Countdown(startDate: startDate, endDate: Calendar.current.date(byAdding: .hour, value: 160, to: startDate))
                .padding()
                .widgetCSSPageBackground()
                .environment(\.colorScheme, .dark)
            
            // Trạng thái sắp hết hạn
            Countdown(startDate: startDate, endDate: Calendar.current.date(byAdding: .hour, value: 18, to: Date()))
                .padding()
                .widgetCSSPageBackground()
                .environment(\.colorScheme, .dark)
        }
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
