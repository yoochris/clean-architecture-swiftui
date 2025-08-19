//
//  CountryCell.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 7/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftUI

/**
 * CountryCell - 国家列表中的单行条目
 * 
 * 职责：
 * 1. 展示国家名称与人口两行信息
 * 2. 使用环境中的 Locale 决定名称展示（本地化名称或原始名称）
 * 3. 保持行高和左右对齐，适合作为 List/ForEach 的子项
 * 
 * 小例子：
 * List(countries) { country in
 *     CountryCell(country: country)
 * }
 */
struct CountryCell: View {

    let country: DBModel.Country
    @Environment(\.locale) var locale: Locale // 从环境读取当前语言区域，用于本地化名称

    var body: some View {
        VStack(alignment: .leading) {
            Text(country.name(locale: locale))
                .font(.title)
            Text("Population \(country.population)")
                .font(.caption)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: 60, alignment: .leading)
    }
}
