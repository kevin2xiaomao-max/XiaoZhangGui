package com.xiaozhanggui.app.quickrecord

import com.xiaozhanggui.app.domain.quickrecord.LocalQuickRecordParser
import com.xiaozhanggui.app.domain.quickrecord.QuickRecordKind
import com.xiaozhanggui.app.ui.screens.quickrecord.quickRecordCommitAmount
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/**
 * QuickRecordParser 边界回归（Phase 1 语义回归 worker）。
 *
 * 在 QuickRecordParserTest 基础上补齐 DELTA 审计要求的边界：
 * - 混合关键词分流（QuickRecord 链路无 expense 分支，GATE C #5）
 * - 缺金额写 0（GATE C #6：缺金额绝不报错，只写 0）
 * - 备忘 title prefix(20)（显式备忘 / 兜底备忘两条路径）
 */
class QuickRecordParserBoundaryTest {

    private val zone: ZoneId = ZoneId.systemDefault()
    private val now: Long = LocalDate.of(2026, 10, 2)
        .atTime(10, 0).atZone(zone).toInstant().toEpochMilli()

    // ---------- 混合关键词：QuickRecord 无 expense 分支 ----------

    @Test
    fun `支出500 falls to memo - quickrecord has no expense branch`() {
        // "支出"不在 todoSignals/revenueSignals → 兜底备忘（与 Voice 的 EXPENSE 形成对照）
        val draft = LocalQuickRecordParser.parse("支出500", now)
        assertEquals(QuickRecordKind.MEMO, draft.kind)
    }

    @Test
    fun `bare 花了500 falls to memo not todo`() {
        // 对照："进货花了500"→TODO（"进货"命中 todoSignals），裸"花了500"无待办信号→备忘
        val withStock = LocalQuickRecordParser.parse("进货花了500", now)
        assertEquals(QuickRecordKind.TODO, withStock.kind)
        val bare = LocalQuickRecordParser.parse("花了500", now)
        assertEquals(QuickRecordKind.MEMO, bare.kind)
    }

    @Test
    fun `performance wins over todo signals`() {
        // 金额 + 营收词 → 营业额（performance 分支最先判断）
        val draft = LocalQuickRecordParser.parse("卖了500块记得对账", now)
        assertEquals(QuickRecordKind.PERFORMANCE, draft.kind)
        assertEquals(500.0, draft.amount!!, 0.0)
    }

    @Test
    fun `performance wins over customer signals`() {
        // 含"收款"→ 营业额，即使句子里有配送动作
        val draft = LocalQuickRecordParser.parse("给王老板送两箱怡宝收款200", now)
        assertEquals(QuickRecordKind.PERFORMANCE, draft.kind)
    }

    @Test
    fun `todo signals route purchase verbs to todo`() {
        assertEquals(QuickRecordKind.TODO, LocalQuickRecordParser.parse("进货", now).kind)
        assertEquals(QuickRecordKind.TODO, LocalQuickRecordParser.parse("明天补货", now).kind)
        assertEquals(QuickRecordKind.TODO, LocalQuickRecordParser.parse("下单买牛奶", now).kind)
    }

    // ---------- 备忘 title prefix(20)：1:1 iOS String(trimmed.prefix(20)) ----------

    @Test
    fun `explicit memo title is trimmed to 20 chars`() {
        val text = "记一下供应商王老板电话1380000111122223333"
        assertTrue(text.length > 20)
        val draft = LocalQuickRecordParser.parse(text, now)
        assertEquals(QuickRecordKind.MEMO, draft.kind)
        assertEquals(20, draft.title.length)
        assertEquals(text.take(20), draft.title)
    }

    @Test
    fun `fallback memo title is trimmed to 20 chars`() {
        val text = "今天天气真不错适合出去走走散散心看看风景拍拍照"
        assertTrue(text.length > 20)
        val draft = LocalQuickRecordParser.parse(text, now)
        assertEquals(QuickRecordKind.MEMO, draft.kind)
        assertEquals(20, draft.title.length)
        assertEquals(text.take(20), draft.title)
    }

    @Test
    fun `short memo keeps full text as title`() {
        val draft = LocalQuickRecordParser.parse("卡卡卡", now)
        assertEquals(QuickRecordKind.MEMO, draft.kind)
        assertEquals("卡卡卡", draft.title)
    }

    // ---------- 缺金额写 0：绝不报错（与 Voice 的报错形成对照） ----------

    @Test
    fun `missing amount commits as 0 without error`() {
        val memo = LocalQuickRecordParser.parse("今天天气真不错适合出去走走散散心看看风景拍拍照", now)
        assertNull(memo.amount)
        assertEquals(0.0, quickRecordCommitAmount(memo), 0.0)
        val todo = LocalQuickRecordParser.parse("明天下午3点联系饮料供应商", now)
        assertNull(todo.amount)
        assertEquals(0.0, quickRecordCommitAmount(todo), 0.0)
    }

    @Test
    fun `performance without amount never becomes performance`() {
        // 无金额 → isPerformance 为 false，落备忘兜底（提交时写 0 也无意义）
        val draft = LocalQuickRecordParser.parse("今天营业额", now)
        assertEquals(QuickRecordKind.MEMO, draft.kind)
    }

    @Test
    fun `performance with amount commits real amount`() {
        val draft = LocalQuickRecordParser.parse("今天营业额2680", now)
        assertEquals(QuickRecordKind.PERFORMANCE, draft.kind)
        assertEquals(2680.0, quickRecordCommitAmount(draft), 0.0)
    }
}
