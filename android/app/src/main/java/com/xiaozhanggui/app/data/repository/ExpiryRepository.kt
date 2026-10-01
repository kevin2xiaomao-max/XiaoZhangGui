package com.xiaozhanggui.app.data.repository

import com.xiaozhanggui.app.data.db.ExpiryItemDao
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import kotlinx.coroutines.flow.Flow

/**
 * 临期 Repository。对应 iOS AppRepository.ExpiryRepository（AppRepository.swift:190-233）。
 *
 * - add → scheduleExpiry + refreshAll
 * - update → cancelExpiry + scheduleExpiry（重排）+ refreshAll
 * - toggleReturn → pending↔returned 切换；returned 时 returnedAt=now 并 cancelExpiry，
 *   恢复 pending 时 returnedAt=nil 并 scheduleExpiry + refreshAll
 * - delete → cancelExpiry + refreshAll
 *
 * 注意：remindDaysBefore 只用于通知，不参与分组（GATE 业务语义）。
 */
class ExpiryRepository(
    private val dao: ExpiryItemDao,
    private val notifications: NotificationScheduler,
    private val refresher: SnapshotRefresher = NoopRefresher
) {
    fun observeAll(): Flow<List<ExpiryItemEntity>> = dao.listAll()
    fun observeById(id: String): Flow<ExpiryItemEntity?> = dao.getById(id)

    suspend fun add(
        name: String,
        category: String = "",
        quantity: Int = 1,
        productionDate: Long? = null,
        expiryDate: Long = System.currentTimeMillis(),
        remindDaysBefore: Int = 7,
        note: String = "",
        imagePath: String? = null
    ): ExpiryItemEntity {
        val entity = ExpiryItemEntity(
            name = name,
            category = category,
            quantity = quantity,
            productionDate = productionDate,
            expiryDate = expiryDate,
            remindDaysBefore = remindDaysBefore,
            note = note,
            imagePath = imagePath
        )
        dao.insert(entity)
        notifications.scheduleExpiry(entity)
        refresher.refreshAll()
        return entity
    }

    suspend fun update(item: ExpiryItemEntity) {
        dao.update(item)
        notifications.cancelExpiry(item)
        notifications.scheduleExpiry(item)
        refresher.refreshAll()
    }

    suspend fun toggleReturn(item: ExpiryItemEntity): ExpiryItemEntity {
        val toReturned = item.returnStatus != ReturnStatus.RETURNED
        val updated = item.copy(
            returnStatus = if (toReturned) ReturnStatus.RETURNED else ReturnStatus.PENDING,
            returnedAt = if (toReturned) System.currentTimeMillis() else null
        )
        dao.update(updated)
        if (toReturned) {
            notifications.cancelExpiry(updated)
        } else {
            notifications.scheduleExpiry(updated)
        }
        refresher.refreshAll()
        return updated
    }

    suspend fun delete(item: ExpiryItemEntity) {
        notifications.cancelExpiry(item)
        dao.delete(item)
        refresher.refreshAll()
    }
}
