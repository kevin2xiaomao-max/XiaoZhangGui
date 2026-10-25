# 你的小掌柜 V4.0 · Full UI Handoff

基线 **V3.9.2 (41) `a6bfced`** · 融合方向 **B70 / A20 / C10** · 交付日 2026-10-25

| 内容 | 位置 |
|---|---|
| 原型入口（13 页画廊） | `index.html` |
| 13 页原型（单文件离线） | `fusion-home/ai/business/todo/customer/calendar/voice/memo/goods/expiry/report/settings/widget.html` |
| 截图（1500×2000 @2×） | `shots/` |
| 设计系统 / token / 日历金色定案 | `01-design-system.md`（§9） |
| 页面与交互清单（V3.9.2 真实结构） | `00-page-inventory.md` |
| V3.9.3 合并映射 + 原型页→代码映射 | `03-v393-merge-map.md` |
| SwiftUI 实现规范（13 页逐页） | `04-swiftui-spec.md` |
| 验收报告（审计/点击/对比度） | `05-acceptance-report.md` |
| 资源清单 | `02-resource-list.md` |
| affectUI 动效参考 | `06-affectui-reference.md` |
| **Muse 接手说明（先读）** | `07-muse-handoff.md` |
| 源码与构建/审计脚本 | `src/`、`tools/` |

`_vendor/`（React 18.3.1 UMD + @babel/standalone 7.26.4 + `ios_frame.jsx`，约 3MB）不随包，
重建方法见 `07-muse-handoff.md` §6。

本分支只新增交付物，**不改业务代码**；`main`、`ios/v392-integration` 与 Muse 的 `ios/v392-*` 均未触碰。
