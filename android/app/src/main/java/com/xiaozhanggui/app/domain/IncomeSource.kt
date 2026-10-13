package com.xiaozhanggui.app.domain

/**
 * 收入来源。对应 iOS `IncomeSource` 枚举
 *（`XiaoZhangGui/Features/Performance/PerformanceModel.swift`）。
 *
 * rawValue 用中文：门店 / 美团 / 其他。Room 实体与备份 JSON 均存 rawValue。
 */
enum class IncomeSource(val rawValue: String) {
    STORE("门店"),
    MEITUAN("美团"),
    OTHER("其他");

    companion object {
        /** 对应 iOS `IncomeSource.from(note:)`：note 含"美团"→美团；含"门店"/"到店"→门店；其余→其他 */
        fun fromNote(note: String): IncomeSource {
            val n = note.trim()
            return when {
                n.contains("美团") -> MEITUAN
                n.contains("门店") || n.contains("到店") -> STORE
                else -> OTHER
            }
        }

        /**
         * 对应 iOS `IncomeSource.from(performance:)`：
         * ① incomeSource 字段非空且合法 → 用字段值；
         * ② 为空时 paymentMethod == "美团"/"meituan" → 美团，"门店"/"store" → 门店；
         * ③ 否则 note 关键词派生。
         */
        fun fromPerformance(incomeSource: String, paymentMethod: String, note: String): IncomeSource {
            val stored = incomeSource.trim()
            entries.firstOrNull { it.rawValue == stored }?.let { return it }
            if (stored.isEmpty()) {
                val pay = paymentMethod.trim()
                if (pay == MEITUAN.rawValue || pay.equals("meituan", ignoreCase = true)) return MEITUAN
                if (pay == STORE.rawValue || pay.equals("store", ignoreCase = true)) return STORE
            }
            return fromNote(note)
        }

        /**
         * 宽容解析：合法 rawValue → 对应枚举；非法/空白 → [STORE]（门店）。
         * 对应 iOS 备份恢复 `IncomeSource(rawValue:)?.rawValue ?? IncomeSource.store.rawValue`。
         */
        fun fromRaw(raw: String?): IncomeSource {
            val stored = raw?.trim().orEmpty()
            return entries.firstOrNull { it.rawValue == stored } ?: STORE
        }
    }
}
