import SwiftUI

/// 启动过程中的等待界面。
///
/// 上游 main 分支里 `DshIOSApp.swift` 引用了 `StartupView` 和 `EngineTrouble`，
/// 但这两个类型在仓库里并不存在（可能是重构到一半，或者提交时漏了文件），
/// 导致**原样编译必然失败**。这里按调用处反推出签名补齐。
///
/// 调用处（原 DshIOSApp.swift）：
///   StartupView(message: String(localized: "正在连接…"))
///   EngineTrouble(headline: String, since: Date?, logFile: URL)
struct StartupView: View {
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}

/// 引擎/连接出问题时的界面：一句话 + 从什么时候开始 + 日志在哪儿。
///
/// 远程模式下这个界面基本用不到（连不上会显示 DeviceSwitcher 里的离线状态），
/// 但入口文件引用了它，必须存在。
struct EngineTrouble: View {
    let headline: String
    let since: Date?
    let logFile: URL

    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(.orange)

            Text(headline)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let since {
                Text("从 \(since.formatted(date: .omitted, time: .standard)) 开始")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text(logFile.path)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .lineLimit(3)
                .truncationMode(.middle)

            HStack(spacing: 12) {
                Button {
                    UIPasteboard.general.string = logFile.path
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { copied = false }
                } label: {
                    Label(copied ? "已复制" : "复制日志路径", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)

                ShareLink(item: logFile) {
                    Label("分享日志", systemImage: "square.and.arrow.up")
                        .font(.footnote)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemBackground))
    }
}
