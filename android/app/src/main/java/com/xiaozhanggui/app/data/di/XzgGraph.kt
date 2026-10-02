package com.xiaozhanggui.app.data.di

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.room.Room
import com.xiaozhanggui.app.XzgApplication
import com.xiaozhanggui.app.data.backup.BackupService
import com.xiaozhanggui.app.data.datastore.XzgSettings
import com.xiaozhanggui.app.data.db.XzgDatabase
import com.xiaozhanggui.app.data.demo.DemoCatalog
import com.xiaozhanggui.app.data.notification.AlarmNotificationScheduler
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import com.xiaozhanggui.app.data.repository.NoopRefresher
import com.xiaozhanggui.app.data.repository.TodoRepository
import com.xiaozhanggui.app.data.repository.MemoRepository
import com.xiaozhanggui.app.data.repository.PerformanceRepository
import com.xiaozhanggui.app.data.repository.ExpenseRepository
import com.xiaozhanggui.app.data.repository.ExpiryRepository
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.data.repository.GoodsRepository
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext

/**
 * 单例装配图。对应 iOS `App/XiaoZhangGuiApp.swift` 的环境装配职责
 *（ModelContainer + 各 Store / Service 的持有与注入）。
 *
 * - 全部依赖 lazy 初始化，`XzgApplication.onCreate()` 调用 [init] 后可用。
 * - database：`Room.databaseBuilder(...).build()`，失败直接抛异常，
 *   绝不静默回退内存库（P0-2 红线）。
 * - 演示模式：DataStore `xzg_demo_mode_enabled` 为 true 时，数据库相关依赖
 *   整体走**内存 Room + DemoCatalog 种子**（对应 iOS DemoMode）；关闭后回到
 *   磁盘真实库 `xzg.db`。内存库与磁盘库物理隔离，关闭演示模式不触碰用户真实数据。
 *   切换经 [switchDatabase] 重建 Graph，调用方随后重启 MainActivity 重建 UI 树
 *  （对应 iOS DemoMode 切换时 sessionID 刷新）。
 * - notificationScheduler 的 settingsImpl 从 XzgSettings 的 Flow 取当前值
 *  （runBlocking + first()，简单可靠）。
 * - refresher 快照钩子 Phase 3 暂用 NoopRefresher，Phase 5 接 AppWidget/快照时替换。
 */
object XzgGraph {

    private const val DB_NAME = "xzg.db"

    private lateinit var appRef: XzgApplication

    /** Application 启动时调用，保存 application 引用。 */
    fun init(app: XzgApplication) {
        appRef = app
    }

    private val app: XzgApplication
        get() = appRef

    val settings: XzgSettings by lazy { XzgSettings(app) }

    val notificationScheduler: NotificationScheduler by lazy {
        val s = settings
        val settingsImpl = object : AlarmNotificationScheduler.NotificationSettings {
            override fun todoReminderEnabled(): Boolean =
                runBlocking { s.todoReminderEnabled.first() }

            override fun expiryReminderEnabled(): Boolean =
                runBlocking { s.expiryReminderEnabled.first() }
        }
        AlarmNotificationScheduler(app, settingsImpl)
    }

    /**
     * 数据库相关依赖的持有者。演示模式切换时整体丢弃重建，
     * 保证 Repository 永远持有当前模式下的 DAO（不出现新旧库混用）。
     */
    private class Graph(
        val database: XzgDatabase,
        app: XzgApplication,
        notificationScheduler: NotificationScheduler
    ) {
        val todoRepository = TodoRepository(database.todoDao(), notificationScheduler)
        val memoRepository = MemoRepository(database.memoDao())
        val performanceRepository = PerformanceRepository(database.performanceDao())
        val expenseRepository = ExpenseRepository(database.expenseDao())
        val expiryRepository = ExpiryRepository(database.expiryItemDao(), notificationScheduler)
        val customerRepository = CustomerRepository(database.customerRequestDao(), notificationScheduler)
        val goodsRepository = GoodsRepository(database.goodsDao())
        val backupService = BackupService(app, database, notificationScheduler, NoopRefresher)

        fun close() {
            database.close()
        }
    }

    @Volatile
    private var graph: Graph? = null

    private fun isDemoEnabled(): Boolean =
        runBlocking { settings.demoModeEnabled.first() }

    /**
     * 按模式建库。演示开 → 内存 Room + DemoCatalog 种子（同步写入，调用方保证不在主线程，
     * 见 [switchDatabase]；[current] 的 runBlocking 路径仅发生在内存库场景，约数十毫秒）；
     * 演示关 → 磁盘真实库，失败直接抛异常，绝不静默回退内存库（P0-2 红线）。
     */
    private suspend fun createGraph(demoEnabled: Boolean): Graph {
        val db = if (demoEnabled) {
            Room.inMemoryDatabaseBuilder(app, XzgDatabase::class.java)
                .build()
                .also { DemoCatalog.seed(it) }
        } else {
            Room.databaseBuilder(app, XzgDatabase::class.java, DB_NAME).build()
        }
        return Graph(db, app, notificationScheduler)
    }

    /**
     * 当前 Graph。首次访问时按 DataStore 演示开关创建；
     * 演示模式切换后 [switchDatabase] 已替换实例，此处直接返回。
     */
    private fun current(): Graph = graph ?: synchronized(this) {
        graph ?: runBlocking { createGraph(isDemoEnabled()) }.also { graph = it }
    }

    val database: XzgDatabase get() = current().database
    val todoRepository: TodoRepository get() = current().todoRepository
    val memoRepository: MemoRepository get() = current().memoRepository
    val performanceRepository: PerformanceRepository get() = current().performanceRepository
    val expenseRepository: ExpenseRepository get() = current().expenseRepository
    val expiryRepository: ExpiryRepository get() = current().expiryRepository
    val customerRepository: CustomerRepository get() = current().customerRepository
    val goodsRepository: GoodsRepository get() = current().goodsRepository
    val backupService: BackupService get() = current().backupService

    /**
     * 演示模式切换：关闭旧库，按目标模式重建数据库与全部 Repository。
     * 在 IO 线程执行建库+种子写入；返回后调用方必须重启 MainActivity 重建 UI 树。
     *
     * 隔离保证：开→内存库（含种子），关→磁盘库；内存库 close 后即丢弃，
     * 关闭演示模式不会删除/覆盖用户真实数据。
     */
    suspend fun switchDatabase(demoEnabled: Boolean) {
        val newGraph = withContext(Dispatchers.IO) { createGraph(demoEnabled) }
        val old = synchronized(this) {
            val previous = graph
            graph = newGraph
            previous
        }
        old?.close()
    }

    /**
     * 重置演示数据：仅演示模式下有效；重建内存库并重写 DemoCatalog 种子。
     * 调用方随后重启 MainActivity 刷新全部页面。
     */
    suspend fun resetDemoData() {
        if (isDemoEnabled()) {
            switchDatabase(demoEnabled = true)
        }
    }

    /**
     * ViewModel 工厂：`viewModel(factory = XzgGraph.vmFactory { MyVm(XzgGraph.todoRepository) })`。
     */
    fun <VM : ViewModel> vmFactory(create: () -> VM): ViewModelProvider.Factory =
        object : ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : ViewModel> create(modelClass: Class<T>): T = create() as T
        }
}
