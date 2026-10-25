# Muse 接手说明 · 你的小掌柜 V4.0 Full UI Handoff

> 交付日期 2026-10-25 · 基线 V3.9.2 (41) `a6bfced` · 设计方向 B70/A20/C10

## 0. 一句话状态

V4.0 全功能 UI 重构的**设计阶段已完成并通过自动化验收**：13 页可交互 HTML 原型（Light/Dark，单文件离线）、设计系统、SwiftUI 实现规范、V3.9.3 合并映射、验收报告、资源清单。下一步是 **Mac 上的 SwiftUI 集成**，不在本交付范围，本文给出接手顺序与边界。

## 1. 先读什么（按这个顺序）

| 顺序 | 文档 | 为什么 |
|---|---|---|
| 1 | `07-muse-handoff.md`（本文） | 边界、已定案、禁动项 |
| 2 | `01-design-system.md` | 全部 token/字号/间距/动效；**§9 日历金色定案**与对比度实测值 |
| 3 | `00-page-inventory.md` | V3.9.2 真实页面、交互、文案清单（§20 为权威核对） |
| 4 | `03-v393-merge-map.md` | V3.9.3 已并入基线的 11 项功能 + §4.1 原型页→代码映射 |
| 5 | `04-swiftui-spec.md` | 13 页逐页 SwiftUI 规范 + §7 动效配方 |
| 6 | `05-acceptance-report.md` | 六页 + 扩展七页验收结果、逐项比较、限制 |
| 7 | `06-affectui-reference.md` | 动效参考来源（可选） |

原型入口：`index.html`（13 页画廊，离线可开）。

## 2. 代码与分支

- 仓库：https://github.com/kevin2xiaomao-max/XiaoZhangGui
- 设计分支：`design/v40-full-ui-evolution`（从 `a6bfced` 建立，**只新增交付物，不改业务代码**）
- 交付物路径：仓库内 `design/v40-fusion/`
- 基线：`a6bfced` =「Merge PR #6 … ios/v392-second-batch-fixes」= V3.9.2 (41)，`MARKETING_VERSION 3.9.2`
- **禁动**：`main`、`ios/v392-integration`、`ios/v392-*`（Muse 的 V3.9.3 开发线）、任何 Tag；不强制推送
- 本地工作树：`C:\Users\Administrator\Documents\deepseek-harness\default-workspace\xiaozhanggui-v40`

## 3. 已冻结的信息架构（不要改）

1. 4 个原生 Tab：首页 / 待办 / 日历 / 经营（`RootView.swift`，冻结）。
2. AI **不是 Tab**：`xzg://ai` 深链 + 首页入口 → `AIChatView` sheet `.large`；`xzg://voice`、`xzg://quickrecord` 同机制。
3. 首页唯一视觉重点是 Revenue Hero；**快捷操作行、今日最重要、最近记录不复活**（2026-10-23 已否决，源码注释禁恢复）。
4. 金额用衬线 tabular（Georgia / Songti SC）；语义色走系统；品牌绿只做 accent。
5. 主按钮实心 `#146B52` + 白字（6.45）；绿色文字浅色 `#146B52` / 深色 `#2FBF71`。

## 4. 已定案（已写入 Huashu 外观账本，不要再翻案）

- 融合比例 **B70 / A20 / C10**（B 原生结构打底，A 收据/衬线金额点缀，C 留白与语音球只进 AI 页）。
- **日历保留 PR-K 金色**（2026-10-25 用户确认）：今日圆 `#D4A017` + 深墨字（7.12）、选中环 `#B8860B`（3.03–3.25）、密度 chips 金底深墨字；浅底金圆必须带 1pt 金环；金不进 AI/经营/待办/客户页，禁止白字压金。
- 品牌绿对比度规则（`01-design-system.md` §1 全表）；`#1FA971` 只做图表/选中/图形。
- 动效归一到 V32Motion（0.18 / 0.28 / 0.42 + easeOut），Reduce Motion 全静态。

## 5. Muse 在 Mac 上要做的事

1. 新 worktree 打开 `design/v40-full-ui-evolution`，**不要**基于它改业务逻辑，只作为设计参考。
2. 按 `04-swiftui-spec.md` 逐页替换 View，建议顺序：工作台 → AI 对话 → 经营 → 待办 → 客户配送 → 日历 → 扩展七页。
3. 图表用 Swift Charts 替换 HTML 柱图；月报图片走 `ImageRenderer`（390pt 宽）。
4. 实机动效：`matchedGeometryEffect` 滑移、ghost 行沉降（`V38ScheduleLayout` 已有）、`ContentTransition.numericText` 数字滚动、shimmer mask。
5. VoiceOver 标签与 Dynamic Type 实机验证（原型未覆盖，属验收缺口）。
6. Token 落到 `ThemeStore` / 语义 token 层，按 `01-design-system.md` §9 建金色 token。

## 6. 本地复验命令（Windows，捆绑 node）

```bash
NODE="C:/Users/Administrator/.dsh/dsh-runtimes/dsh-primary-runtime/dependencies/node/bin/node.exe"
cd design/v40-fusion
"$NODE" build.mjs                                  # 重建 13 页
"$NODE" audit-all.mjs                              # 审计 13 页，exit 2 = 有失败
"$NODE" drive.mjs --url "file:///C:/.../fusion-home.html" \
  --out "shots/home.png" --width 1500 --height 2000 --scale 2 \
  --click "掌柜晨报||关闭"                          # 真实鼠标点击 + 截图
```

`_vendor/` 不随包（3MB）：从 unpkg 取 `react@18.3.1/umd/react.production.min.js`、`react-dom@18.3.1/umd/react-dom.production.min.js`、`@babel/standalone@7.26.4/babel.min.js`，放进 `_vendor/` 并重命名为 `react.js` / `react-dom.js` / `babel.js`，再放 `ios_frame.jsx`（Huashu skill 的 `assets/ios_frame.jsx`）即可重建。

## 7. 已知限制（不要当作已验收）

- 原型是 HTML 单文件，**不代表 Xcode 编译或模拟器通过**；Windows 上未跑过 Xcode。
- 官方 `design_lint check` 在多机双主题板式下按「页面主背景」比对文字，剩余红项为板式误报，以逐元素 `audit.mjs`（13 页 0 失败）为准（详见 `05` §6）。
- 本会话模型无图像输入，16 张截图未经模型复核，建议 Muse 先人工过一遍。
- 原型未覆盖 VoiceOver、真机 Reduce Motion、动态字体极端档位。

## 8. 数据真实性声明

原型文案与结构来自 V3.9.2 真实代码（`AIChatView` 的 examples、MorningBrief 晨报文案、月报「较上月同期」口径、PR-K 密度网格等）；示例金额（¥63,420 / ¥3,480 / ¥680 / ¥1,860）为演示数据，非真实业务数据。
