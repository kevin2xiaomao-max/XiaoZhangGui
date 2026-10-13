package com.xiaozhanggui.app

import androidx.room.Room
import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.xiaozhanggui.app.data.db.MIGRATION_1_2
import com.xiaozhanggui.app.data.db.XzgDatabase
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Room 1 → 2 数据升级回归测试（P0-2 门禁，对应 DELTA §5.3）。
 *
 * 跑在 CI e2e job（`connectedDebugAndroidTest`，真机 SQLite）。
 *
 * 两个场景：
 * - A（真实 V3.6 设备）：v1 库**已含** `performances.incomeSource` 列
 *   （该字段自 Android 工程首个提交 `70849e4` 即存在于实体），迁移必须为
 *   安全 no-op，数据零丢失；
 * - B（防御分支）：v1 库缺该列，迁移执行
 *   `ALTER TABLE ... ADD COLUMN incomeSource TEXT NOT NULL DEFAULT ''`，
 *   旧行默认 `""`，数据零丢失。
 *
 * 断言：7 表行数零丢失、`incomeSource` 默认值/原值正确、关键字段抽查、
 * Room 2.6.1 schema 校验通过（`runMigrationsAndValidate`）、升级后 App
 * 可用 Room 正常打开并读出实体。
 *
 * 注：`payment_codes`（收款码）走 DataStore 非 Room，无表结构，不在本测试内。
 */
