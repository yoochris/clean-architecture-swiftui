//
//  SystemEventsHandler.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 27.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

/**
 * SystemEventsHandler - 系统事件统一处理入口
 * 
 * 功能介绍：
 * 将分散在App生命周期、Scene回调、通知中心等处的系统事件，集中到单一处理器中，
 * 统一转换为对AppState和业务交互器（Interactors）的改变。
 * 
 * 好处：
 * - 单一入口：所有系统事件一处管控，逻辑清晰
 * - 解耦：UI、AppDelegate/SceneDelegate只负责转发，不关心具体业务
 * - 易测试：可以通过注入容器和模拟依赖，分别测试不同系统事件的处理
 * 
 * 小例子：
 * - 当键盘显示/隐藏 → 发布键盘高度 → 更新 AppState.system.keyboardHeight
 * - 当应用激活 → 标记 isActive = true，并检查推送权限状态
 * - 当收到URL（深链） → 解析后调用 DeepLinksHandler 执行导航
 */

import UIKit
import Combine

@MainActor
protocol SystemEventsHandler {
    /// 处理场景打开URL（支持深度链接）
    func sceneOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>)
    /// 场景变为激活状态（前台）
    func sceneDidBecomeActive()
    /// 场景即将失活（进入后台/被打断）
    func sceneWillResignActive()
    /// 推送注册结果（成功返回deviceToken/失败返回error）
    func handlePushRegistration(result: Result<Data, Error>)
    /// 后台收到推送（带取数能力）的回调
    @MainActor
    func appDidReceiveRemoteNotification(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult
}

/// 真实实现：将系统事件映射为对AppState与业务层的操作
struct RealSystemEventsHandler: SystemEventsHandler {

    let container: DIContainer
    let deepLinksHandler: DeepLinksHandler
    let pushNotificationsHandler: PushNotificationsHandler
    let pushTokenWebRepository: PushTokenWebRepository
    private let cancelBag = CancelBag()

    init(container: DIContainer,
         deepLinksHandler: DeepLinksHandler,
         pushNotificationsHandler: PushNotificationsHandler,
         pushTokenWebRepository: PushTokenWebRepository) {

        self.container = container
        self.deepLinksHandler = deepLinksHandler
        self.pushNotificationsHandler = pushNotificationsHandler
        self.pushTokenWebRepository = pushTokenWebRepository

        // 安装公共事件监听
        installKeyboardHeightObserver()
        installPushNotificationsSubscriberOnLaunch()
    }

    // MARK: - 键盘高度监听

    /// 监听键盘显示/隐藏，更新AppState.system.keyboardHeight
    private func installKeyboardHeightObserver() {
        let appState = container.appState
        NotificationCenter.default.keyboardHeightPublisher
            .sink { [appState] height in
                appState[\.system.keyboardHeight] = height
            }
            .store(in: cancelBag)
    }

    // MARK: - 推送权限订阅

    /// 在启动时订阅推送权限状态，一旦变为已知（非unknown），若为granted则请求设备token
    private func installPushNotificationsSubscriberOnLaunch() {
        weak var permissions = container.interactors.userPermissions
        container.appState
            .updates(for: AppState.permissionKeyPath(for: .pushNotifications))
            .first(where: { $0 != .unknown })
            .sink { status in
                if status == .granted {
                    // 如果上次启动时已经授权，则再次请求推送token（以便上报给服务端）
                    permissions?.request(permission: .pushNotifications)
                }
            }
            .store(in: cancelBag)
    }

    // MARK: - URL/深度链接

    func sceneOpenURLContexts(_ urlContexts: Set<UIOpenURLContext>) {
        guard let url = urlContexts.first?.url else { return }
        handle(url: url)
    }

    /// 将外部URL转换为内部DeepLink并执行
    private func handle(url: URL) {
        guard let deepLink = DeepLink(url: url) else { return }
        deepLinksHandler.open(deepLink: deepLink)
    }

    // MARK: - 场景生命周期

    /// 场景激活：更新App活跃状态，并触发权限状态解析
    func sceneDidBecomeActive() {
        container.appState[\.system.isActive] = true
        container.interactors.userPermissions.resolveStatus(for: .pushNotifications)
    }

    /// 场景将要失活：更新App活跃状态
    func sceneWillResignActive() {
        container.appState[\.system.isActive] = false
    }

    // MARK: - 推送注册/后台取数

    /// 推送注册回调（此处留空，实际项目可在此将token上报给服务端）
    func handlePushRegistration(result: Result<Data, Error>) {

    }

    /// 后台收到推送的回调（根据payload决定是否拉取数据）
    func appDidReceiveRemoteNotification(payload: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        return .noData
    }
}

// MARK: - Notifications

private extension NotificationCenter {
    /// 键盘高度的Combine发布者：
    /// - willShow: 提取最终键盘高度
    /// - willHide: 高度置零
    var keyboardHeightPublisher: AnyPublisher<CGFloat, Never> {
        let willShow = publisher(for: UIApplication.keyboardWillShowNotification)
            .map { $0.keyboardHeight }
        let willHide = publisher(for: UIApplication.keyboardWillHideNotification)
            .map { _ in CGFloat(0) }
        return Publishers.Merge(willShow, willHide)
            .eraseToAnyPublisher()
    }
}

private extension Notification {
    /// 从通知userInfo中读取键盘最终frame的高度
    var keyboardHeight: CGFloat {
        return (userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?
            .cgRectValue.height ?? 0
    }
}
