import Foundation
import XCTest

final class V371ProductionRouteManifestTests: XCTestCase {
    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    func testEveryInAppProductionRouteIsDocumentedWithinThreeTaps() throws {
        let manifest = try String(
            contentsOf: root.appendingPathComponent("V371_ROUTE_MANIFEST.md"),
            encoding: .utf8
        )
        let rows = manifest.split(separator: "\n").filter { $0.hasPrefix("| R") }
        XCTAssertEqual(rows.count, 29)

        let expected = Set((1...29).map { String(format: "R%02d", $0) })
        let parsed = try rows.map { row -> (id: String, taps: Int) in
            let columns = row
                .split(separator: "|", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            XCTAssertGreaterThanOrEqual(columns.count, 8, String(row))
            return (columns[0], try XCTUnwrap(Int(columns[4]), String(row)))
        }

        XCTAssertEqual(Set(parsed.map(\.id)), expected)
        for route in parsed {
            XCTAssertLessThanOrEqual(route.taps, 3, "\(route.id) exceeds the Phase 0 reachability budget")
        }
    }

    func testOldDrawerIsNotRestoredIntoRootOrHome() throws {
        for path in [
            "XiaoZhangGui/App/RootView.swift",
            "XiaoZhangGui/Features/Home/HomeView.swift",
        ] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            XCTAssertFalse(source.contains("V35DrawerContainer"), path)
        }
    }
}
