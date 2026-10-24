import SwiftData
import SwiftUI

// MARK: - 首页（V3.8 重建 · Editorial）
//
// 视觉依据：
// - `XZG_iOS_V38_UI_Light/Dark.png`：大日期 → 今天的经营（Revenue Hero 深绿卡）
//   → 问小掌柜（AI 胶囊）→ 今日事项（平面列表）
// - 2026-10-23 用户确认减法：整行删除「快速记一笔 / 写备忘」快捷操作行，
//   首页不再设重复入口；快速记录仍由深链（xzg://quickrecord）等原有路径可达。
// - `02_设计与交互升级说明.md`：Editorial Content + Soft Frosted Controls +
//   Native Interaction + Time-driven Organization
//
// 业务逻辑全部保留自 V3.7.1（@Query / TodaySummary / MonthlyBusinessMetrics /
// HomeInbox / navigationDestination / sheets / alerts），仅重做 Presentation。
// 重建提交前缀 `rebuild(ios/v3.8):`，不冒充原始 8f3a892。

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    @Binding var showQuickRecord: Bool
    @Binding var showAI: Bool
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

    // V3.8：AI 胶囊展开态。
    @State private var aiExpanded = false

    // V3.8 PR-D C3：展示型大数字随系统动态字体档位缩放（基准确认默认视觉不变）。
    @ScaledMetric(relativeTo: .largeTitle) private var heroAmountSize: CGFloat = 54
    @ScaledMetric(relativeTo: .largeTitle) private var dateNumberSize: CGFloat = 64

    private var summary: TodaySummary {
        TodaySummary.build(performances: performances, todos: todos, customers: customers, expiryItems: expiryItems)
    }

    private var monthRevenue: Double {
        MonthlyBusinessMetrics.revenue(from: performances)
    }

    private var monthGoal: Double {
        MonthlyBusinessMetrics.goal(isDemoEnabled: demo.isEnabled, settingsGoal: settings.monthGoal)
    }

    private var handlingItems: [HomeInboxItem] {
        return HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries,
                               expiryItems: summary.pendingExpiry, limit: 3)
    }

    // MARK: V3.9 数据(全部复用既有模型口径,零新增计算规则)

    /// 近7日趋势(既有 PerformanceTrend,与经营页同源)。
    private var trendPoints: [TrendPoint] {
        PerformanceTrend.last7Days(performances: performances)
    }

    /// 本月收入来源占比(既有 IncomeSourceSummary,与经营页同源)。
    private var sourceSummaries: [IncomeSourceSummary] {
        IncomeSourceSummary.compute(performances: performances, range: (Date().startOfMonth, Date().endOfDay))
    }

    /// 逾期未完成数(TodoFilter 同口径)。
    private var overdueCount: Int {
        TodoFilter.todos(for: .overdue, in: todos).count
    }

    /// 今日待办数(含未安排,与首页事项区同一事实源)。
    private var todayTodoCount: Int {
        TodoFilter.todos(for: .today, in: todos).count
    }

    var body: some View {
        ScrollView {
            // V3.9 高级质感版式:日期 → 玻璃Hero(目标环) → 统计chips → 趋势/来源
            // → AI 胶囊 → 快捷行 → 今日事项。信息密度一屏补齐(用户定稿方向)。
            VStack(alignment: .leading, spacing: 18) {
                dateHeader
                heroCard
                statChipsRow
                trendAndSourceSection
                aiSection
                mattersSection
                V371ScrollEndMarker(identifier: V371AccessibilityID.scrollEndHome)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(V371AccessibilityID.screenHome)
        .v39Canvas()
        // V3.8.1 P0-2：iOS 26/27 浮动 Tab 栏为覆盖层，系统底部安全区不含栏体；
        // 用共享 safeAreaInset 机制让内容可完整滚动到栏上方（禁内容内 Spacer 掩盖）。
        .v32PageBottomInset()
        .alert("操作失败", isPresented: Binding(get: { stateActionError != nil }, set: { if !$0 { stateActionError = nil } })) {
            Button("知道了", role: .cancel) { stateActionError = nil }
        } message: { Text(stateActionError ?? "待办状态未改变，请重试") }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .customer: CustomerView()
            case .expiry: ExpiryView()
            case .performance: PerformanceView()
            case .memo: MemoView()
            case .profile:
                ProfileView(showVoice: $showVoice, showsVoiceButton: showsVoiceButton)
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherDetailSheet(model: weatherModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
    }

    // MARK: - 顶部：大日期 / 星期 / 经营时间线

    private var dateHeader: some View {
        HStack(alignment: .top) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(Calendar.current.component(.day, from: Date()))")
                    .font(V38HomeStyle.scaledDateNumber(size: dateNumberSize))
                    .foregroundStyle(.primary)
                    .accessibilityLabel("\(Date(), format: .dateTime.month().day().weekday(.wide))")
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date(), format: .dateTime.month().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("经营时间线")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 12)
            HStack(spacing: 4) {
                weatherButton
                headerAction(
                    icon: "person.crop.circle.fill",
                    label: "个人中心",
                    identifier: V371AccessibilityID.homeProfile,
                    action: { route = .profile }
                )
            }
        }
    }

    private func headerAction(
        icon: String,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
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
            .foregroundStyle(.secondary)
            .padding(.horizontal, 2)
            .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
    }

    // MARK: - V3.9 · 本月营业额玻璃大卡（含月目标进度环,替代 V3.8 深绿 Hero）

    private var heroCard: some View {
        V39HeroCard(
            monthRevenue: monthRevenue,
            monthGoal: monthGoal,
            todayRevenue: summary.revenue,
            changePercent: summary.changePercent,
            heroAmountSize: heroAmountSize,
            onTap: { route = .performance }
        )
    }

    // MARK: - V3.9 · 统计 chips（待办 / 逾期 / 临期 / 配送,一眼看全）

    private var statChipsRow: some View {
        HStack(spacing: 10) {
            V39StatChip(
                icon: "checklist",
                title: "待办",
                count: todayTodoCount,
                tint: V39Style.navy,
                identifier: "v39.home.chips.todo",
                onTap: { tab = .todo }
            )
            V39StatChip(
                icon: "exclamationmark.circle.fill",
                title: "逾期",
                count: overdueCount,
                tint: V371.Colors.orange,
                identifier: "v39.home.chips.overdue",
                onTap: { tab = .todo }
            )
            V39StatChip(
                icon: "hourglass",
                title: "临期",
                count: summary.pendingExpiry.count,
                tint: V371.Colors.red,
                identifier: V371AccessibilityID.homeExpiry,
                onTap: { route = .expiry }
            )
            V39StatChip(
                icon: "box.truck.fill",
                title: "配送",
                count: summary.deliveries.count,
                tint: V39Style.gold,
                identifier: V371AccessibilityID.homeCustomer,
                onTap: { route = .customer }
            )
        }
    }

    // MARK: - V3.9 · 近7日趋势 + 本月收入来源（玻璃数据卡）

    private var trendAndSourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V39TrendCard(
                points: trendPoints,
                heroAmountSize: heroAmountSize,
                onTap: { route = .performance }
            )
            V39SourceBar(
                summaries: sourceSummaries,
                onTap: { route = .performance }
            )
        }
    }

    // MARK: - 问小掌柜 · AI 胶囊（生产）

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            V38HomeSectionHeader(title: "问小掌柜", trailing: "AI 入口")
            V38HomeAICapsule(
                isExpanded: $aiExpanded,
                onOpenAI: {
                    aiExpanded = false
                    withAnimation(V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion)) {
                        showAI = true
                    }
                }
            )
        }
    }

    // MARK: - 今日事项（平面列表）

    private var mattersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            V38HomeSectionHeader(title: "今日事项")
            if handlingItems.isEmpty {
                Text("今天暂无安排")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(handlingItems.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().padding(.leading, 44)
                        }
                        Button { open(item.route) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: itemIcon(item.tone))
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(toneAccent(item.tone))
                                    .frame(width: 32, height: 32)
                                    .background(toneAccent(item.tone).opacity(0.12), in: Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    if !item.subtitle.isEmpty {
                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                                if !item.time.isEmpty {
                                    Text(item.time)
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .frame(minHeight: 60)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(item.title)，\(item.subtitle)")
                        .accessibilityIdentifier(routeIdentifier(item.route))
                    }
                }
            }
        }
    }

    private func itemIcon(_ tone: HomeInboxItem.Tone) -> String {
        switch tone {
        case .urgent: return "exclamationmark.circle.fill"
        case .warning: return "hourglass"
        case .accent: return "checklist"
        case .normal: return "circle"
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

    /// 今日事项行的稳定 identifier（供 UI 测试导航到客户/临期/待办）。
    /// V3.8 重建保留 V3.7.1 的路由标识符契约。
    private func routeIdentifier(_ route: HomeInboxItem.Route) -> String {
        switch route {
        case .todo: return "home.todo"
        case .customer: return "home.customer"
        case .expiry: return "home.expiry"
        }
    }

    // MARK: - 动作（保留 V3.7.1 业务逻辑）

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
