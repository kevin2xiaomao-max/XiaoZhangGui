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
| 3 | ColorOS 自启动 | 设置 → 应用 → 自启动管理允许 | 杀进程后通知仍能触发 | NOT RUN |
| 4 | ColorOS 后台弹出 | 后台弹出界面权限（如通知需弹界面） | 按需申请，不申请不崩 | NOT RUN |
| 5 | 三类通知触发 | 待办（UNCalendarNotificationTrigger 一次）/ 临期（到期日−remindDaysBefore 9:00）/ 客户跟进（仅 pending，3600s 一次） | 触发时机与 `NotificationSideEffectsTest` 语义一致 | NOT RUN |

---

## 4. 后台

| # | 验收项 | 方法 | 期望 | 状态 |
|---|---|---|---|---|
| 1 | WorkManager 在省电策略下 | ColorOS 省电/超级省电模式 | 备份/同步类任务按预期执行或有明确降级 | NOT RUN |
| 2 | AlarmManager 精度 | 设置临期/待办提醒后锁屏待机 | 提醒准时送达（exact 授权时）/ 降级送达（未授权时） | NOT RUN |
| 3 | 进程被杀后恢复 | 从最近任务划掉后重进 | 数据无丢失，通知计划不丢 | NOT RUN |

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
| 精确闹钟（SCHEDULE_EXACT_ALARM） | 降级为非精确提醒 | NOT RUN |

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
