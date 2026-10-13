# Android V3.7.1 OPPO 真机验收计划（PKJ110 / ColorOS 17）

> 目标设备：OPPO PKJ110，ColorOS 17，无完整 GMS（第一优先级）。
> 本文档为 Phase 0 验收计划；所有真机项当前状态均为 **NOT RUN**（未在真机上运行，不虚报）。
> 相关文档：`ANDROID_V371_PARITY_MATRIX.md`（R01–R29 验收基线）、`ANDROID_V371_DELTA_AUDIT.md`（差异与破坏性风险）。

---

## 1. 安装

| # | 验收项 | 方法 | 期望 | 状态 |
|---|---|---|---|---|
| 1 | 侧载安装 | `adb install` / 文件直装 release APK | 安装成功，可启动 | NOT RUN |
| 2 | 未知来源授权 | ColorOS「安装未知应用」授权流程 | 一次授权后可重复安装 | NOT RUN |
| 3 | 覆盖安装（同签名） | 持久签名证书的 v37 包覆盖安装 v36 包 | 数据保留，7 表零丢失 | NOT RUN |
| 4 | 签名冲突并存方案 | 若签名不一致无法覆盖安装，用 `applicationIdSuffix ".v371"` 打并存包（**不卸载旧包**，先备份：设置 → 备份/恢复导出 `xiao-zhang-gui-backup.json`） | 双包并存，旧数据不受影响 | NOT RUN |
| 5 | 冷启动 | 杀进程后冷启动；深链冷启动（`xzg://ai` / `xzg://voice` / `xzg://quickrecord`，参考 V3.6 修过的冷启动深链崩溃回归） | 无崩溃，R01–R29 可达路径正常 | NOT RUN |

---

## 2. ASR（语音识别）

| # | 验收项 | 方法 | 期望 | 状态 |
|---|---|---|---|---|
| 1 | 可用性预检 | 调用 `SpeechRecognizer.isRecognitionAvailable()` | 有 GMS 返回 true；无 GMS 返回 false（**必查，不假设**） | NOT RUN |
| 2 | 无 GMS 降级 | 在 SpeechRecognizer 不可用时走 R24/R28 语音入口 | 降级为文字输入，不崩溃、不卡死，有明确提示 | NOT RUN |
| 3 | VoiceParser 语义 | 真机说"进货花了 200" / "收入 500" | expense 识别、缺金额报错文案（"请补充支出金额"/"请补充收入金额"）与 `VoiceParserTest` 一致 | NOT RUN |
| 4 | 麦克风权限拒绝 | 拒绝 RECORD_AUDIO 后进语音入口 | 降级文字输入 + 引导去设置（不静默失败） | NOT RUN |

---

## 3. 通知

| # | 验收项 | 方法 | 期望 | 状态 |
|---|---|---|---|---|
| 1 | POST_NOTIFICATIONS 授权 | Android 13+ 运行时申请 | 拒绝后待办/临期/客户跟进提醒有降级说明 | NOT RUN |
| 2 | Exact alarm 降级 | `canScheduleExactAlarms()` 为 false 时（侧载/未授权场景） | 走 SCHEDULE_EXACT_ALARM 降级链（已有），提醒仍可送达（精度降级可接受） | NOT RUN |
| 3 | ColorOS 自启动 | 设置 → 应用 → 自启动管理允许（**待 PKJ110 真机确认具体菜单名**；通用路径，见下方说明） | 杀进程后通知仍能触发 | NOT RUN |
| 4 | ColorOS 后台弹出 | 后台弹出界面权限（如通知需弹界面） | 按需申请，不申请不崩 | NOT RUN |
| 5 | 三类通知触发 | 待办（UNCalendarNotificationTrigger 一次）/ 临期（到期日−remindDaysBefore 9:00）/ 客户跟进（仅 pending，3600s 一次） | 触发时机与 `NotificationSideEffectsTest` 语义一致 | NOT RUN |
| 6 | USE_EXACT_ALARM 合规审计 | Manifest 权限审计（Phase 3 Worker B） | **已处理**：该权限仅限闹钟/日历类核心功能应用，本 App 为店铺记账工具不合规 → 已从 Manifest 移除，仅保留 `SCHEDULE_EXACT_ALARM`（用户可授权/撤销）；降级链经 `ReminderCapabilityTest` + CI E2E 验证完整可用 | ✅（代码审计完成；真机行为 NOT RUN） |

### 3.1 用户侧设置路径（真机验收时按此引导用户；菜单名为通用路径，待 PKJ110 真机确认）

- **自启动管理**：设置 → 应用管理 → 自启动管理 → 找到「你的小掌柜」→ 允许自启动
  （**待 PKJ110 真机确认具体菜单名**；ColorOS 17 不同版本可能在「设置 → 应用 → 自启动」或「电池 → 应用速冻/自启动管理」）
- **通知权限**：设置 → 通知与状态栏 → 通知管理 → 「你的小掌柜」→ 允许通知
  （**待 PKJ110 真机确认具体菜单名**）
