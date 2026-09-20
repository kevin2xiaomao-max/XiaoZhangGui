# V3.5 P6 Widget Signing Audit

## Source configuration

- App entitlement: `group.com.xiaozhanggui.ios.shared`
- Widget entitlement: `group.com.xiaozhanggui.ios.shared`
- `SharedKernel/AppGroup.swift`: same identifier.
- `project.yml`: App embeds `XiaoZhangGuiWidget`; both targets use entitlement files.
- `BusinessSnapshot.load()` reads the App Group UserDefaults suite.

## Theme status

ThemeStore persists its accent rawValue in the app's existing settings store, while
Widget data is isolated in the App Group snapshot store. This pass does not mirror
theme state into App Group: doing so without signed capability and migration testing
would couple presentation state to the data sync path. Widgets use a restrained Ocean
fallback and remain schema/sync independent.

## Conclusion

- SOURCE PASS: identifiers and source entitlements match.
- SIGNED IPA UNVERIFIED: final embedded entitlements were not inspected in a signed IPA.
- TRUE DEVICE UNVERIFIED: App Group access and Widget theme propagation require an Apple-signed device build.
- No signing hack or theme-sync claim is made.
