package com.xiaozhanggui.app.migration

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.backup.BackupCodec
import com.xiaozhanggui.app.data.db.MIGRATION_1_2
import com.xiaozhanggui.app.data.db.XzgDatabase
import com.xiaozhanggui.app.domain.IncomeSource
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.UUID

/**
 * 数据升级回归测试（DELTA §5.3，Phase 1 门禁）。
 *
 * 流程：用 [V1Schema] 手工构造 V3.6 旧版本数据库文件（7 表代表性数据，
 * 含扫呗导入记录），再用新 App（V3.7.1 schema + MIGRATION_1_2）打开。
 *
 * 断言：
 * - 7 表数据零丢失（行数 + 关键字段）
 * - `incomeSource`：列已存在→值保留；缺列→ADD COLUMN 默认 `""`，
 *   回退派生（`IncomeSource.fromPerformance`）语义正确
 * - 通知可重建：todo/expiry/customer 的 notificationId 保持为有效 UUID v4
 *  （调度键 `todo-<notificationId>` 等跨升级不变）
 * - 备份 round-trip：升级后库导出→解码，记录数一致
 * - 禁区：全程无 destructive migration（数据存在即证明）
 */
@RunWith(AndroidJUnit4::class)
class DataUpgradeRegressionTest {

    private lateinit var context: Context

    private val uuidV4 =
        Regex("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
            RegexOption.IGNORE_CASE)

