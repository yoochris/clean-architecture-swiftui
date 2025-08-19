//
//  Query+Search.swift
//  CountriesSwiftUI
//
//  Created by Alexey on 8/11/24.
//  Copyright © 2024 Alexey Naumov. All rights reserved.
//

import SwiftUI
import SwiftData

/**
 * Query+Search - 让 @Query 能随搜索词变更而重建的辅助容器
 * 
 * 背景问题：
 * - SwiftData 的 @Query 是按声明时捕获的谓词构建的，简单改变绑定值并不会自动重建查询
 * - 直接把 searchText 作为参数传给查询在某些场景下会产生双重查询或不触发更新
 * 
 * 解决方案：
 * - 提供一个 View 扩展方法 query(searchText:results:_:) 用来包装查询并在 searchText 变化时重建 @Query
 * - 使用 QueryViewContainer 作为“盾牌”，通过 Equatable 约束仅在 searchText 真实变化时刷新子视图
 * - 用隐藏视图 QueryView 挂载 @Query 并通过 onChange 把查询结果回传给外层
 * 
 * 用法：
 * @State private var results: [DBModel.Country] = []
 * var body: some View {
 *     List(results) { country in Text(country.name) }
 *         .query(searchText: searchText, results: $results) { text in
 *             Query(filter: #Predicate<DBModel.Country> { $0.name.contains(text) }, sort: \.[name])
 *         }
 * }
 */
extension View {
    /**
     允许在每次 searchText 变化时重建 @Query
     - Parameters:
       - searchText: 搜索字符串
       - results: 查询结果的绑定（外部持有数组，内部更新）
       - builder: 根据 searchText 生成 SwiftData Query
     - Returns: 包装后的视图
     */
    func query<T: PersistentModel>(
        searchText: String,
        results: Binding<[T]>,
        _ builder: @escaping (String) -> Query<T, [T]>
    ) -> some View {
        background {
            QueryViewContainer(searchText: searchText, builder: builder) { _, values in
                results.wrappedValue = values
            }.equatable()
        }
    }
}

/**
 * 该容器作为 QueryView 的“盾牌”，避免发生双重查询
 * 仅在 searchText 发生改变时视为不相等，从而触发重建
 */
private struct QueryViewContainer<T: PersistentModel>: View, Equatable {

    let searchText: String
    let builder: (String) -> Query<T, [T]>
    let results: ([T], [T]) -> Void

    var body: some View {
        QueryView(query: builder(searchText), results: results)
    }

    static func == (lhs: QueryViewContainer<T>, rhs: QueryViewContainer<T>) -> Bool {
        return lhs.searchText == rhs.searchText
    }
}

/**
 * 实际挂载 @Query 的隐藏视图
 * 通过 onChange(of:query, initial:true) 把结果回传，并避免在外层多次声明 @Query
 */
private struct QueryView<T: PersistentModel>: View {

    @Query var query: [T]
    let results: ([T], [T]) -> Void

    init(query: Query<T, [T]>, results: @escaping ([T], [T]) -> Void) {
        _query = query
        self.results = results
    }

    var body: some View {
        Rectangle()
            .hidden()
            .onChange(of: query, initial: true, results)
    }
}
