# UsageLedger — Roadmap to v1.0

Direction: **sideload-only** distribution (GitHub Releases + in-app update
checker; no Play Store, no iOS). Command Code + Cursor exist; **OpenRouter**
and **OpenAI platform** are the next providers. Each phase ships as one
release.

---

## v0.4.0 — Trust & reliability

*Goal: the app behaves correctly on a phone for weeks, not just in a demo.*

1. **Account health surfacing** — refresh failures are currently invisible:
   `RefreshResult.error` exists but nothing renders it. Persist last sync
   status per account (error + timestamp), show a warning badge on the
   account card and an `InlineMessage` on the Accounts tab; flag accounts
   stale for > 2× sync interval.
2. **Re-auth flow** — "Update key" action on a failing account, reusing the
   add-account bottom sheet prefilled with the provider. Stale Cursor
   tokens / revoked Command Code keys must be recoverable in-app.
3. **Settings screen** — wire the existing but unreachable
   `SyncController.setInterval` (choices already defined: off/5/15/30/60),
   notification on/off toggle, per-account remove with confirm. No settings
   screen exists today.
4. **Real background sync** — the current `Timer` dies when Android kills
   the process. Add `workmanager` periodic task (15-min Android floor),
   battery-optimization exemption prompt, and evaluate limit notifications
   from the background task so they fire with the app closed.
5. **On-device notification check** — sideload current build, verify the
   limit notification fires and dedupes across resets (open item from
   v0.3.0).
6. **Provider tests** — HTTP-level unit tests for `commandcode.dart` and
   `cursor.dart` against captured response fixtures (int64-as-string cases
   included); db migration test.
7. **CI** — GitHub Actions: `flutter analyze` + `flutter test` on push;
   signed release APK build on version tag, attached to the draft release.

Size: L. Most of it is plumbing that already half-exists.

## v0.5.0 — OpenRouter + OpenAI providers

*Goal: the "every platform" pitch starts being true.*

1. **Registry → real plugin metadata**: per-provider id, name, icon,
   credential format hint, key validation regex (registry is currently a
   hardcoded 2-element list with an asset-path switch).
2. **OpenRouter** — key `sk-or-…`; credits endpoint for balance +
   `/api/v1/activity` for per-model usage/cost. Windows: none (prepaid
   credits) → render as a balance card, not limit bars.
3. **OpenAI platform** — key `sk-…`; usage/cost endpoints (verify current
   API shape at build time — billing endpoints have moved before).
   Monthly-window model like Command Code's period totals.
4. **Add-account UX** — per-provider instructions (where the key lives),
   format validation before submit, provider icon.
5. **Provider fixtures + tests** for both new providers.

Size: M per provider once the registry work is done.

## v0.6.0 — Insights & retention

*Goal: reasons to open the app daily beyond checking limits.*

1. **History upgrade** — date-range filter, per-day drill-down (all
   snapshots that day), model-usage trend over time per account.
2. **Aggregates** — 7/30-day spend cards, cross-account per-model cost
   table (data already in `usage_snapshot.models_json`).
3. **CSV export** — snapshots + per-model usage, share sheet.
4. **Android home-screen widget** — next wall (pool, %, reset) + daily
   pace, updated by the workmanager task. Marquee feature for this app
   category.

Size: L.

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
