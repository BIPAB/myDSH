import SwiftUI
import UIKit
import ImageIO

/// 鲸娘像素桌宠。
///
/// 素材来自 https://dshtui.com/pets/whale-girl-emoji/ —— 22 个透明底循环 GIF，
/// 每张 552×528（最近邻放大 8 倍的像素画）。这里只取当前用得到的几个状态，
/// 其余留在 Resources/pets/gifs 里，以后要加直接扩 enum 就行。
///
/// SwiftUI 的 Image 不放 GIF 动画，所以用 UIViewRepresentable 包 UIImageView，
/// 由 ImageIO 把 GIF 每帧解成 UIImage.animatedImage，帧时长用 GIF 自带的元数据。
enum PetState: String, CaseIterable {
    case idle          // 待机眨眼
    case thinking      // 思考中
    case typing        // 敲代码（正在跑）
    case notification  // 需要你确认
    case happy         // 任务完成
    case error         // 出错了
    case sleeping      // 呼呼大睡

    /// Resources/pets/gifs 里的文件名（不含扩展名）
    var file: String {
        switch self {
        case .idle: "01-idle"
        case .thinking: "04-thinking"
        case .typing: "05-typing"
        case .notification: "11-notification"
        case .happy: "10-happy"
        case .error: "09-error"
        case .sleeping: "14-sleeping"
        }
    }
}

private enum PetImages {
    // GIF 只解一次，之后复用
    nonisolated(unsafe) static var cache: [String: UIImage] = [:]

    static func image(for state: PetState) -> UIImage? {
        if let hit = cache[state.file] { return hit }
        guard let url = Bundle.main.url(forResource: state.file, withExtension: "gif"),
              let data = try? Data(contentsOf: url),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }

        let count = CGImageSourceGetCount(source)
        var frames: [UIImage] = []
        var duration: Double = 0
        for i in 0..<count {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cg))
            if let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any],
               let gif = props[kCGImagePropertyGIFDictionary] as? [CFString: Any],
               let d = (gif[kCGImagePropertyGIFUnclampedDelayTime] ?? gif[kCGImagePropertyGIFDelayTime]) as? Double,
               d > 0.01 {
                duration += d
            } else {
                duration += 0.1
            }
        }
        guard !frames.isEmpty else { return nil }
        let image = UIImage.animatedImage(with: frames, duration: max(duration, 0.1))
        cache[state.file] = image
        return image
    }
}

private struct GIFView: UIViewRepresentable {
    let state: PetState

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        let next = PetImages.image(for: state)
        if view.image !== next {
            view.image = next
            view.startAnimating()
        }
    }

    /// 关键：不实现这个的话，SwiftUI 会按 UIImageView 的固有尺寸（GIF 原图 552×528）
    /// 去测量，外层的 .frame 只约束了容器，图片本身不缩小 —— 表现为桌宠铺满半屏。
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIImageView, context: Context) -> CGSize? {
        let side = min(proposal.width ?? 68, proposal.height ?? 68)
        return CGSize(width: side, height: side)
    }
}

/// 桌宠本体：对话区右下角、输入框上方。
struct PetView: View {
    let state: PetState
    var size: CGFloat = 84

    var body: some View {
        GIFView(state: state)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .animation(.easeInOut(duration: 0.2), value: state)
    }
}
