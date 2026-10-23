# Mitra — full hackathon plan (v2: real phone call agent)

MakeHerHack 2026, CITTIC CUSAT. About 16 hours of building. Two people, one repo: https://github.com/fathima-004/mitra

---

## 1. What we are building

**One line:** Mitra lets any woman entrepreneur, even with a basic phone, say what she sold in her own Malayalam and know her real monthly profit, and when she can afford the auto she's saving for.

**The highlight: a real phone call.** Tap "Call me" → the demo phone rings → Mitra speaks Malayalam → she says *"innu 12 biriyani poyi"* → Mitra reads it back → she presses 1 → **the laptop app updates live during the call** → she presses 2 and hears her monthly profit.

**Demo story:** Sheela sells biriyani from home in Kozhikode → logs today's sales by phone call → laptop updates → hears her profit → Money Health shows 60% to her auto, an EMI check, GST status and GST paid → a scheme with a document checklist → 4 women nearby buy rice together.

---

## 2. Work division

### Hiba: call agent + backend (the highlight)
Everything that makes the phone call work, end to end, plus Firebase and deployment.
- Twilio voice flow (Netlify Functions returning TwiML): greet → menu → sales → confirm → save → profit → schemes → support → goodbye
- Claude parsing: Malayalam/Manglish speech text → `[{product, qty}]` using her product list
- Firestore writes from the call (Firebase Admin), so the app updates live
- `js/data.js` (shared data helpers) and `js/calc.js` (profit maths) used by both the call and the app
- "Call me" endpoint the app button uses
- Browser call page `call.html` as the backup, using the same parse + save logic
- Netlify + Firebase setup, environment variables, deployment

