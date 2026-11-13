
//
//  String+Localization.swift
//  AltStore
//
//  Created by SideStore Team.
//  Copyright © 2024 SideStore. All rights reserved.
//

import Foundation

public struct AppStrings {
    
    public struct Common {
        public static let ok = NSLocalizedString("OK", comment: "")
        public static let cancel = NSLocalizedString("Hủy", comment: "")
        public static let done = NSLocalizedString("Xong", comment: "")
        public static let close = NSLocalizedString("Đóng", comment: "")
        public static let save = NSLocalizedString("Lưu", comment: "")
        public static let delete = NSLocalizedString("Xóa", comment: "")
        public static let remove = NSLocalizedString("Gỡ bỏ", comment: "")
        public static let edit = NSLocalizedString("Sửa", comment: "")
        public static let add = NSLocalizedString("Thêm", comment: "")
        public static let retry = NSLocalizedString("Thử lại", comment: "")
        public static let error = NSLocalizedString("Lỗi", comment: "")
        public static let warning = NSLocalizedString("Cảnh báo", comment: "")
        public static let success = NSLocalizedString("Thành công", comment: "")
        public static let loading = NSLocalizedString("Đang tải...", comment: "")
        public static let unknown = NSLocalizedString("Không xác định", comment: "")
        public static let copy = NSLocalizedString("Sao chép", comment: "")
        public static let share = NSLocalizedString("Chia sẻ", comment: "")
        public static let yes = NSLocalizedString("Có", comment: "")
        public static let no = NSLocalizedString("Không", comment: "")
        public static let `continue` = NSLocalizedString("Tiếp tục", comment: "")
        public static let back = NSLocalizedString("Quay lại", comment: "")
        public static let next = NSLocalizedString("Tiếp theo", comment: "")
        public static let search = NSLocalizedString("Tìm kiếm", comment: "")
        public static let refresh = NSLocalizedString("Làm mới", comment: "")
        public static let update = NSLocalizedString("Cập nhật", comment: "")
        public static let install = NSLocalizedString("Cài đặt", comment: "")
        public static let open = NSLocalizedString("Mở", comment: "")
        public static let learnMore = NSLocalizedString("Tìm hiểu thêm", comment: "")
        public static let enable = NSLocalizedString("Bật", comment: "")
        public static let disable = NSLocalizedString("Tắt", comment: "")
        public static let reset = NSLocalizedString("Đặt lại", comment: "")
        public static let clear = NSLocalizedString("Xóa", comment: "")
        public static let selectAll = NSLocalizedString("Chọn tất cả", comment: "")
        public static let deselectAll = NSLocalizedString("Bỏ chọn tất cả", comment: "")
        public static let version = NSLocalizedString("Phiên bản", comment: "")
        public static let size = NSLocalizedString("Kích thước", comment: "")
        public static let date = NSLocalizedString("Ngày", comment: "")
        public static let status = NSLocalizedString("Trạng thái", comment: "")
        public static let details = NSLocalizedString("Chi tiết", comment: "")
        public static let settings = NSLocalizedString("Cài đặt", comment: "")
        public static let general = NSLocalizedString("Chung", comment: "")
        public static let advanced = NSLocalizedString("Nâng cao", comment: "")
        public static let about = NSLocalizedString("Giới thiệu", comment: "")
        public static let help = NSLocalizedString("Trợ giúp", comment: "")
        public static let dismiss = NSLocalizedString("Bỏ qua", comment: "")
        public static let confirm = NSLocalizedString("Xác nhận", comment: "")
        
        public static func resetToDefault() -> String {
            return NSLocalizedString("Khôi phục mặc định", comment: "")
        }
    }
    
    public struct Toast {
        public static let copiedToClipboard = NSLocalizedString("Đã sao chép vào bộ nhớ tạm", comment: "")
        public static let savedSuccessfully = NSLocalizedString("Đã lưu thành công", comment: "")
        public static let operationFailed = NSLocalizedString("Thao tác thất bại", comment: "")
    }
    
    public struct News {
        public static let title = NSLocalizedString("Tin tức", comment: "")
        public static let fetchingNews = NSLocalizedString("Đang tải tin tức...", comment: "")
        public static let noNewsAvailable = NSLocalizedString("Không có tin tức nào", comment: "")
        public static let unableToFetchNews = NSLocalizedString("Không thể tải tin tức", comment: "")
    }
    
