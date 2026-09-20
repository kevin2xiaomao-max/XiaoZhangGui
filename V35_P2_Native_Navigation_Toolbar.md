# V3.5 阶段文件 — P2：Native Navigation / Toolbar

> 本文件为《你的小掌柜 V3.5 Liquid Glass Leap 最终执行版 v4》的独立阶段文件（对应总纲第 9 节）。前置条件：P1 已完成并通过交互回归检查。执行前请遵守总纲中的业务基线与禁止事项。
>
> 以 Apple 官方 API 为第一依据，`apple-design` 只做原则约束。完成后执行 `review-animations`。这是 V3.5 最重要的全局杠杆之一。

## 目标

停止各主页面隐藏 Navigation Bar 再自己画 Header。

## 页面改造

### 首页
保留内容里的：问候 / 日期
迁移：快速记录 → `ToolbarItem`；更多控制 → Toolbar / Menu；天气可保留轻量 pill，但不要与 Toolbar 抢宽

### 日程
使用系统 title；trailing 日历按钮；"今天"进入 Toolbar；不自绘顶栏

### 小掌柜 AI
根页禁止返回语义；`navigationTitle("小掌柜")`；右上更多 → Toolbar `Menu`；新对话/清空/AI 设置进入系统 Menu

### 待办
系统 title；新增 → Toolbar plus；删除优先 `swipeActions`

### 我的
`navigationTitle("我的")`；不再是无标题内容页

### 经营数据
恢复系统 back；`navigationTitle("经营数据")`；收入/支出/扫呗导入 → Toolbar Menu

## 原则

- 根 Tab：系统标题 + Toolbar
- 二级页：系统 back
- 禁止自绘返回圆钮
- 禁止 Toolbar 按钮外再包一层旧 `V32PressButtonStyle`

## 重点文件

- `HomeView.swift`
- `ScheduleView.swift`
- `AIChatView.swift`
- `TodoView.swift`
- `ProfileView.swift`
- `PerformanceView.swift`

## 验收

打开 5 个主 Tab：

- 顶部控制明显更像新 iOS
- 不再是一排自绘实心圆钮
- 系统 back 统一
- Dark Mode / Dynamic Type 正常
- iPhone Air Toolbar 不拥挤

## 与已完成阶段的交互回归

本阶段结束前必须确认：
- 不破坏 P0 / P1 已完成的修复
- Tab / Navigation / Sheet / Keyboard / Toolbar / Dark Mode / Dynamic Type 组合行为正常
- iPhone Air 无新增布局回归

## Commit

`ui(v3.5): migrate navigation controls to native toolbars`
