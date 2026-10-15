package com.xiaozhanggui.app.ui.motion

/**
 * 能力探测结果（Design System §2.3 / §5.1 具名失败思想）。
 *
 * 探测函数**不返回 Boolean**：成功返回 [Ok]，失败返回
 * [Unsupported] 并携带可写日志、可进 PoC 报告的具名词
 * （如 `"no-backdrop-blur-on-api-29"`）。禁止裸 `false`。
 */
sealed interface CapabilityResult {
    /** 能力可用 */
    data object Ok : CapabilityResult

    /**
     * 能力不可用。
     *
     * @param reason 具名失败原因，如 `"no-backdrop-blur-on-api-29"`、
     *   `"predictive-back-unsupported-below-api-33"`。直接写日志，
     *   不拼接业务正文。
     */
    data class Unsupported(val reason: String) : CapabilityResult
}

/**
 * 设备能力快照（一次探测，多处复用）。
 *
 * @param glass 玻璃材质能力（RenderEffect 实时模糊等；Phase 2 PoC-2 消费）
 * @param transition 转场能力（跟手返回、硬件加速等；[MotionPolicy.resolve] 消费）
 */
data class CapabilitySnapshot(
    val glass: CapabilityResult = CapabilityResult.Ok,
    val transition: CapabilityResult = CapabilityResult.Ok,
)

/**
 * 玻璃材质能力探测（纯函数，可 JVM 单测）。
 *
 * T1 档（实时背景模糊）依赖 `android.graphics.RenderEffect`，API 31+ 才可用；
 * 非硬件加速管线下实时模糊不可用。
 *
 * @param apiLevel `Build.VERSION.SDK_INT`
 * @param hardwareAccelerated 是否硬件加速（`View.isHardwareAccelerated` / Window 标志）
 * @return [CapabilityResult.Ok] 或具名 [CapabilityResult.Unsupported]
 */
fun probeGlassCapability(
    apiLevel: Int,
    hardwareAccelerated: Boolean = true,
): CapabilityResult = when {
    !hardwareAccelerated ->
        CapabilityResult.Unsupported("glass-requires-hardware-acceleration")
    apiLevel < 31 ->
        CapabilityResult.Unsupported("no-backdrop-blur-on-api-$apiLevel")
    else -> CapabilityResult.Ok
}

/**
 * 转场能力探测（纯函数，可 JVM 单测）。
 *
 * FADE / SHARED_ANCHOR 是 App 侧独立实现，始终可用；
 * NATIVE 仅在系统级交互（跟手返回）时有意义：预测性返回手势需要 API 33+，
 * 非硬件加速管线下跟手转场不可用。
 *
 * @param apiLevel `Build.VERSION.SDK_INT`
 * @param hardwareAccelerated 是否硬件加速
 * @param predictiveBackRequested 本次转场是否需要预测性跟手返回（NATIVE 场景）
 * @return [CapabilityResult.Ok] 或具名 [CapabilityResult.Unsupported]
 */
fun probeTransitionCapability(
    apiLevel: Int,
    hardwareAccelerated: Boolean = true,
    predictiveBackRequested: Boolean = false,
): CapabilityResult = when {
    !hardwareAccelerated ->
        CapabilityResult.Unsupported("transition-requires-hardware-acceleration")
    predictiveBackRequested && apiLevel < 33 ->
        CapabilityResult.Unsupported("predictive-back-unsupported-below-api-$apiLevel")
    else -> CapabilityResult.Ok
}
