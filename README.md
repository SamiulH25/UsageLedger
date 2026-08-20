# UsageLedger

Track your AI usage across every account and platform — straight from your phone.

**Command Code · Cursor · more coming** — add your accounts once, and UsageLedger pulls live usage directly from each platform's API. No desktop app, no servers, no cloud — your data stays on your device.

## Features

- **Multi-platform, multi-account** — any number of accounts per platform; Home aggregates across all of them.
- **Live plan limits** — Command Code's 5-hour/weekly/monthly windows, and Cursor's included-usage splits (Auto vs API vs total) with exact used/cap and reset times.
- **Per-model token breakdowns** — input, output, and cache tokens per model (Cursor), with cost.
- **Cost over time** — snapshots accumulate on each refresh and build a history chart.
- **Private by design** — tokens are stored encrypted on-device; nothing leaves your phone except the API calls to the platforms themselves.

## Platforms

| Platform | What it shows |
|---|---|
| **Command Code** | Requests, tokens (in/out), cost, credits, 5-hour + weekly + monthly limit windows |
| **Cursor** | Plan spend, included-usage split (auto / API / total), per-model tokens + cache, cost |

## Install

Download the latest APK from the **Releases** page and install it (enable "Install unknown apps" for your file browser). Android 8+.

- `ai-usage-monitor.apk` — release build, signed.

## Getting your tokens

- **Command Code**: the key is in `~/.commandcode/auth.json` (field `apiKey`, starts `user_`), or run `/login` in Command Code.
- **Cursor**: run `cursor-agent login` on your desktop (it prints a URL to approve), then paste the token into the app.

## Privacy

Credentials are stored in the OS secure store (SecureStore). Usage data lives in an on-device SQLite database. The only network calls are to `api.commandcode.ai` and `api2.cursor.sh` with your own credentials — nothing is sent anywhere else.

## Development

```bash
cd flutter
flutter run -d linux   # desktop
flutter build apk      # android
```

## License

MIT
