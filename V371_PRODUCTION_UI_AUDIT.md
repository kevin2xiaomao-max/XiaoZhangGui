# V3.7.1 Production 页面视觉审计报告

**分支**: `feature/v3.7.1-ui-redesign`
**审计日期**: 2026-10-09
**方式**: 静态代码审计（未修改代码）

---

## 总览

| 页面 | V371 设计系统 | V32 遗留 | EmptyState | 字体/间距问题 | 评级 |
|------|--------------|----------|------------|-------------|------|
| 首页 HomeView | ✅ 完整 | 无 | ✅ 统一 | 4 处 system font | A- |
| 待办 TodoView | ✅ | V32SegmentedPicker（本地定义） | ✅ 统一 | 5 处 system font | B |
| 日历 ScheduleView | ✅ 完整 | 无 | ✅ 统一 | 2 处硬编码 padding | A- |
| 经营 PerformanceView | ✅ | V32PrimaryButton | ❌ 3 处自绘 Text | 4 处 system font | C+ |
| 客户 CustomerView | ⚠️ 部分 | V32SegmentedPicker/V32FieldGroup/V32PrimaryButton/V32.hero/V32.brand/V32Layout | ✅ 统一 | 1 处 system font | C |
| 临期 ExpiryView | ✅ | V32FieldGroup/V32PrimaryButton | ✅ 统一 | 2 处 system font | B- |
| 商品 GoodsView | ✅ | 无 | ✅ 统一 | 4 处 system font | A- |
| 备忘 MemoView | ✅ | 无（MemoCard 已废弃） | ✅ 统一 | 4 处 system font + 1 硬编码 padding | A- |
| AI 问小掌柜 AIChatView | ✅ 完整 | 无 | ✅ 统一 | 5 处原生 font | A- |
| 收款码 PaymentCodeView | ✅ | 无 | ✅ 统一 | 6 处 system font | B+ |
| 设置 ProfileView | ✅ | 无 | — | 15 处 system font | B |
| 语音 VoiceView | ✅ | 无 | — | 7 处原生 font + 2 system | B |
| 交易记录 TransactionHistoryView | ⚠️ 弱 | 无 | ❌ 用 ContentUnavailableView | 1 处 system font | B- |
| 各 EditorSheet（6 个） | 原生 Form | 无 | — | 无 | A |

**Dark Mode**: V371.Colors 基于动态 UIColor（v371Canvas/v371Group 等）+ 系统语义色（tertiaryLabel/separator），token 层已处理，无需逐页修复。

---

## P0：必须修复（影响视觉一致性）

### 1. CustomerView — V32 遗留最多
- `V32SegmentedPicker`（L37）、`V32FieldGroup`（L49）、`V32PrimaryButton`（L53）仍在 header/toolbar 使用
- `V32.hero`（L118）、`V32.brand`（L192/196）、`V32Layout.bottomPad`（L119）
- 本地 `V32SwipeAction` struct（L332）仅作原生 `.swipeActions` 的数据模型，建议改名
- 建议：替换为 V371 对应组件/Token

### 2. PerformanceView — 空状态不统一 + V32
- `V32PrimaryButton`（L313）
- 3 处自绘空状态 Text（L189「暂无昨日对比」、L258「本月暂无收入」、L310「暂无交易记录」），未用统一 `EmptyState`
- 建议：替换为 V371 组件 + 统一 EmptyState

### 3. TransactionHistoryView — 空状态不统一
- 使用 `ContentUnavailableView`（L26）而非统一 `EmptyState`
- V371 primitives 使用率为零，建议补 GroupSurface/WorkRow

### 4. ExpiryView — V32 遗留
- `V32FieldGroup`（L23）+ `V32PrimaryButton`（L26）
- 建议：替换为 V371 对应组件

### 5. TodoView — 本地 V32SegmentedPicker
- L265 本地定义了 `V32SegmentedPicker` struct（内部已用 V371 token，功能正常）
- 建议：改名为 `TodoSegmentedPicker` 或提升为共享 V371 组件，避免命名混淆

---

## P1：字体统一（V371.Typography 迁移）

以下为硬编码 `.font(.system(size:))` 或原生 `.font(.title/.body/.caption)`，建议迁移到 `V371.Typography`：

| 文件 | 数量 | 行号示例 |
|------|------|---------|
| ProfileView | 15 处 system | L145/367/560/808/849/1096… |
| AIProviderSettingsSheet | 18 处原生 + 1 system | L59/70/101/262/303… |
| VoiceView | 7 处原生 + 2 system | L69/120/145/239… |
| PaymentCodeView | 6 处 system | L169/192/214/348… |
| QuickRecordSheet | 6 处 system + 1 原生 | L143/161/183/268… |
| ActionCardView | 6 处原生 + 3 system | — |
| AIChatView | 5 处原生 | — |
| TodoView | 5 处 system | — |
| GoodsView / HomeView / MemoView | 各 4 处 system | — |
| AppearanceSettingsView | 4 处原生 + 1 system | — |

另有硬编码 padding：
- ScheduleView：L157 `.padding(20)`、L390 `.padding(12)` → 建议用 `V371.Space` token
- MemoView：L14（MemoCard 内）`.padding(14)` → 随 MemoCard 清理一并处理
- AppearanceSettingsView：1 处

---

## P2：死代码清理

| 文件 | 内容 | 状态 |
|------|------|------|
| MemoView.swift | `MemoCard` struct（L224+） | 无任何调用，已废弃（当前用 WorkRow 单列布局，卡片墙问题已解决） |
| V35SideUtilityDrawer.swift | 整个文件 | 无任何调用 |

---

## 无需改动（已达标）

- **HomeView**：V371 完整（HeroMetric/QuickActionRow/TimedRow/WorkRow/EmptyState/Motion 全套）
- **ScheduleView**：V371 完整，日历+日程共用
- **AIChatView**：V371 完整，无 V32
- **GoodsView**：V371 完整
- **6 个 EditorSheet**：均为原生 Form + V371.Colors，符合规范
- **DailyReportSheet / SaobeiImportSheet / WeatherViews**：V371 正常，无 V32

---

## 修复优先级排序

1. **P0-1**: CustomerView V32 替换（影响主流程页面）
2. **P0-2**: PerformanceView 空状态统一 + V32PrimaryButton 替换
3. **P0-3**: ExpiryView V32 替换
4. **P0-4**: TransactionHistoryView 空状态统一
5. **P0-5**: TodoView 本地 V32SegmentedPicker 改名
6. **P1**: ProfileView / AIProviderSettingsSheet / VoiceView / PaymentCodeView / QuickRecordSheet 字体迁移（按数量排序）
7. **P1**: ScheduleView / AppearanceSettingsView 硬编码 padding
8. **P2**: MemoCard / V35SideUtilityDrawer 死代码删除

**注意**：所有修复应保持小批量、可回滚，禁止为修复而大规模重写已验收页面。
