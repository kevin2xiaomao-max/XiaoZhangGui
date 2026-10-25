# 05 · 验收报告（V4.0 Fusion 原型）

> 状态：骨架 + 方法学已定，逐页数据在六页验收后填入。本报告是「原型设计验证」验收，不是正式 UI 最终验收（用户 m00323 明确）。

## 1. 验收方法
- 构建：`build.mjs`（Babel 预编译单文件 HTML，file:// 离线可开，双击即看）。
- 自动化交互：`drive.mjs`（Edge headless + CDP，真实鼠标事件派发，pageerror/console.error/Log.error 全收集，problems 必须为空）。
- 可访问性/布局：`audit.mjs` 四类断言：①溢出（未声明裁剪却被撑开的元素）②点按目标 ≥38px（HTML 阈值，SwiftUI 落点为 44pt）③字号 ≥11px ④对比度 ≥4.5（≥24px 用 3，WCAG 2.x）。totalFails 必须 = 0。
- 视觉：2×DPI 全页截图存 `shots/`，供用户复核（本会话模型无图像输入，截图由用户查看）。
- 基线对照：与 V3.9.2 真实页面逐项比较（结构树 / 文案 / 交互状态），差异必须有设计理由，写进第 4 节。

## 2. 工具与阈值
| 项 | 阈值 | 来源 |
|---|---|---|
| 对比度正文 | ≥ 4.5:1 | WCAG 2.1 AA |
| 大字号（≥24px） | ≥ 3:1 | WCAG 2.1 AA |
| 点按目标 | HTML ≥38px / SwiftUI ≥44pt | audit 阈值 / iOS HIG |
| 最小字号 | ≥11px | iOS caption2 下限 |
| pageerror | 0 | drive.mjs problems=[] |
| 差异化信息密度 | 每屏 ≥3 处（¥/时间/日期/笔/件/天） | huashu-design 高密度规则 |

## 3. 逐页结果（六页完成后填）
| 页 | HTML | 屏数 | audit | 点击 | problems | 截图 | denseText | 与 V3.9.2 差异要点 |
|---|---|---|---|---|---|---|---|---|
| 工作台 | fusion-home.html | 5 | 0 | 2 OK（晨报/关闭） | [] | home.png | 7/7/15/7/7 | 晨报卡保留（V3.9.2 新功能）；Hero 衬线金额（A）；无被否决块 |
| AI 对话 | fusion-ai.html | 5 | 0 | 2 OK（例子/确认记录） | [] | ai-light.png | 4/4/7/5/3 | 确认卡收据化（A）；输入条 material（B）；语音球（C） |
| 经营 | fusion-business.html | 5 | 0 | 2 OK（周/月度报表） | [] | business.png | 20/20/24/20/20 | 日/周/月 chips（V3.9.2 V38ChipSelector 原生化）；月报 sheet 固定「较上月同期」；近期记录衬线金额（A） |
| 待办 | fusion-todo.html | 5 | 0 | 2 OK（供应商结账/已完成） | [] | todo.png | 7/7/7/4/7 | 两段式勾选（V38TodoToggleFlow：转圈→绿勾→0.7s 移出）；Editorial 进度头；失败重试行 |
| 客户配送 | fusion-customer.html | 5 | 0 | 2 OK（302 便利店/开始配送） | [] | customer.png | 8/8/5/5/4 | 配送状态推进可视化（配送中蓝点+预计、签收绿勾）；列表行加今日时间 |
| 日历 | fusion-calendar.html | 5 | 0 | 2 OK（周/26） | [] | calendar.png | 11/11/11/9/9 | 保留 V38 密度网格；今日金圆/选中金环**已定案保留 PR-K 金色**（2026-10-25 用户确认，token 见 01 §9） |

## 3.1 扩展页结果（七页，2026-10-25 完成）
| 页 | HTML | 屏/卡 | audit | 点击 | problems | 截图 | denseText | 与 V3.9.2 差异要点 |
|---|---|---|---|---|---|---|---|---|
| 语音 | fusion-voice.html | 5 | 0 | 2 OK（说完/确认记录） | [] | voice.png | 4/7/4/4/3 | C 基因全页（语音球+大字转写）；确认卡收据化（A） |
| 备忘 | fusion-memo.html | 5 | 0 | 2 OK（条目/编辑） | [] | memo.png | 9/4/3/9/9 | B 原生列表+分组；行内时间（密度）；编辑态预填 |
| 商品 | fusion-goods.html | 5 | 0 | 2 OK（怡宝/进货） | [] | goods.png | 25/9/7/11/9 | B 列表+分类 chips；低库存 Badge；售价衬线（A）；进货 sheet |
| 临期退货 | fusion-expiry.html | 5 | 0 | 2 OK（开始退货/已退回） | [] | expiry.png | 18/17/18/17/17 | 今天/3天/7天分组+分级 Badge；退货三态推进+统计头联动（3 批 ¥1,860→2 批 ¥1,180） |
| 报表 | fusion-report.html | 5 | 0 | 2 OK（分享/午市） | [] | report.png | 17/17/17/17/17 | A 基因衬线金额；分享按钮触发态（ImageRenderer 390pt 为占位，未验证） |
| 设置 | fusion-settings.html | 5 | 0 | 2 OK（8:00 开关/恢复备份） | [] | settings.png | 4/4/5/4/4 | 保留 V3.9.2 提醒行（每天 8:00/周一 10:00 真实开关）；恢复备份 sheet 文案「恢复为追加合并，不会删除现有数据」 |
| Widget | fusion-widget.html | 6 卡 | 0 | 2 OK（今日营业/记一笔） | [] | widget.png | 3/3/3/3/3/3 | V3.9.2 无改动保持；中号点击切换营业额/净额为原型演示（真 Widget 用 widgetURL 深链）；显示名「小掌柜工作台」 |

