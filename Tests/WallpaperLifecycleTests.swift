import XCTest
@testable import XiaoZhangGui

/// P2-1：壁纸文件生命周期
/// - 换图成功后：旧原图 / 旧 blurred 必须清理，当前新文件不得误删
/// - 新图处理失败：旧壁纸配置与文件原样保留
/// - clearWallpaper：当前文件清理、配置关闭
@MainActor
final class WallpaperLifecycleTests: XCTestCase {

    /// 1x1 PNG
    private let pngData = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+M8AAAMBAQDJ/pLvAAAAAElFTkSuQmCC"
    )!

    private let store = ThemeStore.shared

    override func setUp() {
        super.setUp()
        store.clearWallpaper()
    }

    override func tearDown() {
        store.clearWallpaper()
        super.tearDown()
    }

    func testReplacingWallpaperDeletesOldFilesButKeepsCurrent() {
        // 第一张壁纸落盘
        let error1 = store.applyWallpaperImage(data: pngData, effect: .soft, maskStrength: .medium)
        XCTAssertNil(error1)
        let file1 = try? XCTUnwrap(store.wallpaper.imageFileName, "第一张壁纸应已生效")
        let f1 = file1!
        XCTAssertNotNil(WallpaperStorage.loadData(fileName: f1), "新原图必须存在")
        let blurred1 = WallpaperStorage.blurredFileName(for: f1)
        let blurred1Existed = WallpaperStorage.loadData(fileName: blurred1) != nil

        // 换第二张
        let error2 = store.applyWallpaperImage(data: pngData, effect: .original, maskStrength: .light)
        XCTAssertNil(error2)
        let f2 = try! XCTUnwrap(store.wallpaper.imageFileName)
        XCTAssertNotEqual(f1, f2, "每次换图生成新的 UUID 文件名")

        // 当前壁纸文件完好、配置指向新文件
        XCTAssertNotNil(WallpaperStorage.loadData(fileName: f2))
        XCTAssertTrue(store.wallpaper.isEnabled)

        // 旧文件被清理（原图必须删；blurred 若生成过也必须删）
        XCTAssertNil(WallpaperStorage.loadData(fileName: f1), "旧原图必须删除")
        if blurred1Existed {
            XCTAssertNil(WallpaperStorage.loadData(fileName: blurred1), "旧 blurred 文件必须删除")
        }
    }

    func testFailedNewWallpaperKeepsPreviousWallpaperUntouched() {
        // 先建立一张有效壁纸
        XCTAssertNil(store.applyWallpaperImage(data: pngData, effect: .blurred, maskStrength: .strong))
        let current = try! XCTUnwrap(store.wallpaper.imageFileName)

        // 用非法图片数据换图：降采样失败
        let error = store.applyWallpaperImage(
            data: Data("this is not an image".utf8), effect: .soft, maskStrength: .medium
        )
        XCTAssertNotNil(error, "非法图片必须返回失败描述")

        // 旧壁纸配置与文件原样保留
        XCTAssertEqual(store.wallpaper.imageFileName, current)
        XCTAssertTrue(store.wallpaper.isEnabled)
        XCTAssertNotNil(WallpaperStorage.loadData(fileName: current), "失败时旧原图不得被删除")
    }

    func testClearWallpaperRemovesCurrentFilesAndDisables() {
        XCTAssertNil(store.applyWallpaperImage(data: pngData, effect: .soft, maskStrength: .light))
        let f = try! XCTUnwrap(store.wallpaper.imageFileName)
        let blurred = WallpaperStorage.blurredFileName(for: f)
        let blurredExisted = WallpaperStorage.loadData(fileName: blurred) != nil

        store.clearWallpaper()

        XCTAssertFalse(store.wallpaper.isEnabled)
        XCTAssertNil(store.wallpaper.imageFileName)
        XCTAssertNil(WallpaperStorage.loadData(fileName: f))
        if blurredExisted {
            XCTAssertNil(WallpaperStorage.loadData(fileName: blurred))
        }
    }
}
