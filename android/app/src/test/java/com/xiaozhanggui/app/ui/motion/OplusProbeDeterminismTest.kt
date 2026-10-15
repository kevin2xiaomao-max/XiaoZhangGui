package com.xiaozhanggui.app.ui.motion

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * PoC-4 探测确定性与退化环境安全测试（v1.2.7 审计建议 PoC-4 #1）。
 *
 * 背景：`OplusTransitionProbeTest` 已覆盖各探测项的具名原因，但缺
 * "同一设备多次探测结果一致"与"探测永不阻塞启动"的契约测试。
 * `probeOplusTransitions` 是纯函数（输入全注入），以下断言：
 * - 确定性：相同 env 多次调用结果完全相等；
 * - 无隐藏状态：env A→B→A 调用序列无交叉污染；
 * - 退化环境安全：null/空 buildDisplay、空类表、空制造商、未知预测性返回、
 *   非常规窗口模式下不抛异常，且每个"不可用"结论都有具名原因
 *   （超时/异常不阻塞启动——纯函数无 IO，本测试锁定该契约）。
 *
 * 纯 JVM 测试；只加测试，不改 PoC 实现。
 */
class OplusProbeDeterminismTest {

    private fun env(
        apiLevel: Int = 35,
        manufacturer: String = "OPPO",
        buildDisplay: String? = "CPH1234_15.0.0.200(CN01)",
        classPresent: Map<String, Boolean> = OPLUS_CLASS_CANDIDATES_UNVERIFIED.associateWith { true },
        predictiveBackSystemEnabled: Boolean? = null,
        windowMode: OplusWindowMode = OplusWindowMode.NORMAL,
        hardwareAccelerated: Boolean = true,
    ) = OplusProbeEnv(
        apiLevel = apiLevel,
        manufacturer = manufacturer,
        buildDisplay = buildDisplay,
        classPresent = classPresent,
        predictiveBackSystemEnabled = predictiveBackSystemEnabled,
        windowMode = windowMode,
        hardwareAccelerated = hardwareAccelerated,
    )

    @Test
    fun `same env probed twice returns equal results`() {
        val e = env()
        val first = probeOplusTransitions(e)
        val second = probeOplusTransitions(e)
        assertEquals(first, second)
    }

    @Test
    fun `probe has no hidden state across env changes`() {
        val a = env()
        val b = env(
            apiLevel = 29,
            manufacturer = "Google",
            buildDisplay = null,
            classPresent = emptyMap(),
            windowMode = OplusWindowMode.PIP,
            hardwareAccelerated = false,
        )
        val aFirst = probeOplusTransitions(a)
        probeOplusTransitions(b) // 中间穿插完全不同的环境
        val aAgain = probeOplusTransitions(a)
        assertEquals(aFirst, aAgain)
    }

    @Test
    fun `degenerate env never throws and every item is named`() {
        val degenerate = listOf(
            env(buildDisplay = null),
            env(buildDisplay = ""),
            env(buildDisplay = "   "),
            env(manufacturer = ""),
            env(classPresent = emptyMap()),
            env(apiLevel = 0),
            env(windowMode = OplusWindowMode.FREEFORM),
            env(windowMode = OplusWindowMode.PIP),
            env(hardwareAccelerated = false),
            env(predictiveBackSystemEnabled = false),
            env(predictiveBackSystemEnabled = true),
        )
        for ((i, e) in degenerate.withIndex()) {
            val items = probeOplusTransitions(e) // 不抛异常 = 不阻塞启动
            assertTrue("env#$i returned no items", items.isNotEmpty())
            for (item in items) {
                assertTrue("env#$i item id blank", item.id.isNotBlank())
                val result = item.result
                if (result is CapabilityResult.Unsupported) {
                    assertTrue(
                        "env#$i item ${item.id} reason blank",
                        result.reason.isNotBlank(),
                    )
                }
            }
        }
    }

    @Test
    fun `probe completes promptly - pure function with no IO`() {
        // 契约：探测是纯函数，无网络/反射调用/等待，单次调用必须在
        // 可忽略时间内返回（超时不阻塞启动的结构性保证）。
        val start = System.nanoTime()
        repeat(1000) { probeOplusTransitions(env()) }
        val elapsedMs = (System.nanoTime() - start) / 1_000_000L
        assertTrue("1000 probes took ${elapsedMs}ms, expected < 1000ms", elapsedMs < 1000L)
    }
}
