package com.xiaozhanggui.app.ai

import com.xiaozhanggui.app.domain.ai.DeliveryArguments
import com.xiaozhanggui.app.domain.ai.IntentKind
import com.xiaozhanggui.app.domain.ai.LocalBusinessParser
import com.xiaozhanggui.app.domain.ai.LocalParseResult
import com.xiaozhanggui.app.domain.ai.MemoArguments
import com.xiaozhanggui.app.domain.ai.RevenueArguments
import com.xiaozhanggui.app.domain.ai.TodoArguments
import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolName
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * LocalBusinessParser 测试（Free First 0-Token 本地解析）。
 */
class LocalBusinessParserTest {

    private val parser = LocalBusinessParser()
    private val zone = ZoneId.systemDefault()

    private fun revenueIntent() = IntentKind.BusinessAction(ToolName.RECORD_REVENUE)
    private fun todoIntent() = IntentKind.BusinessAction(ToolName.CREATE_TODO)
    private fun memoIntent() = IntentKind.BusinessAction(ToolName.CREATE_MEMO)
    private fun deliveryIntent() = IntentKind.BusinessAction(ToolName.CREATE_DELIVERY)

    @Test
    fun `营业额高置信直接出卡`() {
        val result = parser.parse("今天美团680", revenueIntent())
        assertTrue(result is LocalParseResult.Tool)
        val args = (result as LocalParseResult.Tool).arguments as ToolArguments.Revenue
        assertEquals(680.0, args.args.amount!!, 0.001)
        assertEquals("美团", args.args.source)
        // 日期落在今天
        val day = LocalDate.ofInstant(Instant.ofEpochMilli(args.args.date!!), zone)
        assertEquals(LocalDate.now(zone), day)
    }

    @Test
    fun `营业额缺金额时追问不脑补`() {
        val result = parser.parse("记个账", revenueIntent())
        assertTrue(result is LocalParseResult.Clarify)
        assertTrue((result as LocalParseResult.Clarify).message.contains("需要金额"))
    }

    @Test
    fun `待办解析标题与到期`() {
        val result = parser.parse("明天下两箱可乐", todoIntent())
        assertTrue(result is LocalParseResult.Tool)
        val args = (result as LocalParseResult.Tool).arguments as ToolArguments.Todo
        assertEquals("下两箱可乐", args.args.title)
        val dueDay = LocalDate.ofInstant(Instant.ofEpochMilli(args.args.dueDate!!), zone)
        assertEquals(LocalDate.now(zone).plusDays(1), dueDay)
    }

    @Test
    fun `待办裸数字点必须追问不回落`() {
        // P0-3：「明天3点」歧义，绝不允许静默回落当前时间
        val result = parser.parse("明天3点开会", todoIntent())
        assertTrue(result is LocalParseResult.Clarify)
        val message = (result as LocalParseResult.Clarify).message
        assertTrue(message.contains("凌晨"))
        assertTrue(message.contains("下午"))
    }

    @Test
    fun `备忘剥前缀`() {
        val result = parser.parse("记一下供应商周五来", memoIntent())
        assertTrue(result is LocalParseResult.Tool)
        val args = (result as LocalParseResult.Tool).arguments as ToolArguments.Memo
        assertEquals("供应商周五来", args.args.title)
        assertEquals("记一下供应商周五来", args.args.content)
    }

    @Test
    fun `配送 P0-2 真机句全字段`() {
        val result = parser.parse("今晚8点送3杯珍珠奶茶到幸福路9号，一共45元", deliveryIntent())
        assertTrue(result is LocalParseResult.Tool)
        val args = (result as LocalParseResult.Tool).arguments as ToolArguments.Delivery
        // customer 必须为空（无明确人名）
        assertNull(args.args.customer)
        assertEquals("幸福路9号", args.args.roomOrAddress)
        assertEquals("珍珠奶茶", args.args.goodsName)
        assertEquals("3杯", args.args.quantity)
        assertEquals(45.0, args.args.amount!!, 0.001)
        assertEquals("今晚8点", args.args.deliveryTimeText)
        // 晚上8点 = 20:00
        val time = Instant.ofEpochMilli(args.args.deliveryTime!!).atZone(zone).toLocalTime()
        assertEquals(20, time.hour)
    }

    @Test
    fun `配送纯数字房号同时作为客户与房号`() {
        val result = parser.parse("给302送两箱可乐", deliveryIntent())
        assertTrue(result is LocalParseResult.Tool)
        val args = (result as LocalParseResult.Tool).arguments as ToolArguments.Delivery
        assertEquals("302", args.args.customer)
        assertEquals("302", args.args.roomOrAddress)
        assertEquals("可乐", args.args.goodsName)
        assertEquals("两箱", args.args.quantity)
    }

    @Test
    fun `配送缺地址缺商品时追问`() {
        val result = parser.parse("帮我送一下", deliveryIntent())
        assertTrue(result is LocalParseResult.Clarify)
    }

    @Test
    fun `非业务意图返回 null 走云端`() {
        assertNull(parser.parse("你好", IntentKind.WorldChat))
    }

    @Test
    fun `多商品交叉写法`() {
        val result = parser.parse("送到302室，百年糊涂×2，王老吉x3", deliveryIntent())
        assertTrue(result is LocalParseResult.Tool)
        val args = (result as LocalParseResult.Tool).arguments as ToolArguments.Delivery
        assertEquals("302室", args.args.roomOrAddress)
        // 首个商品
        assertEquals("百年糊涂", args.args.goodsName)
        assertEquals("×2", args.args.quantity)
        assertTrue(args.args.content!!.contains("王老吉"))
    }
}
