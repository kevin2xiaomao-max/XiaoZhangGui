package com.xiaozhanggui.app.data.voice

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat

/**
 * RECORD_AUDIO 申请结果的三条路径（对应验收文档 §2 验收项 4 / §6 权限矩阵）。
 *
 * - [GRANTED]：已授权，直接开始识别；
 * - [DENIED_TRANSIENT]：本次拒绝（系统仍会再次弹窗）：降级文字输入，
 *   用户下次点麦克风可重新申请；
 * - [DENIED_PERMANENT]：永久拒绝（不再询问）：降级文字输入 +
 *   明确引导去系统设置开启（文案清晰，不静默）。
 */
enum class VoicePermissionOutcome {
    GRANTED,
    DENIED_TRANSIENT,
    DENIED_PERMANENT,
}

object VoicePermissionFlow {

    /**
     * 纯决策核心（JVM 可测）。
     *
     * @param granted 本次申请是否被授予
     * @param shouldShowRationale 系统是否还会再次弹窗
     * （`ActivityCompat.shouldShowRequestPermissionRationale` 的返回值）。
     * 规则：拒绝且系统不再弹窗 → 视为永久拒绝，走系统设置引导。
     */
    fun decide(granted: Boolean, shouldShowRationale: Boolean): VoicePermissionOutcome =
        when {
            granted -> VoicePermissionOutcome.GRANTED
            shouldShowRationale -> VoicePermissionOutcome.DENIED_TRANSIENT
            else -> VoicePermissionOutcome.DENIED_PERMANENT
        }

    /**
     * 在权限申请回调中使用：结合当前 Activity 的 rationale 状态判定三路径。
     * Activity 为 null（极端情况）时按永久拒绝处理，保证用户总能看到
     * 去系统设置的引导而不是静默失败。
     */
    fun decideFromActivity(activity: Activity?, granted: Boolean): VoicePermissionOutcome {
        val rationale = activity?.let {
            ActivityCompat.shouldShowRequestPermissionRationale(
                it,
                Manifest.permission.RECORD_AUDIO,
            )
        } ?: false
        return decide(granted, rationale)
    }
}

/**
 * 打开本应用的系统设置页（永久拒绝后的引导入口）。
 * 失败静默（runCatching），不打断调用方。
 */
fun Context.openAppSettings() {
    val intent = Intent(
        Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
        Uri.fromParts("package", packageName, null),
    ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    runCatching { startActivity(intent) }
}
