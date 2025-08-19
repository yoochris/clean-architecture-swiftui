//
//  AppSchema.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftData

/**
 * AppSchema - 应用的 SwiftData 模型集合定义
 * 
 * 职责：集中声明数据库涉及到的所有 @Model 类型，并维护 Schema 的版本。
 * - 便于统一迁移与演进（actualVersion）
 * - 任何新增/删除模型类都应同步更新此处，保证容器可正确初始化
 * 
 * 小例子：
 * let container = try ModelContainer.appModelContainer()
 * let schema = Schema.appSchema // 包含 Country/CountryDetails/Currency 三个模型
 */

enum DBModel { }

extension Schema {
    /// 当前 Schema 版本（用于未来的版本迁移）
    private static var actualVersion: Schema.Version = Version(1, 0, 0)

    /// 应用 Schema：列出所有数据库模型类型
    static var appSchema: Schema {
        Schema([
            DBModel.Country.self,
            DBModel.CountryDetails.self,
            DBModel.Currency.self,
        ], version: actualVersion)
    }
}
