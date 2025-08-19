//
//  CountriesInteractor.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

/**
 * CountriesInteractor - 国家列表与详情的业务协调层
 * 
 * 职责：
 * - 作为“用例/业务交互器”，协调 Web 仓库与本地数据库仓库的数据流
 * - 对上层（ViewModel / View）暴露简洁的异步接口，屏蔽存取细节
 * 
 * 设计要点：
 * - refreshCountriesList：从网络拉取国家列表后，统一存入本地数据库
 * - loadCountryDetails：优先读本地缓存；若强制刷新或本地缺失，则从网络拉取并入库，再返回
 * 
 * 小例子：
 * - 列表刷新：
 *   await countriesInteractor.refreshCountriesList()
 *   → webRepository.countries() 拉取网络数据
 *   → dbRepository.store(countries:) 写入数据库
 * 
 * - 国家详情：
 *   let details = try await countriesInteractor.loadCountryDetails(country: de, forceReload: false)
 *   → 先查 dbRepository.countryDetails(for:)
 *   → 若无/或 forceReload=true，则 webRepository.details(country:) 拉取并 dbRepository.store(countryDetails:for:)
 *   → 再从数据库读出返回（确保落地成功）
 */

protocol CountriesInteractor {
    /// 刷新国家列表（网络→数据库），上层只需调用即可
    func refreshCountriesList() async throws
    /// 读取国家详情，支持缓存策略：当 forceReload=false 时优先本地缓存
    func loadCountryDetails(country: DBModel.Country, forceReload: Bool) async throws -> DBModel.CountryDetails
}

struct RealCountriesInteractor: CountriesInteractor {

    let webRepository: CountriesWebRepository
    let dbRepository: CountriesDBRepository

    /// 从网络拉取国家列表并写入数据库
    func refreshCountriesList() async throws {
        let apiCountries = try await webRepository.countries()
        try await dbRepository.store(countries: apiCountries)
    }

    /// 读取国家详情：优先本地缓存；必要时从网络拉取并回写数据库
    func loadCountryDetails(
        country: DBModel.Country, forceReload: Bool
    ) async throws -> DBModel.CountryDetails {
        if !forceReload,
           let stored = try? await dbRepository.countryDetails(for: country) {
            return stored
        }
        let details = try await webRepository.details(country: country)
        try await dbRepository.store(countryDetails: details, for: country)
        guard let stored = try? await dbRepository.countryDetails(for: country) else {
            // 正常情况下不应发生：入库后再次读取失败
            throw ValueIsMissingError()
        }
        return stored
    }
}

/// 空实现（用于预览/单元测试或未接入真实数据时的占位）
struct StubCountriesInteractor: CountriesInteractor {

    func refreshCountriesList() async throws {
    }

    func loadCountryDetails(country: DBModel.Country, forceReload: Bool) async throws -> DBModel.CountryDetails {
        throw ValueIsMissingError()
    }
}
