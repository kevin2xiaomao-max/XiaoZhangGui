# Product Design Reference Pack

Phase 4.3 · 只读研究版

本文件用于指导后续 `4.2-D Flow Consistency → Interaction/Motion → Visual System → Brand`。本阶段不实施设计、不修改生产代码、不新增依赖。

## 1. Reference Index

### 公开来源

| 来源 | 用途 | 结论 |
|---|---|---|
| [Kombai Mobile Gallery](https://kombai.com/gallery/mobile/) | 移动端 dashboard、task、calendar、chat、forms、lists、empty states、navigation 的模式扫描 | 只借 interaction / hierarchy；不复制页面皮肤 |
| [Apple HIG · Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts) | 错误、不可逆操作、确认 | Alert 应少用；有多个行动选择时优先 action sheet / confirmationDialog |
| [Apple SwiftUI · Search](https://developer.apple.com/documentation/swiftui/search) | 原生搜索、scope、suggestions、dismiss | 优先 `.searchable`，不自绘搜索栏 |
| [Apple · Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass) | iOS 26+ 控制层、导航层、sheet | Glass 用于 top/control layer；业务内容保持 solid |
| [WWDC22 · Explore navigation design](https://developer.apple.com/videos/play/wwdc2022/10001/) | NavigationStack、返回、sheet 与层级 | 保持系统 back gesture 和上下文导航 |
| [Kenotex theme.rs](https://github.com/kenxcomp/kenotex-cli/blob/main/src/types/theme.rs) | 角色化 token、背景/面板/accent/border 关系 | 只学习 token 分工，不复制 TUI |
| [Kenotex themes.rs](https://github.com/kenxcomp/kenotex-cli/blob/main/src/molecules/config/themes.rs) | Tokyo Night、Nord、Gruvbox、Catppuccin 的配色秩序 | 参考层级和克制度，不复制 hex |

### 仓库已有资料

- `V35_THEME_STUDY.md`：Kenotex palette study，已确认不复制原始颜色值。
- `V35_SDK_API_AUDIT.md`：SDK / Liquid Glass / fallback 结论。
- `V35_P1_Liquid_Tab_Bar.md`、`V35_P2_Native_Navigation_Toolbar.md`：系统控制层方向。
- `V35_P5_FINAL_AUDIT.md`、`V35_P6_FINAL_AUDIT.md`、`V35_P7_FINAL_RELEASE_AUDIT.md`：内容 solid、控制层 selective native glass、无障碍与 Widget 限制。
- `V35_HERO_DECISION.md`：A/A3/B 原型结论与正式 Home 方向。
- `V32Motion.swift`、`V32MotionTests.swift`：当前 motion token 与 Reduce Motion 约束。

### REFERENCE MISSING

- 昨天讨论的 Kombai 具体设计条目 URL / 截图：当前仓库没有保存，不能声称已经研究某个具体页面。
- 昨天若存在其他 GitHub interaction 项目：仓库未找到对应记录，暂不纳入实现依据。
- App Icon / Brand symbol 的正式参考板：当前没有可验证的仓库资料，本阶段只保留研究方向。

## 2. Kombai Selects：可借与不可借

Kombai Mobile Gallery 可按 `Dashboard / Search / Table / Card / Calendar / Chat / Forms / Stepper / Tabs / Dark mode / Toolbar` 分类浏览。它适合做模式索引，不适合作为小掌柜的视觉来源。

| 类别 | 值得借什么 | 不应该借什么 | 适合小掌柜哪里 |
|---|---|---|---|
| Mobile dashboard / finance | 数字优先、摘要到详情的层级、趋势与上下文关系 | 四宫格堆卡、全屏渐变、金融产品式炫技 | Home Hero、Performance |
| Task / productivity | 待办行的完成态、优先级、快速新增 | 把所有任务都提升为大卡片 | Todo、Home 今日事项 |
| Calendar / schedule | 日期选择与当天内容的直接关联 | 复杂桌面日历缩小到手机 | Schedule、CalendarView |
| AI / chat | 输入 → processing → result 的状态节奏、结果操作靠近内容 | 聊天气泡全玻璃、把普通表单包成聊天 | AIChat、ShortVoicePanel |
| Forms / sheets | 分组字段、渐进披露、保存/取消位置稳定 | 自定义 modal 导航、重复确认 | 五类编辑 Sheet、QuickRecord |
| Lists | 行级 action、搜索/筛选和空结果区分 | Web table 密度、隐藏关键状态 | Customer、Memo、TransactionHistory |
| Empty states | 一句事实 + 一个下一步 | 插画、营销文案、巨大占位卡 | Customer、Expiry、Performance、Schedule |
| Navigation / toolbar | 控制放在系统 toolbar，返回路径稳定 | Web hamburger/sidebar 替代 iOS navigation | Drawer root、二级页 |
| Micro-interactions / motion | 短 fade、轻 haptic、局部状态变化 | 无限 pulse、大位移、全屏动画 | 保存、完成、AI processing |
| Glass / translucent surface | 控制层和导航层的层次 | 内容卡片、页面背景全部玻璃 | Toolbar、Sheet controls、Composer |

## 3. Apple Native Pattern Map

| 问题 | 原生优先方案 | 小掌柜落地原则 |
|---|---|---|
| 页面层级 | `NavigationStack`、`navigationTitle`、系统 back | 二级页面保持 edge-swipe；Root Tab 不显示返回 |
| 临时任务 | `.sheet`、`presentationDetents`、drag indicator | 编辑、新增、QuickRecord 使用 sheet；不自绘假导航 |
| 多个危险/选择行动 | `.confirmationDialog` | 删除、状态选择等使用系统 destructive/cancel role |
| 单一错误反馈 | `.alert` 或当前上下文内轻反馈 | 只提示必要信息，失败不 dismiss |
| 搜索 | `.searchable`、search scopes/suggestions | Memo、交易历史优先采用系统搜索 |
| 行级低频操作 | `.contextMenu` / swipe actions | 不把低频设置放在 Home |
| 工具操作 | `.toolbar`、Menu、ShareLink | Toolbar 只放当前上下文高频操作 |
| 触觉 | `sensoryFeedback` 或现有 Haptic wrapper | 保存成功、完成、错误使用轻量语义触觉 |
| 动效 | `.animation`、transition、系统 sheet motion | 复用 V32Motion；Reduce Motion 时 fade/instant |
| 可访问性 | Dynamic Type、VoiceOver label、44pt hit area | 内容不能依赖颜色；状态要有文本语义 |
| Glass | iOS 26+ selective control layer + solid fallback | 不为使用 API 而强上；iOS 18–25 保持稳定 fallback |

## 4. Page Reference Matrix

| 页面 | Current | Reference | Borrow | Avoid | SwiftUI approach | 等级 |
|---|---|---|---|---|---|---|
| Home | Home → Hero → 今日事项 → Today Status | Kombai finance/dashboard + Apple navigation | 数字优先、摘要到详情 | Dashboard card wall | solid content + Hero tap to Performance | L2 |
| Drawer | Root utility drawer，8 个入口 | Mobile navigation / Apple sheet-like control layer | 工具分组、可跟手关闭 | Web sidebar、第二套主导航 | Root-only gesture + solid elevated surface | L1/L2 |
| Revenue / Performance | Hero、指标、图表、交易 | Finance dashboard patterns | chart 与金额层级 | 坐标轴密集、卡片堆叠 | `Chart`、Theme chartAccent、NavigationLink | L2 |
| Todo | 分段筛选、列表、checkbox、编辑 Sheet | Productivity task lists | 行级完成、轻反馈 | 每项大卡、复杂创建流程 | `List`/现有 row、swipe、Repository | L1/L2 |
| Customer | 状态筛选、swipe、编辑 Sheet | Task/order workflow | pending → delivering → done | 把联系字段都设成首屏必填 | 现有 `V32SwipeRow` + sheet | L2 |
| Expiry | 分组、提醒、退货状态 | Inventory/alert patterns | 日期分组、语义 danger | 把临期和删除/退货混淆 | solid rows + confirmation | L2 |
| Memo | 搜索、筛选、双列卡片 | Notes/list/search | searchable、空结果区分 | Web masonry、过多装饰 | `.searchable` + LazyVGrid/List 评估 | L1/L2 |
| Schedule | 周条、当天时间轴、全天事项 | Calendar/schedule | 日期→当天内容的直接映射 | 复杂月历替代日程主任务 | 原生 NavigationLink 到 CalendarView | L1/L2 |
| AI 小掌柜 | chat、tool status、ActionCard | Apple-style conversational task result | processing 与结果就地操作 | 全聊天内容玻璃、绕过确认 | solid body + ActionCard + selective controls | L2 |
| Quick Record / Voice | 三条独立 create 输入链 | Forms + voice capture | transcript → parsed → confirm → save | 强行合并三套状态机 | 共享语义词汇，保持实现独立 | L2 |
| Sheet / Form | 多个编辑器与 QuickRecord Sheet | Apple sheet/form | 分组字段、稳定保存/取消 | 自绘 modal chrome | `.sheet` + `presentationDetents` + toolbar | L1 |
| Bottom Navigation | 五个 Root Tab | Apple TabView | 一级业务模块稳定可见 | 把工具塞进 Tab | `TabView` 只承载一级任务 | L1 |
| Widget / Live Activity | Snapshot / Activity status | Apple glanceable surfaces | 单一重点数字、状态优先 | 伪造 nil snapshot 为 ¥0 | WidgetKit solid hierarchy；App Group verified before richer sync | L1/L2 |
| Empty State | 已有 V32EmptyState | Apple contextual empty states | 事实 + 下一步 | 插画/营销/大卡 | `V32EmptyState` + existing create action | L1 |
| Feedback / Toast / Confirmation | haptic、alert、confirmationDialog、轻 toast | Apple alerts/actions | 反馈靠近触发上下文 | 大型 Toast、重复确认 | `.alert` / `.confirmationDialog` / existing Haptic | L1 |

## 5. Four-Layer Principles

### Interaction

1. 一个任务只有一个明确的写入确认点：`Parsed/Ready → Confirm → Repository → Feedback`。
2. Root、二级 Navigation、Sheet 三层职责不混用。
3. 删除使用系统 destructive confirmation；完成/状态推进不是删除。
4. 高频入口留在 Home/Tab；经营工具留在 Drawer；设置留在 Profile。
5. 行级操作优先使用 swipe/context menu，但核心操作必须仍可被 VoiceOver 找到。
6. 空状态要区分“没有数据”和“当前筛选没有结果”。

### Motion

1. 延续 `V32Motion`：quick 0.18s、standard 0.28s、slow 0.42s。
2. 保存/完成使用轻 fade 或局部状态变化，不做整页庆祝动画。
3. Drawer 拖拽必须连续跟手，关闭后不抢二级页面返回手势。
4. AI processing 只表达当前状态，不做全屏等待动画。
5. Reduce Motion 下去掉 spring、scale、明显位移，保留短 fade 或最终状态。

### Visual

1. Content = solid / paper；controls = native / selective Liquid Glass。
2. Home 视觉重点只有 Revenue Hero；其他区域降低容器感。
3. ThemeStore 是唯一品牌 accent 来源；success/warning/danger/destructive 保持语义独立。
4. 使用 typography、spacing、alignment 建立层级，不依赖边框、阴影、渐变制造高级感。
5. 每个页面允许有自己的结构，不强行套同一种卡片布局。

### Brand

1. “你的小掌柜”应体现可靠、现场效率、经营陪伴，而非泛化金融仪表盘。
2. App symbol 应从“掌柜/经营/可靠记录”研究，不直接画钱币或机器人脸。
3. AI 小掌柜视觉身份应是轻量辅助层，不压过真实经营数据。
4. Widget / Live Activity 继承金额与状态层级，但不把 App 正文全部缩成彩色品牌块。
5. 本阶段不定稿 App Icon、品牌图形或新 Logo。

## 6. Anti-Reference

- Dashboard 四宫格与高密度卡片墙。
- 为了“高级感”让整页、整卡或正文使用 Glass。
- Web 风格侧边栏替代 iOS NavigationStack / TabView。
- 大面积渐变、彩色背景、过度高饱和 accent。
- 无限循环 pulse、全屏 spring、数字飞入等炫技动效。
- 用自定义控件替代成熟系统的 Sheet、Search、Menu、confirmationDialog、Back gesture。
- 依靠颜色表达唯一状态，忽略 VoiceOver、Dynamic Type、Reduce Motion/Transparency。
- 把低频经营工具重新塞回 Home。
- 把 QuickRecord、Voice、AI 三套实现强行合并成第二套架构。
- 在 Widget/App Group 尚未有签名与真机证据时伪造共享数据成功。

## 7. SwiftUI Implementation Mapping

| 设计决定 | 当前可复用组件/能力 | 后续实施注意 |
|---|---|---|
| 主题 | `ThemeStore`、`AccentPalette`、`V32ThemeEnvironment` | 不创建第二套主题存储 |
| 动效 | `V32Motion`、`V32PressButtonStyle` | 所有新动效先过 Reduce Motion |
| Sheet | 现有 `.v32Sheet`、`presentationDetents` | 编辑成功后才 dismiss |
| 删除 | `confirmationDialog`、`.destructive` | 删除失败不伪装成功 |
| 搜索 | 现有 `V32SearchField`，后续评估 `.searchable` | 不为了替换而替换；先看键盘/导航稳定性 |
| 反馈 | `Haptic`、原生 alert、当前轻 toast | 不建立复杂全局反馈总线 |
| AI | `ActionCardView`、`ShortVoicePanel`、现有 Agent/Tool chain | 不改 confirmation gate |
| Navigation | `NavigationStack`、`.navigationTitle`、系统 toolbar | 保留 edge swipe |
| Empty State | `V32EmptyState` | 只补事实与必要 action |
| Glass | SDK audit 已验证路径与 fallback | 只用于 control/navigation layer |

## 8. Recommended Implementation Levels

- L1 System Native：NavigationStack、TabView、sheet、toolbar、confirmationDialog、alert、searchable、contextMenu、VoiceOver/Dynamic Type、Reduce Motion。
- L2 Adapt：Home/Performance 的信息层级、Customer/Expiry 状态行、AI ActionCard 结果层、Empty State 文案和入口关系。
- L3 Custom：仅保留 Drawer 跟手手势、必要的主题 preview、极少量状态 transition；不得为了视觉效果扩大 L3。

## 9. Top 10 Most Valuable Decisions

1. 保持 `Home = 看今天、Drawer = 找工具、Tab = 主业务、Profile = 设置`。
2. 所有 CREATE 统一成 `输入 → 解析 → 可读预览 → 明确确认 → 写入 → 目的地反馈`。
3. 保留 QuickRecord、Voice、AI 独立实现，只共享语义和反馈语言。
4. 所有删除统一使用系统 confirmationDialog + destructive role + 可见失败反馈。
5. 空状态统一采用“当前事实 + 下一步”，并区分数据库为空与筛选无结果。
6. 优先使用 NavigationStack、sheet、toolbar、searchable、Menu、confirmationDialog 等系统能力。
7. Content 保持 solid/paper，Liquid Glass 只进入控制层和导航层。
8. ThemeStore 作为唯一品牌 accent 来源，语义色不被主题色覆盖。
9. Motion 以 V32Motion 和 Reduce Motion 为硬约束，避免全屏和持续动画。
10. Widget/Live Activity 只有在 App Group 与真实签名链可验证后，才继续做共享数据视觉增强。

## 10. Status

本文件仅为研究与决策依据。未实施 4.2-D、Interaction/Motion、Visual System 或 Brand 变更。
