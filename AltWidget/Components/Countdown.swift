//
//  Countdown.swift
//  AltWidgetExtension
//
//  Created by Riley Testut on 8/18/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import WidgetKit
import SwiftUI

import AltStoreCore

private enum WidgetCSSTheme {
    static let darkBgTop = Color(red: 11/255, green: 15/255, blue: 25/255)
    static let darkBgBottom = Color(red: 18/255, green: 25/255, blue: 43/255)
    static let cardSurface = Color(red: 30/255, green: 41/255, blue: 59/255).opacity(0.72)
    static let glassBorder = Color.white.opacity(0.10)
    static let textMain = Color(red: 248/255, green: 250/255, blue: 252/255)
    static let textMuted = Color(red: 148/255, green: 163/255, blue: 184/255)
    static let accentCyan = Color(red: 56/255, green: 189/255, blue: 248/255)
    static let accentIndigo = Color(red: 129/255, green: 140/255, blue: 248/255)
    static let accentSuccess = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let accentWarning = Color(red: 251/255, green: 191/255, blue: 36/255)
    static let accentDanger = Color(red: 248/255, green: 113/255, blue: 113/255)
    
    static func statusColor(for days: Int) -> Color {
        if days <= 1 {
            return accentDanger
        } else if days <= 3 {
            return accentWarning
        } else {
            return accentSuccess
        }
    }
}

struct WidgetBackgroundModifier: ViewModifier {
    var backgroundView: AnyView

    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .containerBackground(for: .widget) {
                    backgroundView
                }
        } else {
            content
                .background(backgroundView)
        }
    }
}

extension View {
    func widgetBackground(_ backgroundView: some View) -> some View {
        modifier(WidgetBackgroundModifier(backgroundView: AnyView(backgroundView)))
    }
}

// MARK: - App Icon View Helper (Prevents Icon Reuse Bugs)
private struct WidgetAppIconView: View {
    let app: AppSnapshot
    let size: CGFloat
    let cornerRadius: CGFloat
    
    var body: some View {
        Group {
            if let uiImage = app.appIcon {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fill)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(WidgetCSSTheme.cardSurface)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: size * 0.45, weight: .semibold))
                            .foregroundColor(WidgetCSSTheme.accentCyan)
                    )
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(WidgetCSSTheme.glassBorder, lineWidth: 0.8)
        )
        .id(app.id) // Force SwiftUI to bind texture strictly to bundleIdentifier
    }
}

// MARK: - Small Widget View (Single Selected App or Top App)
struct SmallAppCycleWidgetView: View {
    var entry: AppsEntry
    
    private var activeApps: [AppSnapshot] {
        if !entry.activeApps.isEmpty {
            return entry.activeApps
        }
        let fallbackID = entry.appName ?? StoreApp.altstoreAppID
        return [
            AppSnapshot(
                id: fallbackID,
                name: entry.appName ?? "SideStore",
                bundleIdentifier: fallbackID,
                refreshedDate: entry.refreshedDate,
                expirationDate: entry.expirationDate,
                appIcon: entry.appIcon
            )
        ]
    }
    
    private var featuredApp: AppSnapshot {
        // Prioritize the app matching entry.appName if selected in widget intent
        if let name = entry.appName, let matched = activeApps.first(where: { $0.name == name }) {
            return matched
        }
        return activeApps[0]
    }
    
    private func remainingDays(for app: AppSnapshot) -> Int {
        max(app.expirationDate.numberOfCalendarDays(since: entry.date), 0)
    }
    
    private func progressRatio(for app: AppSnapshot) -> CGFloat {
        let total = max(app.expirationDate.timeIntervalSince(app.refreshedDate), 1)
        let remaining = max(app.expirationDate.timeIntervalSince(entry.date), 0)
        return CGFloat(min(max(remaining / total, 0), 1))
    }
    
    var body: some View {
        let app = featuredApp
        let days = remainingDays(for: app)
        let ratio = progressRatio(for: app)
        let statusColor = WidgetCSSTheme.statusColor(for: days)
        let displayedApps = Array(activeApps.prefix(4))
        
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: App Icon + QuickRefresh Action + Remaining Badge
            HStack(alignment: .center, spacing: 8) {
                WidgetAppIconView(app: app, size: 38, cornerRadius: 10)
                
                Spacer(minLength: 2)
                
                if let refreshURL = URL(string: "sidestore://refresh-all") {
                    Link(destination: refreshURL) {
                        ZStack {
                            Circle()
                                .fill(WidgetCSSTheme.accentCyan.opacity(0.16))
                                .frame(width: 28, height: 28)
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(WidgetCSSTheme.accentCyan)
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // App Name
            Text(app.name)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(WidgetCSSTheme.textMain)
                .lineLimit(1)
                .id("title_\(app.id)")
            
            // Days Left & Progress Bar
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(days)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(statusColor)
                    Text("ngày còn lại")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(WidgetCSSTheme.textMuted)
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.10))
                            .frame(height: 5)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [statusColor, WidgetCSSTheme.accentCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(geo.size.width * ratio, 6), height: 5)
                    }
                }
                .frame(height: 5)
            }
            
