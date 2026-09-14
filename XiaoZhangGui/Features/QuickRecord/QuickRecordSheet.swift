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
        NavigationStack {
            Form {
                Section {
                    TextField("例如：今天营业额2680", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: text) { _, value in
                            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                            draft = trimmed.isEmpty ? nil : parser.parse(trimmed)
                        }
                } header: {
                    Text("一句话")
                } footer: {
                    Text("本地规则识别，写入现有待办 / 配送 / 临时商品 / 业绩 / 记录。")
                }

                if let draft {
                    Section("识别结果") {
                        LabeledContent("类型", value: kindLabel(draft.kind))
                        LabeledContent("摘要", value: draft.summary)
                        if let amount = draft.amount {
                            LabeledContent("金额", value: Fmt.money(amount))
                        }
                        if let date = draft.date {
                            LabeledContent("时间", value: Fmt.dateTime(date))
                        }
                    }
                }

                if let savedMessage {
                    Section { Text(savedMessage).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle("快速记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("写入") { commit() }
                        .disabled(draft == nil)
                }
            }
        }
        .presentationDetents([.medium, .large])
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
