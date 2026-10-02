# Android V3.6 Release 签名口径（CI 临时测试签名）

## 口径

- `.github/workflows/android.yml` 的 `release` job 产出的 APK/AAB 采用 **CI 临时测试签名（unsigned/测试签名口径）**，**不是**正式发布签名。
- keystore 由 CI 每次运行用 `keytool -genkeypair` 现场生成（随机密码、有效期 1 天），只存放在 runner 的 `/tmp`，**绝不提交到仓库**，密码通过 `::add-mask::` 脱敏、只经 step outputs 传给 Gradle env。
- `android/app/build.gradle.kts` 的 `signingConfigs.ciTest` 仅在 `XZG_RELEASE_KEYSTORE_FILE`（或同名 gradle property）非空时挂到 release buildType；本地/无 env 时 `assembleRelease` 保持未签名（unsigned）。

## 验证

release job 在构建后执行 `aapt dump badging app-release.apk`（检查 package/applicationId、versionCode、versionName）并 `unzip -l app-release.aab`（检查 base module），日志即证据。

## 正式发布

正式上架（Google Play / OPPO 应用商店）需用户另行提供正式 keystore 与签名流程，届时另行立项；本次迁移产物不做正式发布用途。
