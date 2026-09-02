import SwiftUI
import UIKit

// MARK: - 根视图
// 4 个 Tab（NavigationStack）+ 自定义 Floating Dock + 中央语音 fullScreenCover
// 二级页面（备忘/临期/日历/客户/临时商品）在对应 Tab 的 NavigationStack 内 push

@MainActor
struct RootView: View {
    @State private var tab: AppTab
    @State private var showVoice = false
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    init() {
        _tab = State(initialValue: .home)
        UITabBar.appearance().isHidden = true
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $tab) {
                NavigationStack {
                    HomeView(
                        tab: $tab,
                        showVoice: $showVoice,
                        showsVoiceButton: canInitializeSpeechRecognizer
                    )
                }
                .tag(AppTab.home)

                NavigationStack {
                    TodoView()
                }
                .tag(AppTab.todo)

                NavigationStack {
                    PerformanceView()
                }
                .tag(AppTab.performance)

                NavigationStack {
                    ProfileView(
                        tab: $tab,
                        showVoice: $showVoice,
                        showsVoiceButton: canInitializeSpeechRecognizer
                    )
                }
                .tag(AppTab.profile)

            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: V21Layout.dockHeight + V21Layout.spaceXL)
            }

            FloatingDock(
                selection: $tab,
                showsVoiceButton: canInitializeSpeechRecognizer,
                onVoice: { showVoice = true }
            )
            .padding(.bottom, 8)
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
