# Shuffle Slide — execution report

Date: 13 November 2026 (Asia/Calcutta).

**Delivery status: offline evaluation build. Production release acceptance is incomplete.** Flutter source and a signed-with-debug-key ARM64 APK are supplied. The APK has been built and structurally/signature-verified; it has **not** been launched on Android or installed on a phone.

## Executed environment

- Managed Linux cloud workspace, approximately 8 GB writable disk.
- Flutter 3.50.0 stable, revision ab2912035e; Dart 3.14.0.
- Full Temurin JDK 21 installed after detecting that the initial Java installation lacked `javac`.
- Android compile/target SDK 36; app minimum SDK 24.
- Android Studio: not installed/opened in this environment.
- Android runtime version tested: **none**. Target SDK 36 is build metadata, not a tested OS version.
- Physical Android model: **none accessible**. No USB device interface was exposed. ADB startup also failed because its default home-directory location was read-only.
- Emulator attempt: SDK tools downloaded, but the system image could not be completed within disk limits; incomplete files were removed. `/dev/kvm` was absent.

## Final checks

| Category | Status | Actual evidence and limit |
|---|---|---|
| Flutter Android compilation | PASS | `flutter build apk --debug --target-platform android-arm64` completed successfully. |
| Static analysis | PASS | `flutter analyze`: No issues found. |
| Unit/widget suite | PASS | 22 passed, 1 explicit preview-generation test skipped. |
| Preview generation | PASS | Skipped test run explicitly with `RENDER_PREVIEWS=true`; 1 passed. Three Flutter-rendered PNG previews generated and visually inspected. These are not device screenshots. |
| Number level configuration | PASS | Exactly 50 definitions verified; stage sizes, scramble growth and decreasing timers within stages checked. |
| Photo level configuration | PASS | Exactly 50 definitions verified with independent mode keys. |
| Solvable shuffles | PASS | Both modes, all 50 levels, 10 seeds each: 1,000 generated boards reversed to the solved state using legal moves. |
| Tile movement / multi-tile / invalid input | PASS | Shared engine tests verify displaced-tile counting, whole-action undo and rejection of illegal moves. |
| Number gameplay / win / progression | PASS | Flutter widget flow completes a board, displays results and saves the completed level. No Android runtime test. |
| Photo gameplay / reconstruction | PASS | Shared-engine and widget test renders image sections and completes a photo level; full original shown on result screen. |
| Local guest login | PASS | Offline welcome-to-guest flow tested with mocked preferences. |
| Firebase Anonymous login | BLOCKED | Existing project configuration absent. Only local guest flow executed. |
| Google login / canceled native login | BLOCKED | Firebase files, OAuth client mapping and actual Android runtime unavailable. Error handling is implemented but Google authentication was not executed. |
| Guest-to-Google linking / existing-account merge | BLOCKED | Linking code supplied; pure progress reconciliation passes tests. No real Firebase account transition executed. |
| Gallery / crop orchestration | PASS | Mock picker/cropper confirms gallery selection, square crop request, private copy and cancellation behavior. |
| Native gallery / EXIF / large real photos | NOT TESTED | No phone/emulator. Native cropper and picker behavior is not established by mocks. |
| Imported-photo privacy/removal | PASS | Local filesystem test verifies a separate copy and removal without deleting the original; no photo upload code exists. |
| Timer / pause / scoring / stars | PASS | Engine expiry/scoring and widget pause tests; result bonus/star rules checked. Native background/process death not tested. |
| Hints / undo / anti-farming | PASS | Bounded legal hint test, undo cap/penalties, reversal of whole action and consumed placement awards checked. |
| Mode-specific progress / conflicts | PASS | Pure merge test preserves independent best score/stars/time/moves; idempotence and independent unlocks checked. |
| Local persistence | PASS | Saved-attempt/settings/session roundtrip with mocked SharedPreferences; real Android disk/relaunch behavior not executed. |
| Cloud sync / Firestore rules | BLOCKED | No real Firebase configuration or deployed test project. Rules supplied but not deployed or emulator-tested. |
| Result-card / native sharing | NOT TESTED | Implementation provided; result screen share button rendered. No real native share sheet or WhatsApp dispatch executed. |
| Android Studio validation | NOT TESTED | Source includes generated Android Studio project; Gradle build executed via CLI only. |
| APK package / ABI metadata | PASS | AAPT and ZIP inspection: com.rook.shuffleslide, v1.0.0 (1), SDK 24→36, ARM64-only native libraries, debuggable. |
| APK signature | PASS | `apksigner verify --verbose --print-certs` succeeds with APK Signature Scheme v2, one RSA-2048 Android Debug signer. This is not a production certificate. |
| Signed production release APK | BLOCKED | Owner's release keystore/passwords not supplied; no production release signing attempted. |
| Release OAuth certificate fingerprints | BLOCKED | Existing Firebase Android app and release certificate unavailable. |
| Physical installation / real-device gameplay | BLOCKED | No accessible phone. No installation, launch, Android OS version or device model is claimed. |
| iOS build / runtime | NOT TESTED | iOS project and permissions included, deployment target 15.0; no macOS/Xcode executor. |

