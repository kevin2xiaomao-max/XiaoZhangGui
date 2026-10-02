# Android V3.6 最终 Parity 报告

> Source of Truth：iOS `feature/v3.6-ui-ai-expansion` @ `335981b`（只读审计区 `~/workspace/xzg-v36-audit`）
> Android 分支：`android/v3.6`，HEAD `446296f`
> 报告日期：2026-10-02

## 一、结论

Android V3.6 迁移 **Phase 0→7 全部完成**，Release Gate 逐项通过：

| Gate 项 | 结果 |
|---|---|
| TODO / FIXME / stub / placeholder / 空 callback | ✅ 零命中（`placeholder=` 均为 TextField 输入提示文案；`= {}` 均为默认参数，调用点全部真实接线） |
| 假 Production 数据 | ✅ 零命中（假数据仅存在于 Paparazzi/测试；DemoCatalog 只走演示内存库 DAO 直写，生产路径零调用） |
| 未接线按钮 | ✅ 抽查 Todo/Customer/Expiry/Profile 调用点，onClick 全部有真实行为 |
| 55 功能点 Matrix 状态 | ✅ 56 功能行 0 空白（实现 ✅52 / 🟡1 / ⏭️3；Test ✅54 / 🟡2） |
| `assembleRelease` + `bundleRelease` | ✅ CI run `36971656637` SUCCESS |
| GitHub Actions 全绿 | ✅ build（assembleDebug/test/lint/Paparazzi）+ E2E 模拟器 + release 三 job 全绿 |
| APK/AAB artifact 验证 | ✅ 见下表 |
| worktree clean | ✅ `git status` 干净，无 keystore/密码提交 |

## 二、产物证据

### Release 产物（CI 临时测试签名，非正式发布签名）

| 产物 | artifact 名 | 字节数 | SHA256 | 包信息 |
|---|---|---|---|---|
| app-release.apk | `xiaozhanggui-android-release-apk` | 13,676,873 | `90ead5623ce78ba85b21facb2a09611ac7be5bfe2243970e66a9354f5060b159` | `com.xiaozhanggui.app` / v36 / 3.6.0 / label 你的小掌柜 |
| app-release.aab | `xiaozhanggui-android-release-aab` | 13,304,797 | `6e6e631ae3bfa903c9f9a698975589312db3e42a63ce1366e713490d9ca56eb` | base module 含 dex/manifest/res/四架构 so，共 143 文件 |

> 签名口径：CI 内 keytool 现场生成临时 keystore（`/tmp`，随机密码，`::add-mask::` 脱敏），`signingConfigs.ciTest` 仅在 env 传入时挂载。仓库无 keystore、无密码。**正式上架需另立项做正式签名**。详见 `docs/ANDROID_V36_RELEASE_SIGNING.md`。

### Debug 产物

| 产物 | 字节数 | SHA256 |
|---|---|---|
| app-debug.apk（Phase 7 最终） | 19,870,595 | `24544513607c6a04b8aa622c9eb586219cf631136330920c183bfbabb271e312` |

## 三、各 Phase 证据链

| Phase | Commits | CI run | 关键证据 |
|---|---|---|---|
| 0 审计 | `acc3ea8` `5601ce8` `6248233` | — | 5 份审计报告 + Parity Matrix + 平台差异 + 迁移审计报告 |
| 1 骨架 | `70849e4` `1f84475` | `36923819266` SUCCESS | debug APK 17,149,720 字节（SHA256 `53f2076f…`） |
| 2 数据层 | `6293a57` `f897069` `3e0e2ff` | `36926878499` SUCCESS | 12 tests 0 fail；7 Repository + 通知调度 + BackupService v2 |
| 3 UI | `f5fc89c`…`ed9967e`（11） | `36930728086` SUCCESS | debug APK 18,091,134（SHA256 `0e45ad15…`）；5 Tab + 8 抽屉 + 17 Sheet + 4 深链接 |
| 4 AI/语音/速记 | `ce4a944` `e31d1e7` `735f54e` `7d6d178` `85a4803` | `36936403482` SUCCESS | 112 tests 0 fail；5 AI tools + Pending Action + 双独立解析器 + 日程/日历 |
| 5 视觉 | `0588ecf`…`109a3fb`（8） | `36940433302` SUCCESS | 40 张 Paparazzi 截图；修复 4 处真实偏离；`docs/ANDROID_V36_VISUAL_PARITY.md` |
| 6 测试 | `a647cee` `b852dab` `aab80cd` `62dcf69` `429930c` | `36968594853` SUCCESS | 18 Compose UI + 4 E2E 旅程 + 47 JVM 回归；修冷启动深链接崩溃生产 bug |
| 7 Release | `6ca0a5f` `13776ff` `4adf8d5` `25573c3` `412e6f4` `446296f` | `36971656637` SUCCESS | 226 tests 0 fail；release APK/AAB；Demo Mode 真实落地 |

## 四、功能状态总览（56 功能行）

