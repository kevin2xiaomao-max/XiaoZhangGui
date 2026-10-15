package com.xiaozhanggui.app.ui.poc.prep

/**
 * Phase 3 四个动效的独立回退开关名（Design System §2.3：每页独立开关）。
 *
 * 命名约定：`prep.motion.<页面>.<动效>`。开关的语义挂在对应
 * [com.xiaozhanggui.app.ui.motion.MotionSpec.enabled] 上：
 * false → 该动效回到 V3.7.1 行为（瞬切、无动效），
 * 具名原因 `motion-disabled`（见 [com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons]）。
 *
 * 准备阶段开关**不接线**（不读设置/远程配置），仅声明名称供 Phase 3
 * 接线与验收脚本引用；真正的接线由 Phase 3 完成，见
 * `docs/ANDROID_V38_PHASE3_PREP.md` §6。
 */
object PrepSwitches {
    /** 首页 AI Sheet 液滴展开（§3.1）。 */
    const val HOME_AI_SHEET = "prep.motion.home.ai-sheet-expand"

    /** 待办勾选触感 + 状态动画（§3.2）。 */
    const val TODO_TOGGLE = "prep.motion.todo.toggle"

    /** 日历周切换双轨运动（§3.3）。 */
    const val CALENDAR_WEEK = "prep.motion.calendar.week-switch"

    /** 经营数字滚动呈现（§3.4）。 */
    const val PERFORMANCE_NUMBER = "prep.motion.performance.number-roll"
}
