import Foundation

// MARK: - V3.9.1 P2-C · 金额精度约束(不改持久化类型)
//
// 现状:金额以 Double 存 SwiftData,长期累计有二进制浮点漂移风险。
// 本轮红线:禁止无迁移直接把持久化类型换成 Decimal / 整分 Int(会丢经营数据)。
// 因此本轮只做两件可安全落地的事:
// 1) 约束:所有「展示用合计」走整分求和(sumInCents),单笔仍以 Double 存取,合计误差 < 1 分;
// 2) 回归测试锁定:0.1 + 0.2 类经典漂移、5000 笔累计、超大金额均不得出现分位外误差。
// 如未来确需迁移,必须另立迁移方案(旧数据逐条校验 + 回滚),不在本轮做。

enum MoneyPrecision {
    /// 以分为单位求和(每笔先四舍五入到分,再整数相加),返回元。
    static func sumInCents(_ amounts: [Double]) -> Double {
        let cents = amounts.reduce(0) { $0 + Int(($1 * 100).rounded()) }
        return Double(cents) / 100
    }

    /// 单笔金额规范化到分(展示与合计共用同一口径)。
    static func roundedToCents(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }

    /// 两金额在分位上是否相等(容忍 Double 末位漂移)。
    static func equalInCents(_ lhs: Double, _ rhs: Double) -> Bool {
        Int((lhs * 100).rounded()) == Int((rhs * 100).rounded())
    }
}
