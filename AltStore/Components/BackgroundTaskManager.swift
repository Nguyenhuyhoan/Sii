
//
//  BackgroundTaskManager.swift
//  AltStore
//
//  Created by Riley Testut on 6/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import Foundation
import UIKit

final class BackgroundTaskManager
{
    static let shared = BackgroundTaskManager()
    
    private init()
    {
        // ĐÃ XÓA BỎ HOÀN TOÀN AVAudioEngine & Silence.m4a!
        // Không bật phần cứng âm thanh, không hao pin, không xung đột tai nghe/nhạc nền.
    }
}

extension BackgroundTaskManager
{
    func performExtendedBackgroundTask(taskHandler: @escaping ((Result<Void, Error>, @escaping () -> Void) -> Void))
    {
        // Sử dụng API chính thống siêu nhẹ của iOS để giữ kết nối khi người dùng vuốt ra màn hình chính
        // mà không cần giả lập phát nhạc ngầm gây nóng máy.
        var bgTaskID: UIBackgroundTaskIdentifier = .invalid
        
        let endTask = {
            if bgTaskID != .invalid {
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
        }
        
        DispatchQueue.main.async {
            bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "com.altstore.ExtendedBackgroundTask") {
                // Tự động giải phóng an toàn nếu hết thời gian cho phép của iOS (tránh treo ngầm gây hao pin)
                endTask()
            }
            
            taskHandler(.success(())) {
                DispatchQueue.main.async {
                    endTask()
                }
            }
        }
    }
}
