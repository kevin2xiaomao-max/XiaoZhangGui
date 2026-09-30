import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var lastContentTab: AppTab = .home
    @State private var showVoice = false
    @State private var showQuickRecord = false
    @State private var showAIVoice = false
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                Tab("首页", systemImage: "house", value: AppTab.home) {
                    NavigationStack {
                        HomeView(tab: $tab, showVoice: $showVoice, showQuickRecord: $showQuickRecord, showsVoiceButton: canInitializeSpeechRecognizer)
                    }
                }
                Tab("日程", systemImage: "calendar", value: AppTab.schedule) {
                    NavigationStack { ScheduleView() }
                }
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
            .toolbar(.hidden, for: .tabBar)
            .toolbarBackground(.hidden, for: .tabBar)

            V36FloatingTabBar(selection: $tab)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: tab) { _, newValue in
            lastContentTab = newValue
        }
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
