import Charts
import SwiftData
import SwiftUI

// MARK: - 首页 · 今日经营驾驶舱（V32）

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    @Binding var showQuickRecord: Bool
    let showsVoiceButton: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSettings.self) private var settings
    @Bindable private var demo = DemoMode.shared
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @State private var route: HomeRoute?
    @State private var showWeatherSheet = false
    @State private var weatherModel = WeatherViewModel()

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

    private var goalProgress: Double {
        guard monthGoal > 0 else { return 0 }
        return min(max(monthRevenue / monthGoal, 0), 1)
    }

    private var handlingItems: [HomeInboxItem] {
        // 已在横卡展示的配送从今日事项去重；未在横卡的其它待处理配送仍可入列（Q4 定稿）
        let stripIDs = Set(topDeliveries.map { "delivery-\($0.notificationID)" })
        return HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries,
                               expiryItems: summary.pendingExpiry, limit: 4,
                               excludingDeliveryIDs: stripIDs)
    }

    /// P1-1：今日已完成计数（Todo + 配送），与日程「当天完成」共用 ScheduleAgenda 同一口径：
    /// Todo 按 completedAt、配送按 done+updatedAt 归属当天，点进日程每项都可追踪。
    private var todayCompletedCount: Int {
        let now = Date()
        let doneTodos = ScheduleAgenda.completedTodos(todos.filter(\.isCompleted), on: now).count
        let doneDeliveries = ScheduleAgenda.completedDeliveries(customers, on: now).count
        return doneTodos + doneDeliveries
    }

    /// 配送中优先、待处理其次，最多 2 张横滑小卡
    private var topDeliveries: [CustomerRequest] {
        Array(summary.deliveries.sorted { lhs, rhs in
            if lhs.statusEnum != rhs.statusEnum {
                return lhs.statusEnum == .delivering && rhs.statusEnum != .delivering
            }
            return lhs.updatedAt > rhs.updatedAt
        }.prefix(2))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V32Layout.sectionGap) {
                header
                assistantEntry
                heroCard
                    .modifier(V32HomeEntrance(delay: 0, reduceMotion: reduceMotion))
                if !topDeliveries.isEmpty {
                    deliverySection
                        .modifier(V32HomeEntrance(delay: 0.04, reduceMotion: reduceMotion))
                }
                todaySection
                    .modifier(V32HomeEntrance(delay: 0.08, reduceMotion: reduceMotion))
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .customer: CustomerView()
            case .expiry: ExpiryView()
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            // P1-4：跟随 ThemeStore / V32 tokens，不再走旧 AppTheme 链路
            WeatherDetailSheet(model: weatherModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
    }

    // MARK: 顶部：问候 / 日期 / 天气 / 快速记录 / 头像

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingPrefix)
                    .v32Text(.body)
                    .foregroundStyle(V32.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ownerDisplayName)
                        .v32Text(.display)
                        .foregroundStyle(V32.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("👋")
                        .font(.system(size: 24))
                }
                Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textTertiary)
                    .padding(.top, 1)
            }
            Spacer(minLength: 4)
            toolCircle("square.and.pencil") { showQuickRecord = true }
                .accessibilityLabel("快速记录")
            weatherButton
        }
    }

    // MARK: 小掌柜轻入口（只切到 AI Tab，完整 Chat 不塞回首页）

    private var assistantEntry: some View {
        V32Card(padding: 12) {
            Button {
                tab = .assistant
                Haptic.light()
            } label: {
                HStack(spacing: 10) {
                    V32IconBubble(systemName: "sparkles", tone: .brand, size: 36, icon: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("问小掌柜…")
                            .v32Text(.headline)
                            .foregroundStyle(V32.textPrimary)
                        Text("记营业额、待办、备忘、配送")
                            .v32Text(.caption)
                            .foregroundStyle(V32.textTertiary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(V32.textTertiary)
                }
            }
            .buttonStyle(.plain)
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

    private func toolCircle(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: V32Layout.toolIcon, weight: .semibold))
                .foregroundStyle(V32.textSecondary)
                .frame(width: V32Layout.toolCircle, height: V32Layout.toolCircle)
                .background(
                    Circle()
                        .fill(V32.card)
                        .overlay(Circle().strokeBorder(V32.cardOutline, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private var weatherButton: some View {
        Button { showWeatherSheet = true } label: {
            HStack(spacing: 3) {
                Image(systemName: weatherModel.snapshot?.symbolName ?? "cloud.sun")
                    .font(.system(size: 15, weight: .semibold))
                if let weather = weatherModel.snapshot {
                    Text("\(weather.roundedTemperature)°")
                        .v32Text(.metricSmall)
                }
            }
            .foregroundStyle(V32.textSecondary)
            .padding(.horizontal, 8)
            .frame(minHeight: V32Layout.toolCircle)
            .background(
                Capsule()
                    .fill(V32.card)
                    .overlay(Capsule().strokeBorder(V32.cardOutline, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
    }

    // MARK: 深墨绿主卡：今日营业额

    private var heroCard: some View {
        V32HeroCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("今日营业额")
                            .v32Text(.caption)
                            .foregroundStyle(V32.textOnHeroSecondary)
                        Text("¥" + Fmt.groupedAmount(summary.revenue))
                            .v32Text(.heroMoney)
                            .foregroundStyle(V32.textOnHero)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText(value: summary.revenue))
                            .animation(
                                V32Motion.animation(V32Motion.resolve(.numeric, reduceMotion: reduceMotion)),
                                value: summary.revenue
                            )
                        revenueChange
                    }
                    Spacer(minLength: 8)
                    if summary.trend.contains(where: { $0.value > 0 }) {
                        HomeSparkline(points: summary.trend)
                            .frame(width: 84, height: 34)
                            .padding(.top, 18)
                    }
                }

                Rectangle()
                    .fill(V32.dividerOnHero)
                    .frame(height: 1)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text("本月 ¥\(Fmt.groupedAmount(monthRevenue))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Text("目标 ¥\(Fmt.groupedAmount(monthGoal))")
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 4)
                        Text("\(Int((goalProgress * 100).rounded()))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded).monospacedDigit())
                    }
                    .v32Text(.caption)
                    .foregroundStyle(V32.textOnHeroSecondary)

                    V32ProgressBar(progress: goalProgress, onHero: true)

                    Text(goalRemainText)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textOnHeroSecondary)
                }
            }
        }
    }

    private var goalRemainText: String {
        guard monthGoal > 0 else { return "去「我的 → 月营业目标」设定目标" }
        let remain = monthGoal - monthRevenue
        if remain > 0 { return "距月目标还差 ¥\(Fmt.groupedAmount(remain))" }
        return "已完成月目标，继续保持"
    }

    @ViewBuilder
    private var revenueChange: some View {
        if let change = summary.changePercent {
            HStack(spacing: 3) {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 11, weight: .heavy))
                Text("\(String(format: "%.1f", abs(change)))% 较昨日")
                    .v32Text(.caption)
            }
            .foregroundStyle(change >= 0 ? V32.brandOnHero : V32.amberOnHero)
        } else {
            Text("暂无昨日对比")
                .v32Text(.caption)
                .foregroundStyle(V32.textOnHeroSecondary)
        }
    }

    // MARK: 客户配送横滑卡

    private var deliverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("客户配送") {
                V32SectionAction(text: "全部") { route = .customer }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: V32Layout.cardGap) {
                    ForEach(topDeliveries, id: \.persistentModelID) { request in
                        DeliveryCard(request: request)
                            .frame(width: deliveryCardWidth)
                            .onTapGesture { route = .customer }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    /// 横卡宽度：按屏宽计算，静止时自然露出下一张约 15%~20%（含 cardGap）。
    /// 不使用固定 248；不写死机型数值。
    private var deliveryCardWidth: CGFloat {
        let content = UIScreen.main.bounds.width - V32Layout.pageMargin * 2
        return max(220, (content - V32Layout.cardGap) / 1.175)
    }

    // MARK: 今日事项（≤4，动作摘要）

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            V32SectionHeader("今日事项") {
                Text(handlingItems.isEmpty ? "" : "\(handlingItems.count) 项")
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textTertiary)
            }

            if handlingItems.isEmpty {
                V32Card {
                    VStack(spacing: 12) {
                        V32EmptyState(
                            systemName: "checkmark.circle.fill",
                            title: "今天没有待处理事项",
                            message: nil
                        )
                        .padding(.vertical, 4)
                        if showsVoiceButton {
                            V32SecondaryButton(title: "语音记一笔", systemName: "mic.fill") {
                                showVoice = true
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }
            } else {
                V32Card(padding: 4) {
                    VStack(spacing: 0) {
                        ForEach(Array(handlingItems.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Rectangle()
                                    .fill(V32.divider)
                                    .frame(height: 1)
                                    .padding(.leading, 48)
                            }
                            HomeActionRow(item: item) {
                                toggleTodo(for: item)
                            }
                            .onTapGesture { open(item.route) }
                        }
                    }
                }
            }

            // P1-2：有完成项才显示，点击跳日程当天
            if todayCompletedCount > 0 {
                Button {
                    tab = .schedule
                    Haptic.light()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("今日已完成 \(todayCompletedCount) 项")
                            .v32Text(.subhead)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(V32.brand)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleTodo(for item: HomeInboxItem) {
        guard item.route == .todo,
              let todo = summary.todos.first(where: { "todo-\($0.notificationID)" == item.id }) else { return }
        try? TodoRepository(context: modelContext).toggleComplete(todo)
        Haptic.light()
    }

    private func open(_ destination: HomeInboxItem.Route) {
        switch destination {
        case .todo: tab = .todo
        case .customer: route = .customer
        case .expiry: route = .expiry
        }
    }
}

private enum HomeRoute: Hashable { case customer, expiry }

// MARK: - 首页首次出现轻入场（opacity + y 8，standard；Reduce Motion 仅短淡入、无位移）

private struct V32HomeEntrance: ViewModifier {
    let delay: Double
    let reduceMotion: Bool
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: reduceMotion ? 0 : (appeared ? 0 : 8))
            .animation(
                V32Motion.animation(V32Motion.resolve(.fade, reduceMotion: reduceMotion))?.delay(delay),
                value: appeared
            )
            .onAppear { if !appeared { appeared = true } }
    }
}

// MARK: - 配送横滑小卡

private struct DeliveryCard: View {
    let request: CustomerRequest

    private var info: CustomerDeliveryInfo { CustomerDeliveryStorage.decode(request.customer) }

    var body: some View {
        V32Card(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    V32IconBubble(systemName: "box.truck.fill", tone: .brand, size: 34, icon: 15)
                    Spacer(minLength: 0)
                    V32StatusPill(text: request.statusEnum.rawValue,
                                  status: request.statusEnum == .delivering ? .delivering : .pending)
                }

                Text(request.displayTitle)
                    .v32Text(.headline)
                    .foregroundStyle(V32.textPrimary)
                    .lineLimit(2)

                Text(request.displaySubtitle.isEmpty ? "客户配送" : request.displaySubtitle)
                    .v32Text(.subhead)
                    .foregroundStyle(V32.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    // P1-2：这一行只表达配送时间，不重复表达状态（状态唯一来源是右上 Pill）
                    Text(info.deliveryTime.map(Fmt.time) ?? "未设配送时间")
                        .v32Text(.caption)
                }
                .foregroundStyle(V32.textTertiary)
            }
        }
    }
}

// MARK: - 今日事项行（圆形勾选）

private struct HomeActionRow: View {
    let item: HomeInboxItem
    let onTodoToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            leading
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .v32Text(.title)
                    .foregroundStyle(V32.textPrimary)
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .v32Text(.caption)
                        .foregroundStyle(V32.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 6)
            Text(item.time)
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(V32.textQuaternary)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leading: some View {
        switch item.route {
        case .todo:
            V32Checkbox(checked: false, action: onTodoToggle)
        case .customer:
            V32IconBubble(systemName: "box.truck.fill", tone: .brand, size: 34, icon: 15)
        case .expiry:
            V32IconBubble(systemName: "hourglass", tone: .amber, size: 34, icon: 15)
        }
    }
}

// MARK: - 七日火花线（hero 内）

private struct HomeSparkline: View {
    let points: [TrendPoint]
    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("日期", point.date), y: .value("营业额", point.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(V32.brandOnHero)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityLabel("最近七日营业额趋势")
    }
}

