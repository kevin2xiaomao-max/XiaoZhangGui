package com.xiaozhanggui.app.voice

import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.voice.ChineseNumber
import com.xiaozhanggui.app.domain.voice.VoiceDraft
import com.xiaozhanggui.app.domain.voice.VoiceParser
import com.xiaozhanggui.app.domain.voice.VoiceRecordType
import com.xiaozhanggui.app.domain.voice.validateVoiceDraft
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * VoiceParser 单元测试（GATE C #5 / #6）。
 *
 * iOS 侧 VoiceParser 零单元测试（审计 C §八覆盖缺口 1），Android 迁移时补齐：
 * 分流规则、金额缺失报错、天气查询拒绝、金额/时间解析边界全部锁定。
 */
class VoiceParserTest {

    private fun hourOf(millis: Long): Int =
        ZonedDateTime.ofInstant(Instant.ofEpochMilli(millis), ZoneId.systemDefault()).hour

    private fun draftOf(type: VoiceRecordType, amount: Double?): VoiceDraft = VoiceDraft(
        type = type,
        title = "t",
        detail = "d",
        amount = amount,
        dueAt = null,
        expiryDays = null,
        customerName = null,
        quantity = null,
        goodsName = null,
        original = "原文",
    )

    // ---------- detectType 分流 ----------

