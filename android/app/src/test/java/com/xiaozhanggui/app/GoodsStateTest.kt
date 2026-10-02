package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.domain.GoodsState
import com.xiaozhanggui.app.domain.goodsStateOf
import com.xiaozhanggui.app.domain.isExpiringWithin
import com.xiaozhanggui.app.domain.isGoodsNameValid
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 商品状态判定 + 编辑器校验回归测试。
 * 对应 iOS GoodsView 的 GoodsState 优先级：已过期 > 即将到期(7天) > 库存不足 > 正常。
 */
class GoodsStateTest {

    private val now = 1_700_000_000_000L
    private val day = 24 * 3600 * 1000L

    private fun goods(
        expiryDate: Long? = null,
        stock: Int = 10,
        minStock: Int = 2
    ) = GoodsEntity(expiryDate = expiryDate, stock = stock, minStock = minStock)

    @Test
    fun `expired outranks everything`() {
        val g = goods(expiryDate = now - day, stock = 0, minStock = 5)
        assertEquals(GoodsState.EXPIRED, goodsStateOf(g, now))
    }

    @Test
    fun `expiring within 7 days`() {
        assertEquals(GoodsState.EXPIRING_SOON, goodsStateOf(goods(expiryDate = now + 3 * day), now))
        // 恰好 7 天边界（含）仍算即将到期
        assertEquals(GoodsState.EXPIRING_SOON, goodsStateOf(goods(expiryDate = now + 7 * day), now))
    }

    @Test
    fun `beyond 7 days falls through to stock check`() {
        assertEquals(GoodsState.NORMAL, goodsStateOf(goods(expiryDate = now + 8 * day), now))
        assertEquals(
            GoodsState.LOW_STOCK,
            goodsStateOf(goods(expiryDate = now + 8 * day, stock = 1, minStock = 5), now)
        )
    }

    @Test
    fun `low stock when no expiry date`() {
        assertEquals(GoodsState.LOW_STOCK, goodsStateOf(goods(stock = 2, minStock = 2), now))
        assertEquals(GoodsState.NORMAL, goodsStateOf(goods(stock = 3, minStock = 2), now))
    }

    @Test
    fun `expiring outranks low stock`() {
        val g = goods(expiryDate = now + day, stock = 0, minStock = 5)
        assertEquals(GoodsState.EXPIRING_SOON, goodsStateOf(g, now))
    }

    @Test
    fun `state labels match iOS`() {
        assertEquals("已过期", GoodsState.EXPIRED.label)
        assertEquals("即将到期", GoodsState.EXPIRING_SOON.label)
        assertEquals("库存不足", GoodsState.LOW_STOCK.label)
        assertEquals("正常", GoodsState.NORMAL.label)
    }

    @Test
    fun `isExpiringWithin matches stats card window`() {
        assertTrue(isExpiringWithin(goods(expiryDate = now), now))
        assertTrue(isExpiringWithin(goods(expiryDate = now + 7 * day), now))
        assertTrue(!isExpiringWithin(goods(expiryDate = now + 8 * day), now))
        assertTrue(!isExpiringWithin(goods(expiryDate = now - day), now))
        assertTrue(!isExpiringWithin(goods(expiryDate = null), now))
    }

    @Test
    fun `editor requires non-blank name`() {
        assertTrue(isGoodsNameValid("可口可乐"))
        assertTrue(isGoodsNameValid("  雪糕  "))
        assertFalse(isGoodsNameValid(""))
        assertFalse(isGoodsNameValid("   "))
    }
}
