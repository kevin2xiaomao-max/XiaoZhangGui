import SwiftUI
import SwiftData
import PhotosUI

struct HomeView: View {
    @Binding var tab: AppTab
    @Binding var showVoice: Bool
    let showsVoiceButton: Bool
    @Binding var showQuickRecord: Bool

    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context
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
        TodaySummary.build(
            performances: performances,
            todos: todos,
            customers: customers,
            expiryItems: expiryItems
        )
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = settings.ownerName
        if hour < 11 { return "早上好，\(name)" }
        if hour < 14 { return "中午好，\(name)" }
        if hour < 18 { return "下午好，\(name)" }
        return "晚上好，\(name)"
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(Date(), format: .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(greeting)
                        .font(.title2.weight(.semibold))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: Tokens.Space.page, bottom: 4, trailing: Tokens.Space.page))
                .listRowSeparator(.hidden)
            }

            Section {
                RevenueSummary(
                    title: "今日营业额",
                    amount: summary.revenue,
                    yesterday: summary.yesterdayRevenue
                )
                TrendChart(points: summary.trend)
                    .listRowInsets(EdgeInsets(top: 4, leading: Tokens.Space.page, bottom: 8, trailing: Tokens.Space.page))
            } header: {
                Text("今日")
            }

            Section {
                if summary.todos.isEmpty {
                    Text("今天没有待办")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.todos.prefix(4)) { todo in
                        Button {
                            tab = .todo
                        } label: {
                            BusinessRow(
                                title: todo.title,
                                subtitle: todo.dueDate.map(Fmt.time),
                                systemImage: "circle",
                                badge: todo.priorityLevel.shortLabel,
                                badgeTone: todo.priority >= 2 ? .danger : .neutral
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text("待办")
                    Spacer()
                    Button("全部") { tab = .todo }.font(.footnote)
                }
            }

            Section {
                if summary.deliveries.isEmpty {
                    Text("今天暂无配送")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.deliveries.prefix(4)) { item in
                        NavigationLink(value: "customer") {
                            BusinessRow(
                                title: item.content,
                                subtitle: item.roomOrAddress.isEmpty ? item.customer : item.roomOrAddress,
                                badge: item.statusEnum.rawValue,
                                badgeTone: item.statusEnum == .pending ? .warning : .accent
                            )
                        }
                    }
                }
            } header: {
                HStack {
                    Text("配送")
                    Spacer()
                    NavigationLink("全部", value: "customer").font(.footnote)
                }
            }

            Section {
                if summary.pendingExpiry.isEmpty {
                    Text("没有待处理临时商品")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(summary.pendingExpiry.prefix(4)) { item in
                        NavigationLink(value: "expiry") {
                            BusinessRow(
                                title: "\(item.name) ×\(item.quantity)",
                                subtitle: "到期 \(Fmt.formatDate(item.expiryDate))",
                                badge: item.status.rawValue,
                                badgeTone: item.daysLeft() <= 1 ? .danger : .warning
                            )
                        }
                    }
                }
            } header: {
                HStack {
                    Text("临时商品")
                    Spacer()
                    NavigationLink("全部", value: "expiry").font(.footnote)
                }
            }

            Section("快速操作") {
                HStack(spacing: Tokens.Space.sm) {
                    QuickAction(title: "快速记录", systemImage: "square.and.pencil") {
                        showQuickRecord = true
                    }
                    QuickAction(title: "记营业额", systemImage: "yensign") {
                        showRevenueEditor = true
                    }
                }
                .listRowSeparator(.hidden)
                HStack(spacing: Tokens.Space.sm) {
                    QuickAction(title: "新增待办", systemImage: "plus") {
                        tab = .todo
                    }
                    QuickAction(title: "日报", systemImage: "doc.text") {
                        showDailyReport = true
                    }
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.visible)
        .background(Color(.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                WeatherPill(model: weatherModel, palette: AppTheme.palette(named: settings.appThemeName)) {
                    Haptic.light()
                    showWeatherSheet = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptic.light()
                    showAvatarSheet = true
                } label: {
                    AvatarBadge(settings: settings)
                }
            }
        }
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
        }
        .sheet(isPresented: $showDailyReport) {
            DailyReportSheet(report: DailyReport.build(
                performances: performances,
                todos: todos,
                customers: customers,
                expiryItems: expiryItems
            ))
        }
        .sheet(isPresented: $showRevenueEditor) {
            MoneyEditorSheet(mode: .new(.income))
        }
        .task { weatherModel.loadIfNeeded() }
    }
}

private struct AvatarBadge: View {
    let settings: AppSettings

    var body: some View {
        Group {
            if let data = settings.avatarImageData, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Text(settings.avatarEmoji).font(.body)
            }
        }
        .frame(width: 32, height: 32)
        .background(Circle().fill(Color(.tertiarySystemFill)))
        .clipShape(Circle())
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
            HStack(spacing: 12) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        settings.avatarImageData = nil
                        settings.avatarEmoji = emoji
                    } label: {
                        Text(emoji).font(.title2).frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                TextField("自定义 Emoji", text: $customEmoji)
                    .textFieldStyle(.roundedBorder)
                Button("添加") {
                    let value = customEmoji.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !value.isEmpty {
                        settings.avatarImageData = nil
                        settings.avatarEmoji = String(value.prefix(2))
                        customEmoji = ""
                    }
                }
            }
            PhotosPicker(selection: $selectedItem, matching: .images) {
                Label("从相册选择", systemImage: "photo")
            }
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        settings.avatarImageData = data
                    }
                }
            }
            Spacer()
        }
        .padding(20)
    }
}
