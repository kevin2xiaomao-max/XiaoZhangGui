package com.xiaozhanggui.app.ui.poc.glass

/**
 * 玻璃材质档位（Design System §2.1，三档独立实现语义）。
 *
 * - [T1_FIDELITY] 质感：背景静止时预构建一次模糊快照（显隐只改 alpha，
 *   不按帧重建）；背景动态时降为 T2。
 * - [T2_BALANCED] 性能：低采样模糊（真机 RenderEffect 缩放 0.5 后 8dp blur）
 *   或静态半透明 + 双层 hairline；PoC 走后者分支（JVM 可渲染）。
 * - [T3_ESSENTIAL] 超级性能：无模糊——半透明底色（不透明度按对比度守恒提高）
 *   + hairline 描边；几何（圆角/层级/间距）与 T1/T2 完全一致。
 *
 * 档位只降不升；[T3_ESSENTIAL] 为基础档，永不降级。
 */
enum class GlassTier(val tierId: String) {
    /** T1 质感 */
    T1_FIDELITY("T1"),

    /** T2 性能 */
    T2_BALANCED("T2"),

    /** T3 超级性能（基础档） */
    T3_ESSENTIAL("T3"),
}

/**
 * 具名背景域（Design System §2.1 材质声明 `Backdrop-Domain`）。
 *
 * 玻璃表面必须声明自己采样哪个背景域；**禁自采样**——组件不得自行抓取
 * 背景内容，采样源由调用方具名传入（PoC 里为假背景域，真机由 Phase 3 接线）。
 */
@JvmInline
value class BackdropDomain(val name: String) {
    companion object {
        /** PoC 假背景域（隔离 demo 专用，不触碰任何生产页面内容） */
        val POC_DEMO_FEED = BackdropDomain("poc-demo-feed")
    }
}

/**
 * 玻璃材质声明（Design System §2.1 材质声明格式，代码化）。
 *
 * 每个玻璃表面在注释中按以下格式声明，并持有等价的声明对象：
 * ```
 * Material: Glass/T1
 * Backdrop-Domain: poc-demo-feed
 * Role: floating-sheet
 * Fallback: T2 -> T3
 * ```
 *
 * @param tier 声明档位
 * @param backdropDomain 具名背景域（禁自采样）
 * @param role 角色：背景 / 分组 / 浮层 / 决策（Design System §4 检查表）
 * @param fallback 显式降级链（单向，如 T2 -> T3）
 */
data class GlassMaterialDeclaration(
    val tier: GlassTier,
    val backdropDomain: BackdropDomain,
    val role: String,
    val fallback: List<GlassTier>,
) {
    init {
        require(fallback.zipWithNext().all { (a, b) -> a.ordinal < b.ordinal }) {
            "Fallback 必须单向降级（只降不升）：$fallback"
        }
    }

    /** 注释格式的声明文本（与设计稿口径一致） */
    fun toDeclarationComment(): String = buildString {
        appendLine("Material: Glass/${tier.tierId}")
        appendLine("Backdrop-Domain: ${backdropDomain.name}")
        appendLine("Role: $role")
        append("Fallback: ${fallback.joinToString(" -> ") { it.tierId }}")
    }
}
