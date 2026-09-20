# V3.5 P0-A SDK / API Audit

审计范围：仅核查当前本机 Xcode / iOS SDK 与 SwiftUI API 可用性，不改生产代码、不创建 V3.5 分支、不推送、不触发 CI、不生成 IPA。

## 1. 环境

| 项目 | 结果 |
|---|---|
| 当前分支 | `fix/v3.4-build34-real-data-repair` |
| V3.4 候选 HEAD | `94e7be88bbb19cd1800f8b60bc1186910c45137d` |
| Xcode | `27.0 (27A266)` |
| iOS SDK | `iPhoneOS27.0.sdk` |
| Deployment Target | `iOS 18.0` |
| Marketing / Build | `3.4.0 (34)` |

结论依据：读取本机 SDK 的 `SwiftUI.swiftinterface`，并使用当前 SDK 对最小 SwiftUI 片段做 `swiftc -typecheck`。生产代码未改动。

## 2. API 可用性表

| 能力 | 当前 SDK 真实 API | 最低系统 | 结论 | 18–25 fallback |
|---|---|---:|---|---|
| Tab bar 最小化 | `View.tabBarMinimizeBehavior(_:)`，参数 `TabBarMinimizeBehavior`；含 `.automatic`、`.onScrollDown`、`.onScrollUp`、`.never` | iOS 26.0 | 可用 | 不调用，保留普通 `TabView` |
| Glass 容器 | `View.glassEffect(_:, in:)` | iOS 26.0 | 可用 | 现有 V32Card / 系统 material |
| Glass button | `.buttonStyle(.glass)` | iOS 26.0 | 可用 | 现有 button style |
| Prominent Glass button | `.buttonStyle(.glassProminent)` | iOS 26.0 | 可用 | 现有 primary button |
| Glass transition/container | `GlassEffectContainer`、`glassEffectTransition` | iOS 26.0 | 可用 | 不启用，保持普通层级 |
| Tab bottom accessory | `View.tabViewBottomAccessory { ... }` | iOS 26.0 | 可用 | `safeAreaInset(edge: .bottom)` |
| Bottom accessory enabled overload | `tabViewBottomAccessory(isEnabled:content:)` | iOS 26.1 | 可用但需单独 gate | 仍用 `safeAreaInset` |
| Accessory placement | `EnvironmentValues.tabViewBottomAccessoryPlacement`，`.inline` / `.expanded` | iOS 26.0 | 可用 | 不依赖该环境值 |
| Navigation | `NavigationStack`, `navigationTitle`, system back | iOS 16 / 13 | 可用 | 当前 deployment target 已覆盖 |
| Toolbar | `ToolbarItem`, `ToolbarItemGroup`, `Menu` | iOS 14+ | 可用 | 无需新 API fallback |
| Sheet | `.sheet`, `presentationDetents`, `presentationDragIndicator` | iOS 13 / 16 / 16 | 可用 | `.sheet`；detents/indicator 做 availability gate |
| Search | `.searchable` | iOS 15 | 可用 | 普通搜索输入或现有搜索 UI |
| Dialog | `.confirmationDialog` | iOS 15 | 可用 | `.alert` / 普通 sheet |
| Share | `ShareLink` | iOS 16 | 可用 | `UIActivityViewController` bridge 或现有分享路径 |

## 3. 真实编译核查

### Tab

SDK interface 暴露：

```swift
@available(iOS 26.0, ...)
public func tabBarMinimizeBehavior(_ behavior: TabBarMinimizeBehavior) -> some View
```

最小片段在 deployment target 18.0 下通过 typecheck，前提是由 `@available(iOS 26.0, *)` 或 `if #available(iOS 26.0, *)` 包裹。`TabView` / `Tab` 的系统路径可继续作为唯一 Tab 根容器；iOS 26/27 的系统 Tab bar 可由系统呈现新外观，不能在静态 typecheck 中证明具体设备渲染细节。

### Glass / System Controls

当前 SDK 暴露：

- `View.glassEffect(_ glass: Glass = .regular, in:)`
- `.buttonStyle(.glass)` / `GlassButtonStyle`
- `.buttonStyle(.glassProminent)` / `GlassProminentButtonStyle`
- `GlassEffectContainer`
- `glassEffectTransition`

上述 API 均要求 iOS 26.0。最小片段在加上 iOS 26 availability gate 后通过 typecheck；未加 gate 时，当前 SDK 会明确报“only available in iOS 26.0 or newer”。因此不能在当前 iOS 18 deployment target 下无条件调用。

Toolbar / Navigation bar 的系统行为可直接依赖 SwiftUI/UIKit 容器在 iOS 26/27 的系统渲染，不需要额外私有 opt-in。当前审计没有发现必须引入私有 API 的要求。Reduce Transparency 等辅助功能状态下，应允许系统降低或替换玻璃效果，并保留不依赖透明度的颜色、边界和层级信息；V35 不应把信息可读性建立在玻璃背景之上。

