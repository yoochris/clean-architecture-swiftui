//
//  CountriesApp.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftUI
import EnvironmentOverrides // 依赖：用于动态注入/覆盖环境变量，监听环境变化（如本地化、字体大小）

/// 应用入口。SwiftUI 应用的主结构体，配置根窗口和根视图。
@main
struct MainApp: App {
    
    /// 将 UIKit 风格的 AppDelegate 接入 SwiftUI 生命周期，处理通知、深链等系统事件。
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            /// 通过 AppEnvironment 组装好的根视图（包含依赖注入、外观、数据库容器等）
            appDelegate.rootView
        }
    }
}

extension AppEnvironment {
    /// 根视图构建：在测试与非测试环境下展示不同内容，并完成依赖注入/样式/SwiftData 容器绑定。
    var rootView: some View {
        VStack {
            // 单元测试运行时只显示占位文本，避免真实副作用（网络/数据库等）
            if isRunningTests {
                Text("Running unit tests")
            } else {
                // 如果是多个模块，则最好就是在最高层级的业务视图上配置一次
                // MainAppView()  // 你的主视图
                //     .modifier(RootViewAppearance())
                //     .modelContainer(modelContainer) 
                //     .inject(diContainer)
                // 这种设计利用了 SwiftUI 的 Environment 系统，在根视图配置一次，所有子视图都能自动获得这些能力，既简洁又高效！

                // 在 SwiftUI 中， 修饰符会向下传递给所有子视图 。由于 CountriesList 是这个应用的根视图，所以加在它上面等同于全局配置。
                CountriesList()
                
                    // 作用于整个视图树： 应用根级外观（导航外观、颜色、状态栏等）
                    .modifier(RootViewAppearance())

                    // 数据容器向下传递： 注入 SwiftData 的 ModelContainer（数据库容器），供子视图使用 @Environment(\.modelContext)
                    .modelContainer(modelContainer)

                    // 监听并响应 Environment 变化（如本地化/字体尺寸），触发路由重置等
                    .attachEnvironmentOverrides(onChange: onChangeHandler)

                    // 依赖注入向下传递： 注入自定义 DI 容器（交付 AppState、Interactors、Repositories）
                   
                    // DI 是 Dependency Injection（依赖注入）的缩写
                    // 在 DIContainer 里给 SwiftUI 的 Environment 定义了一个键 injected，
                    // 并提供了 View 的便捷方法 inject(_:)。当你在根视图上写 .inject(diContainer) 时，
                    // 它会把这个容器放进 Environment，后续整棵视图树都能用 @Environment(.injected) 取出来用，
                    // 这就是“依赖向下传递”。

                    // 为什么不直接把“更底层”的依赖往下传？
                    // - 比如 URLSession、WebRepository、DBRepository、PushHandlers 等“实现细节”，
                    // 不直接传给 UI，而是藏在 Interactor 层，让 UI 只面向“业务动作”的抽象。
                    // 这能让 UI 更干净、分层更清晰、测试更容易。这些底层依赖在应用启动时通过 AppEnvironment 组装好，
                    // 再交给 Interactors 使用即可。
                    .inject(diContainer)
                    
                // 当本地数据库容器退化为 stub（构建失败或不可用）时给出提示
                if modelContainer.isStub {
                    Text("⚠️ There is an issue with local1 database")
                        .font(.caption2)
                }
            }
        }
    }

    /// 当用户改变语言或字体大小等环境时，重置视图路由，避免已失效路径导致导航异常。
    private var onChangeHandler: (EnvironmentValues.Diff) -> Void {
        // diff 是一个“环境差异集合”，告诉你这次有哪些 Environment 值变了（比如 .locale 语言、.sizeCategory 字体尺寸等）。
        return { diff in
            // “这次变化里，是否包含语言或字体大小中的任意一个？”（isDisjoint 表示是否‘没有交集’，前面加了 ! 就变成“有交集”）。
            if !diff.isDisjoint(with: [.locale, .sizeCategory]) {
                // 如果包含，就把路由状态重置：self.diContainer.appState[.routing] = AppState.ViewRouting()。这等同于“清空/回到初始导航状态”，让界面以新的语言或字体大小从根部重新渲染构建。
                self.diContainer.appState[\.routing] = AppState.ViewRouting()
            }
        }
    }

    // 举 2 个生活化例子

    // - 例子1：切换系统语言（.locale）
    //   1. 你正打开“国家详情页”。
    //   2. 去系统设置把语言从英文切到中文。
    //   3. App 收到 diff，发现 .locale 变了，于是把路由还原到初始值（如回到“国家列表”）。
    //   4. 整个界面用中文环境重建：导航栏标题、按钮文案、列表内容都统一显示中文，避免出现一半英文一半中文的“半刷新”状态。
    
    // - 例子2：调大系统字体（.sizeCategory）
    //   1. 你在一个包含很多文字的详情页。
    //   2. 调整系统字体为“特大”。
    //   3. App 收到 diff，发现 .sizeCategory 变了，重置路由。
    //   4. 返回到列表并重建界面，所有文字用新字号重新布局，避免在深层页面出现布局挤压、截断、导航栈与布局不同步等问题。
}
