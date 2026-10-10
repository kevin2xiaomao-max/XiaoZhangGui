# V3.7.1 P1 视觉规范

## 方向

**Editorial Content + Soft Frosted Controls + Native Interaction**

- 内容像经营日报：数字和文字层级承担主要视觉表达，装饰退后。
- 控件像系统控件：磨砂仅用于少量可操作浮层，不扩散到内容区。
- 交互遵循原生平台：保留 `TabView`、导航返回、Sheet、Dynamic Type 和系统辅助功能。

## 信息层级

1. 页面主结论：问候、日期、营业额、当日关键状态。
2. 主要行动：快速记录、AI 入口，以及各页最常用动作。
3. 分组内容：一个 Section Surface 容纳多行，使用 hairline 分隔。
4. 元数据：时间、趋势、目标、数量和状态使用次级语义色。

同一信息不以多个卡片或徽章重复表达。首页只保留一个 AI 入口，AI 不进入主 Tab。

## 字体

- 中文统一使用 Apple 系统字体，不引入未经授权或未在真机验证的字体。
- 大金额使用系统圆体数字、等宽数字和轻微负字距；数字优先于装饰背景。
- 页面标题使用系统默认设计，避免所有标题都使用圆体。
- 正文、标签和辅助文字使用语义 Text Style，逐步覆盖 Dynamic Type。

## 色彩与 Surface

- S0 Canvas：暖浅灰 / 近黑。
- S1 Group：纯色分组面，用于行列表。
- S2 Editorial Hero：以排版为主；禁止蓝色大渐变 Hero。
- S3 Floating Control：仅 AI、工具按钮和系统底栏可使用轻磨砂。
- 状态色只用于图标、数字或小范围强调；Light/Dark 均使用语义色。

## 几何与留白

- 页面水平边距：16pt。
- 主要 Section 间距：20pt。
- 可点击区域：至少 44×44pt。
- 分组圆角：24pt；轻量控件圆角：18pt；避免随机圆角层级。
- 优先通过留白建立分组，不为每一块内容增加边框、阴影或背景。

## 动效与无障碍

- 状态切换优先 0.18s 淡入淡出；只对变化节点做动画。
- Reduce Motion 开启时取消弹簧、缩放和大位移。
- 所有核心操作有稳定 accessibility identifier、名称和状态。
- 不以颜色作为唯一状态表达；大字号下允许行高增长和文本换行。

## 禁区

- 不恢复 `FloatingTabDock`，不覆盖原生 TabView。
- 不使用蓝色大渐变、卡片墙、整页毛玻璃或多层悬浮控件。
- 不复制研究站点的品牌资产、CSS、字体文件或动效。
- P1 只改 Presentation 层，不改变 SwiftData Schema、Repository、AI 执行链或业务计算。

## 截图基线

- 主 UI 验收设备：Xcode 设备类型 `iPhone Air`。
- 当前可用 Simulator Runtime：iOS 26.5（23F77）。iOS 27 Beta Runtime 当前未安装，相关兼容性明确记为未验证。
- `iPhone 17e` 仅用于窄屏与辅助功能大字号验收，不作为主设计基准。
- `before/light` 与 `before/dark`：P0 稳定提交 `1cb24d9` 的实际运行截图。
- `after/batch1`：首页第一批修改后的实际运行截图。
- `after/batch1/narrow`：iPhone 17e、iOS 26.5、辅助功能超大字号的窄屏验收截图。
- `before/batch2-air`：第二批修改前的 iPhone Air Light / Dark 基线。
- `after/batch2-air`：第二批修改后的 iPhone Air Light / Dark 截图及 iPhone 17e 大字号辅助验收。
- Dark 截图通过 Simulator 系统外观切换并逐张核验，不能以测试进程环境变量代替系统 Color Scheme。
