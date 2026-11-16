
//
//  ErrorProcessing.swift
//  SideStore
//
//  Created by Magesh K on 20/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import Foundation
import UIKit

class ErrorProcessing {
    
    enum InfoMode: String {
        case fullError
        case localizedDescription
    }
    
    let info: InfoMode
    let unique: Bool
    let recur: Bool
    
    var errors: Set<String> = []
    
    // Chống hiện chồng chéo nhiều bảng lỗi khi bấm Refresh All nhiều ứng dụng
    private static var isShowingPopup = false
    private static var lastPopupTime: Date = .distantPast
    
    init(_ mode: InfoMode = .localizedDescription, unique: Bool = false, recur: Bool = false) {
        self.info = mode
        self.unique = unique
        self.recur = recur
        
        // Kích hoạt bộ đánh chặn UIAlertController & ToastView ngay khi khởi tạo
        Self.setupGlobalInterceptors()
    }
    
    // MARK: - BỘ ĐÁNH CHẶN TOÀN CỤC (CHẶN TOASTVIEW LỖI & ALERT CŨ)
    private static var didSetupInterceptors = false
    
    private static func setupGlobalInterceptors() {
        guard !didSetupInterceptors else { return }
        didSetupInterceptors = true
        
        // Lắng nghe sự kiện mỗi khi bất kỳ ToastView nào chuẩn bị hiện lên màn hình
        NotificationCenter.default.addObserver(
            forName: ToastView.willShowNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let toast = notification.object as? ToastView else { return }
            let detail = toast.detailTextLabel.text ?? ""
            
            // Nếu ToastView này là một thông báo lỗi (đã qua ErrorProcessing của chúng ta)
            if detail.contains("🔴") || detail.contains("⚠️ LỖI CHƯA PHÂN LOẠI") {
                // 1. Ẩn ngay cái ToastView màu xanh bé tí đi để không làm rối mắt
                toast.isHidden = true
                toast.alpha = 0
                toast.dismiss()
                
                // 2. Bật bảng thông báo lỗi lớn (Popup giữa màn hình) của chúng ta lên!
                Self.presentErrorAlert(fullMessage: detail)
            }
        }
    }
    
