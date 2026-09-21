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
                               expiryItems: summary.pendingExpiry, limit: 2)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: V32Layout.sectionGap) {
                header
                V35HomeRevenueHero(summary: summary, monthRevenue: monthRevenue, monthGoal: monthGoal) { route = .performance }
                    .modifier(V32HomeEntrance(delay: 0, reduceMotion: reduceMotion))
                V35HomeFocusSection(items: handlingItems, onTodoToggle: toggleTodo) { open($0.route) }
                    .modifier(V32HomeEntrance(delay: 0.04, reduceMotion: reduceMotion))
                V35HomeOverviewGrid(todoCount: summary.todos.count, expiryCount: summary.pendingExpiry.count, customerCount: summary.deliveries.count)
                    .modifier(V32HomeEntrance(delay: 0.06, reduceMotion: reduceMotion))
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
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
        .buttonStyle(V32PressButtonStyle())
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
        .buttonStyle(V32PressButtonStyle())
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
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

private enum HomeRoute: Hashable { case customer, expiry, performance }

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
