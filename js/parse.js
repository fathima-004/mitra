// Understands a spoken or typed sale with word lists only (PLAN.md §7a, step 1). Owner: Hiba.
// Used by call.html in the browser and by the phone call (Netlify Functions), so both understand the same words.
// Input: the sentence, her products, and optional extra words. Output: { items: [{product, qty}], sure, source }.
// The AI backup (step 2) and the keypad (step 3) are handled by the caller when sure is false.
//
// extra = {
//   synonyms: contents of data/synonyms.json (Fathima). Read as:
//     { products: { "p1" or "biriyani": ["biriyani", "ബിരിയാണി", ...] }, numbers: { "ഒന്ന്": 1, ... } }
//   words: her personal words from users/demo1/words, [{ word, product }]
// }

// Built-in words for each product, keyed by the product's English name in lower case.
// data/synonyms.json adds to these when it exists.
const PRODUCT_WORDS = {
  'biriyani': ['biriyani', 'biriyaani', 'biryani', 'beeryani', 'briyani', 'ബിരിയാണി', 'ബിരിയാണിയ്', 'ബിരിയാനി'],
  'chapathi': ['chapathi', 'chapati', 'chappathi', 'chapatti', 'ചപ്പാത്തി', 'ചപ്പാത്തിയ്', 'ചപ്പാത്തി'],
  'parotta': ['parotta', 'porotta', 'porota', 'paratha', 'പൊറോട്ട', 'പൊറോട്ടയ്', 'പറോട്ട'],
  'pickle bottle': ['pickle', 'pickles', 'achar', 'achaar', 'അച്ചാർ', 'അച്ചാറ്', 'അച്ചാര്‍'],
};

const NUMBER_WORDS = {
  'ഒന്ന്': 1, 'ഒന്നു': 1, 'ഒരു': 1, 'one': 1, 'oru': 1, 'onnu': 1, 'ondu': 1,
  'രണ്ട്': 2, 'രണ്ടു': 2, 'two': 2, 'randu': 2, 'rendu': 2,
  'മൂന്ന്': 3, 'മൂന്നു': 3, 'three': 3, 'moonnu': 3, 'moonu': 3,
  'നാല്': 4, 'നാലു': 4, 'four': 4, 'naalu': 4, 'nalu': 4,
  'അഞ്ച്': 5, 'അഞ്ചു': 5, 'five': 5, 'anchu': 5,
  'ആറ്': 6, 'ആറു': 6, 'six': 6, 'aaru': 6,
  'ഏഴ്': 7, 'ഏഴു': 7, 'seven': 7, 'ezhu': 7,
  'എട്ട്': 8, 'എട്ടു': 8, 'eight': 8, 'ettu': 8,
  'ഒമ്പത്': 9, 'ഒമ്പതു': 9, 'ഒൻപത്': 9, 'nine': 9, 'ombathu': 9,
  'പത്ത്': 10, 'പത്തു': 10, 'ten': 10, 'pathu': 10,
  'പതിനൊന്ന്': 11, 'eleven': 11,
  'പന്ത്രണ്ട്': 12, 'പന്ത്രണ്ടു': 12, 'twelve': 12, 'panthrandu': 12,
  'പതിനഞ്ച്': 15, 'fifteen': 15, 'pathinanchu': 15,
  'ഇരുപത്': 20, 'ഇരുപതു': 20, 'twenty': 20, 'irupathu': 20,
  'ഇരുപത്തഞ്ച്': 25, 'ഇരുപത്തിയഞ്ച്': 25,
  'മുപ്പത്': 30, 'മുപ്പതു': 30, 'thirty': 30, 'muppathu': 30,
  'നാൽപ്പത്': 40, 'forty': 40, 'nalpathu': 40,
  'അമ്പത്': 50, 'fifty': 50, 'ambathu': 50,
  'നൂറ്': 100, 'hundred': 100, 'nooru': 100,
};

// Lower case, Unicode-normalised, zero-width joiners removed (Malayalam text often has them).
const clean = (s) => String(s ?? '').normalize('NFC').toLowerCase().replace(/[‌‍]/g, '');

const tokens = (text) => clean(text).split(/[\s,.;:!?()\-]+/).filter(Boolean);

// Words this short must match exactly. Longer ones also match with a suffix,
// so "ബിരിയാണിയും" (and biriyani) and "chapathikal" still count.
const PREFIX_MIN = 4;

function wordTable(products, extra) {
  const syn = extra.synonyms?.products ?? {};
  return products.map((p) => {
    const key = clean(p.name_en);
    const words = [
      ...(PRODUCT_WORDS[key] ?? []),
      ...(syn[p.id] ?? []), ...(syn[key] ?? []),
      ...(extra.words ?? []).filter((w) => w.product === p.id).map((w) => w.word),
      key, p.name_ml ?? '',
      ...key.split(' ').filter((w) => w.length >= PREFIX_MIN), // "pickle" from "pickle bottle"
      ...clean(p.name_ml).split(' ').filter((w) => w.length >= PREFIX_MIN),
    ].map(clean).filter(Boolean);
    return { id: p.id, words: [...new Set(words)] };
  });
}

function productOf(token, table) {
  for (const { id, words } of table) if (words.includes(token)) return id;
  for (const { id, words } of table) {
    if (words.some((w) => w.length >= PREFIX_MIN && token.startsWith(w))) return id;
  }
  return null;
}

export function parse(text, products, extra = {}) {
  const numberWords = { ...NUMBER_WORDS, ...(extra.synonyms?.numbers ?? {}) };
  const numberOf = (token) => (/^\d{1,3}$/.test(token) ? Number(token) : numberWords[token] ?? null);
  const table = wordTable(products, extra);

  const toks = tokens(text);
  const nums = toks.map(numberOf);
  const prods = toks.map((t, i) => (nums[i] === null ? productOf(t, table) : null));
  const used = new Set();
  const found = [];

  toks.forEach((_, i) => {
    const pid = prods[i];
    if (!pid) return;
    // Nearest unused number next to the product word. The word before is tried first.
    const near = [-1, 1, -2, 2].map((d) => i + d).find((j) =>
      j >= 0 && j < toks.length && nums[j] !== null && !prods[j] && !used.has(j));
    if (near !== undefined) used.add(near);
    found.push({ product: pid, qty: near === undefined ? null : nums[near] });
  });

  // Quantities add up per product, and must be 1 to 999.
  const totals = {};
  for (const f of found) {
    if (f.qty === null || f.qty < 1 || f.qty > 999) continue;
    totals[f.product] = (totals[f.product] ?? 0) + f.qty;
  }
  const items = Object.entries(totals).map(([product, qty]) => ({ product, qty }));

  const missing = found.some((f) => f.qty === null || f.qty < 1 || f.qty > 999);
  const leftover = nums.some((n, j) => n !== null && !used.has(j));
  const sure = items.length > 0 && !missing && !leftover;

  return { items, sure, source: 'words' };
}
