import SwiftUI

// 改造版 DshIOSApp.swift
// 改动最小化：不动 NodeEngine，也不动 EngineClient；
// 只在 RootView 的"引擎阶段"前面加一层判断——
//   · DeviceStore 有当前设备  → 远程模式，直接连那台电脑
//   · 没有                    → 回落到原本的本机 Node 引擎
//
// ⚠️ 本文件未经编译验证（当前环境无 Xcode），按 fish-pocket 0.2.x 的写法改的。

@main
struct DshIOSApp: App {
    static let window = "conversation"

    @StateObject private var engine = NodeEngine.shared
    @StateObject private var devices = DeviceStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 预热：它会写 "wallpaper.enabled" 标记，而 Palette.background 在视图求值时
        // 就读这个标记 —— 晚一步的话壁纸会被不透明背景盖住。
        _ = WallpaperStore.shared
    }

    var body: some Scene {
        WindowGroup(id: Self.window, for: SessionWindow.self) { $window in
            RootView(session: window?.session)
                .environmentObject(engine)
                .environmentObject(devices)
                .onAppear {
                    // 远程模式不需要启动本机引擎；从远程切回本机时才启动
                    if devices.currentLaunchURL == nil { engine.start() }
                }
        }
        .commands { ShellCommands() }
        .onChange(of: scenePhase) { _, phase in
            BackgroundKeeper.shared.scenePhaseChanged(to: phase)
            LiveActivityController.shared.scenePhaseChanged(to: phase)
        }
    }
}

struct SessionWindow: Codable, Hashable {
    var session: String
    var token = UUID()
}

/// App 与「一台 DSH」之间的连接。
/// 原来只有本机引擎一种来源；现在多了一种来源（远程设备），
/// 所以用字符串 generation 区分——换设备时 generation 变了，连接会重建。
@MainActor
@Observable
final class EngineConnection {
    static let shared = EngineConnection()

    private(set) var app: AppModel?
    /// 连不上时的错误说明（人话），有值时界面显示错误页 + 重试按钮
    private(set) var error: String?
    @ObservationIgnored private var generation: String?
    @ObservationIgnored private var lastURL: URL?
    @ObservationIgnored private var lastCookie: String?

    /// 本机引擎（原逻辑）：generation 用引擎重启序号
    func connect(to url: URL, generation current: Int) async {
        await connect(to: url, extraCookie: nil, generation: "local-\(current)")
    }

    /// 远程设备：generation 用设备 id，换设备就会重建连接。
    /// 额外带上 dshdev=<dev>，服务端据此把请求路由到那台电脑（三台共用 8443 一个入口）。
    func connect(remote device: Device) async {
        guard let url = device.launchURL else { return }
        await connect(to: url, extraCookie: device.devCookie, generation: "remote-\(device.id)")
    }

    private func connect(to url: URL, extraCookie: String?, generation current: String) async {
        guard current != generation else { return }
        generation = current
        app = nil                      // 先把旧连接摘掉，界面会回到"正在连接…"
        error = nil
        lastURL = url
        lastCookie = extraCookie
        let model = AppModel(launchURL: url, extraCookie: extraCookie)
        // 截图验证专用：DSH_FIXTURE=1 时完全不连服务器，直接进界面，
        // 由 -dshOpen timeline 用本地假数据渲染对话页（避免跨境网络导致截图停在连接中）。
        // 两条通道都支持：启动参数 -dshFixture 1（UserDefaults，已验证可靠）
        // 或环境变量 DSH_FIXTURE=1。
        let fixtureMode = UserDefaults.standard.bool(forKey: "dshFixture")
            || ProcessInfo.processInfo.environment["DSH_FIXTURE"] == "1"
        if fixtureMode {
            app = model
            return
        }
        await model.connect()
        guard current == generation else { return }
        if let message = model.lastError {
            error = message              // 连不上：不留 app，界面显示错误页
        } else {
            app = model
        }
    }

    /// 错误页上的「重试」：重新连一次当前设备。
    func retry() async {
        guard let url = lastURL else { return }
        let generation = generation ?? ""
        self.generation = nil            // 允许同样的 generation 再连一次
        await connect(to: url, extraCookie: lastCookie, generation: generation)
    }
}

struct RootView: View {
    let session: String?
    @EnvironmentObject private var engine: NodeEngine
    @EnvironmentObject private var devices: DeviceStore
    @AppStorage(ThemePreference.key) private var themePreference = ThemePreference.system
    private let connection = EngineConnection.shared
    /// 打开设备面板。两个入口：
    ///   · 环境变量 DSH_SHOW_DEVICES=1（模拟器里没法点界面，靠它验证）
    ///   · dsh://devices 深链（真机可用；模拟器会弹系统确认框）
    @State private var showDevices = ProcessInfo.processInfo.environment["DSH_SHOW_DEVICES"] == "1"

    var body: some View {
        // 用 ZStack 明确层次：壁纸在最底层，界面盖在上面。
        // （之前用 .background 依赖求值顺序，壁纸可能被不透明背景顶掉。）
        ZStack {
            WallpaperLayer(store: WallpaperStore.shared)
            content
        }
        .background(WindowAppearance(style: ThemePreference.style(themePreference)))
            .sheet(isPresented: $showDevices) {
                DeviceSwitcher().environmentObject(devices)
                    .presentationDetents([.height(320), .medium])
                    .presentationDragIndicator(.visible)
            }
            .onOpenURL { url in
                if url.host == "devices" { showDevices = true }
            }
    }

    @ViewBuilder
    private var content: some View {
        if devices.currentLaunchURL != nil {
            // ---- 远程模式：不碰本机引擎 ----
            Group {
                if let message = connection.error {
                    EngineTrouble(
                        headline: message,
                        since: nil,
                        logFile: EnginePaths.data.appendingPathComponent("connect.log"),
                        retry: { Task { await connection.retry() } }
                    )
                    .environmentObject(devices)
                } else if let app = connection.app {
                    MainView(session: session)
                        .environment(app)
                        .environmentObject(devices)
                } else {
                    StartupView(message: String(localized: "正在连接 \(devices.current.name)…"))
                        .environmentObject(devices)
                }
            }
            .task(id: devices.currentID) { await connection.connect(remote: devices.current) }
        } else {
            // ---- 原本的本机引擎模式，原样保留 ----
            switch engine.phase {
            case .starting:
                if engine.stalled {
                    EngineTrouble(headline: String(localized: "引擎还没起来"), since: engine.startedAt, logFile: engine.logFile)
                } else {
                    StartupView(message: String(localized: "正在启动 DSH 引擎…"))
                }
            case .running(let url, let current):
                Group {
                    if let app = connection.app {
                        MainView(session: session)
                            .environment(app)
                            .environmentObject(devices)
                    } else {
                        StartupView(message: String(localized: "正在连接…"))
                            .environmentObject(devices)
                    }
                }
                .task(id: current) { await connection.connect(to: url, generation: current) }
            case .exited(let code):
                EngineTrouble(headline: String(localized: "引擎已退出（\(code)）"), since: nil, logFile: engine.logFile)
            }
        }
    }
}
