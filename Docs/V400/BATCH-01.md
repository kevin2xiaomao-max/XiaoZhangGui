# V4.0 第一批：成功印章与 VoiceOrb

## 实现

- ActionCardView：仅 executed、非预览且非预览确认显示“已记”；绿描边、greenInk 字、圆角、-8°；补充独立无障碍标识及 contain 容器。未增加数据写入。
- V400VoiceOrb：共享静态径向渐变和三同心环，监听/整理由真实阶段决定；无定时器、循环 pulse 或保存调用。
- ShortVoicePanel、VoiceView：接入装饰组件，录音/停止/取消/失败回填/确认保存原调用不变。
- ActionCard 与短语音面板出现的 V4 动效在 Reduce Motion 时直接 nil，不改全局 V32Motion。
- ThinkingIndicator 与 ai.typing 保留；不虚构三步步骤、历史匹配和耗时。真实状态观察事件方案见 IMPLEMENTATION-MATRIX。

## 真实验证

1. 初版 App/Widget 模拟器 Debug build：BUILD SUCCEEDED。
2. 初版全单测：701 executed / 0 failed / 0 skipped，TEST SUCCEEDED。
3. 首轮 Light UI：29 executed / 2 skipped / 1 failed。失败为新增印章查找断言；测试存储证实两卡均真实 executed。确认新增汇总消息滚动到末尾会使卡头离开视口；修订测试返回卡片，并补卡片无障碍 contain。失败记录保留，没有删除或弱化成功印章断言。
4. 修订版 Retry-20261026-230948：TEST SUCCEEDED；xcresult 与日志均确认 14 unit / 0 failed / 0 skipped；11 UI / 0 failed / 2 skipped，即 9 UI 实际通过。包含 Light/Dark 印章、Light/Dark 独立语音页、全局搜索、晨报、费用设置、思考指示空闲与本地查询结束。
5. screenshots manifest 对应截图已导出，人工模型视觉核查：Light/Dark 印章真实可见、金额衬线可读；独立语音页 Light/Dark 有渐变圆与同心环。尚不能用这两张独立语音页截图证明短语音实际录音、权限与失败回填全部验收。
6. 本机测试模拟器：iPhone 18 Pro / 75999ABA-CEF8-48AF-8C6A-A478BBF21221。结果收集阶段约 10 分钟，不等同断言执行耗时。
7. 既有5000条性能测试在初版全单测真实执行：5000 Performance + 5×500 其他；搜索0.153s，经营聚合0.072s，grounding0.269s。仅属当前模拟器中间批证据，最终版本仍需重测。

## NOT RUN 与差异

- slow_server.py 未找回，慢请求成功/失败两个 UI 用例跳过，记 NOT RUN，不计通过。
- 真机录音/识别/VoiceOver、系统 Reduce Motion 实际操作、极端 Dynamic Type、Widget 真机均未验收。
- 暂保留纸面 Dark #2C2C2E；原型 Dark #131815 比较和完成卡折叠仍待下一视觉批，不把整步3标完成。
- 静态 VoiceOrb 无模拟音量或虚构识别状态。
- 第3步未收口前不开始配送逻辑修复；独立业务修复和逐次外发确认差异均在继承审计中保留。
- 本次未 Push/Merge/Release，App/Widget 仍3.9.3(42)，最终验收才升版。

## 实时预览

serve-sim 0.1.48 已在用户终端启动，固定上述 UDID，地址 http://localhost:3200；终端退出会按该 UDID 清理 helper。
2026-10-26 23:23 尝试用 Codex 内置浏览器打开时，Browser Use 返回用户拒绝访问的安全策略错误。尚未通过浏览器画面验证流与交互，不能报告“实时预览已打开”。等待用户重新允许；不换地址/浏览器规避拒绝。
