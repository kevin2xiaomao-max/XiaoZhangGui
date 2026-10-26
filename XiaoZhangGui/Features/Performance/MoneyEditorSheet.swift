import SwiftUI
import SwiftData

// MARK: - 记收入/记支出 编辑器（原生 Form + Mode 三态）
// 写入逻辑（Repository add/update）原样保留，只换原生 Form 与 toolbar 样式。

/// V3.8 PR-D C1：金额文本解析与有效性（纯函数，可单测）。
enum MoneyAmountText {
    /// 解析金额：容忍千分位逗号；非数字 / ≤0 视为无效返回 nil。
    static func parse(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: ",", with: "")
        guard let value = Double(cleaned), value > 0 else { return nil }
        return value
    }

    /// 是否需要「无效金额」行内提示：已输入但解析不出有效金额。
    static func needsInvalidHint(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parse(text) == nil
    }
}

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
    @State private var showDiscardAlert = false

    /// V3.9.1 P1-8:与原记录(编辑)或默认值(新增)比对;日期只比「日」,
    /// 避免 DatePicker 归一化时分造成误判为脏。
    private var isDirty: Bool {
        switch mode {
        case .new:
            return !amountText.isEmpty || !note.isEmpty || category != "其他" || incomeSource != .store
        case .editPerformance(let p):
            return amountText != (p.amount == p.amount.rounded(.towardZero) ? String(Int(p.amount)) : String(p.amount))
                || note != p.note || !Calendar.current.isDate(date, inSameDayAs: p.date)
                || incomeSource != IncomeSource.from(performance: p)
        case .editExpense(let e):
            return amountText != (e.amount == e.amount.rounded(.towardZero) ? String(Int(e.amount)) : String(e.amount))
                || note != e.note || category != e.category
                || !Calendar.current.isDate(date, inSameDayAs: e.date)
        }
    }

    private func cancelTapped() {
        if isDirty { showDiscardAlert = true } else { dismiss() }
    }
    /// V3.8 PR-D C1：金额输入焦点——decimalPad 无回车键，键盘栏补「完成」收起。
    @FocusState private var amountFocused: Bool

    /// V3.8 PR-D C1：已输入但无效（非数字 / ≤0）时行内提示，不再静默置灰保存。
    private var showsInvalidAmountHint: Bool {
        MoneyAmountText.needsInvalidHint(amountText)
    }

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
        MoneyAmountText.parse(amountText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("¥")
                            .font(V400Tokens.serifAmount(size: 22, relativeTo: .title3))
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amountText)
                            .font(V400Tokens.serifAmount(size: 34).weight(.bold))
                            .keyboardType(.decimalPad)
                            .minimumScaleFactor(0.6)
                            .focused($amountFocused)
                            .accessibilityLabel(kind == .income ? "收入金额" : "支出金额")
                    }
                } header: {
                    Text(kind == .income ? "收入金额" : "支出金额")
                } footer: {
                    // V3.8 PR-D C1：无效金额行内提示（原先只是保存键静默置灰）。
                    if showsInvalidAmountHint {
                        Text("请输入大于 0 的有效金额")
                            .foregroundStyle(V371.Colors.red)
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
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: cancelTapped)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(amount == nil)
                }
                // V3.8 PR-D C1：decimalPad 没有回车键，键盘栏补「完成」收起
                // （与 VoiceView 输入栏的 Done 同一口径）。
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { amountFocused = false }
                }
            }
            .onAppear(perform: loadEditing)
            .interactiveDismissDisabled(isDirty)
            .alert("放弃未保存的修改？", isPresented: $showDiscardAlert) {
                Button("放弃修改", role: .destructive) { dismiss() }
                Button("继续编辑", role: .cancel) {}
            } message: { Text("已输入的内容将丢失。") }
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
            // V3.9.1 P1-8:记一笔优先自动聚焦金额字段(键盘直达输入)。
            amountFocused = true
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
