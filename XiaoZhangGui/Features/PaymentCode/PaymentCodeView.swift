import SwiftUI
import UIKit
import PhotosUI

// MARK: - V3.3 Lite · 收款码列表页（我的 → 工具 → 收款码）
//
// - 收款码图片只保存在本机 Application Support/PaymentCodes/，不上传、不联网、不进 AI
// - V371：GroupSurface 分组列表 + hairline；空态用 EmptyState primitive
// - 支持：新增（微信 / 支付宝 / 自定义）、重命名、替换图片、删除、全屏左右滑动
// - 业务逻辑（Store / 图片存取 / 删除确认）原样保留

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
            VStack(alignment: .leading, spacing: V371.Space.section) {
                if store.codes.isEmpty {
                    emptyState
                } else {
                    GroupSurface {
                        ForEach(Array(store.codes.enumerated()), id: \.element.id) { index, code in
                            if index > 0 { V371Divider(leading: 0) }
                            PaymentCodeRow(
                                code: code,
                                thumbnail: store.image(for: code),
                                onOpen: { openFullScreen(code) },
                                onEdit: { editorTarget = .edit(code) },
                                onDelete: { pendingDelete = code }
                            )
                        }
                    }
                    privacyFootnote
                }
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.hidden)
        .v371Canvas()
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
        VStack(spacing: V371.Space.section) {
            GroupSurface {
                EmptyState(
                    icon: "qrcode",
                    title: "还没有收款码",
                    message: "添加微信 / 支付宝收款码或自定义二维码，收款时一键全屏展示",
                    buttonTitle: "添加收款码",
                    buttonAction: { editorTarget = .add }
                )
                .padding(.horizontal, 8)
            }
            privacyFootnote
        }
    }

    private var privacyFootnote: some View {
        Label("图片仅保存在本设备，不会上传服务器或发送给任何服务", systemImage: "lock.shield")
            .font(V371.Typography.rowSubtitle)
            .foregroundStyle(V371.Colors.textTertiary)
            .padding(.horizontal, 4)
            .padding(.top, 2)
    }

    private func openFullScreen(_ code: PaymentCode) {
        guard let index = store.codes.firstIndex(where: { $0.id == code.id }) else { return }
        Haptic.light()
        fullScreenSession = FullScreenSession(initialIndex: index)
    }
}

// MARK: - 列表行（缩略图 + 名称/类型 + 全屏入口 + 更多菜单）

@MainActor
private struct PaymentCodeRow: View {
    let code: PaymentCode
    let thumbnail: UIImage?
    let onOpen: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onOpen) {
                HStack(spacing: 12) {
                    thumb
                    VStack(alignment: .leading, spacing: 4) {
                        Text(code.name)
                            .font(V371.Typography.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .lineLimit(1)
                        Text(code.kind.displayName)
                            .font(V371.Typography.rowSubtitle)
                            .foregroundStyle(V371.Colors.textTertiary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.left.and.down.right.magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(V371.Colors.textTertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("全屏展示\(code.name)")

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
                    .foregroundStyle(V371.Colors.textTertiary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(code.name)更多操作")
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 12)
    }

    private var thumb: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    V371.Colors.groupSecondary
                    Image(systemName: code.kind.iconName)
                        .font(.system(size: 18))
                        .foregroundStyle(V371.Colors.textTertiary)
                }
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                .strokeBorder(V371.Colors.divider, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

// MARK: - 新增 / 编辑 Sheet（V371：原生 NavigationStack + Form + toolbar；逻辑原样）

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
        NavigationStack {
            Form {
                Section {
                    previewContent
                }
                if editingCode == nil {
                    Section("类型") {
                        kindTiles
                    }
                }
                Section("名称") {
                    HStack(spacing: 10) {
                        TextField("收款码名称（如：店铺微信）", text: $name)
                            .tint(V371.Colors.blue)
                        if !name.isEmpty {
                            Button { name = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(V371.Colors.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("清空名称")
                        }
                    }
                }
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label(
                            editingCode == nil ? "从相册选择收款码图片" : "替换收款码图片",
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(processing)
                } footer: {
                    Text("仅在本机展示你自己保存的收款码图片，不识别、不解析二维码内容。")
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(V371.Colors.red)
                    }
                }
            }
            .tint(V371.Colors.blue)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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

    private var previewContent: some View {
        ZStack {
            if let previewImage {
                Image(uiImage: previewImage)
                    .resizable()
                    .scaledToFill()
            } else if let existing = existingThumbnail {
                Image(uiImage: existing)
                    .resizable()
                    .scaledToFill()
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 36))
                        .foregroundStyle(V371.Colors.textTertiary)
                        .accessibilityHidden(true)
                    Text("未选择图片")
                        .font(V371.Typography.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .clipShape(RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous))
        .accessibilityLabel("收款码图片预览")
    }

    private var kindTiles: some View {
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
                            .font(V371.Typography.badge)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.vertical, 12)
                    .foregroundStyle(selected ? V371.Colors.blue : V371.Colors.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                            .fill(selected ? V371.Colors.tinted(V371.Colors.blue) : V371.Colors.groupSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: V371.Radius.tile, style: .continuous)
                            .strokeBorder(selected ? V371.Colors.blue.opacity(0.5) : V371.Colors.divider,
                                          lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.displayName)
            }
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