    @Test
    fun `detectType routes expense keywords`() {
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("今天支出50元打车"))
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("进货花了500"))
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("花了200买菜"))
    }

    @Test
    fun `detectType routes revenue keywords`() {
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("今天营业额2680"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("卖了300块"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("微信收款150"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("今天收入不错入账500"))
    }

    @Test
    fun `detectType routes expiry keywords`() {
        assertEquals(VoiceRecordType.EXPIRY, VoiceParser.detectType("牛奶还有3天过期"))
        assertEquals(VoiceRecordType.EXPIRY, VoiceParser.detectType("临期商品处理一下"))
        assertEquals(VoiceRecordType.EXPIRY, VoiceParser.detectType("面包快到期了"))
    }

    @Test
    fun `detectType routes delivery to customer`() {
        assertEquals(VoiceRecordType.CUSTOMER, VoiceParser.detectType("王老板配送两箱水"))
        assertEquals(VoiceRecordType.CUSTOMER, VoiceParser.detectType("给张老板送两箱怡宝"))
        assertEquals(VoiceRecordType.CUSTOMER, VoiceParser.detectType("送货到幸福小区"))
    }

    @Test
    fun `detectType routes memo keywords`() {
        assertEquals(VoiceRecordType.MEMO, VoiceParser.detectType("记一下供应商电话"))
        assertEquals(VoiceRecordType.MEMO, VoiceParser.detectType("备忘明天带发票"))
        assertEquals(VoiceRecordType.MEMO, VoiceParser.detectType("客人说下次多拿点货"))
    }

    @Test
    fun `detectType defaults to todo`() {
        assertEquals(VoiceRecordType.TODO, VoiceParser.detectType("明天下午三点开会"))
        assertEquals(VoiceRecordType.TODO, VoiceParser.detectType("卡卡卡卡"))
    }

    @Test
    fun `detectType expense wins over revenue when both present`() {
        // 优先级：进货/支出/花了 在前（1:1 iOS detectType 顺序）
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("进货收入都记一下花了500"))
    }

    // ---------- GATE C #5：VoiceParser 支持 expense ----------

    @Test
    fun `GATE C5 parse 进货花了500 yields expense with amount`() {
        val draft = VoiceParser.parse("进货花了500")
        assertEquals(VoiceRecordType.EXPENSE, draft.type)
        assertEquals(500.0, draft.amount!!, 0.0)
        assertEquals("记录进货支出", draft.title)
        assertEquals("¥500.00", draft.detail)
    }

    // ---------- GATE C #6：金额缺失必须报错，绝不写 0 ----------

    @Test
    fun `GATE C6 revenue without amount is rejected`() {
        assertEquals("请补充收入金额", validateVoiceDraft(draftOf(VoiceRecordType.REVENUE, null)))
    }

    @Test
    fun `GATE C6 revenue with zero amount is rejected`() {
        assertEquals("请补充收入金额", validateVoiceDraft(draftOf(VoiceRecordType.REVENUE, 0.0)))
    }

    @Test
    fun `GATE C6 expense without amount is rejected`() {
        assertEquals("请补充支出金额", validateVoiceDraft(draftOf(VoiceRecordType.EXPENSE, null)))
    }

    @Test
    fun `GATE C6 drafts with amount pass validation`() {
        assertNull(validateVoiceDraft(draftOf(VoiceRecordType.REVENUE, 100.0)))
        assertNull(validateVoiceDraft(draftOf(VoiceRecordType.EXPENSE, 50.0)))
    }

    @Test
    fun `GATE C6 non-money types do not require amount`() {
        assertNull(validateVoiceDraft(draftOf(VoiceRecordType.TODO, null)))
        assertNull(validateVoiceDraft(draftOf(VoiceRecordType.MEMO, null)))
        assertNull(validateVoiceDraft(draftOf(VoiceRecordType.EXPIRY, null)))
        assertNull(validateVoiceDraft(draftOf(VoiceRecordType.CUSTOMER, null)))
    }

    // ---------- isUnsupportedQuery ----------

    @Test
    fun `isUnsupportedQuery rejects weather questions`() {
        assertTrue(VoiceParser.isUnsupportedQuery("明天天气怎么样"))
        assertTrue(VoiceParser.isUnsupportedQuery("今天天气不错"))
    }

    @Test
    fun `isUnsupportedQuery keeps record intent with weather word`() {
        assertFalse(VoiceParser.isUnsupportedQuery("明天的天气提醒我带伞"))
        assertFalse(VoiceParser.isUnsupportedQuery("记一下明天的天气"))
        assertFalse(VoiceParser.isUnsupportedQuery("今天营业额2680"))
    }

    // ---------- 金额解析边界 ----------

    @Test
    fun `parseAmount prefers arabic digits`() {
        assertEquals(2680.0, VoiceParser.parseAmount("今天营业额2680")!!, 0.0)
        assertEquals(1280.5, VoiceParser.parseAmount("花了1,280.5元")!!, 0.0)
    }

    @Test
    fun `parseAmount falls back to chinese numerals`() {
        assertEquals(68.0, VoiceParser.parseAmount("花了六十八块")!!, 0.0)
        assertEquals(325.0, VoiceParser.parseAmount("三百二十五元进货")!!, 0.0)
    }

    @Test
    fun `parseAmount returns null when no digits`() {
        assertNull(VoiceParser.parseAmount("明天开会"))
    }

    // ---------- 时间解析边界 ----------

    @Test
    fun `parseDueTime parses 明天下午三点`() {
        val due = VoiceParser.parseDueTime("明天下午三点开会")!!
        assertTrue(DateExt.isTomorrow(due))
        assertEquals(15, hourOf(due))
    }

    @Test
    fun `parseDueTime parses 晚上8点 as 20`() {
        val due = VoiceParser.parseDueTime("晚上8点送两箱怡宝")!!
        assertTrue(DateExt.isToday(due))
        assertEquals(20, hourOf(due))
    }

    @Test
    fun `parseDueTime 今晚 quirk mirrors iOS`() {
        // iOS period 只认"下午/晚上"子串，"今晚"不命中 → 8:00（上午）。1:1 保留此行为。
        val due = VoiceParser.parseDueTime("今晚8点送水")!!
        assertTrue(DateExt.isToday(due))
        assertEquals(8, hourOf(due))
    }

    @Test
    fun `parseDueTime parses 中午 as 12`() {
        val due = VoiceParser.parseDueTime("中午吃饭")!!
        assertTrue(DateExt.isToday(due))
        assertEquals(12, hourOf(due))
    }

    @Test
    fun `parseDueTime date-only yields start of day`() {
        val due = VoiceParser.parseDueTime("后天")!!
        assertTrue(DateExt.isSameDay(due, System.currentTimeMillis() + 2 * 86_400_000L))
        assertFalse(DateExt.hasClock(due))
    }

    @Test
    fun `parseDueTime returns null without time words`() {
        assertNull(VoiceParser.parseDueTime("随便说点什么"))
    }

    // ---------- 数量 / 客户名 / 中文数字 ----------

    @Test
    fun `parseQuantity handles arabic and chinese numerals`() {
        assertEquals(2, VoiceParser.parseQuantity("送两箱水"))
        assertEquals(3, VoiceParser.parseQuantity("3瓶可乐"))
        assertNull(VoiceParser.parseQuantity("明天开会"))
    }

    @Test
    fun `parseCustomerName extracts common titles`() {
        assertEquals("王老板", VoiceParser.parseCustomerName("给王老板送水"))
        assertEquals("张姐", VoiceParser.parseCustomerName("张姐明天来拿货"))
        assertNull(VoiceParser.parseCustomerName("明天开会"))
    }

    @Test
    fun `chineseNumber parses compound numerals`() {
        assertEquals(325, ChineseNumber.parse("三百二十五"))
        assertEquals(2000, ChineseNumber.parse("两千"))
        assertEquals(30, ChineseNumber.parse("三十"))
    }

    // ---------- 完整 parse ----------

    @Test
    fun `parse todo strips leading time tokens`() {
        val draft = VoiceParser.parse("明天下午三点联系饮料供应商")
        assertEquals(VoiceRecordType.TODO, draft.type)
        assertEquals("联系饮料供应商", draft.title)
        assertTrue(DateExt.isTomorrow(draft.dueAt!!))
        assertEquals(15, hourOf(draft.dueAt!!))
    }

    @Test
    fun `parse customer extracts name quantity goods`() {
        val draft = VoiceParser.parse("给王老板送两箱怡宝")
        assertEquals(VoiceRecordType.CUSTOMER, draft.type)
        assertEquals("王老板", draft.customerName)
        assertEquals(2, draft.quantity)
        assertEquals("怡宝", draft.goodsName)
        assertEquals("怡宝", draft.title)
        assertEquals("王老板 · 2 件", draft.detail)
    }

    @Test
    fun `parse customer with delivery time`() {
        val draft = VoiceParser.parse("晚上8点给302送两箱怡宝")
        assertEquals(VoiceRecordType.CUSTOMER, draft.type)
        assertEquals(2, draft.quantity)
        assertEquals(20, hourOf(draft.dueAt!!))
        assertTrue(draft.detail.contains("2 件"))
    }

    @Test
    fun `parse expiry extracts name and days`() {
        val draft = VoiceParser.parse("牛奶还有3天过期")
        assertEquals(VoiceRecordType.EXPIRY, draft.type)
        assertEquals("牛奶", draft.title)
        assertEquals(3, draft.expiryDays)
        assertEquals("还有 3 天过期", draft.detail)
    }

    @Test
    fun `parse expiry supports chinese numeral days`() {
        val draft = VoiceParser.parse("面包还有三天过期")
        assertEquals(3, draft.expiryDays)
    }

    @Test
    fun `parse memo keeps original text`() {
        val draft = VoiceParser.parse("记一下供应商周五过来")
        assertEquals(VoiceRecordType.MEMO, draft.type)
        assertEquals("语音记录", draft.title)
        assertEquals("记一下供应商周五过来", draft.detail)
    }

    @Test
    fun `parse revenue keeps original for note`() {
        val draft = VoiceParser.parse("今天营业额2680")
        assertEquals(VoiceRecordType.REVENUE, draft.type)
        assertEquals(2680.0, draft.amount!!, 0.0)
        assertEquals("今天营业额2680", draft.original)
        assertTrue(DateExt.isToday(draft.dueAt!!))
    }
}
