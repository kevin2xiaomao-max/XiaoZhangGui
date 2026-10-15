#if DEBUG
import SwiftUI

/// DEBUG-only 演示宿主开关。
///
/// XCUITest 以 launch argument `--v38-capture-demo` 启动时，App 跳过生产
/// RootView/TabView，直接呈现 `V38CaptureDemoHost`。Release 构建中此枚举
/// 不存在，生产启动路径不受影响。
enum V38CaptureTestHost {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--v38-capture-demo")
    }
}

/// V3.8 Worker B · AI 胶囊 + 快捷菜单隔离演示宿主。
///
/// - 仅由 `--v38-capture-demo` launch argument 打开的独立宿主，不接入 RootView。
/// - 持有两个组件的展开状态并做互斥（展开其一即收起另一）。
/// - 演示选择仅展示文案，不写库、不调 AI、不联网。
struct V38CaptureDemoHost: View {
    @State private var aiExpanded = false
    @State private var quickExpanded = false
    @State private var lastSelection: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("V3.8 · Capture 隔离演示")
                            .font(.system(size: 28, weight: .semibold, design: .rounded))
                        Text("AI 胶囊 + 快捷菜单精修版 · 无业务数据 · 无网络 · 不调真实 AI")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("v38.capture.demo.title")

                    V38AICapsuleView(isExpanded: $aiExpanded) { expanded in
                        if expanded { quickExpanded = false }
                    }

                    V38QuickMenuView(isExpanded: $quickExpanded) { expanded in
                        if expanded { aiExpanded = false }
                    } onSelect: { action in
                        lastSelection = action.title
                    }

                    if let lastSelection {
                        Text("演示选择：\(lastSelection)。未执行任何保存。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("v38.motion.demo.selection")
                    }

                    stateLine
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("V3.8 Capture 演示")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("v38.capture.demo.host")
    }

    private var stateLine: some View {
        let state = aiExpanded ? "ai-expanded" : (quickExpanded ? "quick-expanded" : "idle")
        return Text("状态：\(state)")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .accessibilityIdentifier("v38.capture.state")
    }
}

#Preview("V38 Capture Demo Host") {
    V38CaptureDemoHost()
}
#endif
