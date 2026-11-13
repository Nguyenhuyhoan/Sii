
//
//  String+Localization.swift
//  AltStore
//
//  Created by Magesh K on 8/9/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import UIKit
import SwiftUI

public extension String {
    init(formatted: String, comment: String? = nil, _ args: String...) {
        self.init(format: NSLocalizedString(formatted, comment: comment ?? ""), args)
    }
}

public func systemLocalizedString(_ string: String) -> String {
    let bundle = Bundle(for: UIApplication.self)
    let localizedString = bundle.localizedString(forKey: string, value: "com.sidestore.SystemLocalizedStringNotFound", table: nil)
    if localizedString == "com.sidestore.SystemLocalizedStringNotFound" {
        return NSLocalizedString(string, comment: "")
    }
    return localizedString
}

// MARK: - Quản lý ngôn ngữ toàn ứng dụng (Tiếng Việt / Tiếng Anh)

public enum CheckAppLanguage: String, CaseIterable {
    case vi = "vi"
    case en = "en"

    public static let storageKey = "com.sidestore.check.selectedLanguage"

    public static var current: CheckAppLanguage {
        get {
            if let raw = UserDefaults.standard.string(forKey: storageKey),
               let saved = CheckAppLanguage(rawValue: raw) {
                return saved
            }
            return .vi
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: storageKey)
        }
    }

    public func tr(_ vi: String, _ en: String) -> String {
        self == .vi ? vi : en
    }
}

/// Hàm dịch nhanh theo ngôn ngữ đang chọn hoặc truyền trực tiếp
@inline(__always)
public func appTr(_ vi: String, _ en: String, lang: CheckAppLanguage = .current) -> String {
    lang == .vi ? vi : en
}

// MARK: - Kho lưu trữ chuỗi văn bản tập trung cho toàn ứng dụng

public enum AppStrings {

    // MARK: 1. Dùng chung (Common)
    public enum Common {
        public static func done(_ l: CheckAppLanguage = .current) -> String { l.tr("Xong", "Done") }
        public static func cancel(_ l: CheckAppLanguage = .current) -> String { l.tr("Huỷ", "Cancel") }
        public static func delete(_ l: CheckAppLanguage = .current) -> String { l.tr("Xoá", "Delete") }
        public static func remove(_ l: CheckAppLanguage = .current) -> String { l.tr("Gỡ bỏ", "Remove") }
        public static func save(_ l: CheckAppLanguage = .current) -> String { l.tr("Lưu", "Save") }
        public static func copy(_ l: CheckAppLanguage = .current) -> String { l.tr("Sao chép", "Copy") }
        public static func copied(_ l: CheckAppLanguage = .current) -> String { l.tr("Đã chép", "Copied") }
        public static func get(_ l: CheckAppLanguage = .current) -> String { l.tr("Nhận", "Get") }
        public static func stable(_ l: CheckAppLanguage = .current) -> String { l.tr("Ổn định", "Stable") }
        public static func unstable(_ l: CheckAppLanguage = .current) -> String { l.tr("Không ổn định", "Unstable") }
        public static func disconnected(_ l: CheckAppLanguage = .current) -> String { l.tr("Chưa kết nối", "Disconnected") }
        public static func disabled(_ l: CheckAppLanguage = .current) -> String { l.tr("Chưa bật", "Disabled") }
        public static func loading(_ l: CheckAppLanguage = .current) -> String { l.tr("Đang tải...", "Loading...") }
        public static func never(_ l: CheckAppLanguage = .current) -> String { l.tr("Chưa bao giờ", "Never") }
    }

    // MARK: 2. Tab Check (NewsViewController)
    public enum Check {
        // Dashboard Sections & Items
        public static func systemStatus(_ l: CheckAppLanguage = .current) -> String { l.tr("Trạng Thái Hệ Thống", "System Status") }
        public static func anisetteServer(_ l: CheckAppLanguage = .current) -> String { l.tr("Máy chủ Anisette", "Anisette Server") }
        public static func anisetteServerTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Máy Chủ Anisette", "Anisette Server") }
        public static func cellularData(_ l: CheckAppLanguage = .current) -> String { l.tr("Mạng 4G/Di Động", "4G/Cellular Data") }
        public static func shortcuts(_ l: CheckAppLanguage = .current) -> String { l.tr("Phím Tắt", "Shortcuts") }
        public static func automationGuide(_ l: CheckAppLanguage = .current) -> String { l.tr("Hướng Dẫn Tự Động Hóa", "Automation Guide") }
        public static func shortcutVideoGuide(_ l: CheckAppLanguage = .current) -> String { l.tr("Hướng Dẫn Video Phím Tắt", "Shortcut Video Guide") }

        // Trạng thái ngắn & chi tiết
        public static func noPairingFile(_ l: CheckAppLanguage = .current) -> String { l.tr("Chưa có tệp Pairing", "No Pairing File") }
        public static func pairingFileLoaded(_ l: CheckAppLanguage = .current) -> String { l.tr("Đã nạp Pairing File", "Pairing File Loaded") }
        public static func pairingErrorTapRepair(_ l: CheckAppLanguage = .current) -> String { l.tr("Pairing lỗi • Nhấn vào để cài lại", "Pairing error • Tap to re-pair") }
        public static func pairingExpiredDetail(_ l: CheckAppLanguage = .current) -> String { l.tr("Pairing bị lỗi hoặc hết hạn • Hãy cài lại Pairing mới", "Pairing invalid or expired • Please re-pair") }
        public static func tapToVerify(_ l: CheckAppLanguage = .current) -> String { l.tr("Nhấn vào đây để kiểm tra", "Tap here to verify") }

        public static func cellularDirectDetail(_ l: CheckAppLanguage = .current) -> String { l.tr("Ổn định • Đang dùng trực tiếp 4G / 5G", "Stable • Using 4G / 5G directly") }
        public static func cellularReadyDetail(_ l: CheckAppLanguage = .current) -> String { l.tr("Ổn định • 4G / 5G đang bật sẵn sàng", "Stable • 4G / 5G is enabled and ready") }
        public static func cellularOffDetail(_ l: CheckAppLanguage = .current) -> String { l.tr("Chưa bật • Hãy bật Dữ liệu di động (4G/5G)", "Disabled • Please turn on Cellular Data (4G/5G)") }

        public static func anisetteOnDeviceWarning(_ l: CheckAppLanguage = .current) -> String { l.tr("Không ổn định • Hãy tắt Use On-Device Anisette", "Unstable • Please disable Use On-Device Anisette") }
        public static func anisetteStableHost(_ host: String, _ l: CheckAppLanguage = .current) -> String { l.tr("Ổn định • Máy chủ: \(host)", "Stable • Server: \(host)") }

