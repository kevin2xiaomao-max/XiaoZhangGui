import SwiftUI

// MARK: - 系统 Tab 标识（V3.7.1 冻结 IA：四 Tab）

enum AppTab: Hashable {
    case home, todo, calendar, business

    var title: String {
        switch self {
        case .home: return "首页"
        case .todo: return "待办"
        case .calendar: return "日历"
        case .business: return "经营"
        }
    }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .todo: return "checkmark.circle"
        case .calendar: return "calendar"
        case .business: return "chart.bar.fill"
        }
    }
}

// MARK: - 触感反馈（V3.7.1 统一 Haptic System · 唯一定义点）
//
// 语义触感：selection / light / medium / success / warning / error。
// 应用到 tab、quick action、todo completion、calendar select、save、
// status advance、AI confirmation、Voice confirmation、destructive warning。
// 禁止乱震、禁止各页面自发明新的触感封装。

import UIKit

enum Haptic {
    /// 选择变化（tab 切换、日历选日、列表选择）
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
    /// 轻触击（press、轻量行反馈）
    static func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    /// 中触击（较重确认）
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    /// 成功（保存成功、AI/Voice 确认、状态推进）
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    /// 警告（destructive 前警告、校验提醒）
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    /// 错误（保存失败、Voice 识别失败）
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
