import SwiftUI

/// V3.8 重建 · Home 生产级 AI 胶囊。
///
/// V3.9.1 P1-5:一次点击直接打开现有 AIChatView,不再有「展开 → 再点输入行」
/// 的中间步骤;不建第二条 AI Provider/ToolExecutor 链;输入行点击后打开现有 AI Sheet。
/// 旧两步契约(v38.home.ai.expand / collapse)随本轮废止,UI 测试已同步改为单步。
struct V38HomeAICapsule: View {
    /// 用户点击胶囊:打开真实 AI Sheet(由宿主将 `showAI` 置 true)。
    var onOpenAI: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: onOpenAI) {
            V38HomeGlassSurface(radius: 27) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.tint)
                    // V3.8.1 P0-4:胶囊标题单行,大字号下等比缩放不换行。
                    Text("问小掌柜…")
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 56)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("v38.home.ai.openSheet")
        .accessibilityLabel("打开问小掌柜 AI 助手")
    }
}
