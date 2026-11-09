//
//  BackgroundTaskManager.swift
//  AltStore
//
//  Created by Riley Testut on 6/19/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import AVFoundation

final class BackgroundTaskManager
{
    static let shared = BackgroundTaskManager()
    
    private init() {}
}

extension BackgroundTaskManager
{
    func performExtendedBackgroundTask(taskHandler: @escaping ((Result<Void, Error>, @escaping () -> Void) -> Void))
    {
        func finish() {}
        
        taskHandler(.success(())) {
            finish()
        }
    }
}
