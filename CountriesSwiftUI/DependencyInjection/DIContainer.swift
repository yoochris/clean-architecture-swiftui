//
//  DIContainer.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//
//  本文件定义了 DIContainer（依赖注入容器）。
//  你可以把它理解为“应用的工具箱”，里面集中放好了：
//  - 全局的应用状态 Store<AppState>
//  - 业务交互器 Interactors（如国家列表、图片加载、权限请求）
//
//  为什么需要它？
//  - 统一管理依赖：所有视图只需要从环境中取出 DIContainer，就能拿到需要的工具（例如某个 interactor）。
//  - 方便测试与替换：在单元测试或预览中，我们可以传入 Stub/Fake 的依赖，而不动业务代码。
//
//  小例子：
//  假如 CountriesListView 需要触发“加载国家列表”的行为，它可以通过环境拿到 container.interactors.countries，
//  调用相应方法即可，而不需要自己去 new WebRepository 或创建网络层。
//
//  使用方式（示意）：
//  struct SomeView: View {
//      @Environment(\.injected) private var container
//      var body: some View {
//          Button("刷新国家数据") {
//              // 通过依赖注入获取交互器来执行操作
//              container.interactors.countries.refresh()
//          }
//      }
//  }
//
//  上面例子中，视图并不知道“如何获取数据”，只知道“向谁发请求”（interactor）。
//  这让视图变得更轻、可测试性更好（可以把 interactor 换成 Stub）。

import SwiftUI
import SwiftData

struct DIContainer {

    // 全局应用状态（单一事实来源）
    let appState: Store<AppState>
    // 业务交互器集合
    let interactors: Interactors

    // 提供带默认 appState 的构造器，方便在多数场景直接使用
    init(appState: Store<AppState> = .init(AppState()), interactors: Interactors) {
        self.appState = appState
        self.interactors = interactors
    }

    // 便捷构造器：允许传入“值类型”的 AppState，再内部包成 Store<AppState>
    init(appState: AppState, interactors: Interactors) {
        self.init(appState: Store<AppState>(appState), interactors: interactors)
    }
}

extension DIContainer {
    // Web 仓库集合：负责与网络 API 通讯
    struct WebRepositories {
        let images: ImagesWebRepository
        let countries: CountriesWebRepository
        let pushToken: PushTokenWebRepository
    }
    // 数据库仓库集合：负责与本地持久化交互（SwiftData）
    struct DBRepositories {
        let countries: CountriesDBRepository
    }
    // 交互器集合：对上游（UI）提供业务能力，对下游使用仓库/系统 API
    struct Interactors {
        let images: ImagesInteractor
        let countries: CountriesInteractor
        let userPermissions: UserPermissionsInteractor

        // stub：方便在 SwiftUI 预览、单元测试中注入假的实现，避免真实网络/数据库依赖
        static var stub: Self {
            .init(images: StubImagesInteractor(),
                  countries: StubCountriesInteractor(),
                  userPermissions: StubUserPermissionsInteractor())
        }
    }
}

extension EnvironmentValues {
    // 将 DIContainer 暴露到 SwiftUI 环境，视图可通过 @Environment(\.injected) 获取
    // 这里提供一个默认值，使用真实 AppState + stub 交互器，方便在预览中运行
    @Entry var injected: DIContainer = DIContainer(appState: AppState(), interactors: .stub)
}

extension View {
    // 语义化的便捷方法：把 DIContainer 注入到视图环境中
    // 例子：RootView().inject(container)
    func inject(_ container: DIContainer) -> some View {
        return self
            .environment(\.injected, container)
    }
}
