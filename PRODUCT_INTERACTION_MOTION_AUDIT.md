# Product Design Stack — Phase 5.0 Interaction & Motion Audit

> Audit only. No production code, tests, project files, IA, data model, repository, AI architecture, or App Icon changes were made.

## Audit basis

This audit follows `PRODUCT_DESIGN_REFERENCE_PACK.md` and the existing SwiftUI implementation. Root navigation uses a five-tab `TabView` with one `NavigationStack` per tab. `V35HomeRevenueHero` is a native `Button` that pushes Performance. `V35SideUtilityDrawer` is root-only, solid, dimmed, and driven by a horizontal drag offset. Motion is centralized in `V32Motion`: quick `0.18s`, standard `0.28s`, slow `0.42s`, reduced `0.12s`, plus soft/interactive spring presets.

Priority: P0 = correctness or misleading feedback; P1 = material flow confidence; P2 = polish.

## Touchpoint audit

| Touchpoint | Current behavior | Problem | Recommended interaction | Motion | Haptic | Level | Priority |
|---|---|---|---|---|---|---|---|
| Home Revenue Hero → Performance | Native button pushes Performance and exposes an accessibility label. | No material issue; extra custom transition would compete with system navigation. | Keep native push and spatial relationship. | System navigation only. | Optional light tap only if it does not duplicate tab haptic. | L1 | P2 |
| Bottom Tab switching | Root `TabView` owns selection and currently emits a light haptic on change. | Rapid switching may make repeated haptics noisy. | Keep system tab behavior and no custom cross-tab transition. | System transition; Reduce Motion fallback is system final state. | Existing light haptic is sufficient. | L1 | P2 |
| Drawer open / close / drag | Root-only drawer follows drag offset; overlay dims; threshold/predicted end decides settle. | Model is strong; completion has little tactile confirmation; tab-bar layering needs to remain unambiguous. | Keep root-only gesture, tap-to-dismiss, and threshold logic. | Interactive offset, short settle; reduced-motion fade/ease. | Light on completed open only; none per tick or close. | L1+L2 | P1 |
| Todo checkbox | Todo guards duplicate toggles, animates state, and uses success/light haptic; Home and Schedule also toggle. | Feedback is not fully identical across surfaces; `try?` actions can hide failure. | One success language and repository result across Home, Schedule, Todo; announce state to VoiceOver. | Small checkbox/state transition only. | Success on complete, light on undo. | L2 | P1 |
| Customer status | Row action advances status; terminal completion gives success haptic and short feedback. | Completion is more prominent than neighboring flows; swallowed failures can look successful. | Keep one-tap progression; report result and retain row on failure. | Short status transition, no large movement. | Success only after repository success. | L2 | P1 |
| Expiry return / restore | Row action toggles returned state with success/light haptic; delete is separately confirmed. | Failure treatment should match save/delete reliability. | Keep toggle semantics and distinguish returned from restored-to-pending. | Brief status transition. | Success on return, light on restore. | L1+L2 | P1 |
| Revenue number change | Hero uses `.numericText`; value is query-derived. | Frequent refreshes could animate noise or imply a user action. | Animate meaningful confirmed changes only; initial load and Reduce Motion show final value. | Numeric transition only; no scale. | Haptic belongs to originating save, not refresh. | L1 | P2 |
| Sheet open / save / close | Native sheets and detents; successful save dismisses; failure stays with input and retry alert. | Custom feedback must not compete with system dismissal. | Keep native sheet and one clear save action; failure remains in place. | System sheet transition only. | Success after repository write. | L1 | P1 |
| QuickRecord states | Parser produces a visible draft/type; explicit “确认保存”; saving, saved destination, and failure are visible. | This is the strongest semantic reference; other free-input paths must not drift. | Preserve `Input → Parsed → Confirm → Saving → Saved/Failed`. | Subtle state replacement only. | Optional light on ready; success after write. | L2 | P0 |
| Voice states | Listening/processing/preview/saving/idle/error are modeled; save keeps confirmation semantics. | Waveform/pulse can dominate; deep link and Home voice should feel like one capability without forced implementation merge. | Reuse state language and save/error language; keep VoiceView independent. | Restrained pulse; static under Reduce Motion. | Light on ready optional; success after save. | L2 | P1 |
| AI Thinking / ActionCard | Body is solid; ActionCard has explicit confirm gate and resolved statuses. | Confirm currently signals success at tap time before async execution is known to succeed. | Keep gate; success only after actual execution; failure/retry remains visible. | Short status transition; no full-screen animation. | Success after executed write only. | L2 | P0 |
| Empty State → create | SF Symbol, short text, and existing create action; filtered-empty and database-empty are separated. | Main remaining risk is inconsistent emphasis, not missing capability. | Keep nearest existing create action without a large card. | No animation required; fade only for state change. | None, or light after successful create. | L1 | P1 |
| Delete confirmation | Native `confirmationDialog` with destructive role; cancel preserves data; failure does not fake success. | Correct system pattern; avoid duplicate alerts or optimistic removal. | Keep one delete call and remove from list only after success. | System dialog only. | Optional light after successful delete, never on tap alone. | L1 | P0 |
| Schedule date / item changes | Date selection updates selected day with light haptic and fade; items refresh; Todo action uses repository. | Date and item transitions can feel like separate systems; `try?` may hide failure. | Keep calendar structure and make selected-day refresh coherent. | Quick fade for content; no large calendar movement. | Light on date; success/light on item change. | L1+L2 | P1 |

