# 你的小掌柜 iOS 3.5.0

独立经营助手。当前开发 / 封版分支：`feature/v3.5-liquid-glass-leap`。

3.5 在既有本地经营数据与小掌柜 AI 上，统一主题化首页驾驶舱、经营快捷中心 Drawer、原生导航与六套 Accent 主题。

数据仍是本地 SwiftData，不改 Bundle ID。

## 版本

- MARKETING_VERSION：3.5.0
- CURRENT_PROJECT_VERSION：35（App + Widget 相同）
- 新用户默认主题：雾蓝（`AccentTheme.blue`）+ 暖米背景

## 小白签 IPA

GitHub Actions 产出 unsigned IPA Artifact，文件名以构建产物 Info.plist 为准，形如：

`XiaoZhangGui-3.5.0-b35-<shortsha>.ipa`

用现有「小白签」自行签名后安装到 iPhone。Widget / Live Activity / App Group 需要带正确 Team 的描述文件才能在真机验证。
