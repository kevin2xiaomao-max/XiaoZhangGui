package com.xiaozhanggui.app.data.demo

import com.xiaozhanggui.app.data.db.CustomerRequestDao
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.db.ExpiryItemDao
import com.xiaozhanggui.app.data.db.ExpiryItemEntity
import com.xiaozhanggui.app.data.db.MemoDao
import com.xiaozhanggui.app.data.db.MemoEntity
import com.xiaozhanggui.app.data.db.PerformanceDao
import com.xiaozhanggui.app.data.db.PerformanceEntity
import com.xiaozhanggui.app.data.db.ReturnStatus
import com.xiaozhanggui.app.data.db.TodoDao
import com.xiaozhanggui.app.data.db.TodoEntity
import com.xiaozhanggui.app.data.db.XzgDatabase
import com.xiaozhanggui.app.domain.CustomerDeliveryInfo
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import java.util.Calendar

/**
 * 演示种子数据。对应 iOS `Demo/DemoMode.swift` 的 `DemoCatalog`
 *（内存容器 + seed：经营/待办/客户配送/临期/备忘五类样本）。
 *
 * ⚠️ 红线：只允许写入**演示模式的内存库**。生产代码路径（XzgGraph 的磁盘库分支、
 * Repository、备份/导入）绝不调用这里；种子内容与 iOS DemoCatalog 逐项对齐，
 * 包括今日/昨日营业额断言口径（见 DemoCatalogTest）。
 */
object DemoCatalog {

    /** 演示写入目标：5 张表的 DAO。生产调用传真实 DAO，测试可传 fake。 */
    data class SeedDaos(
        val todo: TodoDao,
        val expiry: ExpiryItemDao,
        val customer: CustomerRequestDao,
        val memo: MemoDao,
        val performance: PerformanceDao
    )

    /** 便捷入口：向给定数据库写入全部种子。 */
    suspend fun seed(db: XzgDatabase) {
        seed(
            SeedDaos(
                todo = db.todoDao(),
                expiry = db.expiryItemDao(),
                customer = db.customerRequestDao(),
                memo = db.memoDao(),
                performance = db.performanceDao()
            )
        )
    }

    /** 写入全部种子（now 可注入，便于测试断言；默认当前时间）。 */
    suspend fun seed(daos: SeedDaos, now: Long = System.currentTimeMillis()) {
        seedPerformances(daos.performance, now)
        seedTodos(daos.todo, now)
        seedDeliveries(daos.customer, now)
        seedExpiry(daos.expiry, now)
        seedMemos(daos.memo, now)
    }

    // ---------- 日期工具（对应 iOS DemoCatalog.day） ----------

