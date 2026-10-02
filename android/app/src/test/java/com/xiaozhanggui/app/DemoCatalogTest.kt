package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.CustomerRequestDao
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpiryItemDao
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.MemoDao
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceDao
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoDao
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.demo.DemoCatalog
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.util.Calendar

/**
 * DemoCatalog 种子回归测试。对应 iOS `Tests/DemoCatalogTests.swift`
 *（testDemoContainerIsMemoryOnlyAndHasRichData 的计数与今日/昨日营业额断言）。
 *
 * 用 fake DAO（内存 List）验证种子内容，不依赖 Room/Android 运行时；
 * 真实内存库隔离由 XzgGraph.switchDatabase 保证（需 Android 运行时，见 E2E/手动验证）。
 */
class DemoCatalogTest {

    private open class FakeDao<E : Any>(private val idOf: (E) -> String) {
        val items = mutableListOf<E>()
        suspend fun insert(e: E) {
            items.removeAll { idOf(it) == idOf(e) }
            items.add(e)
        }

        fun flow(): Flow<List<E>> = MutableStateFlow(items.toList())
        fun byId(id: String): Flow<E?> = MutableStateFlow(items.toList()).map { l -> l.find { idOf(it) == id } }
    }

    private class FakeTodoDao : FakeDao<TodoEntity>({ it.id }), TodoDao {
        override suspend fun insert(entity: TodoEntity) = super.insert(entity)
        override suspend fun update(entity: TodoEntity) = super.insert(entity)
        override suspend fun delete(entity: TodoEntity) {
            items.removeAll { it.id == entity.id }
        }

        override fun getById(id: String): Flow<TodoEntity?> = byId(id)
        override fun listAll(): Flow<List<TodoEntity>> = flow()
    }

    private class FakeExpiryDao : FakeDao<ExpiryItemEntity>({ it.id }), ExpiryItemDao {
        override suspend fun insert(entity: ExpiryItemEntity) = super.insert(entity)
        override suspend fun update(entity: ExpiryItemEntity) = super.insert(entity)
        override suspend fun delete(entity: ExpiryItemEntity) {
            items.removeAll { it.id == entity.id }
        }

        override fun getById(id: String): Flow<ExpiryItemEntity?> = byId(id)
        override fun listAll(): Flow<List<ExpiryItemEntity>> = flow()
    }

    private class FakeCustomerDao : FakeDao<CustomerRequestEntity>({ it.id }), CustomerRequestDao {
        override suspend fun insert(entity: CustomerRequestEntity) = super.insert(entity)
        override suspend fun update(entity: CustomerRequestEntity) = super.insert(entity)
        override suspend fun delete(entity: CustomerRequestEntity) {
            items.removeAll { it.id == entity.id }
        }

        override fun getById(id: String): Flow<CustomerRequestEntity?> = byId(id)
        override fun listAll(): Flow<List<CustomerRequestEntity>> = flow()
    }

    private class FakeMemoDao : FakeDao<MemoEntity>({ it.id }), MemoDao {
        override suspend fun insert(entity: MemoEntity) = super.insert(entity)
        override suspend fun update(entity: MemoEntity) = super.insert(entity)
        override suspend fun delete(entity: MemoEntity) {
            items.removeAll { it.id == entity.id }
        }

        override fun getById(id: String): Flow<MemoEntity?> = byId(id)
        override fun listAll(): Flow<List<MemoEntity>> = flow()
    }

    private class FakePerformanceDao : FakeDao<PerformanceEntity>({ it.id }), PerformanceDao {
        override suspend fun insert(entity: PerformanceEntity) = super.insert(entity)
        override suspend fun update(entity: PerformanceEntity) = super.insert(entity)
        override suspend fun delete(entity: PerformanceEntity) {
            items.removeAll { it.id == entity.id }
        }

        override fun getById(id: String): Flow<PerformanceEntity?> = byId(id)
        override fun listAll(): Flow<List<PerformanceEntity>> = flow()
        override suspend fun allFingerprints(): List<String> =
            items.map { it.fingerprint }.filter { it.isNotEmpty() }
    }

