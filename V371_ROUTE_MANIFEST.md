# V3.7.1 Production Route Manifest

> Baseline: `1eba796cde0eb47a5e393abdc419fd41827770a7`
>
> Phase 0 branch: `codex/v371-phase0-protection`
>
> Counting rule: one explicit tap is one operation; scrolling is not counted. Conditional destinations require the corresponding user data but their owning page remains reachable. Widget and deep-link surfaces are listed separately because they do not start from the in-app Home screen.

## In-app routes

| ID | Production destination / function | Source | Cold-start route | Max taps | Return path | Stable automation evidence | Phase 0 status |
|---|---|---|---|---:|---|---|---|
| R01 | Home | `App/RootView.swift`, `Home/HomeView.swift` | launch | 0 | n/a | `screen.home`, `tab.home` | Reachable |
| R02 | Todo | `Todo/TodoView.swift` | Todo tab | 1 | switch tab | `tab.todo`, `screen.todo` | Reachable |
| R03 | Calendar | `Schedule/ScheduleView.swift` | Calendar tab | 1 | switch tab | `tab.calendar`, `screen.calendar` | Reachable |
| R04 | Business | `Performance/PerformanceView.swift` | Business tab | 1 | switch tab | `tab.business`, `screen.business` | Reachable |
| R05 | Profile | `Profile/ProfileView.swift` | Home → profile | 1 | system back | `home.profile`, `screen.profile` | Restored binding propagation |
| R06 | Customer delivery | `Customer/CustomerView.swift` | Home → 今日重点客户配送 | 1 | system back | `home.customer`, `screen.customer` | Reachable |
| R07 | Expiry / returns | `Expiry/ExpiryView.swift` | Home → 今日重点临期退货 | 1 | system back | `home.expiry`, `screen.expiry` | Reachable |
| R08 | Quick Record | `QuickRecord/QuickRecordSheet.swift` | Home → microphone | 1 | Cancel / sheet dismiss | `home.quickRecord`, `sheet.quickRecord`, `quickRecord.cancel` | Reachable |
| R09 | AI Chat | `Assistant/AI/UI/AIChatView.swift` | Home → AI command entry | 1 | sheet dismiss | `home.ai`, `sheet.ai` | Reachable; not a Tab |
| R10 | Weather detail | `Weather/WeatherViews.swift` | Home → weather | 1 | Close / sheet dismiss | accessibility label `天气` plus sheet title | Reachable; identifier follow-up is P1 |
| R11 | Temporary Goods | `Goods/GoodsView.swift` | Business tab → goods toolbar button | 2 | system back | `business.goods`, `screen.goods` | **Restored in Phase 0** |
| R12 | Goods add / edit | `Goods/GoodsEditorSheet.swift` | Business → Goods → add / row | 3 | Cancel / Save | owning route R11 | Reachable; CRUD test expansion tracked |
| R13 | Memo search/list | `Memo/MemoView.swift` | Business tab → menu → Records | 3 | system back | `business.menu`, `business.memo`, `screen.memo` | **Stable non-data-dependent route restored** |
| R14 | Memo create / edit | `Memo/MemoEditorSheet.swift` | Todo tab → 备忘 segment → add / row | 3 | Cancel / Save | Todo and editor accessibility labels | Reachable through Todo |
| R15 | Daily business report | `DailyReport/DailyReportSheet.swift` | Business tab → menu → Daily Report | 3 | Close / sheet dismiss | `business.dailyReport`, `sheet.dailyReport`, `dailyReport.close` | **Restored in Phase 0** |
| R16 | Saobei import | `Import/SaobeiImportSheet.swift` | Business tab → menu → Import | 3 | Close / sheet dismiss | `business.import` | Reachable |
| R17 | Add income / expense | `Performance/MoneyEditorSheet.swift` | Business tab → menu → income / expense | 3 | Cancel / Save | `business.addIncome`, `business.addExpense` | Reachable |
| R18 | Transaction history | `Performance/TransactionHistoryView.swift` | Business tab → View All | 2 | system back | `screen.transactions` | Reachable |
| R19 | Payment codes | `PaymentCode/PaymentCodeView.swift` | Home → Profile → Payment Codes | 2 | system back | `profile.paymentCodes`, `screen.paymentCodes` | **Restored in Phase 0** |
| R20 | Payment code add / edit | private `PaymentCodeEditorSheet` | Profile → Payment Codes → add / row | 3 | Close / Save | owning route R19 | Reachable |
| R21 | Payment code full screen | `PaymentCodeFullScreenView.swift` | Profile → Payment Codes → configured code | 3 | explicit close / dismiss | owning route R19; requires saved image | Conditional but reachable |
| R22 | Appearance / theme / wallpaper | `ProfileView.swift`, `AppearanceSettingsView.swift` | Home → Profile → corresponding row | 2 | Done / Close | owning route R05 | Reachable |
| R23 | Shop / goal / reminder settings | `ProfileView.swift` private sheets | Home → Profile → corresponding row | 2 | Cancel / Done | owning route R05 | Reachable |
| R24 | Voice settings | private `VoiceSettingsSheet` | Home → Profile → Voice Input | 2 | Done | `profile.voiceSettings` | Reachable |
| R25 | Original voice test | `Voice/VoiceView.swift` | Home → Profile → Voice Input → Test Voice | 3 | explicit close / sheet dismiss | `profile.voiceTest`, `sheet.voice` | **Broken Binding fixed in Phase 0** |
| R26 | Backup / restore / cache / about / privacy | `Profile/ProfileView.swift` | Home → Profile → corresponding row | 2 | system panel / Close | owning route R05 | Reachable |
| R27 | AI provider settings | `AIProviderSettingsSheet.swift` | Home → AI → menu → AI Settings | 3 | Cancel / Save | `home.ai`, `ai.menu` | Reachable |
| R28 | AI short voice | `ShortVoicePanel.swift` | Home → AI → voice | 2 | cancel / finish | owning route R09 | Reachable when speech recognizer is available |
| R29 | Storage unavailable state | `App/XiaoZhangGuiApp.swift` | automatic on persistent container failure | 0 | restart after remediation | visible failure title | Conditional system state |

