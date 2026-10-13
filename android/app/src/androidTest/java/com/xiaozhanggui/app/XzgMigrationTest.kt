package com.xiaozhanggui.app

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import androidx.room.Room
import androidx.room.util.TableInfo
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.xiaozhanggui.app.data.db.MIGRATION_1_2
import com.xiaozhanggui.app.data.db.XzgDatabase
import com.xiaozhanggui.app.migration.V1Schema
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

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
 * 迁移后表结构与 v2 实体定义逐列一致（类型/NOT NULL/主键）、升级后 App
 * 可用 Room 正常打开并读出实体。
 *
 * 实现方式说明：最初版本使用 `MigrationTestHelper`，但它在
 * `createDatabase()` / `runMigrationsAndValidate()` 时强制读取导出的
 * schema JSON（`assets/<db类名>/1.json`、`2.json`），而本工程
 * `XzgDatabase(exportSchema = false)` 从不导出，导致
 * `FileNotFoundException: .../XzgDatabase/1.json`（CI run 38442903681
 * 两处 FAILED 的根因，与迁移逻辑本身无关）。因此改用原生
 * `SQLiteOpenHelper` 手工构造 v1 旧库（建表 SQL 复用 [V1Schema]，与
 * `DataUpgradeRegressionTest` 同一 CI 已验证模式），由 Room 自身执行
 * `MIGRATION_1_2`；schema 校验改用 `TableInfo.read()` 逐列比对，
 * 等价于 `runMigrationsAndValidate` 的表结构校验。
 *
 * 注：`payment_codes`（收款码）走 DataStore 非 Room，无表结构，不在本测试内。
 */
@RunWith(AndroidJUnit4::class)
class XzgMigrationTest {

    private lateinit var context: Context

    @Before
    fun setup() {
        context = ApplicationProvider.getApplicationContext()
    }

    /** version=1 的旧库 Helper：只建表、不升级（user_version 由构造参数置 1）。 */
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

    /** 场景 A：真实 V3.6 设备 v1 库（performances 已含 incomeSource 列） */
    @Test
    fun migrate1To2_withIncomeSourceAlreadyPresent_preservesAllData() {
        val file = seedV1Database("xzg-migration-a.db", withIncomeSource = true)
        try {
            val roomDb = openAndMigrate(file)
            try {
                assertEquals(2, roomDb.openHelper.readableDatabase.version)
                val db = roomDb.openHelper.writableDatabase
                assertAllTablesIntact(db)
                // 等价于 runMigrationsAndValidate 的 schema 校验：no-op 后仍是合法 v2
                assertV2Schema(db)
                // 原值保留：扫呗导入行 incomeSource=美团，手工旧行 incomeSource=""
                assertEquals("美团", db.stringValue("SELECT incomeSource FROM performances WHERE id = 'p-1'"))
                assertEquals("", db.stringValue("SELECT incomeSource FROM performances WHERE id = 'p-2'"))
            } finally {
                roomDb.close()
            }
            assertRoomCanOpenAndRead(file, expectedMeituan = "美团", expectedManual = "")
        } finally {
            deleteDbFiles("xzg-migration-a.db")
        }
    }

    /** 场景 B：v1 库缺 incomeSource 列 → 迁移补列，旧行默认 "" */
    @Test
    fun migrate1To2_withoutIncomeSourceColumn_addsColumnWithEmptyDefault() {
        val file = seedV1Database("xzg-migration-b.db", withIncomeSource = false)
        try {
            val roomDb = openAndMigrate(file)
            try {
                assertEquals(2, roomDb.openHelper.readableDatabase.version)
                val db = roomDb.openHelper.writableDatabase
                assertAllTablesIntact(db)
                // ADD COLUMN 后的表结构必须与 v2 实体定义逐列一致
                assertV2Schema(db)
                assertEquals("", db.stringValue("SELECT incomeSource FROM performances WHERE id = 'p-1'"))
                assertEquals("", db.stringValue("SELECT incomeSource FROM performances WHERE id = 'p-2'"))
            } finally {
                roomDb.close()
            }
            assertRoomCanOpenAndRead(file, expectedMeituan = "", expectedManual = "")
        } finally {
            deleteDbFiles("xzg-migration-b.db")
        }
    }

    // ---------- 建库 / 造数 ----------

    /** 用原生 SQLiteOpenHelper 构造 v1 旧库并写入 7 表代表性数据，返回库文件。 */
    private fun seedV1Database(fileName: String, withIncomeSource: Boolean): File {
        deleteDbFiles(fileName)
        val file = File(context.cacheDir, fileName)
        val helper = V1Helper(context, file.absolutePath, withIncomeSource)
        try {
            insertV1Rows(helper.writableDatabase, withIncomeSource)
        } finally {
            helper.close()
        }
        return file
    }

