import SwiftUI

// MARK: - 系统 Tab 标识

enum AppTab: Hashable {
    case home, todo, voice, performance, profile

    var title: String {
        switch self {
        case .home: return "首页"
        case .performance: return "业绩"
        case .todo: return "待办"
        case .voice: return "语音"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .performance: return "chart.line.uptrend.xyaxis"
        case .todo: return "checkmark"
        case .voice: return "mic.circle.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - 触感反馈

import UIKit

enum Haptic {
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}
