# Worklog — AI Usage Monitor

Updated: 2026-08-21

## Done

- [2026-08-20] v1 (desktop collector + LAN sync) built and verified against real data: 3,127 Command Code transcript events, Cursor `~/.omp/agent/agent.db` parsed. App bundled for Android.
- [2026-08-20] **PIVOT to phone-only** (user request: no desktop component — app pings account APIs directly). Approved plan: `~/.commandcode/plans/ai-usage-monitor-phone-only.md`.
- [2026-08-20] **Command Code API verified live**: `api.commandcode.ai` REST with `Authorization: Bearer <apiKey>` — `whoami`, `usage/summary?since=<ISO>`, `billing/credits` (5h + weekly windows with resetAt), `billing/subscriptions`. Key from `~/.commandcode/auth.json`.
- [2026-08-20] **Cursor API prototype solved**: `api2.cursor.sh` accepts plain HTTPS POST + `application/json` (Connect protocol) — no HTTP/2 or protobuf. Verified live: `DashboardService/GetMe`, `GetCurrentPeriodUsage`, `GetAggregatedUsageEvents`. Token from `cursorAuth/accessToken` in `globalStorage/state.vscdb`, or `cursor-agent login` device-OAuth.
- [2026-08-20] **PIVOT Expo → Flutter** (user: "expo makes no sense, I can't test it myself"). Flutter 3.32.4 installed to /opt (official tarball), Linux desktop target enabled — app runs as a window on this machine. `mobile/` (Expo) deleted; `flutter/` replaces it. Reason: Linux desktop target lets the user test locally with no phone/emulator.
- [2026-08-20] Flutter app complete: providers (commandcode REST + cursor Connect-JSON), SQLite snapshots (usage_snapshot + account, migration v2 adds models_json), token files chmod 600, Home/Accounts/History/Add screens. Seeded with real accounts via `flutter test tool/seed_test.dart` (FFI sqlite + data-dir override); UI verified by screenshots (dark theme, live numbers, charts, limit bars).
- [2026-08-20] **Cursor token + split accuracy** (user request): added `GetAggregatedUsageEvents` → per-model token breakdowns (input/output/cache) shown in "Top models"; included-usage split via plan's own percentages — `autoPercentUsed` (Auto models bar), `apiPercentUsed` (API models bar), `totalPercentUsed` (Included total bar), cap = includedSpend. Verified: auto $68.79/$70 (98%), api $44.73/$70 (64%), included $65.88/$70 (94%) — matches Cursor's UI numbers. Fixed protobuf int64-as-string casts (`_num` helper).
- [2026-08-20] **Android packaging**: installed Android SDK (platform 36, build-tools, cmdline-tools) at /opt/android-sdk + JDK 17 (/usr/lib/jvm/java-17-openjdk). DB layer now uses native `sqflite` on Android (FFI only on Linux); added INTERNET permission; generated `upload-keystore.jks` + `key.properties` (both gitignored) wired into build.gradle.kts release signing. Built signed `app-release.apk` (21.9MB), copied to repo root as `ai-usage-monitor.apk`.
- [2026-08-20] **GitHub publish**: repo **SamiulH25/UsageLedger** (public). Landing page in `docs/` → GitHub Pages at https://samiulh25.github.io/UsageLedger/. Release **v0.1.0** with `ai-usage-monitor.apk` attached. Name: **UsageLedger**.
- [2026-08-20] **v0.2.0**: Accounts First light mobile UI overhaul — bottom-sheet add account; Cursor shows one included $70 pool with Auto/API shares plus extra/bonus spend; Command Code billing-period totals (weekly pool, monthly period+credits, 5-hour burst ready state, relative reset times). Signed APK built and attached to GitHub Release **v0.2.0**.
- [2026-08-21] **v0.3.0**: MVVM refactor — `AppScope` DI + `SyncController`
  (configurable auto-refresh interval, persisted in settings) + per-tab
  ViewModels; new Account Detail screen (pools, trend, token split,
  expandable snapshots); burn-rate `PoolOutlook` projections on the hero
  gauge ("runs out ~Nd before reset"); Space Grotesk + JetBrains Mono fonts.
  **Fixed daily-spend series**: was plotting per-day MAX(account period
  total) as if cumulative — now per-account day-over-day delta of period
  totals, clamped at resets, zero-filled, summed across accounts; pace =
  trailing 3-day mean blended with today's partial (capped 3x, skipped
  before 6am). Pull-to-refresh now responds to mouse drag on desktop
  (custom ScrollBehavior). Limit-exceeded Android local notifications
  (flutter_local_notifications 19.5, desugaring enabled, POST_NOTIFICATIONS;
  deduped per account+window+reset in settings; desktop no-op). Verified on
  desktop with screenshots; 10/10 tests; Pages site confirmed live.

## Next

- Verify limit notifications fire on a real device after sideloading v0.3.0.
- Android: app icon polish (low priority; sideload only, no Play Store).
## Notes

- Running as root here; all real data under `/home/bob2142`. Always run the app as bob (`sudo -u bob2142`), DISPLAY=:0 (Hyprland + Xwayland). Screenshots: `sudo -u bob2142 DISPLAY=:0 import -window <id> /tmp/x.png`.
- gh auth is under **bob's keyring** (SamiulH25) — run all `gh`/git push as bob, not root.
- Android build env: `JAVA_HOME=/usr/lib/jvm/java-17-openjdk ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk` (system java is 1.8). `android/local.properties` points at /opt/android-sdk.
- Cursor API: tokens in JSON come as **strings** for int64 fields (inputTokens, billingCycleEnd) — must coerce. Plan percentages are authoritative for limit bars. aggregation `totalCents` includes bonus spend, so don't derive splits from it.
- Flutter: `databaseFactory = databaseFactoryFfi` only on Linux desktop (Android uses native sqflite). `path_provider` needs platform channels — tests override the data dir via `setOverrideDir`.
- Seed/refresh headless: `flutter test test/seed_test.dart --dart-define=CC_TOKEN=... --dart-define=CUR_TOKEN=...` (writes to the real app data dir).
- Release APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`; copies to repo root. Signing keystore `android/upload-keystore.jks` (passwords in `android/key.properties`) — both gitignored, don't lose them.
