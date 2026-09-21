# Product Design Stack — Phase 6.0 Visual System Audit

> Read-only audit. No Swift, tests, project files, data models, repositories, AI architecture, Home IA, Drawer IA, or App Icon were modified.

## 1. Audit basis

This review follows `PRODUCT_DESIGN_REFERENCE_PACK.md` and `PRODUCT_INTERACTION_MOTION_AUDIT.md`. Home and Drawer are treated as the visual baseline, not as redesign targets.

Verified repository patterns:

- `ThemeStore` / `AccentPalette` is the brand-color source.
- `V32Font`, `V32Layout`, `V32Radius`, `V32Motion` are existing shared tokens.
- `V32Card`, `V32HeroCard`, `V32SectionHeader`, `V32StatusPill`, `V32EmptyState`, `V32PrimaryButton`, `V32SecondaryButton` already provide reusable primitives.
- Content is generally solid/paper; Glass appears in AI control surfaces and should remain selective.
- Apple native NavigationStack, toolbar, sheet, confirmationDialog, alert, TabView and searchable patterns remain the preferred implementation level.
- Kombai references in the repository are category-level research only. Concrete Kombai entries/screenshots were not saved, so all specific Kombai visual claims remain **UNVERIFIED**.

## 2. Page-by-page audit

Format: `Current → Problem → Keep → Change → Reference → L1/L2/L3`.

### 2.1 Performance / Revenue

- Current: navigation title “经营数据”; hero money typography; metrics, source/period areas, chart/records and editor/import actions mostly wrapped in `V32Card`.
- Problem: repeated card boundaries can make a finance page read like a dashboard wall; chart, period selection and records compete with the primary amount.
- Keep: shared revenue typography, real data calculations, `chartAccent`, solid content surfaces, native toolbar Menu and Performance destination.
- Change: establish one primary revenue region, one compact period/chart region, and flatter record rows; reserve card elevation for genuinely grouped information.
- Reference: repo Home Hero; Apple Navigation/Toolbar/Chart; Kombai finance hierarchy **UNVERIFIED**.
- Level: L1 + L2.

### 2.2 Transaction History

- Current: separate native navigation destination with transaction list and date/amount/source information.
- Problem: historical rows risk inheriting overly card-like styling and may not visually distinguish income/expense hierarchy enough.
- Keep: independent history destination, date descending order, search/filter behavior, native back gesture.
- Change: use a flat solid list; make amount the primary row value, source/date secondary, and keep destructive action contextual.
- Reference: Apple List/Search/Navigation; Kombai list/table category **UNVERIFIED**.
- Level: L1 + L2.

### 2.3 Daily Report

- Current: sheet with report summary, hero money typography and grouped report content.
- Problem: a report sheet can become a second Performance dashboard if every metric gets its own card.
- Keep: sheet presentation, concise summary, real data, existing report generation.
- Change: one summary hierarchy followed by grouped facts; reduce nested cards and keep actions in toolbar or bottom action area.
- Reference: Apple Sheet/Form; repo `V32SheetChrome`/`V32Card`; Kombai finance summary **UNVERIFIED**.
- Level: L1 + L2.

### 2.4 Todo

- Current: segmented filters, statistics, grouped rows, V32 checkbox, swipe/delete, empty states and editor sheets; several sections still use `V32Card`.
- Problem: stats and list containers can over-segment a task page; status, priority and due date may compete at large Dynamic Type sizes.
- Keep: row-level completion, native swipe/delete confirmation, real toggle behavior, Today/Records distinction, V32Checkbox.
- Change: keep task rows visually dominant; make stats quieter; use one consistent row rhythm and reserve cards for actual grouped summaries.
- Reference: Apple List/Swipe/Accessibility; repo existing V32Checkbox; Kombai productivity list **UNVERIFIED**.
- Level: L1 + L2.

### 2.5 Schedule

- Current: week/date selection, selected-day content, timeline/all-day sections, expiry expansion and several V32 cards.
- Problem: date control, summary cards and event cards can create multiple competing surfaces; selected-day hierarchy should be stronger than decorative containers.
- Keep: date-to-day relationship, selectedTint strategy, native CalendarView destination, real status actions.
- Change: make the date strip and current-day heading the anchor; flatten low-density event rows and keep cards only for meaningful grouped summaries.
- Reference: Apple calendar/navigation; repo Schedule/Calendar patterns; Kombai calendar category **UNVERIFIED**.
- Level: L1 + L2.

