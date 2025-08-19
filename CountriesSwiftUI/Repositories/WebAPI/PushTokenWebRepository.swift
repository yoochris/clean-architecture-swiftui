//
//  PushTokenWebRepository.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 26.04.2020.
//  Copyright © 2020 Alexey Naumov. All rights reserved.
//

import Foundation

/**
 * PushTokenWebRepository - 推送 Token 注册接口
 * 
 * 职责：
 * - 将设备获取到的 APNs device token 上传到你的业务服务器
 * - 也可以在此调用第三方 SDK 完成注册
 * 
 * 说明：
 * - 示例项目不包含真实服务端，register 留空，便于你接入自家接口
 * 
 * 伪代码示例：
 * func register(devicePushToken: Data) async throws {
 *   let tokenString = devicePushToken.map { String(format: "%02x", $0) }.joined()
 *   var request = URLRequest(url: URL(string: baseURL + "/register")!)
 *   request.httpMethod = "POST"
 *   request.setValue("application/json", forHTTPHeaderField: "Content-Type")
 *   request.httpBody = try JSONEncoder().encode(["token": tokenString])
 *   let (_, response) = try await session.data(for: request)
 *   guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw APIError.unexpectedResponse }
 * }
 */
protocol PushTokenWebRepository: WebRepository {
    func register(devicePushToken: Data) async throws
}

struct RealPushTokenWebRepository: PushTokenWebRepository {
    
    let session: URLSession
    let baseURL: String
    
    init(session: URLSession) {
        self.session = session
        self.baseURL = "https://your-server.com/api/push-token"
    }
    
    /// 将 APNs token 上传到你的服务器（示例中未实现）
    func register(devicePushToken: Data) async throws {
        // upload the push token to your server
        // you can as well call a third party library here instead
    }
}
