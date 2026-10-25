# 你的小掌柜 V4.0 · 融合设计系统（V1）

> 方向：B 工位 Workbench 70% + A 账页 Ledger 20% + C 掌柜台 Host 10%
> 基线：已验证 V3.9.2 = 远端 ios/v392-integration @ a6bfced（工作树 xiaozhanggui-v40，MARKETING_VERSION 3.9.2 / 41）
> 状态：**基础 token 已验证；页面级决策待 6 页验收后定案**；动效增强见 §8（源自 affectUI 参考，详见 06-affectui-reference.md）

## 0. 融合原则（不做机械拼接）

- B 提供骨架：原生 NavigationStack + 系统 TabView（首页/待办/日历/经营）、大标题导航、inset 分组列表、系统控件、material 输入条、运行三步可视化。
- A 提供质感：**只**落在金额/数字/报表/确认卡上 —— 衬线数字（Georgia / Songti SC）、发丝线、收据式确认卡、印章式完成标记、暖纸面 `#FCFBF7` 局部表面。
- C 提供呼吸：**只**在 AI / 语音页 —— 大留白、单一品牌绿语音球、selective glass 确认 sheet。
- 权重是倾向不是配方：例如 AI 页 = B 的导航与输入条 + C 的留白与语音球，确认卡用 A 的收据式，其余页面不出现账本装饰。

## 1. 色彩 token（已按 WCAG 2.x 实测）

### Light
| Token | 值 | 用途 | 对比度 |
|---|---|---|---|
| bg / page | `#F3F8F5` | 页面底 | — |
| surface | `#FFFFFF` | 卡片 | — |
| fill | `#EAF3EE` | 内嵌填充 | — |
| paper | `#FCFBF7` | A 质感表面（报表/确认卡） | — |
| ink / textPrimary | `#1A1D21` | 主文本 | 16.9:1 AAA |
| ink2 / textSecondary | `#3A3F47` | 次文本 | 10.6:1 AAA |
| ink3 / textTertiary | `#5F646E` | 三级文本（**由 #6E7380 加深**，原值 4.42:1 不达标） | ≥4.8:1 AA |
| ink4 / quaternary | `#B0B4BC` | 仅占位符/禁用图标（2.08:1，不可作文本） | — |
| green / brand | `#1FA971` | 图表、选中态、图形（3.01:1，**禁作正文文本/浅底按钮**） | — |
| greenDeep | `#168B68` | 图标、描边 | 4.26:1 仅大文本 |
| greenInk | `#146B52` | 绿色文本、实心按钮底（白字 6.45:1 AA） | ✓ |
| greenTint | `rgba(31,169,113,0.10)` | 大面积绿**唯一合法形态**（高饱和绿大面积禁用） | — |
| warning / danger / info | `#FF9F0A` / `#E5484D` / `#0A84FF` | 语义状态，仅小面积 | — |

### Dark
| Token | 值 | 用途 | 对比度 |
|---|---|---|---|
| bg | `#0B0F0D` | 页面底 | — |
| surface | `#1C1C1E` | 卡片 | — |
| elevated | `#2C2C2E` | sheet/弹层 | — |
| textPrimary | `#F5F5F7` | 主文本 | 17.7:1 AAA |
| textSecondary | `#C7C7CC` | 次文本 | 10.1:1 AAA |
| textTertiary | `#8E8E93` | 三级 | 5.2:1 AA |
| greenLight | `#2FBF71` | 强调文本/图标 | 8.1:1 AAA |
| green | `#1FA971` | 图表、选中态 | 6.4:1 AA |
| greenDeep | `#168B68` | 描边 | 4.5:1 AA |

### 规则（对应需求 6）
1. `#1FA971` **不允许**大面积填充、不允许作正文文本色、不允许作浅色按钮底。
2. 绿色文本：Light 用 `greenInk #146B52`，Dark 用 `greenLight #2FBF71`。
3. 实心主按钮：Light `#146B52` 白字；Dark `#146B52` 白字（同 6.45:1）。次要按钮用 tint 背景 + greenInk 文字。
4. 大面积绿只允许 `greenTint` 底 + 绿描边。

## 2. 字体

- UI 文本：`-apple-system, "SF Pro Text", "PingFang SC"`（Dynamic Type 语义尺寸）。
- 账本数字（A 基因）：`Georgia, "Songti SC", serif`，只用于金额、日报数值、确认卡金额；tabular-nums。
- 字号阶梯：largeTitle 34/41 · title1 28/34 · title2 22/28 · title3 20/25 · headline 17/22 SB · body 17/22 · callout 16/21 · subheadline 15/20 · footnote 13/18 · caption1 12/16。
- 行高 ≥ 1.3；正文最小 15px（动态字体随系统缩放，原型以 17 为基准）。

## 3. 间距 / 圆角 / 分隔

- Space：xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32；页边距 page 16（B 保持）。
- Radius：sm 8 · md 10 · lg 12 · xl 16。
- 分隔：发丝线 `rgba(60,60,67,0.12)`（Light）/ `rgba(255,255,255,0.08)`（Dark）；账本语境可加页边竖线（A）。
- 层级：typography + spacing + alignment，**不加阴影渐变**（V3.5 定案）。

