# 「你的小掌柜」Android V3.7.1（build 37）Release Notes（框架版）

> 版本：**3.7.1 / build 37**（versionCode 37）
> 基线：iOS `integration/v371-grok-thinking-fixes @ d238ff0`（3.7.1 / build 37，只读审计）
> 构建：**稳定签名 release 构建完成**（CI 38765345381 三 job 全绿（验收修复轮））。

---

## 1. 版本信息

- 版本号：3.7.1
- Build：37（versionCode 37）
- 分支：`android/v3.7.1-oppo-port`
- GitHub SHA：`18fef2a`（ci(android/v3.7.1): release 优先使用稳定签名证书）
- CI run URL：https://github.com/kevin2xiaomao-max/XiaoZhangGui/actions/runs/38765345381
- APK 下载地址：https://github.com/kevin2xiaomao-max/XiaoZhangGui/actions/runs/38765345381/artifacts/11989400569（`xiaozhanggui-android-release-apk`，需登录 GitHub 下载）
- APK SHA-256：`a014025afbf293ec0a06b0959aeffca9c8edfa1b50f388ff5812808fd4c25052`
- 签名证书指纹（SHA-256）：`45:71:3D:B5:DC:BB:87:F3:07:5C:07:4D:16:1E:96:7D:51:64:95:1A:DB:A3:8E:58:C1:08:48:B4:58:C4:46:15`

---

## 2. 信息架构：四 Tab

V3.7.1 起取消五 Tab，改为**四 Tab**结构（与 iOS V3.7.1 对齐）：

| Tab | 内容 |
|---|---|
| 首页 | Editorial 风格：Header（日期/天气按钮/记一笔胶囊/头像）→ 今日营业额 Hero（可点进经营）→ AICommandEntry →「今日重点」→「接下来」 |
| 待办 | 待办事项列表/新增/编辑/完成/删除 |
| 日历 | 日程周条（周一起始）+ 月历网格（周日起始）+ 日口径聚合 |
| 经营 | 营业额/支出统计、交易记录、商品、扫呗导入、记收入/记支出 |

- **AI 不再是独立 Tab**：入口恒为「首页 AICommandEntry → AI Sheet」，关闭 Sheet 回到当前页。
- **「我的」不再是 Tab**：入口为首页右上角头像 → 个人中心。

---

## 3. 主要功能清单

- **记账**：记收入/记支出（`incomeSource` 三级派生：扫呗导入按 paymentMethod / 手动记账默认到店）、交易历史筛选、今日经营日报。
- **扫呗导入**：文件解析 + 库内/文件内双重 fingerprint 去重，导入按 paymentMethod 派生收入来源。
- **待办/备忘/临期/客户**：待办到期提醒、临期退货（提醒日 9:00 = 到期日 − 提前天数）、客户配送跟进（pending 状态跟进通知）。
- **商品**：商品管理，删除需二次确认（"删除后无法恢复"）+ 失败显式提示。
- **AI 助手**（5 tools：`searchRecords` / `recordRevenue` / `createTodo` / `createMemo` / `createDelivery`）：主 Provider 固定 DeepSeek（`deepseek-flash` 默认 / `deepseek-v4-pro`），failover 仅 1 次（仅网络/超时/429/5xx，401/403 不换链），密钥只存 Android Keystore。
- **语音**：语音输入（普通话/粤语）+ AI 短语音面板；无 GMS 设备自动降级文字输入；麦克风按钮按 ASR 可用性置灰（不假装可用）。
- **备份/恢复**：导出 `xiao-zhang-gui-backup.json`（每次覆盖），恢复=追加不清空，恢复后重建三类通知。
- **通知**：待办/临期/客户三类通知渠道；`USE_EXACT_ALARM` 已合规移除，仅保留 `SCHEDULE_EXACT_ALARM`（可授权/撤销，拒绝后降级非精确提醒并诚实标注）。
- **无障碍**：TalkBack 语义覆盖；系统 Reduce Motion（移除动画）开启时全部 Sheet/转场退化为直接呈现/淡入，交互语义不变。
- **演示模式**：DataStore 开关控制的内存库演示数据（与生产库完全隔离，生产路径零调用）。

---

## 4. 已知问题