    public struct Browse {
        public static let title = NSLocalizedString("Khám phá", comment: "")
        public static let searchPlaceholder = NSLocalizedString("Tìm kiếm ứng dụng...", comment: "")
        public static let noAppsFound = NSLocalizedString("Không tìm thấy ứng dụng nào", comment: "")
        public static let noApps = NSLocalizedString("Không có ứng dụng", comment: "")
        public static let searchNoAppsDetail = NSLocalizedString("Hãy thử kiểm tra lại chính tả hoặc tìm kiếm từ khóa khác.", comment: "")
        public static let loading = NSLocalizedString("Đang tải ứng dụng...", comment: "")
        public static let unableToFetchApps = NSLocalizedString("Không thể tải danh sách ứng dụng", comment: "")
        public static let sortBy = NSLocalizedString("Sắp xếp theo", comment: "")
        public static let categories = NSLocalizedString("Danh mục", comment: "")
        public static let allApps = NSLocalizedString("Tất cả ứng dụng", comment: "")
        public static let featured = NSLocalizedString("Nổi bật", comment: "")
        public static let recentlyUpdated = NSLocalizedString("Mới cập nhật", comment: "")
        public static let sources = NSLocalizedString("Nguồn", comment: "")
        
        public struct Sort {
            public static let title = NSLocalizedString("Sắp xếp theo", comment: "")
            public static let name = NSLocalizedString("Tên", comment: "")
            public static let lastUpdated = NSLocalizedString("Cập nhật gần nhất", comment: "")
            public static let source = NSLocalizedString("Nguồn", comment: "")
            public static let `default` = NSLocalizedString("Mặc định", comment: "")
        }
    }
    
    public struct Sources {
        public static let title = NSLocalizedString("Nguồn", comment: "")
        public static let addSource = NSLocalizedString("Thêm nguồn", comment: "")
        public static let enterSourceURL = NSLocalizedString("Nhập URL nguồn", comment: "")
        public static let invalidSourceURL = NSLocalizedString("URL nguồn không hợp lệ", comment: "")
        public static let sourceAlreadyAdded = NSLocalizedString("Nguồn này đã được thêm", comment: "")
        public static let fetchingSource = NSLocalizedString("Đang tải nguồn...", comment: "")
        public static let unableToAddSource = NSLocalizedString("Không thể thêm nguồn", comment: "")
        public static let removeSourceConfirmation = NSLocalizedString("Bạn có chắc chắn muốn gỡ bỏ nguồn này không?", comment: "")
        public static let recommendedSources = NSLocalizedString("Nguồn đề xuất", comment: "")
        public static let installedSources = NSLocalizedString("Nguồn đã cài đặt", comment: "")
        public static let noSources = NSLocalizedString("Chưa có nguồn nào", comment: "")
        public static let addSourceDescription = NSLocalizedString("Nhập địa chỉ URL của nguồn AltStore/SideStore để thêm các ứng dụng mới.", comment: "")
        public static let untrustedSourceTitle = NSLocalizedString("Nguồn chưa được xác minh", comment: "")
        public static let untrustedSourceMessage = NSLocalizedString("Hãy chắc chắn rằng bạn tin tưởng nguồn này trước khi cài đặt các ứng dụng từ nó.", comment: "")
    }
    
