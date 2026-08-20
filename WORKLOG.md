# Worklog — AI Usage Monitor

Updated: 2026-08-20

## Done

- [2026-08-20] v1 (desktop collector + LAN sync) built and verified against real data: 3,127 Command Code transcript events, Cursor `~/.omp/agent/agent.db` parsed. App bundled for Android.
- [2026-08-20] **PIVOT to phone-only** (user request: no desktop component — app pings account APIs directly). Approved plan: `~/.commandcode/plans/ai-usage-monitor-phone-only.md`.
- [2026-08-20] **Command Code API verified live**: `api.commandcode.ai` REST with `Authorization: Bearer <apiKey>` — `whoami`, `usage/summary?since=<ISO>`, `billing/credits` (5h + weekly windows with resetAt), `billing/subscriptions`. Key from `~/.commandcode/auth.json`.
- [2026-08-20] **Cursor API prototype solved**: `api2.cursor.sh` accepts plain HTTPS POST + `application/json` (Connect protocol) — no HTTP/2 or protobuf. Verified live: `DashboardService/GetMe`, `GetCurrentPeriodUsage`, `GetAggregatedUsageEvents`. Token from `cursorAuth/accessToken` in `globalStorage/state.vscdb`, or `cursor-agent login` device-OAuth.
- [2026-08-20] **PIVOT Expo → Flutter** (user: "expo makes no sense, I can't test it myself"). Flutter 3.32.4 installed to /opt (official tarball), Linux desktop target enabled — app runs as a window on this machine. `mobile/` (Expo) deleted; `flutter/` replaces it. Reason: Linux desktop target lets the user test locally with no phone/emulator.
- [2026-08-20] Flutter app complete: providers (commandcode REST + cursor Connect-JSON), SQLite snapshots (usage_snapshot + account, migration v2 adds models_json), token files chmod 600, Home/Accounts/History/Add screens. Seeded with real accounts via `flutter test tool/seed_test.dart` (FFI sqlite + data-dir override); UI verified by screenshots (dark theme, live numbers, charts, limit bars).
- [2026-08-20] **Cursor token + split accuracy** (user request): added `GetAggregatedUsageEvents` → per-model token breakdowns (input/output/cache) shown in "Top models"; included-usage split via plan's own percentages — `autoPercentUsed` (Auto models bar), `apiPercentUsed` (API models bar), `totalPercentUsed` (Included total bar), cap = includedSpend. Verified: auto $68.79/$70 (98%), api $44.73/$70 (64%), included $65.88/$70 (94%) — matches Cursor's UI numbers. Fixed protobuf int64-as-string casts (`_num` helper).

## Next

- Make the Linux window default taller (1822x508 tiling is awkward) — set a phone-ish default size, consider fixed window size.
- History tab: model/token detail per snapshot; pull-to-refresh wiring on desktop.
- Background/auto refresh; limit-exceeded notifications.
- Android build (`flutter build apk`) when the user wants to move to the phone.

## Notes

- Running as root here; all real data under `/home/bob2142`. Always run the app as bob (`sudo -u bob2142`), DISPLAY=:0 (Hyprland + Xwayland). Screenshots: `sudo -u bob2142 DISPLAY=:0 import -window <id> /tmp/x.png`.
- `cc` = gcc; Command Code CLI is `command-code` (v1.29.0). Cursor CLI: `~/.local/bin/cursor-agent`.
- Cursor API: tokens in JSON come as **strings** for int64 fields (inputTokens, billingCycleEnd) — must coerce. Plan percentages are authoritative for limit bars. aggregation `totalCents` includes bonus spend, so don't derive splits from it.
- Flutter: `databaseFactory = databaseFactoryFfi` is required on Linux desktop (not auto-registered). `path_provider` needs platform channels — tests override the data dir via `setOverrideDir`.
- Seed/refresh headless: `flutter test test/seed_test.dart --dart-define=CC_TOKEN=... --dart-define=CUR_TOKEN=...` (writes to the real app data dir).
