package com.xiaozhanggui.app.ui.poc.transition

import android.app.Activity
import android.content.Context
import android.os.Build
import com.xiaozhanggui.app.ui.motion.OPLUS_CLASS_CANDIDATES_UNVERIFIED
import com.xiaozhanggui.app.ui.motion.OplusProbeEnv
import com.xiaozhanggui.app.ui.motion.OplusProbeItem
import com.xiaozhanggui.app.ui.motion.OplusWindowMode
import com.xiaozhanggui.app.ui.motion.probeOplusTransitions

/**
 * PoC-4 Android 侧只读采集器（`ui.poc.transition`，PoC 隔离区内）。
 *
 * **只做只读采集，不反射调用任何私有 API**（无用户授权）：
 * - `Class.forName`：仅存在性检查，不获取方法、不调用；
 * - `Build.*` 字段（含 `Build.VERSION.INCREMENTAL`，部分 ColorOS 机型的
 *   `Build.DISPLAY` 无版本标记时作为第二解析来源）、
 *   `Activity.isInMultiWindowMode` / `isInPictureInPictureMode`：均为公开 API；
 * - 不读 `ro.build.version.oplusrom` 等系统属性（需反射 `SystemProperties`，无授权）。
 * - 预测性返回的系统级开关无公开 API 可读 → 采集为 null，
 *   探测项具名为 `predictive-back-system-state-unknown`（不猜测）。
 *
 * 决策逻辑在 `ui.motion.probeOplusTransitions`（纯函数，JVM 可测）。
 */
object OplusProbeCollector {

    /**
     * 采集当前设备的探测环境并运行 [probeOplusTransitions]。
     *
     * @param context 用于判断窗口模式的 Activity 上下文（非 Activity 时按 NORMAL 处理）
     */
    fun collect(context: Context): List<OplusProbeItem> {
        val activity = context as? Activity
        val env = OplusProbeEnv(
            apiLevel = Build.VERSION.SDK_INT,
            manufacturer = Build.MANUFACTURER ?: "",
            buildDisplay = Build.DISPLAY,
            versionIncremental = Build.VERSION.INCREMENTAL,
            classPresent = OPLUS_CLASS_CANDIDATES_UNVERIFIED.associateWith(::classExists),
            // 系统级预测性返回开关：无公开 API 可读，诚实标 unknown。
            predictiveBackSystemEnabled = null,
            windowMode = detectWindowMode(activity),
            hardwareAccelerated = true,
        )
        return probeOplusTransitions(env)
    }

    /**
     * 类存在性检查（`Class.forName` 的安全封装）。
     * 只判断类是否存在；不获取、不调用任何方法或字段。
     */
    private fun classExists(className: String): Boolean = try {
        Class.forName(className)
        true
    } catch (_: ClassNotFoundException) {
        false
    } catch (_: LinkageError) {
        false
    }

    private fun detectWindowMode(activity: Activity?): OplusWindowMode {
        if (activity == null) return OplusWindowMode.NORMAL
        return when {
            activity.isInPictureInPictureMode -> OplusWindowMode.PIP
            activity.isInMultiWindowMode -> OplusWindowMode.FREEFORM
            else -> OplusWindowMode.NORMAL
        }
    }
}
