import XCTest
@testable import XiaoZhangGui

/// V3.9.2 · AI 多模态外发守卫
///
/// 锁住三件此前真实存在的坑：
/// 1. 选完图片直接整张 base64 外发，没有任何确认，而图片里常有客户姓名、电话；
/// 2. 所有非 2xx 都翻成「联网服务暂时不可用」——选到不支持图片的模型时永远猜不到要换模型；
/// 3. 超大图片没有任何本地拦截，白白上传一次再撞服务端 413。
final class V392AIMultimodalGuardTests: XCTestCase {

    // MARK: 状态码 → 可照着改的错误

    func testHTTPStatusMapping() {
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(forHTTPStatus: 400, capability: .vision),
            .unsupportedModel(.vision)
        )
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(
                forHTTPStatus: 422, capability: .documentUnderstanding),
            .unsupportedModel(.documentUnderstanding)
        )
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(forHTTPStatus: 401, capability: .vision),
            .credentialRejected
        )
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(forHTTPStatus: 403, capability: .vision),
            .credentialRejected
        )
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(forHTTPStatus: 413, capability: .vision),
            .payloadTooLarge
        )
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(forHTTPStatus: 429, capability: .vision),
            .rateLimited
        )
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(forHTTPStatus: 503, capability: .vision),
            .serverUnavailable
        )
        XCTAssertEqual(
            OpenAICompatibleMultimodalRequest.capabilityError(forHTTPStatus: 418, capability: .vision),
            .networkFailure
        )
    }

    func testUserFacingCopyIsActionable() {
        let unsupported = AICapabilityError.unsupportedModel(.vision).errorDescription ?? ""
        XCTAssertTrue(unsupported.contains("不支持图片理解"), unsupported)
        XCTAssertTrue(unsupported.contains("AI 设置"), unsupported)

        let document = AICapabilityError.unsupportedModel(.documentUnderstanding).errorDescription ?? ""
        XCTAssertTrue(document.contains("文件"), document)

        XCTAssertTrue((AICapabilityError.credentialRejected.errorDescription ?? "").contains("API Key"))
        XCTAssertTrue((AICapabilityError.payloadTooLarge.errorDescription ?? "").contains("4 MB"))
        XCTAssertTrue((AICapabilityError.rateLimited.errorDescription ?? "").contains("频繁"))
        XCTAssertTrue((AICapabilityError.serverUnavailable.errorDescription ?? "").contains("暂时不可用"))
    }

    // MARK: 本地体积拦截

    func testOversizedImageIsRejectedLocally() throws {
        XCTAssertNoThrow(try OpenAICompatibleVisionProvider.validateImageSize(Data(count: 1024)))

        let oversized = Data(count: OpenAICompatibleVisionProvider.maxInlineImageBytes + 1)
        XCTAssertThrowsError(try OpenAICompatibleVisionProvider.validateImageSize(oversized)) { error in
            XCTAssertEqual(error as? AICapabilityError, .payloadTooLarge)
        }
    }

    // MARK: 外发确认开关

    func testImageConsentDefaultsToOnAndPersists() {
        let suiteName = "v392.imageconsent.\(UUID().uuidString)"
        guard let suite = UserDefaults(suiteName: suiteName) else {
            return XCTFail("无法创建测试用 UserDefaults suite")
        }
        defer { suite.removePersistentDomain(forName: suiteName) }

        let settings = AISettings(defaults: suite)
        XCTAssertTrue(settings.imageUploadNeedsConfirmation, "缺省应当先问一次")

        settings.imageUploadNeedsConfirmation = false
        XCTAssertFalse(AISettings(defaults: suite).imageUploadNeedsConfirmation, "选择应当持久化")
    }

    // MARK: 源码审计

    func testChatRequiresConfirmationBeforeUploadingImage() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        func source(_ relative: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
        }

        let chat = try source("XiaoZhangGui/Features/Assistant/AI/UI/AIChatView.swift")
        XCTAssertTrue(chat.contains("把这张图片发给 AI 分析？"), "选图后必须先弹确认")
        XCTAssertFalse(chat.contains("AISettings.shared.imageUploadNeedsConfirmation"), "旧偏好不得绕过逐次确认")
        XCTAssertFalse(chat.contains("以后直接发送"))
        XCTAssertEqual(chat.components(separatedBy: "model.analyzeImage(").count - 1, 1, "图片只能从确认发送函数外发")
        XCTAssertEqual(chat.components(separatedBy: "model.analyzeDocument(").count - 1, 1, "文件只能从确认发送函数外发")
        XCTAssertTrue(chat.contains("Button(\"取消\", role: .cancel) { clearPendingImage() }"))
        XCTAssertTrue(chat.contains("Button(\"取消\", role: .cancel) { clearPendingDocument() }"))
        XCTAssertTrue(chat.contains("请勿发送证件、银行卡、客户身份证等敏感照片。"))

        let sheet = try source("XiaoZhangGui/Features/Assistant/AI/UI/AIProviderSettingsSheet.swift")
        // V3.9.3：同一开关现覆盖图片与文件，文案随之改为「发送图片与文件前先确认」。
        XCTAssertTrue(sheet.contains("每次发送图片与文件前确认"))
        XCTAssertFalse(sheet.contains("$draft.imageUploadNeedsConfirmation"), "逐次确认不提供关闭入口")

        let vision = try source("XiaoZhangGui/Features/Assistant/AI/Capabilities/LiveCapabilityProviders.swift")
        XCTAssertTrue(vision.contains("try Self.validateImageSize(input.data)"))
        XCTAssertTrue(vision.contains("static func capabilityError(forHTTPStatus"))
    }
}
