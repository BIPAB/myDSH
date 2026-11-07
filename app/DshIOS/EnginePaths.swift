import Foundation

/// 远程版：不再有「引擎的文件系统视图」。
///
/// 原版把 Node 引擎关在 native/root 里跑（`dsh_root_install` 是那个 C 框架提供的符号），
/// 所以路径要在「引擎视角」和「沙盒视角」之间换算。远程模式下没有引擎，
/// 这个换算层就没意义了——但 `FilesView`、`ConfigDocumentView`、`PluginInstallView`
/// 等界面还在用它，所以保留同名 API，只是全部指向沙盒里的真实路径。
///
/// ⚠️ 关键改动：删掉了 `@_silgen_name("dsh_root_install")`。
/// 那个符号来自已删除的 `DshRoot` framework，留着会**链接失败**（undefined symbol），
/// 即使 `install()` 一次都不调用。
enum EnginePaths {
    static let home = "/home/dsh"
    static let documents = "/home/dsh/Documents"
    /// `DSH_IOS_DATA`：原来是宿主与引擎共享的目录。
    static let shared = "/home/dsh/.ios"
    /// 引擎入口，远程模式下没有；保留常量以免别处引用报错。
    static let script = "/opt/dsh/nodejs-project/main.mjs"
    private static let bundle = "/opt/dsh"

    /// App 自己的数据目录（沙盒内，真实可用）。
    static let data = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("dsh-ios", isDirectory: true)
    private static let root = data.appendingPathComponent("root", isDirectory: true)

    /// 远程模式下 `$DSH_HOME` 指的是本机沙盒里的一份（只用于缓存/日志）。
    static var dshHome: URL { real("/home/dsh/.dsh") }

    /// 没有引擎要装，直接成功。
    static func install() -> Bool {
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return true
    }

    /// 引擎路径 → 沙盒路径（远程模式下就是直接拼到 sandbox 里）。
    static func real(_ path: String) -> URL {
        if path == bundle || path.hasPrefix(bundle + "/") {
            return URL(fileURLWithPath: Bundle.main.bundlePath + path.dropFirst(bundle.count))
        }
        return root.appendingPathComponent(path)
    }
}
