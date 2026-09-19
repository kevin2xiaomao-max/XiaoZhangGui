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

enum UITestSeed {
    static func seed(_ context: ModelContext, now: Date = .now) {
        context.insert(Goods(name: "百威啤酒", stock: 12, purchasePrice: 4, salePrice: 6))
        context.insert(Goods(name: "可口可乐", stock: 20, purchasePrice: 2, salePrice: 3))
        context.insert(Todo(title: "UI Test 保留待办", dueDate: now.addingTimeInterval(86_400)))
        context.insert(Performance(
            amount: 680,
            note: "UI Test 保留营业额",
            date: now,
            incomeSource: "美团"
        ))
        try? context.save()
    }
}
