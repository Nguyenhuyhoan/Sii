//
//  ActiveAppsWidget.swift
//  AltWidgetExtension
//
//  Created by Riley Testut on 8/16/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

import SwiftUI
import WidgetKit
import GameplayKit

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME SÁNG (ĐỒNG BỘ VỚI SETTINGS TAB)
private enum WidgetCSSTheme
{
    static let primary = Color(red: 0/255, green: 123/255, blue: 255/255)          // #007bff
    static let secondary = Color(red: 111/255, green: 66/255, blue: 193/255)       // #6f42c1
    static let green = Color(red: 40/255, green: 167/255, blue: 69/255)            // #28a745
    static let orange = Color(red: 245/255, green: 130/255, blue: 32/255)          // #f58220
    static let red = Color(red: 220/255, green: 53/255, blue: 69/255)              // #dc3545
    static let pureBlack = Color.black
    static let subtitleText = Color(red: 82/255, green: 90/255, blue: 101/255)
    static let cardBackground = Color.white
    static let cardBorder = Color(red: 218/255, green: 224/255, blue: 233/255)     // #dae0e9

    // Nền Gradient Sáng cố định (#f3e0ff -> #e0f7ff)
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

    // Hero Gradient cho biểu tượng Placeholder
    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0/255, green: 123/255, blue: 255/255),
                Color(red: 111/255, green: 66/255, blue: 193/255)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct WidgetTag: WidgetInfo{
    let ID: Int?
}

//@available(iOS 17, *)
struct ActiveAppsWidget: Widget
{
    struct Constants{
        static let MAX_ROWS_PER_PAGE: UInt = 3
    }
    
    private static var id: Int = 1
    private let widgetKind: String
    
    init(){
        widgetKind = "ActiveApps - \(Self.id)"
        Self.id += 1
        debugLog("[ActiveAppsWidget] Initialized instance with widgetKind: \(widgetKind)")
    }
    
    public var body: some WidgetConfiguration {
        
        if #available(iOS 17, *)
        {

            let widgetConfig = AppIntentConfiguration(
                kind: widgetKind,
                intent: WidgetUpdateIntent.self,
                provider: ActiveAppsTimelineProvider<WidgetTag>(widgetKind: widgetKind)
            ) { entry in
                ActiveAppsWidgetView(entry: entry, widgetKind: widgetKind)
            }
            .supportedFamilies([.systemMedium])
            .configurationDisplayName("Active Apps")
            .description("View remaining days until your active apps expire. Tap the countdown timers to refresh them in the background.")
            
            return widgetConfig
        }
        else
        {
            return StaticConfiguration(kind: widgetKind, provider: UnsupportedTimelineProvider()) { _ in
                UnsupportedWidgetView(requiredVersion: "iOS 17")
            }
            .supportedFamilies([.systemMedium])
            .configurationDisplayName("Active Apps")
            .description("Requires iOS 17 or later.")
        }
    }
}

@available(iOS 17, *)
private struct ActiveAppsWidgetView: View
{
    var entry: AppsEntry<WidgetInfo>
    var widgetKind: String

    @Environment(\.widgetRenderingMode)
    private var renderingMode
        
    var body: some View {
        Group {
            if entry.apps.isEmpty
            {
                placeholder
            }
            else
            {
                content
            }
        }
        // Khóa cứng giao diện Sáng (Light Mode Only) như tab Cài đặt
        .environment(\.colorScheme, .light)
        .foregroundStyle(WidgetCSSTheme.pureBlack)
        .containerBackground(for: .widget) {
            if renderingMode == .accented
            {
                Color.black
            }
            else
            {
                WidgetCSSTheme.pageGradient
            }
        }
    }
    
