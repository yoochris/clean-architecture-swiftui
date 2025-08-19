//
//  ModalFlagView.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 26.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import SwiftUI
import EnvironmentOverrides

/**
 * ModalFlagView - 国旗大图模态视图
 * 
 * 职责：
 * - 在 Sheet/全屏模态中展示选中国家的国旗大图
 * - 提供关闭按钮，修改上层绑定的 isDisplayed 以关闭弹窗
 * - 支持依赖注入与测试：使用 Inspection 辅助 ViewInspector
 * 
 * 设计要点：
 * - 使用 NavigationStack + toolbar 提供统一标题与关闭按钮
 * - 通过绑定 @Binding var isDisplayed 与父视图联动
 * - attachEnvironmentOverrides() 便于预览/测试时覆盖环境值
 * 
 * 小例子：
 * @State private var show = false
 * var body: some View {
 *   Button("Show flag") { show = true }
 *   .sheet(isPresented: $show) {
 *       ModalFlagView(country: country, isDisplayed: $show)
 *   }
 * }
 */
struct ModalFlagView: View {

    let country: DBModel.Country
    @Binding var isDisplayed: Bool        // 与父视图路由状态绑定
    let inspection = Inspection<Self>()   // 测试辅助
    
    var body: some View {
        NavigationStack {
            country.flag.map { url in
                HStack {
                    Spacer()
                    ImageView(imageURL: url)
                        .frame(width: 300, height: 200)
                    Spacer()
                }
            }
            .navigationTitle(country.name)
            .toolbar {
                ToolbarItem {
                    closeButton
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
        .attachEnvironmentOverrides()
    }
    
    private var closeButton: some View {
        Button(action: {
            self.isDisplayed = false // 关闭模态
        }, label: { Text("Close") })
    }
}
