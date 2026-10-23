// The whole Mitra phone menu, keypad only, as one small state machine. Owner: Hiba.
//
// Exotel flow (docs/exotel-full-call.md): Gather (exotel-ivr?do=ask) → Passthru (exotel-ivr?do=hear) → back to
// the Gather, round and round, until she presses 0 on the main menu; then Passthru answers "end" and the call
// goes to Hangup. ask() says what to say now; hear() acts on the keys she pressed.
//
// Language: the call speaks the language chosen in the app (users/demo1.lang, "ml" or "en"; Malayalam if unset).
// Key 8 on the main menu switches it, and saves the choice, so the app follows too.
//
// Everything she changes is written to Firestore the moment she confirms it, with via:"call", so the app updates
// live; the call session (calls/{CallSid}) keeps a list of what she did, read back to her at the end.
// Numbers are typed on the keypad, so they are confirmed by her. All maths is plain code (same as js/calc.js).
//
// Main menu
//   1 Add a sale          → item → how many → saved → 1 another, 2 undo, 0 menu
//   2 Add an expense      → what for → how much → saved → 1 another, 2 undo, 0 menu
//   3 My money            → 1 today + this month's profit, 2 monthly report, 3 savings goal (1 add savings),
//                           4 monthly bills (1 add a bill), 5 GST paid this year
//   4 Schemes & together  → 1 government scheme news, 2 buy stock together (pick a group, how much)
//   5 Change a price      → item → new price
//   8 Other language      9 Repeat      0 Finish (summary, goodbye)

const USER = 'demo1';

// ---------- dates (India time) and money (same rules as js/calc.js) ----------
const ist = (now) => new Date(now.getTime() + 5.5 * 3600 * 1000);
const todayOf = (now) => ist(now).toISOString().slice(0, 10);
const timeOf = (now) => ist(now).toISOString().slice(11, 16);
const monthOfNow = (now) => todayOf(now).slice(0, 7);
const r = (n) => Math.round(n);

function addMonths(month, n) {
  const [y, m] = month.split('-').map(Number);
  return new Date(Date.UTC(y, m - 1 + n, 1)).toISOString().slice(0, 7);
}
const MONTHS_EN = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const MONTHS_ML = ['ജനുവരി', 'ഫെബ്രുവരി', 'മാർച്ച്', 'ഏപ്രിൽ', 'മേയ്', 'ജൂൺ', 'ജൂലൈ', 'ഓഗസ്റ്റ്', 'സെപ്റ്റംബർ', 'ഒക്ടോബർ', 'നവംബർ', 'ഡിസംബർ'];
const monthName = (month, ml) => `${(ml ? MONTHS_ML : MONTHS_EN)[Number(month.slice(5, 7)) - 1]} ${month.slice(0, 4)}`;

function totals(d, month) {
  const price = Object.fromEntries(d.products.map((p) => [p.id, Number(p.price) || 0]));
  const sales = d.sales.filter((s) => String(s.date).slice(0, 7) === month);
  const income = sales.reduce((sum, s) => sum + (Number(s.qty) || 0) * (price[s.product] ?? 0), 0);
  const spending = d.bills.filter((b) => b.month === month).reduce((sum, b) => sum + (Number(b.amount) || 0), 0)
    + d.purchases.filter((p) => String(p.date).slice(0, 7) === month).reduce((sum, p) => sum + (Number(p.amount) || 0), 0);
  const byProduct = d.products.map((p) => {
    const qty = sales.filter((s) => s.product === p.id).reduce((n, s) => n + (Number(s.qty) || 0), 0);
    return { p, qty, income: qty * (Number(p.price) || 0) };
  }).sort((a, b) => b.income - a.income);
  return { income, spending, profit: income - spending, byProduct };
}