    private fun day(offset: Int, hour: Int, minute: Int, now: Long): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = now
        cal.set(Calendar.HOUR_OF_DAY, 0)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        cal.add(Calendar.DAY_OF_YEAR, offset)
        cal.set(Calendar.HOUR_OF_DAY, hour)
        cal.set(Calendar.MINUTE, minute)
        return cal.timeInMillis
    }

    // ---------- 经营样本（对应 iOS seedPerformances） ----------

    private suspend fun seedPerformances(dao: PerformanceDao, now: Long) {
        val pending = mutableListOf<PerformanceEntity>()
        val last7 = listOf(
            -6 to 2180.0, -5 to 2460.0, -4 to 2320.0,
            -3 to 2790.0, -2 to 3180.0, -1 to 2381.20
        )
        for ((offset, amount) in last7) {
            pending.add(
                PerformanceEntity(
                    amount = amount,
                    note = "扫呗",
                    date = day(offset, 22, 10, now),
                    fingerprint = "demo-day-$offset",
                    paymentMethod = "扫呗",
                    importSource = "扫呗",
                    incomeSource = ""
                )
            )
        }

        val todayRows = listOf(
            Triple(9, 35, 128.50), Triple(10, 18, 56.00), Triple(11, 42, 236.80),
            Triple(12, 6, 89.90), Triple(13, 28, 318.00), Triple(14, 16, 42.50),
            Triple(15, 38, 168.00), Triple(16, 12, 96.00), Triple(17, 45, 288.80),
            Triple(18, 36, 428.00), Triple(19, 20, 198.00), Triple(20, 14, 368.00)
        )
        for ((h, m, amount) in todayRows) {
            pending.add(
                PerformanceEntity(
                    amount = amount,
                    note = "扫呗",
                    date = day(0, h, m, now),
                    fingerprint = "demo-today-$h$m",
                    paymentMethod = "扫呗",
                    importSource = "扫呗",
                    incomeSource = ""
                )
            )
        }
        // 今日最后一笔：手动记录（fingerprint 为空 = 手工，与 iOS 一致）
        pending.add(
            PerformanceEntity(
                amount = 262.00,
                note = "手动",
                date = day(0, 21, 8, now),
                fingerprint = "",
                paymentMethod = "手动",
                importSource = "手动",
                incomeSource = ""
            )
        )

        val extra = mapOf(
            -29 to 1980.0, -28 to 2110.0, -27 to 1860.0, -26 to 3420.0, -25 to 4010.0,
            -24 to 4280.0, -23 to 1760.0, -22 to 2050.0, -21 to 2190.0, -20 to 1940.0,
            -19 to 3680.0, -18 to 4120.0, -17 to 3890.0, -16 to 1720.0, -15 to 2210.0,
            -14 to 2380.0, -13 to 2090.0, -12 to 2560.0, -11 to 3710.0, -10 to 4450.0,
            -9 to 3180.0, -8 to 1880.0, -7 to 2240.0
        )
        for ((offset, amount) in extra) {
            pending.add(
                PerformanceEntity(
                    amount = amount,
                    note = "扫呗",
                    date = day(offset, 21, 40, now),
                    fingerprint = "demo-hist-$offset",
                    paymentMethod = "扫呗",
                    importSource = "扫呗",
                    incomeSource = ""
                )
            )
        }
        for (e in pending) dao.insert(e)
    }

    // ---------- 待办样本（对应 iOS seedTodos，21 条） ----------

    private data class DemoTodo(
        val title: String,
        val dayOffset: Int,
        val hour: Int,
        val minute: Int,
        val priority: Int,
        val done: Boolean,
        val completedOffset: Int? = null
    )

    private suspend fun seedTodos(dao: TodoDao, now: Long) {
        val todos = listOf(
            DemoTodo("确认饮料供应商送货", 0, 9, 30, 2, true),
            DemoTodo("整理冰柜临期饮料", 0, 11, 0, 1, true),
            DemoTodo("联系可口可乐供应商", 0, 15, 0, 2, false),
            DemoTodo("核对今天配送订单", 0, 18, 30, 1, false),
            DemoTodo("记录今日营业额", 0, 22, 30, 0, false),
            DemoTodo("补充早餐饮料", 1, 9, 0, 1, false),
            DemoTodo("联系泳衣供应商", 1, 10, 30, 2, false),
            DemoTodo("整理退货商品", 1, 14, 0, 1, false),
            DemoTodo("确认周末备货", 1, 18, 0, 0, false),
            DemoTodo("确认纸巾补货", -1, 16, 0, 2, false),
            DemoTodo("整理供应商欠货记录", -2, 20, 0, 1, false),
            DemoTodo("清点矿泉水", -1, 9, 0, 0, true, -1),
            DemoTodo("联系雪糕供应商", -1, 11, 0, 1, true, -1),
            DemoTodo("确认客户配送", -1, 13, 0, 1, true, -1),
            DemoTodo("整理收银台", -2, 10, 0, 0, true, -2),
            DemoTodo("记录昨日营业额", -1, 22, 0, 0, true, -1),
            DemoTodo("确认泳衣库存", -3, 15, 0, 1, true, -3),
            DemoTodo("检查冰柜", -2, 8, 30, 2, true, -2),
            DemoTodo("回复供应商微信", -3, 19, 0, 0, true, -3),
            DemoTodo("整理周末备货", 4, 10, 0, 1, false),
            DemoTodo("月中经营复盘", 6, 20, 0, 1, false)
        )
        for (t in todos) {
            dao.insert(
                TodoEntity(
                    title = t.title,
                    detail = "",
                    dueDate = day(t.dayOffset, t.hour, t.minute, now),
                    priority = t.priority,
                    isCompleted = t.done,
                    createdAt = day(minOf(t.dayOffset, -1), 8, 0, now),
                    completedAt = if (t.done) {
                        day(t.completedOffset ?: t.dayOffset, t.hour + 1, 0, now)
                    } else {
                        null
                    }
                )
            )
        }
    }

    // ---------- 客户配送样本（对应 iOS seedDeliveries，9 条） ----------

    private suspend fun seedDeliveries(dao: CustomerRequestDao, now: Long) {
        data class Row(
            val name: String,
            val content: String,
            val address: String,
            val status: String,
            val dayOffset: Int,
            val hour: Int,
            val minute: Int
        )
        val rows = listOf(
            Row("张老板", "矿泉水 × 3箱，饮料 × 2箱", "温泉路 18 号", CustomerStatus.PENDING, 0, 17, 30),
            Row("陈姐", "零食礼包 × 2", "小区 3 栋", CustomerStatus.PENDING, 0, 19, 0),
            Row("王先生", "饮料 × 4箱", "镇政府对面", CustomerStatus.DONE, 0, 11, 30),
            Row("李阿姨", "纯牛奶 × 2箱", "市场西门", CustomerStatus.DELIVERING, 0, 16, 0),
            Row("周哥", "矿泉水 × 5箱", "工业园门口", CustomerStatus.DONE, -1, 18, 20),
            Row("吴姐", "雪糕 × 1箱", "小学旁", CustomerStatus.DONE, -2, 15, 10),
            Row("赵老板", "饮料礼盒 × 3", "酒店后街", CustomerStatus.DONE, -3, 19, 40),
            Row("供应商送货", "可口可乐补货", "店门口", CustomerStatus.PENDING, 1, 14, 0),
            Row("周末备货", "饮料与水整托", "仓库", CustomerStatus.PENDING, 4, 9, 0)
        )
        for (r in rows) {
            val whenAt = day(r.dayOffset, r.hour, r.minute, now)
            dao.insert(
                CustomerRequestEntity(
                    customer = CustomerDeliveryStorage.encode(
                        CustomerDeliveryInfo(
                            deliveryTime = whenAt,
                            note = "",
                            legacyCustomer = r.name
                        )
                    ),
                    roomOrAddress = r.address,
                    phone = "",
                    content = r.content,
                    status = r.status,
                    createdAt = whenAt
                )
            )
        }
    }

    // ---------- 临期样本（对应 iOS seedExpiry，9 条） ----------

    private suspend fun seedExpiry(dao: ExpiryItemDao, now: Long) {
        data class Row(val name: String, val qty: Int, val days: Int, val returned: Boolean)
        val rows = listOf(
            Row("纯牛奶", 2, 3, false),
            Row("椰汁", 1, 1, false),
            Row("儿童泳衣", 6, 7, false),
            Row("矿泉水", 3, 0, false),
            Row("面包", 8, 2, false),
            Row("酸奶", 12, 4, false),
            Row("雪糕", 1, -3, true),
            Row("火腿肠", 2, -1, true),
            Row("饼干礼盒", 4, 10, true)
        )
        for (r in rows) {
            val cal = Calendar.getInstance()
            cal.timeInMillis = now
            cal.set(Calendar.HOUR_OF_DAY, 0)
            cal.set(Calendar.MINUTE, 0)
            cal.set(Calendar.SECOND, 0)
            cal.set(Calendar.MILLISECOND, 0)
            cal.add(Calendar.DAY_OF_YEAR, r.days)
            dao.insert(
                ExpiryItemEntity(
                    name = r.name,
                    category = "临期",
                    quantity = r.qty,
                    expiryDate = cal.timeInMillis,
                    returnStatus = if (r.returned) ReturnStatus.RETURNED else ReturnStatus.PENDING,
                    returnedAt = if (r.returned) day(-2, 12, 0, now) else null
                )
            )
        }
    }

    // ---------- 备忘样本（对应 iOS seedMemos，9 条） ----------

    private suspend fun seedMemos(dao: MemoDao, now: Long) {
        val notes = listOf(
            0 to "可口可乐供应商说周三下午送货。",
            -1 to "泳衣新款月底前可以退换。",
            0 to "张老板下次配送记得带两箱矿泉水。",
            -2 to "冰柜第二层温度偶尔偏高，继续观察。",
            -1 to "周末温泉客人可能增加，提前准备饮料。",
            -3 to "纸巾供应商改到周四对账。",
            -4 to "收银台备用金今晚清点过，差额已补。",
            -5 to "新到一批儿童泳衣，先放仓库第二层。",
            -6 to "邻居店在做买一送一，观察客流变化。"
        )
        for ((offset, text) in notes) {
            val at = day(offset, 20, 15, now)
            dao.insert(
                MemoEntity(
                    title = text,
                    content = text,
                    createdAt = at,
                    updatedAt = at
                )
            )
        }
    }
}
