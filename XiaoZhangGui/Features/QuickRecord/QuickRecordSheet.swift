import SwiftUI
import SwiftData

struct QuickRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var draft: QuickRecordDraft?
    @State private var savedMessage: String?

    private let parser = LocalQuickRecordParser()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                inputCard
                if let draft { resultCard(draft) }
                if let savedMessage {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(V32.brand)
                        Text(savedMessage).v32Text(.body).foregroundStyle(V32.textSecondary)
                    }
                }
                V32PrimaryButton(title: "写入", systemName: "square.and.pencil") { commit() }
                    .disabled(draft == nil)
                    .opacity(draft == nil ? 0.5 : 1)
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.medium, .large])
    }

    private var header: some View {
        ZStack {
            Text("快速记录").v32Text(.headline).foregroundStyle(V32.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("一句话")
            V32Card {
                TextField("例如：今天营业额2680", text: $text, axis: .vertical)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
                    .lineLimit(3...6)
            }
            Text("本地规则识别，写入现有待办 / 配送 / 临时商品 / 业绩 / 记录。")
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
        }
    }

    private func resultCard(_ draft: QuickRecordDraft) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("识别结果")
            V32Card {
                VStack(spacing: 0) {
                    resultRow("类型", value: kindLabel(draft.kind))
                    divider
                    resultRow("摘要", value: draft.summary)
                    if let amount = draft.amount {
                        divider
                        resultRow("金额", value: Fmt.money(amount))
                    }
                    if let date = draft.date {
                        divider
                        resultRow("时间", value: Fmt.dateTime(date))
                    }
                }
            }
        }
    }

    private func resultRow(_ label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).v32Text(.subhead).foregroundStyle(V32.textTertiary)
            Spacer(minLength: 12)
            Text(value).v32Text(.body).foregroundStyle(V32.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(V32.divider).frame(height: 1)
    }

    private func kindLabel(_ kind: QuickRecordKind) -> String {
        switch kind {
        case .performance: return "业绩"
        case .todo: return "待办"
        case .customer: return "客户配送"
        case .expiry: return "临时商品"
        case .memo: return "记录"
        }
    }

    private func commit() {
        guard let draft else { return }
        do {
            switch draft.kind {
            case .performance:
                try PerformanceRepository(context: context).add(
                    amount: draft.amount ?? 0,
                    note: draft.note,
                    date: draft.date ?? Date()
                )
            case .todo:
                try TodoRepository(context: context).add(
                    title: draft.title,
                    detail: "",
                    dueDate: draft.date
                )
            case .customer:
                try CustomerRepository(context: context).add(
                    customer: draft.customer ?? "",
                    roomOrAddress: "",
                    phone: "",
                    content: draft.title
                )
            case .expiry:
                try ExpiryRepository(context: context).add(
                    name: draft.title,
                    quantity: draft.quantity ?? 1,
                    expiryDate: draft.date ?? Date()
                )
            case .memo:
                try MemoRepository(context: context).add(title: draft.title, content: draft.note)
            }
            Haptic.success()
            savedMessage = "已写入\(kindLabel(draft.kind))"
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { dismiss() }
        } catch {
            Haptic.error()
        }
    }
}
