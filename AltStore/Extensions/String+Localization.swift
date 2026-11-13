
//
//  String+Localization.swift
//  AltStore
//
//  Created by Riley Testut on 9/10/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import UIKit

public func systemLocalizedString(_ key: String) -> String
{
    return Bundle(for: UIApplication.self).localizedString(forKey: key, value: nil, table: nil)
}

public enum AppStrings
{
    public enum Common
    {
        public static let ok = systemLocalizedString("OK")
        public static let cancel = NSLocalizedString("Hủy", comment: "")
        public static let done = NSLocalizedString("Xong", comment: "")
        public static let save = NSLocalizedString("Lưu", comment: "")
        public static let add = NSLocalizedString("Thêm", comment: "")
        public static let remove = NSLocalizedString("Xóa", comment: "")
        public static let delete = NSLocalizedString("Xóa", comment: "")
        public static let edit = NSLocalizedString("Sửa", comment: "")
        public static let close = NSLocalizedString("Đóng", comment: "")
        public static let retry = NSLocalizedString("Thử lại", comment: "")
        public static let yes = NSLocalizedString("Có", comment: "")
        public static let no = NSLocalizedString("Không", comment: "")
        public static let copy = NSLocalizedString("Sao chép", comment: "")
        public static let share = NSLocalizedString("Chia sẻ", comment: "")
        public static let next = NSLocalizedString("Tiếp tục", comment: "")
        public static let back = NSLocalizedString("Quay lại", comment: "")
        
        public static func resetToDefault() -> String {
            return NSLocalizedString("Đặt lại về mặc định", comment: "")
        }
    }
    
    public enum Error
    {
        public static let title = NSLocalizedString("Lỗi", comment: "")
        public static let unknown = NSLocalizedString("Đã xảy ra lỗi không xác định.", comment: "")
        public static let invalidURLTitle = NSLocalizedString("URL không hợp lệ", comment: "")
        public static let invalidURLMessage = NSLocalizedString("Vui lòng nhập một địa chỉ URL hợp lệ.", comment: "")
    }
    
    public enum Browse
    {
        public static let title = NSLocalizedString("Khám phá", comment: "")
        public static let searchPlaceholder = NSLocalizedString("Tìm kiếm ứng dụng...", comment: "")
        public static let noAppsTitle = NSLocalizedString("Không có ứng dụng", comment: "")
        public static let noAppsMessage = NSLocalizedString("Chưa có ứng dụng nào trong nguồn lưu trữ của bạn.", comment: "")
        public static let sourcesButton = NSLocalizedString("Nguồn", comment: "")
        public static let free = NSLocalizedString("NHẬN", comment: "")
        public static let open = NSLocalizedString("MỞ", comment: "")
        public static let update = NSLocalizedString("CẬP NHẬT", comment: "")
        public static let beta = NSLocalizedString("BETA", comment: "")
    }
    
    public enum MyApps
    {
        public static let title = NSLocalizedString("Ứng dụng của tôi", comment: "")
        public static let activeSectionTitle = NSLocalizedString("Đang hoạt động", comment: "")
        public static let inactiveSectionTitle = NSLocalizedString("Không hoạt động", comment: "")
        public static let updatesAvailable = NSLocalizedString("Bản cập nhật khả dụng", comment: "")
        public static let refreshAll = NSLocalizedString("Làm mới tất cả", comment: "")
        public static let noInstalledApps = NSLocalizedString("Chưa có ứng dụng nào được cài đặt", comment: "")
        public static let daysRemaining = NSLocalizedString("%d NGÀY", comment: "")
        public static let expired = NSLocalizedString("Hết hạn", comment: "")
        public static let deactivate = NSLocalizedString("Hủy kích hoạt", comment: "")
        public static let activate = NSLocalizedString("Kích hoạt", comment: "")
        public static let backup = NSLocalizedString("Sao lưu", comment: "")
        public static let restore = NSLocalizedString("Khôi phục", comment: "")
        public static let enableJIT = NSLocalizedString("Bật JIT", comment: "")
        public static let removeApp = NSLocalizedString("Gỡ cài đặt", comment: "")
        public static let viewInStore = NSLocalizedString("Xem trong Cửa hàng", comment: "")
    }
    
    public enum News
    {
        public static let title = NSLocalizedString("Tin tức", comment: "")
        public static let noNewsItems = NSLocalizedString("Không có tin tức nào", comment: "")
        public static let failedToFetchNews = NSLocalizedString("Không thể tải tin tức.\n%@\n\nChạm để thử lại.", comment: "")
        public static let doubleTapToExpand = NSLocalizedString("Chạm hai lần để mở rộng.", comment: "")
        public static let doubleTapToCollapse = NSLocalizedString("Chạm hai lần để thu gọn.", comment: "")
        public static let openInBrowser = NSLocalizedString("Mở \"%@\" trong trình duyệt", comment: "")
        public static let viewApp = NSLocalizedString("Xem ứng dụng \"%@\"", comment: "")
        public static let opensProfilePage = NSLocalizedString("Mở trang thông tin của %@.", comment: "")
    }
    