## External and system-owned routes

| ID | Surface | Entry | Return / completion | Status |
|---|---|---|---|---|
| E01 | Voice deep link | `xzg://voice` | dismiss Voice sheet | Preserved |
| E02 | Quick Record deep link | `xzg://quickrecord`, `xzg://quick` | cancel / dismiss | Preserved |
| E03 | AI deep link | `xzg://ai`, optional `mode=voice` | dismiss AI sheet | Preserved |
| E04 | Today Stats Widget | Add Widget system UI | tap deep link into app | Preserved; simulator/device verification required |
| E05 | Interactive Todo Widget intent | Widget completion control | stays in Widget / refreshes snapshot | Preserved; behavior unit tests exist |
| E06 | Business Live Activity | system Lock Screen / Dynamic Island | open app / activity end | Preserved; device verification required |
| E07 | App Intents | Siri / Shortcuts | system completion | Preserved; not an in-app route |

## Compiled legacy presentation helpers

| Item | Evidence | Decision |
|---|---|---|
| `V35DrawerContainer` | no Production call site | Do not restore the old Drawer; keep source until a later approved cleanup proves every destination has a replacement |
| private `RecordEditorSheet` in `TodoView.swift` | `showNewRecord` has no setter to true | Not treated as a normal user route; retained and made failure-visible rather than deleted |

## Automated coverage map

- `XiaoZhangGuiUISmokeTests.testAppLaunches`: R01–R04 shell invariant and AI-not-a-tab.
- `testFourMainTabsAndSecondaryBackPath`: R01–R05 plus system back.
- `testAIUsesHomeEntryAndReturnsFromSheet`: R09.
- `testQuickRecordUsesHomeEntryAndReturns`: R08.
- `testBusinessRoutesGoodsAndDailyReport`: R11, R13, R15 plus return paths.
- `testProfileRoutesPaymentCodesAndVoiceTest`: R19, R24, R25.
- Existing AI tests enter exclusively through R09 after Phase 0.
- Failure/retry tests cover Todo, Customer, Expiry, and Goods state actions through real UI and repositories with a DEBUG-only one-shot failure gate.

## Known runtime verification boundary

This manifest is a route contract, not a claim of runtime success. The listed UI tests must pass on the macOS Xcode runner. Routes requiring microphone, permissions, configured payment images, Widget host UI, Dynamic Island, or real device services remain NOT RUN until their corresponding runner/device evidence exists.
