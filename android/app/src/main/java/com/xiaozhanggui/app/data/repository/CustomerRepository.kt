package com.xiaozhanggui.app.data.repository

import com.xiaozhanggui.app.data.db.CustomerRequestDao
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import kotlinx.coroutines.flow.Flow

/**
 * 客户需求 Repository。对应 iOS AppRepository.CustomerRepository（AppRepository.swift:235-292）。
 *
 * - add(customer 传已 encode 的串）→ rescheduleCustomer + refreshAll
 * - update → updatedAt=now；rescheduleCustomer（编辑后统一重排）+ refreshAll
 * - advanceStatus → status=next，updatedAt=now；prev==pending → cancelCustomer；
 *   进入 done 不排通知 + refreshAll
 * - delete → cancelCustomer（全部后缀）+ refreshAll
 */
class CustomerRepository(
    private val dao: CustomerRequestDao,
    private val notifications: NotificationScheduler,
    private val refresher: SnapshotRefresher = NoopRefresher
) {
    fun observeAll(): Flow<List<CustomerRequestEntity>> = dao.listAll()
    fun observeById(id: String): Flow<CustomerRequestEntity?> = dao.getById(id)

    suspend fun add(
        customer: String, // 已 encode 的串（xzg-delivery-v1:...）或纯旧数据明文
        roomOrAddress: String = "",
        phone: String = "",
        content: String,
        imagePath: String? = null
    ): CustomerRequestEntity {
        val entity = CustomerRequestEntity(
            customer = customer,
            roomOrAddress = roomOrAddress,
            phone = phone,
            content = content,
            imagePath = imagePath
        )
        dao.insert(entity)
        notifications.rescheduleCustomer(entity)
        refresher.refreshAll()
        return entity
    }

    suspend fun update(request: CustomerRequestEntity): CustomerRequestEntity {
        val updated = request.copy(updatedAt = System.currentTimeMillis())
        dao.update(updated)
        notifications.rescheduleCustomer(updated)
        refresher.refreshAll()
        return updated
    }

    suspend fun advanceStatus(request: CustomerRequestEntity): CustomerRequestEntity {
        val prev = request.status
        val updated = request.copy(
            status = CustomerStatus.next(request.status),
            updatedAt = System.currentTimeMillis()
        )
        dao.update(updated)
        if (prev == CustomerStatus.PENDING) {
            // 离开 pending 立即取消跟进通知
            notifications.cancelCustomer(updated)
        }
        // 进入 done 不排通知（delivering 保持无通知，与 iOS 一致）
        refresher.refreshAll()
        return updated
    }

    suspend fun delete(request: CustomerRequestEntity) {
        notifications.cancelCustomer(request)
        dao.delete(request)
        refresher.refreshAll()
    }
}
