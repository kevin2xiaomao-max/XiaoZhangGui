package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.CustomerRequestDao
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpiryItemDao
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoDao
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

/**
 * 通知副作用回归测试（Phase 6 Worker C）。
 *
 * Repository 写操作 → NotificationScheduler 的调用契约：
 * - Todo：add → scheduleTodo；update → cancelTodo + scheduleTodo；toggleComplete(完成) → cancelTodo；
 *   toggleComplete(取消完成) → scheduleTodo；delete → cancelTodo
 * - Expiry：add/update → scheduleExpiry（update 先 cancel）；delete → cancelExpiry
 * - Customer：add/update → rescheduleCustomer；advanceStatus 离开 pending → cancelCustomer；
 *   delete → cancelCustomer
 *
 * 用内存假 DAO + 记录调用的假 Scheduler，纯 JVM 可跑。
 */
class NotificationSideEffectsTest {

    /** 记录调用的假 NotificationScheduler */
    private class RecordingScheduler : NotificationScheduler {
        data class Call(val name: String, val notificationId: String)
        val calls = mutableListOf<Call>()

        override fun scheduleTodo(todo: TodoEntity) {
            calls.add(Call("scheduleTodo", todo.notificationId))
        }

        override fun cancelTodo(todo: TodoEntity) {
            calls.add(Call("cancelTodo", todo.notificationId))
        }

        override fun scheduleExpiry(item: ExpiryItemEntity) {
            calls.add(Call("scheduleExpiry", item.notificationId))
        }

        override fun cancelExpiry(item: ExpiryItemEntity) {
            calls.add(Call("cancelExpiry", item.notificationId))
        }

        override fun rescheduleCustomer(request: CustomerRequestEntity) {
            calls.add(Call("rescheduleCustomer", request.notificationId))
        }

        override fun cancelCustomer(request: CustomerRequestEntity) {
            calls.add(Call("cancelCustomer", request.notificationId))
        }

        override fun canScheduleExactAlarms(): Boolean = true

        fun namesFor(notificationId: String): List<String> =
            calls.filter { it.notificationId == notificationId }.map { it.name }
    }

    private class FakeTodoDao : TodoDao {
        private val store = MutableStateFlow<List<TodoEntity>>(emptyList())
        override suspend fun insert(entity: TodoEntity) {
            store.value = store.value + entity
        }

        override suspend fun update(entity: TodoEntity) {
            store.value = store.value.map { if (it.id == entity.id) entity else it }
        }

        override suspend fun delete(entity: TodoEntity) {
            store.value = store.value.filterNot { it.id == entity.id }
        }

        override fun getById(id: String): Flow<TodoEntity?> =
            store.map { list -> list.firstOrNull { it.id == id } }

        override fun listAll(): Flow<List<TodoEntity>> = store
    }

    private class FakeExpiryDao : ExpiryItemDao {
        private val store = MutableStateFlow<List<ExpiryItemEntity>>(emptyList())
        override suspend fun insert(entity: ExpiryItemEntity) {
            store.value = store.value + entity
        }

        override suspend fun update(entity: ExpiryItemEntity) {
            store.value = store.value.map { if (it.id == entity.id) entity else it }
        }

        override suspend fun delete(entity: ExpiryItemEntity) {
            store.value = store.value.filterNot { it.id == entity.id }
        }

        override fun getById(id: String): Flow<ExpiryItemEntity?> =
            store.map { list -> list.firstOrNull { it.id == id } }

        override fun listAll(): Flow<List<ExpiryItemEntity>> = store
    }

    private class FakeCustomerDao : CustomerRequestDao {
        private val store = MutableStateFlow<List<CustomerRequestEntity>>(emptyList())
        override suspend fun insert(entity: CustomerRequestEntity) {
            store.value = store.value + entity
        }

        override suspend fun update(entity: CustomerRequestEntity) {
            store.value = store.value.map { if (it.id == entity.id) entity else it }
        }

        override suspend fun delete(entity: CustomerRequestEntity) {
            store.value = store.value.filterNot { it.id == entity.id }
        }

        override fun getById(id: String): Flow<CustomerRequestEntity?> =
            store.map { list -> list.firstOrNull { it.id == id } }

        override fun listAll(): Flow<List<CustomerRequestEntity>> = store
    }

    private lateinit var scheduler: RecordingScheduler
    private lateinit var todoRepo: TodoRepository
    private lateinit var expiryRepo: ExpiryRepository
    private lateinit var customerRepo: CustomerRepository

