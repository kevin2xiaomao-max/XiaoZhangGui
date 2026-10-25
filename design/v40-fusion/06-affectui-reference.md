# 06 · affectUI 辅助参考清单（V4.0 UI 参考 → SwiftUI 映射）

> 定位：affectUI 是**辅助参考**，Huashu Design 仍是主工作流；融合方向 B Workbench + A Ledger + C Host 不变。
> 许可红线：免费 40 项 = MIT（源码在 GitHub 仓库，允许研究参数）；Pro 82 项 = 不在仓库、无授权源码——**只用公开描述提取交互思想，不复制实现、不购买**。最终落地为原生 SwiftUI，不引入 React/TSX、不用 WebView。

## 1. DSH 远程 MCP 接入检查结论

**DSH 桌面版支持远程 MCP**（已在 app.asar 内核实）：
- 插件 `@deepseek-ai/dsh-mcp-client`（profile 的 cordis.yml 已挂载机制）；transport 支持 `stdio` 与 `streamable-http`（HTTP 条目 = url + headers；**不支持 SSE**）。工具命名 `mcp__<serverName>__<tool>`，随 harness 启动挂载，失败不中止启动（可选 `failOnStartupError: true`）。
- **affectUI MCP 端点在线已实测**：`https://www.affectui.com/api/mcp` 返回 JSON-RPC 错误对象 `"Method not allowed – the affectUI MCP server takes POST requests"`（405），证明服务存活，POST 可用。
- **本任务不热接入**：配置生效需要修改全局 cordis.yml 并重启 harness（当前会话无法热挂载，且 m00001 要求「不随意修改全局配置」）。按 m00629 第 2 条，走「官方公开文档 + 免费组件参考」路径。留给用户的可粘贴配置（自担风险、重启后生效）：
  ```yaml
  - id: mcp-affectui
    name: '@deepseek-ai/dsh-mcp-client'
    config:
      serverName: affectui
      transport: streamable-http
      url: https://www.affectui.com/api/mcp
  ```
- 收益评估：affectUI MCP 主要用途是让 AI 检索/装配 React 组件源码，与本任务「原生 SwiftUI、不复制 React 源码」的终点冲突，接入收益有限（仅文档检索）；免费组件的公开源码本任务已直接取用（见下），无需 MCP。

## 2. 重点组件研究结论（m00629 第 3 条，8 项）

研究来源：llms.txt / llms-full.txt / 官网描述（Pro 项）+ GitHub 仓库 MIT 源码（Free 项，已下载到 `_vendor/affectui-ref/`：thinking-loader / number-ticker / shimmer-loader / change-summary / decision-inbox / tool-call-card / segmented-control / smart-recommendation，共 8 个文件 99KB）。
affectUI 全局统一缓动 `cubic-bezier(0.22,1,0.36,1)`（≈iOS easeOutQuint），全库遵守 `prefers-reduced-motion`（动画强制 1ms）。SwiftUI 落点统一映射：V32Motion quick 0.18 / standard 0.28 / slow 0.42 + `.easeOut`。

| 组件 | 等级 | 关键交互逻辑 / 动效参数（实测源码） | 小掌柜适配决策 |
|---|---|---|---|
| **Thinking Loader** | **Free** | 8 射线 spinner 800ms linear 循环；相位标签滚动（旧标签上卷+模糊出、新标签滚入：opacity 240ms + transform 420ms 统一曲线）；完成时对勾 360ms draw-in（延迟 120ms）；标签 shimmer sweep 1.8s | **部分采用**：AI 页「运行三步」保留三步语义，每步图标改 draw-in 对勾、当前步标签滚动换相（相位文案：读取今日营业额→匹配美团历史→生成确认卡）；时长收窄到 0.18–0.28s，不用 420/460ms |
| **Agent Plan** | **Pro** | 步骤计划列表可重命名/拖拽排序/删增，每步 live timer，失败步原地重试 | **仅借思想**：晨报「掌柜建议」7 句优先级列表借鉴「有序可执行 + 完成折叠」；**不实现拖拽**（单手成本高）；Pro 标注 |
| **Model Picker** | **Pro** | 模型菜单 + 速度/质量/成本条 + extended thinking 开关 + tray 滚动首字时间/价格 | **研究后不采用**：小掌柜本地优先、无模型选择场景；仅「切换后 tray 一行状态」的模式已被现有 StatusBadge（Key 已保存/本地模式）覆盖 |
| **KPI Chart** | **Pro** | metric 卡 + 多线图 + 跟随指针 tooltip | **仅借思想**：经营页趋势图用 Swift Charts + `.chartOverlay` 做**长按/拖拽十字线**（iOS 无 hover）；视觉沿用自有 token；Pro 标注 |
| **Change Summary** | **Free** | 一行一指标 + 彩色趋势徽标：good 底 #EDFAF3 字 #1F8A4C、bad 底 #FFF0F0 字 #E5484D、neutral 底 #F5F5F5 字 #8F8F8F；行入场 520ms ease both；行 hover 底 140ms | **完全采用**：晨报「今日概览」、经营「较上月同期」徽标、首页 Hero 昨日对比。颜色映射 = 我方 token：good→greenInk #146B52 + greenTint 底，bad→danger #E5484D + 红淡底（项目原色），neutral→ink3 |
| **Number Ticker** | **Free** | 默认 900ms、ease=1−(1−t)⁴（easeOutQuart）；数字列 0–9+尾 0（11 格，9→0 无缝滚动）；新列入场 450ms 统一曲线 | **部分采用**：首页/经营 Hero 金额**仅在数据刷新时**滚动 0.9s（不做进入视口即滚、不做常驻呼吸）；Reduce Motion 下静态 |
| **Shimmer Loader** | **Free** | **单一渐变横扫共享所有骨架块**（整屏一次扫过，非各自扫），2s linear 循环；ShimmerText 用于「Thinking…」 | **采用共享 sweep 概念**：月报/晨报生成中、AI running 骨架；SwiftUI = 单一 LinearGradient mask + offset 动画；Reduce Motion 切静态骨架 |
| **确认交互** | Free×2 + Pro×1 | **Decision Inbox(Free)**：确认→短暂确认态→行折叠离开→下一条自动展开、计数递减；折叠=一行 muted；**Smart Recommendation(Free)**：置信信号 + 备选切换 + accept with undo（340ms 折叠、280ms chevron）；**Approval Card(Pro)**：风险徽标+倒计时暂停 | **最大收获，采用**：ActionCard 确认后加 0.4s「已记录」确认态 → 折叠为状态行 + 「今日 N 笔」计数联动；「修改」=备选切换、「不记录」=undo。**不采用倒计时**（本地无异步审批）；Approval Card 标 Pro |
| **Tool Call Card** | **Free** | 一行 = 图标+mono 名+摘要+状态（spinner+live timer / check+duration / Failed），展开看参数/结果，失败行内 retry；Group 汇总「Used 3 tools · 2.4s」 | **部分采用**：RunStrip 升级为三步行（✓ 读取今日营业额 0.8s / ✓ 匹配美团历史 1.2s / ✓ 生成确认卡 0.4s）+ 失败步 retry 语义 |
| **Segmented Control** | **Free** | indicator 领先边缘先动→拉伸→回弹（glide 窗口 440ms）；标签 semibold crossfade 不跳宽；按住可横扫选择 | **采用动效参数**：待办分段器/经营日周月/日历密度 chips 的选中指示 glide+stretch（SwiftUI matchedGeometryEffect）；**横扫拖拽不实现**（iOS 用原生分段器） |

