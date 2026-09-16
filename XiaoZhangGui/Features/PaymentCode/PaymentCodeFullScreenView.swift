import SwiftUI
import UIKit

// MARK: - V3.3 Lite · 收款码全屏展示
//
// - 多张码左右滑动切换（TabView .page），顶部/底部只保留关闭键与当前码名称/页码
// - 进入自动拉高屏幕亮度便于扫码；退出 / inactive / 后台恢复；
//   异常终止由 App 启动时 PaymentCodeBrightnessGuard.applyStartupRecovery() 兜底
// - 图片缺失 / 损坏显示占位，不崩溃

@MainActor
struct PaymentCodeFullScreenView: View {
    let store: PaymentCodeStore
    let codes: [PaymentCode]
    let initialIndex: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: Int
    @State private var brightnessGuard = PaymentCodeBrightnessGuard()

    init(store: PaymentCodeStore, codes: [PaymentCode], initialIndex: Int) {
        self.store = store
        self.codes = codes
        self.initialIndex = initialIndex
        _selection = State(initialValue: initialIndex)
    }

    private var currentCode: PaymentCode? {
        guard codes.indices.contains(selection) else { return codes.first }
        return codes[selection]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(Array(codes.enumerated()), id: \.element.id) { index, code in
                    codePage(code: code)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: codes.count > 1 ? .always : .never))
            .ignoresSafeArea(edges: .bottom)

            chrome
        }
        .statusBar(hidden: true)
        .persistentSystemOverlays(.hidden)
        .onAppear {
            brightnessGuard.begin()
        }
        .onDisappear {
            brightnessGuard.end()
        }
        .onChange(of: scenePhase) { _, phase in
            // 控制中心 / 来电 / 切后台：立即恢复亮度；回到前台且仍在全屏时再次拉高
            switch phase {
            case .inactive, .background:
                brightnessGuard.end()
            case .active:
                brightnessGuard.begin()
            @unknown default:
                break
            }
        }
    }

    // MARK: - 最小化 UI 干扰：仅关闭键 + 底部名称/页码

    private var chrome: some View {
        VStack {
            HStack {
                Button {
                    Haptic.light()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white.opacity(0.85))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("关闭收款码")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Spacer()

            if let code = currentCode {
                VStack(spacing: 4) {
                    Text(code.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if codes.count > 1 {
                        Text("\(code.kind.displayName) · \(selection + 1)/\(codes.count)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    } else {
                        Text(code.kind.displayName)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private func codePage(code: PaymentCode) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 56)
            if let image = store.image(for: code) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 20)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(.white)
                    )
                    .padding(.horizontal, 20)
                    .accessibilityLabel("\(code.name)，双指可放大")
            } else {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 34))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("图片不可用")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                            Text("可返回列表后重新替换该收款码图片")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
            }
            Spacer(minLength: 84)
        }
        .padding(.vertical, 8)
    }
}
