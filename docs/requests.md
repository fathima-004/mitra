# Requests between teammates

Write: date/time, who, file, what you need changed.

---

**23 Oct, Fathima → Hiba: `js/data.js` and `js/calc.js`**
I pushed working first versions of your two files so my screens run before Firebase is ready:
- `js/data.js` stores everything in the browser (localStorage) and live-updates other open tabs. It follows the §5 API exactly, plus `getUser()` and a `history` collection (finished months as totals), which I added to PLAN.md §5.
- `js/calc.js` has all the profit maths; the exact function signatures are now in PLAN.md §5.

They're yours: replace the inside of `data.js` with Firestore (keep the localStorage fallback), and change anything you like, as long as the exported names and return shapes stay the same. `loadDemo()` reads `data/demo.json` (Sheela's example month; regenerate with `python tools/make_demo.py`).

**23 Oct, Fathima → Hiba: `js/data.js`, saves at the same moment overwrite each other (local copy)**
In your Firestore version, `add`/`update`/`remove` each do `await store()` → change → `write()`. Two calls in the same moment (e.g. the setup page saving a bill and a purchase together, or `call.html` saving "12 biriyani, 30 chapathi" with `Promise.all`) both read the same old copy, and the second write drops the first one's row from localStorage. Online, Firestore still has both and `onSnapshot` fixes it; **offline, a sale is lost.** I reproduced it and confirmed a queue fixes it. Suggested fix (I didn't touch your file):
```js
let queue = Promise.resolve();
function mutate(change) {
  const run = queue.then(async () => { const s = await store(); const r = change(s); write(KEY, s); return r; });
  queue = run.catch(() => {});
  return run;
}
// then e.g. add: const id = obj.id ?? newId(); const row = {...obj, id};
// await mutate((s) => { s[col] = [...(s[col] ?? []), row]; }); sync(...); return id;
```

**Local testing tip:** `python tools/serve.py` serves with `Cache-Control: no-store`. Python's plain `http.server` lets Chrome keep running old JS after you edit a file.

Tested: adding `{ date: today(), product: 'p1', qty: 12, via: 'call' }` to `sales` makes `index.html` update by itself, flash, and show "Added by phone call". Your call just needs to write that same shape to Firestore.

---

**23 Oct, Hiba → Fathima: data/synonyms.json format for js/parse.js**
call.html now understands sentences with word lists in js/parse.js (PLAN.md §7a, step 1). The words are built in for now. When you have data/synonyms.json, tell me and I'll load it instead. Please include:
- Product words per product id (Malayalam and English spellings: biriyani / biriyaani / ബിരിയാണി and so on)
- "sold" words (vittu, poyi, വിറ്റു)
- Number words (ഒന്ന്, രണ്ട്, twelve, ...) and fillers to ignore (innu, ഇന്ന്)
Also: call.html uses its own short Malayalam and English labels in js/call.js (the T table). Please check those wordings when you have a moment.

**23 Oct night, Fathima → Hiba: join and login by phone call (optional, only after the Must items work)**
`join.html` now shows judges how a woman joins. One path is "basic phone: join by calling Mitra". It plays a recorded example call (script in `data/join_call.json`, clips in `audio/join/`, made with `tools/make_join_audio.py`). For now it's only a replay. If you have time after the demo call works, the real version would be:
- `voice`: if the caller's number (`From`) isn't a known user → play `audio/join/j1.mp3` ("this number is new, press 1 to join").
- Ask name → place → products with prices (speech, read back, 1 = right / 2 = wrong) → 4-digit PIN by keypad → save a user keyed by her phone number → SMS welcome.
- Login next time: known `From` number → "Namaskaram <name>" → ask the PIN → menu.
If there's no time, we keep it as the replay plus a pitch line. No change is needed in your files for the demo.

**24 Oct ~00:30, both: work swapped (PLAN.md §2a, docs/team-rules.md "Team")**
Fathima → phone call (Exotel, Twilio as backup) + content + pitch. Hiba → Flutter app (`app/`) + Firebase/Netlify. For Hiba: the Flutter app's state and how to build it are in `docs/fathima-status.md`. The APK hasn't been built yet (network errors on Fathima's laptop), and the Firestore link is still to do. For Fathima: Hiba's call code is in `netlify/functions/` (voice, menu, ping) and `call.html` / `js/call.js` / `js/parse.js`.

---

**24 Oct, Hiba → Fathima: the Twilio call flow is finished, on branch `hiba/twilio-call-flow` (not on main)**
I built it before I saw the swap, so it's on a branch for you to merge or drop, since these files are yours now. It's the full Twilio backup your plan keeps: `voice`, `menu`, `sales`, `keypad`, `confirm`, `profit`, `parse`, `call-me`, plus `netlify/lib/` (shared TwiML, Firestore save with `via:"call"`, word lists then gemini/groq/claude). Every step is tested with fake Twilio requests, and the steps plus env vars are in `docs/backend.md` on the branch. Parts you can reuse for Exotel: `netlify/lib/understand.mjs` (parse + AI backup), `netlify/lib/store.mjs` (Firestore + India-time dates), and the `js/parse.js` upgrade (reads `data/synonyms.json`, personal words, Malayalam suffixes like "ബിരിയാണിയും").
For your content files:
1. **`data/synonyms.json`** shape that the branch reads: `{ "products": { "p1": ["biriyani", "ബിരിയാണി"] }, "numbers": { "ഇരുപത്തിരണ്ട്": 22 } }`.
2. **`data/schemes.json`**: key 3 and my schemes page read `title_ml` / `title_en`. Nothing is invented while the file is missing.
3. **Tele-MANAS 14416**: please check it on the official site and record the URL and date.
4. **Call voice clips**: `audio/` only has `join/` so far.