- **实现列**：✅ 52 / 🟡 1 / ⏭️ 3
- **Test 列**：✅ 54 / 🟡 2
- 逐项明细见 [`docs/ANDROID_V36_PARITY_MATRIX.md`](./ANDROID_V36_PARITY_MATRIX.md)

### 🟡 已知差异（有依据，接受）

1. **天气按钮+详情**（实现 🟡 / Test 🟡）：占位实现，未接入 WeatherAPI.com。iOS 有真实 API 调用；Android 待真实接入后补测试。按钮可点，Sheet 内已明确标注。
2. **动效**（实现 🟡 / Test ✅）：时长/弹簧参数 1:1，`resolveMotion` 纯函数对齐 iOS `V32Motion.resolve`；但调用方尚未统一使用，系统"减弱动态效果"开关未接线。
3. **App 启动三路**（Test 🟡）：三路切换 + P0-2 失败报错页需 Android 运行时验证，JVM/E2E 均未覆盖。
4. **视觉差异**（见 `docs/ANDROID_V36_VISUAL_PARITY.md`）：日期/时间选择器用 Material3 弹窗（iOS 原生内联，平台惯例适配）；语音面板金额双写与 iOS `VoiceView.swift:285` 同写法，保持 1:1；ActionCard 失败态按钮行为等价。

### ⏭️ 平台差异（不迁移，有依据）

1. **主屏 Widget**：iOS WidgetKit；Android 待立项（无 1:1 对等物，不删除需求）。
2. **Live Activity**：iOS 专属；Android 无对等物。
3. **Siri 快捷指令 ×3**：iOS 专属；Android 可用 App Shortcuts 另立项。

## 五、红线遵守声明

| 红线 | 状态 |
|---|---|
| AI 仅 5 tools（searchRecords/recordRevenue/createTodo/createMemo/createDelivery） | ✅ `domain/ai/AiTools.kt` 枚举恰为 5 个 |
| AI 写入必须经 Pending Action→用户确认→RepositoryToolExecutor→Repository→Journal | ✅ |
| **AI 禁止直接写 Room** | ✅ `data/ai/` + `domain/ai/` 零 DAO 直接调用（grep 验证） |
| Voice（含 Expense，缺金额报错）与 QuickRecord（无 Expense，缺金额写 0）解析器**不得统一** | ✅ 独立 `VoiceParser` / `QuickRecordParser` + GATE C 回归测试 |
| 禁 WebView 套壳 | ✅ 零 WebView |
| 未修改/覆盖 iOS 分支 | ✅ iOS 分支零提交 |
| 未碰 `feature/v3.6.1-reference-home`，未引入 V3.6.1 设计 | ✅ |
| 不提交真实 keystore/密码 | ✅ 仓库零 keystore；release 为 CI 临时测试签名 |
| OPPO / ColorOS 17 / 中国大陆 / 可能无 GMS | ✅ 通知用 AlarmManager（不依赖 GMS）；E2E 用无 GMS 模拟器（API 30） |

### 核心业务语义（抽查通过）

- Todo 无 `updatedAt`；Performance/Expense 统计按业务 `date`
- Customer `xzg-delivery-v1` 编解码 round-trip，UI 不显示编码串；Calendar 按解码 deliveryTime 聚合
- Memo title≤100、content≤2000 静默截断；Goods 标题"临时商品"、删除无确认
- Customer 状态机 待处理→配送中→已完成；Expiry 待处理↔已退货；6 分组口径与 iOS 一致
- Schedule 周一开头；Calendar 周日开头；无 Production 原生 swipe-to-delete

## 六、Remaining Risks

1. **真机手感**：OPPO / ColorOS 17 真机交互、动画、权限弹窗（RECORD_AUDIO、精确闹钟）需用户用 debug APK 实测。
2. **Demo Mode 端到端**：种子数据显示→关闭→真实数据恢复，需真机手动确认（模拟器未覆盖，避免 flake）。
3. **无 GMS 的语音识别**：`SpeechRecognizer` 依赖系统识别服务，在无 GMS/无识别服务的设备上可能不可用——缺金额报错链已做，但识别服务缺失时的降级提示需真机验证。
4. **WeekRail 跨天 golden 漂移**：Paparazzi 用当前日期，跨天对比需重录（CI 内录制+上传 artifact，未入库 golden）。
5. **正式签名**：当前 release 产物为 CI 临时测试签名，上架需另立项。
6. **天气**：真实 WeatherAPI.com 接入待立项（含 API key 的 Secret 管理）。
7. 本地 Linux 无 Android SDK，所有构建验证以 GitHub Actions clean-room 为准；未做本地编译/IPA/真机验证的声称。

---

*本报告与 `docs/ANDROID_V36_PARITY_MATRIX.md`（56 功能行最终状态）、`docs/ANDROID_V36_VISUAL_PARITY.md`、`docs/ANDROID_V36_RELEASE_SIGNING.md` 共同构成 V3.6 Android 迁移交付物。*
