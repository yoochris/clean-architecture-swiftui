//
//  RootViewModifier.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 09.11.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import SwiftUI
import Combine

// MARK: - RootViewAppearance

/**
 * RootViewAppearance - 根视图外观控制修饰符
 * 
 * 职责：
 * - 根据全局 AppState 中 system.isActive 标志，统一控制根视图是否模糊
 * - 常用于 App 被置于非活跃态时（如进入后台/被遮挡）对 UI 做淡化处理
 * 
 * 数据流：
 * - 通过 @Environment(\.injected) 读取 DIContainer
 * - 监听 injected.appState.updates(for: \.system.isActive) 的 Publisher
 * - 将收到的新值写入本地状态 @State isActive，从而触发视图刷新
 * 
 * 小例子：
 * struct RootView: View {
 *   var body: some View {
 *     ContentView().modifier(RootViewAppearance())
 *   }
 * }
 */
struct RootViewAppearance: ViewModifier {
    
    @Environment(\.injected) private var injected: DIContainer
    @State private var isActive: Bool = false
    internal let inspection = Inspection<Self>()
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? 0 : 10)             // 非活跃 -> 模糊
            .ignoresSafeArea()                           // 覆盖安全区，确保模糊一致
            .onReceive(stateUpdate) { self.isActive = $0 } // 订阅全局活跃态
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
    
    // 从 AppState 派生活跃态的更新流
    private var stateUpdate: AnyPublisher<Bool, Never> {
        injected.appState.updates(for: \.system.isActive)
    }
}
