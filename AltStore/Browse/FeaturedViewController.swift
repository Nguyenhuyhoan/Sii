
//
//  FeaturedViewController.swift
//  AltStore
//
//  Created by Riley Testut on 11/8/23.
//  Copyright © 2023 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import CoreData
@preconcurrency import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% VỚI SETTINGS & MY APPS)
private struct FeaturedCSSTheme {
    static let primary = UIColor(red: 44/255, green: 62/255, blue: 80/255, alpha: 1.0)      // #2c3e50
    static let secondary = UIColor(red: 52/255, green: 73/255, blue: 94/255, alpha: 1.0)    // #34495e
    static let white = UIColor.white                                                        // #ffffff
    static let pureBlack = UIColor.black                                                    // #000000
    static let darkGray = UIColor(red: 55/255, green: 65/255, blue: 81/255, alpha: 1.0)     // #374151
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)     // #f5f8ff
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)    // #dce2ec
    static let cardBorder = UIColor(red: 230/255, green: 235/255, blue: 242/255, alpha: 1.0)// #e6ebf2
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0)// #dee5f0
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)        // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)     // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)       // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)         // #dc3545
    static let infoBg = UIColor(red: 238/255, green: 245/255, blue: 255/255, alpha: 1.0)    // #eef5ff
    static let purplePillBg = UIColor(red: 243/255, green: 232/255, blue: 255/255, alpha: 1.0)

    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.92).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.90).cgColor
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH CHUẨN CSS
private final class FeaturedGradientBackgroundView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }

    private func setupGradient() {
        guard let gradientLayer = self.layer as? CAGradientLayer else { return }
        gradientLayer.colors = [FeaturedCSSTheme.bgGradientStart, FeaturedCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 📦 CẤU TRÚC DỮ LIỆU NGUỒN & ỨNG DỤNG ĐA NĂNG (SENDABLE AN TOÀN)
private struct FeaturedRepoSource: Codable, Equatable, Sendable {
    let urlString: String
    var displayName: String
    var subtitle: String
    var iconURLString: String?
    var isEnabledInAllTab: Bool
    var isBuiltIn: Bool

    var normalizedID: String {
        Self.cleanURLString(urlString).lowercased()
    }

    static func cleanURLString(_ raw: String) -> String {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let invisibleChars: [Character] = ["\u{2060}", "\u{fffc}", "\u{200b}", "\u{200c}", "\u{200d}", "\u{feff}"]
        cleaned.removeAll { invisibleChars.contains($0) }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct FeaturedAppItem: Equatable, Sendable {
    let uniqueKey: String
    let name: String
    let bundleIdentifier: String
    let developerName: String
    let version: String
    let versionDateString: String
    let downloadURL: URL
    let iconURL: URL?
    let sizeBytes: Int64
    let subtitle: String
    let localizedDescription: String
    let sourceName: String
    let sourceURLString: String
    let tintHex: String?

    var formattedSize: String {
        guard sizeBytes > 0 else { return "IPA" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: sizeBytes)
    }

    var safeFileName: String {
        let rawName = "\(name)_\(version)_\(bundleIdentifier)"
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let sanitized = rawName.components(separatedBy: allowed.inverted).joined(separator: "_")
        let trimmed = String(sanitized.prefix(90))
        return trimmed.isEmpty ? "App_\(abs(uniqueKey.hashValue)).ipa" : "\(trimmed).ipa"
    }
}

private struct FeaturedDownloadedIPAEntry: Codable, Equatable, Sendable {
    let fileName: String
    let appName: String
    let bundleIdentifier: String
    let version: String
    let sourceName: String
    let downloadURLString: String
    let fileSize: Int64
    let downloadedDate: Date
    let iconURLString: String?

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(fileSize, 1024))
    }
}

// MARK: - 🧠 BỘ GIẢI MÃ ĐA NĂNG (UNIVERSAL JSON PARSER CHO MỌI CHUẨN REPO JSON)
private enum FeaturedUniversalRepoParser {
    static func parse(data: Data, fallbackSource: FeaturedRepoSource) -> (repoName: String, repoIcon: String?, apps: [FeaturedAppItem]) {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]),
              let rootDict = jsonObject as? [String: Any] else {
            return (fallbackSource.displayName, fallbackSource.iconURLString, [])
        }

        let metaDict = rootDict["META"] as? [String: Any]
        let rawRepoName = (rootDict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (metaDict?["repoName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? (rootDict["identifier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? fallbackSource.displayName
        let repoName = rawRepoName.isEmpty ? fallbackSource.displayName : rawRepoName

        let repoIcon = Self.cleanLink(rootDict["iconURL"] as? String)
            ?? Self.cleanLink(metaDict?["repoIcon"] as? String)
            ?? Self.cleanLink(rootDict["icon"] as? String)
            ?? Self.cleanLink(rootDict["headerURL"] as? String)
            ?? fallbackSource.iconURLString

        let repoTint = rootDict["tintColor"] as? String

        guard let rawApps = rootDict["apps"] as? [[String: Any]] else {
            return (repoName, repoIcon, [])
        }

        var parsedApps: [FeaturedAppItem] = []
        parsedApps.reserveCapacity(min(rawApps.count, 1200))

        for (idx, dict) in rawApps.enumerated() {
            let versionsArray = dict["versions"] as? [[String: Any]]
            let latestVersionDict = versionsArray?.first

            let rawDownloadURL = Self.cleanLink(dict["downloadURL"] as? String)
                ?? Self.cleanLink(latestVersionDict?["downloadURL"] as? String)
                ?? Self.cleanLink(dict["down"] as? String)
                ?? Self.cleanLink(latestVersionDict?["down"] as? String)
                ?? Self.cleanLink(dict["url"] as? String)

            guard let downloadStr = rawDownloadURL, let downloadURL = Self.makeSafeURL(from: downloadStr) else {
                continue
            }

            let rawBundleID = (dict["bundleIdentifier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["bundleID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["appID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            let bundleID = rawBundleID.isEmpty ? "app.sidestore.item.\(idx)" : rawBundleID

            var appName = (dict["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if appName.isEmpty {
                let lastComponent = downloadURL.deletingPathExtension().lastPathComponent.removingPercentEncoding ?? ""
                let cleanedComponent = lastComponent
                    .replacingOccurrences(of: "_", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanedComponent.isEmpty {
                    appName = cleanedComponent
                } else {
                    appName = bundleID.components(separatedBy: ".").last ?? bundleID
                }
            }

            let version = (dict["version"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (latestVersionDict?["version"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["absoluteVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (latestVersionDict?["absoluteVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "1.0"

            let dateStr = (dict["versionDate"] as? String)
                ?? (latestVersionDict?["date"] as? String)
                ?? (dict["fullDate"] as? String)
                ?? (dict["date"] as? String)
                ?? ""

            let sizeBytes: Int64 = Self.parseInt64(dict["size"])
                ?? Self.parseInt64(latestVersionDict?["size"])
                ?? 0

            let rawIcon = Self.cleanLink(dict["iconURL"] as? String)
                ?? Self.cleanLink(dict["icon"] as? String)
                ?? repoIcon
            let iconURL = rawIcon != nil ? Self.makeSafeURL(from: rawIcon!) : nil

            let devNameRaw = (dict["developerName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["author"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            let developerName = devNameRaw.isEmpty ? repoName : devNameRaw

            let subtitle = (dict["subtitle"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let desc = (dict["localizedDescription"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (latestVersionDict?["localizedDescription"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["versionDescription"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? subtitle

            let tintHex = (dict["tintColor"] as? String) ?? repoTint
            let uniqueKey = "\(fallbackSource.normalizedID)|\(bundleID)|\(version)|\(downloadURL.absoluteString)"

            let item = FeaturedAppItem(
                uniqueKey: uniqueKey,
                name: appName,
                bundleIdentifier: bundleID,
                developerName: developerName,
                version: version,
                versionDateString: dateStr,
                downloadURL: downloadURL,
                iconURL: iconURL,
                sizeBytes: sizeBytes,
                subtitle: subtitle,
                localizedDescription: desc,
                sourceName: repoName,
                sourceURLString: fallbackSource.urlString,
                tintHex: tintHex
            )
            parsedApps.append(item)
        }

        return (repoName, repoIcon, parsedApps)
    }

    private static func cleanLink(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        return FeaturedRepoSource.cleanURLString(raw.replacingOccurrences(of: "\\/", with: "/"))
    }

    private static func makeSafeURL(from raw: String) -> URL? {
        if let url = URL(string: raw) { return url }
        if let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: encoded) {
            return url
        }
        return nil
    }

    private static func parseInt64(_ anyVal: Any?) -> Int64? {
        if let int64Val = anyVal as? Int64 { return int64Val }
        if let intVal = anyVal as? Int { return Int64(intVal) }
        if let numVal = anyVal as? NSNumber { return numVal.int64Value }
        if let strVal = anyVal as? String, let parsed = Int64(strVal.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }
}

// MARK: - 📥 TRÌNH QUẢN LÝ TẢI IPA (% REALTIME) & KHO LƯU TRỮ FILE ĐÃ TẢI
@MainActor
private final class FeaturedIPADownloadCenter: NSObject, URLSessionDownloadDelegate {
    static let shared = FeaturedIPADownloadCenter()

    static let stateDidChangeNotification = Notification.Name("SideStoreFeaturedIPADownloadStateDidChange")
    static let progressDidChangeNotification = Notification.Name("SideStoreFeaturedIPADownloadProgressDidChange")

    struct ActiveDownload {
        let app: FeaturedAppItem
        let task: URLSessionDownloadTask
        var progress: Double
        var receivedBytes: Int64
        var totalBytes: Int64
    }

    private(set) var activeDownloads: [String: ActiveDownload] = [:]
    private var taskKeyMap: [Int: String] = [:]
    private(set) var downloadedEntries: [FeaturedDownloadedIPAEntry] = []

    private let metadataStorageKey = "SideStore_Hub_DownloadedIPAs_v2"
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 3600
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    var downloadsDirectoryURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("DownloadedIPAs", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private override init() {
        super.init()
        reloadDownloadedFiles()
    }

    func reloadDownloadedFiles() {
        let fm = FileManager.default
        let dir = downloadsDirectoryURL
        var savedEntries: [FeaturedDownloadedIPAEntry] = []
        if let data = UserDefaults.standard.data(forKey: metadataStorageKey),
           let decoded = try? JSONDecoder().decode([FeaturedDownloadedIPAEntry].self, from: data) {
            savedEntries = decoded
        }

        var validEntries: [FeaturedDownloadedIPAEntry] = []
        for entry in savedEntries {
            let fileURL = dir.appendingPathComponent(entry.fileName)
            if fm.fileExists(atPath: fileURL.path) {
                validEntries.append(entry)
            }
        }

        if let fileURLs = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .creationDateKey], options: [.skipsHiddenFiles]) {
            for url in fileURLs where url.pathExtension.lowercased() == "ipa" {
                let fileName = url.lastPathComponent
                if !validEntries.contains(where: { $0.fileName == fileName }) {
                    let attrs = try? fm.attributesOfItem(atPath: url.path)
                    let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                    let date = (attrs?[.creationDate] as? Date) ?? Date()
                    let fallbackName = url.deletingPathExtension().lastPathComponent
                    validEntries.append(
                        FeaturedDownloadedIPAEntry(
                            fileName: fileName,
                            appName: fallbackName,
                            bundleIdentifier: "unknown.bundle.id",
                            version: "1.0",
                            sourceName: "File IPA Đã Tải",
                            downloadURLString: fileName,
                            fileSize: size,
                            downloadedDate: date,
                            iconURLString: nil
                        )
                    )
                }
            }
        }

        validEntries.sort { $0.downloadedDate > $1.downloadedDate }
        self.downloadedEntries = validEntries
        saveMetadata()
    }

    private func saveMetadata() {
        if let encoded = try? JSONEncoder().encode(downloadedEntries) {
            UserDefaults.standard.set(encoded, forKey: metadataStorageKey)
        }
    }

    func localFileURL(for app: FeaturedAppItem) -> URL? {
        let key = app.downloadURL.absoluteString
        if let entry = downloadedEntries.first(where: {
            $0.downloadURLString == key ||
            ($0.bundleIdentifier == app.bundleIdentifier && $0.version == app.version && $0.appName == app.name)
        }) {
            let url = downloadsDirectoryURL.appendingPathComponent(entry.fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        let defaultURL = downloadsDirectoryURL.appendingPathComponent(app.safeFileName)
        if FileManager.default.fileExists(atPath: defaultURL.path) {
            return defaultURL
        }
        return nil
    }

    func localFileURL(for entry: FeaturedDownloadedIPAEntry) -> URL {
        downloadsDirectoryURL.appendingPathComponent(entry.fileName)
    }

    func activeProgress(for app: FeaturedAppItem) -> Double? {
        activeDownloads[app.downloadURL.absoluteString]?.progress
    }

    func startDownload(for app: FeaturedAppItem) {
        let key = app.downloadURL.absoluteString
        guard activeDownloads[key] == nil else { return }

        var request = URLRequest(url: app.downloadURL)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")

        let task = urlSession.downloadTask(with: request)
        taskKeyMap[task.taskIdentifier] = key
        activeDownloads[key] = ActiveDownload(
            app: app,
            task: task,
            progress: 0.01,
            receivedBytes: 0,
            totalBytes: max(app.sizeBytes, 0)
        )
        task.resume()

        NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: nil, userInfo: ["key": key])
    }

    func cancelDownload(for app: FeaturedAppItem) {
        let key = app.downloadURL.absoluteString
        guard let active = activeDownloads.removeValue(forKey: key) else { return }
        taskKeyMap.removeValue(forKey: active.task.taskIdentifier)
        active.task.cancel()
        NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: nil, userInfo: ["key": key])
    }

    func deleteDownloadedFile(entry: FeaturedDownloadedIPAEntry) {
        let url = localFileURL(for: entry)
        try? FileManager.default.removeItem(at: url)
        downloadedEntries.removeAll { $0.fileName == entry.fileName }
        saveMetadata()
        NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: nil)
    }

    func deleteAllDownloadedFiles() {
        for entry in downloadedEntries {
            let url = localFileURL(for: entry)
            try? FileManager.default.removeItem(at: url)
        }
        downloadedEntries.removeAll()
        saveMetadata()
        NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: nil)
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let taskID = downloadTask.taskIdentifier
        Task { @MainActor in
            guard let key = self.taskKeyMap[taskID], var active = self.activeDownloads[key] else { return }
            let expected = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : active.app.sizeBytes
            let ratio: Double
            if expected > 0 {
                ratio = min(max(Double(totalBytesWritten) / Double(expected), 0.01), 0.99)
            } else {
                ratio = min(Double(totalBytesWritten) / Double(60 * 1024 * 1024), 0.95)
            }
            active.progress = ratio
            active.receivedBytes = totalBytesWritten
            active.totalBytes = expected
            self.activeDownloads[key] = active

            NotificationCenter.default.post(
                name: Self.progressDidChangeNotification,
                object: nil,
                userInfo: ["key": key, "progress": ratio]
            )
        }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let taskID = downloadTask.taskIdentifier
        let fm = FileManager.default
        let tempSavedURL = fm.temporaryDirectory.appendingPathComponent("sidestore_dl_\(UUID().uuidString).ipa")
        try? fm.removeItem(at: tempSavedURL)
        do {
            try fm.moveItem(at: location, to: tempSavedURL)
        } catch {
            return
        }

        Task { @MainActor in
            guard let key = self.taskKeyMap.removeValue(forKey: taskID),
                  let active = self.activeDownloads.removeValue(forKey: key) else {
                try? fm.removeItem(at: tempSavedURL)
                return
            }

            let app = active.app
            let destinationURL = self.downloadsDirectoryURL.appendingPathComponent(app.safeFileName)
            try? fm.removeItem(at: destinationURL)

            do {
                try fm.moveItem(at: tempSavedURL, to: destinationURL)
                let attrs = try? fm.attributesOfItem(atPath: destinationURL.path)
                let actualSize = (attrs?[.size] as? NSNumber)?.int64Value ?? app.sizeBytes

                let newEntry = FeaturedDownloadedIPAEntry(
                    fileName: app.safeFileName,
                    appName: app.name,
                    bundleIdentifier: app.bundleIdentifier,
                    version: app.version,
                    sourceName: app.sourceName,
                    downloadURLString: key,
                    fileSize: actualSize,
                    downloadedDate: Date(),
                    iconURLString: app.iconURL?.absoluteString
                )

                self.downloadedEntries.removeAll { $0.fileName == newEntry.fileName || $0.downloadURLString == key }
                self.downloadedEntries.insert(newEntry, at: 0)
                self.saveMetadata()

                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                try? fm.removeItem(at: tempSavedURL)
            }

            NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: nil, userInfo: ["key": key])
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let taskID = task.taskIdentifier
        Task { @MainActor in
            guard let key = self.taskKeyMap.removeValue(forKey: taskID) else { return }
            self.activeDownloads.removeValue(forKey: key)
            if (error as NSError).code != NSURLErrorCancelled {
                NotificationCenter.default.post(
                    name: Self.stateDidChangeNotification,
                    object: nil,
                    userInfo: ["key": key, "error": error.localizedDescription]
                )
            } else {
                NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: nil, userInfo: ["key": key])
            }
        }
    }
}

// MARK: - 🗂️ TRÌNH QUẢN LÝ NGUỒN (14 NGUỒN MỚI ĐÃ THAY THẾ HOÀN TOÀN)
@MainActor
private final class FeaturedSmartRepoStoreManager {
    static let shared = FeaturedSmartRepoStoreManager()

    private let sourcesStorageKey = "SideStore_VNSourcesOnly_v6"
    private(set) var sources: [FeaturedRepoSource] = []
    private var memoryCache: [String: [FeaturedAppItem]] = [:]

    static let defaultLightSources: [FeaturedRepoSource] = [
        FeaturedRepoSource(
            urlString: "https://raw.githubusercontent.com/dvntm0/AltStore/main/repo.json",
            displayName: "Kho App & Game (dvntm0)",
            subtitle: "https://raw.githubusercontent.com/dvntm0/AltStore/main/repo.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://community-apps.sidestore.io/sidecommunity.json",
            displayName: "Kho Giả Lập & Công Cụ (SideStore)",
            subtitle: "https://community-apps.sidestore.io/sidecommunity.json",
            iconURLString: "https://sidestore.io/assets/icon.png",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://wuxu1.github.io/wuxu-complete-plus.json",
            displayName: "Kho App Tổng Hợp (WuXu++)",
            subtitle: "https://wuxu1.github.io/wuxu-complete-plus.json",
            iconURLString: "https://i.imgur.com/stTk5jP.jpeg",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://repo.apptesters.org",
            displayName: "Kho IPA AppTesters",
            subtitle: "https://repo.apptesters.org",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://ipa.cypwn.xyz/cypwn.json",
            displayName: "Kho App & Game Lớn (CyPwn IPA)",
            subtitle: "https://ipa.cypwn.xyz/cypwn.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://raw.githubusercontent.com/swaggyP36000/TrollStore-IPAs/main/apps_esign.json",
            displayName: "Kho TrollStore IPAs (SwaggyP36000)",
            subtitle: "https://raw.githubusercontent.com/swaggyP36000/TrollStore-IPAs/main/apps_esign.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://raw.githubusercontent.com/khcrysalis/Feather/main/app-repo.json",
            displayName: "Kho Ứng Dụng Feather Repo",
            subtitle: "https://raw.githubusercontent.com/khcrysalis/Feather/main/app-repo.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://raw.githubusercontent.com/Neoncat-OG/TrollStore-IPAs/main/apps_esign.json",
            displayName: "Kho TrollStore IPAs (Neoncat-OG)",
            subtitle: "https://raw.githubusercontent.com/Neoncat-OG/TrollStore-IPAs/main/apps_esign.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://fastsign.dev/repo.lite.json",
            displayName: "Kho App FastSign Lite",
            subtitle: "https://fastsign.dev/repo.lite.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://raw.githubusercontent.com/vizunchik/AltStoreRus/master/apps.json",
            displayName: "Kho App & Game (AltStoreRus)",
            subtitle: "https://raw.githubusercontent.com/vizunchik/AltStoreRus/master/apps.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://driftywinds.github.io/repos/esign.json",
            displayName: "Kho IPA DriftyWinds",
            subtitle: "https://driftywinds.github.io/repos/esign.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://quarksources.github.io/quantumsource%2B%2B.json",
            displayName: "Kho Game & Tweaked (Quantum++)",
            subtitle: "https://quarksources.github.io/quantumsource%2B%2B.json",
            iconURLString: "https://quarksources.github.io/assets/ElementQ-Circled.png",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://wuxu1.github.io/wuxu-complete.json",
            displayName: "Kho Ứng Dụng Mở Rộng (WuXu Complete)",
            subtitle: "https://wuxu1.github.io/wuxu-complete.json",
            iconURLString: "https://i.imgur.com/stTk5jP.jpeg",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://burritosoftware.github.io/altstore/channels/burritosource.json",
            displayName: "Kho App Tweaked & Mod (Burrito)",
            subtitle: "https://burritosoftware.github.io/altstore/channels/burritosource.json",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        )
    ]

    private init() {
        loadSavedSources()
    }

    private func loadSavedSources() {
        if let data = UserDefaults.standard.data(forKey: sourcesStorageKey),
           let decoded = try? JSONDecoder().decode([FeaturedRepoSource].self, from: data),
           !decoded.isEmpty {
            self.sources = decoded
        } else {
            self.sources = Self.defaultLightSources
            saveSources()
        }
    }

    func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            UserDefaults.standard.set(data, forKey: sourcesStorageKey)
        }
    }

    func cachedApps(for source: FeaturedRepoSource) -> [FeaturedAppItem]? {
        memoryCache[source.normalizedID]
    }

    func toggleSourceInAllTab(at index: Int, enabled: Bool) {
        guard index >= 0 && index < sources.count else { return }
        sources[index].isEnabledInAllTab = enabled
        saveSources()
    }

    func removeSource(at index: Int) {
        guard index >= 0 && index < sources.count else { return }
        let removed = sources.remove(at: index)
        memoryCache.removeValue(forKey: removed.normalizedID)
        saveSources()
    }

    func addAndVerifyCustomSource(rawURLString: String) async -> Result<FeaturedRepoSource, Error> {
        let cleaned = FeaturedRepoSource.cleanURLString(rawURLString)
        guard let url = URL(string: cleaned), let scheme = url.scheme?.lowercased(), (scheme == "http" || scheme == "https") else {
            return .failure(NSError(domain: "SmartRepo", code: 400, userInfo: [NSLocalizedDescriptionKey: "Địa chỉ URL không hợp lệ. Hãy nhập link bắt đầu bằng https://"]))
        }

        if let existingIndex = sources.firstIndex(where: { $0.normalizedID == cleaned.lowercased() }) {
            sources[existingIndex].isEnabledInAllTab = true
            saveSources()
            let existing = sources[existingIndex]
            _ = await fetchApps(for: existing, forceRefresh: true)
            return .success(existing)
        }

        let tempSource = FeaturedRepoSource(
            urlString: cleaned,
            displayName: url.host ?? "Nguồn Mới",
            subtitle: cleaned,
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: false
        )

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 20
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw NSError(domain: "SmartRepo", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Máy chủ phản hồi lỗi HTTP \(http.statusCode)"])
            }

            let parsed = await Task.detached(priority: .userInitiated) {
                FeaturedUniversalRepoParser.parse(data: data, fallbackSource: tempSource)
            }.value

            guard !parsed.apps.isEmpty else {
                throw NSError(domain: "SmartRepo", code: 422, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy ứng dụng hợp lệ trong đường dẫn JSON này."])
            }

            let finalSource = FeaturedRepoSource(
                urlString: cleaned,
                displayName: parsed.repoName,
                subtitle: "\(parsed.apps.count) ứng dụng • \(url.host ?? "Custom Repo")",
                iconURLString: parsed.repoIcon,
                isEnabledInAllTab: true,
                isBuiltIn: false
            )

            memoryCache[finalSource.normalizedID] = parsed.apps
            sources.insert(finalSource, at: 0)
            saveSources()
            return .success(finalSource)
        } catch {
            return .failure(error)
        }
    }

    func fetchApps(for source: FeaturedRepoSource, forceRefresh: Bool = false) async -> [FeaturedAppItem] {
        let id = source.normalizedID
        if !forceRefresh, let cached = memoryCache[id], !cached.isEmpty {
            return cached
        }

        let cleaned = FeaturedRepoSource.cleanURLString(source.urlString)
        guard let url = URL(string: cleaned) else { return [] }

        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 22
            request.cachePolicy = forceRefresh ? .reloadIgnoringLocalCacheData : .returnCacheDataElseLoad
            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return memoryCache[id] ?? []
            }

            let parsed = await Task.detached(priority: .userInitiated) {
                FeaturedUniversalRepoParser.parse(data: data, fallbackSource: source)
            }.value

            if !parsed.apps.isEmpty {
                memoryCache[id] = parsed.apps
                if let idx = sources.firstIndex(where: { $0.normalizedID == id }) {
                    if !parsed.repoName.isEmpty {
                        sources[idx].displayName = parsed.repoName
                    }
                    sources[idx].subtitle = "\(parsed.apps.count) ứng dụng • \(url.host ?? "Repo")"
                    if let icon = parsed.repoIcon, sources[idx].iconURLString == nil {
                        sources[idx].iconURLString = icon
                    }
                    saveSources()
                }
            }
            return parsed.apps
        } catch {
            return memoryCache[id] ?? []
        }
    }
}

// MARK: - 🏷️ HEADER BANNER (.hero + THANH TÌM KIẾM ĐƠN GỌN ĐẸP KHÔNG ĐÈ KHUNG, KHÔNG TỤT BÀN PHÍM)
private final class FeaturedWebScrollHeaderReusableView: UICollectionReusableView, UITextFieldDelegate {
    static let reuseIdentifier = "FeaturedWebScrollHeaderReusableView"

    private let heroCard = UIView()
    private let heroGradient = CAGradientLayer()

    private let downloadedPillButton = UIButton(type: .system)
    private let sourcesPillButton = UIButton(type: .system)

    private let centerTitleStack = UIStackView()
    private let heroIconView = UIImageView()
    private let heroTitleLabel = UILabel()
    private let loadingSpinner = UIActivityIndicatorView(style: .medium)

    private let filterStatusPillButton = UIButton(type: .system)

    // 1 Khung tìm kiếm duy nhất (Đã xóa khung thừa đè bên dưới & thu nhỏ chiều cao còn 36pt)
    private let searchBoxView = UIView()
    private let searchIconView = UIImageView()
    let searchTextField = UITextField()

    private let sectionRowStack = UIStackView()
    private let sectionTitleLabel = UILabel()
    private let quickSwitchSourceButton = UIButton(type: .system)

    var onOpenDownloadsTapped: (() -> Void)?
    var onOpenSourcesTapped: (() -> Void)?
    var onFilterPillTapped: (() -> Void)?
    var onSearchTextChanged: ((String) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        heroGradient.frame = heroCard.bounds
    }

    private func setupViews() {
        backgroundColor = .clear

        // 1. Thẻ .hero Gradient
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = 16
        heroCard.layer.shadowColor = FeaturedCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 6)
        heroCard.layer.shadowRadius = 14
        heroCard.layer.shadowOpacity = 0.22

        heroGradient.colors = [FeaturedCSSTheme.heroStart, FeaturedCSSTheme.heroEnd]
        heroGradient.startPoint = CGPoint(x: 0.0, y: 0.0)
        heroGradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        heroGradient.cornerRadius = 16
        heroCard.layer.insertSublayer(heroGradient, at: 0)
        addSubview(heroCard)

        downloadedPillButton.translatesAutoresizingMaskIntoConstraints = false
        downloadedPillButton.setTitle("📥 Đã tải", for: .normal)
        downloadedPillButton.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
        downloadedPillButton.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .heavy)
        downloadedPillButton.backgroundColor = FeaturedCSSTheme.white
        downloadedPillButton.layer.cornerRadius = 15
        downloadedPillButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        downloadedPillButton.addTarget(self, action: #selector(handleDownloadsTap), for: .touchUpInside)
        heroCard.addSubview(downloadedPillButton)

        sourcesPillButton.translatesAutoresizingMaskIntoConstraints = false
        sourcesPillButton.setTitle("➕ Nguồn", for: .normal)
        sourcesPillButton.setTitleColor(FeaturedCSSTheme.white, for: .normal)
        sourcesPillButton.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        sourcesPillButton.backgroundColor = UIColor.white.withAlphaComponent(0.20)
        sourcesPillButton.layer.cornerRadius = 15
        sourcesPillButton.layer.borderWidth = 1.0
        sourcesPillButton.layer.borderColor = UIColor.white.withAlphaComponent(0.38).cgColor
        sourcesPillButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        sourcesPillButton.addTarget(self, action: #selector(handleSourcesTap), for: .touchUpInside)
        heroCard.addSubview(sourcesPillButton)

        centerTitleStack.translatesAutoresizingMaskIntoConstraints = false
        centerTitleStack.axis = .horizontal
        centerTitleStack.alignment = .center
        centerTitleStack.spacing = 6
        heroCard.addSubview(centerTitleStack)

        let iconCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
        heroIconView.image = UIImage(systemName: "sparkles.rectangle.stack.fill", withConfiguration: iconCfg)
        heroIconView.tintColor = .white
        centerTitleStack.addArrangedSubview(heroIconView)

        heroTitleLabel.text = "Kho App Game"
        heroTitleLabel.font = UIFont.systemFont(ofSize: 17.5, weight: .heavy)
        heroTitleLabel.textColor = .white
        heroTitleLabel.adjustsFontSizeToFitWidth = true
        heroTitleLabel.minimumScaleFactor = 0.82
        centerTitleStack.addArrangedSubview(heroTitleLabel)

        loadingSpinner.color = .white
        loadingSpinner.transform = CGAffineTransform(scaleX: 0.78, y: 0.78)
        loadingSpinner.hidesWhenStopped = true
        centerTitleStack.addArrangedSubview(loadingSpinner)

        filterStatusPillButton.translatesAutoresizingMaskIntoConstraints = false
        filterStatusPillButton.setTitle("🌐 Tất cả nguồn • Chạm để lọc nguồn", for: .normal)
        filterStatusPillButton.setTitleColor(.white, for: .normal)
        filterStatusPillButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        filterStatusPillButton.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        filterStatusPillButton.layer.cornerRadius = 13
        filterStatusPillButton.layer.borderWidth = 1.0
        filterStatusPillButton.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        filterStatusPillButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)
        filterStatusPillButton.addTarget(self, action: #selector(handleFilterPillTap), for: .touchUpInside)
        heroCard.addSubview(filterStatusPillButton)

        // 2. Thanh tìm kiếm đơn gọn (Cao 36pt, không có khung lồng đè phía dưới)
        searchBoxView.translatesAutoresizingMaskIntoConstraints = false
        searchBoxView.backgroundColor = FeaturedCSSTheme.white
        searchBoxView.layer.cornerRadius = 11
        searchBoxView.layer.borderWidth = 1.0
        searchBoxView.layer.borderColor = FeaturedCSSTheme.cardBorder.cgColor
        searchBoxView.layer.shadowColor = FeaturedCSSTheme.blue.cgColor
        searchBoxView.layer.shadowOffset = CGSize(width: 0, height: 2)
        searchBoxView.layer.shadowRadius = 6
        searchBoxView.layer.shadowOpacity = 0.04
        addSubview(searchBoxView)

        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        searchIconView.image = UIImage(systemName: "magnifyingglass")
        searchIconView.tintColor = FeaturedCSSTheme.blue
        searchIconView.contentMode = .scaleAspectFit
        searchBoxView.addSubview(searchIconView)

        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchTextField.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
        searchTextField.textColor = FeaturedCSSTheme.pureBlack
        searchTextField.clearButtonMode = .whileEditing
        searchTextField.returnKeyType = .done
        searchTextField.autocorrectionType = .no
        searchTextField.autocapitalizationType = .none
        searchTextField.attributedPlaceholder = NSAttributedString(
            string: "Tìm tên App, Game, tác giả, Bundle ID...",
            attributes: [.foregroundColor: FeaturedCSSTheme.darkGray.withAlphaComponent(0.6)]
        )
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(handleTextFieldEditingChanged(_:)), for: .editingChanged)
        searchBoxView.addSubview(searchTextField)

        // 3. Hàng tiêu đề danh sách
        sectionRowStack.translatesAutoresizingMaskIntoConstraints = false
        sectionRowStack.axis = .horizontal
        sectionRowStack.alignment = .center
        sectionRowStack.distribution = .equalSpacing
        addSubview(sectionRowStack)

        sectionTitleLabel.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        sectionTitleLabel.textColor = FeaturedCSSTheme.primary
        sectionTitleLabel.text = "🔥 DANH SÁCH ỨNG DỤNG & TRÒ CHƠI"
        sectionRowStack.addArrangedSubview(sectionTitleLabel)

        quickSwitchSourceButton.setTitle("🗂️ Chọn nguồn", for: .normal)
        quickSwitchSourceButton.setTitleColor(FeaturedCSSTheme.purple, for: .normal)
        quickSwitchSourceButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        quickSwitchSourceButton.backgroundColor = FeaturedCSSTheme.purplePillBg
        quickSwitchSourceButton.layer.cornerRadius = 12
        quickSwitchSourceButton.layer.borderWidth = 0.8
        quickSwitchSourceButton.layer.borderColor = FeaturedCSSTheme.purple.withAlphaComponent(0.28).cgColor
        quickSwitchSourceButton.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        quickSwitchSourceButton.addTarget(self, action: #selector(handleFilterPillTap), for: .touchUpInside)
        sectionRowStack.addArrangedSubview(quickSwitchSourceButton)

        NSLayoutConstraint.activate([
            heroCard.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            heroCard.leadingAnchor.constraint(equalTo: leadingAnchor),
            heroCard.trailingAnchor.constraint(equalTo: trailingAnchor),
            heroCard.heightAnchor.constraint(equalToConstant: 86),

            downloadedPillButton.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 10),
            downloadedPillButton.topAnchor.constraint(equalTo: heroCard.topAnchor, constant: 10),
            downloadedPillButton.heightAnchor.constraint(equalToConstant: 30),

            sourcesPillButton.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -10),
            sourcesPillButton.centerYAnchor.constraint(equalTo: downloadedPillButton.centerYAnchor),
            sourcesPillButton.heightAnchor.constraint(equalToConstant: 30),

            centerTitleStack.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            centerTitleStack.centerYAnchor.constraint(equalTo: downloadedPillButton.centerYAnchor),
            centerTitleStack.leadingAnchor.constraint(greaterThanOrEqualTo: downloadedPillButton.trailingAnchor, constant: 6),
            centerTitleStack.trailingAnchor.constraint(lessThanOrEqualTo: sourcesPillButton.leadingAnchor, constant: -6),

            filterStatusPillButton.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            filterStatusPillButton.bottomAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: -9),
            filterStatusPillButton.heightAnchor.constraint(equalToConstant: 26),
            filterStatusPillButton.leadingAnchor.constraint(greaterThanOrEqualTo: heroCard.leadingAnchor, constant: 12),
            filterStatusPillButton.trailingAnchor.constraint(lessThanOrEqualTo: heroCard.trailingAnchor, constant: -12),

            searchBoxView.topAnchor.constraint(equalTo: heroCard.bottomAnchor, constant: 8),
            searchBoxView.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchBoxView.trailingAnchor.constraint(equalTo: trailingAnchor),
            searchBoxView.heightAnchor.constraint(equalToConstant: 36),

            searchIconView.leadingAnchor.constraint(equalTo: searchBoxView.leadingAnchor, constant: 11),
            searchIconView.centerYAnchor.constraint(equalTo: searchBoxView.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 15),
            searchIconView.heightAnchor.constraint(equalToConstant: 15),

            searchTextField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 8),
            searchTextField.trailingAnchor.constraint(equalTo: searchBoxView.trailingAnchor, constant: -8),
            searchTextField.topAnchor.constraint(equalTo: searchBoxView.topAnchor),
            searchTextField.bottomAnchor.constraint(equalTo: searchBoxView.bottomAnchor),

            sectionRowStack.topAnchor.constraint(equalTo: searchBoxView.bottomAnchor, constant: 8),
            sectionRowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            sectionRowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            sectionRowStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    func updateHeaderState(
        isLoading: Bool,
        filterText: String,
        totalAppsCount: Int,
        downloadedCount: Int
    ) {
        if isLoading {
            loadingSpinner.startAnimating()
        } else {
            loadingSpinner.stopAnimating()
        }

        let dlTitle = downloadedCount > 0 ? "📥 Đã tải (\(downloadedCount))" : "📥 Đã tải"
        downloadedPillButton.setTitle(dlTitle, for: .normal)

        filterStatusPillButton.setTitle(filterText, for: .normal)
        sectionTitleLabel.text = "🔥 DANH SÁCH APP & GAME (\(totalAppsCount))"
    }

    @objc private func handleTextFieldEditingChanged(_ sender: UITextField) {
        onSearchTextChanged?(sender.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc private func handleDownloadsTap() {
        onOpenDownloadsTapped?()
    }

    @objc private func handleSourcesTap() {
        onOpenSourcesTapped?()
    }

    @objc private func handleFilterPillTap() {
        onFilterPillTapped?()
    }
}

// MARK: - 🃏 CELL HIỂN THỊ ỨNG DỤNG CHUẨN THẺ TRẮNG VIỀN CSS (#e6ebf2)
private final class FeaturedHubAppCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "FeaturedHubAppCollectionViewCell"

    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let bundleIDLabel = UILabel()
    private let metaLabel = UILabel()
    private let sourceBadgeView = UIView()
    private let sourceBadgeLabel = UILabel()
    private let descLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let progressBarBg = UIView()
    private let progressBarFill = UIView()
    private var progressWidthConstraint: NSLayoutConstraint!

    private var currentDownloadKey: String?
    var onActionTapped: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = FeaturedCSSTheme.white
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1.0
        cardView.layer.borderColor = FeaturedCSSTheme.cardBorder.cgColor
        cardView.layer.shadowColor = FeaturedCSSTheme.blue.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOpacity = 0.05
        contentView.addSubview(cardView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.backgroundColor = FeaturedCSSTheme.light
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 13
        iconImageView.layer.borderWidth = 0.8
        iconImageView.layer.borderColor = FeaturedCSSTheme.innerBorder.cgColor
        iconImageView.clipsToBounds = true
        cardView.addSubview(iconImageView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        nameLabel.textColor = FeaturedCSSTheme.pureBlack
        nameLabel.numberOfLines = 1
        cardView.addSubview(nameLabel)

        bundleIDLabel.translatesAutoresizingMaskIntoConstraints = false
        bundleIDLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .semibold)
        bundleIDLabel.textColor = FeaturedCSSTheme.blue
        bundleIDLabel.numberOfLines = 1
        bundleIDLabel.lineBreakMode = .byTruncatingMiddle
        cardView.addSubview(bundleIDLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .semibold)
        metaLabel.textColor = FeaturedCSSTheme.darkGray
        metaLabel.numberOfLines = 1
        cardView.addSubview(metaLabel)

        sourceBadgeView.translatesAutoresizingMaskIntoConstraints = false
        sourceBadgeView.backgroundColor = FeaturedCSSTheme.infoBg
        sourceBadgeView.layer.cornerRadius = 6
        sourceBadgeView.layer.borderWidth = 0.7
        sourceBadgeView.layer.borderColor = FeaturedCSSTheme.blue.withAlphaComponent(0.22).cgColor
        cardView.addSubview(sourceBadgeView)

        sourceBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceBadgeLabel.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        sourceBadgeLabel.textColor = FeaturedCSSTheme.blue
        sourceBadgeView.addSubview(sourceBadgeLabel)

        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        descLabel.textColor = FeaturedCSSTheme.darkGray
        descLabel.numberOfLines = 2
        cardView.addSubview(descLabel)

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        actionButton.layer.cornerRadius = 15
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        actionButton.addTarget(self, action: #selector(handleActionButtonTapped), for: .touchUpInside)
        cardView.addSubview(actionButton)

        progressBarBg.translatesAutoresizingMaskIntoConstraints = false
        progressBarBg.backgroundColor = FeaturedCSSTheme.blue.withAlphaComponent(0.12)
        progressBarBg.layer.cornerRadius = 2.0
        progressBarBg.clipsToBounds = true
        progressBarBg.isHidden = true
        cardView.addSubview(progressBarBg)

        progressBarFill.translatesAutoresizingMaskIntoConstraints = false
        progressBarFill.backgroundColor = FeaturedCSSTheme.blue
        progressBarFill.layer.cornerRadius = 2.0
        progressBarBg.addSubview(progressBarFill)

        progressWidthConstraint = progressBarFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 11),
            iconImageView.widthAnchor.constraint(equalToConstant: 54),
            iconImageView.heightAnchor.constraint(equalToConstant: 54),

            actionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            actionButton.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 30),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 92),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: -1),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            bundleIDLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            bundleIDLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            bundleIDLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            metaLabel.topAnchor.constraint(equalTo: bundleIDLabel.bottomAnchor, constant: 1),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            sourceBadgeView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 7),
            sourceBadgeView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            sourceBadgeView.heightAnchor.constraint(equalToConstant: 18),

            sourceBadgeLabel.leadingAnchor.constraint(equalTo: sourceBadgeView.leadingAnchor, constant: 6),
            sourceBadgeLabel.trailingAnchor.constraint(equalTo: sourceBadgeView.trailingAnchor, constant: -6),
            sourceBadgeLabel.centerYAnchor.constraint(equalTo: sourceBadgeView.centerYAnchor),

            descLabel.topAnchor.constraint(equalTo: sourceBadgeView.bottomAnchor, constant: 5),
            descLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            progressBarBg.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            progressBarBg.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            progressBarBg.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -5),
            progressBarBg.heightAnchor.constraint(equalToConstant: 4),

            progressBarFill.leadingAnchor.constraint(equalTo: progressBarBg.leadingAnchor),
            progressBarFill.topAnchor.constraint(equalTo: progressBarBg.topAnchor),
            progressBarFill.bottomAnchor.constraint(equalTo: progressBarBg.bottomAnchor),
            progressWidthConstraint
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = UIImage(systemName: "app.fill")?.withTintColor(FeaturedCSSTheme.blue.withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
        currentDownloadKey = nil
    }

    @objc private func handleActionButtonTapped() {
        UIView.animate(withDuration: 0.1, animations: {
            self.actionButton.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.actionButton.transform = .identity
            }
        }
        onActionTapped?()
    }

    func configure(with app: FeaturedAppItem, isDownloaded: Bool, activeProgress: Double?) {
        let targetKey = app.downloadURL.absoluteString
        currentDownloadKey = targetKey
        nameLabel.text = app.name
        bundleIDLabel.text = app.bundleIdentifier
        metaLabel.text = "v\(app.version) • \(app.formattedSize) • \(app.developerName)"
        sourceBadgeLabel.text = "📦 \(app.sourceName)"

        let cleanDesc = app.localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        descLabel.text = cleanDesc.isEmpty ? "Ứng dụng từ nguồn \(app.sourceName)" : cleanDesc

        iconImageView.image = UIImage(systemName: "app.badge.fill")?.withTintColor(FeaturedCSSTheme.blue.withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
        if let iconURL = app.iconURL {
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let image = try? await ImagePipeline.shared.image(for: iconURL) {
                    if self.currentDownloadKey == targetKey {
                        self.iconImageView.image = image
                    }
                }
            }
        }

        updateDownloadState(isDownloaded: isDownloaded, activeProgress: activeProgress)
    }

    func updateDownloadState(isDownloaded: Bool, activeProgress: Double?) {
        if let progress = activeProgress {
            let percent = Int((progress * 100).rounded())
            actionButton.setTitle("⏳ \(percent)%", for: .normal)
            actionButton.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
            actionButton.backgroundColor = FeaturedCSSTheme.blue.withAlphaComponent(0.14)
            actionButton.layer.borderWidth = 1.2
            actionButton.layer.borderColor = FeaturedCSSTheme.blue.withAlphaComponent(0.45).cgColor

            progressBarBg.isHidden = false
            let maxWidth = max(bounds.width - 24, 100)
            progressWidthConstraint.constant = maxWidth * CGFloat(min(max(progress, 0.03), 1.0))
        } else if isDownloaded {
            actionButton.setTitle("✍️ KÝ APP", for: .normal)
            actionButton.setTitleColor(FeaturedCSSTheme.white, for: .normal)
            actionButton.backgroundColor = FeaturedCSSTheme.green
            actionButton.layer.borderWidth = 0
            progressBarBg.isHidden = true
        } else {
            actionButton.setTitle("⬇️ TẢI VỀ", for: .normal)
            actionButton.setTitleColor(FeaturedCSSTheme.white, for: .normal)
            actionButton.backgroundColor = FeaturedCSSTheme.blue
            actionButton.layer.borderWidth = 0
            progressBarBg.isHidden = true
        }
    }
}

// MARK: - 📋 DATASOURCE RIÊNG CHO FEATURED SMART HUB
@MainActor
private final class FeaturedSmartHubDataSource: NSObject, UICollectionViewDataSource {
    var items: [FeaturedAppItem] = []
    var onActionTapped: ((FeaturedAppItem) -> Void)?
    var configureHeader: ((FeaturedWebScrollHeaderReusableView) -> Void)?

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: FeaturedWebScrollHeaderReusableView.reuseIdentifier,
            for: indexPath
        ) as! FeaturedWebScrollHeaderReusableView
        configureHeader?(header)
        return header
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FeaturedHubAppCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! FeaturedHubAppCollectionViewCell

        let app = items[indexPath.item]
        let isDownloaded = (FeaturedIPADownloadCenter.shared.localFileURL(for: app) != nil)
        let progress = FeaturedIPADownloadCenter.shared.activeProgress(for: app)

        cell.configure(with: app, isDownloaded: isDownloaded, activeProgress: progress)
        cell.onActionTapped = { [weak self] in
            self?.onActionTapped?(app)
        }
        return cell
    }
}

// MARK: - 🪟 KHUNG CHI TIẾT ĐẦY ĐỦ THÔNG TIN APP (CHIỀU RỘNG ĐÚNG 90% MÀN HÌNH)
@MainActor
private final class FeaturedAppFullInfoPopupViewController: UIViewController {
    private let app: FeaturedAppItem
    private let onPrimaryAction: () -> Void

    private let dimView = UIView()
    private let containerCard = UIView()
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
    private let versionBadgeLabel = UILabel()
    private let infoBoxView = UIView()
    private let infoLabel = UILabel()
    private let descriptionTextView = UITextView()
    private let buttonStack = UIStackView()
    private let closeButton = UIButton(type: .system)
    private let actionButton = UIButton(type: .system)

    init(app: FeaturedAppItem, onPrimaryAction: @escaping () -> Void) {
        self.app = app
        self.onPrimaryAction = onPrimaryAction
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        setupViews()
        populateAppData()
    }

    private func setupViews() {
        view.backgroundColor = .clear

        dimView.translatesAutoresizingMaskIntoConstraints = false
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        dimView.addGestureRecognizer(tapGesture)
        view.addSubview(dimView)

        containerCard.translatesAutoresizingMaskIntoConstraints = false
        containerCard.backgroundColor = FeaturedCSSTheme.white
        containerCard.layer.cornerRadius = 20
        containerCard.layer.borderWidth = 1.0
        containerCard.layer.borderColor = FeaturedCSSTheme.cardBorder.cgColor
        containerCard.layer.shadowColor = UIColor.black.cgColor
        containerCard.layer.shadowOffset = CGSize(width: 0, height: 10)
        containerCard.layer.shadowRadius = 24
        containerCard.layer.shadowOpacity = 0.22
        view.addSubview(containerCard)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.backgroundColor = FeaturedCSSTheme.light
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 15
        iconImageView.layer.borderWidth = 1.0
        iconImageView.layer.borderColor = FeaturedCSSTheme.innerBorder.cgColor
        iconImageView.clipsToBounds = true
        containerCard.addSubview(iconImageView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 17, weight: .heavy)
        nameLabel.textColor = FeaturedCSSTheme.pureBlack
        nameLabel.numberOfLines = 2
        containerCard.addSubview(nameLabel)

        versionBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        versionBadgeLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        versionBadgeLabel.textColor = FeaturedCSSTheme.blue
        containerCard.addSubview(versionBadgeLabel)

        infoBoxView.translatesAutoresizingMaskIntoConstraints = false
        infoBoxView.backgroundColor = FeaturedCSSTheme.light
        infoBoxView.layer.cornerRadius = 12
        infoBoxView.layer.borderWidth = 1.0
        infoBoxView.layer.borderColor = FeaturedCSSTheme.innerBorder.cgColor
        containerCard.addSubview(infoBoxView)

        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.numberOfLines = 0
        infoBoxView.addSubview(infoLabel)

        descriptionTextView.translatesAutoresizingMaskIntoConstraints = false
        descriptionTextView.isEditable = false
        descriptionTextView.isSelectable = true
        descriptionTextView.backgroundColor = FeaturedCSSTheme.infoBg.withAlphaComponent(0.55)
        descriptionTextView.layer.cornerRadius = 12
        descriptionTextView.layer.borderWidth = 0.8
        descriptionTextView.layer.borderColor = FeaturedCSSTheme.innerBorder.cgColor
        descriptionTextView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        descriptionTextView.font = UIFont.systemFont(ofSize: 13.5, weight: .regular)
        descriptionTextView.textColor = FeaturedCSSTheme.darkGray
        containerCard.addSubview(descriptionTextView)

        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually
        containerCard.addSubview(buttonStack)

        closeButton.setTitle("Đóng", for: .normal)
        closeButton.setTitleColor(FeaturedCSSTheme.darkGray, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        closeButton.backgroundColor = FeaturedCSSTheme.light
        closeButton.layer.cornerRadius = 12
        closeButton.layer.borderWidth = 1.0
        closeButton.layer.borderColor = FeaturedCSSTheme.border.cgColor
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(closeButton)

        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .heavy)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.layer.cornerRadius = 12
        actionButton.addTarget(self, action: #selector(primaryActionTapped), for: .touchUpInside)
        buttonStack.addArrangedSubview(actionButton)

        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Chiều rộng khung đúng 90% màn hình
            containerCard.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerCard.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerCard.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.90),
            containerCard.heightAnchor.constraint(lessThanOrEqualTo: view.heightAnchor, multiplier: 0.82),

            iconImageView.topAnchor.constraint(equalTo: containerCard.topAnchor, constant: 16),
            iconImageView.leadingAnchor.constraint(equalTo: containerCard.leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 62),
            iconImageView.heightAnchor.constraint(equalToConstant: 62),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 2),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: containerCard.trailingAnchor, constant: -16),

            versionBadgeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            versionBadgeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            versionBadgeLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            infoBoxView.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 14),
            infoBoxView.leadingAnchor.constraint(equalTo: containerCard.leadingAnchor, constant: 16),
            infoBoxView.trailingAnchor.constraint(equalTo: containerCard.trailingAnchor, constant: -16),

            infoLabel.topAnchor.constraint(equalTo: infoBoxView.topAnchor, constant: 10),
            infoLabel.leadingAnchor.constraint(equalTo: infoBoxView.leadingAnchor, constant: 12),
            infoLabel.trailingAnchor.constraint(equalTo: infoBoxView.trailingAnchor, constant: -12),
            infoLabel.bottomAnchor.constraint(equalTo: infoBoxView.bottomAnchor, constant: -10),

            descriptionTextView.topAnchor.constraint(equalTo: infoBoxView.bottomAnchor, constant: 12),
            descriptionTextView.leadingAnchor.constraint(equalTo: containerCard.leadingAnchor, constant: 16),
            descriptionTextView.trailingAnchor.constraint(equalTo: containerCard.trailingAnchor, constant: -16),
            descriptionTextView.heightAnchor.constraint(equalToConstant: 165),

            buttonStack.topAnchor.constraint(equalTo: descriptionTextView.bottomAnchor, constant: 14),
            buttonStack.leadingAnchor.constraint(equalTo: containerCard.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: containerCard.trailingAnchor, constant: -16),
            buttonStack.bottomAnchor.constraint(equalTo: containerCard.bottomAnchor, constant: -16),
            buttonStack.heightAnchor.constraint(equalToConstant: 42)
        ])
    }

    private func populateAppData() {
        nameLabel.text = app.name
        versionBadgeLabel.text = "Phiên bản v\(app.version) • \(app.formattedSize)"

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4

        let infoText = """
        👤 Tác giả: \(app.developerName)
        🆔 Bundle ID: \(app.bundleIdentifier)
        💾 Dung lượng: \(app.formattedSize)
        📦 Nguồn: \(app.sourceName)
        """
        infoLabel.attributedText = NSAttributedString(
            string: infoText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: FeaturedCSSTheme.primary,
                .paragraphStyle: paragraph
            ]
        )

        let cleanDescription = app.localizedDescription
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        descriptionTextView.text = cleanDescription.isEmpty
            ? "Ứng dụng được cung cấp bởi nguồn \(app.sourceName)."
            : cleanDescription

        iconImageView.image = UIImage(systemName: "app.badge.fill")?.withTintColor(FeaturedCSSTheme.blue.withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
        if let iconURL = app.iconURL {
            Task { @MainActor [weak self] in
                if let image = try? await ImagePipeline.shared.image(for: iconURL) {
                    self?.iconImageView.image = image
                }
            }
        }

        let isDownloaded = (FeaturedIPADownloadCenter.shared.localFileURL(for: app) != nil)
        if isDownloaded {
            actionButton.setTitle("✍️ KÝ APP NGAY", for: .normal)
            actionButton.backgroundColor = FeaturedCSSTheme.green
        } else {
            actionButton.setTitle("⬇️ TẢI VỀ IPA", for: .normal)
            actionButton.backgroundColor = FeaturedCSSTheme.blue
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func primaryActionTapped() {
        dismiss(animated: true) { [weak self] in
            self?.onPrimaryAction()
        }
    }
}

// MARK: - 🗂️ MÀN HÌNH QUẢN LÝ FILE ĐÃ TẢI VỀ (CHỮ TÙY CHỌN FILE IPA NHỎ GỌN ĐẸP)
@MainActor
private final class FeaturedDownloadedIPAsManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSelectSignIPA: ((FeaturedDownloadedIPAEntry) -> Void)?

    private let backgroundView = FeaturedGradientBackgroundView(frame: .zero)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private let heroGradientLayer = CAGradientLayer()
    private weak var heroCardRef: UIView?
    private weak var clearAllBtnRef: UIButton?
    private var entries: [FeaturedDownloadedIPAEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        navigationController?.setNavigationBarHidden(true, animated: false)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 68
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 6
        }
        tableView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        view.addSubview(tableView)

        setupScrollableHeroHeader()

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "Chưa có file IPA nào được tải về.\nHãy bấm “⬇️ TẢI VỀ” ở ngoài để lưu IPA vào đây!"
        emptyLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.textColor = FeaturedCSSTheme.darkGray
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: 20),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadDataEntries),
            name: FeaturedIPADownloadCenter.stateDidChangeNotification,
            object: nil
        )
        reloadDataEntries()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let card = heroCardRef {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            heroGradientLayer.frame = card.bounds
            CATransaction.commit()
        }
    }

    private func setupScrollableHeroHeader() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 70))
        headerContainer.backgroundColor = .clear

        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = 16
        heroCard.layer.shadowColor = FeaturedCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 5)
        heroCard.layer.shadowRadius = 12
        heroCard.layer.shadowOpacity = 0.20

        heroGradientLayer.colors = [FeaturedCSSTheme.heroStart, FeaturedCSSTheme.heroEnd]
        heroGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        heroGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        heroGradientLayer.cornerRadius = 16
        heroCard.layer.insertSublayer(heroGradientLayer, at: 0)
        headerContainer.addSubview(heroCard)
        self.heroCardRef = heroCard

        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setTitle("Đóng", for: .normal)
        closeBtn.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
        closeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        closeBtn.backgroundColor = FeaturedCSSTheme.white
        closeBtn.layer.cornerRadius = 14
        closeBtn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        heroCard.addSubview(closeBtn)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "📥 File IPA Đã Tải"
        titleLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        heroCard.addSubview(titleLabel)

        let clearBtn = UIButton(type: .system)
        clearBtn.translatesAutoresizingMaskIntoConstraints = false
        clearBtn.setTitle("Xóa hết", for: .normal)
        clearBtn.setTitleColor(.white, for: .normal)
        clearBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        clearBtn.backgroundColor = FeaturedCSSTheme.red.withAlphaComponent(0.85)
        clearBtn.layer.cornerRadius = 14
        clearBtn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        clearBtn.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        heroCard.addSubview(clearBtn)
        self.clearAllBtnRef = clearBtn

        NSLayoutConstraint.activate([
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -6),

            closeBtn.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            closeBtn.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),
            closeBtn.heightAnchor.constraint(equalToConstant: 28),

            clearBtn.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            clearBtn.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),
            clearBtn.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeBtn.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: clearBtn.leadingAnchor, constant: -8)
        ])

        tableView.tableHeaderView = headerContainer
    }

    @objc private func reloadDataEntries() {
        FeaturedIPADownloadCenter.shared.reloadDownloadedFiles()
        entries = FeaturedIPADownloadCenter.shared.downloadedEntries
        emptyLabel.isHidden = !entries.isEmpty
        clearAllBtnRef?.isEnabled = !entries.isEmpty
        clearAllBtnRef?.alpha = entries.isEmpty ? 0.4 : 1.0
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "Xóa tất cả file IPA?",
            message: "Toàn bộ các file .ipa đã tải trong bộ nhớ sẽ bị xóa để giải phóng dung lượng.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Xóa tất cả", style: .destructive) { _ in
            FeaturedIPADownloadCenter.shared.deleteAllDownloadedFiles()
        })
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard !entries.isEmpty else { return nil }
        let totalBytes = entries.reduce(Int64(0)) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file

        let container = UIView()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "ĐÃ LƯU \(entries.count) FILE IPA • TỔNG DUNG LƯỢNG: \(formatter.string(fromByteCount: totalBytes).uppercased())"
        label.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        label.textColor = FeaturedCSSTheme.primary
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        entries.isEmpty ? 0.01 : 28
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = "FeaturedDownloadedIPACell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        let entry = entries[indexPath.row]

        cell.backgroundColor = FeaturedCSSTheme.white
        cell.textLabel?.text = "\(entry.appName) (v\(entry.version))"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        cell.textLabel?.textColor = FeaturedCSSTheme.pureBlack

        cell.detailTextLabel?.text = "\(entry.formattedSize) • \(entry.bundleIdentifier)"
        cell.detailTextLabel?.font = UIFont.monospacedSystemFont(ofSize: 11.5, weight: .semibold)
        cell.detailTextLabel?.textColor = FeaturedCSSTheme.blue
        cell.imageView?.image = UIImage(systemName: "doc.zipper")?.withTintColor(FeaturedCSSTheme.blue, renderingMode: .alwaysOriginal)

        let signBtn = UIButton(type: .system)
        signBtn.setTitle("✍️ KÝ APP", for: .normal)
        signBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        signBtn.setTitleColor(.white, for: .normal)
        signBtn.backgroundColor = FeaturedCSSTheme.green
        signBtn.layer.cornerRadius = 14
        signBtn.frame = CGRect(x: 0, y: 0, width: 90, height: 30)
        signBtn.tag = indexPath.row
        signBtn.addTarget(self, action: #selector(signButtonTapped(_:)), for: .touchUpInside)
        cell.accessoryView = signBtn

        return cell
    }

    @objc private func signButtonTapped(_ sender: UIButton) {
        let row = sender.tag
        guard row >= 0 && row < entries.count else { return }
        let entry = entries[row]
        dismiss(animated: true) { [weak self] in
            self?.onSelectSignIPA?(entry)
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let entry = entries[indexPath.row]
        presentCompactFileActionsModal(for: entry)
    }

    private func presentCompactFileActionsModal(for entry: FeaturedDownloadedIPAEntry) {
        let fileURL = FeaturedIPADownloadCenter.shared.localFileURL(for: entry)

        let modalVC = UIViewController()
        modalVC.modalPresentationStyle = .overFullScreen
        modalVC.modalTransitionStyle = .crossDissolve

        let dim = UIView()
        dim.translatesAutoresizingMaskIntoConstraints = false
        dim.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        modalVC.view.addSubview(dim)

        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = FeaturedCSSTheme.white
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1.0
        card.layer.borderColor = FeaturedCSSTheme.cardBorder.cgColor
        modalVC.view.addSubview(card)

        let titleLbl = UILabel()
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.text = "\(entry.appName) (v\(entry.version))"
        titleLbl.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        titleLbl.textColor = FeaturedCSSTheme.pureBlack
        titleLbl.textAlignment = .center
        titleLbl.numberOfLines = 2
        card.addSubview(titleLbl)

        let subLbl = UILabel()
        subLbl.translatesAutoresizingMaskIntoConstraints = false
        subLbl.text = "Dung lượng: \(entry.formattedSize)\n\(entry.fileName)"
        subLbl.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        subLbl.textColor = FeaturedCSSTheme.darkGray
        subLbl.textAlignment = .center
        subLbl.numberOfLines = 2
        card.addSubview(subLbl)

        let shareBtn = UIButton(type: .system)
        shareBtn.translatesAutoresizingMaskIntoConstraints = false
        shareBtn.setTitle("📤 Chia sẻ / Lưu vào Tệp (Files)", for: .normal)
        shareBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        shareBtn.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
        shareBtn.backgroundColor = FeaturedCSSTheme.infoBg
        shareBtn.layer.cornerRadius = 11
        card.addSubview(shareBtn)

        let deleteBtn = UIButton(type: .system)
        deleteBtn.translatesAutoresizingMaskIntoConstraints = false
        deleteBtn.setTitle("🗑️ Xóa file IPA này", for: .normal)
        deleteBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        deleteBtn.setTitleColor(FeaturedCSSTheme.red, for: .normal)
        deleteBtn.backgroundColor = FeaturedCSSTheme.red.withAlphaComponent(0.1)
        deleteBtn.layer.cornerRadius = 11
        card.addSubview(deleteBtn)

        let cancelBtn = UIButton(type: .system)
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.setTitle("Đóng", for: .normal)
        cancelBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .bold)
        cancelBtn.setTitleColor(FeaturedCSSTheme.darkGray, for: .normal)
        cancelBtn.backgroundColor = FeaturedCSSTheme.light
        cancelBtn.layer.cornerRadius = 11
        card.addSubview(cancelBtn)

        shareBtn.addAction(UIAction { [weak self, weak modalVC] _ in
            modalVC?.dismiss(animated: true) {
                guard let self else { return }
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = self.view
                    popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
                }
                self.present(activityVC, animated: true)
            }
        }, for: .touchUpInside)

        deleteBtn.addAction(UIAction { [weak modalVC] _ in
            modalVC?.dismiss(animated: true) {
                FeaturedIPADownloadCenter.shared.deleteDownloadedFile(entry: entry)
            }
        }, for: .touchUpInside)

        cancelBtn.addAction(UIAction { [weak modalVC] _ in
            modalVC?.dismiss(animated: true)
        }, for: .touchUpInside)

        NSLayoutConstraint.activate([
            dim.topAnchor.constraint(equalTo: modalVC.view.topAnchor),
            dim.leadingAnchor.constraint(equalTo: modalVC.view.leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: modalVC.view.trailingAnchor),
            dim.bottomAnchor.constraint(equalTo: modalVC.view.bottomAnchor),

            card.centerXAnchor.constraint(equalTo: modalVC.view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: modalVC.view.centerYAnchor),
            card.widthAnchor.constraint(equalTo: modalVC.view.widthAnchor, multiplier: 0.86),

            titleLbl.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            titleLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            titleLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            subLbl.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 4),
            subLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            subLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            shareBtn.topAnchor.constraint(equalTo: subLbl.bottomAnchor, constant: 14),
            shareBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            shareBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            shareBtn.heightAnchor.constraint(equalToConstant: 38),

            deleteBtn.topAnchor.constraint(equalTo: shareBtn.bottomAnchor, constant: 8),
            deleteBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            deleteBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            deleteBtn.heightAnchor.constraint(equalToConstant: 38),

            cancelBtn.topAnchor.constraint(equalTo: deleteBtn.bottomAnchor, constant: 8),
            cancelBtn.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            cancelBtn.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            cancelBtn.heightAnchor.constraint(equalToConstant: 38),
            cancelBtn.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        present(modalVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let entry = entries[indexPath.row]
        let deleteAction = UIContextualAction(style: .destructive, title: "Xóa") { _, _, completion in
            FeaturedIPADownloadCenter.shared.deleteDownloadedFile(entry: entry)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - ➕ MÀN HÌNH QUẢN LÝ & THÊM NGUỒN JSON (BÊN PHẢI CHỈ ĐỂ DẤU +)
@MainActor
private final class FeaturedSourcesHubManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSourcesChanged: ((FeaturedRepoSource?) -> Void)?

    private let backgroundView = FeaturedGradientBackgroundView(frame: .zero)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let heroGradientLayer = CAGradientLayer()
    private weak var heroCardRef: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        navigationController?.setNavigationBarHidden(true, animated: false)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 66
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 6
        }
        tableView.contentInset = UIEdgeInsets(top: 6, left: 0, bottom: 24, right: 0)
        view.addSubview(tableView)

        setupScrollableHeroHeader()

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let card = heroCardRef {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            heroGradientLayer.frame = card.bounds
            CATransaction.commit()
        }
    }

    private func setupScrollableHeroHeader() {
        let headerContainer = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 70))
        headerContainer.backgroundColor = .clear

        let heroCard = UIView()
        heroCard.translatesAutoresizingMaskIntoConstraints = false
        heroCard.layer.cornerRadius = 16
        heroCard.layer.shadowColor = FeaturedCSSTheme.blue.cgColor
        heroCard.layer.shadowOffset = CGSize(width: 0, height: 5)
        heroCard.layer.shadowRadius = 12
        heroCard.layer.shadowOpacity = 0.20

        heroGradientLayer.colors = [FeaturedCSSTheme.heroStart, FeaturedCSSTheme.heroEnd]
        heroGradientLayer.startPoint = CGPoint(x: 0, y: 0)
        heroGradientLayer.endPoint = CGPoint(x: 1, y: 1)
        heroGradientLayer.cornerRadius = 16
        heroCard.layer.insertSublayer(heroGradientLayer, at: 0)
        headerContainer.addSubview(heroCard)
        self.heroCardRef = heroCard

        let closeBtn = UIButton(type: .system)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        closeBtn.setTitle("Đóng", for: .normal)
        closeBtn.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
        closeBtn.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        closeBtn.backgroundColor = FeaturedCSSTheme.white
        closeBtn.layer.cornerRadius = 14
        closeBtn.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        heroCard.addSubview(closeBtn)

        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "🗂️ Quản Lý Nguồn App"
        titleLabel.font = UIFont.systemFont(ofSize: 16.5, weight: .heavy)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        heroCard.addSubview(titleLabel)

        let addBtn = UIButton(type: .system)
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addBtn.setTitle("+", for: .normal)
        addBtn.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
        addBtn.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .heavy)
        addBtn.backgroundColor = FeaturedCSSTheme.white
        addBtn.layer.cornerRadius = 14
        addBtn.addTarget(self, action: #selector(promptAddSourceURL), for: .touchUpInside)
        heroCard.addSubview(addBtn)

        NSLayoutConstraint.activate([
            heroCard.topAnchor.constraint(equalTo: headerContainer.topAnchor, constant: 8),
            heroCard.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor, constant: 16),
            heroCard.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor, constant: -16),
            heroCard.bottomAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: -6),

            closeBtn.leadingAnchor.constraint(equalTo: heroCard.leadingAnchor, constant: 12),
            closeBtn.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),
            closeBtn.heightAnchor.constraint(equalToConstant: 28),

            addBtn.trailingAnchor.constraint(equalTo: heroCard.trailingAnchor, constant: -12),
            addBtn.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),
            addBtn.widthAnchor.constraint(equalToConstant: 28),
            addBtn.heightAnchor.constraint(equalToConstant: 28),

            titleLabel.centerXAnchor.constraint(equalTo: heroCard.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: heroCard.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeBtn.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: addBtn.leadingAnchor, constant: -8)
        ])

        tableView.tableHeaderView = headerContainer
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func promptAddSourceURL() {
        let alert = UIAlertController(
            title: "➕ Thêm Nguồn JSON Mới",
            message: "Nhập hoặc dán đường dẫn nguồn .json bạn muốn thêm:",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "https://example.com/repo.json"
            tf.keyboardType = .URL
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            if let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
               clip.lowercased().hasPrefix("http") {
                tf.text = clip
            }
        }
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Thêm Nguồn", style: .default) { [weak self] _ in
            guard let self, let raw = alert.textFields?.first?.text, !raw.isEmpty else { return }
            self.performAddSource(rawURL: raw)
        })
        present(alert, animated: true)
    }

    private func performAddSource(rawURL: String) {
        let loadingAlert = UIAlertController(title: "⏳ Đang kiểm tra nguồn...", message: rawURL, preferredStyle: .alert)
        present(loadingAlert, animated: true)

        Task { @MainActor in
            let result = await FeaturedSmartRepoStoreManager.shared.addAndVerifyCustomSource(rawURLString: rawURL)
            loadingAlert.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let addedSource):
                    self.tableView.reloadData()
                    self.onSourcesChanged?(addedSource)
                    let ok = UIAlertController(
                        title: "✅ Đã thêm nguồn thành công!",
                        message: "Đã nạp nguồn “\(addedSource.displayName)”.",
                        preferredStyle: .alert
                    )
                    ok.addAction(UIAlertAction(title: "Xem ngay", style: .default) { _ in
                        self.dismiss(animated: true)
                    })
                    self.present(ok, animated: true)
                case .failure(let error):
                    let err = UIAlertController(title: "Không thể thêm nguồn", message: error.localizedDescription, preferredStyle: .alert)
                    err.addAction(UIAlertAction(title: "Đóng", style: .cancel))
                    self.present(err, animated: true)
                }
            }
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        FeaturedSmartRepoStoreManager.shared.sources.count
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let container = UIView()
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = "CHẠM ĐỂ XEM RIÊNG • BẬT CÔNG TẮC ĐỂ GỘP CHUNG"
        label.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        label.textColor = FeaturedCSSTheme.primary
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -6),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        28
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = "FeaturedRepoSourceCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        let source = FeaturedSmartRepoStoreManager.shared.sources[indexPath.row]

        cell.backgroundColor = FeaturedCSSTheme.white
        cell.textLabel?.text = source.displayName
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        cell.textLabel?.textColor = FeaturedCSSTheme.pureBlack

        cell.detailTextLabel?.text = source.subtitle
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        cell.detailTextLabel?.textColor = FeaturedCSSTheme.darkGray

        let toggle = UISwitch()
        toggle.isOn = source.isEnabledInAllTab
        toggle.onTintColor = FeaturedCSSTheme.blue
        toggle.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(sourceSwitchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    @objc private func sourceSwitchChanged(_ sender: UISwitch) {
        FeaturedSmartRepoStoreManager.shared.toggleSourceInAllTab(at: sender.tag, enabled: sender.isOn)
        onSourcesChanged?(nil)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let source = FeaturedSmartRepoStoreManager.shared.sources[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.onSourcesChanged?(source)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Xóa") { [weak self] _, _, completion in
            FeaturedSmartRepoStoreManager.shared.removeSource(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self?.onSourcesChanged?(nil)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// ============================================================================
// MARK: - 🚀 FEATUREDVIEWCONTROLLER (MÀN HÌNH CHÍNH ĐỒNG BỘ 100% CSS WEB THEME)
// ============================================================================

class FeaturedViewController: UICollectionViewController, UICollectionViewDelegateFlowLayout
{
    private enum HubFilterSelection: Equatable {
        case allEnabled
        case specificSource(FeaturedRepoSource)
    }

    private lazy var smartHubDataSource: FeaturedSmartHubDataSource = {
        let ds = FeaturedSmartHubDataSource()
        ds.onActionTapped = { [weak self] app in
            self?.handleHubAppPrimaryAction(for: app)
        }
        ds.configureHeader = { [weak self] header in
            self?.bindScrollableHeaderView(header)
        }
        return ds
    }()

    private var currentFilter: HubFilterSelection = .allEnabled
    private var allLoadedHubApps: [FeaturedAppItem] = []
    private var filteredHubApps: [FeaturedAppItem] = []
    private var displayedHubApps: [FeaturedAppItem] = []
    private let pageSize: Int = 60
    private var currentDisplayLimit: Int = 60
    private var currentSearchText: String = ""
    private var isFetchingSources: Bool = false

    private let hubBackgroundView = FeaturedGradientBackgroundView(frame: .zero)
    private weak var activeHeaderView: FeaturedWebScrollHeaderReusableView?

    // MARK: - Lifecycle

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .light
        self.setupSmartHubMode()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.overrideUserInterfaceStyle = .light
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        self.configureCompactNavigationTitle()
        self.refreshVisibleHeaderState()
        self.collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) 
    {
        super.viewDidAppear(animated)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

// ============================================================================
// MARK: - 🛠️ THIẾT LẬP GIAO DIỆN WEB SCROLL (TIÊU ĐỀ + SEARCH LƯỚT THEO TRANG)
// ============================================================================

private extension FeaturedViewController
{
    func configureCompactNavigationTitle()
    {
        self.title = "Kho App Game"
        self.navigationItem.title = "Kho App Game"
        self.tabBarItem.title = "Kho App"
    }

    func setupSmartHubMode()
    {
        configureCompactNavigationTitle()
        self.navigationController?.setNavigationBarHidden(true, animated: false)

        #if !os(tvOS)
        self.navigationItem.searchController = nil
        self.navigationItem.largeTitleDisplayMode = .never
        #endif

        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumLineSpacing = 10
        flowLayout.sectionHeadersPinToVisibleBounds = false
        flowLayout.sectionInset = UIEdgeInsets(top: 4, left: 14, bottom: 28, right: 14)
        self.collectionView.setCollectionViewLayout(flowLayout, animated: false)

        self.collectionView.backgroundView = self.hubBackgroundView
        self.collectionView.backgroundColor = .clear
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.keyboardDismissMode = .onDrag

        self.collectionView.register(
            FeaturedWebScrollHeaderReusableView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: FeaturedWebScrollHeaderReusableView.reuseIdentifier
        )
        self.collectionView.register(
            FeaturedHubAppCollectionViewCell.self,
            forCellWithReuseIdentifier: FeaturedHubAppCollectionViewCell.reuseIdentifier
        )

        self.collectionView.dataSource = self.smartHubDataSource
        self.collectionView.delegate = self
        self.collectionView.prefetchDataSource = nil

        #if !os(tvOS)
        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.forceRefreshCurrentSelection()
        })
        self.collectionView.refreshControl = refreshControl
        #endif

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloadStateChanged(_:)),
            name: FeaturedIPADownloadCenter.stateDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloadProgressChanged(_:)),
            name: FeaturedIPADownloadCenter.progressDidChangeNotification,
            object: nil
        )

        loadAppsForCurrentFilter(forceRefresh: false)
    }

    func bindScrollableHeaderView(_ header: FeaturedWebScrollHeaderReusableView)
    {
        self.activeHeaderView = header
        if !header.searchTextField.isFirstResponder && header.searchTextField.text != self.currentSearchText {
            header.searchTextField.text = self.currentSearchText
        }

        header.onSearchTextChanged = { [weak self] newText in
            guard let self else { return }
            self.currentSearchText = newText
            self.currentDisplayLimit = self.pageSize
            self.applySearchAndPagination(keepSearchFocus: true)
        }

        header.onOpenDownloadsTapped = { [weak self] in
            self?.openDownloadedIPAsManager()
        }
        header.onOpenSourcesTapped = { [weak self] in
            self?.openSourcesHubManager()
        }
        header.onFilterPillTapped = { [weak self] in
            self?.presentQuickSourcePickerSheet()
        }

        refreshVisibleHeaderState()
    }

    func refreshVisibleHeaderState()
    {
        let dlCount = FeaturedIPADownloadCenter.shared.downloadedEntries.count
        let filterText: String
        switch currentFilter {
        case .allEnabled:
            let enabledCount = FeaturedSmartRepoStoreManager.shared.sources.filter { $0.isEnabledInAllTab }.count
            filterText = "🌐 Đang gộp \(enabledCount) nguồn lớn • \(filteredHubApps.count) App/Game"
        case .specificSource(let source):
            filterText = "📌 Nguồn: \(source.displayName) (Chạm để đổi)"
        }

        activeHeaderView?.updateHeaderState(
            isLoading: isFetchingSources,
            filterText: filterText,
            totalAppsCount: filteredHubApps.count,
            downloadedCount: dlCount
        )
    }

    func presentQuickSourcePickerSheet()
    {
        let sheet = UIAlertController(
            title: "🗂️ Chế Độ Hiển Thị Nguồn App",
            message: "Chọn xem gộp tất cả các nguồn hoặc lọc riêng từng kho ứng dụng:",
            preferredStyle: .actionSheet
        )
        sheet.view.tintColor = FeaturedCSSTheme.blue

        sheet.addAction(UIAlertAction(title: "🌐 Tất cả nguồn đang bật (Gộp chung)", style: .default) { [weak self] _ in
            guard let self else { return }
            self.currentFilter = .allEnabled
            self.loadAppsForCurrentFilter(forceRefresh: false)
        })

        for src in FeaturedSmartRepoStoreManager.shared.sources {
            let prefix = (currentFilter == .specificSource(src)) ? "✅ " : "📦 "
            sheet.addAction(UIAlertAction(title: "\(prefix)\(src.displayName)", style: .default) { [weak self] _ in
                guard let self else { return }
                self.currentFilter = .specificSource(src)
                self.loadAppsForCurrentFilter(forceRefresh: false)
            })
        }

        sheet.addAction(UIAlertAction(title: "➕ Quản lý / Thêm nguồn JSON mới...", style: .default) { [weak self] _ in
            self?.openSourcesHubManager()
        })

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = self.view
            popover.sourceRect = CGRect(x: self.view.bounds.midX, y: 100, width: 1, height: 1)
        }
        present(sheet, animated: true)
    }

    @objc func forceRefreshCurrentSelection()
    {
        loadAppsForCurrentFilter(forceRefresh: true)
    }

    func loadAppsForCurrentFilter(forceRefresh: Bool)
    {
        isFetchingSources = true
        refreshVisibleHeaderState()

        switch currentFilter {
        case .allEnabled:
            let enabledSources = FeaturedSmartRepoStoreManager.shared.sources.filter { $0.isEnabledInAllTab }

            Task { @MainActor in
                var combined: [FeaturedAppItem] = []
                for src in enabledSources {
                    let apps = await FeaturedSmartRepoStoreManager.shared.fetchApps(for: src, forceRefresh: forceRefresh)
                    combined.append(contentsOf: apps)
                }

                self.allLoadedHubApps = combined
                self.isFetchingSources = false
                #if !os(tvOS)
                self.collectionView.refreshControl?.endRefreshing()
                #endif
                self.applySearchAndPagination(keepSearchFocus: false)
            }

        case .specificSource(let source):
            Task { @MainActor in
                let apps = await FeaturedSmartRepoStoreManager.shared.fetchApps(for: source, forceRefresh: forceRefresh)
                self.allLoadedHubApps = apps
                self.isFetchingSources = false
                #if !os(tvOS)
                self.collectionView.refreshControl?.endRefreshing()
                #endif
                self.applySearchAndPagination(keepSearchFocus: false)
            }
        }
    }

    func applySearchAndPagination(keepSearchFocus: Bool)
    {
        let wasEditing = keepSearchFocus || (activeHeaderView?.searchTextField.isFirstResponder == true)

        let query = currentSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty {
            filteredHubApps = allLoadedHubApps
        } else {
            filteredHubApps = allLoadedHubApps.filter { app in
                app.name.lowercased().contains(query) ||
                app.bundleIdentifier.lowercased().contains(query) ||
                app.developerName.lowercased().contains(query) ||
                app.sourceName.lowercased().contains(query) ||
                app.localizedDescription.lowercased().contains(query)
            }
        }

        let count = min(currentDisplayLimit, filteredHubApps.count)
        displayedHubApps = Array(filteredHubApps.prefix(count))
        smartHubDataSource.items = displayedHubApps
        refreshVisibleHeaderState()

        UIView.performWithoutAnimation {
            self.collectionView.reloadData()
            self.collectionView.layoutIfNeeded()
        }

        if wasEditing, let tf = self.activeHeaderView?.searchTextField {
            if !tf.isFirstResponder {
                tf.becomeFirstResponder()
            }
        }
    }

    @objc func handleDownloadStateChanged(_ notification: Notification)
    {
        if let errorMsg = notification.userInfo?["error"] as? String {
            let alert = UIAlertController(title: "Lỗi tải file IPA", message: errorMsg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
            present(alert, animated: true)
        }
        refreshVisibleHeaderState()
        collectionView.reloadData()
    }

    @objc func handleDownloadProgressChanged(_ notification: Notification)
    {
        guard let key = notification.userInfo?["key"] as? String,
              let progress = notification.userInfo?["progress"] as? Double else { return }

        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item < displayedHubApps.count else { continue }
            let app = displayedHubApps[indexPath.item]
            if app.downloadURL.absoluteString == key,
               let cell = collectionView.cellForItem(at: indexPath) as? FeaturedHubAppCollectionViewCell {
                cell.updateDownloadState(isDownloaded: false, activeProgress: progress)
            }
        }
    }

    @objc func openDownloadedIPAsManager()
    {
        let vc = FeaturedDownloadedIPAsManagerViewController()
        vc.onSelectSignIPA = { [weak self] entry in
            guard let self else { return }
            let fileURL = FeaturedIPADownloadCenter.shared.localFileURL(for: entry)
            self.switchToMyAppsAndSignIPA(fileURL: fileURL, appName: entry.appName)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.overrideUserInterfaceStyle = .light
        present(nav, animated: true)
    }

    @objc func openSourcesHubManager()
    {
        let vc = FeaturedSourcesHubManagerViewController()
        vc.onSourcesChanged = { [weak self] selectedOrAddedSource in
            guard let self else { return }
            if let source = selectedOrAddedSource {
                self.currentFilter = .specificSource(source)
            } else {
                self.currentFilter = .allEnabled
            }
            self.loadAppsForCurrentFilter(forceRefresh: false)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.overrideUserInterfaceStyle = .light
        present(nav, animated: true)
    }

    func handleHubAppPrimaryAction(for app: FeaturedAppItem)
    {
        if FeaturedIPADownloadCenter.shared.activeProgress(for: app) != nil {
            let alert = UIAlertController(
                title: "Đang tải \(app.name)",
                message: "Bạn có muốn hủy tải file IPA này không?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Tiếp tục tải", style: .cancel))
            alert.addAction(UIAlertAction(title: "Hủy tải", style: .destructive) { _ in
                FeaturedIPADownloadCenter.shared.cancelDownload(for: app)
            })
            present(alert, animated: true)
            return
        }

        if let localURL = FeaturedIPADownloadCenter.shared.localFileURL(for: app) {
            switchToMyAppsAndSignIPA(fileURL: localURL, appName: app.name)
            return
        }

        FeaturedIPADownloadCenter.shared.startDownload(for: app)
    }

    func switchToMyAppsAndSignIPA(fileURL: URL, appName: String)
    {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let alert = UIAlertController(title: "Không tìm thấy file IPA", message: "File IPA đã bị xóa. Vui lòng tải lại.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
            present(alert, animated: true)
            collectionView.reloadData()
            return
        }

        let tempInstallURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileURL.lastPathComponent)
        try? FileManager.default.removeItem(at: tempInstallURL)
        try? FileManager.default.copyItem(at: fileURL, to: tempInstallURL)
        let targetURL = FileManager.default.fileExists(atPath: tempInstallURL.path) ? tempInstallURL : fileURL

        self.tabBarController?.selectedIndex = 3
        NotificationCenter.default.post(name: AppDelegate.importAppDeepLinkNotification, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let appDelegate = UIApplication.shared.delegate {
                _ = appDelegate.application?(UIApplication.shared, open: targetURL, options: [:])
            }
        }
    }
}

