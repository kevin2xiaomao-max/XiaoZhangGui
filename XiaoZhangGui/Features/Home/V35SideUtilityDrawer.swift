import SwiftUI
import SwiftData

struct V35DrawerContainer: View {
    @Binding var isPresented: Bool
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
        .onAppear { Haptic.light() }
    }

    private func drawer(width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    Spacer()
                    Button { close() } label: { Image(systemName: "xmark").font(.subheadline.weight(.bold)).frame(width: 34, height: 34).background(Color(palette.subtleTint), in: Circle()) }.accessibilityLabel("关闭经营快捷中心")
                }.padding(.bottom, 22)
                drawerSection("经营", destinations: [.transactions, .dailyReport, .customer, .expiry])
                drawerSection("工具", destinations: [.goods, .memo])
                drawerSection("快捷操作", destinations: [.quickRecord, .saobeiImport])
            }
            .padding(.horizontal, 22).padding(.top, 24).padding(.bottom, 32)
        }
        .frame(width: width)
        .background(V32.cardElevated)
        .clipShape(.rect(bottomTrailingRadius: 32, topTrailingRadius: 32))
        .ignoresSafeArea()
    }

    private func drawerSection(_ title: String, destinations: [V35DrawerDestination]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(1.1).foregroundStyle(V32.textTertiary).padding(.top, 10).padding(.bottom, 4)
            ForEach(destinations) { destination in drawerRow(destination) }
        }
    }

    @ViewBuilder private func drawerRow(_ destination: V35DrawerDestination) -> some View {
        if [.transactions, .customer, .expiry, .goods, .memo].contains(destination) {
            NavigationLink { destinationView(destination) } label: { rowLabel(destination) }.simultaneousGesture(TapGesture().onEnded { close() })
        } else {
            Button { navigate(destination) } label: { rowLabel(destination) }.buttonStyle(.plain)
        }
    }

    private func rowLabel(_ destination: V35DrawerDestination) -> some View {
        HStack(spacing: 13) {
            Image(systemName: destination.icon).font(.body.weight(.semibold)).foregroundStyle(Color(palette.accent)).frame(width: 26)
            Text(destination.title).font(.body).foregroundStyle(V32.textPrimary).multilineTextAlignment(.leading)
            Spacer(minLength: 8)
        }
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(destination.title)
    }

    @ViewBuilder private func destinationView(_ destination: V35DrawerDestination) -> some View {
        switch destination {
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
