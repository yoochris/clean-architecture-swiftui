//
//  AppEnvironment.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//
//  本文件定义了 AppEnvironment（应用环境组装器）。
//  你可以把它看作“应用启动时的装配工厂”：
//  - 负责把网络会话、数据库容器、各类仓库（Web/DB）、交互器（Interactors）
//    以及系统事件处理器（SystemEventsHandler）按需创建并连接起来；
//  - 产出一个 DIContainer（依赖注入容器）和 ModelContainer（SwiftData 持久化容器），
//    让后续的视图层只需从环境中取用即可。
//
//  优点：
//  - 依赖集中创建与配置：避免在视图或业务代码中到处散落“如何构造依赖”的细节；
//  - 可替换、可测试：在测试环境可以替换为 Stub/Fake 的仓库或交互器；
//  - 清晰的启动流程：bootstrap() 清楚展示了 App 启动时的每一步。
//
//  举例说明：
//  - 当 App 启动时，bootstrap() 会先创建 URLSession（带超时、缓存策略等配置），
//    再用它创建网络仓库（如 RealCountriesWebRepository）；
//  - 接着创建 SwiftData 的 ModelContainer，并据此构造 DB 仓库（MainDBRepository）；
//  - 再将 Web/DB 仓库交给各个 Interactor（如 RealCountriesInteractor、RealImagesInteractor），
//    由它们对外提供“业务动作”（例如刷新国家列表、加载图片、请求权限）；
//  - 最后把这些依赖塞进 DIContainer，并创建 DeepLinks 和 PushNotifications 的处理器，
//    汇总到 SystemEventsHandler 中，完成应用级系统事件的统一接入。
//
//  使用方式（示意）：
//  @main
//  struct CountriesApp: App {
//      @State private var environment = AppEnvironment.bootstrap()
//      var body: some Scene {
//          WindowGroup {
//              RootView()
//                  .modelContainer(environment.modelContainer) // 注入 SwiftData 持久化容器
//                  .inject(environment.diContainer)            // 注入依赖容器
//          }
//      }
//  }
//
//  如此，界面中的任意 View 都能通过 @Environment(\.injected) 获取 DIContainer，
//  通过它访问 appState 或 interactors，发起业务动作。

import UIKit
import SwiftData

@MainActor
struct AppEnvironment {
    let isRunningTests: Bool
    let diContainer: DIContainer
    let modelContainer: ModelContainer
    let systemEventsHandler: SystemEventsHandler
}

extension AppEnvironment {

    static func bootstrap() -> AppEnvironment {
        let appState = Store<AppState>(AppState())
        /*
         To see the deep linking in action:

         1. Launch the app in iOS 13.4 simulator (or newer)
         2. Subscribe on Push Notifications with "Allow Push" button
         3. Minimize the app
         4. Drag & drop "push_with_deeplink.apns" into the Simulator window
         5. Tap on the push notification

         Alternatively, just copy the code below before the "return" and launch:

            DispatchQueue.main.async {
                deepLinksHandler.open(deepLink: .showCountryFlag(alpha3Code: "AFG"))
            }
        */
        // 1) 配置网络会话（影响请求超时、缓存、并发连接数等）
        let session = configuredURLSession()
        // 2) 基于会话构建 Web 仓库（网络层）
        let webRepositories = configuredWebRepositories(session: session)
        // 3) 创建 SwiftData 的持久化容器
        let modelContainer = configuredModelContainer()
        // 4) 基于持久化容器构建 DB 仓库（本地数据库层）
        let dbRepositories = configuredDBRepositories(modelContainer: modelContainer)
        // 5) 把 Web/DB 仓库交给各 Interactor，形成业务能力的对外入口
        let interactors = configuredInteractors(appState: appState, webRepositories: webRepositories, dbRepositories: dbRepositories)
        // 6) 组合 DI 容器
        let diContainer = DIContainer(appState: appState, interactors: interactors)
        // 7) 系统事件的处理器（深链、推送）
        let deepLinksHandler = RealDeepLinksHandler(container: diContainer)
        let pushNotificationsHandler = RealPushNotificationsHandler(deepLinksHandler: deepLinksHandler)
        // 8) 聚合到统一的系统事件入口
        let systemEventsHandler = RealSystemEventsHandler(
            container: diContainer,
            deepLinksHandler: deepLinksHandler,
            pushNotificationsHandler: pushNotificationsHandler,
            pushTokenWebRepository: webRepositories.pushToken)
        // 9) 返回汇总后的应用环境
        return AppEnvironment(
            isRunningTests: ProcessInfo.processInfo.isRunningTests,
            diContainer: diContainer,
            modelContainer: modelContainer,
            systemEventsHandler: systemEventsHandler)
    }

    // 创建并配置 URLSession。这里设置了请求/资源超时、连接数、缓存等参数。
    private static func configuredURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 5
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = .shared
        return URLSession(configuration: configuration)
    }

    // 基于会话构建 Web 仓库（网络 API 访问层）。
    private static func configuredWebRepositories(session: URLSession) -> DIContainer.WebRepositories {
        let images = RealImagesWebRepository(session: session)
        let countries = RealCountriesWebRepository(session: session)
        let pushToken = RealPushTokenWebRepository(session: session)
        return .init(images: images,
                     countries: countries,
                     pushToken: pushToken)
    }

    // 基于 SwiftData 的 ModelContainer 构建 DB 仓库（本地持久化层）。
    private static func configuredDBRepositories(modelContainer: ModelContainer) -> DIContainer.DBRepositories {
        let mainDBRepository = MainDBRepository(modelContainer: modelContainer)
        return .init(countries: mainDBRepository)
    }

    // 创建 SwiftData 的 ModelContainer。失败时回退到 stub，以免应用崩溃。
    private static func configuredModelContainer() -> ModelContainer {
        do {
            return try ModelContainer.appModelContainer()
        } catch {
            // Log the error
            return ModelContainer.stub
        }
    }

    // 将 Web/DB 仓库与 AppState 装配为具体的业务交互器。
    private static func configuredInteractors(
        appState: Store<AppState>,
        webRepositories: DIContainer.WebRepositories,
        dbRepositories: DIContainer.DBRepositories
    ) -> DIContainer.Interactors {
        let images = RealImagesInteractor(webRepository: webRepositories.images)
        let countries = RealCountriesInteractor(
            webRepository: webRepositories.countries,
            dbRepository: dbRepositories.countries)
        // 打开系统设置的闭包通过 UIApplication 提供，便于在测试中注入其他实现
        let userPermissions = RealUserPermissionsInteractor(
            appState: appState, openAppSettings: {
                URL(string: UIApplication.openSettingsURLString).flatMap {
                    UIApplication.shared.open($0, options: [:], completionHandler: nil)
                }
            })
        return .init(images: images,
                     countries: countries,
                     userPermissions: userPermissions)
    }
}
