# Mitra — rules for every Claude session in this repo

Read `PLAN.md` before doing anything. It has the scope, file ownership, data format and timeline.

## The product in one line
Mitra lets any woman entrepreneur, even with a basic phone, say what she sold in her own Malayalam and know her real monthly profit, and when she can afford the auto she's saving for.

## Team
- **Fathima (fathima-004), Member A:** `money.html`, `schemes.html`, `bulk.html`, `support.html`, `js/money.js`, `data/schemes.json`, `data/ml.json` (all Malayalam text), `data/synonyms.json`, pitch.
- **Hiba (hibaNiz), Member B:** `index.html`, `setup.html`, `daily.html`, `profit.html`, `call.html`, `css/style.css`, `js/data.js`, `js/calc.js`, `js/parse.js`, `js/call.js`, `netlify/`, deployment.

**Only edit files you own.** If you need a change in someone else's file, write it in `docs/requests.md` and tell your teammate. Shared contracts (data format, `data.js` function names) are frozen after hour 1; changing them needs both people to agree.

## Stack
Plain HTML + CSS + JavaScript (ES modules, no build step, no framework). Firebase Firestore via the CDN modular SDK for data and live updates. Netlify for hosting (auto-deploys from `main`). Works on a phone browser first.

## Hard rules
- **No loans anywhere.** Mitra tracks EMIs she already pays and plans savings. It never offers, recommends or compares loans or lenders.
- **Never invent scheme eligibility, documents, tax limits or helpline numbers.** Only use values a person checked on an official site, with the source URL and date checked stored next to them.
- Tax and GST screens always say: guidance only, confirm with your Kudumbashree MEC or a tax consultant.
- **AI never does maths.** Profit, totals, GST and goals are plain JavaScript in `calc.js` / `money.js`. Speech parsing is rule-based first (`parse.js` + `data/synonyms.json`); an AI call is optional and must have a fallback.
- Numbers spoken by voice are always confirmed on the keypad before saving.
- The demo must work without Wi-Fi problems: pre-loaded demo data, keypad fallback, pre-rendered audio, `localStorage` fallback if Firestore is unreachable.
- Malayalam first, English second, on every screen. Big text and big buttons.

## Git
Pull before you start. Commit small, push at least every hour. Never force-push `main`. Never commit secrets (API keys go in Netlify environment variables, never in the repo).
