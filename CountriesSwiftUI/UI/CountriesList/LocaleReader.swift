//
//  LocaleReader.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 8/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftUI

/**
 * CountriesList.LocaleReader - 保留 Environment 中的 Locale 值
 * 
 * 背景：
 * - 在使用 SwiftData 的按名称搜索中，需要从外部获取 Locale 来决定展示或过滤逻辑
 * - 直接在某些辅助结构中使用 @Environment(\.locale) 不可达，导致无法读取
 * 
 * 解决：
 * - 通过 EnvironmentalModifier 在解析阶段读取 EnvironmentValues
 * - 将读取到的 locale 写入一个引用类型 Container，供外层使用
 * - 使用 DummyViewModifier 保证该修饰符不会被 SwiftUI 优化掉
 * 
 * 小例子：
 * let container = CountriesList.LocaleReader.Container()
 * List { ... }
 *   .environmentalModifier(CountriesList.LocaleReader(container: container))
 * // 后续可从 container.locale 读取当前 Locale
 */
extension CountriesList {

    struct LocaleReader: EnvironmentalModifier {

        /**
         * 引用类型容器，用于保存环境中的 Locale 值
         * 之所以用 class 而非 struct，是为了被外部持有并在解析阶段写入
         */
        final class Container {
            var locale: Locale = .backendDefault
        }
        let container: Container

        // 在解析环境时，把当前 locale 写入容器
        func resolve(in environment: EnvironmentValues) -> some ViewModifier {
            container.locale = environment.locale
            return DummyViewModifier()
        }

        /**
         * 空实现的修饰器：不能直接返回 content，因为 SwiftUI 会把无副作用的修饰器折叠
         * 调用 onAppear() 可阻止这种折叠行为，确保 modifier 被应用
         */
        private struct DummyViewModifier: ViewModifier {
            func body(content: Content) -> some View {
                content.onAppear()
            }
        }
    }
}
