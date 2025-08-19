//
//  WebRepository.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 23.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import Foundation
import Combine

/**
 * WebRepository - 通用网络访问协议与工具集
 * 
 * 组成：
 * - WebRepository 协议：需要一个 URLSession 与 baseURL
 * - call(endpoint:decoder:httpCodes:)：泛型解码网络响应为目标类型
 * - APICall 协议：约定 path/method/headers/body 并可生成 URLRequest
 * - APIError：统一错误枚举及本地化描述
 * - HTTPCodes：常用 2xx 成功范围
 * 
 * 小例子：
 * struct Repo: WebRepository { let session: URLSession; let baseURL = "https://api.example.com" }
 * enum API: APICall { case users; var path: String { "/users" }; var method: String { "GET" }; var headers: [String:String]? { ["Accept":"application/json"] }; func body() throws -> Data? { nil } }
 * let repo = Repo(session: .shared)
 * let users: [User] = try await repo.call(endpoint: API.users)
 */

enum ApiModel { }

protocol WebRepository {
    var session: URLSession { get }
    var baseURL: String { get }
}

extension WebRepository {
    /// 通用请求：构建 URLRequest → URLSession.data(for:) → 校验 HTTP 码 → 解码为 Value
    func call<Value, Decoder>(
        endpoint: APICall,
        decoder: Decoder = JSONDecoder(),
        httpCodes: HTTPCodes = .success
    ) async throws -> Value
    where Value: Decodable, Decoder: TopLevelDecoder, Decoder.Input == Data {

        let request = try endpoint.urlRequest(baseURL: baseURL)
        let (data, response) = try await session.data(for: request)
        guard let code = (response as? HTTPURLResponse)?.statusCode else {
            throw APIError.unexpectedResponse
        }
        guard httpCodes.contains(code) else {
            throw APIError.httpCode(code)
        }
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            throw APIError.unexpectedResponse
        }
    }
}

// MARK: - APICall

/// 描述一个具体的 API 调用（REST 端点）
protocol APICall {
    var path: String { get }
    var method: String { get }
    var headers: [String: String]? { get }
    func body() throws -> Data?
}

/// 统一的网络层错误枚举
enum APIError: Swift.Error, Equatable {
    case invalidURL
    case httpCode(HTTPCode)
    case unexpectedResponse
    case imageDeserialization
}

extension APIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case let .httpCode(code): return "Unexpected HTTP code: \(code)"
        case .unexpectedResponse: return "Unexpected response from the server"
        case .imageDeserialization: return "Cannot deserialize image from Data"
        }
    }
}

extension APICall {
    /// 由 baseURL + path 组成 URL 并构造 URLRequest
    func urlRequest(baseURL: String) throws -> URLRequest {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.allHTTPHeaderFields = headers
        request.httpBody = try body()
        return request
    }
}

/// HTTP 码辅助类型与常用范围
 typealias HTTPCode = Int
 typealias HTTPCodes = Range<HTTPCode>

extension HTTPCodes {
    static let success = 200 ..< 300
}
