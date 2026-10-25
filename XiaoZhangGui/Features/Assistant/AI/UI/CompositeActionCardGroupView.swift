import SwiftUI

// MARK: - V3.9.3 C · 复合意图确认卡组
//
// 一组待确认卡：每张卡独立确认 / 修改 / 取消（复用 ActionCardView），
// 顶部另有「一键确认全部」——先展示完整明细（卡片本身即明细），
// 再按列出顺序执行；单项失败隔离、部分失败在汇总消息中明确反馈。
// 布局复用 V371 语言：不覆盖键盘与底部安全区（由父级 ScrollView + safeAreaInset 保证）。
struct CompositeActionCardGroupView: View {
    let proposalIDs: [UUID]
    let proposals: [UUID: ActionProposal]
    let onConfirmAll: () -> Void
    let onConfirm: (UUID) -> Void
    let onModify: (UUID) -> Void
    let onCancel: (UUID) -> Void

    private var hasActionableCard: Bool {
        proposalIDs.contains { id in
            guard let proposal = proposals[id] else { return false }
            return proposal.status == .pending || proposal.status == .failed
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(V371.Colors.orange)
                Text("共 \(proposalIDs.count) 项，逐项确认或一键确认全部")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("共 \(proposalIDs.count) 项待确认")

            ForEach(proposalIDs, id: \.self) { id in
                if let proposal = proposals[id] {
                    ActionCardView(
                        proposal: proposal,
                        onConfirm: { onConfirm(id) },
                        onModify: { onModify(id) },
                        onCancel: { onCancel(id) }
                    )
                }
            }

            Button(action: onConfirmAll) {
                Text("一键确认全部")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasActionableCard)
            .accessibilityLabel("一键确认全部")
            .accessibilityIdentifier("ai.composite.confirmAll")
            .accessibilityHint("按列出顺序逐项执行，已处理过的项会跳过不重复写入")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ai.composite-group")
    }
}
