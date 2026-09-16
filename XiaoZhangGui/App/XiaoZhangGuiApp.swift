import SwiftUI
import SwiftData
import WidgetKit

@main
struct XiaoZhangGuiApp: App {
    // P0-2：持久化失败时 container 为 nil 且保留错误原因，
    // 绝不静默回退到可写 in-memory store（避免「假装保存成功、重启数据蒸发」）。
    private let container: ModelContainer?
    private let databaseError: Error?

    @State private var settings = AppSettings.shared
    @State private var demo = DemoMode.shared
    @State private var themeStore = ThemeStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let resolved = try AppDatabase.makeContainer()
            container = resolved
            databaseError = nil
        } catch {
            container = nil
            databaseError = error
        }
    }

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
                        // P1-4：只有成功构建完整快照才落盘，失败时保留上一次有效快照
                        if let snapshot = SnapshotSyncManager.buildSnapshot(context: ModelContext(contextContainer)) {
                            snapshot.save()
                            WidgetCenter.shared.reloadAllTimelines()
                            LiveActivityManager.startIfNeeded(snapshot: snapshot)
                        }
                    }
            } else {
                // P0-2：存储不可用时显式告知，不伪装成正常 App
                ContentUnavailableView(
                    "数据存储暂不可用",
                    systemImage: "externaldrive.badge.exclamationmark",
                    description: Text(databaseError?.localizedDescription ?? "请重新启动应用")
                )
                .preferredColorScheme(settings.colorScheme)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active || phase == .background,
                  let container else { return }
            let contextContainer = demo.isEnabled ? DemoCatalog.container : container
            // P1-4：查询失败不覆盖旧快照，Widget / Live Activity 继续显示上次有效数据
            guard let snapshot = SnapshotSyncManager.buildSnapshot(context: ModelContext(contextContainer)) else { return }
            snapshot.save()
            WidgetCenter.shared.reloadAllTimelines()
            if phase == .active {
                LiveActivityManager.startIfNeeded(snapshot: snapshot)
            }
        }
    }
}
