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
                    HomeView(tab: $tab, showVoice: $showVoice, showsVoiceButton: canInitializeSpeechRecognizer)
                }
            }
            Tab("日程", systemImage: "calendar", value: AppTab.schedule) {
                NavigationStack { ScheduleView() }
            }
            Tab("语音", systemImage: "mic.fill", value: AppTab.voice, role: voiceTabRole) {
                Color.clear
                    .accessibilityHidden(true)
                    .accessibilityLabel("语音")
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
        .onChange(of: tab) { oldValue, newValue in
            if newValue == .voice {
                guard canInitializeSpeechRecognizer else {
                    tab = oldValue == .voice ? lastContentTab : oldValue
                    return
                }
                showVoice = true
                // 立即回到上一个内容 tab，避免语音占位 tab 高亮残留
                tab = lastContentTab
            } else {
                lastContentTab = newValue
                Haptic.light()
            }
        }
        // 锁屏 / Deep Link 统一入口：xzg://voice → 语音  xzg://quickrecord → 文字快速记录
        .onOpenURL { url in
            handleDeepLink(url)
        }
        .sheet(isPresented: $showQuickRecord) {
            QuickRecordSheet()
        }
        .sheet(isPresented: $showVoice, onDismiss: { tab = lastContentTab }) {
            if canInitializeSpeechRecognizer {
                VoiceView()
                    .presentationDetents([.height(260), .height(340)])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(28)
            }
        }
    }

    private func handleDeepLink(_ url: URL) {
        switch url.host?.lowercased() {
        case "voice":
            showVoice = true
        case "quickrecord", "quick":
            showQuickRecord = true
        default:
            break
        }
    }

    private var voiceTabRole: TabRole? {
        if #available(iOS 27.0, *) {
            return .prominent
        }
        return nil
    }
}
