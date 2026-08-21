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

## v0.7.0 — Remaining-first + early warning — IN TREE 2026-08-21

1. **Night-ledger visuals** ✅ — remaining-first hero and gauges, banker's
   green / brass / carmine.
2. **Tiered alerts** ✅ — 80 / 90 / empty channels; partial sync still
   notifies.
3. **Leftover APIs** ✅ — OpenRouter day/week/month, Cursor plan + on-demand,
   OpenAI leftover line items, cache token split.
4. **Anthropic + DeepSeek** ✅ — admin usage/cost and prepaid balance.
5. **Trust** ✅ — Android Keystore tokens, `allowBackup=false`, masked keys,
   JSON backup, onboarding, GitHub update checker, widget tap, Sync now
   shortcut, launcher name UsageLedger.
6. **On-device checks** ⏳ — still need a sideload on the S23.

## v1.0.0 — Remaining

1. **Landing page refresh** — the night-ledger rewrite is drafted, but
   `docs/index.html` is root-owned in this checkout and needs a one-time
   ownership fix before it can be written.
2. **On-device verification** — notifications + widget on a real phone.
3. **Publish** — signed APK + GitHub Release v1.0.0.

### v1.0.0 implementation pass

The remaining app work is now in tree:

* Sync deltas show what changed since the previous capture.
* The medium widget lists the three hottest pools.
* Backups can be imported and API-key backups can be PBKDF2/AES-GCM
  passphrase protected.
* Settings includes an Android battery-optimization coach.
* The Sync now launcher shortcut performs an immediate refresh.
* Anthropic and DeepSeek use their own provider logos.

### Addendum — Apple packaging (v1.1.0, 2026-08-21)

User request overrode the "no iOS" line above: v1.1.0 adds iOS + macOS
targets, built on GitHub's macOS runners (no local Mac). Distribution stays
sideload-only: ad-hoc-signed macOS zip (Gatekeeper right-click Open) and an
unsigned ipa re-signed by AltStore/Sideloadly with the user's own Apple ID.
See `INSTALL-APPLE.md`. Background sync / notifications / widget remain
Android-only until Darwin equivalents are wired.

Explicitly out of scope for v1.0: Play Store, iOS, crash reporting
(conflicts with the "nothing leaves your phone" pitch), cloud sync.
