package com.xiaozhanggui.app.ui.poc.prep

/**
 * 玻璃材质声明（Design System §2.1 材质声明格式的草案载体）。
 *
 * 规则（§2.1）：
 * - 每个玻璃表面声明「采样来源（具名背景域，非自采样）+ 角色（背景/分组/浮层/决策）+
 *   显式降级链」；
 * - 三档：T1 质感 / T2 性能 / T3 超级性能（无模糊）；
 * - 对比度守恒：T1→T2→T3 降级时底色不透明度单调递增，文字对比度落在同一区间；
 * - 几何（圆角/层级/间距）三档完全一致，模糊只是附加属性。
 *
 * 纯数据类，可 JVM 单测；不含任何 Compose/Android 引用。
 */
data class PrepGlassMaterial(
    val tier: Tier,
    val backdropDomain: String,
    val role: String,
    val fallbackChain: String,
    val description: String = "",
) {
    enum class Tier {
        /** T1 质感：背景静止时预构建一次模糊快照；背景动态时降 T2。 */
        T1_FIDELITY,

        /** T2 性能：低采样模糊或静态半透明+双层 hairline。 */
        T2_BALANCED,

        /** T3 超级性能：无模糊，半透明底色（不透明度按对比度守恒提高）+ hairline。 */
        T3_ESSENTIAL,
    }

    init {
        require(role in setOf("background", "group", "floating-sheet", "decision")) {
            "glass role must be one of background/group/floating-sheet/decision: $role"
        }
        require(!backdropDomain.contains("self", ignoreCase = true)) {
            "backdrop domain must not be self-sampling: $backdropDomain"
        }
    }
}
