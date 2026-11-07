import SwiftUI

/// 设备切换面板。
///
/// 样式对齐我们 Web 版那套「选择设备」底部面板：标题 + 关闭 + 三行设备，
/// 每行带图标、名字，右边是「当前 / 在线 / 离线」。
/// 在线状态用 `HEAD <origin>/dsh-pocket/icon-192.png` 探活（桥的静态资源，
/// 只要那台电脑的桥和隧道活着就会 200），和 Web 版 `/__ping/` 等价。
struct DeviceSwitcher: View {
    @EnvironmentObject private var store: DeviceStore
    @Environment(\.dismiss) private var dismiss

    /// 一台设备的探活状态
    enum Status: Equatable { case unknown, online, offline }

    @State private var status: [String: Status] = [:]
    @State private var pollTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("选择设备").font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            ForEach(store.devices) { device in
                row(device)
                if device.id != store.devices.last?.id {
                    Divider().padding(.leading, 56)
                }
            }

            Button {
                store.restoreDefaults()
            } label: {
                Text("恢复默认三台").font(.footnote).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            status = [:]
            probeAll()
            pollTask = Task {
                // 面板开着时每 10 秒重测一次，和 Web 版一致
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 10_000_000_000)
                    probeAll()
                }
            }
        }
        .onDisappear { pollTask?.cancel() }
    }

    @ViewBuilder
    private func row(_ device: Device) -> some View {
        let isCurrent = device.id == store.currentID
        Button {
            store.select(device)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: device.id == "pc3" ? "cloud" : "desktopcomputer")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(device.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.green)
                } else {
                    badge(status[device.id] ?? .unknown)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func badge(_ s: Status) -> some View {
        switch s {
        case .unknown:
            Text("…").font(.caption2).foregroundStyle(.secondary)
        case .online:
            Text("在线")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.green.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.green)
        case .offline:
            Text("离线")
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(Color.gray.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(.secondary)
        }
    }

    private func probeAll() {
        for device in store.devices {
            guard let url = URL(string: device.origin + "/dsh-pocket/icon-192.png") else { continue }
            var req = URLRequest(url: url)
            req.httpMethod = "HEAD"
            req.timeoutInterval = 6
            req.cachePolicy = .reloadIgnoringLocalCacheData
            URLSession.shared.dataTask(with: req) { _, resp, _ in
                let ok = (resp as? HTTPURLResponse).map { (200..<400).contains($0.statusCode) } ?? false
                Task { @MainActor in
                    status[device.id] = ok ? .online : .offline
                }
            }.resume()
        }
    }
}

/// 贴在界面右边缘的小胶囊，显示当前设备名，点开就是设备面板。
///
/// 放 overlay 用，不插进 fish-pocket 自己的布局里——它的 header 结构复杂，
/// 从外面加一个浮层比改它的视图安全得多。
struct DeviceChip: View {
    @ObservedObject var store: DeviceStore
    @State private var open = false

    var body: some View {
        Button {
            open = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: store.current.id == "pc3" ? "cloud" : "desktopcomputer")
                    .font(.system(size: 11, weight: .medium))
                Text(store.current.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .padding(.trailing, 6)
        .sheet(isPresented: $open) {
            DeviceSwitcher().environmentObject(store)
                .presentationDetents([.height(300), .medium])
                .presentationDragIndicator(.visible)
        }
    }
}
