# Shuffle Slide – Number & Photo Puzzle

Flutter mobile game with 50 Number levels and 50 Photo levels. Android is the immediate target; iOS platform sources are included. This delivery is an offline evaluation build, **not a production-certified release**. Read TESTING_REPORT.md for executed checks and external blockers.

## Implemented

- Shared deterministic, solvable sliding engine for 3×3 through 6×6 boards; tap, directional swipe, and whole-row/column sliding.
- Exactly 50 progressively configured levels per mode, independent unlocks and personal bests.
- Countdown, pause/background handling, session restoration, scoring, non-farmable placement awards, combos, bonuses, stars, 3 hints and 3 undos.
- Bounded 3×3 hint search in an isolate; a reversible legal solution path is retained as the guaranteed fallback for all board sizes. Fallback hints may retrace moves rather than minimize the solution.
- Native gallery picker, square crop, bounded image decode, one shared cached photo provider per board, reusable private local copies, removal, and a generated mountain sample.
- Original-photo reference thumbnail and larger preview; tutorial previews are free, regular previews cost 50 points and close after 3 seconds, expert levels allow one larger preview. Timer continues while viewing a reference.
- Offline guest profile, local progress/settings/session persistence, statistics and derived achievements.
- Image-led home screen with animated number/photo puzzle previews and smoother tile sliding.
- Firebase Anonymous login, Google authentication, anonymous account linking, explicit merge consent, transaction-based best-result reconciliation, and cloud retry on completion, app resume, or Sync.
- Weekly best-score leaderboard for Google and Firebase-anonymous players, with trophy styling and guest aliases.
- Native share sheet with a generated PNG achievement card; personal photo inclusion is opt-in. No invented app-download URL. App never sends a message automatically.
- Light/dark appearance, reduced motion, larger text, system click sounds, haptics, and accessibility labels.

AdMob, photo cloud backup, and app-store publication are omitted. Photos are never written to Firestore. The weekly leaderboard requires the existing Firebase project and rules below; it is not available in offline-only builds.

## Toolchain

Validated tool versions: Flutter 3.50.0 stable (ab2912035e), Dart 3.14.0, JDK 21, Android compile/target SDK from Flutter (36), minimum Android SDK 24 (Android 7). iOS deployment target is 15.0. The committed pubspec.lock records the resolved package versions. Use a complete Flutter/Android toolchain and allow several GB of temporary build space.

The new project uses provisional application ID **com.shuffleslide.shuffle_slide**. No existing project, Firebase configuration, or signing key was supplied. **Confirm and reuse the original application ID before connecting the existing Firebase app or publishing.** Do not create a replacement Firebase project.

## Windows / Android Studio

1. Extract this source project into a writable folder.
2. Open the **shuffle_slide project root** in Android Studio with the Flutter and Dart plugins.
3. Select the installed Flutter SDK and a JDK with `javac` (JDK 21 works here).
4. Install the Android SDK platforms and NDK requested by Gradle; accept SDK licenses with `flutter doctor --android-licenses`.
5. Run:

