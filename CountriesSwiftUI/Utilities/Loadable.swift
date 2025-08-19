//
//  Loadable.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 23.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import Foundation
import SwiftUI

typealias LoadableSubject<T> = Binding<Loadable<T>>

/**
 * Loadable<T> - 异步数据的状态机枚举
 * 
 * 职责：
 * - 将异步加载数据分为4种状态：未请求、加载中、已加载、加载失败
 * - 每种状态附带必要信息：错误信息、中间值(last)、取消包(cancelBag)
 * - 通过 map/unwrap 支持状态转换，通过 cancelLoading 支持取消操作
 * 
 * 四大状态说明：
 * 1. .notRequested: 初始状态，还未发起过加载
 * 2. .isLoading(last: T?, cancelBag: CancelBag): 正在加载，可选地保留上次结果，可取消
 * 3. .loaded(T): 加载成功，包含最终数据
 * 4. .failed(Error): 加载失败，包含错误信息
 * 
 * 小例子：
 * @State private var countries: Loadable<[Country]> = .notRequested
 * 
 * // 开始加载
 * countries = .isLoading(last: nil, cancelBag: CancelBag())
 * 
 * // 视图中按状态展示不同 UI
 * switch countries {
 * case .loaded(let data): Text("共 \(data.count) 个国家")
 * case .failed(let error): ErrorView(error: error)
 * case .isLoading: ProgressView()
 * default: EmptyView()
 * }
 */
enum Loadable<T> {

    case notRequested                               // 未请求状态
    case isLoading(last: T?, cancelBag: CancelBag)  // 加载中（可选保留上次数据，可取消）
    case loaded(T)                                  // 已加载
    case failed(Error)                              // 加载失败

    var value: T? {
        switch self {
        case let .loaded(value): return value
        case let .isLoading(last, _): return last  // 加载中返回上次值
        default: return nil
        }
    }
    var error: Error? {
        switch self {
        case let .failed(error): return error
        default: return nil
        }
    }
}

extension Loadable {
    
    // 设为加载中状态，保留当前值作为 last
    mutating func setIsLoading(cancelBag: CancelBag) {
        self = .isLoading(last: value, cancelBag: cancelBag)
    }
    
    // 取消加载：如有 last 则回退，否则设为取消错误
    mutating func cancelLoading() {
        switch self {
        case let .isLoading(last, cancelBag):
            cancelBag.cancel()
            if let last = last {
                self = .loaded(last)
            } else {
                let error = NSError(
                    domain: NSCocoaErrorDomain, code: NSUserCancelledError,
                    userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("Canceled by user", comment: "")])
                self = .failed(error)
            }
        default: break
        }
    }
    
    // 函数式转换：对成功状态的数据应用 transform 函数
    func map<V>(_ transform: (T) throws -> V) -> Loadable<V> {
        do {
            switch self {
            case .notRequested: return .notRequested
            case let .failed(error): return .failed(error)
            case let .isLoading(value, cancelBag):
                return .isLoading(last: try value.map { try transform($0) },
                                  cancelBag: cancelBag)
            case let .loaded(value):
                return .loaded(try transform(value))
            }
        } catch {
            return .failed(error)
        }
    }
}

// MARK: - Optional 拆包支持

protocol SomeOptional {
    associatedtype Wrapped
    func unwrap() throws -> Wrapped
}

struct ValueIsMissingError: Error {
    var localizedDescription: String {
        NSLocalizedString("Data is missing", comment: "")
    }
}

extension Optional: SomeOptional {
    func unwrap() throws -> Wrapped {
        switch self {
        case let .some(value): return value
        case .none: throw ValueIsMissingError()
        }
    }
}

// 当 T 是 Optional 时，提供 unwrap() 便利方法
extension Loadable where T: SomeOptional {
    func unwrap() -> Loadable<T.Wrapped> {
        map { try $0.unwrap() }
    }
}

// MARK: - Equatable 支持

extension Loadable: Equatable where T: Equatable {
    static func == (lhs: Loadable<T>, rhs: Loadable<T>) -> Bool {
        switch (lhs, rhs) {
        case (.notRequested, .notRequested): return true
        case let (.isLoading(lhsV, lhsC), .isLoading(rhsV, rhsC)):
            return lhsV == rhsV && lhsC.isEqual(to: rhsC)
        case let (.loaded(lhsV), .loaded(rhsV)): return lhsV == rhsV
        case let (.failed(lhsE), .failed(rhsE)):
            return lhsE.localizedDescription == rhsE.localizedDescription
        default: return false
        }
    }
}

// MARK: - LoadableSubject 扩展

/**
 * LoadableSubject<T>.load 扩展方法
 * 
 * 功能：将异步任务包装为状态机流转
 * - 先设为 .isLoading，启动 Task
 * - 成功则设为 .loaded，失败则设为 .failed
 * - Task 自动存入 cancelBag，支持中途取消
 */
extension LoadableSubject {
    func load<T>(_ resource: @escaping () async throws -> T) where Value == Loadable<T> {
        let cancelBag = CancelBag()
        wrappedValue.setIsLoading(cancelBag: cancelBag)  // 先设为加载状态
        let task = Task {
            do {
                wrappedValue = .loaded(try await resource())  // 成功时设为已加载
            } catch {
                wrappedValue = .failed(error)                // 失败时设为错误
            }
        }
        task.store(in: cancelBag)  // 任务存入取消包，便于取消
    }
}
