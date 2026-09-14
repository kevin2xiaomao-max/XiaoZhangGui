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
            Tab("首页", systemImage: "house", value: AppTab.home) {
                NavigationStack {
                    HomeView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer, showQuickRecord: $showQuickRecord)
                }
            }
            Tab("待办", systemImage: "checkmark.circle", value: AppTab.todo) {
                NavigationStack { TodoView() }
            }
            Tab("语音", systemImage: "mic.fill", value: AppTab.voice, role: voiceTabRole) {
                Color.clear.accessibilityLabel("语音")
            }
            Tab("业绩", systemImage: "chart.line.uptrend.xyaxis", value: AppTab.performance) {
                NavigationStack { PerformanceView() }
            }
            Tab("我的", systemImage: "person", value: AppTab.profile) {
                NavigationStack {
                    ProfileView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer)
                }
            }
        }
        .tint(V21.brandGreen)
        .onChange(of: tab) { oldValue, newValue in
            if newValue == .voice {
                guard canInitializeSpeechRecognizer else {
                    tab = oldValue == .voice ? lastContentTab : oldValue
                    return
                }
                showVoice = true
            } else {
                lastContentTab = newValue
                Haptic.light()
            }
        }
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet()
        }
        .fullScreenCover(isPresented: $showVoice, onDismiss: { tab = lastContentTab }) {
            if canInitializeSpeechRecognizer {
                VoiceView()
            }
        }
    }

    private var voiceTabRole: TabRole? {
        if #available(iOS 27.0, *) {
            return .prominent
        }
        return nil
    }
}
