import SwiftUI
import SwiftData

struct V35DrawerContainer: View {
    @Binding var isPresented: Bool
    let onOpenProfile: () -> Void
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query private var performances: [Performance]
    @Query private var todos: [Todo]
    @Query private var customers: [CustomerRequest]
    @Query private var expiryItems: [ExpiryItem]
    @State private var dragOffset: CGFloat = 0
    @State private var showDailyReport = false
    @State private var showQuickRecord = false
    @State private var showSaobeiImport = false

    private var palette: AccentPalette { themeStore.accentPalette }
    private var todayRevenue: Double { performances.filter { $0.date.isToday }.reduce(0) { $0 + $1.amount } }
    private var todayTodoCount: Int { todos.filter { !$0.isCompleted && ($0.dueDate == nil || $0.dueDate?.isToday == true) }.count }

    var body: some View {
        GeometryReader { proxy in
            let width = min(max(proxy.size.width * 0.84, 300), 380)
            ZStack(alignment: .leading) {
                Color.black.opacity(0.23).ignoresSafeArea().contentShape(Rectangle()).onTapGesture { close() }
                drawer(width: width).offset(x: -width + max(0, width + dragOffset)).gesture(closeGesture(width: width))
            }
            .transition(.opacity)
            .animation(reduceMotion ? .easeOut(duration: 0.16) : .spring(response: 0.34, dampingFraction: 0.88), value: isPresented)
        }
        .sheet(isPresented: $showDailyReport) {
            DailyReportSheet(report: .build(performances: performances, todos: todos, customers: customers, expiryItems: expiryItems))
        }
        .sheet(isPresented: $showQuickRecord) { QuickRecordSheet() }
        .sheet(isPresented: $showSaobeiImport) { SaobeiImportSheet() }
    }

    private func drawer(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("☘️  \(settings.shopName.isEmpty ? "你的小掌柜" : settings.shopName)").font(.headline.weight(.semibold)).foregroundStyle(Color(palette.accent))
                        Text("经营快捷中心").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(V32.textPrimary)
                    }
                    Spacer()
                    Button { close() } label: { Image(systemName: "xmark").font(.subheadline.weight(.bold)).frame(width: 34, height: 34).background(Color(palette.subtleTint), in: Circle()) }.accessibilityLabel("关闭经营快捷中心")
                }.padding(.bottom, 22)
                summary.padding(.bottom, 26)
                drawerSection("经营", destinations: [.performance, .transactions, .dailyReport])
                drawerSection("经营工具", destinations: [.customer, .expiry, .goods, .memo])
                drawerSection("快捷操作", destinations: [.quickRecord, .saobeiImport])
                drawerSection("设置", destinations: [.profile])
            }
            .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 32)
        }
        .frame(width: width)
        .background(V32.cardElevated)
        .clipShape(.rect(bottomTrailingRadius: 32, topTrailingRadius: 32))
        .ignoresSafeArea()
    }

    private var summary: some View {
        HStack(spacing: 10) {
            Button { navigate(.performance) } label: { metric(title: "今日营业额", value: Fmt.money(todayRevenue), icon: "yensign") }.buttonStyle(.plain)
            metric(title: "待办", value: "\(todayTodoCount)", icon: "checkmark.circle")
        }.accessibilityElement(children: .contain)
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).foregroundStyle(Color(palette.accent))
            Text(value).font(.title3.weight(.bold).monospacedDigit()).foregroundStyle(V32.textPrimary)
            Text(title).font(.caption).foregroundStyle(V32.textSecondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(13).background(Color(palette.subtleTint), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func drawerSection(_ title: String, destinations: [V35DrawerDestination]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(1.1).foregroundStyle(V32.textTertiary).padding(.top, 10).padding(.bottom, 4)
            ForEach(destinations) { destination in drawerRow(destination) }
        }
    }

    @ViewBuilder private func drawerRow(_ destination: V35DrawerDestination) -> some View {
        if [.performance, .transactions, .customer, .expiry, .goods, .memo].contains(destination) {
            NavigationLink { destinationView(destination) } label: { rowLabel(destination) }.simultaneousGesture(TapGesture().onEnded { close() })
        } else {
            Button { navigate(destination) } label: { rowLabel(destination) }.buttonStyle(.plain)
        }
    }

    private func rowLabel(_ destination: V35DrawerDestination) -> some View {
        HStack(spacing: 13) {
            Image(systemName: destination.icon).font(.body.weight(.semibold)).foregroundStyle(Color(palette.accent)).frame(width: 26)
            Text(destination.title).font(.body.weight(.medium)).foregroundStyle(V32.textPrimary).multilineTextAlignment(.leading)
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(V32.textQuaternary)
        }.padding(.vertical, 10).contentShape(Rectangle()).accessibilityLabel(destination.title)
    }

    @ViewBuilder private func destinationView(_ destination: V35DrawerDestination) -> some View {
        switch destination {
        case .performance: PerformanceView()
        case .transactions: TransactionHistoryView()
        case .customer: CustomerView()
        case .expiry: ExpiryView()
        case .goods: GoodsView()
        case .memo: MemoView()
        default: EmptyView()
        }
    }

    private func navigate(_ destination: V35DrawerDestination) {
        close()
        switch destination {
        case .dailyReport: showDailyReport = true
        case .quickRecord: showQuickRecord = true
        case .saobeiImport: showSaobeiImport = true
        case .profile: onOpenProfile()
        default: break
        }
    }

    private func close() { dragOffset = 0; isPresented = false }
    private func closeGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10).onChanged { value in dragOffset = min(0, value.translation.width) }.onEnded { value in
            if V35DrawerGestureLogic.shouldClose(translation: value.translation.width, predicted: value.predictedEndTranslation.width, width: width) { close() } else { dragOffset = 0 }
        }
    }
}