    public struct MyApps {
        public static let title = NSLocalizedString("Ứng dụng của tôi", comment: "")
        public static let activeApps = NSLocalizedString("Đang hoạt động", comment: "")
        public static let inactiveApps = NSLocalizedString("Không hoạt động", comment: "")
        public static let installedHeader = NSLocalizedString("Đã cài đặt", comment: "")
        public static let activeHeader = NSLocalizedString("Đang hoạt động", comment: "")
        public static let inactiveHeader = NSLocalizedString("Không hoạt động", comment: "")
        public static let updatesAvailable = NSLocalizedString("Bản cập nhật khả dụng", comment: "")
        public static let noUpdatesAvailable = NSLocalizedString("Không có bản cập nhật mới", comment: "")
        public static let unsupportedUpdatesAvailable = NSLocalizedString("Có bản cập nhật không tương thích", comment: "")
        public static let unsupportedUpdateAvailableSingle = NSLocalizedString("1 bản cập nhật không tương thích", comment: "")
        public static let noInstalledApps = NSLocalizedString("Chưa có ứng dụng nào", comment: "")
        public static let noInstalledAppsDetail = NSLocalizedString("Nhấn vào nút '+' ở góc trên để cài đặt tệp .ipa hoặc tải ứng dụng từ mục Khám phá.", comment: "")
        public static let noRemovedApps = NSLocalizedString("Không có ứng dụng đã gỡ", comment: "")
        public static let noRemovedAppsDetail = NSLocalizedString("Các ứng dụng bạn đã từng cài đặt và gỡ bỏ sẽ xuất hiện tại đây.", comment: "")
        public static let updateAll = NSLocalizedString("Cập nhật tất cả", comment: "")
        public static let refreshAll = NSLocalizedString("Làm mới tất cả", comment: "")
        public static let daysRemaining = NSLocalizedString("Còn %d ngày", comment: "")
        public static let expired = NSLocalizedString("Đã hết hạn", comment: "")
        public static let expiresIn = NSLocalizedString("Hết hạn sau", comment: "")
        public static let expiresToday = NSLocalizedString("Hết hạn hôm nay", comment: "")
        public static let expiresInOneDay = NSLocalizedString("Hết hạn sau 1 ngày", comment: "")
        public static let refreshing = NSLocalizedString("Đang làm mới...", comment: "")
        public static let installing = NSLocalizedString("Đang cài đặt...", comment: "")
        public static let updating = NSLocalizedString("Đang cập nhật...", comment: "")
        public static let backingUp = NSLocalizedString("Đang sao lưu...", comment: "")
        public static let restoring = NSLocalizedString("Đang khôi phục...", comment: "")
        public static let open = NSLocalizedString("Mở", comment: "")
        public static let refresh = NSLocalizedString("Làm mới", comment: "")
        public static let resign = NSLocalizedString("Ký lại (Resign)", comment: "")
        public static let reinstall = NSLocalizedString("Cài đặt lại", comment: "")
        public static let fromCache = NSLocalizedString("Từ bộ nhớ đệm", comment: "")
        public static let fromSource = NSLocalizedString("Từ nguồn tải", comment: "")
        public static let activate = NSLocalizedString("Kích hoạt", comment: "")
        public static let activateUpper = NSLocalizedString("KÍCH HOẠT", comment: "")
        public static let deactivate = NSLocalizedString("Hủy kích hoạt", comment: "")
        public static let deleteApp = NSLocalizedString("Xóa ứng dụng", comment: "")
        public static let delete = NSLocalizedString("Xóa", comment: "")
        public static let remove = NSLocalizedString("Gỡ bỏ", comment: "")
        public static let cancel = NSLocalizedString("Hủy", comment: "")
        public static let backup = NSLocalizedString("Sao lưu", comment: "")
        public static let backupMenu = NSLocalizedString("Sao lưu & Khôi phục", comment: "")
        public static let createBackup = NSLocalizedString("Tạo bản sao lưu", comment: "")
        public static let exportBackup = NSLocalizedString("Xuất bản sao lưu", comment: "")
        public static let exportRaw = NSLocalizedString("Thư mục gốc", comment: "")
        public static let exportZip = NSLocalizedString("Tệp nén (.zip)", comment: "")
        public static let importBackup = NSLocalizedString("Nhập bản sao lưu", comment: "")
        public static let importRaw = NSLocalizedString("Từ thư mục", comment: "")
        public static let importZip = NSLocalizedString("Từ tệp nén (.zip)", comment: "")
        public static let restore = NSLocalizedString("Khôi phục", comment: "")
        public static let restoreBackup = NSLocalizedString("Khôi phục bản sao lưu", comment: "")
        public static let restorePreviousBackup = NSLocalizedString("Khôi phục bản sao lưu trước đó", comment: "")
        public static let deleteBackup = NSLocalizedString("Xóa bản sao lưu", comment: "")
        public static let photos = NSLocalizedString("Thư viện ảnh", comment: "")
        public static let removeIcon = NSLocalizedString("Khôi phục biểu tượng gốc", comment: "")
        public static let changeIcon = NSLocalizedString("Đổi biểu tượng", comment: "")
        public static let info = NSLocalizedString("Thông tin chi tiết", comment: "")
        public static let changeProvisioningProfile = NSLocalizedString("Đổi hồ sơ cấp phép", comment: "")
        public static let resetProvisioningProfile = NSLocalizedString("Đặt lại hồ sơ mặc định", comment: "")
        public static let provisioningProfileMenu = NSLocalizedString("Hồ sơ (Profile)", comment: "")
        public static let enableJIT = NSLocalizedString("Bật JIT", comment: "")
        public static let openInFiles = NSLocalizedString("Mở trong Tệp", comment: "")
        public static let removeAppTitle = NSLocalizedString("Gỡ bỏ ứng dụng", comment: "")
        public static let removeAppMessage = NSLocalizedString("Bạn có chắc chắn muốn gỡ bỏ %@ không? Mọi dữ liệu của ứng dụng sẽ bị xóa vĩnh viễn.", comment: "")
        public static let appIdsRemaining = NSLocalizedString("Còn lại %d ID ứng dụng", comment: "")
        public static let oneAppIDRemaining = NSLocalizedString("Còn lại 1 App ID", comment: "")
        public static let viewAppIds = NSLocalizedString("Xem ID ứng dụng", comment: "")
        public static let installFromFile = NSLocalizedString("Cài đặt từ tệp (.ipa)", comment: "")
        public static let sideloadIPA = NSLocalizedString("Cài đặt tệp .ipa", comment: "")
        public static let exportAppBackupTitle = NSLocalizedString("Xuất bản sao lưu ứng dụng", comment: "")
        public static let uploadCustomAppIconTitle = NSLocalizedString("Tải lên biểu tượng ứng dụng", comment: "")
        public static let unableToCheckForUpdates = NSLocalizedString("Không thể kiểm tra cập nhật", comment: "")
        public static let failedToRefreshOneApp = NSLocalizedString("Không thể làm mới 1 ứng dụng", comment: "")
        public static let whatAreInactiveAppsTitle = NSLocalizedString("Ứng dụng không hoạt động là gì?", comment: "")
        public static let inactiveAppsLimitWithExtensionsMsg = NSLocalizedString("Tài khoản Apple ID miễn phí chỉ cho phép tối đa 3 ứng dụng (bao gồm cả tiện ích mở rộng) hoạt động cùng lúc. Bạn có thể hủy kích hoạt ứng dụng để nhường chỗ cho ứng dụng khác mà không làm mất dữ liệu.", comment: "")
        public static let inactiveAppsLimitStandardMsg = NSLocalizedString("Tài khoản Apple ID miễn phí chỉ cho phép tối đa 3 ứng dụng hoạt động cùng lúc. Bạn có thể hủy kích hoạt ứng dụng để nhường chỗ cho ứng dụng khác mà không làm mất dữ liệu.", comment: "")
        public static let inactiveAppsLimitMDCNote = NSLocalizedString("Lưu ý: Bạn đã bật tính năng gỡ giới hạn 3 ứng dụng.", comment: "")
        public static let cannotActivateMoreThan3AppsTitle = NSLocalizedString("Không thể kích hoạt quá 3 ứng dụng", comment: "")
        public static let cannotActivateMoreThan3AppsAndExtTitle = NSLocalizedString("Đã đạt giới hạn ứng dụng và tiện ích", comment: "")
        public static let chooseAppToDeactivateWithExtMsg = NSLocalizedString("Vui lòng chọn một ứng dụng đang hoạt động để hủy kích hoạt trước.", comment: "")
        public static let chooseAppToDeactivateStandardMsg = NSLocalizedString("Vui lòng chọn một ứng dụng đang hoạt động để hủy kích hoạt nhằm nhường chỗ.", comment: "")
        public static let appExtensionSingular = NSLocalizedString("tiện ích mở rộng", comment: "")
        public static let appExtensionPlural = NSLocalizedString("tiện ích mở rộng", comment: "")
        public static let removeLegacyDeactivationMessage = NSLocalizedString("Ứng dụng sẽ bị xóa khỏi danh sách không hoạt động.", comment: "")
        public static let removeEraseBackupMessage = NSLocalizedString("Bản sao lưu dữ liệu của ứng dụng này cũng sẽ bị xóa.", comment: "")
        public static let startBackupTitle = NSLocalizedString("Sao lưu dữ liệu ứng dụng", comment: "")
        public static let startBackupMessage = NSLocalizedString("Ứng dụng sẽ được mở lên trong giây lát để tiến hành sao lưu dữ liệu.", comment: "")
        public static let importBackupSuccessDetail = NSLocalizedString("Bạn có thể khôi phục bản sao lưu này từ menu của ứng dụng.", comment: "")
        public static let restoreBackupConfirmTitle = NSLocalizedString("Khôi phục dữ liệu?", comment: "")
        public static let deleteBackupConfirmMessage = NSLocalizedString("Hành động này sẽ xóa vĩnh viễn bản sao lưu hiện tại của ứng dụng.", comment: "")