## 3. 其他免费项快速裁决（不采用的写明理由）

- Button 加载 shimmer → 部分：主按钮 loading 用 spinner+文字，shimmer 仅用于不可点击的加载卡。
- Reaction Bar / Comment Thread / Email Draft / OTP / Profile Menu / Progress Tracker / Tips Panel → 不适用（社交/onboarding/账户场景）或低价值（Tips Panel 可作为首启提示备选）。
- Filter Menu → 简化采用：客户页筛选 chips（已列入客户页原型）。
- Notification Stack → 参考：逾期/临期通知卡用 iOS 通知样式，不做堆叠动效。
- Grid Background / Text Reveal / Logo Marquee / Testimonial Wall / 全部 Illustrations → **不采用**（营销/装饰，与经营工具无关，违背「不增加无意义动画」）。

## 4. V4.0 UI 参考清单 → SwiftUI 页面映射（m00629 第 9 条）

| 页面 | 采用项 | 落点（原生 SwiftUI） |
|---|---|---|
| AI 对话 | Thinking Loader 相位标签、Tool Call Card 三步行+时长+retry、确认交互 fold-away、Shimmer 骨架、Message Actions 安静工具条（仅复制/重试，不加点赞） | RunStrip 重设计；ActionCard 确认态+计数联动；`ProgressView` 替换为相位标签组件 |
| 工作台首页 | Change Summary（晨报今日概览、Hero 昨日对比）、Number Ticker（刷新滚动）、Segmented glide（chips 选中） | 晨报 sheet 概览行；Hero 金额组件加滚动；`.matchedGeometryEffect` 选中指示 |
| 经营 | KPI Chart 长按十字线、Change Summary「较上月同期」徽标、Number Ticker、Shimmer（月报生成中） | Swift Charts `.chartOverlay` + 长按；月报 sheet 骨架 |
| 待办 | Segmented glide、确认交互（勾选成功 0.7s 移出=fold-away 的变体）、Decision Inbox 计数递减 | 进度头数字随勾选滚动递减；分段器指示 glide |
| 客户配送 | Filter chips、Change Summary（客户月度对比）、确认交互（送达确认→折叠+今日配送计数） | 配送状态推进 + 确认态 |
| 日历 | Segmented glide（月/周密度）、Number Ticker（当日经营刷新） | 密度 chips 选中指示 |
| 语音（后续扩展页） | Thinking Loader 转写中相位、Tool Call Card 识别步骤 | 语音球 + 相位标签 |
| 设置（后续扩展页） | 无（保持原生 iOS 设置列表） | — |

## 5. 落地硬规则（m00629 第 6、7 条）
- 全部动效归一到 V32Motion（quick 0.18 / standard 0.28 / slow 0.42）+ `.easeOut`；不引入 affectUI 的 420–520ms 长动效（经营场景求快）。
- Reduce Motion：`@Environment(\.accessibilityReduceMotion)` 为 true 时全部切静态（affectUI 的 1ms 策略在 SwiftUI 中 = 禁用动画直接终态）。
- Dynamic Type：全部语义字号（.body/.headline…），数字组件用 `@ScaledMetric`；单手操作：关键操作留在屏幕下半区（sheet/输入条）。
- 经营信息可读性优先：数字先稳定显示，滚动只发生在数据变化时；不透明度动画不用于金额本体。
- 色值全走 01-design-system.md token；affectUI good 徽标 #1F8A4C 不直接抄，映射为 greenInk #146B52（对比度已达标）。
