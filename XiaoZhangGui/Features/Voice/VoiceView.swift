import SwiftUI
import SwiftData

// MARK: - AI 语音页（全屏，Typography 驱动 + 空间波纹 + 波形条）
// 状态机：Idle → Listening → Recognized → Parsing → Preview → Saving；Error / TextFallback 分支

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
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(V21.textTertiary)
                            .frame(width: 36, height: 36)
                            .background { Circle().fill(V21.surfaceGlass) }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                Spacer()

                stateTitle(vm)

                Spacer()
                    .frame(height: 20)

                transcriptCard(vm)

                if vm.phase == .listening {
                    Spacer()
                        .frame(height: 32)
                    VoiceWaveform()
                }

                Spacer()
                    .frame(height: 40)

                if vm.isSpeechRecognizerInitialized {
                    centralButton(vm)

                    Spacer()
                        .frame(height: 16)

                    hintText(vm)
                }

                if vm.phase == .preview || vm.phase == .saving {
                    previewSection(vm)
                        .padding(.top, 32)
                }

                Spacer()
            }
            .padding(.horizontal, V21Layout.pageMargin)
        }
    }

    // MARK: - 状态标题

    private func stateTitle(_ vm: VoiceViewModel) -> some View {
        let isSaved = vm.didSave
        return Text(isSaved ? "已保存 ✓" : vm.phase.statusText)
            .v21Style(.titleSection)
            .fontWeight(.semibold)
            .multilineTextAlignment(.center)
            .foregroundColor(isSaved ? AppTheme.palette(named: settings.appThemeName).accent : (isError(vm) ? V21.danger : V21.textPrimary))
    }

    private func isError(_ vm: VoiceViewModel) -> Bool {
        if case .error = vm.phase { return true }
        return false
    }

    // MARK: - 识别文字卡

    private func transcriptCard(_ vm: VoiceViewModel) -> some View {
        Group {
            if !vm.transcript.isEmpty || vm.phase == .listening || vm.phase == .textFallback {
                GlassSurface(radius: V21Layout.radiusLG) {
                    VStack(spacing: 14) {
                        fadeLine
                        if vm.phase == .textFallback {
                            TextField("例如：明天提醒我进货 500 元的牛奶", text: $manualText, axis: .vertical)
                                .v21Style(.bodyLarge)
                                .lineLimit(2...5)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                                .onSubmit { submitManual(vm) }
                        } else {
                            Text(vm.transcript.isEmpty ? "请开始说话…" : vm.transcript)
                                .v21Style(.bodyLarge)
                                .foregroundColor(vm.transcript.isEmpty ? V21.textTertiary : V21.textPrimary)
                                .lineSpacing(4)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                        fadeLine
                    }
                    .padding(20)
                    .frame(minHeight: 118)
                }
            }
        }
    }

    private var fadeLine: some View {
        LinearGradient(
            colors: [.clear, V21.dividerStrong, .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }

    private func submitManual(_ vm: VoiceViewModel) {
        let text = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        manualText = ""
        vm.submitManualText(text)
    }

    // MARK: - 中央按钮

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
        return Group {
            if #available(iOS 26.0, *) {
                // iOS 26+: Liquid Glass prominent 圆形按钮
                Button(action: press) {
                    Image(systemName: centralIcon(vm))
                        .font(.system(size: 26, weight: .medium))
                        .frame(width: 72, height: 72)
                }
                .buttonStyle(.glassProminent)
                .tint(AppTheme.palette(named: settings.appThemeName).accent)
            } else {
                // iOS 18+: 自绘品牌渐变圆 + 阴影
                Button(action: press) {
                    ZStack {
                        Circle()
                            .fill(AnyShapeStyle(AppTheme.palette(named: settings.appThemeName).heroGradient))
                        Image(systemName: centralIcon(vm))
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .frame(width: 72, height: 72)
                    .contentShape(Circle())
                    .shadow(color: AppTheme.palette(named: settings.appThemeName).accent.opacity(0.16), radius: 8, y: 4)
                }
                .buttonStyle(.plain)
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

    // MARK: - 提示文字

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
                    .v21Style(.labelMedium)
                    .foregroundColor(V21.textTertiary)
            }
        }
    }

    // MARK: - 预览区（类型选择 + 保存）

    private func previewSection(_ vm: VoiceViewModel) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("选择记录类型")
                .v21Style(.labelSmall)
                .foregroundColor(V21.textTertiary)

            HStack(spacing: 6) {
                ForEach(VoiceRecordType.allCases) { type in
                    let selected = vm.recordType == type
                    Button {
                        vm.recordType = type
                        Haptic.light()
                    } label: {
                        Text(type.rawValue)
                            .v21Style(.labelMedium)
                            .fontWeight(selected ? .semibold : .medium)
                            .foregroundColor(selected ? AppTheme.palette(named: settings.appThemeName).accent : V21.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selected ? AnyShapeStyle(V21.surfaceElevated) : AnyShapeStyle(V21.surfaceGlass))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }

            Group {
                if #available(iOS 26.0, *) {
                    // iOS 26+: Liquid Glass prominent 保存按钮
                    Button {
                        Haptic.medium()
                        vm.save()
                    } label: {
                        Group {
                            if vm.phase == .saving {
                                ProgressView().tint(.white)
                            } else {
                                Text("保存记录")
                                    .v21Style(.bodyLarge)
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(AppTheme.palette(named: settings.appThemeName).accent)
                    .disabled(vm.phase == .saving)
                } else {
                    // iOS 18+: 自绘品牌渐变按钮
                    Button {
                        Haptic.medium()
                        vm.save()
                    } label: {
                        Group {
                            if vm.phase == .saving {
                                ProgressView().tint(.white)
                            } else {
                                Text("保存记录")
                                    .v21Style(.bodyLarge)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .fill(AppTheme.palette(named: settings.appThemeName).heroGradient)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.phase == .saving)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - 空间波纹（聆听时）

struct SpatialRipples: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .strokeBorder(V21.timeline.opacity(0.35), lineWidth: 1.5)
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

// MARK: - 波形条

struct VoiceWaveform: View {
    @Environment(AppSettings.self) private var settings
    @State private var phase = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<15, id: \.self) { index in
                Capsule()
                    .fill(AppTheme.palette(named: settings.appThemeName).accent)
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