        public static func version(_ ver: String) -> String {
            return String(format: NSLocalizedString("Phiên bản %@", comment: ""), ver)
        }
        public static func betaAppName(_ name: String) -> String {
            return String(format: NSLocalizedString("%@ (Beta)", comment: ""), name)
        }
        public static func updateAccessibilityLabel(_ name: String, _ ver: String, _ date: String) -> String {
            return "\(name), phiên bản \(ver), \(date)"
        }
        public static func updateAppAccessibility(_ name: String) -> String {
            return "Cập nhật \(name)"
        }
        public static func refreshAppAccessibility(_ name: String) -> String {
            return "Làm mới \(name)"
        }
        public static func activateAppAccessibility(_ name: String) -> String {
            return "Kích hoạt \(name)"
        }
        public static func failedToRefreshAppsCount(_ count: Int) -> String {
            return String(format: NSLocalizedString("Không thể làm mới %d ứng dụng", comment: ""), count)
        }
        public static func unsupportedUpdatesAvailableCount(_ count: Int) -> String {
            return String(format: NSLocalizedString("%d bản cập nhật không tương thích", comment: ""), count)
        }
        public static func unsupportedUpdatesMessage(_ osVer: String) -> String {
            return String(format: NSLocalizedString("Các bản cập nhật sau không tương thích với iOS %@ trên thiết bị của bạn:", comment: ""), osVer)
        }
        public static func iOSOrLater(_ ver: String) -> String {
            return String(format: NSLocalizedString("iOS %@ trở lên", comment: ""), ver)
        }
        public static func iOSOrEarlier(_ ver: String) -> String {
            return String(format: NSLocalizedString("iOS %@ trở xuống", comment: ""), ver)
        }
        public static func chooseAppToDeactivateContainingExtMsg(_ name: String, _ count: Int, _ extText: String) -> String {
            return String(format: NSLocalizedString("%@ bao gồm %d %@. Vui lòng chọn ứng dụng để hủy kích hoạt.", comment: ""), name, count, extText)
        }
        public static func deleteAppConfirmTitle(_ name: String) -> String {
            return String(format: NSLocalizedString("Xóa “%@”?", comment: ""), name)
        }
        public static func deleteAppConfirmMessage(_ name: String) -> String {
            return String(format: NSLocalizedString("Bạn có chắc chắn muốn xóa %@ không?", comment: ""), name)
        }
        public static func removeAppConfirmTitle(_ name: String) -> String {
            return String(format: NSLocalizedString("Gỡ bỏ “%@”?", comment: ""), name)
        }
        public static func backUpAppAction(_ name: String) -> String {
            return String(format: NSLocalizedString("Sao lưu %@", comment: ""), name)
        }
        public static func importBackupSuccessText(_ name: String) -> String {
            return String(format: NSLocalizedString("Đã nhập bản sao lưu cho %@", comment: ""), name)
        }
        public static func restoreBackupConfirmMessage(_ name: String) -> String {
            return String(format: NSLocalizedString("Mọi dữ liệu hiện tại của %@ sẽ bị ghi đè bởi bản sao lưu.", comment: ""), name)
        }
        public static func deleteBackupConfirmTitle(_ name: String) -> String {
            return String(format: NSLocalizedString("Xóa bản sao lưu của “%@”?", comment: ""), name)
        }
        public static func appIDsRemainingCount(_ count: Int) -> String {
            return String(format: NSLocalizedString("Còn lại %d App ID", comment: ""), count)
        }
    }
    
