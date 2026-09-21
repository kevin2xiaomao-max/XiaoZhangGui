import SwiftUI
import SwiftData

// MARK: - 记收入/记支出 编辑器（V32 sheet）

struct MoneyEditorSheet: View {
    enum Mode {
        case new(NewMoneyKind)
        case editPerformance(Performance)
        case editExpense(Expense)
    }

    let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var amountText = ""
    @State private var note = ""
    @State private var category = "其他"
    @State private var date = Date()
    @State private var incomeSource: IncomeSource = .store
    @State private var saveError: String?

    private let incomeSources: [IncomeSource] = IncomeSource.allCases

    private let expenseCategories = ["进货", "房租", "水电", "人工", "其他"]

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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                amountCard
                detailCard
                if kind == .income { incomeSourceCard }
                if kind == .expense { categoryCard }
                V32PrimaryButton(title: "保存", systemName: "checkmark") { save() }
                    .disabled(amount == nil)
                    .opacity(amount == nil ? 0.5 : 1)
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet([.medium, .large])
        .onAppear(perform: loadEditing)
        .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
            Button("重试") { save() }
            Button("取消", role: .cancel) { saveError = nil }
        } message: { Text(saveError ?? "请稍后重试") }
    }

    // MARK: 头部

    private var header: some View {
        ZStack {
            Text(title)
                .v32Text(.headline)
                .foregroundStyle(V32.textPrimary)
            HStack {
                Button("取消") { dismiss() }
                    .v32Text(.body)
                    .foregroundStyle(V32.textTertiary)
                Spacer()
            }
        }
    }

    // MARK: 金额

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(kind == .income ? "收入金额" : "支出金额")
                .v32Text(.caption)
                .foregroundStyle(V32.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("¥")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundStyle(V32.textSecondary)
                TextField("0.00", text: $amountText)
                    .font(V32Font.heroMoney)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
                    .keyboardType(.decimalPad)
                    .minimumScaleFactor(0.5)
            }
            Rectangle().fill(V32.brand.opacity(0.45)).frame(height: 2)
        }
        .padding(.top, 8)
    }

    // MARK: 明细

    private var detailCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("明细")
            V32FieldGroup {
                VStack(alignment: .leading, spacing: 12) {
                    TextField(kind == .income ? "备注（选填）" : "备注（选填，如：进了两箱可乐）", text: $note)
                        .v32Text(.body)
                        .foregroundStyle(V32.textPrimary)
                        .tint(V32.brand)
                    Rectangle().fill(V32.divider).frame(height: 1)
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                        .v32Text(.title)
                        .tint(V32.brand)
                }
            }
        }
    }

    // MARK: 分类

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("分类")
            V32SegmentedPicker(
                tabs: expenseCategories,
                selectionIndex: Binding(
                    get: { expenseCategories.firstIndex(of: category) ?? expenseCategories.count - 1 },
                    set: { category = expenseCategories[$0] }
                )
            )
        }
    }

    // MARK: 收入来源（P0-3 美团支持）

    private var incomeSourceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("收入来源")
            V32SegmentedPicker(
                tabs: incomeSources.map(\.rawValue),
                selectionIndex: Binding(
                    get: { incomeSources.firstIndex(of: incomeSource) ?? 0 },
                    set: { incomeSource = incomeSources[$0] }
                )
            )
        }
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
            // P0-3：编辑旧流水时载入已存来源；空字符串 fallback 到派生
            incomeSource = IncomeSource.from(performance: p)
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
                    try PerformanceRepository(context: context).add(
                        amount: amount,
                        note: note,
                        date: date,
                        incomeSource: incomeSource
                    )
                } else {
                    try ExpenseRepository(context: context).add(amount: amount, category: category, note: note, date: date)
                }
            case .editPerformance(let p):
                p.amount = amount
                p.note = note
                p.date = date
                // P0-3：编辑旧流水可修改来源
                p.incomeSource = incomeSource.rawValue
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
            saveError = "经营记录未保存，请重试。"
        }
    }
}

extension Haptic {
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