// ---------- words in both languages ----------
const EXPENSES = [
  { cat: 'ingredients', en: 'Ingredients', ml: 'ചേരുവകൾ', say: 'ingredients like rice or oil', sayMl: 'അരി, എണ്ണ പോലുള്ള ചേരുവകൾ' },
  { cat: 'gas', en: 'Gas', ml: 'ഗ്യാസ്', say: 'gas', sayMl: 'ഗ്യാസ്' },
  { cat: 'packaging', en: 'Packaging', ml: 'പാക്കിംഗ്', say: 'packaging', sayMl: 'പാക്കിംഗ്' },
  { cat: 'transport', en: 'Transport', ml: 'യാത്ര', say: 'transport', sayMl: 'യാത്ര' },
  { cat: 'other', en: 'Other', ml: 'മറ്റുള്ളവ', say: 'anything else', sayMl: 'മറ്റെന്തെങ്കിലും' },
];
const BILLS = [
  { type: 'gas', en: 'Gas', ml: 'ഗ്യാസ്' },
  { type: 'electricity', en: 'Electricity', ml: 'കറന്റ്' },
  { type: 'rent', en: 'Rent', ml: 'വാടക' },
  { type: 'emi', en: 'EMI', ml: 'ഇഎംഐ' },
  { type: 'other', en: 'Other', ml: 'മറ്റുള്ളവ' },
];
const UNITS = { l: ['litres', 'ലിറ്റർ'], kg: ['kilos', 'കിലോ'], g: ['grams', 'ഗ്രാം'], pcs: ['pieces', 'എണ്ണം'], nos: ['pieces', 'എണ്ണം'] };
const unitWord = (u, ml) => (UNITS[String(u ?? '').toLowerCase()] ?? [String(u ?? ''), String(u ?? '')])[ml ? 1 : 0];
const nameOf = (x, ml) => (ml ? x?.name_ml || x?.name_en : x?.name_en || x?.name_ml) ?? '';
const itemOf = (x, ml) => (ml ? x?.item_ml || x?.item : x?.item || x?.item_ml) ?? '';

// "For Biriyani, press 1." / "ബിരിയാണി ആണെങ്കിൽ 1."
const list = (items, label, ml) => items.map((x, i) => (ml ? `${label(x)} ആണെങ്കിൽ ${i + 1}.` : `For ${label(x)}, press ${i + 1}.`)).join(' ');

// ---------- government scheme news: hand-checked file first, then the official PIB feed ----------
const SCHEME_WORDS = /scheme|yojana|mission|women|woman|mahila|self[- ]help|\bshg|kudumbashree|msme|micro|entrepreneur|startup|artisan|vendor|food processing|skill|livelihood|nari|lakhpati|didi|subsid|grant|training|udyam/i;
const LOAN_WORDS = /loan|credit|lend|lender|nbfc|mudra|svanidhi|guarantee|interest rate|borrow|microfinance|debt/i;
const PIB = 'https://www.pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3&reg=3';

// Schemes she can join now: the same hand-checked list as the app (app/assets/data/schemes.json, each with its
// official source and date), only those still open and never loans. Then fresh scheme news from the PIB feed.
function openSchemes(now = new Date()) {
  try {
    const file = require('../../app/assets/data/schemes.json');
    const day = new Date(now.getTime() + 5.5 * 3600 * 1000).toISOString().slice(0, 10);
    return (Array.isArray(file) ? file : file.schemes ?? []).filter((s) => /^https?:\/\//.test(s.source_url ?? '') && s.date_checked
      && s.loan !== true && (s.open_until == null || String(s.open_until) >= day));
  } catch {
    return [];
  }
}

async function schemeNews(ml, fetchImpl = fetch) {
  // Spoken: no "₹" sign ("₹2 lakh" → "2 lakh rupees") and no double full stops.
  const spoken = (t) => String(t ?? '').replace(/\.\s*$/, '')
    .replace(/₹\s?([\d,]+(?:\s?(?:lakh|ലക്ഷം))?)/g, ml ? '$1 രൂപ' : '$1 rupees');
  const open = openSchemes().map((s) => (ml ? `${s.title_ml}: ${spoken(s.about_ml)}` : `${s.title_en}: ${spoken(s.about_en)}`));
  let news = [];
  try {
    const res = await fetchImpl(PIB, { signal: AbortSignal.timeout(3500), headers: { 'User-Agent': 'Mitra/1.0' } });
    const xml = await res.text();
    const titles = [...xml.matchAll(/<item>\s*<title>([\s\S]*?)<\/title>/g)].map((m) => m[1].replace(/<!\[CDATA\[|\]\]>/g, '').trim());
    news = titles.filter((t) => SCHEME_WORDS.test(t) && !LOAN_WORDS.test(t)).slice(0, 2);
  } catch {
    // offline: the checked list is enough
  }
  return { open, news };
}

