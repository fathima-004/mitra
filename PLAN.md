# Mitra — full hackathon plan

MakeHerHack 2026, CITTIC CUSAT. About 16 hours of building. Two people, one repo: https://github.com/fathima-004/mitra

---

## 1. What we are building

**One line:** Mitra lets any woman entrepreneur, even with a basic phone, say what she sold in her own Malayalam and know her real monthly profit, and when she can afford the auto she's saving for.

**Demo story (one woman, one flow):** Sheela sells biriyani from home in Kozhikode → she "calls" Mitra and says *"innu 12 biriyani"* → the laptop app updates by itself → she hears her monthly profit in Malayalam → Money Health shows she's 60% of the way to her auto, an EMI check, and that she doesn't need GST yet (but has paid ₹X GST inside her purchases) → she finds a scheme with a document checklist → 4 women nearby can buy rice together.

### Scope

| Tier | Feature | Owner | Est. |
|---|---|---|---|
| **Must** | Setup: products + prices, monthly bills (incl. existing EMIs), stock purchases (with optional GST from bill) | Hiba | 2 h |
| **Must** | Daily sales: tap product → keypad qty; shows today's total | Hiba | 1.5 h |
| **Must** | Monthly profit: income − spending, breakdown chart, rule-based tips, profit read aloud | Hiba | 2.5 h |
| **Must** | Call page: IVR-style keypad menu, Malayalam voice prompts, speech → confirm → save | Hiba | 3.5 h |
| **Must** | Live sync: call saves → laptop updates by itself (Firestore `onSnapshot`) | Hiba | 1 h |
| **Must** | Money Health: savings goal, EMI affordability, GST status + GST paid | Fathima | 3.5 h |
| **Must** | Schemes: 3 hand-checked non-loan schemes, "how it helps you", document checklist | Fathima | 2 h |
| **Small** | Support: kind message + one-tap call Tele-MANAS 14416 | Fathima | 0.5 h |
| **Small** | Bulk-buy board: grouped demo data ("4 women in Kozhikode need rice → save ₹X"); add form only if time | Fathima | 1.5 h |
| **Small** | All Malayalam text, synonym lists, demo data for Sheela | Fathima | 2 h |
| **Pitch only** | FSSAI tracker, reminders, slow-month warning, shareable report, blog, real phone number | — | — |

**Not building:** login, loans, own AI model, hardware, real phone line, filing tax.

---

## 2. Your machines

| | Fathima | Hiba |
|---|---|---|
| Laptop | Lenovo, i5-1135G7 (11th gen), Iris Xe | i5 12th gen, RTX 3050 |
| RAM / disk | 16 GB, 106 GB free | 16 GB, 512 GB SSD |
| Installed | Node 24, Python 3.11, Git, VS Code, GitHub CLI | (check: Node, Python, Git, VS Code) |

Both are plenty. Nothing runs a local AI model, so the GPU is not needed. Keep Chrome open (Web Speech for Malayalam works best in Chrome).

---

## 3. Before the event starts (today)

⚠️ **First, check the rules:** can anything be built before the start? If not, do only the account setup below, no code.

**Fathima**
- [ ] `pip install edge-tts` (for Malayalam voice clips)
- [ ] Verify on official sites and note URL + date: Tele-MANAS 14416; GST registration limits (goods / services) and the restaurant/food GST rate on gst.gov.in; 3 non-loan schemes with document lists
- [ ] Notes from any women you spoke to (products, prices, bills, what words they use for "sold", numbers)
- [ ] Message a Kudumbashree MEC/CDS contact about a free 30-unit pilot

**Hiba**
- [ ] Accept the GitHub invite, then `git clone https://github.com/fathima-004/mitra.git`
- [ ] Create a **Firebase** project (free Spark plan) → add a Web app → create **Firestore** in test mode, region `asia-south1` (Mumbai). Save the web config.
- [ ] Create a **Netlify** account → "Import from Git" → pick `fathima-004/mitra` → publish directory `/` (root), no build command. Every push to `main` now deploys.
- [ ] Optional: an Anthropic or Gemini API key, only if we want AI parsing (rule-based parsing works without it).

---

## 4. File ownership

