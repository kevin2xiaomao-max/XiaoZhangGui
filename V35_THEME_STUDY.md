# V3.5 Theme Foundation — Kenotex Palette Study

本轮扩展现有 V32 Theme，不创建第二套 `ThemeStore` 或 `ThemeEnvironment`。旧的 Accent rawValue 保持不变；新增 `rose` 使用独立 rawValue `rose`。Theme Lab 仅使用固定 fake data，不连接 SwiftData、正式 HomeView 或写入链路。

## 研究结论

Kenotex 的 `Theme` 将颜色按角色组织，而不是把颜色散落在组件中：背景、前景、光标、选区、边框、强调色、状态色、面板和语法角色各自有明确职责。对 XiaoZhangGui 有用的原则是：

- background / panel 形成稳定层级，普通内容保持中性实体 surface。
- accent 与 selection 需要同一色相家族的明度关系，而不是把每张卡片染成 accent。
- border 只做结构提示，使用低不透明度；不能成为主题的主视觉。
- success / warning / error 是独立语义，不因主题 accent 改写业务状态色。
- 暗色使用有色深灰和低亮度 panel，避免纯黑背景配高饱和色。

参考源码：

- `src/types/theme.rs`：角色化 `Theme` 数据结构，包括 `bg`、`fg`、`selection`、`border`、`accent`、`panel` 与状态/语法角色。
- `src/molecules/config/themes.rs`：Tokyo Night、Gruvbox、Nord、Catppuccin 等内置 palette 的组织方式。
- https://github.com/kenxcomp/kenotex-cli/blob/main/src/types/theme.rs
- https://github.com/kenxcomp/kenotex-cli/blob/main/src/molecules/config/themes.rs

没有复制 Kenotex 的 TUI / Terminal UI，也没有直接复制其原始 hex 值；本项目需要 iOS Light/Dark、Dynamic Type、业务语义和 V32 历史兼容，因此重新映射到 `Color.v32Dynamic(light:dark:)`，并保留 XiaoZhangGui 的中性 surface 与语义色边界。

## 六套 Accent 方向

| XiaoZhangGui | 研究参照 | 适配方式 |
| --- | --- | --- |
| Ocean Blue (`blue`) | Nord；Catppuccin Latte / Macchiato 的蓝色明度关系 | 保留原 `blue` rawValue，使用沉稳浅色蓝与暗色抬亮蓝；hero、chart、selection 使用同一蓝色家族的不同明度。 |
| Violet (`purple`) | Tokyo Night；Catppuccin lavender / mauve | 保留原 `purple` rawValue；降低饱和度，暗色转为紫灰 panel，不做霓虹紫。 |
| Emerald (`emerald`) | 现有 V32 Emerald | 保留原识别度与现有三项 token；补充更克制的 hero、chart、AI 角色。 |
| Warm Orange (`coral`) | Gruvbox warm orange / amber 关系 | 保留原 `coral` rawValue；从珊瑚扩展暖橙和琥珀层次，不覆盖 warning 语义色。 |
| Rose (`rose`) | Catppuccin rose / pink | 新增 rawValue；使用低刺激玫瑰与酒红阴影，避免少女粉和高饱和糖果感。 |
| Graphite (`graphite`) | Nord / Catppuccin 的中性 panel 关系 | 保留原 `graphite` rawValue；黑白灰为主，accent 只承担交互、选中和数据焦点。 |

## Token 扩展

现有 `AccentPalette.accent`、`accentSoft`、`onAccent` 保持兼容；在同一结构上增加：

- `secondaryAccent`
- `heroStart` / `heroEnd`
- `selectedTint`
- `chartAccent`
- `aiAccent`
- `subtleTint`

`success`、`warning`、`danger`、`destructive` 仍由业务语义层独立控制，没有被主题 accent 覆盖。

## Light / Dark 原则

- Light：页面背景保持 V32 的背景体系，普通卡片使用 neutral solid；主题色集中在 Hero、选中态、图标、趋势和重要控制。
- Dark：使用带色相的深灰/深色 panel，不使用纯黑加高饱和色；前景色和 chart accent 提高可读性但控制亮度。
- Liquid Glass 仍只属于控制层；Theme Lab 正文使用 solid / paper 结构。
