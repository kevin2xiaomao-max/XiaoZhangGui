package com.xiaozhanggui.app.voice

import com.xiaozhanggui.app.domain.voice.VoiceParser
import com.xiaozhanggui.app.domain.voice.VoiceRecordType
import com.xiaozhanggui.app.domain.voice.validateVoiceDraft
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * VoiceParser 边界回归（Phase 1 语义回归 worker）。
 *
 * 在 VoiceParserTest 基础上补齐 DELTA 审计要求的边界：
 * - 混合关键词优先级（1:1 iOS VoiceModel.detectType 顺序）
 * - 金额缺失各分支（parse 全链路 + validateVoiceDraft）
 * - expense 关键词误判为收入的反例（及反向：纯收入句不得判支出）
 * - 直写无确认卡（parse 直接产出可写草稿，无中间确认态）
 */
class VoiceParserBoundaryTest {

    // ---------- 混合关键词优先级：expense > revenue > expiry > customer > memo > todo ----------

    @Test
    fun `expense wins over revenue when both present`() {
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("今天收入500进货花了200"))
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("支出100收入200"))
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("卖了300块又进货花了500"))
    }

    @Test
    fun `revenue wins over expiry customer and memo keywords`() {
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("卖了300块过期牛奶处理一下"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("配送费收入200"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("记一下今天的收入"))
    }

    @Test
    fun `expense wins over expiry in mixed sentence`() {
        assertEquals(VoiceRecordType.EXPENSE, VoiceParser.detectType("进货的牛奶还有3天过期"))
    }

    @Test
    fun `expiry wins over customer and memo keywords`() {
        assertEquals(VoiceRecordType.EXPIRY, VoiceParser.detectType("客户退货的牛奶还有3天过期"))
        assertEquals(VoiceRecordType.EXPIRY, VoiceParser.detectType("记一下临期商品"))
    }

    @Test
    fun `customer wins over memo keywords`() {
        assertEquals(VoiceRecordType.CUSTOMER, VoiceParser.detectType("记一下给王老板送两箱水"))
    }

    // ---------- expense 误判反例：纯收入句不得判为支出 ----------

    @Test
    fun `plain revenue sentences are never misclassified as expense`() {
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("今天收入800"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("卖了200块"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("微信收款150"))
        assertEquals(VoiceRecordType.REVENUE, VoiceParser.detectType("入账1000"))
    }

    @Test
    fun `花菜 is not 花了 - substring quirk does not misfire`() {
        // "花"≠"花了"：子串必须完整命中才算支出关键词
        assertEquals(VoiceRecordType.TODO, VoiceParser.detectType("买花菜"))
    }

    // ---------- 金额缺失各分支：parse 全链路 + validateVoiceDraft ----------

    @Test
    fun `revenue without amount blocks with 请补充收入金额`() {
        val draft = VoiceParser.parse("今天营业额")
        assertEquals(VoiceRecordType.REVENUE, draft.type)
        assertNull(draft.amount)
        assertEquals("请补充收入金额", validateVoiceDraft(draft))
    }

    @Test
    fun `expense without amount blocks with 请补充支出金额`() {
        for (text in listOf("进货", "今天支出", "花了")) {
            val draft = VoiceParser.parse(text)
            assertEquals("[$text]", VoiceRecordType.EXPENSE, draft.type)
            assertNull(draft.amount)
            assertEquals("[$text]", "请补充支出金额", validateVoiceDraft(draft))
        }
    }

    @Test
    fun `zero amount blocks like missing amount`() {
        val revenue = VoiceParser.parse("今天营业额0元")
        assertEquals("请补充收入金额", validateVoiceDraft(revenue))
        val expense = VoiceParser.parse("进货花了0元")
        assertEquals("请补充支出金额", validateVoiceDraft(expense))
    }

    @Test
    fun `with amount both money types pass validation`() {
        val revenue = VoiceParser.parse("今天收入不错入账500")
        assertEquals(VoiceRecordType.REVENUE, revenue.type)
        assertNull(validateVoiceDraft(revenue))
        val expense = VoiceParser.parse("进货花了500")
        assertEquals(VoiceRecordType.EXPENSE, expense.type)
        assertNull(validateVoiceDraft(expense))
    }

    // ---------- 直写无确认卡：parse 直接产出可写草稿 ----------

    @Test
    fun `parse yields directly committable draft without confirmation card`() {
        // 语音链路无确认卡：parse 一次到位，校验通过即可写库
        val draft = VoiceParser.parse("进货花了500")
        assertEquals(VoiceRecordType.EXPENSE, draft.type)
        assertTrue(draft.title.isNotBlank())
        assertTrue(draft.detail.isNotBlank())
        assertEquals(500.0, draft.amount!!, 0.0)
        assertNull(validateVoiceDraft(draft))
    }

    @Test
    fun `non-money types never require amount`() {
        for (text in listOf("明天下午三点开会", "记一下供应商电话", "牛奶还有3天过期", "给王老板送两箱怡宝")) {
            assertNull("[$text]", validateVoiceDraft(VoiceParser.parse(text)))
        }
    }
}
