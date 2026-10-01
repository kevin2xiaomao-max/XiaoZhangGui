package com.xiaozhanggui.app.data.backup

import android.content.Context
import java.util.Base64
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.db.XzgDatabase
import com.xiaozhanggui.app.data.notification.NotificationScheduler
import com.xiaozhanggui.app.data.repository.SnapshotRefresher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.double
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put
import java.io.File
import java.util.UUID

/**
 * 备份服务。对应 iOS BackupService（Data/BackupService.swift）。
 *
 * - 文件：`xiao-zhang-gui-backup.json`，formatVersion=2
 * - 顶层：app / version / exportedAt / records
 * - 日期 epoch millis；图片 base64（imageBase64）
 * - 恢复为追加（不清空已有数据）；单次 save；通知重建；一次 refreshAll
 * - 容忍 v1 备份（缺字段 → 安全默认）
 * - 与 iOS 备份文件可互读
 */
class BackupService(
    private val context: Context,
    private val db: XzgDatabase,
    private val notifications: NotificationScheduler,
    private val refresher: SnapshotRefresher
) {
    companion object {
        const val FILE_NAME = "xiao-zhang-gui-backup.json"
        const val FORMAT_VERSION = 2
    }

    sealed class BackupError(message: String) : Exception(message) {
        class InvalidFile : BackupError("无法解析备份 JSON")
        class InvalidRecords : BackupError("备份缺少 records")
        class WriteFailed : BackupError("备份写入失败")
    }

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    private fun readImageBase64(imagePath: String?): String? {
        if (imagePath.isNullOrBlank()) return null
        return try {
            val f = File(context.filesDir, imagePath)
            if (!f.exists()) null
            else Base64.getEncoder().encodeToString(f.readBytes())
        } catch (e: Exception) {
            null
        }
    }

    private suspend fun writeImageBase64(base64: String?): String? {
        if (base64.isNullOrBlank()) return null
        return try {
            val bytes = Base64.getDecoder().decode(base64)
            val name = "img_${UUID.randomUUID()}.jpg"
            withContext(Dispatchers.IO) {
                File(context.filesDir, name).writeBytes(bytes)
            }
            name
        } catch (e: Exception) {
            null
        }
    }

    /** 导出全部数据为 v2 JSON 字符串 */
    suspend fun exportToJson(): String = withContext(Dispatchers.IO) {
        val records = mutableListOf<JsonObject>()
        val todos = db.todoDao().listAll().first()
        for (t in todos) {
            records.add(buildJsonObject {
                put("type", "todo")
                put("title", t.title); put("detail", t.detail)
                put("priority", t.priority); put("isCompleted", t.isCompleted)
                put("createdAt", t.createdAt)
                t.dueDate?.let { put("dueDate", it) }
                t.completedAt?.let { put("completedAt", it) }
                readImageBase64(t.imagePath)?.let { put("imageBase64", it) }
            })
        }
        val memos = db.memoDao().listAll().first()
        for (m in memos) {
            records.add(buildJsonObject {
                put("type", "memo")
                put("title", m.title); put("content", m.content)
                put("createdAt", m.createdAt); put("updatedAt", m.updatedAt)
                readImageBase64(m.imagePath)?.let { put("imageBase64", it) }
            })
        }
        val performances = db.performanceDao().listAll().first()
        for (p in performances) {
            records.add(buildJsonObject {
                put("type", "performance")
                put("amount", p.amount); put("note", p.note); put("date", p.date)
                put("fingerprint", p.fingerprint); put("paymentMethod", p.paymentMethod)
                put("orderNo", p.orderNo); put("importSource", p.importSource)
                put("incomeSource", p.incomeSource)
            })
        }
        val expenses = db.expenseDao().listAll().first()
        for (e in expenses) {
            records.add(buildJsonObject {
                put("type", "expense")
                put("amount", e.amount); put("category", e.category)
                put("note", e.note); put("date", e.date); put("createdAt", e.createdAt)
            })
        }
        val expiryItems = db.expiryItemDao().listAll().first()
        for (x in expiryItems) {
            records.add(buildJsonObject {
                put("type", "expiry")
                put("name", x.name); put("category", x.category); put("quantity", x.quantity)
                put("expiryDate", x.expiryDate); put("remindDaysBefore", x.remindDaysBefore)
                put("note", x.note); put("returnStatus", x.returnStatus)
                put("createdAt", x.createdAt)
                x.productionDate?.let { put("productionDate", it) }
                x.returnedAt?.let { put("returnedAt", it) }
                readImageBase64(x.imagePath)?.let { put("imageBase64", it) }
            })
        }
        val customers = db.customerRequestDao().listAll().first()
        for (c in customers) {
            records.add(buildJsonObject {
                put("type", "customer")
                put("customer", c.customer) // 含 deliveryTime 编码串，round-trip 保留
                put("roomOrAddress", c.roomOrAddress); put("phone", c.phone)
                put("content", c.content); put("status", c.status)
                put("createdAt", c.createdAt); put("updatedAt", c.updatedAt)
                readImageBase64(c.imagePath)?.let { put("imageBase64", it) }
            })
        }
        val goods = db.goodsDao().listAll().first()
        for (g in goods) {
            records.add(buildJsonObject {
                put("type", "goods")
                put("name", g.name); put("category", g.category); put("barcode", g.barcode)
                put("stock", g.stock); put("minStock", g.minStock)
                put("purchasePrice", g.purchasePrice); put("salePrice", g.salePrice)
                put("shelfLifeDays", g.shelfLifeDays); put("note", g.note)
                put("createdAt", g.createdAt); put("updatedAt", g.updatedAt)
                g.productionDate?.let { put("productionDate", it) }
                g.expiryDate?.let { put("expiryDate", it) }
                readImageBase64(g.imagePath)?.let { put("imageBase64", it) }
            })
        }
        val root = buildJsonObject {
            put("app", "xiao-zhang-gui")
            put("version", FORMAT_VERSION)
            put("exportedAt", System.currentTimeMillis())
            put("records", JsonArray(records))
        }
        json.encodeToString(root)
    }

    suspend fun exportToFile(): File = withContext(Dispatchers.IO) {
        try {
            val file = File(context.getExternalFilesDir(null), FILE_NAME)
            file.writeText(exportToJson())
            file
        } catch (e: Exception) {
            throw BackupError.WriteFailed()
        }
    }

    /**
     * 恢复（追加，不清空已有数据）。
     * 返回恢复的记录数。
     */
    suspend fun restore(jsonText: String): Int = withContext(Dispatchers.IO) {
        val root = try {
            json.parseToJsonElement(jsonText).jsonObject
        } catch (e: Exception) {
            throw BackupError.InvalidFile()
        }
        val records = try {
            root["records"] as JsonArray
        } catch (e: Exception) {
            throw BackupError.InvalidRecords()
        }
        var count = 0
        // 绕过 Repository，直接构造 Entity 批量 insert（对应 iOS BackupService.restore）
        for (el in records) {
            val o = el.jsonObject
            val type = o["type"]?.jsonPrimitive?.content ?: continue
            try {
                when (type) {
                    "todo" -> {
                        val exportedAt = root["exportedAt"]?.jsonPrimitive?.longOrNull
                            ?: System.currentTimeMillis()
                        db.todoDao().insert(
                            TodoEntity(
                                title = o.str("title"),
                                detail = o.str("detail"),
                                dueDate = o.longOrNull("dueDate"),
                                priority = o.intOrNull("priority") ?: 0,
                                imagePath = writeImageBase64(o.strOrNull("imageBase64")),
                                isCompleted = o.boolOrNull("isCompleted") ?: false,
                                // v1 容忍：completedAt 缺时用 exportedAt 补
                                completedAt = o.longOrNull("completedAt")
                                    ?: if (o.boolOrNull("isCompleted") == true) exportedAt else null,
                                createdAt = o.longOrNull("createdAt") ?: exportedAt
                            )
                        )
                        count++
                    }
                    "memo" -> {
                        db.memoDao().insert(
                            MemoEntity(
                                title = o.str("title"),
                                content = o.str("content"),
                                imagePath = writeImageBase64(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                updatedAt = o.longOrNull("updatedAt") ?: System.currentTimeMillis()
                            )
                        )
                        count++
                    }
                    "performance" -> {
                        val incomeSource = o.strOrNull("incomeSource") ?: ""
                        db.performanceDao().insert(
                            PerformanceEntity(
                                amount = o.doubleOrNull("amount") ?: 0.0,
                                note = o.str("note"),
                                date = o.longOrNull("date") ?: System.currentTimeMillis(),
                                fingerprint = o.str("fingerprint"),
                                paymentMethod = o.str("paymentMethod"),
                                orderNo = o.str("orderNo"),
                                importSource = o.str("importSource"),
                                // v1 容忍：incomeSource 非法 → "门店"
                                incomeSource = if (incomeSource in setOf("门店", "美团", "其他")) incomeSource else "门店"
                            )
                        )
                        count++
                    }
                    "expense" -> {
                        db.expenseDao().insert(
                            ExpenseEntity(
                                amount = o.doubleOrNull("amount") ?: 0.0,
                                category = o.strOrNull("category")?.ifBlank { "其他" } ?: "其他",
                                note = o.str("note"),
                                date = o.longOrNull("date") ?: System.currentTimeMillis(),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis()
                            )
                        )
                        count++
                    }
                    "expiry" -> {
                        val returnStatus = o.strOrNull("returnStatus") ?: ""
                        db.expiryItemDao().insert(
                            ExpiryItemEntity(
                                name = o.str("name"),
                                category = o.str("category"),
                                quantity = o.intOrNull("quantity") ?: 1,
                                productionDate = o.longOrNull("productionDate"),
                                expiryDate = o.longOrNull("expiryDate") ?: System.currentTimeMillis(),
                                remindDaysBefore = o.intOrNull("remindDaysBefore") ?: 7,
                                note = o.str("note"),
                                imagePath = writeImageBase64(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                returnStatus = if (returnStatus in setOf("待处理", "已退货")) returnStatus else "待处理",
                                returnedAt = o.longOrNull("returnedAt")
                            )
                        )
                        count++
                    }
                    "customer" -> {
                        val status = o.strOrNull("status") ?: ""
                        db.customerRequestDao().insert(
                            CustomerRequestEntity(
                                customer = o.str("customer"),
                                roomOrAddress = o.str("roomOrAddress"),
                                phone = o.str("phone"),
                                content = o.str("content"),
                                imagePath = writeImageBase64(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                updatedAt = o.longOrNull("updatedAt") ?: System.currentTimeMillis(),
                                status = if (status in setOf("待处理", "配送中", "已完成")) status else "待处理"
                            )
                        )
                        count++
                    }
                    "goods" -> {
                        db.goodsDao().insert(
                            GoodsEntity(
                                name = o.str("name"),
                                category = o.strOrNull("category")?.ifBlank { "其他" } ?: "其他",
                                barcode = o.str("barcode"),
                                stock = o.intOrNull("stock") ?: 0,
                                minStock = o.intOrNull("minStock") ?: 0,
                                purchasePrice = o.doubleOrNull("purchasePrice") ?: 0.0,
                                salePrice = o.doubleOrNull("salePrice") ?: 0.0,
                                productionDate = o.longOrNull("productionDate"),
                                shelfLifeDays = o.intOrNull("shelfLifeDays") ?: 0,
                                expiryDate = o.longOrNull("expiryDate"),
                                note = o.str("note"),
                                imagePath = writeImageBase64(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                updatedAt = o.longOrNull("updatedAt") ?: System.currentTimeMillis()
                            )
                        )
                        count++
                    }
                }
            } catch (e: Exception) {
                // 单条坏记录跳过，不中断整体恢复
            }
        }
        // 统一重建通知 + 一次快照刷新（对应 iOS restore 语义）
        rebuildAllNotifications()
        refresher.refreshAll()
        count
    }

    /** 恢复后统一重建所有通知 */
    private suspend fun rebuildAllNotifications() {
        for (t in db.todoDao().listAll().first()) notifications.scheduleTodo(t)
        for (x in db.expiryItemDao().listAll().first()) notifications.scheduleExpiry(x)
        for (c in db.customerRequestDao().listAll().first()) notifications.rescheduleCustomer(c)
    }

    // ---- JsonObject helpers ----
    private fun JsonObject.str(key: String): String =
        this[key]?.jsonPrimitive?.content ?: ""

    private fun JsonObject.strOrNull(key: String): String? =
        try { this[key]?.jsonPrimitive?.content } catch (e: Exception) { null }

    private fun JsonObject.longOrNull(key: String): Long? =
        try { this[key]?.jsonPrimitive?.longOrNull } catch (e: Exception) { null }

    private fun JsonObject.intOrNull(key: String): Int? =
        try { this[key]?.jsonPrimitive?.content?.toIntOrNull() } catch (e: Exception) { null }

    private fun JsonObject.doubleOrNull(key: String): Double? =
        try { this[key]?.jsonPrimitive?.doubleOrNull } catch (e: Exception) { null }

    private fun JsonObject.boolOrNull(key: String): Boolean? =
        try {
            this[key]?.jsonPrimitive?.content?.toBooleanStrictOrNull()
        } catch (e: Exception) { null }
}
