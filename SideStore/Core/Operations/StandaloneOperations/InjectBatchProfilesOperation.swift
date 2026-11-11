
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

        // Tắt 4G đúng 1 lần duy nhất (nếu chạy trong app; nếu chạy qua Shortcut 2 giai đoạn thì tự bỏ qua)
        await CellularRefreshManager.shared.turnOffDataIfNeeded()
        
        // Nạp lại PairingFile & khởi động lại Minimuxer trên giao diện mạng hiện tại (sau khi tắt 4G / bật VPN)
        // (startMinimuxer đã bao gồm sẵn startEMProxy nếu bật WireGuard EMP)
        if let pf = PairingFileManager.shared.fetchPairingFile() {
            try? await AppBootManager.shared.startMinimuxer(pairingFile: pf)
        }
        
        // Đợi đường truyền lockdownd thực sự thông suốt (chống lỗi ProfileInstall khi bảng định tuyến vừa đổi)
        _ = await CellularRefreshManager.shared.waitForMinimuxerReady(timeout: 6.0)
        try? await ensureMinimuxerReady()
        
        do {
            for batch in sortedBatches {
                debugLog("[InjectBatchProfilesOperation] Installing \(batch.profiles.count) profile(s) for \(batch.bundleID)...")
                var mainProfile: ALTProvisioningProfile?
                
                for profileData in batch.profiles {
                    if mainProfile == nil, let parsed = try? ALTProvisioningProfile(data: profileData) {
                        mainProfile = parsed
                    }
                    
                    do {
                        try await installProvisioningProfiles(profileData)
                    } catch {
                        debugLog("[InjectBatchProfilesOperation] First attempt failed for \(batch.bundleID), resetting muxer & retrying: \(error)")
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if let pf = PairingFileManager.shared.fetchPairingFile() {
                            try? await minimuxerStart(pf, preferred: PairingFileManager.shared.preferredProtocol)
                        }
                        _ = await CellularRefreshManager.shared.waitForMinimuxerReady(timeout: 5.0)
                        try await installProvisioningProfiles(profileData)
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

