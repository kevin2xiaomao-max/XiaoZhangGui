import XCTest
@testable import XiaoZhangGui

final class V32MotionTests: XCTestCase {

    // MARK: - 时长 / 弹簧参数与 spec Motion 表一致（FR-21.6）

    func testDurationsMatchSpec() {
        XCTAssertEqual(V32Motion.quickDuration, 0.18, accuracy: 0.0001)
        XCTAssertEqual(V32Motion.standardDuration, 0.28, accuracy: 0.0001)
        XCTAssertEqual(V32Motion.slowDuration, 0.42, accuracy: 0.0001)
        XCTAssertEqual(V32Motion.reducedDuration, 0.12, accuracy: 0.0001)
    }

    func testSpringParametersMatchSpec() {
        XCTAssertEqual(V32Motion.softSpringResponse, 0.35, accuracy: 0.0001)
        XCTAssertEqual(V32Motion.softSpringDamping, 0.86, accuracy: 0.0001)
        XCTAssertEqual(V32Motion.interactiveSpringResponse, 0.28, accuracy: 0.0001)
        XCTAssertEqual(V32Motion.interactiveSpringDamping, 0.82, accuracy: 0.0001)
    }

    // MARK: - Reduce Motion 两态决策（FR-21.1）

    func testReduceMotionOnDegradesEverythingToShortFade() {
        // 减弱动态效果开启：fade / spring 都退化为短淡入，无位移 / 无弹簧
        XCTAssertEqual(V32Motion.resolve(.fade, reduceMotion: true), .quick)
        XCTAssertEqual(V32Motion.resolve(.spring, reduceMotion: true), .quick)
        // 数字类直接替换终值，不做过渡
        XCTAssertEqual(V32Motion.resolve(.numeric, reduceMotion: true), .none)
        XCTAssertNil(V32Motion.animation(.none))
    }

    func testReduceMotionOffKeepsSurfaceMapping() {
        XCTAssertEqual(V32Motion.resolve(.fade, reduceMotion: false), .quick)
        XCTAssertEqual(V32Motion.resolve(.spring, reduceMotion: false), .softSpring)
        XCTAssertEqual(V32Motion.resolve(.numeric, reduceMotion: false), .standard)
        XCTAssertNotNil(V32Motion.animation(.softSpring))
        XCTAssertNotNil(V32Motion.animation(.standard))
    }

    func testAnimationLookupCoversAllTokens() {
        XCTAssertNotNil(V32Motion.animation(.quick))
        XCTAssertNotNil(V32Motion.animation(.standard))
        XCTAssertNotNil(V32Motion.animation(.slow))
        XCTAssertNotNil(V32Motion.animation(.interactiveSpring))
        XCTAssertNotNil(V32Motion.animation(.quick))
    }
}
