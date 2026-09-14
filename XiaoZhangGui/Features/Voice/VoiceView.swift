import SwiftUI
import SwiftData

struct VoiceView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var viewModel: VoiceViewModel?
    @State private var manualText = ""

    var body: some View {
        PageBackground {
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
                try? await Task.sleep(for: .seconds(1))
                dismiss()
            }
        }
    }

    private func content(_ vm: VoiceViewModel) -> some View {
        ZStack {
            if vm.phase == .listening {
                SpatialRipples()
            }

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        vm.reset()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("关闭")
                }
                .padding(.top, 8)

                Spacer()

                stateTitle(vm)

                Spacer().frame(height: 20)

                transcriptCard(vm)

                if vm.phase == .listening {
                    Spacer().frame(height: 24)
                    VoiceWaveform()
                }

                Spacer().frame(height: 36)

                if vm.isSpeechRecognizerInitialized {
                    centralButton(vm)
                    Spacer().frame(height: 14)
                    hintText(vm)
                }

                if vm.phase == .preview || vm.phase == .saving {
                    previewSection(vm)
                        .padding(.top, 28)
                }

                Spacer()
            }
            .padding(.horizontal, 20)
        }
    }

    private func stateTitle(_ vm: VoiceViewModel) -> some View {
        let isSaved = vm.didSave
        return Text(isSaved ? "已保存" : vm.phase.statusText)
            .font(.title2.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(isSaved ? V21.brandGreen : (isError(vm) ? V21.danger : Color.primary))
    }

    private func isError(_ vm: VoiceViewModel) -> Bool {
        if case .error = vm.phase { return true }
        return false
    }

    private func transcriptCard(_ vm: VoiceViewModel) -> some View {
        Group {
            if !vm.transcript.isEmpty || vm.phase == .listening || vm.phase == .textFallback {
                VStack(spacing: 12) {
                    if vm.phase == .textFallback {
                        TextField("例如：明天提醒我进货 500 元的牛奶", text: $manualText, axis: .vertical)
                            .font(.body)
                            .lineLimit(2...5)
                            .multilineTextAlignment(.center)
                            .onSubmit { submitManual(vm) }
                    } else {
                        Text(vm.transcript.isEmpty ? "请开始说话…" : vm.transcript)
                            .font(.body)
                            .foregroundStyle(vm.transcript.isEmpty ? Color.secondary : Color.primary)
                            .lineSpacing(4)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(18)
                .frame(minHeight: 88, maxWidth: .infinity)
                .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(.separator).opacity(0.28), lineWidth: 0.5)
                )
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
        Button {
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
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 84, height: 84)
                Circle()
                    .fill(vm.phase == .listening ? V21.danger : V21.brandGreen)
                    .frame(width: 68, height: 68)
                Image(systemName: centralIcon(vm))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 84, height: 84)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(vm.phase == .listening ? "停止" : "开始语音")
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
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                            .padding(.vertical, 10)
                            .background(V21.surfacePrimary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(selected ? V21.brandGreen.opacity(0.5) : Color(.separator).opacity(0.35), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

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
                .frame(height: 50)
                .background(V21.brandGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(vm.phase == .saving)
            .padding(.top, 8)
        }
    }
}

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

struct VoiceWaveform: View {
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<15, id: \.self) { index in
                Capsule()
                    .fill(V21.brandGreen)
                    .frame(width: 3, height: waveHeight(index))
                    .animation(
                        .easeInOut(duration: 0.65)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index % 5) * 0.08),
                        value: phase
                    )
            }
        }
        .frame(height: 34)
        .onAppear { phase = true }
    }

    private func waveHeight(_ index: Int) -> CGFloat {
        let base: CGFloat = phase ? 8 : 34
        let factor = CGFloat(1 - (index % 5)) / 5
        return 12 + (base - 12) * factor + (phase ? 6 : -6)
    }
}
