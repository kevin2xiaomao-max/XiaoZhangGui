# 你的小掌柜 Android V3.6 — Platform Differences

> iOS Source of Truth：`feature/v3.6-ui-ai-expansion` @ `335981badfa7163ad56063662bf0d7b5d2a78451`
> Android branch：`android/v3.6`
> 本文档记录 Apple-only 能力的 Android 等价实现，以及任何无法 1:1 迁移的行为差异。用户要求：Apple-only 能力不得删除，必须提供 Android 等价实现。

---

## 1. 语音识别

| iOS | Android 等价 |
|---|---|
| SFSpeechRecognizer（iOS 系统级，离线支持较好） | android.speech.SpeechRecognizer（依赖设备 Google 语音服务；国内无 GMS 设备需降级：科大讯飞/百度等云 ASR，或提示用户无法使用）|
| AVAudioEngine 音频流 | AudioRecord 采集（如需自定义）|
| NSSpeechRecognitionUsageDescription | RECORD_AUDIO 运行时权限 |

**差异**：识别准确率与延迟因设备/网络而异；语音波形在 iOS 与 Android 均为装饰动画（非真实音量驱动），保持一致。

---

## 2. 通知调度

| iOS | Android 等价 |
|---|---|
| UNUserNotificationCenter（系统级，省电优化内建） | AlarmManager.setExactAndAllowWhileIdle（精确闹钟）+ NotificationChannel；1 小时跟进用 WorkManager 一次性延时任务 |

**差异与风险**：
- Android 12+ `SCHEDULE_EXACT_ALARM` 为特殊权限，用户可在设置中撤销；被撤销时待办/临期提醒降级为不精确（setAndAllowWhileIdle），可能延迟。
- 国产 ROM（小米/华为/OPPO/vivo）后台限制严格：需引导用户将应用加入电池优化白名单/允许自启动，否则通知可能延迟或丢失。应用内在提醒设置页增加"电池优化"引导入口。
- 通知 ID：iOS 用 `todo-<notificationID>`/`expiry-<notificationID>`/`customer-<notificationID>-followup` 字符串；Android 用 notificationID (UUID) 的稳定 hash 派生 int requestCode，保证重启后可取消。

---

## 3. Widget 与 Live Activity

| iOS | Android 等价 |
|---|---|
| WidgetKit（systemSmall/Medium + 锁屏 accessoryInline/Circular/Rectangular） | AppWidgetProvider + Glance（主屏小/中尺寸）；锁屏小组件 Android 5+ 已移除，无等价 |
| ActivityKit Live Activity + 灵动岛 | 持续性通知（ongoing notification + 自定义 RemoteViews 布局，定期更新）|
| AppIntents（Widget 上直接勾选待办） | 小组件按钮 → PendingIntent → BroadcastReceiver 直接写 Room（同进程，无需跨进程容器）|
| App Group（UserDefaults suiteName + 共享 SwiftData store，跨进程） | 不需要：Android 主应用与 Widget 同 UID，直接访问同一 Room 数据库 |

**差异**：
- 锁屏 accessory 小组件无等价；iOS 锁屏单行/圆形/矩形信息在 Android 上由持续性通知承担。
- 灵动岛 expanded/minimal 形态无等价；持续性通知在锁屏和下拉 shade 可见，行为近似但视觉不同。
- Widget 勾选待办的幂等语义保留（只置完成不 toggle，已完成保持首次 completedAt）。

---

## 4. 收款码亮度保护

| iOS | Android 等价 |
|---|---|
| UIScreen.main.brightness（可写系统亮度，0–1） | Activity Window attributes.screenBrightness（仅当前窗口，0–1；退出恢复）|

**差异**：
- Android 无需 WRITE_SETTINGS 全局亮度权限，窗口级亮度足够且更安全。
- 异常 kill 恢复：iOS 用 UserDefaults 标记；Android 用 DataStore 标记 + Application.onCreate 检查恢复（虽然窗口级亮度 kill 后自动失效，但为语义对齐仍做标记清理）。

---

## 5. 扫呗导入

