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

/** 商品分类（对应 iOS GoodsModel 已知分类）：饮料 / 零食 / 日用品 / 烟酒 / 其他 */
object GoodsCategory {
    const val DRINK = "饮料"
    const val SNACK = "零食"
    const val DAILY = "日用品"
    const val TOBACCO = "烟酒"
    const val OTHER = "其他"
    val ALL = listOf(DRINK, SNACK, DAILY, TOBACCO, OTHER)
}

/**
 * 临时商品。对应 iOS `Goods`（Models/Goods.swift）。
 * 状态判定优先级（GoodsState）：已过期 > 即将到期(7天内) > 库存不足(stock<=minStock) > 正常。
 */
@Entity(tableName = "goods")
data class GoodsEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String = "",
    val category: String = GoodsCategory.OTHER,
    val barcode: String = "",
    val stock: Int = 0,
    val minStock: Int = 0,
    val purchasePrice: Double = 0.0,
    val salePrice: Double = 0.0,
    val productionDate: Long? = null,
    val shelfLifeDays: Int = 0,
    val expiryDate: Long? = null,
    val note: String = "",
    val imagePath: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Dao
interface GoodsDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: GoodsEntity)

    @Update
    suspend fun update(entity: GoodsEntity)

    @Delete
    suspend fun delete(entity: GoodsEntity)

    @Query("SELECT * FROM goods WHERE id = :id")
    fun getById(id: String): Flow<GoodsEntity?>

    @Query("SELECT * FROM goods ORDER BY createdAt DESC")
    fun listAll(): Flow<List<GoodsEntity>>
}
