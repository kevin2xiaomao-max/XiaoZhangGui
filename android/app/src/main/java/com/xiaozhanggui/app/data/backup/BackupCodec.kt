package com.xiaozhanggui.app.data.backup

import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.ExpenseEntity
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.TodoEntity
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.doubleOrNull
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.longOrNull
import kotlinx.serialization.json.put

/**
 * 备份编解码核心：实体列表 ↔ v2 JSON records。
 *
 * 从 BackupService 抽出（Phase 6 可测试性改造），纯 JVM 可测，不依赖 Context/DAO。
 * 编解码语义与原 BackupService.exportToJson/restore 逐行一致：
 * - 顶层：app / version / exportedAt / records；日期 epoch millis；图片 base64（imageBase64）
 * - 容忍 v1 备份（缺字段 → 安全默认）：todo completedAt、performance incomeSource、
 *   expiry returnStatus、customer status、expense/goods category
 * - 单条坏记录跳过，不中断整体恢复
 *
 * 图片读写仍由调用方注入（生产走 Context 文件；测试走内存假实现）。
 */
object BackupCodec {

    /** 一次备份/恢复的全部实体。 */
    data class BackupData(
        val todos: List<TodoEntity> = emptyList(),
        val memos: List<MemoEntity> = emptyList(),
        val performances: List<PerformanceEntity> = emptyList(),
        val expenses: List<ExpenseEntity> = emptyList(),
        val expiryItems: List<ExpiryItemEntity> = emptyList(),
        val customers: List<CustomerRequestEntity> = emptyList(),
        val goods: List<GoodsEntity> = emptyList()
    ) {
        fun totalCount(): Int =
            todos.size + memos.size + performances.size + expenses.size +
                    expiryItems.size + customers.size + goods.size
    }

    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    /** 编码为 v2 JSON 字符串。imageBase64Of：实体 imagePath → base64（无图返回 null）。 */
    fun encode(
        data: BackupData,
        exportedAt: Long,
        imageBase64Of: (String?) -> String? = { null }
    ): String {
        val records = mutableListOf<JsonObject>()
        for (t in data.todos) {
            records.add(buildJsonObject {
                put("type", "todo")
                put("title", t.title); put("detail", t.detail)
                put("priority", t.priority); put("isCompleted", t.isCompleted)
                put("createdAt", t.createdAt)
                t.dueDate?.let { put("dueDate", it) }
                t.completedAt?.let { put("completedAt", it) }
                imageBase64Of(t.imagePath)?.let { put("imageBase64", it) }
            })
        }
        for (m in data.memos) {
            records.add(buildJsonObject {
                put("type", "memo")
                put("title", m.title); put("content", m.content)
                put("createdAt", m.createdAt); put("updatedAt", m.updatedAt)
                imageBase64Of(m.imagePath)?.let { put("imageBase64", it) }
            })
        }
        for (p in data.performances) {
            records.add(buildJsonObject {
                put("type", "performance")
                put("amount", p.amount); put("note", p.note); put("date", p.date)
                put("fingerprint", p.fingerprint); put("paymentMethod", p.paymentMethod)
                put("orderNo", p.orderNo); put("importSource", p.importSource)
                put("incomeSource", p.incomeSource)
            })
        }
        for (e in data.expenses) {
            records.add(buildJsonObject {
                put("type", "expense")
                put("amount", e.amount); put("category", e.category)
                put("note", e.note); put("date", e.date); put("createdAt", e.createdAt)
            })
        }
        for (x in data.expiryItems) {
            records.add(buildJsonObject {
                put("type", "expiry")
                put("name", x.name); put("category", x.category); put("quantity", x.quantity)
                put("expiryDate", x.expiryDate); put("remindDaysBefore", x.remindDaysBefore)
                put("note", x.note); put("returnStatus", x.returnStatus)
                put("createdAt", x.createdAt)
                x.productionDate?.let { put("productionDate", it) }
                x.returnedAt?.let { put("returnedAt", it) }
                imageBase64Of(x.imagePath)?.let { put("imageBase64", it) }
            })
        }
        for (c in data.customers) {
            records.add(buildJsonObject {
                put("type", "customer")
                put("customer", c.customer) // 含 deliveryTime 编码串，round-trip 保留
                put("roomOrAddress", c.roomOrAddress); put("phone", c.phone)
                put("content", c.content); put("status", c.status)
                put("createdAt", c.createdAt); put("updatedAt", c.updatedAt)
                imageBase64Of(c.imagePath)?.let { put("imageBase64", it) }
            })
        }
        for (g in data.goods) {
            records.add(buildJsonObject {
                put("type", "goods")
                put("name", g.name); put("category", g.category); put("barcode", g.barcode)
                put("stock", g.stock); put("minStock", g.minStock)
                put("purchasePrice", g.purchasePrice); put("salePrice", g.salePrice)
                put("shelfLifeDays", g.shelfLifeDays); put("note", g.note)
                put("createdAt", g.createdAt); put("updatedAt", g.updatedAt)
                g.productionDate?.let { put("productionDate", it) }
                g.expiryDate?.let { put("expiryDate", it) }
                imageBase64Of(g.imagePath)?.let { put("imageBase64", it) }
            })
        }
        val root = buildJsonObject {
            put("app", "xiao-zhang-gui")
            put("version", BackupService.FORMAT_VERSION)
            put("exportedAt", exportedAt)
            put("records", JsonArray(records))
        }
        return json.encodeToString(JsonObject.serializer(), root)
    }

