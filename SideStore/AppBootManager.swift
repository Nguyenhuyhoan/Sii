
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
        
        // Ưu tiên lấy UDID từ Keychain cache (forceLive: false) để mở app nhanh.
        // Nếu chưa có trong cache thì fallback sang forceLive: true để lấy và lưu vào Keychain.
        do {
            if let udid = try? await fetchUDID(forceLive: false), !udid.isEmpty {
                self.needsPairingPrompt = false
            } else {
                _ = try await fetchUDID(forceLive: true)
                self.needsPairingPrompt = false
            }
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
