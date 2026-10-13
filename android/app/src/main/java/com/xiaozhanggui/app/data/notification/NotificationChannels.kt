package com.xiaozhanggui.app.data.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

/**
 * 通知渠道（Android 8+）。对应 iOS 的通知分类语义（iOS 无 Channel 概念，按通知类型区分）。
 *
 * 三类提醒各用独立渠道（Phase 3 Worker B 合规补齐）：
 * - 待办提醒 / 临期退货提醒 / 客户跟进提醒
 * 重要性均为 IMPORTANCE_DEFAULT（有声音+横幅，不打断），描述为中文。
 *
 * 历史遗留的单渠道 "xzg_reminders" 在 [ensureChannels] 中删除（仅删渠道，
 * 不影响任何业务数据；用户已手动改过的渠道设置随系统渠道删除而重置为默认）。
 */
object NotificationChannels {
    const val TODO = "xzg_todo"
    const val EXPIRY = "xzg_expiry"
    const val CUSTOMER = "xzg_customer"

    /** Phase 2 遗留单渠道，已被三类渠道取代 */
    private const val LEGACY = "xzg_reminders"

    private data class Spec(val id: String, val name: String, val description: String)

    private val SPECS = listOf(
        Spec(TODO, "待办提醒", "待办事项到期提醒"),
        Spec(EXPIRY, "临期退货提醒", "商品临期与退货提醒"),
        Spec(CUSTOMER, "客户跟进提醒", "客户配送需求跟进提醒"),
    )

    /** 按闹钟 tag 前缀映射到渠道：tag 形如 "todo-<id>" / "expiry-<id>" / "customer-<id>-followup"。 */
    fun channelIdForTag(tag: String): String = when {
        tag.startsWith("todo-") -> TODO
        tag.startsWith("expiry-") -> EXPIRY
        tag.startsWith("customer-") -> CUSTOMER
        else -> TODO
    }

    /** 幂等创建三类渠道；删除 Phase 2 遗留的单渠道。API 26 以下直接返回。 */
    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        for (spec in SPECS) {
            if (mgr.getNotificationChannel(spec.id) == null) {
                val channel = NotificationChannel(
                    spec.id, spec.name, NotificationManager.IMPORTANCE_DEFAULT
                ).apply { description = spec.description }
                mgr.createNotificationChannel(channel)
            }
        }
        // 清理遗留单渠道（若存在）
        if (mgr.getNotificationChannel(LEGACY) != null) {
            mgr.deleteNotificationChannel(LEGACY)
        }
    }
}
