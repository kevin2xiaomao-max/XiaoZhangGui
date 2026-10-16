# Android V3.8 PoC 真机反馈 Backlog

> 来源：用户 2026-10-16 在 OPPO ColorOS 17 真机（PKJ110）打开 V3.8 PoC 实验区的反馈。
> 原则：PoC 视觉效果在真机验收通过前**不进入正式生产页面**；本轮只记录、不改代码。

## B-1 PoC-2 玻璃质感偏灰、偏厚（待优化）
- 现象：真机上玻璃质感偏灰、偏厚，不够通透。
- 优化方向（后续）：透明度、层次、文字对比度；遵守 V3.8 简洁设计原则（Design System §1）。
- 约束：三档几何一致性与对比度守恒（PoC-2 已有 JVM 测试）不得破坏；优化后需补 Light/Dark 真机截图对比。
- 状态：待办，未排期。

## B-2 PoC-1 液滴菜单保留验收项
- 结论：液滴菜单继续保留为验收项，不移除。
- 后续：待 `--perf` 真机实测（帧间隔分布）确认流畅度后再定生产接入方案。
- 状态：验收项保留。

## B-3 PoC-3 拖拽/展开流畅度待确认
- 现象：PoC-3 已能显示，但拖拽和展开动画是否流畅尚未确认。
- 后续：用 `tools/poc-acceptance.sh --perf` 在真机实测帧间隔分布（p50/p95、≤18.18ms 占比）后判定。
- 状态：待真机实测（NOT RUN）。

## B-4 PoC-4 版本解析（已修）
- 现象：`coloros-version` 显示 UNAVAILABLE / `coloros-version-unparseable`（`Build.DISPLAY` 无版本标记）。
- 修复：`parseColorOsMajorVersion` 扩展为依次尝试 `Build.DISPLAY` → `Build.VERSION.INCREMENTAL` → `Build.FINGERPRINT`（均为公开 API）；解析不到仍具名降级 → FADE。
- 约束：不许用反射读 SystemProperties（私有 API 红线）。
- 状态：已修复，待用户真机复验。

## 真机验收门槛（不变）
- ≥55fps 真机帧率硬门槛保持；结论只基于 `dumpsys gfxinfo framestats` 实测的帧间隔分布，不用采样帧数代替。
- 真机未测项一律标 NOT RUN，不虚报。
