//
//  Helpers.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import Foundation
import Combine

/**
 * Helpers - 常用工具扩展集合
 * 
 * 包含内容：
 * 1) ProcessInfo.isRunningTests: 判断当前是否处在单元测试环境
 * 2) String.localized(_:)：在指定 Locale 下读取对应 lproj 的本地化文案
 * 3) Locale.backendDefault / shortIdentifier：后端默认语言与缩写标识
 * 4) Result.isSuccess：快捷判断结果是否成功
 * 5) Inspection：ViewInspector 测试辅助，允许在特定时刻访问视图
 * 
 * 小例子：
 * // 读取法语文案
 * "Capital".localized(Locale(identifier: "fr"))
 * 
 * // 判断是否在测试
 * if ProcessInfo.processInfo.isRunningTests { ... }
 */
extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}

extension String {
    // 按指定 Locale 读取 main bundle 对应 lproj 的本地化字符串
    func localized(_ locale: Locale) -> String {
        let localeId = locale.shortIdentifier
        guard let path = Bundle.main.path(forResource: localeId, ofType: "lproj"),
            let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        return bundle.localizedString(forKey: self, value: nil, table: nil)
    }
}

extension Locale {
    static var backendDefault: Locale {
        return Locale(identifier: "en")
    }

    // 取前两位作为语言缩写（如 zh-Hans -> zh）
    var shortIdentifier: String {
        return String(identifier.prefix(2))
    }
}

extension Result {
    var isSuccess: Bool {
        switch self {
        case .success: return true
        case .failure: return false
        }
    }
}

// MARK: - View Inspection helper

/**
 * Inspection: 用于 ViewInspector 的测试辅助类
 * - 通过 notice 触发器在某行(line)回调时注入闭包
 * - 使测试可以在合适的生命周期时机访问到 SwiftUI 视图
 */
internal final class Inspection<V> {
    let notice = PassthroughSubject<UInt, Never>()
    var callbacks = [UInt: (V) -> Void]()

    func visit(_ view: V, _ line: UInt) {
        if let callback = callbacks.removeValue(forKey: line) {
            callback(view)
        }
    }
}
