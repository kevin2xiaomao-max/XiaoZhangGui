package com.xiaozhanggui.app

import com.xiaozhanggui.app.data.db.MigrationSql
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * `MIGRATION_1_2` 决策逻辑的 JVM 单元测试（纯函数，不依赖 Android 框架）。
 *
 * 真机语义（见 `Migrations.kt`）：V3.6 实体自首个提交即带 `incomeSource` 字段，
 * 真实设备 v1 库已有该列 → 迁移必须为防御式 add-if-missing，否则覆盖安装时
 * SQLite 报 "duplicate column name" 导致升级崩溃。
 */
class MigrationSqlTest {

    private val columnDef = "`incomeSource` TEXT NOT NULL DEFAULT ''"

    @Test
    fun `缺列时返回标准 ALTER 语句`() {
        val sql = MigrationSql.addColumnIfMissing(
            existingColumns = setOf("id", "amount", "note"),
            table = "performances",
            column = "incomeSource",
            columnDef = columnDef
        )
        assertEquals(
            "ALTER TABLE performances ADD COLUMN `incomeSource` TEXT NOT NULL DEFAULT ''",
            sql
        )
    }

    @Test
    fun `列已存在时返回 null（真实 V3_6 设备库场景，不执行 DDL）`() {
        val sql = MigrationSql.addColumnIfMissing(
            existingColumns = setOf("id", "amount", "note", "incomeSource"),
            table = "performances",
            column = "incomeSource",
            columnDef = columnDef
        )
        assertNull(sql)
    }

    @Test
    fun `列名比对大小写不敏感`() {
        assertNull(
            MigrationSql.addColumnIfMissing(
                existingColumns = setOf("INCOMESOURCE"),
                table = "performances",
                column = "incomeSource",
                columnDef = columnDef
            )
        )
    }

    @Test
    fun `空列集合时返回 ALTER（表不存在等异常场景仍尝试补列）`() {
        val sql = MigrationSql.addColumnIfMissing(
            existingColumns = emptySet(),
            table = "performances",
            column = "incomeSource",
            columnDef = columnDef
        )
        assertEquals(
            "ALTER TABLE performances ADD COLUMN `incomeSource` TEXT NOT NULL DEFAULT ''",
            sql
        )
    }
}
