import Foundation

/// 远程版：引擎跑在用户自己的电脑上，App 里不再启动 Node。
///
/// 保留和原版完全一样的对外接口（`phase` / `runningSince` / `stalled` /
/// `startedAt` / `logFile` / `start()`），这样 `Views/`、`BackgroundKeeper`、
/// `LiveActivityController` 里那些引用一行都不用改。
///
/// `RootView` 在有远程设备时根本不会读 `phase`（它走另一条分支），
/// 所以这里停在 `.starting` 也不会卡住界面。
@MainActor
final class NodeEngine: ObservableObject {
    enum Phase: Equatable {
        case starting
        case running(URL, generation: Int)
        case exited(Int32)
    }

    static let shared = NodeEngine()

    @Published private(set) var phase: Phase = .starting
    @Published private(set) var runningSince: Date?
    @Published private(set) var stalled = false
    @Published private(set) var startedAt: Date?

    private init() {}

    var logFile: URL { EnginePaths.real(EnginePaths.shared + "/engine.log") }

    /// 远程模式下不启动任何引擎。本机模式在改造版入口里被显式关掉了。
    func start() {
        startedAt = startedAt ?? Date()
    }
}
