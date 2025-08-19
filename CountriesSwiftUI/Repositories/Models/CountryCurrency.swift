//
//  CountryCurrency.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 8/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftData

// MARK: - Database Model

extension DBModel {
    /// 货币表（持久化对象）
    /// - code: 货币代码（如 CNY、EUR），唯一约束
    /// - symbol: 符号（如 ¥、€），可为空
    /// - name: 名称（如 Chinese Yuan）
    /// - countries: 与 CountryDetails 的多对多关系（哪些国家详情使用该货币）
    @Model final class Currency {
        @Relationship(inverse: \CountryDetails.currencies) var countries: [CountryDetails] = []
        @Attribute(.unique) var code: String
        var symbol: String?
        var name: String

        init(code: String, symbol: String?, name: String) {
            self.code = code
            self.symbol = symbol
            self.name = name
        }
    }
}

// MARK: - Web API Model

extension ApiModel {
    /// 来自 Web API 的货币数据
    struct Currency: Codable, Equatable {
        let code: String
        let symbol: String?
        let name: String
    }
}

// MARK: - 小例子
// let api = ApiModel.Currency(code: "EUR", symbol: "€", name: "Euro")
// let db = DBModel.Currency(code: api.code, symbol: api.symbol, name: api.name)
