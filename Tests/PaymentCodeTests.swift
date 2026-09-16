import XCTest
import UIKit
@testable import XiaoZhangGui

// MARK: - V3.3 Lite · 收款码（Payment QR）
//
// 覆盖范围：
// - metadata 仅保存轻量字段（ID/名称/类型/文件名/排序），保存/加载往返一致
// - 多张码顺序保持
// - 新增写入图片文件；删除移除文件；替换清理旧文件；删除一张不误删其它图片
// - 文件缺失 / 内容损坏时返回 nil 而不是崩溃
// - 亮度提升：进入保存、退出恢复、重复进入不覆盖保存值
// - 启动恢复保护：异常终止留下标记时恢复合理亮度并清标记；无标记不动作；脏值只清标记

@MainActor
final class PaymentCodeTests: XCTestCase {

    /// 1x1 PNG（最小合法图片）
    private let pngData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
    )!

    private var defaults: UserDefaults!
    private var suiteName: String!
    private var tempDir: URL!
    private var imageStore: PaymentCodeImageStore!
    private var metadataStore: PaymentCodeMetadataStore!
    private var store: PaymentCodeStore!

    override func setUp() {
        super.setUp()
        suiteName = "xzg.tests.paymentcode.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)

        tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("payment-code-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        imageStore = PaymentCodeImageStore(directory: tempDir)
        metadataStore = PaymentCodeMetadataStore(defaults: defaults)
        store = PaymentCodeStore(metadata: metadataStore, images: imageStore)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Metadata

    func testEmptyMetadataLoadsEmptyArray() {
        XCTAssertTrue(metadataStore.load().isEmpty)
    }

    func testMetadataRoundTripPersistsLightweightFieldsOnly() throws {
        let id = UUID()
        let code = PaymentCode(id: id,
                               name: "店铺微信",
                               kind: .wechat,
                               fileName: "payment-code-\(id.uuidString).png",
                               createdAt: Date(timeIntervalSince1970: 1_700_000_000),
                               order: 3)
        metadataStore.save([code])

        let reloaded = try XCTUnwrap(PaymentCodeMetadataStore(defaults: defaults).load().first)
        XCTAssertEqual(reloaded, code)
        XCTAssertEqual(reloaded.name, "店铺微信")
        XCTAssertEqual(reloaded.kind, .wechat)
        XCTAssertEqual(reloaded.fileName, code.fileName)
        XCTAssertEqual(reloaded.order, 3)

        // 图片 Data / base64 绝不进入 UserDefaults
        let rawData = try XCTUnwrap(defaults.data(forKey: PaymentCodeMetadataStore.storageKey))
        let raw = try XCTUnwrap(String(data: rawData, encoding: .utf8))
        XCTAssertFalse(raw.contains("data:image"), "metadata 不得内嵌图片 base64")
        XCTAssertFalse(raw.contains("iVBOR"))
    }

    func testMultipleCodesKeepInsertionOrderAcrossReload() throws {
        _ = try store.addCode(name: "微信", kind: .wechat, imageData: pngData)
        _ = try store.addCode(name: "支付宝", kind: .alipay, imageData: pngData)
        _ = try store.addCode(name: "自定义", kind: .custom, imageData: pngData)

        let reloaded = PaymentCodeStore(metadata: PaymentCodeMetadataStore(defaults: defaults),
                                        images: imageStore)
        XCTAssertEqual(reloaded.codes.map(\.name), ["微信", "支付宝", "自定义"])
        XCTAssertEqual(reloaded.codes.map(\.order), [0, 1, 2])
    }

    // MARK: - 图片文件生命周期

    func testAddCodeWritesImageFileAndAssignsIncrementalOrder() throws {
        let code = try store.addCode(name: "微信", kind: .wechat, imageData: pngData)
        XCTAssertEqual(code.order, 0)
        XCTAssertNotNil(imageStore.data(for: code.fileName), "新增码的图片必须落盘")
        XCTAssertEqual(try contentsOfTempDir().count, 1, "目录下只能有这一张图片文件")

        let second = try store.addCode(name: "支付宝", kind: .alipay, imageData: pngData)
        XCTAssertEqual(second.order, 1)
        XCTAssertEqual(try contentsOfTempDir().count, 2)
    }

    func testBlankNameFallsBackToKindDefaultName() throws {
        let code = try store.addCode(name: "   ", kind: .alipay, imageData: pngData)
        XCTAssertEqual(code.name, PaymentCodeKind.alipay.displayName)
    }

    func testDeleteRemovesMetadataAndImageFile() throws {
        let code = try store.addCode(name: "微信", kind: .wechat, imageData: pngData)
        store.delete(id: code.id)

        XCTAssertTrue(store.codes.isEmpty)
        XCTAssertTrue(metadataStore.load().isEmpty)
        XCTAssertNil(imageStore.data(for: code.fileName), "删除码后图片文件必须删除")
    }

    func testDeleteOneCodeDoesNotDeleteOtherImages() throws {
        let a = try store.addCode(name: "微信", kind: .wechat, imageData: pngData)
        let b = try store.addCode(name: "支付宝", kind: .alipay, imageData: pngData)
        let c = try store.addCode(name: "备用", kind: .custom, imageData: pngData)

        store.delete(id: b.id)

        XCTAssertEqual(store.codes.map(\.id), [a.id, c.id])
        XCTAssertNil(imageStore.data(for: b.fileName), "被删码的文件必须删除")
        XCTAssertNotNil(imageStore.data(for: a.fileName), "其它码图片不得误删")
        XCTAssertNotNil(imageStore.data(for: c.fileName), "其它码图片不得误删")
        XCTAssertEqual(try contentsOfTempDir().count, 2)
    }

    func testReplaceImageDeletesOldFileAndPointsMetadataToNew() throws {
        let code = try store.addCode(name: "微信", kind: .wechat, imageData: pngData)
        let oldFile = code.fileName

        let updated = try store.replaceImage(id: code.id, with: pngData)
        XCTAssertNotEqual(updated.fileName, oldFile, "替换应生成新的 UUID 文件名")
        XCTAssertNil(imageStore.data(for: oldFile), "替换后旧文件必须清理")
        XCTAssertNotNil(imageStore.data(for: updated.fileName), "新文件必须存在")
        XCTAssertEqual(store.codes.first?.fileName, updated.fileName)
        XCTAssertEqual(try contentsOfTempDir().count, 1, "替换后目录中不得残留孤儿文件")
    }

    func testReplaceWithInvalidDataKeepsOldFileAndMetadata() throws {
        let code = try store.addCode(name: "微信", kind: .wechat, imageData: pngData)
        let oldFile = code.fileName

        XCTAssertThrowsError(try store.replaceImage(id: code.id, with: Data("not-an-image".utf8))) { error in
            XCTAssertEqual(error as? PaymentCodeError, .invalidImageData)
        }
        XCTAssertEqual(store.codes.first?.fileName, oldFile, "失败替换不得改动 metadata")
        XCTAssertNotNil(imageStore.data(for: oldFile), "失败替换不得删除旧文件")
        XCTAssertEqual(try contentsOfTempDir().count, 1)
    }

    // MARK: - 缺失 / 损坏文件容错

    func testMissingImageFileReturnsNilInsteadOfCrashing() throws {
        let code = try store.addCode(name: "微信", kind: .wechat, imageData: pngData)
        try FileManager.default.removeItem(at: imageStore.url(for: code.fileName))

        XCTAssertNil(store.image(for: code), "图片缺失时必须返回 nil")
    }

    func testCorruptImageFileReturnsNilInsteadOfCrashing() throws {
        let corruptURL = imageStore.url(for: "payment-code-corrupt.jpg")
        try Data("broken-content".utf8).write(to: corruptURL)
        XCTAssertNil(imageStore.image(for: "payment-code-corrupt.jpg"), "损坏图片必须解码为 nil")
    }

    func testRenamePersistsAcrossReload() throws {
        let code = try store.addCode(name: "旧名字", kind: .custom, imageData: pngData)
        store.rename(id: code.id, to: "  新名字  ")

        let reloaded = PaymentCodeStore(metadata: PaymentCodeMetadataStore(defaults: defaults),
                                        images: imageStore)
        XCTAssertEqual(reloaded.codes.first?.name, "新名字", "名称应 trim 后持久化")
    }

    // MARK: - 亮度

    func testBrightnessBeginSavesCurrentAndRaises() {
        let screen = StubBrightnessController(0.42)
        let brightness = PaymentCodeBrightnessGuard(controller: screen, defaults: defaults)

        brightness.begin(targetLevel: 1.0)

        XCTAssertEqual(screen.brightness, 1.0, accuracy: 0.001)
        XCTAssertTrue(defaults.bool(forKey: PaymentCodeBrightnessGuard.activeFlagKey))
        XCTAssertEqual(defaults.double(forKey: PaymentCodeBrightnessGuard.savedBrightnessKey),
                       0.42, accuracy: 0.001)
    }

    func testBrightnessEndRestoresSavedValueAndClearsFlag() {
        let screen = StubBrightnessController(0.35)
        let brightness = PaymentCodeBrightnessGuard(controller: screen, defaults: defaults)

        brightness.begin(targetLevel: 1.0)
        brightness.end()

        XCTAssertEqual(screen.brightness, 0.35, accuracy: 0.001, "退出必须恢复进入前亮度")
        XCTAssertFalse(defaults.bool(forKey: PaymentCodeBrightnessGuard.activeFlagKey))
        XCTAssertNil(defaults.object(forKey: PaymentCodeBrightnessGuard.savedBrightnessKey))
    }

    func testBeginTwiceDoesNotOverwriteSavedBrightness() {
        let screen = StubBrightnessController(0.4)
        let brightness = PaymentCodeBrightnessGuard(controller: screen, defaults: defaults)

        brightness.begin(targetLevel: 1.0)
        screen.brightness = 0.8 // 模拟外部变化
        brightness.begin(targetLevel: 1.0) // 重复进入不得覆盖原始保存值
        brightness.end()

        XCTAssertEqual(screen.brightness, 0.4, accuracy: 0.001)
    }

    func testEndWithoutBeginIsNoOp() {
        let screen = StubBrightnessController(0.6)
        PaymentCodeBrightnessGuard(controller: screen, defaults: defaults).end()
        XCTAssertEqual(screen.brightness, 0.6, accuracy: 0.001)
    }

    func testStartupRecoveryRestoresStaleBrightnessAndClearsFlag() {
        let screen = StubBrightnessController(1.0)
        defaults.set(true, forKey: PaymentCodeBrightnessGuard.activeFlagKey)
        defaults.set(0.33, forKey: PaymentCodeBrightnessGuard.savedBrightnessKey)

        PaymentCodeBrightnessGuard.applyStartupRecovery(controller: screen, defaults: defaults)

        XCTAssertEqual(screen.brightness, 0.33, accuracy: 0.001, "异常终止后下次启动必须恢复保存的亮度")
        XCTAssertFalse(defaults.bool(forKey: PaymentCodeBrightnessGuard.activeFlagKey))
        XCTAssertNil(defaults.object(forKey: PaymentCodeBrightnessGuard.savedBrightnessKey))

        // 标记已清除：再次启动不得重复改写亮度
        screen.brightness = 0.9
        PaymentCodeBrightnessGuard.applyStartupRecovery(controller: screen, defaults: defaults)
        XCTAssertEqual(screen.brightness, 0.9, accuracy: 0.001)
    }

    func testStartupRecoveryWithoutFlagIsNoOp() {
        let screen = StubBrightnessController(0.7)
        PaymentCodeBrightnessGuard.applyStartupRecovery(controller: screen, defaults: defaults)
        XCTAssertEqual(screen.brightness, 0.7, accuracy: 0.001, "没有遗留标记时不得改动亮度")
    }

    func testStartupRecoveryWithInvalidSavedValueOnlyClearsFlag() {
        let screen = StubBrightnessController(1.0)
        defaults.set(true, forKey: PaymentCodeBrightnessGuard.activeFlagKey)
        defaults.set(1.7, forKey: PaymentCodeBrightnessGuard.savedBrightnessKey) // 非法亮度

        PaymentCodeBrightnessGuard.applyStartupRecovery(controller: screen, defaults: defaults)

        XCTAssertEqual(screen.brightness, 1.0, accuracy: 0.001, "非法保存值不得写入屏幕")
        XCTAssertFalse(defaults.bool(forKey: PaymentCodeBrightnessGuard.activeFlagKey))
        XCTAssertNil(defaults.object(forKey: PaymentCodeBrightnessGuard.savedBrightnessKey))
    }

    // MARK: - Helpers

    private func contentsOfTempDir() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
            .filter { $0.hasPrefix("payment-code-") }
            .sorted()
    }
}

// MARK: - 测试替身

private final class StubBrightnessController: BrightnessControlling {
    var brightness: CGFloat
    init(_ brightness: CGFloat) { self.brightness = brightness }
}
