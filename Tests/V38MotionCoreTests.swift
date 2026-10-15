import XCTest
@testable import XiaoZhangGui

/// V3.8 Motion Foundation 纯逻辑测试（Worker A）。
///
/// 覆盖 `V38MotionTokens` 的 Reduce Motion 两态决策、三意图时序数值（复用 MotionLab PoC 结论）、
/// `V38CapabilityGate` 的 2×2 门控矩阵、`V38MotionPolicy` 的降级矩阵与能力开关。
/// 不依赖模拟器真值，CI 上可直接运行。
final class V38MotionCoreTests: XCTestCase {

    // MARK: - V38MotionTokens：Reduce Motion 两态决策

    func testTokensReduceMotionOnReturnsNil() {
        for intent in V38MotionTokens.Intent.allCases {
            XCTAssertNil(
                V38MotionTokens.token(for: intent, reduceMotion: true),
                "Reduce Motion 开启时意图 \(intent) 的 token 必须为 nil（静态呈现）"
            )
            XCTAssertNil(
                V38MotionTokens.animation(for: intent, reduceMotion: true),
                "Reduce Motion 开启时意图 \(intent) 的 animation 必须为 nil"
            )
        }
        XCTAssertFalse(V38MotionTokens.allowsDecorativeMorph(reduceMotion: true))
    }

    func testTokensReduceMotionOffReturnsAnimation() {
        for intent in V38MotionTokens.Intent.allCases {
            XCTAssertNotNil(
                V38MotionTokens.animation(for: intent, reduceMotion: false),
                "Reduce Motion 关闭时意图 \(intent) 必须返回非 nil 动效"
            )
        }
        XCTAssertTrue(V38MotionTokens.allowsDecorativeMorph(reduceMotion: false))
    }

    func testTokensIntentCoverage() {
        // 三种意图全覆盖：press / expand / contentChange
        XCTAssertEqual(V38MotionTokens.Intent.allCases.count, 3)
        XCTAssertEqual(Set(V38MotionTokens.Intent.allCases),
                       [.press, .expand, .contentChange])
    }

    // MARK: - V38MotionTokens：时序数值与 MotionLab PoC 结论一致

    func testTokensRawValuesMatchPoCConclusions() {
        // PoC 结论（V38MotionLabTokens）：press = 0.18s easeOut、
        // expand = spring(response: 0.35, dampingFraction: 0.86)、contentChange = 0.28s easeInOut。
        XCTAssertEqual(
            V38MotionTokens.token(for: .press, reduceMotion: false),
            V38MotionTokens.Token(curve: .easeOut(duration: 0.18))
        )
        XCTAssertEqual(
            V38MotionTokens.token(for: .expand, reduceMotion: false),
            V38MotionTokens.Token(curve: .spring(response: 0.35, dampingFraction: 0.86))
        )
        XCTAssertEqual(
            V38MotionTokens.token(for: .contentChange, reduceMotion: false),
            V38MotionTokens.Token(curve: .easeInOut(duration: 0.28))
        )
    }

    func testTokensDeterministic() {
        // 纯函数确定性：同输入同输出。
        for intent in V38MotionTokens.Intent.allCases {
            XCTAssertEqual(
                V38MotionTokens.token(for: intent, reduceMotion: false),
                V38MotionTokens.token(for: intent, reduceMotion: false)
            )
        }
    }

    // MARK: - V38CapabilityGate：2×2 门控矩阵

    func testGateMatrix() {
        // (glassEffectAvailable, reduceTransparency) → 期望档
        let matrix: [(V38CapabilityGate.Capabilities, V38CapabilityGate.MaterialTier)] = [
            (.init(glassEffectAvailable: true, reduceTransparency: true), .opaque),
            (.init(glassEffectAvailable: true, reduceTransparency: false), .glass),
            (.init(glassEffectAvailable: false, reduceTransparency: true), .opaque),
            (.init(glassEffectAvailable: false, reduceTransparency: false), .ultraThin),
        ]
        for (input, expected) in matrix {
            XCTAssertEqual(V38CapabilityGate.resolve(input), expected,
                           "输入 \(input) 应解析为 \(expected)")
        }
    }

