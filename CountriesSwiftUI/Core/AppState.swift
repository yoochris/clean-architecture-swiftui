//
//  AppState.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 23.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

/**
 * AppState - 应用全局状态容器
 * 
 * 这是一份集中管理应用数据的“单一真相源”（Single Source of Truth）。
 * SwiftUI视图层通过观察/订阅AppState的变化来自动刷新UI。
 * 
 * 为什么需要AppState？
 * - 统一管理：将“路由状态、系统状态、权限状态”聚合到一起，便于维护
 * - 可测试性：通过构造不同的AppState，轻松编写UI和业务的单元测试
 * - 可观测：结合Store和Combine，视图可以精确订阅自己关心的字段
 * 
 * 小例子：
 * - 当键盘出现时，我们只更新 AppState.system.keyboardHeight → 依赖该字段的视图自动上移
 * - 当需要展示国家详情弹窗时，设置 AppState.routing.countryDetails.detailsSheet = true → UI自动弹出
 */

import SwiftUI
import Combine

/// AppState由三个子状态组成：路由、系统、权限。
struct AppState: Equatable {
    /// 路由相关的UI状态（决定显示哪个界面/弹窗/选中项等）
    var routing = ViewRouting()
    /// 系统级状态（是否活跃、键盘高度等）
    var system = System()
    /// 权限相关状态（推送、相册、定位等，这里仅示例推送）
    var permissions = Permissions()
}

extension AppState {
    /// 路由状态：用来描述界面导航与显示逻辑
    struct ViewRouting: Equatable {
        /// 国家列表页面的路由状态（例如选择了哪个国家）
        var countriesList = CountriesList.Routing()
        /// 国家详情页面的路由状态（例如是否显示详情弹窗）
        var countryDetails = CountryDetails.Routing()
    }
}

extension AppState {
    /// 系统状态：用于保存与系统交互相关的信息
    struct System: Equatable {
        /// 应用是否处于前台活跃状态
        var isActive: Bool = false
        /// 当前键盘高度（配合Safe Area或滚动视图调整布局）
        var keyboardHeight: CGFloat = 0
    }
}

extension AppState {
    /// 权限状态：描述App对系统权限的申请与当前状态
    struct Permissions: Equatable {
        /// 推送通知权限状态（unknown/granted/denied）
        var push: Permission.Status = .unknown
    }

    /// 根据权限类型返回对应的可写KeyPath，便于统一订阅/更新
    ///
    /// 小例子：
    /// let path = AppState.permissionKeyPath(for: .pushNotifications)
    /// store[path] = .granted // 更新推送权限状态
    static func permissionKeyPath(for permission: Permission) -> WritableKeyPath<AppState, Permission.Status> {
        let pathToPermissions = \AppState.permissions
        switch permission {
        case .pushNotifications:
            return pathToPermissions.appending(path: \.push)
        }
    }
}

/// AppState等值比较：当三个子状态都相等时，两个AppState相等。
/// SwiftUI中只要AppState发生变化（且被订阅），依赖它的视图就会刷新。
func == (lhs: AppState, rhs: AppState) -> Bool {
    return lhs.routing == rhs.routing
        && lhs.system == rhs.system
        && lhs.permissions == rhs.permissions
}
