package com.xiaozhanggui.app.ui.components

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.MotionSpec
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.TransitionKind

/**
 * V3.8 Phase 1（Worker B）四路径动效的 MotionSpec 声明注册表。
 *
 * 设计依据：`docs/ANDROID_V38_DESIGN_SYSTEM.md` §2.3。
 * 声明直接使用 Worker A（`ui/motion/`）的 [MotionSpec] 数据类——
 * 不另起类型体系；解析一律走 `MotionPolicy.resolve(spec, ctx)`。
 *
 * Phase 1 四路径的硬规则（JVM 测试 `ui/components/V38MotionSpecTest` 强制）：
 * - transitionKind 一律 FADE：禁 NATIVE（OEM 转场不一致，ColorOS 撕裂）、
 *   禁 SHARED_ANCHOR（那是 Phase 2 PoC）；
 * - durationTier 只用 V371 四档（100/180/280/420），不新增数值；
 * - 页面容器 overshoot = NONE（"页面必单调"）；内容分组错峰由各 Screen
 *   后续接入，不在本文件声明；
 * - 每个 spec 必须声明 fallbackKind（降级路径）+ 独立 enabled 开关；
 *   reduce-motion 降级一律走"直接显示 / 短淡入"，具名原因 reduce-motion。
 */
object XzgMotionSpecs {
    // ---- 1. 按钮按压反馈 ----
    // 按压缩放 0.97（V371Motion.PRESS_SCALE）+ FAST 180ms；reduce-motion 时无缩放。
    val BUTTON_PRESS = MotionSpec(
        id = "v38.button.press",
        transitionKind = TransitionKind.FADE, // 即时反馈：轻微缩放+变暗，无位移/弹簧
        durationTier = DurationTier.FAST,
        overshoot = Overshoot.NONE, // 瞬时反馈不允许过冲
        interruptible = true, // 中途松开立即回弹
        fallbackKind = TransitionKind.FADE,
        description = "按钮按压反馈：按压缩放 0.97 + 变暗 0.82，FAST 180ms；reduce-motion 时无缩放",
    )

    // ---- 2. 菜单展开（FADE + 轻微位移，FAST 档） ----
    private fun menu(id: String, description: String) = MotionSpec(
        id = id,
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.FAST,
        overshoot = Overshoot.NONE,
        fallbackKind = TransitionKind.FADE,
        description = description,
    )

    val MENU_EXPAND_AI_CHAT = menu(
        "v38.menu.expand.ai-chat",
        "AI 对话页右上角「对话菜单」展开；reduce-motion 时直接显示",
    )
    val MENU_EXPAND_CUSTOMER_ROW = menu(
        "v38.menu.expand.customer-row",
        "客户行「编辑」菜单展开；reduce-motion 时直接显示",
    )
    val MENU_EXPAND_PAYMENT_CODE = menu(
        "v38.menu.expand.payment-code",
        "付款码页「更多操作」菜单展开；reduce-motion 时直接显示",
    )
    val MENU_EXPAND_RECORD = menu(
        "v38.menu.expand.record",
        "经营页「记一笔」菜单展开；reduce-motion 时直接显示",
    )
    val MENU_EXPAND_QUICK_RECORD_KIND = menu(
        "v38.menu.expand.quick-record-kind",
        "速记 Sheet「改类型」菜单展开；reduce-motion 时直接显示",
    )

    // ---- 3. 弹窗（Dialog / BottomSheet：FADE，STANDARD 档 280ms） ----
    // 实现说明：Material3 AlertDialog 的进出动画由平台窗口动画驱动，
    // Compose 动画时钟服从系统 ANIMATOR_DURATION_SCALE（=0 时瞬切），
    // 因此 reduce-motion 降级天然成立；此处声明统一口径与降级路径。
    // BottomSheet 统一走 rememberXzgModalBottomSheetState（ReduceMotion.kt，
    // Phase 3 Worker C 已接线：reduce-motion 时初始值 Expanded，直接呈现）。
    private fun dialog(id: String, description: String) = MotionSpec(
        id = id,
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.STANDARD,
        overshoot = Overshoot.NONE,
        fallbackKind = TransitionKind.FADE,
        description = description,
    )

