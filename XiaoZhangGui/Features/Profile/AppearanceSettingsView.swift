import SwiftUI

@MainActor
struct AppearanceSettingsView: View {
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                sectionTitle("显示模式")
                displayMode
                sectionTitle("选择主题")
                themeGrid
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 30)
        }
        .scrollIndicators(.hidden)
        .v32PageBackground()
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.title3.weight(.bold)).foregroundStyle(V32.textPrimary)
    }

    private var displayMode: some View {
        HStack(spacing: 8) {
            modeButton("跟随系统", icon: "circle.lefthalf.filled", key: "system")
            modeButton("浅色", icon: "sun.max", key: "light")
            modeButton("深色", icon: "moon.stars", key: "dark")
        }
    }

    private func modeButton(_ title: String, icon: String, key: String) -> some View {
        Button {
            settings.themeMode = key
            Haptic.light()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon).font(.headline)
                Text(title).font(.caption.weight(.medium)).lineLimit(1)
            }
            .foregroundStyle(settings.themeMode == key ? V32.brand : V32.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 68)
            .background(settings.themeMode == key ? V32.brandSoft : V32.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(settings.themeMode == key ? V32.brand.opacity(0.4) : V32.cardOutline, lineWidth: 1))
        }
        .buttonStyle(.plain)
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
                .background(LinearGradient(colors: [Color(accent.heroStart), Color(accent.heroEnd)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 6) {
                    Circle().fill(Color(accent.accent)).frame(width: 7, height: 7)
                    Text("中性内容区域").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(9)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .padding(12)
            .background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isSelected ? Color(accent.accent) : V32.cardOutline, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("主题 \(theme.displayName)\(isSelected ? "，当前选中" : "")")
    }
}
