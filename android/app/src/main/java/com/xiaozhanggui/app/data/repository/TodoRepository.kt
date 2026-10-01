package com.xiaozhanggui.app.data.repository

import com.xiaozhanggui.app.data.db.TodoDao
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import kotlinx.coroutines.flow.Flow

/**
 * 待办 Repository。对应 iOS AppRepository.TodoRepository（AppRepository.swift:14-55）。
 *
 * 副作用（每次成功后）：
 * - add → scheduleTodo + refreshAll
 * - update → cancelTodo + scheduleTodo（重排）+ refreshAll
 * - toggleComplete → 完成时 completedAt=now 并 cancelTodo；取消完成时 completedAt=nil 并 scheduleTodo + refreshAll
 * - delete → cancelTodo + refreshAll
 *
 * 注意：Todo 无 updatedAt 字段（GATE C），update 不写时间戳。
 */
class TodoRepository(
    private val dao: TodoDao,
    private val notifications: NotificationScheduler,
    private val refresher: SnapshotRefresher = NoopRefresher
) {
    fun observeAll(): Flow<List<TodoEntity>> = dao.listAll()
    fun observeById(id: String): Flow<TodoEntity?> = dao.getById(id)

    suspend fun add(
        title: String,
        detail: String = "",
        dueDate: Long? = null,
        priority: Int = 0,
        imagePath: String? = null
    ): TodoEntity {
        val entity = TodoEntity(
            title = title,
            detail = detail,
            dueDate = dueDate,
            priority = priority,
            imagePath = imagePath
        )
        dao.insert(entity)
        notifications.scheduleTodo(entity)
        refresher.refreshAll()
        return entity
    }

    suspend fun update(todo: TodoEntity) {
        dao.update(todo)
        notifications.cancelTodo(todo)
        notifications.scheduleTodo(todo)
        refresher.refreshAll()
    }

    suspend fun toggleComplete(todo: TodoEntity): TodoEntity {
        val updated = todo.copy(
            isCompleted = !todo.isCompleted,
            completedAt = if (!todo.isCompleted) System.currentTimeMillis() else null
        )
        dao.update(updated)
        if (updated.isCompleted) {
            notifications.cancelTodo(updated)
        } else {
            notifications.scheduleTodo(updated)
        }
        refresher.refreshAll()
        return updated
    }

    suspend fun delete(todo: TodoEntity) {
        notifications.cancelTodo(todo)
        dao.delete(todo)
        refresher.refreshAll()
    }
}
