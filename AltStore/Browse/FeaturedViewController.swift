
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

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% TOÀN HỆ THỐNG)
private struct FeaturedCSSTheme {
    static let white = UIColor.white
    static let pureBlack = UIColor.black                                                 // #000000
    static let darkGray = UIColor(red: 55/255, green: 65/255, blue: 81/255, alpha: 1.0)
    static let light = UIColor(red: 245/255, green: 248/255, blue: 255/255, alpha: 1.0)   // #f5f8ff
    static let border = UIColor(red: 220/255, green: 226/255, blue: 236/255, alpha: 1.0)  // #dce2ec
    static let innerBorder = UIColor(red: 222/255, green: 229/255, blue: 240/255, alpha: 1.0)
    static let blue = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 1.0)      // #007bff
    static let purple = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 1.0)   // #6f42c1
    static let green = UIColor(red: 40/255, green: 167/255, blue: 69/255, alpha: 1.0)     // #28a745
    static let red = UIColor(red: 220/255, green: 53/255, blue: 69/255, alpha: 1.0)       // #dc3545

    static let bgGradientStart = UIColor(red: 243/255, green: 224/255, blue: 255/255, alpha: 1.0).cgColor
    static let bgGradientEnd = UIColor(red: 224/255, green: 247/255, blue: 255/255, alpha: 1.0).cgColor

    static let heroStart = UIColor(red: 0/255, green: 123/255, blue: 255/255, alpha: 0.95).cgColor
    static let heroEnd = UIColor(red: 111/255, green: 66/255, blue: 193/255, alpha: 0.92).cgColor
}

