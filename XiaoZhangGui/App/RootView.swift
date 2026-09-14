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
        Group {
            if #available(iOS 18.0, *) {
                modernTabView
            } else {
                legacyTabView
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

    @available(iOS 18.0, *)
    private var modernTabView: some View {
        TabView(selection: $tab) {
            Tab(value: AppTab.home) {
                NavigationStack {
                    HomeView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer, showQuickRecord: $showQuickRecord)
                }
            } label: {
                Label("首页", systemImage: "house")
            }
            Tab(value: AppTab.todo) {
                NavigationStack { TodoView() }
            } label: {
                Label("待办", systemImage: "checkmark.circle")
            }
            Tab(value: AppTab.voice, role: voiceTabRole) {
                Color.clear.accessibilityLabel("语音")
            } label: {
                Label("语音", systemImage: "mic.fill")
            }
            Tab(value: AppTab.performance) {
                NavigationStack { PerformanceView() }
            } label: {
                Label("业绩", systemImage: "chart.line.uptrend.xyaxis")
            }
            Tab(value: AppTab.profile) {
                NavigationStack {
                    ProfileView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer)
                }
            } label: {
                Label("我的", systemImage: "person")
            }
        }
    }

    @available(iOS 18.0, *)
    private var voiceTabRole: TabRole? {
        #if compiler(>=6.3)
        if #available(iOS 27.0, *) {
            return .prominent
        }
        #endif
        return nil
    }

    private var legacyTabView: some View {
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
                .tabItem { Label("语音", systemImage: "mic.fill") }
                .tag(AppTab.voice)

            NavigationStack { PerformanceView() }
                .tabItem { Label("业绩", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.performance)

            NavigationStack {
                ProfileView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer)
            }
            .tabItem { Label("我的", systemImage: "person") }
            .tag(AppTab.profile)
        }
    }
}
