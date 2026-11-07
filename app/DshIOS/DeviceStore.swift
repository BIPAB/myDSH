import Foundation

/// 一台电脑上的 DSH。
///
/// fish-pocket 原本只认一个 `launchURL`（App 内 Node 引擎的 `http://127.0.0.1:<port>/?token=…`）。
/// 远程模式下我们给它别的东西：家里三台电脑的反向代理地址 + 配对码。
///
/// 认证方式和 fish-pocket 现有实现完全一致：
///   `GET <origin>/?k=<key>` → 302 + `Set-Cookie: dshp=…`（App 不跟随重定向，自己读 header）
///   → 之后每个请求带 `Cookie: dshp=…`
struct Device: Identifiable, Codable, Hashable {
    /// 稳定 id，用于记住"上次用的那台"
    let id: String
    /// 显示名（顶部胶囊上显示这个）
    var name: String
    /// 设备地址，例如 `https://dsh.spqrbipab.site:8443`
    var origin: String
    /// 配对码（三台共用同一个，仍逐台存着，方便以后换）
    var key: String

    /// 拼出给 `EngineClient(launchURL:)` 用的地址
    var launchURL: URL? {
        guard var c = URLComponents(string: origin) else { return nil }
        c.queryItems = [URLQueryItem(name: "k", value: key)]
        return c.url
    }
}

/// 设备列表与选择状态的持久化。
///
/// 只做两件事：存三台机器的地址；记住上次选的是哪台。
/// 不碰引擎、不碰会话——切换设备后由上层重建 `EngineClient`。
@MainActor
final class DeviceStore: ObservableObject {
    static let shared = DeviceStore()

    /// 默认三台。配对码三台统一（我们服务端已经统一成 9MJ52DQX）。
    static let presets: [Device] = [
        Device(id: "pc1", name: "沫雨",           origin: "https://dsh.spqrbipab.site:8443", key: "9MJ52DQX"),
        Device(id: "pc2", name: "DESKTOP-M1P9A8G", origin: "https://dsh.spqrbipab.site:5173", key: "9MJ52DQX"),
        Device(id: "pc3", name: "云电脑",          origin: "https://dsh.spqrbipab.site:8444", key: "9MJ52DQX"),
    ]

    private let devicesKey = "fishpocket.devices"
    private let currentKey = "fishpocket.currentDevice"

    @Published var devices: [Device]
    @Published var currentID: String

    init() {
        let saved = UserDefaults.standard.data(forKey: devicesKey)
            .flatMap { try? JSONDecoder().decode([Device].self, from: $0) }
        devices = saved?.isEmpty == false ? saved! : DeviceStore.presets
        currentID = UserDefaults.standard.string(forKey: currentKey)
            ?? devices.first?.id
            ?? "pc1"
        if !devices.contains(where: { $0.id == currentID }) {
            currentID = devices.first?.id ?? "pc1"
        }
    }

    var current: Device {
        devices.first { $0.id == currentID } ?? devices[0]
    }

    /// 这台设备能不能直接连（拼 URL 用）
    var currentLaunchURL: URL? { current.launchURL }

    func select(_ device: Device) {
        currentID = device.id
        UserDefaults.standard.set(device.id, forKey: currentKey)
    }

    func update(_ device: Device) {
        guard let i = devices.firstIndex(where: { $0.id == device.id }) else { return }
        var next = devices
        next[i] = device
        devices = next
        if let data = try? JSONEncoder().encode(next) {
            UserDefaults.standard.set(data, forKey: devicesKey)
        }
    }

    func restoreDefaults() {
        devices = DeviceStore.presets
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: devicesKey)
        }
        currentID = devices[0].id
        UserDefaults.standard.set(currentID, forKey: currentKey)
    }
}
