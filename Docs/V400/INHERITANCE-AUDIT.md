# V3.9.3 A–F 继承核对（进行中）

V4 起点相对 a2d83ca 仅 7 文件的视觉与日历契约变化。当前第一批仅 UI、装饰组件与测试变化；业务核心尚未修改。不能因此将功能验收标成通过。

| 项 | 代码/入口证据 | 既有测试 | 当前结论 |
|---|---|---|---|
| A 经营分析 | AgentCore.businessInsight → groundingPack → BusinessAnswerComposer；建议路径走脱敏上下文 | V393BusinessAnalysisTests | 链路保留，待本轮测试日志逐项确认 |
| B 拍照/文件 | AIChatView 选图/文件 → 确认弹窗 → ViewModel.analyzeImage/analyzeDocument → 原 Agent | V393VisionExpenseTests / V393VisionExpenseUITests | 链路保留；发现逐次确认要求与旧开关冲突，见下 |
| C 复合意图 | CompositeIntentParser、CompositeActionCardGroupView、AgentCore.confirmComposite | V393CompositeIntentTests / V393SmartOperationsUITests | 多卡/幂等保留；用户原句静默丢配送缺陷仍未修，严格在第3步之后独立修 |
| D 模型费用 | ProviderChain 按 route.providerID 决定起手槽位，真实 fallback 模型显示、AIUsageStore、输入预算 | V393ModelCostTests | 保留真实路由与计量，非只改 UI |
| E 晨报行动 | MorningBriefBuilder/MorningBriefAction、首页卡片→Sheet→动作导航 | V393MorningBriefActionTests / SmartOperationsUI | 源码保留；通知点按详情真机 NOT RUN |
| F 全局搜索 | AI 菜单与例子→AgentCore.globalSearch→contextProvider.searchGlobal→本地结果 | V393GlobalSearchTests / SmartOperationsUI | 只读本地路径保留；不新增外发或写库 |

## 逐次外发确认要求与既有实现的差异

AIChatView 既有 imageUploadNeedsConfirmation 开关允许选择“以后直接发送”，并对图片与文件共同生效。关闭后选图/文件可直接调用 analyze；因此“始终逐次确认”不是当前源码的无条件保证。该逻辑在交接 HEAD 已存在，不是本批引入。按最新用户要求应安排独立逻辑修复和回归：每次图片/文件选择后都先展示发送确认；取消不得调用 analyze；不改变 Keychain、Provider、ToolExecutor、PendingActionStore 或 ExecutionJournal。当前正在进行视觉批验证，不在同批混改此逻辑。

## 测试状态

第一批本机日志：701 单测汇总 0 失败，仍需 xcodebuild 完成与结果产物确认。UI 和截图待执行结果。历史698/68(2 skip)为交接报告；slow_server 缺失的两项始终单列 NOT RUN。外部 Provider 实扣费、真机 OCR/通知/VoiceOver 等未执行，不作通过结论。
