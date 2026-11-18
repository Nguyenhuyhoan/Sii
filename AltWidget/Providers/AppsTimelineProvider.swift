
//
//  AppsTimelineProvider.swift
//  AltWidget
//
//  Created by Riley Testut on 9/17/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import WidgetKit
import SwiftUI
import Intents
import CoreData

import AltStoreCore

struct AppSnapshot: Identifiable, Equatable {
    let id: String // Unique bundleIdentifier to prevent SwiftUI ForEach icon mix-ups
    let name: String
    let bundleIdentifier: String
    let refreshedDate: Date
    let expirationDate: Date
    let appIcon: UIImage?
    
    static func == (lhs: AppSnapshot, rhs: AppSnapshot) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.refreshedDate == rhs.refreshedDate &&
               lhs.expirationDate == rhs.expirationDate
    }
}

struct AppsEntry: TimelineEntry {
    public let date: Date
    let refreshedDate: Date
    let expirationDate: Date
    let appName: String?
    let appIcon: UIImage?
    let activeApps: [AppSnapshot]
    
    init(
        date: Date,
        refreshedDate: Date? = nil,
        expirationDate: Date? = nil,
        appName: String? = "SideStore",
        appIcon: UIImage? = nil,
        activeApps: [AppSnapshot] = []
    ) {
        self.date = date
        
        let currentDate = Date()
        self.refreshedDate = refreshedDate ?? currentDate
        self.expirationDate = expirationDate ?? (Calendar.current.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate)
        self.appName = appName
        self.appIcon = appIcon
        self.activeApps = activeApps
    }
}

struct AppsTimelineProvider: IntentTimelineProvider {
    typealias Intent = SelectAppIntent
    public typealias Entry = AppsEntry
    
    private static func loadIsolatedIcon(for app: InstalledApp) -> UIImage? {
        // 1. Read strictly from this app's dedicated folder on disk without UIImage path caching
        let iconURL = InstalledApp.fileURL(for: app).appendingPathComponent("Icon.png")
        if let data = try? Data(contentsOf: iconURL), let image = UIImage(data: data) {
            return image.resizing(toFill: CGSize(width: 90, height: 90)) ?? image
        }
        
        // 2. If this app is SideStore itself and Icon.png isn't on disk, use the bundled SideStore icon
        if app.bundleIdentifier == StoreApp.altstoreAppID, let bundledIcon = UIImage(named: "AppIcon60x60") {
            return bundledIcon.resizing(toFill: CGSize(width: 90, height: 90)) ?? bundledIcon
        }
        
        // 3. Fallback to InstalledApp.icon property
        if let fallbackIcon = app.icon {
            return fallbackIcon.resizing(toFill: CGSize(width: 90, height: 90)) ?? fallbackIcon
        }
        
        return UIImage(named: "AppIcon60x60")
    }
    
    public func snapshot(for configuration: SelectAppIntent, with context: Context, completion: @escaping (AppsEntry) -> ()) {
        let currentDate = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate
        let sampleApps = [
            AppSnapshot(id: StoreApp.altstoreAppID, name: "SideStore", bundleIdentifier: StoreApp.altstoreAppID, refreshedDate: currentDate, expirationDate: nextWeek, appIcon: UIImage(named: "AppIcon60x60"))
        ]
        let entry = AppsEntry(date: currentDate, activeApps: sampleApps)
        completion(entry)
    }
    
    public func timeline(for configuration: SelectAppIntent, with context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        DatabaseManager.shared.start { (error) in
            let currentDate = Date()
            let reloadDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate.addingTimeInterval(1800)
            
            if let error = error {
                print("Failed to start DatabaseManager in Widget:", error)
                let timeline = Timeline(entries: [AppsEntry(date: currentDate)], policy: .after(reloadDate))
                return completion(timeline)
            }
            
            let bgContext = DatabaseManager.shared.persistentContainer.newBackgroundContext()
            bgContext.perform {
                // Reset context to avoid stale cached relationships or faulted properties
                bgContext.reset()
                
                let allActivePredicate = NSPredicate(format: "%K == YES", #keyPath(InstalledApp.isActive))
                // Deterministic sorting: expirationDate -> refreshedDate -> bundleIdentifier
                let sortDescriptors = [
                    NSSortDescriptor(keyPath: \InstalledApp.expirationDate, ascending: true),
                    NSSortDescriptor(keyPath: \InstalledApp.refreshedDate, ascending: true),
                    NSSortDescriptor(keyPath: \InstalledApp.bundleIdentifier, ascending: true)
                ]
                
                let fetchRequest = InstalledApp.fetchRequest() as NSFetchRequest<InstalledApp>
                fetchRequest.predicate = allActivePredicate
                fetchRequest.sortDescriptors = sortDescriptors
                fetchRequest.returnsObjectsAsFaults = false
                
                let fetchedApps = (try? bgContext.fetch(fetchRequest)) ?? []
                
                let snapshots: [AppSnapshot] = fetchedApps.map { app in
                    let bundleID = app.bundleIdentifier
                    let iconImage = Self.loadIsolatedIcon(for: app)
                    return AppSnapshot(
                        id: bundleID,
                        name: app.name,
                        bundleIdentifier: bundleID,
                        refreshedDate: app.refreshedDate,
                        expirationDate: app.expirationDate,
                        appIcon: iconImage
                    )
                }
                
                let selectedBundleID = configuration.app?.identifier ?? StoreApp.altstoreAppID
                let targetSnapshot = snapshots.first(where: { $0.bundleIdentifier == selectedBundleID }) ?? snapshots.first
                
                guard let primaryApp = targetSnapshot else {
                    let timeline = Timeline(entries: [AppsEntry(date: currentDate, activeApps: [])], policy: .after(reloadDate))
                    completion(timeline)
                    return
                }
                
                var entries: [AppsEntry] = []
                
                let remainingHours = Calendar.current.dateComponents([.hour], from: currentDate, to: primaryApp.expirationDate).hour ?? 0
                let totalEntries = max(min(remainingHours, 24), 1)
                
                for hourOffset in 0 ..< totalEntries {
                    guard let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate),
                          entryDate <= primaryApp.expirationDate
                    else { break }
                    
                    let entry = AppsEntry(
                        date: entryDate,
                        refreshedDate: primaryApp.refreshedDate,
                        expirationDate: primaryApp.expirationDate,
                        appName: primaryApp.name,
                        appIcon: primaryApp.appIcon,
                        activeApps: snapshots
                    )
                    entries.append(entry)
                }
                
                if entries.isEmpty {
                    let fallbackEntry = AppsEntry(
                        date: currentDate,
                        refreshedDate: primaryApp.refreshedDate,
                        expirationDate: primaryApp.expirationDate,
                        appName: primaryApp.name,
                        appIcon: primaryApp.appIcon,
                        activeApps: snapshots
                    )
                    entries.append(fallbackEntry)
                }
                
                let timeline = Timeline(entries: entries, policy: .after(reloadDate))
                completion(timeline)
            }
        }
    }
    
    func placeholder(in context: Context) -> AppsEntry {
        let currentDate = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate
        let sampleApps = [
            AppSnapshot(id: StoreApp.altstoreAppID, name: "SideStore", bundleIdentifier: StoreApp.altstoreAppID, refreshedDate: currentDate, expirationDate: nextWeek, appIcon: UIImage(named: "AppIcon60x60"))
        ]
        return AppsEntry(date: currentDate, activeApps: sampleApps)
    }
}
