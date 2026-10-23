# Muse 接手说明 — PR-D 应用与验证步骤

## 1. 应用补丁(推荐:git am)

```bash
cd XiaoZhangGui
git checkout -b ios/v38-pr-d-quality-closeout 750bad39a319dc99367fb5f97ec825c6589b63ed
git am patches/0001-*.patch
```

备用:`git apply --binary pr-d-backup-full.diff` 后手动 commit。
补丁含**文件删除与重命名**(6 删 1 移),git am 可完整还原;若用备用 diff,确认 `git status` 中出现 6 个 D 与 1 个 R。

## 2. 推送与 CI

```bash
git push -u origin ios/v38-pr-d-quality-closeout
```

`ios-v38-validate.yml` 对 `ios/v38-*` push 自动触发(编译会立刻验证死代码删除与迁移是否有漏引用——这是本 PR 最需要机器验证的点)。

## 3. 验证清单

1. CI 全绿(重点:编译期验证 6 个删除文件确无引用、V38PageMotionState 迁移后 TodoView/ScheduleView 正常链接)。
2. 新增测试:`V38QualityCloseoutTests`(10 用例)。
3. **动态字体验收(C3 的必要环节,CI 覆盖不了视觉)**:
   - 模拟器 Settings → Accessibility → Display & Text Size 逐档放大(xL/XXL/AX3):
     首页/待办/经营/日历页文字应同步放大,标题与正文层级保持;
   - 首页 Hero 金额与日期大数字应随档位放大且不截断(minimumScaleFactor 兜底);
   - 日历格与图表读数行保持固定(设计决定),确认无溢出即可。
4. 记一笔收入:输入 "0"/"abc" 出现红色行内提示;键盘栏「完成」可收起;滚动表单键盘跟随收起。

## 4. 合并顺序与依赖

- **A/B/C/D 四条 PR 同基线独立,任意顺序合并**;唯一已知交叉:C 与本 PR 都不触碰对方文件(已核对),无冲突预期。
- 建议合并顺序仍按 A → B → C → D(数据正确性优先),每条合并后跑一次 RC 门禁。

## 5. 注意事项

- **不要把 FloatingDock.swift 当死代码删**:它定义了全项目在用的 `Haptic`/`AppTab`(文件名是历史遗留)。
- 死代码删除若在编译期爆出漏网引用(我的核查是 grep 级,非编译级):优先恢复该文件而不是改调用点,然后告诉我补进删除清单或移出。
- 本 PR 删除行数多(-836),review 时重点看 META.txt 的文件清单与提交信息一一对应。