### Bottom accessory / AI Composer

当前 SDK 暴露：

```swift
@available(iOS 26.0, ...)
public func tabViewBottomAccessory<Content>(
    @ViewBuilder content: () -> Content
) -> some View
```

另有 `isEnabled:` overload，最低 iOS 26.1。该能力适合把 AI Composer 绑定到 TabView 的底部系统区域，但仍需真机检查：键盘出现/收起、Tab bar 最小化、横竖屏、较长输入、Sheet 覆盖时的布局行为。它与 `safeAreaInset` 的主要差异是：前者由 TabView 管理并可参与系统 Tab bar accessory placement，后者是通用安全区插入，不理解 Tab bar 的 inline/expanded 生命周期。

因此 P4 的推荐路径是：iOS 26+ 使用 `tabViewBottomAccessory`；iOS 18–25 保留现有 `safeAreaInset` 路径。不能把 accessory API 直接写在无 gate 的共享主路径中。

## 4. Navigation / Presentation 原生能力

当前 SDK 足以支持 V3.5 所需的原生导航与呈现层：

- `NavigationStack`：可用，项目 deployment target 18.0 已覆盖。
- `navigationTitle`：可用。
- `ToolbarItem` / `ToolbarItemGroup` / `Menu`：可用。
- 系统返回：由 `NavigationStack` 提供；不需要自绘返回按钮作为默认路径。
- `.sheet`：可用。
- `presentationDetents`、`presentationDragIndicator`：可用，均需 iOS 16+，当前 target 已覆盖。
- `.searchable`：可用，iOS 15+。
- `confirmationDialog`：可用，iOS 15+；旧 `ActionSheet` 不应作为新主路径。
- `ShareLink`：可用，iOS 16+。

## 5. Compatibility / fallback

### iOS 27

完整方案可用：系统 `TabView` + `tabBarMinimizeBehavior`、`tabViewBottomAccessory`、Glass effect/button、原生 Navigation/Toolbar/Sheet/Search/Dialog/ShareLink。新 API 仍保留 availability gate，避免模块级复用时产生编译或运行时问题。

### iOS 26

完整或近完整方案可用。Tab 最小化、Glass、基础 bottom accessory 均为 iOS 26.0；`isEnabled` accessory overload 等 iOS 26.1 API 需单独 gate。实现上不应依赖 26.1 专属 overload 才能工作。

### iOS 18–25

稳定 fallback：普通 `TabView`、现有 V32 组件/系统 material、现有 button style、`safeAreaInset` AI Composer、`NavigationStack`、Toolbar、Sheet/detents、searchable、confirmationDialog、ShareLink。所有 iOS 26 API 必须使用 `if #available` 或 `@available` 包裹；不使用伪造的 Glass API、私有符号或无条件调用。

## 6. 对后续阶段的影响

- P1 Tab：可以按系统 `TabView` 方案进入设计；最小化行为只放 iOS 26+ 分支。
- P2 Toolbar / Navigation：原生 API 足够，优先移除自绘返回和隐藏 Toolbar 的依赖，但本轮不执行改造。
- P3 Sheet / Search / Dialog：原生能力完整，detents/drag indicator 使用既有 iOS 16 能力。
- P4 AI Composer：iOS 26+ 可采用 `tabViewBottomAccessory`；iOS 18–25 明确走 `safeAreaInset`。
- P5/P6：Glass 不能替代可读性、Reduce Transparency、Dynamic Type 和深色模式验证；需要保留非玻璃 fallback。

## 7. 风险

1. SDK/typecheck 只能证明符号、签名和 availability；iOS 26/27 的实际 Tab bar Glass 渲染、键盘联动和 accessory 生命周期仍需真机验收。
2. `tabViewBottomAccessory` 的行为依赖 TabView 层级；若 Composer 位于 TabView 外层，可能无法获得预期 placement。
3. 当前 deployment target 为 iOS 18.0，任何 iOS 26 API 无条件调用都会编译失败。
4. Reduce Transparency、Dynamic Type、横屏和 iPhone Air 窄屏必须在后续 UI 阶段单独验证。

## 8. 最终结论

**PARTIAL GO**

核心方向可行：当前 SDK 同时提供 Tab 最小化、Glass、Glass button 和 bottom accessory；但这些能力最低为 iOS 26.0（部分 overload 为 26.1），而项目 deployment target 是 iOS 18.0。因此必须采用 iOS 26/27 新 API + iOS 18–25 fallback 的双路径，不能直接无条件进入共享 UI 主路径。

本轮到此结束，不进入 P0-C、P1 或任何 V3.5 UI 改造。
