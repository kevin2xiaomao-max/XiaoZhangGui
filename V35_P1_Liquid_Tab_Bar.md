# V3.5 阶段文件 — P1：Liquid Tab Bar

> 本文件为《你的小掌柜 V3.5 Liquid Glass Leap 最终执行版 v4》的独立阶段文件（对应总纲第 8 节）。前置条件：P0（含 P0-A SDK/API 核查）已完成并给出 Go 结论。执行前请遵守总纲中的业务基线与禁止事项。
>
> 开始前读取 `apple-design`；完成后使用 `review-animations` 审查滚动、最小化与状态变化。

## 当前事实

RootView 已经使用系统 `TabView` + `Tab(...)`。

## 目标

让现有系统 Tab 在 iOS 26/27 下真正表现出新系统语言。**具体使用哪些 API，以 P0-A 的 `V35_SDK_API_AUDIT.md` 结论为准——若关键 API 不可用，按该文件记录的 fallback 方案执行。**

## 执行

1. 用当前 Xcode / SDK 真机或模拟器确认系统默认 Tab 外观
2. **禁止先自绘假玻璃**
3. 若新 SDK 支持，使用系统滚动最小化行为：`.tabBarMinimizeBehavior(.onScrollDown)` 或当前 SDK 对应官方 API
4. 内容允许自然延伸至 Tab Bar 后方
5. `v32PageBottomInset` 只保留必要呼吸空间
6. 中间"小掌柜"仍是普通 Tab
7. 可通过 icon / label / badge 做轻强调
8. 禁止凸起圆形 FAB
9. AI 语音面板期间统一 Tab hidden / minimize 策略，禁止两套状态打架

## 不做

- Search Tab
- sidebarAdaptable 作为 iPhone 主路径
- FloatingDock 复活

## 重点文件

- `XiaoZhangGui/App/RootView.swift`
- `XiaoZhangGui/DesignSystem/V32/V32PageBottomInset.swift`
- `XiaoZhangGui/DesignSystem/FloatingDock.swift`

## 验收

打开 App 第一眼：

- Tab 不再像旧式固定底栏
- 滚动行为自然
- 内容与 Tab Bar 层级正确
- AI / 键盘 / Sheet 不冲突
- iPhone Air 不挤

## 与已完成阶段的交互回归

本阶段结束前必须确认：
- 不破坏 P0 已完成的修复
- Tab / Navigation / Sheet / Keyboard / Toolbar / Dark Mode / Dynamic Type 组合行为正常
- iPhone Air 无新增布局回归

## Commit

`ui(v3.5): adopt native liquid tab navigation`
