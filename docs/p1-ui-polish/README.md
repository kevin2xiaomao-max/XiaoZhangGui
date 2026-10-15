# P1 UI 精修：四页视觉统一 V371 Design System

## 提交
- `c685da7` — P1 四页视觉统一 V371 Design System（主改动）
- `8817890` — 修 c685da7 解构声明类型注解编译错误（他人解堵 CI）
- `93cf693` — 修 Text fontFeatureSettings 参数误用（须走 TextStyle）

## 改动清单（按页面）

### 待办 (TodoScreen.kt)
- V32 卡片统计区 → 平面统计行（24sp semibold 数字 + hairline 分隔线，待办=蓝/已完成=绿/逾期=橙）
- 胶囊分段选择器（groupSecondary 底、选中段 group 实心）
- 列表 → SectionHeader + GroupSurface + V371Divider
- V32Checkbox → TodoToggleCircle（完成=绿实心 / 未完成=优先级色描边）
- 行标题 17 semibold（iOS `.body.weight(.semibold)`）

### 日历 Tab (ScheduleScreen.kt)
- 时间轴 section → SectionHeader + GroupSurface + V371Divider
- V32IconBubble → ScheduleIconBubble（36dp 圆 + 13% tint）
- 全天/摘要卡片 → GroupSurface
- V32Checkbox → ScheduleToggleCircle（未完成=蓝描边）
- 未动 ScheduleTimelineRow 图标选择逻辑（Worker A 的 P0-1 已在树上）

### 月历二级页 (CalendarScreen.kt)
- V32Card → GroupSurface
- 日期格：今日=蓝底白字 bold、选中=groupSecondary 底+蓝描边
- 状态点颜色按 iOS（绿/蓝/橙/灰）
- 当日详情 → GroupSurface + V371Divider，金额右对齐蓝色

### 经营 (PerformanceScreen.kt)
- 蓝/绿渐变 HeroCard → 平面 editorialHero（S2 蓝渐变仅天气 sheet 用）
- 新增月目标 GroupSection（进度条 + 本年累计）
- 收入来源 → WorkRow（门店=蓝/美团=橙/其他=灰）
- 交易流水 → GroupSurface +「查看全部」行链
- 交易行金额：收入=蓝 / 支出=红（iOS 口径）
- section 间距 30dp → 20dp（V371Space.section）

### 首页 (HomeScreen.kt)
- heroFlat「今日营业额」15sp Medium → V371Type.heroTitle（15 semibold）
- 其余已与 iOS 一致，未动

## 前后对比截图
- `docs/p1-ui-polish/before/` — 10 张（CI run 38477155074，Phase 4 全绿）
- `docs/p1-ui-polish/after/` — 10 张（CI run 38763466464）

| 页面 | Before | After |
|------|--------|-------|
| 首页 | home_light/dark | home_light/dark（仅标题字重） |
| 待办 | todo_light/dark（卡片统计+灰圈） | todo_light/dark（平面统计+优先级色圈） |
| 日历 Tab | schedule_light/dark | schedule_light/dark（GroupSurface+蓝圈） |
| 月历 | calendar_light/dark | calendar_light/dark（GroupSurface+状态点） |
| 经营 | performance_light/dark（绿渐变大卡） | performance_light/dark（平面+月目标） |

## CI 结果
- Run `38763466464`（commit 93cf693）：
  - ✅ Android assembleDebug / test / lint — SUCCESS（含 Paparazzi 50 张、单元测试、lint）
  - ✅ E2E 模拟器测试 — SUCCESS
  - ❌ Release 构建 — FAILURE（签名证书问题，coordinator 另行处理，非本改动）

## 未覆盖
- OPPO 真机：NOT RUN（无真机）
- 本地编译：NOT RUN（沙箱代理密码高频轮换，Gradle 无法下载依赖；以 CI 为准）