    val DIALOG_CONFIRM_DELETE = dialog("v38.dialog.confirm-delete", "通用删除确认弹窗")
    val DIALOG_AI_CLEAR_CONVERSATION = dialog("v38.dialog.ai.clear-conversation", "AI 对话「清空当前对话」确认")
    val DIALOG_CUSTOMER_TIME_PICKER = dialog("v38.dialog.customer.time-picker", "客户编辑器时间选择器")
    val DIALOG_CUSTOMER_SAVE_ERROR = dialog("v38.dialog.customer.save-error", "客户保存失败提示")
    val DIALOG_CUSTOMER_DELETE_ERROR = dialog("v38.dialog.customer.delete-error", "客户删除失败提示")
    val DIALOG_EXPIRY_SAVE_ERROR = dialog("v38.dialog.expiry.save-error", "临期保存失败提示")
    val DIALOG_EXPIRY_DELETE_ERROR = dialog("v38.dialog.expiry.delete-error", "临期删除失败提示")
    val DIALOG_GOODS_SAVE_ERROR = dialog("v38.dialog.goods.save-error", "商品保存失败提示")
    val DIALOG_GOODS_DELETE_ERROR = dialog("v38.dialog.goods.delete-error", "商品删除失败提示")
    val DIALOG_HOME_ACTION_ERROR = dialog("v38.dialog.home.action-error", "首页操作错误提示")
    val DIALOG_MONEY_SAVE_ERROR = dialog("v38.dialog.performance.save-error", "记一笔保存失败提示")
    val DIALOG_PERFORMANCE_DELETE_ERROR = dialog("v38.dialog.performance.delete-error", "经营删除失败提示")
    val DIALOG_SCHEDULE_ERROR = dialog("v38.dialog.schedule.error", "日历页错误提示")
    val DIALOG_TODO_SAVE_FAILED = dialog("v38.dialog.todo.save-failed", "待办保存失败（重试）提示")
    val DIALOG_TODO_SCREEN_ERROR = dialog("v38.dialog.todo.screen-error", "待办页通用错误提示")
    val DIALOG_PAYMENT_CODE_FULLSCREEN = dialog("v38.dialog.payment-code.fullscreen", "付款码全屏 Dialog（平台 Dialog，不走包装）")

    // ---- 4. 页面切换（Tab / NavHost：FADE，页面容器单调 tween 无过冲） ----
    // "内容可过冲、页面必单调"：容器 overshoot=NONE；内容分组错峰淡入由各
    // Screen 后续接入（Worker C/D 范围），此处只声明容器级 spec。
    val NAV_PAGE_FADE = MotionSpec(
        id = "v38.nav.page-fade",
        transitionKind = TransitionKind.FADE,
        durationTier = DurationTier.FAST, // 180ms 单调 tween
        overshoot = Overshoot.NONE, // 页面容器必单调，禁过冲
        interruptible = true, // 快速切 Tab 中途反转保持速度续播
        fallbackKind = TransitionKind.FADE,
        description = "Tab 切换 / NavHost 页面导航：FADE 单调 tween 180ms；reduce-motion 时直接显示",
    )

    /** 全部声明，供测试枚举校验（id 唯一、档位合法、kind 合规）。 */
    val all: List<MotionSpec> = listOf(
        BUTTON_PRESS,
        MENU_EXPAND_AI_CHAT,
        MENU_EXPAND_CUSTOMER_ROW,
        MENU_EXPAND_PAYMENT_CODE,
        MENU_EXPAND_RECORD,
        MENU_EXPAND_QUICK_RECORD_KIND,
        DIALOG_CONFIRM_DELETE,
        DIALOG_AI_CLEAR_CONVERSATION,
        DIALOG_CUSTOMER_TIME_PICKER,
        DIALOG_CUSTOMER_SAVE_ERROR,
        DIALOG_CUSTOMER_DELETE_ERROR,
        DIALOG_EXPIRY_SAVE_ERROR,
        DIALOG_EXPIRY_DELETE_ERROR,
        DIALOG_GOODS_SAVE_ERROR,
        DIALOG_GOODS_DELETE_ERROR,
        DIALOG_HOME_ACTION_ERROR,
        DIALOG_MONEY_SAVE_ERROR,
        DIALOG_PERFORMANCE_DELETE_ERROR,
        DIALOG_SCHEDULE_ERROR,
        DIALOG_TODO_SAVE_FAILED,
        DIALOG_TODO_SCREEN_ERROR,
        DIALOG_PAYMENT_CODE_FULLSCREEN,
        NAV_PAGE_FADE,
    )
}
