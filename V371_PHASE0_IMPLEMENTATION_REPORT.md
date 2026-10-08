# V3.7.1 Phase 0 Implementation Report

## Outcome

Phase 0 implementation is complete in the local independent branch `codex/v371-phase0-protection`, but it is **not accepted** because the configured GitHub integration rejected every write attempt with HTTP 403. The remote branch was not created, macOS CI was not triggered, and simulator/runtime claims remain NOT RUN.

The target branch was rechecked before implementation on 2026-10-08. Remote `feature/v3.7.1-muse-rebuild` and the requested baseline both resolved to:

`1eba796cde0eb47a5e393abdc419fd41827770a7`

No upstream delta existed at the time of the check.

## Local commits

| Commit | Scope | Behavior boundary |
|---|---|---|
| `56cc3d1` | Production route restoration, stable accessibility identifiers, Route Manifest, current XCUITests, CI evidence upload, audit/plan documents | Navigation and test infrastructure only; no schema or AI execution changes |
| `0f58d37` | One-shot DEBUG failure injection and minimal failure/retry handling | Customer, Expiry, Goods and Todo/Memo state actions only; kept separate for review |
| `f066f00` | CI result-count correction | Records an explicit zero `not_run` count on a passing Unit run |

The final local report commit is intentionally separate from the implementation commits. Use `git log -4 --oneline` to resolve it after this document is committed.

## P0-A: CI and UI Tests

- Added `feature/v3.7.1-muse-rebuild` and `codex/v371-phase0-protection` to push triggers and the target branch to pull-request triggers.
- Removed the stale fifth AI-tab assumption. All AI scenarios now enter through the real Home AI control (`home.ai`).
- Added stable identifiers for the four tabs, key screens, Home AI/Quick Record/Profile entries, Business routes, Profile tools, sheets and retry controls.
- Added XCUITest coverage for four tabs, a secondary navigation return path, AI sheet, Quick Record, Goods, Memo, Daily Report, Payment Codes and original Voice Test.
- CI records discovered/passed/failed/not-run counts, simulator build log, Unit/UI logs, xcresult bundles, failure screenshots contained in xcresult, baseline diff and file list.
- The target/Phase 0 branches skip the unsigned generic-device IPA step; no formal IPA is produced.

Runtime status: **NOT RUN**. See `V371_PHASE0_TEST_RESULTS.md`.

## P0-B: Production route restoration

The authoritative inventory is `V371_ROUTE_MANIFEST.md` (R01-R29 plus external/system routes E01-E07).

- Temporary Goods: restored as a direct Business toolbar destination (two taps from cold start; editor within three).
- Daily Business Report: restored in the Business action menu (three taps).
- Memo list: restored in the Business action menu without adding Home cards or the old Drawer.
- Payment Codes: restored in the Profile tools group (two taps; editor within three).
- Original Voice Test: Home now propagates the real `showVoice` binding into Profile; UI-test mode exposes the control without pretending that speech hardware is available.
- The old `V35DrawerContainer` has no Production call site and was not restored.

All in-app Production destinations in the manifest have a route budget of at most three explicit taps and a documented return path. Runtime reachability is not claimed until XCUITest passes.

## Save reliability protection

| Location | Before | Phase 0 behavior | Risk | Acceptance criterion |
|---|---|---|---|---|
| `Features/Customer/CustomerView.swift` | `try?` could discard `advanceStatus` failure while UI feedback continued | `do/catch`, no success feedback on failure, visible retry preserving the request | Medium | Injected first failure keeps label/state; retry advances exactly once |
| `Features/Expiry/ExpiryView.swift` | `try?` could discard return-state failure and still emit feedback | `do/catch`, visible retry, success haptic only after repository success | Medium | Injected failure keeps pending state; retry toggles exactly once |
| `Features/Goods/GoodsView.swift` | Delete failure was silent | `do/catch`, row remains, visible retry | Medium | Injected failure preserves row count; retry removes one row |
| `Features/Todo/TodoView.swift` | Reachable toggle already caught errors, but had no retry; retained Record editor used `try?` | One-shot injected toggle failure with retry; Record editor save now exposes failure | Medium | Injected toggle failure leaves task pending; retry completes once; no silent Memo repository write |

Failure injection exists only in DEBUG, requires `--ui-testing`, is scoped to a named operation and fails once per process. Production builds cannot enable it.

The remaining `try?` occurrences in these feature directories are non-state operations: JSON compatibility decoding/encoding, animation delay and Photos picker transfer. `UITestSeed` retains a test-only `context.save()` best-effort call; it is not reachable in Production.

## Protected boundaries

- No V371DesignSystem redesign.
- No data model or SwiftData schema change.
- No AI provider/router/core execution-chain change.
- No deletion of user data, settings, navigation destinations or Production features.
- No Home, Calendar or Dock visual redesign.
- No old Drawer restoration and no new Home card wall.
- No test assertion was removed and no failing test was skipped.

## Changed-file groups

- CI/tests: `.github/workflows/build.yml`, `Tests/UITests/XiaoZhangGuiUISmokeTests.swift`, two new Phase 0 Unit suites.
- Route contract/docs: `V371_ROUTE_MANIFEST.md`, this report, test results, audit and refinement plan.
- Shell/navigation: Root, FloatingDock, V371 primitives and centralized accessibility IDs.
- Restored routes: Home, Performance, Profile, Goods, Memo, Payment Code, Daily Report, Voice and Transaction History.
- Reliability: UI test mode/seed plus Customer, Expiry, Goods and Todo.

The complete machine-readable name/status list is produced by:

```sh
git diff --name-status 1eba796cde0eb47a5e393abdc419fd41827770a7..HEAD
```

## Blocker and continuation

Push attempts using Git Smart HTTP and Git Data API both failed with `Resource not accessible by integration` / HTTP 403. Remote remains at the baseline SHA and no CI URL exists for these commits.

Required continuation: provide a credential with repository Contents write permission (and Actions read permission for monitoring/artifacts), then push `codex/v371-phase0-protection`. The workflow will run automatically. Phase 0 must remain stopped until that run reports actual build, Unit and UI results.
