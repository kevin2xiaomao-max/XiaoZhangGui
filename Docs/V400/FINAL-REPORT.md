# 「你的小掌柜」V4.0 本地开发与验收报告

日期：2026-10-27（Asia/Shanghai）。本地开发、构建与下列自动化已完成；生产发布验收仍有明确 NOT RUN / BLOCKED 项，未 Push、Merge 或 Release。

## 代码与设计依据

- 仓库 kevin2xiaomao-max/XiaoZhangGui；开发分支 feature/v400-native-ui-integration。
- 接手 HEAD 2febf6493273775e98fc20e4c3ec6270a7afe5f9；本轮从已验证的 1910881 继续，保留已有成果。
- 最终产品代码：2454f57ae5313570e3df8ab64b734170562990ce。后续报告文档提交不改变产品代码或 IPA。
- 业务基线 ios/v393-integration @ a2d83ca；视觉依据 design/v40-full-ui-evolution @ cde375c2a424c3112b40e8592e1445869274a402 的 Fusion 定稿，以页面清单 §20 为准。
- 原始 Muse Token/Page 映射已从 reference pack 找回并继承。设计分支只读查看，没有 Merge / Cherry-pick。
- SwiftUI 原生实现；没有新 schema、数据迁移或未经批准的业务扩展。没有更改 main、稳定分支或 Tags。

## 页面与功能结果

| 页面/功能 | 本轮结果 |
|---|---|
| 首页/共享基础 | 双主题默认画布、深绿 Hero、品牌绿标题标记、衬线数值；保留用户主题、壁纸、四 Tab、晨报、原入口；未恢复被删除快捷行 |
| AI 确认卡 | 真实保存才盖“已记”；成功后收起、真实结果保留、可展开；预览/失败/取消/跳过/重复不冒充成功。多卡和原确认链路保留 |
| RunStrip | 按用户允许的安全降级，保留真实 isProcessing / processingLabel 驱动的 ThinkingIndicator 与 ai.typing；没有三阶段真实事件，因此没有伪造步骤、耗时或已读上下文。真实观察事件方案已记录，三阶段条未实施 |
| 语音 | AI 短语音与语音页使用真实阶段的静态 VoiceOrb；不做无限 pulse；录音、停止、取消、转写回填、确认保存链路保留 |
| 配送解析 | 原句“记一笔美团350，再送302两箱水”保留两张卡；缺项明确提示；数量/小数不冒充地址、302室 后缀保留；确认前零业务写入规则未改 |
| 经营 | Hero、汇总、来源、流水和金额编辑器衬线化；保留日/周/月、来源筛选、编辑/删除、目标和计算公式 |
| 日报/月报 | 纸面、发丝线与绿色分享按钮；月报仍是较上月同期、真实来源占比、全部历史待办口径。390pt ImageRenderer 双主题真实渲染；导出固定标准字号/浅色 |
| 待办 | 保留五筛选、两段式完成、失败重试；进度数值升级；忽略移出动画旧行事件，修复快速连点反转；已完成页仍可重新打开任务 |
| 客户配送 | 保留三状态、配送时间、地址复制、编辑和推进动作；统一 Badge 与可读语义色；未添加原型额外状态/电话导航业务 |
| 日历 | 定稿今日金圆/选中环/金底深字/描边/可读操作金、衬线日期；保留月周密度、锚点、ghost、时间/全天清单、详情与经营摘要，保留大字号日期列表 |
| 备忘 | “备忘记录”“更新于”明确职责；搜索/筛选/附件/编辑保留；日期文本不自动生成任务 |
| 商品/临期 | 商品金额/统计数字统一；临期仍是数量、天数组和原退货语义，不虚构风险金额或新退货状态 |
| 设置/Widget/其他 | 保留备份预览/追加恢复、提醒、主题/壁纸、Keychain、原导入/收款码/天气/快捷记录流程。Widget 数字与局部色彩统一，原深链/交互保留并参与编译；设备外观另列未验收 |
| 图片/文件外发 | 每次选择后均确认，取消清除待确认内容；移除绕过确认入口，保留旧偏好字段兼容，不改 Provider / 执行器 / Keychain |

最大字号月报使用同一真实数据的逐日读数、纵向来源/页脚与自然高度，避免日期省略号和挤列；普通字号和导出规格保持。

## 三页面职责与待确认方案

待办和日历操作同一 Todo；备忘独立保存 Memo。本轮只做职责/更新时间提示、视觉层级和交互保护，不复制任务、不自动转任务、不改日期归属。

今天/计划/已完成三组替换、备忘转任务、提醒规则和 schema 变更仍需独立评审；本轮未实施，也无需为当前版本迁移数据。

[三页面专项记录](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/XiaoZhangGui/Docs/V400/THREE-PAGE-REVIEW.md)；[设计与代码对照](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/XiaoZhangGui/Docs/V400/IMPLEMENTATION-MATRIX.md)。

