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
    @Query(sort: \Memo.updatedAt, order: .reverse) private var memos: [Memo]
    @State private var route: HomeRoute?
    @State private var showUtilityDrawer = false
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
            VStack(alignment: .leading, spacing: 24) {
                header
                V35HomeRevenueHero(summary: summary, monthRevenue: monthRevenue, monthGoal: monthGoal) { route = .performance }
                    .modifier(V32HomeEntrance(delay: 0, reduceMotion: reduceMotion))
                weekRail
                V35HomeFocusSection(items: handlingItems, onTodoToggle: toggleTodo) { open($0.route) }
                    .modifier(V32HomeEntrance(delay: 0.04, reduceMotion: reduceMotion))
                if !memos.isEmpty {
                    V35HomeRecentMemo(memos: Array(memos.prefix(2))) { route = .memo }
                        .padding(.top, 4)
                        .modifier(V32HomeEntrance(delay: 0.06, reduceMotion: reduceMotion))
                }
                V35HomeOverviewGrid(todoCount: summary.todos.count, expiryCount: summary.pendingExpiry.count, customerCount: summary.deliveries.count,
                                    todoInsight: summary.todos.filter { $0.dueDate?.isToday == true }.count > 0 ? "今天到期" : nil,
                                    customerInsight: summary.deliveries.count > 0 ? "待配送" : nil,
                                    expiryInsight: summary.pendingExpiry.filter { $0.daysLeft() <= 3 }.count > 0 ? "≤3天" : nil,
                                    onTodo: { tab = .todo },
                                    onCustomer: { route = .customer },
                                    onExpiry: { route = .expiry })
                    .modifier(V32HomeEntrance(delay: 0.08, reduceMotion: reduceMotion))
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        // Keep the first scroll content below the translucent system navigation bar.
        // The microphone remains a real toolbar item; this is only a container inset.
        .safeAreaPadding(.top, 12)
        .v32PageBackground()
        .v32PageBottomInset()
        .alert("操作失败", isPresented: Binding(get: { stateActionError != nil }, set: { if !$0 { stateActionError = nil } })) {
            Button("知道了", role: .cancel) { stateActionError = nil }
        } message: { Text(stateActionError ?? "待办状态未改变，请重试") }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showUtilityDrawer = true } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel("打开经营快捷中心")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showQuickRecord = true } label: {
                    Image(systemName: "mic.fill")
                }
                .accessibilityLabel("一句话快速记录")
            }
        }
        .toolbar(showUtilityDrawer ? .hidden : .visible, for: .navigationBar)
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .customer: CustomerView()
            case .expiry: ExpiryView()
            case .performance: PerformanceView()
            case .memo: MemoView()
            }
        }
        .sheet(isPresented: $showWeatherSheet) {
            // P1-4：跟随 ThemeStore / V32 tokens，不再走旧 AppTheme 链路
            WeatherDetailSheet(model: weatherModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { weatherModel.loadIfNeeded() }
        .overlay {
            if showUtilityDrawer {
                V35DrawerContainer(isPresented: $showUtilityDrawer)
                    .zIndex(100)
            }
        }
        // Home root only: the leading edge is reserved for the utility drawer.
        // Pushed NavigationStack destinations do not contain this gesture.
        .overlay(alignment: .leading) {
            if !showUtilityDrawer {
                Color.clear
                    .frame(width: 26)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 12)
                            .onEnded { value in
                                let width = UIScreen.main.bounds.width * 0.84
                                if V35DrawerGestureLogic.shouldOpen(
                                    translation: value.translation.width,
                                    predicted: value.predictedEndTranslation.width,
                                    width: width
                                ) {
                                    showUtilityDrawer = true
                                }
                            }
                    )
            }
        }
    }

    // MARK: 顶部：问候 / 日期 / 天气 / 快速记录 / 头像

    private var header: some View {
        HStack(alignment: .bottom, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greetingPrefix)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(V32.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(ownerDisplayName)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(V32.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(V32.textTertiary)
                    .padding(.top, 1)
            }
            Spacer(minLength: 12)
            weatherButton
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
                    .font(.system(size: 16, weight: .medium))
                if let weather = weatherModel.snapshot {
                    Text("\(weather.roundedTemperature)°")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
            .foregroundStyle(V32.textSecondary)
            .padding(.horizontal, 2)
            .frame(minHeight: 44)
        }
        .buttonStyle(V32PressButtonStyle())
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
    }

    private var weekRail: some View {
        let calendar = Calendar.current
        let today = Date()
        let start = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let dates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let symbols = ["一", "二", "三", "四", "五", "六", "日"]
        return HStack(spacing: 6) {
            ForEach(Array(dates.enumerated()), id: \.element) { index, date in
                VStack(spacing: 5) {
                    Text(symbols[index])
                        .font(.caption2.weight(.medium))
                    Text(date, format: .dateTime.day())
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                .foregroundStyle(date.isToday ? ThemeStore.shared.accentPalette.onAccent : V32.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(date.isToday ? ThemeStore.shared.accentPalette.accent : Color.clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("本周日期，今天是\(today.formatted(.dateTime.day()))日")
    }

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

private enum HomeRoute: Hashable { case customer, expiry, performance, memo }

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

// MARK: - 今日事项行（圆形勾选）

struct HomeActionRow: View {
    let item: HomeInboxItem
    let onTodoToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
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
        .padding(.vertical, 14)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var leading: some View {
        switch item.route {
        case .todo:
            V32Checkbox(checked: false, action: onTodoToggle)
        case .customer:
            Image(systemName: "box.truck.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(V32.brand)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        case .expiry:
            Image(systemName: "hourglass")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(V32.amber)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - 七日火花线（hero 内）

struct HomeSparkline: View {
    let points: [TrendPoint]
    let lineColor: Color
    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("日期", point.date), y: .value("营业额", point.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityLabel("最近七日营业额趋势")
    }
}