### Fathima: the app + content + pitch
Every screen the judges see on the laptop, all Malayalam text, the demo data and the pitch.
- `css/style.css` (the look), `index.html` (home with live today's sales + profit + "Call me" button)
- `setup.html` (products, bills incl. EMIs, purchases with GST), `daily.html` (tap + keypad)
- `profit.html` (profit, chart, tips), `money.html` (goals, EMI check, GST)
- `schemes.html`, `support.html`, `bulk.html`
- `data/demo.json`, `data/ml.json`, `data/synonyms.json`, `data/schemes.json`, `data/limits.json`
- Malayalam voice clips (edge-tts) that Hiba's call plays
- Slides, pitch, backup video

**Why this split:** the call agent is the riskiest part, so Hiba gives it full attention. Nobody waits on the other after hour 1.

### What you need from each other (and when)
| From | To | What | By |
|---|---|---|---|
| Hiba | Fathima | `js/data.js` + `js/calc.js` with the API in §5, Firebase connected | **H1** |
| Fathima | Hiba | `data/demo.json` (Sheela's products, bills, purchases, sales) | **H1** |
| Fathima | Hiba | `data/synonyms.json` first version (product words, "sold" words, numbers) | **H3** |
| Fathima | Hiba | Call voice clips in `audio/` (list in §7) | **H5** |
| Hiba | Fathima | `/.netlify/functions/call-me` endpoint for the "Call me" button | **H6** |

---

## 3. Scope

| Tier | Feature | Owner |
|---|---|---|
| **Must** | Real phone call: menu, speech → Claude parse → read-back → keypad confirm → save → live app update | Hiba |
| **Must** | Press 2 on the call: hear this month's profit | Hiba |
| **Must** | Browser call page (backup, same logic) | Hiba |
| **Must** | Setup, daily sales, monthly profit screens | Fathima |
| **Must** | Money Health: savings goal, EMI affordability, GST status + GST paid | Fathima |
| **Must** | Schemes: 3 hand-checked non-loan schemes with document checklist | Fathima |
| **Small** | Call: press 3 schemes, 4 support, 9 person | Hiba |
| **Small** | Support page (Tele-MANAS 14416), bulk-buy board with grouped demo data | Fathima |
| **Pitch only** | Indian IVR number (needs KYC), FSSAI tracker, reminders, slow-month warning, reports, blog | — |

**Not building:** login, loans, own AI model, hardware, filing tax.

---

## 4. Before the event (today)

⚠️ **First check the rules:** can anything be built before the start? If not, do only account setup, no code.

**Hiba**
- [ ] Accept the GitHub invite → `git clone https://github.com/fathima-004/mitra.git`
- [ ] **Twilio** trial account → get a phone number → **Verified Caller IDs: add every demo phone** (yours, Fathima's) → Voice **Geo Permissions: enable India**
- [ ] **Anthropic API key** at console.anthropic.com, add about $5 credit
- [ ] **Firebase** project (free Spark plan) → Web app config → Firestore in test mode, region `asia-south1` → Project settings → Service accounts → generate a private key (JSON, keep it secret)
- [ ] **Netlify**: import `fathima-004/mitra`, publish dir `/`, no build command. Add environment variables: `ANTHROPIC_API_KEY`, `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_NUMBER`, `FIREBASE_SERVICE_ACCOUNT` (the JSON), `DEMO_PHONE`
- [ ] Twilio number → Voice webhook: `https://<site>.netlify.app/.netlify/functions/voice` (POST)

**Fathima**
- [ ] `pip install edge-tts` and test one Malayalam clip
- [ ] Verify on official sites (URL + date): Tele-MANAS 14416; GST registration limits and food GST rate (gst.gov.in); 3 non-loan schemes with documents
- [ ] Notes from women you spoke to: products, prices, bills, the words they use for "sold" and for numbers
- [ ] Message a Kudumbashree MEC/CDS about a free 30-unit pilot

---

## 5. Shared contracts (frozen at H1)

### Firestore
```
users/demo1                    { name:"Sheela", place:"Kozhikode", lang:"ml", phone }
users/demo1/products/{id}      { name_ml, name_en, price, cost? }
users/demo1/bills/{id}         { month:"2026-10", type:"gas"|"rent"|"emi"|..., amount, due_day? }
users/demo1/purchases/{id}     { date, item, qty, unit, amount, gst? }
users/demo1/sales/{id}         { date:"2026-10-23", product:"p1", qty, via:"app"|"call"|"web-call" }
users/demo1/goals/{id}         { name_ml, name_en, target, saved, monthly }
users/demo1/words/{id}         { word, product }        // personal words learned on calls
calls/{callSid}                { state, pending:[{product,qty}], updatedAt }   // call session
bulk_requests/{id}             { user, month, item, qty, unit, place }
```

### `js/data.js` (Hiba)
```js
export const USER = 'demo1';
export async function get(col)              // users/demo1/{col} → array
export async function add(col, obj)         // → id
export async function update(col, id, obj)
export async function remove(col, id)
export function listen(col, cb)             // live updates; returns unsubscribe
export async function loadDemo()            // reset demo1 from data/demo.json
export async function getBulk(), addBulk(obj)
// localStorage fallback with the same shapes if Firestore is unreachable
```

### `js/calc.js` (Hiba) — shared by app screens and the call
```js
monthIncome(sales, products, month)   monthSpending(bills, purchases, month)
monthProfit(...)  breakdown(...)  avgMonthlyProfit(..., months=3)  yearTurnover(sales, products, fyStart)
```

### `js/money.js` (Fathima)
```js
goalPlan(goal, avgProfit)  emiCheck(newEmi, avgProfit, worstMonthProfit)
gstStatus(turnover, limits)  gstPaid(purchases, fyStart)
```

### Netlify Functions (Hiba)
```
POST /.netlify/functions/voice      Twilio webhook: greet + main menu (Gather digits+speech)
POST /.netlify/functions/menu       routes the pressed key
POST /.netlify/functions/sales      Gather speech (language ml-IN) → parse → read back
POST /.netlify/functions/confirm    1 = save to Firestore, 2 = try again / keypad
POST /.netlify/functions/profit     plays/says this month's profit
POST /.netlify/functions/parse      { text, products } → [{product, qty}] (Claude; used by call + call.html)
POST /.netlify/functions/call-me    starts an outbound call to DEMO_PHONE (button on index.html)
```

---

## 6. Time planner (H0 = hacking starts)

| Time | Hiba (call agent + backend) | Fathima (app + content) |
|---|---|---|
| **H0–H1** | Firebase connected; push `js/data.js`, `js/calc.js`; Netlify deploy working; `package.json` with `twilio`, `firebase-admin`, `@anthropic-ai/sdk` | Push `css/style.css`, `index.html` shell, `data/demo.json` (Sheela's month). **Both: freeze §5 contracts.** |
| **H1–H3** | `voice` + `menu`: Twilio calls the verified phone, Mitra greets and reads the menu, keypad works | `setup.html` + `daily.html` on Firestore; `synonyms.json` v1 to Hiba by H3 |
| **H3–H5** | `sales` + `parse`: speech (ml-IN) → Claude → `[{product, qty}]`; rule-based fallback with `synonyms.json`; read-back | `profit.html`: totals, chart, tips. Generate all call voice clips, push to `audio/` by H5 |
| **H5–H7** | `confirm` saves to Firestore with `via:"call"`; `profit` speaks profit; **first full test: phone call → laptop updates live** | `money.html` + `js/money.js`: goal, EMI check, GST cards |
| **H7–H9** | `call-me` endpoint; press 3/4/9; play Fathima's clips; handle silence, unclear speech, wrong product | `index.html`: live today's sales + profit (`listen`), "Call me" button wired to `call-me` |
| **H9–H11** | `call.html` browser backup using the same `parse` + save | `schemes.html` + `schemes.json`, `support.html`, `bulk.html` |
| **H11–H12** | **Together: full demo run 3 times** (phone + laptop). List every bug. | |
| **H12–H13** | Fix call bugs only; tune synonyms with real test sentences | Fix screen bugs; Malayalam everywhere; "Reset demo" button; slides |
| **H13** | 🧊 **FEATURE FREEZE** | |
| **H13–H14** | Record the **backup video** of the full call demo | Finish slides, evidence slide, pilot ask |
| **H14–H16** | Rehearse the demo twice with Fathima; keep phone charged, hotspot ready | Rehearse the 3-minute pitch twice |

**Sleep (if overnight):** never both at once. Fathima naps H8–H9.5, Hiba naps H9.5–H11 (after the call works end to end).

---

## 7. The call agent in detail (Hiba)

**Flow**
1. `call-me` → Twilio `calls.create({ to: DEMO_PHONE, from: TWILIO_NUMBER, url: …/voice })`.
2. `voice`: play `audio/greet.mp3` + `audio/menu.mp3`, `<Gather input="dtmf speech" numDigits="1" language="ml-IN">`.
3. Key 1 → `sales`: play `audio/ask-sales.mp3`, `<Gather input="speech" language="ml-IN" speechTimeout="auto">`.
4. Twilio posts `SpeechResult` → `parse`:
   - First try rule-based matching with `data/synonyms.json` against her products (fast, free, no network to Claude).
   - If not confident, call Claude (Haiku-class model) with her product list; it must return JSON `[{product, qty}]` only. Claude never does maths.
   - Save pending items in `calls/{CallSid}`.
5. Read back: "12 biriyani, 30 chapathi, alle? Shari aanel 1, thettaanel 2." (`<Say language="ml-IN">` or clips + numbers)
6. `confirm`: 1 → write each item to `users/demo1/sales` with `via:"call"` → **laptop updates live** → play `saved.mp3`, back to menu. 2 → "number amarthuka" keypad entry.
7. Key 2 → `profit`: compute with `calc.js` → speak "Ee maasam ningalude laabham ₹X".
8. Key 3 → top scheme title. Key 4 → Tele-MANAS 14416 message (offer `<Dial>`). Key 9 → team number.

**Voice clips Fathima makes (edge-tts, `ml-IN-SobhanaNeural`):** `greet`, `menu`, `ask-sales`, `not-understood`, `ask-qty`, `saved`, `profit-intro`, `scheme-1`, `support`, `person`, `goodbye`. Dynamic parts (numbers, product names) use Twilio `<Say>` in Malayalam if a Malayalam voice is available on the account; test this in H1–H3. If not, say numbers with English `<Say>` (people mix English numbers anyway).

**Things to know**
- Trial calls play a short "trial account" message first and can only call **verified** numbers. That's fine for the demo; upgrading (about $20) removes it.
- Twilio needs a public URL: test on the deployed Netlify site (every push redeploys in about a minute).
- Keep every function fast (well under 10 s). Claude Haiku-class responses are about a second.
- Log every call's speech text to Firestore so Fathima can improve `synonyms.json` from real tests.

**Backup:** `call.html` in the browser: same menu, Chrome Web Speech `ml-IN` + keypad, same `parse` and save. If the venue's phone signal fails, demo this.

---

## 8. Money Health (Fathima)

- **Goal:** "Auto ₹40,000. Saved ₹24,000 (60%). ₹5,000/month → ready by March."
- **EMI check:** new EMI vs average profit and worst month. Never suggests a lender or loan.
- **GST:** GST paid this year (sum of `purchase.gst` from bills); registration needed? (yearly sales vs limit in `limits.json`); estimate if registered later. Footer: guidance only, confirm with MEC / tax consultant, gst.gov.in link + date checked.

---

## 9. Git workflow
```bash
git pull
git add <your files only>
git commit -m "call: confirm saves to firestore"
git push
```
Commit small, push at least every hour. Only edit your own files; ask in `docs/requests.md`. Secrets go in Netlify environment variables, never in the repo.

---

## 10. 3-minute demo

| Time | What happens |
|---|---|
| 0:00 | Problem: Sheela's story, real numbers from your calls |
| 0:25 | Laptop: tap **"Call me"** → phone rings on the table, on speaker |
| 0:35 | Press 1 → "innu 12 biriyani poyi" → read-back → press 1 → **laptop updates live** |
| 1:05 | Press 2 → profit spoken in Malayalam; laptop shows breakdown + tip |
| 1:25 | Money Health: 60% to her auto, EMI check, GST paid + "no registration needed yet" |
| 1:55 | Schemes: one scheme with document checklist |
| 2:10 | Bulk-buy + support (10 s) |
| 2:20 | Evidence from the women you called |
| 2:35 | Business: free for women; Kudumbashree / CSR pays per unit; 30-unit pilot ask. Next: Indian IVR number (after KYC), FSSAI, reminders |

---

## 11. Risks and fallbacks

| Risk | Fallback |
|---|---|
| Phone signal / Twilio fails at the venue | `call.html` browser call page; backup video |
| Malayalam speech misheard | Read-back + keypad confirm; practised demo sentence; synonyms tuned from test calls |
| Claude API slow or down | Rule-based parser first; Claude only when unsure |
| Live update fails | Refresh button on the laptop |
| Wi-Fi fails | Phone hotspot; demo data pre-loaded |
