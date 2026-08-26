# UsageLedger

Know before you hit the wall.

UsageLedger tracks what is left in every AI provider pool — Command Code, Cursor, OpenRouter, OpenAI, Anthropic, DeepSeek — and how long your current pace will carry you. Multi-account, on-device, no desktop piece, no cloud.

## Dashboard

The home tab opens as a dashboard — amount left, burn rate, hottest pool and runway — before the wall card and providers. Each provider is a collapsible row: tap to expand its runway lanes. The Ledger wordmark collapses on scroll (`USAGE` fades, `Ledger` shrinks) to keep content in view.

**Tokens:** Apple HIG dark elevations (`#000 → #1C1C1E → #2C2C2E → #38383A`), system blue `#0A84FF` as cold, warm amber `#FF9F0A`, hot `#FF3B30`. `12px` card radius, `8px` controls, `Archivo` + `JetBrains Mono`.

## Features

- **Multi-provider, multi-account** — any number per provider; Home aggregates.
- **Live limits** — 5-hour/weekly/monthly windows, Cursor included splits, extra/bonus spend.
- **Per-model tokens + cost** — input/output/cache, share bars.
- **KPI strip** — left total, burn $/day (7d), hottest pool, runway wall.
- **Runway** — hatched dead zone + reset gate; provider rows gate the lanes.
- **Cost over time** — daily snapshots → chart, pace, 30-day budget overlay.
- **Private** — keys in OS Keystore/Keychain; SQLite on device; only network calls are to the provider APIs.

## Platforms

| Platform | Windows shown |
|---|---|
| **Command Code** | 5h + weekly + monthly, credits, burst, tokens |
| **Cursor** | included pool (auto/api/total), extra/bonus, per-model cache |
| **OpenRouter** | credits + key quota windows, per-model history |
| **OpenAI** | monthly cost windows, per-model usage |
| **Anthropic / DeepSeek** | balance windows, admin usage/costs |

## Install

Download the APK from **Releases** (Android 8+). `usageledger-vX.Y.Z.apk` is the upload-keystore signed build; CI’s debug APK is draft-only.
- macOS: `UsageLedger-vX.Y.Z-macos.zip` (ad-hoc signed, right-click Open on first run)
- iOS: `UsageLedger-vX.Y.Z-ios-unsigned.ipa` — re-sign with AltStore/Sideloadly + your Apple ID.

## Getting your tokens

- **Command Code:** `~/.commandcode/auth.json` → `apiKey` (`user_…`), or `/login`.
- **Cursor:** `cursor-agent login` on desktop → paste the token.

## Privacy

Keys live in `flutter_secure_storage` (Keystore/Keychain). Usage lives in SQLite. `allowBackup=false`. No auth or usage leaves the device except the API calls you authorize. Backups can be passphrase-encrypted (PBKDF2/AES-GCM).

## Development

```bash
cd flutter
flutter run -d linux   # desktop
flutter build apk      # android (needs ANDROID_HOME, JDK 17)
flutter test
```

Themelab HTML previews live under `themelab/` (served at `8765` in dev). They share the same Horizon data and demo themes/layouts/brand without touching the app.

## License

MIT
