import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var lastContentTab: AppTab = .home
    @State private var showVoice = false
    @State private var showQuickRecord = false
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer, showQuickRecord: $showQuickRecord)
            }
            .tabItem { Label("首页", systemImage: "house") }
            .tag(AppTab.home)

            NavigationStack { TodoView() }
                .tabItem { Label("待办", systemImage: "checkmark.circle") }
                .tag(AppTab.todo)

            Color.clear
                .tabItem { Label("语音", systemImage: "mic.circle.fill") }
                .tag(AppTab.voice)

            NavigationStack { PerformanceView() }
                .tabItem { Label("业绩", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.performance)

            NavigationStack { ProfileView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer) }
                .tabItem { Label("我的", systemImage: "person") }
                .tag(AppTab.profile)
        }
        .tint(V21.brandGreen)
        .onChange(of: tab) { oldValue, newValue in
            if newValue == .voice {
                guard canInitializeSpeechRecognizer else {
                    tab = oldValue == .voice ? .home : oldValue
                    return
                }
                showVoice = true
            } else {
                lastContentTab = newValue
                Haptic.light()
            }
        }
        .sheet(isPresented: $showQuickRecord) { QuickRecordSheet() }
        .fullScreenCover(isPresented: $showVoice, onDismiss: { tab = lastContentTab }) {
            if canInitializeSpeechRecognizer { VoiceView() }
        }
    }
}
