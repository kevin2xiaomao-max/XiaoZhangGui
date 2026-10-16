package com.xiaozhanggui.app.ui.poc

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * PoC autodrive 自动交互驱动（V3.8 真机验收补强；debug only）。
 *
 * 背景：`tools/poc-acceptance.sh --perf` 曾只采样静态页面，帧率不能作为
 * 动画达标证据。autodrive 让 PoC 屏在深链进入后自动循环执行关键动画，
 * 无需触摸，`--perf` 的 framestats 采样窗口即为动画期间实测。
 *
 * 门控（与 [PocSpeed] 同一模式）：
 * - 置位唯一入口：`XzgNavGraph.handleOpenPoc` 解析深链 `?autodrive=`；
 *   release 构建（POC_ENABLED=false）`handleOpenPoc` 直接返回，永不置位；
 * - 各屏的 autodrive 循环均为 `LaunchedEffect(PocAutodrive.enabled)`，
 *   离屏即取消；手动模式（enabled=false）行为零变化；
 * - `ui/poc` 与生产页物理隔离不变（生产代码无任何引用）。
 *
 * 深链：`xzg://poc/droplet?autodrive=true`（glass / morph 同理；
 * transition 为静态探测页，按设计跳过）；
 * 可与 `?speed=slow|normal` 联用：`?autodrive=true&speed=slow`。
 */
object PocAutodrive {
    /** 预热延迟：等待锚点 onGloballyPositioned 测量完成再开启动画。 */
    const val WARMUP_MS = 600

    /** droplet：展开后停留（≥ 一次展开动画时长 + 目视停留）。 */
    const val DROPLET_EXPANDED_DWELL_MS = 1200

    /** droplet：收起后停留。 */
    const val DROPLET_COLLAPSED_DWELL_MS = 800

    /** glass：单个档位聚焦停留（alpha 显隐动画持续期间有帧产出）。 */
    const val GLASS_FOCUS_MS = 1500

    /** morph：拖拽扫动一轮后停留。 */
    const val MORPH_DRAG_PAUSE_MS = 600

    /** morph：展开/收起后停留（不含动画本身与 200ms 释放）。 */
    const val MORPH_EXPAND_DWELL_MS = 900

    /**
     * autodrive 是否开启（Compose 可观察）。
     * 只读对外暴露；置位经 [setEnabled]（深链导航层调用）。
     *
     * 注：内部状态命名为 `enabledState`——若直接用 `var enabled … private set`
     * 再加 `fun setEnabled`，Kotlin 会报 platform declaration clash
     *（两者 JVM 签名同为 `setEnabled(Z)V`）；此写法对外 API 不变。
     */
    val enabled: Boolean
        get() = enabledState

    /** Compose 可观察的内部开关状态。 */
    private var enabledState: Boolean by mutableStateOf(false)

    fun setEnabled(value: Boolean) {
        enabledState = value
    }

    /**
     * 深链 `?autodrive=` 原始值映射（纯函数，JVM 可测）：
     * - `"true"` / `"1"` / `"yes"` → 开启；
     * - `"false"` / `"0"` / `"no"` → 关闭；
     * - 缺省 / 非法值 → null（保持当前状态，不重置；大小写敏感，
     *   与 [PocSpeed.modeForQuery] 口径一致）。
     */
    fun enabledForQuery(value: String?): Boolean? = when (value) {
        "true", "1", "yes" -> true
        "false", "0", "no" -> false
        else -> null
    }
}
