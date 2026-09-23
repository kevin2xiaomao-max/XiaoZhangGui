import SwiftUI
import SwiftData

// MARK: - 记收入/记支出 编辑器（原生 Form + Mode 三态）
// 写入逻辑（Repository add/update）原样保留，只换原生 Form 与 toolbar 样式。

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
        NavigationStack {
            Form {
                Section(kind == .income ? "收入金额" : "支出金额") {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("¥")
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                            .keyboardType(.decimalPad)
                            .minimumScaleFactor(0.6)
                            .accessibilityLabel(kind == .income ? "收入金额" : "支出金额")
                    }
                }

                Section("明细") {
                    TextField(
                        kind == .income ? "备注（选填）" : "备注（选填，如：进了两箱可乐）",
                        text: $note,
                        axis: .vertical
                    )
                    DatePicker("日期", selection: $date, displayedComponents: .date)
                }

                if kind == .expense {
                    Section("分类") {
                        Picker("分类", selection: $category) {
                            ForEach(expenseCategories, id: \.self) { Text($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                if kind == .income {
                    Section("收入来源") {
                        Picker("收入来源", selection: $incomeSource) {
                            ForEach(incomeSources) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(amount == nil)
                }
            }
            .onAppear(perform: loadEditing)
            .alert("保存失败", isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })) {
                Button("重试") { save() }
                Button("取消", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "请稍后重试") }
        }
        .v32Sheet([.medium, .large])
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

// Haptic 统一定义点见 XiaoZhangGui/DesignSystem/FloatingDock.swift（enum Haptic）。