// MARK: - 🌈 LỚP NỀN GRADIENT CỐ ĐỊNH
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

            // 1. Lấy link tải IPA (hỗ trợ cả cấp ngoài, versions[0], trường "down", "url")
            let rawDownloadURL = Self.cleanLink(dict["downloadURL"] as? String)
                ?? Self.cleanLink(latestVersionDict?["downloadURL"] as? String)
                ?? Self.cleanLink(dict["down"] as? String)
                ?? Self.cleanLink(latestVersionDict?["down"] as? String)
                ?? Self.cleanLink(dict["url"] as? String)

            guard let downloadStr = rawDownloadURL, let downloadURL = Self.makeSafeURL(from: downloadStr) else {
                continue
            }

            // 2. Lấy Bundle Identifier
            let rawBundleID = (dict["bundleIdentifier"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["bundleID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["appID"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? ""
            let bundleID = rawBundleID.isEmpty ? "app.sidestore.item.\(idx)" : rawBundleID

            // 3. Lấy Tên App
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

            // 4. Lấy Phiên bản
            let version = (dict["version"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (latestVersionDict?["version"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (dict["absoluteVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? (latestVersionDict?["absoluteVersion"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                ?? "1.0"

            // 5. Lấy Ngày cập nhật
            let dateStr = (dict["versionDate"] as? String)
                ?? (latestVersionDict?["date"] as? String)
                ?? (dict["fullDate"] as? String)
                ?? (dict["date"] as? String)
                ?? ""

            // 6. Lấy Dung lượng
            let sizeBytes: Int64 = Self.parseInt64(dict["size"])
                ?? Self.parseInt64(latestVersionDict?["size"])
                ?? 0

            // 7. Lấy Icon App
            let rawIcon = Self.cleanLink(dict["iconURL"] as? String)
                ?? Self.cleanLink(dict["icon"] as? String)
                ?? repoIcon
            let iconURL = rawIcon != nil ? Self.makeSafeURL(from: rawIcon!) : nil

            // 8. Lấy Nhà phát triển & Mô tả
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

    // MARK: URLSessionDownloadDelegate
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

// MARK: - 🗂️ TRÌNH QUẢN LÝ NGUỒN (7 NGUỒN LỚN NHIỀU APP & GAME CẬP NHẬT LIÊN TỤC)
@MainActor
private final class FeaturedSmartRepoStoreManager {
    static let shared = FeaturedSmartRepoStoreManager()

    private let sourcesStorageKey = "SideStore_VNSourcesOnly_v5"
    private(set) var sources: [FeaturedRepoSource] = []
    private var memoryCache: [String: [FeaturedAppItem]] = [:]

    // ✅ 7 NGUỒN LỚN NHIỀU APP & GAME PHỔ BIẾN, CẬP NHẬT THƯỜNG XUYÊN
    static let defaultLightSources: [FeaturedRepoSource] = [
        FeaturedRepoSource(
            urlString: "https://wuxu1.github.io/wuxu-complete-plus.json",
            displayName: "Kho App Việt Hóa (WuXu++)",
            subtitle: "Tổng hợp Youtube, Locket, Spotify, TikTok, Liên Quân & App Mod cập nhật hàng ngày",
            iconURLString: "https://i.imgur.com/stTk5jP.jpeg",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://ipa.cypwn.xyz/cypwn.json",
            displayName: "Kho App & Game Lớn (CyPwn IPA)",
            subtitle: "Kho hàng ngàn Game & Ứng dụng Mod mở khóa tính năng Pro cập nhật liên tục",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://ipa.nabzclan.vip/repos/altstore.php",
            displayName: "Kho IPA Tổng Hợp (NabzClan)",
            subtitle: "Kho hàng trăm App & Game Mod iOS cập nhật liên tục mỗi ngày",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://quarksources.github.io/quantumsource%2B%2B.json",
            displayName: "Kho Game & Tweaked (Quantum++)",
            subtitle: "Kho ứng dụng mở rộng, giải trí & công cụ tiện ích phong phú",
            iconURLString: "https://quarksources.github.io/assets/ElementQ-Circled.png",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://wuxu1.github.io/wuxu-complete.json",
            displayName: "Kho Ứng Dụng Mở Rộng (WuXu Complete)",
            subtitle: "Bộ sưu tập ứng dụng tiện ích, mạng xã hội & giải trí chuẩn ổn định",
            iconURLString: "https://i.imgur.com/stTk5jP.jpeg",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://burritosoftware.github.io/altstore/channels/burritosource.json",
            displayName: "Kho App Tweaked & Mod (Burrito)",
            subtitle: "Tổng hợp App chỉnh sửa, công cụ mạng xã hội & trò chơi chọn lọc",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        FeaturedRepoSource(
            urlString: "https://community-apps.sidestore.io/sidecommunity.json",
            displayName: "Kho Giả Lập & Công Cụ (SideStore)",
            subtitle: "Tổng hợp trình giả lập Game PPSSPP, Delta, LiveContainer & tiện ích hệ thống",
            iconURLString: "https://sidestore.io/assets/icon.png",
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
            request.timeoutInterval = 18
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
                    if !parsed.repoName.isEmpty && sources[idx].displayName != parsed.repoName && !sources[idx].isBuiltIn {
                        sources[idx].displayName = parsed.repoName
                    }
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

// MARK: - 🃏 CELL HIỂN THỊ ỨNG DỤNG (3 TRẠNG THÁI: TẢI VỀ -> % ĐANG TẢI -> KÝ APP)
private final class FeaturedHubAppCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "FeaturedHubAppCollectionViewCell"

    private let cardView = UIView()
    private let iconImageView = UIImageView()
    private let nameLabel = UILabel()
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
        cardView.layer.cornerRadius = 15
        cardView.layer.borderWidth = 1.0
        cardView.layer.borderColor = FeaturedCSSTheme.border.cgColor
        cardView.layer.shadowColor = FeaturedCSSTheme.blue.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 3)
        cardView.layer.shadowRadius = 8
        cardView.layer.shadowOpacity = 0.06
        contentView.addSubview(cardView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.backgroundColor = FeaturedCSSTheme.light
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 12
        iconImageView.layer.borderWidth = 0.8
        iconImageView.layer.borderColor = FeaturedCSSTheme.innerBorder.cgColor
        iconImageView.clipsToBounds = true
        cardView.addSubview(iconImageView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        nameLabel.textColor = FeaturedCSSTheme.pureBlack
        nameLabel.numberOfLines = 1
        cardView.addSubview(nameLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        metaLabel.textColor = FeaturedCSSTheme.darkGray
        metaLabel.numberOfLines = 1
        cardView.addSubview(metaLabel)

        sourceBadgeView.translatesAutoresizingMaskIntoConstraints = false
        sourceBadgeView.backgroundColor = FeaturedCSSTheme.blue.withAlphaComponent(0.09)
        sourceBadgeView.layer.cornerRadius = 5
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

            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 11),
            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 11),
            iconImageView.widthAnchor.constraint(equalToConstant: 50),
            iconImageView.heightAnchor.constraint(equalToConstant: 50),

            actionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -11),
            actionButton.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 30),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 0),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            metaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            sourceBadgeView.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 3),
            sourceBadgeView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            sourceBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),
            sourceBadgeView.heightAnchor.constraint(equalToConstant: 16),

            sourceBadgeLabel.leadingAnchor.constraint(equalTo: sourceBadgeView.leadingAnchor, constant: 5),
            sourceBadgeLabel.trailingAnchor.constraint(equalTo: sourceBadgeView.trailingAnchor, constant: -5),
            sourceBadgeLabel.centerYAnchor.constraint(equalTo: sourceBadgeView.centerYAnchor),

            descLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 7),
            descLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 11),
            descLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -11),

            progressBarBg.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 11),
            progressBarBg.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -11),
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
        metaLabel.text = "v\(app.version) • \(app.formattedSize) • \(app.developerName)"
        sourceBadgeLabel.text = "📦 \(app.sourceName)"

        let cleanDesc = app.localizedDescription
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        descLabel.text = cleanDesc.isEmpty ? app.bundleIdentifier : cleanDesc

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
            let maxWidth = max(bounds.width - 22, 100)
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

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
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

// MARK: - 🗂️ MÀN HÌNH QUẢN LÝ FILE ĐÃ TẢI VỀ (THANH BAR CÂN ĐỐI, DANH SÁCH ĐẨY SÁT LÊN TRÊN)
@MainActor
private final class FeaturedDownloadedIPAsManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSelectSignIPA: ((FeaturedDownloadedIPAEntry) -> Void)?

    private let backgroundView = FeaturedGradientBackgroundView(frame: .zero)
    private let topBarContainer = UIView()
    private let topTitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let clearAllButton = UIButton(type: .system)
    private let separatorLine = UIView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private var entries: [FeaturedDownloadedIPAEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        navigationController?.setNavigationBarHidden(true, animated: false)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        // Thanh Header cân đối 1 hàng chuẩn iOS: Đóng (trái) - Tiêu đề (giữa, chữ 16pt bold) - Xóa hết (phải)
        topBarContainer.translatesAutoresizingMaskIntoConstraints = false
        topBarContainer.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        view.addSubview(topBarContainer)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Đóng", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        closeButton.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
        closeButton.backgroundColor = FeaturedCSSTheme.blue.withAlphaComponent(0.1)
        closeButton.layer.cornerRadius = 14
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBarContainer.addSubview(closeButton)

        topTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        topTitleLabel.text = "📥 Quản Lý File IPA Đã Tải"
        topTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        topTitleLabel.textColor = FeaturedCSSTheme.pureBlack
        topTitleLabel.textAlignment = .center
        topBarContainer.addSubview(topTitleLabel)

        clearAllButton.translatesAutoresizingMaskIntoConstraints = false
        clearAllButton.setTitle("Xóa hết", for: .normal)
        clearAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
        clearAllButton.setTitleColor(FeaturedCSSTheme.red, for: .normal)
        clearAllButton.backgroundColor = FeaturedCSSTheme.red.withAlphaComponent(0.1)
        clearAllButton.layer.cornerRadius = 14
        clearAllButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 11, bottom: 5, right: 11)
        clearAllButton.addTarget(self, action: #selector(clearAllTapped), for: .touchUpInside)
        topBarContainer.addSubview(clearAllButton)

        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = FeaturedCSSTheme.border
        topBarContainer.addSubview(separatorLine)

        // Đẩy sát danh sách lên ngay dưới thanh tiêu đề
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 66
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 4
        }
        tableView.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 16, right: 0)
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0.01))
        view.addSubview(tableView)

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

            topBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarContainer.heightAnchor.constraint(equalToConstant: 48),

            closeButton.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor, constant: 14),
            closeButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            clearAllButton.trailingAnchor.constraint(equalTo: topBarContainer.trailingAnchor, constant: -14),
            clearAllButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            clearAllButton.heightAnchor.constraint(equalToConstant: 28),

            topTitleLabel.centerXAnchor.constraint(equalTo: topBarContainer.centerXAnchor),
            topTitleLabel.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            topTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 6),
            topTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: clearAllButton.leadingAnchor, constant: -6),

            separatorLine.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: topBarContainer.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: topBarContainer.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.8),

            tableView.topAnchor.constraint(equalTo: topBarContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
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

    @objc private func reloadDataEntries() {
        FeaturedIPADownloadCenter.shared.reloadDownloadedFiles()
        entries = FeaturedIPADownloadCenter.shared.downloadedEntries
        emptyLabel.isHidden = !entries.isEmpty
        clearAllButton.isEnabled = !entries.isEmpty
        clearAllButton.alpha = entries.isEmpty ? 0.35 : 1.0
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
        label.text = "Đã lưu \(entries.count) file IPA • Tổng dung lượng: \(formatter.string(fromByteCount: totalBytes))"
        label.font = UIFont.systemFont(ofSize: 12.5, weight: .bold)
        label.textColor = FeaturedCSSTheme.darkGray
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
        entries.isEmpty ? 0.01 : 26
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
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .medium)
        cell.detailTextLabel?.textColor = FeaturedCSSTheme.darkGray
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
        let fileURL = FeaturedIPADownloadCenter.shared.localFileURL(for: entry)

        let sheet = UIAlertController(
            title: "\(entry.appName) (v\(entry.version))",
            message: "Dung lượng: \(entry.formattedSize)\nFile: \(entry.fileName)",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "✍️ Ký & Cài đặt ngay (Sang Tab Ứng dụng)", style: .default) { [weak self] _ in
            self?.dismiss(animated: true) {
                self?.onSelectSignIPA?(entry)
            }
        })

        sheet.addAction(UIAlertAction(title: "📤 Chia sẻ / Lưu vào Tệp (Files)", style: .default) { [weak self] _ in
            guard let self else { return }
            let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = self.view
                popover.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 1, height: 1)
            }
            self.present(activityVC, animated: true)
        })

        sheet.addAction(UIAlertAction(title: "🗑️ Xóa file IPA này", style: .destructive) { _ in
            FeaturedIPADownloadCenter.shared.deleteDownloadedFile(entry: entry)
        })

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let popover = sheet.popoverPresentationController, let cell = tableView.cellForRow(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(sheet, animated: true)
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

// MARK: - ➕ MÀN HÌNH QUẢN LÝ & THÊM NGUỒN JSON (THANH BAR ĐẸP, DANH SÁCH SÁT LÊN TRÊN)
@MainActor
private final class FeaturedSourcesHubManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSourcesChanged: ((FeaturedRepoSource?) -> Void)?

    private let backgroundView = FeaturedGradientBackgroundView(frame: .zero)
    private let topBarContainer = UIView()
    private let topTitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let addPlusButton = UIButton(type: .system)
    private let separatorLine = UIView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        navigationController?.setNavigationBarHidden(true, animated: false)

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        // Thanh Header chuẩn 1 hàng cân đối: Đóng (trái, 15pt) - Tiêu đề (giữa, 16pt bold) - Nút + (phải, rõ đẹp)
        topBarContainer.translatesAutoresizingMaskIntoConstraints = false
        topBarContainer.backgroundColor = UIColor.white.withAlphaComponent(0.92)
        view.addSubview(topBarContainer)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("Đóng", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        closeButton.setTitleColor(FeaturedCSSTheme.blue, for: .normal)
        closeButton.backgroundColor = FeaturedCSSTheme.blue.withAlphaComponent(0.1)
        closeButton.layer.cornerRadius = 14
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topBarContainer.addSubview(closeButton)

        topTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        topTitleLabel.text = "➕ Quản Lý & Thêm Nguồn App"
        topTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        topTitleLabel.textColor = FeaturedCSSTheme.pureBlack
        topTitleLabel.textAlignment = .center
        topBarContainer.addSubview(topTitleLabel)

        let plusCfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)
        addPlusButton.translatesAutoresizingMaskIntoConstraints = false
        addPlusButton.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: plusCfg), for: .normal)
        addPlusButton.tintColor = FeaturedCSSTheme.blue
        addPlusButton.backgroundColor = FeaturedCSSTheme.blue.withAlphaComponent(0.1)
        addPlusButton.layer.cornerRadius = 15
        addPlusButton.addTarget(self, action: #selector(promptAddSourceURL), for: .touchUpInside)
        topBarContainer.addSubview(addPlusButton)

        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = FeaturedCSSTheme.border
        topBarContainer.addSubview(separatorLine)

        // Đẩy sát danh sách nguồn lên ngay dưới thanh tiêu đề
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 64
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 4
        }
        tableView.contentInset = UIEdgeInsets(top: 2, left: 0, bottom: 16, right: 0)
        tableView.tableHeaderView = UIView(frame: CGRect(x: 0, y: 0, width: 1, height: 0.01))
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            topBarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBarContainer.heightAnchor.constraint(equalToConstant: 48),

            closeButton.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor, constant: 14),
            closeButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 28),

            addPlusButton.trailingAnchor.constraint(equalTo: topBarContainer.trailingAnchor, constant: -14),
            addPlusButton.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            addPlusButton.widthAnchor.constraint(equalToConstant: 34),
            addPlusButton.heightAnchor.constraint(equalToConstant: 30),

            topTitleLabel.centerXAnchor.constraint(equalTo: topBarContainer.centerXAnchor),
            topTitleLabel.centerYAnchor.constraint(equalTo: topBarContainer.centerYAnchor),
            topTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 6),
            topTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: addPlusButton.leadingAnchor, constant: -6),

            separatorLine.leadingAnchor.constraint(equalTo: topBarContainer.leadingAnchor),
            separatorLine.trailingAnchor.constraint(equalTo: topBarContainer.trailingAnchor),
            separatorLine.bottomAnchor.constraint(equalTo: topBarContainer.bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: 0.8),

            tableView.topAnchor.constraint(equalTo: topBarContainer.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
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
        label.text = "DANH SÁCH NGUỒN HIỆN CÓ (CHẠM ĐỂ XEM RIÊNG, GẠT NÚT ĐỂ GỘP CHUNG)"
        label.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        label.textColor = FeaturedCSSTheme.darkGray
        label.numberOfLines = 1
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.85
        container.addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4)
        ])
        return container
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        26
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
// MARK: - 🚀 FEATUREDVIEWCONTROLLER (MÀN HÌNH CHÍNH TỔNG HỢP APP GAME)
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
        return ds
    }()

    private var currentFilter: HubFilterSelection = .allEnabled
    private var allLoadedHubApps: [FeaturedAppItem] = []
    private var filteredHubApps: [FeaturedAppItem] = []
    private var displayedHubApps: [FeaturedAppItem] = []
    private let pageSize: Int = 60
    private var currentDisplayLimit: Int = 60
    private var currentSearchText: String = ""

    // Thành phần UI tinh gọn & thanh thoát
    private let hubBackgroundView = FeaturedGradientBackgroundView(frame: .zero)
    private let hubTopContainer = UIView()
    private let hubHeroCard = UIView()
    private let hubHeroGradient = CAGradientLayer()
    private let hubHeroSubtitleLabel = UILabel()
    private let hubSearchBar = UISearchBar()
    private let hubLoadingSpinner = UIActivityIndicatorView(style: .medium)
    private let hubHeaderHeight: CGFloat = 104

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
        self.configureCompactNavigationTitle()
        self.collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) 
    {
        super.viewDidAppear(animated)
        self.navigationController?.navigationBar.tintColor = FeaturedCSSTheme.blue
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        self.hubHeroGradient.frame = self.hubHeroCard.bounds
    }
}

