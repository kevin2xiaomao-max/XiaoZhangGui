package com.xiaozhanggui.app.ai

import com.xiaozhanggui.app.data.ai.AgentCore
import com.xiaozhanggui.app.data.ai.BusinessContextReader
import com.xiaozhanggui.app.data.ai.BusinessInsightReader
import com.xiaozhanggui.app.domain.ai.ExecutionJournal
import com.xiaozhanggui.app.data.ai.GoodsLookupSkill
import com.xiaozhanggui.app.domain.ai.InMemoryExecutionJournal
import com.xiaozhanggui.app.data.ai.ProviderChain
import com.xiaozhanggui.app.data.ai.RepositoryToolExecutor
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
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.GoodsRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.ai.InMemoryConversationStore
import com.xiaozhanggui.app.domain.ai.InMemoryPendingActionStore
import com.xiaozhanggui.app.domain.ai.ProposalStatus
import com.xiaozhanggui.app.domain.ai.ToolArguments
import com.xiaozhanggui.app.domain.ai.ToolCall
import com.xiaozhanggui.app.domain.ai.ToolIdempotency
import com.xiaozhanggui.app.domain.ai.ToolExecutionResult
import com.xiaozhanggui.app.domain.ai.ToolName
import com.xiaozhanggui.app.domain.ai.TodoArguments
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 幂等测试：同一 callId / 同一业务指纹重复执行只写库一次。
 * 对应 iOS 红线：AI 绝不允许因重复响应 / 重试 / 崩溃恢复把数据写两次。
 */

// ---------- Fakes ----------

private class FakeTodoDao : TodoDao {
    val inserted = mutableListOf<TodoEntity>()
    private val flow = MutableStateFlow<List<TodoEntity>>(emptyList())
    override suspend fun insert(entity: TodoEntity) {
        inserted.add(entity)
        flow.value = inserted.toList()
    }
    override suspend fun update(entity: TodoEntity) {}
    override suspend fun delete(entity: TodoEntity) {}
    override fun getById(id: String): Flow<TodoEntity?> =
        MutableStateFlow(inserted.firstOrNull { it.id == id })
    override fun listAll(): Flow<List<TodoEntity>> = flow
}

private class FakePerformanceDao : PerformanceDao {
    private val flow = MutableStateFlow<List<PerformanceEntity>>(emptyList())
    override suspend fun insert(entity: PerformanceEntity) {}
    override suspend fun update(entity: PerformanceEntity) {}
    override suspend fun delete(entity: PerformanceEntity) {}
    override fun getById(id: String): Flow<PerformanceEntity?> = MutableStateFlow(null)
    override fun listAll(): Flow<List<PerformanceEntity>> = flow
    override suspend fun allFingerprints(): List<String> = emptyList()
}

private class FakeMemoDao : MemoDao {
    private val flow = MutableStateFlow<List<MemoEntity>>(emptyList())
    override suspend fun insert(entity: MemoEntity) {}
    override suspend fun update(entity: MemoEntity) {}
    override suspend fun delete(entity: MemoEntity) {}
    override fun getById(id: String): Flow<MemoEntity?> = MutableStateFlow(null)
    override fun listAll(): Flow<List<MemoEntity>> = flow
}

private class FakeCustomerRequestDao : CustomerRequestDao {
    private val flow = MutableStateFlow<List<CustomerRequestEntity>>(emptyList())
    override suspend fun insert(entity: CustomerRequestEntity) {}
    override suspend fun update(entity: CustomerRequestEntity) {}
    override suspend fun delete(entity: CustomerRequestEntity) {}
    override fun getById(id: String): Flow<CustomerRequestEntity?> = MutableStateFlow(null)
    override fun listAll(): Flow<List<CustomerRequestEntity>> = flow
}

private class FakeExpiryDao : ExpiryItemDao {
    private val flow = MutableStateFlow<List<ExpiryItemEntity>>(emptyList())
    override suspend fun insert(entity: ExpiryItemEntity) {}
    override suspend fun update(entity: ExpiryItemEntity) {}
    override suspend fun delete(entity: ExpiryItemEntity) {}
    override fun getById(id: String): Flow<ExpiryItemEntity?> = MutableStateFlow(null)
    override fun listAll(): Flow<List<ExpiryItemEntity>> = flow
}

private class FakeGoodsDao : GoodsDao {
    private val flow = MutableStateFlow<List<GoodsEntity>>(emptyList())
    override suspend fun insert(entity: GoodsEntity) {}
    override suspend fun update(entity: GoodsEntity) {}
    override suspend fun delete(entity: GoodsEntity) {}
    override fun getById(id: String): Flow<GoodsEntity?> = MutableStateFlow(null)
    override fun listAll(): Flow<List<GoodsEntity>> = flow
}

