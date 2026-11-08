import SwiftUI

/// 桌宠调试页（仅用于截图验证尺寸/位置，不影响正常使用）。
///
/// 用 `-dshPetDemo 1` 启动即可进入。它把真实布局照搬一遍：
/// 底部是"假输入框"，上方是桌宠占的那一行 —— 和 ConversationView 里的结构一致，
/// 所以截图里的比例就是真机上的比例。不连服务器、不依赖任何会话。
struct PetDemoView: View {
    /// 可以一次看多个尺寸，方便挑
    private let sizes: [CGFloat] = [56, 64, 68, 76, 88]

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            sizesRow
            Spacer(minLength: 0)
            productionRow
            fakeComposer
        }
        .background(Palette.background)
    }

    private var header: some View {
        Text("桌宠尺寸/位置调试")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Palette.secondary)
            .padding(.top, 8)
    }

    /// 一排不同尺寸，选一个
    private var sizesRow: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(sizes, id: \.self) { size in
                    VStack(spacing: 2) {
                        PetView(state: .idle, size: size)
                        Text("\(Int(size))")
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.secondary)
                    }
                }
            }
            Text("↑ 同一张图在不同 size 下的实际大小")
                .font(.system(size: 9))
                .foregroundStyle(Palette.secondary)
        }
        .padding(.bottom, 12)
    }

    /// 正式布局的样子：68pt、右对齐、踩在输入框上沿
    private var productionRow: some View {
        HStack(alignment: .bottom) {
            Spacer(minLength: 0)
            PetView(state: .idle, size: 68)
                .padding(.trailing, 16)
                .padding(.bottom, 2)
        }
    }

    private var fakeComposer: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Palette.secondary)
            Text("发消息…")
                .font(.subheadline)
                .foregroundStyle(Palette.secondary)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(Palette.secondary.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Palette.field, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}
