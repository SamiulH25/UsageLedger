# Installing UsageLedger on macOS & iOS

Every version tag attaches Apple builds to the GitHub **Releases** page:

| File | Platform | Signature |
|---|---|---|
| `UsageLedger-vX.Y.Z.apk` | Android 8+ | release-signed |
| `UsageLedger-vX.Y.Z-macos.zip` | macOS 10.15+ | ad-hoc signed |
| `UsageLedger-vX.Y.Z-ios-unsigned.ipa` | iOS 15.6+ (iPhone/iPad) | unsigned |

No paid Apple Developer certificate is used anywhere, so both Apple builds
need a one-time trust step below.

## macOS

1. Download `UsageLedger-vX.Y.Z-macos.zip` and unzip it.
2. Drag **UsageLedger.app** into `/Applications`.
3. First launch is blocked by Gatekeeper (ad-hoc signature, unnotarized).
   Either right-click the app → **Open** → **Open**, or run:

   ```sh
   xattr -cr /Applications/UsageLedger.app
   ```

   Needed once; launches normally afterwards.

Proper Developer-ID signing + notarization requires a paid Apple Developer
account ($99/yr); the CI pipeline can be extended with certs + `notarytool`
if that ever happens.

## iOS

The ipa has no signature at all (`--no-codesign`), so iOS refuses direct
installs — including via Finder/Apple Configurator unless re-signed. Any of
these tools re-signs the ipa on your own device with your own Apple ID:

- **AltStore / SideStore** — free Apple ID, keeps re-signing every 7 days
  automatically while the AltServer/SideStore helper runs.
- **Sideloadly** — free Apple ID, 7-day validity, manual re-sign.

Steps (AltStore example):

1. Install AltServer on your computer and AltStore on the iPhone.
2. Download `UsageLedger-vX.Y.Z-ios-unsigned.ipa`.
3. Open AltStore on the phone → `+` → pick the ipa.
4. Trust your developer profile under Settings → General → VPN & Device
   Management, then launch.

With a paid account you get better options: sign in Xcode ("Automatically
manage signing" with a registered device) or ship via Ad Hoc / TestFlight.

## What works / doesn't on Apple today

- Sync, accounts, history, insights, CSV export, encrypted backup: full parity.
- Background periodic sync: Android only (WorkManager). On iOS/macOS the app
  syncs while open; `workmanager_apple` BGTask support is a future step.
- Limit notifications: Android only so far (Darwin notification init pending).
- Home-screen widget: Android only; an iOS WidgetKit extension would need an
  Xcode target that only builds on macOS hardware.
