# V3.7.1 UI/UX 审计报告（夜间模式 Phase 3）

基线：db6d99e | 分支：codex/v371-phase0-protection
设计目标：Editorial Content + Soft Frosted Controls + Apple Native Interaction

## 设计系统现状（V371）

**已有基础**（V371DesignSystem.swift, V371Primitives.swift）：
- S0-S3 Surface 分级（Canvas/Group/Hero/Floating）
- 语义化 Colors/Radius/Space/Typography
- 明确禁止：内容区 material、Card Wall
- WorkRow、SectionHeader、GroupSurface 等基础组件

**待统一**：
- Typography 层级需审查（heroNumber 44pt 是否过大）
- Spacing 在窄屏的适配
- Empty State、状态反馈、Motion 尚未统一

## 页面审计

### 首页（HomeView）
- [ ] 检查 Hero 营业额模块的视觉层次
- [ ] 检查快捷入口的布局密度
- [ ] 检查"接下来"部分的拥挤度

### 待办（TodoView）
- [ ] 检查行布局（toggle/delete 按钮间距）
- [ ] 检查优先级色的使用是否克制

### 日历（Calendar）
- [ ] 检查 masthead 与内容的层次
- [ ] 检查窄屏适配

### 经营（Business）
- [ ] 检查 11 个业务页的入口布局
- [ ] 检查数据密度

### 底部控制层（FloatingTabDock）
- [ ] **已知问题**：遮挡页面底部操作区域（收款码测试证实 tap 误触）
- [ ] 需确保所有页面的底部内容不被遮挡
- [ ] 考虑 safeArea 处理

### 其他页面
- [ ] 我的（Profile）：收款码入口、语音设置
- [ ] 商品（Goods）：列表密度、删除按钮
- [ ] 临期（Expiry）：状态 badge、退货按钮
- [ ] 客户配送（Customer）：分组 section、推进按钮
- [ ] 营业报告（DailyReport）：数据展示
- [ ] 收款码（PaymentCode）：二维码展示、空状态

## 导航审计
- [ ] HomeView → ProfileView → PaymentCodeView 链路（已发现 tap 误触问题）
- [ ] 检查所有 navigationDestination 是否在正确的 NavigationStack 层级
- [ ] 检查 sheet 与 push 的使用是否一致

## 无障碍审计
- [ ] AIChatView 容器 identifier 覆盖（已修复）
- [ ] PaymentCodeView/ProfileView 容器 identifier（已加 contain）
- [ ] 检查其他页面的容器 identifier

## 下一步
按批次推进，每批次独立提交。
