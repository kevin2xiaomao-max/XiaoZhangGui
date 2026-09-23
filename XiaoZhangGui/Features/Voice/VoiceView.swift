import SwiftUI
import SwiftData

// MARK: - 语音记账（V3.7.1 Presentation 重构 · §10.3）
//
// 流程完整保留：speech → parse → preview → confirm → save。
// 去掉老旧「大圆麦克风占满页面」设计，改为：
// clear header + waveform/listening state + transcript + parsed preview + confirm/save + cancel。
// 所有业务调用（beginListening/stopListening/submitManualText/save/reset）原样走 VoiceViewModel。

struct VoiceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: VoiceViewModel?
    @State private var manualText = ""
    @FocusState private var manualFocused: Bool

    /// 允许外部注入已创建的 ViewModel（RootView 预创建）；nil 时按原逻辑在 onAppear 懒创建。
    init(viewModel: VoiceViewModel? = nil) {
        _viewModel = State(initialValue: viewModel)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if let vm = viewModel {
                content(vm)
                    .onAppear {
                        guard vm.isSpeechRecognizerInitialized else { return }
                        vm.beginListening()
                    }
            } else {
                Color.clear.onAppear {
                    viewModel = VoiceViewModel(context: context)
                }
            }
        }
        .onChange(of: viewModel?.didSave ?? false) { _, saved in
            guard saved else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.8))
                dismiss()
            }
        }
    }

    private func content(_ vm: VoiceViewModel) -> some View {
        VStack(spacing: 0) {
            header(vm)

            if vm.phase == .preview || vm.phase == .saving {
                previewSection(vm)
            } else {
                listeningSection(vm)
            }
        }
        .v371Canvas()
    }

    // MARK: - Clear header

    private func header(_ vm: VoiceViewModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("语音记账")
                    .font(.headline)
                    .foregroundStyle(V371.Colors.textPrimary)
                stateTitle(vm)
            }
            Spacer(minLength: 8)
            Button {
                Haptic.light()
                vm.reset()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(V371.Colors.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(V371.Colors.groupSecondary))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
        }
        .padding(.horizontal, V371.Space.page)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }

    private func stateTitle(_ vm: VoiceViewModel) -> some View {
        let text: String
        let tint: Color
        if vm.didSave {
            text = "已记录"
            tint = V371.Colors.green
        } else if case .error = vm.phase {
            text = "出错了，点击重试"
            tint = V371.Colors.red
        } else {
            text = vm.phase.statusText
            tint = V371.Colors.textSecondary
        }
        return Text(text)
            .font(.subheadline)
            .foregroundStyle(tint)
    }

    // MARK: - Listening state：waveform + transcript + actions

    private func listeningSection(_ vm: VoiceViewModel) -> some View {
        VStack(spacing: 14) {
            // waveform / listening state
            Group {
                if vm.phase == .textFallback {
                    TextField("例如：明天下午三点联系饮料供应商", text: $manualText, axis: .vertical)
                        .font(.body)
                        .lineLimit(2...4)
                        .focused($manualFocused)
                        .onSubmit { submitManual(vm) }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("完成") { manualFocused = false }
                            }
                        }
                        .padding(V371.Space.rowPadding)
                        .background(
                            RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                                .fill(V371.Colors.group)
                        )
                } else {
                    VStack(spacing: 10) {
                        if vm.phase == .listening || vm.phase == .recognized || vm.phase == .parsing {
                            CompactVoiceWaveform()
                                .frame(height: 24)
                                .frame(maxWidth: .infinity)
                                .accessibilityHidden(true)
                        }
                        // transcript
                        Text(vm.transcript.isEmpty ? transcriptPlaceholder(for: vm.phase) : vm.transcript)
                            .font(.body)
                            .foregroundStyle(vm.transcript.isEmpty ? V371.Colors.textTertiary : V371.Colors.textPrimary)
                            .lineLimit(4)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                    .padding(V371.Space.rowPadding)
                    .background(
                        RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                            .fill(V371.Colors.group)
                    )
                }
            }
            .padding(.horizontal, V371.Space.page)

            if case .error(let message) = vm.phase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(V371.Colors.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, V371.Space.page)
            }

            Spacer(minLength: 0)

            // actions：primary（开始/停止/重试/解析）+ cancel
            VStack(spacing: 10) {
                primaryActionButton(vm)
                Button {
                    Haptic.light()
                    vm.reset()
                    dismiss()
                } label: {
                    Text("取消")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(V371.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.bottom, 12)
        }
        .padding(.top, 6)
    }

    private func transcriptPlaceholder(for phase: VoicePhase) -> String {
        switch phase {
        case .listening: return QuickCaptureSemantic.listening
        case .recognized, .parsing: return QuickCaptureSemantic.processing
        case .textFallback: return ""
        default: return "点击「开始说话」，例如：今天美团680"
        }
    }

    private func primaryActionButton(_ vm: VoiceViewModel) -> some View {
        let title: String
        let icon: String
        let tint: Color
        let action: () -> Void
        let enabled: Bool
        switch vm.phase {
        case .listening:
            title = "停止识别"; icon = "stop.fill"; tint = V371.Colors.red
            action = { vm.stopListening() }; enabled = true
        case .idle, .error:
            title = vm.phase == .idle ? "开始说话" : "重试"
            icon = "mic.fill"; tint = V371.Colors.blue
            action = { vm.reset(); vm.beginListening() }; enabled = true
        case .textFallback:
            title = "解析"; icon = "paperplane.fill"; tint = V371.Colors.blue
            action = { submitManual(vm) }; enabled = true
        case .recognized, .parsing:
            title = QuickCaptureSemantic.processing; icon = "waveform"; tint = V371.Colors.blue
            action = {}; enabled = false
        case .preview, .saving:
            title = ""; icon = ""; tint = V371.Colors.blue
            action = {}; enabled = false
        }
        return Button {
            Haptic.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if enabled || vm.phase == .recognized || vm.phase == .parsing {
                    if vm.phase == .recognized || vm.phase == .parsing {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                    }
                }
                Text(title)
                    .font(.body.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(
                Capsule(style: .continuous)
                    .fill(enabled ? tint : V371.Colors.gray.opacity(0.4))
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }

    private func submitManual(_ vm: VoiceViewModel) {
        let text = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        manualText = ""
        vm.submitManualText(text)
    }

    // MARK: - Parsed preview + confirm/save + cancel

    private func previewSection(_ vm: VoiceViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // 识别文字作为主要信息
                Text(vm.transcript.isEmpty ? "（未识别到文字）" : vm.transcript)
                    .font(.body.weight(.medium))
                    .foregroundStyle(V371.Colors.textPrimary)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(V371.Space.rowPadding)
                    .background(
                        RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                            .fill(V371.Colors.group)
                    )

                // 解析结果（紧凑字段展示）
                if let draft = vm.draft {
                    SectionHeader("解析结果")
                        .padding(.horizontal, 4)
                    GroupSurface {
                        parsedFields(draft)
                            .padding(V371.Space.rowPadding)
                    }
                }

                // 类型选择（系统 segmented，紧凑）
                Picker("类型", selection: Binding(
                    get: { vm.recordType },
                    set: { vm.recordType = $0; Haptic.light() }
                )) {
                    ForEach(VoiceRecordType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.top, 2)

                // 确认保存
                Button {
                    Haptic.medium()
                    vm.save()
                } label: {
                    Group {
                        if vm.phase == .saving {
                            ProgressView().tint(.white)
                        } else {
                            Text("确认保存")
                                .font(.body.weight(.semibold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        Capsule(style: .continuous)
                            .fill(V371.Colors.blue)
                    )
                }
                .buttonStyle(.plain)
                .disabled(vm.phase == .saving)
                .accessibilityLabel("确认保存")

                // 取消
                Button {
                    Haptic.light()
                    vm.reset()
                } label: {
                    Text("取消")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(V371.Colors.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("取消本次语音")
            }
            .padding(.horizontal, V371.Space.page)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private func parsedFields(_ draft: VoiceDraft) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch draft.type {
            case .revenue, .expense:
                if let amount = draft.amount {
                    fieldRow(label: "金额", value: Fmt.money(amount), icon: "yensign.circle")
                }
            case .expiry:
                fieldRow(label: "商品", value: draft.title, icon: "shippingbox")
                if let days = draft.expiryDays {
                    fieldRow(label: "临期", value: "还有 \(days) 天", icon: "exclamationmark.triangle")
                }
            case .customer:
                if let customer = draft.customerName {
                    fieldRow(label: "客户", value: customer, icon: "person")
                }
                if let goods = draft.goodsName {
                    fieldRow(label: "商品", value: goods, icon: "cart")
                }
                if let qty = draft.quantity {
                    fieldRow(label: "数量", value: "\(qty)", icon: "number")
                }
            case .memo:
                fieldRow(label: "备忘", value: draft.detail, icon: "note.text")
            case .todo:
                fieldRow(label: "事项", value: draft.title, icon: "checkmark.circle")
            }
            if let due = draft.dueAt {
                fieldRow(label: "时间", value: Fmt.monthDayTime(due), icon: "clock")
            }
        }
        .font(.subheadline)
    }

    private func fieldRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(V371.Colors.blue)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(label)
                .foregroundStyle(V371.Colors.textSecondary)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .foregroundStyle(V371.Colors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 紧凑波形（轻量动态反馈 · V371）

struct CompactVoiceWaveform: View {
    @State private var phase = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<15, id: \.self) { index in
                let height = computeHeight(index: index)
                Capsule()
                    .fill(V371.Colors.blue.opacity(0.7))
                    .frame(width: 2.5, height: height)
                    .animation(
                        reduceMotion ? nil : V32Motion.slow
                            .repeatForever(autoreverses: true)
                            .delay(Double(index % 5) * 0.07),
                        value: phase
                    )
            }
        }
        .onAppear { phase = !reduceMotion }
        .accessibilityHidden(true)
    }

    @MainActor
    private func computeHeight(index: Int) -> CGFloat {
        let minH: CGFloat = 4
        let maxH: CGFloat = 22
        let base = phase ? maxH : minH
        let centerDist = abs(index - 7)
        let factor: CGFloat = max(0.4, 1 - CGFloat(centerDist) * 0.08)
        return max(minH, base * factor)
    }
}