@RunWith(AndroidJUnit4::class)
class XzgMigrationTest {

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        XzgDatabase::class.java
    )

    // ---------- v1 DDL（与 Room 2.6.1 生成一致：列顺序 = 实体字段声明顺序） ----------

    private val createTodosV1 =
        "CREATE TABLE IF NOT EXISTS `todos` (`id` TEXT NOT NULL, `title` TEXT NOT NULL, " +
            "`detail` TEXT NOT NULL, `dueDate` INTEGER, `priority` INTEGER NOT NULL, " +
            "`imagePath` TEXT, `isCompleted` INTEGER NOT NULL, `completedAt` INTEGER, " +
            "`createdAt` INTEGER NOT NULL, `notificationId` TEXT NOT NULL, PRIMARY KEY(`id`))"

    private val createExpiryV1 =
        "CREATE TABLE IF NOT EXISTS `expiry_items` (`id` TEXT NOT NULL, `name` TEXT NOT NULL, " +
            "`category` TEXT NOT NULL, `quantity` INTEGER NOT NULL, `productionDate` INTEGER, " +
            "`expiryDate` INTEGER NOT NULL, `remindDaysBefore` INTEGER NOT NULL, `note` TEXT NOT NULL, " +
            "`imagePath` TEXT, `createdAt` INTEGER NOT NULL, `returnStatus` TEXT NOT NULL, " +
            "`returnedAt` INTEGER, `notificationId` TEXT NOT NULL, PRIMARY KEY(`id`))"

    private val createCustomersV1 =
        "CREATE TABLE IF NOT EXISTS `customer_requests` (`id` TEXT NOT NULL, `customer` TEXT NOT NULL, " +
            "`roomOrAddress` TEXT NOT NULL, `phone` TEXT NOT NULL, `content` TEXT NOT NULL, " +
            "`status` TEXT NOT NULL, `imagePath` TEXT, `createdAt` INTEGER NOT NULL, " +
            "`updatedAt` INTEGER NOT NULL, `notificationId` TEXT NOT NULL, PRIMARY KEY(`id`))"

    private val createGoodsV1 =
        "CREATE TABLE IF NOT EXISTS `goods` (`id` TEXT NOT NULL, `name` TEXT NOT NULL, " +
            "`category` TEXT NOT NULL, `barcode` TEXT NOT NULL, `stock` INTEGER NOT NULL, " +
            "`minStock` INTEGER NOT NULL, `purchasePrice` REAL NOT NULL, `salePrice` REAL NOT NULL, " +
            "`productionDate` INTEGER, `shelfLifeDays` INTEGER NOT NULL, `expiryDate` INTEGER, " +
            "`note` TEXT NOT NULL, `imagePath` TEXT, `createdAt` INTEGER NOT NULL, " +
            "`updatedAt` INTEGER NOT NULL, PRIMARY KEY(`id`))"

    private val createMemosV1 =
        "CREATE TABLE IF NOT EXISTS `memos` (`id` TEXT NOT NULL, `title` TEXT NOT NULL, " +
            "`content` TEXT NOT NULL, `imagePath` TEXT, `createdAt` INTEGER NOT NULL, " +
            "`updatedAt` INTEGER NOT NULL, PRIMARY KEY(`id`))"

    private val createPerformancesV1WithIncomeSource =
        "CREATE TABLE IF NOT EXISTS `performances` (`id` TEXT NOT NULL, `amount` REAL NOT NULL, " +
            "`note` TEXT NOT NULL, `date` INTEGER NOT NULL, `fingerprint` TEXT NOT NULL, " +
            "`paymentMethod` TEXT NOT NULL, `orderNo` TEXT NOT NULL, `importSource` TEXT NOT NULL, " +
            "`incomeSource` TEXT NOT NULL, PRIMARY KEY(`id`))"

    private val createPerformancesV1WithoutIncomeSource =
        "CREATE TABLE IF NOT EXISTS `performances` (`id` TEXT NOT NULL, `amount` REAL NOT NULL, " +
            "`note` TEXT NOT NULL, `date` INTEGER NOT NULL, `fingerprint` TEXT NOT NULL, " +
            "`paymentMethod` TEXT NOT NULL, `orderNo` TEXT NOT NULL, `importSource` TEXT NOT NULL, " +
            "PRIMARY KEY(`id`))"

    private val createExpensesV1 =
        "CREATE TABLE IF NOT EXISTS `expenses` (`id` TEXT NOT NULL, `amount` REAL NOT NULL, " +
            "`category` TEXT NOT NULL, `note` TEXT NOT NULL, `date` INTEGER NOT NULL, " +
            "`createdAt` INTEGER NOT NULL, PRIMARY KEY(`id`))"

    /** 场景 A：真实 V3.6 设备 v1 库（performances 已含 incomeSource 列） */
    @Test
    fun migrate1To2_withIncomeSourceAlreadyPresent_preservesAllData() {
        val dbName = "xzg-migration-a.db"
        helper.createDatabase(dbName, 1).apply {
            createV1Schema(withIncomeSource = true)
            insertV1Rows(withIncomeSource = true)
            close()
        }

        helper.runMigrationsAndValidate(dbName, 2, true, MIGRATION_1_2).apply {
            assertAllTablesIntact(this)
            // 原值保留：扫呗导入行 incomeSource=美团，手工旧行 incomeSource=""
            assertEquals("美团", stringValue("SELECT incomeSource FROM performances WHERE id = 'p-1'"))
            assertEquals("", stringValue("SELECT incomeSource FROM performances WHERE id = 'p-2'"))
            close()
        }

        assertRoomCanOpenAndRead(dbName, expectedMeituan = "美团", expectedManual = "")
    }

    /** 场景 B：v1 库缺 incomeSource 列 → 迁移补列，旧行默认 "" */
    @Test
    fun migrate1To2_withoutIncomeSourceColumn_addsColumnWithEmptyDefault() {
        val dbName = "xzg-migration-b.db"
        helper.createDatabase(dbName, 1).apply {
            createV1Schema(withIncomeSource = false)
            insertV1Rows(withIncomeSource = false)
            close()
        }

        helper.runMigrationsAndValidate(dbName, 2, true, MIGRATION_1_2).apply {
            assertAllTablesIntact(this)
            assertEquals("", stringValue("SELECT incomeSource FROM performances WHERE id = 'p-1'"))
            assertEquals("", stringValue("SELECT incomeSource FROM performances WHERE id = 'p-2'"))
            close()
        }

        assertRoomCanOpenAndRead(dbName, expectedMeituan = "", expectedManual = "")
    }

    // ---------- 建表 / 造数 ----------

    private fun SupportSQLiteDatabase.createV1Schema(withIncomeSource: Boolean) {
        execSQL(createTodosV1)
        execSQL(createExpiryV1)
        execSQL(createCustomersV1)
        execSQL(createGoodsV1)
        execSQL(createMemosV1)
        execSQL(
            if (withIncomeSource) createPerformancesV1WithIncomeSource
            else createPerformancesV1WithoutIncomeSource
        )
        execSQL(createExpensesV1)
    }

    private fun SupportSQLiteDatabase.insertV1Rows(withIncomeSource: Boolean) {
        execSQL(
            "INSERT INTO todos VALUES ('todo-1', '进货牛奶', '2箱', 1700000000000, 2, NULL, 0, NULL, " +
                "1699000000000, 'nid-todo-1')"
        )
        execSQL(
            "INSERT INTO expiry_items VALUES ('exp-1', '鲜奶', '饮料', 5, NULL, 1701000000000, 7, " +
                "'临期', NULL, 1699000000000, '待处理', NULL, 'nid-exp-1')"
        )
        execSQL(
            "INSERT INTO customer_requests VALUES ('cus-1', 'xzg-delivery-v1:e30=', '3楼', " +
                "'13800000000', '送两箱水', '待处理', NULL, 1699000000000, 1699000000000, 'nid-cus-1')"
        )
        execSQL(
            "INSERT INTO goods VALUES ('g-1', '可乐', '饮料', '6901234567890', 10, 5, 2.5, 3.5, " +
                "NULL, 365, 1735000000000, '', NULL, 1699000000000, 1699000000000)"
        )
        execSQL(
            "INSERT INTO memos VALUES ('m-1', '备忘标题', '备忘内容', NULL, 1699000000000, 1699000000000)"
        )
        if (withIncomeSource) {
            execSQL(
                "INSERT INTO performances VALUES ('p-1', 128.5, '扫呗 · 美团', 1700000000000, " +
                    "'abc123', '美团', 'ORDER001', 'saobei', '美团')"
            )
            execSQL(
                "INSERT INTO performances VALUES ('p-2', 200.0, '散客', 1699900000000, " +
                    "'', '', '', '', '')"
            )
        } else {
            execSQL(
                "INSERT INTO performances VALUES ('p-1', 128.5, '扫呗 · 美团', 1700000000000, " +
                    "'abc123', '美团', 'ORDER001', 'saobei')"
            )
            execSQL(
                "INSERT INTO performances VALUES ('p-2', 200.0, '散客', 1699900000000, " +
                    "'', '', '', '')"
            )
        }
        execSQL(
            "INSERT INTO expenses VALUES ('e-1', 50.0, '进货', '牛奶', 1700000000000, 1699000000000)"
        )
    }

    // ---------- 断言 ----------

    private fun SupportSQLiteDatabase.count(table: String): Int {
        query("SELECT COUNT(*) FROM `$table`").use { c ->
            c.moveToFirst()
            return c.getInt(0)
        }
    }

    private fun SupportSQLiteDatabase.stringValue(sql: String): String? {
        query(sql).use { c ->
            return if (c.moveToFirst()) c.getString(0) else null
        }
    }

    private fun SupportSQLiteDatabase.doubleValue(sql: String): Double {
        query(sql).use { c ->
            c.moveToFirst()
            return c.getDouble(0)
        }
    }

    /** 7 表零丢失 + 关键字段抽查 */
    private fun assertAllTablesIntact(db: SupportSQLiteDatabase) {
        assertEquals(1, db.count("todos"))
        assertEquals(1, db.count("expiry_items"))
        assertEquals(1, db.count("customer_requests"))
        assertEquals(1, db.count("goods"))
        assertEquals(1, db.count("memos"))
        assertEquals(2, db.count("performances"))
        assertEquals(1, db.count("expenses"))
        // 关键字段抽查：金额 / 指纹 / 标题 / 通知标识未被迁移破坏
        assertEquals(128.5, db.doubleValue("SELECT amount FROM performances WHERE id = 'p-1'"), 0.0)
        assertEquals("abc123", db.stringValue("SELECT fingerprint FROM performances WHERE id = 'p-1'"))
        assertEquals("美团", db.stringValue("SELECT paymentMethod FROM performances WHERE id = 'p-1'"))
        assertEquals("进货牛奶", db.stringValue("SELECT title FROM todos WHERE id = 'todo-1'"))
        assertEquals("nid-todo-1", db.stringValue("SELECT notificationId FROM todos WHERE id = 'todo-1'"))
        assertEquals("nid-cus-1", db.stringValue("SELECT notificationId FROM customer_requests WHERE id = 'cus-1'"))
        assertEquals("nid-exp-1", db.stringValue("SELECT notificationId FROM expiry_items WHERE id = 'exp-1'"))
        assertEquals("待处理", db.stringValue("SELECT status FROM customer_requests WHERE id = 'cus-1'"))
        assertEquals("待处理", db.stringValue("SELECT returnStatus FROM expiry_items WHERE id = 'exp-1'"))
    }

    /** 升级后 App 可用 Room 正常打开并读出实体（端到端） */
    private fun assertRoomCanOpenAndRead(
        dbName: String,
        expectedMeituan: String,
        expectedManual: String
    ) {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val roomDb = Room.databaseBuilder(context, XzgDatabase::class.java, dbName)
            .addMigrations(MIGRATION_1_2)
            .build()
        try {
            val performances = runBlocking { roomDb.performanceDao().listAll().first() }
            assertEquals(2, performances.size)
            assertEquals(expectedMeituan, performances.first { it.id == "p-1" }.incomeSource)
            assertEquals(expectedManual, performances.first { it.id == "p-2" }.incomeSource)
            val todos = runBlocking { roomDb.todoDao().listAll().first() }
            assertEquals(1, todos.size)
            assertEquals("进货牛奶", todos[0].title)
        } finally {
            roomDb.close()
        }
    }
}
