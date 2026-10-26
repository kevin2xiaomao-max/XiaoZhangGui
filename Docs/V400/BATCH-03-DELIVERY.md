# 独立配送修复

用户原句「记一笔美团350，再送302两箱水」先加回归测试：旧实现2用例真实失败（3断言失败），仅生成1卡/裸房号分类worldChat。随后修复IntentRouter配送动词后房号捕获、LocalBusinessParser字段、CompositeIntentParser解析失败补齐提示；金额/钟点/电话不能作为裸房号，无地址或无商品必须补齐，不静默丢。

Delivery-green.xcresult和test.log：703单测0失败，原句真实UI（多卡→用户确认→成功印章和可展开详情）1项0失败，TEST SUCCEEDED。既有ToolExecutor、PendingActionStore、ExecutionJournal、Repository和schema未改；确认前零写入和幂等测试随全单测通过。与AI视觉分开提交。
