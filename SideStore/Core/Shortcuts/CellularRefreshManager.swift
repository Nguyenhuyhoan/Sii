
//
//  CellularRefreshManager.swift
//  SideStore
//
//  Created by SideStore Team.
//

import Foundation
import UIKit
import Darwin
#if canImport(minimuxer)
import minimuxer
#endif

@MainActor
public final class CellularRefreshManager {
    public static let shared = CellularRefreshManager()

    private nonisolated enum Keys {
        static let enabled = "SS_CELLULAR_REFRESH_ENABLED"
        static let shortcutTurnOffName = "SS_CELLULAR_SHORTCUT_OFF"
        static let shortcutTurnOnName = "SS_CELLULAR_SHORTCUT_ON"
        static let deviceID = "deviceID"
        static let pairingFile = "pairingFile"
    }

    public static let defaultTurnOffShortcutName = "SideStore Turn Off Data"
    public static let defaultTurnOnShortcutName = "SideStore Turn On Data"

    public static let turnOffShortcutICloudURL = URL(string: "https://www.icloud.com/shortcuts/27762c3ee91e4f0e8adba06a8a3d8d4c")!
    public static let turnOnShortcutICloudURL = URL(string: "https://www.icloud.com/shortcuts/d6db3c41465c42e88a32049e4bf55a2e")!

    public var isSupported: Bool {
        true
    }

