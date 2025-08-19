//
//  ModelContainer.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftData

/**
 * ModelContainer - SwiftData 的容器工厂与辅助扩展
 * 
 * 职责：
 * - 创建应用的 ModelContainer，绑定统一的 Schema
 * - 提供内存库（inMemoryOnly）与桩环境（isStub）的快速构造，用于单元测试/预览
 * - 暴露识别当前容器是否为 stub 的便捷属性
 * 
 * 设计要点：
 * - 通过 Schema.appSchema 管理模型集合，避免分散配置
 * - 使用 ModelConfiguration 给不同环境命名，如 "stub"，并支持仅内存存储，避免污染真实数据
 * 
 * 小例子：
 * - 生产环境容器：
 *   let container = try ModelContainer.appModelContainer()
 * - 单元测试容器（内存且隔离命名）：
 *   let container = try ModelContainer.appModelContainer(inMemoryOnly: true, isStub: true)
 * - 判断容器是否为 stub：
 *   if container.isStub { /* 走假数据逻辑 */ }
 */
extension ModelContainer {

    /// 构造应用 ModelContainer，并可选择是否仅内存存储以及是否使用 stub 命名空间
    static func appModelContainer(
        inMemoryOnly: Bool = false, isStub: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema.appSchema
        let modelConfiguration = ModelConfiguration(isStub ? "stub" : nil, schema: schema, isStoredInMemoryOnly: inMemoryOnly)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    /// 便捷的 stub 容器：仅内存 + 命名空间 "stub"
    static var stub: ModelContainer {
        try! appModelContainer(inMemoryOnly: true, isStub: true)
    }

    /// 是否为 stub 容器（通过配置名判断）
    var isStub: Bool {
        return configurations.first?.name == "stub"
    }
}

/// 标注主数据库仓库为 SwiftData 的 @ModelActor，获得线程安全的数据访问
@ModelActor
final actor MainDBRepository { }
