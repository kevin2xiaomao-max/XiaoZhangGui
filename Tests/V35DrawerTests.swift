import XCTest
@testable import XiaoZhangGui

final class V35DrawerTests: XCTestCase {
    func testDestinationMappingHasStableTitlesAndIcons() {
        XCTAssertEqual(V35DrawerDestination.performance.title, "经营数据")
        XCTAssertEqual(V35DrawerDestination.transactions.title, "交易记录")
        XCTAssertEqual(V35DrawerDestination.quickRecord.icon, "plus.circle")
        XCTAssertEqual(V35DrawerDestination.allCases.count, 10)
    }

    func testDrawerProgressAndPredictedEndDecision() {
        XCTAssertEqual(V35DrawerGestureLogic.progress(translation: 100, width: 400), 0.25, accuracy: 0.001)
        XCTAssertTrue(V35DrawerGestureLogic.shouldOpen(translation: 90, predicted: 180, width: 400))
        XCTAssertFalse(V35DrawerGestureLogic.shouldOpen(translation: 80, predicted: 100, width: 400))
        XCTAssertTrue(V35DrawerGestureLogic.shouldClose(translation: -180, predicted: -240, width: 400))
    }
}
