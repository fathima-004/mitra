# Requests between teammates

Write: date/time, who, file, what you need changed.

---

**23 Oct, Fathima → Hiba: `js/data.js` and `js/calc.js`**
I pushed working first versions of your two files so my screens run before Firebase is ready:
- `js/data.js` stores everything in the browser (localStorage) and live-updates other open tabs. It follows the §5 API exactly, plus `getUser()` and a `history` collection (finished months as totals), which I added to PLAN.md §5.
- `js/calc.js` has all the profit maths; the exact function signatures are now in PLAN.md §5.

They're yours: replace the inside of `data.js` with Firestore (keep the localStorage fallback), and change anything you like, as long as the exported names and return shapes stay the same. `loadDemo()` reads `data/demo.json` (Sheela's example month; regenerate with `python tools/make_demo.py`).

Tested: adding `{ date: today(), product: 'p1', qty: 12, via: 'call' }` to `sales` makes `index.html` update by itself, flash, and show "Added by phone call". Your call just needs to write that same shape to Firestore.
