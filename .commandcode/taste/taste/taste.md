# Taste
- Prefers apps to be entirely self-contained on the phone — no desktop collector, companion server, or LAN-sync component. Confidence: 0.9
- Prefers fetching data by pinging the platform's API directly with the user's account credentials, rather than parsing local logs/files on a companion device. Confidence: 0.85
- Prefers mobile app UI/UX to feel native on the platform, not web-like. Confidence: 0.9
- Wants apps to support multiple accounts and multiple platforms via an extensible design, not a single account/tenant. Confidence: 0.8
- Prefers development frameworks and targets that let them run and test the app on their own machine (e.g., a Linux desktop target), rather than a dev loop that requires a separate phone/emulator they can't use — explicitly switched from Expo to Flutter for this reason ("expo makes no sense to me right now, i cant test it myself"). Confidence: 0.9
- Wants the approach explained and agreed before work proceeds — explicitly asks to be walked through how something will be done (e.g., "explain how we're going to package this as an android app") rather than just having the agent execute. Confidence: 0.7
- Communicates casually and informally ("alright solid job mate") and expects plain, conversational explanations rather than stiff/formal prose. Confidence: 0.6
- End goal is running the app on the user's own physical Android device (Samsung S23), not just the Linux desktop test target — packaging must lead to an installable Android build for their phone. Confidence: 0.85
- Prefers distributing the app via a public GitHub repo with a GitHub Pages landing page and a GitHub Releases page to download the APK from — self-service web download rather than USB/adb install. Confidence: 0.75
- Wants projects to have a creative, branded name (e.g., "UsageLedger") rather than a generic/technical one, and delegates the naming/branding choice to the agent. Confidence: 0.6
- Uses omp (a CLI agent configured under ~/.omp) as their agent tool and OpenRouter as their model provider — wants ox-alpha as the default model. Confidence: 0.5


