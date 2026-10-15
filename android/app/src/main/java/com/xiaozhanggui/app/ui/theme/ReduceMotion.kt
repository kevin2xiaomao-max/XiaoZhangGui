package com.xiaozhanggui.app.ui.theme

import android.content.Context
import android.database.ContentObserver
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.SheetState
import androidx.compose.material3.SheetValue
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity

/**
 * 系统「减弱动态效果 / 移除动画」开关接线（Phase 3 Worker C）。
 *
 * API 核查结论（compileSdk 35 实测 `android.jar`）：
 * - `AccessibilityManager` 在 SDK 35 **没有** `isReduceMotionEnabled`/`isReducedMotion`
 *   之类的公开 API（任务书提到的 `LocalAccessibilityManager`/`isReduceMotionEnabled`
 *   在当前 SDK 不存在，按「等价 API」接线）；
 * - Android 无障碍设置里的「移除动画」开关，本质就是把
 *   [Settings.Global.ANIMATOR_DURATION_SCALE]（及另外两个动画缩放）置 0，
 *   这是全平台通用的 de-facto 信号源（含 ColorOS 17）。
 *
 * 语义：开启后转场 / Sheet / 浮层退化为直接显示或短淡入（走
 * [V371Motion.resolve]/[resolveMotion] 的 reduceMotion=true 分支）；
 * 导航可达性、点击区域、返回行为、弹窗保存/取消语义与动效开启时完全一致。
 */

import com.xiaozhanggui.app.ui.motion.isReduceMotionEnabled as isReduceMotionEnabledPure

/** 纯函数：读取系统动画时长缩放是否为 0（0 = 用户开启了「移除动画」）。读取无需权限。 */
fun isReduceMotionEnabled(context: Context): Boolean = runCatching {
    // 取值在这里，判定逻辑收敛到 ui.motion 的纯函数（JVM 可单测），不分叉。
    isReduceMotionEnabledPure(
        Settings.Global.getFloat(
            context.contentResolver,
            Settings.Global.ANIMATOR_DURATION_SCALE,
            1f
        )
    )
}.getOrDefault(false)

/**
 * 响应式的系统 Reduce Motion 状态。
 *
 * @param reduceMotionOverride 测试钩子：非空时直接返回该值（不读系统设置），
 *   供 instrumented 测试验证「开关 → 动效分支」的接线路径。
 */
@Composable
fun rememberReduceMotion(reduceMotionOverride: Boolean? = null): Boolean =
    reduceMotionOverride ?: rememberSystemReduceMotion()

@Composable
private fun rememberSystemReduceMotion(): Boolean {
    val context = LocalContext.current
    var reduceMotion by remember { mutableStateOf(isReduceMotionEnabled(context)) }
    DisposableEffect(context) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                reduceMotion = isReduceMotionEnabled(context)
            }
        }
        val uri = Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE)
        context.contentResolver.registerContentObserver(uri, false, observer)
        // 注册后重读一次，避免注册间隙的竞态
        reduceMotion = isReduceMotionEnabled(context)
        onDispose { context.contentResolver.unregisterContentObserver(observer) }
    }
    return reduceMotion
}

/**
 * Reduce Motion 感知的 ModalBottomSheetState。
 *
 * Material3 的 Sheet 滑入/滑出动画由框架内部的 animationSpec 驱动，
 * `rememberModalBottomSheetState` 没有公开的动画开关；这里直接用
 * [SheetState] 的公开构造器：开启 Reduce Motion 时初始值设为
 * [SheetValue.Expanded]，Sheet 直接呈现（跳过滑入动画），关闭/返回/
 * 下滑手势语义不变。`rememberSaveable` 的 key 含 reduceMotion，
 * 开关变化后新打开的 Sheet 即按新值呈现。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun rememberXzgModalBottomSheetState(
    skipPartiallyExpanded: Boolean = true,
    reduceMotionOverride: Boolean? = null,
): SheetState {
    val density = LocalDensity.current
    val reduceMotion = rememberReduceMotion(reduceMotionOverride)
    val initialValue = if (reduceMotion) SheetValue.Expanded else SheetValue.Hidden
    return rememberSaveable(
        skipPartiallyExpanded, initialValue,
        saver = SheetState.Saver(
            skipPartiallyExpanded = skipPartiallyExpanded,
            confirmValueChange = { true },
            density = density,
            skipHiddenState = false,
        )
    ) {
        SheetState(
            skipPartiallyExpanded = skipPartiallyExpanded,
            density = density,
            initialValue = initialValue,
        )
    }
}
