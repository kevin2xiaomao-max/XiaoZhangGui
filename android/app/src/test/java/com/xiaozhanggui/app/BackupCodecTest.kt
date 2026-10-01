package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.backup.BackupCodec
import com.xiaozhanggui.app.data.backup.BackupService
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * 备份/恢复回归测试（Phase 6 Worker C）。
 *
 * 覆盖 BackupCodec（从 BackupService 抽出的纯编解码核心，语义逐行一致）：
 * - v2 round-trip：导出 JSON → 解码 → 7 类记录数一致、关键字段一致
 * - v1 旧格式容错：缺 incomeSource/completedAt/returnStatus/status/category → 安全默认，不崩溃
 * - 非法 JSON → InvalidFile；缺 records → InvalidRecords
 * - 未知 type / 单条坏记录 → 跳过不中断
 *
 * 说明：Room DAO 落库部分需 Android 运行时，JVM 测不到，此处以"解码出的实体集合"
 * 作为"新库导入"的结果断言（BackupService.restore 的落库只是逐条 insert）。
 */
class BackupCodecTest {

    private val json = Json { ignoreUnknownKeys = true }

    private fun sampleData(now: Long = 1_700_000_000_000L): BackupCodec.BackupData =
        BackupCodec.BackupData(
            todos = listOf(
                TodoEntity(title = "进货", detail = "牛奶20箱", dueDate = now + 3600_000, priority = 2),
                TodoEntity(title = "已办事项", isCompleted = true, completedAt = now - 1000)
            ),
            memos = listOf(
                MemoEntity(title = "供应商电话", content = "13800001111")
            ),
            performances = listOf(
                PerformanceEntity(
                    amount = 128.5, note = "扫呗 · 微信支付", date = now,
                    fingerprint = "fp-001", paymentMethod = "微信支付",
                    orderNo = "ORDER001", importSource = "saobei", incomeSource = "门店"
                )
            ),
            expenses = listOf(
                ExpenseEntity(amount = 50.0, category = "进货", note = "牛奶", date = now)
            ),
            expiryItems = listOf(
                ExpiryItemEntity(
                    name = "鲜奶", category = "乳品", quantity = 12,
                    expiryDate = now + 10L * 24 * 3600 * 1000,
                    remindDaysBefore = 7, returnStatus = "待处理"
                )
            ),
            customers = listOf(
                CustomerRequestEntity(
                    customer = "xzg-delivery-v1:abc", roomOrAddress = "3栋2单元",
                    phone = "13900002222", content = "送两箱水", status = "待处理"
                )
            ),
            goods = listOf(
                GoodsEntity(
                    name = "康师傅红烧牛肉面", category = "方便面", barcode = "6901234567890",
                    stock = 48, minStock = 12, purchasePrice = 2.5, salePrice = 4.5,
                    shelfLifeDays = 180
                )
            )
        )

    @Test
    fun `v2 roundtrip preserves counts and fields`() = runTest {
        val data = sampleData()
        val exportedAt = 1_700_000_111_111L
        val decoded = BackupCodec.decode(BackupCodec.encode(data, exportedAt))

        assertEquals(2, decoded.todos.size)
        assertEquals(1, decoded.memos.size)
        assertEquals(1, decoded.performances.size)
        assertEquals(1, decoded.expenses.size)
        assertEquals(1, decoded.expiryItems.size)
        assertEquals(1, decoded.customers.size)
        assertEquals(1, decoded.goods.size)
        assertEquals(8, decoded.totalCount())

        val todo = decoded.todos.first { it.title == "进货" }
        assertEquals("牛奶20箱", todo.detail)
        assertEquals(2, todo.priority)
        assertEquals(data.todos[0].dueDate, todo.dueDate)

        val done = decoded.todos.first { it.title == "已办事项" }
        assertTrue(done.isCompleted)
        assertEquals(data.todos[1].completedAt, done.completedAt)

        val perf = decoded.performances[0]
        assertEquals(128.5, perf.amount, 0.001)
        assertEquals("fp-001", perf.fingerprint)
        assertEquals("门店", perf.incomeSource)
        assertEquals("saobei", perf.importSource)

        assertEquals("待处理", decoded.expiryItems[0].returnStatus)
        assertEquals(12, decoded.expiryItems[0].quantity)
        assertEquals("xzg-delivery-v1:abc", decoded.customers[0].customer)
        assertEquals("待处理", decoded.customers[0].status)
        assertEquals(48, decoded.goods[0].stock)
        assertEquals("6901234567890", decoded.goods[0].barcode)
        assertEquals("供应商电话", decoded.memos[0].title)
        assertEquals("进货", decoded.expenses[0].category)
    }

    @Test
    fun `export writes v2 envelope`() {
        val text = BackupCodec.encode(sampleData(), exportedAt = 9_999L)
        val root = json.parseToJsonElement(text).jsonObject
        assertEquals("xiao-zhang-gui", root["app"]!!.jsonPrimitive.content)
        assertEquals(2, root["version"]!!.jsonPrimitive.int)
        assertEquals(9_999L, root["exportedAt"]!!.jsonPrimitive.long)
        assertEquals(8, root["records"]!!.jsonArray.size)
    }

