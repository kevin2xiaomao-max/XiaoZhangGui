import XCTest
@testable import XiaoZhangGui

// MARK: - P3-3：XLSX round-trip 测试
// 生成 XLSX → SaobeiXLSXParser 解析 → 金额/日期/中文字段一致

final class SaobeiRoundTripTests: XCTestCase {

    private func makeRow(date: Date, amount: Double, status: String, orderNo: String, pay: String) -> SaobeiParsedRow {
        SaobeiParsedRow(
            date: date, amount: amount, status: status,
            orderNo: orderNo, paymentMethod: pay,
            fingerprint: "fp-\(orderNo)", isSuccess: true, rawLine: ""
        )
    }

    func testXLSXRoundTripPreservesFields() throws {
        let date1 = SaobeiDateParser.parse("2026-09-16 14:30:00")!
        let date2 = SaobeiDateParser.parse("2026-09-16 09:15:00")!
        let original = [
            makeRow(date: date1, amount: 128.50, status: "成功", orderNo: "SO20260916-001", pay: "微信"),
            makeRow(date: date2, amount: 56.00, status: "成功", orderNo: "SO20260916-002", pay: "支付宝")
        ]

        let xlsxData = try SaobeiExporter.exportXLSX(rows: original)
        // 确认是真 XLSX（ZIP 魔数 50 4B 03 04）
        XCTAssertTrue(xlsxData.starts(with: [0x50, 0x4b, 0x03, 0x04]), "导出必须是真 XLSX（ZIP 格式）")

        let result = try SaobeiXLSXParser.parse(data: xlsxData, fileName: "test.xlsx")
        XCTAssertEqual(result.rows.count, 2, "行数应一致")

        // 金额一致
        XCTAssertEqual(result.rows[0].amount, 128.50, accuracy: 0.01)
        XCTAssertEqual(result.rows[1].amount, 56.00, accuracy: 0.01)

        // 日期一致
        XCTAssertEqual(result.rows[0].date, date1)
        XCTAssertEqual(result.rows[1].date, date2)

        // 中文字段一致
        XCTAssertEqual(result.rows[0].paymentMethod, "微信")
        XCTAssertEqual(result.rows[1].paymentMethod, "支付宝")
        XCTAssertEqual(result.rows[0].orderNo, "SO20260916-001")
        XCTAssertEqual(result.rows[1].orderNo, "SO20260916-002")
    }

    func testCSVRoundTripPreservesFields() throws {
        let date = SaobeiDateParser.parse("2026-09-16 14:30:00")!
        let original = [
            makeRow(date: date, amount: 88.88, status: "成功", orderNo: "CSV-001", pay: "微信")
        ]

        let csvData = SaobeiExporter.exportCSV(rows: original)
        let result = try SaobeiCSVParser.parse(data: csvData, fileName: "test.csv")
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0].amount, 88.88, accuracy: 0.01)
        XCTAssertEqual(result.rows[0].date, date)
        XCTAssertEqual(result.rows[0].paymentMethod, "微信")
        XCTAssertEqual(result.rows[0].orderNo, "CSV-001")
    }

    /// 禁止 CSV 改后缀冒充 XLSX
    func testXLSXIsNotCSVDisguised() throws {
        let rows = [makeRow(date: Date(), amount: 10, status: "成功", orderNo: "X", pay: "现金")]
        let xlsxData = try SaobeiExporter.exportXLSX(rows: rows)

        // XLSX 是二进制 ZIP，必须以 ZIP 魔数开头
        XCTAssertTrue(xlsxData.starts(with: [0x50, 0x4b, 0x03, 0x04]), "必须是 ZIP 格式")

        // 不应以 CSV 表头明文开头（CSV 冒充会被前两个字节 '交' '易' 识破）
        let firstTwo = xlsxData.prefix(2)
        XCTAssertFalse(firstTwo == Data([0xE4, 0xBA]), "不应以 UTF-8 中文开头（CSV 冒充）")
    }
}
