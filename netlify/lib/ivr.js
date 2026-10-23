// The whole Mitra phone menu, keypad only, as one small state machine. Owner: Hiba.
//
// Exotel flow (docs/exotel-full-call.md): Gather (exotel-ivr?do=ask) → Passthru (exotel-ivr?do=hear) → back to
// the Gather, round and round, until she presses 0 on the main menu; then Passthru answers "end" and the call
// goes to Hangup. ask() says what to say now; hear() acts on the keys she pressed.
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
//   9 Repeat              0 Finish (summary, goodbye)

const USER = 'demo1';

// ---------- dates (India time) and money (same rules as js/calc.js) ----------
const ist = (now) => new Date(now.getTime() + 5.5 * 3600 * 1000);
const todayOf = (now) => ist(now).toISOString().slice(0, 10);
const timeOf = (now) => ist(now).toISOString().slice(11, 16);
const monthOfNow = (now) => todayOf(now).slice(0, 7);
const rs = (n) => `${Math.round(n)} rupees`;

function addMonths(month, n) {
  const [y, m] = month.split('-').map(Number);
  const d = new Date(Date.UTC(y, m - 1 + n, 1));
  return d.toISOString().slice(0, 7);
}
const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const monthName = (month) => `${MONTHS[Number(month.slice(5, 7)) - 1]} ${month.slice(0, 4)}`;

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

// ---------- what she can pick ----------
const EXPENSES = [
  { cat: 'ingredients', en: 'Ingredients', ml: 'ചേരുവകൾ', say: 'ingredients like rice or oil' },
  { cat: 'gas', en: 'Gas', ml: 'ഗ്യാസ്', say: 'gas' },
  { cat: 'packaging', en: 'Packaging', ml: 'പാക്കിംഗ്', say: 'packaging' },
  { cat: 'transport', en: 'Transport', ml: 'യാത്ര', say: 'transport' },
  { cat: 'other', en: 'Other', ml: 'മറ്റുള്ളവ', say: 'anything else' },
];
const BILLS = [
  { type: 'gas', en: 'Gas', ml: 'ഗ്യാസ്' },
  { type: 'electricity', en: 'Electricity', ml: 'കറന്റ്' },
  { type: 'rent', en: 'Rent', ml: 'വാടക' },
  { type: 'emi', en: 'EMI', ml: 'ഇഎംഐ' },
  { type: 'other', en: 'Other', ml: 'മറ്റുള്ളവ' },
];

const list = (items, label) => items.map((x, i) => `For ${label(x)}, press ${i + 1}.`).join(' ');

// ---------- government scheme news: hand-checked file first, then the official PIB feed ----------
const SCHEME_WORDS = /scheme|yojana|mission|women|woman|mahila|self[- ]help|\bshg|kudumbashree|msme|micro|entrepreneur|startup|artisan|vendor|food processing|skill|livelihood|nari|lakhpati|didi|subsid|grant|training|udyam/i;
const LOAN_WORDS = /loan|credit|lend|lender|nbfc|mudra|svanidhi|guarantee|interest rate|borrow|microfinance|debt/i;
const PIB = 'https://www.pib.gov.in/RssMain.aspx?ModId=6&Lang=1&Regid=3&reg=3';