    /** 固定 now：2026-09-14 20:00（与 iOS DemoCatalogTests 一致），避免跨天 flake。 */
    private fun fixedNow(): Long {
        val cal = Calendar.getInstance()
        cal.set(2026, Calendar.SEPTEMBER, 14, 20, 0, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private fun startOfDay(millis: Long): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = millis
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    private data class Seeded(
        val todos: FakeTodoDao,
        val expiry: FakeExpiryDao,
        val customers: FakeCustomerDao,
        val memos: FakeMemoDao,
        val performances: FakePerformanceDao,
        val now: Long
    )

    private suspend fun seedAll(): Seeded {
        val now = fixedNow()
        val daos = DemoCatalog.SeedDaos(
            todo = FakeTodoDao(),
            expiry = FakeExpiryDao(),
            customer = FakeCustomerDao(),
            memo = FakeMemoDao(),
            performance = FakePerformanceDao()
        )
        DemoCatalog.seed(daos, now)
        return Seeded(
            daos.todo as FakeTodoDao,
            daos.expiry as FakeExpiryDao,
            daos.customer as FakeCustomerDao,
            daos.memo as FakeMemoDao,
            daos.performance as FakePerformanceDao,
            now
        )
    }

    @Test
    fun `seed has rich demo data in all five categories`() = runTest {
        val s = seedAll()
        // 对应 iOS 断言：performances≥20 / todos≥15 / customers≥8 / expiry≥7 / memos≥8
        assertTrue("performances=${s.performances.items.size}", s.performances.items.size >= 20)
        assertTrue("todos=${s.todos.items.size}", s.todos.items.size >= 15)
        assertTrue("customers=${s.customers.items.size}", s.customers.items.size >= 8)
        assertTrue("expiry=${s.expiry.items.size}", s.expiry.items.size >= 7)
        assertTrue("memos=${s.memos.items.size}", s.memos.items.size >= 8)
    }

    @Test
    fun `today and yesterday revenue match iOS demo catalog`() = runTest {
        val s = seedAll()
        val todayStart = startOfDay(s.now)
        val todayRevenue = s.performances.items
            .filter { it.date in todayStart until todayStart + 24 * 3600 * 1000L }
            .sumOf { it.amount }
        assertEquals(2680.50, todayRevenue, 0.01)

        val yesterdayStart = todayStart - 24 * 3600 * 1000L
        val yesterdayRevenue = s.performances.items
            .filter { it.date in yesterdayStart until yesterdayStart + 24 * 3600 * 1000L }
            .sumOf { it.amount }
        assertEquals(2381.20, yesterdayRevenue, 0.01)
    }

    @Test
    fun `seeded customers hide encoded delivery string`() = runTest {
        val s = seedAll()
        for (c in s.customers.items) {
            assertTrue(
                "customer 字段应为 xzg-delivery-v1 编码串：${c.customer.take(20)}",
                CustomerDeliveryStorage.isEncoded(c.customer)
            )
            val info = CustomerDeliveryStorage.decode(c.customer)
            assertTrue("legacyCustomer 不应为空", info.legacyCustomer.isNotBlank())
            assertTrue("deliveryTime 应有值", (info.deliveryTime ?: 0L) > 0L)
        }
        // 9 条里应同时覆盖三种状态
        val statuses = s.customers.items.map { it.status }.toSet()
        assertTrue(statuses.contains("待处理"))
        assertTrue(statuses.contains("配送中"))
        assertTrue(statuses.contains("已完成"))
    }

    @Test
    fun `seeded todos cover done and pending with priorities`() = runTest {
        val s = seedAll()
        assertEquals(21, s.todos.items.size)
        assertTrue(s.todos.items.any { it.isCompleted })
        assertTrue(s.todos.items.any { !it.isCompleted })
        val priorities = s.todos.items.map { it.priority }.toSet()
        assertEquals(setOf(0, 1, 2), priorities)
        // 已完成项应有 completedAt
        assertTrue(s.todos.items.filter { it.isCompleted }.all { it.completedAt != null })
    }

    @Test
    fun `repeat seed appends fresh rows - reset path rebuilds the in-memory db instead`() = runTest {
        // 生产重置走"重建内存库"（XzgGraph.resetDemoData），不会在同一库上 seed 两次；
        // 此处仅记录 seed 的行为：每次调用写入全新 id 的行（REPLACE 语义按 id 去重）。
        val now = fixedNow()
        val dao = FakePerformanceDao()
        val daos = DemoCatalog.SeedDaos(
            todo = FakeTodoDao(),
            expiry = FakeExpiryDao(),
            customer = FakeCustomerDao(),
            memo = FakeMemoDao(),
            performance = dao
        )
        DemoCatalog.seed(daos, now)
        val first = dao.items.size
        DemoCatalog.seed(daos, now)
        assertEquals(first * 2, dao.items.size)
    }
}
