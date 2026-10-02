package com.xiaozhanggui.app.ui.screens.goods

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Inventory2
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.GoodsCategory
import com.xiaozhanggui.app.data.db.GoodsEntity
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.GoodsRepository
import com.xiaozhanggui.app.domain.Format
import com.xiaozhanggui.app.domain.GoodsState
import com.xiaozhanggui.app.domain.goodsStateOf
import com.xiaozhanggui.app.domain.isExpiringWithin
import com.xiaozhanggui.app.ui.components.PillTone
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32MetricCell
import com.xiaozhanggui.app.ui.components.V32PillBar
import com.xiaozhanggui.app.ui.components.V32SearchField
import com.xiaozhanggui.app.ui.components.V32StatusPill
import com.xiaozhanggui.app.ui.components.v32PressFeedback
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

/**
 * 商品 ViewModel。对应 iOS `GoodsView` 的 `@Query` 数据源。
 */
class GoodsViewModel(
    private val goodsRepository: GoodsRepository
) : ViewModel() {
    val goods: StateFlow<List<GoodsEntity>> =
        goodsRepository.observeAll()
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    suspend fun delete(goods: GoodsEntity) = goodsRepository.delete(goods)
}

internal fun goodsViewModelFactory(): ViewModelProvider.Factory =
    object : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            GoodsViewModel(XzgGraph.goodsRepository) as T
    }

private val FILTERS = listOf("全部") + GoodsCategory.ALL