### 2.6 Customer

- Current: filter control, empty state, a large grouped card containing swipe rows, status progression, edit/delete actions and completion toast.
- Problem: the outer card plus row separators plus status treatments can feel nested; delivery status may be visually heavier than customer/item content.
- Keep: pending → delivering → done model, V32SwipeRow, native sheet/editor, status semantics, solid surface.
- Change: reduce nested borders, keep one row surface, make customer/item primary and status secondary but explicit; preserve swipe discoverability with accessible actions.
- Reference: Apple List/Swipe/Confirmation; repo V32SwipeRow; Kombai task/order workflow **UNVERIFIED**.
- Level: L1 + L2.

### 2.7 Expiry

- Current: grouped expiry content in cards, date/status rows, expandable details, return/restore and destructive delete.
- Problem: warning color and card boundaries can over-amplify every item; returned state needs a quieter but unmistakable treatment.
- Keep: semantic amber/danger colors, date grouping, expansion, return/restore distinction, confirmation for delete.
- Change: use semantic color only for status/icon/action; keep the item surface neutral and flatten low-density groups.
- Reference: Apple semantic color/accessibility/confirmation; repo V32Status; Kombai alert/inventory category **UNVERIFIED**.
- Level: L1 + L2.

### 2.8 Goods

- Current: product list and editor-oriented content with multiple V32 cards and temporary-product terminology.
- Problem: card stacking and mixed inventory/editor density can make the page feel like a utility form rather than a browsable list.
- Keep: existing data/editor structure, native navigation and semantic empty state.
- Change: use flat product rows; reserve a grouped surface for filters or genuinely related metadata; avoid making every product a mini-card.
- Reference: Apple List/Form; repo V32Card and sheet primitives; Kombai list/forms **UNVERIFIED**.
- Level: L1 + L2.

### 2.9 Memo

- Current: search/filter plus memo content using V32Card and sometimes grid-like grouping.
- Problem: notes can inherit dashboard/card density; search result hierarchy should be stronger than decorative containers.
- Keep: search/filter, memo editor, empty vs filtered-empty distinction, solid content.
- Change: prefer a flat list for chronological reading; if grid remains for a deliberate reason, reduce card chrome and keep title/body hierarchy clear.
- Reference: Apple Search/List; repo V32SearchField; Kombai notes/list category **UNVERIFIED**.
- Level: L1 + L2.

### 2.10 AI / ActionCard

- Current: native navigation, solid chat body, selective Glass composer/thinking controls, solid ActionCard with field inset and explicit status/result.
- Problem: nested inset surfaces and control-surface Glass can become visually busy; ActionCard status must remain text-readable in all themes.
- Keep: solid chat body, confirmation gate, result/failure/retry states, selective Glass only in controls, AI accent from ThemeStore.
- Change: keep one solid ActionCard body; reduce decorative nesting; make pending/executing/saved/failed status the strongest secondary hierarchy.
- Reference: Apple native controls/Glass guidance; repo ActionCard/TypingIndicator; Kombai chat/AI category **UNVERIFIED**.
- Level: L1 + L2.

### 2.11 QuickRecord / Voice

- Current: native sheets, parsed preview, explicit confirmation, voice phase states, cards for grouped content and stable save/error language.
- Problem: multiple stacked cards can make a short capture feel like a form; waveform and phase controls must not overpower parsed content.
- Keep: Local-first parsing, Parsed → Confirm → Saving → Saved, independent Voice implementation, no automatic write.
- Change: make parsed business type/content primary; keep controls compact and lower in hierarchy; use one consistent sheet chrome.
- Reference: Apple Sheet/Form/Accessibility; repo QuickCaptureSemantic and V32Sheet; Kombai forms/voice **UNVERIFIED**.
- Level: L1 + L2.

### 2.12 Editor Sheets

- Current: Todo, Customer, Expiry, Revenue and Memo editors use native sheets, grouped V32Card fields, toolbar/save actions and failure alerts.
- Problem: repeated large rounded field groups create a strong legacy V32 form signature; too many containers reduce scan speed.
- Keep: native sheet, stable save/cancel placement, failure stays in sheet, existing repository behavior and Dynamic Type support.
- Change: use fewer grouped surfaces; group only fields with a real semantic relationship; let system Form/List rows carry simple fields.
- Reference: Apple Sheet/Form; repo existing `V32SheetChrome`; Kombai forms **UNVERIFIED**.
- Level: L1.

