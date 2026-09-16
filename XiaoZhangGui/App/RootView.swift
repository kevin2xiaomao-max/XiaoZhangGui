import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var lastContentTab: AppTab = .home
    @State private var showVoice = false
    @State private var showQuickRecord = false
    /// xzg://ai?mode=voice 到达后，通知小掌柜页拉起短语音面板
    @State private var showAIVoice = false
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    var body: some View {
        // P0-3：壁纸由 v32PageBackground() 在各页面内部渲染，容器不额外铺底。
        TabView(selection: $tab) {
            Tab("首页", systemImage: "house", value: AppTab.home) {
                NavigationStack {
                    HomeView(tab: $tab, showVoice: $showVoice, showQuickRecord: $showQuickRecord, showsVoiceButton: canInitializeSpeechRecognizer)
                }
            }
            Tab("日程", systemImage: "calendar", value: AppTab.schedule) {
                NavigationStack { ScheduleView() }
            }
            // V3.3：第三个 Tab 从「语音占位 + Sheet」升级为独立的小掌柜 AI 页
            Tab("小掌柜", systemImage: "sparkles", value: AppTab.assistant) {
                NavigationStack {
                    AIChatView(voiceDeepLink: $showAIVoice)
                }
            }
            Tab("待办", systemImage: "checkmark.circle", value: AppTab.todo) {
                NavigationStack { TodoView() }
            }
            Tab("我的", systemImage: "person", value: AppTab.profile) {
                NavigationStack {
                    ProfileView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer)
                }
            }
        }
            .tint(V32.brand)
            .onChange(of: tab) { _, newValue in
                lastContentTab = newValue
                Haptic.light()
            }
            // Deep Link：xzg://voice 旧语音、xzg://quickrecord 快速记录、
            // xzg://ai 小掌柜、xzg://ai?mode=voice 小掌柜短语音
            .onOpenURL { url in
                handleDeepLink(url)
            }
            .sheet(isPresented: $showQuickRecord) {
                QuickRecordSheet()
            }
            .sheet(isPresented: $showVoice) {
                if canInitializeSpeechRecognizer {
                    VoiceView()
                        .presentationDetents([.height(260), .height(340)])
                        .presentationDragIndicator(.visible)
                        .presentationCornerRadius(28)
                }
            }
    }

    private func handleDeepLink(_ url: URL) {
        guard let route = AppDeepLink.route(url: url) else { return }
        switch route {
        case .voice:
            showVoice = true
        case .quickRecord:
            showQuickRecord = true
        case .ai(let voiceMode):
            tab = .assistant
            if voiceMode { showAIVoice = true }
        }
    }
}