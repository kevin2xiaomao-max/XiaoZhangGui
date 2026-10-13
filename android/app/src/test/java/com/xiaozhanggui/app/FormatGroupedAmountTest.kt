package com.xiaozhanggui.app

import com.xiaozhanggui.app.domain.Format
import org.junit.Assert.assertEquals
import org.junit.Test

/**
 * 金额格式化 parity 回归（Phase 3 Worker C）。
 *
 * 对应 iOS `Fmt.groupedAmount`：整数 → 千分位整数；小数 → 千分位 2 位小数；
 * **两分支都不带 ¥**，调用方自行拼接 "¥"。
 * 旧实现小数分支误用带 ¥ 的 `money()`，导致首页 Hero/日历出现 "¥¥"。
 */
class FormatGroupedAmountTest {

    @Test
    fun `groupedAmount integer has no currency symbol`() {
        assertEquals("11,500", Format.groupedAmount(11500.0))
        assertEquals("0", Format.groupedAmount(0.0))
    }

    @Test
    fun `groupedAmount decimal has no currency symbol`() {
        assertEquals("1,288.50", Format.groupedAmount(1288.5))
        assertEquals("0.50", Format.groupedAmount(0.5))
    }

    @Test
    fun `money keeps currency symbol`() {
        // money() 本身带 ¥ 的行为不变（其他调用方依赖）
        assertEquals("¥1,288.50", Format.money(1288.5))
    }
}