    public struct AppDetail {
        public static let whatsNew = NSLocalizedString("Có gì mới", comment: "")
        public static let versionHistory = NSLocalizedString("Lịch sử phiên bản", comment: "")
        public static let permissions = NSLocalizedString("Quyền truy cập", comment: "")
        public static let entitlements = NSLocalizedString("Quyền hạn (Entitlements)", comment: "")
        public static let privacy = NSLocalizedString("Quyền riêng tư", comment: "")
        public static let developer = NSLocalizedString("Nhà phát triển", comment: "")
        public static let category = NSLocalizedString("Danh mục", comment: "")
        public static let compatibility = NSLocalizedString("Khả năng tương thích", comment: "")
        public static let languages = NSLocalizedString("Ngôn ngữ", comment: "")
        public static let ageRating = NSLocalizedString("Giới hạn độ tuổi", comment: "")
        public static let copyright = NSLocalizedString("Bản quyền", comment: "")
        public static let website = NSLocalizedString("Trang web", comment: "")
        public static let support = NSLocalizedString("Hỗ trợ", comment: "")
        public static let screenshots = NSLocalizedString("Ảnh chụp màn hình", comment: "")
        public static let description = NSLocalizedString("Mô tả", comment: "")
        public static let more = NSLocalizedString("thêm", comment: "")
        public static let free = NSLocalizedString("NHẬN", comment: "")
        public static let installed = NSLocalizedString("ĐÃ CÀI ĐẶT", comment: "")
    }
    
