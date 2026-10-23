# Mitra — team rules

Read `PLAN.md` before doing anything. It has the scope, file ownership, data format and timeline.

## The product in one line
Mitra lets any woman entrepreneur, even with a basic phone, say what she sold in her own Malayalam and know her real monthly profit, and when she can afford the auto she's saving for.

## Team
- **Fathima (fathima-004): app screens + content + pitch.** `css/style.css`, `index.html`, `setup.html`, `daily.html`, `profit.html`, `money.html`, `schemes.html`, `support.html`, `bulk.html`, `js/money.js`, `js/app.js`, `manifest.webmanifest`, `sw.js`, `icons/`, `tools/`, everything in `data/` and `audio/`, slides.

Local testing: `python tools/serve.py` (no-cache server on port 8080; the phone on the same Wi-Fi can open `http://<laptop-ip>:8080`). Every page must load `js/app.js` (it registers the service worker that makes Mitra an installable phone app).
- **Hiba (hibaNiz): call agent + backend.** `netlify/functions/*` (Twilio voice flow, Claude parsing, call-me), `call.html`, `js/call.js`, `js/data.js`, `js/calc.js`, `js/parse.js`, `package.json`, `netlify.toml`, Firebase and Netlify setup.

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
