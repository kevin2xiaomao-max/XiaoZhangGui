# 你的小掌柜 iOS V3.8 — 修复与封板总交接说明

生成:2026-10-24(ZCode 本地开发,Windows 环境)
交付对象:Muse AI(GitHub 集成 / Xcode 编译 / CI / 验收)

---

## 一、总览:四条独立 PR,同一稳定基线

| PR | 分支 | 本地 commit | 内容 | 交付物 |
|---|---|---|---|---|
| **A 数据正确性** | `ios/v38-pr-a-data-correctness` | `1e55406` | 收入来源归因 / Widget 月目标 / 重复保存 | **已推送 GitHub**,PR [#2](https://github.com/kevin2xiaomao-max/XiaoZhangGui/pull/2),CI run 39983395646(结果见下) |
| **B 核心交互** | `ios/v38-pr-b-core-interaction` | `0a52d99` | 日历+/两段式勾选/ghost沉降/周口径真实化/取消选中/VoiceOver/44pt/标题统一 | `XZG-PR-B-交接包.zip` |
| **C 同步性能** | `ios/v38-pr-c-sync-perf` | `9f8db38` | 快照刷新去抖合并/Intent复用Repository/容器缓存/后台兜底 | `XZG-PR-C-交接包.zip` |
| **D 质量收口** | `ios/v38-pr-d-quality-closeout` | `3351576` | 动态字体语义化/空态分tab/键盘与校验/Logger统一/死代码-836行/生产文件归位 | `XZG-PR-D-交接包.zip` |

- **基线统一**:`release/v380-rc` @ `750bad39a319dc99367fb5f97ec825c6589b63ed`(即 CI 39956185095 全绿的提交)。
- **独立无叠加**:四条 PR 互不叠加、文件零重叠(B 与 D 互不触碰对方文件;C 与 D 互不触碰对方文件),可任意顺序合并,每条独立过 CI 门禁。
- 每个 ZIP 内含:`patches/0001-*.patch`(git format-patch --binary,含全部新增文件)、`*-backup-full.diff`(备用)、`META.txt`(BASE_SHA/HEAD_SHA/分支/文件清单)、`修复说明与测试结果.md`、`Muse接手说明.md`。

## 二、Muse 的标准动作(每个 PR)

```bash
cd XiaoZhangGui
git checkout -b <分支名> 750bad39a319dc99367fb5f97ec825c6589b63ed
git am <包>/patches/0001-*.patch        # 或 git apply --binary <包>/备用diff
git push -u origin <分支名>              # ios/v38-* 前缀自动触发 CI
# CI 全绿 → 向 release/v380-rc 发 PR → 真机验收 → 合并
```

建议合并顺序 **A → B → C → D**(数据正确性优先)。合并顺序无硬依赖。

## 三、如实声明(未执行项)

以下项在 Windows 本地**无法执行**,全部未经真实运行,由 Muse 的 CI/真机补齐:
- Xcode 编译(所有 Swift 改动只经人工 + 静态自审:括号平衡/符号引用/契约测试核对)
- XCTest / UITest 真实运行(四个 PR 共新增 **48 个测试用例**,已编写未运行)
- UI 视觉验收(尤其 PR-D 动态字体需逐档位截图)
- PR-A 的 CI 结果截至交付时仍 in_progress(排队,MacRunner 紧张),Muse 接手后查看 run 39983395646 结论即可,失败则按其日志修(最常见:偶发 UI 测试,同代码重跑)

## 四、遗留问题汇总(按优先级,详见各包"修复说明")

1. C2 语音/快捷记录**结构**统一(A 已做数据口径等价;类型学合并需先给 QuickRecord 补"支出"能力,单独立项)
2. 经营页展示型金额随动 + 图表读数行随动(与 B 的文件重叠,合并后顺势做)
3. ProfileView 1274 行拆分(机械但量大,建议 CI 环境做)
4. 扫呗导入 fingerprint 谓词查重(与 C 同文件,C 合并后做)
5. 跨天 Widget 时间线策略(`.after(次日零点)` 重载,Widget 侧单独立项)
6. Release 构建剥离 Experiments(CI 现只出 Debug;需 EXCLUDED_SOURCE_FILE_NAMES 或重构 if-链,注意既有 #if 拆链编译教训)
7. V35 抽屉死代码(有测试引用,需连测试一起清)

## 五、红线遵守确认(全四 PR)

- ✅ 未动数据库 schema、未覆盖任何用户数据、未动历史统计口径
- ✅ 未合并 main;未推送任何远端分支(A 为指令变更前的既成推送,保持原状)
- ✅ 未做 UI 推倒重做;V3.8 Editorial 风格、G5 待办回执、动效 token 纪律全部保留并加强
- ✅ 未删除未完成等价迁移的能力(语音/解析/状态机均在,状态机已迁正式目录)
- ✅ 保留契约:「确认保存」文案、44pt 触点、亮度/截图断言口径、IncomeSource 三分类不扩展
