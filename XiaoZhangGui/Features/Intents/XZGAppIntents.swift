import Foundation
import AppIntents
import SwiftData

// MARK: - App Intents / Siri 快捷指令（场景 3）
// "在你的小掌柜新增待办 进货" / "记录营业额 500" / "记一条备忘"
// 原生 AppIntents 框架；写入 App Group 内的 SwiftData 容器，并刷新小组件/Live Activity
// 需 Mac/Xcode：真机验证 Siri 短语注册与后台执行

// MARK: 新增待办

struct AddTodoIntent: AppIntent {
    static var title: LocalizedStringResource = "新增待办"
    static var description = IntentDescription("快速记一条待办，可指定截止时间与优先级")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "待办内容")
    var title: String

    @Parameter(title: "优先级", default: 1, requestValueDialog: "优先级：0 低 / 1 中 / 2 高")
    var priority: Int

    @Parameter(title: "今天", default: false)
    var dueToday: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("新增待办 \(\.$title)，\(\.$dueToday) 今天截止，优先级 \(\.$priority)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .result(dialog: "待办内容不能为空")
        }
        let container = try AppDatabase.makeContainer()
        let context = ModelContext(container)
        let todo = Todo(
            title: title.trimmingCharacters(in: .whitespaces),
            dueDate: dueToday ? Date().endOfDay : nil,
            priority: min(max(priority, 0), 2)
        )
        context.insert(todo)
        try context.save()
        NotificationManager.scheduleTodo(todo)
        SnapshotSyncManager.refreshAll(container: container)
        return .result(dialog: "已新增待办：\(todo.title)")
    }
}

// MARK: 记录营业额

struct RecordRevenueIntent: AppIntent {
    static var title: LocalizedStringResource = "记录营业额"
    static var description = IntentDescription("记一笔今日营业收入，自动计入今日营业额与月目标")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "金额")
    var amount: Double

    @Parameter(title: "备注", default: "Siri 快捷指令")
    var note: String

    static var parameterSummary: some ParameterSummary {
        Summary("记录营业额 \(\.$amount) 元，备注 \(\.$note)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: "金额需要大于 0")
        }
        let container = try AppDatabase.makeContainer()
        let context = ModelContext(container)
        try PerformanceRepository(context: context).add(amount: amount, note: note, date: Date())
        SnapshotSyncManager.refreshAll(container: container)
        return .result(dialog: "已记录营业额 ¥\(String(format: "%.2f", amount))")
    }
}

// MARK: 记记录

struct AddMemoIntent: AppIntent {
    static var title: LocalizedStringResource = "记记录"
    static var description = IntentDescription("快速记一条记录，例如客人口味、记账习惯")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "记录标题")
    var title: String

    @Parameter(title: "详细内容", default: "")
    var content: String

    static var parameterSummary: some ParameterSummary {
        Summary("记记录 \(\.$title)，内容 \(\.$content)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            return .result(dialog: "记录标题不能为空")
        }
        let container = try AppDatabase.makeContainer()
        let context = ModelContext(container)
        try MemoRepository(context: context).add(title: title, content: content)
        SnapshotSyncManager.refreshAll(container: container)
        return .result(dialog: "已记下记录：\(title)")
    }
}

// MARK: Siri 短语（App Shortcuts）

struct XZGAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTodoIntent(),
            phrases: [
                "在\(.applicationName)新增待办",
                "用\(.applicationName)记待办",
                "添加\(.applicationName)待办",
            ],
            shortTitle: "新增待办",
            systemImageName: "checkmark.circle"
        )
        AppShortcut(
            intent: RecordRevenueIntent(),
            phrases: [
                "在\(.applicationName)记录营业额",
                "用\(.applicationName)记一笔营业额",
                "\(.applicationName)记收入",
            ],
            shortTitle: "记录营业额",
            systemImageName: "banknote"
        )
        AppShortcut(
            intent: AddMemoIntent(),
            phrases: [
                "在\(.applicationName)记记录",
                "用\(.applicationName)记一条记录",
            ],
            shortTitle: "记记录",
            systemImageName: "note.text"
        )
    }
}
