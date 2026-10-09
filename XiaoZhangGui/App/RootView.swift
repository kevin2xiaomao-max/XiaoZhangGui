import SwiftUI
import SwiftData
import Speech

// MARK: - V3.7.1 Root Shell（P0-A：纯原生 TabView）
//
// 冻结 IA：首页 / 待办 / 日历 / 经营。使用系统原生 TabView，
// 不再叠加自定义 FloatingTabDock（iOS 27 双 Tab 问题根因）。
// AI 不再是 Tab：xzg://ai / aivoice 深链与首页入口
// 都打开 AIChatView sheet（AI 执行语义不变）。
// 「我的」从首页右上角头像进入（HomeView route=.profile）。

struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var showVoice = false
    @State private var showQuickRecord = false
    @State private var showAI = false
    @State private var showAIVoice = false
    @Environment(\.modelContext) private var modelContext
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    var body: some View {
        TabView(selection: $tab) {
            Tab("首页", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack {
                    HomeView(
                        tab: $tab,
                        showVoice: $showVoice,
                        showQuickRecord: $showQuickRecord,
                        showAI: $showAI,
                        showsVoiceButton: canInitializeSpeechRecognizer || UITestMode.isEnabled
                    )
                }
            }
            .accessibilityIdentifier(V371AccessibilityID.tabHome)
            Tab("待办", systemImage: "checkmark.circle", value: AppTab.todo) {
                NavigationStack {
                    TodoView()
                }
            }
            .accessibilityIdentifier(V371AccessibilityID.tabTodo)
            Tab("日历", systemImage: "calendar", value: AppTab.calendar) {
                NavigationStack {
                    ScheduleView()
                }
            }
            .accessibilityIdentifier(V371AccessibilityID.tabCalendar)
            Tab("经营", systemImage: "chart.bar.fill", value: AppTab.business) {
                NavigationStack {
                    PerformanceView()
                }
            }
            .accessibilityIdentifier(V371AccessibilityID.tabBusiness)
        }
        .tint(V371.Colors.blue)
        .onOpenURL(perform: handleDeepLink)
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet()
        }
        .sheet(isPresented: $showVoice) {
            // 直接使用 App 级主 modelContext：语音数据与主 App 同库，
            // 不再创建重复容器（曾导致 UI 测试模式下内存库隔离、生产回退进演示库）。
            VoiceView(viewModel: VoiceViewModel(context: modelContext))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAI) {
            NavigationStack {
                AIChatView(voiceDeepLink: $showAIVoice)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func handleDeepLink(_ url: URL) {
        // V3.3 Deep Link 契约（AppDeepLink，可单测）：xzg://voice、
        // xzg://quickrecord（quick 别名）、xzg://ai[?mode=voice]
        guard let route = AppDeepLink.route(url: url) else { return }
        switch route {
        case .voice:
            showVoice = true
        case .quickRecord:
            showQuickRecord = true
        case .ai(let voiceMode):
            // AI 不再是 Tab：以 sheet 呈现；若已在展示则先关闭再重开，保证入口可达
            if showAI {
                showAIVoice = false
                showAI = false
            }
            showAI = true
            showAIVoice = voiceMode
        }
    }
}