## V3.9.3 A–F 继承

| 项 | 保留链路 | 最终对应单测 |
|---|---|---:|
| A 经营分析 | businessInsight → groundingPack → BusinessAnswerComposer，脱敏和只读分析保留 | 9 |
| B 拍照/文件 | 逐次确认 → 原 analyzeImage/analyzeDocument → 草稿确认；不自动落账 | 8，另有多模态确认门禁 |
| C 复合意图 | 多卡、顺序确认、失败隔离、幂等/执行日志；本轮修复裸房号与数量边界 | 11 |
| D 模型费用 | 真实起手 Provider、fallback 模型、预算与 AIUsageStore 保留 | 5 |
| E 晨报行动 | 原 Builder、详情和动作导航保留 | 4 |
| F 全局搜索 | 本地 searchGlobal 路径与结果保留，不新增外发 | 5 |

以上均包含在实际执行的 705 项单测中；真实 Provider、费用对账和通知触达不是这些单测的通过结论。

## 构建与测试结果

| 代码/范围 | 实际结果 | 证据 |
|---|---|---|
| b35bbe7 完整回归 | 705 unit 通过；77 UI 中 75 通过、2 skipped、0 失败 | [Final-v2.xcresult](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/Final-v2.xcresult) |
| 2454f57 最终墨色补丁 | 再次执行 705 unit + 10 相关 UI，全部通过；这是补丁后受影响范围回归，不冒称又跑了整套 77 UI | [Final-inks.xcresult](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/Final-inks.xcresult) |
| 待办鲁棒性 | 原 20 次快速连点连续 3 轮通过；已完成页重新打开任务用例通过 | [Rapid-repeat.xcresult](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/Rapid-repeat.xcresult) |
| 最大字号/390pt 导出 | 真实 XXXL 参数，标题高度 >40pt 验证字号前提，分享可滚动触达；390pt 两主题真实渲染 | [Accessible-report.xcresult](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/Accessible-report.xcresult) |
| 最终 Release 设备构建 | BUILD SUCCEEDED；App 与 Widget 均为 iPhoneOS / arm64 / 4.0.0(43) | [Device-inks.log](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/Device-inks.log) |

- Full-v2 的 xcresult 汇总：782 tests、0 failed、2 skipped，action succeeded；整体工具覆盖率约 65.91%，不是需求覆盖率认证。
- 两项慢请求测试因 slow_server.py 缺失而 skipped，验收状态为 NOT RUN，未算入实际通过。
- 新提交远端 CI：NOT RUN，未获 Push 授权。历史 CI 40317286552 的 698 unit / 68 UI（2 skip）只证明交接 SHA，不能替代本地新提交验收。
- 各批执行次数不相加冒充独立测试数量。

## 失败和环境异常记录

配送修复及数量边界均先执行失败用例再修复。第一轮完整候选发现待办连点失败，已保留产物并修复后重跑完整套。旧视觉源码契约迁移到定稿 Token/动态字号/静态 RM 写法，保留原标识符、锚点、失败重试和业务断言，没有删测试或弱化失败条件。

另有两次测试宿主未进入用例的环境异常，记 NOT RUN；新专用模拟器恢复后才记录真实断言结果。发现并纠正两处无效字号参数，参数无效的截图没有作为最大字号验收证据。详情见：

[最终问题收口记录](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/XiaoZhangGui/Docs/V400/BATCH-10-CLOSEOUT-FIXES.md)；[墨色补丁记录](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/XiaoZhangGui/Docs/V400/BATCH-11-INKS.md)。

## 性能与无障碍

环境：Apple M4 / 16GB、macOS 27.0.1、Xcode 27、iOS 27 Simulator；App 最低部署 iOS 18。下列是本机模拟器 Debug 自动化数据。

| 测量 | 结果 | 边界 |
|---|---:|---|
| 5000 条 Performance + 五类各500条：搜索 | 0.114 s | 内存数据库，返回接口上限50条 |
| 同数据经营聚合 | 0.036 s | 不含真实设备磁盘性能 |
| 同数据 grounding | 0.144 s | 不含外部 Provider 延迟 |
| App 重复启动（3样本） | 平均 2.769 s | 无已批准发布性能基线，不作真机启动结论 |
| 经营两次滑动场景 | 墙钟平均 2.754 s；CPU平均 0.474 s | 含 UI 自动化操作/等待，非每帧耗时，UI使用小型种子数据 |
| 同滚动场景物理内存 | 平均约64.2MB，峰值平均约64.3MB | 不等于长时无泄漏证明 |

31 个列明色对通过静态对比度计算；已核对双主题截图与真实最高字号月报。既有“AX3”命名部分用例实际注入 AccessibilityXXXL，按实际最高字号记录。MotionLab 的 RM/RT 是隔离覆盖，不冒充真实设备全业务验收。

