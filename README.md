# 你的小掌柜 iOS 3.0.1

独立经营助手。本次在 1.1 功能上新增：

- 扫呗 CSV / Excel 导入（防重复 fingerprint）
- 业绩日/周/月趋势（Swift Charts）
- 快速记录（本地规则写入现有模块）
- 今日汇总与经营日报

数据仍是本地 SwiftData，不改 Bundle ID / Signing。

开发分支：`ios-dev`

## 小白签 IPA

GitHub Actions 产出 unsigned IPA Artifact：

- Artifact：`XiaoZhangGui-3.0.1-Demo-IPA`
- 文件：`XiaoZhangGui-3.0.1-Demo.ipa`
- Payload：`你的小掌柜.app`

用现有「小白签」自行签名后安装到 iPhone。

## 3.0.1 UI

- 系统 TabView + iOS 27 Prominent 语音入口，内容层白底，玻璃只给控件
- 首页：问候、今日营业额短卡、三计数、「需要你处理」
- 待办按上午 / 下午 / 晚上分组，左勾选、右时间
- 演示数据走独立内存容器，关闭后回到真实 SwiftData
