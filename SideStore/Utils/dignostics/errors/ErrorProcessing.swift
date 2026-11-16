
//
//  ErrorProcessing.swift
//  SideStore
//
//  Created by Magesh K on 20/01/25.
//  Copyright © 2025 SideStore. All rights reserved.
//

import Foundation

class ErrorProcessing {
    
    enum InfoMode: String {
        case fullError
        case localizedDescription
    }
    
    // MARK: - 🚨 PHÂN LOẠI 3 LỖI HỆ THỐNG QUAN TRỌNG CHO CÀI ĐẶT
    enum CriticalErrorCategory: String {
        case pairingFile = "Lỗi Pairing File (Tệp ghép nối)"
        case pairedDevice = "Lỗi Thiết bị đã ghép nối (Minimuxer / VPN)"
        case server = "Lỗi Máy chủ (Anisette / Apple Server)"
    }
    
    static let pendingErrorCategoryKey = "SideStore.PendingCriticalErrorCategory"
    static let pendingErrorDetailKey = "SideStore.PendingCriticalErrorDetail"
    static let pendingErrorTimestampKey = "SideStore.PendingCriticalErrorTimestamp"
    static let criticalErrorDetectedNotification = Notification.Name("SideStore.CriticalErrorDetectedNotification")
    
    let info: InfoMode
    let unique: Bool
    let recur: Bool
    
    var errors: Set<String> = []
    
    // by default we will process only the localDesc on first level errors
    init(_ mode: InfoMode = .localizedDescription, unique: Bool = false, recur: Bool = false){
        self.info = mode
        self.unique = unique
        self.recur = recur
    }
    
    // MARK: - 🔍 NHẬN DIỆN & LƯU TRẠNG THÁI LỖI HỆ THỐNG
    static func classifyCriticalError(_ error: NSError) -> CriticalErrorCategory? {
        var visited = Set<String>()
        return inspectErrorNode(error, visited: &visited)
    }
    
    private static func inspectErrorNode(_ error: NSError, visited: inout Set<String>) -> CriticalErrorCategory? {
        let signature = "\(error.domain)#\(error.code)#\(error.localizedDescription)"
        guard !visited.contains(signature) else { return nil }
        visited.insert(signature)
        
        let domain = error.domain.lowercased()
        let desc = error.localizedDescription.lowercased()
        let failureReason = (error.localizedFailureReason ?? "").lowercased()
        let recovery = (error.localizedRecoverySuggestion ?? "").lowercased()
        let debugText = "\(error)".lowercased()
        let combined = "\(domain) \(desc) \(failureReason) \(recovery) \(debugText)"
        
        // 1. Kiểm tra Lỗi Pairing File (Tệp ghép nối bị thiếu, sai định dạng, hết hạn hoặc sai UDID)
        let pairingKeywords = [
            "pairing file", "pairingfile", "mobiledevicepairing", "pair_record",
            "pairing record", "invalid pairing", "missing pairing", "no pairing",
            "plist", "escrowbag", "hostid", "systembuid", "tệp ghép nối"
        ]
        if domain.contains("pairing") || pairingKeywords.contains(where: { combined.contains($0) }) {
            return .pairingFile
        }
        
        // 2. Kiểm tra Lỗi Thiết bị đã ghép nối (Minimuxer, LocalDevVPN, mất kết nối tới thiết bị)
        let deviceKeywords = [
            "minimuxer", "muxer", "idevice", "lockdownd", "instproxy",
            "misagent", "afc", "heartbeat", "no device", "device not found",
            "connect to device", "connection to device", "localdevvpn",
            "wireguard", "stovpn", "vpn", "jit", "debugserver", "thiết bị ghép nối"
        ]
        if domain.contains("minimuxer") || domain.contains("muxer") || domain.contains("device") ||
           deviceKeywords.contains(where: { combined.contains($0) }) {
            return .pairedDevice
        }
        
        // 3. Kiểm tra Lỗi Máy chủ (Anisette Server, Apple Developer Portal, lỗi kết nối mạng)
        let serverKeywords = [
            "anisette", "altanisette", "apple", "developer portal", "gsa.apple.com",
            "idms", "502 bad gateway", "503 service", "504 gateway", "500 internal",
            "timed out", "timeout", "cannot connect to host", "could not connect to the server",
            "network connection was lost", "offline", "ssl", "tls", "server", "máy chủ"
        ]
        if domain == NSURLErrorDomain.lowercased() ||
           domain.contains("anisette") ||
           domain.contains("altapple") ||
           domain.contains("altserver") ||
           domain.contains("cfnetwork") ||
           serverKeywords.contains(where: { combined.contains($0) }) {
            return .server
        }
        
        // Đệ quy kiểm tra các lỗi bọc bên trong (ALTWrappedError & underlyingErrors)
        if let wrappedError = (error as? ALTWrappedError)?.wrappedError {
            if let found = inspectErrorNode(wrappedError, visited: &visited) {
                return found
            }
        }
        
        for underlying in error.underlyingErrors {
            if let found = inspectErrorNode(underlying as NSError, visited: &visited) {
                return found
            }
        }
        
        if let singleUnderlying = error.underlyingError as NSError? {
            if let found = inspectErrorNode(singleUnderlying, visited: &visited) {
                return found
            }
        }
        
        return nil
    }
    
