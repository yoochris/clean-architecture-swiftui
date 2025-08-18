//
//  PushNotificationsHandler.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 26.04.2020.
//  Copyright © 2020 Alexey Naumov. All rights reserved.
//

/**
 * PushNotificationsHandler - 推送通知处理
 * 
 * 功能介绍：
 * 统一处理APNs推送通知的展示、点击回调和自定义业务逻辑。
 * 通过实现 UNUserNotificationCenterDelegate，接收系统回调并转发到应用逻辑。
 * 
 * 小例子：
 * - 当App在前台收到通知，我们允许展示横幅/列表/声音提示
 * - 当用户点击通知，我们从payload中读出国家码，触发深度链接跳转到国家旗帜页面
 */

import UserNotifications

/// 空协议用于抽象通知处理（便于注入与测试）
protocol PushNotificationsHandler { }

/// 实现：将系统级通知回调转化为应用内的导航行为
final class RealPushNotificationsHandler: NSObject, PushNotificationsHandler {
    
    private let deepLinksHandler: DeepLinksHandler
    
    init(deepLinksHandler: DeepLinksHandler) {
        self.deepLinksHandler = deepLinksHandler
        super.init()
        // 注册自己为通知中心的代理，接收通知回调
        UNUserNotificationCenter.current().delegate = self
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension RealPushNotificationsHandler: UNUserNotificationCenterDelegate {
    
    /// 前台收到通知时的展示策略
    /// 这里选择：展示在通知列表、横幅，并播放声音
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler:
        @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.list, .banner, .sound])
    }
    
    /// 用户点击通知后的回调（包括横幅和列表点击）
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        handleNotification(userInfo: userInfo, completionHandler: completionHandler)
    }
    
    /// 解析通知payload并执行相应动作
    /// 约定：payload.aps.country 为国家alpha3Code（例如 "USA"）
    /// 若解析失败，则直接完成回调，不做跳转
    func handleNotification(userInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
        guard let payload = userInfo["aps"] as? [AnyHashable: Any],
            let countryCode = payload["country"] as? String else {
            completionHandler()
            return
        }
        // 将通知点击转换为深度链接导航
        Task { @MainActor in
            deepLinksHandler.open(deepLink: .showCountryFlag(alpha3Code: countryCode))
            completionHandler()
        }
    }
}
