//
//  AppBootManager.swift
//  SideStore
//
//  Created by Magesh K on 9/7/26.
//  Copyright © 2026 SideStore. All rights reserved.
//

import Foundation
import UIKit
import Minimuxer

public final class AppBootManager {
    public static let shared = AppBootManager()
    
    private let lock = NSLock()
    
    private var cachedNeedsPairingPrompt = false
    public var needsPairingPrompt: Bool {
        get { lock.withLock { cachedNeedsPairingPrompt } }
        set { lock.withLock { cachedNeedsPairingPrompt = newValue } }
    }
    
    private var cachedNeedsSideJITPrompt = false
    public var needsSideJITPrompt: Bool {
        get { lock.withLock { cachedNeedsSideJITPrompt } }
        set { lock.withLock { cachedNeedsSideJITPrompt = newValue } }
    }
    
    private init() {}

    public nonisolated func startMinimuxer(pairingFile: String) async throws {
        if UserDefaults.standard.enableEMPforWireguard {
            try await startEMProxy()
        }

        let preferred = PairingFileManager.shared.preferredProtocol
        try await minimuxerStart(pairingFile, preferred: preferred)
        
        // TỐI ƯU: Dùng forceLive: false để lấy ngay UDID từ Keychain cache nếu đã có,
        // không bắt máy phải mở kết nối mạng/VPN giả lập tới lockdownd mỗi lần mở app!
        do {
            _ = try await fetchUDID(forceLive: false)
            self.needsPairingPrompt = false
        } catch {
            if case MinimuxerError.invalidPairing = error {
                self.needsPairingPrompt = true
                throw error
            }
        }
    }
    
    @MainActor
    public func promptForPairing(on vc: UIViewController) async {
        var isRetry = false
        while true {
            guard let _ = await withCheckedContinuation({ (continuation: CheckedContinuation<URL?, Never>) in
                PairingViewController.shared.presentPairingFileAlert(on: vc, isRetry: isRetry) { selectedURL in
                    continuation.resume(returning: selectedURL)
                }
            }) else {
                break
            }
            
            guard let pairingString = PairingFileManager.shared.fetchPairingFile() else {
                isRetry = true
                continue
            }
            
            do {
                try await self.startMinimuxer(pairingFile: pairingString)
                self.needsPairingPrompt = false
                break
            } catch {
                let didSwitch = await PairingViewController.shared.handlePotentialProtocolMismatch(
                    on: vc,
                    pairingContent: pairingString
                )
                if didSwitch {
                    do {
                        try await self.startMinimuxer(pairingFile: pairingString)
                        self.needsPairingPrompt = false
                        break
                    } catch {}
                }
                isRetry = true
            }
        }
    }
    
    public nonisolated func performBootSequence() async {
        // ĐÃ XÓA BỎ HOÀN TOÀN KHỐI `jitCheck` QUÉT MẠNG NỘI BỘ TÌM SIDEJITSERVER LÚC KHỞI ĐỘNG!
        guard let pf = PairingFileManager.shared.fetchPairingFile() else {
            #if !targetEnvironment(simulator)
            self.needsPairingPrompt = true
            #endif
            return
        }

        do {
            try await self.startMinimuxer(pairingFile: pf)
        } catch {}
    }
}
