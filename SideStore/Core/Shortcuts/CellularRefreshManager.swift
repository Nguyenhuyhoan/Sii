
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

/// Theo dõi chính xác chu kỳ SideStore nhường màn hình cho Phím tắt và quay trở lại Foreground
private final class ShortcutTransitionTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var _didResignActive = false
    private var _didBecomeActiveAfterResign = false
    private var observers: [NSObjectProtocol] = []

    var didResignActive: Bool {
        lock.withLock { _didResignActive }
    }

    var didBecomeActiveAfterResign: Bool {
        lock.withLock { _didBecomeActiveAfterResign }
    }

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
        let bgObs = nc.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
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
        self.observers = [resignObs, bgObs, activeObs]
    }

    @MainActor
    func stop() {
        let nc = NotificationCenter.default
        for obs in observers {
            nc.removeObserver(obs)
        }
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

    // --- BỘ NHỚ TẠM CHO SHORTCUT 2 GIAI ĐOẠN (RAM + DISK BACKUP KHI TẮT MÀN HÌNH) ---
    private var cachedShortcutMode = false
    public var isShortcutTwoStageMode: Bool {
        get { lock.withLock { cachedShortcutMode } }
        set { lock.withLock { cachedShortcutMode = newValue } }
    }

    private var stagedBatchesFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("cellular_staged_batches.json")
    }

    private var cachedStagedBatches: [PendingProfileBatch] = []
    private var cachedStagedTimestamp: TimeInterval = 0

    /// Hàm nội bộ (gọi bên trong `lock.withLock`): Kiểm tra RAM trước, chỉ đọc ổ cứng 1 lần duy nhất nếu RAM trống
    private func loadValidStagedBatchesLocked() -> [PendingProfileBatch] {
        let now = Date().timeIntervalSince1970

        if !cachedStagedBatches.isEmpty && cachedStagedTimestamp > 0 {
            if (now - cachedStagedTimestamp) <= 180 {
                return cachedStagedBatches
            } else {
                cachedStagedBatches = []
                cachedStagedTimestamp = 0
                try? FileManager.default.removeItem(at: stagedBatchesFileURL)
                return []
            }
        }

        guard let data = try? Data(contentsOf: stagedBatchesFileURL),
              let persisted = try? JSONDecoder().decode([PersistedProfileBatch].self, from: data),
              let first = persisted.first else {
            return []
        }

        if (now - first.timestamp) <= 180 {
            cachedStagedTimestamp = first.timestamp
            cachedStagedBatches = persisted.map {
                PendingProfileBatch(bundleID: $0.bundleID, profiles: $0.profiles, app: nil, certStatus: nil)
            }
            return cachedStagedBatches
        } else {
            cachedStagedBatches = []
            cachedStagedTimestamp = 0
            try? FileManager.default.removeItem(at: stagedBatchesFileURL)
            return []
        }
    }

    /// Kiểm tra xem có dữ liệu Profile của Bước 1 vừa lưu trong vòng 180 giây qua không
    public var hasRecentStagedBatches: Bool {
        lock.withLock {
            !loadValidStagedBatchesLocked().isEmpty
        }
    }

    internal var stagedBatches: [PendingProfileBatch] {
        get {
            lock.withLock {
                loadValidStagedBatchesLocked()
            }
        }
        set {
            lock.withLock {
                cachedStagedBatches = newValue
                if newValue.isEmpty {
                    cachedStagedTimestamp = 0
                    try? FileManager.default.removeItem(at: stagedBatchesFileURL)
                } else {
                    let now = Date().timeIntervalSince1970
                    cachedStagedTimestamp = now
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
    // -------------------------------------------------------------------------------

    private init() {}

    public var isSupported: Bool {
        #if os(tvOS)
        return false
        #else
        return true
        #endif
    }

    public var isEnabled: Bool {
        return UserDefaults.standard.isCellularRefreshEnabled
    }

    public var isCellularMode: Bool {
        if isShortcutTwoStageMode { return true }
        guard isSupported && isEnabled else { return false }
        return !minimuxer.network.isWifiSatisfied
    }

    public func setEnabled(_ enabled: Bool) {
        UserDefaults.standard.isCellularRefreshEnabled = enabled
    }

    public static func sanitizeShortcutName(_ name: String, fallback: String = "") -> String {
        var sanitized = name.components(separatedBy: .controlCharacters).joined()
        sanitized = sanitized.replacingOccurrences(of: "\n", with: "")
        sanitized = sanitized.replacingOccurrences(of: "\r", with: "")
        sanitized = sanitized.replacingOccurrences(of: "/", with: "")
        sanitized = sanitized.replacingOccurrences(of: ":", with: "")
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.count > 100 {
            sanitized = String(sanitized.prefix(100)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return sanitized.isEmpty ? fallback : sanitized
    }

    public var turnOffDataShortcutName: String {
        let raw = UserDefaults.standard.turnOffDataShortcutName
        return Self.sanitizeShortcutName(raw, fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
    }

    public var turnOnDataShortcutName: String {
        let raw = UserDefaults.standard.turnOnDataShortcutName
        return Self.sanitizeShortcutName(raw, fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
    }

    public func setTurnOffDataShortcutName(_ name: String) {
        let sanitized = Self.sanitizeShortcutName(name, fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
        UserDefaults.standard.turnOffDataShortcutName = sanitized
    }

    public func setTurnOnDataShortcutName(_ name: String) {
        let sanitized = Self.sanitizeShortcutName(name, fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
        UserDefaults.standard.turnOnDataShortcutName = sanitized
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
        let success = await UIApplication.shared.open(url)
        debugLog("[CellularRefreshManager] Shortcut URL open completed with success: \(success)")
        return success
    }

    @discardableResult
    private func turnOffData() async -> Bool {
        let name = turnOffDataShortcutName
        let url = shortcutURL(for: name, fallback: AppConstants.Shortcuts.defaultTurnOffDataShortcutName)
        debugLog("[CellularRefreshManager] Executing TurnOffData shortcut '\(name)' (URL: \(url.absoluteString))...")
        let success = await openShortcut(url: url)
        debugLog("[CellularRefreshManager] TurnOffData shortcut finished execution.")
        return success
    }

    @discardableResult
    private func turnOnData() async -> Bool {
        let name = turnOnDataShortcutName
        let url = shortcutURL(for: name, fallback: AppConstants.Shortcuts.defaultTurnOnDataShortcutName)
        debugLog("[CellularRefreshManager] Executing turnOnData shortcut '\(name)' (URL: \(url.absoluteString))...")
        let success = await openShortcut(url: url)
        debugLog("[CellularRefreshManager] turnOnData shortcut finished execution.")
        return success
    }

    public var turnOffDataBaseDelayOverride: TimeInterval? {
        guard let value = UserDefaults.standard.object(forKey: "turnOffDataBaseDelayOverride") as? Double else {
            return nil
        }
        return max(0, value)
    }

    public var turnOnDataBaseDelayOverride: TimeInterval? {
        guard let value = UserDefaults.standard.object(forKey: "turnOnDataBaseDelayOverride") as? Double else {
            return nil
        }
        return max(0, value)
    }

    public func setTurnOffDataBaseDelayOverride(_ delay: TimeInterval?) {
        if let delay = delay {
            UserDefaults.standard.set(max(0, delay), forKey: "turnOffDataBaseDelayOverride")
        } else {
            UserDefaults.standard.removeObject(forKey: "turnOffDataBaseDelayOverride")
        }
    }

    public func setTurnOnDataBaseDelayOverride(_ delay: TimeInterval?) {
        if let delay = delay {
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

    private func sleep(baseDelay: TimeInterval, addOnDelay: TimeInterval = 0) async {
        let totalDelay = baseDelay + addOnDelay
        guard totalDelay > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
    }

    /// Kiểm tra trực tiếp tầng nhân iOS xem giao diện mạng di động (`pdp_ip*` - 4G/5G) còn giữ địa chỉ IP hay đã ngắt hoàn toàn
    private static func hasActiveCellularInterface() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
            if isUp, let namePtr = current.pointee.ifa_name, let addr = current.pointee.ifa_addr {
                let name = String(cString: namePtr)
                if name.hasPrefix("pdp_ip") {
                    let family = Int32(addr.pointee.sa_family)
                    if family == AF_INET {
                        let sin = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        if sin.sin_addr.s_addr != 0 {
                            return true
                        }
                    } else if family == AF_INET6 {
                        let sin6 = addr.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee }
                        let bytes = withUnsafeBytes(of: sin6.sin6_addr) { Array($0) }
                        let isLinkLocal = bytes.count >= 2 && bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80
                        let isUnspecified = bytes.allSatisfy { $0 == 0 }
                        if !isLinkLocal && !isUnspecified {
                            return true
                        }
                    }
                }
            }
            ptr = current.pointee.ifa_next
        }
        return false
    }

    /// Mở Phím tắt và chờ trọn vẹn chu trình: SideStore -> Phím tắt -> Quay lại SideStore (.active)
    private func runShortcutWithRoundTrip(_ action: () async -> Bool) async -> Bool {
        let wasActive = await MainActor.run { UIApplication.shared.applicationState == .active }
        let tracker = ShortcutTransitionTracker()
        if wasActive {
            await tracker.start()
        }
        defer {
            Task { @MainActor in tracker.stop() }
        }

        let success = await action()
        guard success, wasActive else { return success }

        // 1. Đợi tối đa 1.5s để iOS chuyển tiêu điểm từ SideStore sang app Phím tắt
        let leaveDeadline = Date().addingTimeInterval(1.5)
        while !tracker.didResignActive && Date() < leaveDeadline {
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        // 2. Nếu đã chuyển sang Phím tắt, đợi Phím tắt chạy xong và đưa SideStore trở lại trạng thái .active (tối đa 10s)
        if tracker.didResignActive {
            debugLog("[CellularRefreshManager] Waiting for Shortcut to finish and return SideStore to active state...")
            let returnDeadline = Date().addingTimeInterval(10.0)
            while Date() < returnDeadline {
                let isActive = await MainActor.run { UIApplication.shared.applicationState == .active }
                if tracker.didBecomeActiveAfterResign && isActive {
                    debugLog("[CellularRefreshManager] SideStore returned to active state after Shortcut.")
                    break
                }
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }
        return true
    }

    /// Dừng hẳn phiên Minimuxer cũ (tạo lúc còn 4G), khởi động mới trên LocalDevVPN và xác minh bắt tay kép tới lockdownd
    private func resetAndPrepareMinimuxer(timeout: TimeInterval) async {
        debugLog("[CellularRefreshManager] Resetting Minimuxer session cleanly for LocalDevVPN...")
        try? await minimuxerStop()
        if let pf = PairingFileManager.shared.fetchPairingFile() {
            try? await AppBootManager.shared.startMinimuxer(pairingFile: pf)
        }

        if await waitForMinimuxerReady(timeout: timeout, requireDoubleCheck: true) {
            return
        }

        // Dự phòng: Nếu lần khởi động đầu sau khi ngắt 4G vẫn còn trễ định tuyến, reset thêm 1 nhịp nữa
        debugLog("[CellularRefreshManager] First muxer warmup timed out, performing second clean restart...")
        try? await minimuxerStop()
        try? await Task.sleep(nanoseconds: 500_000_000)
        if let pf = PairingFileManager.shared.fetchPairingFile() {
            try? await AppBootManager.shared.startMinimuxer(pairingFile: pf)
        }
        _ = await waitForMinimuxerReady(timeout: 5.0, requireDoubleCheck: false)
    }

    public func waitForMinimuxerReady(timeout: TimeInterval) async -> Bool {
        await waitForMinimuxerReady(timeout: timeout, requireDoubleCheck: false)
    }

    private func waitForMinimuxerReady(timeout: TimeInterval, requireDoubleCheck: Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        debugLog("[CellularRefreshManager] Waiting for minimuxer endpoint to become ready (timeout: \(timeout)s)...")

        // 1. Đảm bảo Minimuxer đã nạp Pairing File (xử lý cả trường hợp chưa start hoặc lỗi trạng thái)
        let readyState = await minimuxer.core.isReady(withNetworkCheck: false)
        if case .success(true) = readyState {
            // Đã nạp sẵn
        } else if let pf = PairingFileManager.shared.fetchPairingFile() {
            try? await AppBootManager.shared.startMinimuxer(pairingFile: pf)
        }

        while Date() < deadline {
            await minimuxer.network.refreshEndpoint()
            // 2. Ép bắt tay trực tiếp tới lockdownd bằng fetchUDID(forceLive: true)
            if (try? await fetchUDID(forceLive: true)) != nil {
                if requireDoubleCheck {
                    // Kiểm tra xác nhận lần 2 sau 200ms để chắc chắn đường truyền RwAfc qua LocalDevVPN ổn định tuyệt đối
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    await minimuxer.network.refreshEndpoint()
                    if (try? await fetchUDID(forceLive: true)) != nil {
                        debugLog("[CellularRefreshManager] Minimuxer live lockdown connection double-verified & ready.")
                        return true
                    }
                } else {
                    debugLog("[CellularRefreshManager] Minimuxer live lockdown connection is ready.")
                    return true
                }
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        debugLog("[CellularRefreshManager] Timed out waiting for minimuxer to become ready.")
        return false
    }

    // public apis
    @discardableResult
    public func turnOffDataIfNeeded(addOnDelay: TimeInterval = 0) async -> Bool {
        guard !isShortcutTwoStageMode else { return false }
        guard isSupported && isEnabled else { return false }

        guard !minimuxer.network.isWifiSatisfied else {
            debugLog("[CellularRefreshManager] Wi-Fi is active, skipping turnOff shortcut.")
            return false
        }

        // Chống kẹt cờ didTurnOffData: Nếu cờ đang true nhưng thực tế sóng 4G (pdp_ip*) đang bật
        // (do người dùng tự bật lại hoặc lần cài trước lỗi lúc ở nền), tự động gỡ kẹt để tắt 4G lại chuẩn xác.
        if didTurnOffData {
            if Self.hasActiveCellularInterface() {
                debugLog("[CellularRefreshManager] Detected active cellular interface despite didTurnOffData == true; resetting state.")
                didTurnOffData = false
            } else {
                _ = await waitForMinimuxerReady(timeout: 5.0)
                return false
            }
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let effectiveBaseDelay = turnOffDataBaseDelayOverride ?? AppConstants.Shortcuts.defaultTurnOffDataBaseDelay

        let success = await runShortcutWithRoundTrip {
            await self.turnOffData()
        }

        if success {
            didTurnOffData = true

            // Đợi nhân iOS thực sự thu hồi địa chỉ IP khỏi giao diện 4G (pdp_ip*) (tối đa 5.0s)
            let dropDeadline = Date().addingTimeInterval(5.0)
            while Self.hasActiveCellularInterface() && Date() < dropDeadline {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
            debugLog("[CellularRefreshManager] Cellular interface teardown check completed (active: \(Self.hasActiveCellularInterface())).")

            // Nghỉ đệm tối thiểu 0.9s sau khi về lại app & ngắt 4G (đồng thời tôn trọng cấu hình delay của người dùng)
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let remainingUserDelay = (effectiveBaseDelay + addOnDelay) - elapsed
            await sleep(baseDelay: max(0.9, remainingUserDelay))

            // Khởi động lại Minimuxer sạch trên LocalDevVPN và xác minh lockdownd thông suốt trước khi SendAppOperation chạy RwAfc
            await resetAndPrepareMinimuxer(timeout: 8.0)
        }
        return success
    }

    @discardableResult
    public func turnOnDataIfNeeded(addOnDelay: TimeInterval = 0) async -> Bool {
        guard !isShortcutTwoStageMode else { return false }
        guard didTurnOffData else { return false }

        // Nếu app đang chuyển giao từ nền về chính diện, chờ nhẹ tối đa 2.5s để UIApplication.open không bị iOS từ chối
        let activeWaitDeadline = Date().addingTimeInterval(2.5)
        while Date() < activeWaitDeadline {
            let isActive = await MainActor.run { UIApplication.shared.applicationState == .active }
            if isActive { break }
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        let effectiveBaseDelay = turnOnDataBaseDelayOverride ?? AppConstants.Shortcuts.defaultTurnOnDataBaseDelay

        let success = await runShortcutWithRoundTrip {
            await self.turnOnData()
        }

        // Luôn đặt lại cờ để không bao giờ kẹt cho lần cài đặt tiếp theo
        didTurnOffData = false

        if success {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let remainingDelay = (effectiveBaseDelay + addOnDelay) - elapsed
            if remainingDelay > 0 {
                await sleep(baseDelay: remainingDelay)
            }
        }
        return success
    }
}
