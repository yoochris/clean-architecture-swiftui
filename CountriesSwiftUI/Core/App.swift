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
                CountriesList()
                    // 应用根级外观（导航外观、颜色、状态栏等）
                    .modifier(RootViewAppearance())
                    // 注入 SwiftData 的 ModelContainer（数据库容器），供子视图使用 @Environment(\.modelContext)
                    .modelContainer(modelContainer)
                    // 监听并响应 Environment 变化（如本地化/字体尺寸），触发路由重置等
                    .attachEnvironmentOverrides(onChange: onChangeHandler)
                    // 注入自定义 DI 容器（交付 AppState、Interactors、Repositories）
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
        return { diff in
            if !diff.isDisjoint(with: [.locale, .sizeCategory]) {
                self.diContainer.appState[\.routing] = AppState.ViewRouting()
            }
        }
    }
}