    private val now = 1_700_000_000_000L

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
    }

    /** version=1 的旧库 Helper：只建表、不升级。 */
    private class V1Helper(
        context: Context,
        path: String,
        private val withIncomeSource: Boolean
    ) : SQLiteOpenHelper(context, path, null, 1) {
        override fun onCreate(db: SQLiteDatabase) {
            for (sql in V1Schema.createAllTables(withIncomeSource)) db.execSQL(sql)
        }

        override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) = Unit
    }

    private fun cv(vararg pairs: Pair<String, Any?>): ContentValues =
        ContentValues().apply {
            for ((k, v) in pairs) {
                when (v) {
                    null -> putNull(k)
                    is String -> put(k, v)
                    is Long -> put(k, v)
                    is Int -> put(k, v)
                    is Double -> put(k, v)
                    else -> put(k, v.toString())
                }
            }
        }

    /** 构造 v1 旧库并写入 7 表代表性数据，返回库文件。 */
    private fun seedV1Database(fileName: String, withIncomeSource: Boolean): File {
        val file = File(context.cacheDir, fileName)
        if (file.exists()) file.delete()
        val helper = V1Helper(context, file.absolutePath, withIncomeSource)
        try {
            val db = helper.writableDatabase
            val perfCols: (ContentValues) -> ContentValues = { values ->
                if (!withIncomeSource) values.apply { remove("incomeSource") } else values
            }

            // performances：1 条扫呗导入 + 1 条手工
            db.insert("performances", null, perfCols(cv(
                "id" to "perf-saobei-1", "amount" to 128.5,
                "note" to "扫呗 · 微信支付", "date" to now,
                "fingerprint" to "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90",
                "paymentMethod" to "微信支付", "orderNo" to "ORDER001",
                "importSource" to "saobei", "incomeSource" to "门店"
            )))
            db.insert("performances", null, perfCols(cv(
                "id" to "perf-manual-1", "amount" to 500.0,
                "note" to "今日营业额", "date" to now,
                "fingerprint" to "", "paymentMethod" to "",
                "orderNo" to "", "importSource" to "", "incomeSource" to "门店"
            )))

            // todos：1 待办 + 1 已完成
            db.insert("todos", null, cv(
                "id" to "todo-1", "title" to "进货", "detail" to "牛奶20箱",
                "dueDate" to now + 3_600_000, "priority" to 2,
                "imagePath" to null, "isCompleted" to 0,
                "completedAt" to null, "createdAt" to now,
                "notificationId" to "11111111-1111-4111-8111-111111111111"
            ))
            db.insert("todos", null, cv(
                "id" to "todo-2", "title" to "已办事项", "detail" to "",
                "dueDate" to null, "priority" to 0,
                "imagePath" to null, "isCompleted" to 1,
                "completedAt" to now - 1000, "createdAt" to now,
                "notificationId" to "22222222-2222-4222-8222-222222222222"
            ))

            // customer_requests：1 条待处理
            db.insert("customer_requests", null, cv(
                "id" to "cust-1", "customer" to "王老板",
                "roomOrAddress" to "3栋2单元", "phone" to "13900002222",
                "content" to "送两箱水", "status" to "待处理",
                "imagePath" to null, "createdAt" to now, "updatedAt" to now,
                "notificationId" to "33333333-3333-4333-8333-333333333333"
            ))

            // expiry_items：1 条待处理
            db.insert("expiry_items", null, cv(
                "id" to "exp-1", "name" to "鲜奶", "category" to "乳品",
                "quantity" to 12, "productionDate" to null,
                "expiryDate" to now + 10L * 86_400_000, "remindDaysBefore" to 7,
                "note" to "", "imagePath" to null, "createdAt" to now,
                "returnStatus" to "待处理", "returnedAt" to null,
                "notificationId" to "44444444-4444-4444-8444-444444444444"
            ))

            // goods：1 条
            db.insert("goods", null, cv(
                "id" to "goods-1", "name" to "康师傅红烧牛肉面",
                "category" to "方便面", "barcode" to "6901234567890",
                "stock" to 48, "minStock" to 12,
                "purchasePrice" to 2.5, "salePrice" to 4.5,
                "productionDate" to null, "shelfLifeDays" to 180,
                "expiryDate" to null, "note" to "",
                "imagePath" to null, "createdAt" to now, "updatedAt" to now
            ))

            // memos：1 条
            db.insert("memos", null, cv(
                "id" to "memo-1", "title" to "供应商电话",
                "content" to "13800001111", "imagePath" to null,
                "createdAt" to now, "updatedAt" to now
            ))

            // expenses：1 条
            db.insert("expenses", null, cv(
                "id" to "expn-1", "amount" to 50.0, "category" to "进货",
                "note" to "牛奶", "date" to now, "createdAt" to now
            ))
        } finally {
            helper.close()
        }
        return file
    }

    private fun openUpgraded(file: File): XzgDatabase =
        Room.databaseBuilder(context, XzgDatabase::class.java, file.absolutePath)
            .addMigrations(MIGRATION_1_2)
            .build()

    // ---------- 场景 1：真实 V3.6 设备（incomeSource 列已存在）→ 迁移为 no-op ----------

    @Test
    fun upgrade_v1_with_incomeSource_column_keeps_all_data() = runBlocking {
        val file = seedV1Database("upgrade_v1_present.db", withIncomeSource = true)
        val db = openUpgraded(file)
        try {
            assertEquals(2, db.openHelper.readableDatabase.version)

            // 7 表零丢失
            val performances = db.performanceDao().listAll().first()
            val todos = db.todoDao().listAll().first()
            val customers = db.customerRequestDao().listAll().first()
            val expiryItems = db.expiryItemDao().listAll().first()
            val goods = db.goodsDao().listAll().first()
            val memos = db.memoDao().listAll().first()
            val expenses = db.expenseDao().listAll().first()
            assertEquals(2, performances.size)
            assertEquals(2, todos.size)
            assertEquals(1, customers.size)
            assertEquals(1, expiryItems.size)
            assertEquals(1, goods.size)
            assertEquals(1, memos.size)
            assertEquals(1, expenses.size)

            // 关键字段原样保留（含扫呗指纹）
            val saobei = performances.first { it.id == "perf-saobei-1" }
            assertEquals(128.5, saobei.amount, 0.001)
            assertEquals(
                "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90",
                saobei.fingerprint
            )
            assertEquals("saobei", saobei.importSource)
            assertEquals("门店", saobei.incomeSource)
            assertEquals("门店", performances.first { it.id == "perf-manual-1" }.incomeSource)
            assertEquals("进货", todos.first { it.id == "todo-1" }.title)
            assertEquals(48, goods[0].stock)
            assertEquals("供应商电话", memos[0].title)
            assertEquals("进货", expenses[0].category)

            assertNotificationIdsSurvive(todos, expiryItems, customers)
            assertBackupRoundTrip(db, expectedTotal = 9)
        } finally {
            db.close()
            file.delete()
        }
    }

    // ---------- 场景 2：缺列旧库 → ADD COLUMN，默认 ""，回退派生正确 ----------

    @Test
    fun upgrade_v1_missing_incomeSource_column_gets_default_and_derivation() = runBlocking {
        val file = seedV1Database("upgrade_v1_missing.db", withIncomeSource = false)
        val db = openUpgraded(file)
        try {
            assertEquals(2, db.openHelper.readableDatabase.version)

            val performances = db.performanceDao().listAll().first()
            assertEquals(2, performances.size)
            // 缺列 → 默认 ""
            for (p in performances) {
                assertEquals("[" + p.id + "]", "", p.incomeSource)
            }
            // 其余表零丢失
            assertEquals(2, db.todoDao().listAll().first().size)
            assertEquals(1, db.goodsDao().listAll().first().size)

            // 回退派生语义（iOS IncomeSource.from(performance:) 1:1）：
            // paymentMethod 美团 → 美团；字段为空 + paymentMethod 非美团 → note 派生
            assertEquals(
                IncomeSource.MEITUAN,
                IncomeSource.fromPerformance("", "美团", "扫呗 · 美团支付")
            )
            assertEquals(
                IncomeSource.OTHER,
                IncomeSource.fromPerformance("", "微信支付", "扫呗 · 微信支付")
            )
            assertEquals(
                IncomeSource.STORE,
                IncomeSource.fromPerformance("门店", "微信支付", "扫呗 · 微信支付")
            )

            assertNotificationIdsSurvive(
                db.todoDao().listAll().first(),
                db.expiryItemDao().listAll().first(),
                db.customerRequestDao().listAll().first()
            )
            assertBackupRoundTrip(db, expectedTotal = 9)
        } finally {
            db.close()
            file.delete()
        }
    }

    // ---------- 共享断言 ----------

    private suspend fun assertNotificationIdsSurvive(
        todos: List<com.xiaozhanggui.app.data.db.TodoEntity>,
        expiryItems: List<com.xiaozhanggui.app.data.db.ExpiryItemEntity>,
        customers: List<com.xiaozhanggui.app.data.db.CustomerRequestEntity>
    ) {
        // 通知可重建的前提：三类实体的 notificationId 跨升级保持有效 UUID v4
        for (t in todos) {
            assertTrue("[todo ${t.id}]", uuidV4.matches(t.notificationId))
        }
        for (x in expiryItems) {
            assertTrue("[expiry ${x.id}]", uuidV4.matches(x.notificationId))
        }
        for (c in customers) {
            assertTrue("[customer ${c.id}]", uuidV4.matches(c.notificationId))
        }
    }

    private suspend fun assertBackupRoundTrip(db: XzgDatabase, expectedTotal: Int) {
        // 备份 round-trip 一致：升级后库导出 → 解码，记录数一致
        val data = BackupCodec.BackupData(
            todos = db.todoDao().listAll().first(),
            memos = db.memoDao().listAll().first(),
            performances = db.performanceDao().listAll().first(),
            expenses = db.expenseDao().listAll().first(),
            expiryItems = db.expiryItemDao().listAll().first(),
            customers = db.customerRequestDao().listAll().first(),
            goods = db.goodsDao().listAll().first()
        )
        val decoded = BackupCodec.decode(BackupCodec.encode(data, now))
        assertEquals(expectedTotal, decoded.totalCount())
        // 注意：备份不持久化 id/notificationId（BackupCodec 设计），只比业务字段
        assertEquals(
            data.performances.map { it.amount to it.fingerprint }.toSet(),
            decoded.performances.map { it.amount to it.fingerprint }.toSet()
        )
        assertEquals(
            data.todos.map { it.title }.toSet(),
            decoded.todos.map { it.title }.toSet()
        )
    }
}
