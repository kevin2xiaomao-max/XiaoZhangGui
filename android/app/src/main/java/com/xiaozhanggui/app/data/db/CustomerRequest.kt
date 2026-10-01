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

/** 客户需求状态机（对应 iOS CustomerStatus）：待处理 → 配送中 → 已完成 */
object CustomerStatus {
    const val PENDING = "待处理"
    const val DELIVERING = "配送中"
    const val DONE = "已完成"

    fun next(status: String): String = when (status) {
        PENDING -> DELIVERING
        DELIVERING -> DONE
        else -> DONE
    }
}

/**
 * 客户需求。对应 iOS `CustomerRequest`（Models/ExpiryItem.swift:63）。
 *
 * ⚠️ 关键语义：`customer` 字段是编码串 `xzg-delivery-v1:<base64(JSON)>`，
 * JSON 内含 deliveryTime / note / legacyCustomer（见 B_data.md §1.3）。
 * 展示层必须解码隐藏编码串；日历按解码出的 deliveryTime 聚类。
 * 编解码逻辑在 Phase 2 的 Repository 层实现，此处原样存储。
 */
@Entity(tableName = "customer_requests")
data class CustomerRequestEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val customer: String = "",
    val roomOrAddress: String = "",
    val phone: String = "",
    val content: String = "",
    val status: String = CustomerStatus.PENDING,
    val imagePath: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val notificationId: String = UUID.randomUUID().toString()
)

@Dao
interface CustomerRequestDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: CustomerRequestEntity)

    @Update
    suspend fun update(entity: CustomerRequestEntity)

    @Delete
    suspend fun delete(entity: CustomerRequestEntity)

    @Query("SELECT * FROM customer_requests WHERE id = :id")
    fun getById(id: String): Flow<CustomerRequestEntity?>

    @Query("SELECT * FROM customer_requests ORDER BY createdAt DESC")
    fun listAll(): Flow<List<CustomerRequestEntity>>
}