    public struct Settings {
        public static let title = NSLocalizedString("Cài đặt", comment: "")
        public static let none = NSLocalizedString("Không có", comment: "")
        public static let account = NSLocalizedString("Tài khoản Apple ID", comment: "")
        public static let signIn = NSLocalizedString("Đăng nhập", comment: "")
        public static let signOut = NSLocalizedString("Đăng xuất", comment: "")
        public static let signOutConfirmTitle = NSLocalizedString("Đăng xuất Apple ID?", comment: "")
        public static let signOutConfirmMessage = NSLocalizedString("Bạn sẽ cần phải đăng nhập lại để cài đặt hoặc làm mới các ứng dụng.", comment: "")
        public static let signOutConfirmationTitle = signOutConfirmTitle
        public static let signOutConfirmationMessage = signOutConfirmMessage
        public static let activeAccount = NSLocalizedString("Tài khoản đang dùng", comment: "")
        public static let teamType = NSLocalizedString("Loại đội ngũ (Team)", comment: "")
        public static let freeDeveloperAccount = NSLocalizedString("Tài khoản miễn phí", comment: "")
        public static let paidDeveloperAccount = NSLocalizedString("Tài khoản trả phí", comment: "")
        public static let linkPatreon = NSLocalizedString("Liên kết tài khoản Patreon", comment: "")
        public static let unlinkPatreon = NSLocalizedString("Hủy liên kết Patreon", comment: "")
        public static let unlinkPatreonConfirmTitle = NSLocalizedString("Hủy liên kết Patreon?", comment: "")
        public static let unlinkPatreonConfirmMessage = NSLocalizedString("Bạn sẽ không còn nhận được các đặc quyền dành cho người ủng hộ cho đến khi liên kết lại.", comment: "")
        public static let anisetteServer = NSLocalizedString("Máy chủ Anisette", comment: "")
        public static let customAnisetteURL = NSLocalizedString("URL Anisette tùy chỉnh", comment: "")
        public static let backgroundRefresh = NSLocalizedString("Làm mới trong nền", comment: "")
        public static let backgroundRefreshDescription = NSLocalizedString("Tự động làm mới các ứng dụng đã cài đặt trong nền khi có kết nối Wi-Fi và VPN được bật.", comment: "")
        public static let pairingFile = NSLocalizedString("Tệp ghép nối (Pairing File)", comment: "")
        public static let resetPairingFile = NSLocalizedString("Đặt lại tệp ghép nối", comment: "")
        public static let importPairingFile = NSLocalizedString("Nhập tệp ghép nối", comment: "")
        public static let exportLogs = NSLocalizedString("Xuất nhật ký lỗi (Logs)", comment: "")
        public static let errorLogs = NSLocalizedString("Nhật ký lỗi", comment: "")
        public static let clearCache = NSLocalizedString("Xóa bộ nhớ đệm", comment: "")
        public static let clearCacheConfirmTitle = NSLocalizedString("Xóa bộ nhớ đệm ứng dụng?", comment: "")
        public static let clearedAppCache = NSLocalizedString("Đã xóa bộ nhớ đệm ứng dụng", comment: "")
        public static let resetAll = NSLocalizedString("Đặt lại tất cả cài đặt", comment: "")
        public static let resetAllConfirmTitle = NSLocalizedString("Đặt lại tất cả cài đặt?", comment: "")
        public static let resetAllConfirmMessage = NSLocalizedString("Thao tác này sẽ khôi phục mọi thiết lập của SideStore về trạng thái mặc định ban đầu.", comment: "")
        public static let patreon = NSLocalizedString("Patreon", comment: "")
        public static let credits = NSLocalizedString("Đóng góp & Ghi công", comment: "")
        public static let acknowledgements = NSLocalizedString("Lời cảm ơn", comment: "")
        public static let customServerURL = NSLocalizedString("URL máy chủ tùy chỉnh", comment: "")
        public static let jitServer = NSLocalizedString("Máy chủ JIT", comment: "")
        public static let vpnStatus = NSLocalizedString("Trạng thái kết nối VPN", comment: "")
        public static let minimuxerStatus = NSLocalizedString("Trạng thái Minimuxer", comment: "")
        public static let connected = NSLocalizedString("Đã kết nối", comment: "")
        public static let disconnected = NSLocalizedString("Chưa kết nối", comment: "")
        public static let ready = NSLocalizedString("Sẵn sàng", comment: "")
        public static let notReady = NSLocalizedString("Chưa sẵn sàng", comment: "")
        
        public struct Server {
            public static let headerDescription = NSLocalizedString("Chọn máy chủ Anisette để xác thực Apple ID hoặc tự thiết lập máy chủ riêng.", comment: "")
            public static let hostYourOwnLink = NSLocalizedString("tự thiết lập máy chủ riêng", comment: "")
            public static let footerDescription = NSLocalizedString("Máy chủ Anisette giúp cung cấp dữ liệu xác thực thiết bị cần thiết để đăng nhập Apple ID.", comment: "")
            public static let enterCustomURL = NSLocalizedString("Nhập URL tùy chỉnh...", comment: "")
            public static let custom = NSLocalizedString("Tùy chỉnh", comment: "")
            public static let selectAnisetteServer = NSLocalizedString("Chọn máy chủ Anisette", comment: "")
            public static let customAnisetteServerTitle = NSLocalizedString("Máy chủ Anisette tùy chỉnh", comment: "")
            public static let customAnisetteServerMessage = NSLocalizedString("Nhập địa chỉ URL của máy chủ Anisette bạn muốn sử dụng:", comment: "")
        }
        
