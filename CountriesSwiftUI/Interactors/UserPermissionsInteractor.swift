//
//  UserPermissionsInteractor.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 26.04.2020.
//  Copyright © 2020 Alexey Naumov. All rights reserved.
//

import Foundation
import UserNotifications

/**
 * UserPermissionsInteractor - 用户权限用例（以推送权限为例）
 * 
 * 职责：
 * - 统一解析与请求系统权限（当前示例仅实现推送权限）
 * - 将系统层返回的状态映射为应用可用的简化状态（unknown/notRequested/granted/denied）
 * - 通过 AppState 对外暴露权限最新状态，便于 UI 响应展示
 * 
 * 两个核心操作：
 * - resolveStatus(for:): 仅查询当前权限状态，不弹系统框
 * - request(permission:): 请求权限（如已被拒绝，则引导打开系统设置）
 * 
 * 小例子：
 * - 应用进入前台时，解析推送权限：
 *   userPermissions.resolveStatus(for: .pushNotifications)
 *   → 读取 UNUserNotificationCenter.currentSettings().authorizationStatus
 *   → 映射为 Permission.Status 写入 AppState.permissions.push
 * 
 * - 首次请求推送权限：
 *   userPermissions.request(permission: .pushNotifications)
 *   → 调用 requestAuthorization(options: [.alert, .sound])
 *   → 根据是否授权将 AppState.permissions.push 置为 .granted / .denied
 */

enum Permission {
    case pushNotifications
}

extension Permission {
    enum Status: Equatable {
        case unknown
        case notRequested
        case granted
        case denied
    }
}

protocol UserPermissionsInteractor: AnyObject {
    /// 解析当前权限状态（不触发系统弹窗）
    func resolveStatus(for permission: Permission)
    /// 请求权限（可能触发系统弹窗；若已拒绝则引导用户去设置）
    func request(permission: Permission)
}

/// 为系统通知设置做一层抽象，便于单元测试替换
protocol SystemNotificationsSettings {
    var authorizationStatus: UNAuthorizationStatus { get }
}

/// 为通知中心做一层抽象，便于单元测试替换
protocol SystemNotificationsCenter {
    func currentSettings() async -> SystemNotificationsSettings
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNNotificationSettings: SystemNotificationsSettings { }
extension UNUserNotificationCenter: SystemNotificationsCenter {
    func currentSettings() async -> any SystemNotificationsSettings {
        return await notificationSettings()
    }
}

// MARK: - RealUserPermissionsInteractor

final class RealUserPermissionsInteractor: UserPermissionsInteractor {

    private let appState: Store<AppState>
    private let openAppSettings: () -> Void
    private let notificationCenter: SystemNotificationsCenter

    init(appState: Store<AppState>,
         notificationCenter: SystemNotificationsCenter = UNUserNotificationCenter.current(),
         openAppSettings: @escaping () -> Void
    ) {
        self.appState = appState
        self.notificationCenter = notificationCenter
        self.openAppSettings = openAppSettings
    }

    /// 查询权限状态：仅在 AppState 中为 .unknown 时才进行（避免重复开销）
    func resolveStatus(for permission: Permission) {
        let keyPath = AppState.permissionKeyPath(for: permission)
        let currentStatus = appState[keyPath]
        guard currentStatus == .unknown else { return }
        let appState = appState
        switch permission {
        case .pushNotifications:
            Task { @MainActor in
                appState[keyPath] = await pushNotificationsPermissionStatus()
            }
        }
    }

    /// 请求权限：若已被拒绝，直接引导用户前往系统设置修改
    func request(permission: Permission) {
        let keyPath = AppState.permissionKeyPath(for: permission)
        let currentStatus = appState[keyPath]
        guard currentStatus != .denied else {
            openAppSettings()
            return
        }
        switch permission {
        case .pushNotifications:
            Task {
                await requestPushNotificationsPermission()
            }
        }
    }
}

// MARK: - Push Notifications

extension UNAuthorizationStatus {
    /// 将系统层的授权状态映射至业务可用的 Permission.Status
    var map: Permission.Status {
        switch self {
        case .denied: return .denied
        case .authorized: return .granted
        case .notDetermined, .provisional, .ephemeral: return .notRequested
        @unknown default: return .notRequested
        }
    }
}

private extension RealUserPermissionsInteractor {

    /// 读取推送权限的当前系统状态并映射
    func pushNotificationsPermissionStatus() async -> Permission.Status {
        return await notificationCenter
            .currentSettings()
            .authorizationStatus.map
    }

    /// 发起推送权限请求，并同步更新 AppState.permissions.push
    func requestPushNotificationsPermission() async {
        let center = notificationCenter
        let isGranted = (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        appState[\.permissions.push] = isGranted ? .granted : .denied
    }
}

// MARK: -

/// 空实现（用于预览/测试或占位）
final class StubUserPermissionsInteractor: UserPermissionsInteractor {

    func resolveStatus(for permission: Permission) {
    }
    func request(permission: Permission) {
    }
}

