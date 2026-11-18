
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
import UIKit

#if canImport(AltStoreCore)
import AltStoreCore
#endif

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

// MARK: - Self-Contained App Group & CoreData Reader (No AltStoreCore Dependency Needed)
enum WidgetDataReader {
    static var defaultSideStoreBundleID: String {
        if let appBundleID = Bundle.main.object(forInfoDictionaryKey: "ALTAppBundleIdentifier") as? String, !appBundleID.isEmpty {
            return appBundleID
        }
        // Fallback: strip widget extension suffix from bundle identifier
        if let widgetBundleID = Bundle.main.bundleIdentifier {
            let components = widgetBundleID.split(separator: ".")
            if components.count > 1 {
                return components.dropLast().joined(separator: ".")
            }
        }
        return "com.SideStore.SideStore"
    }
    
    static var sharedAppGroupURL: URL? {
        if let groupID = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? String,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) {
            return url
        }
        if let groups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String],
           let firstGroup = groups.first,
           let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: firstGroup) {
            return url
        }
        return nil
    }
    
    static func resizeImage(_ image: UIImage, targetSize: CGSize = CGSize(width: 90, height: 90)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1.0
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    static func loadIsolatedIcon(for bundleIdentifier: String, containerURL: URL?) -> UIImage? {
        // 1. Read strictly from Apps/<bundleIdentifier>/Icon.png inside Shared App Group
        if let baseURL = containerURL {
            let candidatePaths = [
                baseURL.appendingPathComponent("Apps", isDirectory: true)
                       .appendingPathComponent(bundleIdentifier, isDirectory: true)
                       .appendingPathComponent("Icon.png"),
                baseURL.appendingPathComponent("Application Support/Apps", isDirectory: true)
                       .appendingPathComponent(bundleIdentifier, isDirectory: true)
                       .appendingPathComponent("Icon.png")
            ]
            
            for iconURL in candidatePaths {
                if let data = try? Data(contentsOf: iconURL), let rawImage = UIImage(data: data) {
                    return resizeImage(rawImage)
                }
            }
        }
        
        // 2. If this app is SideStore itself, use bundled icon
        if bundleIdentifier == defaultSideStoreBundleID, let bundled = UIImage(named: "AppIcon60x60") {
            return resizeImage(bundled)
        }
        
        return nil
    }
    
    static func fetchActiveAppsFromDisk() -> [AppSnapshot] {
        guard let containerURL = sharedAppGroupURL else { return [] }
        
        // Find CoreData model (.momd) inside main app or widget bundle
        let modelURL: URL? = Bundle.main.url(forResource: "AltStore", withExtension: "momd") ?? {
            let appBundleURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()
            return Bundle(url: appBundleURL)?.url(forResource: "AltStore", withExtension: "momd")
        }()
        
        guard let validModelURL = modelURL,
              let managedObjectModel = NSManagedObjectModel(contentsOf: validModelURL) else {
            return []
        }
        
        let possibleStoreURLs = [
            containerURL.appendingPathComponent("AltStore.sqlite"),
            containerURL.appendingPathComponent("Database/AltStore.sqlite"),
            containerURL.appendingPathComponent("Library/Application Support/AltStore.sqlite"),
            containerURL.appendingPathComponent("Application Support/AltStore.sqlite")
        ]
        
        guard let storeURL = possibleStoreURLs.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return []
        }
        
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
        let options: [AnyHashable: Any] = [
            NSReadOnlyPersistentStoreOption: true,
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true
        ]
        
        guard (try? coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeURL, options: options)) != nil else {
            return []
        }
        
        let context = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        
        var results: [AppSnapshot] = []
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "InstalledApp")
            request.predicate = NSPredicate(format: "isActive == YES")
            request.sortDescriptors = [
                NSSortDescriptor(key: "expirationDate", ascending: true),
                NSSortDescriptor(key: "refreshedDate", ascending: true),
                NSSortDescriptor(key: "bundleIdentifier", ascending: true)
            ]
            request.returnsObjectsAsFaults = false
            
            guard let objects = try? context.fetch(request) else { return }
            
            for obj in objects {
                guard let bundleID = obj.value(forKey: "bundleIdentifier") as? String,
                      let name = obj.value(forKey: "name") as? String,
                      let refreshedDate = obj.value(forKey: "refreshedDate") as? Date,
                      let expirationDate = obj.value(forKey: "expirationDate") as? Date else {
                    continue
                }
                
                let iconImage = loadIsolatedIcon(for: bundleID, containerURL: containerURL)
                results.append(
                    AppSnapshot(
                        id: bundleID,
                        name: name,
                        bundleIdentifier: bundleID,
                        refreshedDate: refreshedDate,
                        expirationDate: expirationDate,
                        appIcon: iconImage
                    )
                )
            }
        }
        
        return results
    }
}

struct AppsTimelineProvider: IntentTimelineProvider {
    typealias Intent = SelectAppIntent
    public typealias Entry = AppsEntry
    
    public func snapshot(for configuration: SelectAppIntent, with context: Context, completion: @escaping (AppsEntry) -> ()) {
        let currentDate = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate
        let defaultID = WidgetDataReader.defaultSideStoreBundleID
        let sampleApps = [
            AppSnapshot(
                id: defaultID,
                name: "SideStore",
                bundleIdentifier: defaultID,
                refreshedDate: currentDate,
                expirationDate: nextWeek,
                appIcon: UIImage(named: "AppIcon60x60")
            )
        ]
        let entry = AppsEntry(date: currentDate, activeApps: sampleApps)
        completion(entry)
    }
    
    public func timeline(for configuration: SelectAppIntent, with context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        DispatchQueue.global(qos: .userInitiated).async {
            let currentDate = Date()
            let reloadDate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate.addingTimeInterval(1800)
            
            let snapshots = WidgetDataReader.fetchActiveAppsFromDisk()
            let defaultID = WidgetDataReader.defaultSideStoreBundleID
            let selectedBundleID = configuration.app?.identifier ?? defaultID
            
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
    
    func placeholder(in context: Context) -> AppsEntry {
        let currentDate = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: currentDate) ?? currentDate
        let defaultID = WidgetDataReader.defaultSideStoreBundleID
        let sampleApps = [
            AppSnapshot(
                id: defaultID,
                name: "SideStore",
                bundleIdentifier: defaultID,
                refreshedDate: currentDate,
                expirationDate: nextWeek,
                appIcon: UIImage(named: "AppIcon60x60")
            )
        ]
        return AppsEntry(date: currentDate, activeApps: sampleApps)
    }
}
