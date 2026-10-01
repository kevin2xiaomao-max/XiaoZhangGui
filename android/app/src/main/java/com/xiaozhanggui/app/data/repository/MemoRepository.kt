package com.xiaozhanggui.app.data.repository

import com.xiaozhanggui.app.data.db.MemoDao
import com.xiaozhanggui.app.data.db.MemoEntity
import kotlinx.coroutines.flow.Flow

/**
 * 备忘 Repository。对应 iOS AppRepository.MemoRepository（AppRepository.swift:57-78）。
 * - add/update/delete 后 refreshAll，无通知副作用。
 * - update 刷新 updatedAt=now（GATE C：Memo 有 updatedAt，排序按 updatedAt 倒序）。
 * - 新增/更新时静默截断：title ≤100、content ≤2000（GATE C）。
 */
class MemoRepository(
    private val dao: MemoDao,
    private val refresher: SnapshotRefresher = NoopRefresher
) {
    companion object {
        const val MAX_TITLE = 100
        const val MAX_CONTENT = 2000
    }

    fun observeAll(): Flow<List<MemoEntity>> = dao.listAll()
    fun observeById(id: String): Flow<MemoEntity?> = dao.getById(id)

    suspend fun add(title: String, content: String, imagePath: String? = null): MemoEntity {
        val entity = MemoEntity(
            title = title.take(MAX_TITLE),
            content = content.take(MAX_CONTENT),
            imagePath = imagePath
        )
        dao.insert(entity)
        refresher.refreshAll()
        return entity
    }

    suspend fun update(memo: MemoEntity): MemoEntity {
        val updated = memo.copy(
            title = memo.title.take(MAX_TITLE),
            content = memo.content.take(MAX_CONTENT),
            updatedAt = System.currentTimeMillis()
        )
        dao.update(updated)
        refresher.refreshAll()
        return updated
    }

    suspend fun delete(memo: MemoEntity) {
        dao.delete(memo)
        refresher.refreshAll()
    }
}
