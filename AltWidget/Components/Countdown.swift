//
//  Countdown.swift
//  AltWidgetExtension
//
//  Created by Riley Testut on 7/6/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import SwiftUI
import WidgetKit

struct Countdown: View
{
    var startDate: Date?
    var endDate: Date?
    var currentDate: Date = Date()
    
    var strokeWidth: Double = 4.0
    
    @Environment(\.font) private var font
    
    private var remainingDaysAndHours: (days: Int, hours: Int) {
        guard let endDate = self.endDate, endDate > self.currentDate else {
            return (0, 0)
        }
        return endDate.remainingDaysAndHours(since: self.currentDate)
    }
    
    // Chuỗi hiển thị Ngày - Giờ
    private var remainingTimeText: String {
        guard let endDate = self.endDate else { return "0d 0h" }
        
        if endDate <= self.currentDate {
            return "Hết hạn"
        }
        
        let remaining = self.remainingDaysAndHours
        return "\(remaining.days)d \(remaining.hours)h"
    }
    
    // Tính thanh tiến trình chính xác theo từng giây
    private var fractionComplete: CGFloat {
        guard let startDate = self.startDate, let endDate = self.endDate else { return 1.0 }
        
        let totalTime = endDate.timeIntervalSince(startDate)
        let remainingTime = endDate.timeIntervalSince(self.currentDate)
        
        guard totalTime > 0 else { return 0.0 }
        
        let fraction = CGFloat(remainingTime / totalTime)
        return min(max(fraction, 0.0), 1.0)
    }
    
    // Màu sắc tự động theo thời hạn còn lại (Xanh ngọc -> Vàng cam -> Đỏ)
    private var statusGradient: LinearGradient {
        let days = self.remainingDaysAndHours.days
        let hours = self.remainingDaysAndHours.hours
        
        if days == 0 && hours == 0 {
            return LinearGradient(
                colors: [Color(red: 248/255, green: 113/255, blue: 113/255), Color(red: 239/255, green: 68/255, blue: 68/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if days <= 1 {
            return LinearGradient(
                colors: [Color(red: 248/255, green: 113/255, blue: 113/255), Color(red: 251/255, green: 146/255, blue: 60/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if days <= 3 {
            return LinearGradient(
                colors: [Color(red: 251/255, green: 191/255, blue: 36/255), Color(red: 56/255, green: 189/255, blue: 248/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(red: 52/255, green: 211/255, blue: 153/255), Color(red: 56/255, green: 189/255, blue: 248/255)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
        
    @ViewBuilder
    private func overlay(progress: CGFloat) -> some View
    {
        let strokeStyle = StrokeStyle(lineWidth: self.strokeWidth, lineCap: .round, lineJoin: .round)
        
        Capsule(style: .continuous)
            .trim(from: 0.0, to: progress)
            .stroke(style: strokeStyle)
    }
    
    var body: some View {
        Text(remainingTimeText)
            .font((font ?? .title3).monospacedDigit())
            .bold()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .opacity(endDate != nil ? 1 : 0)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                ZStack {
                    overlay(progress: 1.0)
                        .opacity(0.22)
                    
                    overlay(progress: fractionComplete)
                        .foregroundStyle(statusGradient)
                }
            )
    }
}

struct Countdown_Previews: PreviewProvider {
    static var previews: some View {
        let startDate = Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        Group {
            Countdown(startDate: startDate, endDate: Calendar.current.date(byAdding: .hour, value: 160, to: startDate))
            Countdown(startDate: startDate, endDate: Calendar.current.date(byAdding: .day, value: 365, to: startDate))
        }
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