[性能原始数据](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/performance.json)；[颜色对比度与范围](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/颜色对比度.md)。

## 截图

实际模拟器截图使用自动化种子数据，不是原型或真实经营数据。App 内覆盖首页/待办/日历/经营/AI/语音/配送/备忘/商品/临期/日报/月报/设置的双主题；Widget 外观仍是 NOT RUN，不能用 App 截图种类数冒充全部原型验收。

- Light：[1](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/light-1.png) / [2](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/light-2.png) / [3](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/light-3.png) / [4](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/light-4.png)；[原图与用例来源](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/light-sources.json)。
- Dark：[1](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/dark-1.png) / [2](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/dark-2.png) / [3](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/dark-3.png) / [4](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/dark-4.png)；[原图与用例来源](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/截图总览/dark-sources.json)。

[原始截图 manifest](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/final-inks-screens/manifest.json)；[完整套截图 manifest](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/final-screens/manifest.json)。

## 最终 IPA

[XiaoZhangGui-4.0.0-b43-2454f57-unsigned.ipa](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/XiaoZhangGui-4.0.0-b43-2454f57-unsigned.ipa)（5805822 bytes）。

- 产品代码 2454f57ae5313570e3df8ab64b734170562990ce；App/Widget 均 4.0.0(43)。
- 已校验 ZIP 完整性、两 bundle 版本、iPhoneOS 平台、arm64 与未签名状态。此包 unsigned，未签名安装到真机。
- 本地没有 XZG_WEATHER_API_KEY，天气在线配置未注入；不能据此宣称天气服务生产验收通过。

SHA-256：

`66f013b0adc83d430831f5f4f4d1b72e07f1c09857a974e1f87538faf2903324`

[校验文件](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/XiaoZhangGui-4.0.0-b43-2454f57-unsigned.ipa.sha256)；[包内核验明细](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/本地构建日志/V400-batch2/IPA-delivery-verification.json)。早期 f7d2581 / b35bbe7 包为历史候选，不是本次最终交付包。

## NOT RUN / BLOCKED 与后续所需

- BLOCKED：localhost:3200 保存的拒绝规则。未换地址、未绕过，也未重试浏览器验收；权限恢复后再补实时预览与操作验收。
- NOT RUN：slow_server.py 缺失的慢请求成功/失败两项；新提交远端 CI。
- NOT RUN：真机签名/安装、麦克风/识别/OCR、照片/文件真实外发及取消网络核验、外部 Provider 真实扣费、天气在线配置、真实通知触达/点按。
- NOT RUN：Widget 主屏/锁屏/StandBy/跨午夜设备显示；真实 VoiceOver 焦点顺序、系统 RM/RT、GPU/FPS、设备温度/能耗、长时泄漏。
- 如需三页面任务语义/结构调整，需独立确认；当前没有待批准的数据迁移。远端 CI 需另行授权 Push，正式分发需签名/发布授权。本轮没有执行。

## 本地提交与备份

| 提交 | 内容 |
|---|---|
| b4f5eca | docs(v400): reconcile original handoff maps and validation gaps |
| 1910881 | feat(v400): add verified recorded stamp and static voice orb |
| 8f00303 | feat(v400): finish truthful AI processing and expandable receipts |
| 39c747f | fix(v400): retain bare-room delivery intents and require clarification |
| 2e9dbf3 | feat(v400): apply Fusion business report and shared surfaces |
| ccb08cc | feat(v400): refine todo progress and preserve completion flow |
| be8a0c7 | feat(v400): improve delivery status and action contrast |
| 6c8fc27 | feat(v400): finish calendar gold and reduced motion presentation |
| f2c328c | feat(v400): unify extension pages and add export and screenshot evidence |
| 0f87406 | fix(v400): require consent for every image and document upload |
| f7d2581 | chore(v400): prepare app and widget 4.0.0 build 43 for acceptance |
| 99f31fd | fix(v400): distinguish numeric goods quantities from delivery addresses |
| af29eba | fix(v400): ignore stale todo taps during row removal |
| b35bbe7 | fix(v400): close contrast and accessible report layout gaps |
| 2454f57 | fix(v400): use defined Fusion inks for secondary text |

其后仅有报告文档收口提交，完整清单以 [V400-local-commits.tsv](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/V400-local-commits.tsv) 为准。[本地分支 Git bundle 备份](/Users/chuzu/Documents/Codex/2026-10-26/mac-museai-mac/outputs/XiaoZhangGui-V400-local-final.bundle) 包含当前分支全部本地提交，便于离开租用 Mac 前自行保存；没有向远端写入。

工作区保留生成的未跟踪 XiaoZhangGui.xcodeproj/；未把它当成无改动干净仓库。产品代码无未提交改动。