- **精确闹钟**：设置 → 应用 → 特殊应用权限 → 闹钟和提醒 → 「你的小掌柜」→ 允许
  （**待 PKJ110 真机确认具体菜单名**；拒绝后 App 内提醒设置页如实显示"非精确提醒"）
- **后台弹出界面**（如需）：设置 → 应用 → 特殊应用权限 → 后台弹出界面
  （**待 PKJ110 真机确认具体菜单名**）

> 约束：不写死未经验证的 ColorOS 菜单名；以上路径为通用写法，真机验收时以 PKJ110 实测菜单为准并回填本节。

---

## 4. 后台

| # | 验收项 | 方法 | 期望 | 状态 |
|---|---|---|---|---|
| 1 | WorkManager 在省电策略下 | ColorOS 省电/超级省电模式 | 备份/同步类任务按预期执行或有明确降级 | NOT RUN |
| 2 | AlarmManager 精度 | 设置临期/待办提醒后锁屏待机 | 提醒准时送达（exact 授权时）/ 降级送达（未授权时） | NOT RUN |
| 3 | 进程被杀后恢复 | 从最近任务划掉后重进 | 数据无丢失，通知计划不丢 | NOT RUN |

### 4.1 用户侧设置路径（真机验收时按此引导用户；菜单名为通用路径，待 PKJ110 真机确认）

- **省电策略 / 后台管理**：设置 → 电池 → 应用耗电管理 → 「你的小掌柜」→ 允许后台活动 / 允许完全后台行为
  （**待 PKJ110 真机确认具体菜单名**；ColorOS 17 可能在「设置 → 应用 → 应用管理 → 省电策略」）
- **锁定后台（防清理）**：多任务界面下拉「你的小掌柜」卡片 → 锁定
  （**待 PKJ110 真机确认具体手势/菜单名**）
- **自启动**：见 §3.1（通知杀进程后仍能触发的前提）

> 约束：不写死未经验证的 ColorOS 菜单名；以上路径为通用写法，真机验收时以 PKJ110 实测菜单为准并回填本节。

---

## 5. 性能

| # | 验收项 | 方法 | 期望 | 状态 |
|---|---|---|---|---|
| 1 | 冷启动耗时 | 从点击图标到首页可交互 | ≤ 2s（记录实测值） | NOT RUN |
| 2 | 列表滑动 | 商品/交易/待办长列表滑动 | 无掉帧感（记录实测） | NOT RUN |
| 3 | APK 体积 | release APK 大小 | 记录实测值（V3.6 参考：13.7MB） | NOT RUN |

---

## 6. 权限拒绝降级矩阵

| 权限 | 拒绝后期望行为 | 状态 |
|---|---|---|
| RECORD_AUDIO（麦克风） | 语音入口降级文字输入 | NOT RUN |
| POST_NOTIFICATIONS | 提醒功能降级说明，不影响主流程 | NOT RUN |
| 相册/文件（备份恢复、收款码图片） | 对应功能提示授权，不阻塞其他功能 | NOT RUN |
| 精确闹钟（SCHEDULE_EXACT_ALARM） | 降级为非精确提醒（`USE_EXACT_ALARM` 已合规移除，见 §3.6） | NOT RUN |

---

## 7. 签名方案（独立节，用户强制要求③）

### 7.1 口径

- 最终 APK **必须使用持久可复用的正式签名证书**，**禁止**每轮 CI 随机生成测试签名作为长期更新包。
- 现状（V3.6）：`release` job 每次用 `keytool -genkeypair` 现场生成临时 keystore（随机密码、有效期 1 天），仅用于 CI 验证构建产物可签名、可安装——**该口径不延续为 V3.7.1 正式包**。
- 正式密钥**不上仓库**（不提交 keystore / 密码 / 任何密钥材料到 Git）。

### 7.2 Phase 0 只定方案（本节），Phase 4 执行

1. **密钥生成**：用户在可信本地环境生成正式 keystore（RSA 2048+，有效期 25 年+），**由用户保管**，不经手仓库。
2. **CI 注入方式**：keystore 经 base64 编码后存入 GitHub Secrets（如 `XZG_RELEASE_KEYSTORE_BASE64`、`XZG_KEYSTORE_PASSWORD`、`XZG_KEY_ALIAS`、`XZG_KEY_PASSWORD`）；`release` job 在运行时解码到 runner `/tmp`（`::add-mask::` 脱敏），构建后删除，不留 artifact。
3. **构建接线**：`android/app/build.gradle.kts` 的正式 `signingConfig` 仅在上述 Secrets 非空时启用；无 Secrets 时 `assembleRelease` 保持现有 CI 临时测试签名口径（用于日常验证），并在产物名/文档中明确标注"测试签名，不可作为更新包"。
4. **更新连续性**：同一证书签名 → 覆盖安装保留数据（配合 §1.3 覆盖安装验收）；证书更换必须提前规划迁移（换签 = 无法覆盖安装，需走备份恢复流程）。

