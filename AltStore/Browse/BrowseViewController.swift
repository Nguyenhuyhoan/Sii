
//
//  BrowseViewController.swift
//  AltStore
//
//  Created by Riley Testut on 7/15/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

@preconcurrency import UIKit
import Combine
import CoreData
@preconcurrency import Nuke

// MARK: - 🎨 BỘ GIAO DIỆN CHUẨN CSS THEME (ĐỒNG BỘ 100% TOÀN HỆ THỐNG)
private struct HubCSSTheme {
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
private final class HubGradientBackgroundView: UIView {
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
        gradientLayer.colors = [HubCSSTheme.bgGradientStart, HubCSSTheme.bgGradientEnd]
        gradientLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
    }
}

// MARK: - 📦 CẤU TRÚC DỮ LIỆU NGUỒN & ỨNG DỤNG ĐA NĂNG (SENDABLE AN TOÀN)
private struct HubRepoSource: Codable, Equatable, Sendable {
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

private struct HubAppItem: Equatable, Sendable {
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

private struct DownloadedIPAEntry: Codable, Equatable, Sendable {
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
private enum UniversalRepoParser {
    static func parse(data: Data, fallbackSource: HubRepoSource) -> (repoName: String, repoIcon: String?, apps: [HubAppItem]) {
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

        var parsedApps: [HubAppItem] = []
        parsedApps.reserveCapacity(min(rawApps.count, 800))

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

            let item = HubAppItem(
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
        return HubRepoSource.cleanURLString(raw.replacingOccurrences(of: "\\/", with: "/"))
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
private final class IPADownloadCenter: NSObject, URLSessionDownloadDelegate {
    static let shared = IPADownloadCenter()

    static let stateDidChangeNotification = Notification.Name("SideStoreHubIPADownloadStateDidChange")
    static let progressDidChangeNotification = Notification.Name("SideStoreHubIPADownloadProgressDidChange")

    struct ActiveDownload {
        let app: HubAppItem
        let task: URLSessionDownloadTask
        var progress: Double
        var receivedBytes: Int64
        var totalBytes: Int64
    }

    private(set) var activeDownloads: [String: ActiveDownload] = [:] // Key: downloadURL.absoluteString
    private var taskKeyMap: [Int: String] = [:]                      // taskIdentifier -> downloadURL.absoluteString
    private(set) var downloadedEntries: [DownloadedIPAEntry] = []

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
        var savedEntries: [DownloadedIPAEntry] = []
        if let data = UserDefaults.standard.data(forKey: metadataStorageKey),
           let decoded = try? JSONDecoder().decode([DownloadedIPAEntry].self, from: data) {
            savedEntries = decoded
        }

        var validEntries: [DownloadedIPAEntry] = []
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
                        DownloadedIPAEntry(
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

    func localFileURL(for app: HubAppItem) -> URL? {
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

    func localFileURL(for entry: DownloadedIPAEntry) -> URL {
        downloadsDirectoryURL.appendingPathComponent(entry.fileName)
    }

    func activeProgress(for app: HubAppItem) -> Double? {
        activeDownloads[app.downloadURL.absoluteString]?.progress
    }

    func startDownload(for app: HubAppItem) {
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

    func cancelDownload(for app: HubAppItem) {
        let key = app.downloadURL.absoluteString
        guard let active = activeDownloads.removeValue(forKey: key) else { return }
        taskKeyMap.removeValue(forKey: active.task.taskIdentifier)
        active.task.cancel()
        NotificationCenter.default.post(name: Self.stateDidChangeNotification, object: nil, userInfo: ["key": key])
    }

    func deleteDownloadedFile(entry: DownloadedIPAEntry) {
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

                let newEntry = DownloadedIPAEntry(
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

// MARK: - 🗂️ TRÌNH QUẢN LÝ NGUỒN TINH GỌN (ĐÃ XOÁ HẲN CÁC NGUỒN NẶNG RA KHỎI MÃ)
@MainActor
private final class SmartRepoStoreManager {
    static let shared = SmartRepoStoreManager()

    private let sourcesStorageKey = "SideStore_LightSourcesOnly_v3"
    private(set) var sources: [HubRepoSource] = []
    private var memoryCache: [String: [HubAppItem]] = [:] // Key: normalizedID

    // Danh sách các nguồn nặng bị loại bỏ hoàn toàn
    private static let bannedHeavyDomains: [String] = [
        "apptesters.org",
        "fastsign.dev",
        "cypwn.xyz"
    ]

    // ✅ CHỈ GIỮ LẠI 5 NGUỒN NHẸ, TỐC ĐỘ CAO, CHẤT LƯỢNG NHẤT
    static let defaultLightSources: [HubRepoSource] = [
        HubRepoSource(
            urlString: "https://community-apps.sidestore.io/sidecommunity.json",
            displayName: "SideStore Picks",
            subtitle: "Kho ứng dụng chọn lọc chính thức của SideStore",
            iconURLString: "https://sidestore.io/assets/icon.png",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        HubRepoSource(
            urlString: "https://quarksources.github.io/quantumsource.json",
            displayName: "Quantum Source",
            subtitle: "Giả lập, công cụ & tiện ích chuẩn AltStore v2",
            iconURLString: "https://quarksources.github.io/assets/ElementQ-Circled.png",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        HubRepoSource(
            urlString: "https://quarksources.github.io/quantumsource%2B%2B.json",
            displayName: "Quantum++",
            subtitle: "Ứng dụng tinh chỉnh, giải trí & tiện ích mở rộng",
            iconURLString: "https://quarksources.github.io/assets/ElementQ-Circled.png",
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        HubRepoSource(
            urlString: "https://getaccretion.github.io/source.json",
            displayName: "Accretion",
            subtitle: "Kho ứng dụng & trình giả lập gọn nhẹ",
            iconURLString: nil,
            isEnabledInAllTab: true,
            isBuiltIn: true
        ),
        HubRepoSource(
            urlString: "https://wuxu1.github.io/wuxu-complete-plus.json",
            displayName: "WuXu's Library++",
            subtitle: "Tổng hợp LiveContainer, uYouEnhanced & Tweaked Apps",
            iconURLString: "https://i.imgur.com/stTk5jP.jpeg",
            isEnabledInAllTab: true,
            isBuiltIn: true
        )
    ]

    private init() {
        loadSavedSources()
    }

    private func loadSavedSources() {
        if let data = UserDefaults.standard.data(forKey: sourcesStorageKey),
           let decoded = try? JSONDecoder().decode([HubRepoSource].self, from: data),
           !decoded.isEmpty {
            var cleaned = decoded.filter { src in
                !Self.bannedHeavyDomains.contains(where: { src.normalizedID.contains($0) })
            }
            for preset in Self.defaultLightSources {
                if !cleaned.contains(where: { $0.normalizedID == preset.normalizedID }) {
                    cleaned.append(preset)
                }
            }
            self.sources = cleaned
            saveSources()
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

    func cachedApps(for source: HubRepoSource) -> [HubAppItem]? {
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

    func resetToDefaults() {
        memoryCache.removeAll()
        sources = Self.defaultLightSources
        saveSources()
    }

    func addAndVerifyCustomSource(rawURLString: String) async -> Result<HubRepoSource, Error> {
        let cleaned = HubRepoSource.cleanURLString(rawURLString)
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

        let tempSource = HubRepoSource(
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
                UniversalRepoParser.parse(data: data, fallbackSource: tempSource)
            }.value

            guard !parsed.apps.isEmpty else {
                throw NSError(domain: "SmartRepo", code: 422, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy ứng dụng hợp lệ trong đường dẫn JSON này."])
            }

            let finalSource = HubRepoSource(
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

    func fetchApps(for source: HubRepoSource, forceRefresh: Bool = false) async -> [HubAppItem] {
        let id = source.normalizedID
        if !forceRefresh, let cached = memoryCache[id], !cached.isEmpty {
            return cached
        }

        let cleaned = HubRepoSource.cleanURLString(source.urlString)
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
                UniversalRepoParser.parse(data: data, fallbackSource: source)
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
private final class HubAppCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "HubAppCollectionViewCell"

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
        cardView.backgroundColor = HubCSSTheme.white
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1.1
        cardView.layer.borderColor = HubCSSTheme.border.cgColor
        cardView.layer.shadowColor = HubCSSTheme.blue.cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOpacity = 0.07
        contentView.addSubview(cardView)

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.backgroundColor = HubCSSTheme.light
        iconImageView.contentMode = .scaleAspectFill
        iconImageView.layer.cornerRadius = 13
        iconImageView.layer.borderWidth = 0.8
        iconImageView.layer.borderColor = HubCSSTheme.innerBorder.cgColor
        iconImageView.clipsToBounds = true
        cardView.addSubview(iconImageView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 15.5, weight: .bold)
        nameLabel.textColor = HubCSSTheme.pureBlack
        nameLabel.numberOfLines = 1
        cardView.addSubview(nameLabel)

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        metaLabel.textColor = HubCSSTheme.darkGray
        metaLabel.numberOfLines = 1
        cardView.addSubview(metaLabel)

        sourceBadgeView.translatesAutoresizingMaskIntoConstraints = false
        sourceBadgeView.backgroundColor = HubCSSTheme.blue.withAlphaComponent(0.10)
        sourceBadgeView.layer.cornerRadius = 6
        sourceBadgeView.layer.borderWidth = 0.8
        sourceBadgeView.layer.borderColor = HubCSSTheme.blue.withAlphaComponent(0.25).cgColor
        cardView.addSubview(sourceBadgeView)

        sourceBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        sourceBadgeLabel.font = UIFont.systemFont(ofSize: 10.5, weight: .bold)
        sourceBadgeLabel.textColor = HubCSSTheme.blue
        sourceBadgeView.addSubview(sourceBadgeLabel)

        descLabel.translatesAutoresizingMaskIntoConstraints = false
        descLabel.font = UIFont.systemFont(ofSize: 12.5, weight: .regular)
        descLabel.textColor = HubCSSTheme.darkGray
        descLabel.numberOfLines = 2
        cardView.addSubview(descLabel)

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 12.5, weight: .heavy)
        actionButton.layer.cornerRadius = 16
        actionButton.contentEdgeInsets = UIEdgeInsets(top: 7, left: 13, bottom: 7, right: 13)
        actionButton.addTarget(self, action: #selector(handleActionButtonTapped), for: .touchUpInside)
        cardView.addSubview(actionButton)

        progressBarBg.translatesAutoresizingMaskIntoConstraints = false
        progressBarBg.backgroundColor = HubCSSTheme.blue.withAlphaComponent(0.12)
        progressBarBg.layer.cornerRadius = 2.5
        progressBarBg.clipsToBounds = true
        progressBarBg.isHidden = true
        cardView.addSubview(progressBarBg)

        progressBarFill.translatesAutoresizingMaskIntoConstraints = false
        progressBarFill.backgroundColor = HubCSSTheme.blue
        progressBarFill.layer.cornerRadius = 2.5
        progressBarBg.addSubview(progressBarFill)

        progressWidthConstraint = progressBarFill.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconImageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconImageView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 54),
            iconImageView.heightAnchor.constraint(equalToConstant: 54),

            actionButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            actionButton.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 33),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96),

            nameLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 1),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 11),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            metaLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),

            sourceBadgeView.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 4),
            sourceBadgeView.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            sourceBadgeView.trailingAnchor.constraint(lessThanOrEqualTo: actionButton.leadingAnchor, constant: -8),
            sourceBadgeView.heightAnchor.constraint(equalToConstant: 18),

            sourceBadgeLabel.leadingAnchor.constraint(equalTo: sourceBadgeView.leadingAnchor, constant: 6),
            sourceBadgeLabel.trailingAnchor.constraint(equalTo: sourceBadgeView.trailingAnchor, constant: -6),
            sourceBadgeLabel.centerYAnchor.constraint(equalTo: sourceBadgeView.centerYAnchor),

            descLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 8),
            descLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            descLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),

            progressBarBg.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            progressBarBg.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12),
            progressBarBg.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -6),
            progressBarBg.heightAnchor.constraint(equalToConstant: 5),

            progressBarFill.leadingAnchor.constraint(equalTo: progressBarBg.leadingAnchor),
            progressBarFill.topAnchor.constraint(equalTo: progressBarBg.topAnchor),
            progressBarFill.bottomAnchor.constraint(equalTo: progressBarBg.bottomAnchor),
            progressWidthConstraint
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconImageView.image = UIImage(systemName: "app.fill")?.withTintColor(HubCSSTheme.blue.withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
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

    func configure(with app: HubAppItem, isDownloaded: Bool, activeProgress: Double?) {
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

        iconImageView.image = UIImage(systemName: "app.badge.fill")?.withTintColor(HubCSSTheme.blue.withAlphaComponent(0.35), renderingMode: .alwaysOriginal)
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
            actionButton.setTitleColor(HubCSSTheme.blue, for: .normal)
            actionButton.backgroundColor = HubCSSTheme.blue.withAlphaComponent(0.14)
            actionButton.layer.borderWidth = 1.2
            actionButton.layer.borderColor = HubCSSTheme.blue.withAlphaComponent(0.45).cgColor

            progressBarBg.isHidden = false
            let maxWidth = max(bounds.width - 24, 100)
            progressWidthConstraint.constant = maxWidth * CGFloat(min(max(progress, 0.03), 1.0))
        } else if isDownloaded {
            actionButton.setTitle("✍️ KÝ APP", for: .normal)
            actionButton.setTitleColor(HubCSSTheme.white, for: .normal)
            actionButton.backgroundColor = HubCSSTheme.green
            actionButton.layer.borderWidth = 0
            progressBarBg.isHidden = true
        } else {
            actionButton.setTitle("⬇️ TẢI VỀ", for: .normal)
            actionButton.setTitleColor(HubCSSTheme.white, for: .normal)
            actionButton.backgroundColor = HubCSSTheme.blue
            actionButton.layer.borderWidth = 0
            progressBarBg.isHidden = true
        }
    }
}

// MARK: - 📋 DATASOURCE RIÊNG CHO SMART HUB (TRÁNH XUNG ĐỘT AMBIGUOUS VỚI COREDATA DATASOURCE)
@MainActor
private final class SmartHubCollectionDataSource: NSObject, UICollectionViewDataSource {
    var items: [HubAppItem] = []
    var onActionTapped: ((HubAppItem) -> Void)?

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: HubAppCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! HubAppCollectionViewCell

        let app = items[indexPath.item]
        let isDownloaded = (IPADownloadCenter.shared.localFileURL(for: app) != nil)
        let progress = IPADownloadCenter.shared.activeProgress(for: app)

        cell.configure(with: app, isDownloaded: isDownloaded, activeProgress: progress)
        cell.onActionTapped = { [weak self] in
            self?.onActionTapped?(app)
        }
        return cell
    }
}

// MARK: - 🗂️ MÀN HÌNH QUẢN LÝ FILE ĐÃ TẢI VỀ (KHO IPA OFFLINE)
@MainActor
private final class DownloadedIPAsManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSelectSignIPA: ((DownloadedIPAEntry) -> Void)?

    private let backgroundView = HubGradientBackgroundView(frame: .zero)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyLabel = UILabel()
    private var entries: [DownloadedIPAEntry] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        title = "📥 Quản Lý File IPA Đã Tải"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Đóng",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Xóa tất cả",
            style: .plain,
            target: self,
            action: #selector(clearAllTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = HubCSSTheme.red

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 76
        view.addSubview(tableView)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.text = "Chưa có file IPA nào được tải về.\nHãy bấm “⬇️ TẢI VỀ” ở ngoài Kho App để lưu IPA vào đây!"
        emptyLabel.font = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
        emptyLabel.textColor = HubCSSTheme.darkGray
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        view.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
            name: IPADownloadCenter.stateDidChangeNotification,
            object: nil
        )
        reloadDataEntries()
    }

    @objc private func reloadDataEntries() {
        IPADownloadCenter.shared.reloadDownloadedFiles()
        entries = IPADownloadCenter.shared.downloadedEntries
        emptyLabel.isHidden = !entries.isEmpty
        navigationItem.rightBarButtonItem?.isEnabled = !entries.isEmpty
        tableView.reloadData()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func clearAllTapped() {
        let alert = UIAlertController(
            title: "Xóa tất cả file IPA?",
            message: "Toàn bộ các file .ipa đã tải trong bộ nhớ Kho App sẽ bị xóa để giải phóng dung lượng.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        alert.addAction(UIAlertAction(title: "Xóa tất cả", style: .destructive) { _ in
            IPADownloadCenter.shared.deleteAllDownloadedFiles()
        })
        present(alert, animated: true)
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard !entries.isEmpty else { return nil }
        let totalBytes = entries.reduce(Int64(0)) { $0 + $1.fileSize }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return "Đã lưu \(entries.count) file IPA • Tổng dung lượng: \(formatter.string(fromByteCount: totalBytes))"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellId = "DownloadedIPACell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        let entry = entries[indexPath.row]

        cell.backgroundColor = HubCSSTheme.white
        cell.textLabel?.text = "\(entry.appName) (v\(entry.version))"
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        cell.textLabel?.textColor = HubCSSTheme.pureBlack

        cell.detailTextLabel?.text = "\(entry.formattedSize) • \(entry.sourceName) • \(entry.bundleIdentifier)"
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        cell.detailTextLabel?.textColor = HubCSSTheme.darkGray
        cell.imageView?.image = UIImage(systemName: "doc.zipper")?.withTintColor(HubCSSTheme.blue, renderingMode: .alwaysOriginal)

        let signBtn = UIButton(type: .system)
        signBtn.setTitle("✍️ KÝ APP", for: .normal)
        signBtn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        signBtn.setTitleColor(.white, for: .normal)
        signBtn.backgroundColor = HubCSSTheme.green
        signBtn.layer.cornerRadius = 14
        signBtn.frame = CGRect(x: 0, y: 0, width: 92, height: 30)
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
        let fileURL = IPADownloadCenter.shared.localFileURL(for: entry)

        let sheet = UIAlertController(
            title: "\(entry.appName) (v\(entry.version))",
            message: "Dung lượng: \(entry.formattedSize)\nFile: \(entry.fileName)",
            preferredStyle: .actionSheet
        )

        sheet.addAction(UIAlertAction(title: "✍️ Ký & Cài đặt ngay (Chuyển sang Tab Ứng dụng)", style: .default) { [weak self] _ in
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
            IPADownloadCenter.shared.deleteDownloadedFile(entry: entry)
        })

        sheet.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        if let popover = sheet.popoverPresentationController, let cell = tableView.cellForRow(at: indexPath) {
            popover.sourceView = cell
            popover.sourceRect = cell.bounds
        }
        present(sheet, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let entry = entries[indexPath.row]
        let deleteAction = UIContextualAction(style: .destructive, title: "Xóa") { _, _, completion in
            IPADownloadCenter.shared.deleteDownloadedFile(entry: entry)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// MARK: - ➕ MÀN HÌNH QUẢN LÝ & THÊM NGUỒN JSON (DẤU + TRÊN CÙNG BÊN PHẢI)
@MainActor
private final class SourcesHubManagerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    var onSourcesChanged: ((HubRepoSource?) -> Void)?

    private let backgroundView = HubGradientBackgroundView(frame: .zero)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        title = "➕ Quản Lý & Thêm Nguồn App"

        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Đóng",
            style: .done,
            target: self,
            action: #selector(closeTapped)
        )

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(promptAddSourceURL)
        )

        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backgroundView)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 66
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
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
            message: "Hỗ trợ mọi định dạng JSON: AltStore v1/v2, SideStore, ESign, Scarlet, Feather, WuXu...",
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
            let result = await SmartRepoStoreManager.shared.addAndVerifyCustomSource(rawURLString: rawURL)
            loadingAlert.dismiss(animated: true) { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let addedSource):
                    self.tableView.reloadData()
                    self.onSourcesChanged?(addedSource)
                    let ok = UIAlertController(
                        title: "✅ Đã thêm nguồn thành công!",
                        message: "Đã nạp nguồn “\(addedSource.displayName)” vào Kho App.",
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
        2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return 2 }
        return SmartRepoStoreManager.shared.sources.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "THÊM NGUỒN MỚI"
        }
        return "DANH SÁCH NGUỒN HIỆN CÓ (CHẠM ĐỂ XEM RIÊNG, GẠT NÚT ĐỂ GỘP CHUNG)"
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return "✨ Đã tối ưu hóa: Chỉ giữ các nguồn tinh gọn tốc độ cao giúp ứng dụng hoạt động mượt mà, không gây tốn RAM."
        }
        return nil
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
            cell.backgroundColor = HubCSSTheme.white
            if indexPath.row == 0 {
                cell.textLabel?.text = "➕ Nhập hoặc Dán Link Nguồn JSON..."
                cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
                cell.textLabel?.textColor = HubCSSTheme.blue
                cell.detailTextLabel?.text = "Tự động nhận diện mọi chuẩn Repo JSON"
                cell.accessoryType = .disclosureIndicator
            } else {
                cell.textLabel?.text = "🔄 Khôi phục 5 Nguồn Tinh Gọn Mặc Định"
                cell.textLabel?.font = UIFont.systemFont(ofSize: 14.5, weight: .semibold)
                cell.textLabel?.textColor = HubCSSTheme.purple
                cell.detailTextLabel?.text = "SideStore Picks, Quantum, Quantum++, Accretion, WuXu++"
            }
            return cell
        }

        let cellId = "RepoSourceCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellId) ?? UITableViewCell(style: .subtitle, reuseIdentifier: cellId)
        let source = SmartRepoStoreManager.shared.sources[indexPath.row]

        cell.backgroundColor = HubCSSTheme.white
        cell.textLabel?.text = source.displayName
        cell.textLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        cell.textLabel?.textColor = HubCSSTheme.pureBlack

        cell.detailTextLabel?.text = source.subtitle
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        cell.detailTextLabel?.textColor = HubCSSTheme.darkGray

        let toggle = UISwitch()
        toggle.isOn = source.isEnabledInAllTab
        toggle.onTintColor = HubCSSTheme.blue
        toggle.tag = indexPath.row
        toggle.addTarget(self, action: #selector(sourceSwitchChanged(_:)), for: .valueChanged)
        cell.accessoryView = toggle

        return cell
    }

    @objc private func sourceSwitchChanged(_ sender: UISwitch) {
        SmartRepoStoreManager.shared.toggleSourceInAllTab(at: sender.tag, enabled: sender.isOn)
        onSourcesChanged?(nil)
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            if indexPath.row == 0 {
                promptAddSourceURL()
            } else {
                SmartRepoStoreManager.shared.resetToDefaults()
                tableView.reloadData()
                onSourcesChanged?(nil)
            }
            return
        }

        let source = SmartRepoStoreManager.shared.sources[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.onSourcesChanged?(source)
        }
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.section == 1 else { return nil }
        let deleteAction = UIContextualAction(style: .destructive, title: "Xóa") { [weak self] _, _, completion in
            SmartRepoStoreManager.shared.removeSource(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self?.onSourcesChanged?(nil)
            completion(true)
        }
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}

// ============================================================================
// MARK: - 🚀 BROWSEVIEWCONTROLLER (TÍCH HỢP KHO APP THÔNG MINH + GIỮ NGUYÊN ABI GỐC)
// ============================================================================

class BrowseViewController: UICollectionViewController
{
    // Nil == Show apps from all sources.
    let source: Source?
    
    private(set) var category: StoreCategory? {
        didSet {
            guard !self.isSmartHubMode else { return }
            self.updateDataSource()
            self.update()
        }
    }
    
    var searchPredicate: NSPredicate? {
        didSet {
            guard !self.isSmartHubMode else { return }
            self.updateDataSource()
        }
    }
    
    private lazy var dataSource = self.makeDataSource()
    private lazy var placeholderView = PlaceholderView(frame: .zero)
    
    private let prototypeCell = AppCardCollectionViewCell(frame: .zero)
    private var sortButton: UIBarButtonItem?
    
    private var preferredAppSorting: AppSorting = UserDefaults.standard.preferredAppSorting
    
    private var cancellables = Set<AnyCancellable>()
    
    private var titleStackView: UIStackView!
    private var titleSourceIconView: AppIconImageView!
    private var titleCategoryIconView: UIImageView!
    private var titleLabel: UILabel!
    
    init?(source: Source?, coder: NSCoder)
    {
        self.source = source
        self.category = nil
        
        super.init(coder: coder)
    }
    
    init?(category: StoreCategory?, coder: NSCoder)
    {
        self.source = nil
        self.category = category
        
        super.init(coder: coder)
    }
    
    required init?(coder: NSCoder)
    {
        self.source = nil
        self.category = nil
        
        super.init(coder: coder)
    }
    
    private var cachedItemSizes = [String: CGSize]()
    
    @IBOutlet private var sourcesBarButtonItem: UIBarButtonItem!

    // MARK: - 🌟 Trạng thái Kho App Thông Minh (Smart Hub Mode)
    private var isSmartHubMode: Bool {
        return self.source == nil && self.category == nil && self.searchPredicate == nil
    }

    private enum HubFilterSelection: Equatable {
        case allEnabled
        case specificSource(HubRepoSource)
    }

    private lazy var smartHubDataSource: SmartHubCollectionDataSource = {
        let ds = SmartHubCollectionDataSource()
        ds.onActionTapped = { [weak self] app in
            self?.handleHubAppPrimaryAction(for: app)
        }
        return ds
    }()

    private var currentFilter: HubFilterSelection = .allEnabled
    private var allLoadedHubApps: [HubAppItem] = []
    private var filteredHubApps: [HubAppItem] = []
    private var displayedHubApps: [HubAppItem] = []
    private let pageSize: Int = 60
    private var currentDisplayLimit: Int = 60
    private var currentSearchText: String = ""

    // Thành phần UI của Kho App Thông Minh
    private let hubBackgroundView = HubGradientBackgroundView(frame: .zero)
    private let hubTopContainer = UIView()
    private let hubHeroCard = UIView()
    private let hubHeroGradient = CAGradientLayer()
    private let hubHeroSubtitleLabel = UILabel()
    private let hubDownloadedFilesButton = UIButton(type: .system)
    private let hubQuickAddSourceButton = UIButton(type: .system)
    private let hubSearchBar = UISearchBar()
    private let hubChipsScrollView = UIScrollView()
    private let hubChipsStackView = UIStackView()
    private let hubStatusBannerLabel = UILabel()
    private let hubLoadingSpinner = UIActivityIndicatorView(style: .medium)
    private let hubHeaderHeight: CGFloat = 212

    // MARK: - Lifecycle

    override func viewDidLoad()
    {
        super.viewDidLoad()
        self.overrideUserInterfaceStyle = .light

        if self.isSmartHubMode
        {
            self.setupSmartHubMode()
            return
        }

        // Chế độ CoreData gốc
        self.collectionView.backgroundColor = .altBackground
        self.collectionView.alwaysBounceVertical = true
        
        self.dataSource.searchableKeyPaths = [#keyPath(StoreApp.name),
                                               #keyPath(StoreApp.subtitle),
                                               #keyPath(StoreApp.developerName),
                                               #keyPath(StoreApp.bundleIdentifier)]
        #if !os(tvOS)
        self.navigationItem.searchController = self.dataSource.searchController
        #endif
        
        self.prototypeCell.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        self.collectionView.register(AppCardCollectionViewCell.self, forCellWithReuseIdentifier: CellContentGenericCellIdentifier)
        
        self.collectionView.dataSource = self.dataSource
        self.collectionView.prefetchDataSource = self.dataSource
        self.dataSource.contentView = self.collectionView
        
        let collectionViewLayout = self.collectionViewLayout as! UICollectionViewFlowLayout
        collectionViewLayout.minimumLineSpacing = 30
        
        #if !os(tvOS)
        self.registerForPreviewing(with: self, sourceView: self.collectionView)
        
        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.updateSources()
        })
        self.collectionView.refreshControl = refreshControl
        #endif
        
        #if !os(tvOS)
        if self.category != nil, #available(iOS 16, *)
        {
            let categoriesMenu = UIMenu(children: [
                UIDeferredMenuElement.uncached { [weak self] completion in
                    let actions = self?.makeCategoryActions() ?? []
                    completion(actions)
                }
            ])
            
            self.navigationItem.titleMenuProvider = { _ in categoriesMenu }
        }
        #endif
        
        self.titleSourceIconView = AppIconImageView(style: .circular)
        
        self.titleCategoryIconView = UIImageView(frame: .zero)
        self.titleCategoryIconView.contentMode = .scaleAspectFit
        
        self.titleLabel = UILabel()
        self.titleLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        
        self.titleStackView = UIStackView(arrangedSubviews: [self.titleSourceIconView, self.titleCategoryIconView, self.titleLabel])
        self.titleStackView.spacing = 4
        self.titleStackView.translatesAutoresizingMaskIntoConstraints = false
        
        #if !os(tvOS)
        self.navigationItem.largeTitleDisplayMode = .never
        
        if #available(iOS 16, *)
        {
            self.navigationItem.preferredSearchBarPlacement = .automatic
        }
        #endif
        
        self.prepareAppSorting()
        
        self.preparePipeline()
        
        NSLayoutConstraint.activate([
            self.titleSourceIconView.heightAnchor.constraint(equalToConstant: 26),
            self.titleSourceIconView.widthAnchor.constraint(equalTo: self.titleSourceIconView.heightAnchor),
            self.titleCategoryIconView.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        self.updateDataSource()
        self.update()
    }
    
    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        self.overrideUserInterfaceStyle = .light

        if self.isSmartHubMode
        {
            self.title = "Kho App"
            self.navigationItem.title = "Kho App"
            self.tabBarItem.title = "Kho App"
            self.refreshDownloadedFilesCountBadge()
            self.collectionView.reloadData()
            return
        }
        
        self.update()
    }
    
    override func viewDidDisappear(_ animated: Bool) 
    {
        super.viewDidDisappear(animated)
        
        if !self.isSmartHubMode {
            self.navigationController?.navigationBar.tintColor = nil
        }
    }

    override func viewDidLayoutSubviews()
    {
        super.viewDidLayoutSubviews()
        if self.isSmartHubMode {
            self.hubHeroGradient.frame = self.hubHeroCard.bounds
        }
    }
}

// ============================================================================
// MARK: - 🛠️ THIẾT LẬP GIAO DIỆN & CHỨC NĂNG KHO APP THÔNG MINH (SMART HUB MODE)
// ============================================================================

private extension BrowseViewController
{
    func setupSmartHubMode()
    {
        self.title = "Kho App"
        self.navigationItem.title = "Kho App"
        self.tabBarItem.title = "Kho App"
        self.navigationItem.largeTitleDisplayMode = .never

        // 1. Cấu hình Navigation Bar: Dấu "+" góc trên bên phải để thêm nguồn & Nút "File đã tải" bên trái
        let addSourceBarBtn = UIBarButtonItem(
            image: UIImage(systemName: "plus.circle.fill"),
            style: .plain,
            target: self,
            action: #selector(openSourcesHubManager)
        )
        addSourceBarBtn.tintColor = HubCSSTheme.blue

        let refreshBarBtn = UIBarButtonItem(
            image: UIImage(systemName: "arrow.clockwise"),
            style: .plain,
            target: self,
            action: #selector(forceRefreshCurrentSelection)
        )
        refreshBarBtn.tintColor = HubCSSTheme.purple

        let downloadsBarBtn = UIBarButtonItem(
            image: UIImage(systemName: "arrow.down.doc.fill"),
            style: .plain,
            target: self,
            action: #selector(openDownloadedIPAsManager)
        )
        downloadsBarBtn.tintColor = HubCSSTheme.green

        self.navigationItem.rightBarButtonItems = [addSourceBarBtn, refreshBarBtn]
        self.navigationItem.leftBarButtonItem = downloadsBarBtn

        // 2. Cấu hình Nền Gradient & CollectionView với SmartHubCollectionDataSource riêng biệt
        self.collectionView.backgroundView = self.hubBackgroundView
        self.collectionView.backgroundColor = .clear
        self.collectionView.alwaysBounceVertical = true
        self.collectionView.keyboardDismissMode = .onDrag
        self.collectionView.register(HubAppCollectionViewCell.self, forCellWithReuseIdentifier: HubAppCollectionViewCell.reuseIdentifier)
        self.collectionView.dataSource = self.smartHubDataSource
        self.collectionView.delegate = self
        self.collectionView.prefetchDataSource = nil

        if let flow = self.collectionViewLayout as? UICollectionViewFlowLayout {
            flow.minimumLineSpacing = 10
            flow.sectionInset = UIEdgeInsets(top: hubHeaderHeight + 10, left: 14, bottom: 28, right: 14)
        }

        let refreshControl = UIRefreshControl(frame: .zero, primaryAction: UIAction { [weak self] _ in
            self?.forceRefreshCurrentSelection()
        })
        self.collectionView.refreshControl = refreshControl

        // 3. Xây dựng Khung Header Đính Đầu Trang
        setupSmartHubHeaderView()

        // 4. Lắng nghe sự kiện tải % & hoàn tất IPA
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloadStateChanged(_:)),
            name: IPADownloadCenter.stateDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDownloadProgressChanged(_:)),
            name: IPADownloadCenter.progressDidChangeNotification,
            object: nil
        )

