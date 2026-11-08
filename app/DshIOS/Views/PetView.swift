import SwiftUI
import UIKit
import ImageIO

/// 像素桌宠：四张循环动画 GIF，按当前状态切换。
///
/// SwiftUI 的 Image 不放 GIF 动画，所以用 UIViewRepresentable 包一个 UIImageView，
/// 由 ImageIO 把 GIF 的每一帧解成 UIImage.animatedImage。
enum PetState: String, CaseIterable {
    case typing        // 敲代码：正在跑
    case notification  // 等你确认：有待处理的审批/提问
    case sleeping      // 睡觉：闲置
    case happy         // 完成：刚跑完

    var file: String {
        switch self {
        case .typing: "pet-girl-typing-zh-light"
        case .notification: "pet-girl-notification-zh-light"
        case .sleeping: "pet-girl-sleeping-zh-light"
        case .happy: "pet-girl-happy-zh-light"
        }
    }
}

private enum PetImages {
    // GIF 只解一次，四张轮流用
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
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        if view.image !== PetImages.image(for: state) {
            view.image = PetImages.image(for: state)
        }
        view.startAnimating()
    }
}

/// 桌宠本体：对话区右下角、输入框上方。
struct PetView: View {
    let state: PetState
    var size: CGFloat = 72

    var body: some View {
        GIFView(state: state)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .transition(.opacity)
    }
}
