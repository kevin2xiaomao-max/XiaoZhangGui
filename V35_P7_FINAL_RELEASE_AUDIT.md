# V3.5 Final Release Audit

## Final architecture

ThemeStore is the single brand-theme source. Content remains solid/paper; native
controls and selective Liquid Glass are reserved for control layers. Home shows
today, Drawer holds business tools, Tabs hold primary modules, and Profile holds
settings and personal/store configuration.

## P0–P7 status

- P0 repair, P1/P2 native navigation, P3 presentation, P4 AI Liquid Experience: complete.
- P4.1 real-device issue repairs and P4.1.1 Home toolbar hotfix: complete in source history.
- P5.0–P5.4 theme, Drawer, Home cockpit, visual language, and cleanup: complete.
- P6 accessibility/widget polish: source complete; signed device verification pending.
- P7 final regression and release audit: code gates recorded here.

## Gates

- iPhone 17 / iPhone Air / generic iOS device builds: PASS.
- Final gate rerun: Widget2 time-dependent test was converted to a fixed UTC reference date. A subsequent simulator test-runner invocation stalled before producing a completed result; XCTest is therefore not claimed PASS until that runner issue is rerun in a clean simulator session.
- Theme, Drawer, Home, AI, Widget regression coverage remains in the repository test targets.
- `git diff --check`: required PASS before final commit.

## Widget, Live Activity, and signing

Widget and Live Activity use restrained presentation styling without changing
BusinessSnapshot or ActivityAttributes. App and Widget source entitlements match
`group.com.xiaozhanggui.ios.shared`.

`SIGNED IPA UNVERIFIED` and `TRUE DEVICE UNVERIFIED` remain explicit. A signed
Apple device build is still required for App Group read/write, Widget real-data
sync, Lock Screen, Live Activity, deep links, and keyboard/accessibility acceptance.

## Final true-device checklist

- Chinese 9-key keyboard and AI Composer dismissal
- Home Drawer edge swipe and secondary-page system back
- Real Saobei screenshot OCR: recognition → preview → confirm → persistence
- Widget real-data sync, App Group read/write, Small/Medium states
- Lock Screen / Live Activity compact, minimal, expanded
- `xzg://ai` and `xzg://voice` deep links
- Light/Dark, Dynamic Type Large/XXL/Accessibility Large, VoiceOver, Reduce Motion/Transparency

## Known limitations

No signed IPA or true-device evidence is available in this local final pass. Widget
theme rawValue propagation is intentionally not enabled without verified signed App
Group capability. Release Notes describe only shipped V3.5 changes; no receivables,
unpaid, or other unimplemented functionality is claimed.
