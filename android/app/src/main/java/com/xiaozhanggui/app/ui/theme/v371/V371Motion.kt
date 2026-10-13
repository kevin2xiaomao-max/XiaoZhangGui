package com.xiaozhanggui.app.ui.theme.v371

import com.xiaozhanggui.app.ui.theme.MotionSurface
import com.xiaozhanggui.app.ui.theme.ResolvedMotion
import com.xiaozhanggui.app.ui.theme.resolveMotion

/**
 * V371 Motion（对应 iOS `V371.Motion`）。
 *
 * V371Motion 是 V3.7.1 的语义动效 token 层；数值实现复用 V32 口径
 * （[com.xiaozhanggui.app.ui.theme.XzgMotion] 的克制取值：quick 0.18 / standard 0.28 /
 * slow 0.42 / reducedFade 0.12，不分叉、不另起数值体系）。
 *
 * Reduce Motion 全走 [resolve]（对应 iOS `V371.Motion.resolve` → `V32Motion.resolve`）：
 * 开启时 fade/spring 退化为短淡入、numeric 直接终值，调用方不得自写裸时长。
 */
object V371Motion {
    /** 即时反馈（0.10s）：tab 选中胶囊、press 高亮等最轻反馈 */
    const val INSTANT_MS = 100

    /** 快速（0.18s）：默认状态切换、淡入、行状态变化 */
    const val FAST_MS = 180

    /** 标准（0.28s）：数字滚动、较大过渡 */
    const val STANDARD_MS = 280

    /** 强调（0.42s）：极少用，仅 deliberate 的大区块展开 */
    const val EMPHASIZED_MS = 420

    /** Quick Action 按压缩放（克制，不夸张） */
    const val PRESS_SCALE = 0.97f

    /**
     * 按系统「减弱动态效果」开关解析应使用的动效。
     * reduceMotion=true：无位移、无弹簧、无明显 scale；fade/spring→短淡入，numeric→直接终值。
     */
    fun resolve(surface: MotionSurface, reduceMotion: Boolean): ResolvedMotion =
        resolveMotion(surface, reduceMotion)
}
