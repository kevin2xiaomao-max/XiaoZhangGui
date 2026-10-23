# Muse 接手说明 — PR-B 应用与验证步骤

## 1. 应用补丁(推荐:git am,保留提交信息与作者)

```bash
git clone https://github.com/kevin2xiaomao-max/XiaoZhangGui.git   # 或用现有工作副本
cd XiaoZhangGui
git checkout -b ios/v38-pr-b-core-interaction 750bad39a319dc99367fb5f97ec825c6589b63ed
git am patches/0001-*.patch
```

若 `git am` 有麻烦,用备用完整 diff:

```bash
git checkout -b ios/v38-pr-b-core-interaction 750bad39a319dc99367fb5f97ec825c6589b63ed
git apply --binary pr-b-backup-full.diff
git add -A && git commit   # 提交信息可参考 patches/0001 头部
```

## 2. 推送与 CI

```bash
git push -u origin ios/v38-pr-b-core-interaction
```

仓库工作流 `.github/workflows/ios-v38-validate.yml` 对 `ios/v38-*` 分支 **push 即自动触发**(无需手动 dispatch)。也可在 Actions 页手动 workflow_dispatch 选该分支。

## 3. 验证清单

1. CI `XZG iOS V3.8 isolated validation` 全绿(编译 + XCTest + UITest + IPA 产物)。
2. 重点看三类测试:
   - `V38CoreInteractionB1B2Tests`(本 PR 新增,15 用例)
   - `V38PerformanceRebuildTests`(已更新周期口径断言:周 4 点)
   - `V38ScheduleRebuildUITests` / `V38PerformanceChartCorrectionUITests`(见《修复说明》"需要重点回归"一节)
3. 真机验收要点(在模拟器/真机各过一遍):
   - 日历页右上「+」→ 新建待办默认带上当前选中日期(09:00)
   - 日历页勾选待办:先转圈再变完成;断网/注入失败时不变完成、alert 可重试
   - 周视图:切到"周"后约 0.5s 上方空白收起;选中日期切换不跳动
   - 经营页:周 chip 显示 4 根周汇总柱(本周/上周/前2周/前3周);点柱选中、再点同柱或点空白取消
   - VoiceOver 打开时图表可逐项朗读每日/每周金额
4. 验证通过后向 `release/v380-rc` 发起 PR(与 PR-A、C、D 互不冲突,任意顺序合并)。

## 4. 注意事项

- **不要 rebase 到 PR-A 之上**:四条 PR 同基线独立,合并时 GitHub 会自动处理(零重叠文件)。
- 若 `V38ScheduleRebuildUITests` 因 ghost 沉降后的新稳态布局而失败,属于**预期行为变更**(修复目标),按实际布局更新断言即可,不要回退沉降逻辑。
- 补丁含 LF→CRLF 转换警告属正常(Windows 导出),git am 自动处理。
