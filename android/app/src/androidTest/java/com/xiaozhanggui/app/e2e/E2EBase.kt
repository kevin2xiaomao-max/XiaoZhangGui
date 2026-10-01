package com.xiaozhanggui.app.e2e

import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.UiDevice

/**
 * E2E 测试公共基建（Phase 6 Worker B）。
 *
 * - [disableAnimations]：关闭三类系统动画（window/transition/animator），减少
 *   Sheet/导航动画带来的 flaky；通过 UiDevice 以 shell 身份执行 settings 命令，
 *   模拟器上无需特殊权限。各测试类在自己的 `@BeforeClass` 里调用。
 * - 注意：这些测试跑在真机/模拟器的 debug 包上（connectedDebugAndroidTest），
 *   与 Worker A 的本地 UI 测试（test/ + Paparazzi）互不重叠；
 *   CI 用 `-Pandroid.testInstrumentationRunnerArguments.package=com.xiaozhanggui.app.e2e`
 *   只跑本包，避免重复执行。
 */
object E2EBase {

    fun device(): UiDevice =
        UiDevice.getInstance(InstrumentationRegistry.getInstrumentation())

    fun disableAnimations() {
        val d = device()
        d.executeShellCommand("settings put global window_animation_scale 0")
        d.executeShellCommand("settings put global transition_animation_scale 0")
        d.executeShellCommand("settings put global animator_duration_scale 0")
    }
}
