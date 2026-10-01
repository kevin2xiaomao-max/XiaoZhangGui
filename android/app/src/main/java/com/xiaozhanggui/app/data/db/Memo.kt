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

/**
 * 备忘（导航标题"记录"）。对应 iOS `Memo`（Models/Memo.swift）。
 * 排序按 updatedAt 倒序；卡片色条索引 = (createdAt 秒 % 3)。
 */
@Entity(tableName = "memos")
data class MemoEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val title: String = "",
    val content: String = "",
    val imagePath: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)

@Dao
interface MemoDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: MemoEntity)

    @Update
    suspend fun update(entity: MemoEntity)

    @Delete
    suspend fun delete(entity: MemoEntity)

    @Query("SELECT * FROM memos WHERE id = :id")
    fun getById(id: String): Flow<MemoEntity?>

    @Query("SELECT * FROM memos ORDER BY updatedAt DESC")
    fun listAll(): Flow<List<MemoEntity>>
}
