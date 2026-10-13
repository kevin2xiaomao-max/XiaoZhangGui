package com.xiaozhanggui.app.ui.theme.v371

import androidx.compose.ui.hapticfeedback.HapticFeedback
import androidx.compose.ui.hapticfeedback.HapticFeedbackType

/**
 * V371 统一触感（对应 iOS `DesignSystem/FloatingDock.swift` 的 `enum Haptic`）。
 *
 * **V3.7.1 触感的唯一定义点**。语义触感：selection / light / medium / success / warning / error，
 * 应用到 tab、quick action、todo completion、calendar select、save、status advance、
 * AI confirmation、Voice confirmation、destructive warning。
 * 禁止乱震、禁止各页面自发明新的触感封装；需要新语义先在此处定义。
 *
 * Android 映射（Compose 内建类型近似，平台无 iOS 同款 impact/notification 反馈）：
 * - selection（选择变化）→ SegmentTick
 * - light（轻触击）→ VirtualKey
 * - medium（中触击）→ GestureThresholdActivate
 * - success（成功）→ Confirm
 * - warning（警告）→ GestureEnd
 * - error（错误）→ Reject
 */
object V371Haptic {
    /** 选择变化（tab 切换、日历选日、列表选择） */
    fun selection(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.SegmentTick)

    /** 轻触击（press、轻量行反馈） */
    fun light(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.VirtualKey)

    /** 中触击（较重确认） */
    fun medium(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.GestureThresholdActivate)

    /** 成功（保存成功、AI/Voice 确认、状态推进） */
    fun success(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.Confirm)

    /** 警告（destructive 前警告、校验提醒） */
    fun warning(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.GestureEnd)

    /** 错误（保存失败、Voice 识别失败） */
    fun error(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.Reject)
}
