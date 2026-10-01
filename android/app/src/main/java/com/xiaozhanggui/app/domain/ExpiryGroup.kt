package com.xiaozhanggui.app.domain

import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.ReturnStatus

/**
 * 临期分组。对应 iOS ExpiryGroup（Features/Expiry/ExpiryModel.swift）。
 * 按 daysLeft（到期日 0 点 - 参考日 0 点）：
 * expired(<0) / urgent3(0-3) / urgent7(4-7) / safe30(8-30) / later(>30) / returned(已退货独立组)
 */
enum class ExpiryGroup {
    EXPIRED, URGENT_3, URGENT_7, SAFE_30, LATER, RETURNED;

    companion object {
        fun of(item: ExpiryItemEntity, nowMillis: Long = System.currentTimeMillis()): ExpiryGroup {
            if (item.returnStatus == ReturnStatus.RETURNED) return RETURNED
            val daysLeft = DateExt.daysBetween(
                DateExt.startOfDay(nowMillis),
                DateExt.startOfDay(item.expiryDate)
            )
            return when {
                daysLeft < 0 -> EXPIRED
                daysLeft <= 3 -> URGENT_3
                daysLeft <= 7 -> URGENT_7
                daysLeft <= 30 -> SAFE_30
                else -> LATER
            }
        }
    }
}

/** 临期统计三格：urgentCount(0-3) / warningCount(4-7) / safeCount(8-30) */
data class ExpiryStats(
    val urgentCount: Int,
    val warningCount: Int,
    val safeCount: Int,
    /** 副标题：7 天内件数（0-7） */
    val within7Days: Int
) {
    companion object {
        fun compute(items: List<ExpiryItemEntity>, nowMillis: Long = System.currentTimeMillis()): ExpiryStats {
            var urgent = 0; var warning = 0; var safe = 0; var within7 = 0
            for (item in items) {
                if (ExpiryGroup.of(item, nowMillis) == ExpiryGroup.RETURNED) continue
                val daysLeft = DateExt.daysBetween(
                    DateExt.startOfDay(nowMillis),
                    DateExt.startOfDay(item.expiryDate)
                )
                when (daysLeft) {
                    in 0..3 -> { urgent++; within7++ }
                    in 4..7 -> { warning++; within7++ }
                    in 8..30 -> safe++
                }
            }
            return ExpiryStats(urgent, warning, safe, within7)
        }
    }
}
