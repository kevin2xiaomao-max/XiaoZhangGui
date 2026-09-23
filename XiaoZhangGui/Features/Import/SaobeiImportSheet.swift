import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI
import Vision

// MARK: - 扫呗导入 Sheet（V371：分组列表语言；解析/去重/写入等业务行为原样保留）

struct SaobeiImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var performances: [Performance]
    @Bindable private var demo = DemoMode.shared

    @State private var parseResult: SaobeiParseResult?
    @State private var errorText: String?
    @State private var commitResult: SaobeiImportCommitResult?
    @State private var showPicker = false
    @State private var isParsing = false
    @State private var screenshotItem: PhotosPickerItem?
    @State private var isOCR = false

    private var existing: Set<String> {
        Set(performances.map(\.fingerprint).filter { !$0.isEmpty })
    }

    private var newRows: [SaobeiParsedRow] {
        (parseResult?.rows ?? []).filter { !existing.contains($0.fingerprint) }
    }

    private var duplicateCount: Int {
        (parseResult?.rows ?? []).filter { existing.contains($0.fingerprint) }.count
    }

    private var isDemoPreview: Bool {
        demo.isEnabled && parseResult?.sourceFileName == DemoImportPreview.fileName
    }

    private var fileCount: Int {
        isDemoPreview ? DemoImportPreview.fileCount : (parseResult?.rows.count ?? 0) + (parseResult?.skipped.count ?? 0)
    }

    private var validCount: Int {
        isDemoPreview ? DemoImportPreview.validCount : (parseResult?.rows.filter { $0.isSuccess }.count ?? 0)
    }

    private var displayDuplicateCount: Int {
        isDemoPreview ? DemoImportPreview.duplicateCount : duplicateCount
    }

    private var displayNewCount: Int {
        isDemoPreview ? DemoImportPreview.insertedCount : newRows.count
    }

    private var displayAmount: Double {
        isDemoPreview ? DemoImportPreview.amount : newRows.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    pickerCard
                    if isParsing { parsingCard }
                    if let errorText { errorCard(errorText) }
                    if let parseResult {
                        overviewCard(parseResult)
                        if !parseResult.errors.isEmpty { errorsCard(parseResult.errors) }
                        newRowsCard
                    }
                    if let commitResult { resultCard(commitResult) }
                    confirmButton
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .v371Canvas()
            .navigationTitle("扫呗导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .fileImporter(
            isPresented: $showPicker,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePick(result)
        }
        .task {
            if demo.isEnabled && parseResult == nil { loadDemoPreview() }
        }
    }

    // MARK: - 文件选择

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: V371.Space.rowGap) {
            GroupSurface {
                WorkRow(
                    icon: "square.and.arrow.down",
                    iconColor: V371.Colors.blue,
                    title: "选择扫呗导出文件",
                    action: { showPicker = true },
                    trailing: { V371Chevron() }
                )
                V371Divider()
                PhotosPicker(selection: $screenshotItem, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "text.viewfinder")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(V371.Colors.blue)
                            .frame(width: 36, height: 36)
                            .background(V371.Colors.tinted(V371.Colors.blue), in: Circle())
                            .accessibilityHidden(true)
                        Text("从扫呗截图识别预览")
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        V371Chevron()
                    }
                    .padding(.horizontal, V371.Space.rowPadding)
                    .padding(.vertical, 12)
                    .frame(minHeight: 60)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("从扫呗截图识别预览")
                .onChange(of: screenshotItem) { _, item in
                    guard let item else { return }
                    Task { await handleScreenshot(item) }
                }
                if isOCR {
                    V371Divider()
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(V371.Colors.blue)
                        Text("正在本地识别截图…")
                            .font(V371.Type.rowTitle)
                            .foregroundStyle(V371.Colors.textSecondary)
                    }
                    .padding(.horizontal, V371.Space.rowPadding)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Text("支持 CSV / XLSX。旧版 XLS 请另存为 XLSX 或 CSV。")
                .font(V371.Type.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
                .padding(.horizontal, 4)
            if demo.isEnabled {
                Button {
                    Haptic.light()
                    loadDemoPreview()
                } label: {
                    Label("查看扫呗 Demo 预览", systemImage: "sparkles")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(V371.Colors.blue)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Text("当前为演示模式，导入不会写入真实数据。")
                    .font(V371.Type.rowSubtitle)
                    .foregroundStyle(V371.Colors.textTertiary)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var parsingCard: some View {
        GroupSurface {
            HStack(spacing: 10) {
                ProgressView()
                    .tint(V371.Colors.blue)
                Text("正在解析…")
                    .font(V371.Type.rowTitle)
                    .foregroundStyle(V371.Colors.textSecondary)
            }
            .padding(.horizontal, V371.Space.rowPadding)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func errorCard(_ text: String) -> some View {
        GroupSurface {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(V371.Colors.red)
                    .frame(width: 36, height: 36)
                    .background(V371.Colors.tinted(V371.Colors.red), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("无法导入")
                        .font(V371.Type.rowTitle)
                        .foregroundStyle(V371.Colors.textPrimary)
                    Text(text)
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, V371.Space.rowPadding)
            .padding(.vertical, 14)
        }
    }

    // MARK: - 解析结果

    private func overviewCard(_ result: SaobeiParseResult) -> some View {
        VStack(alignment: .leading, spacing: V371.Space.rowGap) {
            SectionHeader("文件概览")
            GroupSurface {
                overviewRow("文件", value: result.sourceFileName)
                V371Divider(leading: 0)
                overviewRow("文件记录", value: "\(fileCount) 笔")
                V371Divider(leading: 0)
                overviewRow("有效交易", value: "\(validCount) 笔")
                V371Divider(leading: 0)
                overviewRow("重复", value: "\(displayDuplicateCount) 笔")
                V371Divider(leading: 0)
                overviewRow("新增", value: "\(displayNewCount) 笔")
                V371Divider(leading: 0)
                overviewRow("新增金额", value: Fmt.money(displayAmount), highlight: true)
                if !result.errors.isEmpty {
                    V371Divider(leading: 0)
                    Text("\(result.errors.count) 行无法解析")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.orange)
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func overviewRow(_ label: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(V371.Type.rowSubtitle)
                .foregroundStyle(V371.Colors.textTertiary)
            Spacer(minLength: 12)
            Text(value)
                .font(V371.Type.rowTitle)
                .foregroundStyle(highlight ? V371.Colors.blue : V371.Colors.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, V371.Space.rowPadding)
        .padding(.vertical, 12)
    }

    private func errorsCard(_ errors: [String]) -> some View {
        VStack(alignment: .leading, spacing: V371.Space.rowGap) {
            SectionHeader("错误行")
            GroupSurface {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(errors.prefix(20).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(V371.Type.rowSubtitle)
                            .foregroundStyle(V371.Colors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, V371.Space.rowPadding)
                .padding(.vertical, 12)
            }
        }
    }

    private var newRowsCard: some View {
        VStack(alignment: .leading, spacing: V371.Space.rowGap) {
            SectionHeader("将写入业绩")
            GroupSurface {
                if displayNewCount == 0 {
                    Text("没有新的成功交易。重复导入不会让营业额翻倍。")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.vertical, 14)
                } else {
                    ForEach(Array((isDemoPreview ? (parseResult?.rows ?? []) : newRows).prefix(5).enumerated()), id: \.offset) { index, row in
                        if index > 0 { V371Divider(leading: 0) }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Fmt.money(row.amount))
                                .font(V371.Type.rowTitle)
                                .foregroundStyle(V371.Colors.textPrimary)
                            Text([Fmt.dateTime(row.date), row.paymentMethod, row.orderNo]
                                .filter { !$0.isEmpty }
                                .joined(separator: " · "))
                                .font(V371.Type.rowSubtitle)
                                .foregroundStyle(V371.Colors.textTertiary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private func resultCard(_ result: SaobeiImportCommitResult) -> some View {
        VStack(alignment: .leading, spacing: V371.Space.rowGap) {
            SectionHeader("导入结果")
            GroupSurface {
                overviewRow("新增", value: "\(result.inserted)")
                V371Divider(leading: 0)
                overviewRow("重复", value: "\(result.duplicates)")
                V371Divider(leading: 0)
                overviewRow("未计入", value: "\(result.skippedFailed)")
                if demo.isEnabled {
                    V371Divider(leading: 0)
                    Label("Demo 导入完成，真实数据未发生变化", systemImage: "checkmark.shield")
                        .font(V371.Type.rowSubtitle)
                        .foregroundStyle(V371.Colors.blue)
                        .padding(.horizontal, V371.Space.rowPadding)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    // MARK: - 确认导入 CTA

    private var confirmButton: some View {
        let isDone = commitResult != nil
        return Button {
            Haptic.light()
            if isDone { dismiss() } else { commit() }
        } label: {
            Label(isDone ? "完成" : "确认导入",
                  systemImage: isDone ? "checkmark" : "tray.and.arrow.down")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(V371.Colors.blue, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isDone && displayNewCount == 0)
        .opacity(!isDone && displayNewCount == 0 ? 0.5 : 1)
        .accessibilityLabel(isDone ? "完成" : "确认导入")
    }

    // MARK: - 业务逻辑（原样保留）

    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .plainText, .data]
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
        // P3-5：去掉 .xls（旧二进制格式不伪装支持）
        return types
    }

    private func handlePick(_ result: Result<[URL], Error>) {
        errorText = nil
        commitResult = nil
        switch result {
        case .failure(let error):
            errorText = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            // P0-1：原 defer 在 switch case 块结束就执行，isParsing 立即被设回 false，
            // UI 几乎不显示「正在解析」；且同步 parse 阻塞 main thread。
            // 改用 Task @MainActor 异步解析，让 UI 状态变化先渲染再执行重活。
            isParsing = true
            let fileName = url.lastPathComponent
            Task { @MainActor in
                do {
                    let parsed = try await Task.detached(priority: .userInitiated) {
                        try SaobeiImportWorker.parse(url: url, fileName: fileName)
                    }.value
                    parseResult = parsed
                    errorText = nil
                } catch {
                    parseResult = nil
                    errorText = error.localizedDescription
                }
                isParsing = false
            }
        }
    }

    private func loadDemoPreview() {
        parseResult = DemoImportPreview.parseResult()
        commitResult = nil
        errorText = nil
    }

    @MainActor
    private func handleScreenshot(_ item: PhotosPickerItem) async {
        isOCR = true
        defer { isOCR = false; screenshotItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { throw SaobeiImportError.noHeader }
            let candidates = try await Task.detached(priority: .userInitiated) {
                try SaobeiScreenshotOCR.recognize(imageData: data)
            }.value
            guard !candidates.isEmpty else { throw SaobeiImportError.noHeader }
            parseResult = SaobeiParseResult(rows: candidates.map { candidate in
                let fingerprint = "ocr-\(candidate.sourceKey)"
                return SaobeiParsedRow(date: candidate.date, amount: candidate.amount, status: "成功", orderNo: candidate.orderNo ?? fingerprint, paymentMethod: candidate.paymentMethod ?? "扫呗截图", fingerprint: fingerprint, isSuccess: true, rawLine: "OCR")
            }, skipped: [], errors: [], sourceFileName: "扫呗截图（本地 OCR）")
            errorText = nil
            commitResult = nil
        } catch { errorText = "截图无法识别，请确认日期和金额清晰后重试。" }
    }

    private func commit() {
        if demo.isEnabled {
            commitResult = isDemoPreview
                ? DemoImportPreview.fakeCommit
                : SaobeiImportCommitResult(inserted: newRows.count, duplicates: duplicateCount, skippedFailed: parseResult?.skipped.count ?? 0)
            Haptic.success()
            return
        }
        do {
            let result = try PerformanceRepository(context: context)
                .importSaobei(newRows, skippedFailed: parseResult?.skipped.count ?? 0)
            commitResult = result
            parseResult = nil
            Haptic.success()
        } catch {
            errorText = error.localizedDescription
            Haptic.error()
        }
    }
}