    @Test
    fun `v1 todo without completedAt falls back to exportedAt`() = runTest {
        val text = """
            {"app":"xiao-zhang-gui","version":1,"exportedAt":5555,"records":[
              {"type":"todo","title":"旧待办","isCompleted":true,"createdAt":1111}
            ]}
        """.trimIndent()
        val decoded = BackupCodec.decode(text)
        assertEquals(1, decoded.todos.size)
        assertEquals(5555L, decoded.todos[0].completedAt)
    }

    @Test
    fun `v1 performance without incomeSource falls back to store`() = runTest {
        val text = """
            {"app":"xiao-zhang-gui","version":1,"exportedAt":5555,"records":[
              {"type":"performance","amount":99.0,"note":"x","date":1111}
            ]}
        """.trimIndent()
        val decoded = BackupCodec.decode(text)
        assertEquals("门店", decoded.performances[0].incomeSource)
        // 非法值同样回退
        val bad = text.replace("\"amount\":99.0", "\"amount\":99.0,\"incomeSource\":\"火星\"")
        assertEquals("门店", BackupCodec.decode(bad).performances[0].incomeSource)
    }

    @Test
    fun `v1 invalid status strings fall back to pending defaults`() = runTest {
        val text = """
            {"app":"xiao-zhang-gui","version":1,"exportedAt":5555,"records":[
              {"type":"expiry","name":"奶","expiryDate":2222,"returnStatus":"???"},
              {"type":"customer","customer":"c","status":"???"},
              {"type":"expense","amount":10.0,"category":""},
              {"type":"goods","name":"面","category":""}
            ]}
        """.trimIndent()
        val decoded = BackupCodec.decode(text)
        assertEquals("待处理", decoded.expiryItems[0].returnStatus)
        assertEquals("待处理", decoded.customers[0].status)
        assertEquals("其他", decoded.expenses[0].category)
        assertEquals("其他", decoded.goods[0].category)
    }

    @Test
    fun `invalid json throws InvalidFile`() = runTest {
        try {
            BackupCodec.decode("这不是 JSON {{{")
            fail("应抛 InvalidFile")
        } catch (e: BackupService.BackupError.InvalidFile) {
            // 预期
        }
    }

    @Test
    fun `missing records throws InvalidRecords`() = runTest {
        try {
            BackupCodec.decode("""{"app":"xiao-zhang-gui","version":2}""")
            fail("应抛 InvalidRecords")
        } catch (e: BackupService.BackupError.InvalidRecords) {
            // 预期
        }
    }

    @Test
    fun `unknown type and corrupt record are skipped`() = runTest {
        val text = """
            {"app":"xiao-zhang-gui","version":2,"exportedAt":5555,"records":[
              {"type":"alien","foo":"bar"},
              {"type":"todo","title":{"nested":1}},
              {"type":"todo","title":"好记录"}
            ]}
        """.trimIndent()
        val decoded = BackupCodec.decode(text)
        assertEquals(1, decoded.todos.size)
        assertEquals("好记录", decoded.todos[0].title)
    }

    @Test
    fun `double roundtrip is stable`() = runTest {
        val data = sampleData()
        val once = BackupCodec.decode(BackupCodec.encode(data, 1000L))
        val twice = BackupCodec.decode(BackupCodec.encode(once, 2000L))
        assertEquals(once.totalCount(), twice.totalCount())
        // 除 id/notificationId（导出本就不持久化）外关键字段一致
        assertEquals(
            once.todos.map { it.title to it.dueDate },
            twice.todos.map { it.title to it.dueDate }
        )
        assertEquals(
            once.performances.map { it.amount to it.fingerprint },
            twice.performances.map { it.amount to it.fingerprint }
        )
        assertEquals(once.goods.map { it.name to it.stock }, twice.goods.map { it.name to it.stock })
    }

    @Test
    fun `image base64 hooks are honored`() = runTest {
        val data = sampleData().copy(
            memos = listOf(MemoEntity(title = "带图", imagePath = "img/1.jpg"))
        )
        val encoded = BackupCodec.encode(data, 1000L, imageBase64Of = { path ->
            if (path == "img/1.jpg") "BASE64DATA" else null
        })
        assertTrue(encoded.contains("BASE64DATA"))
        val decoded = BackupCodec.decode(encoded, writeImage = { base64 ->
            if (base64 == "BASE64DATA") "img/restored.jpg" else null
        })
        assertEquals("img/restored.jpg", decoded.memos[0].imagePath)
    }

    @Test
    fun `empty database roundtrips to zero records`() = runTest {
        val decoded = BackupCodec.decode(BackupCodec.encode(BackupCodec.BackupData(), 1000L))
        assertEquals(0, decoded.totalCount())
        assertNull(decoded.todos.firstOrNull())
    }
}