| iOS | Android 等价 |
|---|---|
| 自研 MiniZip + Compression framework raw DEFLATE 解压 XLSX | java.util.zip（ZipInputStream/Inflater nowrap=true）+ SAXParser 标准库；自研部分可整体替换 |
| Vision VNRecognizeTextRequest（系统内置，零体积，中文离线） | ML Kit Text Recognition 中文模型（com.google.mlkit:text-recognition-chinese；需随包或动态下载，APK 体积增加约数 MB；无 GMS 设备需降级提示）|
| fileImporter / PhotosPicker | ActivityResultContracts.OpenDocument / PickVisualMedia；ContentResolver.takePersistableUriPermission 对应 security-scoped resource |

**不变**：字段映射关键词、fingerprint 生成规则（SHA-256）、去重语义（文件内+跨文件）、"状态为空视为成功/未知状态视为未计入"的反直觉业务规则，逐字保留。

---

## 6. 天气

| iOS | Android 等价 |
|---|---|
| WeatherAPI.com（API Key 经 CI secret → Info.plist 注入） | 同一 API；Key 经 local.properties → BuildConfig 注入，不进仓库 |
| CLLocationManager（kCLLocationAccuracyKilometer，4 秒超时） | FusedLocationProviderClient.getCurrentLocation(PRIORITY_BALANCED_POWER_ACCURACY) + ACCESS_COARSE_LOCATION；协程 withTimeout(4000) |
| 定位失败 fallback 恩平（22.183, 112.305） | 相同 |

---

## 7. 备份分享

| iOS | Android 等价 |
|---|---|
| UIActivityViewController 分享 xiao-zhang-gui-backup.json | ACTION_SEND + FileProvider 分享；ACTION_OPEN_DOCUMENT 导入 |
| JSON formatVersion 2（epoch millis 日期，图片 base64） | 相同格式，**与 iOS 备份互读**；恢复语义追加不清空 |

---

## 8. 深链接与快捷方式

| iOS | Android 等价 |
|---|---|
| URL scheme xzg://（ai/voice/quickrecord/quick，ai?mode=voice） | AndroidManifest intent-filter（scheme="xzg"，host 匹配）|
| AppIntents ×3（新增待办/记录营业额/记记录） | App Actions（actions.xml）+ 长按图标 App Shortcuts |

---

## 9. UI/系统行为

| iOS | Android 等价 |
|---|---|
| iOS 26 下滑隐藏 tab bar | NestedScrollConnection 实现同等效果 |
| .persistentSystemOverlays(.hidden)（收款码全屏） | WindowInsetsController.hide(systemBars) + 沉浸式 |
| SF Symbols 图标 | Material Symbols / 自绘 Vector Drawable（逐图标对照，保证语义一致）|
| SF Rounded 数字字体 | 等宽数字（tabular figures）；Android 用 fontFeatureSettings="tnum" 或等宽字体 |
| Haptic 反馈 | View.performHapticFeedback / Vibrator |
| Reduce Motion | Settings.Global.TRANSITION_ANIMATION_SCALE / 无障碍 reduce motion 检查降级动效 |
| 数字键盘/IME | KeyboardOptions(keyboardType=Number)；BottomSheet 随键盘上移（imePadding）|
| Predictive Back | Android 14+ predictive back gesture；Navigation Compose 支持 |

---

## 10. 数据层差异

| iOS | Android 等价 |
|---|---|
| SwiftData @Attribute(.externalStorage) | 图片存 app files dir，Room 存相对路径；事务语义与 iOS 一致（先落文件后更新引用）|
| @Model 变更通知 → @Query 自动刷新 | Room Flow → ViewModel StateFlow → Compose collectAsState |
| ISO8601 JSON（UserDefaults 快照/metadata） | kotlinx.serialization + Instant ISO-8601 |
| xzg-delivery-v1: base64 编码串（CustomerRequest.customer） | **原样保留**：Room 存同一编码串，展示层解码；不做格式迁移，保证与 iOS 备份互读 |

---

## 修订记录

- 2026-10-02：Phase 0 初版。
