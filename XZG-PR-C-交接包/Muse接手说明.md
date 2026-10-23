# Muse 接手说明 — PR-C 应用与验证步骤

## 1. 应用补丁(推荐:git am)

```bash
cd XiaoZhangGui   # 你的工作副本
git checkout -b ios/v38-pr-c-sync-perf 750bad39a319dc99367fb5f97ec825c6589b63ed
git am patches/0001-*.patch
```

备用(完整 diff):

```bash
git checkout -b ios/v38-pr-c-sync-perf 750bad39a319dc99367fb5f97ec825c6589b63ed
git apply --binary pr-c-backup-full.diff
git add -A && git commit
```

## 2. 推送与 CI

```bash
git push -u origin ios/v38-pr-c-sync-perf
```

`ios-v38-validate.yml` 对 `ios/v38-*` 分支 push 自动触发。

## 3. 验证清单

1. CI 全绿;重点新增测试:`SnapshotRefreshDebouncerTests`(9 用例,真实异步计时,约 1.5s)。
2. 真机/模拟器验收要点:
   - **连续快速记账 3-5 笔**(快捷记录/语音):Widget 不应闪烁刷新多次(可看 WidgetCenter reload 日志),但**最后一笔必须反映**(等 ~1s 后看小组件或下拉今天视图)
   - 记一笔账后**立刻切后台**:切回来看 Widget,数据必须已同步(scenePhase 兜底)
   - Siri 说"在小掌柜新增待办 进货":待办出现、通知正常、Widget 待办数更新
   - 扫呗批量导入:导入完成弹结果的同时 Widget 立即更新(保留的立即刷新路径)
3. 性能对比(可选):Instruments 看 WidgetCenter reload 次数,连续 5 笔写入应从 5 次降为 1 次。

## 4. 注意事项

- 本 PR 与 PR-A/B/D 同基线独立,零文件重叠,任意顺序合并无冲突。
- 若想让 PR-A 的 GoalEditSheet 也走去抖(可选优化):`SnapshotSyncManager.refreshAll(context:)` → `scheduleDebouncedRefresh(context:)` 即可;当前立即刷新也是正确语义(目标变更后用户马上看 Widget)。
- 测试如遇间歇性失败:`testRapidSchedulesCoalesceToSingleTrailingExecution` 依赖真实计时,CI 高负载时 350ms 余量可能偏紧,可放宽到 500ms(改测试,不改实现)。
