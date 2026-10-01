package com.xiaozhanggui.app.data.di

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.room.Room
import com.xiaozhanggui.app.XzgApplication
import com.xiaozhanggui.app.data.backup.BackupService
import com.xiaozhanggui.app.data.datastore.XzgSettings
import com.xiaozhanggui.app.data.db.XzgDatabase
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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking

/**
 * 单例装配图。对应 iOS `App/XiaoZhangGuiApp.swift` 的环境装配职责
 *（ModelContainer + 各 Store / Service 的持有与注入）。
 *
 * - 全部依赖 lazy 初始化，`XzgApplication.onCreate()` 调用 [init] 后可用。
 * - database：`Room.databaseBuilder(...).build()`，失败直接抛异常，
 *   绝不静默回退内存库（P0-2 红线）。
 * - notificationScheduler 的 settingsImpl 从 XzgSettings 的 Flow 取当前值
 *  （runBlocking + first()，简单可靠）。
 * - refresher 快照钩子 Phase 3 暂用 NoopRefresher，Phase 5 接 AppWidget/快照时替换。
 */
object XzgGraph {

    private lateinit var appRef: XzgApplication

    /** Application 启动时调用，保存 application 引用。 */
    fun init(app: XzgApplication) {
        appRef = app
    }

    private val app: XzgApplication
        get() = appRef

    val database: XzgDatabase by lazy {
        Room.databaseBuilder(app, XzgDatabase::class.java, "xzg.db").build()
    }

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

    val todoRepository: TodoRepository by lazy {
        TodoRepository(database.todoDao(), notificationScheduler)
    }

    val memoRepository: MemoRepository by lazy {
        MemoRepository(database.memoDao())
    }

    val performanceRepository: PerformanceRepository by lazy {
        PerformanceRepository(database.performanceDao())
    }

    val expenseRepository: ExpenseRepository by lazy {
        ExpenseRepository(database.expenseDao())
    }

    val expiryRepository: ExpiryRepository by lazy {
        ExpiryRepository(database.expiryItemDao(), notificationScheduler)
    }

    val customerRepository: CustomerRepository by lazy {
        CustomerRepository(database.customerRequestDao(), notificationScheduler)
    }

    val goodsRepository: GoodsRepository by lazy {
        GoodsRepository(database.goodsDao())
    }

    val backupService: BackupService by lazy {
        BackupService(app, database, notificationScheduler, NoopRefresher)
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