## Corrections and retests

- Initial level test incorrectly required scramble count to increase across board-size transitions. The brief's stage ranges restart at a larger board. Corrected the test to check increasing scrambles/decreasing timers within each stage; retest passes.
- Widget tests found narrow-screen mode-card/footer and photo-toolbar overflow. Wrapped constrained text and gave toolbar controls bounded widths; final suite passes.
- Mock photo tests initially completed asynchronous file work outside the correct test zone and attempted to assert offscreen lazy-list widgets. Corrected the test scheduling and scrolling; final tests pass. Photos were also preloaded before capturing golden renders.
- Java runtime lacked a compiler; installed a full JDK. Java downloads initially lacked the cloud proxy CA; configured the existing system trust store without disabling TLS validation. Build subsequently passed.
- SDK/emulator and native build files exceeded disk space repeatedly. Removed the incomplete emulator install and unused tool/docs caches, restored compiler libraries removed during cleanup, and deduplicated identical generated files. Excluded the optional Vulkan developer validation layer from APK packaging.
- Native-library inspection caught dependencies advertising extra ABIs without a matching Flutter engine. The project now derives ABI filters from Flutter's requested targets and disables Flutter's default broad filter; final APK contains **only arm64-v8a**. Other targets remain available through the normal build commands.
- Standard debug key location was unwritable in this cloud environment. Used an explicit, conventional Android debug keystore through `SHUFFLE_DEBUG_KEYSTORE`. Production signing remains separate and unconfigured.

## Required external completion

1. Supply the existing Flutter/Firebase project configuration and confirm the original app/bundle identifier. The current identifier is provisional; no Firebase credentials/project IDs were invented.
2. Verify Anonymous and Google auth, account linking/reconciliation, cloud conflict handling and the reviewed security rules against the existing Firebase project.
3. Provide the existing release signing configuration securely on the developer machine and verify its SHA-1/SHA-256 in Firebase.
4. Run the supplied integration test and the README acceptance flow on an emulator and an actual phone, including real gallery photos, resume, offline/online sync, native sharing and release Google sign-in.
5. Migrate the growing cloud attempt ledger out of the single profile document before high-volume production use. It currently has Firestore's 1 MiB document limit. No public leaderboard or server-authoritative score validation is implemented.

AdMob, cloud photo backup and leaderboards are optional and omitted. Photos remain on-device; automatic cross-device transfer of imported images is intentionally absent.

## Artifact

- `Shuffle-Slide-Android-ARM64-debug.apk`
- Bytes: **51,524,328** (about 49.14 MiB).
- SHA-256: `0bae68b5e5f6420903debe61141e004bfcdf43d9869a580a93ba4ff303f54f28`.
- Application ID: `com.shuffleslide.shuffle_slide`.
- Debug certificate SHA-256: `941cda1ff43c708e3d99927895fc1dd4094a78e0f9506be61d54d78ad7d8f305`.
- Debug certificate SHA-1: `183cbc4f85d43247d1cfd1c484d568a8feb55d72`.
- Original build output: `build/app/outputs/flutter-apk/app-debug.apk`.

Evidence logs accompany the output under `verification/`. Source, README, tests and this report are included in `Shuffle-Slide-source.zip`.
