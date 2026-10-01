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

/** 退货状态字符串（对应 iOS ReturnStatus）：pending="待处理"，returned="已退货" */
object ReturnStatus {
    const val PENDING = "待处理"
    const val RETURNED = "已退货"
}

/**
 * 临期/退货商品。对应 iOS `ExpiryItem`（Models/ExpiryItem.swift）。
 * daysLeft 按"到期日 0 点 - 参考日 0 点"整天数计算（业务层实现，此处只存原始值）。
 */
@Entity(tableName = "expiry_items")
data class ExpiryItemEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val category: String = "",
    val quantity: Int = 1,
    val productionDate: Long? = null,
    val expiryDate: Long = System.currentTimeMillis(),
    val remindDaysBefore: Int = 7,
    val note: String = "",
    val imagePath: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val returnStatus: String = ReturnStatus.PENDING,
    val returnedAt: Long? = null,
    val notificationId: String = UUID.randomUUID().toString()
)

@Dao
interface ExpiryItemDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: ExpiryItemEntity)

    @Update
    suspend fun update(entity: ExpiryItemEntity)

    @Delete
    suspend fun delete(entity: ExpiryItemEntity)

    @Query("SELECT * FROM expiry_items WHERE id = :id")
    fun getById(id: String): Flow<ExpiryItemEntity?>

    @Query("SELECT * FROM expiry_items ORDER BY expiryDate ASC")
    fun listAll(): Flow<List<ExpiryItemEntity>>
}
