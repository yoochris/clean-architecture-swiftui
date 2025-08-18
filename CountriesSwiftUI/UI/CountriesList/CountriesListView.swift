//
//  CountriesList.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftUI
import SwiftData
import Combine

/// CountriesList 是应用首页的“国家列表”视图，负责：
/// 1) 展示与搜索本地 SwiftData 中的国家；
/// 2) 导航至国家详情（含深链/通知路由跳转）；
/// 3) 触发副作用（网络刷新、推送权限请求等）。
struct CountriesList: View {

    // 用于驱动列表显示的国家数组（从 SwiftData 查询结果映射而来）
    @State private var countries: [DBModel.Country] = []
    // 加载状态机：未请求/加载中/已加载/失败，用于切换 UI
    @State private(set) var countriesState: Loadable<Void>
    // 是否可以弹出推送权限按钮（由全局权限状态驱动）
    @State private var canRequestPushPermission: Bool = false
    // 搜索框文本，驱动 SwiftData 查询过滤
    @State internal var searchText = ""
    // NavigationStack 路径，用于编程式跳转到详情
    @State internal var navigationPath = NavigationPath()
    // 当前页的路由状态（与 AppState.routing.countriesList 双向绑定）
    @State private var routingState: Routing = .init()
    // 通过 Store.dispatched 与全局 AppState 建立绑定，用于写入路由
    private var routingBinding: Binding<Routing> {
        $routingState.dispatched(to: injected.appState, \.routing.countriesList)
    }
    // 依赖注入容器（AppState + Interactors）
    @Environment(\.injected) private var injected: DIContainer
    // 当前 Locale，用于文案/排序
    @Environment(\.locale) private var locale: Locale
    // 读取并监听 Locale 的自定义容器，配合 LocaleReader 修饰器
    private let localeContainer = LocaleReader.Container()

    // 测试注入点（用于 UI 测试/单元测试的检查）
    let inspection = Inspection<Self>()

    // 允许从外部（如测试）注入初始加载状态
    init(state: Loadable<Void> = .notRequested) {
        self._countriesState = .init(initialValue: state)
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            content
                .query(searchText: searchText, results: $countries, { search in
                    Query(filter: #Predicate<DBModel.Country> { country in
                        if search.isEmpty {
                            return true
                        } else {
                            return country.name.localizedStandardContains(search)
                        }
                    }, sort: \DBModel.Country.name)
                })
                .navigationTitle("Countries")
        }
        .modifier(LocaleReader(container: localeContainer))
        .onReceive(routingUpdate) { self.routingState = $0 }
        .onReceive(canRequestPushPermissionUpdate) { self.canRequestPushPermission = $0 }
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
        .flipsForRightToLeftLayoutDirection(true)
    }

    @ViewBuilder private var content: some View {
        switch countriesState {
        case .notRequested:
            defaultView()
        case .isLoading:
            loadingView()
        case .loaded:
            loadedView()
        case let .failed(error):
            failedView(error)
        }
    }

    @ViewBuilder private var permissionsButton: some View {
        if canRequestPushPermission {
            Button(action: requestPushPermission, label: { Text("Allow Push") })
        }
    }
}

// MARK: - Loading Content

private extension CountriesList {
    /// 首次进入页面的默认视图：如果已有数据则直接标记为已加载；否则触发网络加载
    func defaultView() -> some View {
        Text("").onAppear {
            if !countries.isEmpty {
                countriesState = .loaded(())
            }
            loadCountriesList(forceReload: false)
        }
    }

    /// 加载中视图：展示系统圆形进度条
    func loadingView() -> some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
    }

    /// 失败视图：展示错误信息并提供重试
    func failedView(_ error: Error) -> some View {
        ErrorView(error: error, retryAction: {
            loadCountriesList(forceReload: true)
        })
    }
}

// MARK: - Displaying Content

@MainActor
private extension CountriesList {
    /// 已加载视图：
    /// - 空结果 + 有搜索词：提示“无匹配项”；
    /// - 列表 + 点击进入详情；
    /// - 搜索与下拉刷新；
    /// - 工具栏展示“允许推送”按钮；
    /// - 监听路由：当有 countryCode 时，编程式跳转到对应国家；当导航路径非空，清空路由避免重复跳转。
    @ViewBuilder
    func loadedView() -> some View {
        if countries.isEmpty && !searchText.isEmpty {
            Text("No matches found")
                .font(.footnote)
        }
        List(countries, id: \.alpha3Code) { country in
            NavigationLink(value: country) {
                CountryCell(country: country)
            }
        }
        .navigationDestination(for: DBModel.Country.self) { country in
            CountryDetails(country: country)
        }
        .searchable(text: $searchText)
        .refreshable {
            loadCountriesList(forceReload: true)
        }
        .toolbar {
            ToolbarItem {
                permissionsButton
            }
        }
        .onChange(of: routingState.countryCode, initial: true, { _, code in
            guard let code,
                  let country = countries.first(where: { $0.alpha3Code == code})
            else { return }
            navigationPath.append(country)
        })
        .onChange(of: navigationPath, { _, path in
            if !path.isEmpty {
                routingBinding.wrappedValue.countryCode = nil
            }
        })
    }
}

// MARK: - Side Effects

private extension CountriesList {

    /// 触发国家列表加载：
    /// - 参数 forceReload 为 true 时强制刷新；
    /// - 否则仅在本地尚无数据时加载；
    /// - 使用 `$countriesState.load` 包装异步调用以驱动 UI 状态机。
    private func loadCountriesList(forceReload: Bool) {
        guard forceReload || countries.isEmpty else { return }
        $countriesState.load {
            try await injected.interactors.countries
                .refreshCountriesList()
        }
    }

    /// 发起推送权限请求，通过 DI 注入的用户权限交互器实现
    private func requestPushPermission() {
        injected.interactors.userPermissions
            .request(permission: .pushNotifications)
    }
}

// MARK: - Routing

extension CountriesList {
    /// 页面内路由状态，仅包含要跳转的国家代码
    struct Routing: Equatable {
        var countryCode: String?
    }
}

// MARK: - State Updates

private extension CountriesList {

    /// 订阅全局 AppState 中的路由更新（countriesList 子路由）
    private var routingUpdate: AnyPublisher<Routing, Never> {
        injected.appState.updates(for: \.routing.countriesList)
    }

    /// 根据全局权限状态判断是否可请求推送权限：
    /// - 当状态为 `notRequested` 或 `denied` 时返回 true，其余为 false。
    private var canRequestPushPermissionUpdate: AnyPublisher<Bool, Never> {
        injected.appState.updates(for: AppState.permissionKeyPath(for: .pushNotifications))
            .map { $0 == .notRequested || $0 == .denied }
            .eraseToAnyPublisher()
    }
}
