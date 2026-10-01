package com.xiaozhanggui.app.domain

import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import java.time.Instant
import java.time.ZoneId

/**
 * 展示逻辑。对应 iOS Utilities/DisplayLogic.swift。
 */
object DisplayLogic {

    /** 是否为编码串（UI 必须隐藏）：xzg- 前缀 / 含 xzg-delivery-v1: / ≥32 位纯 base64 字符 */
    fun isEncoded(v: String): Boolean {
        val t = v.trim()
        if (t.isEmpty()) return false
        if (t.startsWith("xzg-")) return true
        if (t.contains(CustomerDeliveryStorage.PREFIX)) return true
        if (t.length >= 32 && t.all { it in 'A'..'Z' || it in 'a'..'z' || it in '0'..'9' || it == '+' || it == '/' || it == '=' }) {
            return true
        }
        return false
    }

    /** trim 后空或编码串 → fallback */
    fun visible(v: String, fallback: String): String {
        val t = v.trim()
        return if (t.isEmpty() || isEncoded(t)) fallback else t
    }

    /** 问候语：<11 早上好，<14 中午好，<18 下午好，否则晚上好 */
    fun greetingPhrase(nowMillis: Long = System.currentTimeMillis(), owner: String): String {
        val hour = java.time.ZonedDateTime
            .ofInstant(Instant.ofEpochMilli(nowMillis), ZoneId.systemDefault()).hour
        val word = when {
            hour < 11 -> "早上好"
            hour < 14 -> "中午好"
            hour < 18 -> "下午好"
            else -> "晚上好"
        }
        return "$word，$owner"
    }

    /**
     * 时间标签（对应 iOS DayTimeLabel.label）：
     * nil → unscheduledText；有钟点 → 当天 "HH:mm" / 非当天 "M月d日 HH:mm"；
     * 无钟点（当天 00:00）→ 当天"全天" / 非当天 "M月d日"。
     */
    fun dayTimeLabel(millis: Long?, unscheduledText: String): String {
        if (millis == null) return unscheduledText
        return if (DateExt.hasClock(millis)) {
            if (DateExt.isToday(millis)) Format.time(millis) else Format.monthDayTime(millis)
        } else {
            if (DateExt.isToday(millis)) "全天" else Format.monthDay(millis)
        }
    }

    /**
     * 记录来源标签（对应 iOS RecordSourceLabel.display）。
     * banned 分类：""、其他、other、收入、营业额、支出。
     */
    fun recordSourceLabel(p: PerformanceEntity): String {
        val src = p.incomeSource
        if (src == "门店" || src == "美团") return src
        val haystack = listOf(p.importSource, p.paymentMethod, p.note)
        if (haystack.any { it.contains("扫呗") || it.contains("saobei", ignoreCase = true) }) return "扫呗"
        // Performance 无 category 字段（恒为 banned 的 ""），跳过 category 分支
        if (p.note == "手动" || p.note == "门店" || p.note == "美团") return p.note
        return "手动"
    }

    /** 支出记录行标题：note 空则用 category */
    fun expenseTitle(e: ExpenseEntity): String =
        if (e.note.trim().isEmpty()) e.category else e.note

    /** 收入记录行标题：note 空则显示"营业额" */
    fun performanceTitle(p: PerformanceEntity): String =
        if (p.note.trim().isEmpty()) "营业额" else p.note
}

/** 首页待办收件箱条目（对应 iOS HomeInboxItem） */
data class HomeInboxItem(
    val id: String,
    val title: String,
    val subtitle: String,
    /** 排序 rank：临期过期/今天=0、高优先级待办=1、配送中=2、普通配送=3、普通待办=4、远期临期=5 */
    val rank: Int,
    val sortDate: Long
)
