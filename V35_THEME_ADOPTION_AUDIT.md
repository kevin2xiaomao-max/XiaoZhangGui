# V3.5 Theme Adoption Audit

## Scope

P5.1.1 adds the formal appearance selector on top of the existing V32 `ThemeStore`,
`V32ThemeEnvironment`, `AccentTheme`, `BackgroundTheme`, and `AccentPalette`.
No second theme storage or parallel environment was introduced.

## Remaining hardcoded accent candidates

| File | Finding | Follow-up |
| --- | --- | --- |
| `XiaoZhangGui/Features/Home/HeroPrototypeGallery.swift` | Prototype-only progress accents still use `Color.green` in two preview components. | P5.3: route prototype previews through `AccentPalette`; not part of production Home. |

The scan found no hardcoded green/hex accent in the production feature views covered by
this pass. Import parser hexadecimal values are file-format signatures, not UI colors.

## Current adoption

- Root theme state remains owned by `ThemeStore` and persisted through its existing
  UserDefaults keys.
- The new Appearance screen and P5.1 drawer consume the shared accent tokens.
- Existing legacy raw values remain unchanged; `rose` is additive.
- Existing saved V32 accent/background keys are preserved even if the migration marker
  has not yet been written.
- New installs with no legacy or saved theme use Ocean Blue as the migration fallback.

## Deferred

Older screens that still use literal semantic or brand colors should be migrated only
with a targeted P5.3 audit. Business semantic colors (`success`, `warning`, `danger`,
and `destructive`) remain independent of the selected theme.