// ============================================================================
// MARK: - 🛠️ THIẾT LẬP GIAO DIỆN TỔNG HỢP APP GAME TINH GỌN
// ============================================================================

private extension FeaturedViewController
{
    func configureCompactNavigationTitle()
    {
        self.title = "Tổng Hợp App Game"
        self.navigationItem.title = "Tổng Hợp App Game"
        self.tabBarItem.title = "Kho App"

        let titleLabel = UILabel()
        titleLabel.text = "Tổng Hợp App Game"
        titleLabel.font = UIFont.systemFont(ofSize: 17, weight: .bold)
        titleLabel.textColor = FeaturedCSSTheme.pureBlack
        self.navigationItem.titleView = titleLabel
    }

    func setupSmartHubMode()
    {
        configureCompactNavigationTitle()

        #if !os(tvOS)
        self.navigationItem.searchController = nil
        self.navigationItem.largeTitleDisplayMode = .never
        #endif

        // 1. Cấu hình Navigation Bar: Icon Đã tải về (trái) và dấu + (phải) cân đối, sắc nét
        let navIconConfig = UIImage.SymbolConfiguration(pointSize: 16.5, weight: .bold)

        let addBtn = UIButton(type: .system)
        addBtn.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: navIconConfig), for: .normal)
        addBtn.tintColor = FeaturedCSSTheme.blue
        addBtn.backgroundColor = FeaturedCSSTheme.blue.withAlphaComponent(0.1)
        addBtn.layer.cornerRadius = 16
        addBtn.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        addBtn.addTarget(self, action: #selector(openSourcesHubManager), for: .touchUpInside)
        self.navigationItem.rightBarButtonItems = [UIBarButtonItem(customView: addBtn)]

        let dlBtn = UIButton(type: .system)
        dlBtn.setImage(UIImage(systemName: "arrow.down.doc.fill", withConfiguration: navIconConfig), for: .normal)
        dlBtn.tintColor = FeaturedCSSTheme.green
        dlBtn.backgroundColor = FeaturedCSSTheme.green.withAlphaComponent(0.1)
        dlBtn.layer.cornerRadius = 16
        dlBtn.frame = CGRect(x: 0, y: 0, width: 32, height: 32)
        dlBtn.addTarget(self, action: #selector(openDownloadedIPAsManager), for: .touchUpInside)
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: dlBtn)

        // 2. FlowLayout mượt mà, thanh thoát
        let flowLayout = UICollectionViewFlowLayout()
        flowLayout.scrollDirection = .vertical
        flowLayout.minimumLineSpacing = 9
        flowLayout.sectionInset = UIEdgeInsets(top: hubHeaderHeight + 8, left: 14, bottom: 24, right: 14)
        self.collectionView.setCollectionViewLayout(flowLayout, animated: false)

        self.collectionView.backgroundView = self.hubBackgroundView
        self.collectionView.backgroundColor = .clear
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.keyboardDismissMode = .onDrag
        self.collectionView.register(FeaturedHubAppCollectionViewCell.self, forCellWithReuseIdentifier: FeaturedHubAppCollectionViewCell.reuseIdentifier)
        self.collectionView.dataSource = self.smartHubDataSource
        self.collectionView.delegate = self
        self.collectionView.prefetchDataSource = nil

        #if !os(tvOS)
        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.forceRefreshCurrentSelection()
        })
        self.collectionView.refreshControl = refreshControl
        #endif

        // 3. Xây dựng Khung Header Đính Đầu Trang (Gọn gàng, sát lên trên)
        setupSmartHubHeaderView()

        // 4. Lắng nghe sự kiện tải % & hoàn tất IPA
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

        // 5. Nạp danh sách ứng dụng từ 7 nguồn lớn
        loadAppsForCurrentFilter(forceRefresh: false)
    }

    func setupSmartHubHeaderView()
    {
        hubTopContainer.translatesAutoresizingMaskIntoConstraints = false
        hubTopContainer.backgroundColor = UIColor(red: 243/255, green: 236/255, blue: 255/255, alpha: 0.96)
        hubTopContainer.layer.cornerRadius = 16
        hubTopContainer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        hubTopContainer.layer.shadowColor = UIColor.black.cgColor
        hubTopContainer.layer.shadowOffset = CGSize(width: 0, height: 2)
        hubTopContainer.layer.shadowRadius = 6
        hubTopContainer.layer.shadowOpacity = 0.05
        self.view.addSubview(hubTopContainer)

        // Hero Banner sát lên phía trên
        hubHeroCard.translatesAutoresizingMaskIntoConstraints = false
        hubHeroCard.layer.cornerRadius = 14
        hubHeroCard.layer.shadowColor = FeaturedCSSTheme.blue.cgColor
        hubHeroCard.layer.shadowOffset = CGSize(width: 0, height: 3)
        hubHeroCard.layer.shadowRadius = 8
        hubHeroCard.layer.shadowOpacity = 0.16

        hubHeroGradient.colors = [FeaturedCSSTheme.heroStart, FeaturedCSSTheme.heroEnd]
        hubHeroGradient.startPoint = CGPoint(x: 0, y: 0)
        hubHeroGradient.endPoint = CGPoint(x: 1, y: 1)
        hubHeroGradient.cornerRadius = 14
        hubHeroCard.layer.insertSublayer(hubHeroGradient, at: 0)
        hubTopContainer.addSubview(hubHeroCard)

        let heroTitleLabel = UILabel()
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroTitleLabel.text = "📦 Kho App Tinh Gọn"
        heroTitleLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .heavy)
        heroTitleLabel.textColor = .white
        hubHeroCard.addSubview(heroTitleLabel)

        hubHeroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        hubHeroSubtitleLabel.text = "Tải IPA báo % trực tiếp • Tự động chuyển sang Ký App"
        hubHeroSubtitleLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .semibold)
        hubHeroSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        hubHeroCard.addSubview(hubHeroSubtitleLabel)

        hubLoadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        hubLoadingSpinner.color = .white
        hubLoadingSpinner.transform = CGAffineTransform(scaleX: 0.85, y: 0.85)
        hubLoadingSpinner.hidesWhenStopped = true
        hubHeroCard.addSubview(hubLoadingSpinner)

        // Thanh Tìm Kiếm gọn gàng
        hubSearchBar.translatesAutoresizingMaskIntoConstraints = false
        hubSearchBar.placeholder = "Tìm tên ứng dụng, tác giả, Bundle ID..."
        hubSearchBar.searchBarStyle = .minimal
        hubSearchBar.delegate = self
        hubSearchBar.returnKeyType = .done
        if let tf = hubSearchBar.value(forKey: "searchField") as? UITextField {
            tf.backgroundColor = FeaturedCSSTheme.white
            tf.textColor = FeaturedCSSTheme.pureBlack
            tf.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
            tf.layer.cornerRadius = 10
            tf.layer.borderWidth = 0.9
            tf.layer.borderColor = FeaturedCSSTheme.border.cgColor
            tf.clipsToBounds = true
        }
        hubTopContainer.addSubview(hubSearchBar)

        NSLayoutConstraint.activate([
            hubTopContainer.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            hubTopContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hubTopContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            hubTopContainer.heightAnchor.constraint(equalToConstant: hubHeaderHeight),

            hubHeroCard.topAnchor.constraint(equalTo: hubTopContainer.topAnchor, constant: 2),
            hubHeroCard.leadingAnchor.constraint(equalTo: hubTopContainer.leadingAnchor, constant: 14),
            hubHeroCard.trailingAnchor.constraint(equalTo: hubTopContainer.trailingAnchor, constant: -14),
            hubHeroCard.heightAnchor.constraint(equalToConstant: 56),

            heroTitleLabel.topAnchor.constraint(equalTo: hubHeroCard.topAnchor, constant: 9),
            heroTitleLabel.leadingAnchor.constraint(equalTo: hubHeroCard.leadingAnchor, constant: 13),

            hubHeroSubtitleLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: 2),
            hubHeroSubtitleLabel.leadingAnchor.constraint(equalTo: heroTitleLabel.leadingAnchor),
            hubHeroSubtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: hubLoadingSpinner.leadingAnchor, constant: -8),

            hubLoadingSpinner.centerYAnchor.constraint(equalTo: hubHeroCard.centerYAnchor),
            hubLoadingSpinner.trailingAnchor.constraint(equalTo: hubHeroCard.trailingAnchor, constant: -13),

            hubSearchBar.topAnchor.constraint(equalTo: hubHeroCard.bottomAnchor, constant: 4),
            hubSearchBar.leadingAnchor.constraint(equalTo: hubTopContainer.leadingAnchor, constant: 8),
            hubSearchBar.trailingAnchor.constraint(equalTo: hubTopContainer.trailingAnchor, constant: -8),
            hubSearchBar.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    @objc func forceRefreshCurrentSelection()
    {
        loadAppsForCurrentFilter(forceRefresh: true)
    }

    func loadAppsForCurrentFilter(forceRefresh: Bool)
    {
        hubLoadingSpinner.startAnimating()

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
                self.hubLoadingSpinner.stopAnimating()
                #if !os(tvOS)
                self.collectionView.refreshControl?.endRefreshing()
                #endif
                self.applySearchAndPagination()
            }

        case .specificSource(let source):
            Task { @MainActor in
                let apps = await FeaturedSmartRepoStoreManager.shared.fetchApps(for: source, forceRefresh: forceRefresh)
                self.allLoadedHubApps = apps
                self.hubLoadingSpinner.stopAnimating()
                #if !os(tvOS)
                self.collectionView.refreshControl?.endRefreshing()
                #endif
                self.applySearchAndPagination()
            }
        }
    }

    func applySearchAndPagination()
    {
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
        self.collectionView.reloadData()
    }

    @objc func handleDownloadStateChanged(_ notification: Notification)
    {
        if let errorMsg = notification.userInfo?["error"] as? String {
            let alert = UIAlertController(title: "Lỗi tải file IPA", message: errorMsg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
            present(alert, animated: true)
        }
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
        // Trạng thái 1: Nếu đang tải -> Hỏi hủy tải
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

        // Trạng thái 2: Nếu đã tải xong file .ipa -> Nút đang là "✍️ KÝ APP" -> Chuyển ngay sang Tab "Ứng dụng" (My Apps) để ký & cài đặt!
        if let localURL = FeaturedIPADownloadCenter.shared.localFileURL(for: app) {
            switchToMyAppsAndSignIPA(fileURL: localURL, appName: app.name)
            return
        }

        // Trạng thái 3: Chưa tải -> Bắt đầu tải file IPA và hiện %
        FeaturedIPADownloadCenter.shared.startDownload(for: app)
    }

    /// Chuyển giao diện sang Tab 3 ("Ứng dụng" - My Apps) và kích hoạt trình Ký & Cài đặt IPA chuẩn của SideStore
    func switchToMyAppsAndSignIPA(fileURL: URL, appName: String)
    {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let alert = UIAlertController(title: "Không tìm thấy file IPA", message: "File IPA đã bị xóa. Vui lòng tải lại.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
            present(alert, animated: true)
            collectionView.reloadData()
            return
        }

        // 1. Tạo bản sao tạm thời của file IPA để trình cài đặt SideStore xử lý mà không làm mất file gốc trong "File đã tải"
        let tempInstallURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileURL.lastPathComponent)
        try? FileManager.default.removeItem(at: tempInstallURL)
        try? FileManager.default.copyItem(at: fileURL, to: tempInstallURL)
        let targetURL = FileManager.default.fileExists(atPath: tempInstallURL.path) ? tempInstallURL : fileURL

        // 2. Chuyển ngay lập tức sang Tab 3 ("Ứng dụng" - My Apps)
        self.tabBarController?.selectedIndex = 3
        NotificationCenter.default.post(name: AppDelegate.importAppDeepLinkNotification, object: nil)

        // 3. Kích hoạt luồng mở file .ipa chuẩn của SideStore (tự động bật hộp thoại Ký & Cài đặt trong Tab Ứng dụng)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let appDelegate = UIApplication.shared.delegate {
                _ = appDelegate.application?(UIApplication.shared, open: targetURL, options: [:])
            }
        }
    }
}

