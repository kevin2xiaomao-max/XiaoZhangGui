package com.xiaozhanggui.app.voice

import com.xiaozhanggui.app.domain.quickrecord.LocalQuickRecordParser
import com.xiaozhanggui.app.domain.quickrecord.QuickRecordDraft
import com.xiaozhanggui.app.domain.quickrecord.QuickRecordKind
import com.xiaozhanggui.app.domain.voice.VoiceDraft
import com.xiaozhanggui.app.domain.voice.VoiceParser
import com.xiaozhanggui.app.domain.voice.VoiceRecordType
import com.xiaozhanggui.app.domain.voice.validateVoiceDraft
import com.xiaozhanggui.app.ui.screens.quickrecord.quickRecordCommitAmount
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 语音 vs 快速记录语义差异回归锁（Phase 3 Worker A）。
 *
 * 两条链路的差异是 iOS 原生行为，必须长期保持独立：
 * - VoiceParser：含 EXPENSE 分支，缺金额**报错**（GATE C #6，绝不写 0）；
 * - QuickRecordParser：无 EXPENSE 分支（5 类），缺金额**写 0，不报错**。
 */
class VoiceQuickRecordSemanticsRegressionTest {

    private fun voiceDraftOf(type: VoiceRecordType, amount: Double?): VoiceDraft = VoiceDraft(
        type = type,
        title = "",
        detail = "",
        amount = amount,
        dueAt = null,
        expiryDays = null,
        customerName = null,
        quantity = null,
        goodsName = null,
        original = "",
    )

    private fun quickRecordDraftOf(kind: QuickRecordKind, amount: Double?): QuickRecordDraft =
        QuickRecordDraft(
            kind = kind,
            title = "",
            amount = amount,
            date = null,
            quantity = null,
            customer = null,
            note = "",
            raw = "",
        )

    // ---------- VoiceParser：含 Expense，缺金额报错 ----------

    @Test
    fun `voice parser has expense branch`() {
        assertEquals(
            VoiceRecordType.EXPENSE,
            VoiceParser.detectType("进货花了500"),
        )
    }

    @Test
    fun `voice expense without amount is rejected with 请补充支出金额`() {
        assertEquals(
            "请补充支出金额",
            validateVoiceDraft(voiceDraftOf(VoiceRecordType.EXPENSE, null)),
        )
    }

    @Test
    fun `voice expense with amount passes validation`() {
        assertNull(validateVoiceDraft(voiceDraftOf(VoiceRecordType.EXPENSE, 500.0)))
    }

    @Test
    fun `voice revenue without amount is rejected with 请补充收入金额`() {
        assertEquals(
            "请补充收入金额",
            validateVoiceDraft(voiceDraftOf(VoiceRecordType.REVENUE, null)),
        )
    }

    // ---------- QuickRecordParser：无 Expense，缺金额写 0 ----------

    @Test
    fun `quick record has no expense kind`() {
        assertTrue(
            QuickRecordKind.entries.none { it.name == "EXPENSE" },
        )
    }

    @Test
    fun `quick record expense-like input never routes to expense`() {
        // "进货花了500" 在快速记录链路走待办分支，绝不产生支出分支
        //（QuickRecordKind 只有 PERFORMANCE/TODO/CUSTOMER/EXPIRY/MEMO 五类）。
        val draft = LocalQuickRecordParser.parse("进货花了500")
        assertEquals(QuickRecordKind.TODO, draft.kind)
    }

    @Test
    fun `quick record missing amount commits as 0 without error`() {
        assertEquals(
            0.0,
            quickRecordCommitAmount(quickRecordDraftOf(QuickRecordKind.PERFORMANCE, null)),
            0.0,
        )
        assertEquals(
            0.0,
            quickRecordCommitAmount(quickRecordDraftOf(QuickRecordKind.TODO, null)),
            0.0,
        )
    }

    @Test
    fun `quick record keeps amount when present`() {
        assertEquals(
            2680.0,
            quickRecordCommitAmount(quickRecordDraftOf(QuickRecordKind.PERFORMANCE, 2680.0)),
            0.0,
        )
    }
}
