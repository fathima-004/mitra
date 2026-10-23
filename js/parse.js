// Understands a spoken or typed sale with word lists only (PLAN.md §7a, step 1). Owner: Hiba.
// Input: the sentence and the shop's products. Output: { items: [{product, qty}], sure, source }.
// The AI backup (step 2) and the keypad (step 3) are handled by the caller when sure is false.

// Words for each product, keyed by the product's English name in lower case.
// Fathima's data/synonyms.json will replace this list (PLAN.md §2).
const PRODUCT_WORDS = {
  'biriyani': ['biriyani', 'biriyaani', 'biryani', 'beeryani', 'ബിരിയാണി', 'ബിരിയാണിയ്'],
  'chapathi': ['chapathi', 'chapati', 'chappathi', 'ചപ്പാത്തി', 'ചപ്പാത്തിയ്'],
  'parotta': ['parotta', 'porotta', 'porota', 'പൊറോട്ട', 'പൊറോട്ടയ്'],
  'pickle bottle': ['pickle', 'achar', 'അച്ചാർ', 'അച്ചാറ്', 'അച്ചാര്‍'],
};

const NUMBER_WORDS = {
  'ഒന്ന്': 1, 'ഒന്നു': 1, 'ഒരു': 1, 'one': 1, 'oru': 1, 'onnu': 1, 'ondu': 1,
  'രണ്ട്': 2, 'രണ്ടു': 2, 'two': 2, 'randu': 2, 'rendu': 2,
  'മൂന്ന്': 3, 'മൂന്നു': 3, 'three': 3, 'moonnu': 3, 'moonu': 3,
  'നാല്': 4, 'നാലു': 4, 'four': 4, 'naalu': 4,
  'അഞ്ച്': 5, 'അഞ്ചു': 5, 'five': 5, 'anchu': 5,
  'ആറ്': 6, 'ആറു': 6, 'six': 6, 'aaru': 6,
  'ഏഴ്': 7, 'ഏഴു': 7, 'seven': 7, 'ezhu': 7,
  'എട്ട്': 8, 'എട്ടു': 8, 'eight': 8, 'ettu': 8,
  'ഒമ്പത്': 9, 'ഒമ്പതു': 9, 'ഒൻപത്': 9, 'nine': 9, 'ombathu': 9,
  'പത്ത്': 10, 'പത്തു': 10, 'ten': 10, 'pathu': 10,
  'പന്ത്രണ്ട്': 12, 'പന്ത്രണ്ടു': 12, 'twelve': 12,
  'പതിനഞ്ച്': 15, 'fifteen': 15,
  'ഇരുപത്': 20, 'ഇരുപതു': 20, 'twenty': 20, 'irupathu': 20,
  'മുപ്പത്': 30, 'മുപ്പതു': 30, 'thirty': 30, 'muppathu': 30,
};

// Lower case, Unicode-normalised, zero-width joiners removed (Malayalam text often has them).
const clean = (s) => s.normalize('NFC').toLowerCase().replace(/[‌‍]/g, '');

const tokens = (text) => clean(text).split(/[\s,.;:!?()\-]+/).filter(Boolean);

function numberOf(token) {
  if (/^\d{1,3}$/.test(token)) return Number(token);
  return NUMBER_WORDS[token] ?? null;
}

function productOf(token, products) {
  for (const p of products) {
    const key = p.name_en.toLowerCase();
    const words = PRODUCT_WORDS[key] ?? [key, clean(p.name_ml ?? '')];
    if (words.map(clean).includes(token)) return p.id;
  }
  return null;
}

export function parse(text, products) {
  const toks = tokens(text);
  const nums = toks.map(numberOf);
  const prods = toks.map((t) => productOf(t, products));
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
