package com.xiaozhanggui.app.ui.poc.prep

/**
 * Phase 3 接入准备包（V3.8 Phase 3，准备 track；**只做准备，不接线生产页面**）。
 *
 * - 本包内全部是**声明草案 + 纯函数数学**：`MotionSpec` 声明、材质声明、
 *   相位/插值/相位窗口的纯函数；不引用任何生产页面组件
 *   （`HomeScreen` / `TodoScreen` / `CalendarScreen` / `PerformanceScreen`
 *   及其 ViewModel/Repository 均不在本包的引用范围）；
 * - 本包**不被生产代码引用**：生产页禁止引用 `ui.poc` 下任何符号
 *   （grep 门禁，见 PoC 报告）；本包随 PoC 代码一起受
 *   [com.xiaozhanggui.app.ui.poc.PocGate] 编译门约束；
 * - 独立开关名见 [PrepSwitches]；每个 [com.xiaozhanggui.app.ui.motion.MotionSpec]
 *   的 `enabled` 字段是该动效的回退开关（false → V3.7.1 瞬切行为），
 *   Phase 3 接线时绑定到设置/远程配置，准备阶段一律保持 true；
 * - 数值独立标定：相位分数/过冲幅度/错峰步长均为本包独立推导，
 *   **未复制 SleepDown 的 260ms/2.2%/3.5%/6组×18ms 等数值**；
 * - 降级原因一律具名（见各 prep 对象的 `DowngradeReasons` 与
 *   [com.xiaozhanggui.app.ui.motion.MotionDowngradeReasons]），可写日志、可单测断言；
 * - 真机帧率/录屏验收全部 NOT RUN（见 `docs/ANDROID_V38_PHASE3_PREP.md`）。
 */
object PrepGate {
    /** 准备包的隔离声明：true = 本包仅含声明与纯函数，无生产接线。 */
    const val DECLARATION_ONLY: Boolean = true
}
