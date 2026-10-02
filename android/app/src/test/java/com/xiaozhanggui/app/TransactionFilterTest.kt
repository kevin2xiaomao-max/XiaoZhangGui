package com.xiaozhanggui.app

import com.xiaozhanggui.app.domain.TransactionSearchable
import com.xiaozhanggui.app.domain.filterTransactions
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 交易记录搜索回归测试。对应 iOS TransactionHistoryView：
 * 标题 / 来源大小写不敏感匹配；空 query 返回全部（顺序由调用方按日期倒序保证）。
 */
class TransactionFilterTest {

    private data class Row(
        override val title: String,
        override val source: String
    ) : TransactionSearchable

    private val rows = listOf(
        Row("扫呗收款", "扫呗"),
        Row("手动记账", "手动"),
        Row("美团外卖", "美团")
    )

    @Test
    fun `empty query returns all in order`() {
        assertEquals(rows, filterTransactions(rows, ""))
        assertEquals(rows, filterTransactions(rows, "   "))
    }

    @Test
    fun `matches title`() {
        assertEquals(listOf(rows[0]), filterTransactions(rows, "扫呗收款"))
    }

    @Test
    fun `matches source`() {
        assertEquals(listOf(rows[2]), filterTransactions(rows, "美团"))
    }

    @Test
    fun `case insensitive`() {
        val mixed = listOf(Row("ABC Shop", "Manual"))
        assertEquals(mixed, filterTransactions(mixed, "abc"))
        assertEquals(mixed, filterTransactions(mixed, "MANUAL"))
    }

    @Test
    fun `no match returns empty`() {
        assertEquals(emptyList<Row>(), filterTransactions(rows, "不存在"))
    }
}
