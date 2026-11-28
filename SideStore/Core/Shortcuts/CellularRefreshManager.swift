
//
//  CellularRefreshManager.swift
//  SideStore
//
//  Created by Magesh K on 4/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import UIKit
import Darwin
import Minimuxer

private struct PersistedProfileBatch: Codable {
    let bundleID: String
    let profiles: [Data]
    let timestamp: TimeInterval
}

/// Theo dõi chu kỳ SideStore nhường màn hình cho Phím tắt và quay trở lại Foreground
private final class ShortcutTransitionTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _didResignActive = false
    private var _didBecomeActiveAfterResign = false
    private var observers: [NSObjectProtocol] = []

    var didResignActive: Bool { lock.withLock { _didResignActive } }
    var didBecomeActiveAfterResign: Bool { lock.withLock { _didBecomeActiveAfterResign } }

    @MainActor
    func start() {
        let nc = NotificationCenter.default
        let resignObs = nc.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.lock.withLock { self?._didResignActive = true }
        }
        let activeObs = nc.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.lock.withLock {
                if self._didResignActive {
                    self._didBecomeActiveAfterResign = true
                }
            }
        }
        self.observers = [resignObs, activeObs]
    }

    @MainActor
    func stop() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
}

public final class CellularRefreshManager: @unchecked Sendable {
    public static let shared = CellularRefreshManager()

    private let lock = NSLock()
    private var cachedDidTurnOffData = false
    private var didTurnOffData: Bool {
        get { lock.withLock { cachedDidTurnOffData } }
        set { lock.withLock { cachedDidTurnOffData = newValue } }
    }

    // --- LƯU TRỮ TẠM CHO SHORTCUT 2 GIAI ĐOẠN ---
    private var cachedShortcutMode = false
    public var isShortcutTwoStageMode: Bool {
        get { lock.withLock { cachedShortcutMode } }
        set { lock.withLock { cachedShortcutMode = newValue } }
    }

