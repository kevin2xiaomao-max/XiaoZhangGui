import SwiftUI

// MARK: - V32 / Theme · Environment 注入（b28 T23）
//
// 设计依据：spec FR-22.1 / V32ThemeEnvironment.swift
// - 视图通过 @Environment(ThemeStore.self) 取当前调色板
// - App 入口 .environment(ThemeStore.shared) 注入
// - V32 静态 token 仍走 ThemeStore.shared，二者等价（注入即 shared）

private struct V32ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeStore? = nil
}

extension EnvironmentValues {
    /// 当前 ThemeStore（App 入口注入 ThemeStore.shared）
    var v32ThemeStore: ThemeStore? {
        get { self[V32ThemeEnvironmentKey.self] }
        set { self[V32ThemeEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// 在 View 树注入 ThemeStore。App 入口调用：`.environment(ThemeStore.shared)`
    func v32Theme(_ store: ThemeStore) -> some View {
        environment(\.v32ThemeStore, store)
    }
}
