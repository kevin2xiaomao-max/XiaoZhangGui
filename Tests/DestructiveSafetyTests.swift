import XCTest

final class DestructiveSafetyTests: XCTestCase {
    private let views = [
        "XiaoZhangGui/Features/Todo/TodoView.swift",
        "XiaoZhangGui/Features/Customer/CustomerView.swift",
        "XiaoZhangGui/Features/Expiry/ExpiryView.swift",
        "XiaoZhangGui/Features/Performance/PerformanceView.swift",
        "XiaoZhangGui/Features/Memo/MemoView.swift"
    ]

    func testEveryDeletePathUsesNativeConfirmationAndDestructiveRole() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for path in views {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertTrue(source.contains("confirmationDialog"), path)
            XCTAssertTrue(source.contains("Button(\"删除\", role: .destructive)"), path)
            XCTAssertTrue(source.contains("Button(\"取消\", role: .cancel)"), path)
            XCTAssertTrue(source.contains("删除失败"), path)
        }
    }

    func testDeleteErrorsAreNotSilentlyIgnored() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        for (path, repository) in zip(views, ["TodoRepository", "CustomerRepository", "ExpiryRepository", "PerformanceRepository", "MemoRepository"]) {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertFalse(source.contains("try? \(repository)(context: context).delete"), path)
        }
    }
}
