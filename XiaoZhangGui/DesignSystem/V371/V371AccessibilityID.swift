import Foundation

/// Stable identifiers for UI automation and accessibility inspection.
/// Keep these independent from localized display copy.
enum V371AccessibilityID {
    static let screenHome = "screen.home"
    static let screenTodo = "screen.todo"
    static let screenCalendar = "screen.calendar"
    static let screenBusiness = "screen.business"
    static let screenProfile = "screen.profile"
    static let screenGoods = "screen.goods"
    static let screenPaymentCodes = "screen.paymentCodes"
    static let screenCustomer = "screen.customer"
    static let screenExpiry = "screen.expiry"
    static let screenMemo = "screen.memo"
    static let screenTransactions = "screen.transactions"

    static let tabHome = "tab.home"
    static let tabTodo = "tab.todo"
    static let tabCalendar = "tab.calendar"
    static let tabBusiness = "tab.business"

    static let homeQuickRecord = "home.quickRecord"
    static let homeProfile = "home.profile"
    static let homeAI = "home.ai"
    static let homeCustomer = "home.customer"
    static let homeExpiry = "home.expiry"

    static let businessMenu = "business.menu"
    static let businessAddIncome = "business.addIncome"
    static let businessAddExpense = "business.addExpense"
    static let businessImport = "business.import"
    static let businessGoods = "business.goods"
    static let businessMemo = "business.memo"
    static let businessDailyReport = "business.dailyReport"

    static let profilePaymentCodes = "profile.paymentCodes"
    static let profileVoiceSettings = "profile.voiceSettings"
    static let profileVoiceTest = "profile.voiceTest"

    static let sheetQuickRecord = "sheet.quickRecord"
    static let quickRecordCancel = "quickRecord.cancel"
    static let sheetAI = "sheet.ai"
    static let sheetDailyReport = "sheet.dailyReport"
    static let dailyReportClose = "dailyReport.close"
    static let sheetVoice = "sheet.voice"

    static let customerAdvance = "customer.advance"
    static let expiryToggleReturn = "expiry.toggleReturn"
    static let goodsDelete = "goods.delete"
    static let todoToggle = "todo.toggle"
    static let reliabilityRetry = "reliability.retry"
}
