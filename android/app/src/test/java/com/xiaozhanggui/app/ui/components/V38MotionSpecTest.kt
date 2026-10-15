package com.xiaozhanggui.app.ui.components

import com.xiaozhanggui.app.ui.motion.DurationTier
import com.xiaozhanggui.app.ui.motion.Overshoot
import com.xiaozhanggui.app.ui.motion.TransitionKind
import com.xiaozhanggui.app.ui.theme.v371.V371Motion
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Worker B 四路径 MotionSpec 声明注册表校验（[XzgMotionSpecs.all]「供测试枚举校验」）。
 *
 * 声明使用 `ui.motion` 的 MotionSpec 数据类（Worker A 基础设施），解析走
 * `MotionPolicy.resolve`；本测试只校验声明内容的硬规则。
 *
 * Phase 1 硬规则（见 `V38MotionDeclarations.kt` 文件头文档）：
 * - transitionKind 一律 FADE：禁 NATIVE（OEM 转场不一致，ColorOS 撕裂）、
 *   禁 SHARED_ANCHOR（那是 Phase 2 PoC）
 * - durationTier 只用 V371 四档（100/180/280/420），不新增数值
 * - 页面容器 overshoot = NONE（"页面必单调"）
 * - 每个 spec 必须声明 fallbackKind（降级 kind）+ 独立 enabled 开关
 * - id 唯一
 */
class V38MotionSpecTest {

    @Test
    fun `all spec ids are unique and namespaced`() {
        val ids = XzgMotionSpecs.all.map { it.id }
        assertEquals(ids.size, ids.toSet().size)
        ids.forEach { id ->
            assertTrue("id 非空", id.isNotBlank())
            assertTrue("id 命名空间 v38. [$id]", id.startsWith("v38."))
        }
    }

    @Test
    fun `phase1 four paths use fade only`() {
        XzgMotionSpecs.all.forEach { spec ->
            assertEquals(
                "Phase 1 四路径禁 NATIVE/SHARED_ANCHOR [${spec.id}]",
                TransitionKind.FADE,
                spec.transitionKind,
            )
        }
    }

    @Test
    fun `duration tiers reuse v371 values without forking`() {
        val allowed = setOf(
            V371Motion.INSTANT_MS, // 100
            V371Motion.FAST_MS, // 180
            V371Motion.STANDARD_MS, // 280
            V371Motion.EMPHASIZED_MS, // 420
        )
        XzgMotionSpecs.all.forEach { spec ->
            assertTrue(
                "时长档必须沿用 V371 四档 [${spec.id}=${spec.durationTier.ms}ms]",
                spec.durationTier.ms in allowed,
            )
        }
        // 枚举值与 V371 常量逐项对齐
        assertEquals(V371Motion.INSTANT_MS, DurationTier.INSTANT.ms)
        assertEquals(V371Motion.FAST_MS, DurationTier.FAST.ms)
        assertEquals(V371Motion.STANDARD_MS, DurationTier.STANDARD.ms)
        assertEquals(V371Motion.EMPHASIZED_MS, DurationTier.EMPHASIZED.ms)
    }

    @Test
    fun `page containers never overshoot`() {
        XzgMotionSpecs.all.forEach { spec ->
            assertEquals(
                "页面容器必单调，禁过冲 [${spec.id}]",
                Overshoot.NONE,
                spec.overshoot,
            )
        }
    }

    @Test
    fun `every spec declares a fallback kind`() {
        XzgMotionSpecs.all.forEach { spec ->
            // fallbackKind 无默认值（构造必填）是编译期强制；这里再断言降级方向合法：
            // Phase 1 的降级终点只能是 FADE（直接显示/短淡入）
            assertEquals(
                "降级 kind 必须是 FADE [${spec.id}]",
                TransitionKind.FADE,
                spec.fallbackKind,
            )
        }
    }

    @Test
    fun `every spec has an independent enabled switch defaulting to on`() {
        XzgMotionSpecs.all.forEach { spec ->
            assertTrue("独立回退开关默认开启 [${spec.id}]", spec.enabled)
        }
    }

    @Test
    fun `registry covers all four paths`() {
        val ids = XzgMotionSpecs.all.map { it.id }
        assertTrue(ids.any { it.startsWith("v38.button.") })
        assertTrue(ids.any { it.startsWith("v38.menu.") })
        assertTrue(ids.any { it.startsWith("v38.dialog.") })
        assertTrue(ids.any { it.startsWith("v38.nav.") })
        // 1 button + 5 menus + 16 dialogs + 1 nav = 23
        assertEquals(23, ids.size)
    }

    @Test
    fun `button press uses FAST tier`() {
        assertEquals(DurationTier.FAST, XzgMotionSpecs.BUTTON_PRESS.durationTier)
    }

    @Test
    fun `menus use FAST tier`() {
        XzgMotionSpecs.all
            .filter { it.id.startsWith("v38.menu.") }
            .forEach { spec ->
                assertEquals(
                    "菜单展开必须 FAST(180) [${spec.id}]",
                    DurationTier.FAST,
                    spec.durationTier,
                )
            }
    }

    @Test
    fun `dialogs use STANDARD tier`() {
        XzgMotionSpecs.all
            .filter { it.id.startsWith("v38.dialog.") }
            .forEach { spec ->
                assertEquals(
                    "弹窗必须 STANDARD(280) [${spec.id}]",
                    DurationTier.STANDARD,
                    spec.durationTier,
                )
            }
    }

    @Test
    fun `nav page fade is monotonic FADE FAST`() {
        val spec = XzgMotionSpecs.NAV_PAGE_FADE
        assertEquals(TransitionKind.FADE, spec.transitionKind)
        assertEquals(DurationTier.FAST, spec.durationTier)
        assertEquals(Overshoot.NONE, spec.overshoot)
    }
}