## 4. 动效（沿用 V32Motion）

- quick 0.18s · standard 0.28s · slow 0.42s；保存/完成轻 fade；AI processing 只表达状态，不做庆祝；无无限 pulse。

## 5. 密度与差异化信息（高密度型 App 规则）

AI/经营/待办/日历每屏 ≥3 处可见产品差异化信息（真实数据、对话/推理片段、状态推断、上下文关联）；原型全部用真实业务数据（¥3,480、美团 680、待办、库存预警可乐等）。

## 6. 组件清单（B 基 + A/C 点缀）

NavigationStack 大标题 · 系统 TabView 四 Tab · inset 分组列表 · List 行（icon/title/value/chevron）· 收据式确认卡（A）· 印章完成标记（A）· 语音球 + 同心环（C）· selective glass sheet（C）· material 输入条 · 运行三步条 · 状态徽章 · chip · 分段控件（日/周/月）· 空态（标题+说明+例子）· 骨架占位。

## 7. 已否决项（需求 8，不复活）

首页**不**恢复「今日最重要」「最近记录」、不重复快捷入口；保持 Revenue Hero 为唯一视觉重点（PRODUCT_DESIGN_REFERENCE_PACK）。

## 8. 动效增强（affectUI 参考定案，细则见 06 文档 §2）

- **曲线**：全部归一到 V32Motion（quick 0.18 / standard 0.28 / slow 0.42）+ `.easeOut`；不引入 420–520ms 长动效。
- **相位标签**（AI 运行三步）：当前步标签滚动换相（旧上卷淡出 / 新滚入），每步完成 draw-in 对勾。
- **三步行**：✓ 步骤名 + 时长；失败步行内重试（Tool Call Card 语义）。
- **确认折叠**（ActionCard）：确认后 0.4s「已记录」确认态 → 折叠为状态行 + 「今日 N 笔」计数联动；不记录 = undo；不采用倒计时。
- **数字滚动**：金额**仅数据刷新时**滚 0.9s easeOutQuart；不做视口入场滚、不做常驻呼吸。
- **共享 shimmer**：单一渐变横扫共享全部骨架块（2s）；Reduce Motion 切静态骨架。
- **指示 glide**：分段器/chips 选中指示「领先边缘先动 + 拉伸回弹」（matchedGeometryEffect）。
- **Reduce Motion**：`accessibilityReduceMotion = true` 时全部切静态；Dynamic Type 全语义字号；数字先稳定显示再滚动。
- 不采用（无意义动画）：Grid Background / Text Reveal / Logo Marquee / Testimonial / Illustrations / Reaction Bar / 倒计时审批。

## 9. 定案记录 · 日历 PR-K 金色（2026-10-25 用户确认）

**定案**：日历**保留** V3.9.2 PR-K 香槟金，不改品牌绿系。今日格实心圆 `#D4A017` + 深墨字；选中格金环 `#B8860B`；密度 chips 金底深墨字。

**理由**：金色在日历里只承担「时间位置 / 选择」一种语义，与品牌绿的「状态 / 成功 / 主操作」语义分开，避免绿色多处重复导致层级塌陷；低饱和 Editorial 方向里金色是唯一允许的暖点缀。此项覆盖 03/04/05 早期「建议改品牌绿」的待裁意见。

**对比度实测（WCAG 2.x，本机复测）**：

| 组合 | 比值 | 判定 |
|---|---|---|
| 深墨 `#1A1D21` 压金圆 `#D4A017` | **7.12** | AAA，日期文字安全 |
| 金环 `#B8860B` / 浅页底 `#F3F8F5` | **3.03** | 达非文字 3:1 |
| 金环 `#B8860B` / 白卡 `#FFFFFF` | **3.25** | 达非文字 3:1 |
| 今日金圆 `#D4A017` / 浅页底 `#F3F8F5` | 2.21 | **低于 3:1** → 浅底金圆必须带 1pt 金环 |
| 深色：金 `#D4A017` / `#0B0F0D` | **8.12** | 充足，沿用同值 |
| 深色：金环 `#B8860B` / `#0B0F0D` | **5.93** | 充足，沿用同值 |
| 深金 `#8A6400` / 白 · 页底 | 5.38 · 5.01 | 浅白底发丝环备选 |

**使用边界（硬规则）**：

1. 金只出现在日历——今日格、选中格、密度 chips；**不得**用于金额、状态徽章、主按钮，以及 AI / 经营 / 待办 / 客户页。
2. 金上唯一合法文字色是深墨 `#1A1D21`；**禁止白字压金**（白字压 #D4A017 仅 2.31，压 #B8860B 仅 3.25，均不达标）。
3. 浅底（页底 #F3F8F5 / 白卡 #FFFFFF）上金圆必须带 1pt `#B8860B` 环（白卡可用更深的 `#8A6400`），不允许只靠 #D4A017 填充表达「今天」。
4. 深色模式沿用同值；金环不做 1pt 时改用 `#2FBF71` 之外的中性描边会破坏语义，不采用。
5. Reduce Motion 下选中环不做 matchedGeometryEffect 滑移，改为静态环（见 §8）。
