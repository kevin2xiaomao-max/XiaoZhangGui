import SwiftUI
import UIKit
import PhotosUI
import UniformTypeIdentifiers

// MARK: - V32 / Wallpaper · 壁纸存储 + 图片编解码 + 背景 View（b28 T27）
//
// 设计依据：spec FR-22.7 / FR-22.8 / FR-22.9 / NFR-9 / NFR-22
// - 壁纸图片降采样后落盘到 Application Support/Appearance/
// - 不允许把原图巨量数据塞 UserDefaults
// - 壁纸层必须 allowsHitTesting(false)，不拦截交互
// - 文字可读性：遮罩层（light/medium/strong），深色自动增强
// - Demo Mode 下不显示自定义壁纸
// - 效果档：original / soft / blurred（预渲染缓存）

/// 壁纸文件存储工具
enum WallpaperStorage {
    /// 壁纸目录：Application Support/Appearance/
    static var directoryURL: URL {
        let fm = FileManager.default
        let appSupport = try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = appSupport?.appendingPathComponent("Appearance", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("Appearance", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 保存 JPEG 数据，返回自动生成的文件名（不含路径）
    static func saveJPEGData(_ data: Data) throws -> String {
        let fileName = "wallpaper-\(UUID().uuidString).jpg"
        let url = directoryURL.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return fileName
    }

    /// 保存 JPEG 数据到指定文件名（用于预渲染模糊版本等）
    static func saveJPEGData(_ data: Data, fileName: String) throws {
        let url = directoryURL.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
    }

    /// 模糊版本文件名：wallpaper-xxx.jpg → wallpaper-xxx-blurred.jpg
    static func blurredFileName(for original: String) -> String {
        let ns = original as NSString
        let stem = ns.deletingPathExtension
        let ext = ns.pathExtension.isEmpty ? "jpg" : ns.pathExtension
        return "\(stem)-blurred.\(ext)"
    }

    /// 读取文件 Data
    static func loadData(fileName: String) -> Data? {
        let url = directoryURL.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }

    /// 删除文件（不存在则静默）
    static func deleteFile(fileName: String) {
        let url = directoryURL.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    /// 删除 Appearance 目录下所有壁纸文件
    static func purgeAll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil) else { return }
        for url in files where url.pathExtension == "jpg" {
            try? fm.removeItem(at: url)
        }
    }
}

/// 图片降采样与预渲染工具
enum ImageCodec {
    /// 降采样 + JPEG 重编码，限制最大边长，控制质量
    /// - Parameters:
    ///   - data: 原始图数据
    ///   - maxDimension: 最大边长（推荐 2048）
    ///   - quality: JPEG 质量（0.82~0.85）
    /// - Returns: 降采样后的 JPEG Data
    static func downscaled(data: Data, maxDimension: CGFloat = 2048, quality: CGFloat = 0.84) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil),
              let jpgData = encodeJPEG(image: cgImage, maxDimension: maxDimension, quality: quality) else {
            return nil
        }
        return jpgData
    }

    /// 预渲染模糊版本（用于 WallpaperEffect.blurred）
    /// - Parameters:
    ///   - data: 原始图数据
    ///   - blurRadius: 模糊半径（推荐 24~32）
    ///   - maxDimension: 最大边长（模糊版可进一步缩小）
    ///   - quality: JPEG 质量
    static func prerenderBlurred(data: Data, blurRadius: Double = 28, maxDimension: CGFloat = 1280, quality: CGFloat = 0.78) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let clamped = ciImage.clampedToExtent()
        guard let filter = CIFilter(name: "CIGaussianBlur") else {
            return encodeJPEG(image: cgImage, maxDimension: maxDimension, quality: quality)
        }
        filter.setValue(clamped, forKey: kCIInputImageKey)
        filter.setValue(blurRadius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage?.cropped(to: ciImage.extent) else {
            return encodeJPEG(image: cgImage, maxDimension: maxDimension, quality: quality)
        }
        let context = CIContext(options: nil)
        guard let outputCG = context.createCGImage(output, from: ciImage.extent) else {
            return encodeJPEG(image: cgImage, maxDimension: maxDimension, quality: quality)
        }
        return encodeJPEG(image: outputCG, maxDimension: maxDimension, quality: quality)
    }

    /// 通用 JPEG 编码，附带降采样
    private static func encodeJPEG(image: CGImage, maxDimension: CGFloat, quality: CGFloat) -> Data? {
        let originalWidth = CGFloat(image.width)
        let originalHeight = CGFloat(image.height)
        let scale: CGFloat
        let maxSide = max(originalWidth, originalHeight)
        if maxSide > maxDimension {
            scale = maxDimension / maxSide
        } else {
            scale = 1
        }
        let targetWidth = Int((originalWidth * scale).rounded())
        let targetHeight = Int((originalHeight * scale).rounded())

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: nil, width: targetWidth, height: targetHeight, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))
        guard let scaledImage = context.makeImage() else { return nil }

        let uiImage = UIImage(cgImage: scaledImage)
        return uiImage.jpegData(compressionQuality: quality)
    }
}