    /** 由 Room 自身打开旧库并执行 MIGRATION_1_2（即 App 覆盖安装时的真实路径）。 */
    private fun openAndMigrate(file: File): XzgDatabase =
        Room.databaseBuilder(context, XzgDatabase::class.java, file.absolutePath)
            .addMigrations(MIGRATION_1_2)
            .build()

    private fun deleteDbFiles(fileName: String) {
        File(context.cacheDir, fileName).delete()
        File(context.cacheDir, "$fileName-wal").delete()
        File(context.cacheDir, "$fileName-shm").delete()
    }

    private fun insertV1Rows(db: SQLiteDatabase, withIncomeSource: Boolean) {
        db.execSQL(
            "INSERT INTO todos VALUES ('todo-1', '进货牛奶', '2箱', 1700000000000, 2, NULL, 0, NULL, " +
                "1699000000000, 'nid-todo-1')"
        )
        db.execSQL(
            "INSERT INTO expiry_items VALUES ('exp-1', '鲜奶', '饮料', 5, NULL, 1701000000000, 7, " +
                "'临期', NULL, 1699000000000, '待处理', NULL, 'nid-exp-1')"
        )
        db.execSQL(
            "INSERT INTO customer_requests VALUES ('cus-1', 'xzg-delivery-v1:e30=', '3楼', " +
                "'13800000000', '送两箱水', '待处理', NULL, 1699000000000, 1699000000000, 'nid-cus-1')"
        )
        db.execSQL(
            "INSERT INTO goods VALUES ('g-1', '可乐', '饮料', '6901234567890', 10, 5, 2.5, 3.5, " +
                "NULL, 365, 1735000000000, '', NULL, 1699000000000, 1699000000000)"
        )
        db.execSQL(
            "INSERT INTO memos VALUES ('m-1', '备忘标题', '备忘内容', NULL, 1699000000000, 1699000000000)"
        )
        if (withIncomeSource) {
            db.execSQL(
                "INSERT INTO performances VALUES ('p-1', 128.5, '扫呗 · 美团', 1700000000000, " +
                    "'abc123', '美团', 'ORDER001', 'saobei', '美团')"
            )
            db.execSQL(
                "INSERT INTO performances VALUES ('p-2', 200.0, '散客', 1699900000000, " +
                    "'', '', '', '', '')"
            )
        } else {
            db.execSQL(
                "INSERT INTO performances VALUES ('p-1', 128.5, '扫呗 · 美团', 1700000000000, " +
                    "'abc123', '美团', 'ORDER001', 'saobei')"
            )
            db.execSQL(
                "INSERT INTO performances VALUES ('p-2', 200.0, '散客', 1699900000000, " +
                    "'', '', '', '')"
            )
        }
        db.execSQL(
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

    /** 期望列定义（逐字对应 7 个 Entity 的字段声明顺序与类型映射）。 */
    private data class ExpectedColumn(
        val name: String,
        val type: String,
        val notNull: Boolean,
        val pkPosition: Int
    )

    private val v2Schema: Map<String, List<ExpectedColumn>> = mapOf(
        "todos" to listOf(
            ExpectedColumn("id", "TEXT", true, 1),
            ExpectedColumn("title", "TEXT", true, 0),
            ExpectedColumn("detail", "TEXT", true, 0),
            ExpectedColumn("dueDate", "INTEGER", false, 0),
            ExpectedColumn("priority", "INTEGER", true, 0),
            ExpectedColumn("imagePath", "TEXT", false, 0),
            ExpectedColumn("isCompleted", "INTEGER", true, 0),
            ExpectedColumn("completedAt", "INTEGER", false, 0),
            ExpectedColumn("createdAt", "INTEGER", true, 0),
            ExpectedColumn("notificationId", "TEXT", true, 0)
        ),
        "expiry_items" to listOf(
            ExpectedColumn("id", "TEXT", true, 1),
            ExpectedColumn("name", "TEXT", true, 0),
            ExpectedColumn("category", "TEXT", true, 0),
            ExpectedColumn("quantity", "INTEGER", true, 0),
            ExpectedColumn("productionDate", "INTEGER", false, 0),
            ExpectedColumn("expiryDate", "INTEGER", true, 0),
            ExpectedColumn("remindDaysBefore", "INTEGER", true, 0),
            ExpectedColumn("note", "TEXT", true, 0),
            ExpectedColumn("imagePath", "TEXT", false, 0),
            ExpectedColumn("createdAt", "INTEGER", true, 0),
            ExpectedColumn("returnStatus", "TEXT", true, 0),
            ExpectedColumn("returnedAt", "INTEGER", false, 0),
            ExpectedColumn("notificationId", "TEXT", true, 0)
        ),
        "customer_requests" to listOf(
            ExpectedColumn("id", "TEXT", true, 1),
            ExpectedColumn("customer", "TEXT", true, 0),
            ExpectedColumn("roomOrAddress", "TEXT", true, 0),
            ExpectedColumn("phone", "TEXT", true, 0),
            ExpectedColumn("content", "TEXT", true, 0),
            ExpectedColumn("status", "TEXT", true, 0),
            ExpectedColumn("imagePath", "TEXT", false, 0),
            ExpectedColumn("createdAt", "INTEGER", true, 0),
            ExpectedColumn("updatedAt", "INTEGER", true, 0),
            ExpectedColumn("notificationId", "TEXT", true, 0)
        ),
        "goods" to listOf(
            ExpectedColumn("id", "TEXT", true, 1),
            ExpectedColumn("name", "TEXT", true, 0),
            ExpectedColumn("category", "TEXT", true, 0),
            ExpectedColumn("barcode", "TEXT", true, 0),
            ExpectedColumn("stock", "INTEGER", true, 0),
            ExpectedColumn("minStock", "INTEGER", true, 0),
            ExpectedColumn("purchasePrice", "REAL", true, 0),
            ExpectedColumn("salePrice", "REAL", true, 0),
            ExpectedColumn("productionDate", "INTEGER", false, 0),
            ExpectedColumn("shelfLifeDays", "INTEGER", true, 0),
            ExpectedColumn("expiryDate", "INTEGER", false, 0),
            ExpectedColumn("note", "TEXT", true, 0),
            ExpectedColumn("imagePath", "TEXT", false, 0),
            ExpectedColumn("createdAt", "INTEGER", true, 0),
            ExpectedColumn("updatedAt", "INTEGER", true, 0)
        ),
        "memos" to listOf(
            ExpectedColumn("id", "TEXT", true, 1),
            ExpectedColumn("title", "TEXT", true, 0),
            ExpectedColumn("content", "TEXT", true, 0),
            ExpectedColumn("imagePath", "TEXT", false, 0),
            ExpectedColumn("createdAt", "INTEGER", true, 0),
            ExpectedColumn("updatedAt", "INTEGER", true, 0)
        ),
        "performances" to listOf(
            ExpectedColumn("id", "TEXT", true, 1),
            ExpectedColumn("amount", "REAL", true, 0),
            ExpectedColumn("note", "TEXT", true, 0),
            ExpectedColumn("date", "INTEGER", true, 0),
            ExpectedColumn("fingerprint", "TEXT", true, 0),
            ExpectedColumn("paymentMethod", "TEXT", true, 0),
            ExpectedColumn("orderNo", "TEXT", true, 0),
            ExpectedColumn("importSource", "TEXT", true, 0),
            ExpectedColumn("incomeSource", "TEXT", true, 0)
        ),
        "expenses" to listOf(
            ExpectedColumn("id", "TEXT", true, 1),
            ExpectedColumn("amount", "REAL", true, 0),
            ExpectedColumn("category", "TEXT", true, 0),
            ExpectedColumn("note", "TEXT", true, 0),
            ExpectedColumn("date", "INTEGER", true, 0),
            ExpectedColumn("createdAt", "INTEGER", true, 0)
        )
    )

    /**
     * 迁移后 7 表结构与 v2 实体定义逐列一致（列名/类型/NOT NULL/主键位置）。
     * 等价于 `MigrationTestHelper.runMigrationsAndValidate(..., validateDroppedTables = true)`
     * 的表结构校验，但不依赖导出的 schema JSON。
     */
    private fun assertV2Schema(db: SupportSQLiteDatabase) {
        for ((table, expected) in v2Schema) {
            val actual = TableInfo.read(db, table).columns
            assertEquals("[$table] 列数", expected.size, actual.size)
            for (c in expected) {
                assertTrue("[$table] 缺列 ${c.name}", actual.containsKey(c.name))
                val a = actual.getValue(c.name)
                assertEquals("[${table}.${c.name}] type", c.type, a.type)
                assertEquals("[${table}.${c.name}] notNull", c.notNull, a.notNull)
                assertEquals("[${table}.${c.name}] pk", c.pkPosition, a.primaryKeyPosition)
            }
        }
    }

    /** 升级后 App 可用 Room 正常打开并读出实体（端到端） */
    private fun assertRoomCanOpenAndRead(
        file: File,
        expectedMeituan: String,
        expectedManual: String
    ) {
        val roomDb = Room.databaseBuilder(context, XzgDatabase::class.java, file.absolutePath)
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
