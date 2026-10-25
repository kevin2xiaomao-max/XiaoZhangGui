# 02 · 资源清单（V4.0 Fusion 原型工程）

工程根：`design-demos/xzg-v400-fusion/`

## A. 设计 Skill 安装（DSH 接入层）
| 资源 | 路径 |
|---|---|
| Skill 安装目录 | `C:\Users\Administrator\.agents\skills\huashu-design`（389 文件 / 41MB，DSH rank-500 扫描根） |
| 源仓库 | https://github.com/alchaincyf/huashu-design（工作区 `_vendor/huashu-design` 有克隆副本，与安装副本逐字节一致） |
| 官方 CLI | `npx skills`（npm-cache 缓存 `C:/Users/Administrator/AppData/Local/npm-cache/_npx/ac0ed6aa23b37c1e/node_modules/skills`） |
| 安装命令 | `npx skills add alchaincyf/huashu-design -g -a codex -y --copy` |
| iOS 设备框（skill 资产，被本工程内联） | `~\.agents\skills\huashu-design\assets\ios_frame.jsx`（192 行 / 4945 B） |

## B. 本工程 vendor（离线自包含，build.mjs 在构建期全部内联进单 HTML）
| 文件 | 来源 | 大小 |
|---|---|---|
| `_vendor/react.js` | react@18.3.1 UMD production | 10,751 B |
| `_vendor/react-dom.js` | react-dom@18.3.1 UMD production | 131,835 B |
| `_vendor/babel.js` | @babel/standalone@7.26.4 | 2,983,904 B |
| `_vendor/ios_frame.jsx` | skill assets/ios_frame.jsx 原样复制（md5 4b47e0bb…） | 4,945 B |
| `_vendor/affectui-ref/` | affectUI 8 个 MIT 免费组件源码（仅参数研究，不复制实现）：thinking-loader / number-ticker / shimmer-loader / change-summary / decision-inbox / tool-call-card / segmented-control / smart-recommendation | 99 KB |

## C. 构建与验证脚本（Node 24 内置 WebSocket，零第三方依赖）
| 文件 | 职责 |
|---|---|
| `build.mjs` | Babel 预编译（presets:['react']），把 kit + ios_frame + 页面 jsx 各包 IIFE 内联为单 HTML（避免顶层 const 词法冲突）。产物：13 页 fusion-{home,ai,business,todo,customer,calendar,voice,memo,goods,expiry,report,settings,widget}.html |
| `drive.mjs` | Edge headless + CDP：截图（2×DPI）、按可见文本派发真实鼠标事件点击、捕获 Runtime.exceptionThrown / console.error / Log.entryAdded。参数 `--url --out --width --height --click="A||B" --clickgap --wait --scale` |
| `audit.mjs` | 自动体检（exit 2 = 有失败）：每台 [data-phone] 输出 overflow / smallTargets(<38px) / smallText(<11px) / contrast(<4.5，≥24px 用 3) / interactive / denseText |
| `probe.mjs` | 一次性溢出诊断（列出溢出元素身份 + 样式片段） |

浏览器依赖：`C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe`（headless=new）。

## D. 源码
| 文件 | 职责 |
|---|---|
| `src/fusion-kit.jsx` | 共享设计系统：tokens `T.light/T.dark`（全部经 WCAG 实测）、`P` 图标库（26 个 24px stroke SVG）、组件 Icon / Money(serif tabular) / Badge / Row / Section / Sep / EmptyState / Segmented / TabBar(4-tab 冻结 IA) / ReceiptCard(A 基因收据确认卡) / VoiceOrb(C 基因语音球) / RunStrip / Phone(内联 IosFrame，内容区 764px) / Board(展示板 ground #E9EFEB) |
| `src/pages/fusion-ai.jsx` | AI 对话 |
| `src/pages/fusion-home.jsx` | 工作台首页 |
| `src/pages/fusion-business.jsx` | 经营 |
| `src/pages/fusion-todo.jsx` | 待办 |
| `src/pages/fusion-customer.jsx` | 客户配送 |
| `src/pages/fusion-calendar.jsx` | 日历 |
| `src/pages/fusion-voice.jsx` | 语音记账 |
| `src/pages/fusion-memo.jsx` | 备忘/记录 |
| `src/pages/fusion-goods.jsx` | 商品库存 |
| `src/pages/fusion-expiry.jsx` | 临期退货 |
| `src/pages/fusion-report.jsx` | 今日经营日报 |
| `src/pages/fusion-settings.jsx` | 设置/我的 |
| `src/pages/fusion-widget.jsx` | 小组件（6 张 data-phone 卡片，非 IosFrame） |
| `build-vm.mjs` / `build-ge.mjs` / `build-rs.mjs` | 扩展页构建期用的 per-agent 构建副本（targets 仅各代理负责页），官方 `build.mjs` 已含全部 13 target |

## E. 设计文档
| 文件 | 内容 |
|---|---|
| `00-page-inventory.md` | 全页面与交互清单（§1–§19 基于 3.7.1 树，§20 为 V3.9.2 权威修订：掌柜晨报 / 经营趋势 chips+月报 / 日历密度网格 / 待办进度头+两段式勾选 / MoneyEditor 分段 / Profile 新提醒行） |
| `01-design-system.md` | 融合原则（B70/A20/C10）、Light/Dark token 表（含对比度实测值）、字号/间距/圆角、V32Motion、高密度规则、组件清单、已否决项 |
| `03-v393-merge-map.md` | V3.9.3 功能合并映射：10 项已并入基线功能→V4.0 设计处理表、Muse 未并入线状态（ai-cost-guard 分歧核实）、§4.1 十三页原型→基线代码映射表 |
| `04-swiftui-spec.md` | SwiftUI 实现规范：token→Color 映射表（不达标色值禁回退）、衬线数字、44pt 点按、V32Motion、组件约定、§6 十三页逐页规范（结构树+状态机+token+差异点）、§7 动效落地配方 |
| `05-acceptance-report.md` | 验收报告：方法学 + 阈值 + 六页结果表 + §3.1 扩展七页结果表 + §4 V3.9.2 逐项比较 + 已排除项 + 限制 |
| `06-affectui-reference.md` | affectUI 辅助参考清单：DSH 远程 MCP 接入结论（不热接入 + 可粘贴 YAML）、8 个重点组件实测参数与采纳决策、页面映射表、落地硬规则 |

## F. 截图产出
`shots/`（均 1500×2000 @2×，13 页点击链终态截图）：`home.png`、`ai-light.png`、`business.png`、`business-sheet.png`、`todo.png`、`customer.png`、`calendar.png`、`voice.png`、`memo.png`、`goods.png`、`expiry.png`、`report.png`、`settings.png`、`widget.png`。

## G. 测试基线（V3.9.2 验证提交）
- `xiaozhanggui-v40/`：git worktree，分支 `design/v40-full-ui-evolution`，检出 `a6bfced`（= ios/v392-integration「Merge pull request #6」），MARKETING_VERSION 3.9.2 / build 41。
- 远端：`https://github.com/kevin2xiaomao-max/XiaoZhangGui.git`（单分支克隆需 `git fetch origin <分支名>` 显式拉取）。
- 禁动分支：`ios/v392-ai-cost-guard`(19a5f452, tag v3.9.2-handoff-2)、`ios/v392-pr-i-morning-brief`(cfdb179c)、`ios/v392-pr-k-schedule-v39`(afb41d3)、`ios/v392-second-batch-fixes`(5247ec0)。
