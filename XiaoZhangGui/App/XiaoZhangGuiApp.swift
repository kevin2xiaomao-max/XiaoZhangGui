import SwiftUI
import SwiftData
import WidgetKit

@main
struct XiaoZhangGuiApp: App {
    let container = try? AppDatabase.makeContainer()

    @State private var settings = AppSettings.shared
    @State private var demo = DemoMode.shared
    @State private var themeStore = ThemeStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .id(demo.sessionID)
                    .modelContainer(demo.isEnabled ? DemoCatalog.container : container)
                    .environment(settings)
                    .environment(themeStore)
                    .tint(V32.brand)
                    .preferredColorScheme(settings.colorScheme)
                    .task {
                        NotificationManager.requestAuthorization()
                        // 首次启动即构建当日快照并尝试创建 Live Activity，
                        // 不依赖 scenePhase 的 onChange
                        let contextContainer = demo.isEnabled ? DemoCatalog.container : container
                        let snapshot = SnapshotSyncManager.buildSnapshot(context: ModelContext(contextContainer))
                        snapshot.save()
                        WidgetCenter.shared.reloadAllTimelines()
                        LiveActivityManager.startIfNeeded(snapshot: snapshot)
                    }
            } else {
                ContentUnavailableView(
                    "数据暂时不可用",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text("请重新启动应用")
                )
                .preferredColorScheme(settings.colorScheme)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active || phase == .background,
                  let container else { return }
            let contextContainer = demo.isEnabled ? DemoCatalog.container : container
            let snapshot = SnapshotSyncManager.buildSnapshot(context: ModelContext(contextContainer))
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
            if phase == .active {
                LiveActivityManager.startIfNeeded(snapshot: snapshot)
            }
        }
    }
}
