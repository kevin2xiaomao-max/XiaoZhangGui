# V3.9.3 A–F 继承核对

代码基线 a2d83ca；接手 2febf64；本轮原完整候选 f7d2581（快速连点失败后已修订，最终代码提交见报告）。以下区分源码、自动化和真实服务验收。

| 项 | 当前链路 | 本地自动化证据 | 实际服务/设备边界 |
|---|---|---|---|
| A 经营分析 | AgentCore.businessInsight → groundingPack → BusinessAnswerComposer，脱敏上下文与查询保留 | V393BusinessAnalysisTests，全量单测实际执行 | 外部 Provider 在线输出 NOT RUN |
| B 拍照/文件 | 选图/文件 → 本次发送确认 → analyzeImage/analyzeDocument → 原 Agent；支出草稿确认前不写库 | V393VisionExpenseTests、V392AIMultimodalGuardTests；Consent-final 13 unit + 1 UI 通过 | 相册/文件真实外发、OCR 服务实扣费、取消网络抓包 NOT RUN |
| C 复合意图 | 原多卡、confirmComposite、幂等与执行日志保留；裸房号配送与缺项澄清独立修复 | 原句先红后绿；Delivery-green 703 unit + 1 UI 通过，最终全量再回归 | 未改 ToolExecutor / Journal / Repository / schema |
| D 模型费用 | ProviderChain 实际起手槽位、fallback 模型、AIUsageStore、预算保留 | V393ModelCostTests，全量单测实际执行；设置 UI 保留 | 真实 Provider 账单对账 NOT RUN |
| E 晨报行动 | 原 Builder / Sheet / 首页动作导航保留，金额与图形视觉统一 | V393MorningBriefActionTests；SmartOperations UI | 通知实际触达、点按进详情真机 NOT RUN |
| F 全局搜索 | AI 菜单 → globalSearch → 本地 contextProvider.searchGlobal；不新增外发 | V393GlobalSearchTests；5000 条压力搜索实际执行 | 大量真实用户数据与设备耗时 NOT RUN |

## 外发确认差异已修复

交接版本允许 imageUploadNeedsConfirmation=false 跳过确认；按用户正式指令，本轮独立提交 0f87406 取消该绕过路径。保留旧偏好字段以兼容，不迁移用户数据。图片和文件每次选取均进入确认，发送调用仍经原模型，取消清除待确认内容。

## 验证边界

Visual-unit：704 单测、0 失败，包含上述 A–F 测试。最终候选的全量测试、UI 数量和产物以最终验收报告为准。历史 CI 40317286552 为 698 unit / 68 UI（2 skip），不能证明新本地提交通过远端 CI。slow_server.py 缺失，两项慢请求用例 NOT RUN，skip 不计通过。

最终汇总：产品代码2454f57；完整回归b35bbe7为705 unit +77 UI（75通过、2 NOT RUN、0失败）；最终纯墨色补丁再次705 unit +10 UI全通过。详见 FINAL-REPORT.md。