// ============================================================================
// MARK: - 🔍 UISearchBarDelegate (TÌM KIẾM SIÊU TỐC TRONG KHO APP)
// ============================================================================

extension FeaturedViewController: UISearchBarDelegate
{
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)
    {
        self.currentSearchText = searchText
        self.currentDisplayLimit = self.pageSize
        self.applySearchAndPagination()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar)
    {
        searchBar.resignFirstResponder()
    }
}

// ============================================================================
// MARK: - 📋 COLLECTIONVIEW DELEGATE & FLOW LAYOUT
// ============================================================================

extension FeaturedViewController
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        let width = max(collectionView.bounds.width - 28, 280)
        return CGSize(width: width, height: 104)
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
        let isDownloaded = (FeaturedIPADownloadCenter.shared.localFileURL(for: app) != nil)

        let titleText = "\(app.name) (v\(app.version))"
        let cleanDescription = app.localizedDescription
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let shortDesc = String(cleanDescription.prefix(340))

        let infoBlock = "👤 Tác giả: \(app.developerName)\n🆔 Bundle ID: \(app.bundleIdentifier)\n💾 Dung lượng: \(app.formattedSize)"
        let messageText = shortDesc.isEmpty ? infoBlock : "\(infoBlock)\n\n\(shortDesc)"

        let sheet = UIAlertController(
            title: titleText,
            message: messageText,
            preferredStyle: .actionSheet
        )

        // Cỡ chữ rõ ràng, dễ đọc (Tiêu đề 16.5pt bold, Nội dung 14pt regular)
        let titleAttr = NSAttributedString(
            string: titleText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16.5, weight: .bold),
                .foregroundColor: FeaturedCSSTheme.pureBlack
            ]
        )
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        let messageAttr = NSAttributedString(
            string: "\n" + messageText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: FeaturedCSSTheme.darkGray,
                .paragraphStyle: paragraphStyle
            ]
        )
        sheet.setValue(titleAttr, forKey: "attributedTitle")
        sheet.setValue(messageAttr, forKey: "attributedMessage")

        // Đã bỏ nút "Tải về file IPA (...)" khi chưa tải để bảng thông tin gọn gàng, chỉ hiện nút Ký khi đã tải xong
        if isDownloaded, let localURL = FeaturedIPADownloadCenter.shared.localFileURL(for: app) {
            sheet.addAction(UIAlertAction(title: "✍️ Ký & Cài đặt ngay (Sang Tab Ứng dụng)", style: .default) { [weak self] _ in
                self?.switchToMyAppsAndSignIPA(fileURL: localURL, appName: app.name)
            })
        }

        sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        if let popover = sheet.popoverPresentationController, let cell = collectionView.cellForItem(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(sheet, animated: true)
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
