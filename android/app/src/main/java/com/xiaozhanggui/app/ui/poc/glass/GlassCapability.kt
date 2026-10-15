package com.xiaozhanggui.app.ui.poc.glass

import com.xiaozhanggui.app.ui.motion.CapabilityResult
import com.xiaozhanggui.app.ui.motion.probeGlassCapability

/**
 * T1 档能力探测（纯函数，可 JVM 单测）。
 *
 * 复用 Phase 1 [probeGlassCapability] 的 API/硬件加速判定（具名失败原因
 * 原样透传，不分叉）；PoC-2 追加**低内存**分支——低内存设备上预构建模糊
 * 快照的常驻位图成本不可接受，直接降 T2。
 *
 * @param apiLevel `Build.VERSION.SDK_INT`
 * @param hardwareAccelerated 是否硬件加速
 * @param lowMemory 是否低内存设备（`ActivityManager.isLowRamDevice`）
 * @return [CapabilityResult.Ok]（T1 可用）或具名 [CapabilityResult.Unsupported]
 */
fun probeGlassTierCapability(
    apiLevel: Int,
    hardwareAccelerated: Boolean = true,
    lowMemory: Boolean = false,
): CapabilityResult {
    val base = probeGlassCapability(apiLevel, hardwareAccelerated)
    if (base is CapabilityResult.Unsupported) return base
    if (lowMemory) return CapabilityResult.Unsupported("glass-low-memory-device")
    return CapabilityResult.Ok
}