    /**
     * 解码 v2/v1 JSON → 实体列表。
     * writeImage：base64 → 新 imagePath（无图返回 null）。
     * 非法 JSON 抛 [BackupService.BackupError.InvalidFile]，缺 records 抛 InvalidRecords。
     */
    suspend fun decode(
        jsonText: String,
        writeImage: suspend (String?) -> String? = { null }
    ): BackupData {
        val root = try {
            json.parseToJsonElement(jsonText).jsonObject
        } catch (e: Exception) {
            throw BackupService.BackupError.InvalidFile()
        }
        val records = try {
            root["records"] as JsonArray
        } catch (e: Exception) {
            throw BackupService.BackupError.InvalidRecords()
        }
        val todos = mutableListOf<TodoEntity>()
        val memos = mutableListOf<MemoEntity>()
        val performances = mutableListOf<PerformanceEntity>()
        val expenses = mutableListOf<ExpenseEntity>()
        val expiryItems = mutableListOf<ExpiryItemEntity>()
        val customers = mutableListOf<CustomerRequestEntity>()
        val goods = mutableListOf<GoodsEntity>()
        for (el in records) {
            val o = el.jsonObject
            val type = o["type"]?.jsonPrimitive?.content ?: continue
            try {
                when (type) {
                    "todo" -> {
                        val exportedAt = root["exportedAt"]?.jsonPrimitive?.longOrNull
                            ?: System.currentTimeMillis()
                        todos.add(
                            TodoEntity(
                                title = o.str("title"),
                                detail = o.str("detail"),
                                dueDate = o.longOrNull("dueDate"),
                                priority = o.intOrNull("priority") ?: 0,
                                imagePath = writeImage(o.strOrNull("imageBase64")),
                                isCompleted = o.boolOrNull("isCompleted") ?: false,
                                // v1 容忍：completedAt 缺时用 exportedAt 补
                                completedAt = o.longOrNull("completedAt")
                                    ?: if (o.boolOrNull("isCompleted") == true) exportedAt else null,
                                createdAt = o.longOrNull("createdAt") ?: exportedAt
                            )
                        )
                    }
                    "memo" -> {
                        memos.add(
                            MemoEntity(
                                title = o.str("title"),
                                content = o.str("content"),
                                imagePath = writeImage(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                updatedAt = o.longOrNull("updatedAt") ?: System.currentTimeMillis()
                            )
                        )
                    }
                    "performance" -> {
                        val incomeSource = o.strOrNull("incomeSource") ?: ""
                        performances.add(
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
                    }
                    "expense" -> {
                        expenses.add(
                            ExpenseEntity(
                                amount = o.doubleOrNull("amount") ?: 0.0,
                                category = o.strOrNull("category")?.ifBlank { "其他" } ?: "其他",
                                note = o.str("note"),
                                date = o.longOrNull("date") ?: System.currentTimeMillis(),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis()
                            )
                        )
                    }
                    "expiry" -> {
                        val returnStatus = o.strOrNull("returnStatus") ?: ""
                        expiryItems.add(
                            ExpiryItemEntity(
                                name = o.str("name"),
                                category = o.str("category"),
                                quantity = o.intOrNull("quantity") ?: 1,
                                productionDate = o.longOrNull("productionDate"),
                                expiryDate = o.longOrNull("expiryDate") ?: System.currentTimeMillis(),
                                remindDaysBefore = o.intOrNull("remindDaysBefore") ?: 7,
                                note = o.str("note"),
                                imagePath = writeImage(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                returnStatus = if (returnStatus in setOf("待处理", "已退货")) returnStatus else "待处理",
                                returnedAt = o.longOrNull("returnedAt")
                            )
                        )
                    }
                    "customer" -> {
                        val status = o.strOrNull("status") ?: ""
                        customers.add(
                            CustomerRequestEntity(
                                customer = o.str("customer"),
                                roomOrAddress = o.str("roomOrAddress"),
                                phone = o.str("phone"),
                                content = o.str("content"),
                                imagePath = writeImage(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                updatedAt = o.longOrNull("updatedAt") ?: System.currentTimeMillis(),
                                status = if (status in setOf("待处理", "配送中", "已完成")) status else "待处理"
                            )
                        )
                    }
                    "goods" -> {
                        goods.add(
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
                                imagePath = writeImage(o.strOrNull("imageBase64")),
                                createdAt = o.longOrNull("createdAt") ?: System.currentTimeMillis(),
                                updatedAt = o.longOrNull("updatedAt") ?: System.currentTimeMillis()
                            )
                        )
                    }
                }
            } catch (e: Exception) {
                // 单条坏记录跳过，不中断整体恢复
            }
        }
        return BackupData(todos, memos, performances, expenses, expiryItems, customers, goods)
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