| # | 问题 | 状态 |
|---|---|---|
| 1 | R10 天气：占位实现（`--°` + Phase 5 说明），真实天气 API 待后续版本 | 🟡 占位 |
| 2 | R15 今日经营日报：UI 截图用例待补（VM 绑定） | 🟡 验证待补 |
| 3 | R18 交易历史：无专用 UI 截图 | 🟡 验证待补 |
| 4 | R19–R21 收款码系列（列表/编辑/全屏）：UI 存在，无专用测试 | 🟡 验证待补 |
| 5 | R23 店铺/目标设置：无专用测试（提醒设置行已有 JVM 测试） | 🟡 验证待补 |
| 6 | 低性能模式自动降帧/跳过非必要动画：未实现（P1 候选，见 DELTA §10） | GAP |
| 7 | E04–E07（Widget / Live Activity / App Intents）：平台差异，不追求对等 | ⏭️ 平台差异 |

---

## 5. NOT RUN 真机清单（OPPO PKJ110 / ColorOS 17）

以下项目**未在真机上运行**，CI/模拟器通过不代替真机结论（用户红线）：

- 侧载安装 / 未知来源授权 / 同签名覆盖安装（数据保留）/ 签名冲突并存方案 / 冷启动（含深链冷启动）
- ASR 可用性预检、无 GMS 降级、语音语义真机验证、麦克风权限拒绝路径
- 通知三类触发时机、POST_NOTIFICATIONS 拒绝降级、精确闹钟降级链、ColorOS 自启动/后台弹出/省电策略
- WorkManager 省电策略下行为、AlarmManager 精度、进程被杀后恢复
- 冷启动耗时、长列表滑动、APK 体积实测
- Reduce Motion / 减少透明度 / 低电量模式 真机行为
- Oplus 私有转场能力、端侧 ASR 可用性 → 一律 `NOT VERIFIED`

完整验收表见 `docs/ANDROID_V371_OPPO_VERIFICATION.md`。

---

## 6. 构建与签名

- 最终提交 SHA：`18fef2a`
- CI run（含 assembleRelease）URL：https://github.com/kevin2xiaomao-max/XiaoZhangGui/actions/runs/38765345381（build / e2e / release 三 job 全绿）
- release APK 下载地址：https://github.com/kevin2xiaomao-max/XiaoZhangGui/actions/runs/38765345381/artifacts/11989400569（`xiaozhanggui-android-release-apk`，13,742,417 字节）
- release AAB 下载地址：https://github.com/kevin2xiaomao-max/XiaoZhangGui/actions/runs/38765345381/artifacts/11990150310（`xiaozhanggui-android-release-aab`，13,358,223 字节）
- APK SHA-256：`a014025afbf293ec0a06b0959aeffca9c8edfa1b50f388ff5812808fd4c25052`
- AAB SHA-256：`b6d0901bf1523505186cd0b9a82b63ac6eeb89ef1f072bcbe1d8854fd9feb5c2`
- 签名证书 SHA-256 指纹：`45:71:3D:B5:DC:BB:87:F3:07:5C:07:4D:16:1E:96:7D:51:64:95:1A:DB:A3:8E:58:C1:08:48:B4:58:C4:46:15`
- 签名证书有效期：2026-10-13 → 2051-10-13（25 年，RSA 2048，alias `xzg-v371-release`）
- 包信息（aapt dump badging）：`package: name='com.xiaozhanggui.app' versionCode='37' versionName='3.7.1'`，label='你的小掌柜'
- apksigner：`Verifies`，v2 scheme，证书指纹与 keystore 逐字节一致
- 口径确认：✅ 持久可复用正式证书（一次生成，GitHub Secrets 注入） / ✅ 密钥不上仓库（keystore 存仓库外 `~/workspace/xzg-signing/`） / ✅ CI 临时测试签名仅用于无 secret 环境（回退逻辑已明确标注）

## 7. 升级说明

- 同签名 + 更高 versionCode 可直接覆盖升级，数据保留（Room 非破坏性迁移 1→2，防御式：V3.6 真机库已有 `incomeSource` 列则跳过 ADD）。
- 签名不一致**不得直接覆盖安装**：先在旧包内备份导出 JSON，**不得擅自卸载旧包**（详见 `docs/OPPO_INSTALL_GUIDE.md` §2）。
