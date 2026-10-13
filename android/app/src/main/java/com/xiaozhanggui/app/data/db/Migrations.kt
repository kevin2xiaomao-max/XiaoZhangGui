package com.xiaozhanggui.app.data.db

import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

/**
 * V3.7.1 schema 迁移：version 1 → 2。
 *
 * 变更内容：`performances` 表新增 `incomeSource` 列
 *（`ALTER TABLE performances ADD COLUMN incomeSource TEXT NOT NULL DEFAULT ''`）。
 *
 * ⚠️ 防御式写法的原因：`incomeSource` 字段自 Android 工程首个提交
 *（`70849e4`）即存在于 `PerformanceEntity`，真实 V3.6 设备上的 v1 库
 ***已经包含该列**。若无条件执行 ADD COLUMN，覆盖安装升级时 SQLite 会报
 * "duplicate column name: incomeSource" 导致启动崩溃。因此先查
 * `PRAGMA table_info`，仅缺列时才执行 ADD COLUMN。
 *
 * Room 校验安全性：实体未声明 `@ColumnInfo(defaultValue=...)`，Room 2.6.1
 * `TableInfo.Column.equals` 仅在实体侧定义了 defaultValue 时才比较
 *（b/136019383），`DEFAULT ''` 不影响 `runMigrationsAndValidate`。
 *
 * 禁区：禁止 `fallbackToDestructiveMigration`（见 §5 破坏性风险）。
 */
object MigrationSql {
    /**
     * 纯函数：给定已存在的列名集合，返回需要执行的 ADD COLUMN 语句；
     * 列已存在则返回 null。列名比对大小写不敏感。JVM 可单元测试。
     */
    fun addColumnIfMissing(
        existingColumns: Set<String>,
        table: String,
        column: String,
        columnDef: String
    ): String? {
        val lower = existingColumns.map { it.lowercase() }.toSet()
        return if (column.lowercase() !in lower) {
            "ALTER TABLE $table ADD COLUMN $columnDef"
        } else {
            null
        }
    }
}

/** 读取表的现有列名（`PRAGMA table_info`）。 */
internal fun SupportSQLiteDatabase.existingColumns(table: String): Set<String> {
    val cols = mutableSetOf<String>()
    query("PRAGMA table_info(`$table`)").use { c ->
        val nameIdx = c.getColumnIndex("name")
        while (c.moveToNext()) {
            cols.add(c.getString(nameIdx))
        }
    }
    return cols
}

/** version 1 → 2：`performances.incomeSource` 缺列时补列（防御式，见上）。 */
val MIGRATION_1_2 = object : Migration(1, 2) {
    override fun migrate(db: SupportSQLiteDatabase) {
        MigrationSql.addColumnIfMissing(
            existingColumns = db.existingColumns("performances"),
            table = "performances",
            column = "incomeSource",
            columnDef = "`incomeSource` TEXT NOT NULL DEFAULT ''"
        )?.let { db.execSQL(it) }
    }
}
