import SwiftUI
import SwiftData

struct VoiceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: VoiceViewModel?
    @State private var manualText = ""

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
            // 顶部：状态文字 + 关闭（一行，紧凑）
            HStack {
                stateTitle(vm)
                Spacer()
                Button {
                    vm.reset()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // 聆听 / 转写区
            if vm.phase == .preview || vm.phase == .saving {
                previewSection(vm)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
            } else {
                Group {
                    if vm.phase == .textFallback {
                        TextField("例如：明天下午三点联系饮料供应商", text: $manualText, axis: .vertical)
                            .font(.body)
                            .lineLimit(2...3)
                            .multilineTextAlignment(.center)
                            .onSubmit { submitManual(vm) }
                            .padding(10)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else if !vm.transcript.isEmpty {
                        Text(vm.transcript)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    } else {
                        CompactVoiceWaveform()
                            .frame(height: 20)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer(minLength: 0)

                // 主语音按钮
                centralButton(vm)
                    .padding(.top, 4)

                hintText(vm)
                    .padding(.top, 4)
                    .padding(.bottom, 10)
            }
        }
    }

    // MARK: - 子视图

    private func stateTitle(_ vm: VoiceViewModel) -> some View {
        let text: String
        let tint: Color
        if vm.didSave {
            text = "已记录"
            tint = V32.brand
        } else if case .error = vm.phase {
            text = "出错了，点击重试"
            tint = V32.danger
        } else {
            text = vm.phase.statusText
            tint = Color.primary
        }
        return Text(text)
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(tint)
    }

    private func submitManual(_ vm: VoiceViewModel) {
        let text = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        manualText = ""
        vm.submitManualText(text)
    }

    private func centralButton(_ vm: VoiceViewModel) -> some View {
        let press: () -> Void = {
            switch vm.phase {
            case .listening:
                vm.stopListening()
            case .idle, .error:
                vm.reset()
                vm.beginListening()
            case .textFallback:
                submitManual(vm)
            default:
                break
            }
        }
        let tint = vm.phase == .listening ? V32.danger : V32.brand
        let size = V21Layout.centralVoiceButton // 60pt

        return Group {
            if #available(iOS 26.0, *) {
                Button(action: press) {
                    Image(systemName: centralIcon(vm))
                        .font(.system(size: V21Layout.voiceButtonIconSize, weight: .semibold))
                        .frame(width: size, height: size)
                }
                .buttonStyle(.glassProminent)
                .tint(tint)
                .accessibilityLabel(vm.phase == .listening ? "停止" : "开始语音")
            } else {
                Button(action: press) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: size + 12, height: size + 12)
                        Circle()
                            .fill(tint)
                            .frame(width: size, height: size)
                        Image(systemName: centralIcon(vm))
                            .font(.system(size: V21Layout.voiceButtonIconSize, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: size, height: size)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(vm.phase == .listening ? "停止" : "开始语音")
            }
        }
    }

    private func centralIcon(_ vm: VoiceViewModel) -> String {
        switch vm.phase {
        case .listening: return "stop.fill"
        case .textFallback: return "paperplane.fill"
        case .idle, .error: return "mic.fill"
        default: return "mic.fill"
        }
    }

    private func hintText(_ vm: VoiceViewModel) -> some View {
        let text: String
        switch vm.phase {
        case .listening: text = "点击停止"
        case .textFallback: text = "输入后回车解析"
        case .preview, .saving, .parsing: text = ""
        default: text = "点击重新说"
        }
        return Group {
            if !text.isEmpty {
                Text(text)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func previewSection(_ vm: VoiceViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 识别文字作为主要信息
            Text(vm.transcript.isEmpty ? "（未识别到文字）" : vm.transcript)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // 解析结果（紧凑字段展示）
            if let draft = vm.draft {
                parsedFields(draft)
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

            // 保存按钮
            Group {
                if #available(iOS 26.0, *) {
                    Button {
                        Haptic.medium()
                        vm.save()
                    } label: {
                        Group {
                            if vm.phase == .saving {
                                ProgressView().tint(.white)
                            } else {
                                Text("保存")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(V32.brand)
                    .disabled(vm.phase == .saving)
                } else {
                    Button {
                        Haptic.medium()
                        vm.save()
                    } label: {
                        Group {
                            if vm.phase == .saving {
                                ProgressView().tint(.white)
                            } else {
                                Text("保存")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(V32.brand, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.phase == .saving)
                }
            }
        }
    }

    @ViewBuilder
    private func parsedFields(_ draft: VoiceDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            switch draft.type {
            case .revenue, .expense:
                if let amount = draft.amount {
                    fieldRow(label: "金额", value: "¥\(Fmt.money(amount))", icon: "yensign.circle")
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
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func fieldRow(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(V32.brand)
                .frame(width: 18)
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 36, alignment: .leading)
            Text(value)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - 紧凑波形（高度 20pt，轻量动态反馈）

struct CompactVoiceWaveform: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<15, id: \.self) { index in
                let height = computeHeight(index: index)
                Capsule()
                    .fill(V32.brand.opacity(0.7))
                    .frame(width: 2.5, height: height)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index % 5) * 0.07),
                        value: phase
                    )
            }
        }
        .onAppear { phase = true }
    }

    @MainActor
    private func computeHeight(index: Int) -> CGFloat {
        let minH: CGFloat = 4
        let maxH: CGFloat = 18
        let base = phase ? maxH : minH
        let centerDist = abs(index - 7)
        let factor: CGFloat = max(0.4, 1 - CGFloat(centerDist) * 0.08)
        return max(minH, base * factor)
    }
}

// MARK: - 旧组件保留（向后兼容，如果没被引用会被编译器裁剪）

@MainActor
struct SpatialRipples: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(V32.brand.opacity(0.18), lineWidth: 1.5)
                    .scaleEffect(animate ? 2.6 : 0.4)
                    .opacity(animate ? 0 : 0.5)
                    .animation(
                        .linear(duration: 4)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 1.3),
                        value: animate
                    )
            }
        }
        .onAppear { animate = true }
        .allowsHitTesting(false)
    }
}
