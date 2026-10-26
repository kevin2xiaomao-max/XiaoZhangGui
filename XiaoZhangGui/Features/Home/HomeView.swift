import SwiftData
import SwiftUI

// MARK: - 首页（V3.8 重建 · Editorial）
//
// 视觉依据：
// - `XZG_iOS_V38_UI_Light/Dark.png`：大日期 → 今天的经营（Revenue Hero 深绿卡）
//   → 问小掌柜（AI 胶囊）→ 今日事项（平面列表）
// - 2026-10-23 用户确认减法：整行删除「快速记一笔 / 写备忘」快捷操作行，
//   不得恢复整排或四宫格；快速记录仍由深链（xzg://quickrecord）等原有路径可达。
// - 2026-10-24 V3.9.1 P1-6（在减法之上、非回退）：首页顶部仅设一个克制「记一笔」
//   图标入口，复用 RootView 的 showQuickRecord Binding，不属于已删的快捷行。
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
    /// V3.9.1 P1-4:与 TodoView 共享的筛选导航状态(RootView 持有)。
    var todoNavigation: TodoNavigationState = TodoNavigationState()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings
    @Bindable private var demo = DemoMode.shared
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    // V3.9.2 PR-I:快捷行删除后首页已无备忘消费点,移除死查询(每次 body 白拉全表);
    // 需要备忘数据时按路由进 MemoView,不在首页预取。
    @State private var route: HomeRoute?
    // V3.7.1 起的首页待办操作失败反馈:FlowConsistencyTests 以源码审计
    // 「首页入口同样须等 Repository 成功」;toggleTodo 目前未被行内调用,
    // 但审计契约仍在,不得以「死代码」为由删除(2026-10-24 CI 红线教训)。
    @State private var stateActionError: String?
    @State private var showWeatherSheet = false
    @State private var weatherModel = WeatherViewModel()
    /// V3.9.2 PR-I:掌柜晨报(已读状态存 UserDefaults,跨天自动未读)。
    @State private var showMorningBrief = false
    @AppStorage(MorningBriefStore.readOnKey) private var morningBriefReadOn: String = ""

    // V3.8 PR-D C3：展示型大数字随系统动态字体档位缩放（基准确认默认视觉不变）。
    @ScaledMetric(relativeTo: .largeTitle) private var heroAmountSize: CGFloat = 54
    @ScaledMetric(relativeTo: .largeTitle) private var dateNumberSize: CGFloat = 64

    /// V3.9.1 P1-7:首页全部派生数据一次遍历产出,body 内只求值一次并下发各区块,
    /// 各区块不得再各自对 performances/todos 做全量聚合。
    private var aggregates: HomeAggregates {
        HomeAggregates.build(
            performances: performances, todos: todos, customers: customers,
            expiryItems: expiryItems,
            monthGoal: MonthlyBusinessMetrics.goal(isDemoEnabled: demo.isEnabled, settingsGoal: settings.monthGoal)
        )
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
        let agg = aggregates
        return ScrollView {
            // V3.9 高级质感版式:日期 → 玻璃Hero(目标环) → 统计chips → 趋势/来源
            // → AI 胶囊 → 今日事项。信息密度一屏补齐(用户定稿方向)。
            VStack(alignment: .leading, spacing: 18) {
                if demo.isEnabled {
                    demoBanner
                }
                dateHeader
                heroCard(agg)
                statChipsRow(agg)
                trendAndSourceSection(agg)
                briefSection(agg)
                aiSection
                mattersSection(agg)
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
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMorningBrief) {
            MorningBriefSheet(
                brief: MorningBriefBuilder.build(
                    performances: performances, todos: todos,
                    expiryItems: expiryItems, customers: customers,
                    monthGoal: MonthlyBusinessMetrics.goal(isDemoEnabled: demo.isEnabled, settingsGoal: settings.monthGoal)
                ),
                onNavigate: { destination in
                    showMorningBrief = false
                    switch destination {
                    case .todo: tab = .todo
                    case .delivery: route = .customer
                    case .expiry: route = .expiry
                    }
                },
                onExecute: { destination in
                    switch destination {
                    case .todo(let title):
                        guard let todo = todos.first(where: { !$0.isCompleted && $0.title == title }) else { return }
                        do {
                            try TodoRepository(context: modelContext).toggleComplete(todo)
                            Haptic.success()
                        } catch {
                            Haptic.error()
                            stateActionError = "待办状态未改变，请重试。"
                        }
                    case .delivery(let customer, let room):
                        guard let request = customers.first(where: {
                            $0.statusEnum != .done
                            && (customer.isEmpty || $0.customer == customer)
                            && (room.isEmpty || $0.roomOrAddress == room)
                        }) else { return }
                        do {
                            try CustomerRepository(context: modelContext).advanceStatus(request)
                            Haptic.success()
                        } catch {
                            Haptic.error()
                            stateActionError = "配送状态未改变，请重试。"
                        }
                    case .expiry:
                        break
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
    }

    // MARK: - Demo 提示条(V3.9.1 P1-12:演示数据不得被误认为真实经营数据)

    private var demoBanner: some View {
        HStack(spacing: 8) {
            Label("演示数据", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.semibold))
            Text("仅供演示，不会写入真实账本")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
            Button("退出演示") { demo.isEnabled = false }
                .font(.footnote.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(V371.Colors.orange.opacity(0.15)))
        .accessibilityIdentifier("v39.demo.banner")
        // 无障碍：原先在整条横幅上盖 label，会把「退出演示」按钮的语义一起吞掉；
        // 去掉后由内部两段文案 + 按钮各自播报。
    }

    // MARK: - 顶部：大日期 / 星期 / 今日经营一览

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
                    Text("今日经营一览")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 8)
            }
            Spacer(minLength: 12)
            HStack(spacing: 4) {
                weatherButton
                // V3.9.1 P1-6:首页顶部唯一的克制「记一笔」入口,复用 RootView 的
                // showQuickRecord Binding(不恢复已删快捷行整排、不新增四宫格)。
                headerAction(
                    icon: "plus",
                    label: "记一笔",
                    identifier: "v39.home.quickRecord",
                    action: { showQuickRecord = true }
                )
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

    private func heroCard(_ agg: HomeAggregates) -> some View {
        V39HeroCard(
            monthRevenue: agg.monthRevenue,
            monthGoal: agg.monthGoal,
            todayRevenue: agg.todayRevenue,
            changePercent: agg.changePercent,
            heroAmountSize: heroAmountSize,
            onTap: { route = .performance }
        )
    }

    // MARK: - V3.9 · 统计 chips（待办 / 逾期 / 临期 / 配送,一眼看全）

    private func statChipsRow(_ agg: HomeAggregates) -> some View {
        HStack(spacing: 10) {
            V39StatChip(
                icon: "checklist",
                title: "待办",
                count: agg.todayTodoCount,
                tint: V39Style.navy,
                identifier: "v39.home.chips.todo",
                hint: "打开今日待办",
                onTap: { todoNavigation.request(.today); tab = .todo }
            )
            V39StatChip(
                icon: "exclamationmark.circle.fill",
                title: "逾期",
                count: agg.overdueCount,
                // V3.9.1 P1-4:颜色语义统一——逾期=红(警示),临期=橙(提示);旧代码恰好写反。
                tint: V371.Colors.red,
                identifier: "v39.home.chips.overdue",
                hint: "打开逾期筛选",
                onTap: { todoNavigation.request(.overdue); tab = .todo }
            )
            V39StatChip(
                icon: "hourglass",
                title: "临期",
                count: agg.pendingExpiryCount,
                tint: V371.Colors.orange,
                identifier: V371AccessibilityID.homeExpiry,
                onTap: { route = .expiry }
            )
            V39StatChip(
                icon: "box.truck.fill",
                title: "配送",
                count: agg.deliveryCount,
                tint: V400Tokens.infoInk,
                identifier: V371AccessibilityID.homeCustomer,
                onTap: { route = .customer }
            )
        }
    }

    // MARK: - V3.9 · 近7日趋势 + 本月收入来源（玻璃数据卡）

    private func trendAndSourceSection(_ agg: HomeAggregates) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            V39TrendCard(
                points: agg.trendPoints,
                heroAmountSize: heroAmountSize,
                onTap: { route = .performance }
            )
            V39SourceBar(
                summaries: agg.sourceSummaries,
                onTap: { route = .performance }
            )
        }
    }

    // MARK: - V3.9.2 PR-I · 掌柜晨报卡(开店前 30 秒总览)

    private func briefSection(_ agg: HomeAggregates) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V38HomeSectionHeader(title: "掌柜晨报")
            MorningBriefCard(
                brief: MorningBriefBuilder.build(
                    performances: performances, todos: todos,
                    expiryItems: expiryItems, customers: customers,
                    monthGoal: agg.monthGoal
                ),
                isRead: morningBriefReadOn == MorningBriefStore.dayKey(Date()),
                onTap: {
                    // 打开即视为已读(金点消失);详情数据在 Sheet 内按当下时刻重算。
                    MorningBriefStore.markRead()
                    morningBriefReadOn = MorningBriefStore.dayKey(Date())
                    showMorningBrief = true
                }
            )
        }
    }

    // MARK: - 问小掌柜 · AI 胶囊（生产）

    private var aiSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            V38HomeSectionHeader(title: "问小掌柜")
            // V3.9.1 P1-5:一次点击直接打开现有 AI 对话页,去除「展开→再点输入行」
            // 的中间步骤。注意:本文件不得出现 AI 对话视图的类型名字面量,
            // HomeQuickEntryAuditTests 以原始源码子串审计(含注释)。
            // 的中间步骤;不另起 AI 引擎,Sheet/键盘/TabBar 行为不变。
            V38HomeAICapsule(
                onOpenAI: {
                    withAnimation(V38MotionTokens.animation(for: .contentChange, reduceMotion: reduceMotion)) {
                        showAI = true
                    }
                }
            )
        }
    }

    // MARK: - 今日事项（平面列表）

    private func mattersSection(_ agg: HomeAggregates) -> some View {
        let handlingItems = agg.handlingItems
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                V38HomeSectionHeader(title: "今日事项")
                Spacer()
                // P2-A:今日事项「查看全部」入口(只列 3 条时可达完整待办)。
                Button("查看全部") { tab = .todo }
                    .font(.footnote.weight(.semibold))
                    .accessibilityIdentifier("v39.home.matters.all")
            }
            if handlingItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("今天暂无安排")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("去待办添加") { tab = .todo }
                        .font(.footnote.weight(.semibold))
                        .accessibilityIdentifier("v39.home.matters.add")
                }
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
                        .accessibilityLabel("\(item.title)，\(item.subtitle)\(toneWord(item.tone).isEmpty ? "" : "，\(toneWord(item.tone))")\(item.time.isEmpty ? "" : "，\(item.time)")")
                        .accessibilityIdentifier(routeIdentifier(item.route))
                    }
                }
            }
        }
    }

    /// P2-A:无障碍朗读含优先级语义(紧急/临期),不只读标题与时间。
    private func toneWord(_ tone: HomeInboxItem.Tone) -> String {
        switch tone {
        case .urgent: return "紧急"
        case .warning: return "临期提醒"
        case .accent: return "待办"
        case .normal: return ""
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

    /// 首页待办状态变更入口:必须等 Repository 成功才算完成,失败时
    /// 出错反馈且状态未改变(FlowConsistencyTests 审计契约;见 stateActionError 注释)。
    private func toggleTodo(for item: HomeInboxItem) {
        guard item.route == .todo,
              let todo = todos.first(where: { "todo-\($0.notificationID)" == item.id }) else { return }
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
