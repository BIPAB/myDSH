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
    @ObservationIgnored private var generation: String?

    /// 本机引擎（原逻辑）：generation 用引擎重启序号
    func connect(to url: URL, generation current: Int) async {
        await connect(to: url, generation: "local-\(current)")
    }

    /// 远程设备：generation 用设备 id，换设备就会重建
    func connect(remote device: Device) async {
        guard let url = device.launchURL else { return }
        await connect(to: url, generation: "remote-\(device.id)")
    }

    private func connect(to url: URL, generation current: String) async {
        guard current != generation else { return }
        generation = current
        app = nil                      // 先把旧连接摘掉，界面会回到"正在连接…"
        let model = AppModel(launchURL: url)
        await model.connect()
        if current == generation { app = model }
    }
}

struct RootView: View {
    let session: String?
    @EnvironmentObject private var engine: NodeEngine
    @EnvironmentObject private var devices: DeviceStore
    @AppStorage(ThemePreference.key) private var themePreference = ThemePreference.system
    private let connection = EngineConnection.shared
    /// dsh://devices 打开设备面板（模拟器里点不了界面，用它来验证）
    @State private var showDevices = false

    var body: some View {
        content
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
                if let app = connection.app {
                    MainView(session: session)
                        .environment(app)
                        .environmentObject(devices)
                        .overlay(alignment: .topTrailing) { DeviceChip(store: devices).padding(.top, 56) }
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
