//
//  CancelBag.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 04.04.2020.
//  Copyright © 2020 Alexey Naumov. All rights reserved.
//

import Combine

/**
 * CancelBag - 取消令牌收纳器
 * 
 * 职责：
 * - 统一管理 Combine 的 AnyCancellable 和 Task 的取消生命周期
 * - 支持批量 cancel()；在视图销毁或任务中断时清理资源
 * - isEqual(to:) 提供自定义等价逻辑，解决 Equatable 比较状态一致性
 * 
 * 使用场景：
 * - 加载状态是 .isLoading(last:cancelBag: ) 时，把 Task 存入 cancelBag，点击“取消”或离开页面时取消
 * - 在 ViewModel / Interactor 中管理多个订阅，集中关闭
 * 
 * 小例子：
 * let bag = CancelBag()
 * URLSession.shared.dataTaskPublisher(for: url)
 *   .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
 *   .store(in: bag) // 统一收纳
 * // 需要时
 * bag.cancel() // 取消所有订阅/任务
 */
final class CancelBag {
    fileprivate(set) var subscriptions = [any Cancellable]() // 内部存储所有可取消项
    private let equalToAny: Bool                             // 是否认为与任意 CancelBag 相等（用于测试/比较）
    
    init(equalToAny: Bool = false) {
        self.equalToAny = equalToAny
    }
    
    func cancel() {
        subscriptions.removeAll() // 移除即触发订阅取消
    }
    
    func isEqual(to other: CancelBag) -> Bool {
        return other === self || other.equalToAny || self.equalToAny
    }
}

extension Cancellable {
    
    func store(in cancelBag: CancelBag) {
        cancelBag.subscriptions.append(self)
    }
}

// 将 Swift 并发的 Task retroactive 地标记为 Cancellable，便于与 CancelBag 配合
extension Task: @retroactive Cancellable { }
