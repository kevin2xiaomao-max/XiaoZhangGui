import SwiftUI
import SwiftData
import WidgetKit

@main
struct XiaoZhangGuiApp: App {
    /// 仅在 XCTest 单元测试宿主进程中为 true。
    /// 测试宿主渲染空页面并跳过全部启动副作用（持久容器构建、通知授权、
    /// 快照落盘、WidgetCenter、Live Activity），规避预发布版 CI 模拟器
    /// CoreDevice lockdown 停滞时启动期主线程争用导致的测试宿主挂起。
    /// 单元测试各自构建 in-memory ModelContainer，不依赖 App 启动。
    /// 生产进程中永远为 false，生产启动路径逻辑保持不变。
    private static var isUnitTesting: Bool {
        NSClassFromString("XCTestCase") != nil
    }

    // P0-2：持久化失败时 container 为 nil 且保留错误原因，
    // 绝不静默回退到可写 in-memory store（避免「假装保存成功、重启数据蒸发」）。
    private let container: ModelContainer?
    private let databaseError: Error?

    @State private var settings = AppSettings.shared
    @State private var demo = DemoMode.shared
    @State private var themeStore = ThemeStore.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if Self.isUnitTesting {
            // 测试宿主：不构建持久容器、不触发任何真实业务启动工作。
            container = nil
            databaseError = nil
            return
        }
        #if DEBUG
        if UITestMode.isEnabled {
            do {
                let testContainer = try AppDatabase.makeInMemoryContainer()
                UITestSeed.seed(ModelContext(testContainer))
                container = testContainer
                databaseError = nil
            } catch {
                container = nil
                databaseError = error
            }
            return
        }
        #endif
        // V3.3 Lite Payment QR：全屏收款码若在上次异常终止时遗留「亮度提升中」标记，
        // 启动即恢复合理亮度并清标记（正常退出/后台恢复在 PaymentCodeFullScreenView 内处理）。
        PaymentCodeBrightnessGuard.applyStartupRecovery()
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
            if Self.isUnitTesting {
                // 最小测试宿主：无 RootView、无快照、无 Live Activity。
                Color.clear
            } else if let container {
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
            guard !Self.isUnitTesting else { return }
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
