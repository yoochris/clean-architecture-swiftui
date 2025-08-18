//
//  AppDelegate.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 23.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

/**
 * AppDelegate.swift - 应用代理
 * 
 * 功能介绍：
 * AppDelegate 是 iOS 应用的"总管家"，负责处理应用级别的生命周期事件
 * 主要职责包括：
 * 1. 应用启动配置
 * 2. 场景(Scene)生命周期管理
 * 3. 推送通知注册和接收
 * 4. 系统事件分发
 * 
 * 核心概念：
 * - UIApplicationDelegate: iOS系统与App通信的桥梁
 * - UIWindowSceneDelegate: 管理窗口场景的生命周期（iOS 13+新特性）
 * - 系统事件分发: 将系统级事件转发给应用内的处理器
 * 
 * 实际应用场景举例：
 * 1. 用户点击推送通知 → AppDelegate接收 → 转发给SystemEventsHandler处理
 * 2. 用户通过URL scheme打开应用 → SceneDelegate接收 → 转发给深度链接处理器
 * 3. 应用进入后台/前台 → SceneDelegate监听 → 更新应用状态
 */

import UIKit
import SwiftUI
import Combine
import Foundation

@MainActor
final class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - 依赖管理
    
    /**
     * 应用环境实例（懒加载）
     * 使用懒加载模式，确保在第一次访问时才初始化整个依赖图
     * 
     * 举例：就像一个工厂，只有在真正需要生产产品时才开始运转
     */
    private lazy var environment = AppEnvironment.bootstrap()
    
    /**
     * 系统事件处理器的便捷访问器
     * 通过计算属性提供对系统事件处理器的快速访问
     * 
     * 举例：就像酒店的总台，所有客人的请求都通过这里转发给对应部门
     */
    private var systemEventsHandler: SystemEventsHandler { environment.systemEventsHandler }

    /**
     * 根视图
     * 提供SwiftUI应用的根视图，供SceneDelegate使用
     * 
     * 举例：这是应用的"主页面"，所有其他页面都从这里开始
     */
    var rootView: some View {
        environment.rootView
    }

    // MARK: - 应用生命周期方法
    
    /**
     * 应用启动完成回调
     * 当应用完成启动准备时，iOS系统会调用此方法
     * 
     * 参数说明：
     * - application: 应用实例
     * - launchOptions: 启动选项（比如是否通过推送通知启动）
     * 
     * 返回值：true表示应用成功处理了启动
     * 
     * 举例：就像开店时的准备工作，检查所有设备是否正常，员工是否到位
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }

    /**
     * 场景配置方法
     * iOS 13+引入了Scene概念，一个应用可以有多个窗口/场景
     * 此方法负责为新创建的场景提供配置信息
     * 
     * 参数说明：
     * - connectingSceneSession: 正在连接的场景会话
     * - options: 连接选项
     * 
     * 工作流程：
     * 1. 创建场景配置
     * 2. 指定SceneDelegate作为场景代理
     * 3. 注册系统事件处理器
     * 
     * 举例：就像为新开的分店配置管理制度和负责人
     */
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config: UISceneConfiguration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        SceneDelegate.register(systemEventsHandler)
        return config
    }

    // MARK: - 推送通知处理
    
    /**
     * 推送通知注册成功回调
     * 当应用成功向APNs注册推送通知后，系统会调用此方法
     * 
     * 参数说明：
     * - deviceToken: 设备令牌，用于向特定设备发送推送
     * 
     * 处理流程：
     * 将成功结果传递给系统事件处理器进行后续处理
     * 
     * 举例：就像获得了快递配送许可证，现在可以接收包裹了
     */
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        systemEventsHandler.handlePushRegistration(result: .success(deviceToken))
    }

    /**
     * 推送通知注册失败回调
     * 当应用向APNs注册推送通知失败时，系统会调用此方法
     * 
     * 参数说明：
     * - error: 注册失败的错误信息
     * 
     * 处理流程：
     * 将失败结果传递给系统事件处理器进行错误处理
     * 
     * 举例：就像申请快递配送许可证被拒绝，需要记录原因并决定下一步行动
     */
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        systemEventsHandler.handlePushRegistration(result: .failure(error))
    }

    /**
     * 后台推送通知接收回调
     * 当应用在后台运行时收到推送通知，系统会调用此方法
     * 
     * 参数说明：
     * - userInfo: 推送通知的载荷数据
     * 
     * 返回值：UIBackgroundFetchResult枚举
     * - .newData: 获取到新数据
     * - .noData: 没有新数据
     * - .failed: 处理失败
     * 
     * 异步处理：使用async/await模式处理异步操作
     * 
     * 举例：就像店铺关门后收到紧急订单，需要决定是否处理以及如何处理
     */
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        return await systemEventsHandler
            .appDidReceiveRemoteNotification(payload: userInfo)
    }
}

