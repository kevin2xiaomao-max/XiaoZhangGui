package com.xiaozhanggui.app.ui.motion

/**
 * 转场类型（Design System §2.3）。
 *
 * 选择规则：
 * - Tab 切换 / 页面导航：[FADE]（页面容器单调 tween，内容分组错峰淡入）
 * - 浮层 / 弹窗：[FADE]（特殊批准的场景用 [SHARED_ANCHOR]）
 * - [NATIVE] 仅用于系统级交互（跟手返回手势等），不用于页面间转场——
 *   NATIVE 在不同 OEM 上表现不一致，ColorOS 的 Activity 转场与 Compose NavHost
 *   转场混用会产生撕裂；FADE 是可预测、可测试、可降级的最小公分母。
 */
enum class TransitionKind {
    /** 平台默认（仅系统级交互，如跟手返回；页面转场禁用） */
    NATIVE,

    /** 淡入淡出 + 轻微位移（页面转场/浮层的默认安全选择） */
    FADE,

    /** 液滴式锚点展开（仅 Design System §2.2 批准的场景，如 AI Sheet） */
    SHARED_ANCHOR,
}

/**
 * 时长档（沿用 V371Motion 的 100/180/280/420，不分叉、不新增数值）。
 *
 * 对应 [com.xiaozhanggui.app.ui.theme.v371.V371Motion] 的
 * INSTANT_MS / FAST_MS / STANDARD_MS / EMPHASIZED_MS。
 */
enum class DurationTier(val ms: Int) {
    /** 即时反馈（100ms）：tab 选中胶囊、press 高亮等最轻反馈 */
    INSTANT(100),

    /** 快速（180ms）：默认状态切换、淡入、行状态变化；Reduce Motion 下的短淡入也用此档 */
    FAST(180),

    /** 标准（280ms）：数字滚动、较大过渡 */
    STANDARD(280),

    /** 强调（420ms）：极少用，仅 deliberate 的大区块展开 */
    EMPHASIZED(420),
}

/**
 * 过冲策略。铁律：**页面容器永远 [NONE]**；只有内容分组允许 [CONTENT_ONLY]
 *（"内容可过冲、页面必单调"）。
 *
 * 任何降级路径都会把过冲强制压到 [NONE]（单向只降不升）。
 */
enum class Overshoot {
    /** 无过冲（页面容器、降级后唯一允许的值） */
    NONE,

    /** 仅内容分组允许的轻微过冲（末段一次、肉眼克制） */
    CONTENT_ONLY,
}

/**
 * 每个转场 / 动效的声明（Design System §2.3 MotionSpec）。
 *
 * 一个 MotionSpec = 一次动效的全部设计意图 + 预先声明的降级路径。
 * **无预先声明降级路径的动效不允许合入生产页面**——[fallbackKind] 没有默认值，
 * 构造时必须显式传入，这是编译期强制，不是文档约定。
 *
 * @param id 唯一标识，如 "button.press"、"ai.sheet.expand"、"home.tab.switch"
 * @param transitionKind 转场类型（[TransitionKind]；NATIVE 仅系统级交互）
 * @param durationTier 时长档（沿用 V371 档位，不分叉）
 * @param interruptible 中途反转是否保持速度续播（默认 true）
 * @param overshoot 过冲策略（页面容器必须 [Overshoot.NONE]）
 * @param fallbackKind 预先声明的降级路径（如 SHARED_ANCHOR → FADE）；能力探测失败时走此路径
 * @param enabled 独立回退开关（false → 该动效回到 V3.7.1 瞬切行为）
 * @param description 设计意图一句话（写进日志/评审表，不写业务正文）
 */
data class MotionSpec(
    val id: String,
    val transitionKind: TransitionKind,
    val durationTier: DurationTier,
    val interruptible: Boolean = true,
    val overshoot: Overshoot = Overshoot.NONE,
    val fallbackKind: TransitionKind,
    val enabled: Boolean = true,
    val description: String = "",
)
