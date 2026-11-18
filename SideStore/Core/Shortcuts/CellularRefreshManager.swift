
//
//  CellularRefreshManager.swift
//  SideStore
//
//  Quản lý quy trình làm mới và cài đặt ứng dụng tự động qua mạng di động (4G/5G)
//  Kết hợp với ứng dụng Phím tắt (Shortcuts) của iOS.
//

import UIKit
import Minimuxer
import OSLog
import AltSign
import CoreData

public final class CellularRefreshManager {
    public static let shared = CellularRefreshManager()

    /// Trạng thái đang thực hiện luồng làm mới/cài đặt bằng 4G
    public private(set) var isCellularMode: Bool = false

    /// Chế độ chạy Phím tắt 2 giai đoạn (Giai đoạn 1: Đang bật 4G lấy Profile -> Lưu cache; Giai đoạn 2: Đã tắt 4G -> Tiêm Profile)
    public var isShortcutTwoStageMode: Bool = false

    /// Đánh dấu đã gọi phím tắt tắt 4G trong phiên hiện tại (tránh gọi lặp lại nhiều lần)
    public private(set) var hasTurnedOffData: Bool = false

    public struct StagedProfileBatch: Codable {
        public let bundleID: String
        public let profileDataList: [Data]
        public let timestamp: Date

        public init(bundleID: String, profileDataList: [Data], timestamp: Date = Date()) {
            self.bundleID = bundleID
            self.profileDataList = profileDataList
            self.timestamp = timestamp
        }
    }

    private var stagedFileURL: URL {
        FileManager.default.documentsDirectory.appendingPathComponent("cellular_staged_batches.json")
    }

    /// Lưu trữ các gói Provisioning Profile đã lấy thành công ở Giai đoạn 1 (để Giai đoạn 2 tiêm vào máy)
    public var stagedBatches: [StagedProfileBatch] {
        get {
            guard let data = try? Data(contentsOf: stagedFileURL),
                  let batches = try? JSONDecoder().decode([StagedProfileBatch].self, from: data) else {
                return []
            }
            return batches
        }
        set {
            if newValue.isEmpty {
                try? FileManager.default.removeItem(at: stagedFileURL)
            } else if let data = try? JSONEncoder().encode(newValue) {
                try? data.write(to: stagedFileURL, options: .atomic)
            }
        }
    }

    /// Kiểm tra xem có dữ liệu Profile vừa lấy trong vòng 10 phút gần đây không
    public var hasRecentStagedBatches: Bool {
        let batches = stagedBatches
        guard !batches.isEmpty else { return false }
        let validBatches = batches.filter { Date().timeIntervalSince($0.timestamp) < 600 }
        if validBatches.count != batches.count {
            stagedBatches = validBatches
        }
        return !validBatches.isEmpty
    }

    private var foregroundObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Hệ thống 6 Lớp Dự Phòng lấy UDID thiết bị (Không cần tắt 4G)

