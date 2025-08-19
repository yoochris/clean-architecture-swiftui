//
//  CountriesDBRepository.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftData
import Foundation

/**
 * CountriesDBRepository - 国家相关的数据库操作仓库
 * 
 * 职责：
 * - 封装基于 SwiftData 的国家列表与详情的 CRUD 操作
 * - 提供统一的异步接口，隐藏底层 ModelContext/FetchDescriptor 等实现细节
 * - 负责 API 模型（ApiModel）与数据库模型（DBModel）之间的转换
 * 
 * 核心操作：
 * - countryDetails(for:): 根据国家查询其详情（首都、货币、邻国等）
 * - store(countries:): 批量存储国家基础信息
 * - store(countryDetails:for:): 存储某个国家的详细信息（含关联关系）
 * 
 * 小例子：
 * - 存储国家列表：
 *   let apiCountries = [ApiModel.Country(...), ...]
 *   try await repository.store(countries: apiCountries)
 *   → 转换为 DBModel.Country 并批量插入数据库
 * 
 * - 查询国家详情：
 *   let details = try await repository.countryDetails(for: germanyDBModel)
 *   → 用 FetchDescriptor + Predicate 按 alpha3Code 查询
 *   → 返回 DBModel.CountryDetails?（含首都、货币、邻国关系）
 */

protocol CountriesDBRepository {
    @MainActor
    func countryDetails(for country: DBModel.Country) async throws -> DBModel.CountryDetails?
    func store(countries: [ApiModel.Country]) async throws
    func store(countryDetails: ApiModel.CountryDetails, for country: DBModel.Country) async throws
}

extension MainDBRepository: CountriesDBRepository {

    /// 根据国家的 alpha3Code 查询其详情信息
    @MainActor
    func countryDetails(for country: DBModel.Country) async throws -> DBModel.CountryDetails? {
        let alpha3Code = country.alpha3Code
        let fetchDescriptor = FetchDescriptor(predicate: #Predicate<DBModel.CountryDetails> {
            $0.alpha3Code == alpha3Code
        })
        return try modelContainer.mainContext.fetch(fetchDescriptor).first
    }

    /// 批量存储国家基础信息：API模型 → DB模型 → 插入数据库
    func store(countries: [ApiModel.Country]) async throws {
        try modelContext.transaction {
            countries
                .map { $0.dbModel() }
                .forEach {
                    modelContext.insert($0)
                }
        }
    }

    /// 存储国家详情：处理货币、邻国等复杂关联关系
    func store(countryDetails: ApiModel.CountryDetails, for country: DBModel.Country) async throws {
        let alpha3Code = country.alpha3Code
        try modelContext.transaction {
            // 1. 转换货币模型并插入
            let currencies = countryDetails.currencies.map { $0.dbModel() }
            
            // 2. 查询邻国：根据 borders 数组中的 alpha3Code 找到对应的 DBModel.Country
            let neighborsFetch = FetchDescriptor(predicate: #Predicate<DBModel.Country> { countryDBModel in
                countryDetails.borders?.contains(countryDBModel.alpha3Code) == true
            })
            let neighbors = try modelContext.fetch(neighborsFetch)
            
            // 3. 插入货币实体
            currencies.forEach {
                modelContext.insert($0)
            }
            
            // 4. 创建并插入国家详情（含关联）
            let object = DBModel.CountryDetails(
                alpha3Code: alpha3Code,
                capital: countryDetails.capital,
                currencies: currencies,
                neighbors: neighbors)
            modelContext.insert(object)
        }
    }
}

// MARK: - API模型到DB模型的转换器

internal extension ApiModel.Country {
    /// 将网络获取的国家数据转换为数据库存储格式
    func dbModel() -> DBModel.Country {
        return .init(name: name, translations: translations,
                     population: population, flag: flag,
                     alpha3Code: alpha3Code)
    }
}

internal extension ApiModel.Currency {
    /// 将网络获取的货币数据转换为数据库存储格式
    func dbModel() -> DBModel.Currency {
        return .init(code: code, symbol: symbol, name: name)
    }
}
