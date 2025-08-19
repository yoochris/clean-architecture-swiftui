//
//  Store.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 04.04.2020.
//  Copyright © 2020 Alexey Naumov. All rights reserved.
//

import SwiftUI
import Combine

/**
 * Store<State> - 简化版的应用状态容器
 * 
 * 职责：
 * - 用 Combine 的 CurrentValueSubject 承载全局或模块状态
 * - 提供便利的下标写入语法和去重发布 updates(for:)
 * - 与 SwiftUI 的 Binding 扩展配合，实现双向绑定 + 自动分发
 * 
 * 小例子：
 * struct AppState { var count = 0 }
 * let store = Store(AppState())
 * 
 * // 订阅某个键路径的变化
 * store.updates(for: \AppState.count).sink { print($0) }
 * // 写入（带去重）
 * store[\\AppState.count] = 1
 */
typealias Store<State> = CurrentValueSubject<State, Never>

extension Store {

    // 通过下标读写状态中某个可写 KeyPath 的值（带 Equatable 去重）
    subscript<T>(keyPath: WritableKeyPath<Output, T>) -> T where T: Equatable {
        get { value[keyPath: keyPath] }
        set {
            var value = self.value
            if value[keyPath: keyPath] != newValue {
                value[keyPath: keyPath] = newValue
                self.value = value
            }
        }
    }

    // 批量更新：在一个闭包里修改多个字段，最后一次性发布
    func bulkUpdate(_ update: (inout Output) -> Void) {
        var value = self.value
        update(&value)
        self.value = value
    }

    // 按 KeyPath 订阅值变化：自动去重
    func updates<Value>(for keyPath: KeyPath<Output, Value>) ->
        AnyPublisher<Value, Failure> where Value: Equatable {
        return map(keyPath).removeDuplicates().eraseToAnyPublisher()
    }
}

// MARK: - Binding 扩展：值改变时分发到 Store

extension Binding where Value: Equatable {
    // 将 Binding 的 set 动作同步写入 Store 的对应键路径（带去重）
    func dispatched<State>(to state: Store<State>,
                           _ keyPath: WritableKeyPath<State, Value>) -> Self {
        return onSet { state[keyPath] = $0 }
    }
}

extension Binding where Value: Equatable {
    typealias ValueClosure = (Value) -> Void

    // 在 set 时回调 perform（即使新旧值相等也会触发回调逻辑判断）
    func onSet(_ perform: @escaping ValueClosure) -> Self {
        return .init(get: { () -> Value in
            self.wrappedValue
        }, set: { value in
            if self.wrappedValue != value {     // 先本地去重
                self.wrappedValue = value
            }
            perform(value)                      // 再执行业务回调（触发 Store 分发）
        })
    }
}

