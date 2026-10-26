# How Mitra works

Notes so either of us can pick up any part. Last updated 24 Oct.

Three ways in, all using the same Firestore data (user `demo1`, Sheela):
- the Android app (Flutter, `app/`)
- the web app (`web/`, plain HTML/JS, also on Netlify)
- a phone call on Exotel, handled by Netlify functions in `netlify/`

A sale saved on a call shows up in the app within a few seconds.

## App sync
- The app keeps its own copy on the phone and starts from `assets/data/demo.json`.
- It talks to Firestore over REST (`lib/data/cloud.dart`). No Firebase SDK, no google-services.json.
- Saves go into an outbox first. If she's offline they wait and are sent in order later.
- Every 4 s it checks today's sales and `users/demo1.changedAt`. If the call changed something it reloads everything and shows "Added by phone call".
- If the demo month has no sales for today it adds a few (`Repo.ensureDemoToday`), so Home isn't ₹0 during the demo.
- Language is one field, `users/demo1.lang`. The EN/മല button in the app and key 8 on the call both change it.

## Phone call
Main has the simple keypad flow (`exotel-gather` + `exotel-save`): pick an item, type how many, save, hear the profit. Setup steps are in `exotel-setup.md`.

The full menu is on branch `hiba/exotel-full-call` (not merged yet):

| Key | |
|---|---|
| 1 | add a sale |
| 2 | add an expense |
| 3 | profit, monthly report, savings goal, bills, GST paid |
| 4 | schemes, buy together |
| 5 | change a price |
| 8 | Malayalam / English |
| 9 | repeat |
| 0 | finish (reads back all changes) |

Try it without a phone: `node netlify/lib/ivr-sim.js 1 1 12 0 0`

Every change from a call is saved with `via:"call"` and stamps `changedAt`.

## Schemes
`schemes.json` has 4 non-loan schemes, each checked on the official site (source + date in the file). Anything past `open_until` or marked as a loan is hidden. The app also shows PIB scheme news from the RSS feed, with loan news filtered out.

## Data
See PLAN.md §5. Profit for a month = that month's sales income minus that month's bills and purchases. Dart (`app/lib/logic/`) and JS (`web/js/calc.js`, `money.js`) do the same maths, and `test/logic_test.dart` checks they match.

## Run and test
```
python tools/serve.py          # web app on localhost:8080
python tools/sync_app_assets.py   # after changing web/data or web/audio
cd app
flutter run --release
flutter analyze
flutter test test/screens_test.dart test/logic_test.dart
flutter test test/sync_test.dart --dart-define=FIREBASE_PROJECT=test
flutter build apk --release --dart-define=MITRA_SITE=https://<site>.netlify.app --dart-define=FIREBASE_PROJECT=<id> --dart-define=FIREBASE_API_KEY=<key>
```
Netlify deploys on every push to main. Keys only go in Netlify env vars.

## Still to do
- Put the Firebase web config and site URL into the builds. Until then "Call me" says it's unavailable.
- Merge `hiba/exotel-full-call` (Fathima's files).
- `web/js/parse.js` on main doesn't get Malayalam endings like "ബിരിയാണിയും". The fix is on `hiba/twilio-call-flow`.
- `exotel-save` says "Saved" even when Firebase isn't connected.
- Twilio `voice`/`menu` on main are still placeholders.
- GST limits in `limits.json` need checking on gst.gov.in.
- The Malayalam call voice uses Microsoft's free read-aloud service. We need a proper TTS for a real pilot.
- Re-check the 4 schemes before any pilot.
