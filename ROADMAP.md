# UsageLedger — Roadmap to v1.0

Direction: **sideload-only** distribution (GitHub Releases + in-app update
checker; no Play Store, no iOS). Command Code, Cursor, **OpenRouter**, and
**OpenAI platform** are implemented. Each phase shipped as one release.

---

## v0.4.0 — Trust & reliability — SHIPPED 2026-08-21

*Goal: the app behaves correctly on a phone for weeks, not just in a demo.*

1. **Account health surfacing** ✅ — per-account `sync_error` (db migration
   v4), SYNC FAILED state on cards, inline banner.
2. **Re-auth flow** ✅ — "Update key" dialog verifies before saving.
3. **Settings screen** ✅ — sync interval chips wired to
   `SyncController.setInterval`, notification toggle, about card.
4. **Real background sync** ✅ — workmanager periodic task; notifications +
   widget fed from the background task. minSdk 23.
5. **On-device checks** ⏳ — sideload and verify notifications + widget on a
   real phone.
6. **Provider tests** ✅ — HTTP fixtures per provider, db migration test.
7. **CI** ✅ — analyze + hermetic tests on push; signed APK on version tags.

## v0.5.0 — OpenRouter + OpenAI providers — SHIPPED 2026-08-21

1. **Registry metadata** ✅ — id/name/icon/keyHint/advisory keyPattern.
2. **OpenRouter** ✅ — Credits window (management key), key-quota window,
   /activity per-model history; graceful degradation on regular keys.
3. **OpenAI platform** ✅ — admin-key usage/costs endpoints, cursor
   pagination, month as uncapped window, line_item↔model cost matching.
4. **Add-account UX** ✅ — per-provider placeholder, instructions, advisory
   mismatch warning (non-blocking).
5. **Fixtures + tests** ✅ — 12 new provider tests.

## v0.6.0 — Insights & retention — SHIPPED 2026-08-21

1. **History upgrade** ✅ — 7D/30D/All range filter chips.
2. **Aggregates** ✅ — LAST 7/30 DAYS spend readout; cross-account top-models
   table with share bars.
3. **CSV export** ✅ — snapshots + per-model rows via share sheet.
4. **Home-screen widget** ✅ — NEXT WALL gauge fed by foreground + background
   syncs (on-device layout check pending).

## v1.0.0 — Release hardening

1. **In-app update checker** — GitHub Releases API, compare `versionCode`,
   banner + deep-link to the APK asset. The distribution channel *is* the
   app.
2. **Onboarding** — first-run screen: what the app does, privacy pitch
   (keys stay on device), add first account.
3. **State audit** — offline behavior, empty states per tab, error
   recovery paths.
4. **Landing page refresh** — real screenshots, provider list, changelog
   highlights per release.
5. **Version policy** — semver discipline, per-release changelog in the
   release notes.

Explicitly out of scope for v1.0: Play Store, iOS, crash reporting
(conflicts with the "nothing leaves your phone" pitch), cloud sync.
