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
