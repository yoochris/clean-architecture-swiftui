//
//  CountryDetails.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 25.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import SwiftUI
import Combine
import SwiftData

/**
 * CountryDetails - 国家详情页面主视图
 * 
 * 职责：
 * 1. 根据传入的 Country 实体，异步加载并展示国家详情信息
 * 2. 提供国旗查看模态窗口、邻国导航等交互功能
 * 3. 使用 Loadable<CountryDetails> 状态机管理加载/成功/失败三态
 * 4. 通过路由绑定管理 Sheet 弹窗的显示状态
 * 5. 支持依赖注入与单测：可预设任意初始状态，便于预览和测试
 * 
 * 架构特点：
 * - 通过 @Environment(\.injected) 获取 DIContainer，实现依赖解耦合
 * - 将路由状态 $routingState 与 AppState 双向绑定，保持全局状态同步
 * - 使用 LoadableSubject<T>.load 扩展，简化异步数据加载模式
 * 
 * 小例子：
 * // 正常使用
 * CountryDetails(country: selectedCountry)
 * 
 * // 预览中注入已加载状态
 * CountryDetails(country: mockCountry, details: .loaded(mockDetails))
 */
@MainActor
struct CountryDetails: View {
    
    private let country: DBModel.Country

    @Environment(\.locale) var locale: Locale                    // 本地化配置
    @Environment(\.injected) private var injected: DIContainer   // 依赖注入容器
    @State private var details: Loadable<DBModel.CountryDetails> // 详情加载状态机
    @State private var routingState: Routing = .init()           // 路由状态（控制 Sheet 显示）
    
    // 将本地路由状态与全局 AppState 双向绑定
    private var routingBinding: Binding<Routing> {
        $routingState.dispatched(to: injected.appState, \.routing.countryDetails)
    }
    let inspection = Inspection<Self>()                          // 测试辅助（ViewInspector）
    
    init(country: DBModel.Country, details: Loadable<DBModel.CountryDetails> = .notRequested) {
        self.country = country
        self._details = .init(initialValue: details)
    }
    
    var body: some View {
        content
            .navigationBarTitle(country.name(locale: locale))
            .onReceive(routingUpdate) { self.routingState = $0 }
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
    
    @ViewBuilder private var content: some View {
        switch details {
        case .notRequested:
            defaultView()
        case .isLoading:
            loadingView()
        case let .loaded(countryDetails):
            loadedView(countryDetails)
        case let .failed(error):
            failedView(error)
        }
    }
}

// MARK: - Side Effects

private extension CountryDetails {

    // 发起国家详情加载，委托给 CountriesInteractor
    func loadCountryDetails(forceReload: Bool) {
        $details.load {
            try await injected.interactors.countries
                .loadCountryDetails(country: country, forceReload: forceReload)
        }
    }
    
    // 显示国旗查看模态窗口
    func showCountryDetailsSheet() {
        injected.appState[\.routing.countryDetails.detailsSheet] = true
    }
}

// MARK: - Loading Content

private extension CountryDetails {
    // 首次出现时触发加载
    func defaultView() -> some View {
        Text("").onAppear {
            loadCountryDetails(forceReload: false)
        }
    }
    
    // 加载中视图，支持取消操作
    func loadingView() -> some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Button(action: {
                self.details.cancelLoading()
            }, label: { Text("Cancel loading") })
        }
    }
    
    // 失败视图，提供重试功能
    func failedView(_ error: Error) -> some View {
        ErrorView(error: error, retryAction: {
            self.loadCountryDetails(forceReload: true)
        })
    }
}

// MARK: - Displaying Content

