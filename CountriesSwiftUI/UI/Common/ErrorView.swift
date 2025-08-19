//
//  ErrorView.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 25.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import SwiftUI

/**
 * ErrorView - 通用错误展示视图组件
 * 
 * 职责：
 * 1. 统一错误信息的展示样式和交互方式
 * 2. 提供重试按钮，允许用户重新尝试失败的操作
 * 3. 支持任意类型的 Error，自动提取本地化描述信息
 * 4. 保持应用内错误页面的 UI 一致性
 * 
 * 适用场景：
 * - 网络请求失败后的错误提示
 * - 数据加载异常时的占位视图
 * - 任何需要展示错误信息并提供重试机会的场合
 * 
 * 小例子：
 * ErrorView(
 *     error: APIError.networkUnavailable,
 *     retryAction: {
 *         // 重新加载数据
 *         loadCountries()
 *     }
 * )
 */
struct ErrorView: View {
    let error: Error                // 要展示的错误对象
    let retryAction: () -> Void     // 用户点击重试按钮时执行的闭包
    
    var body: some View {
        VStack {
            // 固定的错误标题
            Text("An Error Occured")
                .font(.title)
            
            // 从错误对象中提取本地化描述
            Text(error.localizedDescription)
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.bottom, 40).padding()
            
            // 重试按钮，执行传入的重试动作
            Button(action: retryAction, label: { Text("Retry").bold() })
        }
    }
}

#Preview {
    ErrorView(error: NSError(domain: "", code: 0, userInfo: [
        NSLocalizedDescriptionKey: "Something went wrong"]),
              retryAction: { })
}