    public var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.enabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.enabled)
            NotificationCenter.default.post(name: .cellularRefreshPreferencesChanged, object: nil)
        }
    }

    public var turnOffShortcutName: String {
        get {
            let val = UserDefaults.standard.string(forKey: Keys.shortcutTurnOffName)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return val.isEmpty ? Self.defaultTurnOffShortcutName : val
        }
        set {
            UserDefaults.standard.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: Keys.shortcutTurnOffName
            )
        }
    }

    public var turnOnShortcutName: String {
        get {
            let val = UserDefaults.standard.string(forKey: Keys.shortcutTurnOnName)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return val.isEmpty ? Self.defaultTurnOnShortcutName : val
        }
        set {
            UserDefaults.standard.set(
                newValue.trimmingCharacters(in: .whitespacesAndNewlines),
                forKey: Keys.shortcutTurnOnName
            )
        }
    }

    public var isShortcutTwoStageMode: Bool = false
    public private(set) var didTurnOffData: Bool = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    public var turnOffDataBaseDelayOverride: TimeInterval?

    public var isCellularMode: Bool {
        #if canImport(minimuxer)
        return isSupported && isEnabled && !minimuxer.network.isWifiSatisfied
        #else
        return isSupported && isEnabled
        #endif
    }

    private init() {
        UserDefaults.standard.register(defaults: [
            Keys.enabled: false,
            Keys.shortcutTurnOffName: Self.defaultTurnOffShortcutName,
            Keys.shortcutTurnOnName: Self.defaultTurnOnShortcutName
        ])
        _ = Self.resolveDeviceUDID()
    }

    // =========================================================================
    // MARK: - LẤY UDID TỪ 3 NGUỒN CHÍNH XÁC NHẤT (ƯU TIÊN 1 -> 2 -> 3)
    // =========================================================================

    /// Lấy UDID chuẩn của thiết bị theo đúng 3 thứ tự ưu tiên:
    /// 1. Trực tiếp từ `minimuxer.fetch_udid()`
    /// 2. Trực tiếp từ File Pairing của máy (`pairingFile` / `ALTPairingFile.plist`)
    /// 3. Từ `UserDefaults.standard` (`deviceID`) đã lưu
    @discardableResult
    public nonisolated static func resolveDeviceUDID() -> String? {
        // ƯU TIÊN 1: Lấy trực tiếp từ Minimuxer (chính xác nhất khi kết nối sẵn sàng)
        #if canImport(minimuxer)
        if let liveUDID = try? minimuxer.fetch_udid() {
            let clean = liveUDID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                saveDeviceIDIfNeeded(clean)
                return clean
            }
        }
        #endif

        // ƯU TIÊN 2: Bóc trực tiếp khóa UDID từ File Pairing của máy (luôn có sẵn kể cả khi đang bật 4G)
        if let pairingUDID = extractUDIDFromPairingFile() {
            saveDeviceIDIfNeeded(pairingUDID)
            return pairingUDID
        }

        // ƯU TIÊN 3: Lấy từ UserDefaults (deviceID)
        if let savedDeviceID = UserDefaults.standard.string(forKey: Keys.deviceID) {
            let clean = savedDeviceID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !clean.isEmpty {
                return clean
            }
        }

        return nil
    }

    private nonisolated static func saveDeviceIDIfNeeded(_ udid: String) {
        guard !udid.isEmpty else { return }
        if UserDefaults.standard.string(forKey: Keys.deviceID) != udid {
            UserDefaults.standard.set(udid, forKey: Keys.deviceID)
        }
    }

    /// Đọc khóa UDID từ dữ liệu Pairing File của SideStore
    private nonisolated static func extractUDIDFromPairingFile() -> String? {
        let parsePlist: (Data) -> String? = { data in
            guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
                return nil
            }
            for key in ["UDID", "UniqueDeviceID", "DeviceUDID"] {
                if let val = plist[key] as? String {
                    let clean = val.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !clean.isEmpty { return clean }
                }
            }
            return nil
        }

        // Kiểm tra chuỗi/dữ liệu Pairing lưu trong UserDefaults
        if let pairingString = UserDefaults.standard.string(forKey: Keys.pairingFile),
           let data = pairingString.data(using: .utf8),
           let udid = parsePlist(data) {
            return udid
        }

        if let pairingData = UserDefaults.standard.data(forKey: Keys.pairingFile),
           let udid = parsePlist(pairingData) {
            return udid
        }

        // Kiểm tra file ALTPairingFile.plist trong thư mục Documents / Application Support
        let fm = FileManager.default
        for dir in [FileManager.SearchPathDirectory.documentDirectory, .applicationSupportDirectory] {
            if let baseURL = fm.urls(for: dir, in: .userDomainMask).first {
                let fileURL = baseURL.appendingPathComponent("ALTPairingFile.plist")
                if let data = try? Data(contentsOf: fileURL),
                   let udid = parsePlist(data) {
                    return udid
                }
            }
        }

        return nil
    }

    // =========================================================================
    // MARK: - QUẢN LÝ CHẠY NGẦM
    // =========================================================================
    private func beginBackgroundKeepAlive() {
        endBackgroundKeepAlive()
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "SideStoreCellularShortcutSwitch") { [weak self] in
            Task { @MainActor in self?.endBackgroundKeepAlive() }
        }
    }

    private func endBackgroundKeepAlive() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    // =========================================================================
    // MARK: - KIỂM TRA MẠNG & MINIMUXER
    // =========================================================================
    /// Kiểm tra tầng nhân iOS xem giao diện dữ liệu di động chính (`pdp_ip0`) còn giữ IP hay đã ngắt hoàn toàn
    /// (Bỏ qua pdp_ip1, pdp_ip2... vì đó là cổng VoLTE/IMS luôn giữ IP kể cả khi đã tắt 4G)
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

    @discardableResult
    public func waitForMinimuxerReady(timeout: TimeInterval = 8.0) async -> Bool {
        _ = Self.resolveDeviceUDID()
        #if canImport(minimuxer)
        let deadline = Date().addingTimeInterval(timeout)
        var retryTick = 0
        while Date() < deadline {
            if minimuxer.Status.shared.ready && minimuxer.Status.shared.deviceConnected {
                _ = Self.resolveDeviceUDID()
                return true
            }
            if retryTick % 3 == 0 {
                minimuxer.retryFetchudid()
            }
            retryTick += 1
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        _ = Self.resolveDeviceUDID()
        return minimuxer.Status.shared.ready
        #else
        return true
        #endif
    }

    /// Sau khi tắt 4G, ép minimuxer tạo kết nối mới qua LocalDevVPN
    @discardableResult
    private func resetAndPrepareMinimuxer(timeout: TimeInterval = 8.0) async -> Bool {
        #if canImport(minimuxer)
        let deadline = Date().addingTimeInterval(timeout)
        var retryTick = 0
        while Date() < deadline {
            if retryTick % 3 == 0 {
                minimuxer.retryFetchudid()
            }
            retryTick += 1
            try? await Task.sleep(nanoseconds: 300_000_000)
            if minimuxer.Status.shared.ready && minimuxer.Status.shared.deviceConnected {
                _ = Self.resolveDeviceUDID()
                return true
            }
        }
        _ = Self.resolveDeviceUDID()
        return minimuxer.Status.shared.ready
        #else
        return true
        #endif
    }

    private func sleep(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }

    // =========================================================================
    // MARK: - PUBLIC APIS
    // =========================================================================
    @discardableResult
    public func turnOffDataIfNeeded(addOnDelay: TimeInterval = 0) async -> Bool {
        // Luôn đồng bộ UDID từ 3 nguồn ưu tiên vào UserDefaults trước tiên
        _ = Self.resolveDeviceUDID()

        guard !isShortcutTwoStageMode, isSupported, isEnabled else {
            return false
        }

        // Nếu trong phiên này (Install IPA / Refresh / Refresh All) ĐÃ gọi tắt 4G rồi,
        // thì tuyệt đối không mở Phím tắt Tắt 4G lần 2 nữa, chỉ đảm bảo Minimuxer sẵn sàng cho từng app.
        if didTurnOffData {
            _ = await waitForMinimuxerReady(timeout: 5.0)
            return false
        }

        #if canImport(minimuxer)
        guard !minimuxer.network.isWifiSatisfied else {
            return false
        }
        #endif

        let success = await runShortcutWithRoundTrip { await self.turnOffData() }
        guard success else { return false }

        didTurnOffData = true

        // Đợi iOS thu hồi hoàn toàn địa chỉ IP khỏi cổng 4G chính pdp_ip0 (tối đa 5s)
        let dropDeadline = Date().addingTimeInterval(5.0)
        while Self.hasActiveCellularInterface() && Date() < dropDeadline {
            await sleep(0.2)
        }

        // Nghỉ đệm để bảng định tuyến chuyển hẳn sang utun (LocalDevVPN)
        let customDelay = turnOffDataBaseDelayOverride ?? 1.0
        await sleep(max(1.0, customDelay) + addOnDelay)

        _ = await resetAndPrepareMinimuxer(timeout: 8.0)
        return true
    }

    public func turnOnDataIfNeeded() async {
        guard !isShortcutTwoStageMode, isSupported, isEnabled, didTurnOffData else { return }
        didTurnOffData = false
        _ = await runShortcutWithRoundTrip { await self.turnOnData() }
        await sleep(1.5)
    }

    @discardableResult
    public func turnOffData() async -> Bool {
        await runShortcut(named: turnOffShortcutName)
    }

    @discardableResult
    public func turnOnData() async -> Bool {
        await runShortcut(named: turnOnShortcutName)
    }

    public func resetState() {
        didTurnOffData = false
        endBackgroundKeepAlive()
    }

    // =========================================================================
    // MARK: - SHORTCUT EXECUTION
    // =========================================================================
    @discardableResult
    private func runShortcutWithRoundTrip(trigger: @MainActor () async -> Bool) async -> Bool {
        while UIApplication.shared.applicationState != .active {
            await sleep(0.15)
        }

        beginBackgroundKeepAlive()
        defer { endBackgroundKeepAlive() }

        let nc = NotificationCenter.default
        var didResignActive = false
        let resignObs = nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { _ in
            didResignActive = true
        }
        defer { nc.removeObserver(resignObs) }

        let opened = await trigger()
        guard opened else { return false }

        // 1. Chờ tối đa 3 giây để nhảy sang ứng dụng Phím tắt
        let resignDeadline = Date().addingTimeInterval(3.0)
        while !didResignActive && UIApplication.shared.applicationState == .active && Date() < resignDeadline {
            await sleep(0.05)
        }

        // 2. Chờ đến khi Phím tắt chạy lệnh "Mở ứng dụng SideStore" quay trở lại (tối đa 25s)
        let activeDeadline = Date().addingTimeInterval(25.0)
        while UIApplication.shared.applicationState != .active && Date() < activeDeadline {
            await sleep(0.1)
        }

        // 3. Nghỉ 0.5s để UI SideStore ổn định hoàn toàn trên Foreground
        await sleep(0.5)
        return UIApplication.shared.applicationState == .active
    }

    @discardableResult
    private func runShortcut(named shortcutName: String) async -> Bool {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&+=?#/")

        guard let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)")
        else { return false }

        return await withCheckedContinuation { continuation in
            UIApplication.shared.open(url, options: [:]) { success in
                continuation.resume(returning: success)
            }
        }
    }
}

public extension Notification.Name {
    static let cellularRefreshPreferencesChanged = Notification.Name("SSCellularRefreshPreferencesChanged")
}