    public enum Sources
    {
        public static let title = NSLocalizedString("Nguồn lưu trữ", comment: "")
        public static let addSourceTitle = NSLocalizedString("Thêm Nguồn", comment: "")
        public static let addSourceMessage = NSLocalizedString("Nhập URL nguồn lưu trữ SideStore/AltStore (cách nhau bằng dấu cách hoặc xuống dòng):", comment: "")
        public static let removeSourceConfirmTitle = NSLocalizedString("Xóa \"%@\"?", comment: "")
        public static let removeSourceConfirmMessage = NSLocalizedString("Các ứng dụng đã cài đặt từ nguồn này sẽ vẫn hoạt động, nhưng bạn sẽ không nhận được bản cập nhật từ nguồn này nữa.", comment: "")
        public static let recommendedSources = NSLocalizedString("Nguồn đề xuất", comment: "")
        public static let addedSources = NSLocalizedString("Nguồn đã thêm", comment: "")
        public static let noSources = NSLocalizedString("Không có Nguồn nào", comment: "")
        public static let YouHaveNotAddedAnySources = NSLocalizedString("Bạn chưa thêm bất kỳ nguồn lưu trữ nào.", comment: "")
        public static let copiedToClipboardTitle = NSLocalizedString("Đã sao chép vào bộ nhớ tạm", comment: "")
        public static let copyURL = NSLocalizedString("Sao chép URL", comment: "")
        
        public static func copiedToClipboardMessage(count: Int) -> String {
            return String(format: NSLocalizedString("Đã sao chép %d URL nguồn.", comment: ""), count)
        }
    }
    
    public enum Settings
    {
        public static let title = NSLocalizedString("Cài đặt", comment: "")
        public static let none = NSLocalizedString("Không có", comment: "")
        public static let signIn = NSLocalizedString("Đăng nhập bằng Apple ID", comment: "")
        public static let signOut = NSLocalizedString("Đăng xuất", comment: "")
        public static let signOutConfirmTitle = NSLocalizedString("Bạn có chắc chắn muốn đăng xuất?", comment: "")
        public static let signOutConfirmMessage = NSLocalizedString("Bạn sẽ không thể làm mới hoặc cài đặt ứng dụng cho đến khi đăng nhập lại.", comment: "")
        public static let linkPatreon = NSLocalizedString("Liên kết tài khoản Patreon", comment: "")
        public static let unlinkPatreon = NSLocalizedString("Hủy liên kết Patreon", comment: "")
        public static let unlinkPatreonConfirmTitle = NSLocalizedString("Bạn có chắc chắn muốn hủy liên kết tài khoản Patreon?", comment: "")
        public static let unlinkPatreonConfirmMessage = NSLocalizedString("Bạn sẽ không còn quyền truy cập vào các tính năng beta cho đến khi liên kết lại.", comment: "")
        public static let clearCache = NSLocalizedString("Xóa bộ nhớ đệm", comment: "")
        public static let clearCacheConfirmTitle = NSLocalizedString("Bạn có chắc chắn muốn xóa bộ nhớ đệm ứng dụng?", comment: "")
        public static let clearedAppCache = NSLocalizedString("Đã xóa bộ nhớ đệm ứng dụng", comment: "")
        public static let resetAll = NSLocalizedString("Đặt lại tất cả cài đặt", comment: "")
        public static let resetAllConfirmTitle = NSLocalizedString("Đặt lại tất cả cài đặt?", comment: "")
        public static let resetAllConfirmMessage = NSLocalizedString("Thao tác này sẽ khôi phục toàn bộ tùy chỉnh của SideStore về mặc định ban đầu.", comment: "")
        
        public enum Server
        {
            public static let selectAnisetteServer = NSLocalizedString("Chọn máy chủ Anisette", comment: "")
            public static let custom = NSLocalizedString("Tùy chỉnh...", comment: "")
            public static let enterCustomURL = NSLocalizedString("Nhập URL máy chủ tùy chỉnh", comment: "")
            public static let customAnisetteServerTitle = NSLocalizedString("Máy chủ Anisette tùy chỉnh", comment: "")
            public static let customAnisetteServerMessage = NSLocalizedString("Nhập địa chỉ URL của máy chủ Anisette v3 mà bạn muốn sử dụng:", comment: "")
            public static let hostYourOwnLink = NSLocalizedString("tự tạo máy chủ của riêng bạn", comment: "")
            public static let headerDescription = NSLocalizedString("Máy chủ Anisette được sử dụng để xác thực tài khoản Apple ID. Bạn có thể chọn một máy chủ có sẵn hoặc tự tạo máy chủ của riêng bạn.", comment: "")
            public static let footerDescription = NSLocalizedString("Nếu gặp lỗi khi đăng nhập hoặc làm mới ứng dụng, hãy thử chuyển sang một máy chủ Anisette khác trong danh sách.", comment: "")
        }
        