// MARK: - SceneDelegate

/**
 * SceneDelegate - 场景代理
 * 
 * 功能介绍：
 * iOS 13引入了多场景支持，一个应用可以有多个窗口
 * SceneDelegate负责管理单个场景的生命周期
 * 
 * 主要职责：
 * 1. 场景生命周期管理（激活/失活）
 * 2. URL方案处理（深度链接）
 * 3. 与系统事件处理器协调
 * 
 * 设计模式：
 * - 静态注册模式：通过类方法注册事件处理器
 * - 代理模式：实现UIWindowSceneDelegate协议
 * 
 * 举例：就像每个分店都有自己的店长，负责该店的日常运营
 */
@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate, ObservableObject {

    // MARK: - 静态事件处理器管理
    
    /**
     * 静态系统事件处理器实例
     * 使用静态变量存储，确保在场景创建前就能访问
     * 
     * 为什么用静态？
     * 因为SceneDelegate是由系统创建的，我们无法通过构造函数传递依赖
     */
    private static var systemEventsHandler: SystemEventsHandler?
    
    /**
     * 实例级事件处理器访问器
     * 通过计算属性访问静态实例
     */
    private var systemEventsHandler: SystemEventsHandler? { Self.systemEventsHandler }

    /**
     * 注册系统事件处理器
     * 由AppDelegate在配置场景时调用
     * 
     * 参数说明：
     * - systemEventsHandler: 要注册的事件处理器实例
     * 
     * 举例：就像给新店长配发对讲机，以便与总部通信
     */
    static func register(_ systemEventsHandler: SystemEventsHandler?) {
        Self.systemEventsHandler = systemEventsHandler
    }

    // MARK: - URL处理（深度链接）
    
    /**
     * URL方案处理方法
     * 当用户通过URL方案打开应用时（如自定义scheme或Universal Links），此方法被调用
     * 
     * 参数说明：
     * - scene: 当前场景实例
     * - URLContexts: URL上下文集合，包含要处理的URL信息
     * 
     * 处理流程：
     * 提取第一个URL并转发给系统事件处理器
     * 
     * 举例场景：
     * 用户点击邮件中的链接："myapp://country?alpha3code=USA"
     * → SceneDelegate接收 → 转发给SystemEventsHandler → 处理深度链接导航
     */
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        systemEventsHandler?.sceneOpenURLContexts(URLContexts)
    }

    // MARK: - 场景生命周期管理
    
    /**
     * 场景激活回调
     * 当场景从非激活状态变为激活状态时调用
     * 
     * 激活时机：
     * - 应用启动后首次显示
     * - 从后台切换到前台
     * - 从其他应用切换回来
     * 
     * 处理内容：
     * 通知系统事件处理器更新应用状态和权限检查
     * 
     * 举例：就像店铺开门营业，需要打开灯光、检查设备、准备接客
     */
    func sceneDidBecomeActive(_ scene: UIScene) {
        systemEventsHandler?.sceneDidBecomeActive()
    }

    /**
     * 场景即将失活回调
     * 当场景即将从激活状态变为非激活状态时调用
     * 
     * 失活时机：
     * - 应用进入后台
     * - 切换到其他应用
     * - 接收电话等系统中断
     * 
     * 处理内容：
     * 通知系统事件处理器更新应用状态，可能暂停某些操作
     * 
     * 举例：就像店铺临时关门，需要关灯、锁门、暂停营业活动
     */
    func sceneWillResignActive(_ scene: UIScene) {
        systemEventsHandler?.sceneWillResignActive()
    }
}