// ---------- prompts ----------
const T = {
  hello: ['Hello, this is Mitra.', 'നമസ്കാരം, ഞാൻ മിത്ര.'],
  main: [
    'Main menu. To add a sale, press 1. To add an expense, press 2. For your money, profit and savings, press 3. '
      + 'For government schemes and buying together, press 4. To change a price, press 5. For Malayalam, press 8. To hear this again, press 9. To finish, press 0.',
    'പ്രധാന മെനു. വിൽപ്പന ചേർക്കാൻ 1. ചെലവ് ചേർക്കാൻ 2. ലാഭം, റിപ്പോർട്ട്, സമ്പാദ്യം എന്നിവയ്ക്ക് 3. '
      + 'സർക്കാർ പദ്ധതികൾക്കും ഒരുമിച്ച് വാങ്ങാനും 4. വില മാറ്റാൻ 5. ഇംഗ്ലീഷിൽ കേൾക്കാൻ 8. വീണ്ടും കേൾക്കാൻ 9. അവസാനിപ്പിക്കാൻ 0.',
  ],
  toMain: ['For the main menu, press 0.', 'പ്രധാന മെനുവിന് 0.'],
  back: ['To go back, press 0.', 'തിരികെ പോകാൻ 0.'],
  typeHash: ['Type the number, then press hash.', 'നമ്പർ അമർത്തി, ഒടുവിൽ ഹാഷ് അമർത്തുക.'],
  typeRs: ['Type the rupees, then press hash.', 'തുക അമർത്തി, ഒടുവിൽ ഹാഷ് അമർത്തുക.'],
  whatSold: ['What did you sell?', 'എന്താണ് വിറ്റത്?'],
  whatSpent: ['What did you spend on?', 'എന്തിനാണ് ചെലവാക്കിയത്?'],
  afterAdd: ['To add another, press 1. To undo that, press 2. For the main menu, press 0.', 'ഇനിയും ചേർക്കാൻ 1. അത് മാറ്റാൻ 2. പ്രധാന മെനുവിന് 0.'],
  money: [
    "Your money. For today and this month's profit, press 1. For the monthly report, press 2. For your savings goal, press 3. "
      + 'For monthly bills, press 4. For GST paid this year, press 5. For the main menu, press 0.',
    'നിങ്ങളുടെ പണം. ഇന്നത്തെയും ഈ മാസത്തെയും ലാഭം അറിയാൻ 1. മാസ റിപ്പോർട്ടിന് 2. സമ്പാദ്യ ലക്ഷ്യത്തിന് 3. '
      + 'മാസ ബില്ലുകൾക്ക് 4. ഈ വർഷം അടച്ച ജിഎസ്ടി അറിയാൻ 5. പ്രധാന മെനുവിന് 0.',
  ],
  goalMenu: ['To add to your savings, press 1. To go back, press 0.', 'സമ്പാദ്യം ചേർക്കാൻ 1. തിരികെ പോകാൻ 0.'],
  goalAmt: ['How much did you save?', 'എത്ര രൂപ മാറ്റിവെച്ചു?'],
  billsMenu: ['To add a bill, press 1. To go back, press 0.', 'ബിൽ ചേർക്കാൻ 1. തിരികെ പോകാൻ 0.'],
  whichBill: ['Which bill?', 'ഏത് ബിൽ?'],
  together: [
    'For government scheme news, press 1. To buy stock together with women near you, press 2. For the main menu, press 0.',
    'സർക്കാർ പദ്ധതി വാർത്തകൾക്ക് 1. അടുത്തുള്ള സ്ത്രീകളോടൊപ്പം ഒരുമിച്ച് സാധനം വാങ്ങാൻ 2. പ്രധാന മെനുവിന് 0.',
  ],
  whichPrice: ['Which price?', 'ഏതിന്റെ വില മാറ്റണം?'],
  sorry: ['Sorry, that key is not on the menu.', 'ക്ഷമിക്കണം, ആ നമ്പർ മെനുവിൽ ഇല്ല.'],
  noKey: ['I did not hear a key.', 'ഒന്നും കേട്ടില്ല.'],
  noKeyEnd: ['I did not hear any key.', 'ഒന്നും കേൾക്കുന്നില്ല.'],
  qtyRange: ['Please type a number from 1 to 999.', '1 മുതൽ 999 വരെയുള്ള നമ്പർ അമർത്തുക.'],
  rsAgain: ['Please type the amount in rupees.', 'തുക രൂപയിൽ അമർത്തുക.'],
  removed: ['Removed.', 'മാറ്റി.'],
  noGoal: ['You have no savings goal yet. You can set one in the Mitra app.', 'സമ്പാദ്യ ലക്ഷ്യം ഇതുവരെ ഇല്ല. മിത്ര ആപ്പിൽ ചേർക്കാം.'],
  noNews: ['There is no new scheme news today. The Mitra app shows the latest updates.', 'ഇന്ന് പുതിയ പദ്ധതി വാർത്തകൾ ഇല്ല. മിത്ര ആപ്പിൽ പുതിയവ കാണാം.'],
  noGroups: ['There are no groups buying together right now.', 'ഇപ്പോൾ ഒരുമിച്ച് വാങ്ങുന്ന ഗ്രൂപ്പുകൾ ഇല്ല.'],
  howMuchNeed: ['Please type how much you need.', 'എത്ര വേണമെന്ന് അമർത്തുക.'],
  priceAgain: ['Please type the price in rupees.', 'വില രൂപയിൽ അമർത്തുക.'],
  bye: ['Thank you. Goodbye from Mitra.', 'നന്ദി. വീണ്ടും വിളിക്കൂ.'],
  noChanges: ['Nothing was changed on this call.', 'ഈ വിളിയിൽ മാറ്റങ്ങൾ ഒന്നും വരുത്തിയില്ല.'],
  inApp: ['It is all in your Mitra app.', 'എല്ലാം മിത്ര ആപ്പിൽ ഉണ്ട്.'],
  nowMl: ['', 'ശരി, ഇനി മലയാളത്തിൽ.'],
  nowEn: ['Okay, English from now on.', ''],
  gst: [
    'This is guidance only. Please confirm with your Kudumbashree M E C or a tax consultant.',
    'ഇത് മാർഗ്ഗനിർദ്ദേശം മാത്രം. കുടുംബശ്രീ എം ഇ സി യോടോ ടാക്സ് കൺസൾട്ടന്റിനോടോ ഉറപ്പാക്കുക.',
  ],
  oops: ['Sorry, something went wrong. Nothing was lost.', 'ക്ഷമിക്കണം, ഒരു പ്രശ്നം ഉണ്ടായി. ഒന്നും നഷ്ടമായില്ല.'],
};
const MAIN = T.main[0];