### 2.13 Profile / Settings

- Current: long settings surface with many V32Card groups, AppearanceSettingsView, store/data/AI/about sections and native navigation.
- Problem: repeated card groups and long section rhythm make settings feel heavier than necessary; title/section hierarchy can flatten.
- Keep: Profile as settings/identity root, Appearance selector, persistence, native navigation and no business-entry duplication.
- Change: establish a compact settings-group rhythm; use native rows for simple settings and cards only for previews or high-value grouped controls.
- Reference: Apple Settings/List/Navigation; repo AppearanceSettingsView and ThemeStore; Kenotex role-based palette study, not layout; Kombai settings **UNVERIFIED**.
- Level: L1 + L2.

### 2.14 Widget / Live Activity

- Current: glanceable solid surfaces with amount/status hierarchy, restrained accent and nil-snapshot handling; App Group/signing remains a separate verification boundary.
- Problem: shared theme data cannot be treated as proven on a resigned/unsigned device; visual accent must not imply sync success.
- Keep: BusinessSnapshot semantics, nil state distinct from ¥0, compact/minimal hierarchy, semantic status colors.
- Change: only refine typography/spacing after signed entitlement and true-device sync evidence; fallback should remain neutral/Ocean.
- Reference: Apple WidgetKit/Live Activities; repo Widget/Activity code; App Group audit limitations.
- Level: L1 + L2.

## 3. Old UI traces to watch

These are audit findings, not changes for this phase:

1. `V32Card` used as the default wrapper for nearly every section.
2. Nested card + border + inset-card combinations in Customer, Schedule, Profile and editor sheets.
3. Strong rounded-corner language repeated even when content is a simple list.
4. Form fields grouped as visual cards where native Form/List rows would scan faster.
5. Status color and surface color sometimes compete for the same attention.
6. Similar section titles can become visually repetitive when a navigation title and a page header both exist.
7. Toolbar density needs to remain contextual; no extra icon should be added merely for symmetry.
8. Chevrons should communicate navigation only; action rows without navigation should remain chevron-free.
9. Glass must remain limited to composer, toolbar/sheet controls and other control-layer surfaces.
10. Large numeric styles should remain exclusive to revenue/meaningful metrics, not ordinary counts.

## 4. Proposed Visual System tokens and rules

### Typography

| Role | Rule |
|---|---|
| Page title | `V32TextStyle.pageTitle` or native `navigationTitle`; one title source per screen |
| Section title | `V32TextStyle.section`, semibold, used to establish rhythm rather than decorate every card |
| Primary | `V32TextStyle.body/title`; highest weight belongs to the user’s main content |
| Secondary | `subhead/body` with `V32.textSecondary`; explanatory, never the only state signal |
| Caption | `caption/pill` for date, source and metadata; must remain readable under Dynamic Type |
| Numeric / Revenue | `V32Font.heroMoney` or metric tokens only for business totals and key measures; monospaced digits where alignment matters |

### Spacing

Use `V32Layout` as the source of truth: page margin, section gap, list row gap, card padding, bottom padding and tool-circle sizes. New visual work should not introduce arbitrary per-page spacing values unless a component documents why it needs an exception.

### Radius

- `V32Radius.sheet` for sheets.
- `card/cardLarge` only for meaningful grouped surfaces or Hero.
- `inset/bubble` for nested control groups and compact status surfaces.
- Plain list rows do not need a rounded container.
- Radius should describe hierarchy; it must not be applied to every text block.

### Surface

- **plain:** page background / paper content; default.
- **grouped:** a small set of related rows or fields; solid, low-contrast boundary.
- **elevated:** Drawer and a deliberately raised surface; solid and opaque under Reduce Transparency.
- **glass:** toolbar, composer, sheet control area, menu/popover and selected control layer only; never default content.

### Icons

- Prefer SF Symbols already expressing the business meaning.
- Use one weight family within a row; filled symbols for selected/active states, regular/outline for neutral states where a counterpart exists.
- Keep icon size tied to `V32Layout.iconRegular`, `toolIcon`, or bubble tokens.
- Do not use an icon plus a chevron unless the row actually navigates.

