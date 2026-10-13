package com.xiaozhanggui.app.backup

import android.content.Context
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.backup.BackupCodec
import com.xiaozhanggui.app.data.backup.BackupService
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.db.XzgDatabase
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import com.xiaozhanggui.app.data.repository.SnapshotRefresher
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 备份恢复语义回归（Phase 1 语义回归 worker）。
 *
 * 对应 iOS BackupService.restore 语义（DELTA §2.5 / 矩阵 R26）：
 * - 恢复 = 追加，不清空已有数据（不走 Repository，直接构造实体 + 单次 save）
 * - 恢复后重建三类通知（todo / expiry / customer，含已有数据）
 * - 恢复后恰好一次快照刷新
 *
 * 说明：编解码本身由 JVM 的 BackupCodecTest 覆盖；此处用真 Room（内存库）+
 * 真 BackupService，验证 restore 的落库/通知/刷新三段语义。
 */
@RunWith(AndroidJUnit4::class)
class BackupRestoreSemanticsTest {

    private class RecordingScheduler : NotificationScheduler {
        val scheduledTodos = mutableListOf<TodoEntity>()
        val scheduledExpiry = mutableListOf<ExpiryItemEntity>()
        val rescheduledCustomers = mutableListOf<CustomerRequestEntity>()
        override fun scheduleTodo(todo: TodoEntity) { scheduledTodos += todo }
        override fun cancelTodo(todo: TodoEntity) { /* not under test */ }
        override fun scheduleExpiry(item: ExpiryItemEntity) { scheduledExpiry += item }
        override fun cancelExpiry(item: ExpiryItemEntity) { /* not under test */ }
        override fun rescheduleCustomer(request: CustomerRequestEntity) {
            rescheduledCustomers += request
        }
        override fun cancelCustomer(request: CustomerRequestEntity) { /* not under test */ }
        override fun canScheduleExactAlarms(): Boolean = true
    }

    private lateinit var context: Context
    private lateinit var db: XzgDatabase
    private lateinit var scheduler: RecordingScheduler
    private var refreshCount = 0

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
        db = Room.inMemoryDatabaseBuilder(context, XzgDatabase::class.java).build()
        scheduler = RecordingScheduler()
        refreshCount = 0
    }

    @After
    fun teardown() {
        db.close()
    }

    @Test
    fun restore_appends_without_clearing_rebuilds_notifications_and_refreshes_once() {
        runBlocking {
            val now = 1_700_000_000_000L
            // 库里已有数据（恢复不得清空）
            db.todoDao().insert(TodoEntity(title = "已有待办", dueDate = now + 3_600_000))

            val service = BackupService(
                context, db, scheduler,
                SnapshotRefresher { refreshCount++ }
            )
            val json = BackupCodec.encode(
                BackupCodec.BackupData(
                    todos = listOf(TodoEntity(title = "备份待办", dueDate = now + 7_200_000)),
                    expiryItems = listOf(
                        ExpiryItemEntity(
                            name = "备份临期",
                            expiryDate = now + 10L * 86_400_000,
                            remindDaysBefore = 7
                        )
                    ),
                    customers = listOf(
                        CustomerRequestEntity(customer = "备份客户", status = "待处理")
                    )
                ),
                now
            )

            val restored = service.restore(json)
            assertEquals(3, restored)

            // 1) 追加不清空
            val todos = db.todoDao().listAll().first()
            assertEquals(2, todos.size)
            assertTrue(todos.any { it.title == "已有待办" })
            assertTrue(todos.any { it.title == "备份待办" })
            assertEquals(1, db.expiryItemDao().listAll().first().size)
            assertEquals(1, db.customerRequestDao().listAll().first().size)

            // 2) 恢复后重建三类通知：全库（已有 + 恢复的）各走一遍
            assertEquals(2, scheduler.scheduledTodos.size)
            assertEquals(1, scheduler.scheduledExpiry.size)
            assertEquals(1, scheduler.rescheduledCustomers.size)

            // 3) 快照刷新恰好一次
            assertEquals(1, refreshCount)
        }
    }

    @Test
    fun restore_empty_backup_refreshes_and_rebuilds_without_inserting() {
        runBlocking {
            val now = 1_700_000_000_000L
            db.todoDao().insert(TodoEntity(title = "已有待办", dueDate = now + 3_600_000))

            val service = BackupService(
                context, db, scheduler,
                SnapshotRefresher { refreshCount++ }
            )
            val restored = service.restore(
                BackupCodec.encode(BackupCodec.BackupData(), now)
            )

            assertEquals(0, restored)
            // 已有数据不动
            assertEquals(1, db.todoDao().listAll().first().size)
            // 空恢复仍重建已有通知 + 刷新一次（与 iOS restore 语义一致）
            assertEquals(1, scheduler.scheduledTodos.size)
            assertEquals(1, refreshCount)
        }
    }
}
