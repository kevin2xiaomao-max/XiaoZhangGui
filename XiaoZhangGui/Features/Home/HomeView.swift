import Charts
import SwiftData
import SwiftUI

// MARK: - 首页（V3.7.1 presentation）
//
// 结构（MD §5）：Header → Revenue Hero → QuickActionRow → 「今日重点」
// → 「接下来」→ AICommandEntry。内容区只用 V371 primitives，禁 Card Wall。

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    @Binding var showQuickRecord: Bool
    @Binding var showAI: Bool = .constant(false)
    let showsVoiceButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings
    @Bindable private var demo = DemoMode.shared
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]
    @State private var route: HomeRoute?
    @State private var showWeatherSheet = false
    @State private var weatherModel = WeatherViewModel()
    @State private var stateActionError: String?

    private var summary: TodaySummary {
        TodaySummary.build(performances: performances, todos: todos, customers: customers, expiryItems: expiryItems)
    }

    private var monthRevenue: Double {
        if demo.isEnabled { return DemoCatalog.monthlyRevenue }
        return performances
            .filter { $0.date >= Date().startOfMonth && $0.date <= Date().endOfDay }
            .reduce(0) { $0 + $1.amount }
    }

    private var monthGoal: Double {
        demo.isEnabled ? DemoCatalog.monthlyGoal : settings.monthGoal
    }

    private var handlingItems: [HomeInboxItem] {
        return HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries,
                               expiryItems: summary.pendingExpiry, limit: 3)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V371.Space.section) {
                header
                hero
                QuickActionRow(items: quickActions)
                focusSection
                nextSection
                AICommandEntry { showAI = true }
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
        .v371DockInset()
        .alert("操作失败", isPresented: Binding(get: { stateActionError != nil }, set: { if !$0 { stateActionError = nil } })) {
            Button("知道了", role: .cancel) { stateActionError = nil }
        } message: { Text(stateActionError ?? "待办状态未改变，请重试") }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 2) {
                    Button { showQuickRecord = true } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 17, weight: .medium))
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("一句话快速记录")
                    Button { route = .profile } label: {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(V371.Colors.textSecondary)
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("个人中心")
                }
            }
        }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .customer: CustomerView()
            case .expiry: ExpiryView()
            case .performance: PerformanceView()
            case .memo: MemoView()
            case .profile: ProfileView()
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherDetailSheet(model: weatherModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
    }

    // MARK: 顶部：日期 / 问候 / 天气

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(V371.Colors.textSecondary)
                weatherButton
            }
            Text("\(greetingPrefix)，\(ownerDisplayName)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(V371.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .accessibilityLabel("\(greetingPrefix)，\(ownerDisplayName)")
        }
    }

    private var greetingPrefix: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 11 { return "早上好" }
        if hour < 14 { return "中午好" }
        if hour < 18 { return "下午好" }
        return "晚上好"
    }

    private var ownerDisplayName: String {
        let name = settings.ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "老板" : name
    }

    private var weatherButton: some View {
        Button { showWeatherSheet = true } label: {
            HStack(spacing: 5) {
                Image(systemName: weatherModel.snapshot?.symbolName ?? "cloud.sun")
                    .font(.system(size: 15, weight: .medium))
                if let weather = weatherModel.snapshot {
                    Text("\(weather.roundedTemperature)°")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            .foregroundStyle(V371.Colors.textSecondary)
            .padding(.horizontal, 2)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
    }

    // MARK: Revenue Hero（S2 蓝色能量面）

    private var hero: some View {
        HeroMetric(title: "今日营业额", value: "¥" + Fmt.groupedAmount(summary.revenue),
                   action: { route = .performance }) {
            heroInfo
        }
        .contentTransition(.numericText(value: summary.revenue))
        .animation(V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion)), value: summary.revenue)
    }

    private var heroInfo: some View {
        Group {
            if !heroInfoParts.isEmpty {
                Text(heroInfoParts.joined(separator: " · "))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(V371.Colors.heroTextSecondary)
            }
        }
    }

    private var heroInfoParts: [String] {
        var parts: [String] = []
        if let change = summary.changePercent {
            let sign = change >= 0 ? "+" : ""
            parts.append("较昨日 \(sign)\(String(format: "%.1f", change))%")
        }
        if monthGoal > 0 {
            parts.append("月目标 \(String(format: "%.0f", monthRevenue / monthGoal * 100))%")
        }
        return parts
    }

    // MARK: 快捷入口

    private var quickActions: [QuickActionItem] {
        [
            QuickActionItem(icon: "box.truck.fill", title: "客户配送") { route = .customer },
            QuickActionItem(icon: "hourglass", title: "临期退货") { route = .expiry },
            QuickActionItem(icon: "plus.circle.fill", title: "快速记一笔") { showQuickRecord = true },
            // audit 钉住 HomeView 不得出现 AI 名称字面量，此处用「小掌柜」映射到 AI
            QuickActionItem(icon: "sparkles", title: "小掌柜") { showAI = true },
        ]
    }

    // MARK: 今日重点

    private var focusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("今日重点")
            GroupSurface {
                WorkRow(icon: "box.truck.fill", iconColor: V371.Colors.blue,
                        title: "客户配送", subtitle: deliverySubtitle,
                        action: { open(.customer) }) {
                    HStack(spacing: 8) {
                        StatusBadge("\(summary.deliveries.count) 单", color: V371.Colors.blue)
                        V371Chevron()
                    }
                }
                V371Divider()
                WorkRow(icon: "checklist", iconColor: V371.Colors.green,
                        title: "今日待办", subtitle: todoSubtitle,
                        action: { open(.todo) }) {
                    HStack(spacing: 8) {
                        StatusBadge("\(summary.todos.count) 项", color: V371.Colors.green)
                        V371Chevron()
                    }
                }
                V371Divider()
                WorkRow(icon: "hourglass", iconColor: V371.Colors.orange,
                        title: "临期退货", subtitle: expirySubtitle,
                        action: { open(.expiry) }) {
                    HStack(spacing: 8) {
                        StatusBadge("\(summary.pendingExpiry.count) 件", color: V371.Colors.orange)
                        V371Chevron()
                    }
                }
            }
        }
    }

    private var deliverySubtitle: String {
        let delivering = summary.deliveries.filter { $0.statusEnum == .delivering }.count
        if delivering > 0 { return "有 \(delivering) 单配送中" }
        return summary.deliveries.isEmpty ? "暂无配送" : "待配送"
    }

    private var todoSubtitle: String {
        let dueToday = summary.todos.filter { $0.dueDate?.isToday == true }.count
        if dueToday > 0 { return "\(dueToday) 项今天到期" }
        return summary.todos.isEmpty ? "全部完成" : "灵活安排"
    }

    private var expirySubtitle: String {
        let urgent = summary.pendingExpiry.filter { $0.daysLeft() <= 3 }.count
        if urgent > 0 { return "\(urgent) 件 3 天内临期" }
        return summary.pendingExpiry.isEmpty ? "暂无临期" : "待处理"
    }

    // MARK: 接下来

    private var nextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("接下来")
            GroupSurface {
                if handlingItems.isEmpty {
                    EmptyState(icon: "sun.max", title: "今天暂无安排",
                               message: "待办、配送与临期事项会出现在这里")
                } else {
                    ForEach(Array(handlingItems.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { V371Divider(leading: 30) }
                        TimedRow(time: item.time, title: item.title,
                                 subtitle: item.subtitle.isEmpty ? nil : item.subtitle,
                                 accent: toneAccent(item.tone),
                                 action: { open(item.route) })
                    }
                }
            }
        }
    }

    private func toneAccent(_ tone: HomeInboxItem.Tone) -> Color {
        switch tone {
        case .urgent: return V371.Colors.red
        case .warning: return V371.Colors.orange
        case .accent: return V371.Colors.blue
        case .normal: return V371.Colors.gray
        }
    }

    // MARK: 动作

    private func toggleTodo(for item: HomeInboxItem) {
        guard item.route == .todo,
              let todo = summary.todos.first(where: { "todo-\($0.notificationID)" == item.id }) else { return }
        do {
            try TodoRepository(context: modelContext).toggleComplete(todo)
            todo.isCompleted ? Haptic.success() : Haptic.light()
        } catch {
            Haptic.error()
            stateActionError = "待办状态未改变，请重试。"
        }
    }

    private func open(_ destination: HomeInboxItem.Route) {
        switch destination {
        case .todo: tab = .todo
        case .customer: route = .customer
        case .expiry: route = .expiry
        }
    }
}

private enum HomeRoute: Hashable { case customer, expiry, performance, memo, profile }