        // 5. Nạp danh sách Chip nguồn & tải 5 nguồn nhẹ mặc định
        rebuildSourceChipsBar()
        refreshDownloadedFilesCountBadge()
        loadAppsForCurrentFilter(forceRefresh: false)
    }

    func setupSmartHubHeaderView()
    {
        hubTopContainer.translatesAutoresizingMaskIntoConstraints = false
        hubTopContainer.backgroundColor = UIColor(red: 243/255, green: 236/255, blue: 255/255, alpha: 0.96)
        hubTopContainer.layer.cornerRadius = 18
        hubTopContainer.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        hubTopContainer.layer.shadowColor = UIColor.black.cgColor
        hubTopContainer.layer.shadowOffset = CGSize(width: 0, height: 3)
        hubTopContainer.layer.shadowRadius = 8
        hubTopContainer.layer.shadowOpacity = 0.06
        self.view.addSubview(hubTopContainer)

        // Hero Banner đồng bộ CSS Theme
        hubHeroCard.translatesAutoresizingMaskIntoConstraints = false
        hubHeroCard.layer.cornerRadius = 16
        hubHeroCard.layer.shadowColor = HubCSSTheme.blue.cgColor
        hubHeroCard.layer.shadowOffset = CGSize(width: 0, height: 4)
        hubHeroCard.layer.shadowRadius = 10
        hubHeroCard.layer.shadowOpacity = 0.20

        hubHeroGradient.colors = [HubCSSTheme.heroStart, HubCSSTheme.heroEnd]
        hubHeroGradient.startPoint = CGPoint(x: 0, y: 0)
        hubHeroGradient.endPoint = CGPoint(x: 1, y: 1)
        hubHeroGradient.cornerRadius = 16
        hubHeroCard.layer.insertSublayer(hubHeroGradient, at: 0)
        hubTopContainer.addSubview(hubHeroCard)

        let heroTitleLabel = UILabel()
        heroTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        heroTitleLabel.text = "📦 Kho App Tinh Gọn"
        heroTitleLabel.font = UIFont.systemFont(ofSize: 17, weight: .heavy)
        heroTitleLabel.textColor = .white
        hubHeroCard.addSubview(heroTitleLabel)

        hubHeroSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        hubHeroSubtitleLabel.text = "Tải IPA báo % trực tiếp • Tự động chuyển sang Ký App"
        hubHeroSubtitleLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .semibold)
        hubHeroSubtitleLabel.textColor = UIColor.white.withAlphaComponent(0.92)
        hubHeroCard.addSubview(hubHeroSubtitleLabel)