    private var content: some View {
        GeometryReader { (geometry) in
            HStack(alignment: .center, spacing: 8) {
                
                let itemsPerPage = ActiveAppsWidget.Constants.MAX_ROWS_PER_PAGE
                let totalVerticalSpacing: CGFloat = 12.0
                let calculatedRowHeight = (geometry.size.height - totalVerticalSpacing) / Double(itemsPerPage)
                let rowHeight = max(36.0, min(calculatedRowHeight, 44.0))

                LazyVStack(spacing: 6) {
                    // Duyệt theo Identifiable của AppSnapshot thay vì index offset để không bao giờ nhầm Icon
                    ForEach(entry.apps) { app in
                    
                        let icon: UIImage = app.icon ?? UIImage(named: "SideStore") ?? UIImage(systemName: "app.fill")!
                        
                        // 1024x1024 images are not supported by previews but supported by device
                        // so we scale the image to 97% so as to reduce its actual size but not too much
                        // to somewhere below value, acceptable by previews ie < 1042x948
                        let scalingFactor = 0.97
                        
                        let resizedSize = CGSize(
                            width:  icon.size.width * scalingFactor,
                            height: icon.size.height * scalingFactor
                        )
                        
                        let resizedIcon = icon.resizing(to: resizedSize) ?? icon
                        let iconSize = max(26.0, rowHeight - 10.0)
                        let iconCornerRadius = iconSize * 0.24
                        let daysRemaining = app.expirationDate.numberOfCalendarDays(since: entry.date)
                        let isExpired = entry.date > app.expirationDate
                        let statusColor: Color = isExpired
                            ? WidgetCSSTheme.red
                            : (daysRemaining <= 2 ? WidgetCSSTheme.orange : WidgetCSSTheme.green)

                        HStack(spacing: 10) {
                            Image(uiImage: resizedIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: iconSize, height: iconSize)
                                .luminanceToAlphaInAccentedMode()
                                .clipShape(RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: iconCornerRadius, style: .continuous)
                                        .stroke(WidgetCSSTheme.cardBorder.opacity(0.85), lineWidth: 0.8)
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
                                .widgetAccentableIfAvailable()
                            
                            VStack(alignment: .leading, spacing: 1.5) {
                                Text(app.name)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(WidgetCSSTheme.pureBlack)
                                    .lineLimit(1)
                                
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(statusColor)
                                        .frame(width: 5.5, height: 5.5)

                                    let text = if isExpired
                                    {
                                        Text("Expired")
                                    }
                                    else
                                    {
                                        Text("Expires in \(daysRemaining) ") + (daysRemaining == 1 ? Text("day") : Text("days"))
                                    }
                                    
                                    text
                                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                        .foregroundStyle(isExpired ? WidgetCSSTheme.red : WidgetCSSTheme.subtitleText)
                                        .lineLimit(1)
                                }
                            }
                            .widgetAccentableIfAvailable()
                            
                            Spacer(minLength: 4)
                            
                            Countdown(startDate: app.refreshedDate,
                                      endDate: app.expirationDate,
                                      currentDate: entry.date,
                                      strokeWidth: 2.8)
                            .foregroundStyle(isExpired ? WidgetCSSTheme.red : WidgetCSSTheme.primary)
                            .background {
                                WidgetCSSTheme.primary.opacity(0.10)
                                    .mask(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(WidgetCSSTheme.primary.opacity(0.22), lineWidth: 0.8)
                                    )
                                    .padding(.all, -4)
                            }
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .activatesRefreshAllAppsIntent()
                            .invalidatableContent()
                            .widgetAccentableIfAvailable()
                        }
                        .padding(.horizontal, 10)
                        .frame(height: rowHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(renderingMode == .accented ? Color.white.opacity(0.12) : WidgetCSSTheme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(WidgetCSSTheme.cardBorder, lineWidth: 1.0)
                        )
                        .shadow(color: WidgetCSSTheme.primary.opacity(0.07), radius: 5, x: 0, y: 2)
                    }
                }
                
                let widgetID = entry.context?.ID
                
                VStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(WidgetCSSTheme.cardBackground)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(WidgetCSSTheme.cardBorder, lineWidth: 1.0)
                            )
                            .shadow(color: WidgetCSSTheme.primary.opacity(0.10), radius: 3, x: 0, y: 1)

                        Image(systemName: "chevron.up")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(WidgetCSSTheme.primary)
                    }
                    .pageUpButton(widgetID, widgetKind)
                    
                    Spacer(minLength: 4)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(WidgetCSSTheme.primary.opacity(0.25))
                        .frame(width: 4, height: 14)

                    Spacer(minLength: 4)
                    
                    ZStack {
                        Circle()
                            .fill(WidgetCSSTheme.cardBackground)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(WidgetCSSTheme.cardBorder, lineWidth: 1.0)
                            )
                            .shadow(color: WidgetCSSTheme.primary.opacity(0.10), radius: 3, x: 0, y: 1)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(WidgetCSSTheme.primary)
                    }
                    .pageDownButton(widgetID, widgetKind)
                }
                .padding(.vertical, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                debugLog("[ActiveAppsWidgetView] onAppear: isPlaceholder=\(entry.isPlaceholder), appsCount=\(entry.apps.count), date=\(entry.date)")
            }
        }
    }
    
    private var placeholder: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(WidgetCSSTheme.heroGradient)
                    .frame(width: 38, height: 38)
                    .shadow(color: WidgetCSSTheme.primary.opacity(0.25), radius: 6, x: 0, y: 3)

                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Color.white)
            }

            Text("Open SideStore")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(WidgetCSSTheme.primary)

            Text("Launch app to update widget")
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .foregroundStyle(WidgetCSSTheme.subtitleText)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(WidgetCSSTheme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(WidgetCSSTheme.cardBorder, lineWidth: 1.0)
        )
        .shadow(color: WidgetCSSTheme.primary.opacity(0.08), radius: 8, x: 0, y: 4)
        .unredacted()
    }
}

@available(iOS 17, *)
#Preview(as: .systemMedium) {
    return ActiveAppsWidget()
} timeline: {
    let expiredDate = Date().addingTimeInterval(1 * 60 * 60 * 24 * 7)
    let (altstore, delta, clip, longAltStore, longDelta, longClip) = AppSnapshot.makePreviewSnapshots()
    
    AppsEntry<Void>(date: Date(), apps: [altstore, delta, clip])
    AppsEntry<Void>(date: Date(), apps: [longAltStore, longDelta, longClip])
    
    AppsEntry<Void>(date: expiredDate, apps: [altstore, delta, clip])
    
    AppsEntry<Void>(date: Date(), apps: [altstore, delta])
    AppsEntry<Void>(date: Date(), apps: [altstore])
    
    AppsEntry<Void>(date: Date(), apps: [])
    AppsEntry<Void>(date: Date(), apps: [], isPlaceholder: true)
}
