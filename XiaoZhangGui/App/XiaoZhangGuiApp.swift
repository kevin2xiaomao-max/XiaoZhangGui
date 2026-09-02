import SwiftUI
import SwiftData
import WidgetKit

@main
struct XiaoZhangGuiApp: App {
    let container = try? AppDatabase.makeContainer()

    @State private var settings = AppSettings.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if let container {
                RootView()
                    .modelContainer(container)
                    .environment(settings)
                    .tint(AppTheme.palette(named: settings.appThemeName).accent)
                    .preferredColorScheme(settings.colorScheme)
                    .task {
                        NotificationManager.requestAuthorization()
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
            // 小组件 / Live Activity / 锁屏数据快照刷新
            let snapshot = SnapshotSyncManager.buildSnapshot(context: ModelContext(container))
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
            if phase == .active {
                LiveActivityManager.startIfNeeded(snapshot: snapshot)
            }
        }
    }

}
