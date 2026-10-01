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
 * 待办。对应 iOS `Todo`（Models/Todo.swift）。
 * 注意：Todo 有意**没有** updatedAt 字段（与 iOS 保持一致，见 B_data.md §1.1）。
 * 图片走外部文件存储（对应 iOS @Attribute(.externalStorage)），Room 只存相对路径。
 */
@Entity(tableName = "todos")
data class TodoEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val title: String = "",
    val detail: String = "",
    /** 截止时间 epoch millis；null = 无截止 */
    val dueDate: Long? = null,
    /** 0 低 / 1 中 / 2 高（TodoPriority） */
    val priority: Int = 0,
    /** 附件图片在 app files dir 下的相对路径；null = 无图 */
    val imagePath: String? = null,
    val isCompleted: Boolean = false,
    val completedAt: Long? = null,
    val createdAt: Long = System.currentTimeMillis(),
    /** 通知稳定标识，UUID v4 */
    val notificationId: String = UUID.randomUUID().toString()
)

@Dao
interface TodoDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(entity: TodoEntity)

    @Update
    suspend fun update(entity: TodoEntity)

    @Delete
    suspend fun delete(entity: TodoEntity)

    @Query("SELECT * FROM todos WHERE id = :id")
    fun getById(id: String): Flow<TodoEntity?>

    @Query("SELECT * FROM todos ORDER BY createdAt DESC")
    fun listAll(): Flow<List<TodoEntity>>
}
