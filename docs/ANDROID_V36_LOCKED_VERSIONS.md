# Android V3.6 锁定版本基线（Phase 1 Release Gate）

CI 首绿：run `36923437739`→失败（serialization 映射）→ run `36923819266` **SUCCESS**
（`./gradlew clean assembleDebug` / `test` / `lint` 全 PASS，GitHub Actions clean-room，JDK 17）

| 组件 | 版本 |
|------|------|
| Gradle | 8.10.2 |
| AGP | 8.5.2 |
| Kotlin | 2.0.21 |
| KSP | 2.0.21-1.0.25 |
| Compose BOM | 2024.09.00 |
| compileSdk / targetSdk | 35 |
| minSdk | 26 |
| JDK（CI） | 17（Temurin） |
| applicationId | com.xiaozhanggui.app |
| versionName / versionCode | 3.6.0 / 36 |

APK（debug，CI artifact `xiaozhanggui-android-debug-apk`）：
- 17,149,720 字节，SHA256 `53f2076f39e300d1…`
- 8 dex + 8 native .so，169 entries

## 已知 environment issue（不阻塞后续开发）

Muse 沙箱 egress 对 Java TLS 指纹 Connection reset：
`plugins.gradle.org`、`repo.maven.apache.org`、`dl.google.com` 均不可用（curl 正常）。
`settings.gradle.kts` 用 `resolutionStrategy` 将 AGP/Kotlin/KSP 映射到官方 Maven module，
仅 `google()` / `mavenCentral()`，无第三方镜像、无 HTTP、无关闭 TLS 校验。
本地记为 environment issue；CI clean-room 为准，不伪报本地构建 PASS。