    static func recordCriticalErrorIfNeeded(_ error: NSError, formattedDescription: String? = nil) {
        guard let category = classifyCriticalError(error) else { return }
        
        let detail = (formattedDescription?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? error.localizedDescription
        
        let defaults = UserDefaults.standard
        defaults.set(category.rawValue, forKey: pendingErrorCategoryKey)
        defaults.set(detail, forKey: pendingErrorDetailKey)
        defaults.set(Date().timeIntervalSince1970, forKey: pendingErrorTimestampKey)
        
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: criticalErrorDetectedNotification,
                object: nil,
                userInfo: [
                    "category": category.rawValue,
                    "detail": detail
                ]
            )
        }
    }
    
    static func clearRecordedCriticalError() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: pendingErrorCategoryKey)
        defaults.removeObject(forKey: pendingErrorDetailKey)
        defaults.removeObject(forKey: pendingErrorTimestampKey)
    }
    
    private func userFriendlyDescription(for error: NSError) -> String {
        let domain = error.domain
        if domain == "kcerrordomain" || domain == NSOSStatusErrorDomain {
            switch error.code {
            case -25300: // errSecItemNotFound
                return NSLocalizedString("Keychain item not found.", comment: "")
            case -25299: // errSecDuplicateItem
                return NSLocalizedString("Keychain item already exists.", comment: "")
            case -25293: // errSecAuthFailed
                return NSLocalizedString("Keychain authentication failed.", comment: "")
            default:
                return NSLocalizedString("Keychain security error.", comment: "")
            }
        }
        return error.localizedDescription
    }

    private func processError(_ error: NSError, ignoreTitle: Bool = false, getMoreErrors: (_ error: NSError)->String) -> String{
        // if unique was requested and if this error is duplicate, ignore processing it
        let serializedError = "\(error)"
        if unique && errors.contains(serializedError) {
            return ""
        }
        errors.insert(serializedError)    // mark this as processed
        
        var title = ""
        var desc = ""
        switch (info){
            case .localizedDescription:
                title = !ignoreTitle ? (error.localizedTitle.map{$0+"\n"} ?? "") : ""
                desc = userFriendlyDescription(for: error)
            case .fullError:
                desc = serializedError
        }
        var moreErrors = getMoreErrors(error)
        moreErrors = moreErrors == "" ? "" : "\n" + moreErrors
        return title + desc + moreErrors
    }

    func getDescription(error: NSError) -> String{
        errors = []  // reinit for each request
        let finalDescription = getDescriptionText(error: error)
        ErrorProcessing.recordCriticalErrorIfNeeded(error, formattedDescription: finalDescription)
        return finalDescription
    }
    
    
    func getDescriptionText(error: NSError,_ depth: Int = 0) -> String{
        if depth == 0 {
            ErrorProcessing.recordCriticalErrorIfNeeded(error)
        }
        
        // closure
        let recurseErrors = { error in
            self.getDescriptionText(error: error, depth+1)
        }
        
        var description = ""
        // process current error only if recur was not requested
        let processMoreErrors = recur ? recurseErrors : {_ in ""}
        
        let underlyingErrors = error.underlyingErrors
        if let wrappedError = (error as? ALTWrappedError)?.wrappedError {
            description += getDescriptionText(error: wrappedError, depth + 1)
        } else if !underlyingErrors.isEmpty {
            description += underlyingErrors.map{ error in
                let error = error as NSError
                return processError(error, getMoreErrors: processMoreErrors)
            }.joined(separator: "\n")
        } else if let underlyingError = error.underlyingError as? NSError {
            let error = underlyingError as NSError
            description += processError(error, getMoreErrors: processMoreErrors)
        } else {
            // ignore the title for the base error since we wanted this to be description
            let isBaseError = (depth == 0)
            description += processError(error, ignoreTitle: isBaseError, getMoreErrors: processMoreErrors)
        }
        return description
    }
}