## Cross-cutting findings

### P0

1. AI ActionCard must not feel “saved” before asynchronous execution succeeds. The confirmation gate is correct; feedback timing needs a later narrow alignment pass.
2. Delete must remain native and non-optimistic.
3. QuickRecord parsed preview is the reference state language for interpreted CREATE flows.

### P1

1. Align completion language and haptics across Home, Schedule, and Todo.
2. Expose repository failure for Customer, Expiry, and Todo state actions instead of silently treating `try?` as success.
3. Keep Drawer haptic limited to settled open; never vibrate on drag updates.
4. Share user-facing state words between Voice and ShortVoicePanel without merging implementations or weakening AI confirmation.

### P2

1. Do not add a custom Hero-to-Performance animation.
2. Do not animate every revenue refresh; numeric motion should communicate a meaningful update.
3. Native sheets, tabs, dialogs, and navigation are already the correct motion baseline.

## Top 8 XiaoZhangGui interaction moments

1. **Revenue Hero → Performance:** makes “今天赚多少” an obvious next inspection step. Use native `Button` + `NavigationStack`; optional light tap; Reduce Motion uses the normal system push.
2. **Todo completion from Home:** makes “现在做什么” actionable. Use the native control and small state transition; success/light haptic; Reduce Motion shows the final check immediately.
3. **Customer delivered:** a real-world handoff deserves concise acknowledgement. Keep the row action; success only after repository success; static status fallback under Reduce Motion.
4. **Expiry returned:** resolves a risk item without celebration. Use the existing row action and semantic label change; success/light haptic; no large movement.
5. **QuickRecord parsed → confirm:** the trust moment where the user sees what will be written. Keep parser and native sheet; optional light on ready, success after write; no motion required for comprehension.
6. **Voice listening → ready:** makes speech feel like the same quick-capture capability. Keep VoiceView/system sheet; restrained pulse; static labels under Reduce Motion.
7. **AI confirm → saved:** preserves “AI suggests, user authorizes.” Keep ActionCard; success only after execution; final status without processing spectacle under Reduce Motion.
8. **Drawer edge open/close:** gives the utility center a physical feel while protecting system back. Keep root-only custom drag over native layout; light haptic on settled open; fade/ease fallback.

## Accessibility and resilience

- **Reduce Motion:** remove spring, large translation, repeated pulse, and numeric movement where needed; always show the final state.
- **Dynamic Type:** preserve at least 44pt targets and wrap labels rather than truncate; no motion should be required to understand status.
- **VoiceOver:** announce checkbox completion, Customer/Expiry changes, save destination, and ActionCard result; haptic must never be the only confirmation.
- **Rapid actions:** retain Todo `togglingIDs`, disabled save/confirm while saving, and resolved ActionCards. Customer/Expiry actions should receive equivalent duplicate-tap protection in a later pass if evidence supports it.
- **Low performance:** avoid new per-frame work beyond the existing Drawer offset; do not combine blur, glass, large shadows, and animation in content surfaces.

## Proposed implementation split

### Phase 5.1 — Interaction semantics alignment

Align success/failure wording and haptic timing across Todo, Customer, Expiry, Revenue, Memo, QuickRecord, Voice, and AI. Add focused before-write/after-write/failure tests. Keep navigation, models, repositories, and confirmation gates unchanged.

### Phase 5.2 — Motion and accessibility hardening

Audit rapid taps, VoiceOver announcements, Dynamic Type targets, Reduce Motion, Reduce Transparency, and low-performance behavior. Standardize only state transitions that communicate completion or spatial relationship.

### Phase 5.3 — Selective micro-interaction pilot

Pilot at most three moments: Drawer settle, parsed-to-saved QuickRecord, and one state transition such as Todo completion. Use existing `V32Motion` and native haptics first; stop if comprehension or accessibility regresses.

## Scope result

This document is an audit and recommendation only. No production code, tests, project files, data models, repositories, AI architecture, Home IA, Drawer IA, or App Icon were modified for Phase 5.0.
