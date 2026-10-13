package com.xiaozhanggui.app.migration

/**
 * V3.6（Room version 1）建表 SQL fixture。
 *
 * 逐字对应 Room 2.6.1 由 `data.db` 7 个 Entity 生成的 `CREATE TABLE`
 *（列顺序 = 字段声明顺序；String→TEXT / Double→REAL / Long·Int·Boolean→INTEGER；
 * 非空 Kotlin 类型 → NOT NULL；无索引、无外键、无 TypeConverter）。
 *
 * 用途：[DataUpgradeRegressionTest] 用其构造"旧版本数据库文件"，
 * 再用 `Room.databaseBuilder(...).addMigrations(MIGRATION_1_2)` 打开，
 * 验证覆盖安装升级语义。Room 打开时会对迁移后 schema 做
 * `validateMigration`，SQL 若与实体定义不一致测试会直接失败（自校验）。
 *
 * @param withIncomeSource performances 表是否带 `incomeSource` 列。
 * 真实 V3.6 设备：带（该字段自工程首个提交即存在于实体，见 Migrations.kt 注释）；
 * `false` 模拟理论上的缺列旧库，走 MIGRATION_1_2 的 ADD COLUMN 分支。
 */
object V1Schema {

    fun createAllTables(withIncomeSource: Boolean): List<String> = listOf(
        """
        CREATE TABLE IF NOT EXISTS `todos` (
          `id` TEXT NOT NULL, `title` TEXT NOT NULL, `detail` TEXT NOT NULL,
          `dueDate` INTEGER, `priority` INTEGER NOT NULL, `imagePath` TEXT,
          `isCompleted` INTEGER NOT NULL, `completedAt` INTEGER,
          `createdAt` INTEGER NOT NULL, `notificationId` TEXT NOT NULL,
          PRIMARY KEY(`id`)
        )
        """.trimIndent(),
        """
        CREATE TABLE IF NOT EXISTS `expiry_items` (
          `id` TEXT NOT NULL, `name` TEXT NOT NULL, `category` TEXT NOT NULL,
          `quantity` INTEGER NOT NULL, `productionDate` INTEGER,
          `expiryDate` INTEGER NOT NULL, `remindDaysBefore` INTEGER NOT NULL,
          `note` TEXT NOT NULL, `imagePath` TEXT, `createdAt` INTEGER NOT NULL,
          `returnStatus` TEXT NOT NULL, `returnedAt` INTEGER,
          `notificationId` TEXT NOT NULL,
          PRIMARY KEY(`id`)
        )
        """.trimIndent(),
        """
        CREATE TABLE IF NOT EXISTS `customer_requests` (
          `id` TEXT NOT NULL, `customer` TEXT NOT NULL, `roomOrAddress` TEXT NOT NULL,
          `phone` TEXT NOT NULL, `content` TEXT NOT NULL, `status` TEXT NOT NULL,
          `imagePath` TEXT, `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL,
          `notificationId` TEXT NOT NULL,
          PRIMARY KEY(`id`)
        )
        """.trimIndent(),
        """
        CREATE TABLE IF NOT EXISTS `goods` (
          `id` TEXT NOT NULL, `name` TEXT NOT NULL, `category` TEXT NOT NULL,
          `barcode` TEXT NOT NULL, `stock` INTEGER NOT NULL, `minStock` INTEGER NOT NULL,
          `purchasePrice` REAL NOT NULL, `salePrice` REAL NOT NULL,
          `productionDate` INTEGER, `shelfLifeDays` INTEGER NOT NULL, `expiryDate` INTEGER,
          `note` TEXT NOT NULL, `imagePath` TEXT,
          `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL,
          PRIMARY KEY(`id`)
        )
        """.trimIndent(),
        """
        CREATE TABLE IF NOT EXISTS `memos` (
          `id` TEXT NOT NULL, `title` TEXT NOT NULL, `content` TEXT NOT NULL,
          `imagePath` TEXT, `createdAt` INTEGER NOT NULL, `updatedAt` INTEGER NOT NULL,
          PRIMARY KEY(`id`)
        )
        """.trimIndent(),
        performancesTable(withIncomeSource),
        """
        CREATE TABLE IF NOT EXISTS `expenses` (
          `id` TEXT NOT NULL, `amount` REAL NOT NULL, `category` TEXT NOT NULL,
          `note` TEXT NOT NULL, `date` INTEGER NOT NULL, `createdAt` INTEGER NOT NULL,
          PRIMARY KEY(`id`)
        )
        """.trimIndent()
    )

    private fun performancesTable(withIncomeSource: Boolean): String {
        val incomeSourceCol = if (withIncomeSource) "`incomeSource` TEXT NOT NULL, " else ""
        return """
        CREATE TABLE IF NOT EXISTS `performances` (
          `id` TEXT NOT NULL, `amount` REAL NOT NULL, `note` TEXT NOT NULL,
          `date` INTEGER NOT NULL, `fingerprint` TEXT NOT NULL,
          `paymentMethod` TEXT NOT NULL, `orderNo` TEXT NOT NULL,
          `importSource` TEXT NOT NULL, ${incomeSourceCol}PRIMARY KEY(`id`)
        )
        """.trimIndent()
    }
}
