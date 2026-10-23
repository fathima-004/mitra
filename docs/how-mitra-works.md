# How Mitra works

Mitra helps a woman who runs a small food business at home know her real profit. She can use it three ways: the **Android app**, the **web app** in a phone browser, or a **phone call** from any basic phone. All three read and write the same data in **Firestore**, so a sale she says on a call shows up in the app within a few seconds.

Updated 24 Oct 2026, after an end-to-end test of every part. Owners follow CLAUDE.md: Hiba owns the Flutter app, the web screens and the data layer. Fathima owns the phone call, the content in `data/` and `audio/`, and `tools/`.

---

## 1. The big picture

```
 Android app (Flutter, app/)        Web app (HTML + JS, root)        Phone call (Exotel)
   phone storage + outbox             browser storage                  keypad menu, spoken prompts
          │  Firestore REST                │  Firebase JS SDK                 │  Exotel calls our URLs
          │  (checks every 4 s)            │  (live listeners)                ▼
          │                                │                     Netlify Functions (netlify/)
          └──────────────► Firestore: users/demo1/… ◄─────────── firebase-admin
                                  ▲
                      Official sources: PIB RSS feed (scheme news),
                      jansuraksha.gov.in / udyamregistration.gov.in (checked schemes)
```

- **Hosting:** Netlify serves the web app (the repo root) and runs the backend functions. A push to `main` deploys.
- **Database:** Firestore holds one demo user, `demo1`, for Sheela, a biriyani seller in Kozhikode.
- **Offline first:** both apps keep a full copy on the phone, so the demo works without Wi-Fi. Changes made offline are sent when the connection returns.
- **No AI does maths.** Profit, totals, GST and goals are plain code. Sentences are understood with word lists. Every spoken number is confirmed before saving.

---

## 2. Workflows

### 2.1 Judge opens the app
1. The app starts. `main.dart` loads the Malayalam/English text, her chosen language and the saved data.
2. If her demo data has no sales today, the app adds a few sales from earlier today (`Repo.ensureDemoToday`). The example month ends before the demo day, and this stops Home from showing ₹0.
3. The login screen offers **Try the demo** (one tap), phone + PIN (98765 43210 / 1234), a language choice, and **New here? Join**, a walkthrough of how a new woman signs up.

### 2.2 She adds a sale in the app
1. Home → **Add income** → pick the item → − 10 + → **Save** (`screens/add.dart`).
2. `Repo.add('sales', …)` saves it on the phone at once, so the screen updates immediately. It also puts it in the **outbox**.
3. The outbox sends it to Firestore. If she's offline, it waits and is sent in order later. Firestore never overwrites changes that haven't been sent yet.
4. The web app, if open, sees it through its Firestore listener.

### 2.3 She speaks instead (Speak tab)
1. The mic uses Android speech recognition (`ml-IN`), via the `speech_to_text` package.
2. `logic/parse.dart` reads the sentence with word lists:
   - **sales:** "ഇന്ന് 12 ബിരിയാണിയും 30 ചപ്പാത്തിയും വിറ്റു"
   - **expenses:** "200 രൂപയ്ക്ക് അരി വാങ്ങി"
3. She sees what was understood and taps **Save**. Tapping a line opens the normal form with it filled in, so she can correct it.

### 2.4 She uses the phone call (any phone)
1. She calls the ExoPhone, or taps **Mitra, call me** in the app (`call-me` function).
2. Exotel runs a loop of two boxes: **Gather** (`exotel-ivr?do=ask`, what to say) → **Passthru** (`exotel-ivr?do=hear`, the keys she pressed) → back to Gather.
3. The menu, in `netlify/lib/ivr.js`:

   | Key | What she can do |
   |---|---|
   | 1 | add a sale |
   | 2 | add an expense |
   | 3 | today's profit, the monthly report, savings goal (add savings), monthly bills (add a bill), GST paid |
   | 4 | schemes she can join, and buy together (join a group) |
   | 5 | change a price |
   | 8 | Malayalam ⇄ English |
   | 9 | repeat |
   | 0 | finish |

4. Each confirmed change is written to Firestore at once with `via:"call"`. It also stamps `users/demo1.changedAt`.
5. The app reads that stamp every 4 seconds. When it changes, the app reloads everything and shows "Added by phone call".
6. At the end, Mitra reads back every change made on the call.

