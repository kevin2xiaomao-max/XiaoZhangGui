import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool
    @Binding var showQuickRecord: Bool

    @Environment(AppSettings.self) private var settings
    @Bindable private var demo = DemoMode.shared
    @Query private var todos: [Todo]
    @Query private var performances: [Performance]
    @Query private var expiryItems: [ExpiryItem]
    @Query private var customers: [CustomerRequest]
    @State private var showAvatarSheet = false
    @State private var showWeatherSheet = false
    @State private var showDailyReport = false
    @State private var showRevenueEditor = false
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var weatherModel = WeatherViewModel()

    private var summary: TodaySummary {
        TodaySummary.build(performances: performances, todos: todos, customers: customers, expiryItems: expiryItems)
    }

    private var monthRevenue: Double {
        if demo.isEnabled { return DemoCatalog.monthlyRevenue }
        performances.filter { $0.date >= Date().startOfMonth && $0.date <= Date().endOfDay }.reduce(0) { $0 + $1.amount }
    }

    private var monthGoal: Double {
        demo.isEnabled ? DemoCatalog.monthlyGoal : settings.monthGoal
    }

    private var goalProgress: Double {
        guard monthGoal > 0 else { return 0 }
        return min(monthRevenue / monthGoal, 1)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let prefix = hour < 11 ? "早上好" : hour < 14 ? "中午好" : hour < 18 ? "下午好" : "晚上好"
        return "\(prefix)，\(settings.ownerName) 👋"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.lg) {
                HomeBrandHeader(
                    greeting: greeting,
                    weatherModel: weatherModel,
                    palette: AppTheme.palette(named: settings.appThemeName),
                    settings: settings,
                    showWeather: { showWeatherSheet = true },
                    showAvatar: { showAvatarSheet = true }
                )
                HomeRevenuePanel(summary: summary, monthRevenue: monthRevenue, monthGoal: monthGoal, goalProgress: goalProgress)
                todoSection
                deliverySection
                expirySection
                HomeQuickActions(
                    quickRecord: { showQuickRecord = true },
                    revenue: { showRevenueEditor = true },
                    todo: { tab = .todo },
                    report: { showDailyReport = true }
                )
            }
            .padding(.horizontal, Tokens.Space.page)
            .padding(.top, Tokens.Space.sm)
            .padding(.bottom, Tokens.Space.xl)
        }
        .background(HomeMintBackdrop())
        .navigationBarHidden(true)
        .navigationDestination(for: String.self) { route in
            switch route {
            case "memo": MemoView()
            case "expiry": ExpiryView()
            case "calendar": CalendarView()
            case "customer": CustomerView()
            case "goods": GoodsView()
            default: EmptyView()
            }
        }
        .sheet(isPresented: $showAvatarSheet) {
            AvatarPickerSheet(settings: settings, selectedItem: $selectedAvatarItem)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showWeatherSheet) {
            WeatherDetailSheet(model: weatherModel, palette: AppTheme.palette(named: settings.appThemeName))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDailyReport) {
            DailyReportSheet(report: DailyReport.build(performances: performances, todos: todos, customers: customers, expiryItems: expiryItems))
        }
        .sheet(isPresented: $showRevenueEditor) { MoneyEditorSheet(mode: .new(.income)) }
        .task { weatherModel.loadIfNeeded() }
    }

    private var todoSection: some View {
        HomeCompactSection(title: "今日待办", countText: "\(summary.todos.count) 件") {
            if summary.todos.isEmpty {
                HomeStatusLine(text: "今天没有未完成待办", systemImage: "checkmark.circle")
            } else {
                ForEach(summary.todos.prefix(3)) { todo in
                    Button { tab = .todo } label: {
                        BusinessRow(title: todo.title, subtitle: todo.dueDate.map(Fmt.time) ?? "今天", badge: todo.priorityLevel.shortLabel, badgeTone: todo.priority >= 2 ? .danger : .neutral)
                    }
                    .buttonStyle(.plain)
                }
                Button("查看全部", systemImage: "chevron.right") { tab = .todo }.font(.footnote)
            }
        }
    }

    private var deliverySection: some View {
        HomeCompactSection(title: "客户配送", countText: "\(summary.deliveries.count) 单") {
            if summary.deliveries.isEmpty {
                HomeStatusLine(text: "今天暂无待处理配送", systemImage: "shippingbox")
            } else {
                ForEach(summary.deliveries.prefix(3)) { item in
                    NavigationLink(value: "customer") {
                        BusinessRow(title: item.content, subtitle: item.roomOrAddress, badge: item.statusEnum.rawValue, badgeTone: item.statusEnum == .pending ? .warning : .accent)
                    }
                }
                NavigationLink("查看全部", value: "customer").font(.footnote)
            }
        }
    }

    private var expirySection: some View {
        HomeCompactSection(title: "临时商品", countText: "\(summary.pendingExpiry.count) 项") {
            if summary.pendingExpiry.isEmpty {
                HomeStatusLine(text: "没有待处理临时商品", systemImage: "clock.badge.checkmark")
            } else {
                ForEach(summary.pendingExpiry.prefix(3)) { item in
                    NavigationLink(value: "expiry") {
                        BusinessRow(title: "\(item.name) ×\(item.quantity)", subtitle: item.daysLeft() == 0 ? "今天处理" : "\(item.daysLeft()) 天后到期", badge: item.daysLeft() <= 1 ? "尽快处理" : "待处理", badgeTone: item.daysLeft() <= 1 ? .danger : .warning)
                    }
                }
                NavigationLink("查看全部", value: "expiry").font(.footnote)
            }
        }
    }
}

