import Foundation

enum V35DrawerDestination: String, CaseIterable, Identifiable {
    case transactions, dailyReport, customer, expiry, goods, memo, quickRecord, saobeiImport
    var id: String { rawValue }
    var title: String {
        switch self {
        case .transactions: return "交易记录"
        case .dailyReport: return "今日经营报告"
        case .customer: return "客户需求"
        case .expiry: return "临期退货"
        case .goods: return "商品"
        case .memo: return "备忘"
        case .quickRecord: return "快速记一笔"
        case .saobeiImport: return "扫呗导入"
        }
    }
    var icon: String {
        switch self {
        case .transactions: return "list.bullet.rectangle"
        case .dailyReport: return "doc.text.magnifyingglass"
        case .customer: return "person.2"
        case .expiry: return "clock.badge.exclamationmark"
        case .goods: return "shippingbox"
        case .memo: return "note.text"
        case .quickRecord: return "plus.circle"
        case .saobeiImport: return "square.and.arrow.down"
        }
    }
}

enum V35DrawerGestureLogic {
    static let openThreshold: CGFloat = 0.32
    static func progress(translation: CGFloat, width: CGFloat) -> CGFloat { min(max(translation / max(width, 1), 0), 1) }
    static func shouldOpen(translation: CGFloat, predicted: CGFloat, width: CGFloat) -> Bool { progress(translation: max(translation, predicted), width: width) > openThreshold }
    static func shouldClose(translation: CGFloat, predicted: CGFloat, width: CGFloat) -> Bool { progress(translation: -min(translation, predicted), width: width) > openThreshold }
}
