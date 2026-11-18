//
//  DeviceRegistrationFlow.swift
//  SideStore
//
//  Created by SideStore Team on 5/9/24.
//

import UIKit
import Foundation
import AltSign
import Minimuxer
import OSLog

final class DeviceRegistrationFlow: Operation {
    let context: AuthenticatedOperationContext
    
    init(context: AuthenticatedOperationContext) {
        self.context = context
    }
    
    func run() async throws -> InstalledDevice {
        // verify Context sanity
        guard
            let team = self.context.team,
            let session = self.context.session
        else {
            throw OperationError.invalidParameters("DeviceRegistrationFlow.main: Context expected team and session to be non-nil, found nil instead")
        }

        // Lấy UDID thông qua cơ chế 6 lớp dự phòng đồng nhất của CellularRefreshManager
        let deviceUDID = try await fetchDeviceUDID()
        let devices = try await AppleAPIService.shared.fetchDevices(for: team, types: .all, session: session)
        let currentDevice = devices.first { $0.identifier == deviceUDID }
        
        let registeredDevice: ALTDevice
        if let currentDevice {                                          // device was already registered, nothing more to do
            registeredDevice = currentDevice
        } else {
            let deviceName = try await fetchDeviceName()                // device not registered -> register this device with apple directly
            let deviceType = await fetchDeviceType()
            
            registeredDevice = try await AppleAPIService.shared.registerDevice(
                name: deviceName,
                identifier: deviceUDID,
                type: deviceType,
                team: team,
                session: session
            )
        }
        return InstalledDevice(
            name: registeredDevice.name,
            type: registeredDevice.type,
            udid: registeredDevice.identifier
        )
    }

    /// Lấy UDID thiết bị qua hệ thống 6 lớp dự phòng của CellularRefreshManager
    private func fetchDeviceUDID() async throws -> String {
        return try await CellularRefreshManager.shared.resolveDeviceUDID()
    }
    
    private func fetchDeviceName() async throws -> String {
        // Nếu đang dùng 4G và chưa tắt 4G, ưu tiên lấy tên thiết bị từ hệ thống iOS để tránh lỗi gọi Minimuxer
        if CellularRefreshManager.shared.isCellularMode && !CellularRefreshManager.shared.hasTurnedOffData {
            return await UIDevice.current.name
        }

        do {
            return try Minimuxer.fetchDeviceName()
        } catch {
            // Fallback an toàn: Sử dụng tên thiết bị từ UIDevice nếu Minimuxer không phản hồi
            return await UIDevice.current.name
        }
    }
    
    private func fetchDeviceType() async -> ALTDeviceType {
        let idiom = await UIDevice.current.userInterfaceIdiom
        switch idiom {
        case .phone:
            return .iPhone
        case .pad:
            return .iPad
        default:
            return .none
        }
    }
}
