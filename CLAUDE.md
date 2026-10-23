# Mitra — rules for every Claude session in this repo

Read `PLAN.md` before doing anything. It has the scope, file ownership, data format and timeline.

## The product in one line
Mitra lets any woman entrepreneur, even with a basic phone, say what she sold in her own Malayalam and know her real monthly profit, and when she can afford the auto she's saving for.

## Team (swapped 24 Oct, ~00:30 — see PLAN.md §2a)
- **Fathima (fathima-004): the phone call + content + pitch.** The call agent, moving to **Exotel** (Indian number; Twilio stays as backup): `netlify/functions/*` (voice flow, parsing, call-me), `call.html`, `js/call.js`, `js/parse.js`. Plus everything in `data/` and `audio/` (Malayalam text, synonyms, schemes, voice clips), `tools/`, slides, pitch, backup video.
- **Hiba (hibaNiz): the Flutter app + backend setup.** `app/` (Flutter: screens, data on the phone, Firestore link), the web screens (`*.html` except `call.html`, `css/`, `js/app.js`, `js/art.js`, `js/insights.js`, `js/money.js`, `manifest.webmanifest`, `sw.js`, `icons/`), `js/data.js`, `js/calc.js`, `package.json`, `netlify.toml`, Firebase and Netlify setup.

Local testing (web): `python tools/serve.py` (no-cache server on port 8080). Flutter: `cd app && flutter run`; after changing `data/` or `audio/`, run `python tools/sync_app_assets.py`. Status and setup notes: `docs/fathima-status.md`.

**Only edit files you own.** If you need a change in someone else's file, write it in `docs/requests.md` and tell your teammate. Shared contracts (data format, `data.js` function names) are frozen after hour 1; changing them needs both people to agree.

## Stack
Plain HTML + CSS + JavaScript (ES modules, no build step, no framework). Firebase Firestore via the CDN modular SDK for data and live updates. Netlify for hosting (auto-deploys from `main`) and Netlify Functions (Node) for the backend. The phone call uses Twilio Programmable Voice (TwiML from Netlify Functions, `<Gather>` with `language="ml-IN"`); speech text becomes `[{product, qty}]` using word lists first (`data/synonyms.json`), then a free AI backup chosen by the `AI_PROVIDER` env var (`gemini` default, `groq`, or `claude` only if we get API credit). AI calls use plain `fetch`, no SDKs, with a 4-second timeout. Functions write to Firestore with `firebase-admin`. Works on a phone browser first.

## Hard rules
- **No loans anywhere.** Mitra tracks EMIs she already pays and plans savings. It never offers, recommends or compares loans or lenders.
- **Never invent scheme eligibility, documents, tax limits or helpline numbers.** Only use values a person checked on an official site, with the source URL and date checked stored next to them.
- Tax and GST screens always say: guidance only, confirm with your Kudumbashree MEC or a tax consultant.
- **AI never does maths.** Profit, totals, GST and goals are plain JavaScript in `calc.js` / `money.js`. Speech parsing is word lists first (`parse.js` + `data/synonyms.json`); the AI backup is optional and always falls back to the keypad. Only demo data is ever sent to a free AI tier.
- Numbers spoken by voice are always confirmed on the keypad before saving.
- The demo must work without Wi-Fi problems: pre-loaded demo data, keypad fallback, pre-rendered audio, `localStorage` fallback if Firestore is unreachable.
- Malayalam first, English second, on every screen. Big text and big buttons.

## Git
Pull before you start. Commit small, push at least every hour. Never force-push `main`. Never commit secrets (API keys go in Netlify environment variables, never in the repo).
