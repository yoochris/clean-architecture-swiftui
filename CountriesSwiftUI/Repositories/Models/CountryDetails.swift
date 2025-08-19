//
//  CountryDetails.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftData

// MARK: - Database Model

extension DBModel {

    /// 国家详情表（持久化对象）
    /// - alpha3Code: 国家三位码，唯一，用于与 DBModel.Country 关联
    /// - capital: 首都
    /// - currencies: 使用的货币（与 DBModel.Currency 多对多）
    /// - neighbors: 邻国（与 DBModel.Country 多对多，可能为空）
    @Model final class CountryDetails {
        @Attribute(.unique) var alpha3Code: String
        var capital: String
        var currencies: [Currency]
        var neighbors: [Country]?

        init(alpha3Code: String, capital: String, currencies: [Currency], neighbors: [Country]) {
            self.alpha3Code = alpha3Code
            self.capital = capital
            self.currencies = currencies
            self.neighbors = neighbors
        }
    }
}

// MARK: - Web API Model

extension ApiModel {
    /// 来自 Web API 的国家详情数据
    struct CountryDetails: Codable, Equatable {
        let capital: String
        let currencies: [Currency]
        let borders: [String]? // 邻国的 alpha3Code 数组
    }
}

// MARK: - 小例子
// let api = ApiModel.CountryDetails(capital: "Berlin", currencies: [.init(code: "EUR", symbol: "€", name: "Euro")], borders: ["FRA", "POL"])