/**
 * 商品页。对应 iOS `GoodsView`：
 * - 顶部统计卡：临期（7 天内，expiry >= now）/ 缺货（stock<=minStock）/ 总库存（max(stock,0) 求和）
 * - 搜索 + 分类 Pill（"其他" = 其他或未知分类；搜索名称大小写不敏感、条码区分大小写）
 * - 商品卡：缩略图 / 名称 + 状态胶囊 / 条码 / 库存 / 进价·售价·毛利 / 到期日 / 编辑·删除
 * - 删除无确认、失败静默（与 iOS 一致）
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoodsScreen() {
    val vm: GoodsViewModel = viewModel(factory = remember { goodsViewModelFactory() })
    val goods by vm.goods.collectAsStateWithLifecycle(initialValue = emptyList())
    val scope = rememberCoroutineScope()

    var editingGoods by remember { mutableStateOf<GoodsEntity?>(null) }
    var showNew by remember { mutableStateOf(false) }

    GoodsContent(
        goods = goods,
        onAdd = { showNew = true },
        onEdit = { editingGoods = it },
        onDelete = { item ->
            // 与 iOS 一致：删除无确认，失败静默
            scope.launch {
                try {
                    vm.delete(item)
                } catch (_: Exception) {
                    // 失败静默（与 iOS 一致）
                }
            }
        }
    )

    if (showNew) {
        GoodsEditorSheet(
            mode = GoodsEditorMode.NEW,
            onDismiss = { showNew = false }
        )
    }
    editingGoods?.let { g ->
        GoodsEditorSheet(
            mode = GoodsEditorMode.EDIT,
            goods = g,
            onDismiss = { editingGoods = null }
        )
    }
}

/**
 * 商品页纯渲染内容（Paparazzi 截图入口）。
 * 搜索 / 分类为内部状态；编辑 Sheet 保留在 [GoodsScreen]。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoodsContent(
    goods: List<GoodsEntity>,
    onAdd: () -> Unit = {},
    onEdit: (GoodsEntity) -> Unit = {},
    onDelete: (GoodsEntity) -> Unit = {}
) {
    val palettes = LocalXzgPalettes.current
    var searchText by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("全部") }

    val now = System.currentTimeMillis()
    val filtered = remember(goods, searchText, category) {
        val keyword = searchText.trim()
        goods.filter { item ->
            val matchesCategory = category == "全部" ||
                    item.category == category ||
                    (category == "其他" && !GoodsCategory.ALL.contains(item.category))
            val matchesQuery = keyword.isEmpty() ||
                    item.name.contains(keyword, ignoreCase = true) ||
                    (item.barcode.isNotEmpty() && item.barcode.contains(keyword))
            matchesCategory && matchesQuery
        }.sortedByDescending { it.createdAt }
    }
    val expiringCount = remember(goods, now) {
        goods.count { isExpiringWithin(it, now) }
    }
    val lowStockCount = remember(goods) { goods.count { it.stock <= it.minStock } }
    val totalStock = remember(goods) { goods.sumOf { maxOf(it.stock, 0) } }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("商品", style = XzgType.headline, color = palettes.background.textPrimary) },
                actions = {
                    IconButton(onClick = onAdd) {
                        Icon(
                            imageVector = Icons.Filled.Add,
                            contentDescription = "新增商品",
                            tint = palettes.background.textPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = palettes.background.pageBG
                )
            )
        },
        containerColor = palettes.background.pageBG
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .padding(innerPadding)
                .padding(horizontal = XzgDimens.pageMargin)
                .padding(top = 16.dp, bottom = XzgDimens.bottomPad),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 统计卡
            V32Card {
                Row(modifier = Modifier.fillMaxWidth()) {
                    V32MetricCell(
                        label = "临期",
                        value = "$expiringCount",
                        sub = "7 天内到期",
                        modifier = Modifier.weight(1f)
                    )
                    V32MetricCell(
                        label = "缺货",
                        value = "$lowStockCount",
                        sub = "低于安全库存",
                        modifier = Modifier.weight(1f)
                    )
                    V32MetricCell(
                        label = "总库存",
                        value = "$totalStock",
                        sub = "件",
                        modifier = Modifier.weight(1f)
                    )
                }
            }

            V32SearchField(
                value = searchText,
                onValueChange = { searchText = it },
                placeholder = "搜索商品名称 / 条码"
            )
            V32PillBar(
                options = FILTERS,
                selectedIndex = FILTERS.indexOf(category).takeIf { it >= 0 } ?: 0,
                onSelect = { category = FILTERS[it] }
            )

            if (filtered.isEmpty()) {
                V32Card {
                    V32EmptyState(
                        icon = Icons.Filled.Inventory2,
                        title = "还没有商品",
                        actionText = "新增商品",
                        onAction = onAdd
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    items(filtered, key = { it.id }) { item ->
                        GoodsCard(
                            goods = item,
                            now = now,
                            onEdit = { onEdit(item) },
                            onDelete = { onDelete(item) }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun GoodsCard(
    goods: GoodsEntity,
    now: Long,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val state = remember(goods, now) { goodsStateOf(goods, now) }
    V32Card {
        Column(
            modifier = Modifier.v32PressFeedback(onClick = onEdit),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(verticalAlignment = Alignment.Top) {
                GoodsThumb(imagePath = goods.imagePath)
                Spacer(Modifier.width(12.dp))
                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = goods.name,
                            style = XzgType.title,
                            color = palettes.background.textPrimary,
                            maxLines = 1,
                            modifier = Modifier.weight(1f)
                        )
                        Spacer(Modifier.width(6.dp))
                        V32StatusPill(
                            text = state.label,
                            tone = if (state == GoodsState.NORMAL) PillTone.DONE else PillTone.EXPIRY
                        )
                    }
                    if (goods.barcode.isNotEmpty()) {
                        Text(
                            text = "码 ${goods.barcode}",
                            style = XzgType.caption,
                            color = palettes.background.textQuaternary,
                            maxLines = 1
                        )
                    }
                    Text(
                        text = "库存 ${goods.stock} · 最低 ${goods.minStock}",
                        style = XzgType.caption,
                        color = palettes.background.textSecondary,
                        maxLines = 1
                    )
                }
            }

            HorizontalDivider(color = palettes.background.divider)

            Text(
                text = "进价 ${Format.money(goods.purchasePrice)} · 售价 ${Format.money(goods.salePrice)} · 毛利 ${
                    Format.money(
                        goods.salePrice - goods.purchasePrice
                    )
                }",
                style = XzgType.caption,
                color = palettes.background.textTertiary,
                maxLines = 1
            )

            goods.expiryDate?.let { expiry ->
                Text(
                    text = "到期 ${Format.formatDate(expiry)}",
                    style = XzgType.caption,
                    color = when (state) {
                        GoodsState.EXPIRED -> palettes.fixed.danger
                        GoodsState.EXPIRING_SOON, GoodsState.LOW_STOCK -> palettes.fixed.amber
                        GoodsState.NORMAL -> palettes.accent.accent
                    },
                    maxLines = 1
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.End)
            ) {
                IconButton(
                    onClick = onEdit,
                    modifier = Modifier
                        .size(30.dp)
                        .background(palettes.accent.accentSoft, CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Edit,
                        contentDescription = "编辑商品",
                        tint = palettes.accent.accent,
                        modifier = Modifier.size(12.dp)
                    )
                }
                IconButton(
                    onClick = onDelete,
                    modifier = Modifier
                        .size(30.dp)
                        .background(palettes.background.pageBGSecondary, CircleShape)
                ) {
                    Icon(
                        imageVector = Icons.Filled.Delete,
                        contentDescription = "删除商品",
                        tint = palettes.background.textQuaternary,
                        modifier = Modifier.size(12.dp)
                    )
                }
            }
        }
    }
}

/** 商品缩略图：BitmapFactory 按需降采样解码；无图时中性占位。 */
@Composable
private fun GoodsThumb(imagePath: String?) {
    val palettes = LocalXzgPalettes.current
    val bitmap = remember(imagePath) {
        imagePath?.takeIf { it.isNotBlank() }?.let { decodeThumb(it) }
    }
    Box(
        modifier = Modifier
            .size(56.dp)
            .clip(RoundedCornerShape(12.dp))
            .background(palettes.background.pageBGSecondary),
        contentAlignment = Alignment.Center
    ) {
        if (bitmap != null) {
            Image(
                bitmap = bitmap,
                contentDescription = null,
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop
            )
        } else {
            Icon(
                imageVector = Icons.Filled.Inventory2,
                contentDescription = null,
                tint = palettes.background.textQuaternary,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

/** 降采样解码到 ~112px，避免大图 OOM。 */
private fun decodeThumb(path: String) = try {
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeFile(path, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) {
        null
    } else {
        var sample = 1
        while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= 112) sample *= 2
        BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
            ?.asImageBitmap()
    }
} catch (_: Exception) {
    null
}
