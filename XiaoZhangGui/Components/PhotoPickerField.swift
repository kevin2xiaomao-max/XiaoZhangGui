import SwiftUI
import PhotosUI

// MARK: - 图片选择/预览组件（PhotosPicker → Data，配合 @Attribute(.externalStorage)）

struct PhotoPickerField: View {
    let imageData: Data?
    var onChange: (Data?) -> Void

    @State private var pickerItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 12) {
            if let data = imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: V32Radius.inset, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            onChange(nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .offset(x: 6, y: -6)
                    }
            }

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(imageData == nil ? "添加图片" : "更换图片", systemImage: "photo.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(V32.brand)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background {
                        Capsule(style: .continuous).fill(V32.brandSoft)
                    }
            }
            .onChange(of: pickerItem) { _, item in
                guard let item else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        onChange(ImageCodec.downscaled(data: data))
                    }
                    pickerItem = nil
                }
            }

            Spacer()
        }
    }
}

// MARK: - 图片压缩（避免大图占用数据库）

enum ImageCodec {
    /// 压缩到最长边 1600px 的 JPEG
    static func downscaled(data: Data, maxDimension: CGFloat = 1600) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return data }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85) ?? data
    }
}

// MARK: - 列表行小缩略图

struct ImageThumb: View {
    let imageData: Data?
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let data = imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                EmptyView()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