    /// Trích xuất UDID trực tiếp từ dữ liệu tệp ghép nối (Pairing File plist) lưu trong máy.
    /// Hoạt động hoàn toàn offline (0ms), không phụ thuộc mạng hay Minimuxer.
    public func extractUDIDFromPairingFileData(_ data: Data? = UserDefaults.standard.pairingFile) -> String? {
        guard let data = data, !data.isEmpty else { return nil }

        // Phương án A: Giải mã chuẩn PropertyList (XML hoặc Binary Plist)
        if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            let possibleKeys = ["UDID", "DeviceUDID", "udid", "UniqueDeviceID"]
            for key in possibleKeys {
                if let udid = plist[key] as? String,
                   !udid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return udid.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // Phương án B: Quét Regex trực tiếp trên chuỗi XML nếu tệp có định dạng đặc biệt
        if let xmlString = String(data: data, encoding: .utf8),
           let range = xmlString.range(of: "<key>UDID</key>\\s*<string>([^<]+)</string>", options: .regularExpression) {
            let matched = String(xmlString[range])
            if let start = matched.range(of: "<string>")?.upperBound,
               let end = matched.range(of: "</string>")?.lowerBound {
                let udid = String(matched[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !udid.isEmpty {
                    return udid
                }
            }
        }

        return nil
    }

    /// Trích xuất UDID từ Provisioning Profile của chính ứng dụng SideStore đang chạy
    public func extractUDIDFromEmbeddedProfile() -> String? {
        guard let profileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let profile = ALTProvisioningProfile(url: profileURL),
              let firstUDID = profile.provisionedDevices.first,
              !firstUDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return firstUDID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Trích xuất UDID từ Provisioning Profile của bất kỳ ứng dụng nào đã cài trên máy (Lưu trong thư mục Apps)
    public func extractUDIDFromInstalledAppsProfiles() -> String? {
        guard let appsDir = FileManager.default.installedAppsDirectory,
              let contents = try? FileManager.default.contentsOfDirectory(at: appsDir, includingPropertiesForKeys: nil) else {
            return nil
        }

        for dir in contents {
            let profileURL = dir.appendingPathComponent("embedded.mobileprovision")
            if let profile = ALTProvisioningProfile(url: profileURL),
               let firstUDID = profile.provisionedDevices.first,
               !firstUDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return firstUDID.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    /// Đồng bộ và làm giàu bộ nhớ đệm UDID từ mọi nguồn offline sẵn có.
    /// Có thể gọi bất cứ lúc nào để đảm bảo `cachedDeviceUDID` luôn có giá trị.
    @discardableResult
    public func syncOfflineCachedUDID() -> String? {
        if let cached = UserDefaults.standard.cachedDeviceUDID,
           !cached.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cached.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let pairingUDID = extractUDIDFromPairingFileData() {
            UserDefaults.standard.cachedDeviceUDID = pairingUDID
            Logger.main.notice("[CellularRefresh] Đã trích xuất và lưu UDID từ Pairing File: \(pairingUDID)")
            return pairingUDID
        }

        if let profileUDID = extractUDIDFromEmbeddedProfile() {
            UserDefaults.standard.cachedDeviceUDID = profileUDID
            Logger.main.notice("[CellularRefresh] Đã trích xuất và lưu UDID từ Embedded Profile: \(profileUDID)")
            return profileUDID
        }

        if let installedProfileUDID = extractUDIDFromInstalledAppsProfiles() {
            UserDefaults.standard.cachedDeviceUDID = installedProfileUDID
            Logger.main.notice("[CellularRefresh] Đã trích xuất và lưu UDID từ Profile ứng dụng đã cài: \(installedProfileUDID)")
            return installedProfileUDID
        }

        return nil
    }

    /// Lấy UDID của thiết bị với 6 lớp dự phòng an toàn, đồng bộ cho cả Wi-Fi và 4G.
    /// Đảm bảo khi cài IPA hoặc Refresh qua 4G KHÔNG BAO GIỜ phải tắt 4G ở bước xác thực/chứng chỉ.
    public func resolveDeviceUDID() async throws -> String {
        // Khi đang dùng Wi-Fi (hoặc 4G đã tắt sẵn): Thử hỏi Minimuxer trước để lấy UDID trực tiếp
        let canQueryMinimuxerDirectly = !isCellularMode || hasTurnedOffData || !hasActiveCellularInterface()

        if canQueryMinimuxerDirectly {
            if let muxerUDID = try? Minimuxer.fetchDeviceUDID(),
               !muxerUDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanUDID = muxerUDID.trimmingCharacters(in: .whitespacesAndNewlines)
                UserDefaults.standard.cachedDeviceUDID = cleanUDID
                return cleanUDID
            }
        }

        // LỚP DỰ PHÒNG 1: Lấy từ UserDefaults.standard.cachedDeviceUDID
        if let cachedUDID = UserDefaults.standard.cachedDeviceUDID,
           !cachedUDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let cleanUDID = cachedUDID.trimmingCharacters(in: .whitespacesAndNewlines)
            Logger.main.notice("[CellularRefresh] Sử dụng UDID từ bộ nhớ đệm (Lớp 1): \(cleanUDID)")
            return cleanUDID
        }

        // LỚP DỰ PHÒNG 2: Giải mã trực tiếp từ Pairing File trong bộ nhớ (0ms, không cần tắt 4G)
        if let pairingUDID = extractUDIDFromPairingFileData() {
            UserDefaults.standard.cachedDeviceUDID = pairingUDID
            Logger.main.notice("[CellularRefresh] Sử dụng UDID trích xuất từ Pairing File (Lớp 2): \(pairingUDID)")
            return pairingUDID
        }

        // LỚP DỰ PHÒNG 3: Đọc từ embedded.mobileprovision của chính ứng dụng đang chạy
        if let profileUDID = extractUDIDFromEmbeddedProfile() {
            UserDefaults.standard.cachedDeviceUDID = profileUDID
            Logger.main.notice("[CellularRefresh] Sử dụng UDID trích xuất từ Embedded Profile (Lớp 3): \(profileUDID)")
            return profileUDID
        }

        // LỚP DỰ PHÒNG 4: Đọc từ Provisioning Profile của các ứng dụng đã cài trên máy
        if let installedProfileUDID = extractUDIDFromInstalledAppsProfiles() {
            UserDefaults.standard.cachedDeviceUDID = installedProfileUDID
            Logger.main.notice("[CellularRefresh] Sử dụng UDID từ Profile ứng dụng đã cài (Lớp 4): \(installedProfileUDID)")
            return installedProfileUDID
        }

        // LỚP DỰ PHÒNG 5: Thử gọi trực tiếp Minimuxer (nếu lúc đầu chưa thử)
        if !canQueryMinimuxerDirectly {
            if let muxerUDID = try? Minimuxer.fetchDeviceUDID(),
               !muxerUDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanUDID = muxerUDID.trimmingCharacters(in: .whitespacesAndNewlines)
                UserDefaults.standard.cachedDeviceUDID = cleanUDID
                Logger.main.notice("[CellularRefresh] Lấy thành công UDID trực tiếp từ Minimuxer (Lớp 5): \(cleanUDID)")
                return cleanUDID
            }
        }

        // LỚP DỰ PHÒNG 6 (Phương án cuối cùng): Chỉ khi cả 5 lớp trên đều trống và đang bật 4G
        if isCellularMode && !hasTurnedOffData {
            Logger.main.notice("[CellularRefresh] Cả 5 lớp UDID đều trống khi đang dùng 4G. Chuyển sang Lớp 6 (tắt 4G tạm thời)...")
            let switched = await turnOffDataIfNeeded()
            if switched,
               let muxerUDID = try? Minimuxer.fetchDeviceUDID(),
               !muxerUDID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let cleanUDID = muxerUDID.trimmingCharacters(in: .whitespacesAndNewlines)
                UserDefaults.standard.cachedDeviceUDID = cleanUDID
                // Bật lại 4G để bước FetchProvisioningProfiles tiếp theo có Internet tải Profile từ Apple
                await turnOnDataIfNeeded()
                return cleanUDID
            }
        }

        throw MinimuxerError.DeviceFetchError
    }

    // MARK: - Quản lý phiên mạng 4G / Wi-Fi

    /// Kiểm tra và khởi tạo trạng thái mạng trước khi bắt đầu Pipeline
    public func beginSessionIfNeeded() {
        // Đảm bảo bộ nhớ đệm UDID luôn sẵn sàng trước mọi phiên làm việc
        syncOfflineCachedUDID()

        guard UserDefaults.standard.cellularRefreshEnabled else {
            isCellularMode = false
            hasTurnedOffData = false
            return
        }

        let isWifiConnected = Minimuxer.shared.network.isWifiSatisfied
        // Nếu không có Wi-Fi và tính năng Cellular Refresh được bật -> Kích hoạt chế độ 4G
        isCellularMode = !isWifiConnected
        hasTurnedOffData = false

        if isCellularMode {
            Logger.main.notice("[CellularRefresh] Bắt đầu phiên làm việc qua mạng di động (4G/5G).")
        }
    }

    /// Kết thúc phiên làm việc và đặt lại trạng thái
    public func endSession() {
        isCellularMode = false
        hasTurnedOffData = false
        removeObserver()
    }

    /// Gọi Phím tắt để TẮT dữ liệu di động (4G/5G) và chờ người dùng/Phím tắt quay lại ứng dụng
    @MainActor
    public func turnOffDataIfNeeded() async -> Bool {
        guard isCellularMode else { return true }
        guard !hasTurnedOffData else { return true }

        // CHỐT CHẶN AN TOÀN: Nếu kiểm tra giao diện mạng thực tế thấy 4G (pdp_ip*) đã tắt sẵn rồi,
        // tuyệt đối không gọi Phím tắt lần nữa để tránh nhảy qua Phím tắt 2 lần!
        if !hasActiveCellularInterface() {
            Logger.main.notice("[CellularRefresh] Phát hiện 4G đã tắt sẵn trên thiết bị. Bỏ qua gọi Phím tắt Tắt 4G.")
            hasTurnedOffData = true
            let muxerReady = await resetAndPrepareMinimuxer()
            if !muxerReady {
                Logger.main.error("[CellularRefresh] Minimuxer vẫn chưa sẵn sàng sau khi kiểm tra 4G đã tắt.")
            }
            return true
        }

        let shortcutName = UserDefaults.standard.turnOffDataShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortcutName.isEmpty,
              let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") else {
            Logger.main.error("[CellularRefresh] Tên phím tắt tắt 4G không hợp lệ.")
            return false
        }

        // Đảm bảo ứng dụng đang ở trạng thái Active trước khi gọi mở URL sang Phím tắt
        await waitForApplicationActive(timeout: 3.0)

        Logger.main.notice("[CellularRefresh] Đang gọi phím tắt tắt 4G: \(shortcutName)")
        hasTurnedOffData = true

        let switched = await openShortcutAndWaitForReturn(url: url, timeout: 25.0)
        guard switched else {
            // Nếu mở Phím tắt thất bại và 4G vẫn còn bật -> Khôi phục cờ để có thể thử lại
            if hasActiveCellularInterface() {
                hasTurnedOffData = false
            }
            return false
        }

        // Chờ giao diện mạng di động (pdp_ip*) thực sự ngắt kết nối ở tầng hệ thống iOS
        await waitForCellularDisconnect(maxWaitSeconds: 6.0)

        // Khởi động lại hoặc xác nhận kết nối Minimuxer qua LocalDevVPN
        let muxerReady = await resetAndPrepareMinimuxer()
        if !muxerReady {
            Logger.main.error("[CellularRefresh] Minimuxer vẫn chưa sẵn sàng sau khi tắt 4G và reset.")
        }

        return true
    }

    /// Gọi Phím tắt để BẬT lại dữ liệu di động (4G/5G) sau khi đã tiêm xong toàn bộ Profile hoặc cài xong IPA
    @MainActor
    public func turnOnDataIfNeeded() async {
        guard isCellularMode && hasTurnedOffData else { return }

        // Nếu kiểm tra thấy 4G thực tế đã được bật lại rồi thì chỉ cần đặt lại cờ trạng thái
        if hasActiveCellularInterface() {
            Logger.main.notice("[CellularRefresh] Phát hiện 4G đã bật sẵn. Kết thúc phiên tắt 4G.")
            hasTurnedOffData = false
            return
        }

        let shortcutName = UserDefaults.standard.turnOnDataShortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortcutName.isEmpty,
              let encodedName = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "shortcuts://run-shortcut?name=\(encodedName)") else {
            Logger.main.error("[CellularRefresh] Tên phím tắt bật 4G không hợp lệ.")
            hasTurnedOffData = false
            return
        }

        // Đợi ứng dụng thực sự ở trạng thái Active trên màn hình để iOS không chặn lệnh mở URL
        await waitForApplicationActive(timeout: 4.0)

        Logger.main.notice("[CellularRefresh] Đang gọi phím tắt bật lại 4G: \(shortcutName)")
        _ = await openShortcutAndWaitForReturn(url: url, timeout: 20.0)
        hasTurnedOffData = false
    }

