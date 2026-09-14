import Charts
import PhotosUI
import SwiftData
import SwiftUI

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
    @State private var route: HomeRoute?
    @State private var showAvatarSheet = false
    @State private var showWeatherSheet = false
    @State private var selectedAvatarItem: PhotosPickerItem?
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

    private var greeting: String {
        Greeting.phrase(owner: settings.ownerName)
    }

    private var handlingItems: [HomeInboxItem] {
        HomeInbox.items(todos: summary.todos, deliveries: summary.deliveries, expiryItems: summary.pendingExpiry)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                revenue
                businessCounts
                handlingList
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background {
            ZStack {
                Color(.systemGroupedBackground)
                V21.background.opacity(0.7)
            }
            .ignoresSafeArea()
        }
        .navigationTitle("你的小掌柜")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showQuickRecord = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .accessibilityLabel("快速记录")
            }
        }
        .navigationDestination(item: $route) { destination in
            switch destination {
            case .customer: CustomerView()
            case .expiry: ExpiryView()
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
        .task { weatherModel.loadIfNeeded() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            weatherButton
            Button { showAvatarSheet = true } label: { HomeAvatar(settings: settings) }
                .buttonStyle(.plain)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("更换头像")
        }
    }

    private var weatherButton: some View {
        Button { showWeatherSheet = true } label: {
            HStack(spacing: 4) {
                Image(systemName: weatherModel.snapshot?.symbolName ?? "cloud.sun")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                if let weather = weatherModel.snapshot {
                    Text("\(weather.roundedTemperature)°")
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            .frame(minWidth: 36, minHeight: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weatherModel.snapshot.map { "\($0.city)，\($0.roundedTemperature)度" } ?? "天气")
    }

    private var revenue: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("今日营业额")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Fmt.money(summary.revenue))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)
                    revenueChange
                }
                Spacer(minLength: 4)
                if summary.trend.contains(where: { $0.value > 0 }) {
                    HomeSparkline(points: summary.trend)
                        .frame(width: 96, height: 36)
                }
            }
            HStack(spacing: 8) {
                Text("本月 \(Fmt.money(monthRevenue))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("目标 \(Fmt.money(monthGoal))")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Text("\(Int((goalProgress * 100).rounded()))%")
                    .monospacedDigit()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            ProgressView(value: goalProgress)
                .tint(V21.brandGreen)
                .scaleEffect(x: 1, y: 0.7, anchor: .center)
        }
        .padding(16)
        .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private var revenueChange: some View {
        if let change = summary.changePercent {
            Label {
                Text("\(String(format: "%.1f", abs(change)))% 较昨日")
            } icon: {
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(change >= 0 ? V21.brandGreen : V21.danger)
        } else {
            Text("暂无昨日对比").font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var businessCounts: some View {
        HStack(spacing: 0) {
            HomeCountButton(value: summary.todos.count, label: "待办") { tab = .todo }
            Divider().frame(height: 28)
            HomeCountButton(value: summary.deliveries.count, label: "配送") { route = .customer }
            Divider().frame(height: 28)
            HomeCountButton(value: summary.pendingExpiry.count, label: "临期") { route = .expiry }
        }
        .padding(.vertical, 2)
        .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
        )
    }

    private var handlingList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("需要你处理")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button("查看全部") { tab = .todo }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                if handlingItems.isEmpty {
                    AppEmptyState(title: "今天没有待处理事项", systemImage: "checkmark.circle", actionTitle: "记一笔") {
                        showQuickRecord = true
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(Array(handlingItems.enumerated()), id: \.element.id) { index, item in
                        Button { open(item.route) } label: { HomeHandlingRow(item: item) }
                            .buttonStyle(.plain)
                        if index < handlingItems.count - 1 { Divider().padding(.leading, 58) }
                    }
                }
            }
            .padding(.horizontal, 14)
            .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
            )
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

private enum HomeRoute: Hashable { case customer, expiry }

private struct HomeHandlingRow: View {
    let item: HomeInboxItem
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(toneColor)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            Text(item.time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var toneColor: Color {
        switch item.tone {
        case .normal: return V21.textQuaternary
        case .accent: return V21.brandGreen
        case .warning: return .orange
        case .urgent: return V21.danger
        }
    }
}

private struct HomeCountButton: View {
    let value: Int
    let label: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct HomeSparkline: View {
    let points: [TrendPoint]
    var body: some View {
        Chart(points) { point in
            LineMark(x: .value("日期", point.date), y: .value("营业额", point.value))
                .interpolationMethod(.catmullRom)
                .foregroundStyle(V21.brandGreen)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .accessibilityLabel("最近七日营业额趋势")
    }
}

private struct HomeAvatar: View {
    let settings: AppSettings
    var body: some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(settings.avatarEmoji).font(.title3)
            }
        }
        .frame(width: 36, height: 36)
        .background(V21.surfacePrimary, in: Circle())
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.separator).opacity(0.4), lineWidth: 0.5))
    }
}

private struct AvatarPickerSheet: View {
    let settings: AppSettings
    @Binding var selectedItem: PhotosPickerItem?
    @State private var customEmoji = ""
    private let emojis = ["😀", "😎", "🥰", "🐼", "🐶", "🏪", "☕️"]

    var body: some View {
        NavigationStack {
            Form {
                Section("选择 Emoji") {
                    HStack(spacing: 8) {
                        ForEach(emojis, id: \.self) { emoji in
                            Button(emoji) { settings.avatarImageData = nil; settings.avatarEmoji = emoji }
                                .font(.title2)
                                .frame(minWidth: 40, minHeight: 44)
                        }
                    }
                    TextField("自定义 Emoji", text: $customEmoji)
                        .onSubmit(addEmoji)
                }
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("从相册选择", systemImage: "photo")
                    }
                }
            }
            .navigationTitle("我的头像")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) { settings.avatarImageData = data }
                }
            }
        }
    }

    private func addEmoji() {
        let value = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        settings.avatarImageData = nil
        settings.avatarEmoji = String(value.prefix(2))
        customEmoji = ""
    }
}