### 2.5 Language
- **One setting:** `users/demo1.lang` is shared by the app and the call.
- **In the app:** the EN / മല button on every screen switches the language and saves it. The whole screen redraws in place.
- **On a call:** pressing 8 switches the call's language and saves it, and the app follows.
- **Malayalam voice:** Malayalam call prompts contain live numbers, so they are spoken with Microsoft's neural Malayalam voice, generated per step (`netlify/lib/tts.js`). If that fails, the prompt is spoken in English.

### 2.6 Government schemes
- **Checked list:** "Schemes you can join now" comes from `app/assets/data/schemes.json`. It has 4 non-loan schemes, each checked on its official page with the source and date.
- **Hidden entries:** a scheme past its `open_until` date, or marked as a loan, is never shown.
- **Live news:** below the list, scheme news from the official PIB RSS feed, with anything about loans filtered out. The last result is kept for offline use.
- **Everywhere:** the app, the web page and the call all use the same checked list.

---

## 3. Data (Firestore, PLAN.md §5)

| Path | Shape |
|---|---|
| `users/demo1` | `{name, name_ml, place, place_ml, lang, changedAt}` |
| `users/demo1/products/{id}` | `{name_ml, name_en, price}` |
| `users/demo1/sales/{id}` | `{date "YYYY-MM-DD", time?, product, qty, via: app\|call\|web-call}` |
| `users/demo1/purchases/{id}` | `{date, time?, cat?, item, item_ml, qty, unit, amount, gst}` (expenses) |
| `users/demo1/bills/{id}` | `{month "YYYY-MM", type, label_en, label_ml, amount, due_day?}` (incl. EMIs she already pays) |
| `users/demo1/goals/{id}` | `{name_en, name_ml, target, saved, monthly}` |
| `users/demo1/history/{month}` | `{month, income, spending, gst_paid}`: finished months as totals |
| `bulk_requests/{id}` | `{user, name, month, item, item_ml, qty, unit, place}` |
| `calls/{CallSid}` | call session: menu position, language, list of changes |
| `call_audio/{CallSid}` | the current spoken Malayalam prompt (MP3) |

Profit for a month = income from that month's sales − (that month's bills + purchases).

---

## 4. Every file

### Root
| File | What it is |
|---|---|
| `CLAUDE.md`, `PLAN.md` | team rules, scope, owners, data contract, timeline |
| `README.md` | short project description |
| `package.json` | backend dependencies: `firebase-admin`, `twilio` (+ `msedge-tts` on the call branch) |
| `netlify.toml` | publish the repo root, functions in `netlify/functions` |
| `manifest.webmanifest`, `sw.js` | installable web app; `sw.js` caches pages and data so the web app opens offline |

### Web app (root HTML + `js/`, `css/`)
| File | What it is |
|---|---|
| `index.html` | home: today's sales (live), this month's profit, savings goal, "Mitra noticed", Call me, Reset demo |
| `setup.html` | products and prices, monthly bills, purchases with GST |
| `daily.html` | tap a product, type how many: today's sales |
| `profit.html` | month profit, chart, best sellers, where money went, tips |
| `money.html` | Money Health: savings goal, EMI affordability (never a loan), GST status and GST paid |
| `schemes.html` | schemes she can join now (checked list), with documents and source |
| `bulk.html` | buy-together board: groups by item and month, join with an amount |
| `support.html` | someone to talk to: shows helplines only from a checked `data/support.json` |
| `join.html` | how a new woman joins (app or by a recorded Malayalam call) |
| `call.html` + `js/call.js` | browser call page (backup): speak or type, read-back, save |
| `js/data.js` | data layer: Firestore (when configured) + browser storage, live listeners, queued writes |
| `js/calc.js` | profit maths: month income/spending/profit, breakdown, averages, worst month, year turnover |
| `js/money.js` | goal plan, EMI check, GST status, GST paid |
| `js/insights.js` | "Mitra noticed": best weekday, cost rises, pace, small-but-valuable, big cost |
| `js/parse.js` | word-list sentence parser for `call.html` |
| `js/app.js` | shared helpers: Malayalam/English text, money format, bottom menu, toast; registers `sw.js` |
| `js/art.js`, `js/icons.js` | inline SVG drawings (food, auto, palm) and line icons |
| `css/style.css` | the "kasavu" web look |

