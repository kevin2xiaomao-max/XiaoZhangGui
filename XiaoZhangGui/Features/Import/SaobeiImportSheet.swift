import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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

    private let importer = SaobeiImporter()

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
            List {
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        Label("选择扫呗导出文件", systemImage: "square.and.arrow.down")
                    }
                    Text("优先 CSV。Excel 会尝试解析；失败时请另存为 CSV。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if demo.isEnabled {
                        Button {
                            loadDemoPreview()
                        } label: {
                            Label("查看扫呗 Demo 预览", systemImage: "sparkles")
                        }
                        Text("演示模式只展示完整流程，确认后也不会写入真实数据库。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if isParsing {
                    Section { ProgressView("正在解析…") }
                }

                if let errorText {
                    Section("无法导入") {
                        Text(errorText).foregroundStyle(.red)
                    }
                }

                if let parseResult {
                    Section("文件概览") {
                        LabeledContent("文件", value: parseResult.sourceFileName)
                        LabeledContent("文件记录", value: "\(fileCount) 笔")
                        LabeledContent("有效交易", value: "\(validCount) 笔")
                        LabeledContent("重复", value: "\(displayDuplicateCount) 笔")
                        LabeledContent("新增", value: "\(displayNewCount) 笔")
                        LabeledContent("新增金额", value: Fmt.money(displayAmount))
                        if !parseResult.errors.isEmpty {
                            Text("\(parseResult.errors.count) 行无法解析")
                                .foregroundStyle(.orange)
                        }
                    }

                    if !parseResult.errors.isEmpty {
                        Section("错误行") {
                            ForEach(parseResult.errors.prefix(20), id: \.self) { Text($0).font(.footnote) }
                        }
                    }

                    Section("将写入业绩") {
                        if displayNewCount == 0 {
                            Text("没有新的成功交易。重复导入不会让营业额翻倍。")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach((isDemoPreview ? parseResult.rows : newRows).prefix(5)) { row in
                                BusinessRow(
                                    title: Fmt.money(row.amount),
                                    subtitle: [Fmt.dateTime(row.date), row.paymentMethod, row.orderNo]
                                        .filter { !$0.isEmpty }
                                        .joined(separator: " · ")
                                )
                            }
                        }
                    }
                }

                if let commitResult {
                    Section("导入结果") {
                        LabeledContent("新增", value: "\(commitResult.inserted)")
                        LabeledContent("重复", value: "\(commitResult.duplicates)")
                        LabeledContent("未计入", value: "\(commitResult.skippedFailed)")
                        if demo.isEnabled {
                            Label("Demo 导入完成，真实数据未发生变化", systemImage: "checkmark.shield")
                                .foregroundStyle(V21.brandGreen)
                        }
                    }
                }
            }
            .navigationTitle("扫呗导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确认导入") { commit() }
                        .disabled(displayNewCount == 0 || commitResult != nil)
                }
            }
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
    }

    private static var allowedTypes: [UTType] {
        var types: [UTType] = [.commaSeparatedText, .plainText, .data]
        if let csv = UTType(filenameExtension: "csv") { types.append(csv) }
        if let xlsx = UTType(filenameExtension: "xlsx") { types.append(xlsx) }
        if let xls = UTType(filenameExtension: "xls") { types.append(xls) }
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
            isParsing = true
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
                isParsing = false
            }
            do {
                let data = try Data(contentsOf: url)
                parseResult = try importer.parse(data: data, fileName: url.lastPathComponent)
            } catch {
                parseResult = nil
                errorText = error.localizedDescription
            }
        }
    }

    private func loadDemoPreview() {
        parseResult = DemoImportPreview.parseResult()
        commitResult = nil
        errorText = nil
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
