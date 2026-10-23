# Fathima's side: where things are (23 Oct, ~midnight)

Read this first on a new computer, together with CLAUDE.md and PLAN.md.

## Done
- **Web app** (root folder): home, setup, daily, profit, money (Money Health), join (sign-up demo incl. recorded Malayalam join-by-call). Illustrations in `js/art.js`, "Mitra noticed" insights in `js/insights.js`.
- **Flutter app** (`app/`): Home, Sales (keypad), Call, Profit, Money Health, Join (app sign-up + voice-call replay with `assets/audio/join/*.mp3`). Logic ported from calc.js / money.js / insights.js into `app/lib/logic/`. Data stays on the phone (shared_preferences) and starts from `assets/data/demo.json`. `flutter analyze` has no issues and the web build runs.
- Shared content lives in `data/` and `audio/`. After changing them run `python tools/sync_app_assets.py` to copy them into `app/assets/`.

## Not done yet
- Android APK build has not finished yet (first build was running when we switched computers).
- Flutter: live Firestore link for the phone-call update (needs Hiba's Firebase project + `google-services.json`), setup screen (products/bills/purchases), schemes, support, bulk pages.
- `data/limits.json`: GST limits still need checking on gst.gov.in (fill `checked_by`, `date_checked`).
- Slides, pitch, backup video.

## Set up Flutter on a new computer
1. `git clone https://github.com/fathima-004/mitra.git` (or `git pull`)
2. Install Flutter (stable) + Android SDK (Android Studio is the easy way) + JDK 17. Check with `flutter doctor`.
3. `cd app && flutter pub get && flutter run` (phone plugged in with USB debugging), or `flutter build apk --release`.
4. If Gradle downloads time out, the network may have broken IPv6: `android/gradle.properties` already has `systemProp.java.net.preferIPv4Stack=true`; also set the env var `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true` before building.
5. Web preview of the Flutter app: `flutter build web` then serve `app/build/web`; `?tab=0..4` opens a tab directly.
