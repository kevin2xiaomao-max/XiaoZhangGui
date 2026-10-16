# V38 · 页面动效接入规格（Page Motion Spec）

分支：`ios/v38-page-motion` · 状态：**M0 BLOCKED，生产页冻结，本规格为 M0 恢复后接线的依据，不代表已实施**
对照：《02_设计与交互升级说明.md》§本轮新增互动 场景 1–7、《04_自动验收矩阵与交付要求.md》G4/G5
适用基线：`integration/v371-grok-thinking-fixes @ d238ff0` 恢复的 iOS V3.8 生产页（8f3 树）

## 0 · 全局约束（六处通用）

1. **生产页零改动**：M0 恢复前本规格只存文档 + 隔离演示；接入只能在 M0 基线恢复、且逐项 review 后进行。
2. 动效永远**装饰性**：不得遮挡可读性、不得代替状态语义（勾选≠保存成功，见 §4）。
3. Token 复用：时序只使用 `V38MotionLabTokens.Intent`（press 0.18s / expand spring 0.35 · 0.86 / contentChange 0.28s）或后续 A 线
   `DesignSystem/V38/Motion/` 正式模块的映射；**不准新建同名 token**（02 §正确的视觉 DNA）。
4. iOS 26+ API（`glassEffect` 等）一律 `#available(iOS 26, *)`，iOS 18–25 走 `.ultraThinMaterial` / 不透明回退。
5. Reduce Motion 开启时：取消位移 / 过冲 / 循环动画，允许极短淡入或直接终态（02 §交互策略、04 G6）。
6. Reduce Transparency 开启时：内容不透明背景，命中区域（≥44pt）保持一致（04 G6）。
7. **不准全屏离屏模糊截图式转场**（02 §交互策略）；页面级只用原生 navigation transition + 局部 Spring。
8. 验收走 G4（交互：入口工作且原路返回、20 次快速连续开合无卡死/残影）与 G5（保存正确性：成功 UI 只在持久化成功后触发）。

## 1 · 首页 Home（场景 7 局部 + §交互策略）

业务锚点：顶部日期/周次/天气信息区、营业额 Revenue Hero（**禁止形态变化，已校验**）、平面信息列表。

| 动效 | 锚点 | 起态 → 终态 | 时序 |
|---|---|---|---|
| 页面首次出现 | 各 editorial group 容器 | 透明度 0 + 位移 +12pt → 透明度 1 + 位移 0（分组错峰 40ms） | contentChange，单次 |
| 内容刷新（下拉/数据回写） | 列表行容器 | 旧内容淡出 0.12s → 新内容淡入 0.16s，行高不变 | contentChange；行高/分割线几何不抖 |
| 金额微变化 | Hero 数字 Text | 旧值 → 新值 numeric transition（`contentTransition(.numericText())`），Hero 外框不动 | contentChange；只在数值真实变化时触发 |

**不准**：Hero 包玻璃卡、首页整屏 morph、双层 FloatingTabDock 回潮（02 §交互策略）。

验收（G4/G5 对照）：刷新前后营业额口径一致（G5）；快速切换 Tab 20 次 Hero 不抖动不残影（G4）；Reduce Motion 下刷新=直接终态（G6）。

## 2 · 待办 Todo（场景 4）

业务锚点：待办行复选框（≥44pt 命中区）、行排序、顶部进度指示。

| 动效 | 锚点 | 起态 → 终态 | 时序 |
|---|---|---|---|
| 勾选反馈 | 复选框圆圈 | 按下 scale 0.92 → 弹回 1.0；**先进入「保存中」态**（小转圈/灰色） | press；保存成功后才播完成 |
| 完成确认 | 行整体 | 保存成功回执后：勾选图标填充 + 行透明度 0.55 + 删除线淡入；行随后按排序规则滑入新位置 | contentChange；**排序位移只在持久化成功后发生** |
| 失败回执 | 复选框 | 抖动 6pt ×2（Reduce Motion 下为静态红点提示）→ 回到未勾选态；行内出现「重试」按钮 | press；草稿/勾选意图保留，不丢失 |

**铁律（G5）**：持久化完成之前**不宣告成功**；`isCompleted` 的 UI 完成态只在 Repository 回写成功后渲染；
失败保持可操作并保留重试入口（02 场景 4「持久化完成之前不宣告成功；失败保持可操作」）。

验收：模拟保存失败时无成功态闪现；20 次快速连点勾选无状态错乱（G4 鲁棒性）；VoiceOver 播报「正在保存/已保存/保存失败可重试」。

## 3 · 日历 Schedule（场景 3）

业务锚点：**日期格子 = 几何锚点**（`selectedDate` 绝不因布局变化而漂移）、日/周切换器、事项列表。

| 动效 | 锚点 | 起态 → 终态 | 时序 |
|---|---|---|---|
| 日期选中 | 被点日期格 | 选中环以格子中心为锚 `matchedGeometryEffect(id: date)` 滑到新格；格子 frame 不变 | expand（无过冲变体：damping 1.0） |
| 日/周密度切换 | 整个日历容器 | 周视图行高 → 日视图行高，选中日期格位置保持；事项列表用 contentChange 交叉淡入淡出 | contentChange；**选中日期锚点在切换前后像素位置一致** |
| 新建/编辑事项 | 事项行 | Sheet 采用原生 sheet transition；保存后列表行 contentChange 插入，不整列重排闪烁 | 系统 Sheet；contentChange |