        public struct PairingFile {
            public static let reset = NSLocalizedString("Đặt lại tệp ghép nối", comment: "")
            public static let resetConfirmTitle = NSLocalizedString("Đặt lại tệp ghép nối?", comment: "")
            public static let resetConfirmMessage = NSLocalizedString("Tệp ghép nối hiện tại sẽ bị xóa và bạn sẽ được yêu cầu chọn tệp mới.", comment: "")
            public static let importSuccessTitle = NSLocalizedString("Nhập thành công", comment: "")
            public static let importSuccessMessage = NSLocalizedString("Tệp ghép nối đã được lưu thành công.", comment: "")
            public static let notFoundTitle = NSLocalizedString("Không tìm thấy tệp ghép nối", comment: "")
            public static let notFoundMessage = NSLocalizedString("Hiện chưa có tệp ghép nối nào được lưu trên thiết bị.", comment: "")
            public static let testSuccessTitle = NSLocalizedString("Kiểm tra thành công", comment: "")
            public static let testSuccessMessage = NSLocalizedString("Tệp ghép nối hợp lệ và kết nối thiết bị hoạt động tốt!", comment: "")
            public static let testFailedTitle = NSLocalizedString("Kiểm tra thất bại", comment: "")
        }
        
        // User Customizations & Cache
        public static let customizationsTitle = NSLocalizedString("Tùy chỉnh giao diện", comment: "")
        public static let themeSectionHeader = NSLocalizedString("Chủ đề & Màu sắc", comment: "")
        public static let accentColorTitle = NSLocalizedString("Màu nhấn chủ đạo", comment: "")
        public static let useCustomAccentColor = NSLocalizedString("Sử dụng màu nhấn tùy chỉnh", comment: "")
        public static let appIconTitle = NSLocalizedString("Biểu tượng ứng dụng", comment: "")
        public static let appearanceModeTitle = NSLocalizedString("Chế độ hiển thị", comment: "")
        public static let appearanceSystem = NSLocalizedString("Theo hệ thống", comment: "")
        public static let appearanceLight = NSLocalizedString("Sáng", comment: "")
        public static let appearanceDark = NSLocalizedString("Tối", comment: "")
        public static let resetCustomizations = NSLocalizedString("Khôi phục giao diện mặc định", comment: "")
        public static let colorDescription = NSLocalizedString("Màu sắc", comment: "")
        
        public static let cacheSectionHeader = NSLocalizedString("Bộ nhớ đệm & Dữ liệu", comment: "")
        public static let clearAppCache = NSLocalizedString("Xóa bộ nhớ đệm ứng dụng", comment: "")
        public static let clearImageCache = NSLocalizedString("Xóa bộ nhớ đệm hình ảnh", comment: "")
        public static let cacheClearedMessage = NSLocalizedString("Đã dọn dẹp bộ nhớ đệm thành công.", comment: "")
        
        // Provisioning Profiles Management
        public static let profilesTitle = NSLocalizedString("Quản lý Hồ sơ (Profiles)", comment: "")
        public static let localProfilesHeader = NSLocalizedString("Hồ sơ trên thiết bị", comment: "")
        public static let remoteProfilesHeader = NSLocalizedString("Hồ sơ trên Apple Developer", comment: "")
        public static let purgeProfilesTitle = NSLocalizedString("Dọn dẹp hồ sơ thừa", comment: "")
        public static let syncProfilesTitle = NSLocalizedString("Đồng bộ hồ sơ", comment: "")
        public static let noProfilesFound = NSLocalizedString("Không tìm thấy hồ sơ nào", comment: "")
        public static let profileUUID = NSLocalizedString("UUID", comment: "")
        public static let profileExpiration = NSLocalizedString("Ngày hết hạn", comment: "")
        public static let profileTeam = NSLocalizedString("Đội ngũ", comment: "")
        
        // Resign / Certificate
        public static let certificatesTitle = NSLocalizedString("Chứng chỉ (Certificates)", comment: "")
        public static let revokeCertificate = NSLocalizedString("Thu hồi chứng chỉ", comment: "")
        public static let revokeCertificateWarning = NSLocalizedString("Thu hồi chứng chỉ hiện tại sẽ tạo một chứng chỉ mới. Bạn có muốn tiếp tục?", comment: "")
    }
    