        public enum PairingFile
        {
            public static let reset = NSLocalizedString("Đặt lại tệp ghép đôi", comment: "")
            public static let resetConfirmTitle = NSLocalizedString("Đặt lại tệp ghép đôi?", comment: "")
            public static let resetConfirmMessage = NSLocalizedString("Tệp ghép đôi hiện tại sẽ bị xóa và bạn sẽ được yêu cầu chọn tệp mới.", comment: "")
            public static let importSuccessTitle = NSLocalizedString("Nhập thành công", comment: "")
            public static let importSuccessMessage = NSLocalizedString("Đã lưu tệp ghép đôi mới thành công.", comment: "")
            public static let notFoundTitle = NSLocalizedString("Không tìm thấy tệp ghép đôi", comment: "")
            public static let notFoundMessage = NSLocalizedString("Chưa có tệp ghép đôi nào được nhập vào SideStore.", comment: "")
            public static let testSuccessTitle = NSLocalizedString("Kiểm tra thành công", comment: "")
            public static let testSuccessMessage = NSLocalizedString("Tệp ghép đôi hợp lệ và kết nối thiết bị hoạt động bình thường!", comment: "")
            public static let testFailedTitle = NSLocalizedString("Kiểm tra thất bại", comment: "")
        }
    }
    
    public enum UserCustomizations
    {
        public static let title = NSLocalizedString("Tùy chỉnh giao diện", comment: "")
        public static let themeSection = NSLocalizedString("Màu sắc & Chủ đề", comment: "")
        public static let behaviorSection = NSLocalizedString("Hành vi ứng dụng", comment: "")
        public static let resetDefaults = NSLocalizedString("Khôi phục mặc định", comment: "")
    }
    
    public enum Customizations
    {
        public static let documentImportDescription = NSLocalizedString("Mô tả nhập tài liệu", comment: "")
        public static let colorDescription = NSLocalizedString("Màu sắc", comment: "")
        public static letcacheSectionHeader = NSLocalizedString("Bộ nhớ đệm", comment: "")
        public static let cacheSectionHeader = NSLocalizedString("Bộ nhớ đệm", comment: "")
        public static let clearCacheButton = NSLocalizedString("Xóa bộ nhớ đệm", comment: "")
        public static let clearCacheFooter = NSLocalizedString("Giải phóng dung lượng lưu trữ tạm thời của ứng dụng.", comment: "")
        public static let layoutSectionHeader = NSLocalizedString("Bố cục", comment: "")
        public static let hideAppDescriptionsToggle = NSLocalizedString("Ẩn mô tả ứng dụng", comment: "")
        public static let hideScreenShotsToggle = NSLocalizedString("Ẩn ảnh chụp màn hình", comment: "")
        public static let showAppSourceBadgeToggle = NSLocalizedString("Hiển thị nhãn nguồn ứng dụng", comment: "")
        public static let tintColorSectionHeader = NSLocalizedString("Màu chủ đạo", comment: "")
        public static let customTintColorToggle = NSLocalizedString("Sử dụng màu tùy chỉnh", comment: "")
        public static let selectColorPicker = NSLocalizedString("Chọn màu", comment: "")
        public static let presetColorsHeader = NSLocalizedString("Màu cài sẵn", comment: "")
        public static let logsSectionHeader = NSLocalizedString("Nhật ký hệ thống", comment: "")
        public static let enableDetailedLogsToggle = NSLocalizedString("Bật nhật ký chi tiết", comment: "")
        public static let exportLogsButton = NSLocalizedString("Xuất nhật ký", comment: "")
        public static let clearLogsButton = NSLocalizedString("Xóa nhật ký", comment: "")
        public static let clearLogsConfirmationTitle = NSLocalizedString("Xóa toàn bộ nhật ký?", comment: "")
        public static let clearLogsConfirmationMessage = NSLocalizedString("Hành động này không thể hoàn tác.", comment: "")
        public static let cacheClearedTitle = NSLocalizedString("Đã xóa bộ nhớ đệm", comment: "")
        public static let cacheClearedMessage = NSLocalizedString("Toàn bộ tệp tạm đã được dọn dẹp.", comment: "")
    }
}