```
mitra/
├── index.html          Hiba     home: today's sales, profit snapshot, links to every page
├── setup.html          Hiba     products, bills, purchases (gst field)
├── daily.html          Hiba     log today's sales
├── profit.html         Hiba     monthly profit + chart + tips + audio
├── call.html           Hiba     IVR-style call page
├── money.html          Fathima  Money Health: goals, EMI check, GST
├── schemes.html        Fathima  schemes + document checklist
├── bulk.html           Fathima  bulk-buy board
├── support.html        Fathima  Tele-MANAS + kind message
├── css/style.css       Hiba     shared look (Fathima reads, never edits)
├── js/data.js          Hiba     Firestore + localStorage helpers (frozen API, see §5)
├── js/calc.js          Hiba     pure functions: totals, profit, breakdown
├── js/parse.js         Hiba     speech text → [{product, qty}] using synonyms
├── js/call.js          Hiba     call page logic
├── js/money.js         Fathima  goals, EMI, GST maths (pure functions)
├── data/demo.json      Fathima  Sheela's month (products, bills, purchases, sales)
├── data/schemes.json   Fathima  hand-checked schemes
├── data/ml.json        Fathima  every Malayalam/English string, keyed
├── data/synonyms.json  Fathima  product + "sold" + number words per dialect
├── data/limits.json    Fathima  GST limits/rates with source URL + date checked
├── audio/*.mp3         Fathima  pre-rendered Malayalam clips (edge-tts)
├── netlify/functions/  Hiba     optional AI parse function
└── docs/requests.md    both     "please change X in your file" notes
```

---

## 5. Shared contracts (freeze in hour 1)

### Firestore layout
```
users/demo1                         { name:"Sheela", place:"Kozhikode", lang:"ml" }
users/demo1/products/{id}           { name_ml, name_en, price, cost? }
users/demo1/bills/{id}              { month:"2026-10", type:"gas"|"rent"|"emi"|..., amount, due_day? }
users/demo1/purchases/{id}          { date:"2026-10-03", item, qty, unit, amount, gst? }
users/demo1/sales/{id}              { date:"2026-10-23", product:"p1", qty, via:"app"|"call" }
users/demo1/goals/{id}              { name_ml, name_en, target, saved, monthly }
bulk_requests/{id}                  { user, month:"2026-11", item, qty, unit, place }
```
Schemes, Malayalam text, synonyms and limits are static JSON files in `data/`, not Firestore.

### `js/data.js` API (Hiba writes, both use)
```js
export const USER = 'demo1';
export async function get(col)               // → array of docs in users/demo1/{col}
export async function add(col, obj)          // → id
export async function update(col, id, obj)
export async function remove(col, id)
export function listen(col, callback)        // live updates; returns unsubscribe
export async function loadDemo()             // wipes demo1 and loads data/demo.json
export async function getBulk() / addBulk(obj)
```
If Firestore fails to load, every function falls back to `localStorage` with the same shapes.

### `js/calc.js` (Hiba) and `js/money.js` (Fathima): pure functions, no Firestore inside
```js
// calc.js
monthIncome(sales, products, month)      monthSpending(bills, purchases, month)
monthProfit(...)                          breakdown(...)       avgMonthlyProfit(..., months=3)
yearTurnover(sales, products, fyStart)
// money.js
goalPlan(goal, avgProfit)       // → { monthsLeft, readyBy, percent }
emiCheck(newEmi, avgProfit, worstMonthProfit)   // → { percentOfProfit, shortfallInWorstMonth }
gstStatus(turnover, limits)     // → { needed, percentOfLimit, yearsToLimit }
gstPaid(purchases, fyStart)     // → total of purchase.gst this financial year
```

### Page conventions
Every page: `<link rel="stylesheet" href="css/style.css">`, `<script type="module">`, a top bar with back button, Malayalam heading with English under it, bottom nav to Home / Daily / Profit / Money / Call.

---

## 6. Timeline (hours from the start, H0 = hacking begins)

