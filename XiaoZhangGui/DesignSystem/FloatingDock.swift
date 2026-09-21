import SwiftUI

// MARK: - 系统 Tab 标识

enum AppTab: Hashable {
    case home, schedule, assistant, todo, profile

    var title: String {
        switch self {
        case .home: return "首页"
        case .schedule: return "日程"
        case .todo: return "待办"
        case .assistant: return "小掌柜"
        case .profile: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .schedule: return "calendar"
        case .todo: return "checkmark"
        case .assistant: return "sparkles"
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
