//
//  DeepLinksHandler.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 26.04.2020.
//  Copyright © 2020 Alexey Naumov. All rights reserved.
//

/**
 * DeepLinksHandler - 深度链接处理
 * 
 * 功能介绍：
 * 深度链接（Deep Link）允许外部来源（如邮件、推送、网页）直接打开App内的特定页面。
 * 本文件负责：
 * 1) 定义支持的深度链接类型 DeepLink
 * 2) 从URL解析出深度链接
 * 3) 根据深度链接，更新App的路由状态，完成导航
 * 
 * 小例子：
 * 用户点击链接：https://www.example.com?alpha3code=USA
 * → 解析出 DeepLink.showCountryFlag(alpha3Code: "USA")
 * → 更新AppState.routing，使国家详情弹窗自动展示国旗
 */

import Foundation

/// 支持的深度链接类型（可扩展）
enum DeepLink: Equatable {
    
    /// 展示某个国家的国旗（根据国家alpha3Code，如USA、CHN）
    case showCountryFlag(alpha3Code: String)

    /// 从URL尝试解析出DeepLink
    /// 约定：host必须为 www.example.com，参数 alpha3code 表示国家代码
    init?(url: URL) {
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            components.host == "www.example.com",
            let query = components.queryItems
            else { return nil }
        if let item = query.first(where: { $0.name == "alpha3code" }),
            let alpha3Code = item.value {
            self = .showCountryFlag(alpha3Code: alpha3Code)
            return
        }
        return nil
    }
}

// MARK: - DeepLinksHandler

/// 处理深度链接的协议
@MainActor
protocol DeepLinksHandler {
    /// 根据DeepLink在应用内执行对应的导航动作
    func open(deepLink: DeepLink)
}

/// 实现：根据DeepLink更新AppState，从而驱动SwiftUI导航
struct RealDeepLinksHandler: DeepLinksHandler {
    
    private let container: DIContainer
    
    init(container: DIContainer) {
        self.container = container
    }
    
    func open(deepLink: DeepLink) {
        switch deepLink {
        case let .showCountryFlag(alpha3Code):
            // 目标导航动作：设置列表路由中的国家代码，并展示详情弹窗
            let routeToDestination = {
                self.container.appState.bulkUpdate {
                    $0.routing.countriesList.countryCode = alpha3Code
                    $0.routing.countryDetails.detailsSheet = true
                }
            }
            /*
             关于两步导航的原因：
             SwiftUI在处理复杂导航（同时关闭旧界面并打开新界面）时可能出现问题。
             解决办法：先回到默认路由，再异步导航到目标，保证UI状态一致。
             */
            let defaultRouting = AppState.ViewRouting()
            if container.appState.value.routing != defaultRouting {
                // 第一步：重置到默认路由
                self.container.appState[\.routing] = defaultRouting
                // 根据是否在测试环境，决定是否添加可见的动画延迟
                let delay: DispatchTime = .now() + (ProcessInfo.processInfo.isRunningTests ? 0 : 1.5)
                DispatchQueue.main.asyncAfter(deadline: delay, execute: routeToDestination)
            } else {
                // 已经是默认路由，直接执行导航
                routeToDestination()
            }
        }
    }
}
