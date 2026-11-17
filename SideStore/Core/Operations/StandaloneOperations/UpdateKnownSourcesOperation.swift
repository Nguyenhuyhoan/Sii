//
//  UpdateKnownSourcesOperation.swift
//  AltStore
//
//  Created by Riley Testut on 4/13/22.
//  Copyright © 2022 Riley Testut. All rights reserved.
//

import Foundation

class UpdateKnownSourcesOperation: OperationLogging
{
    init() {}
    
    func execute() async throws -> ([KnownSource], [KnownSource])
    {
        // Đã vô hiệu hóa hoàn toàn việc tải danh sách nguồn JSON ngầm lúc khởi động
        // vì ứng dụng đã chuyển sang cơ chế Tab Sửa Lỗi độc lập.
        let cachedDefault = UserDefaults.standard.recommendedSources ?? []
        let cachedBlocked = UserDefaults.standard.blockedSources ?? []
        return (cachedDefault, cachedBlocked)
    }
}
