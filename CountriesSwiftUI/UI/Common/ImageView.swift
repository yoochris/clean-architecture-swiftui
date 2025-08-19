//
//  ImageView.swift
//  CountriesSwiftUI
//
//  Created by Alexey Naumov on 25.10.2019.
//  Copyright © 2019 Alexey Naumov. All rights reserved.
//

import SwiftUI
import Combine

/**
 * ImageView - 远程图片加载显示组件
 * 
 * 职责：
 * 1. 根据传入的 URL 异步加载图片数据，并显示加载/成功/失败三态 UI
 * 2. 通过 DIContainer 注入 ImagesInteractor，解耦视图与数据请求逻辑
 * 3. 使用 Loadable<UIImage> 表达状态机，避免额外的布尔状态变量
 * 4. 支持单测与预览：可在 init 时注入任意初始状态
 * 
 * 状态说明（Loadable<UIImage>）：
 * - notRequested：尚未发起请求，onAppear 时触发加载
 * - isLoading(last:cancelBag:)：正在加载（可持有上次成功值），用于展示进度
 * - loaded(image)：加载成功，展示图片
 * - failed(error)：加载失败，提示错误信息或替代视图
 * 
 * 小例子：
 * // 直接在视图中使用，默认状态 notRequested
 * ImageView(imageURL: URL(string: "https://example.com/image.png")!)
 * 
 * // 在预览或测试中注入已加载状态
 * ImageView(imageURL: url, image: .loaded(UIImage()))
 */
struct ImageView: View {
    
    private let imageURL: URL
    @Environment(\.injected) var injected: DIContainer // 依赖注入容器，提供 ImagesInteractor
    @State private var image: Loadable<UIImage>          // 图片加载状态机
    let inspection = Inspection<Self>()                  // 测试辅助（ViewInspector）
    
    init(imageURL: URL, image: Loadable<UIImage> = .notRequested) {
        self.imageURL = imageURL
        self._image = .init(initialValue: image)
    }
    
    var body: some View {
        content
            .onReceive(inspection.notice) { self.inspection.visit(self, $0) }
    }
    
    @ViewBuilder private var content: some View {
        switch image {
        case .notRequested:
            defaultView()
        case .isLoading:
            loadingView()
        case let .loaded(image):
            loadedView(image)
        case let .failed(error):
            failedView(error)
        }
    }
}

// MARK: - Side Effects

private extension ImageView {
    // 发起图片加载，委托给 ImagesInteractor
    func loadImage() {
        injected.interactors.images
            .load(image: $image, url: imageURL)
    }
}

// MARK: - Content

private extension ImageView {
    // 首次出现时触发加载
    func defaultView() -> some View {
        Text("").onAppear {
            self.loadImage()
        }
    }
    
    // 加载中占位
    func loadingView() -> some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
    }
    
    // 失败占位（可按需拓展为带重试按钮的样式）
    func failedView(_ error: Error) -> some View {
        Text("Unable to load image")
            .font(.footnote)
            .multilineTextAlignment(.center)
            .padding()
    }
    
    // 成功显示图片
    func loadedView(_ uiImage: UIImage) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}

#Preview {
    VStack {
        ImageView(imageURL: URL(string: "https://flagcdn.com/w640/us.jpg")!)
        ImageView(imageURL: URL(string: "https://flagcdn.com/w640/al.jpg")!)
        ImageView(imageURL: URL(string: "https://flagcdn.com/w640/ru.jpg")!)
    }
}