## 4. 与 V3.9.2 的逐项比较结论
- 工作台：保留 日期头+plus、四 chips、近7日+收入来源、晨报卡/MorningBriefSheet 结构、问小掌柜胶囊、今日事项、TabBar IA；重设计 Hero 金额衬线 serif（A）；逾期 chip 加「直达待办 · 逾期筛选」注记（对应 V3.9.2 TodoNavigationState 真实跳转，原型以注记表达）；未验证 晨报未读点（xzg.morningBrief.readOn 跨天重置）。
- AI 对话：保留 空态文案与 4 例、状态徽标、确认卡三动作、清空弹窗文案；重设计 确认卡收据化（A 虚线+衬线金额+印章）、输入条 material 悬浮（B）、语音球（C）、确认后折叠状态行+今日 N 笔计数联动（affectUI change-summary 确认交互）；未验证 modify→MoneyEditor 真实链路（「修改」为占位）。
- 经营：保留 V38ChipSelector 日/周/月、收入来源三色条、月目标、近期记录、月报 sheet 固定「较上月同期」；重设计 金额衬线（A）、图表用 #1FA971（图表专用规则）、徽标底 t.fill（对比度修正）；未验证 ImageRenderer 390pt 分享图片（金底按钮触发态占位）。
- 待办：保留 五分段器、Editorial 进度头、上/下午/晚上分组、两段式勾选语义（先写库成功再显完成）、失败重试行、空态文案；重设计 done 圆底 #146B52（对比度修正，暗色恒用）、移出动画归一 V32Motion slow；未验证 TodoNavigationState 首页→待办逾期筛选跳转。
- 客户配送：保留 列表/筛选 chips/详情/四态推进；重设计 状态徽标 Badge 组件化（对比度修正）、pending 行加今日时间（密度）；未验证 电话/导航真实动作。
- 日历：保留 masthead/当日时间/全天事项/月周密度网格/当日详情/当日经营 全部结构；重设计 无；**已定案** 今日金圆 #D4A017 与选中金环 #B8860B 保留 V3.9.2 PR-K 金色（2026-10-25 用户确认，已入账本与 01 §9）；未验证 ghost 行沉降与 matchedGeometryEffect 滑移（原型静态环）。

## 5. 已排除项（不得在实现中复活）
Dashboard 四宫格、全页/正文 Glass、渐变背景、高饱和 accent、无限 pulse、Web 侧边栏替代 NavigationStack、合并 QuickRecord/Voice/AI、快捷操作行、今日最重要、最近记录。

## 6. 限制与已知缺口
- 本会话模型不支持图像输入 → 截图由用户人工复核，自动化校验以 DOM 审计为准。
- 官方 `design_lint.py` 依赖 Playwright Chromium（118MB 下载在本机停滞）→ 以包装器 `_ledger_via_edge.py`（monkeypatch `channel='msedge'`，不改动 skill 脚本）跑通官方 check 与 ledger add；账本已入 `~\.huashu-design\ledger.jsonl`（项目「你的小掌柜 V4.0 fusion」，含外观指纹与决策 note）。
- 官方 check 剩余 🔴 均属板式误报：①单页同时含 Light/Dark 多台手机，官方以页面主背景比对文字（如 business/calendar 主背景被判「深·近黑」）→ 我方 audit.mjs 按逐元素实际祖先背景计算，13 页 0 失败，以 audit 为准；②12–13px 的 footnote/caption 文字低于官方 13px 正文下限 → 属 iOS 原生尺度（caption2=11px 下限），audit 按 ≥11px 通过。🟡「A · B · C」中点连接为内容密度分隔符（非模板装饰）、标题用系统字体为原生 iOS 有意选择。
- 原型是 HTML 单文件，不替代 SwiftUI 实现；SwiftUI 落点见 `04-swiftui-spec.md`。
- 已定案（2026-10-25 用户确认）：日历今日金圆 #D4A017 / 选中金环 #B8860B **保留** V3.9.2 PR-K 金色，已写入设计规范 01 §9 与 Huashu 外观账本；品牌绿不进入日历。