function newState(now, lang = 'ml') {
  const ml = lang !== 'en';
  return {
    node: 'main', lang: ml ? 'ml' : 'en', msg: T.hello[ml ? 1 : 0], data: {}, seq: 0, handled: -1, idle: 0, n: 0, actions: [], last: null,
    started: now.toISOString(),
  };
}

/** What Mitra says now, and how many keys to wait for. Returns { text, lang, digits, finish, timeout }. */
async function ask(state, ctx) {
  const d = await ctx.load();
  const s = state;
  const ml = s.lang === 'ml';
  const t = (k) => T[k][ml ? 1 : 0];
  const pre = s.msg ? `${s.msg} ` : '';
  s.msg = '';
  s.seq += 1;
  const menu = (text, digits = 1) => ({ text: pre + text, lang: s.lang, digits, finish: digits > 1 ? '#' : '' });
  const product = d.products.find((p) => p.id === s.data.product);
  const items = d.products.slice(0, 9);

  switch (s.node) {
    case 'main': return menu(t('main'));
    case 'sale_pick': return menu(`${t('whatSold')} ${list(items, (p) => nameOf(p, ml), ml)} ${t('toMain')}`);
    case 'sale_qty': return menu(ml ? `${nameOf(product, ml)} എത്ര എണ്ണം വിറ്റു? ${t('typeHash')}` : `How many ${nameOf(product, ml)} did you sell? ${t('typeHash')}`, 3);
    case 'exp_pick': return menu(`${t('whatSpent')} ${list(EXPENSES, (e) => (ml ? e.sayMl : e.say), ml)} ${t('toMain')}`);
    case 'exp_amt': {
      const e = EXPENSES.find((x) => x.cat === s.data.cat);
      return menu(ml ? `${e?.sayMl} എത്ര രൂപ ചെലവായി? ${t('typeRs')}` : `How much did you spend on ${e?.say}? ${t('typeRs')}`, 6);
    }
    case 'after_add': return menu(t('afterAdd'));
    case 'money': return menu(t('money'));
    case 'goal_menu': return menu(t('goalMenu'));
    case 'goal_amt': return menu(`${t('goalAmt')} ${t('typeRs')}`, 6);
    case 'bills_menu': return menu(t('billsMenu'));
    case 'bill_pick': return menu(`${t('whichBill')} ${list(BILLS, (b) => (ml ? b.ml : b.en), ml)} ${t('back')}`);
    case 'bill_amt': {
      const b = BILLS.find((x) => x.type === s.data.bill);
      return menu(ml ? `${b?.ml} ബിൽ എത്ര രൂപ? ${t('typeRs')}` : `How much is the ${b?.en} bill? ${t('typeRs')}`, 6);
    }
    case 'together': return menu(t('together'));
    case 'bulk_pick': {
      const text = bulkGroups(d.bulk_requests).slice(0, 9).map((g, i) => (ml
        ? `ഗ്രൂപ്പ് ${i + 1}: ${itemOf(g, ml)}, ${g.rows.length} പേർ, ഇതുവരെ ${g.total} ${unitWord(g.unit, ml)}. ${g.mine ? 'നിങ്ങൾ ഇതിൽ ഉണ്ട്.' : `ചേരാൻ ${i + 1}.`}`
        : `Group ${i + 1}: ${itemOf(g, ml)}, ${g.rows.length} women, ${g.total} ${unitWord(g.unit, ml)} so far. ${g.mine ? 'You are already in it.' : `To join, press ${i + 1}.`}`)).join(' ');
      return menu(`${text} ${t('back')}`);
    }
    case 'bulk_qty': {
      const g = bulkGroups(d.bulk_requests)[s.data.group];
      return menu(ml ? `എത്ര ${unitWord(g?.unit, ml)} ${itemOf(g, ml)} വേണം? ${t('typeHash')}`
        : `How much ${itemOf(g, ml)} do you need, in ${unitWord(g?.unit, ml) || 'units'}? ${t('typeHash')}`, 4);
    }
    case 'price_pick':
      return menu(`${t('whichPrice')} ${list(items, (p) => (ml ? `${nameOf(p, ml)}, ഇപ്പോൾ ${p.price} രൂപ,` : `${nameOf(p, ml)}, now ${p.price} rupees`), ml)} ${t('toMain')}`);
    case 'price_new':
      return menu(ml ? `${nameOf(product, ml)} പുതിയ വില എത്ര? ${t('typeRs')}` : `Type the new price of ${nameOf(product, ml)} in rupees, then press hash.`, 5);
    case 'end': return { text: `${pre}${summary(s)} ${t('bye')}`, lang: s.lang, digits: 1, finish: '', timeout: 1 };
    default:
      s.node = 'main';
      return menu(t('main'));
  }
}

