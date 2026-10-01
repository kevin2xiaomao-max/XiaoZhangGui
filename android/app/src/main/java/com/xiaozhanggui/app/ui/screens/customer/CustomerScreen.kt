package com.xiaozhanggui.app.ui.screens.customer

import android.graphics.BitmapFactory
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.DeliveryDining
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.Inventory
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import com.xiaozhanggui.app.data.db.CustomerRequestEntity
import com.xiaozhanggui.app.data.db.CustomerStatus
import com.xiaozhanggui.app.data.di.XzgGraph
import com.xiaozhanggui.app.data.repository.CustomerRepository
import com.xiaozhanggui.app.domain.CustomerDeliveryStorage
import com.xiaozhanggui.app.domain.DisplayLogic
import com.xiaozhanggui.app.ui.components.BubbleTone
import com.xiaozhanggui.app.ui.components.ConfirmDeleteDialog
import com.xiaozhanggui.app.ui.components.PillTone
import com.xiaozhanggui.app.ui.components.V32Card
import com.xiaozhanggui.app.ui.components.V32EmptyState
import com.xiaozhanggui.app.ui.components.V32IconBubble
import com.xiaozhanggui.app.ui.components.V32SegmentedPicker
import com.xiaozhanggui.app.ui.components.V32StatusPill
import com.xiaozhanggui.app.ui.theme.LocalXzgPalettes
import com.xiaozhanggui.app.ui.theme.XzgDimens
import com.xiaozhanggui.app.ui.theme.XzgType
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

/**
 * 客户配送页。对应 iOS Customer/CustomerView.swift。
 *
 * - 筛选：全部 / 待处理 / 配送中 / 已完成，过滤后按 createdAt 倒序
 * - 行：状态图标泡 + 标题区（点行编辑、长按菜单）+ 44dp 缩略图 + 状态胶囊 + 行内推进圆按钮
 * - 横滑：pending 左滑露出「开始配送」，delivering 左滑露出「完成」；done 不可滑
 *   （与 iOS 一致：内容左移、右侧露出操作按钮；DragGesture 最小距离 14、中点吸附）
 * - 推进到已完成 → 底部胶囊「✓ 已完成配送」2 秒
 */
enum class CustomerFilter(val label: String) {
    ALL("全部"),
    PENDING("待处理"),
    DELIVERING("配送中"),
    DONE("已完成");

    val status: String?
        get() = when (this) {
            ALL -> null
            PENDING -> CustomerStatus.PENDING
            DELIVERING -> CustomerStatus.DELIVERING
            DONE -> CustomerStatus.DONE
        }
}

class CustomerViewModel(private val repo: CustomerRepository) : ViewModel() {
    val requests: StateFlow<List<CustomerRequestEntity>> =
        repo.observeAll().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    suspend fun advance(request: CustomerRequestEntity) {
        repo.advanceStatus(request)
    }

