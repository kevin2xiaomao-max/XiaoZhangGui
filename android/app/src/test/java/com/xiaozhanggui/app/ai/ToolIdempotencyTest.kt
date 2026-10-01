package com.xiaozhanggui.app.ai

import com.xiaozhanggui.app.domain.ai.DeliveryArguments
import com.xiaozhanggui.app.domain.ai.MemoArguments
import com.xiaozhanggui.app.domain.ai.RevenueArguments
import com.xiaozhanggui.app.domain.ai.TodoArguments
import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolIdempotency
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.ZoneId

/**
 * 幂等指纹测试：格式与 iOS `ToolIdempotency.swift` 逐字 1:1。
 * - 营业额：`rev|<金额2位>|<日期yyyyMMdd>|<来源>|<备注>`
 * - 待办：`todo|<标题>|<到期分钟yyyyMMddHHmm>|<优先级>`
 * - 备忘：`memo|<标题>`
 * - 配送：`del|<客户>|<房号地址>|<分钟>|<商品名>|<数量>|<金额>`
 */
class ToolIdempotencyTest {

    private val zone = ZoneId.systemDefault()

    /** 2026-10-02 15:30（系统默认时区） */
    private fun millis(y: Int, mo: Int, d: Int, h: Int, mi: Int): Long =
        java.time.LocalDateTime.of(y, mo, d, h, mi).atZone(zone).toInstant().toEpochMilli()

    @Test
    fun `营业额指纹格式`() {
        val args = ToolArguments.Revenue(
            RevenueArguments(amount = 680.0, source = "美团", date = millis(2026, 10, 2, 15, 30))
        )
        assertEquals("rev|680.00|20261002|美团|", ToolIdempotency.fingerprint(args))
    }

    @Test
    fun `营业额金额保留两位小数`() {
        val args = ToolArguments.Revenue(
            RevenueArguments(amount = 100.5, date = millis(2026, 10, 2, 0, 0))
        )
        assertTrue(ToolIdempotency.fingerprint(args).startsWith("rev|100.50|"))
    }

    @Test
    fun `营业额无日期时记为 na`() {
        val args = ToolArguments.Revenue(RevenueArguments(amount = 10.0, date = null))
        assertTrue(ToolIdempotency.fingerprint(args).startsWith("rev|10.00|na|"))
    }

    @Test
    fun `待办指纹格式`() {
        val args = ToolArguments.Todo(
            TodoArguments(title = "下两箱可乐", dueDate = millis(2026, 10, 3, 15, 0), priority = 0)
        )
        assertEquals("todo|下两箱可乐|202610031500|0", ToolIdempotency.fingerprint(args))
    }

    @Test
    fun `待办无到期时记为 na`() {
        val args = ToolArguments.Todo(TodoArguments(title = "买菜", dueDate = null))
        assertEquals("todo|买菜|na|0", ToolIdempotency.fingerprint(args))
    }

    @Test
    fun `备忘指纹格式`() {
        val args = ToolArguments.Memo(MemoArguments(title = "供应商周五来", content = "x"))
        assertEquals("memo|供应商周五来", ToolIdempotency.fingerprint(args))
    }

    @Test
    fun `配送指纹格式`() {
        val args = ToolArguments.Delivery(
            DeliveryArguments(
                customer = "阿东",
                roomOrAddress = "302室",
                deliveryTime = millis(2026, 10, 2, 20, 0),
                goodsName = "珍珠奶茶",
                quantity = "3杯",
                amount = 45.0
            )
        )
        assertEquals(
            "del|阿东|302室|202610022000|珍珠奶茶|3杯|45.00",
            ToolIdempotency.fingerprint(args)
        )
    }

    @Test
    fun `相同业务内容指纹相同`() {
        val date = millis(2026, 10, 2, 9, 0)
        val a = ToolArguments.Revenue(RevenueArguments(amount = 100.0, source = "微信", date = date))
        val b = ToolArguments.Revenue(RevenueArguments(amount = 100.0, source = "微信", date = date))
        assertEquals(ToolIdempotency.fingerprint(a), ToolIdempotency.fingerprint(b))
    }

    @Test
    fun `不同金额指纹不同`() {
        val date = millis(2026, 10, 2, 9, 0)
        val a = ToolArguments.Revenue(RevenueArguments(amount = 100.0, date = date))
        val b = ToolArguments.Revenue(RevenueArguments(amount = 101.0, date = date))
        assertNotEquals(ToolIdempotency.fingerprint(a), ToolIdempotency.fingerprint(b))
    }

    @Test
    fun `newCallId 唯一且带前缀`() {
        val a = ToolIdempotency.newCallId()
        val b = ToolIdempotency.newCallId()
        assertTrue(a.startsWith("call_"))
        assertNotEquals(a, b)
    }
}
