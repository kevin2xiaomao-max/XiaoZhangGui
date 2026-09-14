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
            Tab("首页", systemImage: "house") {
                NavigationStack {
                    HomeView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer, showQuickRecord: $showQuickRecord)
                }
            }
            .tag(AppTab.home)

            Tab("待办", systemImage: "checkmark.circle") {
                NavigationStack { TodoView() }
            }
            .tag(AppTab.todo)

            Tab("语音", systemImage: "mic.circle.fill") {
                Color.clear
            }
            .tag(AppTab.voice)

            Tab("业绩", systemImage: "chart.line.uptrend.xyaxis") {
                NavigationStack { PerformanceView() }
            }
            .tag(AppTab.performance)

            Tab("我的", systemImage: "person") {
                NavigationStack { ProfileView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer) }
            }
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
