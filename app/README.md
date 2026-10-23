# Mitra, the Flutter app (Hiba)

Home, Sales keypad, Call, Profit, Money Health, Join, plus Products & bills (setup), Schemes, Buy together and Support from the Home tiles.

## Build and install
```
cd app
flutter pub get
flutter build apk --release ^
  --dart-define=MITRA_SITE=https://<site>.netlify.app ^
  --dart-define=FIREBASE_PROJECT=<firebase project id> ^
  --dart-define=FIREBASE_API_KEY=<firebase web api key>
```
The APK is `build/app/outputs/flutter-apk/app-release.apk`. Copy it to the phone and open it, or use `flutter install` with the phone plugged in.
Without the three values the app still works fully on the phone. "Call me" then says the call isn't available, and nothing syncs.

## How the live update works
- Data lives on the phone (shared_preferences) and starts from `assets/data/demo.json`.
- With `FIREBASE_PROJECT` set, the app talks to Firestore's REST API (`lib/data/cloud.dart`). There is no Firebase SDK and no `google-services.json`.
- Every 4 seconds it checks **today's** sales. A sale saved by the phone call (`via:"call"`) appears and a "Added by phone call" message shows. Older months are pulled on start and when the app comes back to the front.
- Changes made in the app go to Firestore straight away. Offline changes wait in an outbox and are sent in order when the connection returns. Firestore never overwrites changes that haven't reached it yet.
- "Reset demo" resets the phone and Firestore.
- Firestore rules must allow the demo paths (`users/demo1/**`, `bulk_requests/**`), for example test mode.

## Content rules
Schemes and helplines show only entries from `assets/data/schemes.json` and `assets/data/support.json` that have a `source_url` and `date_checked`. Until those files exist, the screens say the details are still being checked.

## Tests
```
flutter test test/screens_test.dart                                  # every screen at 360 px, setup forms save
flutter test test/sync_test.dart --dart-define=FIREBASE_PROJECT=test # Firestore sync against a fake server
```

## Build problems seen on this laptop
- Java could not download Gradle 9.3.1, but `curl` could. Fix: download the zip with curl into `%USERPROFILE%\.gradle\wrapper\dists\gradle-9.3.1-all\<hash>\gradle-9.3.1-all.zip` and build again.
- Set `JAVA_TOOL_OPTIONS=-Djava.net.preferIPv4Stack=true` before building.
