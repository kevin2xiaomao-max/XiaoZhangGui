package com.xiaozhanggui.app.ui.notifications

/**
 * 提醒能力状态（纯逻辑，可 JVM 测试）。对应 iOS 通知授权/精确闹钟状态展示语义。
 *
 * UI 诚实性要求（Phase 3 Worker B）：
 * - 通知未授权 → 必须显示降级说明（"通知未授权，提醒仅在应用内显示"），不得假装会推送；
 * - 精确闹钟不可用 → 必须显示"非精确提醒"，不得误报"已设置精确提醒"。
 */
data class ReminderCapability(
    /** POST_NOTIFICATIONS 是否已授权（API 33 以下恒为 true） */
    val notificationsGranted: Boolean,
    /** [com.xiaozhanggui.app.data.notification.NotificationScheduler.canScheduleExactAlarms] */
    val exactAlarmAvailable: Boolean,
) {
    /**
     * 降级说明行。全部正常时返回空列表 → UI 不显示任何警告。
     * 顺序：通知授权问题优先（通知都没开，精确与否无意义）。
     */
    fun degradationLines(): List<String> = buildList {
        if (!notificationsGranted) add("通知未授权，提醒仅在应用内显示")
        if (!exactAlarmAvailable) add("非精确提醒：系统未授予精确闹钟权限，提醒可能延迟几分钟")
    }

    /** 提醒精度行：精确可用时才允许写"精确提醒"，否则必须写"非精确提醒"。 */
    fun exactnessLine(): String =
        if (exactAlarmAvailable) "精确提醒" else "非精确提醒（系统未授权精确闹钟）"
}