    // MARK: - HIỂN THỊ BẢNG THÔNG BÁO LỖI GIỮA MÀN HÌNH (HỖ TRỢ LAUNCHVIEWCONTROLLER EMBED)
    static func presentErrorAlert(fullMessage: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Nếu đang có bảng lỗi hiện rồi hoặc vừa mới hiện trong 1.5s trước (Refresh All) thì bỏ qua
            if isShowingPopup || Date().timeIntervalSince(lastPopupTime) < 1.5 {
                return
            }
            
            guard let presenter = Self.findActiveViewController() else { return }
            
            // Không đè lên nếu đang có sẵn bảng lỗi của chính chúng ta
            if let currentAlert = presenter as? UIAlertController,
               currentAlert.title == "⚠️ Hệ thống chẩn đoán lỗi" {
                return
            }
            
            isShowingPopup = true
            lastPopupTime = Date()
            
            let alert = UIAlertController(
                title: "⚠️ Hệ thống chẩn đoán lỗi",
                message: fullMessage,
                preferredStyle: .alert
            )
            
            // Căn lề trái để các mục 🔴 💡 🛠️ hiển thị thẳng hàng, dễ đọc
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left
            paragraphStyle.lineSpacing = 3.5
            
            let attributedMessage = NSAttributedString(
                string: "\n" + fullMessage,
                attributes: [
                    .paragraphStyle: paragraphStyle,
                    .font: UIFont.systemFont(ofSize: 13.5),
                    .foregroundColor: UIColor.label
                ]
            )
            alert.setValue(attributedMessage, forKey: "attributedMessage")
            
            // Nút Sao chép lỗi
            alert.addAction(UIAlertAction(title: "📋 Sao chép chi tiết", style: .default) { _ in
                UIPasteboard.general.string = fullMessage
                isShowingPopup = false
            })
            
            // Nút Đóng
            alert.addAction(UIAlertAction(title: "Đã hiểu", style: .cancel) { _ in
                isShowingPopup = false
            })
            
            presenter.present(alert, animated: true)
        }
    }
    
    // Tìm chính xác ViewController đang hiển thị (Xuyên qua cả LaunchViewController.children)
    private static func findActiveViewController() -> UIViewController? {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
        
        guard let root = keyWindow?.rootViewController else { return nil }
        return drillDownViewController(from: root)
    }
    
    private static func drillDownViewController(from vc: UIViewController) -> UIViewController {
        // 1. Nếu có màn hình đang được present đè lên trên
        if let presented = vc.presentedViewController, !presented.isBeingDismissed {
            return drillDownViewController(from: presented)
        }
        // 2. Nếu là UITabBarController -> đi vào tab đang chọn
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return drillDownViewController(from: selected)
        }
        // 3. Nếu là UINavigationController -> đi vào màn hình trên cùng
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return drillDownViewController(from: visible)
        }
        // 4. QUAN TRỌNG NHẤT: LaunchViewController dùng embed(child: TabBarController)
        if let lastChild = vc.children.last {
            return drillDownViewController(from: lastChild)
        }
        return vc
    }
    
    // MARK: - HỆ THỐNG PHÂN TÍCH 30 LỖI TRỰC QUAN CHO NGƯỜI DÙNG
    private func userFriendlyDescription(for error: NSError) -> String {
        // Quét toàn bộ chuỗi lỗi cha + lỗi con (underlyingErrors) + userInfo
        let text = Self.extractDeepErrorString(from: error).lowercased()
        
        let domain = error.domain
        let code = error.code
        let rawDesc = error.localizedDescription
        let failureReason = error.localizedFailureReason ?? ""

        // Hàm hỗ trợ tạo khung thông báo trực quan, đồng bộ
        func formatGuide(title: String, cause: String, fix: String) -> String {
            return """
            🔴 \(title)
            
            💡 Nguyên nhân:
            \(cause)
            
            🛠️ Cách sửa:
            \(fix)
            ────────────────────
            📝 Gốc: \(rawDesc) [\(domain): \(code)]
            """
        }

        // =========================================================================
        // NHÓM 1: LỖI KẾT NỐI VPN, MẠNG WI-FI & THIẾT BỊ (LỖI SỐ 1 -> 5)
        // =========================================================================

        // Lỗi 1: Chưa bật VPN (LocalDevVPN / WireGuard / StosVPN)
        if text.contains("localdevvpn") || text.contains("novpn") || text.contains("invalidvpn") || text.contains("vpn connection error") || text.contains("stosvpn") {
            return formatGuide(
                title: "LỖI KẾT NỐI VPN (CHƯA BẬT VPN)",
                cause: "VPN của SideStore chưa được bật hoặc bị xung đột với VPN/DNS khác (như AdGuard, 1.1.1.1, Shadowrocket).",
                fix: "1. Tắt các ứng dụng VPN/DNS chặn quảng cáo khác.\n2. Mở app StosVPN / LocalDevVPN / WireGuard và bật kết nối lên rồi thử lại."
            )
        }

        // Lỗi 2: Không có kết nối Wi-Fi (Đang dùng 4G/5G hoặc mất mạng)
        if text.contains("noconnection") || text.contains("connect to wi-fi") || code == -1009 {
            return formatGuide(
                title: "CHƯA KẾT NỐI MẠNG WI-FI",
                cause: "Thiết bị đang tắt mạng hoặc chỉ dùng dữ liệu di động (4G/5G thông thường không thể định tuyến nội bộ cho SideStore).",
                fix: "Hãy kết nối vào một mạng Wi-Fi ổn định trước khi làm mới/cài đặt."
            )
        }

        // Lỗi 4: Minimuxer chưa khởi động
        if text.contains("minimuxernotstarted") || text.contains("minimuxer has not been started") {
            return formatGuide(
                title: "DỊCH VỤ MINIMUXER CHƯA CHẠY",
                cause: "Trình giả lập kết nối máy tính bên trong SideStore chưa được kích hoạt.",
                fix: "Đảm bảo đã nhập file Pairing hợp lệ, bật VPN, sau đó đóng hoàn toàn ứng dụng SideStore và mở lại."
            )
        }

        // =========================================================================
        // NHÓM 2: LỖI FILE GHÉP ĐÔI - PAIRING FILE (LỖI SỐ 6 -> 8)
        // =========================================================================

        // Lỗi 6: Chưa có Pairing File
        if text.contains("pairingnotcomplete") || text.contains("pairing required") || text.contains("nopairingfile") || text.contains("missing pairing") {
            return formatGuide(
                title: "CHƯA CÓ FILE GHÉP ĐÔI (PAIRING FILE)",
                cause: "SideStore chưa được cấp file ghép đôi (hoặc bạn đã xóa mất) nên không thể giao tiếp với iOS.",
                fix: "Kết nối iPhone với máy tính, dùng công cụ 'idevice_pair' hoặc 'iloader' để tạo file ghép đôi và nhập vào SideStore."
            )
        }

        // Lỗi 7: Pairing File bị hỏng hoặc hết hiệu lực
        if text.contains("invalidpairingfile") || text.contains("current pairing file is invalid") || text.contains("lockdown") || text.contains("muxerror") || text.contains("invalid host id") {
            return formatGuide(
                title: "FILE GHÉP ĐÔI BỊ HỎNG HOẶC VÔ HIỆU HÓA",
                cause: "File ghép đôi hiện tại không còn tác dụng (do đã xóa, cập nhật iOS, hoặc đổi mật khẩu màn hình khóa).",
                fix: "Cắm iPhone vào máy tính, bấm 'Tin cậy' lại và tạo file Pairing mới bằng idevice_pair / jitterbugpair / iloader."
            )
        }

        // Lỗi 8: Không xác định được UDID của máy
        if text.contains("unknownudid") || text.contains("determine this device's udid") {
            return formatGuide(
                title: "KHÔNG ĐỌC ĐƯỢC UDID THIẾT BỊ",
                cause: "File ghép đôi bị thiếu thông tin định danh thiết bị hoặc đã bị xóa.",
                fix: "Kiểm tra lại file Pairing trong Settings hoặc tạo lại file Pairing mới trên máy tính."
            )
        }

        // Lỗi 3: Không tìm thấy điểm cuối thiết bị (No Device / Not Reachable / Connection Refused)
        if text.contains("nodevice") || text.contains("not reachable") || text.contains("connection refused") || text.contains("could not connect to device") || text.contains("device could not be found") {
            return formatGuide(
                title: "KHÔNG THỂ KẾT NỐI TỚI THIẾT BỊ",
                cause: "Chưa bật VPN (StosVPN/WireGuard), đường truyền VPN bị kẹt hoặc đã xóa/hỏng File ghép đôi (Pairing File).",
                fix: "1. Bật lại công tắc VPN.\n2. Kiểm tra mục Pairing File trong Settings.\n3. Vuốt đóng hẳn SideStore từ đa nhiệm rồi mở lại."
            )
        }

        // Lỗi 5: Quá thời gian chờ (Timed Out)
        if text.contains("timed out") || text.contains("timedout") || code == -1001 {
            return formatGuide(
                title: "QUÁ THỜI GIAN PHẢN HỒI (TIMED OUT)",
                cause: "Mạng Wi-Fi quá chậm, máy chủ Apple/Anisette phản hồi lâu, hoặc bạn đã tắt màn hình làm ngắt kết nối ngầm.",
                fix: "Giữ màn hình iPhone luôn sáng, kiểm tra lại mạng Wi-Fi và bấm làm mới từng ứng dụng một."
            )
        }

        // =========================================================================
        // NHÓM 3: LỖI TÀI KHOẢN APPLE ID, CHỨNG CHỈ & ANISETTE (LỖI SỐ 9 -> 16)
        // =========================================================================

        // Lỗi 9: Lỗi máy chủ Anisette (-22421, -29004, hoặc lỗi kết nối host)
        if code == -22421 || code == -29004 || text.contains("anisette") || code == -1004 || code == -1003 {
            return formatGuide(
                title: "LỖI MÁY CHỦ ANISETTE (MÃ \(code))",
                cause: "Máy chủ Anisette đang dùng bị sập, quá tải, bảo trì hoặc bị Apple chặn xác thực.",
                fix: "Vào mục Settings (Cài đặt) -> Anisette Server -> Đổi sang một địa chỉ máy chủ khác trong danh sách."
            )
        }

        // Lỗi 10: Vượt quá giới hạn 10 App ID hoặc 3 App của tài khoản miễn phí (Mã 36607)
        if code == 36607 || text.contains("maximum number") || text.contains("10 app") || text.contains("free-provisioning") {
            return formatGuide(
                title: "ĐẠT GIỚI HẠN TÀI KHOẢN APPLE MIỄN PHÍ",
                cause: "Tài khoản miễn phí chỉ cho phép tạo tối đa 10 App ID trong 7 ngày và kích hoạt tối đa 3 ứng dụng cùng lúc.",
                fix: "1. Khi cài IPA mới, hãy chọn 'Remove App Extensions' để tiết kiệm App ID.\n2. Nếu đã hết sạch 10 ID, bạn phải đợi 7 ngày để các ID cũ tự hết hạn."
            )
        }

        // Lỗi 11: Chưa đăng nhập hoặc hết hạn phiên đăng nhập (-1100, -20101, -36607)
        if code == -1100 || code == -20101 || code == -36607 || text.contains("not signed in") || text.contains("notauthenticated") || text.contains("session has expired") {
            return formatGuide(
                title: "PHIÊN ĐĂNG NHẬP APPLE ID HẾT HẠN",
                cause: "Bạn chưa đăng nhập Apple ID, vừa đổi mật khẩu, hoặc phiên làm việc với máy chủ Apple đã hết hạn.",
                fix: "Vào mục Settings (Cài đặt) của SideStore -> Đăng xuất (Sign Out) tài khoản Apple ID và đăng nhập lại."
            )
        }

        // Lỗi 12: Tài khoản Apple ID bị khóa bảo mật
        if text.contains("locked") && (text.contains("account") || text.contains("apple")) {
            return formatGuide(
                title: "TÀI KHOẢN APPLE ID BỊ TẠM KHÓA",
                cause: "Hệ thống Apple phát hiện đăng nhập từ vị trí lạ (do máy chủ Anisette đặt ở nước ngoài) nên tự khóa để bảo vệ.",
                fix: "Mở trình duyệt Safari, vào trang 'iforgot.apple.com' để mở khóa/đổi mật khẩu, sau đó đăng nhập lại vào SideStore."
            )
        }

        // Lỗi 13: Chứng chỉ ký ứng dụng đã bị thu hồi hoặc hết hạn
        if text.contains("certificateexpired") || text.contains("certificaterevoked") || (text.contains("certificate") && (text.contains("revoked") || text.contains("expired"))) {
            return formatGuide(
                title: "CHỨNG CHỈ ĐÃ HẾT HẠN HOẶC BỊ THU HỒI",
                cause: "Chứng chỉ phát triển dùng để ký ứng dụng đã hết hạn 7 ngày hoặc bị thu hồi từ một thiết bị/công cụ Sideload khác.",
                fix: "Vào Settings -> Đăng xuất và đăng nhập lại Apple ID, sau đó bấm Refresh ứng dụng."
            )
        }

        // Lỗi 14: Thiếu Provisioning Profile (Hồ sơ cấp phép)
        if text.contains("missingprovisioningprofile") || text.contains("provisioning profile for the app could not be found") {
            return formatGuide(
                title: "THIẾU HỒ SƠ CẤP PHÉP (PROVISIONING PROFILE)",
                cause: "Không thể tải hoặc tạo hồ sơ cấp phép từ máy chủ Apple cho ứng dụng này.",
                fix: "Kiểm tra lại kết nối mạng, đổi Anisette Server khác hoặc đăng nhập lại Apple ID rồi thử lại."
            )
        }

        // Lỗi 15: Lỗi Keychain của iOS (-25300, -25299, -25293)
        let keychainCodes = [-25300, -25299, -25293, -25291, -25308, -34018]
        if domain.lowercased() == "kcerrordomain" || (domain.lowercased() == NSOSStatusErrorDomain.lowercased() && keychainCodes.contains(code)) {
            let kcDetail: String
            switch code {
            case -25300: kcDetail = "Không tìm thấy thông tin xác thực trong chuỗi khóa (Item not found)."
            case -25299: kcDetail = "Dữ liệu trong chuỗi khóa bị trùng lặp (Duplicate item)."
            case -25293: kcDetail = "Xác thực chuỗi khóa thất bại (Auth failed)."
            default: kcDetail = "Lỗi truy cập bộ nhớ bảo mật Keychain của iOS."
            }
            return formatGuide(
                title: "LỖI BẢO MẬT KEYCHAIN (MÃ \(code))",
                cause: kcDetail,
                fix: "Vào Cài đặt SideStore, đăng xuất Apple ID ra và đăng nhập lại. Nếu không được, hãy khởi động lại iPhone."
            )
        }

        // Lỗi 16: Không truy cập được Shared App Group
        if text.contains("missingappgroup") || text.contains("shared app group") {
            return formatGuide(
                title: "LỖI TRUY CẬP APP GROUP",
                cause: "Nhóm dữ liệu chung của SideStore không thể khởi tạo hoặc bị thiếu quyền hạn (Entitlements).",
                fix: "Hãy thử làm mới (Refresh) lại chính ứng dụng SideStore trước, sau đó đóng hẳn app và mở lại."
            )
        }

        // =========================================================================
        // NHÓM 4: LỖI FILE IPA, DỮ LIỆU & CÀI ĐẶT VÀO HỆ THỐNG (LỖI SỐ 17 -> 25)
        // =========================================================================

        // Lỗi 17: Mất gói dữ liệu ứng dụng (context.targetAppBundle is nil / missingAppBundle)
        if text.contains("targetappbundle is nil") || text.contains("missingappbundle") || text.contains("app bundle could not be found") {
            return formatGuide(
                title: "KHÔNG TÌM THẤY DỮ LIỆU GÓI ỨNG DỤNG",
                cause: "- Nếu đang cài mới: File IPA bị lỗi giải nén hoặc không đúng cấu trúc.\n- Nếu đang làm mới (Refresh): File lưu tạm (Cache) của app này trong SideStore đã bị xóa mất.",
                fix: "Hãy tải lại file IPA gốc của ứng dụng này và bấm Cài đặt đè (Install) lại từ đầu (không mất dữ liệu app)."
            )
        }

        // Lỗi 18: File IPA sai định dạng hoặc thiếu Info.plist
        if text.contains("invalidapp") || text.contains("missinginfoplist") || text.contains("info.plist could not be found") || text.contains("invalid format") {
            return formatGuide(
                title: "FILE IPA BỊ HỎNG HOẶC SAI ĐỊNH DẠNG",
                cause: "File IPA tải về chưa hoàn chỉnh, bị nén sai cấu trúc hoặc thiếu tệp cấu hình Info.plist.",
                fix: "Đảm bảo file IPA đã tải xong 100% về mục 'Trên iPhone' (không nằm trên đám mây iCloud), hoặc tải file IPA khác."
            )
        }

        // Lỗi 19: Lỗi xác minh chữ ký số (0xe80080... / ApplicationVerificationFailed / Undecrypted IPA)
        if text.contains("applicationverificationfailed") || text.contains("0xe80080") || text.contains("code signature") || text.contains("failed to verify") {
            return formatGuide(
                title: "XÁC MINH CHỮ KÝ SỐ THẤT BẠI",
                cause: "File IPA này chưa được giải mã (Undecrypted IPA lấy trực tiếp từ App Store) hoặc quá trình ký chứng chỉ bị lỗi.",
                fix: "SideStore chỉ cài được các file IPA đã bẻ khóa (Decrypted IPA). Hãy tải IPA từ nguồn khác uy tín hơn."
            )
        }

        // Lỗi 20: Trùng lặp Bundle ID với ứng dụng đã cài sẵn trên máy
        if text.contains("mismatchedbundleidentifiers") || text.contains("mismatchedapplicationidentifier") || text.contains("already installed") || text.contains("bundle id does not match") {
            return formatGuide(
                title: "XUNG ĐỘT TÊN GÓI ỨNG DỤNG (BUNDLE ID)",
                cause: "Trên máy đã có sẵn ứng dụng gốc tải từ App Store trùng Bundle ID, hoặc bản cập nhật mới khác Bundle ID với bản cũ.",
                fix: "Hãy xóa ứng dụng gốc ngoài màn hình chính đi trước, hoặc bật tùy chọn đổi Bundle ID khi cài đặt."
            )
        }

        // Lỗi 21: Phiên bản iOS không hỗ trợ (Quá thấp hoặc quá cao)
        if text.contains("iosversionnotsupported") || text.contains("requires ios") || text.contains("does not support ios") {
            return formatGuide(
                title: "PHIÊN BẢN iOS KHÔNG TƯƠNG THÍCH",
                cause: "Phiên bản iOS hiện tại trên máy của bạn thấp hơn yêu cầu tối thiểu của ứng dụng này.",
                fix: "Tìm tải phiên bản cũ hơn của ứng dụng (IPA bản cũ) phù hợp với iOS của bạn, hoặc cập nhật iOS."
            )
        }

        // Lỗi 22: Hết dung lượng bộ nhớ máy
        if text.contains("nospaceleft") || text.contains("insufficient storage") || text.contains("not enough space") || code == 28 {
            return formatGuide(
                title: "KHÔNG ĐỦ DUNG LƯỢNG BỘ NHỚ TRỐNG",
                cause: "SideStore cần dung lượng trống gấp 2-3 lần kích thước file IPA để giải nén, sao lưu và đóng gói ký lại.",
                fix: "Hãy xóa bớt ảnh/video hoặc ứng dụng không dùng để giải phóng thêm vài GB bộ nhớ trống rồi thử lại."
            )
        }

        // Lỗi 23: Sai lệch mã Hash SHA-256 hoặc Kích thước file từ Nguồn (Source)
        if text.contains("mismatchedhash") || text.contains("mismatchedsize") || text.contains("mismatchedversion") || text.contains("sha-256 hash") {
            return formatGuide(
                title: "TỆP TẢI VỀ KHÔNG KHỚP VỚI NGUỒN (SOURCE)",
                cause: "File IPA tải từ Kho nguồn (Source) bị đứt quãng giữa chừng hoặc chủ Kho nguồn khai báo sai dung lượng/mã SHA-256.",
                fix: "Thử tải lại lần nữa. Nếu vẫn lỗi, hãy dùng trình duyệt Safari tải trực tiếp file IPA về máy rồi cài thủ công qua dấu '+'."
            )
        }

        // Lỗi 24: Ứng dụng yêu cầu thêm quyền hạn mới (Permissions)
        if text.contains("undeclaredpermissions") || text.contains("addedpermissions") || text.contains("requires additional permissions") {
            return formatGuide(
                title: "ỨNG DỤNG YÊU CẦU QUYỀN HẠN CHƯA KHAI BÁO",
                cause: "Ứng dụng trong Nguồn (Source) yêu cầu thêm quyền riêng tư/hệ thống chưa được liệt kê trong thông tin nguồn.",
                fix: "Tải file IPA đó về ứng dụng Tệp (Files) và cài đặt trực tiếp bằng nút dấu '+' trong tab My Apps."
            )
        }

        // Lỗi 25: Không có ứng dụng nào để làm mới
        if text.contains("noinstalledapps") || text.contains("no active sideloaded apps") {
            return formatGuide(
                title: "KHÔNG CÓ ỨNG DỤNG NÀO ĐỂ LÀM MỚI",
                cause: "Hiện tại danh sách ứng dụng đang kích hoạt trong SideStore đang trống.",
                fix: "Hãy cài đặt hoặc kích hoạt ít nhất một ứng dụng trước khi bấm làm mới."
            )
        }

        // =========================================================================
        // NHÓM 5: LỖI TÍNH NĂNG NÂNG CAO: PHÍM TẮT, WIDGET, JIT & SOURCE (LỖI 26 -> 30)
        // =========================================================================

        // Lỗi 26: Lỗi chạy Phím tắt (Shortcuts) & Widget (LNPerformActionErrorCodeMalformedResponse)
        if text.contains("lnperformaction") || text.contains("malformedresponse") {
            return formatGuide(
                title: "LỖI LÀM MỚI NGẦM QUA PHÍM TẮT / WIDGET",
                cause: "Khi chạy qua Phím tắt hoặc Widget, iOS giới hạn thời gian và RAM rất gắt gao nên đã ngắt tiến trình của SideStore giữa chừng.",
                fix: "Không dùng Phím tắt/Widget lúc này. Hãy mở trực tiếp ứng dụng SideStore lên và giữ sáng màn hình để làm mới."
            )
        }

        // Lỗi 27: Không kết nối được máy chủ SideJITServer
        if text.contains("unabletoconnectsidejit") || text.contains("unable to connect to sidejitserver") {
            return formatGuide(
                title: "KHÔNG KẾT NỐI ĐƯỢC SIDEJITSERVER",
                cause: "Điện thoại không tìm thấy máy chủ kích hoạt JIT trên mạng Wi-Fi hiện tại.",
                fix: "Đảm bảo máy tính đang mở SideJITServer, cùng kết nối chung 1 mạng Wi-Fi với iPhone và đã tắt Tường lửa (Firewall) chặn cổng."
            )
        }

        // Lỗi 28: SideJITServer không phản hồi thiết bị hoặc lỗi JIT chung
        if text.contains("unabletorespondsidejitdevice") || text.contains("sidejitissue") || text.contains("sidejit") {
            return formatGuide(
                title: "LỖI KÍCH HOẠT JIT TRÊN THIẾT BỊ",
                cause: "SideJITServer chưa được ghép đôi với iPhone này hoặc dịch vụ JIT bị lỗi.",
                fix: "Chạy lệnh 'SideJITServer -y' trên máy tính để ghép đôi lại, hoặc vào Settings của SideStore bấm làm mới máy chủ JIT."
            )
        }

        // Lỗi 29: Lỗi làm mới Kho nguồn (Failed to refresh Source / Store)
        if text.contains("could not refresh source") || text.contains("failed to refresh source") || text.contains("nosources") || text.contains("unable to load") {
            return formatGuide(
                title: "LỖI CẬP NHẬT KHO NGUỒN (SOURCE)",
                cause: "Một trong các đường dẫn Kho nguồn (Source URL) bạn thêm vào bị sập, sai định dạng JSON hoặc mất kết nối mạng.",
                fix: "Vào tab Sources (Nguồn), kiểm tra và xóa các nguồn bị lỗi đi rồi tải lại."
            )
        }

        // Lỗi 30: Từ chối quyền mở ứng dụng hoặc lỗi tham số nội bộ khác
        if text.contains("openappfailed") || text.contains("invalidparameters") || text.contains("cacheclearerror") {
            return formatGuide(
                title: "LỖI THAO TÁC NỘI BỘ ỨNG DỤNG",
                cause: "Thao tác bị thiếu tham số đầu vào, lỗi bộ nhớ đệm (Cache) hoặc iOS từ chối quyền khởi chạy.",
                fix: "Hãy thử vào Settings -> Clear Cache (Xóa bộ nhớ đệm), sau đó khởi động lại ứng dụng SideStore."
            )
        }

        // =========================================================================
        // DỰ PHÒNG: NẾU GẶP LỖI LẠ NGOÀI 30 LỖI TRÊN, HIỂN THỊ RÕ RÀNG ĐỂ TRA CỨU
        // =========================================================================
        return """
        ⚠️ LỖI CHƯA PHÂN LOẠI:
        \(rawDesc)
        ────────────────────
        🔍 Thông tin kỹ thuật:
        • Nguồn (Domain): \(domain)
        • Mã số (Code): \(code)
        \(failureReason.isEmpty ? "" : "• Lý do: \(failureReason)")
        """
    }
    
    // Quét sâu toàn bộ cây lỗi (bao gồm cả ALTWrappedError và underlyingErrors)
    private static func extractDeepErrorString(from error: NSError, depth: Int = 0) -> String {
        guard depth < 6 else { return "" }
        var result = "\(error.domain) \(error.code) \(error.localizedDescription) \(error.localizedFailureReason ?? "") \(error.localizedRecoverySuggestion ?? "") \(error) \(error.userInfo)"
        
        if let wrapped = (error as? ALTWrappedError)?.wrappedError {
            result += " " + extractDeepErrorString(from: wrapped as NSError, depth: depth + 1)
        }
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            result += " " + extractDeepErrorString(from: underlying, depth: depth + 1)
        }
        for sub in error.underlyingErrors {
            result += " " + extractDeepErrorString(from: sub as NSError, depth: depth + 1)
        }
        return result
    }

    func getDescription(error: NSError) -> String {
        errors = []
        let formatted = userFriendlyDescription(for: error)
        
        // Ngay lập tức lên lịch bật bảng thông báo lỗi lớn giữa màn hình!
        // (Kể cả khi được gọi từ LaunchViewController hay ToastView)
        Self.presentErrorAlert(fullMessage: formatted)
        
        return formatted
    }
    
    func getDescriptionText(error: NSError, _ depth: Int = 0) -> String {
        return userFriendlyDescription(for: error)
    }
}