    public struct UserCustomizations {
        public static let title = NSLocalizedString("Tùy chỉnh", comment: "")
    }
    
    public struct Customizations {
        public static let layoutSectionHeader = NSLocalizedString("Bố cục hiển thị", comment: "")
        public static let hideAppDescriptionsToggle = NSLocalizedString("Ẩn mô tả ứng dụng", comment: "")
        public static let hideScreenShotsToggle = NSLocalizedString("Ẩn ảnh chụp màn hình", comment: "")
        public static let showAppSourceBadgeToggle = NSLocalizedString("Hiện biểu tượng nguồn ứng dụng", comment: "")
        public static let tintColorSectionHeader = NSLocalizedString("Màu chủ đạo", comment: "")
        public static let customTintColorToggle = NSLocalizedString("Dùng màu chủ đạo tùy chỉnh", comment: "")
        public static let selectColorPicker = NSLocalizedString("Chọn màu sắc", comment: "")
        public static let presetColorsHeader = NSLocalizedString("Màu mẫu có sẵn", comment: "")
        public static let colorDescription = NSLocalizedString("Màu", comment: "")
        public static let cacheSectionHeader = NSLocalizedString("Bộ nhớ đệm", comment: "")
        public static let clearCacheFooter = NSLocalizedString("Xóa các dữ liệu hình ảnh và phản hồi mạng tạm thời.", comment: "")
        public static let clearCacheButton = NSLocalizedString("Xóa bộ nhớ đệm", comment: "")
        public static let cacheClearedTitle = NSLocalizedString("Đã xóa bộ nhớ đệm", comment: "")
        public static let cacheClearedMessage = NSLocalizedString("Bộ nhớ đệm đã được dọn sạch.", comment: "")
        public static let logsSectionHeader = NSLocalizedString("Nhật ký hoạt động (Logs)", comment: "")
        public static let enableDetailedLogsToggle = NSLocalizedString("Bật ghi nhật ký chi tiết", comment: "")
        public static let exportLogsButton = NSLocalizedString("Xuất tệp nhật ký", comment: "")
        public static let clearLogsButton = NSLocalizedString("Xóa tệp nhật ký", comment: "")
        public static let clearLogsConfirmationTitle = NSLocalizedString("Xóa nhật ký?", comment: "")
        public static let clearLogsConfirmationMessage = NSLocalizedString("Bạn có chắc chắn muốn xóa toàn bộ nhật ký hoạt động hiện tại không?", comment: "")
    }
    
    public struct Error {
        public static let invalidURLTitle = NSLocalizedString("URL không hợp lệ", comment: "")
        public static let invalidURLMessage = NSLocalizedString("Vui lòng nhập một địa chỉ URL hợp lệ (bắt đầu bằng http:// hoặc https://).", comment: "")
    }
    
    public struct Errors {
        public static let unknownError = NSLocalizedString("Đã xảy ra lỗi không xác định.", comment: "")
        public static let networkError = NSLocalizedString("Lỗi kết nối mạng. Vui lòng kiểm tra lại đường truyền Internet.", comment: "")
        public static let authenticationFailed = NSLocalizedString("Xác thực Apple ID thất bại. Vui lòng kiểm tra lại thông tin đăng nhập.", comment: "")
        public static let maximumAppIDsReached = NSLocalizedString("Bạn đã đạt giới hạn tối đa 10 ID ứng dụng trong 7 ngày của tài khoản Apple miễn phí.", comment: "")
        public static let maximumActiveAppsReached = NSLocalizedString("Tài khoản miễn phí chỉ cho phép kích hoạt tối đa 3 ứng dụng cùng lúc.", comment: "")
        public static let pairingFileMissing = NSLocalizedString("Không tìm thấy tệp ghép nối (Pairing File). Vui lòng nhập tệp ghép nối trong phần Cài đặt.", comment: "")
        public static let vpnNotConnected = NSLocalizedString("Chưa kết nối VPN (WireGuard/StosVPN). Vui lòng bật VPN trước khi thực hiện thao tác này.", comment: "")
        public static let invalidIPA = NSLocalizedString("Tệp .ipa không hợp lệ hoặc bị hỏng.", comment: "")
        public static let diskSpaceInsufficient = NSLocalizedString("Thiết bị không đủ dung lượng trống để thực hiện cài đặt.", comment: "")
        public static let anisetteError = NSLocalizedString("Không thể lấy dữ liệu xác thực từ máy chủ Anisette. Hãy thử đổi máy chủ Anisette khác trong Cài đặt.", comment: "")
    }
}

public extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}
