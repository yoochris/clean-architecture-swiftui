//
//  CountriesWebRepository.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import Foundation

/**
 * CountriesWebRepository - 国家数据的网络访问层
 * 
 * 职责：
 * - 继承 WebRepository，获得通用的网络请求能力
 * - 提供 countries() 和 details(country:) 两个核心接口
 * - 封装 REST Countries API 的具体调用规范
 * 
 * 设计要点：
 * - 协议分离：便于测试时注入 Stub 实现
 * - 端点枚举：集中管理 API 的 path、method、headers
 * - URL编码：countryDetails 需要对国家名进行编码处理
 * 
 * 小例子：
 * let repo = RealCountriesWebRepository(session: URLSession.shared)
 * let countries = try await repo.countries() // 获取所有国家
 * let details = try await repo.details(country: germanyDBModel) // 获取德国详情
 */
protocol CountriesWebRepository: WebRepository {
    func countries() async throws -> [ApiModel.Country]
    func details(country: DBModel.Country) async throws -> ApiModel.CountryDetails
}

struct RealCountriesWebRepository: CountriesWebRepository {

    let session: URLSession
    let baseURL: String

    init(session: URLSession) {
        self.session = session
        self.baseURL = "https://restcountries.com/v2"
    }

    /// 获取所有国家的基础信息（名称、翻译、人口、国旗、alpha3Code）
    func countries() async throws -> [ApiModel.Country] {
        return try await call(endpoint: API.allCountries)
    }

    /// 根据国家名获取详细信息（首都、货币、邻国）
    func details(country: DBModel.Country) async throws -> ApiModel.CountryDetails {
        let response: [ApiModel.CountryDetails] = try await call(endpoint: API.countryDetails(countryName: country.name))
        guard let details = response.first else {
            throw APIError.unexpectedResponse
        }
        return details
    }
}

// MARK: - Endpoints

extension RealCountriesWebRepository {
    /// API 端点枚举：定义具体的请求参数
    enum API {
        case allCountries
        case countryDetails(countryName: String)
    }
}

extension RealCountriesWebRepository.API: APICall {
    var path: String {
        switch self {
        case .allCountries:
            return "/all?fields=name,translations,population,flag,alpha3Code"
        case let .countryDetails(countryName):
            let encodedName = countryName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            return "/name/\(encodedName ?? countryName)"
        }
    }
    var method: String {
        switch self {
        case .allCountries, .countryDetails:
            return "GET"
        }
    }
    var headers: [String: String]? {
        return ["Accept": "application/json"]
    }
    func body() throws -> Data? {
        return nil
    }
}