function bulkGroups(rows) {
  const groups = new Map();
  for (const row of rows) {
    const k = `${row.month}|${row.item}`;
    if (!groups.has(k)) groups.set(k, { key: k, item: row.item, item_ml: row.item_ml, month: row.month, unit: row.unit ?? '', place: row.place, rows: [] });
    groups.get(k).rows.push(row);
  }
  return [...groups.values()].sort((a, b) => a.key.localeCompare(b.key)).map((g) => ({
    ...g,
    total: g.rows.reduce((n, x) => n + (Number(x.qty) || 0), 0),
    mine: g.rows.some((x) => x.user === USER),
  }));
}

function summary(s) {
  const ml = s.lang === 'ml';
  const changes = s.actions.filter((a) => a.col);
  if (!changes.length) return T.noChanges[ml ? 1 : 0];
  const said = changes.map((a) => (ml ? a.sayMl ?? a.say : a.say)).join('; ');
  return ml
    ? `ഈ വിളിയിൽ ${changes.length} മാറ്റങ്ങൾ വരുത്തി: ${said}. ${T.inApp[1]}`
    : `On this call you made ${changes.length} change${changes.length > 1 ? 's' : ''}: ${said}. ${T.inApp[0]}`;
}

function goalLine(g, month, ml) {
  const target = Number(g.target) || 0;
  const saved = Number(g.saved) || 0;
  const left = Math.max(0, target - saved);
  const pct = target > 0 ? Math.min(100, Math.round((saved / target) * 100)) : 0;
  const name = ml ? 'സമ്പാദ്യ ലക്ഷ്യം' : 'Savings goal';
  const months = Number(g.monthly) > 0 ? Math.ceil(left / Number(g.monthly)) : null;
  if (left === 0) return ml ? `${name}: ലക്ഷ്യമായ ${r(target)} രൂപ എത്തി!` : `${name}: you have reached your goal of ${r(target)} rupees!`;
  if (ml) {
    return `${name}: ${r(target)} രൂപയിൽ ${r(saved)} രൂപ ആയി, ${pct} ശതമാനം. ഇനി ${r(left)} രൂപ.`
      + (months ? ` മാസം ${r(g.monthly)} രൂപ വീതം മാറ്റിവെച്ചാൽ ${monthName(addMonths(month, months), true)} ആകുമ്പോൾ എത്തും.` : '');
  }
  return `${name}: saved ${r(saved)} rupees of ${r(target)} rupees, that is ${pct} percent. ${r(left)} rupees to go.`
    + (months ? ` Saving ${r(g.monthly)} rupees a month, you will get there by ${monthName(addMonths(month, months), false)}.` : '');
}

