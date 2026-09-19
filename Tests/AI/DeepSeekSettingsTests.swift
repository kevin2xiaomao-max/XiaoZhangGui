import XCTest
@testable import XiaoZhangGui

// MARK: V3.3 AI REAL · DeepSeek 配置迁移 + 设置 Draft 保存/取消
//
// 真机问题：
// - 默认模型仍是已下线的 deepseek-chat，用户还能自由输入 "DeepSeek" 之类的非法模型 ID；
// - 设置页 @Bindable 实时写 UserDefaults，「取消」无法恢复旧值。
//
// 本文件使用独立 UserDefaults suite，不碰 .standard / Keychain。

@MainActor
final class DeepSeekSettingsTests: XCTestCase {

    private var suite: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ai-settings-test-\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)
        suite.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        suiteName = nil
        super.tearDown()
    }

    // MARK: 默认值必须是当前 DeepSeek 配置

    func testDefaultsAreCurrentDeepSeekConfig() {
        XCTAssertEqual(AISettings.Defaults.primaryBaseURL, "https://api.deepseek.com")
        XCTAssertEqual(AISettings.Defaults.primaryModel, "deepseek-flash")
        XCTAssertTrue(DeepSeekModel.allCases.contains(.v4Pro))
        XCTAssertEqual(DeepSeekModel.v4Pro.rawValue, "deepseek-v4-pro")
    }

    // MARK: 1) 旧 deepseek-chat 配置自动迁移到 deepseek-flash

    func testLegacyDeepseekChatMigratesToFlash() {
        suite.set("deepseek-chat", forKey: "ai_primary_model")
        let settings = AISettings(defaults: suite)

        XCTAssertEqual(settings.resolvedPrimaryModel, "deepseek-flash",
                       "旧 deepseek-chat 不得继续拿去请求，必须自动迁移到 deepseek-flash")
        XCTAssertEqual(suite.string(forKey: "ai_primary_model"), "deepseek-flash",
                       "迁移结果必须持久化，重启后不再出现旧模型")
    }

    func testLegacyDeepseekReasonerMigratesToFlash() {
        suite.set("deepseek-reasoner", forKey: "ai_primary_model")
        let settings = AISettings(defaults: suite)
        XCTAssertEqual(settings.resolvedPrimaryModel, "deepseek-flash")
    }

    // MARK: 2) "DeepSeek" 等非法模型 ID 不允许通过，回落 flash

    func testInvalidFreeTextModelFallsBackToFlash() {
        suite.set("DeepSeek", forKey: "ai_primary_model")
        let settings = AISettings(defaults: suite)
        XCTAssertEqual(settings.resolvedPrimaryModel, "deepseek-flash",
                       "DeepSeek 主流程不接受自由输入的模型名")
    }

    func testUnknownModelFallsBackToFlash() {
        XCTAssertEqual(DeepSeekModel.normalize("gpt-4o"), .flash)
        XCTAssertEqual(DeepSeekModel.normalize(""), .flash)
        XCTAssertEqual(DeepSeekModel.normalize(nil), .flash)
        XCTAssertEqual(DeepSeekModel.normalize("deepseek-v4-pro"), .v4Pro)
    }

    // MARK: 11) Cancel 不落盘：编辑 Draft 不写设置，丢弃即恢复

    func testDraftCancelDoesNotPersistAnything() {
        let settings = AISettings(defaults: suite)
        settings.primaryBaseURL = "https://api.deepseek.com"
        settings.primaryModel = "deepseek-flash"
        let originalBaseURL = settings.primaryBaseURL

        let draft = AISettingsDraft(settings: settings)
        draft.primaryBaseURL = "  https://evil.example.com/v1  "
        draft.primaryModel = .v4Pro
        draft.tier = .highQuality
        draft.fallbackModel = "some-model"
        // 不调用 commit（= 用户点取消）

        XCTAssertEqual(settings.primaryBaseURL, originalBaseURL, "Draft 编辑不得实时落盘")
        XCTAssertEqual(settings.resolvedPrimaryModel, "deepseek-flash")
        XCTAssertEqual(settings.tier, .freeFirst)
        XCTAssertEqual(suite.string(forKey: "ai_fallback_model"), nil)
    }

    // MARK: 12) Save 才落盘：commit 后 trim + 模型 Picker 值写入

    func testDraftSaveCommitsTrimmedValues() {
        let settings = AISettings(defaults: suite)
        let draft = AISettingsDraft(settings: settings)
        draft.primaryBaseURL = "  https://api.deepseek.com  "
        draft.primaryModel = .v4Pro
        draft.tier = .highQuality
        draft.fallbackBaseURL = "  https://fb.example.com/v1 "
        draft.fallbackModel = " fb-model "

        draft.commit(to: settings)

        XCTAssertEqual(settings.primaryBaseURL, "https://api.deepseek.com", "保存前必须 trim")
        XCTAssertEqual(settings.resolvedPrimaryModel, "deepseek-v4-pro")
        XCTAssertEqual(settings.tier, .highQuality)
        XCTAssertEqual(settings.fallbackBaseURL, "https://fb.example.com/v1")
        XCTAssertEqual(settings.fallbackModel, "fb-model")
        XCTAssertEqual(suite.string(forKey: "ai_primary_model"), "deepseek-v4-pro")
    }
}
