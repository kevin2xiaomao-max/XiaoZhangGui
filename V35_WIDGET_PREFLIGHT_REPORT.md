# V3.5 Widget Preflight Report

日期：2026-09-20  
分支：`feature/v3.5-liquid-glass-leap`  
审计基线：`38525002f97ab062659dc8920b373cece7a8b797`

## 结论

源码侧 App Group 配置一致，但当前没有可供本地解包检查的已签名真机 IPA，因此无法证明重签后的最终 App / Widget entitlement 仍然保留 App Group。

结合真机现象：Small 显示“轻点同步今日经营”，Medium 显示 ¥0 和“打开 App 同步数据”，可以确定 Widget 当前拿到的是 `BusinessSnapshot == nil`，不是“真实营业额为 0”的正常快照。

当前 Widget P5 结论：**NO-GO，先完成正式签名能力核验和真机同步链验收。**

## 1. App Group 配置审计

统一标识：

```text
group.com.xiaozhanggui.ios.shared
```

源码常量：`SharedKernel/AppGroup.swift` 的 `XZGShared.appGroupID`。

源码 entitlement：

- `XiaoZhangGui/XiaoZhangGui.entitlements`：包含该 App Group。
- `XiaoZhangGuiWidget/XiaoZhangGuiWidgetExtension.entitlements`：包含同一 App Group。

Bundle ID：

- App：`com.xiaozhanggui.ios`
- Widget：`com.xiaozhanggui.ios.widget`

`project.yml` 也分别为 App 和 Widget 指定了上述 entitlement 文件。源码配置没有发现 ID 不一致。

## 2. 为什么当前是 snapshot nil

Widget 数据源唯一读取路径是：

```text
BusinessSnapshot.load()
→ XZGShared.sharedDefaults
→ UserDefaults(suiteName: "group.com.xiaozhanggui.ios.shared")
```

当 App Group entitlement 在最终签名中缺失或不可访问时，`UserDefaults(suiteName:)` 无法访问共享 suite，`BusinessSnapshot.load()` 返回 `nil`。

Widget UI 对 nil 的明确分支正好对应真机现象：

- Small：`轻点同步今日经营`
- Medium：`snapshot == nil ? "打开 App 同步数据" : "现在没有要紧事"`
- Medium 金额在 nil 时显示默认 `0`

因此该现象不是普通的“今日营业额为 0”。

## 3. 主 App 同步链

正常链路为：

```text
SwiftData fetch
→ SnapshotSyncManager.buildSnapshot
→ BusinessSnapshot.save()
→ App Group UserDefaults
→ WidgetCenter.reloadAllTimelines()
```

已审计调用点：

- App 启动 `.task`：构建并保存快照，reload Widget timelines。
- `scenePhase == .active / .background`：再次构建并保存快照，reload Widget timelines。
- `SnapshotSyncManager.refreshAll(context:)`：统一提交快照并 reload。
- `AppRepository` 多个写入路径：写入后调用 `refreshAll`。
- App Intent 写入：保存后调用 `SnapshotSyncManager.refreshAll`。
- Widget `CompleteTodoIntent`：共享容器写入后保存快照并 reload。

`commit(snapshot: nil)` 会保留旧快照，不会用空快照覆盖已有数据；这是安全行为，但无法在 App Group 不可用时产生 Widget 可见数据。

## 4. 主 App 是否回退到 sandbox

是。`AppDatabase.makeContainer()` 的行为是：

1. `FileManager.containerURL(forSecurityApplicationGroupIdentifier:)` 成功：使用 App Group SwiftData store。
2. App Group URL 不可用或共享 store 打开失败：记录 `DatabaseHealth`，回退到 App sandbox 的 `default.store`。
3. 两者都失败：显式显示“数据存储暂不可用”。

这意味着重签包丢失 App Group 时可能出现：

