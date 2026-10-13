package com.xiaozhanggui.app

import com.xiaozhanggui.app.domain.IncomeSource
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * `IncomeSource` 派生逻辑单元测试（对应 iOS `IncomeSource.from(note:)` /
 * `IncomeSource.from(performance:)`，`PerformanceModel.swift`）。
 */
class IncomeSourceTest {

    // ---------- from(note:) ----------

    @Test
    fun `fromNote 含美团返回美团`() {
        assertEquals(IncomeSource.MEITUAN, IncomeSource.fromNote("美团外卖收入"))
    }

    @Test
    fun `fromNote 含门店返回门店`() {
        assertEquals(IncomeSource.STORE, IncomeSource.fromNote("门店散客"))
    }

    @Test
    fun `fromNote 含到店返回门店`() {
        assertEquals(IncomeSource.STORE, IncomeSource.fromNote("到店自提"))
    }

    @Test
    fun `fromNote 美团优先于门店（与 iOS 检查顺序一致）`() {
        assertEquals(IncomeSource.MEITUAN, IncomeSource.fromNote("美团门店联营"))
    }

    @Test
    fun `fromNote 无关键词返回其他`() {
        assertEquals(IncomeSource.OTHER, IncomeSource.fromNote("微信收款"))
    }

    @Test
    fun `fromNote 空白返回其他`() {
        assertEquals(IncomeSource.OTHER, IncomeSource.fromNote("   "))
    }

    // ---------- from(performance:)：字段优先级 ----------

    @Test
    fun `fromPerformance 字段合法时直接用字段值`() {
        assertEquals(
            IncomeSource.MEITUAN,
            IncomeSource.fromPerformance("美团", "微信支付", "门店散客")
        )
    }

    @Test
    fun `fromPerformance 字段非法时跳过 paymentMethod 走 note 派生`() {
        // iOS：stored 非空但非法 → 不查 paymentMethod，直接 from(note:)
        assertEquals(
            IncomeSource.OTHER,
            IncomeSource.fromPerformance("火星", "美团", "散客")
        )
    }

    @Test
    fun `fromPerformance 字段为空 paymentMethod 美团`() {
        assertEquals(
            IncomeSource.MEITUAN,
            IncomeSource.fromPerformance("", "美团", "扫呗")
        )
    }

    @Test
    fun `fromPerformance 字段为空 paymentMethod 英文 meituan`() {
        assertEquals(
            IncomeSource.MEITUAN,
            IncomeSource.fromPerformance("", "MeiTuan", "扫呗")
        )
    }

    @Test
    fun `fromPerformance 字段为空 paymentMethod 门店`() {
        assertEquals(
            IncomeSource.STORE,
            IncomeSource.fromPerformance("", "门店", "扫呗")
        )
    }

    @Test
    fun `fromPerformance 字段为空 paymentMethod 英文 store`() {
        assertEquals(
            IncomeSource.STORE,
            IncomeSource.fromPerformance("", "STORE", "扫呗")
        )
    }

    @Test
    fun `fromPerformance 字段与 paymentMethod 均为空时 note 派生`() {
        assertEquals(
            IncomeSource.STORE,
            IncomeSource.fromPerformance("", "", "到店自提")
        )
    }

    @Test
    fun `fromPerformance 全空回退其他`() {
        assertEquals(
            IncomeSource.OTHER,
            IncomeSource.fromPerformance("", "", "现金")
        )
    }

    // ---------- fromRaw（宽容解析） ----------

    @Test
    fun `fromRaw 合法值`() {
        assertEquals(IncomeSource.MEITUAN, IncomeSource.fromRaw("美团"))
    }

    @Test
    fun `fromRaw 非法值回退门店`() {
        assertEquals(IncomeSource.STORE, IncomeSource.fromRaw("火星"))
    }

    @Test
    fun `fromRaw null 回退门店`() {
        assertEquals(IncomeSource.STORE, IncomeSource.fromRaw(null))
    }

    @Test
    fun `rawValue 为中文`() {
        assertEquals("门店", IncomeSource.STORE.rawValue)
        assertEquals("美团", IncomeSource.MEITUAN.rawValue)
        assertEquals("其他", IncomeSource.OTHER.rawValue)
    }
}
