package com.xiaozhanggui.app.ai

import com.xiaozhanggui.app.domain.ai.BusinessInsightKind
import com.xiaozhanggui.app.domain.ai.BusinessPeriod
import com.xiaozhanggui.app.domain.ai.BusinessRecordKind
import com.xiaozhanggui.app.domain.ai.IntentKind
import com.xiaozhanggui.app.domain.ai.IntentRouter
import com.xiaozhanggui.app.domain.ai.ToolName
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * IntentRouter 分类测试（路由顺序 1:1 iOS IntentRouter.swift）。
 * 纯规则、0 Token、可单测。
 */
class IntentRouterTest {

    private val router = IntentRouter()

    @Test
    fun `天气问句优先于一切 CREATE`() {
        val result = router.classify("明天恩平什么天气啊，帮我查下")
        assertEquals(IntentKind.WeatherQuery, result)
    }

    @Test
    fun `提醒看天气不是天气查询而是待办`() {
        val result = router.classify("提醒我看天气")
        assertEquals(IntentKind.BusinessAction(ToolName.CREATE_TODO), result)
    }

    @Test
    fun `记营业额`() {
        val result = router.classify("今天美团680")
        assertEquals(IntentKind.BusinessAction(ToolName.RECORD_REVENUE), result)
    }

    @Test
    fun `只有来源词没有金额时不当成记账`() {
        val result = router.classify("美团怎么开店")
        assertEquals(IntentKind.WorldChat, result)
    }

    @Test
    fun `配送`() {
        val result = router.classify("今晚8点送3杯珍珠奶茶到幸福路9号")
        assertEquals(IntentKind.BusinessAction(ToolName.CREATE_DELIVERY), result)
    }

    @Test
    fun `备忘先于待办`() {
        val result = router.classify("记一下供应商周五来")
        assertEquals(IntentKind.BusinessAction(ToolName.CREATE_MEMO), result)
    }

    @Test
    fun `待办`() {
        val result = router.classify("明天下两箱可乐")
        assertEquals(IntentKind.BusinessAction(ToolName.CREATE_TODO), result)
    }

    @Test
    fun `经营读问答优先于新建`() {
        val revenue = router.classify("今天营业额多少")
        assertTrue(revenue is IntentKind.BusinessQuery)
        assertEquals(BusinessRecordKind.REVENUE_TODAY, (revenue as IntentKind.BusinessQuery).kind)

        val delivery = router.classify("今天还有几单配送")
        assertTrue(delivery is IntentKind.BusinessQuery)
        assertEquals(BusinessRecordKind.DELIVERY, (delivery as IntentKind.BusinessQuery).kind)
    }

    @Test
    fun `问句含时间词也不落入 CREATE`() {
        // P0-1 / P0-4：是问句但不属于店内经营实体 → worldChat，绝不能因「明天」落 CREATE
        val result = router.classify("明天会下雨吗")
        assertEquals(IntentKind.WeatherQuery, result)

        val result2 = router.classify("明天有什么安排吗")
        assertEquals(IntentKind.WorldChat, result2)
    }

    @Test
    fun `商品查询`() {
        val result = router.classify("可乐多少钱")
        assertTrue(result is IntentKind.GoodsQuery)
        assertEquals("可乐多少钱", (result as IntentKind.GoodsQuery).query)
    }

    @Test
    fun `解释类问题不是商品查询`() {
        val result = router.classify("什么是毛利率")
        assertEquals(IntentKind.WorldChat, result)
    }

    @Test
    fun `经营分析周期`() {
        val result = router.classify("这个月生意怎么样")
        assertTrue(result is IntentKind.BusinessInsight)
        val kind = (result as IntentKind.BusinessInsight).kind
        assertTrue(kind is BusinessInsightKind.Period)
        assertEquals(BusinessPeriod.THIS_MONTH, (kind as BusinessInsightKind.Period).period)
    }

    @Test
    fun `跨日比较直接进入经营分析`() {
        val result = router.classify("今天比昨天生意怎么样")
        assertTrue(result is IntentKind.BusinessInsight)
        assertEquals(BusinessInsightKind.Comparison, (result as IntentKind.BusinessInsight).kind)
    }

    @Test
    fun `兜底普通聊天`() {
        assertEquals(IntentKind.WorldChat, router.classify("你好"))
        assertEquals(IntentKind.WorldChat, router.classify(""))
        assertEquals(IntentKind.WorldChat, router.classify("   "))
    }
}
