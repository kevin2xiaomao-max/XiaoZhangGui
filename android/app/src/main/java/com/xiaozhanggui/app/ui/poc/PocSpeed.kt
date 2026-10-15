package com.xiaozhanggui.app.ui.poc

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/**
 * PoC 全局速度控制器（V3.8 PoC 测试菜单增强；debug only）。
 *
 * - [PocSpeedMode.NORMAL]（1x）：真实时长；
 * - [PocSpeedMode.SLOW]（4x）：慢放，便于逐帧核验相位顺序与慢放录屏
 *   （与各屏既有调试慢放 `* 4` 口径归一到此）。
 *
 * 修改入口（debug 构建）：
 * - PoC launcher 菜单的速度分段控件（正常 / 慢放×4）；
 * - PoC 演示屏内的慢放开关（与全局联动）；
 * - 深链 `xzg://poc/<屏>?speed=slow|normal`。
 *
 * release 构建：PoC route 不注册、PoC 深链在路由层即映射为 Ignore，
 * 此对象无任何生产路径可达（[PocGate.enabled] 保护）。
 *
 * 状态为 Compose 可观察：切换后，正在展示的 PoC 屏**下次开启动画**
 * 即按新档缩放（进行中的动画不中断、不重播）。
 */
enum class PocSpeedMode(val factor: Int) {
    /** 正常速度（1x） */
    NORMAL(1),

    /** 慢放（4x） */
    SLOW(4),
}

/** PoC 全局速度（单例；debug only，见类文档）。 */
object PocSpeed {
    /**
     * 慢放倍率（== [PocSpeedMode.SLOW] 的 factor）。
     * 各屏既有 `* 4` 慢放口径归一到此常量，改一处即全局生效。
     */
    const val SLOW_FACTOR = 4

    var mode: PocSpeedMode by mutableStateOf(PocSpeedMode.NORMAL)
        private set

    /**
     * 动画时长缩放：`durationMs * 当前档 factor`。
     *
     * 边界：`durationMs <= 0` 原样返回（非法/零时长不放大，避免把"无动画"变成动画）。
     */
    fun scale(durationMs: Int): Int =
        if (durationMs <= 0) durationMs else durationMs * mode.factor

    /**
     * 深链 `?speed=` 参数映射：
     * - `"slow"` → [PocSpeedMode.SLOW]；
     * - `"normal"` → [PocSpeedMode.NORMAL]；
     * - 缺省 / 非法值 → null（保持当前档，不重置；大小写敏感，锁定行为）。
     */
    fun modeForQuery(value: String?): PocSpeedMode? = when (value) {
        "slow" -> PocSpeedMode.SLOW
        "normal" -> PocSpeedMode.NORMAL
        else -> null
    }

    /** 切换速度档（launcher 分段控件 / 演示屏慢放开关 / 深链落盘共用）。 */
    fun setMode(newMode: PocSpeedMode) {
        mode = newMode
    }
}