**不准**：未获数据语义前假造周视图（02 场景 3）；切换时选中日期跳动/回弹到今天。

验收（G4）：`selectedDate` 在 20 次日/周连续切换后仍为用户所选日期；锚点位移 ≤1pt（模拟器截图对比）；
真实事项点击编辑/新建路由不变（G5 隐含：不碰业务链）。

## 4 · 经营 Performance（场景 7）

业务锚点：金额数字、图表（柱/线）、收入分类汇总。

| 动效 | 锚点 | 起态 → 终态 | 时序 |
|---|---|---|---|
| 数字变化 | 金额 Text | `contentTransition(.numericText())` 旧值滚动到新值；小数位/货币符号不动 | contentChange；变化幅度大时可分两段（整数先行） |
| 图表数据更新 | 图表容器 | 柱高/线点以旧值为起点插值到新值，坐标轴不动 | contentChange；Reduce Motion 下直接终态 |
| 分类切换 | 分类 chip | 选中态背景 `matchedGeometryEffect` 在 chip 间滑动；下方汇总数字 numeric transition | expand（轻）/ contentChange |

**不准**：演示数字、补假数据；重写收入分类与公式（02 场景 7「金额来自真实模型」「不得重写收入分类与公式」）。

验收（G5）：切换前后总额 = 各分类之和（口径测试）；图表终态数值与模型一致。

## 5 · 客户/配送 Customer（场景 5）

业务锚点：客户行状态 badge（待处理 → 处理中 → 完成）、数量/详情文本。

| 动效 | 锚点 | 起态 → 终态 | 时序 |
|---|---|---|---|
| 状态推进 | badge 胶囊 | 背景色 + 文案 contentChange；胶囊宽度以文本为锚自然伸缩，不跳行 | contentChange |
| 数量同步 | 数量文本 | numeric transition；详情行淡入更新 | contentChange |

**不准**：虚构房号、商品、截止时间；只动现存业务字段（02 场景 5）。

验收（G5）：状态变化只在落库成功后渲染；失败回滚到原状态 + 错误提示。

## 6 · 临期 Expiry（场景 6）

业务锚点：临期行「完成/退货」操作按钮、行状态。

| 动效 | 起态 → 终态 | 时序 |
|---|---|---|
| 完成/退货 | 按钮 press 反馈 → 保存中态 → 成功后行置灰 + 状态文案更新 | press → contentChange；**已落库后才做完成动效**（02 场景 6） |
| 失败 | 按钮回弹 + 行内错误提示 + 重试 | press；草稿保留 |

验收（G5）：失败展示错误并保留重试/草稿；成功 UI 只在持久化成功后触发。

## 7 · 降级矩阵（G6 接线表）

| 系统设置 | 页面动效行为 |
|---|---|
| Reduce Motion 开 | 全部位移/过冲/循环取消；勾选=直接终态；数字=直接终态；日/周切换=直接终态 |
| Reduce Transparency 开 | 浮层/胶囊走不透明背景；命中几何不变 |
| Dynamic Type AXXXL | 行高自适应放大；动效锚点跟随布局，不固定坐标 |
| iOS 18–25 | 无 glassEffect；ultraThinMaterial/不透明回退，时序不变 |

## 8 · 隔离演示对照（本分支交付）

| 演示组件 | 覆盖规格节 | 验证点 |
|---|---|---|
| `Experiments/V38PageMotion/ScheduleAnchorDemoView.swift` | §3 | 月/周密度切换时选中日期 matched-geometry 连续滑移，`selectedDate` 不漂移 |
| `Experiments/V38PagePreviews/V38CalendarAnchorPreview.swift` | §3 | 日/周切换时锚点日期行几何完全不动，仅内容变密/变疏；Reduce Motion 下直接终态 |
| `Experiments/V38PageMotion/TodoToggleDemoView.swift` | §2 / G5 | 勾选→保存中回执→成功后渲染完成态；失败回弹 + 重试/放弃；保存中禁用连点 |
| `Experiments/V38PagePreviews/V38TodoCheckFeedbackPreview.swift` | §2 / G5 | 勾选→回执→成功后行沉降到底部无跳动；进度数字过渡；失败保持可操作、再点即重试 |
| `Experiments/V38PageMotion/V38PageMotionState.swift`（纯逻辑状态机）+ `Tests/V38PageMotionStateTests.swift`（8 个单元测试） | §2 状态机 | idle→saving→idle/failed 转换规则；成功态只在持久化回执后出现；非 saving 态回执被忽略 |

说明：`V38PageMotion/` 为本任务先前尝试的隔离演示（已提交），`V38PagePreviews/` 为按任务简报补齐的两个 Preview 组件；
两者目的互补、无符号冲突，一并保留供 Integrator 取舍。

演示组件均为 Debug-only 隔离文件：不接 RootView、不读 Repository、不写 SwiftData、不发网络；仅通过 SwiftUI Preview 打开。

## 9 · NOT RUN（诚实清单）

- 真机（iPhone 17 Air / OPPO 无关项）帧率与触感：无设备 → NOT RUN。
- 生产页真实接入：M0 BLOCKED → NOT RUN（本规格仅为接线依据）。
- 模拟器录屏/截图：由 E 线（QA）在 workflow 扩展后统一采集，本分支 CI 只做编译 + 单元测试。
- G7 性能（55fps 目标）：无 Instruments/真机测量 → NOT RUN。
