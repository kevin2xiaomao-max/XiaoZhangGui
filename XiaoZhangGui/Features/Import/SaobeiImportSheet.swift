import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import PhotosUI
import Vision

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
                VStack(alignment: .leading, spacing: 16) {
                pickerCard
                if isParsing { parsingCard }
                if let errorText { errorCard(errorText) }
                if let parseResult {
                    overviewCard(parseResult)
                    if !parseResult.errors.isEmpty { errorsCard(parseResult.errors) }
                    newRowsCard
                }
                if let commitResult { resultCard(commitResult) }
                    V32PrimaryButton(
                        title: commitResult == nil ? "确认导入" : "完成",
                        systemName: commitResult == nil ? "tray.and.arrow.down" : "checkmark"
                    ) {
                        if commitResult == nil { commit() } else { dismiss() }
                    }
                    .disabled(commitResult == nil && displayNewCount == 0)
                    .opacity(commitResult == nil && displayNewCount == 0 ? 0.5 : 1)
                }
                .padding(.horizontal, V32Layout.pageMargin)
                .padding(.top, 14)
                .padding(.bottom, V32Layout.bottomPad)
            }
            .scrollIndicators(.hidden)
            .v32PageBackground()
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

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SecondaryButton(title: "选择扫呗导出文件", systemName: "square.and.arrow.down") {
                showPicker = true
            }
            PhotosPicker(selection: $screenshotItem, matching: .images) {
                Label("从扫呗截图识别预览", systemImage: "text.viewfinder")
                    .v32Text(.subhead)
                    .foregroundStyle(V32.brand)
            }
            .onChange(of: screenshotItem) { _, item in
                guard let item else { return }
                Task { await handleScreenshot(item) }
            }
            if isOCR { ProgressView("正在本地识别截图…") }
            Text("支持 CSV / XLSX。旧版 XLS 请另存为 XLSX 或 CSV。")
                .v32Text(.caption)
                .foregroundStyle(V32.textTertiary)
            if demo.isEnabled {
                Button {
                    loadDemoPreview()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                        Text("查看扫呗 Demo 预览").v32Text(.subhead)
                    }
                    .foregroundStyle(V32.brand)
                }
                .buttonStyle(.plain)
                Text("当前为演示模式，导入不会写入真实数据。")
                    .v32Text(.caption)
                    .foregroundStyle(V32.textTertiary)
            }
        }
    }

    private var parsingCard: some View {
        V32FieldGroup {
            HStack(spacing: 10) {
                ProgressView().tint(V32.brand)
                Text("正在解析…").v32Text(.body).foregroundStyle(V32.textSecondary)
            }
        }
    }

    private func errorCard(_ text: String) -> some View {
        V32FieldGroup {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(V32.danger)
                VStack(alignment: .leading, spacing: 4) {
                    Text("无法导入").v32Text(.headline).foregroundStyle(V32.textPrimary)
                    Text(text).v32Text(.subhead).foregroundStyle(V32.textSecondary)
                }
                Spacer()
            }
        }
    }

    private func overviewCard(_ result: SaobeiParseResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("文件概览")
            V32FieldGroup {
                VStack(spacing: 0) {
                    overviewRow("文件", value: result.sourceFileName)
                    divider
                    overviewRow("文件记录", value: "\(fileCount) 笔")
                    divider
                    overviewRow("有效交易", value: "\(validCount) 笔")
                    divider
                    overviewRow("重复", value: "\(displayDuplicateCount) 笔")
                    divider
                    overviewRow("新增", value: "\(displayNewCount) 笔")
                    divider
                    overviewRow("新增金额", value: Fmt.money(displayAmount), highlight: true)
                    if !result.errors.isEmpty {
                        divider
                        HStack {
                            Text("\(result.errors.count) 行无法解析")
                                .v32Text(.subhead)
                                .foregroundStyle(V32.amber)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private func overviewRow(_ label: String, value: String, highlight: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).v32Text(.subhead).foregroundStyle(V32.textTertiary)
            Spacer(minLength: 12)
            Text(value)
                .v32Text(highlight ? .headline : .body)
                .foregroundStyle(highlight ? V32.brand : V32.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(V32.divider).frame(height: 1)
    }

    private func errorsCard(_ errors: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("错误行")
            V32FieldGroup {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(errors.prefix(20).enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .v32Text(.caption)
                            .foregroundStyle(V32.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var newRowsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("将写入业绩")
            V32FieldGroup {
                if displayNewCount == 0 {
                    Text("没有新的成功交易。重复导入不会让营业额翻倍。")
                        .v32Text(.subhead)
                        .foregroundStyle(V32.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array((isDemoPreview ? (parseResult?.rows ?? []) : newRows).prefix(5).enumerated()), id: \.offset) { index, row in
                            if index > 0 { divider }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(Fmt.money(row.amount))
                                    .v32Text(.headline)
                                    .foregroundStyle(V32.textPrimary)
                                Text([Fmt.dateTime(row.date), row.paymentMethod, row.orderNo]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · "))
                                    .v32Text(.caption)
                                    .foregroundStyle(V32.textTertiary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
        }
    }

    private func resultCard(_ result: SaobeiImportCommitResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            V32SectionHeader("导入结果")
            V32FieldGroup {
                VStack(spacing: 0) {
                    overviewRow("新增", value: "\(result.inserted)")
                    divider
                    overviewRow("重复", value: "\(result.duplicates)")
                    divider
                    overviewRow("未计入", value: "\(result.skippedFailed)")
                    if demo.isEnabled {
                        divider
                        Label("Demo 导入完成，真实数据未发生变化", systemImage: "checkmark.shield")
                            .v32Text(.subhead)
                            .foregroundStyle(V32.brand)
                            .padding(.vertical, 10)
                    }
                }
            }
        }
    }

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
