import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var showVoice = false
    @State private var showQuickRecord = false
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView(
                    tab: $tab,
                    showVoice: $showVoice,
                    showsVoiceButton: canInitializeSpeechRecognizer,
                    showQuickRecord: $showQuickRecord
                )
            }
            .tabItem { Label("今日", systemImage: "sun.max") }
            .tag(AppTab.home)

            NavigationStack {
                TodoView()
            }
            .tabItem { Label("待办", systemImage: "checkmark.circle") }
            .tag(AppTab.todo)

            NavigationStack {
                PerformanceView()
            }
            .tabItem { Label("业绩", systemImage: "chart.line.uptrend.xyaxis") }
            .tag(AppTab.performance)

            NavigationStack {
                ProfileView(
                    tab: $tab,
                    showVoice: $showVoice,
                    showsVoiceButton: canInitializeSpeechRecognizer
                )
            }
            .tabItem { Label("我的", systemImage: "person") }
            .tag(AppTab.profile)
        }
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet()
        }
        .fullScreenCover(isPresented: $showVoice) {
            if canInitializeSpeechRecognizer {
                VoiceView()
            }
        }
        .onChange(of: showVoice) { _, isPresented in
            if isPresented && !canInitializeSpeechRecognizer {
                showVoice = false
            }
        }
    }
}
