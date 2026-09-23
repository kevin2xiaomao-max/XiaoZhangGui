import SwiftUI

// MARK: - 外观设置（V3.7.1：行样式 V371 化；主题切换逻辑原样）

@MainActor
struct AppearanceSettingsView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: V371.Space.section) {
                    SectionHeader("显示模式")
                    displayMode
                    SectionHeader("选择主题")
                    themeGrid
                }
                .padding(.horizontal, V371.Space.page)
                .padding(.top, 12)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("外观")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .v371Canvas()
    }

    private var displayMode: some View {
        HStack(spacing: 8) {
            modeButton("跟随系统", icon: "circle.lefthalf.filled", key: "system")
            modeButton("浅色", icon: "sun.max", key: "light")
            modeButton("深色", icon: "moon.stars", key: "dark")
        }
    }

    private func modeButton(_ title: String, icon: String, key: String) -> some View {
        let selected = settings.themeMode == key
        return Button {
            settings.themeMode = key
            Haptic.light()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption.weight(.medium)).lineLimit(1)
            }
            .foregroundStyle(selected ? V371.Colors.blue : V371.Colors.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(
                RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                    .fill(selected ? V371.Colors.tinted(V371.Colors.blue) : V371.Colors.group)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                    .strokeBorder(selected ? V371.Colors.blue.opacity(0.45) : V371.Colors.divider,
                                  lineWidth: selected ? 1.5 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var themeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
            ForEach(AccentTheme.allCases, id: \.rawValue) { theme in
                ThemePreviewCard(theme: theme, isSelected: themeStore.accentTheme == theme) {
                    withAnimation(reduceMotion ? .easeOut(duration: 0.12) : .easeInOut(duration: 0.2)) {
                        themeStore.setAccent(theme)
                    }
                    Haptic.light()
                }
            }
        }
    }
}

private struct ThemePreviewCard: View {
    let theme: AccentTheme
    let isSelected: Bool
    let action: () -> Void

    private var accent: AccentPalette { theme.palette }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text(theme.displayName).font(.subheadline.weight(.semibold))
                    Spacer()
                    if isSelected { Image(systemName: "checkmark.circle.fill").font(.subheadline) }
                }
                .foregroundStyle(Color(accent.accent))

                VStack(alignment: .leading, spacing: 6) {
                    Text("今日营业额").font(.caption2).foregroundStyle(Color(accent.onAccent.opacity(0.72)))
                    Text("¥2,680").font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(Color(accent.onAccent))
                    Capsule().fill(Color(accent.chartAccent)).frame(width: 52, height: 3)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(colors: [Color(accent.heroStart), Color(accent.heroEnd)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous)
                )

                HStack(spacing: 6) {
                    Circle().fill(Color(accent.accent)).frame(width: 7, height: 7)
                    Text("中性内容区域").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(9)
                .background(V371.Colors.groupSecondary,
                            in: RoundedRectangle(cornerRadius: V371.Radius.control, style: .continuous))
            }
            .padding(12)
            .background(V371.Colors.group,
                        in: RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: V371.Radius.group, style: .continuous)
                    .strokeBorder(isSelected ? Color(accent.accent) : V371.Colors.divider,
                                  lineWidth: isSelected ? 2 : 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("主题 \(theme.displayName)\(isSelected ? "，当前选中" : "")")
    }
}