        // Nút Quản lý File đã tải ngay trên Hero Card
        hubDownloadedFilesButton.translatesAutoresizingMaskIntoConstraints = false
        hubDownloadedFilesButton.setTitle(" 📥 File đã tải (0) ", for: .normal)
        hubDownloadedFilesButton.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
        hubDownloadedFilesButton.setTitleColor(.white, for: .normal)
        hubDownloadedFilesButton.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        hubDownloadedFilesButton.layer.cornerRadius = 12
        hubDownloadedFilesButton.layer.borderWidth = 1.0
        hubDownloadedFilesButton.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        hubDownloadedFilesButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        hubDownloadedFilesButton.addTarget(self, action: #selector(openDownloadedIPAsManager), for: .touchUpInside)
        hubHeroCard.addSubview(hubDownloadedFilesButton)

        // Nút + Thêm nguồn nhanh trên Hero Card
        hubQuickAddSourceButton.translatesAutoresizingMaskIntoConstraints = false
        hubQuickAddSourceButton.setTitle(" ➕ Thêm nguồn ", for: .normal)
        hubQuickAddSourceButton.titleLabel?.font = UIFont.systemFont(ofSize: 11.5, weight: .heavy)
        hubQuickAddSourceButton.setTitleColor(.white, for: .normal)
        hubQuickAddSourceButton.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        hubQuickAddSourceButton.layer.cornerRadius = 12
        hubQuickAddSourceButton.layer.borderWidth = 1.0
        hubQuickAddSourceButton.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
        hubQuickAddSourceButton.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        hubQuickAddSourceButton.addTarget(self, action: #selector(openSourcesHubManager), for: .touchUpInside)
        hubHeroCard.addSubview(hubQuickAddSourceButton)

        // Thanh Tìm Kiếm (Search Bar)
        hubSearchBar.translatesAutoresizingMaskIntoConstraints = false
        hubSearchBar.placeholder = "Tìm tên ứng dụng, tác giả, Bundle ID..."
        hubSearchBar.searchBarStyle = .minimal
        hubSearchBar.delegate = self
        hubSearchBar.returnKeyType = .done
        if let tf = hubSearchBar.value(forKey: "searchField") as? UITextField {
            tf.backgroundColor = HubCSSTheme.white
            tf.textColor = HubCSSTheme.pureBlack
            tf.font = UIFont.systemFont(ofSize: 13.5, weight: .medium)
            tf.layer.cornerRadius = 12
            tf.layer.borderWidth = 1.0
            tf.layer.borderColor = HubCSSTheme.border.cgColor
            tf.clipsToBounds = true
        }
        hubTopContainer.addSubview(hubSearchBar)

        // Thanh Chọn Nguồn Ngang (Source Filter Chips)
        hubChipsScrollView.translatesAutoresizingMaskIntoConstraints = false
        hubChipsScrollView.showsHorizontalScrollIndicator = false
        hubChipsScrollView.backgroundColor = .clear
        hubTopContainer.addSubview(hubChipsScrollView)

        hubChipsStackView.translatesAutoresizingMaskIntoConstraints = false
        hubChipsStackView.axis = .horizontal
        hubChipsStackView.spacing = 8
        hubChipsStackView.alignment = .center
        hubChipsScrollView.addSubview(hubChipsStackView)

        // Dòng trạng thái nhỏ + Spinner
        hubStatusBannerLabel.translatesAutoresizingMaskIntoConstraints = false
        hubStatusBannerLabel.font = UIFont.systemFont(ofSize: 11.5, weight: .bold)
        hubStatusBannerLabel.textColor = HubCSSTheme.purple
        hubStatusBannerLabel.text = "Đang nạp danh sách ứng dụng..."
        hubTopContainer.addSubview(hubStatusBannerLabel)

        hubLoadingSpinner.translatesAutoresizingMaskIntoConstraints = false
        hubLoadingSpinner.color = HubCSSTheme.blue
        hubLoadingSpinner.hidesWhenStopped = true
        hubTopContainer.addSubview(hubLoadingSpinner)

        NSLayoutConstraint.activate([
            hubTopContainer.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
            hubTopContainer.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            hubTopContainer.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            hubTopContainer.heightAnchor.constraint(equalToConstant: hubHeaderHeight),

            hubHeroCard.topAnchor.constraint(equalTo: hubTopContainer.topAnchor, constant: 6),
            hubHeroCard.leadingAnchor.constraint(equalTo: hubTopContainer.leadingAnchor, constant: 14),
            hubHeroCard.trailingAnchor.constraint(equalTo: hubTopContainer.trailingAnchor, constant: -14),
            hubHeroCard.heightAnchor.constraint(equalToConstant: 82),

            heroTitleLabel.topAnchor.constraint(equalTo: hubHeroCard.topAnchor, constant: 10),
            heroTitleLabel.leadingAnchor.constraint(equalTo: hubHeroCard.leadingAnchor, constant: 14),

            hubHeroSubtitleLabel.topAnchor.constraint(equalTo: heroTitleLabel.bottomAnchor, constant: 2),
            hubHeroSubtitleLabel.leadingAnchor.constraint(equalTo: heroTitleLabel.leadingAnchor),
            hubHeroSubtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: hubHeroCard.trailingAnchor, constant: -12),

            hubDownloadedFilesButton.leadingAnchor.constraint(equalTo: hubHeroCard.leadingAnchor, constant: 14),
            hubDownloadedFilesButton.bottomAnchor.constraint(equalTo: hubHeroCard.bottomAnchor, constant: -8),
            hubDownloadedFilesButton.heightAnchor.constraint(equalToConstant: 24),

            hubQuickAddSourceButton.leadingAnchor.constraint(equalTo: hubDownloadedFilesButton.trailingAnchor, constant: 8),
            hubQuickAddSourceButton.centerYAnchor.constraint(equalTo: hubDownloadedFilesButton.centerYAnchor),
            hubQuickAddSourceButton.heightAnchor.constraint(equalToConstant: 24),

            hubSearchBar.topAnchor.constraint(equalTo: hubHeroCard.bottomAnchor, constant: 3),
            hubSearchBar.leadingAnchor.constraint(equalTo: hubTopContainer.leadingAnchor, constant: 8),
            hubSearchBar.trailingAnchor.constraint(equalTo: hubTopContainer.trailingAnchor, constant: -8),
            hubSearchBar.heightAnchor.constraint(equalToConstant: 42),

            hubChipsScrollView.topAnchor.constraint(equalTo: hubSearchBar.bottomAnchor, constant: 2),
            hubChipsScrollView.leadingAnchor.constraint(equalTo: hubTopContainer.leadingAnchor, constant: 14),
            hubChipsScrollView.trailingAnchor.constraint(equalTo: hubTopContainer.trailingAnchor, constant: -14),
            hubChipsScrollView.heightAnchor.constraint(equalToConstant: 36),

            hubChipsStackView.topAnchor.constraint(equalTo: hubChipsScrollView.topAnchor),
            hubChipsStackView.bottomAnchor.constraint(equalTo: hubChipsScrollView.bottomAnchor),
            hubChipsStackView.leadingAnchor.constraint(equalTo: hubChipsScrollView.leadingAnchor, constant: 2),
            hubChipsStackView.trailingAnchor.constraint(equalTo: hubChipsScrollView.trailingAnchor, constant: -2),
            hubChipsStackView.heightAnchor.constraint(equalTo: hubChipsScrollView.heightAnchor),

            hubStatusBannerLabel.topAnchor.constraint(equalTo: hubChipsScrollView.bottomAnchor, constant: 5),
            hubStatusBannerLabel.leadingAnchor.constraint(equalTo: hubTopContainer.leadingAnchor, constant: 16),

            hubLoadingSpinner.centerYAnchor.constraint(equalTo: hubStatusBannerLabel.centerYAnchor),
            hubLoadingSpinner.trailingAnchor.constraint(equalTo: hubTopContainer.trailingAnchor, constant: -16)
        ])
    }

