package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.CustomerRequestDao
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpiryItemDao
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.GoodsDao
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.db.MemoDao
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceDao
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoDao
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map

/**
 * Phase 6 UI 测试共用假实现：内存 DAO + 空通知调度器。
 *
 * - 不碰真数据库、不碰 AlarmManager（Alarm 相关在测试里不验证，只要求不崩溃）；
 * - 每个测试方法各自 new 一份实例，保证测试独立可重复；
 * - 方法签名与真实 DAO 对齐（以 `src/test` 的 AiIdempotencyTest 假实现为基准，
 *   补齐 update/delete 的内存语义，供 UI 全流程测试用）。
 */

class FakeTodoDao : TodoDao {
    private val lock = Any()
    private val items = mutableListOf<TodoEntity>()
    private val flow = MutableStateFlow<List<TodoEntity>>(emptyList())

    /** 当前内存快照（测试断言用）。 */
    val current: List<TodoEntity> get() = synchronized(lock) { items.toList() }

    private fun emit() {
        flow.value = synchronized(lock) { items.toList() }
    }

    override suspend fun insert(entity: TodoEntity) {
        synchronized(lock) {
            items.removeAll { it.id == entity.id }
            items.add(entity)
        }
        emit()
    }

    override suspend fun update(entity: TodoEntity) {
        synchronized(lock) {
            val i = items.indexOfFirst { it.id == entity.id }
            if (i >= 0) items[i] = entity else items.add(entity)
        }
        emit()
    }

    override suspend fun delete(entity: TodoEntity) {
        synchronized(lock) { items.removeAll { it.id == entity.id } }
        emit()
    }

    override fun getById(id: String): Flow<TodoEntity?> =
        flow.map { list -> list.firstOrNull { it.id == id } }

    override fun listAll(): Flow<List<TodoEntity>> = flow
}

class FakeMemoDao : MemoDao {
    private val lock = Any()
    private val items = mutableListOf<MemoEntity>()
    private val flow = MutableStateFlow<List<MemoEntity>>(emptyList())

    private fun emit() {
        flow.value = synchronized(lock) { items.toList() }
    }

    override suspend fun insert(entity: MemoEntity) {
        synchronized(lock) {
            items.removeAll { it.id == entity.id }
            items.add(entity)
        }
        emit()
    }

    override suspend fun update(entity: MemoEntity) {
        synchronized(lock) {
            val i = items.indexOfFirst { it.id == entity.id }
            if (i >= 0) items[i] = entity else items.add(entity)
        }
        emit()
    }

    override suspend fun delete(entity: MemoEntity) {
        synchronized(lock) { items.removeAll { it.id == entity.id } }
        emit()
    }

    override fun getById(id: String): Flow<MemoEntity?> =
        flow.map { list -> list.firstOrNull { it.id == id } }

    override fun listAll(): Flow<List<MemoEntity>> = flow
}

class FakePerformanceDao : PerformanceDao {
    private val flow = MutableStateFlow<List<PerformanceEntity>>(emptyList())
    override suspend fun insert(entity: PerformanceEntity) {}
    override suspend fun update(entity: PerformanceEntity) {}
    override suspend fun delete(entity: PerformanceEntity) {}
    override fun getById(id: String): Flow<PerformanceEntity?> = MutableStateFlow(null)
    override fun listAll(): Flow<List<PerformanceEntity>> = flow
    override suspend fun allFingerprints(): List<String> = emptyList()
}

class FakeCustomerRequestDao : CustomerRequestDao {
    private val lock = Any()
    private val items = mutableListOf<CustomerRequestEntity>()
    private val flow = MutableStateFlow<List<CustomerRequestEntity>>(emptyList())

    val current: List<CustomerRequestEntity> get() = synchronized(lock) { items.toList() }

    private fun emit() {
        flow.value = synchronized(lock) { items.toList() }
    }

    override suspend fun insert(entity: CustomerRequestEntity) {
        synchronized(lock) {
            items.removeAll { it.id == entity.id }
            items.add(entity)
        }
        emit()
    }

    override suspend fun update(entity: CustomerRequestEntity) {
        synchronized(lock) {
            val i = items.indexOfFirst { it.id == entity.id }
            if (i >= 0) items[i] = entity else items.add(entity)
        }
        emit()
    }

    override suspend fun delete(entity: CustomerRequestEntity) {
        synchronized(lock) { items.removeAll { it.id == entity.id } }
        emit()
    }

    override fun getById(id: String): Flow<CustomerRequestEntity?> =
        flow.map { list -> list.firstOrNull { it.id == id } }

    override fun listAll(): Flow<List<CustomerRequestEntity>> = flow
}

class FakeExpiryItemDao : ExpiryItemDao {
    private val lock = Any()
    private val items = mutableListOf<ExpiryItemEntity>()
    private val flow = MutableStateFlow<List<ExpiryItemEntity>>(emptyList())

    val current: List<ExpiryItemEntity> get() = synchronized(lock) { items.toList() }

    private fun emit() {
        flow.value = synchronized(lock) { items.toList() }
    }

    override suspend fun insert(entity: ExpiryItemEntity) {
        synchronized(lock) {
            items.removeAll { it.id == entity.id }
            items.add(entity)
        }
        emit()
    }

    override suspend fun update(entity: ExpiryItemEntity) {
        synchronized(lock) {
            val i = items.indexOfFirst { it.id == entity.id }
            if (i >= 0) items[i] = entity else items.add(entity)
        }
        emit()
    }

    override suspend fun delete(entity: ExpiryItemEntity) {
        synchronized(lock) { items.removeAll { it.id == entity.id } }
        emit()
    }

    override fun getById(id: String): Flow<ExpiryItemEntity?> =
        flow.map { list -> list.firstOrNull { it.id == id } }

    override fun listAll(): Flow<List<ExpiryItemEntity>> = flow
}

class FakeGoodsDao : GoodsDao {
    private val flow = MutableStateFlow<List<GoodsEntity>>(emptyList())
    override suspend fun insert(entity: GoodsEntity) {}
    override suspend fun update(entity: GoodsEntity) {}
    override suspend fun delete(entity: GoodsEntity) {}
    override fun getById(id: String): Flow<GoodsEntity?> = MutableStateFlow(null)
    override fun listAll(): Flow<List<GoodsEntity>> = flow
}

/** 空通知调度器：UI 测试不验证 AlarmManager，只要求流程不崩溃。 */
object FakeNotifications : NotificationScheduler {
    override fun scheduleTodo(todo: TodoEntity) {}
    override fun cancelTodo(todo: TodoEntity) {}
    override fun scheduleExpiry(item: ExpiryItemEntity) {}
    override fun cancelExpiry(item: ExpiryItemEntity) {}
    override fun rescheduleCustomer(request: CustomerRequestEntity) {}
    override fun cancelCustomer(request: CustomerRequestEntity) {}
    override fun canScheduleExactAlarms(): Boolean = false
}