// ============================================================================
// MARK: - 📋 COLLECTIONVIEW DELEGATE & FLOW LAYOUT
// ============================================================================

extension FeaturedViewController
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForHeaderInSection section: Int) -> CGSize
    {
        let width = max(collectionView.bounds.width - 28, 280)
        return CGSize(width: width, height: 168)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let width = max(collectionView.bounds.width - 28, 280)
        return CGSize(width: width, height: 118)
    }

    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        if indexPath.item >= self.displayedHubApps.count - 6 && self.displayedHubApps.count < self.filteredHubApps.count {
            self.currentDisplayLimit += self.pageSize
            let newCount = min(self.currentDisplayLimit, self.filteredHubApps.count)
            self.displayedHubApps = Array(self.filteredHubApps.prefix(newCount))
            self.smartHubDataSource.items = self.displayedHubApps
            DispatchQueue.main.async {
                self.collectionView.reloadData()
            }
        }
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        guard indexPath.item < self.displayedHubApps.count else { return }
        let app = self.displayedHubApps[indexPath.item]

        let popupVC = FeaturedAppFullInfoPopupViewController(app: app) { [weak self] in
            self?.handleHubAppPrimaryAction(for: app)
        }
        present(popupVC, animated: true)
    }
}

// ============================================================================
// MARK: - 🔗 GIỮ NGUYÊN @IBSegueAction ĐỂ TƯƠNG THÍCH 100% VỚI MAIN.STORYBOARD
// ============================================================================

private extension FeaturedViewController
{
    @IBSegueAction
    func makeBrowseViewController(_ coder: NSCoder, sender: Any) -> UIViewController?
    {
        if let category = sender as? StoreCategory
        {
            let browseViewController = BrowseViewController(category: category, coder: coder)
            return browseViewController
        }
        else if let source = sender as? Source
        {
            let browseViewController = BrowseViewController(source: source, coder: coder)
            return browseViewController
        }
        else
        {
            let browseViewController = BrowseViewController(coder: coder)
            return browseViewController
        }
    }
    
    @IBSegueAction
    func makeSourceDetailViewController(_ coder: NSCoder, sender: Any?) -> UIViewController?
    {
        guard let source = sender as? Source else { return nil }
        
        let sourceDetailViewController = SourceDetailViewController(source: source, coder: coder)
        return sourceDetailViewController
    }
}