    func rebuildSourceChipsBar()
    {
        for sub in hubChipsStackView.arrangedSubviews {
            hubChipsStackView.removeArrangedSubview(sub)
            sub.removeFromSuperview()
        }

        // Chip 0: Tất cả nguồn đang bật
        let isAllSelected = (currentFilter == .allEnabled)
        let allBtn = makeChipButton(
            title: "⚡ Tất cả nguồn",
            isSelected: isAllSelected,
            tag: -1
        )
        allBtn.addTarget(self, action: #selector(handleChipButtonTapped(_:)), for: .touchUpInside)
        hubChipsStackView.addArrangedSubview(allBtn)

        // Các Chip từng nguồn nhẹ
        let sources = SmartRepoStoreManager.shared.sources
        for (idx, src) in sources.enumerated() {
            let isSelected = (currentFilter == .specificSource(src))
            let cachedCount = SmartRepoStoreManager.shared.cachedApps(for: src)?.count
            let countSuffix = cachedCount != nil ? " (\(cachedCount!))" : ""
            let btn = makeChipButton(
                title: "📦 \(src.displayName)\(countSuffix)",
                isSelected: isSelected,
                tag: idx
            )
            btn.addTarget(self, action: #selector(handleChipButtonTapped(_:)), for: .touchUpInside)
            hubChipsStackView.addArrangedSubview(btn)
        }
    }

    func makeChipButton(title: String, isSelected: Bool, tag: Int) -> UIButton
    {
        let btn = UIButton(type: .system)
        btn.tag = tag
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        btn.layer.cornerRadius = 15
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)

        if isSelected {
            btn.backgroundColor = HubCSSTheme.blue
            btn.setTitleColor(.white, for: .normal)
            btn.layer.borderWidth = 0
        } else {
            btn.backgroundColor = HubCSSTheme.white
            btn.setTitleColor(HubCSSTheme.pureBlack, for: .normal)
            btn.layer.borderWidth = 1.0
            btn.layer.borderColor = HubCSSTheme.border.cgColor
        }
        return btn
    }

    @objc func handleChipButtonTapped(_ sender: UIButton)
    {
        let tag = sender.tag
        if tag == -1 {
            currentFilter = .allEnabled
        } else {
            let sources = SmartRepoStoreManager.shared.sources
            guard tag >= 0 && tag < sources.count else { return }
            currentFilter = .specificSource(sources[tag])
        }
        currentDisplayLimit = pageSize
        rebuildSourceChipsBar()
        loadAppsForCurrentFilter(forceRefresh: false)
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
            let enabledSources = SmartRepoStoreManager.shared.sources.filter { $0.isEnabledInAllTab }
            hubStatusBannerLabel.text = "⏳ Đang nạp \(enabledSources.count) nguồn ứng dụng..."

            Task { @MainActor in
                var combined: [HubAppItem] = []
                for src in enabledSources {
                    let apps = await SmartRepoStoreManager.shared.fetchApps(for: src, forceRefresh: forceRefresh)
                    combined.append(contentsOf: apps)
                }

                self.allLoadedHubApps = combined
                self.hubLoadingSpinner.stopAnimating()
                self.collectionView.refreshControl?.endRefreshing()
                self.rebuildSourceChipsBar()
                self.applySearchAndPagination()
            }

        case .specificSource(let source):
            hubStatusBannerLabel.text = "⏳ Đang nạp nguồn \(source.displayName)..."

            Task { @MainActor in
                let apps = await SmartRepoStoreManager.shared.fetchApps(for: source, forceRefresh: forceRefresh)
                self.allLoadedHubApps = apps
                self.hubLoadingSpinner.stopAnimating()
                self.collectionView.refreshControl?.endRefreshing()
                self.rebuildSourceChipsBar()
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

        switch currentFilter {
        case .allEnabled:
            hubStatusBannerLabel.text = "✨ Hiển thị \(displayedHubApps.count) / \(filteredHubApps.count) ứng dụng từ các nguồn tinh gọn"
        case .specificSource(let src):
            hubStatusBannerLabel.text = "📦 \(src.displayName): Hiển thị \(displayedHubApps.count) / \(filteredHubApps.count) ứng dụng"
        }

        self.collectionView.reloadData()
    }

    func refreshDownloadedFilesCountBadge()
    {
        IPADownloadCenter.shared.reloadDownloadedFiles()
        let count = IPADownloadCenter.shared.downloadedEntries.count
        hubDownloadedFilesButton.setTitle(" 📥 File đã tải (\(count)) ", for: .normal)
    }

    @objc func handleDownloadStateChanged(_ notification: Notification)
    {
        guard isSmartHubMode else { return }
        refreshDownloadedFilesCountBadge()

        if let errorMsg = notification.userInfo?["error"] as? String {
            let alert = UIAlertController(title: "Lỗi tải file IPA", message: errorMsg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
            present(alert, animated: true)
        }
        collectionView.reloadData()
    }

    @objc func handleDownloadProgressChanged(_ notification: Notification)
    {
        guard isSmartHubMode,
              let key = notification.userInfo?["key"] as? String,
              let progress = notification.userInfo?["progress"] as? Double else { return }

        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item < displayedHubApps.count else { continue }
            let app = displayedHubApps[indexPath.item]
            if app.downloadURL.absoluteString == key,
               let cell = collectionView.cellForItem(at: indexPath) as? HubAppCollectionViewCell {
                cell.updateDownloadState(isDownloaded: false, activeProgress: progress)
            }
        }
    }

    @objc func openDownloadedIPAsManager()
    {
        let vc = DownloadedIPAsManagerViewController()
        vc.onSelectSignIPA = { [weak self] entry in
            guard let self else { return }
            let fileURL = IPADownloadCenter.shared.localFileURL(for: entry)
            self.switchToMyAppsAndSignIPA(fileURL: fileURL, appName: entry.appName)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.overrideUserInterfaceStyle = .light
        present(nav, animated: true)
    }

    @objc func openSourcesHubManager()
    {
        let vc = SourcesHubManagerViewController()
        vc.onSourcesChanged = { [weak self] selectedOrAddedSource in
            guard let self else { return }
            if let source = selectedOrAddedSource {
                self.currentFilter = .specificSource(source)
            }
            self.rebuildSourceChipsBar()
            self.loadAppsForCurrentFilter(forceRefresh: false)
        }
        let nav = UINavigationController(rootViewController: vc)
        nav.overrideUserInterfaceStyle = .light
        present(nav, animated: true)
    }

    func handleHubAppPrimaryAction(for app: HubAppItem)
    {
        // Trạng thái 1: Nếu đang tải -> Hỏi hủy tải
        if IPADownloadCenter.shared.activeProgress(for: app) != nil {
            let alert = UIAlertController(
                title: "Đang tải \(app.name)",
                message: "Bạn có muốn hủy tải file IPA này không?",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Tiếp tục tải", style: .cancel))
            alert.addAction(UIAlertAction(title: "Hủy tải", style: .destructive) { _ in
                IPADownloadCenter.shared.cancelDownload(for: app)
            })
            present(alert, animated: true)
            return
        }

        // Trạng thái 2: Nếu đã tải xong file .ipa -> Nút đang là "✍️ KÝ APP" -> Chuyển ngay sang Tab "Ứng dụng" (My Apps) để ký & cài đặt!
        if let localURL = IPADownloadCenter.shared.localFileURL(for: app) {
            switchToMyAppsAndSignIPA(fileURL: localURL, appName: app.name)
            return
        }

        // Trạng thái 3: Chưa tải -> Bắt đầu tải file IPA và hiện %
        IPADownloadCenter.shared.startDownload(for: app)
    }

    /// Chuyển giao diện sang Tab 3 ("Ứng dụng" - My Apps) và kích hoạt trình Ký & Cài đặt IPA chuẩn của SideStore
    func switchToMyAppsAndSignIPA(fileURL: URL, appName: String)
    {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let alert = UIAlertController(title: "Không tìm thấy file IPA", message: "File IPA đã bị xóa. Vui lòng tải lại.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Đóng", style: .cancel))
            present(alert, animated: true)
            refreshDownloadedFilesCountBadge()
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
            if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
               let sceneDelegate = scene.delegate {
                let openContextClass = UIOpenURLContext.self
                _ = openContextClass // Giữ tương thích iOS
                if let appDelegate = UIApplication.shared.delegate,
                   appDelegate.responds(to: #selector(UIApplicationDelegate.application(_:open:options:))) {
                    _ = appDelegate.application?(UIApplication.shared, open: targetURL, options: [:])
                    return
                }
                _ = sceneDelegate
            }

            if let appDelegate = UIApplication.shared.delegate {
                _ = appDelegate.application?(UIApplication.shared, open: targetURL, options: [:])
            }
        }
    }
}

// ============================================================================
// MARK: - 🔍 UISearchBarDelegate (TÌM KIẾM SIÊU TỐC TRONG KHO APP)
// ============================================================================

extension BrowseViewController: UISearchBarDelegate
{
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String)
    {
        guard isSmartHubMode else { return }
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
// MARK: - 📋 INFINITE SCROLL CHO SMART HUB MODE
// ============================================================================

extension BrowseViewController
{
    override func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath)
    {
        guard self.isSmartHubMode else { return }
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
}

// ============================================================================
// MARK: - 🧱 PHẦN LOGIC COREDATA GỐC (GIỮ NGUYÊN ĐỂ TƯƠNG THÍCH TOÀN DỰ ÁN)
// ============================================================================

private extension BrowseViewController
{
    func preparePipeline()
    {
        AppManager.shared.$updateSourcesResult
            .receive(on: RunLoop.main)
            .sink { [weak self] result in
                guard let self, !self.isSmartHubMode else { return }
                self.update()
            }
            .store(in: &self.cancellables)
    }
    
    func makeFetchRequest() -> NSFetchRequest<StoreApp>
    {
        let fetchRequest = StoreApp.fetchRequest() as NSFetchRequest<StoreApp>
        fetchRequest.returnsObjectsAsFaults = false
        
        let predicate = StoreApp.visibleAppsPredicate
        
        if let source = self.source
        {
            let filterPredicate = NSPredicate(format: "%K == %@", #keyPath(StoreApp._source), source)
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [filterPredicate, predicate])
        }
        else if let category = self.category
        {
            let categoryPredicate = switch category {
            case .other: StoreApp.otherCategoryPredicate
            default: NSPredicate(format: "%K == %@", #keyPath(StoreApp._category), category.rawValue)
            }
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [categoryPredicate, predicate])
        }
        else
        {
            fetchRequest.predicate = predicate
        }
        
        var sortDescriptors = [NSSortDescriptor(keyPath: \StoreApp.name, ascending: true),
                               NSSortDescriptor(keyPath: \StoreApp.bundleIdentifier, ascending: true),
                               NSSortDescriptor(keyPath: \StoreApp.sourceIdentifier, ascending: true)]
        
        switch self.preferredAppSorting
        {
        case .default:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.sortIndex, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
            
        case .name:
            break
            
        case .developer:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.developerName, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
            
        case .lastUpdated:
            let descriptor = NSSortDescriptor(keyPath: \StoreApp.latestSupportedVersion?.date, ascending: self.preferredAppSorting.isAscending)
            sortDescriptors.insert(descriptor, at: 0)
        }
        
        fetchRequest.sortDescriptors = sortDescriptors
        
        return fetchRequest
    }
    
    func makeDataSource() -> FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>
    {
        let fetchRequest = self.makeFetchRequest()
        
        let context = self.source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let dataSource = FetchedResultsCollectionViewPrefetchingDataSource<StoreApp, UIImage>(fetchRequest: fetchRequest, managedObjectContext: context)
        dataSource.placeholderView = self.placeholderView
        dataSource.cellConfigurationHandler = { [weak self] (cell, app, indexPath) in
            guard let self else { return }
            
            let cell = cell as! AppCardCollectionViewCell
            cell.layoutMargins.left = self.view.layoutMargins.left
            cell.layoutMargins.right = self.view.layoutMargins.right
            
            let showSourceIcon = (self.source == nil)
            cell.configure(for: app, showSourceIcon: showSourceIcon)
            
            cell.bannerView.iconImageView.image = nil
            cell.bannerView.iconImageView.isIndicatingActivity = true
            
            cell.bannerView.button.addTarget(self, action: #selector(BrowseViewController.performAppAction(_:)), for: .primaryActionTriggered)
            cell.bannerView.button.activityIndicatorView.style = .medium
            cell.bannerView.button.activityIndicatorView.color = .white
            
            let tintColor = app.tintColor ?? .altPrimary
            cell.tintColor = tintColor
        }
        dataSource.prefetchHandler = { (storeApp, indexPath) in
            let image = try await ImagePipeline.shared.image(for: storeApp.iconURL)
            return await Task.detached(priority: .userInitiated) {
                _ = image.isPredominantlyLight
                _ = image.withDropShadow(color: .black, radius: 4, offset: CGSize(width: 0, height: 1.5), opacity: 0.25)
                return image
            }.value
        }
        dataSource.prefetchCompletionHandler = { [weak dataSource] (cell, image, indexPath, error) in
            let cell = cell as! AppCardCollectionViewCell
            cell.bannerView.iconImageView.isIndicatingActivity = false
            cell.bannerView.iconImageView.image = image
            
            if let error = error, let dataSource
            {
                let app = dataSource.item(at: indexPath)
                debugLog("Failed to load app icon from \(app.iconURL). \(error.localizedDescription)")
            }
        }
        
        return dataSource
    }
    
    func updateDataSource()
    {
        guard !self.isSmartHubMode else { return }
        let fetchRequest = self.makeFetchRequest()
        
        let context = self.source?.managedObjectContext ?? DatabaseManager.shared.viewContext
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: context, sectionNameKeyPath: nil, cacheName: nil)
        self.dataSource.fetchedResultsController = fetchedResultsController
        
        self.dataSource.predicate = self.searchPredicate
    }
    
    func updateSources()
    {
        if self.isSmartHubMode {
            self.forceRefreshCurrentSelection()
            return
        }

        AppManager.shared.updateAllSources { result in
            #if !os(tvOS)
            self.collectionView.refreshControl?.endRefreshing()
            #endif
            
            guard case .failure(let error) = result else { return }
            
            if self.dataSource.itemCount > 0
            {
                let toastView = ToastView(error: error)
                toastView.addTarget(nil, action: #selector(TabBarController.presentSources), for: .touchUpInside)
                toastView.show(in: self)
            }
        }
    }
    
    func update()
    {
        guard !self.isSmartHubMode else { return }

        if self.searchPredicate != nil
        {
            self.placeholderView.textLabel.text = NSLocalizedString("No Apps", comment: "")
            self.placeholderView.textLabel.isHidden = false
            
            self.placeholderView.detailTextLabel.text = NSLocalizedString("Please make sure your spelling is correct, or try searching for another app.", comment: "")
            self.placeholderView.detailTextLabel.isHidden = false
            
            self.placeholderView.activityIndicatorView.stopAnimating()
        }
        else
        {
            switch AppManager.shared.updateSourcesResult
            {
            case nil:
                self.placeholderView.textLabel.isHidden = true
                self.placeholderView.detailTextLabel.isHidden = false
                
                self.placeholderView.detailTextLabel.text = NSLocalizedString("Loading...", comment: "")
                
                self.placeholderView.activityIndicatorView.startAnimating()
                
            case .failure(let error):
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = false
                
                self.placeholderView.textLabel.text = NSLocalizedString("Unable to Fetch Apps", comment: "")
                self.placeholderView.detailTextLabel.text = error.localizedDescription
                
                self.placeholderView.activityIndicatorView.stopAnimating()
                
            case .success:
                self.placeholderView.textLabel.text = NSLocalizedString("No Apps", comment: "")
                self.placeholderView.textLabel.isHidden = false
                self.placeholderView.detailTextLabel.isHidden = true
                
                self.placeholderView.activityIndicatorView.stopAnimating()
            }
        }
        
        let tintColor: UIColor
        
        if let source = self.source
        {
            tintColor = source.effectiveTintColor?.adjustedForDisplay ?? .altPrimary
            
            self.title = source.name
                        
            self.titleSourceIconView?.backgroundColor = tintColor
            self.titleSourceIconView?.isHidden = false
            
            self.titleCategoryIconView?.isHidden = true
            
            if let iconURL = source.effectiveIconURL
            {
                Task { [weak self] in
                    do
                    {
                        let image = try await ImagePipeline.shared.image(for: iconURL)
                        guard let self else { return }
                        self.titleSourceIconView?.image = image
                        self.titleSourceIconView?.backgroundColor = .white
                    }
                    catch
                    {
                        debugLog("Failed to fetch source icon at \(iconURL). \(error.localizedDescription)")
                    }
                }
            }
        }
        else if let category = self.category
        {
            tintColor = category.tintColor
            
            self.title = category.localizedName
            
            let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
            self.titleCategoryIconView?.image = image
            self.titleCategoryIconView?.isHidden = false
            
            self.titleSourceIconView?.isHidden = true
        }
        else
        {
            tintColor = .altPrimary
            
            self.title = "Kho App"
            
            self.titleSourceIconView?.isHidden = true
            self.titleCategoryIconView?.isHidden = true
        }
        
        self.titleLabel?.text = self.title
        self.titleStackView?.sizeToFit()
        self.navigationItem.titleView = self.titleStackView
        
        self.view.tintColor = tintColor
        
        #if !os(tvOS)
        let appearance = NavigationBarAppearance()
        appearance.configureWithTintColor(tintColor)
        appearance.configureWithDefaultBackground()
        
        let edgeAppearance = appearance.copy()
        edgeAppearance.configureWithTransparentBackground()
        
        self.navigationItem.standardAppearance = appearance
        self.navigationItem.scrollEdgeAppearance = edgeAppearance
        #endif
        
        self.navigationController?.navigationBar.tintColor = tintColor
        
        if let sortButton
        {
            sortButton.image = sortButton.image?.withTintColor(tintColor, renderingMode: .alwaysOriginal)
        }
    }
    
    func makeCategoryActions() -> [UIAction]
    {
        let handler = { [weak self] (category: StoreCategory) in
            self?.category = category
        }
        
        let fetchRequest = NSFetchRequest(entityName: StoreApp.entity().name!) as NSFetchRequest<NSDictionary>
        fetchRequest.resultType = .dictionaryResultType
        fetchRequest.returnsDistinctResults = true
        fetchRequest.propertiesToFetch = [#keyPath(StoreApp._category)]
        fetchRequest.predicate = StoreApp.visibleAppsPredicate
        
        do
        {
            let dictionaries = try DatabaseManager.shared.viewContext.fetch(fetchRequest)
            
            let categories = dictionaries.map { $0[#keyPath(StoreApp._category)] as? String? ?? nil }.map { rawCategory -> StoreCategory in
                guard let rawCategory else { return .other }
                return StoreCategory(rawValue: rawCategory) ?? .other
            }
            
            var sortedCategories = Set(categories).sorted(by: { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending })
            if let otherIndex = sortedCategories.firstIndex(of: .other)
            {
                sortedCategories.move(fromOffsets: [otherIndex], toOffset: sortedCategories.count)
            }
            
            let actions = sortedCategories.map { category in
                let state: UIAction.State = (category == self.category) ? .on : .off
                let image = UIImage(systemName: category.filledSymbolName)?.withTintColor(category.tintColor, renderingMode: .alwaysOriginal)
                return UIAction(title: category.localizedName, image: image, state: state) { _ in
                    handler(category)
                }
            }
            
            return actions
        }
        catch
        {
            debugLog("Failed to fetch categories. \(error.localizedDescription)")
            
            return []
        }
    }
    
    func prepareAppSorting()
    {
        if self.preferredAppSorting == .default && self.source == nil
        {
            self.preferredAppSorting = .lastUpdated
        }
        
        let children = UIDeferredMenuElement.uncached { [weak self] completion in
            guard let self else { return completion([]) }
            
            var sortingOptions = AppSorting.allCases
            if self.source == nil
            {
                sortingOptions = sortingOptions.filter { $0 != .default }
            }
            
            let actions = sortingOptions.map { sorting in
                let state: UIMenuElement.State = (sorting == self.preferredAppSorting) ? .on : .off
                let action = UIAction(title: sorting.localizedName, image: nil, state: state) { action in
                    self.preferredAppSorting = sorting
                    UserDefaults.standard.preferredAppSorting = sorting
                    
                    self.updateDataSource()
                }
                
                return action
            }
            
            completion(actions)
        }
        
        let sortMenu = UIMenu(title: NSLocalizedString("Sort by…", comment: ""), options: [.singleSelection], children: [children])
        let sortIcon = UIImage(systemName: "arrow.up.arrow.down")
        
        let sortButton = UIBarButtonItem(title: NSLocalizedString("Sort by…", comment: ""), image: sortIcon, primaryAction: nil, menu: sortMenu)
        self.sortButton = sortButton
        
        self.navigationItem.rightBarButtonItems = [sortButton]
    }
}

private extension BrowseViewController
{
    @IBAction func performAppAction(_ sender: PillButton)
    {
        guard !self.isSmartHubMode else { return }
        let point = self.collectionView.convert(sender.center, from: sender.superview)
        guard let indexPath = self.collectionView.indexPathForItem(at: point) else { return }
        
        let app = self.dataSource.item(at: indexPath)
        
        if let installedApp = app.installedApp, !installedApp.hasUpdate
        {
            self.open(installedApp)
        }
        else
        {
            self.install(app, at: indexPath) { progress in
                sender.progress = progress
            }
        }
    }
    
    func install(_ app: StoreApp, at indexPath: IndexPath, progressUpdateHandler: @escaping (Progress) -> Void)
    {
        InstallAppDialog.present(storeApp: app, from: self) { [weak self] in
            guard let self else { return }
            let previousProgress = AppManager.shared.installationProgress(for: app)
            guard previousProgress == nil else {
                previousProgress?.cancel()
                return
            }
            
            if let installedApp = app.installedApp, installedApp.hasUpdate
            {
                let progress = AppManager.shared.update(installedApp, presentingViewController: self, completionHandler: finish(_:))
                progressUpdateHandler(progress)
            }
            else
            {
                let group = AppManager.shared.install(.app(app), presentingViewController: self, completionHandler: finish(_:))
                progressUpdateHandler(group.progress)
            }
            
            func finish(_ result: Result<InstalledApp, Error>)
            {
                debugLog("BrowseViewController.finish invoked with result: \(result) for \(app.bundleIdentifier)")
                DispatchQueue.main.async {
                    switch result
                    {
                    case .failure(let error) where error is CancellationError: break
                    case .failure(let error):
                        let toastView = ToastView(error: error, opensLog: true)
                        toastView.show(in: self)
                        
                    case .success: debugLog("Installed app: \(app.bundleIdentifier)")
                    }
                    
                    UIView.performWithoutAnimation {
                        if let indexPath = self.dataSource.fetchedResultsController.indexPath(forObject: app)
                        {
                            self.collectionView.reloadItems(at: [indexPath])
                        }
                        else
                        {
                            self.collectionView.reloadData()
                        }
                    }
                }
            }
        }
    }
    
    func open(_ installedApp: InstalledApp)
    {
        UIApplication.shared.open(installedApp.openAppURL)
    }
}

extension BrowseViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize
    {
        if self.isSmartHubMode {
            let width = max(collectionView.bounds.width - 28, 280)
            return CGSize(width: width, height: 112)
        }

        let item = self.dataSource.item(at: indexPath)
        let itemID = item.globallyUniqueID ?? item.bundleIdentifier

        if let previousSize = self.cachedItemSizes[itemID]
        {
            return previousSize
        }
        
        self.dataSource.cellConfigurationHandler(self.prototypeCell, item, indexPath)
        
        let insets = (self.view.layoutMargins.left + self.view.layoutMargins.right)

        let widthConstraint = self.prototypeCell.contentView.widthAnchor.constraint(equalToConstant: collectionView.bounds.width - insets)
        widthConstraint.isActive = true
        defer { widthConstraint.isActive = false }

        self.prototypeCell.frame.size.width = widthConstraint.constant
        self.prototypeCell.layoutIfNeeded()
        
        let itemSize = self.prototypeCell.contentView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        self.cachedItemSizes[itemID] = itemSize
        return itemSize
    }
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        if self.isSmartHubMode {
            guard indexPath.item < self.displayedHubApps.count else { return }
            let app = self.displayedHubApps[indexPath.item]
            let isDownloaded = (IPADownloadCenter.shared.localFileURL(for: app) != nil)

            let sheet = UIAlertController(
                title: "\(app.name) (v\(app.version))",
                message: "📦 Nguồn: \(app.sourceName)\n👤 Tác giả: \(app.developerName)\n🆔 Bundle ID: \(app.bundleIdentifier)\n💾 Dung lượng: \(app.formattedSize)\n\n\(app.localizedDescription.prefix(350))",
                preferredStyle: .actionSheet
            )

            if isDownloaded, let localURL = IPADownloadCenter.shared.localFileURL(for: app) {
                sheet.addAction(UIAlertAction(title: "✍️ Ký & Cài đặt ngay (Sang Tab Ứng dụng)", style: .default) { [weak self] _ in
                    self?.switchToMyAppsAndSignIPA(fileURL: localURL, appName: app.name)
                })
                sheet.addAction(UIAlertAction(title: "⬇️ Tải lại bản mới", style: .default) { _ in
                    IPADownloadCenter.shared.startDownload(for: app)
                })
            } else {
                sheet.addAction(UIAlertAction(title: "⬇️ Tải về file IPA (\(app.formattedSize))", style: .default) { [weak self] _ in
                    self?.handleHubAppPrimaryAction(for: app)
                })
            }

            sheet.addAction(UIAlertAction(title: "📋 Sao chép Link tải IPA", style: .default) { _ in
                UIPasteboard.general.string = app.downloadURL.absoluteString
            })

            sheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
            if let popover = sheet.popoverPresentationController, let cell = collectionView.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
            present(sheet, animated: true)
            return
        }

        let app = self.dataSource.item(at: indexPath)
        let appViewController = AppViewController.makeAppViewController(app: app)
        
        let navigationController = self.navigationController ?? self.presentingViewController?.navigationController
        navigationController?.pushViewController(appViewController, animated: true)
    }
}

extension BrowseViewController: UIViewControllerPreviewingDelegate
{
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController?
    {
        guard !self.isSmartHubMode else { return nil }
        guard
            let indexPath = self.collectionView.indexPathForItem(at: location),
            let cell = self.collectionView.cellForItem(at: indexPath)
        else { return nil }
        
        previewingContext.sourceRect = cell.frame
        
        let app = self.dataSource.item(at: indexPath)
        
        let appViewController = AppViewController.makeAppViewController(app: app)
        return appViewController
    }
    
    @available(iOS, deprecated: 13.0)
    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController)
    {
        guard !self.isSmartHubMode else { return }
        self.navigationController?.pushViewController(viewControllerToCommit, animated: true)
    }
}