- 主 App 仍能正常记录和读取自己的 sandbox 数据。
- Widget 读取的是 App Group，因而看不到主 App 的 sandbox 数据。
- 主 App 的 `BusinessSnapshot.save()` 也无法写入 Widget 所需的共享 suite。
- Widget 继续显示 `snapshot == nil`。

这是数据隔离下的安全回退，不是数据同步成功。

## 5. Widget 点击链

### `xzg://ai`

`SharedKernel/WidgetFocusItem.swift` 定义 `xzg://ai`；Widget 使用 `OpenURLIntent`。主 App `RootView.onOpenURL` 交给 `AppDeepLink.route`，切换到 assistant Tab。

源码链路完整，真机能否打开取决于 App 的 URL scheme 是否在最终包中保留；`project.yml` 声明了 `xzg` scheme。

### `xzg://voice`

同样由 Widget `OpenURLIntent` 触发，主 App 解析为 `.voice` 并展示 Voice sheet。RootView 已使用系统 sheet、detent 和 drag indicator。

源码链路完整，仍需真机点击确认最终包的 URL scheme 与系统打开行为。

### Interactive Todo

`CompleteTodoIntent` 在 Widget Extension 中：

1. 调用 `AppDatabase.sharedStoreURL()`。
2. App Group 不可用时直接抛出 `sharedStoreUnavailable`。
3. App Group 可用时打开共享 SwiftData store。
4. 完成 Todo、保存快照、reload timelines。

因此它不会静默写错到 Widget 私有数据；但在重签丢 capability 时会明确失败，不能完成真机勾选。

## 6. 正式签名与重签限制

### A. 正常 Apple provisioning

正式实现要求：

- App ID 与 Widget App ID 都启用 App Groups capability。
- Provisioning profile 同时包含 `group.com.xiaozhanggui.ios.shared`。
- 最终签名后的 App 和 `.appex` entitlement 都包含同一 group。
- App Group container 可由 App 和 Widget 访问。

满足后，App sandbox 与 Widget 共享 store / UserDefaults，快照和 Interactive Todo 链路成立。

### B. 当前重签 IPA

当前没有可核验的最终签名 IPA entitlement，因此不能把源码 entitlement 当作重签结果。

若重签工具移除了 App Group capability，结论必须标记为：

**Signing limitation / App Group unavailable**

此时：

- 主 App 可安全回退到 sandbox store。
- Widget 无法读取主 App 数据。
- Widget snapshot 会是 nil。
- Interactive Todo 会显式失败。
- `xzg://ai` / `xzg://voice` 仍可能工作，因为它们依赖 URL scheme，不依赖 App Group；但必须真机验证最终包。

### C. 安全 fallback

当前已有安全 fallback：主 App 回退到自己的持久 sandbox store，避免把数据写入不稳定的内存库；Widget 不伪造数据、不把 nil 当成 0 数据写回。

不建议用普通 shared sandbox、剪贴板、URL 参数或网络服务替代 App Group，这些都会破坏数据隔离或引入新的泄露/一致性风险。

## 7. P5 前必须完成的真机验证

使用正式 Apple provisioning 的构建包，在 App 和 Widget 安装完成后：

1. 读取最终签名 entitlement，确认 App 与 Widget 都含 `com.apple.security.application-groups` 和目标 group。
2. App 启动后确认 Widget 从 nil 变为真实快照。
3. 新增一笔营业额，回到桌面确认金额和时间刷新。
4. 新增/完成待办，确认 Widget focus item 更新。
5. 点击 Small 的 `xzg://ai`，确认进入小掌柜 Tab。
6. 点击 Small 的 `xzg://voice`，确认打开语音 sheet。
7. 点击 Medium Todo 圆圈，确认 Interactive Todo 完成并刷新 Widget。
8. 若任一步骤失败，记录 `DatabaseHealth.usedLocalFallback`、App Group URL 是否为 nil，以及 Widget 日志中的 `BusinessSnapshot.load()` 结果。

在上述验证完成前，不进入 P5 Widget 视觉改造。
