import Foundation

struct SaobeiParsedRow: Equatable, Identifiable {
    var id: String { fingerprint }
    let date: Date
    let amount: Double
    let status: String
    let orderNo: String
    let paymentMethod: String
    let fingerprint: String
    let isSuccess: Bool
    let rawLine: String
}

struct SaobeiParseResult: Equatable {
    var rows: [SaobeiParsedRow]
    var skipped: [String]
    var errors: [String]
    var sourceFileName: String
}

struct SaobeiImportCommitResult: Equatable {
    var inserted: Int
    var duplicates: Int
    var skippedFailed: Int
}

enum SaobeiImportError: LocalizedError, Equatable {
    case emptyFile
    case unreadableEncoding
    case noHeader
    case missingAmountOrDate
    case unsupportedExcel(String)

    var errorDescription: String? {
        switch self {
        case .emptyFile: return "文件是空的"
        case .unreadableEncoding: return "无法识别文件编码，请另存为 UTF-8 CSV"
        case .noHeader: return "找不到表头，请确认是扫呗导出文件"
        case .missingAmountOrDate: return "缺少交易时间或收款金额列"
        case .unsupportedExcel(let detail): return detail
        }
    }
}

enum SaobeiColumn {
    static let dateKeys = ["交易时间", "交易日期", "完成时间", "支付时间", "交易完成时间", "时间"]
    static let amountKeys = ["收款金额", "实收金额", "交易金额", "订单金额", "支付金额", "金额"]
    static let statusKeys = ["交易状态", "订单状态", "状态", "支付状态"]
    static let orderKeys = ["订单号", "商户订单号", "流水号", "交易单号", "平台订单号", "商户单号"]
    static let payKeys = ["支付方式", "支付类型", "付款方式", "渠道"]

    static let successStatuses: Set<String> = [
        "成功", "支付成功", "已支付", "已完成", "交易成功", "success", "SUCCESS", "完成"
    ]
    static let failedStatuses: Set<String> = [
        "退款", "已退款", "失败", "关闭", "已取消", "已关闭", "撤销", "fail"
    ]
}