    func testGateReduceTransparencyAlwaysOpaque() {
        // Reduce Transparency 是最高优先级：无论 glassEffect 可用性都回退不透明。
        XCTAssertEqual(
            V38CapabilityGate.resolve(.init(glassEffectAvailable: true, reduceTransparency: true)),
            .opaque
        )
        XCTAssertEqual(
            V38CapabilityGate.resolve(.init(glassEffectAvailable: false, reduceTransparency: true)),
            .opaque
        )
    }

    func testGateMaterialTierHasThreeCases() {
        let tiers: [V38CapabilityGate.MaterialTier] = [.glass, .ultraThin, .opaque]
        XCTAssertEqual(Set(tiers).count, 3)
        // 同输入同输出（纯函数确定性）
        let input = V38CapabilityGate.Capabilities(glassEffectAvailable: false, reduceTransparency: false)
        XCTAssertEqual(V38CapabilityGate.resolve(input), V38CapabilityGate.resolve(input))
    }

    // MARK: - V38MotionPolicy：降级矩阵

    func testPolicyMatrix() {
        let matrix: [(V38MotionPolicy.Environment, V38MotionPolicy.MotionTier)] = [
            (.init(reduceMotion: true, lowPowerMode: true), .staticOnly),
            (.init(reduceMotion: true, lowPowerMode: false), .staticOnly),
            (.init(reduceMotion: false, lowPowerMode: true), .reduced),
            (.init(reduceMotion: false, lowPowerMode: false), .full),
        ]
        for (input, expected) in matrix {
            XCTAssertEqual(V38MotionPolicy.resolve(input), expected,
                           "输入 \(input) 应解析为 \(expected)")
        }
    }

    func testPolicyCapabilitySwitches() {
        // 完整档：全部允许
        XCTAssertTrue(V38MotionPolicy.allowsDecorativeMorph(tier: .full))
        XCTAssertTrue(V38MotionPolicy.allowsDisplacement(tier: .full))
        XCTAssertTrue(V38MotionPolicy.allowsOvershoot(tier: .full))
        XCTAssertTrue(V38MotionPolicy.allowsLoopedAnimation(tier: .full))
        // 降级档：取消装饰（无形变/无过冲/无循环），位移保留
        XCTAssertFalse(V38MotionPolicy.allowsDecorativeMorph(tier: .reduced))
        XCTAssertTrue(V38MotionPolicy.allowsDisplacement(tier: .reduced))
        XCTAssertFalse(V38MotionPolicy.allowsOvershoot(tier: .reduced))
        XCTAssertFalse(V38MotionPolicy.allowsLoopedAnimation(tier: .reduced))
        // 全静态档：一切都不允许（取消位移/过冲/循环）
        XCTAssertFalse(V38MotionPolicy.allowsDecorativeMorph(tier: .staticOnly))
        XCTAssertFalse(V38MotionPolicy.allowsDisplacement(tier: .staticOnly))
        XCTAssertFalse(V38MotionPolicy.allowsOvershoot(tier: .staticOnly))
        XCTAssertFalse(V38MotionPolicy.allowsLoopedAnimation(tier: .staticOnly))
    }

    func testPolicyTokenModeMapping() {
        XCTAssertEqual(V38MotionPolicy.tokenMode(tier: .full), .fullTokens)
        XCTAssertEqual(V38MotionPolicy.tokenMode(tier: .reduced), .shortFadeOnly)
        XCTAssertEqual(V38MotionPolicy.tokenMode(tier: .staticOnly), .none)
    }

    func testPolicyAndTokensConsistency() {
        // policy = .staticOnly 时，tokens 必须返回 nil：两处 Reduce Motion 决策一致。
        let env = V38MotionPolicy.Environment(reduceMotion: true, lowPowerMode: false)
        XCTAssertEqual(V38MotionPolicy.resolve(env), .staticOnly)
        for intent in V38MotionTokens.Intent.allCases {
            XCTAssertNil(V38MotionTokens.token(for: intent, reduceMotion: env.reduceMotion))
            XCTAssertNil(V38MotionTokens.animation(for: intent, reduceMotion: env.reduceMotion))
        }
        // policy = .full 时，三意图都有 token。
        let fullEnv = V38MotionPolicy.Environment(reduceMotion: false, lowPowerMode: false)
        XCTAssertEqual(V38MotionPolicy.resolve(fullEnv), .full)
        for intent in V38MotionTokens.Intent.allCases {
            XCTAssertNotNil(V38MotionTokens.token(for: intent, reduceMotion: fullEnv.reduceMotion))
        }
    }
}