/** Acts on the keys she pressed. Returns { end } when the call should hang up. */
async function hear(state, raw, ctx) {
  const s = state;
  if (s.handled === s.seq) return { end: s.node === 'ended' }; // Exotel retried the same request: already done
  s.handled = s.seq;
  if (s.node === 'end') {
    s.node = 'ended';
    return { end: true };
  }
  if (s.node === 'ended') return { end: true };

  const ml = s.lang === 'ml';
  const t = (k) => T[k][ml ? 1 : 0];
  const digits = String(raw ?? '').replace(/["\s#*]/g, '');
  if (!digits) {
    s.idle += 1;
    if (s.idle >= 3) {
      s.node = 'end';
      s.msg = t('noKeyEnd');
    } else {
      s.msg = t('noKey');
    }
    return { end: false };
  }
  s.idle = 0;
  const key = Number(digits);
  const d = await ctx.load();
  const now = ctx.now();
  const go = (node, msg = '', data = s.data) => {
    s.node = node;
    s.msg = msg;
    s.data = data;
    return { end: false };
  };
  const id = (prefix) => `${prefix}${String(ctx.sid).replace(/[^\w]/g, '').slice(-12)}${(s.n += 1)}`;
  const record = async (col, row, say, sayMl) => {
    const rid = id(col[0]);
    await ctx.store.set(col, rid, row);
    s.last = { col, id: rid };
    s.actions.push({ col, id: rid, say, sayMl });
    return rid;
  };
  const sorry = (node) => go(node, t('sorry'));

  switch (s.node) {
    case 'main':
      if (key === 1) return go('sale_pick', '', {});
      if (key === 2) return go('exp_pick', '', {});
      if (key === 3) return go('money');
      if (key === 4) return go('together');
      if (key === 5) return go('price_pick', '', {});
      if (key === 8) {
        s.lang = ml ? 'en' : 'ml';
        await ctx.store.setLang(s.lang); // the app follows within a few seconds
        return go('main', ml ? T.nowEn[0] : T.nowMl[1]);
      }
      if (key === 9) return go('main');
      if (key === 0) return go('end');
      return sorry('main');

    // ----- sales -----
    case 'sale_pick': {
      if (key === 0) return go('main');
      const p = d.products.slice(0, 9)[key - 1];
      return p ? go('sale_qty', '', { product: p.id }) : sorry('sale_pick');
    }
    case 'sale_qty': {
      const p = d.products.find((x) => x.id === s.data.product);
      if (!p || !(key >= 1 && key <= 999)) return go('sale_qty', t('qtyRange'));
      const amt = r(key * (Number(p.price) || 0));
      await record('sales', { date: todayOf(now), time: timeOf(now), product: p.id, qty: key, via: 'call' },
        `sold ${key} ${nameOf(p, false)}, ${amt} rupees`, `${key} ${nameOf(p, true)} വിറ്റു, ${amt} രൂപ`);
      return go('after_add', ml ? `സേവ് ചെയ്തു. ${key} ${nameOf(p, true)}, ${amt} രൂപ.` : `Saved. ${key} ${nameOf(p, false)}, ${amt} rupees.`, { again: 'sale_pick' });
    }

    // ----- expenses -----
    case 'exp_pick': {
      if (key === 0) return go('main');
      const e = EXPENSES[key - 1];
      return e ? go('exp_amt', '', { cat: e.cat }) : sorry('exp_pick');
    }
    case 'exp_amt': {
      const e = EXPENSES.find((x) => x.cat === s.data.cat);
      if (!e || !(key >= 1 && key <= 999999)) return go('exp_amt', t('rsAgain'));
      await record('purchases', {
        date: todayOf(now), time: timeOf(now), cat: e.cat, item: e.en, item_ml: e.ml, qty: 1, unit: '', amount: key, gst: 0, via: 'call',
      }, `spent ${key} rupees on ${e.say}`, `${e.ml} ${key} രൂപ ചെലവ്`);
      return go('after_add', ml ? `സേവ് ചെയ്തു. ${e.ml}, ${key} രൂപ.` : `Saved. ${key} rupees for ${e.say}.`, { again: 'exp_pick' });
    }

    case 'after_add':
      if (key === 1) return go(s.data.again ?? 'main', '', {});
      if (key === 2 && s.last) {
        await ctx.store.remove(s.last.col, s.last.id);
        s.actions = s.actions.filter((a) => a.id !== s.last.id);
        s.last = null;
        return go('main', t('removed'), {});
      }
      if (key === 0) return go('main', '', {});
      return sorry('after_add');

    // ----- my money -----
    case 'money': {
      if (key === 0) return go('main');
      const month = monthOfNow(now);
      const tt = totals(d, month);
      if (key === 1) {
        const today = totals({ ...d, sales: d.sales.filter((x) => x.date === todayOf(now)), bills: [], purchases: [] }, month);
        return go('money', ml
          ? `ഇന്ന് ${r(today.income)} രൂപയുടെ വിൽപ്പന. ഈ മാസം ഇതുവരെ വരവ് ${r(tt.income)} രൂപ, ചെലവ് ${r(tt.spending)} രൂപ, ${tt.profit >= 0 ? `ലാഭം ${r(tt.profit)} രൂപ` : `നഷ്ടം ${r(-tt.profit)} രൂപ`}.`
          : `Today you sold ${r(today.income)} rupees. This month so far: income ${r(tt.income)} rupees, spending ${r(tt.spending)} rupees, `
            + `${tt.profit >= 0 ? `profit ${r(tt.profit)} rupees` : `loss ${r(-tt.profit)} rupees`}.`);
      }
      if (key === 2) {
        const best = tt.byProduct.find((x) => x.qty > 0);
        const last = d.history.find((h) => h.month === addMonths(month, -1));
        const lastProfit = last ? last.income - last.spending : null;
        const diff = lastProfit === null ? null : r(tt.profit - lastProfit);
        if (ml) {
          return go('money', `${monthName(month, true)} മാസത്തെ റിപ്പോർട്ട്. വരവ് ${r(tt.income)} രൂപ. ചെലവ് ${r(tt.spending)} രൂപ. ലാഭം ${r(tt.profit)} രൂപ.`
            + (best ? ` ഏറ്റവും കൂടുതൽ വിറ്റത് ${nameOf(best.p, true)}, ${best.qty} എണ്ണം, ${r(best.income)} രൂപ.` : '')
            + (diff === null ? '' : diff >= 0 ? ` കഴിഞ്ഞ മാസത്തേക്കാൾ ${diff} രൂപ കൂടുതൽ.` : ` കഴിഞ്ഞ മാസത്തേക്കാൾ ${-diff} രൂപ കുറവ്, ഇതുവരെ.`));
        }
        return go('money', `Report for ${monthName(month, false)}. Income ${r(tt.income)} rupees. Spending ${r(tt.spending)} rupees. Profit ${r(tt.profit)} rupees.`
          + (best ? ` Your best seller is ${nameOf(best.p, false)}, ${best.qty} sold, ${r(best.income)} rupees.` : '')
          + (diff === null ? '' : diff >= 0 ? ` That is ${diff} rupees more than last month.` : ` That is ${-diff} rupees less than last month so far.`));
      }
      if (key === 3) {
        const g = d.goals[0];
        return g ? go('goal_menu', goalLine(g, month, ml)) : go('money', t('noGoal'));
      }
      if (key === 4) {
        const bills = d.bills.filter((b) => b.month === month);
        const total = bills.reduce((n, b) => n + (Number(b.amount) || 0), 0);
        const each = bills.map((b) => `${(ml ? b.label_ml : b.label_en) ?? b.type} ${r(b.amount)} ${ml ? 'രൂപ' : 'rupees'}`).join(', ');
        return go('bills_menu', ml ? `ഈ മാസത്തെ ബില്ലുകൾ ആകെ ${r(total)} രൂപ. ${each}.` : `This month's bills come to ${r(total)} rupees. ${each}.`);
      }
      if (key === 5) {
        const [y, m] = month.split('-').map(Number);
        const fyStart = `${m >= 4 ? y : y - 1}-04`;
        const past = d.history.filter((h) => h.month >= fyStart && h.month < month).reduce((n, h) => n + (Number(h.gst_paid) || 0), 0);
        const now2 = d.purchases.filter((p) => String(p.date).slice(0, 7) === month).reduce((n, p) => n + (Number(p.gst) || 0), 0);
        return go('money', ml
          ? `ഈ വർഷം വാങ്ങിയ സാധനങ്ങൾക്ക് അടച്ച ജിഎസ്ടി ${r(past + now2)} രൂപ. ${t('gst')}`
          : `GST you paid on what you bought this year: ${r(past + now2)} rupees. ${t('gst')}`);
      }
      return sorry('money');
    }
    case 'goal_menu':
      if (key === 1) return go('goal_amt');
      if (key === 0) return go('money');
      return sorry('goal_menu');
    case 'goal_amt': {
      const g = d.goals[0];
      if (!g || !(key >= 1 && key <= 999999)) return go('goal_amt', t('rsAgain'));
      const saved = (Number(g.saved) || 0) + key;
      await ctx.store.update('goals', g.id, { saved });
      s.actions.push({ col: 'goals', id: g.id, say: `added ${key} rupees to savings`, sayMl: `സമ്പാദ്യത്തിൽ ${key} രൂപ ചേർത്തു` });
      s.last = null; // a savings change isn't undone with "2"; she can change it in the app
      return go('money', `${ml ? 'സേവ് ചെയ്തു.' : 'Saved.'} ${goalLine({ ...g, saved }, monthOfNow(now), ml)}`);
    }
    case 'bills_menu':
      if (key === 1) return go('bill_pick');
      if (key === 0) return go('money');
      return sorry('bills_menu');
    case 'bill_pick': {
      if (key === 0) return go('money');
      const b = BILLS[key - 1];
      return b ? go('bill_amt', '', { bill: b.type }) : sorry('bill_pick');
    }
    case 'bill_amt': {
      const b = BILLS.find((x) => x.type === s.data.bill);
      if (!b || !(key >= 1 && key <= 999999)) return go('bill_amt', t('rsAgain'));
      await record('bills', { month: monthOfNow(now), type: b.type, label_en: b.en, label_ml: b.ml, amount: key, via: 'call' },
        `added a ${b.en} bill of ${key} rupees`, `${b.ml} ബിൽ ${key} രൂപ`);
      return go('money', ml ? `സേവ് ചെയ്തു. ${b.ml} ബിൽ, ${key} രൂപ.` : `Saved. ${b.en} bill, ${key} rupees.`, {});
    }

    // ----- schemes and buying together -----
    case 'together': {
      if (key === 0) return go('main');
      if (key === 1) {
        const { open, news } = await schemeNews(ml, ctx.fetch);
        s.actions.push({ col: null, id: null, say: 'heard schemes' });
        if (!open.length && !news.length) return go('together', t('noNews'));
        const parts = [];
        if (open.length) parts.push(ml ? `ഇപ്പോൾ ചേരാവുന്ന പദ്ധതികൾ: ${open.join('. ')}.` : `Schemes you can join now: ${open.join('. ')}.`);
        if (news.length) parts.push(ml ? `സർക്കാരിൽ നിന്നുള്ള പുതിയ അറിയിപ്പുകൾ: ${news.join('. ')}.` : `New from the Government: ${news.join('. ')}.`);
        parts.push(ml ? 'ചേരേണ്ട വിധവും രേഖകളും മിത്ര ആപ്പിൽ ഉണ്ട്. മിത്ര ഒരിക്കലും വായ്പ നിർദ്ദേശിക്കില്ല.'
          : 'How to join, and the documents, are in the Mitra app. Mitra never offers loans.');
        return go('together', parts.join(' '));
      }
      if (key === 2) return bulkGroups(d.bulk_requests).length ? go('bulk_pick', '', {}) : go('together', t('noGroups'));
      return sorry('together');
    }
    case 'bulk_pick': {
      if (key === 0) return go('together');
      const g = bulkGroups(d.bulk_requests)[key - 1];
      if (!g) return sorry('bulk_pick');
      if (g.mine) return go('bulk_pick', ml ? `നിങ്ങൾ ${itemOf(g, true)} ഗ്രൂപ്പിൽ ഇപ്പോൾത്തന്നെ ഉണ്ട്.` : `You are already in the ${itemOf(g, false)} group.`);
      return go('bulk_qty', '', { group: key - 1 });
    }
    case 'bulk_qty': {
      const g = bulkGroups(d.bulk_requests)[s.data.group];
      if (!g || !(key >= 1 && key <= 9999)) return go('bulk_qty', t('howMuchNeed'));
      const user = await ctx.store.user();
      await record('bulk_requests', {
        user: USER, name: user.name ?? '', month: g.month, item: g.item, item_ml: g.item_ml, qty: key, unit: g.unit, place: user.place ?? g.place, via: 'call',
      }, `joined the ${itemOf(g, false)} group for ${key} ${unitWord(g.unit, false)}`, `${itemOf(g, true)} ഗ്രൂപ്പിൽ ${key} ${unitWord(g.unit, true)}`);
      return go('together', ml
        ? `ചേർന്നു. ${itemOf(g, true)} ഗ്രൂപ്പിൽ ${key} ${unitWord(g.unit, true)}. ഇപ്പോൾ ${g.rows.length + 1} പേർ ഒരുമിച്ച് വാങ്ങുന്നു.`
        : `Done. You joined the ${itemOf(g, false)} group for ${key} ${unitWord(g.unit, false)}. Now ${g.rows.length + 1} women are buying together.`, {});
    }

    // ----- prices -----
    case 'price_pick': {
      if (key === 0) return go('main');
      const p = d.products.slice(0, 9)[key - 1];
      return p ? go('price_new', '', { product: p.id }) : sorry('price_pick');
    }
    case 'price_new': {
      const p = d.products.find((x) => x.id === s.data.product);
      if (!p || !(key >= 1 && key <= 99999)) return go('price_new', t('priceAgain'));
      await ctx.store.update('products', p.id, { price: key });
      s.actions.push({ col: 'products', id: p.id, say: `changed the price of ${nameOf(p, false)} to ${key} rupees`, sayMl: `${nameOf(p, true)} വില ${key} രൂപ ആക്കി` });
      s.last = null;
      return go('main', ml ? `സേവ് ചെയ്തു. ${nameOf(p, true)} ഇനി ${key} രൂപ.` : `Saved. ${nameOf(p, false)} is now ${key} rupees.`, {});
    }

    default:
      return go('main');
  }
}

module.exports = { ask, hear, newState, totals, bulkGroups, schemeNews, openSchemes, MAIN, T };