// MARK: - 壁纸背景 View

/// 在最底层 ZStack 挂载壁纸图 + 效果层 + 遮罩层
/// - 不参与点击（allowsHitTesting(false)）
/// - Demo Mode 下隐藏
/// - T28 性能优化：内存缓存 UIImage 避免每次 body 重复解码
struct V32WallpaperBackground: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    private let demo = DemoMode.shared

    /// 内存缓存已解码的 UIImage + 对应文件名，避免每次 body 重复解码
    @State private var cachedImage: UIImage?
    @State private var cachedDisplayFileName: String?

    private var currentFileName: String? {
        themeStore.wallpaper.isEnabled ? themeStore.wallpaper.imageFileName : nil
    }

    private var currentDisplayFileName: String? {
        guard let fileName = currentFileName else { return nil }
        return displayFileName(for: fileName, effect: themeStore.wallpaper.effect)
    }

    var body: some View {
        Group {
            if !demo.isEnabled, let image = cachedImage {
                wallpaperLayer(uiImage: image)
            } else {
                EmptyView()
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        // fileName 或 effect 变化时重新加载（避免每次 body 重复解码）
        .task(id: taskID) {
            await loadImage()
        }
    }

    private var taskID: String {
        "\(currentDisplayFileName ?? "none")|\(colorScheme == .dark ? "d" : "l")"
    }

    @MainActor
    private func loadImage() async {
        guard let displayFileName = currentDisplayFileName else {
            cachedImage = nil
            cachedDisplayFileName = nil
            return
        }
        // 已缓存且文件名匹配，跳过
        if cachedDisplayFileName == displayFileName, cachedImage != nil {
            return
        }
        // 异步加载 + 解码，避免阻塞 MainActor
        let data = await Task.detached(priority: .userInitiated) {
            WallpaperStorage.loadData(fileName: displayFileName)
        }.value
        if let data, let image = UIImage(data: data) {
            cachedImage = image
            cachedDisplayFileName = displayFileName
        } else {
            cachedImage = nil
            cachedDisplayFileName = nil
        }
    }

    @ViewBuilder
    private func wallpaperLayer(uiImage: UIImage) -> some View {
        let blurFallback = (themeStore.wallpaper.effect == .blurred
                            && cachedDisplayFileName == currentFileName)
        ZStack {
            // 1. 壁纸原图（或预渲染模糊版）
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .blur(radius: blurFallback ? 24 : 0)
                .ignoresSafeArea()

            // 2. 效果层（original 无附加；blurred 已预渲染）
            effectLayer

            // 3. 遮罩层（深色自动增强；Reduce Transparency 用纯色兜底）
            maskLayer
        }
    }

    /// 根据效果档返回实际应加载的文件名
    /// - effect=.blurred 优先加载预渲染模糊版本；若不存在则回退原文件 + .blur 兜底
    private func displayFileName(for original: String, effect: WallpaperEffect) -> String {
        guard effect == .blurred else { return original }
        let blurred = WallpaperStorage.blurredFileName(for: original)
        let url = WallpaperStorage.directoryURL.appendingPathComponent(blurred)
        return FileManager.default.fileExists(atPath: url.path) ? blurred : original
    }

    @ViewBuilder
    private var effectLayer: some View {
        switch themeStore.wallpaper.effect {
        case .original:
            EmptyView()
        case .soft:
            // 柔和：轻微提亮 + 降饱和（不破坏原图色相）
            Color.white.opacity(colorScheme == .dark ? 0.12 : 0.18)
                .blendMode(.softLight)
            Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08)
                .blendMode(.softLight)
        case .blurred:
            // 模糊已在壁纸图层处理（预渲染或 SwiftUI .blur 兜底）
            EmptyView()
        }
    }

    @ViewBuilder
    private var maskLayer: some View {
        let strength = maskOpacity
        if reduceTransparency {
            // Reduce Transparency 时使用接近背景色的纯色
            Color(themeStore.backgroundPalette.pageBG)
        } else {
            ZStack {
                // 主题底色和谐层
                Color(themeStore.backgroundPalette.pageBG)
                    .opacity(strength * 0.55)
                // 深色遮罩
                Color.black.opacity(strength * 0.45)
            }
        }
    }

    private var maskOpacity: Double {
        switch themeStore.wallpaper.maskStrength {
        case .light: return colorScheme == .dark ? 0.55 : 0.25
        case .medium: return colorScheme == .dark ? 0.75 : 0.5
        case .strong: return colorScheme == .dark ? 0.9 : 0.75
        }
    }
}
