import SwiftUI
import SwiftData

// MARK: - 记收入/记支出 编辑器（sheet）

struct MoneyEditorSheet: View {
    enum Mode {
        case new(NewMoneyKind)
        case editPerformance(Performance)
        case editExpense(Expense)
    }

    let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var amountText = ""
    @State private var note = ""
    @State private var category = "其他"
    @State private var date = Date()

    private var kind: MoneyRecord.Kind {
        switch mode {
        case .new(let k): return k == .income ? .income : .expense
        case .editPerformance: return .income
        case .editExpense: return .expense
        }
    }

    private var title: String {
        switch mode {
        case .new(.income): return "记一笔收入"
        case .new(.expense): return "记一笔支出"
        case .editPerformance: return "编辑收入"
        case .editExpense: return "编辑支出"
        }
    }

    private var amount: Double? {
        let cleaned = amountText.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 6) {
                        Text("¥")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(AppTheme.palette(named: settings.appThemeName).accent)
                        TextField("0.00", text: $amountText)
                            .font(.system(size: 40, weight: .bold))
                            .keyboardType(.decimalPad)
                            .foregroundColor(V21.textPrimary)
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField(
                        kind == .income ? "备注（选填）" : "备注（选填，如：进了两箱可乐）",
                        text: $note,
                        prompt: Text(kind == .income ? "备注（选填）" : "备注（选填）")
                    )
                    .foregroundColor(V21.textPrimary)

                    if kind == .expense {
                        Picker("分类", selection: $category) {
                            ForEach(["进货", "房租", "水电", "人工", "其他"], id: \.self) { Text($0) }
                        }
                    }

                    DatePicker("日期", selection: $date, displayedComponents: .date)
                } header: {
                    Text("明细")
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .foregroundColor(V21.textTertiary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(amount == nil)
                }
            }
            .onAppear(perform: loadEditing)
        }
        .presentationDetents([.medium, .large])
    }

    private func loadEditing() {
        switch mode {
        case .new:
            break
        case .editPerformance(let p):
            amountText = p.amount == p.amount.rounded(.towardZero)
                ? String(Int(p.amount))
                : String(p.amount)
            note = p.note
            date = p.date
        case .editExpense(let e):
            amountText = e.amount == e.amount.rounded(.towardZero)
                ? String(Int(e.amount))
                : String(e.amount)
            note = e.note
            category = e.category
            date = e.date
        }
    }

    private func save() {
        guard let amount else { return }
        do {
            switch mode {
            case .new(let k):
                if k == .income {
                    try PerformanceRepository(context: context).add(amount: amount, note: note, date: date)
                } else {
                    try ExpenseRepository(context: context).add(amount: amount, category: category, note: note, date: date)
                }
            case .editPerformance(let p):
                p.amount = amount
                p.note = note
                p.date = date
                try PerformanceRepository(context: context).update(p)
            case .editExpense(let e):
                e.amount = amount
                e.note = note
                e.category = category
                e.date = date
                try ExpenseRepository(context: context).update(e)
            }
            Haptic.success()
            dismiss()
        } catch {
            Haptic.error()
        }
    }
}

extension Haptic {
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
