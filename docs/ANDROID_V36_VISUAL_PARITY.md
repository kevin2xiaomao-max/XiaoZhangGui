# Android V3.6 视觉对照（Phase 5 Paparazzi）

> 方法：Android Paparazzi 截图（PIXEL_6，`XzgTheme` Light/Dark）逐张对照 iOS
> `feature/v3.6-ui-ai-expansion @ 335981b` 同名 SwiftUI 视图的结构 / 文案 / 分组 / 主题色。
> Sheet 统一用仿真底部容器渲染（遮罩 + 顶部圆角 28dp + 小把手），不依赖 ModalBottomSheet 手势状态。
> 数据为手写假数据；时间用 UTC 固定毫秒。
> 截图来源：CI run `36940433302`（`paparazzi-screenshots` artifact，共 40 张；本表 9 项 × Light/Dark = 18 张）。
>
> 图例：✅ 结构/文案/分组/主题色与 iOS 一致；🟡 存在已知差异（见末尾清单）。

| # | 截图 | iOS 对照源 | Light | Dark | 说明 |
|---|---|---|---|---|---|
| 1 | TodoEditor | `Features/Todo/TodoEditorSheet.swift` | ✅ | ✅ | 标题/时间/优先级/图片四分组头、优先级文案（低优先级/中优先级/高优先级）、取消灰色均已对齐 iOS（commit `8b47f1d` 修复） |
| 2 | CustomerEditor | `Features/Customer/CustomerEditorSheet.swift` | ✅ | ✅ | 购买内容/地址与联系/配送时间/备注/图片五分组与 iOS 一致；取消为 textTertiary 灰色与 iOS 一致 |
| 3 | ExpiryEditor | `Features/Expiry/ExpiryEditorSheet.swift` | ✅ | ✅ | 商品名称/数量/到期日期/提前提醒/备注/图片六分组与 iOS 一致；3/7/15 天提醒选项一致 |
| 4 | GoodsEditor | `Features/Goods/GoodsEditorSheet.swift` | ✅ | ✅ | 10 个分组（商品名称/分类/条码/库存/价格/生产日期/保质期/到期日期/备注/商品图片）与 iOS 一致；分类 饮料/零食/日用品/烟酒/其他一致 |
| 5 | MoneyEditor | `Features/Performance/MoneyEditorSheet.swift` | ✅ | ✅ | 收入模式：明细/收入来源（门店/美团/其他）与 iOS 一致；分类仅支出模式出现，与 iOS 逻辑一致 |
| 6 | MemoEditor | `Features/Memo/MemoEditorSheet.swift` | ✅ | ✅ | 已拆分为标题/内容独立卡片 + 图片分组，3 个分组头与 iOS 一致；取消为 textTertiary（commit `8b47f1d` 修复） |
| 7 | VoicePanel | `Features/Voice/VoiceView.swift` | ✅ | ✅ | 预览态：原文/金额/时间字段行、6 类型选择器（待办/营业记录/支出/记录/临期退货/客户配送）、确认保存，与 iOS 一致 |
| 8 | QuickRecord | `Features/QuickRecord/QuickRecordSheet.swift` | ✅ | ✅ | 一句话输入/说明文案/识别结果（类型/内容/金额/时间）/确认保存，与 iOS 一致；类型 营业额/待办/配送/临时商品/备忘一致 |
| 9 | AIActionCard | `Features/Assistant/AI/UI/ActionCardView.swift` | ✅ | ✅ | PENDING（待你确认/确认记录/修改/不记录）+ EXECUTED（已保存/已记录 ¥680.00（美团）/按钮置灰）两态与 iOS 一致 |

## 已知视觉差异清单

以下为平台适配或与 iOS 共有的细节，不视为偏离，不修：

1. **日期/时间选择器形态**：iOS 用 SwiftUI 原生内联选择器（图形日历 / 滚轮时间），Android 用 Material3 `DatePickerDialog` / `TimePickerDialog` 弹窗。这是平台惯例适配，触发入口（点击日期行）与回填格式一致。
2. **语音面板金额「¥¥680.00」**：Android `VoiceFieldRow("金额", "¥${Format.money(it)}")` 中 `Format.money` 已含 ¥ 前缀。iOS `VoiceView.swift:285` 同样写成 `"¥\(Fmt.money(amount))"`（`Fmt.money` 亦含 ¥ 前缀），属 iOS 共有的显示细节，保持 1:1 未改。
3. **Sheet 仿真容器**：截图用仿真底部容器（非真实 `ModalBottomSheet`），遮罩透明度/圆角/把手为近似还原，仅用于视觉对照，不代表运行时手势行为差异。
4. **ActionCard 失败态按钮**：iOS 失败态复用 `onConfirm`（文案"重试保存"），Android 用独立 `onRetry` 回调；调用方行为等价，截图渲染无差异。
