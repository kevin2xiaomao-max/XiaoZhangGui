package com.xiaozhanggui.app.data.notification

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.domain.DateExt

/**
 * 通知调度契约。对应 iOS NotificationManager（Services/NotificationManager.swift）。
 *
 * 三类规则（B_data.md §8.1）：
 * 1. 待办：todoReminderEnabled && dueDate != null && dueDate > now && !isCompleted，
 *    在截止时间的年月日时分触发（非重复）。ID = "todo-<notificationID>"。
 * 2. 临期：expiryReminderEnabled && status==pending，
 *    触发 = (expiryDate - remindDaysBefore) 当天 9:00，且必须 > now。
 *    ID = "expiry-<notificationID>"。
 * 3. 客户跟进：仅 pending；新增/编辑后 3600 秒触发；ID = "customer-<notificationID>-followup"；
 *    离开 pending 立即取消全部后缀（-followup/-delivery/-custom）。
 *
 * GATE B（OPPO/ColorOS/无 GMS）：
 * - POST_NOTIFICATIONS 运行时权限由调用方（UI 层）在触发前申请；此处发送前检查 enabled。
 * - 精确闹钟：API 31+ 检查 canScheduleExactAlarms()；无权限时降级为非精确闹钟，
 *   并通过 [ExactAlarmStatus] 暴露状态，UI 必须明确显示（不得假装成功）。
 * - 精确闹钟权限口径（Phase 3 Worker B 合规审计结论）：
 *   `USE_EXACT_ALARM` 仅限闹钟/日历类核心功能应用，本 App 为店铺记账工具，
 *   精确闹钟只是提醒增强，不合规 → 已从 Manifest 移除；
 *   只保留 `SCHEDULE_EXACT_ALARM`（用户可授权/可撤销的特殊权限），
 *   降级链 canScheduleExactAlarms()=false → 非精确闹钟 完整可用。
 * - 无 GMS 不依赖任何 Google 服务；纯 AlarmManager + BroadcastReceiver。
 */
interface NotificationScheduler {
    fun scheduleTodo(todo: TodoEntity)
    fun cancelTodo(todo: TodoEntity)
    fun scheduleExpiry(item: ExpiryItemEntity)
    fun cancelExpiry(item: ExpiryItemEntity)

    /** 客户新增/编辑后调用：pending 则 1 小时后触发，否则取消 */
    fun rescheduleCustomer(request: CustomerRequestEntity)
    fun cancelCustomer(request: CustomerRequestEntity)

    /** 精确闹钟是否可用（UI 用于显示状态） */
    fun canScheduleExactAlarms(): Boolean
}

/** 精确闹钟状态（UI 显示用） */
enum class ExactAlarmStatus { AVAILABLE, UNAVAILABLE_FALLBACK_INEXACT, UNKNOWN }

class AlarmNotificationScheduler(
    private val context: Context,
    private val settings: NotificationSettings
) : NotificationScheduler {

    /** 通知总开关（对应 iOS todo_reminder / expiry_reminder） */
    interface NotificationSettings {
        fun todoReminderEnabled(): Boolean
        fun expiryReminderEnabled(): Boolean
    }

    init {
        // 三类通知渠道（待办/临期/跟进）创建 + 遗留单渠道清理，幂等
        NotificationChannels.ensureChannels(context)
    }

    override fun canScheduleExactAlarms(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return am.canScheduleExactAlarms()
    }

    private fun alarmManager(): AlarmManager =
        context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

    private fun pendingIntent(tag: String, title: String, body: String): PendingIntent {
        val intent = Intent(context, XzgAlarmReceiver::class.java).apply {
            action = "com.xiaozhanggui.app.ALARM"
            putExtra("tag", tag)
            putExtra("title", title)
            putExtra("body", body)
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        return PendingIntent.getBroadcast(context, tag.hashCode(), intent, flags)
    }

    private fun schedule(tag: String, triggerAtMillis: Long, title: String, body: String) {
        if (triggerAtMillis <= System.currentTimeMillis()) return
        val am = alarmManager()
        val pi = pendingIntent(tag, title, body)
        if (canScheduleExactAlarms()) {
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            } catch (e: SecurityException) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
            }
        } else {
            // GATE B：无精确闹钟权限 → 降级非精确，UI 层通过 canScheduleExactAlarms() 显示状态
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAtMillis, pi)
        }
    }

    private fun cancel(tag: String, title: String = "", body: String = "") {
        alarmManager().cancel(pendingIntent(tag, title, body))
    }

    override fun scheduleTodo(todo: TodoEntity) {
        val due = todo.dueDate ?: return
        if (!settings.todoReminderEnabled()) return
        if (todo.isCompleted) return
        if (due <= System.currentTimeMillis()) return
        // 在截止时间的年月日时分触发（非重复）
        schedule("todo-${todo.notificationId}", due, "待办提醒", todo.title)
    }

    override fun cancelTodo(todo: TodoEntity) {
        cancel("todo-${todo.notificationId}")
    }

    override fun scheduleExpiry(item: ExpiryItemEntity) {
        if (!settings.expiryReminderEnabled()) return
        if (item.returnStatus != ReturnStatus.PENDING) return
        // (expiryDate - remindDaysBefore) 当天 9:00，且必须 > now
        val remindDay = item.expiryDate - item.remindDaysBefore * 24 * 3600 * 1000L
        val trigger = DateExt.atTime(remindDay, 9, 0)
        if (trigger <= System.currentTimeMillis()) return
        val daysLeft = DateExt.daysBetween(
            DateExt.startOfDay(System.currentTimeMillis()),
            DateExt.startOfDay(item.expiryDate)
        )
        val body = if (daysLeft < 0) {
            "「${item.name}」已到期（${item.quantity} 件）"
        } else {
            "「${item.name}」还有 $daysLeft 天到期（${item.quantity} 件）"
        }
        schedule("expiry-${item.notificationId}", trigger, "临期退货提醒", body)
    }

    override fun cancelExpiry(item: ExpiryItemEntity) {
        cancel("expiry-${item.notificationId}")
    }

    override fun rescheduleCustomer(request: CustomerRequestEntity) {
        cancelCustomer(request)
        if (request.status != CustomerStatus.PENDING) return
        // 新增/编辑后 3600 秒触发
        val trigger = System.currentTimeMillis() + 3600 * 1000L
        val body = "${request.content} · ${request.roomOrAddress}".trim(' ', '·')
        schedule("customer-${request.notificationId}-followup", trigger, "配送需求待跟进", body)
    }

    override fun cancelCustomer(request: CustomerRequestEntity) {
        // 取消全部后缀（-followup/-delivery/-custom），对应 iOS 注释
        for (suffix in listOf("-followup", "-delivery", "-custom")) {
            cancel("customer-${request.notificationId}$suffix")
        }
    }
}

/** 闹钟触发后的通知展示 */
class XzgAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.xiaozhanggui.app.ALARM") return
        val title = intent.getStringExtra("title") ?: return
        val body = intent.getStringExtra("body") ?: ""
        val tag = intent.getStringExtra("tag") ?: return

        val nm = NotificationManagerCompat.from(context)
        if (ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.POST_NOTIFICATIONS
            ) != android.content.pm.PackageManager.PERMISSION_GRANTED &&
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU
        ) {
            return // 无通知权限则静默丢弃（GATE B：不得 crash）
        }

        val channelId = NotificationChannels.channelIdForTag(tag)
        // 兜底：接收器可能在渠道创建前被系统唤起，幂等补建
        NotificationChannels.ensureChannels(context)

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .build()
        nm.notify(tag.hashCode(), notification)
    }
}
