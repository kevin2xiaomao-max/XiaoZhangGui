import SwiftUI
import UIKit
import PhotosUI

// MARK: - V3.3 Lite · 收款码列表页（我的 → 工具 → 收款码）
//
// - 收款码图片只保存在本机 Application Support/PaymentCodes/，不上传、不联网、不进 AI
// - 视觉全部沿用 V32 Design System（V32Card / V32PageHeader / V32EmptyState / 主题/壁纸）
// - 支持：新增（微信 / 支付宝 / 自定义）、重命名、替换图片、删除、全屏左右滑动

@MainActor
struct PaymentCodeView: View {

    /// 全屏展示会话（携带起始位置；fullScreenCover(item:) 需要 Identifiable）
    struct FullScreenSession: Identifiable {
        let id = UUID()
        let initialIndex: Int
    }

    private enum EditorTarget: Identifiable {
        case add
        case edit(PaymentCode)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let code): return "edit-\(code.id.uuidString)"
            }
        }
    }

    @State private var store = PaymentCodeStore.shared
    @State private var fullScreenSession: FullScreenSession?
    @State private var editorTarget: EditorTarget?
    @State private var pendingDelete: PaymentCode?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if store.codes.isEmpty {
                    emptyState
                } else {
                    ForEach(store.codes) { code in
                        PaymentCodeRow(
                            code: code,
                            thumbnail: store.image(for: code),
                            onOpen: { openFullScreen(code) },
                            onEdit: { editorTarget = .edit(code) },
                            onDelete: { pendingDelete = code }
                        )
                    }
                    privacyFootnote
                }
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 8)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32PageBottomInset()
        .navigationTitle("收款码")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editorTarget = .add } label: { Image(systemName: "plus") }
                    .accessibilityLabel("新增收款码")
            }
        }
        .fullScreenCover(item: $fullScreenSession) { session in
            PaymentCodeFullScreenView(store: store,
                                      codes: store.codes,
                                      initialIndex: session.initialIndex)
        }
        .sheet(item: $editorTarget) { target in
            switch target {
            case .add:
                PaymentCodeEditorSheet(kind: .add) { store.load() }
            case .edit(let code):
                PaymentCodeEditorSheet(kind: .edit(code)) { store.load() }
            }
        }
        .confirmationDialog(
            "删除这张收款码？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let code = pendingDelete {
                    store.delete(id: code.id)
                    Haptic.warning()
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("将同时删除本机保存的收款码图片，此操作不可撤销。")
        }
    }

    private var emptyState: some View {
        V32Card {
            VStack(spacing: 16) {
                V32EmptyState(systemName: "qrcode",
                              title: "还没有收款码",
                              message: "添加微信 / 支付宝收款码或自定义二维码，收款时一键全屏展示")
                V32PrimaryButton(title: "添加收款码", systemName: "plus") {
                    editorTarget = .add
                }
                .padding(.horizontal, 8)
                privacyFootnote
            }
            .padding(.vertical, 8)
        }
    }

    private var privacyFootnote: some View {
        Label("图片仅保存在本设备，不会上传服务器或发送给任何服务", systemImage: "lock.shield")
            .v32Text(.caption)
            .foregroundStyle(V32.textTertiary)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }

    private func openFullScreen(_ code: PaymentCode) {
        guard let index = store.codes.firstIndex(where: { $0.id == code.id }) else { return }
        Haptic.light()
        fullScreenSession = FullScreenSession(initialIndex: index)
    }
}

// MARK: - 列表行