    // MARK: - Kiểm tra kết nối tầng hệ thống & Khôi phục Minimuxer

    /// Đợi đến khi ứng dụng thực sự ở trạng thái `.active` (tránh lỗi iOS nuốt lệnh `UIApplication.shared.open` khi vừa chuyển cảnh)
    @MainActor
    private func waitForApplicationActive(timeout: TimeInterval) async {
        let startTime = Date()
        while UIApplication.shared.applicationState != .active {
            if Date().timeIntervalSince(startTime) >= timeout {
                break
            }
            try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
        }
    }

    /// Kiểm tra xem giao diện mạng di động (`pdp_ip0`, `pdp_ip1`,...) của iOS có còn giữ địa chỉ IP hoạt động không
    public func hasActiveCellularInterface() -> Bool {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return false }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let name = String(cString: current.pointee.ifa_name)
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0

            if name.hasPrefix("pdp_ip") && isUp && isRunning, let addr = current.pointee.ifa_addr {
                let family = addr.pointee.sa_family
                if family == UInt8(AF_INET) || family == UInt8(AF_INET6) {
                    return true
                }
            }
            ptr = current.pointee.ifa_next
        }
        return false
    }

    /// Chờ cho đến khi hệ điều hành thực sự ngắt địa chỉ IP của mạng di động (4G/5G)
    private func waitForCellularDisconnect(maxWaitSeconds: TimeInterval) async {
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < maxWaitSeconds {
            if !hasActiveCellularInterface() {
                Logger.main.notice("[CellularRefresh] Giao diện mạng 4G (pdp_ip) đã ngắt hoàn toàn.")
                try? await Task.sleep(nanoseconds: 500_000_000) // Đợi thêm 0.5s để bảng định tuyến VPN ổn định
                return
            }
            try? await Task.sleep(nanoseconds: 300_000_000) // Kiểm tra mỗi 0.3s
        }
        Logger.main.warning("[CellularRefresh] Hết thời gian chờ ngắt pdp_ip, tiếp tục thực hiện kết nối Minimuxer.")
    }

    /// Làm mới lại hoàn toàn Minimuxer và đợi cho đến khi kết nối thiết bị qua LocalDevVPN sẵn sàng
    public func resetAndPrepareMinimuxer() async -> Bool {
        Logger.main.notice("[CellularRefresh] Đang kiểm tra và làm mới kết nối Minimuxer qua LocalDevVPN...")

        // Kiểm tra nhanh xem sau khi ngắt 4G, Minimuxer đã tự thông qua LocalDevVPN chưa
        if Minimuxer.shared.isDeviceReady() || Minimuxer.shared.testDeviceConnection() {
            Logger.main.notice("[CellularRefresh] Minimuxer đã sẵn sàng ngay sau khi ngắt 4G!")
            return true
        }

        for attempt in 1...3 {
            // Đánh thức kết nối Minimuxer trước, nếu chưa được mới gọi startWithLogger
            Minimuxer.shared.Adopted()

            for _ in 1...4 {
                if Minimuxer.shared.isDeviceReady() || Minimuxer.shared.testDeviceConnection() {
                    Logger.main.notice("[CellularRefresh] Minimuxer đã kết nối thành công sau Adopted ở lần thử \(attempt)!")
                    return true
                }
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            }

            if let pairingFile = UserDefaults.standard.pairingFile {
                let documentsDirectory = FileManager.default.documentsDirectory.path
                _ = try? Minimuxer.startWithLogger(pairingFile, logPath: documentsDirectory, consoleLogging: true)
            }

            for _ in 1...5 {
                if Minimuxer.shared.isDeviceReady() || Minimuxer.shared.testDeviceConnection() {
                    Logger.main.notice("[CellularRefresh] Minimuxer đã kết nối thành công sau startWithLogger ở lần thử \(attempt)!")
                    return true
                }
                try? await Task.sleep(nanoseconds: 400_000_000) // 0.4s
            }

            Logger.main.warning("[CellularRefresh] Lần thử kết nối Minimuxer thứ \(attempt) chưa phản hồi, đang thử lại...")
        }

        return Minimuxer.shared.isDeviceReady() || Minimuxer.shared.testDeviceConnection()
    }

    // MARK: - Private Helpers

    @MainActor
    private func openShortcutAndWaitForReturn(url: URL, timeout: TimeInterval) async -> Bool {
        guard UIApplication.shared.canOpenURL(url) else {
            Logger.main.error("[CellularRefresh] Thiết bị không thể mở URL Phím tắt: \(url.absoluteString)")
            return false
        }

        return await withCheckedContinuation { continuation in
            var isResolved = false

            let resolve: (Bool) -> Void = { [weak self] result in
                guard !isResolved else { return }
                isResolved = true
                self?.removeObserver()
                continuation.resume(returning: result)
            }

            // Lắng nghe sự kiện người dùng / Phím tắt chuyển ngược về lại SideStore
            self.foregroundObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    // Đợi nhẹ 0.8s để hệ thống ổn định sau khi chuyển về app
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    resolve(true)
                }
            }

            // Mở ứng dụng Phím tắt
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    Logger.main.error("[CellularRefresh] Không thể mở ứng dụng Phím tắt.")
                    resolve(false)
                }
            }

            // Timeout an toàn phòng trường hợp người dùng không quay lại app
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if !isResolved {
                    Logger.main.warning("[CellularRefresh] Hết thời gian chờ phản hồi từ Phím tắt (\(timeout)s).")
                    resolve(true)
                }
            }
        }
    }

    private func removeObserver() {
        if let observer = foregroundObserver {
            NotificationCenter.default.removeObserver(observer)
            foregroundObserver = nil
        }
    }
}