private object FakeNotifications : NotificationScheduler {
    override fun scheduleTodo(todo: TodoEntity) {}
    override fun cancelTodo(todo: TodoEntity) {}
    override fun scheduleExpiry(item: ExpiryItemEntity) {}
    override fun cancelExpiry(item: ExpiryItemEntity) {}
    override fun rescheduleCustomer(request: CustomerRequestEntity) {}
    override fun cancelCustomer(request: CustomerRequestEntity) {}
    override fun canScheduleExactAlarms(): Boolean = false
}

// ---------- Tests ----------

class AiIdempotencyTest {

    private fun buildCore(todoDao: FakeTodoDao = FakeTodoDao()): Triple<AgentCore, FakeTodoDao, ExecutionJournal> {
        val journal = InMemoryExecutionJournal()
        val todoRepository = TodoRepository(todoDao, FakeNotifications)
        val executor = RepositoryToolExecutor(
            moneyRepository = PerformanceRepository(FakePerformanceDao()),
            todoRepository = todoRepository,
            memoRepository = MemoRepository(FakeMemoDao()),
            customerRepository = CustomerRepository(FakeCustomerRequestDao(), FakeNotifications),
            journal = journal
        )
        val core = AgentCore(
            providerChain = ProviderChain(primary = null, fallback = null),
            contextReader = BusinessContextReader(
                PerformanceRepository(FakePerformanceDao()),
                todoRepository,
                MemoRepository(FakeMemoDao()),
                CustomerRepository(FakeCustomerRequestDao(), FakeNotifications),
                ExpiryRepository(FakeExpiryDao(), FakeNotifications)
            ),
            insightReader = BusinessInsightReader(
                PerformanceRepository(FakePerformanceDao()),
                todoRepository,
                CustomerRepository(FakeCustomerRequestDao(), FakeNotifications),
                ExpiryRepository(FakeExpiryDao(), FakeNotifications),
                GoodsRepository(FakeGoodsDao())
            ),
            goodsLookupSkill = GoodsLookupSkill(GoodsRepository(FakeGoodsDao())),
            toolExecutor = executor,
            journal = journal,
            conversation = InMemoryConversationStore(),
            pending = InMemoryPendingActionStore()
        )
        return Triple(core, todoDao, journal)
    }

    @Test
    fun `同一 proposal 重复 confirm 只执行一次`() = runTest {
        val (core, todoDao, _) = buildCore()

        val turn = core.send("明天下两箱可乐")
        val proposal = turn.proposal!!
        assertEquals(ProposalStatus.PENDING, proposal.status)

        val first = core.confirm(proposal.id)!!
        assertEquals(ProposalStatus.EXECUTED, first.status)
        assertEquals(1, todoDao.inserted.size)

        // 第二次 confirm：卡已决，直接返回 null，不再执行
        val second = core.confirm(proposal.id)
        assertNull(second)
        assertEquals(1, todoDao.inserted.size)
    }

    private fun buildExecutor(todoDao: FakeTodoDao): Pair<RepositoryToolExecutor, FakeTodoDao> {
        val executor = RepositoryToolExecutor(
            moneyRepository = PerformanceRepository(FakePerformanceDao()),
            todoRepository = TodoRepository(todoDao, FakeNotifications),
            memoRepository = MemoRepository(FakeMemoDao()),
            customerRepository = CustomerRepository(FakeCustomerRequestDao(), FakeNotifications),
            journal = InMemoryExecutionJournal()
        )
        return executor to todoDao
    }

    @Test
    fun `同一 ToolCall 在执行器层重复执行只写一次`() = runTest {
        val todoDao = FakeTodoDao()
        val (executor, _) = buildExecutor(todoDao)

        val call = ToolCall(
            callId = ToolIdempotency.newCallId(),
            name = ToolName.CREATE_TODO,
            argumentsJson = (ToolArguments.Todo(TodoArguments(title = "买菜"))).toToolCall().argumentsJson
        )

        val first = executor.execute(call)
        val second = executor.execute(call)

        assertEquals(1, todoDao.inserted.size)
        // 第二次命中 toolCallID 幂等 → DUPLICATE
        assertTrue(second is ToolExecutionResult.Duplicate)
        assertTrue(first is ToolExecutionResult.Executed)
    }

    @Test
    fun `不同 callId 但同业务指纹也只写一次`() = runTest {
        val todoDao = FakeTodoDao()
        val (executor, _) = buildExecutor(todoDao)
        val args = ToolArguments.Todo(TodoArguments(title = "买菜"))
        val json = args.toToolCall().argumentsJson

        executor.execute(ToolCall(ToolIdempotency.newCallId(), ToolName.CREATE_TODO, json))
        val second = executor.execute(ToolCall(ToolIdempotency.newCallId(), ToolName.CREATE_TODO, json))

        assertEquals(1, todoDao.inserted.size)
        assertTrue(second is ToolExecutionResult.Duplicate)
    }
}