    @Before
    fun setUp() {
        scheduler = RecordingScheduler()
        todoRepo = TodoRepository(FakeTodoDao(), scheduler)
        expiryRepo = ExpiryRepository(FakeExpiryDao(), scheduler)
        customerRepo = CustomerRepository(FakeCustomerDao(), scheduler)
    }

    // ---------- Todo ----------

    @Test
    fun `add todo with future due date schedules notification`() = runTest {
        val todo = todoRepo.add(
            title = "买牛奶",
            dueDate = System.currentTimeMillis() + 3600 * 1000L
        )
        assertEquals(listOf("scheduleTodo"), scheduler.namesFor(todo.notificationId))
    }

    @Test
    fun `delete todo cancels notification`() = runTest {
        val todo = todoRepo.add(title = "买牛奶")
        scheduler.calls.clear()
        todoRepo.delete(todo)
        assertEquals(listOf("cancelTodo"), scheduler.namesFor(todo.notificationId))
    }

    @Test
    fun `completing todo cancels notification`() = runTest {
        val todo = todoRepo.add(
            title = "买牛奶",
            dueDate = System.currentTimeMillis() + 3600 * 1000L
        )
        scheduler.calls.clear()
        todoRepo.toggleComplete(todo)
        assertEquals(listOf("cancelTodo"), scheduler.namesFor(todo.notificationId))
    }

    @Test
    fun `uncompleting todo reschedules notification`() = runTest {
        val todo = todoRepo.add(title = "买牛奶")
        val done = todoRepo.toggleComplete(todo)
        scheduler.calls.clear()
        todoRepo.toggleComplete(done)
        assertEquals(listOf("scheduleTodo"), scheduler.namesFor(todo.notificationId))
    }

    @Test
    fun `update todo cancels then reschedules`() = runTest {
        val todo = todoRepo.add(title = "买牛奶")
        scheduler.calls.clear()
        todoRepo.update(todo.copy(title = "买牛奶和面包"))
        assertEquals(
            listOf("cancelTodo", "scheduleTodo"),
            scheduler.namesFor(todo.notificationId)
        )
    }

    // ---------- Expiry ----------

    @Test
    fun `add expiry item schedules notification`() = runTest {
        val item = expiryRepo.add(
            name = "鲜奶",
            expiryDate = System.currentTimeMillis() + 10L * 24 * 3600 * 1000,
            remindDaysBefore = 7
        )
        assertEquals(ReturnStatus.PENDING, item.returnStatus)
        assertEquals(listOf("scheduleExpiry"), scheduler.namesFor(item.notificationId))
    }

    @Test
    fun `delete expiry item cancels notification`() = runTest {
        val item = expiryRepo.add(name = "鲜奶")
        scheduler.calls.clear()
        expiryRepo.delete(item)
        assertEquals(listOf("cancelExpiry"), scheduler.namesFor(item.notificationId))
    }

    @Test
    fun `update expiry item cancels then reschedules`() = runTest {
        val item = expiryRepo.add(name = "鲜奶")
        scheduler.calls.clear()
        expiryRepo.update(item.copy(quantity = 3))
        assertEquals(
            listOf("cancelExpiry", "scheduleExpiry"),
            scheduler.namesFor(item.notificationId)
        )
    }

    // ---------- Customer ----------

    @Test
    fun `add customer request reschedules followup`() = runTest {
        val req = customerRepo.add(customer = "张三", content = "送两箱水")
        assertEquals(CustomerStatus.PENDING, req.status)
        assertEquals(listOf("rescheduleCustomer"), scheduler.namesFor(req.notificationId))
    }

    @Test
    fun `advanceStatus leaving pending cancels customer notifications`() = runTest {
        val req = customerRepo.add(customer = "张三", content = "送两箱水")
        scheduler.calls.clear()
        val advanced = customerRepo.advanceStatus(req)
        assertEquals(CustomerStatus.DELIVERING, advanced.status)
        assertEquals(listOf("cancelCustomer"), scheduler.namesFor(req.notificationId))
    }

    @Test
    fun `delete customer request cancels notifications`() = runTest {
        val req = customerRepo.add(customer = "张三", content = "送两箱水")
        scheduler.calls.clear()
        customerRepo.delete(req)
        assertEquals(listOf("cancelCustomer"), scheduler.namesFor(req.notificationId))
    }
}