async function schemeNews(fetchImpl = fetch) {
  try {
    const checked = require('../../data/schemes.json');
    const rows = (Array.isArray(checked) ? checked : checked.schemes ?? [])
      .filter((s) => /^https?:\/\//.test(s.source_url ?? '') && s.date_checked && (s.title_en || s.name_en));
    if (rows.length) return rows.slice(0, 3).map((s) => s.title_en ?? s.name_en);
  } catch {
    // no hand-checked file yet
  }
  try {
    const res = await fetchImpl(PIB, { signal: AbortSignal.timeout(3500), headers: { 'User-Agent': 'Mitra/1.0' } });
    const xml = await res.text();
    const titles = [...xml.matchAll(/<item>\s*<title>([\s\S]*?)<\/title>/g)].map((m) => m[1].replace(/<!\[CDATA\[|\]\]>/g, '').trim());
    return titles.filter((t) => SCHEME_WORDS.test(t) && !LOAN_WORDS.test(t)).slice(0, 2);
  } catch {
    return [];
  }
}

// ---------- the menu ----------
const MAIN = 'Main menu. To add a sale, press 1. To add an expense, press 2. For your money, profit and savings, press 3. '
  + 'For government schemes and buying together, press 4. To change a price, press 5. To hear this again, press 9. To finish, press 0.';

function newState(now) {
  return { node: 'main', msg: 'Hello, this is Mitra.', data: {}, seq: 0, handled: -1, idle: 0, n: 0, actions: [], last: null, started: now.toISOString() };
}

/** What Mitra says now, and how many keys to wait for. */
async function ask(state, ctx) {
  const d = await ctx.load();
  const s = state;
  const pre = s.msg ? `${s.msg} ` : '';
  s.msg = '';
  s.seq += 1;
  const menu = (text, digits = 1) => ({ text: pre + text, digits, finish: digits > 1 ? '#' : '' });
  const product = d.products.find((p) => p.id === s.data.product);

  switch (s.node) {
    case 'main': return menu(MAIN);
    case 'sale_pick': return menu(`What did you sell? ${list(d.products.slice(0, 9), (p) => p.name_en)} For the main menu, press 0.`);
    case 'sale_qty': return menu(`How many ${product?.name_en ?? 'items'} did you sell? Type the number, then press hash.`, 3);
    case 'exp_pick': return menu(`What did you spend on? ${list(EXPENSES, (e) => e.say)} For the main menu, press 0.`);
    case 'exp_amt': return menu(`How much did you spend on ${EXPENSES.find((e) => e.cat === s.data.cat)?.say}? Type the rupees, then press hash.`, 6);
    case 'after_add': return menu('To add another, press 1. To undo that, press 2. For the main menu, press 0.');
    case 'money': return menu('Your money. For today and this month\'s profit, press 1. For the monthly report, press 2. '
      + 'For your savings goal, press 3. For monthly bills, press 4. For GST paid this year, press 5. For the main menu, press 0.');
    case 'goal_menu': return menu('To add to your savings, press 1. To go back, press 0.');
    case 'goal_amt': return menu('How much did you save? Type the rupees, then press hash.', 6);
    case 'bills_menu': return menu('To add a bill, press 1. To go back, press 0.');
    case 'bill_pick': return menu(`Which bill? ${list(BILLS, (b) => b.en)} To go back, press 0.`);
    case 'bill_amt': return menu(`How much is the ${BILLS.find((b) => b.type === s.data.bill)?.en} bill? Type the rupees, then press hash.`, 6);
    case 'together': return menu('For government scheme news, press 1. To buy stock together with women near you, press 2. For the main menu, press 0.');
    case 'bulk_pick': {
      const groups = bulkGroups(d.bulk_requests);
      const text = groups.slice(0, 9).map((g, i) => `Group ${i + 1}: ${g.item}, ${g.rows.length} women, ${g.total} ${unitWord(g.unit)} so far. `
        + (g.mine ? 'You are already in it.' : `To join, press ${i + 1}.`)).join(' ');
      return menu(`${text} To go back, press 0.`);
    }
    case 'bulk_qty': {
      const g = bulkGroups(d.bulk_requests)[s.data.group];
      return menu(`How much ${g?.item ?? ''} do you need, in ${unitWord(g?.unit) || 'units'}? Type the number, then press hash.`, 4);
    }
    case 'price_pick': return menu(`Which price? ${list(d.products.slice(0, 9), (p) => `${p.name_en}, now ${p.price} rupees`)} For the main menu, press 0.`);
    case 'price_new': return menu(`Type the new price of ${product?.name_en ?? 'it'} in rupees, then press hash.`, 5);
    case 'end': return { text: `${pre}${summary(s)} Thank you. Goodbye from Mitra.`, digits: 1, finish: '', timeout: 1 };
    default:
      s.node = 'main';
      return menu(MAIN);
  }
}

function bulkGroups(rows) {
  const groups = new Map();
  for (const r of rows) {
    const k = `${r.month}|${r.item}`;
    if (!groups.has(k)) groups.set(k, { key: k, item: r.item, item_ml: r.item_ml, month: r.month, unit: r.unit ?? '', place: r.place, rows: [] });
    groups.get(k).rows.push(r);
  }
  return [...groups.values()].sort((a, b) => a.key.localeCompare(b.key)).map((g) => ({
    ...g,
    total: g.rows.reduce((n, r) => n + (Number(r.qty) || 0), 0),
    mine: g.rows.some((r) => r.user === USER),
  }));
}

function summary(s) {
  const changes = s.actions.filter((a) => a.col);
  if (!changes.length) return 'Nothing was changed on this call.';
  return `On this call you made ${changes.length} change${changes.length > 1 ? 's' : ''}: ${changes.map((a) => a.say).join('; ')}. It is all in your Mitra app.`;
}

// "L" → "litres" so the phone voice reads units properly.
const UNITS = { l: 'litres', kg: 'kilos', g: 'grams', pcs: 'pieces', nos: 'pieces' };
const unitWord = (u) => UNITS[String(u ?? '').toLowerCase()] ?? String(u ?? '');

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

  const digits = String(raw ?? '').replace(/["\s#*]/g, '');
  if (!digits) {
    s.idle += 1;
    if (s.idle >= 3) {
      s.node = 'end';
      s.msg = 'I did not hear any key.';
    } else {
      s.msg = 'I did not hear a key.';
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
  const record = async (col, row, say) => {
    const rid = id(col[0]);
    await ctx.store.set(col, rid, row);
    s.last = { col, id: rid, say, kind: s.node };
    s.actions.push({ col, id: rid, say });
    return rid;
  };
  const sorry = (node) => go(node, 'Sorry, that key is not on the menu.');

  switch (s.node) {
    case 'main':
      if (key === 1) return go('sale_pick', '', {});
      if (key === 2) return go('exp_pick', '', {});
      if (key === 3) return go('money');
      if (key === 4) return go('together');
      if (key === 5) return go('price_pick', '', {});
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
      if (!p || !(key >= 1 && key <= 999)) return go('sale_qty', 'Please type a number from 1 to 999.');
      const say = `${key} ${p.name_en}, ${rs(key * (Number(p.price) || 0))}`;
      await record('sales', { date: todayOf(now), time: timeOf(now), product: p.id, qty: key, via: 'call' }, `sold ${say}`);
      s.data = { again: 'sale_pick' };
      return go('after_add', `Saved. ${say}.`, s.data);
    }

    // ----- expenses -----
    case 'exp_pick': {
      if (key === 0) return go('main');
      const e = EXPENSES[key - 1];
      return e ? go('exp_amt', '', { cat: e.cat }) : sorry('exp_pick');
    }
    case 'exp_amt': {
      const e = EXPENSES.find((x) => x.cat === s.data.cat);
      if (!e || !(key >= 1 && key <= 999999)) return go('exp_amt', 'Please type the amount in rupees.');
      await record('purchases', {
        date: todayOf(now), time: timeOf(now), cat: e.cat, item: e.en, item_ml: e.ml, qty: 1, unit: '', amount: key, gst: 0, via: 'call',
      }, `spent ${rs(key)} on ${e.say}`);
      return go('after_add', `Saved. ${rs(key)} for ${e.say}.`, { again: 'exp_pick' });
    }

    case 'after_add':
      if (key === 1) return go(s.data.again ?? 'main', '', {});
      if (key === 2 && s.last) {
        await ctx.store.remove(s.last.col, s.last.id);
        s.actions = s.actions.filter((a) => a.id !== s.last.id);
        s.last = null;
        return go('main', 'Removed.', {});
      }
      if (key === 0) return go('main', '', {});
      return sorry('after_add');

    // ----- my money -----
    case 'money': {
      if (key === 0) return go('main');
      const month = monthOfNow(now);
      const t = totals(d, month);
      if (key === 1) {
        const today = totals({ ...d, sales: d.sales.filter((x) => x.date === todayOf(now)), bills: [], purchases: [] }, month);
        return go('money', `Today you sold ${rs(today.income)}. This month so far: income ${rs(t.income)}, `
          + `spending ${rs(t.spending)}, ${t.profit >= 0 ? `profit ${rs(t.profit)}` : `loss ${rs(-t.profit)}`}.`);
      }
      if (key === 2) {
        const best = t.byProduct.find((r) => r.qty > 0);
        const last = d.history.find((h) => h.month === addMonths(month, -1));
        const lastProfit = last ? last.income - last.spending : null;
        const compare = lastProfit === null ? ''
          : t.profit >= lastProfit ? ` That is ${rs(t.profit - lastProfit)} more than last month.` : ` That is ${rs(lastProfit - t.profit)} less than last month so far.`;
        return go('money', `Report for ${monthName(month)}. Income ${rs(t.income)}. Spending ${rs(t.spending)}. Profit ${rs(t.profit)}.`
          + `${best ? ` Your best seller is ${best.p.name_en}, ${best.qty} sold, ${rs(best.income)}.` : ''}${compare}`);
      }
      if (key === 3) {
        const g = d.goals[0];
        if (!g) return go('money', 'You have no savings goal yet. You can set one in the Mitra app.');
        return go('goal_menu', goalLine(g, month));
      }
      if (key === 4) {
        const bills = d.bills.filter((b) => b.month === month);
        const total = bills.reduce((n, b) => n + (Number(b.amount) || 0), 0);
        return go('bills_menu', `This month's bills come to ${rs(total)}. ${bills.map((b) => `${b.label_en ?? b.type} ${rs(b.amount)}`).join(', ')}.`);
      }
      if (key === 5) {
        const fyStart = (() => { const [y, m] = month.split('-').map(Number); return `${m >= 4 ? y : y - 1}-04`; })();
        const past = d.history.filter((h) => h.month >= fyStart && h.month < month).reduce((n, h) => n + (Number(h.gst_paid) || 0), 0);
        const now2 = d.purchases.filter((p) => String(p.date).slice(0, 7) === month).reduce((n, p) => n + (Number(p.gst) || 0), 0);
        return go('money', `GST you paid on what you bought this year: ${rs(past + now2)}. This is guidance only. `
          + 'Please confirm with your Kudumbashree M E C or a tax consultant.');
      }
      return sorry('money');
    }
    case 'goal_menu':
      if (key === 1) return go('goal_amt');
      if (key === 0) return go('money');
      return sorry('goal_menu');
    case 'goal_amt': {
      const g = d.goals[0];
      if (!g || !(key >= 1 && key <= 999999)) return go('goal_amt', 'Please type the amount in rupees.');
      const saved = (Number(g.saved) || 0) + key;
      await ctx.store.update('goals', g.id, { saved });
      s.actions.push({ col: 'goals', id: g.id, say: `added ${rs(key)} to savings` });
      s.last = null; // a savings change isn't undone with "2"; she can change it in the app
      return go('money', `Saved. ${goalLine({ ...g, saved }, monthOfNow(now))}`);
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
      if (!b || !(key >= 1 && key <= 999999)) return go('bill_amt', 'Please type the amount in rupees.');
      await record('bills', { month: monthOfNow(now), type: b.type, label_en: b.en, label_ml: b.ml, amount: key, via: 'call' }, `added a ${b.en} bill of ${rs(key)}`);
      return go('money', `Saved. ${b.en} bill, ${rs(key)}.`, {});
    }

    // ----- schemes and buying together -----
    case 'together': {
      if (key === 0) return go('main');
      if (key === 1) {
        const news = await schemeNews(ctx.fetch);
        s.actions.push({ col: null, id: null, say: 'heard scheme news' });
        return go('together', news.length
          ? `Latest from the Government: ${news.join('. ')}. The details and links are in the Mitra app. Mitra never offers loans.`
          : 'There is no new scheme news today. The Mitra app shows the latest updates.');
      }
      if (key === 2) {
        return bulkGroups(d.bulk_requests).length ? go('bulk_pick', '', {}) : go('together', 'There are no groups buying together right now.');
      }
      return sorry('together');
    }
    case 'bulk_pick': {
      if (key === 0) return go('together');
      const groups = bulkGroups(d.bulk_requests);
      const g = groups[key - 1];
      if (!g) return sorry('bulk_pick');
      if (g.mine) return go('bulk_pick', `You are already in the ${g.item} group.`);
      return go('bulk_qty', '', { group: key - 1 });
    }
    case 'bulk_qty': {
      const g = bulkGroups(d.bulk_requests)[s.data.group];
      if (!g || !(key >= 1 && key <= 9999)) return go('bulk_qty', 'Please type how much you need.');
      const user = await ctx.store.user();
      await record('bulk_requests', {
        user: USER, name: user.name ?? '', month: g.month, item: g.item, item_ml: g.item_ml, qty: key, unit: g.unit, place: user.place ?? g.place, via: 'call',
      }, `joined the ${g.item} group for ${key} ${unitWord(g.unit)}`);
      return go('together', `Done. You joined the ${g.item} group for ${key} ${unitWord(g.unit)}. Now ${g.rows.length + 1} women are buying together.`, {});
    }

    // ----- prices -----
    case 'price_pick': {
      if (key === 0) return go('main');
      const p = d.products.slice(0, 9)[key - 1];
      return p ? go('price_new', '', { product: p.id }) : sorry('price_pick');
    }
    case 'price_new': {
      const p = d.products.find((x) => x.id === s.data.product);
      if (!p || !(key >= 1 && key <= 99999)) return go('price_new', 'Please type the price in rupees.');
      await ctx.store.update('products', p.id, { price: key });
      s.actions.push({ col: 'products', id: p.id, say: `changed the price of ${p.name_en} to ${rs(key)}` });
      s.last = null;
      return go('main', `Saved. ${p.name_en} is now ${rs(key)}.`, {});
    }

    default:
      return go('main');
  }
}

function goalLine(g, month) {
  const target = Number(g.target) || 0;
  const saved = Number(g.saved) || 0;
  const left = Math.max(0, target - saved);
  const pct = target > 0 ? Math.min(100, Math.round((saved / target) * 100)) : 0;
  const name = String(g.name_en ?? 'your goal').split(' (')[0];
  if (left === 0) return `${name}: you have reached your goal of ${rs(target)}!`;
  const months = Number(g.monthly) > 0 ? Math.ceil(left / Number(g.monthly)) : null;
  return `${name}: saved ${rs(saved)} of ${rs(target)}, that is ${pct} percent. ${rs(left)} to go.`
    + (months ? ` Saving ${rs(g.monthly)} a month, you will get there by ${monthName(addMonths(month, months))}.` : '');
}

module.exports = { ask, hear, newState, totals, bulkGroups, schemeNews, MAIN };