### Android app (`app/`, Flutter)
| File | What it is |
|---|---|
| `lib/main.dart` | start-up, login gate, the five tabs (Home, Records, Speak, Products, More), redraw on language change |
| `lib/config.dart` | site URL and Firebase project/key, passed at build time with `--dart-define` |
| `lib/i18n.dart` | every on-screen word in Malayalam and English (one at a time), the `?` help texts, dates |
| `lib/ui/kit.dart` | the design kit: colours, text styles, page frame, cards, big buttons, stepper, EN/മല switch, `?` button |
| `lib/data/repo.dart` | the app's data: phone copy, outbox, Firestore check every 4 s, full reload when the call changes data, demo "today" sales, language sync |
| `lib/data/cloud.dart` | Firestore over REST (no Firebase SDK): read, query today's sales, write, delete, reset |
| `lib/data/services.dart` | PIB scheme news (RSS, loan filter, offline copy), "call me" request |
| `lib/logic/calc.dart` | profit maths, same as `js/calc.js` (tested to give identical numbers) |
| `lib/logic/money.dart` | goal plan, EMI check, GST, same as `js/money.js` |
| `lib/logic/insights.dart` | "Mitra noticed" tips, same as `js/insights.js` |
| `lib/logic/parse.dart` | understands spoken/typed sales and expenses with word lists |
| `lib/logic/spend.dart` | expense categories (ingredients, gas, packaging…) and spending per category |
| `lib/screens/login.dart` | demo login, phone + PIN, language, join link |
| `lib/screens/home.dart` | today's money, Call me, four big tiles, this month, savings goal, tips under the bell |
| `lib/screens/add.dart` | Add income and Add expense forms |
| `lib/screens/speak.dart` | Speak to add: mic, examples, confirm, save; type instead |
| `lib/screens/records.dart` | all / income / expense, by day, tap to delete with undo |
| `lib/screens/products.dart` | products and prices, add / edit |
| `lib/screens/profit.dart` | My profit (month picker, cards, "where I spent" donut, tips) and the Monthly report (weekly bars, best sellers, 6 months) |
| `lib/screens/more.dart` | More menu, business details, monthly bills, someone to talk to, help |
| `lib/screens/tools.dart` | savings goal + EMI check, GST & tax calculator, government schemes, buy together |
| `lib/screens/join.dart` | the join walkthrough (uses the older look in `theme.dart`, `widgets/common.dart`, `strings.dart`) |
| `lib/widgets/art.dart` | food and auto drawings |
| `assets/data/` | demo month, text, GST limits, join call script (copied from `data/`), and `schemes.json` (checked schemes) |
| `assets/audio/join/`, `assets/fonts/` | join-call clips; Noto Sans Malayalam and Plus Jakarta Sans fonts |
| `android/` | Android project: internet + microphone permissions, Kotlin plugin, release shrink rules |
| `test/screens_test.dart` | every screen fits a 360 px phone in both languages; add income/expense save; GST maths; language switch redraws; call button; schemes; "Savings goal" label |
| `test/sync_test.dart` | Firestore sync against a fake server: seed, live call sale, offline outbox, reset, unique ids, call changes reload, language both ways |
| `test/logic_test.dart` | Dart maths = JS maths on the demo data; categories add up; sentence parser |
| `test/render_shots.dart` | renders every screen to `build/shots/` for a visual check |

### Backend (`netlify/`, Fathima's on main)
| File | What it is |
|---|---|
| `functions/exotel-gather.js`, `exotel-save.js` | the current one-sale Exotel call: pick item → how many → save → profit |
| `functions/call-me.js` | rings `DEMO_PHONE` through Exotel |
| `functions/seed-demo.js` | one-time load of the demo month into Firestore (never overwrites) |
| `functions/ping.js` | health check; `?check=1` lists which settings are present and whether Firestore answers |
| `functions/voice.js`, `menu.js` + `lib/twiml.js` | early Twilio menu (placeholders; the full Twilio flow is on branch `hiba/twilio-call-flow`) |
| `lib/exotel.js`, `lib/firestore.js` | Exotel request helpers; firebase-admin connection |

