package com.xiaozhanggui.app.data.db

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow
import java.util.UUID

/** 收入来源（对应 iOS IncomeSource）：门店 / 美团 / 其他 */
object IncomeSource {
    const val STORE = "门店"
    const val MEITUAN = "美团"
    const val OTHER = "其他"

    /** 对应 iOS IncomeSource.from(note:)：note 含"美团"→美团；含"门店"/"到店"→门店；其余→其他 */
    fun fromNote(note: String): String {
        val n = note.trim()
        return when {
            n.contains("美团") -> MEITUAN
            n.contains("门店") || n.contains("到店") -> STORE
            else -> OTHER
        }
    }
}

/**
 * 营业额记录。对应 iOS `Performance`（Models/Money.swift）。
 * 注意：用 `date`（业务发生日期）做统计，而非 createdAt；本表**没有** createdAt。
 * fingerprint 为空字符串 = 手工记录；扫呗导入的 fingerprint 为 SHA-256 hex。
 */
@Entity(tableName = "performances")
data class PerformanceEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val amount: Double = 0.0,
    val note: String = "",
    /** 业务发生日期 epoch millis */
    val date: Long = System.currentTimeMillis(),
    val fingerprint: String = "",
    val paymentMethod: String = "",
    val orderNo: String = "",
    val importSource: String = "",
    val incomeSource: String = ""
)

/** 支出分类（对应 iOS MoneyEditorSheet）：进货 / 房租 / 水电 / 人工 / 其他 */
object ExpenseCategory {
    const val STOCK = "进货"
    const val RENT = "房租"
    const val UTILITY = "水电"
    const val LABOR = "人工"
    const val OTHER = "其他"
    val ALL = listOf(STOCK, RENT, UTILITY, LABOR, OTHER)
}

/**
 * 支出记录。对应 iOS `Expense`（Models/Money.swift:39）。
 */
@Entity(tableName = "expenses")
data class ExpenseEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val amount: Double = 0.0,
    val category: String = ExpenseCategory.OTHER,
    val note: String = "",
    /** 业务发生日期 epoch millis */
    val date: Long = System.currentTimeMillis(),
    val createdAt: Long = System.currentTimeMillis()
)

@Dao
interface PerformanceDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: PerformanceEntity)

    @Update
    suspend fun update(entity: PerformanceEntity)

    @Delete
    suspend fun delete(entity: PerformanceEntity)

    @Query("SELECT * FROM performances WHERE id = :id")
    fun getById(id: String): Flow<PerformanceEntity?>

    @Query("SELECT * FROM performances ORDER BY date DESC")
    fun listAll(): Flow<List<PerformanceEntity>>

    /** 扫呗去重：全库非空 fingerprint 集合（对应 iOS importSaobei 的 seen 集初始化） */
    @Query("SELECT fingerprint FROM performances WHERE fingerprint != ''")
    suspend fun allFingerprints(): List<String>
}

@Dao
interface ExpenseDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: ExpenseEntity)

    @Update
    suspend fun update(entity: ExpenseEntity)

    @Delete
    suspend fun delete(entity: ExpenseEntity)

    @Query("SELECT * FROM expenses WHERE id = :id")
    fun getById(id: String): Flow<ExpenseEntity?>

    @Query("SELECT * FROM expenses ORDER BY date DESC")
    fun listAll(): Flow<List<ExpenseEntity>>
}
