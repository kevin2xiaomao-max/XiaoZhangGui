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
 * 平台映射（Compose BOM 2024.09.00 / UI 1.7 的限制）：
 * `HapticFeedbackType` 在此版本仅暴露 LongPress / TextHandleMove 两个常量
 * （VirtualKey / SegmentTick / Confirm / Reject 等完整集合是 Compose 1.8 才加入的），
 * 因此 6 语义暂收敛为两档：
 * - selection / light（轻 tick）→ TextHandleMove
 * - medium / success / warning / error（重 tick）→ LongPress
 *
 * 语义层保持稳定：调用方一律用 `V371Haptic.success(h)` 这类语义调用；
 * 将来升级 Compose BOM 到 1.8+ 后，只需在此文件内恢复细粒度映射，
 * 调用方零改动。目标映射（待 1.8）：selection→SegmentTick、light→VirtualKey、
 * medium→GestureThresholdActivate、success→Confirm、warning→GestureEnd、error→Reject。
 */
object V371Haptic {
    /** 选择变化（tab 切换、日历选日、列表选择） */
    fun selection(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.TextHandleMove)

    /** 轻触击（press、轻量行反馈） */
    fun light(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.TextHandleMove)

    /** 中触击（较重确认） */
    fun medium(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.LongPress)

    /** 成功（保存成功、AI/Voice 确认、状态推进） */
    fun success(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.LongPress)

    /** 警告（destructive 前警告、校验提醒） */
    fun warning(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.LongPress)

    /** 错误（保存失败、Voice 识别失败） */
    fun error(h: HapticFeedback) =
        h.performHapticFeedback(HapticFeedbackType.LongPress)
}
