package com.xiaozhanggui.app.ui.motion

/**
 * 设备性能档（Design System §2.3 降级链第 2 级）。
 *
 * - [FULL]：旗舰/中端机，全开（SHARED_ANCHOR、T1/T2 材质、运动模糊）
 * - [REDUCED]：中低端机，禁用运动模糊、材质退一档（T1→T2），转场保持
 * - [ESSENTIAL]：低端机/省电模式：禁用 SHARED_ANCHOR（→FADE）、禁用 T1/T2 材质（→T3）、
 *   禁用运动模糊；具名原因 `perf-tier-essential`
 *
 * 档位判定逻辑（内存/SoC/省电模式）由 Phase 3 接线；Motion 层只消费档位，
 * 不决定档位。
 */
enum class PerfTier {
    FULL,
    REDUCED,
    ESSENTIAL,
}

/**
 * [MotionPolicy.resolve] 的运行时上下文（值语义，可单测）。
 *
 * @param reduceMotion 系统「移除动画」开关（`Settings.Global.ANIMATOR_DURATION_SCALE == 0`，
 *   见 `ui.theme.isReduceMotionEnabled`）；true → 全部退化为 FAST 短淡入，
 *   无位移/无弹簧/无过冲/无模糊
 * @param perfTier 设备性能档；[PerfTier.ESSENTIAL] → 禁 SHARED_ANCHOR→FADE
 * @param denseList 密集列表（可见卡片 > 10，由调用方在布局后计算传入）；
 *   true → 内容错峰退化为整面单调
 * @param capabilities 设备能力快照；转场能力失败 → 走 [MotionSpec.fallbackKind]
 * @param runtimeMaxTransitionKind [FrameRateMonitor] 的运行时档位上限
 *   （帧率持续不足时单向降档，回到前台重新探测后恢复）；默认不设限
 */
data class MotionContext(
    val reduceMotion: Boolean = false,
    val perfTier: PerfTier = PerfTier.FULL,
    val denseList: Boolean = false,
    val capabilities: CapabilitySnapshot = CapabilitySnapshot(),
    val runtimeMaxTransitionKind: TransitionKind = TransitionKind.SHARED_ANCHOR,
)