            // Mini Dock of Active Apps (Strictly keyed by app.id)
            if displayedApps.count > 1 {
                HStack(spacing: 5) {
                    ForEach(displayedApps, id: \.id) { item in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(WidgetCSSTheme.statusColor(for: remainingDays(for: item)))
                                .frame(width: 5, height: 5)
                            Text("\(remainingDays(for: item))d")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(item.id == app.id ? WidgetCSSTheme.textMain : WidgetCSSTheme.textMuted)
                        }
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(item.id == app.id ? Color.white.opacity(0.14) : Color.white.opacity(0.05))
                        )
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(13)
        .widgetBackground(
            LinearGradient(
                colors: [WidgetCSSTheme.darkBgTop, WidgetCSSTheme.darkBgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

// MARK: - Medium Widget View (Multi-App Status Dashboard)
struct MediumAppListWidgetView: View {
    var entry: AppsEntry
    
    private var activeApps: [AppSnapshot] {
        if !entry.activeApps.isEmpty {
            return entry.activeApps
        }
        let fallbackID = entry.appName ?? StoreApp.altstoreAppID
        return [
            AppSnapshot(
                id: fallbackID,
                name: entry.appName ?? "SideStore",
                bundleIdentifier: fallbackID,
                refreshedDate: entry.refreshedDate,
                expirationDate: entry.expirationDate,
                appIcon: entry.appIcon
            )
        ]
    }
    
    private func remainingDays(for app: AppSnapshot) -> Int {
        max(app.expirationDate.numberOfCalendarDays(since: entry.date), 0)
    }
    
    private func progressRatio(for app: AppSnapshot) -> CGFloat {
        let total = max(app.expirationDate.timeIntervalSince(app.refreshedDate), 1)
        let remaining = max(app.expirationDate.timeIntervalSince(entry.date), 0)
        return CGFloat(min(max(remaining / total, 0), 1))
    }
    
    var body: some View {
        let displayedApps = Array(activeApps.prefix(4))
        
        VStack(alignment: .leading, spacing: 10) {
            // Header Bar
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(WidgetCSSTheme.accentCyan)
                        .frame(width: 7, height: 7)
                    Text("TRẠNG THÁI CHỨNG CHỈ")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundColor(WidgetCSSTheme.textMuted)
                }
                
                Spacer()
                
                if let refreshURL = URL(string: "sidestore://refresh-all") {
                    Link(destination: refreshURL) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 10, weight: .bold))
                            Text("Gia hạn tất cả")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color(red: 15/255, green: 23/255, blue: 42/255))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [WidgetCSSTheme.accentCyan, WidgetCSSTheme.accentIndigo],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                }
            }
            
            // Grid of up to 4 Active Apps (Strictly keyed by app.id)
            let columns = [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ]
            
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(displayedApps, id: \.id) { app in
                    let days = remainingDays(for: app)
                    let ratio = progressRatio(for: app)
                    let statusColor = WidgetCSSTheme.statusColor(for: days)
                    
                    HStack(spacing: 8) {
                        // App Icon strictly bound to app.id
                        WidgetAppIconView(app: app, size: 34, cornerRadius: 8)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(app.name)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(WidgetCSSTheme.textMain)
                                    .lineLimit(1)
                                
                                Spacer(minLength: 2)
                                
                                Text("\(days)d")
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundColor(statusColor)
                            }
                            
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(statusColor)
                                        .frame(width: max(geo.size.width * ratio, 4), height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(WidgetCSSTheme.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(WidgetCSSTheme.glassBorder, lineWidth: 0.8)
                            )
                    )
                    .id("card_\(app.id)")
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(13)
        .widgetBackground(
            LinearGradient(
                colors: [WidgetCSSTheme.darkBgTop, WidgetCSSTheme.darkBgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct CountdownWidgetEntryView: View {
    var entry: AppsTimelineProvider.Entry
    @Environment(\.widgetFamily) private var family
    
    var body: some View {
        switch family {
        case .systemMedium:
            MediumAppListWidgetView(entry: entry)
        default:
            SmallAppCycleWidgetView(entry: entry)
        }
    }
}

struct Countdown: Widget {
    public let kind: String = "Countdown"
    
    public var body: some WidgetConfiguration {
        IntentConfiguration(
            kind: kind,
            intent: SelectAppIntent.self,
            provider: AppsTimelineProvider()
        ) { entry in
            CountdownWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Theo Dõi Thời Hạn")
        .description("Hiển thị số ngày còn lại của các ứng dụng và nút gia hạn nhanh.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabledIfAvailable()
    }
}

extension WidgetConfiguration {
    func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return self.contentMarginsDisabled()
        } else {
            return self
        }
    }
}

struct Countdown_Previews: PreviewProvider {
    static var previews: some View {
        let now = Date()
        let exp = Calendar.current.date(byAdding: .day, value: 6, to: now) ?? now
        let sample = [
            AppSnapshot(id: "com.SideStore.SideStore", name: "SideStore", bundleIdentifier: "com.SideStore.SideStore", refreshedDate: now, expirationDate: exp, appIcon: nil),
            AppSnapshot(id: "com.example.youtube", name: "YouTube", bundleIdentifier: "com.example.youtube", refreshedDate: now, expirationDate: exp, appIcon: nil)
        ]
        Group {
            CountdownWidgetEntryView(entry: AppsEntry(date: now, activeApps: sample))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            CountdownWidgetEntryView(entry: AppsEntry(date: now, activeApps: sample))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}