| Time | Hiba | Fathima |
|---|---|---|
| **H0–H1** | Push `style.css`, `data.js`, `calc.js` skeleton, `index.html` shell, Firebase connected, Netlify live. **Freeze contracts.** | `data/demo.json` (Sheela's month), `data/ml.json` first pass, `data/limits.json`. Generate the first audio clips. |
| **H1–H4** | `setup.html` + `daily.html` working on Firestore | `money.html` + `money.js`: goal card, EMI check, GST card |
| **H4–H7** | `profit.html`: totals, chart, tips, audio | `schemes.html` + `schemes.json` (3 schemes, checklist) |
| **H7–H10** | `call.html`: keypad menu, prompts, speech → `parse.js` → confirm → save; live update on laptop | `support.html`, `bulk.html` (grouped demo data), `synonyms.json`, all Malayalam text, remaining audio |
| **H10–H12** | **Merge + test together on one phone + one laptop.** Fix bugs. Load demo data. | |
| **H12–H13** | Polish: big buttons, Malayalam everywhere, "Reset demo" button | Slides (6–7) |
| **H13** | 🧊 **FEATURE FREEZE.** Nothing new after this. | |
| **H13–H16** | Rehearse the demo twice, record the backup video, fix only demo-breaking bugs | Rehearse the pitch twice, final slide with evidence + pilot ask |

Sleep: if the event is overnight, each take one 1.5-hour nap at different times (e.g. Hiba H8–H9.5 after the call page skeleton, Fathima H9.5–H11 before merge), never both at once.

---

## 7. The call page in detail

1. Big phone-style screen, green "call" button → Mitra greets: "Namaskaram Sheela, Mitra-yilekku swagatham."
2. Menu clip: 1 = sales, 2 = profit, 3 = schemes, 4 = support, 9 = person. Keypad or voice.
3. **Press 1:** Chrome Web Speech (`lang = 'ml-IN'`) listens → text → `parse.js` matches against **her** products using `synonyms.json` (biriyani/biriyaani/beeryani, vittu/poyi, Malayalam + English number words) → reads back "12 biriyani, alle? Shari aanel 1, thettaanel 2." → press 1 → `add('sales', {..., via:'call'})`.
   - Anything unclear → "biriyani ethra? number amarthuka" → keypad.
   - No mic / no Chrome → keypad only: product number, then quantity.
4. **Press 2:** plays the profit clip + shows the number on screen. (Pre-render clips for the demo amounts before and after the logged sale.)
5. **Press 3:** reads the top scheme title. **Press 4:** opens `support.html`. **Press 9:** shows the team helpline number.

**The wow moment:** phone on `call.html`, laptop on `index.html`. When she confirms, the laptop's sales and profit change by themselves (`listen('sales', ...)`).

AI parsing (optional): a Netlify function that turns the text into `[{product, qty}]` using her product list. Only call it if `parse.js` fails; cache demo responses; never block the demo on it.

---

## 8. Money Health (Fathima) in detail

- **Goal card:** "Auto: ₹40,000. Saved ₹24,000 (60%). Set aside ₹5,000/month → ready by March." Uses `avgMonthlyProfit` from `calc.js`.
- **EMI check:** she types a new EMI amount → "This is 45% of your average profit. In your slow month (June) you'd be short by ₹2,000." Never suggests a lender or a loan.
- **GST card:**
  1. "GST you've paid this year: ₹X" (sum of `purchase.gst`, read from her bills)
  2. "Do you need GST registration?" yearly sales vs the limit in `limits.json` → "₹11.2 lakh of ₹20 lakh. Not needed yet. About 3 years at this pace."
  3. "If you register later: about ₹X/month GST on sales" (clearly an estimate)
  4. Footer: guidance only, confirm with MEC / tax consultant, link to gst.gov.in, date checked.
- Optional if time: FSSAI status line ("Food sellers need at least basic FSSAI registration") with the official link.

---

## 9. Audio (Fathima)

```bash
pip install edge-tts
edge-tts --voice ml-IN-SobhanaNeural --text "നമസ്കാരം ഷീല, മിത്രയിലേക്ക് സ്വാഗതം." --write-media audio/greet.mp3
```
Clips: greet, menu, confirm, ask-qty, saved, profit-before, profit-after, scheme-1, support, goodbye. Every clip also has its text on screen.

---

## 10. Git workflow

```bash
git pull                      # before starting, and before every push
git add <your files only>
git commit -m "money: goal card"
git push
```
- Commit small, push at least every hour.
- Never edit the other person's files. Use `docs/requests.md`.
- If `git pull` shows a conflict in a file you don't own, keep their version.

---

## 11. 3-minute demo

| Time | What happens |
|---|---|
| 0:00 | Problem: Sheela's story. "She sells every day but doesn't know if she made a profit." Real numbers from your calls. |
| 0:25 | Phone: `call.html` → press 1 → "innu 12 biriyani" → confirm → **laptop updates by itself** |
| 0:55 | Press 2 → profit spoken in Malayalam; laptop shows the breakdown + one tip |
| 1:20 | Money Health: 60% to her auto, EMI check, "₹X GST paid, no registration needed yet" |
| 1:50 | Schemes: one scheme with document checklist |
| 2:05 | Bulk-buy: 4 women near her → save ₹X on rice. Support button (5 s). |
| 2:20 | Evidence: what the women you called said |
| 2:35 | Business: free for women; Kudumbashree district mission / CSR pays per unit; ask for a 30-unit pilot. Next: real IVR number, FSSAI, reminders. |

---

## 12. What could go wrong, and the fallback

| Risk | Fallback |
|---|---|
| Venue Wi-Fi fails | Phone hotspot; `localStorage` fallback; demo data pre-loaded |
| Malayalam speech recognition mishears | Keypad entry; read-back confirmation; demo with a clear pre-practised sentence |
| Firestore live update fails | Refresh button on the laptop still shows the new sale |
| Merge conflicts | File ownership; pull before push |
| Everything breaks at judging | Backup video recorded at H14 |
