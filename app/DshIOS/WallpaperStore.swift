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
        // 模拟器验证用：DSH_WALLPAPER=1 时临时生成一张花哨的图（不落盘）
        if image == nil,
           ProcessInfo.processInfo.environment["DSH_WALLPAPER"] == "1" {
            image = Self.makeTestWallpaper()
        }
        UserDefaults.standard.set(image != nil, forKey: Self.flagKey)
    }

    /// 只为截图验证：一张有明显图案的壁纸，用来看材质气泡够不够清楚。
    private static func makeTestWallpaper() -> UIImage? {
        let size = CGSize(width: 1200, height: 2400)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [UIColor(red: 0.15, green: 0.35, blue: 0.85, alpha: 1).cgColor,
                          UIColor(red: 0.85, green: 0.25, blue: 0.45, alpha: 1).cgColor,
                          UIColor(red: 0.95, green: 0.65, blue: 0.15, alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray, locations: [0, 0.55, 1])!
            ctx.cgContext.drawLinearGradient(gradient, start: .zero,
                                             end: CGPoint(x: size.width, y: size.height), options: [])
            // 一堆圆点，模拟"花背景"
            for i in 0..<40 {
                let r = CGFloat(20 + (i * 37) % 90)
                let x = CGFloat((i * 311) % Int(size.width))
                let y = CGFloat((i * 547) % Int(size.height))
                UIColor.white.withAlphaComponent(0.18).setFill()
                ctx.cgContext.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
            }
        }
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