private struct HomeBrandHeader: View {
    let greeting: String
    let weatherModel: WeatherViewModel
    let palette: AppThemePalette
    let settings: AppSettings
    let showWeather: () -> Void
    let showAvatar: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("你的小掌柜").font(.largeTitle.bold())
                Spacer(minLength: 6)
                WeatherPill(model: weatherModel, palette: palette, action: showWeather)
                Button(action: showAvatar) { HomeAvatar(settings: settings) }
                    .buttonStyle(.plain)
                    .frame(width: 44, height: 44)
                    .accessibilityLabel("更换头像")
            }
            Text(greeting).font(.title3)
            Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HomeAvatar: View {
    let settings: AppSettings
    var body: some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else { Text(settings.avatarEmoji).font(.title3) }
        }
        .frame(width: 38, height: 38)
        .background(V21.surfacePrimary, in: Circle())
        .clipShape(Circle())
        .overlay(Circle().stroke(V21.divider, lineWidth: 0.5))
    }
}

private struct HomeRevenuePanel: View {
    let summary: TodaySummary
    let monthRevenue: Double
    let monthGoal: Double
    let goalProgress: Double
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            RevenueSummary(title: "今日营业额", amount: summary.revenue, yesterday: summary.yesterdayRevenue)
            HStack {
                Text("本月 \(Fmt.money(monthRevenue))")
                Spacer()
                Text("目标 \(Fmt.money(monthGoal))")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            ProgressView(value: goalProgress).tint(.accentColor)
            if summary.trend.contains(where: { $0.value > 0 }) { TrendChart(points: summary.trend) }
        }
        .padding(Tokens.Space.md)
        .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: Tokens.Radius.xl))
        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.xl).stroke(V21.divider, lineWidth: 0.5))
    }
}

private struct HomeCompactSection<Content: View>: View {
    let title: String
    let countText: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.headline); Spacer(); Text(countText).font(.subheadline).foregroundStyle(.secondary) }
            VStack(spacing: 0) { content }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: Tokens.Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.lg).stroke(V21.divider, lineWidth: 0.5))
        }
    }
}

private struct HomeStatusLine: View {
    let text: String
    let systemImage: String
    var body: some View {
        Label(text, systemImage: systemImage).font(.subheadline).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10)
    }
}

private struct HomeQuickActions: View {
    let quickRecord: () -> Void
    let revenue: () -> Void
    let todo: () -> Void
    let report: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("快捷操作").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                QuickAction(title: "快速记录", systemImage: "square.and.pencil", action: quickRecord)
                QuickAction(title: "记营业额", systemImage: "yensign", action: revenue)
                QuickAction(title: "新增待办", systemImage: "plus.circle", action: todo)
                QuickAction(title: "日报", systemImage: "doc.text", action: report)
            }
        }
    }
}

private struct HomeMintBackdrop: View {
    var body: some View {
        ZStack {
            V21.background
            LinearGradient(colors: [V21.brandGreen.opacity(0.055), .clear, V21.brandGreen.opacity(0.025)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }.ignoresSafeArea()
    }
}

private struct AvatarPickerSheet: View {
    let settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @State private var customEmoji = ""
    private let emojis = ["😀", "😎", "🥰", "🐼", "🐶", "🏪", "☕️"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("我的头像").font(.headline)
            HStack(spacing: 8) {
                ForEach(emojis, id: \.self) { emoji in
                    Button(emoji) { settings.avatarImageData = nil; settings.avatarEmoji = emoji }
                        .font(.title2).frame(minWidth: 40, minHeight: 44)
                }
            }
            TextField("自定义 Emoji", text: $customEmoji).textFieldStyle(.roundedBorder).onSubmit(addEmoji)
            Button("添加", action: addEmoji).disabled(customEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            PhotosPicker(selection: $selectedItem, matching: .images) { Label("从相册选择", systemImage: "photo") }
                .onChange(of: selectedItem) { _, item in
                    guard let item else { return }
                    Task { if let data = try? await item.loadTransferable(type: Data.self) { settings.avatarImageData = data } }
                }
            Spacer()
        }.padding(20)
    }

    private func addEmoji() {
        let value = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        settings.avatarImageData = nil
        settings.avatarEmoji = String(value.prefix(2))
        customEmoji = ""
    }
}
