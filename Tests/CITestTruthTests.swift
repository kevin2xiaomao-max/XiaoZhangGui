import XCTest

final class CITestTruthTests: XCTestCase {
    func testWorkflowDoesNotIgnorePackageResolutionFailure() throws {
        let workflow = try workflowSource()
        XCTAssertFalse(workflow.contains("resolvePackageDependencies -project XiaoZhangGui.xcodeproj -scheme XiaoZhangGui || true"))
        XCTAssertTrue(workflow.contains("FAIL: Swift Package 依赖解析两次均失败"))
    }

    func testWorkflowRejectsZeroAndFragmentedTestRuns() throws {
        let workflow = try workflowSource()
        XCTAssertTrue(workflow.contains("test \"$EXPECTED\" -gt 0"))
        XCTAssertTrue(workflow.contains("test \"$EXPECTED_UI\" -gt 0"))
        XCTAssertTrue(workflow.contains("if log_passes_all \"$LOG\"; then return 0; fi"))
        XCTAssertFalse(workflow.contains("log_passes_all \"$LOG\" || check_round \"$LOG\""))
    }

    private func workflowSource() throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(".github/workflows/build.yml"),
            encoding: .utf8
        )
    }
}
