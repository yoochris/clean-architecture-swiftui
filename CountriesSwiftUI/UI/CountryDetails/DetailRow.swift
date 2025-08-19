//
//  DetailRow.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 25.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import SwiftUI

/**
 * DetailRow - 详情页通用的左右两列行组件
 * 
 * 职责：
 * - 以一致的样式展示一条“键值对”信息（右侧可为文字或本地化 key）
 * - 复用在国家详情页各个 Section 中，保持列表对齐与留白统一
 * 
 * 设计要点：
 * - leftLabel、rightLabel 都使用 Text，支持富文本与本地化
 * - HStack + Spacer 实现左右对齐；固定高度保证密集信息也整齐
 * - 提供两个 init，分别支持 Text/Text 与 Text/LocalizedStringKey
 * 
 * 小例子：
 * // 直接传入 Text
 * DetailRow(leftLabel: Text("Population"), rightLabel: Text("12,345,678"))
 * 
 * // 右侧是本地化 key（会自动应用当前 Locale 的 strings）
 * DetailRow(leftLabel: Text("Capital"), rightLabel: "Paris")
 */
struct DetailRow: View {
    private let leftLabel: Text
    private let rightLabel: Text
    
    init(leftLabel: Text, rightLabel: Text) {
        self.leftLabel = leftLabel
        self.rightLabel = rightLabel
    }
    
    init(leftLabel: Text, rightLabel: LocalizedStringKey) {
        self.leftLabel = leftLabel
        self.rightLabel = Text(rightLabel)
    }
    
    var body: some View {
        HStack {
            leftLabel
                .font(.headline)          // 左侧信息更醒目
            Spacer()                     // 推动右侧内容靠右
            rightLabel
                .font(.callout)          // 右侧信息相对次要
        }
        .padding()                        // 行内留白
        .frame(maxWidth: .infinity, maxHeight: 40, alignment: .leading) // 统一行高
    }
}

#Preview(traits: .fixedLayout(width: 375, height: 40)) {
    DetailRow(leftLabel: Text("Rate"), rightLabel: Text("$123.99"))
}