### 7.3 与安装节的衔接

- §1.3 覆盖安装验收**必须使用正式证书签名的包**验证，CI 临时签名包不计入。
- §1.4 并存方案（`applicationIdSuffix`）仅用于签名冲突过渡期，不作为常规分发形态。

---

## 8. 验收结论记录（Phase 3/4 填写）

| 轮次 | 日期 | 包版本/签名 | 通过/失败/NOT RUN | 备注 |
|---|---|---|---|---|
| — | — | — | — | 待 Phase 3 真机执行后填写 |

---

## 9. SleepDown-derived candidate ideas（P0 文档归档）

> **许可证红线**：SleepDown 的 `LICENSE.md` 是自定义"署名非商业、源码可见 1.1"许可，**不是**宽松开源许可（研究报告 §4）。本节只记录交互原则 / 运动参数 / 架构思路的独立实现清单；**禁止直接复制** SleepDown 的 Kotlin / 着色器 / 资源 / 界面代码。

- **已具备**（小掌柜已有，无需做）：AI 五工具 + 确认卡 / 写库门禁 / 幂等日志（`AgentCore` → Pending Action → 确认 → `RepositoryToolExecutor` → Repository → 幂等日志）；Compose + Room + DataStore；通知调度；语音降级（ASR 不可用时文字回退，见 §2）。
- **建议下一期（P1）**（首个 APK 交付后评估）：Android 自有 MotionSpec / MotionPolicy（立项见 `ANDROID_V371_DELTA_AUDIT.md` §10）；非线性模糊强度滑杆映射（仅当壁纸/玻璃强度设置需优化时）；材质性能分级思路。
- **不可直接搬用**：`OplusSeamlessBackend` 跨 Activity 转场（小掌柜单 Activity NavHost 架构不匹配）；SleepDown 课程表复杂计划（店铺业务工具不适用）。
- **真机待验证**：Oplus 私有转场能力、端侧 ASR 可用性——PKJ110 + 当前 ColorOS 17 固件上未经真实设备日志/视频验证前，一律标 `NOT VERIFIED`，模拟器通过不算。

### 9.1 系统辅助功能与低性能降级测试要求

以下条目在 Phase 3 真机验收时逐项按 PASS / FAIL / NOT RUN 报告：

1. **系统 Reduce Motion（动画减弱）开启**：全部页面转场、Sheet 展开、浮层动画必须退化为直接显示/淡入（参考 iOS V371 S0–S3 token 的 Reduce Motion 规则）；验收项：导航可达性、点击区域、返回行为、弹窗保存/取消语义与动效开启时完全一致。
2. **系统"减少透明度"**：玻璃/模糊类控制面退化为不透明底色；列表、经营数字、任务内容始终保持清晰可读。
3. **系统低性能模式**：动效自动降帧或跳过非必要动画；动效不可造成卡顿、尾帧残影、黑屏或点击丢失。
4. **低电量模式**：仅可作为**特效强度调整的参考输入**（如降低模糊强度、缩短动效时长）；**不得凭系统状态自行禁用核心功能**——禁止在省电/低电量时关闭同步、通知、语音入口、记一笔等业务功能。

### 9.2 设备能力检测与具名失败诊断（只写要求和分类，不写代码）

参考 SleepDown `OplusCapabilityPolicy` 的具名失败原因结构（研究报告 §1 发现 2），在小掌柜内**独立实现**以下能力探测分类，用于 ASR 可用性（§2）、通知（§3）、精确闹钟（§6）的能力探测。实现方式独立编写，不搬用 SleepDown 源码（许可证红线见本节开头）。

| 失败原因 | 含义 | 适用能力 |
|---|---|---|
| `runtimeClassMissing` | 运行时类不存在（如 OEM 定制类缺失） | Oplus 私有转场 PoC、端侧 ASR 引擎 |
| `requiredApiMissing` | 所需方法 / API 缺失 | 精确闹钟（AlarmManager）、全屏 Intent 通知 |
| `unsupportedVersion` | 系统 / 固件版本不满足 | Oplus 私有转场、通知渠道新特性 |
| `sourceNotReady` | 能力源未就绪（服务未绑定 / 权限待定） | 端侧 ASR 引擎、TTS |
| `unsupportedWindowMode` | 当前窗口模式不支持 | 分屏 / 小窗下的转场与浮层 |

要求：

- 探测结果只用于**降级与诊断提示**（如 ASR 不可用 → 文字回退 + 明确提示用户），不得静默关闭功能；
- 每项探测结果与 §8 验收结论绑定记录：探测失败或未验证时记录 `NOT VERIFIED`，**不许记 PASS**；
- 诊断日志须脱敏（禁止输出 API Key、语音原文等敏感内容），可用于 §8 的失败原因归档；
- Oplus 私有转场 PoC 的每次探测都必须留下可查日志；无真机视频/日志不得宣称支持（对应本节"真机待验证"分类）。
