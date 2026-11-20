//
//  PrepareAppExtensionBundleIDsOperation.swift
//  SideStore
//
//  Created by Magesh K on 01/08/26.
//  Copyright © 2026 AltStore. All rights reserved.
//

import Foundation

final class PrepareAppExtensionBundleIDsOperation: BasePipelineOperation<InstallAppOperationContext, Void>, @unchecked Sendable {
    override func execute(parentProgress: Progress?) async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        debugLog("[PrepareAppExtensionBundleIDsOperation] execute() started")
        defer {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            debugLog("[PrepareAppExtensionBundleIDsOperation] execute() took: \(String(format: "%.3fs", elapsed))")
        }
        try await super.executePreconditionCheck(parentProgress: parentProgress)

        if self.context.useMainProfile {
            let mainBundleKey = self.context.targetBundleIdentifier
            if let appBundle = self.context.targetAppBundle,
               let profile = self.context.provisioningProfiles?[mainBundleKey]
                    ?? self.context.provisioningProfiles?[self.context.bundleIdentifier]
                    ?? self.context.provisioningProfiles?.values.first {
                var appexBundleIds: [String: String] = [:]
                for appex in appBundle.appExtensions {
                    let originalExtID = appex.bundleIdentifier
                    let originalMainID = appBundle.bundleIdentifier

                    let resolvedAppExBundleID: String
                    if originalExtID.hasPrefix(originalMainID + ".") {
                        let suffix = String(originalExtID.dropFirst(originalMainID.count))
                        resolvedAppExBundleID = profile.bundleIdentifier + suffix
                    } else {
                        let extName = originalExtID.components(separatedBy: ".").last
                            ?? appex.name.replacingOccurrences(of: " ", with: "")
                        resolvedAppExBundleID = "\(profile.bundleIdentifier).\(extName)"
                    }

                    // Lưu cả key gốc lẫn key đã thay bằng targetBundleIdentifier để ResignAppOperation luôn tra cứu trúng 100%
                    let updatedKeyInResign: String
                    if originalExtID.hasPrefix(originalMainID + ".") {
                        let suffix = String(originalExtID.dropFirst(originalMainID.count))
                        updatedKeyInResign = mainBundleKey + suffix
                    } else {
                        updatedKeyInResign = originalExtID.replacingOccurrences(of: originalMainID, with: mainBundleKey)
                    }

                    appexBundleIds[originalExtID] = resolvedAppExBundleID
                    appexBundleIds[updatedKeyInResign] = resolvedAppExBundleID
                }
                self.context.appexBundleIds = appexBundleIds
                debugLog("[PrepareAppExtensionBundleIDsOperation] Mapped \(appBundle.appExtensions.count) extensions to main profile '\(profile.bundleIdentifier)'")
            }
        }
        self.setProgress(100)
    }
}
