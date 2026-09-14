import XCTest
@testable import XiaoZhangGui

final class SaobeiImporterTests: XCTestCase {
    func testCSVImportParsesSuccessRows() throws {
        let csv = """
        交易时间,收款金额,交易状态,订单号,支付方式
        2026-09-13 10:00:00,128.00,支付成功,SB001,微信
        2026-09-13 11:00:00,66.50,成功,SB002,支付宝
        2026-09-13 12:00:00,30.00,已退款,SB003,微信
        """
        let result = try SaobeiCSVParser.parse(text: csv, fileName: "saobei.csv")
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.skipped.count, 1)
        XCTAssertEqual(result.rows[0].amount, 128)
        XCTAssertFalse(result.rows[0].fingerprint.isEmpty)
    }

    func testFingerprintStableAcrossReimport() throws {
        let csv = """
        交易时间,收款金额,交易状态,订单号
        2026-09-13 10:00:00,100,成功,ORDER-9
        """
        let a = try SaobeiCSVParser.parse(text: csv, fileName: "a.csv")
        let b = try SaobeiCSVParser.parse(text: csv, fileName: "b.csv")
        XCTAssertEqual(a.rows.first?.fingerprint, b.rows.first?.fingerprint)
    }

    func testMissingHeaderFails() {
        XCTAssertThrowsError(try SaobeiCSVParser.parse(text: "foo,bar\n1,2", fileName: "x.csv"))
    }

    func testAmountStripsCurrency() {
        XCTAssertEqual(SaobeiCSVParser.parseAmount("¥128.00"), 128)
        XCTAssertEqual(SaobeiCSVParser.parseAmount("1,280.50"), 1280.5)
        XCTAssertNil(SaobeiCSVParser.parseAmount("0"))
    }

    func testSuccessStatus() {
        XCTAssertTrue(SaobeiCSVParser.isSuccess("支付成功"))
        XCTAssertTrue(SaobeiCSVParser.isSuccess(""))
        XCTAssertFalse(SaobeiCSVParser.isSuccess("已退款"))
    }
}
