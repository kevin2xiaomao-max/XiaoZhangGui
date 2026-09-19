import Foundation

/// V3.4 I0 audit corpus.
///
/// This file records the baseline behavior and the intended V3.4 behavior.
/// It is deliberately descriptive: I0 must not change product behavior merely
/// to make these scenarios pass.
struct AI20RegressionCase: Identifiable, Sendable {
    let id: String
    let utterance: String
    let currentFinalBehavior: String
    let v34TargetBehavior: String
    let currentTestCoverage: String
    let gap: String
}

enum AI20RegressionCorpus {
    static let cases: [AI20RegressionCase] = [
        .init(id: "weather-tomorrow", utterance: "明天恩平天气怎么样", currentFinalBehavior: "weatherQuery 进入固定未接入天气回复", v34TargetBehavior: "WeatherSkill 读取天气 forecast/cache 并回答明天预报", currentTestCoverage: "WeatherAPIProvider 与天气拒答有覆盖", gap: "缺 forecast 对话技能与明天语义"),
        .init(id: "goods-price", utterance: "百威多少钱一箱", currentFinalBehavior: "进入 worldChat/远程回答，Goods 不参与查询", v34TargetBehavior: "本地匹配 Goods 并回答售价/单位信息", currentTestCoverage: "无 GoodsLookupSkill 语料覆盖", gap: "缺商品查询路由与单位字段"),
        .init(id: "goods-cost", utterance: "百威进价多少", currentFinalBehavior: "不会读取 Goods.purchasePrice", v34TargetBehavior: "本地返回进价，缺失时明确说明", currentTestCoverage: "Goods 模型字段有业务 UI 覆盖", gap: "缺 AI 查询接线"),
        .init(id: "goods-stock", utterance: "百威还有多少库存", currentFinalBehavior: "不会读取 Goods.stock", v34TargetBehavior: "本地返回库存并提示低库存状态", currentTestCoverage: "无 AI 商品库存覆盖", gap: "缺 Goods READ Skill"),
        .init(id: "revenue-today", utterance: "今天营业额怎么样", currentFinalBehavior: "只支持今日总额/笔数的本地查询", v34TargetBehavior: "回答总额、较昨日及必要的来源拆分", currentTestCoverage: "BusinessAnswerComposer 今日营业额有覆盖", gap: "缺昨日对比与来源拆分"),
        .init(id: "revenue-seven-days", utterance: "最近7天生意怎么样", currentFinalBehavior: "无 7 日查询种类", v34TargetBehavior: "本地聚合近 7 日趋势并给出短结论", currentTestCoverage: "无覆盖", gap: "缺 7 日 BusinessContext"),
        .init(id: "pricing-advice", utterance: "百威应该怎么定价", currentFinalBehavior: "worldChat 不携带商品店况", v34TargetBehavior: "先读本店 Goods，再以最小 Grounding 请求建议", currentTestCoverage: "worldChat 空 context 有覆盖", gap: "缺经营相关 Grounding 路由"),
        .init(id: "basket-size", utterance: "便利店怎么提高客单价", currentFinalBehavior: "普通聊天交给 DeepSeek，通常无店况", v34TargetBehavior: "正常回答，不生成业务卡；必要时仅带脱敏摘要", currentTestCoverage: "worldChat 基础链路有覆盖", gap: "缺经营建议判定与上下文策略"),
        .init(id: "gross-margin", utterance: "什么是毛利率", currentFinalBehavior: "普通聊天交给 DeepSeek", v34TargetBehavior: "正常知识问答，不生成业务记录", currentTestCoverage: "无专门语料覆盖", gap: "缺 meta/knowledge 回归样例"),
        .init(id: "meta-ai", utterance: "那我还要AI干嘛", currentFinalBehavior: "普通聊天交给 DeepSeek，可能背诵系统提示词边界", v34TargetBehavior: "本地 Meta Reply：承认边界、说明价值、给一个可行动作", currentTestCoverage: "无专门覆盖", gap: "缺本地 Meta Reply"),
        .init(id: "meituan-revenue", utterance: "今天美团680", currentFinalBehavior: "本地解析成 recordRevenue ActionCard", v34TargetBehavior: "保留来源为美团，确认前不写库", currentTestCoverage: "本地解析、ActionCard、幂等有覆盖", gap: "缺回归语料快照"),
        .init(id: "todo-clear-time", utterance: "提醒我明天下午3点进货", currentFinalBehavior: "本地解析成 createTodo ActionCard", v34TargetBehavior: "保留下午 3 点，确认前不写库", currentTestCoverage: "Todo parser 与时间有覆盖", gap: "缺正式 corpus 记录"),
        .init(id: "todo-ambiguous-time", utterance: "提醒我明天3点进货", currentFinalBehavior: "本地/远程链路需确认是否拒绝歧义时间", v34TargetBehavior: "主动澄清上午/下午，禁止猜当前时间", currentTestCoverage: "有部分时间规则覆盖", gap: "缺该真机话术断言"),
        .init(id: "delivery-room", utterance: "今晚8点给302送水", currentFinalBehavior: "createDelivery ActionCard，确认后写 CustomerRequest", v34TargetBehavior: "保持单卡确认与真实时间，不依赖动画写库", currentTestCoverage: "配送 parser 与 executor 有覆盖", gap: "缺 corpus 快照"),
        .init(id: "delivery-address", utterance: "今晚8点送3杯珍珠奶茶到幸福路9号，一共45元", currentFinalBehavior: "远程 tool call 或本地解析后生成配送卡", v34TargetBehavior: "完整展示配送信息，确认后才落库", currentTestCoverage: "配送字段及工具调用有覆盖", gap: "缺地址/金额真机组合语料"),
        .init(id: "receivable", utterance: "阿东货款还没收到", currentFinalBehavior: "识别为未收款后明确拒绝，不写 Memo/Todo", v34TargetBehavior: "生成应收对象 ActionCard，确认后写入正式模型", currentTestCoverage: "P0-6 拒写有覆盖", gap: "缺 ReceivableSkill 与 schema"),
        .init(id: "correction-memo", utterance: "不是待办，改成备忘", currentFinalBehavior: "有 pending 时取消旧卡并重走 createMemo", v34TargetBehavior: "旧卡失效，只保留新的备忘提案", currentTestCoverage: "CorrectionParser/AgentCore 有覆盖", gap: "缺该自然语言组合快照"),
        .init(id: "correction-time", utterance: "时间改成晚上9点", currentFinalBehavior: "有 pending 时可取消旧卡并重走，但时间字段需远程重新抽取", v34TargetBehavior: "基于上一条动作更新时间，保留其他字段", currentTestCoverage: "纠正取消旧 proposal 有覆盖", gap: "缺字段级多轮更新"),
        .init(id: "cancel", utterance: "不要了", currentFinalBehavior: "取消 pending proposal，不写业务库", v34TargetBehavior: "取消当前提案并保持会话一致", currentTestCoverage: "cancel/clear 有覆盖", gap: "缺正式 corpus 记录")
    ]
}
