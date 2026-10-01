package com.xiaozhanggui.app.quickrecord

import com.xiaozhanggui.app.domain.quickrecord.AmountPhraseParser
import com.xiaozhanggui.app.domain.quickrecord.DatePhraseParser
import com.xiaozhanggui.app.domain.quickrecord.LocalQuickRecordParser
import com.xiaozhanggui.app.domain.quickrecord.QuantityPhraseParser
import com.xiaozhanggui.app.domain.quickrecord.QuickRecordKind
import com.xiaozhanggui.app.domain.quickrecord.canSaveQuickRecord
import com.xiaozhanggui.app.ui.screens.quickrecord.quickRecordCommitAmount
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * QuickRecordParser 单元测试。对应 iOS QuickRecordParser.swift 的分流/提取规则。
 *
 * 固定 now = 2026-10-02（周五）10:00 本地时间，所有日期断言都基于此时钟。
 */
class QuickRecordParserTest {

    private val zone: ZoneId = ZoneId.systemDefault()
    private val now: Long = LocalDate.of(2026, 10, 2)
        .atTime(10, 0).atZone(zone).toInstant().toEpochMilli()

    private fun ldt(millis: Long): LocalDateTime =
        ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), zone).toLocalDateTime()

    init {
        assertEquals(DayOfWeek.FRIDAY, LocalDate.of(2026, 10, 2).dayOfWeek)
    }

    // ---------- 分流 ----------

    @Test
    fun `今天营业额2680 parses as performance`() {
        val draft = LocalQuickRecordParser.parse("今天营业额2680", now)
        assertEquals(QuickRecordKind.PERFORMANCE, draft.kind)
        assertEquals(2680.0, draft.amount!!, 0.0)
        assertEquals("营业额", draft.title)
        assertEquals(now, draft.date)
        assertTrue(draft.summary.startsWith("记入业绩"))
    }

    @Test
    fun `今天美团680 parses as performance without 营业额 keyword`() {
        val draft = LocalQuickRecordParser.parse("今天美团680", now)
        assertEquals(QuickRecordKind.PERFORMANCE, draft.kind)
        assertEquals(680.0, draft.amount!!, 0.0)
    }

    @Test
    fun `记一下王老板交代的事 parses as memo`() {
        val draft = LocalQuickRecordParser.parse("记一下王老板交代的事", now)
        assertEquals(QuickRecordKind.MEMO, draft.kind)
        assertEquals("记一下王老板交代的事", draft.title)
    }

    @Test
    fun `明天下午3点联系饮料供应商 parses as todo at 15-00`() {
        val draft = LocalQuickRecordParser.parse("明天下午3点联系饮料供应商", now)
        assertEquals(QuickRecordKind.TODO, draft.kind)
        assertEquals(LocalDateTime.of(2026, 10, 3, 15, 0), ldt(draft.date!!))
    }

    @Test
    fun `后天张老板配送 parses as customer`() {
        val draft = LocalQuickRecordParser.parse("后天张老板配送", now)
        assertEquals(QuickRecordKind.CUSTOMER, draft.kind)
        assertEquals("张老板", draft.customer)
        assertEquals(LocalDateTime.of(2026, 10, 4, 10, 0), ldt(draft.date!!))
    }

    @Test
    fun `给302送 parses as customer with room number`() {
        val draft = LocalQuickRecordParser.parse("今晚8点给302送两箱怡宝", now)
        assertEquals(QuickRecordKind.CUSTOMER, draft.kind)
        assertEquals("302", draft.customer)
    }

    @Test
    fun `月底两箱牛奶退货 parses as expiry`() {
        val draft = LocalQuickRecordParser.parse("月底两箱牛奶退货", now)
        assertEquals(QuickRecordKind.EXPIRY, draft.kind)
        assertEquals("两箱牛奶", draft.title)
        assertEquals(2, draft.quantity)
        assertEquals(LocalDateTime.of(2026, 10, 31, 0, 0), ldt(draft.date!!))
    }

    @Test
    fun `unrecognized sentence falls back to memo`() {
        val draft = LocalQuickRecordParser.parse("卡卡卡", now)
        assertEquals(QuickRecordKind.MEMO, draft.kind)
        assertEquals("卡卡卡", draft.note)
    }

    @Test
    fun `blank input cannot save`() {
        assertFalse(canSaveQuickRecord(""))
        assertFalse(canSaveQuickRecord("   \n "))
        assertTrue(canSaveQuickRecord("记一笔"))
    }

    // ---------- GATE C #5：QuickRecord 无 expense 类型 ----------

    @Test
    fun `GATE C5 - quickrecord has no expense kind`() {
        assertFalse(QuickRecordKind.entries.any { it.name == "EXPENSE" })
        assertEquals(5, QuickRecordKind.entries.size)
    }

    @Test
    fun `GATE C5 - 进货花了500 routes to todo not expense`() {
        // iOS 规则：「进货」命中 todoSignals → todo；QuickRecord 链路无 expense 分支。
        val draft = LocalQuickRecordParser.parse("进货花了500", now)
        assertEquals(QuickRecordKind.TODO, draft.kind)
    }

    // ---------- GATE C #6：缺金额写 0，不报错 ----------

    @Test
    fun `GATE C6 - missing amount commits as 0`() {
        val withoutAmount = LocalQuickRecordParser.parse("记一下买牛奶", now)
        assertNull(withoutAmount.amount)
        assertEquals(0.0, quickRecordCommitAmount(withoutAmount), 0.0)

        val withAmount = LocalQuickRecordParser.parse("今天营业额2680", now)
        assertEquals(2680.0, quickRecordCommitAmount(withAmount), 0.0)
    }

    // ---------- 金额 / 数量提取 ----------

    @Test
    fun `amount prefers arabic numerals`() {
        assertEquals(50.0, AmountPhraseParser.parse("买牛奶50元")!!, 0.0)
        assertEquals(2680.0, AmountPhraseParser.parse("今天营业额2680")!!, 0.0)
    }

    @Test
    fun `amount falls back to chinese numerals`() {
        assertEquals(68.0, AmountPhraseParser.parse("六十八元")!!, 0.0)
    }

    @Test
    fun `quantity parses units and 两箱`() {
        assertEquals(3, QuantityPhraseParser.parse("3箱水"))
        assertEquals(2, QuantityPhraseParser.parse("两箱怡宝"))
        assertNull(QuantityPhraseParser.parse("一些水"))
    }

    // ---------- 日期 ----------

    @Test
    fun `月底 resolves to last day of month`() {
        val millis = DatePhraseParser.parse("月底对账", now)!!
        assertEquals(LocalDateTime.of(2026, 10, 31, 0, 0), ldt(millis))
    }

    @Test
    fun `2月30日 is rejected`() {
        assertNull(DatePhraseParser.parse("2月30日提醒我", now))
    }

    @Test
    fun `same weekday rolls forward 7 days`() {
        // 周五说「周五」= 下周五（firstWeekday=周日，同周→+7）
        val millis = DatePhraseParser.parse("周五进货", now)!!
        assertEquals(LocalDateTime.of(2026, 10, 9, 0, 0), ldt(millis))
    }

    @Test
    fun `upcoming weekday stays in near future`() {
        // 周五说「周日」= 2 天后的周日
        val millis = DatePhraseParser.parse("周日休息", now)!!
        assertEquals(LocalDateTime.of(2026, 10, 4, 0, 0), ldt(millis))
    }

    @Test
    fun `明天下午3点 resolves to 15-00`() {
        val millis = DatePhraseParser.parse("明天下午3点", now)!!
        assertEquals(LocalDateTime.of(2026, 10, 3, 15, 0), ldt(millis))
    }

    @Test
    fun `no time words returns null`() {
        assertNull(DatePhraseParser.parse("随便记一句", now))
    }

    @Test
    fun `expiry without date defaults to tomorrow`() {
        val draft = LocalQuickRecordParser.parse("牛奶退货", now)
        assertEquals(QuickRecordKind.EXPIRY, draft.kind)
        assertEquals(1, draft.quantity)
        assertEquals(LocalDateTime.of(2026, 10, 3, 10, 0), ldt(draft.date!!))
    }

    @Test
    fun `expiry with empty name falls back to 临时商品`() {
        val draft = LocalQuickRecordParser.parse("明天退货", now)
        assertEquals(QuickRecordKind.EXPIRY, draft.kind)
        assertEquals("临时商品", draft.title)
    }

    // ---------- resolve（AI 专用澄清） ----------

    @Test
    fun `resolve bare 3点 is ambiguous`() {
        val result = DatePhraseParser.resolve("明天3点", now)
        assertTrue(result is DatePhraseParser.Resolution.AmbiguousClock)
        assertEquals("3点", (result as DatePhraseParser.Resolution.AmbiguousClock).token)
    }

    @Test
    fun `resolve 明天下午3点 is 15-00`() {
        val result = DatePhraseParser.resolve("明天下午3点", now)
        assertTrue(result is DatePhraseParser.Resolution.Date)
        val millis = (result as DatePhraseParser.Resolution.Date).millis
        assertEquals(LocalDateTime.of(2026, 10, 3, 15, 0), ldt(millis))
    }

    @Test
    fun `resolve 明天上午3点 is 03-00`() {
        val result = DatePhraseParser.resolve("明天上午3点", now)
        val millis = (result as DatePhraseParser.Resolution.Date).millis
        assertEquals(LocalDateTime.of(2026, 10, 3, 3, 0), ldt(millis))
    }

    @Test
    fun `resolve 12点 means noon without clarification`() {
        val result = DatePhraseParser.resolve("明天12点", now)
        val millis = (result as DatePhraseParser.Resolution.Date).millis
        assertEquals(LocalDateTime.of(2026, 10, 3, 12, 0), ldt(millis))
    }

    @Test
    fun `resolve date only returns the day`() {
        val result = DatePhraseParser.resolve("明天进货", now)
        assertTrue(result is DatePhraseParser.Resolution.Date)
    }

    @Test
    fun `resolve without any time word returns null`() {
        assertNull(DatePhraseParser.resolve("随便记一句", now))
    }
}