```powershell
flutter doctor -v
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

Expected APK: `build/app/outputs/flutter-apk/app-debug.apk`.
For other ABIs, omit `--target-platform` or use `flutter build apk --debug --split-per-abi`. The delivered evaluation APK is ARM64 only and uses a standard debug certificate. It does not target x86 Android emulators or ARM32-only phones.

Normal development uses Android's standard local debug key. In a restricted CI environment you can set `SHUFFLE_DEBUG_KEYSTORE` to an already-created standard debug keystore. This is unrelated to release signing.

## Connect the existing Firebase project

Offline gameplay works with no Firebase files. Google and cloud features display an unavailable message until configured.

1. Obtain the original project identity, existing `firebase_options.dart` if used, and the existing Android `google-services.json`. They were absent from this workspace. Never fabricate their contents.
2. Match `applicationId`, `namespace`, and MainActivity package/path to the original Android app. Check the corresponding iOS bundle ID.
3. Put the owner's matching `google-services.json` at `android/app/google-services.json`. The Google Services Gradle plugin is applied only when this file exists. Native initialization uses these Android-generated resources.
4. If the original app uses generated Dart options, preserve that file and update initialization to `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`, importing the real generated file. Native configuration is sufficient for this Android build. Do not invent a fallback FirebaseOptions.
5. For iOS, add the owner's `GoogleService-Info.plist` to the Runner target in Xcode and the existing `REVERSED_CLIENT_ID` URL scheme. Reuse the existing OAuth setup. Build on macOS; iOS was not compiled here.
6. Inspect Authentication → Sign-in method in the **existing** Firebase project. Google is already enabled according to the brief. Enable Anonymous only if it is currently disabled.
7. Run `cd android; .\gradlew signingReport` (PowerShell) and compare debug and release SHA-1/SHA-256 fingerprints with that existing Firebase Android app. Add missing fingerprints, then download its refreshed JSON if needed. Confirm an OAuth **web client** is present for Google ID tokens. No server client ID is invented or embedded by this app.
8. Review both the owner-only `/users/{uid}` block and `/weeklyLeaderboards/{week}/players/{uid}` block in `firestore.rules`. The latter permits authenticated reads and owner-only writes, including Firebase Anonymous players. **Merge both into the existing project's rules**, preserving unrelated collections. Do not overwrite existing production rules wholesale. No rules were deployed here.
9. On an actual device, verify guest login, fresh Google login, cancellation, anonymous upgrade, an existing-account merge, offline-to-online sync, and release-signed Google login.

### Data and merge policy

`users/{uid}` stores displayName, provider, lastLoginAt, `results`, and an idempotent `attempts` map. Result keys are `number_1` through `number_50` and `photo_1` through `photo_50`. Each stores score, stars, time, and moves. Merging preserves maximum score/stars and minimum completion time/moves independently. Unlocks and achievements are derived from completed-level records. Local writes happen first; failed sync leaves local data intact.

The compact document schema differs from the suggested subcollection layout but keeps modes independent. The attempt ledger grows with completed attempts; **migrate it to per-attempt subcollections before high-volume production use** to avoid Firestore's 1 MiB document limit. Weekly leaderboard scores are client-computed and can be forged; use server-side validation before treating rankings as competitive. The rules enforce entry ownership and schema but do not verify gameplay. Their Firebase Emulator/production behavior remains unverified.

Signing out retains device progress, as labeled in the UI. Connecting another Google account explicitly offers to merge that device progress. Imported photos remain local, including when scores synchronize to another device. Account deletion requires recent authentication; a failed deletion retains local progress. Cloud deletion and Firebase Auth deletion are separate service operations and must be tested against the real project.

## Release signing

Use the developer's existing production keystore. Do not reuse the evaluation debug certificate. Copy `android/key.properties.example` to `android/key.properties` locally and enter the actual key path/alias/passwords there. These files and keystores are gitignored and absent from this archive.

```powershell
flutter build apk --release --target-platform android-arm64
# Optional Play submission after device/release verification:
flutter build appbundle --release
```

The Gradle release configuration deliberately has no debug-signing fallback. Without the owner's key, a release artifact may be unsigned and must not be distributed. No signed production release is provided.

## Installation and real-device acceptance

```powershell
adb devices
adb -s YOUR_AUTHORIZED_DEVICE_SERIAL install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s YOUR_AUTHORIZED_DEVICE_SERIAL shell am start -n com.shuffleslide.shuffle_slide/.MainActivity
flutter test integration_test/game_flow_test.dart -d YOUR_AUTHORIZED_DEVICE_SERIAL
```

Use the actual package ID if restored from an existing app. For final acceptance, install the signed release instead of the debug APK and exercise both modes, real portrait/landscape/high-resolution gallery images, crop cancellation, timer expiry, hints, undo, resume after background/termination, offline progress, Google merge and sync, and a user-initiated WhatsApp share. Record the actual Android version and phone model. No physical device was accessible here.

## Tests and UI previews

```powershell
flutter analyze
flutter test
flutter test integration_test/game_flow_test.dart -d YOUR_DEVICE
# Explicit generation of rendered Flutter widget previews:
flutter test test/photo_test.dart --plain-name "renders home" --dart-define=RENDER_PREVIEWS=true --update-goldens
```

The visual test is skipped during the normal suite because it writes preview goldens and depends on rendering/fonts. `test/goldens` contains actual Flutter widget renders, not Android-device screenshots. Native gallery/crop/share integrations are mocked in automated tests; device behavior is not certified by those mocks.

## Source layout

- `lib/features/puzzle_engine/engine.dart`: level definitions, shuffle, moves, scoring, undo, serialization, bounded hints.
- `lib/data/progress.dart`: deterministic conflict reconciliation and mode-specific unlocking.
- `lib/data/store.dart`: Riverpod-provided observable store, local persistence, Firebase/auth, private photo storage.
- `lib/app.dart`: welcome, main menu, levels, local photo library/crop, settings, profile/statistics.
- `lib/features/game/game_screen.dart`: shared number/photo gameplay, lifecycle/timing, result and sharing.
- `test/`: engine, navigation, persistence, and mocked photo workflows.
- `integration_test/`: on-device number-game flow, supplied but not executed on a device here.

Manrope font is included under the SIL Open Font License in `assets/OFL.txt`. The built-in sample is generated locally in Dart. No user photograph or Firebase credential is bundled.
