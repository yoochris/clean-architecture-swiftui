//
//  Country.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import Foundation
import SwiftData

// MARK: - Database Model

extension DBModel {

    /// 国家表（持久化对象）
    /// - name: 英文名
    /// - translations: 多语言名称字典（键为 Locale.shortIdentifier，如 "zh_CN"）
    /// - population: 人口数
    /// - flag: 国旗图片链接（可能为空）
    /// - alpha3Code: 三位国家码，唯一约束
    /// - neighbors: 与 CountryDetails 的反向关系（哪些详情把它作为邻国）
    @Model final class Country {

        var name: String
        var translations: [String: String?]
        var population: Int
        var flag: URL?
        @Attribute(.unique) var alpha3Code: String
        @Relationship(inverse: \CountryDetails.neighbors) var neighbors: [CountryDetails] = []

        init(name: String, translations: [String: String?], population: Int, flag: URL? = nil, alpha3Code: String) {
            self.name = name
            self.translations = translations
            self.population = population
            self.flag = flag
            self.alpha3Code = alpha3Code
        }

        /// 根据当前 Locale 优先返回本地化名称，若无则使用英文名
        func name(locale: Locale) -> String {
            let localeId = locale.shortIdentifier
            if let value = translations[localeId], let localizedName = value {
                return localizedName
            }
            return name
        }
    }
}

// MARK: - Web API Model

extension ApiModel {

    /// 来自 Web API 的国家数据（可编码/解码，便于网络传输与单元测试）
    struct Country: Codable, Equatable {

        let name: String
        let translations: [String: String?]
        let population: Int
        let flag: URL?
        let alpha3Code: String

        enum CodingKeys: String, CodingKey {
            case name
            case translations
            case population
            case flag = "alpha2Code" // 注意：服务端此字段可能是 alpha2Code 或者 flag URL
            case alpha3Code
        }

        init(name: String, translations: [String: String?], population: Int, flag: URL?, alpha3Code: String) {
            self.name = name
            self.translations = translations
            self.population = population
            self.flag = flag
            self.alpha3Code = alpha3Code
        }

        /// 自定义解码：兼容两种格式
        /// - 情况1：flag 字段是 2 位的 alpha2Code，例如 "DE" → 组装为 flagcdn URL
        /// - 情况2：flag 字段直接是图片 URL 字符串
        /// - 情况3：字段缺失或非法，flag 置为 nil
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            name = try values.decode(String.self, forKey: .name)
            translations = try values.decode([String: String?].self, forKey: .translations)
            population = try values.decode(Int.self, forKey: .population)
            if let alpha2orFlagURL = try? values.decode(String.self, forKey: .flag) {
                let urlString = alpha2orFlagURL.count == 2 ?
                "https://flagcdn.com/w640/\(alpha2orFlagURL.lowercased()).jpg" : alpha2orFlagURL
                flag = URL(string: urlString)
            } else { flag = nil }
            alpha3Code = try values.decode(String.self, forKey: .alpha3Code)
        }
    }
}

// MARK: - 小例子
// let api = ApiModel.Country(name: "Germany", translations: ["zh_CN": "德国"], population: 83000000, flag: nil, alpha3Code: "DEU")
// let db = DBModel.Country(name: api.name, translations: api.translations, population: api.population, flag: api.flag, alpha3Code: api.alpha3Code)