@MainActor
private struct PaymentCodeRow: View {
    let code: PaymentCode
    let thumbnail: UIImage?
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        V32Card {
            HStack(spacing: 12) {
                Button(action: onOpen) {
                    HStack(spacing: 12) {
                        thumb
                        VStack(alignment: .leading, spacing: 4) {
                            Text(code.name)
                                .v32Text(.headline)
                                .foregroundStyle(V32.textPrimary)
                                .lineLimit(1)
                            Text(code.kind.displayName)
                                .v32Text(.caption)
                                .foregroundStyle(V32.textTertiary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(V32.textQuaternary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Menu {
                    Button {
                        Haptic.light()
                        onEdit()
                    } label: {
                        Label("重命名 / 替换图片", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20))
                        .foregroundStyle(V32.textQuaternary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var thumb: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    V32.pageBGSecondary
                    Image(systemName: code.kind.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(V32.textQuaternary)
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(V32.cardOutline, lineWidth: 1)
        )
    }
}

// MARK: - 新增 / 编辑 Sheet

@MainActor
private struct PaymentCodeEditorSheet: View {

    enum Kind {
        case add
        case edit(PaymentCode)
    }

    let kind: Kind
    /// 保存成功后的回调（让列表重新从磁盘读一次）
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedKind: PaymentCodeKind = .wechat
    @State private var pickerItem: PhotosPickerItem?
    @State private var pickedImageData: Data?
    @State private var previewImage: UIImage?
    @State private var processing = false
    @State private var errorMessage: String?

    private var editingCode: PaymentCode? {
        if case .edit(let code) = kind { return code }
        return nil
    }

    private var navigationTitle: String { editingCode == nil ? "添加收款码" : "编辑收款码" }
    private var existingThumbnail: UIImage? {
        guard let code = editingCode else { return nil }
        return PaymentCodeStore.shared.image(for: code)
    }

    var body: some View {
        PaymentCodeSheetChrome(navigationTitle, detents: [.large], doneTitle: "关闭", onDone: { dismiss() }) {
            previewCard
            if editingCode == nil {
                kindPicker
            }
            nameField
            PhotosPicker(selection: $pickerItem, matching: .images) {
                HStack(spacing: 10) {
                    V32IconBubble(systemName: "photo.on.rectangle", tone: .brand, size: 30, icon: 14)
                    Text(editingCode == nil ? "从相册选择收款码图片" : "替换收款码图片（从相册选择）")
                        .v32Text(.title)
                        .foregroundStyle(V32.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(V32.textQuaternary)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(processing)

            if let errorMessage {
                Text(errorMessage)
                    .v32Text(.caption)
                    .foregroundStyle(V32.danger)
            }

            V32PrimaryButton(title: "保存", systemName: "checkmark") { save() }
                .disabled(!canSave)

            Text("仅在本机展示你自己保存的收款码图片，不识别、不解析二维码内容。")
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
                .padding(.horizontal, 4)
        }
        .onAppear(perform: setup)
        .onChange(of: pickerItem) { _, item in
            Task { await handlePickedItem(item) }
        }
    }

    private var canSave: Bool {
        if processing { return false }
        if editingCode != nil { return true } // 编辑：至少保留原图 + 原名称
        return pickedImageData != nil
    }

    private var previewCard: some View {
        V32Card {
            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                } else if let existing = existingThumbnail {
                    Image(uiImage: existing)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 36))
                            .foregroundStyle(V32.textQuaternary)
                        Text("未选择图片")
                            .v32Text(.subhead)
                            .foregroundStyle(V32.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                }
            }
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("类型")
                .v32Text(.section)
                .foregroundStyle(V32.textPrimary)
            HStack(spacing: 8) {
                ForEach(PaymentCodeKind.allCases) { kind in
                    let selected = selectedKind == kind
                    Button {
                        Haptic.light()
                        selectedKind = kind
                        if name.isEmpty { name = kind.displayName }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: kind.iconName)
                                .font(.system(size: 18, weight: .semibold))
                            Text(kind.displayName)
                                .v32Text(.pill)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(selected ? V32.brand : V32.textSecondary)
                        .background(
                            RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous)
                                .fill(selected ? V32.brandSoft : V32.card)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: V32Radius.card, style: .continuous)
                                .strokeBorder(selected ? V32.brand.opacity(0.5) : V32.cardOutline,
                                              lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var nameField: some View {
        V32Card(padding: 0) {
            HStack(spacing: 10) {
                Image(systemName: "pencil.line")
                    .font(.system(size: 15))
                    .foregroundStyle(V32.textTertiary)
                TextField("收款码名称（如：店铺微信）", text: $name)
                    .v32Text(.body)
                    .foregroundStyle(V32.textPrimary)
                    .tint(V32.brand)
                if !name.isEmpty {
                    Button { name = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(V32.textQuaternary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
        }
    }

    private func setup() {
        if let code = editingCode {
            name = code.name
            selectedKind = code.kind
        } else {
            name = selectedKind.displayName
        }
    }

    private func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        processing = true
        errorMessage = nil
        defer { processing = false }
        do {
            let data = try await item.loadTransferable(type: Data.self)
            guard let data, let image = UIImage(data: data) else {
                errorMessage = "无法读取该图片，请换一张试试"
                pickedImageData = nil
                previewImage = nil
                return
            }
            pickedImageData = data
            previewImage = image
        } catch {
            errorMessage = "无法读取该图片，请换一张试试"
            pickedImageData = nil
            previewImage = nil
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if let code = editingCode {
                if !trimmed.isEmpty && trimmed != code.name {
                    PaymentCodeStore.shared.rename(id: code.id, to: trimmed)
                }
                if let data = pickedImageData {
                    try PaymentCodeStore.shared.replaceImage(id: code.id, with: data)
                }
            } else {
                guard let data = pickedImageData else {
                    errorMessage = "请先选择收款码图片"
                    return
                }
                try PaymentCodeStore.shared.addCode(name: trimmed,
                                                    kind: selectedKind,
                                                    imageData: data)
            }
            Haptic.success()
            onSaved()
            dismiss()
        } catch PaymentCodeError.invalidImageData {
            errorMessage = "图片无法识别，请换一张试试"
        } catch {
            errorMessage = "保存失败，请重试"
        }
    }
}

// MARK: - 收款码 Sheet 容器（对齐 V32SheetChrome 视觉；不改动 Profile 私有组件）

@MainActor
private struct PaymentCodeSheetChrome<Content: View>: View {
    let title: String
    var detents: Set<PresentationDetent> = [.medium]
    var doneTitle: String = "完成"
    let onDone: (() -> Void)?
    @ViewBuilder var content: Content

    init(_ title: String,
         detents: Set<PresentationDetent> = [.medium],
         doneTitle: String = "完成",
         onDone: (() -> Void)? = nil,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.detents = detents
        self.doneTitle = doneTitle
        self.onDone = onDone
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    Text(title)
                        .v32Text(.headline)
                        .foregroundStyle(V32.textPrimary)
                    HStack {
                        Spacer()
                        if let onDone {
                            Button(doneTitle, action: onDone)
                                .v32Text(.body)
                                .foregroundStyle(V32.brand)
                        }
                    }
                }
                content
            }
            .padding(.horizontal, V32Layout.pageMargin)
            .padding(.top, 14)
            .padding(.bottom, V32Layout.bottomPad)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .v32Sheet(detents)
    }
}