### Buttons

- Primary: one clear write/confirm action, accent-backed, success only after completion.
- Secondary: modify/cancel/low-emphasis action, neutral surface or text treatment.
- Destructive: native destructive role and confirmation pattern.
- Toolbar: contextual, compact, system placement; never duplicate the page’s main action.
- Inline action: row-local and at least 44pt hit area; no large card wrapper.

### Status

- Todo: completion is a state change, not a destructive action; use checkbox + text/accessibility state.
- Customer: pending/delivering/done use readable text and restrained semantic tint.
- Expiry: warning/danger expresses urgency; returned is a resolved state, not a success-colored dashboard card.
- AI: pending/executing/saved/failed/duplicate/cancelled must always have text; color and animation are supplementary.
- Semantic `success`, `warning`, `danger`, and `destructive` stay independent from ThemeStore brand accent.

## 5. Top 10 visual issues affecting perceived quality

1. Default reliance on `V32Card` makes many pages read as stacked dashboards.
2. Nested card/inset-card/border combinations add visual noise.
3. Editor Sheets repeat large rounded groups for simple fields.
4. Profile’s long settings surface has more container chrome than the setting hierarchy needs.
5. Performance can dilute revenue focus with multiple equally prominent regions.
6. Schedule can give date controls, summaries and event groups similar visual weight.
7. Customer and Expiry status styling can over-amplify semantic colors when combined with card surfaces.
8. Memo/Goods list content risks feeling like utility cards rather than fast-scanning rows.
9. AI ActionCard and composer can become busy if inset surfaces and Glass controls are all emphasized simultaneously.
10. Widget/Live Activity theme treatment must remain conservative until signed App Group sync is proven.

## 6. Ten existing designs that should not be changed

1. Home order: Header → Revenue Hero → 今日事项 → Today Status.
2. Home Revenue Hero as the main Performance entry.
3. Drawer as a root-only utility center, not a second Tab navigation.
4. Five-item Bottom Tab IA.
5. ThemeStore as the single brand-accent source.
6. Solid/paper content with selective control-layer Glass.
7. QuickRecord parsed preview and explicit confirmation.
8. AI ActionCard confirmation gate and idempotency behavior.
9. Native destructive confirmation with visible failure handling.
10. Empty State pattern: fact + next step, without a large illustration/card.

## 7. Recommended batches

### Phase 6.1 — first batch: three page families

1. **Performance / Revenue + Transaction History**
   - Before: revenue, chart, metrics and records compete across repeated cards.
   - After target: one clear money hierarchy, one compact chart/period group, flat transaction rows with amount/date/source hierarchy.

2. **Editor Sheets family: Revenue, Todo, Customer, Expiry, Memo**
   - Before: repeated large rounded field cards and similar but not identical form chrome.
   - After target: consistent native sheet/form rhythm, fewer containers, stable save/cancel hierarchy, preserved failure behavior and Dynamic Type.

3. **Schedule + Customer + Expiry status surfaces**
   - Before: date, status and content groups can carry too much card/border weight.
   - After target: readable status-first rows, neutral content surfaces, semantic colors used sparingly, consistent row density and empty states.

### Phase 6.2 — second batch

- Memo + Goods + Profile/Settings, using the flat-list and native-settings language established in 6.1.
- AI / QuickRecord / Voice visual density only after the form and status rules are stable; preserve their existing flow semantics.

### Phase 6.3 — final harmonization

- Remaining icon weights, section rhythm, title duplication, toolbar density, radius exceptions, Light/Dark contrast and Dynamic Type edge cases.
- Widget/Live Activity only within verified signing/data constraints.
- No Home or Drawer IA redesign.

## 8. Reference mapping status

- Apple native patterns: verified as the primary implementation reference in the existing Reference Pack.
- Existing XiaoZhangGui patterns: verified from V32/V35 tokens and production components.
- Kenotex: verified for role-based palette relationships only, not layout or UI skin.
- Kombai: category-level source recorded, but concrete entries/screenshots are **UNVERIFIED** and must not be used as precise visual evidence.

## 9. Scope result

This is a visual audit and proposed rule set only. No production code, tests, project files, business logic, Home IA, Drawer IA, data model, repository, AI architecture, dependency, or App Icon was changed.
