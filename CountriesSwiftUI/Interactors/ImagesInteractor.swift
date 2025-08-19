//
//  ImagesInteractor.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 09.11.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

/**
 * ImagesInteractor - 图片加载用例
 * 
 * 职责：
 * - 作为“业务交互器”，封装图片加载流程，对上层只暴露一个统一方法 load(image:url:)
 * - 结合 Loadable/LoadableSubject，将图片的加载状态（未请求/加载中/成功/失败）与数据（UIImage）统一管理
 * 
 * 设计要点：
 * - 若 URL 为空：直接将状态置为 .notRequested（视图可选择显示占位图）
 * - 若 URL 存在：调用 image.load { await webRepository.loadImage(url:) }，自动处理状态流转
 * 
 * 小例子（在 SwiftUI 视图中使用）：
 *   @State private var imageState: Loadable<UIImage> = .notRequested
 *   let subject = LoadableSubject(wrappedValue: imageState)
 *   imagesInteractor.load(image: subject, url: URL(string: "https://example.com/a.png"))
 *   → 触发后 imageState 会经历：.isLoading → .loaded(UIImage) 或 .failed(Error)
 */

protocol ImagesInteractor {
    /// 加载远程图片，并通过 LoadableSubject 反馈状态与结果
    func load(image: LoadableSubject<UIImage>, url: URL?)
}

struct RealImagesInteractor: ImagesInteractor {
    
    let webRepository: ImagesWebRepository
    
    init(webRepository: ImagesWebRepository) {
        self.webRepository = webRepository
    }
    
    /// 启动加载流程：无URL则重置状态，有URL则发起网络请求
    func load(image: LoadableSubject<UIImage>, url: URL?) {
        guard let url else {
            image.wrappedValue = .notRequested; return
        }
        image.load {
            try await webRepository.loadImage(url: url)
        }
    }
}

/// 空实现（用于预览/测试或占位）
struct StubImagesInteractor: ImagesInteractor {
    func load(image: LoadableSubject<UIImage>, url: URL?) {
    }
}
