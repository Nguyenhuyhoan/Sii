//
//  InjectBatchProfilesOperation.swift
//  SideStore
//
//  Created by Magesh K on 14/09/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import CoreData
import SideSign
import Minimuxer

final class InjectBatchProfilesOperation: BaseStandaloneOperation<StandaloneOperationContext, Void>, @unchecked Sendable {
    let batches: [PendingProfileBatch]
    var onAppCompleted: (@Sendable (String) -> Void)?

    init(
        batches: [PendingProfileBatch],
        context: StandaloneOperationContext,
        onAppCompleted: (@Sendable (String) -> Void)? = nil
    ) throws {
        self.batches = batches
        self.onAppCompleted = onAppCompleted
        try super.init(context: context)
    }

    override func execute(parentProgress: Progress?) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[InjectBatchProfilesOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[InjectBatchProfilesOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)

        guard !self.batches.isEmpty else {
            debugLog("[InjectBatchProfilesOperation] No pending profiles collected across batch, skipping")
            return
        }

        // Sắp xếp để ứng dụng chính (lc+ss / SideStore) luôn được tiêm profile cuối cùng
        let sortedBatches = self.batches.sorted { b1, b2 in
            let isB1Self = (b1.bundleID == StoreApp.altstoreAppID) || b1.bundleID.isAltStoreAppID || (b1.bundleID == Bundle.main.bundleIdentifier)
            let isB2Self = (b2.bundleID == StoreApp.altstoreAppID) || b2.bundleID.isAltStoreAppID || (b2.bundleID == Bundle.main.bundleIdentifier)
            if isB1Self != isB2Self {
                return !isB1Self
            }
            return false
        }

        debugLog("[InjectBatchProfilesOperation] Running batch injection for \(sortedBatches.count) app(s)")

        // Tắt 4G đúng 1 lần duy nhất.
        // Lưu ý: Nếu hàm này trả về true, nó ĐÃ tự gọi resetAndPrepareMinimuxer() bên trong.
        let didTurnOffAndReset = await CellularRefreshManager.shared.turnOffDataIfNeeded()
        
        if !didTurnOffAndReset {
            // Trường hợp chạy qua Shortcut 2 giai đoạn (4G đã tắt sẵn từ bên ngoài) hoặc Wi-Fi:
            // Reset sạch Minimuxer (Stop -> Sleep -> Start -> Wait) để tránh lỗi MinimuxerError 35
            let isReady = await CellularRefreshManager.shared.resetAndPrepareMinimuxer(timeout: 6.0)
            if !isReady {
                try? await ensureMinimuxerReady()
            }
        }
        
        do {
            for batch in sortedBatches {
                debugLog("[InjectBatchProfilesOperation] Installing \(batch.profiles.count) profile(s) for \(batch.bundleID)...")
                var mainProfile: ALTProvisioningProfile?
                
                for profileData in batch.profiles {
                    if mainProfile == nil, let parsed = try? ALTProvisioningProfile(data: profileData) {
                        mainProfile = parsed
                    }
                    
                    var lastError: Error?
                    for attempt in 1...3 {
                        do {
                            try await installProvisioningProfiles(profileData)
                            lastError = nil
                            break
                        } catch {
                            lastError = error
                            debugLog("[InjectBatchProfilesOperation] Attempt \(attempt) failed for \(batch.bundleID), resetting muxer & retrying: \(error)")
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            _ = await CellularRefreshManager.shared.resetAndPrepareMinimuxer(timeout: 6.0)
                        }
                    }
                    if let error = lastError {
                        throw error
                    }
                }

                // Cập nhật Database cho cả trường hợp chạy trong App (batch.app != nil)
                // VÀ trường hợp chạy từ Shortcut Giai đoạn 2 đọc từ JSON (batch.app == nil)
                let dbContext = batch.app?.managedObjectContext ?? self.context.dbBackgroundContext
                let targetBundleID = batch.bundleID
                let certStatus = batch.certStatus
                let parsedCreationDate = mainProfile?.creationDate
                let parsedExpirationDate = mainProfile?.expirationDate
                let existingAppObjectID = batch.app?.objectID

                try? await dbContext.perform {
                    let appToUpdate: InstalledApp?
                    if let objectID = existingAppObjectID,
                       let existingApp = try? dbContext.existingObject(with: objectID) as? InstalledApp {
                        appToUpdate = existingApp
                    } else {
                        let predicate = NSPredicate(
                            format: "%K == %@ OR %K == %@",
                            #keyPath(InstalledApp.bundleIdentifier), targetBundleID,
                            #keyPath(InstalledApp.resignedBundleIdentifier), targetBundleID
                        )
                        appToUpdate = InstalledApp.first(satisfying: predicate, in: dbContext)
                    }
                    
                    if let installedApp = appToUpdate {
                        if let certStatus = certStatus {
                            installedApp.certificateStatus = certStatus
                        }
                        if let creationDate = parsedCreationDate, let expirationDate = parsedExpirationDate {
                            installedApp.refreshedDate = creationDate
                            installedApp.expirationDate = expirationDate
                        }
                        if dbContext.hasChanges {
                            try dbContext.save()
                        }
                    }
                }

                self.onAppCompleted?(batch.bundleID)
                debugLog("[InjectBatchProfilesOperation] Successfully processed \(batch.bundleID)")
            }
            
            // Bật lại 4G ngay sau khi tiêm xong tất cả
            await CellularRefreshManager.shared.turnOnDataIfNeeded()
        } catch {
            // Đảm bảo luôn bật lại 4G nếu có lỗi bất ngờ
            await CellularRefreshManager.shared.turnOnDataIfNeeded()
            throw error
        }

        debugLog("[InjectBatchProfilesOperation] Batch profile injection completed for all \(sortedBatches.count) app(s)")
        self.setProgress(100)
    }
}
