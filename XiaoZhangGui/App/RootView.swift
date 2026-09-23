import SwiftUI
import SwiftData
import Speech

// MARK: - V3.7.1 Root Shell（§4：四 Tab 悬浮 dock）
//
// 冻结 IA：首页 / 待办 / 日历 / 经营。系统 TabBar 隐藏，
// 由 V371 FloatingTabDock（S3 surface）承载切换。
// AI 不再是 Tab：xzg://ai / aivoice 深链与首页紧凑入口
// 都打开 AIChatView sheet（AI 执行语义不变）。
// 「我的」从首页右上角头像进入（HomeView route=.profile）。

struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var showVoice = false
    @State private var showQuickRecord = false
    @State private var showAI = false
    @State private var showAIVoice = false
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    private var sharedContainer: ModelContainer {
        UITestMode.isEnabled ? UITestMode.container : AppDatabase.shared.container
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("首页", systemImage: "house.fill", value: AppTab.home) {
                NavigationStack {
                    HomeView(
                        tab: $tab,
                        showVoice: $showVoice,
                        showQuickRecord: $showQuickRecord,
                        showsVoiceButton: canInitializeSpeechRecognizer,
                        showAI: $showAI
                    )
                }
            }
            Tab("待办", systemImage: "checkmark.circle", value: AppTab.todo) {
                NavigationStack {
                    TodoView()
                }
            }
            Tab("日历", systemImage: "calendar", value: AppTab.calendar) {
                NavigationStack {
                    ScheduleView()
                }
            }
            Tab("经营", systemImage: "chart.bar.fill", value: AppTab.business) {
                NavigationStack {
                    PerformanceView()
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .tint(V371.Colors.blue)
        .overlay(alignment: .bottom) {
            FloatingTabDock(selection: $tab, tabs: [.home, .todo, .calendar, .business])
        }
        .onOpenURL(perform: handleDeepLink)
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet()
        }
        .sheet(isPresented: $showVoice) {
            VoiceView(viewModel: VoiceViewModel(context: ModelContext(sharedContainer)))
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
