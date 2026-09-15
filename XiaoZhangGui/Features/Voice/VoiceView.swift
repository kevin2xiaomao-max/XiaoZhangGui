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
            // 顶部关闭按钮（小，不抢视觉）
            HStack {
                Spacer()
                Button {
                    vm.reset()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, height: 32)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // 状态文字（居中，简洁）
            stateTitle(vm)
                .padding(.top, 4)

            // 转写/波形区
            Group {
                if vm.phase == .listening || vm.phase == .textFallback || !vm.transcript.isEmpty {
                    transcriptOrWave(vm)
                }
            }
            .padding(.top, 10)
            .padding(.horizontal, 20)

            Spacer(minLength: 0)

            // 主语音按钮（紧凑 60pt）
            centralButton(vm)
                .padding(.bottom, 6)

            // 提示文字（简洁）
            hintText(vm)
                .padding(.bottom, 4)

            // 预览/保存区
            if vm.phase == .preview || vm.phase == .saving {
                previewSection(vm)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            } else {
                Spacer(minLength: 12)
            }
        }
    }

    // MARK: - 子视图

    private func stateTitle(_ vm: VoiceViewModel) -> some View {
        let text: String
        let tint: Color
        if vm.didSave {
            text = "已记录"
            tint = V21.brandGreen
        } else if case .error = vm.phase {
            text = "出错了，点击重试"
            tint = V21.danger
        } else {
            text = vm.phase.statusText
            tint = Color.primary
        }
        return Text(text)
            .font(.headline)
            .multilineTextAlignment(.center)
            .foregroundStyle(tint)
    }

    private func transcriptOrWave(_ vm: VoiceViewModel) -> some View {
        Group {
            if vm.phase == .textFallback {
                TextField("例如：明天提醒我进货 500 元的牛奶", text: $manualText, axis: .vertical)
                    .font(.body)
                    .lineLimit(2...4)
                    .multilineTextAlignment(.center)
                    .onSubmit { submitManual(vm) }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else if !vm.transcript.isEmpty {
                // 识别中 / 有结果 → 显示转写文字在小卡片里
                Text(vm.transcript)
                    .font(.body)
                    .foregroundStyle(Color.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                // 正在聆听但还没有文字 → 轻量波形
                CompactVoiceWaveform()
                    .frame(height: 20)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
            }
        }
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
        let tint = vm.phase == .listening ? V21.danger : V21.brandGreen
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
        VStack(alignment: .leading, spacing: 8) {
            Text("选择记录类型")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(VoiceRecordType.allCases) { type in
                    let selected = vm.recordType == type
                    Button {
                        vm.recordType = type
                        Haptic.light()
                    } label: {
                        Text(type.rawValue)
                            .font(.subheadline.weight(selected ? .semibold : .medium))
                            .foregroundStyle(selected ? V21.brandGreen : Color.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(selected ? V21.brandGreen.opacity(0.5) : Color(.separator).opacity(0.35), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

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
                                Text("保存记录")
                                    .font(.body.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(V21.brandGreen)
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
                                Text("保存记录")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(V21.brandGreen, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.phase == .saving)
                }
            }
            .padding(.top, 4)
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
                    .fill(V21.brandGreen.opacity(0.7))
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
                    .strokeBorder(V21.brandGreen.opacity(0.18), lineWidth: 1.5)
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
