//
//  ImageWebRepository.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 09.11.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import Combine
import UIKit

/**
 * ImagesWebRepository - 图片下载仓库
 * 
 * 职责：
 * - 从给定 URL 拉取图片数据，转为 UIImage 返回
 * - 不依赖 baseURL，直接对外部资源进行下载
 * 
 * 关键点：
 * - 使用 URLSession.download(from:) 避免大图占用过多内存
 * - Data → UIImage 失败时抛出 APIError.imageDeserialization
 * 
 * 小例子：
 * let repo = RealImagesWebRepository(session: .shared)
 * let image = try await repo.loadImage(url: URL(string: "https://.../flag.jpg")!)
 */
protocol ImagesWebRepository: WebRepository {
    func loadImage(url: URL) async throws -> UIImage
}

struct RealImagesWebRepository: ImagesWebRepository {

    let session: URLSession
    let baseURL: String
    
    init(session: URLSession) {
        self.session = session
        self.baseURL = ""
    }
    
    /// 下载远程图片并反序列化为 UIImage
    func loadImage(url: URL) async throws -> UIImage {
        let (localURL, _) = try await session.download(from: url)
        let data = try Data(contentsOf: localURL)
        guard let image = UIImage(data: data) else {
            throw APIError.imageDeserialization
        }
        return image
    }
}