On branch **`hiba/exotel-full-call`** (to merge): `functions/exotel-ivr.js` (the full menu endpoint), `lib/ivr.js` (the menu, both languages), `lib/ivr-store.js` (Firestore or in-memory demo), `lib/tts.js` (Malayalam voice), `lib/ivr-sim.js` (try a call from the command line), `docs/exotel-full-call.md`.

### Content and tools (Fathima)
| File | What it is |
|---|---|
| `data/demo.json` | Sheela's example month (made by `tools/make_demo.py`) |
| `data/ml.json` | Malayalam/English text for the web app |
| `data/limits.json` | GST registration limits (still to be checked on gst.gov.in) |
| `data/join_call.json`, `audio/` | recorded join call and call prompts (edge-tts) |
| `tools/serve.py` | local no-cache web server on port 8080 |
| `tools/sync_app_assets.py` | copies `data/` and `audio/` into the Flutter app |
| `tools/make_*.py` | make the demo data, icons and voice clips |
| `docs/` | setup notes (Exotel), status, requests between teammates, this file |

---

## 5. Rules the code enforces (CLAUDE.md)
- **No loans.** No screen or call option offers loans. Scheme news mentioning loans is filtered out. The EMI check only says whether an EMI she's considering is affordable.
- **No invented facts.** Schemes and helplines are shown only with an official source URL and a check date. GST limits say "not yet checked" until someone confirms them.
- **Tax screens are guidance only.** They say to confirm with a Kudumbashree MEC or a tax consultant.
- **AI never does maths.** All figures are plain code. Dart and JS give identical results, which a test checks.
- **Numbers are confirmed.** Spoken numbers are confirmed before saving: on screen in the app, by keypad on the call.
- **Works without Wi-Fi.** There is a phone copy, an outbox, a keypad fallback and an offline web cache.
- **Malayalam first.** It's the default language, with English one tap away everywhere.

---

## 6. Run, test, build
```
python tools/serve.py                                   # web app on http://localhost:8080
cd app && flutter run --release                         # app on a USB-connected phone
cd app && flutter analyze
cd app && flutter test test/screens_test.dart test/logic_test.dart
cd app && flutter test test/sync_test.dart --dart-define=FIREBASE_PROJECT=test
cd app && flutter build apk --release --dart-define=MITRA_SITE=https://<site>.netlify.app --dart-define=FIREBASE_PROJECT=<id> --dart-define=FIREBASE_API_KEY=<key>
node netlify/lib/ivr-sim.js 1 1 12 0 0                  # try the full call (branch hiba/exotel-full-call)
```
Deploy: push to `main`, and Netlify builds. Secrets (Exotel, Firebase service account) live only in Netlify environment variables.

---

## 7. End-to-end test results (24 Oct 2026)

| Area | Result |
|---|---|
| Flutter analyze | no issues |
| App screens (both languages, 360 px) | 10 / 10 pass |
| Sync with Firestore (fake server), 3 runs | 8 / 8 pass each run |
| Maths parity Dart = JS, parser | 3 / 3 pass |
| Web pages in headless Chrome | 10 / 10 load, 0 console errors |
| Backend functions on main (no secrets) | all respond as designed |
| Full call menu (branch), English + Malayalam | every feature saves; retried requests apply once |
| Release APK | builds (53.5 MB), runs on a vivo I2410 and the Pixel 9a emulator |

## 8. Open items
- **Firebase web config and the Netlify site address** are not yet in the builds. Until they are, the app and web app work on the phone only, and "Call me" says the call is unavailable.
- **Merge `hiba/exotel-full-call`** (Fathima's files) and build its three-box Exotel flow.
- **`js/parse.js` on main** doesn't understand Malayalam words with endings ("ബിരിയാണിയും"). The fix is on `hiba/twilio-call-flow`.
- **`exotel-save` / `exotel-gather`** say "Saved" even when Firebase isn't connected and nothing was stored.
- **Twilio `voice` / `menu`** on main are still placeholders.
- **`data/limits.json`** GST limits still need a person's check on gst.gov.in.
- **The Malayalam call voice** uses Microsoft's free read-aloud service (unofficial). Use a paid text-to-speech service for a real pilot.
- **The four schemes** were read from official pages on 24 Oct. A person should re-check them before the pilot.
