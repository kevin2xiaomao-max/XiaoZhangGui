import Foundation
import SwiftData

/// UI-test-only runtime switch. Release builds can never enable this mode.
enum UITestMode {
    #if DEBUG
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("--ui-testing")
    }
    #else
    static let isEnabled = false
    #endif

    static var storageDirectory: URL {
        let arguments = ProcessInfo.processInfo.arguments
        let token = arguments.firstIndex(of: "--ui-testing-id")
            .flatMap { index in arguments.indices.contains(index + 1) ? arguments[index + 1] : nil }
            ?? "process-\(ProcessInfo.processInfo.processIdentifier)"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("XiaoZhangGui-UI-Test-\(token)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

/// DEBUG-only, one-shot failure gate used by XCUITest to prove that UI success
/// feedback is emitted only after a throwing operation succeeds.
enum UITestFailureInjection {
    enum Operation: String, CaseIterable {
        case customerAdvance = "customer.advance"
        case expiryToggleReturn = "expiry.toggleReturn"
        case goodsDelete = "goods.delete"
        case todoToggle = "todo.toggle"
    }

    struct InjectedError: LocalizedError {
        let operation: Operation
        var errorDescription: String? { "UI test injected failure: \(operation.rawValue)" }
    }

    #if DEBUG
    @MainActor private static var consumed: Set<Operation> = []
    #endif

    static func requestedOperation(arguments: [String]) -> Operation? {
        guard let index = arguments.firstIndex(of: "--ui-testing-fail-once"),
              arguments.indices.contains(index + 1) else { return nil }
        return Operation(rawValue: arguments[index + 1])
    }

    @MainActor
    static func throwIfRequested(_ operation: Operation) throws {
        #if DEBUG
        guard UITestMode.isEnabled,
              requestedOperation(arguments: ProcessInfo.processInfo.arguments) == operation,
              !consumed.contains(operation) else { return }
        consumed.insert(operation)
        throw InjectedError(operation: operation)
        #endif
    }

    #if DEBUG
    @MainActor
    static func resetForTesting() {
        consumed.removeAll()
    }
    #endif
}

enum UITestSeed {
    static func seed(_ context: ModelContext, now: Date = .now) {
        context.insert(Goods(name: "百威啤酒", stock: 12, purchasePrice: 4, salePrice: 6))
        context.insert(Goods(name: "可口可乐", stock: 20, purchasePrice: 2, salePrice: 3))
        context.insert(Todo(title: "UI Test 保留待办", dueDate: now))
        context.insert(CustomerRequest(
            customer: "测试客户",
            roomOrAddress: "302",
            content: "两箱矿泉水",
            notificationID: "ui-test-customer"
        ))
        context.insert(ExpiryItem(
            name: "测试临期商品",
            quantity: 2,
            expiryDate: now.addingTimeInterval(86_400),
            notificationID: "ui-test-expiry"
        ))
        context.insert(Performance(
            amount: 680,
            note: "UI Test 保留营业额",
            date: now,
            incomeSource: "美团"
        ))
        try? context.save()
    }
}
