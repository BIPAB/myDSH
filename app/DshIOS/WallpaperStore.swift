import UIKit
import SwiftUI

/// 自定义壁纸。
///
/// 设计要点：
/// · 图片存在 App 沙盒里（不放 UserDefaults，图可能几 MB）
/// · 只记录「有没有壁纸」和图片本身，不改任何文字颜色 —— 气泡用的是材质，
///   会自动模糊背景并自适应明暗，所以壁纸再花也不会影响可读性
/// · 关掉壁纸就是删文件，界面立刻回到纯色背景
@MainActor
final class WallpaperStore: ObservableObject {
    static let shared = WallpaperStore()

    /// 有图就表示开着。nil = 没有壁纸。
    @Published private(set) var image: UIImage?

    private static var fileURL: URL {
        let dir = EnginePaths.data.appendingPathComponent("wallpaper", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("current.jpg")
    }

    var enabled: Bool { image != nil }

    /// 供 Palette 读取的标记（UserDefaults 是非隔离的，避免在 Color 计算里碰 MainActor）
    static let flagKey = "wallpaper.enabled"

    private init() {
        image = Self.loadFromDisk()
        UserDefaults.standard.set(image != nil, forKey: Self.flagKey)
    }

    private static func loadFromDisk() -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)?.preparingThumbnail(of: CGSize(width: 1200, height: 1200))
            ?? UIImage(data: data)
    }

    /// 选一张图。会压到最大 1200px、JPEG 质量 0.85，原图 10 MB 也只剩几百 KB。
    func set(_ picked: UIImage) {
        let resized = picked.preparingThumbnail(of: CGSize(width: 1200, height: 1200)) ?? picked
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
        image = resized
        UserDefaults.standard.set(true, forKey: Self.flagKey)
    }

    func clear() {
        try? FileManager.default.removeItem(at: Self.fileURL)
        image = nil
        UserDefaults.standard.set(false, forKey: Self.flagKey)
    }
}

/// 铺在最底层的壁纸。没有壁纸时什么都不画（露出原来的纯色背景）。
struct WallpaperLayer: View {
    @ObservedObject var store: WallpaperStore

    var body: some View {
        GeometryReader { proxy in
            if let image = store.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.18))   // 压一点亮度，让材质气泡更清楚
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
    }
}
