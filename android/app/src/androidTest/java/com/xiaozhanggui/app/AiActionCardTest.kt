package com.xiaozhanggui.app

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.ai.AgentCore
import com.xiaozhanggui.app.data.ai.BusinessContextReader
import com.xiaozhanggui.app.data.ai.BusinessInsightReader
import com.xiaozhanggui.app.data.ai.GoodsLookupSkill
import com.xiaozhanggui.app.data.ai.ProviderChain
import com.xiaozhanggui.app.data.ai.RepositoryToolExecutor
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.GoodsRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.domain.ai.ActionProposal
import com.xiaozhanggui.app.domain.ai.InMemoryConversationStore
import com.xiaozhanggui.app.domain.ai.InMemoryExecutionJournal
import com.xiaozhanggui.app.domain.ai.InMemoryPendingActionStore
import com.xiaozhanggui.app.ui.screens.ai.ActionCardView
import com.xiaozhanggui.app.ui.theme.XzgTheme
import kotlinx.coroutines.launch
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * AI ActionCard 测试（Phase 6 Worker A）：
 * 固定意图输入 → 出现 PendingAction 卡片 → 点确认 → 假 Repository 收到写入。
 *
 * - AgentCore 用与 `src/test` 的 AiIdempotencyTest 相同的假装配
 *   （ProviderChain 为空 → 本地 CREATE 走 0-Token，不碰网络）；
 * - UI 侧渲染真实 [ActionCardView]，确认链走真实 `core.confirm`。
 */
@RunWith(AndroidJUnit4::class)
class AiActionCardTest {

    @get:Rule
    val rule = createComposeRule()

    private lateinit var todoDao: FakeTodoDao
    private lateinit var core: AgentCore

    @Before
    fun setup() {
        todoDao = FakeTodoDao()
        val journal = InMemoryExecutionJournal()
        val todoRepository = TodoRepository(todoDao, FakeNotifications)
        val memoRepository = MemoRepository(FakeMemoDao())
        val customerRepository = CustomerRepository(FakeCustomerRequestDao(), FakeNotifications)
        val executor = RepositoryToolExecutor(
            moneyRepository = PerformanceRepository(FakePerformanceDao()),
            todoRepository = todoRepository,
            memoRepository = memoRepository,
            customerRepository = customerRepository,
            journal = journal
        )
        core = AgentCore(
            providerChain = ProviderChain(primary = null, fallback = null),
            contextReader = BusinessContextReader(
                PerformanceRepository(FakePerformanceDao()),
                todoRepository,
                memoRepository,
                customerRepository,
                ExpiryRepository(FakeExpiryItemDao(), FakeNotifications)
            ),
            insightReader = BusinessInsightReader(
                PerformanceRepository(FakePerformanceDao()),
                todoRepository,
                customerRepository,
                ExpiryRepository(FakeExpiryItemDao(), FakeNotifications),
                GoodsRepository(FakeGoodsDao())
            ),
            goodsLookupSkill = GoodsLookupSkill(GoodsRepository(FakeGoodsDao())),
            toolExecutor = executor,
            journal = journal,
            conversation = InMemoryConversationStore(),
            pending = InMemoryPendingActionStore()
        )
    }

    /** 测试 Harness：固定意图输入 → 渲染待确认卡片 → 确认走真实 AgentCore.confirm。 */
    @Composable
    private fun ActionCardHarness(agentCore: AgentCore) {
        val proposals = remember { mutableStateListOf<ActionProposal>() }
        val scope = rememberCoroutineScope()
        LaunchedEffect(Unit) {
            val turn = agentCore.send("明天下两箱可乐")
            turn.proposal?.let { proposals.add(it) }
        }
        proposals.forEach { proposal ->
            ActionCardView(
                proposal = proposal,
                onConfirm = {
                    scope.launch {
                        val done = agentCore.confirm(proposal.id)
                        if (done != null) {
                            val index = proposals.indexOfFirst { it.id == proposal.id }
                            if (index >= 0) proposals[index] = done
                        }
                    }
                },
                onRetry = {},
                onModify = {},
                onCancel = {}
            )
        }
    }

    @Test
    fun aiActionCard_confirmWritesToFakeRepository() {
        rule.setContent {
            XzgTheme { ActionCardHarness(core) }
        }

        // 固定意图输入 → 待确认卡片出现
        rule.waitUntil(timeoutMillis = 10_000) {
            rule.onAllNodesWithText("待你确认").fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithTag("ai.actionCard").assertExists()
        rule.onNodeWithText("新建待办").assertExists()
        rule.onNodeWithText("确认记录").assertExists()
        assertTrue(todoDao.current.isEmpty())

        // 点确认 → 假 Repository 收到写入
        rule.onNodeWithText("确认记录").performClick()
        rule.waitUntil(timeoutMillis = 10_000) { todoDao.current.size == 1 }
        val written: TodoEntity = todoDao.current.first()
        assertTrue("AI 写入的待办标题应包含可乐，实际=${written.title}", written.title.contains("可乐"))

        // 卡片变为已保存态
        rule.waitUntil(timeoutMillis = 5_000) {
            rule.onAllNodesWithText("已保存").fetchSemanticsNodes().isNotEmpty()
        }
        rule.onNodeWithText("已记录").assertExists()
        assertEquals(1, todoDao.current.size)
    }
}