        // Phím tắt & Tự động hoá
        public static func cellularRefreshToggleTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Cellular Refresh (Refresh Qua 4G)", "Cellular Refresh (Refresh via 4G)") }
        public static func enabledByDefault(_ l: CheckAppLanguage = .current) -> String { l.tr("Đã bật mặc định", "Enabled by Default") }
        public static func shortcutTurnOff4G(_ l: CheckAppLanguage = .current) -> String { l.tr("Phím tắt Tắt 4G", "Turn Off 4G Shortcut") }
        public static func shortcutTurnOn4G(_ l: CheckAppLanguage = .current) -> String { l.tr("Phím tắt Bật 4G", "Turn On 4G Shortcut") }
        public static func shortcutAutoRefresh6AM(_ l: CheckAppLanguage = .current) -> String { l.tr("Tự động làm mới App (6:00 sáng)", "Auto Refresh App (6:00 AM)") }
        public static func shortcutAutoRefresh3PM(_ l: CheckAppLanguage = .current) -> String { l.tr("Tự động làm mới App (15:00 chiều)", "Auto Refresh App (3:00 PM)") }

        public static func autoGuideStep1Caption(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Bước 1: Mở Phím Tắt mục Auto Refresh 4G (Auto Refresh 4G 2) và nhấn vào dấu xổ xuống:",
                 "Step 1: Open Shortcuts ➔ Auto Refresh 4G (Auto Refresh 4G 2) and tap the dropdown arrow:")
        }
        public static func autoGuideStep2Caption(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Bước 2: Bật nút Tự động hóa:", "Step 2: Turn on Enable This Automation:")
        }
        public static func loadingImage(_ l: CheckAppLanguage = .current) -> String { l.tr("Đang tải ảnh...", "Loading image...") }
        public static func imageLoadError(_ l: CheckAppLanguage = .current) -> String { l.tr("Không tải được ảnh. Vui lòng kiểm tra mạng.", "Failed to load image. Please check your connection.") }
        public static func videoGuideDescription(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Nếu phím tắt tải về không tương thích với phiên bản iOS trên máy của bạn, bạn có thể xem video bên dưới để tự tạo phím tắt.",
                 "If the downloaded shortcut is not compatible with your iOS version, you can watch the video below to create the shortcut yourself.")
        }

        // Bảng kiểm tra Pairing (Pairing Sheet)
        public static func pairingVerificationTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Kiểm Tra Pairing", "Pairing Verification") }
        public static func deletePairingAlertTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Xoá tệp Pairing?", "Delete Pairing File?") }
        public static func deletePairingAlertMessage(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Tệp Pairing hiện tại sẽ bị xoá hoàn toàn khỏi ứng dụng. Bạn sẽ cần cài hoặc nhập lại tệp mới để tiếp tục sử dụng.",
                 "The current Pairing file will be completely removed from the app. You will need to pair or import a new file to continue.")
        }
        public static func pairingDeletedBanner(_ l: CheckAppLanguage = .current) -> String { l.tr("Đã xoá tệp Pairing khỏi ứng dụng.", "Pairing file has been deleted from the app.") }
        public static func pairingImportedBanner(_ l: CheckAppLanguage = .current) -> String { l.tr("Đã nạp tệp Pairing thành công!", "Pairing file imported successfully!") }
        public static func pairingInstalledBanner(_ l: CheckAppLanguage = .current) -> String { l.tr("Đã cài và nạp Pairing thành công!", "Pairing installed and activated successfully!") }

        public static func pairingHeaderVerified(_ l: CheckAppLanguage = .current) -> String { l.tr("Pairing Hoạt Động Tốt (Tích Xanh)", "Pairing Verified & Ready (Green Check)") }
        public static func pairingHeaderWaiting(_ l: CheckAppLanguage = .current) -> String { l.tr("Đang Chờ Xác Minh Pairing", "Waiting for Pairing Verification") }
        public static func pairingHeaderMissing(_ l: CheckAppLanguage = .current) -> String { l.tr("Chưa Có Tệp Pairing (Tích Đỏ)", "No Pairing File Found (Red X)") }
        public static func pairingHeaderInvalid(_ l: CheckAppLanguage = .current) -> String { l.tr("Pairing Lỗi Hoặc Hết Hạn (Tích Đỏ)", "Pairing Invalid or Expired (Red X)") }

        public static func verify3StepsTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("3 Bước Kiểm Tra Pairing Chính Xác:", "3 Steps for Accurate Pairing Verification:") }
        public static func verifyStep1Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Kết nối mạng trên iPhone", "Connect iPhone to Network") }
        public static func verifyStep1Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Đảm bảo iPhone của bạn đang có kết nối **Wi-Fi** hoặc **4G**.", "Make sure your iPhone is connected to **Wi-Fi** or **4G**.")
        }
        public static func verifyStep2Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Bật LocalDevVPN", "Turn ON LocalDevVPN") }
        public static func verifyStep2Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Mở ứng dụng **LocalDevVPN** và bật kết nối VPN lên.", "Open **LocalDevVPN** and turn ON the VPN connection.")
        }
        public static func verifyStep3Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Tắt cả Wi-Fi và 4G (Chỉ bật LocalDevVPN)", "Turn OFF Wi-Fi & 4G (Keep Only LocalDevVPN)") }
        public static func verifyStep3Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Tắt cả **Wi-Fi** và **4G**, chỉ để lại mỗi **LocalDevVPN** đang bật.", "Turn OFF both **Wi-Fi** and **4G**, leaving only **LocalDevVPN** enabled.")
        }
        public static func verifyFooterNote(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Xong 3 bước trên, nhìn lên mục Đang Chờ Xác Minh Pairing ở phía trên sẽ tự động hiện Tích Xanh báo đang hoạt động tốt hoặc Tích Đỏ đã bị lỗi / cần cài lại.",
                 "After completing the 3 steps above, look at the Waiting for Pairing Verification section at the top — it will automatically show a Green Check (working properly) or a Red X (error / needs re-pairing).")
        }

        // Phần 1: iOS 27 Direct Pairing
        public static func part1iOS27Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Phần 1: Dành Cho iOS 27", "Part 1: For iOS 27") }
        public static func directPairingSubtitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Ghép nối trực tiếp trên iPhone", "Direct On-Device Pairing on iPhone") }
        public static func ios27Step1Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Bắt đầu phát tín hiệu Pairing", "Start Pairing Broadcast") }
        public static func ios27Step1Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Nhấn vào nút **\"Cài Pairing lên iPhone\"** ở bên dưới để ứng dụng phát tín hiệu ghép đôi.",
                 "Tap the **\"Install Pairing on iPhone\"** button below so the app broadcasts the pairing signal.")
        }
        public static func ios27Step2Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Mở Cài đặt Nhà phát triển", "Open Developer Mode Settings") }
        public static func ios27Step2Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Thoát ra màn hình chính (không vuốt tắt ứng dụng này), mở **Cài đặt (Settings)** ➔ **Quyền riêng tư & Bảo mật (Privacy & Security)** ➔ kéo xuống cuối chọn **Chế độ nhà phát triển (Developer Mode)**.",
                 "Go to the Home Screen (do not close this app), open **Settings** ➔ **Privacy & Security** ➔ scroll down and select **Developer Mode**.")
        }
        public static func ios27Step3Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Nhập mã PIN 6 chữ số (Tự động kích hoạt)", "Enter 6-Digit PIN (Auto-Activated)") }
        public static func ios27Step3Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Trong mục Chế độ nhà phát triển, nếu có “Thiết bị đã ghép đôi” cũ thì xoá đi, sau đó nhấn vào dòng **Pair with SideStore** và nhập mật khẩu iPhone. Quay lại app này xem **mã 6 chữ số**, rồi sang **Cài đặt** nhập vào và nhấn **Ghép đôi**. Ngay sau khi ghép đôi xong, ứng dụng sẽ **tự động nạp và kích hoạt Pairing luôn**!",
                 "In Developer Mode, remove any old paired devices, tap **Pair with SideStore**, and enter your iPhone passcode. Check the **6-digit PIN** in this app, enter it in **Settings**, and tap **Pair**. Once paired, the app **automatically loads and activates your Pairing file**!")
        }
        public static func ios27Step4Title(_ l: CheckAppLanguage = .current) -> String { l.tr("Lưu tệp Pairing dự phòng (Khuyên dùng)", "Save Backup Pairing File (Recommended)") }
        public static func ios27Step4Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Sau khi ghép nối xong, bạn **không cần nhập lại tệp nữa**. Tuy nhiên, hãy nhấn nút **“Xuất tệp Pairing (Lưu dự phòng)”** (màu xanh lá) ➔ chọn **Lưu vào Tệp (Save to Files)** để cất giữ dự phòng cho những lần cài lại app sau này.",
                 "After pairing, you **do not need to re-import the file**. However, tap **“Export Pairing File (Backup)”** (green button) ➔ **Save to Files** to keep a backup copy for future reinstalls.")
        }
        public static func pinCodeHeader(_ l: CheckAppLanguage = .current) -> String { l.tr("MÃ GHÉP NỐI 6 CHỮ SỐ", "6-DIGIT PAIRING PIN") }
        public static func stopPairingBroadcastBtn(_ l: CheckAppLanguage = .current) -> String { l.tr("Dừng Cài Pairing (Đang phát sóng...)", "Stop Pairing (Broadcasting...)") }
        public static func startPairingBroadcastBtn(_ l: CheckAppLanguage = .current) -> String { l.tr("Cài Pairing lên iPhone", "Install Pairing on iPhone") }
        public static func exportBackupBtn(_ l: CheckAppLanguage = .current) -> String { l.tr("Xuất tệp Pairing (Lưu dự phòng)", "Export Pairing File (Backup)") }
        public static func exportBeforePairWarning(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Vui lòng thực hiện Bước 2 & Bước 3 (nhập xong 6 chữ số trong Cài đặt ➔ Chế độ nhà phát triển) trước khi lưu tệp dự phòng.",
                 "Please complete Step 2 & Step 3 (enter the 6-digit PIN in Settings ➔ Developer Mode) before saving a backup file.")
        }
        public static func importExistingPairingBtn(_ l: CheckAppLanguage = .current) -> String { l.tr("Nhập tệp Pairing có sẵn", "Import Existing Pairing File") }
        public static func importFromFilesBtn(_ l: CheckAppLanguage = .current) -> String { l.tr("Nhập tệp Pairing (Từ ứng dụng Tệp)", "Import Pairing File (From Files App)") }
        public static func deletePairingBtn(_ l: CheckAppLanguage = .current) -> String { l.tr("Xoá tệp Pairing", "Delete Pairing File") }

        // Phần 2: PC / Mac Pairing
        public static func part2PCTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Phần 2: Dưới iOS 27 (PC / Mac)", "Part 2: Below iOS 27 (PC / Mac)") }
        public static func pcPairingSubtitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Tạo / Cài tệp Pairing qua Máy tính (Windows / Mac)", "Generate / Install Pairing via Computer (Windows / Mac)") }
        public static func pcPrepInfo(_ l: CheckAppLanguage = .current) -> String {
            l.tr("**Chuẩn bị chung:** Trên Windows cần cài đặt **iTunes** & **iCloud** bản chính chủ từ Apple (không tải bản Microsoft Store). Cắm cáp kết nối iPhone vào máy tính, mở khóa màn hình iPhone và nhấn **Tin cậy (Trust)** + nhập mật khẩu màn hình. Hãy chọn **1 trong 3 công cụ** dưới đây:",
                 "**General Preparation:** On Windows, install official Apple **iTunes** & **iCloud** (non-Microsoft Store version). Connect iPhone via USB cable, unlock the screen, tap **Trust**, and enter your passcode. Choose **1 of the 3 tools** below:")
        }
        public static func pcMethod1Title(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Cách 1: Dùng idevice_pair (Khuyên dùng - Hỗ trợ cả nạp thẳng & xuất tệp)", "Method 1: Using idevice_pair (Recommended - Direct Load & File Export)")
        }
        public static func pcMethod1Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("• Mở phần mềm **idevice_pair** trên máy tính và chọn iPhone của bạn.\n• **Cách nạp thẳng vào ứng dụng:** Trong mục ứng dụng trên **idevice_pair**, chọn **SideStore** hoặc **LiveContainer** rồi nhấn nút **Load** (hoặc **Install Pairing File**). Phần mềm sẽ tự động chép thẳng tệp Pairing vào trong ứng dụng trên iPhone mà không cần làm thủ công.\n• **Cách xuất ra tệp `.mobiledevicepairing` dự phòng:** Nhấn nút **Generate** rồi chọn **Export / Save** để lưu tệp có đuôi **`.mobiledevicepairing`** ra máy tính. Gửi tệp này sang iPhone (qua Zalo, AirDrop, iCloud Drive), chọn **Lưu vào Tệp** rồi nhấn nút **“Nhập tệp Pairing”** ở dưới.",
                 "• Open **idevice_pair** on your computer and select your iPhone.\n• **Direct App Injection:** Under the app list in **idevice_pair**, select **SideStore** or **LiveContainer** and click **Load** (or **Install Pairing File**). It will automatically install the Pairing file into the app.\n• **Export `.mobiledevicepairing` Backup:** Click **Generate** then **Export / Save** to save the **`.mobiledevicepairing`** file. Send it to your iPhone, choose **Save to Files**, and tap **“Import Pairing File”** below.")
        }
        public static func pcMethod2Title(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Cách 2: Dùng jitterbugpair (Công cụ xuất tệp `.mobiledevicepairing` ra máy tính)", "Method 2: Using jitterbugpair (CLI Tool to Export `.mobiledevicepairing`)")
        }
        public static func pcMethod2Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("• Tải và giải nén **jitterbugpair** (trên Windows/macOS/Linux).\n• Giữ màn hình iPhone luôn sáng và mở khóa, sau đó chạy file **`jitterbugpair.exe`** (trên Windows) hoặc chạy **`./jitterbugpair`** trong Terminal (trên Mac).\n• Công cụ sẽ tự động xuất ra một tệp có tên dạng **`<UDID>.mobiledevicepairing`** nằm ngay trong cùng thư mục chứa **jitterbugpair** (công cụ này chỉ xuất ra tệp chứ không tự chép vào app).\n• Gửi tệp **`.mobiledevicepairing`** đó sang iPhone ➔ chọn **Lưu vào Tệp (Save to Files)** ➔ nhấn nút **“Nhập tệp Pairing”** bên dưới để nạp vào ứng dụng.",
                 "• Download and extract **jitterbugpair** (Windows/macOS/Linux).\n• Keep your iPhone unlocked, then run **`jitterbugpair.exe`** (Windows) or **`./jitterbugpair`** in Terminal (Mac).\n• It will generate a **`<UDID>.mobiledevicepairing`** file in the same folder.\n• Transfer that **`.mobiledevicepairing`** file to your iPhone ➔ **Save to Files** ➔ tap **“Import Pairing File”** below.")
        }
        public static func pcMethod3Title(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Cách 3: Dùng iLoader (Cài đặt tự động vào ứng dụng trên iPhone)", "Method 3: Using iLoader (Automatic Injection into iPhone App)")
        }
        public static func pcMethod3Body(_ l: CheckAppLanguage = .current) -> String {
            l.tr("• Mở phần mềm **iLoader** trên máy tính, đăng nhập hoặc kết nối với iPhone đã nhấn Tin cậy.\n• **iLoader** chủ yếu hỗ trợ tính năng **Tự động tạo và nạp trực tiếp (Inject) Pairing File** vào **SideStore / LiveContainer** thông qua tùy chọn **Generate / Place Pairing File** ngay trong giao diện quản lý thiết bị.\n• Sau khi iLoader báo hoàn tất trên máy tính, hãy mở lại ứng dụng này trên iPhone để hệ thống tự nhận diện.",
                 "• Open **iLoader** on your computer and connect your trusted iPhone.\n• **iLoader** supports **Automatic Generation and Direct Injection** of the Pairing File into **SideStore / LiveContainer** via the **Generate / Place Pairing File** option.\n• Once iLoader finishes on your computer, reopen this app on your iPhone.")
        }

        // Bảng VPN, 4G, Anisette
        public static func vpnStableHeader(_ l: CheckAppLanguage = .current) -> String { l.tr("LocalDevVPN Đang Ổn Định", "LocalDevVPN is Stable") }
        public static func vpnDisconnectedHeader(_ l: CheckAppLanguage = .current) -> String { l.tr("LocalDevVPN Chưa Kết Nối", "LocalDevVPN is Disconnected") }
        public static func vpnSwitchHint(_ l: CheckAppLanguage = .current) -> String { l.tr("Hãy bật công tắc VPN trong ứng dụng LocalDevVPN.", "Please turn on the VPN switch inside the LocalDevVPN app.") }
        public static func vpnCurrentDetailsTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Thông Số Kết Nối Hiện Tại", "Current Connection Details") }
        public static func vpnRecommendedTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Cấu hình khuyên dùng iOS 27", "Recommended Config iOS 27") }
        public static func vpnRecommendedDesc(_ l: CheckAppLanguage = .current) -> String {
            l.tr("Nếu dùng iOS 27 và bản LiveContainer+SideStore này, hãy đặt IP trong LocalDevVPN theo thông số sau để kết nối nhanh nhất:",
                 "If using iOS 27 with this LiveContainer+SideStore build, set the IP addresses in LocalDevVPN as follows for the fastest connection:")
        }

        public static func cellularStableHeader(_ l: CheckAppLanguage = .current) -> String { l.tr("Mạng 4G/Di Động Ổn Định", "4G/Cellular Data is Stable") }
        public static func cellularOffHeader(_ l: CheckAppLanguage = .current) -> String { l.tr("Mạng 4G/Di Động Đang Tắt", "4G/Cellular Data is Off") }
        public static func cellularCardTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Cài & Gia hạn App qua 4G + VPN", "Install & Refresh Apps via 4G + VPN") }
        public static func cellularCardBody(_ l: CheckAppLanguage = .current) -> String {
            l.tr("• **Không cần Wi-Fi:** Cài đặt IPA và làm mới ứng dụng trực tiếp qua **4G/5G + LocalDevVPN**.\n\n• **Tự động hóa:** Kết hợp phím tắt làm mới lúc 6:00 hoặc 15:00 để tự động gia hạn ứng dụng mỗi ngày.",
                 "• **No Wi-Fi Needed:** Install IPAs and refresh apps directly over **4G/5G + LocalDevVPN**.\n\n• **Automation:** Combine with the 6:00 AM or 3:00 PM shortcuts to automatically refresh apps daily.")
        }

        public static func customServerPrefix(_ l: CheckAppLanguage = .current) -> String { l.tr("Máy chủ tùy chỉnh", "Custom Server") }
        public static func anisetteStableHeader(_ l: CheckAppLanguage = .current) -> String { l.tr("Máy Chủ Anisette Ổn Định", "Anisette Server is Stable") }
        public static func anisetteOnDeviceHeader(_ l: CheckAppLanguage = .current) -> String { l.tr("Đang Bật On-Device Anisette", "On-Device Anisette is Enabled") }
        public static func anisetteModeCardTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Chế độ xác thực Anisette", "Anisette Authentication Mode") }
        public static func anisetteOnDeviceEnabledSub(_ l: CheckAppLanguage = .current) -> String { l.tr("Đang BẬT (Khuyên tắt để ổn định hơn)", "ENABLED (Recommended to turn OFF for stability)") }
        public static func anisetteOnDeviceDisabledSub(_ l: CheckAppLanguage = .current) -> String { l.tr("(Nên Tắt Để Dễ Đăng Nhập)", "(Keep OFF for Easy Login)") }
        public static func turnOffOnDeviceNowBtn(_ l: CheckAppLanguage = .current) -> String { l.tr("Tắt ngay Use On-Device Anisette", "Turn Off Use On-Device Anisette Now") }
        public static func selectAnisetteServerTitle(_ l: CheckAppLanguage = .current) -> String { l.tr("Chọn Máy chủ Anisette", "Select Anisette Server") }
        public static func inUseBadge(_ l: CheckAppLanguage = .current) -> String { l.tr("Đang dùng", "In Use") }
        public static func customServerInputLabel(_ l: CheckAppLanguage = .current) -> String { l.tr("Hoặc nhập URL máy chủ tùy chỉnh:", "Or enter custom server URL:") }
    }

    // MARK: 3. Tab Sources (SourcesViewController)
    public enum Sources {
        public static var title: String { NSLocalizedString("Sources", comment: "") }
        public static var addMoreSourcesTitle: String { NSLocalizedString("Add More Sources!", comment: "") }
        public static var addMoreSourcesDetail: String {
            NSLocalizedString("Sources determine what apps are available in SideStore. The more sources you add, the better your SideStore experience will be.\n\nDon’t know where to start? Try adding one of our Recommended Sources!", comment: "")
        }
        public static var viewRecommendedSources: String { NSLocalizedString("View Recommended Sources", comment: "") }
        public static var remove: String { NSLocalizedString("Remove", comment: "") }
        public static var viewError: String { NSLocalizedString("View Error", comment: "") }
        public static var never: String { NSLocalizedString("Never", comment: "") }
        public static func lastUpdated(_ dateText: String) -> String {
            String(format: NSLocalizedString("Last Updated: %@", comment: ""), dateText)
        }
        public static func couldNotBeAdded(_ name: String) -> String {
            String(format: NSLocalizedString("“%@” could not be added to SideStore.", comment: ""), name)
        }
        public static var unableToAddSource: String { NSLocalizedString("Unable to Add Source", comment: "") }
        public static func downloadingApp(_ name: String) -> String {
            String(format: NSLocalizedString("Downloading %@…", comment: ""), name)
        }
        public static var tapToViewProgress: String { NSLocalizedString("Tap to view progress.", comment: "") }
    }

    // MARK: 4. Tab Browse (BrowseViewController)
    public enum Browse {
        public static var title: String { NSLocalizedString("Browse", comment: "") }
        public static var noApps: String { NSLocalizedString("No Apps", comment: "") }
        public static var searchNoAppsDetail: String {
            NSLocalizedString("Please make sure your spelling is correct, or try searching for another app.", comment: "")
        }
        public static var loading: String { NSLocalizedString("Loading...", comment: "") }
        public static var unableToFetchApps: String { NSLocalizedString("Unable to Fetch Apps", comment: "") }
        public static var sortBy: String { NSLocalizedString("Sort by…", comment: "") }
    }

    // MARK: 5. Tab My Apps (MyAppsViewController)
    public enum MyApps {
        public static var title: String { NSLocalizedString("My Apps", comment: "") }
        public static var unsupportedUpdatesAvailable: String { NSLocalizedString("Unsupported Updates Available", comment: "") }
        public static var noUpdatesAvailable: String { NSLocalizedString("No Updates Available", comment: "") }
        public static func version(_ versionText: String) -> String {
            String(format: NSLocalizedString("Version %@", comment: ""), versionText)
        }
        public static func betaAppName(_ name: String) -> String {
            String(format: NSLocalizedString("%@ beta", comment: ""), name)
        }
        public static func updateAccessibilityLabel(_ appName: String, _ version: String, _ date: String) -> String {
            String(format: NSLocalizedString("%@ %@ update. Released on %@.", comment: ""), appName, version, date)
        }
        public static func updateAppAccessibility(_ name: String) -> String {
            String(format: NSLocalizedString("Update %@", comment: ""), name)
        }
        public static var expiresIn: String { NSLocalizedString("Expires in", comment: "") }
        public static func refreshAppAccessibility(_ name: String) -> String {
            String(format: NSLocalizedString("Refresh %@", comment: ""), name)
        }
        public static var activateUpper: String { NSLocalizedString("ACTIVATE", comment: "") }
        public static func activateAppAccessibility(_ name: String) -> String {
            String(format: NSLocalizedString("Activate %@", comment: ""), name)
        }
        public static var failedToRefreshOneApp: String { NSLocalizedString("Failed to refresh 1 app.", comment: "") }
        public static func failedToRefreshAppsCount(_ count: Int) -> String {
            String(format: NSLocalizedString("Failed to refresh %@ apps.", comment: ""), NSNumber(value: count))
        }
        public static var refreshing: String { NSLocalizedString("Refreshing", comment: "") }
        public static var sideloadIPA: String { NSLocalizedString("Sideload IPA", comment: "") }

        // Inactive Apps Alert
        public static var inactiveAppsLimitWithExtensionsMsg: String {
            NSLocalizedString("Non-developer Apple IDs are limited to 3 apps and app extensions. Inactive apps don't count towards your total, but cannot be opened until activated.", comment: "")
        }
        public static var inactiveAppsLimitStandardMsg: String {
            NSLocalizedString("Non-developer Apple IDs are limited to 3 apps. Inactive apps are backed up and uninstalled so they don't count towards your total, but will be reinstalled with all their data when activated again.", comment: "")
        }
        public static var inactiveAppsLimitMDCNote: String {
            NSLocalizedString("If you're using the MacDirtyCow exploit to remove the 3-app limit, you can install up to 10 apps and app extensions instead.", comment: "")
        }
        public static var whatAreInactiveAppsTitle: String { NSLocalizedString("What are inactive apps?", comment: "") }

        // Hidden / Unsupported Updates Alert
        public static var unsupportedUpdateAvailableSingle: String { NSLocalizedString("Unsupported Update Available", comment: "") }
        public static func unsupportedUpdatesAvailableCount(_ count: Int) -> String {
            String(format: NSLocalizedString("%@ Unsupported Updates Available", comment: ""), count as NSNumber)
        }
        public static func unsupportedUpdatesMessage(_ osVersion: String) -> String {
            String(format: NSLocalizedString("These updates don't support iOS %@. Please update your device to the latest iOS version to install them.", comment: ""), osVersion)
        }
        public static func iOSOrLater(_ version: String) -> String {
            String(format: NSLocalizedString("iOS %@ or later", comment: ""), version)
        }
        public static func iOSOrEarlier(_ version: String) -> String {
            String(format: NSLocalizedString("iOS %@ or earlier", comment: ""), version)
        }

        // Deactivation Prompt Alert
        public static var cannotActivateMoreThan3AppsTitle: String { NSLocalizedString("Cannot Activate More than 3 Apps", comment: "") }
        public static var cannotActivateMoreThan3AppsAndExtTitle: String { NSLocalizedString("Cannot Activate More than 3 Apps and App Extensions", comment: "") }
        public static var chooseAppToDeactivateWithExtMsg: String {
            NSLocalizedString("Non-developer Apple IDs are limited to 3 active apps and app extensions. Please choose an app to deactivate.", comment: "")
        }
        public static var chooseAppToDeactivateStandardMsg: String {
            NSLocalizedString("Non-developer Apple IDs are limited to 3 active apps. Please choose an app to deactivate.", comment: "")
        }
        public static var appExtensionSingular: String { NSLocalizedString("app extension", comment: "") }
        public static var appExtensionPlural: String { NSLocalizedString("app extensions", comment: "") }
        public static func chooseAppToDeactivateContainingExtMsg(_ appName: String, _ count: Int, _ extText: String) -> String {
            String(format: NSLocalizedString("Non-developer Apple IDs are limited to 3 active apps and app extensions, and \"%@\" contains %@ %@. Please choose an app to deactivate.", comment: ""), appName, NSNumber(value: count), extText)
        }

        // Delete & Remove App Alerts
        public static func deleteAppConfirmTitle(_ name: String) -> String {
            String(format: NSLocalizedString("Delete “%@”?", comment: ""), name)
        }
        public static func deleteAppConfirmMessage(_ name: String) -> String {
            String(format: NSLocalizedString("This will remove “%@” from SideStore and erase any backup data for this app.", comment: ""), name)
        }
        public static var cancel: String { NSLocalizedString("Cancel", comment: "") }
        public static var delete: String { NSLocalizedString("Delete", comment: "") }
        public static var remove: String { NSLocalizedString("Remove", comment: "") }
        public static func removeAppConfirmTitle(_ name: String) -> String {
            String(format: NSLocalizedString("Remove “%@” from SideStore?", comment: ""), name)
        }
        public static var removeLegacyDeactivationMessage: String {
            NSLocalizedString("You must also delete it from the home screen to fully uninstall the app.", comment: "")
        }
        public static var removeEraseBackupMessage: String {
            NSLocalizedString("This will also erase any backup data for this app.", comment: "")
        }

        // Backup & Restore
        public static var startBackupTitle: String { NSLocalizedString("Start Backup?", comment: "") }
        public static var startBackupMessage: String {
            NSLocalizedString("This will replace any previous backups. Please leave SideStore open until the backup is complete.", comment: "")
        }
        public static func backUpAppAction(_ name: String) -> String {
            String(format: NSLocalizedString("Back Up %@", comment: ""), name)
        }
        public static func importBackupSuccessText(_ name: String) -> String {
            "Import Backup successful for \(name)"
        }
        public static var importBackupSuccessDetail: String {
            "Use 'Restore Backup' option to restore data from this imported backup"
        }
        public static func restoreBackupConfirmMessage(_ name: String) -> String {
            String(format: NSLocalizedString("This will replace all data you currently have in %@.", comment: ""), name)
        }
        public static var restoreBackupConfirmTitle: String {
            NSLocalizedString("Are you sure you want to restore this backup?", comment: "")
        }
        public static var restoreBackup: String { NSLocalizedString("Restore Backup", comment: "Restores the last or current backup of this app") }
        public static var exportAppBackupTitle: String { "Export App Backup" }
        public static func deleteBackupConfirmTitle(_ name: String) -> String {
            String(format: NSLocalizedString("Delete Backup for “%@”?", comment: ""), name)
        }
        public static var deleteBackupConfirmMessage: String {
            NSLocalizedString("Are you sure you want to delete the backup for this app? This action cannot be undone.", comment: "")
        }
        public static var deleteBackup: String { NSLocalizedString("Delete Backup", comment: "") }
        public static var uploadCustomAppIconTitle: String { "Upload Custom App Icon" }
        public static var unableToCheckForUpdates: String { NSLocalizedString("Unable to Check for Updates", comment: "") }

        // Headers & Footers
        public static var installedHeader: String { NSLocalizedString("Installed", comment: "") }
        public static var activeHeader: String { NSLocalizedString("Active", comment: "") }
        public static var refreshAll: String { NSLocalizedString("Refresh All", comment: "") }
        public static var inactiveHeader: String { NSLocalizedString("Inactive", comment: "") }
        public static var oneAppIDRemaining: String { NSLocalizedString("1 App ID Remaining", comment: "") }
        public static func appIDsRemainingCount(_ count: Int) -> String {
            String(format: NSLocalizedString("%@ App IDs Remaining", comment: ""), NSNumber(value: count))
        }

        // Context Menu Actions
        public static var open: String { NSLocalizedString("Open", comment: "") }
        public static var refresh: String { NSLocalizedString("Refresh", comment: "") }
        public static var resign: String { NSLocalizedString("Resign", comment: "") }
        public static var fromCache: String { NSLocalizedString("From Cache", comment: "") }
        public static var fromSource: String { NSLocalizedString("From Source", comment: "") }
        public static var reinstall: String { NSLocalizedString("Reinstall", comment: "") }
        public static var activate: String { NSLocalizedString("Activate", comment: "") }
        public static var deactivate: String { NSLocalizedString("Deactivate", comment: "") }
        public static var deleteApp: String { NSLocalizedString("Delete App", comment: "") }
        public static var enableJIT: String { NSLocalizedString("Enable JIT", comment: "") }
        public static var createBackup: String { NSLocalizedString("Create Backup", comment: "") }
        public static var exportRaw: String { NSLocalizedString("Export (Raw)", comment: "") }
        public static var exportZip: String { NSLocalizedString("Export (ZIP)", comment: "") }
        public static var exportBackup: String { NSLocalizedString("Export Backup", comment: "") }
        public static var importRaw: String { NSLocalizedString("Import (Raw)", comment: "") }
        public static var importZip: String { NSLocalizedString("Import (ZIP)", comment: "") }
        public static var importBackup: String { NSLocalizedString("Import Backup", comment: "") }
        public static var restorePreviousBackup: String { NSLocalizedString("Restore Previous Backup", comment: "Restores the backup saved before the current backup was created.") }
        public static var photos: String { NSLocalizedString("Photos", comment: "") }
        public static var removeIcon: String { NSLocalizedString("Remove Icon", comment: "") }
        public static var info: String { NSLocalizedString("Info", comment: "") }
        public static var changeIcon: String { NSLocalizedString("Change Icon", comment: "") }
        public static var backupMenu: String { NSLocalizedString("Backup", comment: "") }
        public static var changeProvisioningProfile: String { NSLocalizedString("Change Provisioning Profile", comment: "") }
        public static var resetProvisioningProfile: String { NSLocalizedString("Reset Provisioning Profile", comment: "") }
        public static var provisioningProfileMenu: String { NSLocalizedString("Provisioning Profile", comment: "") }
    }

    // MARK: 6. Tab Settings (SettingsViewController)
    public enum Settings {
        public static var accountHeader: String { NSLocalizedString("ACCOUNT", comment: "") }
        public static var signInFooter: String { NSLocalizedString("Sign in with your Apple ID to download apps from SideStore.", comment: "") }
        public static var supportUsHeader: String { NSLocalizedString("SUPPORT US", comment: "") }
        public static var supportUsFooter: String { NSLocalizedString("Support the SideStore Team by following our socials or becoming a patron!", comment: "") }
        public static var signOutUpper: String { NSLocalizedString("SIGN OUT", comment: "") }
        public static var signOut: String { NSLocalizedString("Sign Out", comment: "") }
        public static var signOutConfirmTitle: String { NSLocalizedString("Are you sure you want to sign out?", comment: "") }
        public static var signOutConfirmMessage: String { NSLocalizedString("Are you sure you want to sign out? You will no longer be able to install or refresh apps once you sign out.", comment: "") }
        public static var signInWithAppleID: String { NSLocalizedString("Sign in with Apple ID", comment: "") }

        public static var noPairingFileTitle: String { NSLocalizedString("No Pairing File Found", comment: "") }
        public static var noPairingFileMessage: String { NSLocalizedString("Please import a pairing file in Settings before signing in.", comment: "") }
        public static var resetPairingFile: String { NSLocalizedString("Reset Pairing File", comment: "") }
        public static var pairingSuccessTitle: String { NSLocalizedString("Pairing File Imported", comment: "") }

        public static var removeAppLimitTitle: String { NSLocalizedString("Remove 3-App Limit?", comment: "") }
        public static var removeAppLimitMessage: String { NSLocalizedString("This requires the MacDirtyCow exploit (iOS 15.0 – 16.1.2) to remove the 3-app limit.", comment: "") }
        public static var removeAppLimitConfirm: String { NSLocalizedString("Remove Limit", comment: "") }

        public static var useMainProfileTitle: String { NSLocalizedString("Use Main Profile?", comment: "") }
        public static var useMainProfileMessage: String { NSLocalizedString("Using the main profile may help resolve certain installation issues.", comment: "") }
        public static var useMainProfileConfirm: String { NSLocalizedString("Enable", comment: "") }

        public static var resetConfirmTitle: String { NSLocalizedString("Reset All Settings?", comment: "") }
        public static var resetConfirmMessage: String { NSLocalizedString("This will reset all SideStore settings and sign you out.", comment: "") }
        public static var resetAllAction: String { NSLocalizedString("Reset All", comment: "") }
        public static var resetAllRow: String { NSLocalizedString("Reset All", comment: "") }

        public static var clearCacheConfirmTitle: String { NSLocalizedString("Clear Cache?", comment: "") }
        public static func clearCacheConfirmTitle(_ size: String) -> String {
            String(format: NSLocalizedString("Are you sure you want to clear SideStore's cache?\n\nCache Size: %@", comment: ""), size)
        }
        public static var clearCacheConfirmMessage: String { NSLocalizedString("This will remove all temporary files as well as backups for uninstalled apps.", comment: "") }
        public static var clearCache: String { NSLocalizedString("Clear Cache", comment: "") }
        public static var clearCacheAction: String { NSLocalizedString("Clear Cache", comment: "") }
        public static var clearCacheRow: String { NSLocalizedString("Clear Cache", comment: "") }
        public static var unableToClearCache: String { NSLocalizedString("Unable to Clear Cache", comment: "") }

        public static var enableFallbackTitle: String { NSLocalizedString("Enforce Refresh Fallback?", comment: "") }
        public static var enableFallbackMessage: String { NSLocalizedString("This forces SideStore to use the fallback method when refreshing apps.", comment: "") }
        public static var enableFallbackAction: String { NSLocalizedString("Enforce Fallback", comment: "") }
        public static var enableFallbackRow: String { NSLocalizedString("Enforce Refresh Fallback", comment: "") }

        public static var disableFallbackTitle: String { NSLocalizedString("Disable Refresh Fallback?", comment: "") }
        public static var disableFallbackMessage: String { NSLocalizedString("SideStore will use the standard refresh method.", comment: "") }
        public static var disableFallbackAction: String { NSLocalizedString("Disable Fallback", comment: "") }
        public static var disableFallbackRow: String { NSLocalizedString("Disable Refresh Fallback", comment: "") }

        public static var refreshingAppsHeader: String { NSLocalizedString("REFRESHING APPS", comment: "") }
        public static var refreshingAppsFooter: String { NSLocalizedString("Add a Siri Shortcut to quickly refresh your sideloaded apps via Wi-Fi or Cellular Data.", comment: "") }
        public static var displayHeader: String { NSLocalizedString("DISPLAY", comment: "") }
        public static var displayFooter: String { NSLocalizedString("Personalize your SideStore experience by choosing an alternate app icon.", comment: "") }
        public static var techyThingsHeader: String { NSLocalizedString("TECHY THINGS", comment: "") }
        public static var techyThingsFooter: String { NSLocalizedString("Free up disk space by removing non-essential data, such as temporary files and backups for uninstalled apps.", comment: "") }
        public static var creditsHeader: String { NSLocalizedString("CREDITS", comment: "") }
        public static var advancedSettingsHeader: String { NSLocalizedString("ADVANCED SETTINGS", comment: "") }

        public static var calculating: String { NSLocalizedString("Calculating…", comment: "") }

        public static var sendFeedbackTitle: String { NSLocalizedString("Send Feedback", comment: "") }
        public static var sendFeedbackMessage: String { NSLocalizedString("Choose a method to send feedback:", comment: "") }
        public static var sendEmail: String { NSLocalizedString("Send Email", comment: "") }
        public static var cannotSendMail: String { NSLocalizedString("Cannot Send Mail", comment: "") }
        public static var clearedAdiPbTitle: String { NSLocalizedString("Cleared adi.pb!", comment: "") }
        public static var clearedAdiPbMessage: String { "You will need to log back into Apple ID in SideStore." }
        public static var networkDiscovery: String { NSLocalizedString("Network Discovery", comment: "") }
        public static var backupAndRestore: String { NSLocalizedString("Backup & Restore", comment: "") }
        public static var userCustomizations: String { NSLocalizedString("User Customizations", comment: "") }
    }

    // MARK: 7. User Customizations (UserCustomizationsView)
    public enum UserCustomizations {
        public static var appearanceHeader: String { "APPEARANCE & THEMES" }
        public static var themeManager: String { "Theme Manager" }

        public static var anisetteHeader: String { "ANISETTE" }
        public static var onDeviceAnisette: String { "On-Device Anisette" }
        public static var onDeviceAnisetteSub: String { "Run ADI emulation directly on device instead of remote servers" }
        public static var anisetteClientConfig: String { "Anisette Client Configuration" }
        public static var resetAdiPb: String { NSLocalizedString("Reset adi.pb", comment: "") }
        public static var resetAdiPbSub: String { "Clear local Anisette provisioning data from Keychain" }
        public static var resetAdiAlertMsg: String {
            NSLocalizedString("This will sign you out of Apple ID in SideStore and clear the provisioned adi.pb data from your Keychain. Your active signing certificate will be preserved.", comment: "")
        }
        public static var resetAndSignOut: String { NSLocalizedString("Reset & Sign Out", comment: "") }
        public static var signedOutKeepHeadersMsg: String { NSLocalizedString("Signed out of Apple ID. You can now sign back in with fresh provisioning.", comment: "") }
        public static var signedOutResetAllMsg: String { NSLocalizedString("Signed out of Apple ID. Reset adi.pb and header configs to defaults.", comment: "") }

        public static var sideSignHeader: String { "SIDESIGN" }
        public static var sideSignClientConfig: String { "SideSign Client Configuration" }

        public static var generalHeader: String { "GENERAL" }
        public static var customizeInfoPlist: String { "Customize Info.plist" }
        public static var customizeAppId: String { "Customize AppID" }
        public static var customizeExtensions: String { "Customize Extensions" }
        public static var defaultImportMode: String { "Default Import Mode" }
        public static var confirmAppInstallation: String { "Confirm App Installation" }
        public static var confirmAppInstallationSub: String { "Prompt for confirmation before installing or importing an app" }
        public static var clearCustomizationsOnUninstall: String { "Clear Customizations on Uninstall" }
        public static var clearCustomizationsOnUninstallSub: String { "Reset assigned profiles, custom certificates, and metadata when an app is deleted" }
        public static var autoLaunchAfterInstall: String { "Auto-Launch App After Install" }
        public static var autoLaunchAfterInstallSub: String { "Automatically open apps after installation completes" }
        public static var customizeEntitlements: String { "Customize Entitlements" }
        public static var autoFixAppGroupIds: String { "Auto-Fix AppGroup IDs" }
        public static var autoFixFreeSub: String { "Required for free developer accounts" }
        public static var autoFixPaidSub: String { "Automatically fix App Group casing mismatches" }
        public static var customizeAppIcon: String { "Customize App Icon" }
        public static var customizeAppIconSub: String { "Prompt to choose a custom icon before installing" }
        public static var customizeProvisioningProfile: String { "Customize Provisioning Profile" }
        public static var customizeProvisioningProfileSub: String { "Prompt to select a provisioning profile before installing" }
        public static var skipUncopyableBackupFiles: String { "Skip Uncopyable Backup Files" }
        public static var preferSheetInfoPlist: String { "Prefer Sheet for Info.plist" }
        public static var preferSheetEntitlements: String { "Prefer Sheet for Entitlements" }
        public static var preferSheetSub: String { "Use sheet instead of dialog" }

        public static var appVerificationHeader: String { "APP VERIFICATION" }
        public static var disableAllVerifications: String { "Disable All Verifications" }
        public static var bundleIdCheck: String { "Bundle Identifier Check" }
        public static var iosVersionCheck: String { "iOS Version Check" }
        public static var appVersionCheck: String { "App Version Check" }
        public static var permissionChecks: String { "Permission Checks" }

        public static var emproxyHeader: String { "EMPROXY & WIREGUARD" }
        public static var exportWireGuardConfig: String { "Export WireGuard Config" }
        public static var exportWireGuardConfigSub: String { "Exports SideStore.conf to import into WireGuard VPN app" }
        public static var emproxyServer: String { "EMProxy (WireGuard) Server" }
        public static var emproxyServerSub: String { "Restart required to apply changes" }
        public static var sideStoreConfMissing: String { NSLocalizedString("SideStore.conf missing!", comment: "") }
        public static var sideStoreConfMissingDetail: String { "Unable to locate SideStore.conf in bundle resources." }

        public static var cellularRefreshHeader: String { "CELLULAR REFRESH" }
        public static var cellularRefresh: String { "Cellular Refresh" }
        public static var cellularRefreshSub: String { "Automatically toggle cellular data via Shortcuts during refresh" }
        public static var turnOnCellularShortcut: String { "Turn On Cellular Shortcut" }
        public static var turnOffCellularShortcut: String { "Turn Off Cellular Shortcut" }
        public static var shortcutNameSub: String { "Name of the shortcut in Apple Shortcuts app" }
        public static var turnOnBaseDelay: String { "Turn On Base Delay" }
        public static var turnOnBaseDelaySub: String { "Base wait time after turning on data (seconds, ≥ 0)" }
        public static var turnOffBaseDelay: String { "Turn Off Base Delay" }
        public static var turnOffBaseDelaySub: String { "Base wait time after turning off data (seconds, ≥ 0)" }
        public static var resetToDefaults: String { "Reset to Defaults" }

        public static var minimuxerBackendHeader: String { "MINIMUXER BACKEND" }

        public static var restartRequired: String { "Restart Required" }
        public static var restartNow: String { "Restart Now" }
        public static var anisetteRestartMsg: String { "Changing Anisette config will invalidate your current provisioned Anisette data and you will be signed out.\n\nThis action will require a restart, do you want to proceed?" }
        public static var emproxyRestartMsg: String { "Changing the EMProxy setting requires restarting SideStore. If canceled, changes will not be saved." }
        public static var backendRestartMsg: String { "Changing the Minimuxer backend requires restarting SideStore. If canceled, changes will not be saved." }
    }
}