@MainActor
private extension CountryDetails {
    // 主要内容视图：分组列表展示各种详情
    func loadedView(_ countryDetails: DBModel.CountryDetails) -> some View {
        List {
            // 可选：国旗展示区
            country.flag.map { url in
                flagView(url: url)
            }
            // 基本信息段
            basicInfoSectionView(countryDetails: countryDetails)
            // 可选：货币段
            if countryDetails.currencies.count > 0 {
                currenciesSectionView(currencies: countryDetails.currencies)
            }
            // 可选：邻国段
            if let neighbors = countryDetails.neighbors {
                if neighbors.count  > 0 {
                    neighborsSectionView(neighbors: neighbors)
                }
            }
        }
        .listStyle(GroupedListStyle())
        .sheet2(isPresented: routingBinding.detailsSheet,
                content: { self.modalDetailsView() })
    }
    
    // 国旗展示（点击打开模态窗口）
    func flagView(url: URL) -> some View {
        HStack {
            Spacer()
            ImageView(imageURL: url)
                .frame(width: 120, height: 80)
                .onTapGesture {
                    self.showCountryDetailsSheet()
                }
            Spacer()
        }
    }
    
    // 基本信息段：国家代码、人口、首都
    func basicInfoSectionView(countryDetails: DBModel.CountryDetails) -> some View {
        Section(header: Text("Basic Info")) {
            DetailRow(leftLabel: Text(country.alpha3Code), rightLabel: "Code")
            DetailRow(leftLabel: Text("\(country.population)"), rightLabel: "Population")
            DetailRow(leftLabel: Text("\(countryDetails.capital)"), rightLabel: "Capital")
        }
    }
    
    // 货币段：列举所有货币
    func currenciesSectionView(currencies: [DBModel.Currency]) -> some View {
        Section(header: Text("Currencies")) {
            ForEach(currencies) { currency in
                DetailRow(leftLabel: Text(currency.title), rightLabel: Text(currency.code))
            }
        }
    }
    
    // 邻国段：每个邻国可导航到其详情页
    func neighborsSectionView(neighbors: [DBModel.Country]) -> some View {
        Section(header: Text("Neighboring countries")) {
            ForEach(neighbors) { country in
                NavigationLink(destination: self.neighbourDetailsView(country: country)) {
                    DetailRow(leftLabel: Text(country.name(locale: self.locale)), rightLabel: "")
                }
            }
        }
    }
    
    // 邻国详情页（递归展示）
    func neighbourDetailsView(country: DBModel.Country) -> some View {
        CountryDetails(country: country)
    }
    
    // 国旗模态窗口
    func modalDetailsView() -> some View {
        ModalFlagView(country: country,
                      isDisplayed: routingBinding.detailsSheet)
            .inject(injected)
    }
}

// MARK: - Helpers

private extension DBModel.Currency {
    // 货币展示标题（名称 + 符号）
    var title: String {
        return name + (symbol.map {" " + $0} ?? "")
    }
}

// MARK: - Routing

extension CountryDetails {
    // 路由状态结构体：控制是否显示国旗详情 Sheet
    struct Routing: Equatable {
        var detailsSheet: Bool = false
    }
}

// MARK: - State Updates

private extension CountryDetails {
    
    // 监听全局路由状态变化
    var routingUpdate: AnyPublisher<Routing, Never> {
        injected.appState.updates(for: \.routing.countryDetails)
    }
}

// MARK: - ViewInspector helper
// https://github.com/nalexn/ViewInspector/blob/master/guide_popups.md#sheet

/**
 * ViewInspector 需要的自定义 Sheet 修饰符
 * 在普通 App 中等价于 .sheet()，但在测试中允许检查 Sheet 内容
 */
extension View {
    func sheet2<Sheet>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Sheet
    ) -> some View where Sheet: View {
        return self.modifier(InspectableSheet(isPresented: isPresented, onDismiss: onDismiss, popupBuilder: content))
    }
}

struct InspectableSheet<Sheet>: ViewModifier where Sheet: View {

    let isPresented: Binding<Bool>
    let onDismiss: (() -> Void)?
    let popupBuilder: () -> Sheet

    func body(content: Self.Content) -> some View {
        content.sheet(isPresented: isPresented, onDismiss: onDismiss, content: popupBuilder)
    }
}
