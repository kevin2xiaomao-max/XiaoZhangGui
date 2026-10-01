package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.PerformanceDao
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.SaobeiImportCommitResult
import com.xiaozhanggui.app.data.repository.SaobeiParsedRow
import com.xiaozhanggui.app.ui.screens.imp.SaobeiCSVParser
import com.xiaozhanggui.app.ui.screens.imp.SaobeiFingerprint
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * 扫呗导入回归测试（Phase 6 Worker C）。
 *
 * 覆盖：CSV 解析 → Performance 记录映射；相同 fingerprint 二次导入去重；
 * 文件内重复 fingerprint 只计 duplicates；失败状态行跳过不计入；
 * fingerprint 确定性。
 */
class SaobeiImportTest {

    private class FakePerformanceDao : PerformanceDao {
        private val store = MutableStateFlow<List<PerformanceEntity>>(emptyList())
        override suspend fun insert(entity: PerformanceEntity) {
            store.value = store.value + entity
        }

        override suspend fun update(entity: PerformanceEntity) {
            store.value = store.value.map { if (it.id == entity.id) entity else it }
        }

        override suspend fun delete(entity: PerformanceEntity) {
            store.value = store.value.filterNot { it.id == entity.id }
        }

        override fun getById(id: String): Flow<PerformanceEntity?> =
            store.map { list -> list.firstOrNull { it.id == id } }

        override fun listAll(): Flow<List<PerformanceEntity>> = store

        override suspend fun allFingerprints(): List<String> =
            store.value.map { it.fingerprint }.filter { it.isNotEmpty() }

        fun all(): List<PerformanceEntity> = store.value
    }

    private lateinit var dao: FakePerformanceDao
    private lateinit var repo: PerformanceRepository

    @Before
    fun setUp() {
        dao = FakePerformanceDao()
        repo = PerformanceRepository(dao)
    }

    private val sampleCsv = """
        交易时间,收款金额,交易状态,订单号,支付方式
        2026-10-01 10:00:00,100.50,支付成功,ORDER001,微信支付
        2026-10-01 11:00:00,200.00,成功,ORDER002,支付宝
        2026-10-01 12:00:00,50.00,已退款,ORDER003,微信支付
    """.trimIndent()

    @Test
    fun `csv parses into performance records`() = runTest {
        val result = SaobeiCSVParser.parseText(sampleCsv, "saobei.csv")
        // 退款行不计入 rows，进入 skipped
        assertEquals(2, result.rows.size)
        assertEquals(1, result.skipped.size)
        assertTrue(result.errors.isEmpty())

        val commit = repo.importSaobei(result.rows, result.skipped.size)
        assertEquals(SaobeiImportCommitResult(inserted = 2, duplicates = 0, skippedFailed = 1), commit)

        val all = dao.all()
        assertEquals(2, all.size)
        assertEquals(100.50, all[0].amount, 0.001)
        assertEquals(200.00, all[1].amount, 0.001)
        assertEquals("saobei", all[0].importSource)
        assertTrue(all[0].note.contains("扫呗"))
        assertEquals("ORDER001", all[0].orderNo)
        assertTrue(all[0].fingerprint.isNotBlank())
        assertTrue(all[1].fingerprint.isNotBlank())
        assertNotEquals(all[0].fingerprint, all[1].fingerprint)
    }

    @Test
    fun `reimporting same file does not duplicate`() = runTest {
        val result = SaobeiCSVParser.parseText(sampleCsv, "saobei.csv")
        val first = repo.importSaobei(result.rows, result.skipped.size)
        assertEquals(2, first.inserted)

        val second = repo.importSaobei(result.rows, result.skipped.size)
        assertEquals(0, second.inserted)
        assertEquals(2, second.duplicates)
        assertEquals(2, dao.all().size)
    }

    @Test
    fun `duplicate fingerprints within one import counted once`() = runTest {
        val row = SaobeiParsedRow(
            date = 1_700_000_000_000L,
            amount = 88.0,
            status = "成功",
            orderNo = "DUP001",
            paymentMethod = "微信支付",
            fingerprint = "fp-dup-001",
            isSuccess = true,
            rawLine = "raw"
        )
        val commit = repo.importSaobei(listOf(row, row.copy(amount = 99.0)), skippedFailed = 0)
        assertEquals(1, commit.inserted)
        assertEquals(1, commit.duplicates)
        assertEquals(1, dao.all().size)
        assertEquals(88.0, dao.all()[0].amount, 0.001)
    }

    @Test
    fun `failed status rows are skipped`() {
        val result = SaobeiCSVParser.parseText(sampleCsv, "saobei.csv")
        assertTrue(result.rows.none { it.orderNo == "ORDER003" })
        assertEquals(1, result.skipped.size)
        assertTrue(result.skipped[0].contains("已退款"))
    }

    @Test
    fun `fingerprint is deterministic and order-sensitive`() {
        val a = SaobeiFingerprint.make("ORDER001", 1_700_000_000_000L, 100.5, "微信支付", "raw")
        val b = SaobeiFingerprint.make("ORDER001", 1_700_000_000_000L, 100.5, "微信支付", "raw")
        val c = SaobeiFingerprint.make("ORDER002", 1_700_000_000_000L, 100.5, "微信支付", "raw")
        assertEquals(a, b)
        assertNotEquals(a, c)
    }

    @Test
    fun `pre-existing db fingerprint is treated as duplicate`() = runTest {
        val first = SaobeiCSVParser.parseText(sampleCsv, "saobei.csv")
        repo.importSaobei(first.rows, first.skipped.size)
        assertEquals(2, dao.all().size)

        // 新文件含一条已存在 + 一条新增
        val extra = """
            交易时间,收款金额,交易状态,订单号,支付方式
            2026-10-01 10:00:00,100.50,支付成功,ORDER001,微信支付
            2026-10-02 09:00:00,300.00,成功,ORDER004,微信支付
        """.trimIndent()
        val second = SaobeiCSVParser.parseText(extra, "saobei2.csv")
        val commit = repo.importSaobei(second.rows, second.skipped.size)
        assertEquals(1, commit.inserted)
        assertEquals(1, commit.duplicates)
        assertEquals(3, dao.all().size)
        assertEquals(300.00, dao.all().last().amount, 0.001)
    }
}
