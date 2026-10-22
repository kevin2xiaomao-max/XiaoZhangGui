import SwiftUI

/// V3.8 重建 · 分类 Chip 选择器（经营页：图表周期 / 收入分类共用）。
///
/// 动效（Worker C 规格 §4）：选中态背景以 `matchedGeometryEffect` 在 chip 间
/// 滑动（expand spring）；Reduce Motion 时 `V38MotionTokens` 返回 nil，直接终态。
///
/// 无障碍注意（Worker B 实证）：identifier 只挂在每个 chip 按钮本身，
/// 绝不挂在容器上，避免 iOS 27 无障碍树遮蔽子按钮。
struct V38ChipSelector<Option: Hashable & Identifiable>: View where Option.ID == String {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    let identifier: (Option) -> String

    @Namespace private var chipNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            ForEach(options, id: \.id) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(V38MotionTokens.animation(for: .expand, reduceMotion: reduceMotion)) {
                        selection = option
                    }
                } label: {
                    Text(title(option))
                        .font(V38PerformanceStyle.chipLabel)
                        .foregroundStyle(isSelected ? .white : .primary)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(V38PerformanceStyle.accent)
                                    .matchedGeometryEffect(id: "v38.chip.selection", in: chipNamespace)
                            } else {
                                Capsule()
                                    .fill(V371.Colors.groupSecondary)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier(option))
                .accessibilityLabel(title(option))
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
            }
            Spacer(minLength: 0)
        }
    }
}
