# V3.5 P5-A Hero A/B/C Prototype

本轮仅建立隔离 Preview 原型，使用同一份 fake preview data；未接入正式首页、Performance 数据、SwiftData、AI 或任何写入路径。

## A — Editorial Large Number

- 中性实体 surface。
- 超大营业额数字是唯一主视觉。
- 绿色只用于极少量状态/进度强调。
- 优点：信息层级最清楚、留白最强、3 秒内最容易找到金额。
- 缺点：经营上下文最少；没有趋势线时对变化的感知较弱。

## B — Large Number + Minimal Trend

- 保留 A 的超大营业额数字。
- 增加一条低对比度、无网格迷你趋势线。
- 月目标与完成率保持次级层级。
- 优点：在不削弱金额主视觉的前提下提供变化方向。
- 缺点：小屏或 XXL 下趋势区域最容易被压缩；数据不足时需要隐藏趋势线。

## C — Neutral Card + Accent Rail

- 中性实体卡，不使用整张深绿色背景。
- 通过细绿色 rail / progress accent 提供品牌识别。
- 比 A 信息更丰富，包含笔数、变化和目标上下文。
- 优点：信息密度与品牌强调更均衡，适合作为经营概览入口。
- 缺点：视觉重量高于 A；在 XXL 或窄屏下需要更严格控制文本换行。

## 评审范围

- Light / Dark：均有 Preview。
- iPhone Air 窄宽度：有独立宽度 Preview。
- Dynamic Type Normal / XXL：有对应 Preview。
- Reduce Motion：有无动画参考 Preview；原型本身无持续动画。
- Widget / Lock Screen / Live Activity：沿用 Preflight 的 NO-GO，不在本轮改造。

本文件不替产品负责人或实际使用者选择 winner。正式首页替换前应在同一台真机、相同假数据下分别体验 A/B/C，并由产品负责人记录选择与理由。