    suspend fun delete(request: CustomerRequestEntity) {
        repo.delete(request)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerScreen() {
    val vm: CustomerViewModel = viewModel(
        factory = XzgGraph.vmFactory { CustomerViewModel(XzgGraph.customerRepository) }
    )
    val requests by vm.requests.collectAsStateWithLifecycle()
    var showNewEditor by remember { mutableStateOf(false) }
    var editingRequest by remember { mutableStateOf<CustomerRequestEntity?>(null) }
    var deletingRequest by remember { mutableStateOf<CustomerRequestEntity?>(null) }
    var deleteFailed by remember { mutableStateOf(false) }
    var showDoneToast by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val clipboard = LocalClipboardManager.current

    LaunchedEffect(showDoneToast) {
        if (showDoneToast) {
            kotlinx.coroutines.delay(2000)
            showDoneToast = false
        }
    }

    CustomerContent(
        requests = requests,
        showDoneToast = showDoneToast,
        onAdd = { showNewEditor = true },
        onEdit = { editingRequest = it },
        onDelete = { deletingRequest = it },
        onAdvance = { request ->
            scope.launch {
                val willComplete = request.status == CustomerStatus.DELIVERING
                runCatching { vm.advance(request) }
                if (willComplete) showDoneToast = true
            }
        },
        onCopyAddress = { request ->
            val address = request.roomOrAddress.trim()
            if (address.isNotEmpty()) {
                clipboard.setText(AnnotatedString(address))
            }
        }
    )

    if (showNewEditor) {
        CustomerEditorSheet(request = null, onDismiss = { showNewEditor = false })
    }
    editingRequest?.let { req ->
        CustomerEditorSheet(request = req, onDismiss = { editingRequest = null })
    }
    if (deletingRequest != null) {
        ConfirmDeleteDialog(
            title = "删除这条客户需求？",
            onConfirm = {
                val target = deletingRequest
                deletingRequest = null
                if (target != null) {
                    scope.launch {
                        runCatching { vm.delete(target) }
                            .onFailure { deleteFailed = true }
                    }
                }
            },
            onDismiss = { deletingRequest = null }
        )
    }
    if (deleteFailed) {
        AlertDialog(
            onDismissRequest = { deleteFailed = false },
            title = { Text(text = "删除失败", style = XzgType.headline) },
            text = { Text(text = "客户需求未删除，请重试。", style = XzgType.body) },
            confirmButton = {
                TextButton(onClick = { deleteFailed = false }) { Text(text = "知道了") }
            }
        )
    }
}

/**
 * 客户配送页纯渲染内容（Paparazzi 截图入口）。
 * 筛选为内部状态；编辑 Sheet / 删除确认保留在 [CustomerScreen]。
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CustomerContent(
    requests: List<CustomerRequestEntity>,
    showDoneToast: Boolean = false,
    onAdd: () -> Unit = {},
    onEdit: (CustomerRequestEntity) -> Unit = {},
    onDelete: (CustomerRequestEntity) -> Unit = {},
    onAdvance: (CustomerRequestEntity) -> Unit = {},
    onCopyAddress: (CustomerRequestEntity) -> Unit = {}
) {
    val palettes = LocalXzgPalettes.current
    var filter by remember { mutableStateOf(CustomerFilter.ALL) }

    val shown = remember(requests, filter) {
        val list = filter.status?.let { s -> requests.filter { it.status == s } } ?: requests
        list.sortedByDescending { it.createdAt }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(palettes.background.pageBG)
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            CenterAlignedTopAppBar(
                title = {
                    Text(
                        text = "客户配送",
                        style = XzgType.headline,
                        color = palettes.background.textPrimary
                    )
                },
                actions = {
                    IconButton(onClick = onAdd) {
                        Icon(
                            imageVector = Icons.Filled.Add,
                            contentDescription = "新增配送",
                            tint = palettes.background.textPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = palettes.background.pageBG
                )
            )
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = XzgDimens.pageMargin)
            ) {
                V32SegmentedPicker(
                    options = CustomerFilter.values().map { it.label },
                    selectedIndex = filter.ordinal,
                    onSelect = { filter = CustomerFilter.values()[it] },
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(18.dp))
                if (shown.isEmpty()) {
                    V32Card(modifier = Modifier.fillMaxWidth()) {
                        if (requests.isEmpty()) {
                            V32EmptyState(
                                icon = Icons.Filled.Inventory,
                                title = "暂无客户需求",
                                message = "可以先新增一条配送需求",
                                actionText = "新增配送",
                                onAction = onAdd
                            )
                        } else {
                            V32EmptyState(
                                icon = Icons.Filled.FilterList,
                                title = "当前筛选暂无结果",
                                message = "可以切换筛选查看其他需求"
                            )
                        }
                    }
                } else {
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        itemsIndexed(shown, key = { _, r -> r.id }) { index, request ->
                            if (index > 0) {
                                HorizontalDivider(
                                    color = palettes.background.divider,
                                    thickness = 1.dp,
                                    modifier = Modifier.padding(start = 48.dp)
                                )
                            }
                            CustomerSwipeRow(
                                request = request,
                                onAction = { onAdvance(request) }
                            ) {
                                CustomerRow(
                                    request = request,
                                    onEdit = { onEdit(request) },
                                    onCopyAddress = { onCopyAddress(request) },
                                    onAdvance = { onAdvance(request) },
                                    onDelete = { onDelete(request) }
                                )
                            }
                        }
                    }
                }
            }
        }

        AnimatedVisibility(
            visible = showDoneToast,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = XzgDimens.bottomPad + 12.dp),
            enter = fadeIn() + slideInVertically { it },
            exit = fadeOut()
        ) {
            Text(
                text = "✓ 已完成配送",
                style = XzgType.subhead,
                color = Color.White,
                modifier = Modifier
                    .background(palettes.fixed.hero, RoundedCornerShape(50))
                    .padding(horizontal = 16.dp, vertical = 10.dp)
            )
        }
    }
}

/** 行内状态 → 图标/气泡色/胶囊色 */
private fun customerBubbleIcon(status: String): ImageVector = when (status) {
    CustomerStatus.PENDING -> Icons.Filled.Schedule
    CustomerStatus.DELIVERING -> Icons.Filled.DeliveryDining
    else -> Icons.Filled.Check
}

private fun customerBubbleTone(status: String): BubbleTone = when (status) {
    CustomerStatus.PENDING -> BubbleTone.AMBER
    CustomerStatus.DELIVERING -> BubbleTone.BRAND
    else -> BubbleTone.NEUTRAL
}

private fun customerPillTone(status: String): PillTone = when (status) {
    CustomerStatus.PENDING -> PillTone.PENDING
    CustomerStatus.DELIVERING -> PillTone.DELIVERING
    else -> PillTone.DONE
}

/** 横滑行：pending 左滑露出「开始配送」，delivering 左滑露出「完成」；done 无手势 */
@Composable
private fun CustomerSwipeRow(
    request: CustomerRequestEntity,
    onAction: () -> Unit,
    content: @Composable () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    val density = LocalDensity.current
    val scope = rememberCoroutineScope()
    val maxSwipePx = with(density) { 76.dp.toPx() }
    val offsetX = remember(request.id) { Animatable(0f) }

    val (actionTitle, actionIcon) = when (request.status) {
        CustomerStatus.PENDING -> "开始配送" to Icons.Filled.DeliveryDining
        CustomerStatus.DELIVERING -> "完成" to Icons.Filled.Check
        else -> null to null
    }
    val swipeable = actionTitle != null && actionIcon != null

    Box(modifier = Modifier.fillMaxWidth()) {
        if (swipeable) {
            Row(
                modifier = Modifier
                    .align(Alignment.CenterEnd)
                    .fillMaxHeight()
                    .width(76.dp)
                    .background(palettes.accent.accent)
                    .clickable {
                        scope.launch {
                            offsetX.animateTo(0f)
                            onAction()
                        }
                    }
                    .padding(horizontal = 8.dp),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Icon(
                        imageVector = actionIcon!!,
                        contentDescription = null,
                        tint = palettes.accent.onAccent,
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = actionTitle!!,
                        style = XzgType.pill,
                        color = palettes.accent.onAccent
                    )
                }
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .offset { IntOffset(offsetX.value.roundToInt(), 0) }
                .background(palettes.background.card)
                .then(
                    if (swipeable) {
                        Modifier.pointerInput(request.id) {
                            detectHorizontalDragGestures(
                                onDragEnd = {
                                    scope.launch {
                                        val target =
                                            if (offsetX.value < -maxSwipePx / 2) -maxSwipePx else 0f
                                        offsetX.animateTo(target)
                                    }
                                }
                            ) { change, dragAmount ->
                                change.consume()
                                scope.launch {
                                    offsetX.snapTo(
                                        (offsetX.value + dragAmount).coerceIn(-maxSwipePx, 0f)
                                    )
                                }
                            }
                        }
                    } else Modifier
                )
        ) {
            content()
        }
    }
}

@Composable
@OptIn(ExperimentalFoundationApi::class)
private fun CustomerRow(
    request: CustomerRequestEntity,
    onEdit: () -> Unit,
    onCopyAddress: () -> Unit,
    onAdvance: () -> Unit,
    onDelete: () -> Unit
) {
    val palettes = LocalXzgPalettes.current
    var menuOpen by remember { mutableStateOf(false) }

    // 标题必须隐藏 xzg-delivery-v1 编码串；fallback = 解码出的 legacyCustomer 或「客户」
    val decoded = remember(request.customer) { CustomerDeliveryStorage.decode(request.customer) }
    val displayTitle = DisplayLogic.visible(
        request.customer,
        decoded.legacyCustomer.trim().ifEmpty { "客户" }
    )
    val displaySubtitle = listOf(
        decoded.legacyCustomer.trim(),
        request.roomOrAddress.trim()
    ).filter { it.isNotEmpty() }.joinToString(" · ")

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 10.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            V32IconBubble(
                icon = customerBubbleIcon(request.status),
                tone = customerBubbleTone(request.status),
                size = 34.dp
            )
            Spacer(modifier = Modifier.width(12.dp))
            Box(modifier = Modifier.weight(1f)) {
                Column(
                    modifier = Modifier.combinedClickable(
                        onClick = onEdit,
                        onLongClick = { menuOpen = true }
                    )
                ) {
                    Text(
                        text = displayTitle,
                        style = XzgType.title,
                        color = palettes.background.textPrimary,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis
                    )
                    if (displaySubtitle.isNotEmpty()) {
                        Spacer(modifier = Modifier.height(3.dp))
                        Text(
                            text = displaySubtitle,
                            style = XzgType.caption,
                            color = palettes.background.textTertiary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis
                        )
                    }
                }
                DropdownMenu(
                    expanded = menuOpen,
                    onDismissRequest = { menuOpen = false }
                ) {
                    DropdownMenuItem(
                        text = { Text(text = "编辑") },
                        onClick = { menuOpen = false; onEdit() }
                    )
                    if (request.roomOrAddress.isNotBlank()) {
                        DropdownMenuItem(
                            text = { Text(text = "复制地址") },
                            onClick = { menuOpen = false; onCopyAddress() }
                        )
                    }
                    DropdownMenuItem(
                        text = { Text(text = "删除", color = palettes.fixed.danger) },
                        onClick = { menuOpen = false; onDelete() }
                    )
                }
            }
            if (!request.imagePath.isNullOrBlank()) {
                Spacer(modifier = Modifier.width(12.dp))
                val context = LocalContext.current
                val absolutePath = remember(request.imagePath) {
                    java.io.File(context.filesDir, request.imagePath!!).absolutePath
                }
                ImageThumb(path = absolutePath, size = 44.dp)
            }
            Spacer(modifier = Modifier.width(12.dp))
            V32StatusPill(
                text = request.status,
                tone = customerPillTone(request.status)
            )
        }
        if (request.status != CustomerStatus.DONE) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Spacer(modifier = Modifier.width(46.dp))
                Spacer(modifier = Modifier.weight(1f))
                Box(
                    modifier = Modifier
                        .size(30.dp)
                        .clip(RoundedCornerShape(50))
                        .background(palettes.background.pageBGSecondary)
                        .clickable(onClick = onAdvance),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = if (request.status == CustomerStatus.PENDING)
                            Icons.Filled.DeliveryDining else Icons.Filled.Check,
                        contentDescription = "推进",
                        tint = palettes.accent.accent,
                        modifier = Modifier.size(14.dp)
                    )
                }
            }
        }
    }
}

/** 本地图片 44dp 缩略图（BitmapFactory 直读，无三方依赖） */
@Composable
private fun ImageThumb(path: String, size: Dp) {
    val bitmap: ImageBitmap? = remember(path) {
        runCatching { BitmapFactory.decodeFile(path)?.asImageBitmap() }.getOrNull()
    }
    if (bitmap != null) {
        Image(
            bitmap = bitmap,
            contentDescription = "配送图片",
            modifier = Modifier
                .size(size)
                .clip(RoundedCornerShape(8.dp)),
            contentScale = ContentScale.Crop
        )
    }
}