    private var stagedBatchesFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("cellular_staged_batches.json")
    }

    public var hasRecentStagedBatches: Bool {
        !stagedBatches.isEmpty
    }

    internal var stagedBatches: [PendingProfileBatch] {
        get {
            lock.withLock {
                guard let data = try? Data(contentsOf: stagedBatchesFileURL),
                      let persisted = try? JSONDecoder().decode([PersistedProfileBatch].self, from: data),
                      let first = persisted.first else {
                    return []
                }
                // Chỉ giữ hiệu lực trong 180 giây (3 phút)
                guard (Date().timeIntervalSince1970 - first.timestamp) <= 180 else {
                    try? FileManager.default.removeItem(at: stagedBatchesFileURL)
                    return []
                }
                return persisted.map {
                    PendingProfileBatch(bundleID: $0.bundleID, profiles: $0.profiles, app: nil, certStatus: nil)
                }
            }
        }
        set {
            lock.withLock {
                if newValue.isEmpty {
                    try? FileManager.default.removeItem(at: stagedBatchesFileURL)
                } else {
                    let now = Date().timeIntervalSince1970
                    let persisted = newValue.map {
                        PersistedProfileBatch(bundleID: $0.bundleID, profiles: $0.profiles, timestamp: now)
                    }
                    if let data = try? JSONEncoder().encode(persisted) {
                        try? data.write(to: stagedBatchesFileURL, options: .atomic)
                    }
                }
            }
        }
    }

    private init() {}

    // --- CẤU HÌNH & TRẠNG THÁI ---
    public var isSupported: Bool {
        #if os(tvOS)
        return false
        #else
        return true
        #endif
    }

    public var isEnabled: Bool {
        // Luôn kích hoạt chế độ hỗ trợ 4G mà không cần người dùng phải bật trong Settings
        return true
    }

    public var isCellularMode: Bool {
        if isShortcutTwoStageMode { return true }
        guard isSupported && isEnabled else { return false }
        return !minimuxer.network.isWifiSatisfied
    }

    public func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.isCellularRefreshEnabled = enabled
    }

    // --- QUẢN LÝ PHÍM TẮT (SHORTCUTS) ---
    public static func sanitizeShortcutName(_ name: String, fallback: String = "") -> String {
        let cleaned = name.components(separatedBy: .controlCharacters).joined()
                          .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = String(cleaned.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
        return limited.isEmpty ? fallback : limited
    }

    public var turnOffDataShortcutName: String {
        Self.sanitizeShortcutName(UserDefaults.standard.turnOffDataShortcutName,
                                  fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
    }

    public var turnOnDataShortcutName: String {
        Self.sanitizeShortcutName(UserDefaults.standard.turnOnDataShortcutName,
                                  fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
    }

    public func setTurnOffDataShortcutName(_ name: String) {
        UserDefaults.standard.turnOffDataShortcutName = Self.sanitizeShortcutName(
            name, fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName
        )
    }

    public func setTurnOnDataShortcutName(_ name: String) {
        UserDefaults.standard.turnOnDataShortcutName = Self.sanitizeShortcutName(
            name, fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName
        )
    }

    public func shortcutURL(for name: String, fallback: String) -> URL {
        let sanitized = Self.sanitizeShortcutName(name, fallback: fallback)
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: sanitized)]
        return components.url ?? URL(string: "shortcuts://run-shortcut?name=\(fallback)")!
    }

    @MainActor
    private func openShortcut(url: URL) async -> Bool {
        debugLog("[CellularRefreshManager] Opening shortcut URL: \(url.absoluteString)")
        return await UIApplication.shared.open(url)
    }

    @discardableResult
    private func turnOffData() async -> Bool {
        let url = shortcutURL(for: turnOffDataShortcutName, fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
        return await openShortcut(url: url)
    }

    @discardableResult
    private func turnOnData() async -> Bool {
        let url = shortcutURL(for: turnOnDataShortcutName, fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
        return await openShortcut(url: url)
    }

    // --- CẤU HÌNH ĐỘ TRỄ (GIỮ LẠI ĐỂ TƯƠNG THÍCH UI SETTINGS) ---
    public var turnOffDataBaseDelayOverride: TimeInterval? {
        (UserDefaults.standard.object(forKey: "turnOffDataBaseDelayOverride") as? Double).map { max(0, $0) }
    }

    public var turnOnDataBaseDelayOverride: TimeInterval? {
        (UserDefaults.standard.object(forKey: "turnOnDataBaseDelayOverride") as? Double).map { max(0, $0) }
    }

    public func setTurnOffDataBaseDelayOverride(_ delay: TimeInterval?) {
        if let delay {
            UserDefaults.standard.set(max(0, delay), forKey: "turnOffDataBaseDelayOverride")
        } else {
            UserDefaults.standard.removeObject(forKey: "turnOffDataBaseDelayOverride")
        }
    }

    public func setTurnOnDataBaseDelayOverride(_ delay: TimeInterval?) {
        if let delay {
            UserDefaults.standard.set(max(0, delay), forKey: "turnOnDataBaseDelayOverride")
        } else {
            UserDefaults.standard.removeObject(forKey: "turnOnDataBaseDelayOverride")
        }
    }

    public func resetToDefaults() {
        setTurnOffDataShortcutName(AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
        setTurnOnDataShortcutName(AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
        setTurnOffDataBaseDelayOverride(nil)
        setTurnOnDataBaseDelayOverride(nil)
    }

    private func sleep(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // --- KIỂM TRA MẠNG & MINIMUXER ---
    private static func hasActiveCellularInterface() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            if isUp, let namePtr = current.pointee.ifa_name, let addr = current.pointee.ifa_addr {
                if String(cString: namePtr) == "pdp_ip0" {
                    let family = Int32(addr.pointee.sa_family)
                    if family == AF_INET {
                        let sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        if sin.sin_addr.s_addr != 0 { return true }
                    } else if family == AF_INET6 {
                        let sin6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                        let bytes = withUnsafeBytes(of: sin6.sin6_addr) { Array($0) }
                        let isLinkLocal = bytes.count >= 2 && bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
                        let isUnspecified = bytes.allSatisfy { $0 == 0 }
                        if !isLinkLocal && !isUnspecified { return true }
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return false
    }

    private func runShortcutWithRoundTrip(_ action: () async -> Bool) async -> Bool {
        let wasActive = await MainActor.run { UIApplication.shared.applicationState == .active }
        let tracker = ShortcutTransitionTracker()
        if wasActive { await tracker.start() }
        defer { Task { @MainActor in tracker.stop() } }

        let success = await action()
        guard success, wasActive else { return success }

        let leaveDeadline = Date().addingTimeInterval(1.5)
        while !tracker.didResignActive && Date() < leaveDeadline {
            await sleep(0.08)
        }

        if tracker.didResignActive {
            let returnDeadline = Date().addingTimeInterval(10.0)
            while Date() < returnDeadline {
                let isActive = await MainActor.run { UIApplication.shared.applicationState == .active }
                if tracker.didBecomeActiveAfterResign && isActive { break }
                await sleep(0.12)
            }
        }
        return true
    }

    public func waitForMinimuxerReady(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)

        if case .success(true) = await minimuxer.core.isReady(withNetworkCheck: false) {
            // Đã sẵn sàng
        } else if let pf = PairingFileManager.shared.fetchPairingFile() {
            try? await AppBootManager.shared.startMinimuxer(pairingFile: pf)
        }

        while Date() < deadline {
            await minimuxer.network.refreshEndpoint()
            if (try? await fetchUDID(forceLive: true)) != nil {
                // Thêm đệm 0.25s sau khi lockdown thông suốt để các dịch vụ con (RwAfc/misagent) ổn định hẳn
                await sleep(0.25)
                debugLog("[CellularRefreshManager] Minimuxer live lockdown connection is ready.")
                return true
            }
            await sleep(0.4)
        }
        debugLog("[CellularRefreshManager] Timed out waiting for minimuxer to become ready.")
        return false
    }

    @discardableResult
    public func resetAndPrepareMinimuxer(timeout: TimeInterval = 8.0) async -> Bool {
        debugLog("[CellularRefreshManager] Resetting Minimuxer session for LocalDevVPN...")
        try? await minimuxerStop()
        // Đợi 0.35s để OS thu hồi hoàn toàn các file descriptor / socket cũ tránh lỗi MinimuxerError 35 (EAGAIN)
        await sleep(0.35)
        if let pf = PairingFileManager.shared.fetchPairingFile() {
            try? await AppBootManager.shared.startMinimuxer(pairingFile: pf)
        }
        return await waitForMinimuxerReady(timeout: timeout)
    }

    // --- PUBLIC APIS (ÉP CHẠY TRỰC TIẾP QUA 4G + LOCALDEVVPN MÀ KHÔNG TẮT DATA) ---
    @discardableResult
    public func turnOffDataIfNeeded(addOnDelay: TimeInterval = 0) async -> Bool {
        guard isSupported else { return false }

        // Nếu đã làm mới phiên Minimuxer trong chu trình này rồi thì chỉ đảm bảo kết nối sẵn sàng
        if didTurnOffData {
            _ = await waitForMinimuxerReady(timeout: 5.0)
            return false
        }

        // Nếu đang có Wi-Fi thì không cần can thiệp
        guard !minimuxer.network.isWifiSatisfied else {
            return false
        }

        didTurnOffData = true
        debugLog("[CellularRefreshManager] Giữ nguyên 4G, ép kết nối thẳng qua LocalDevVPN (10.7.0.1)...")

        // Không mở Phím tắt tắt 4G nữa! Khởi động lại phiên Minimuxer bám vào Override IP 10.7.0.1
        _ = await resetAndPrepareMinimuxer(timeout: 8.0)
        return true
    }

    @discardableResult
    public func turnOnDataIfNeeded(addOnDelay: TimeInterval = 0) async -> Bool {
        // Vì không tắt 4G nên chỉ cần reset lại cờ trạng thái, không mở Phím tắt
        guard didTurnOffData else { return false }
        didTurnOffData = false
        return true
    }
}
