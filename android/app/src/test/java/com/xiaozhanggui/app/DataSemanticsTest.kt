package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.MemoDao
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.domain.DateExt
import com.xiaozhanggui.app.domain.HomeStats
import com.xiaozhanggui.app.domain.PerformancePeriod
import com.xiaozhanggui.app.domain.PerformanceStats2
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * GATE C 数据语义回归测试。
 */
class DataSemanticsTest {

    // ---------- GATE C #1：Performance 统计用业务 date，不用 createdAt ----------

    @Test
    fun `performance stats use business date not createdAt`() {
        val now = System.currentTimeMillis()
        val todayStart = DateExt.startOfDay(now)
        // 一条昨天的记录（即使它是"刚刚创建"的，也不应计入今日）
        val yesterday = PerformanceEntity(
            amount = 1000.0,
            note = "昨天",
            date = todayStart - 3600 * 1000L
        )
        val today = PerformanceEntity(
            amount = 500.0,
            note = "今天",
            date = todayStart + 3600 * 1000L
        )
        val stats = PerformanceStats2.compute(
            PerformancePeriod.TODAY,
            listOf(yesterday, today),
            emptyList(),
            nowMillis = now
        )
        assertEquals(500.0, stats.income, 0.001)
    }

    @Test
    fun `home todayRevenue uses business date`() {
        val now = System.currentTimeMillis()
        val todayStart = DateExt.startOfDay(now)
        val performances = listOf(
            PerformanceEntity(amount = 9999.0, date = todayStart - 24 * 3600 * 1000L), // 昨天
            PerformanceEntity(amount = 100.0, date = todayStart + 1000L) // 今天
        )
        val stats = HomeStats.compute(performances, emptyList(), emptyList(), 120000.0, now)
        assertEquals(100.0, stats.todayRevenue, 0.001)
    }

    // ---------- GATE C #3：Todo 没有 updatedAt，不得新增并改变排序 ----------

    @Test
    fun `todo entity has no updatedAt field`() {
        val fieldNames = TodoEntity::class.java.declaredFields.map { it.name }
        assertFalse(
            "Todo 不得有 updatedAt 字段（GATE C）",
            fieldNames.any { it.equals("updatedAt", ignoreCase = true) }
        )
    }

    // ---------- GATE C #4：Memo title≤100、content≤2000，静默截断 ----------

    /** 内存假 DAO（不依赖 Room） */
    private class FakeMemoDao : MemoDao {
        private val store = MutableStateFlow<List<MemoEntity>>(emptyList())
        override suspend fun insert(entity: MemoEntity) {
            store.value = store.value + entity
        }
        override suspend fun update(entity: MemoEntity) {
            store.value = store.value.map { if (it.id == entity.id) entity else it }
        }
        override suspend fun delete(entity: MemoEntity) {
            store.value = store.value.filter { it.id != entity.id }
        }
        override fun getById(id: String): Flow<MemoEntity?> =
            MutableStateFlow(store.value.find { it.id == id })
        override fun listAll(): Flow<List<MemoEntity>> = store
        fun current(): List<MemoEntity> = store.value
    }

    @Test
    fun `memo add silently truncates title to 100 and content to 2000`() = runTest {
        val dao = FakeMemoDao()
        val repo = MemoRepository(dao)
        val entity = repo.add("t".repeat(150), "c".repeat(2500))
        assertEquals(100, entity.title.length)
        assertEquals(2000, entity.content.length)
        // 静默截断：无异常、无标记
        assertEquals("t".repeat(100), entity.title)
    }

    @Test
    fun `memo update silently truncates and refreshes updatedAt`() = runTest {
        val dao = FakeMemoDao()
        val repo = MemoRepository(dao)
        val created = repo.add("ok", "ok")
        Thread.sleep(5)
        val updated = repo.update(created.copy(title = "x".repeat(120), content = "y".repeat(2100)))
        assertEquals(100, updated.title.length)
        assertEquals(2000, updated.content.length)
        assertTrue(updated.updatedAt >= created.updatedAt)
    }

    @Test
    fun `memo within limits is untouched`() = runTest {
        val dao = FakeMemoDao()
        val repo = MemoRepository(dao)
        val entity = repo.add("标题", "内容")
        assertEquals("标题", entity.title)
        assertEquals("内容", entity.content)
    }
}
