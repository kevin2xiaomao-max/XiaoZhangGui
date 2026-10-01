package com.xiaozhanggui.app.data.db

import androidx.room.Database
import androidx.room.RoomDatabase

/**
 * 你的小掌柜 Room 数据库。对应 iOS SwiftData ModelContainer（7 @Model）。
 * version 1 = V3.6 基线；后续 schema 变更必须加 Migration（禁止 fallbackToDestructiveMigration）。
 */
@Database(
    entities = [
        TodoEntity::class,
        ExpiryItemEntity::class,
        CustomerRequestEntity::class,
        GoodsEntity::class,
        MemoEntity::class,
        PerformanceEntity::class,
        ExpenseEntity::class
    ],
    version = 1,
    exportSchema = false
)
abstract class XzgDatabase : RoomDatabase() {
    abstract fun todoDao(): TodoDao
    abstract fun expiryItemDao(): ExpiryItemDao
    abstract fun customerRequestDao(): CustomerRequestDao
    abstract fun goodsDao(): GoodsDao
    abstract fun memoDao(): MemoDao
    abstract fun performanceDao(): PerformanceDao
    abstract fun expenseDao(): ExpenseDao
}
