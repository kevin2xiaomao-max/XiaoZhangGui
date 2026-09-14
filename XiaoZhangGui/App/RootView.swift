import SwiftUI
import UIKit

@MainActor
struct RootView: View {
    @State private var tab: AppTab = .home
    @State private var showVoice = false
    @State private var showQuickRecord = false
    private let canInitializeSpeechRecognizer = SpeechService.canInitializeRecognizer

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .home:
                    NavigationStack {
                        HomeView(
                            tab: $tab,
                            showVoice: $showVoice,
                            showsVoiceButton: canInitializeSpeechRecognizer,
                            showQuickRecord: $showQuickRecord
                        )
                    }
                case .todo:
                    NavigationStack { TodoView() }
                case .performance:
                    NavigationStack { PerformanceView() }
                case .profile:
                    NavigationStack {
                        ProfileView(
                            tab: $tab,
                            showVoice: $showVoice,
                            showsVoiceButton: canInitializeSpeechRecognizer
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FloatingDock(
                selection: $tab,
                showsVoiceButton: canInitializeSpeechRecognizer
            ) {
                showVoice = true
            }
            .padding(.bottom, 4)
        }
        .ignoresSafeArea(.keyboard)
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
