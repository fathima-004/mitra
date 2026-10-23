// "Mitra noticed": short, personal facts from her own numbers (Fathima). Plain maths, no AI, no loan advice.
// Each insight: { key, icon, tone, ml, en } (ml/en are HTML-safe text built from her data).
import { thisMonth, monthOf, monthProfit, avgMonthlyProfit } from './calc.js';
import { goalPlan } from './money.js';
import { icon } from './icons.js';

const DAYS_ML = ['ഞായറാഴ്ച', 'തിങ്കളാഴ്ച', 'ചൊവ്വാഴ്ച', 'ബുധനാഴ്ച', 'വ്യാഴാഴ്ച', 'വെള്ളിയാഴ്ച', 'ശനിയാഴ്ച'];
const DAYS_EN = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
const inr = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 });
const rs = (n) => `₹${inr.format(Math.round(n))}`;
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// Quantity sold per calendar day for one product, over the given sales.
function perDay(sales, productId) {
  const days = {};
  for (const s of sales) days[s.date] = (days[s.date] ?? 0) + (s.product === productId ? s.qty : 0);
  return days;
}

// Her best day of the week for her top product.
function bestWeekday(sales, top) {
  const days = perDay(sales, top.id);
  const by = Array.from({ length: 7 }, () => []);
  for (const [date, qty] of Object.entries(days)) by[new Date(`${date}T12:00`).getDay()].push(qty);
  const all = Object.values(days);
  if (all.length < 10) return null;
  const mean = (a) => a.reduce((x, y) => x + y, 0) / a.length;
  const avgAll = mean(all);
  const best = by.map((a, i) => ({ i, avg: a.length ? mean(a) : 0, n: a.length })).filter((d) => d.n >= 2)
    .sort((a, b) => b.avg - a.avg)[0];
  if (!best || avgAll <= 0) return null;
  const more = Math.round((best.avg / avgAll - 1) * 100);
  if (more < 15) return null;
  const name = esc(top.name_ml), q = Math.round(best.avg), usual = Math.round(avgAll);
  return {
    key: 'weekday', icon: 'sparkle', tone: 'tone-gold',
    ml: `${DAYS_ML[best.i]}കളിൽ ${name} ${more}% കൂടുതൽ പോകുന്നു (ഏകദേശം ${q}, മറ്റു ദിവസം ${usual}). അന്ന് കൂടുതൽ ഉണ്ടാക്കാം.`,
    en: `${DAYS_EN[best.i]}s sell ${more}% more ${esc(top.name_en)} (about ${q} vs ${usual}). Make extra that day.`,
  };
}

// A stock item whose price per kg/L went up across her recent bills.
function costRise(purchases, now) {
  const since = new Date(now.getTime() - 62 * 864e5).toISOString().slice(0, 10);
  const groups = {};
  for (const p of purchases) {
    if (p.date < since || !p.qty || !['kg', 'L'].includes(p.unit)) continue;
    (groups[p.item] ??= []).push(p);
  }
  let pick = null;
  for (const list of Object.values(groups)) {
    if (list.length < 2) continue;
    list.sort((a, b) => a.date.localeCompare(b.date));
    const first = list[0].amount / list[0].qty, last = list.at(-1).amount / list.at(-1).qty;
    const up = Math.round((last / first - 1) * 100);
    if (up >= 3 && (!pick || up > pick.up)) pick = { p: list.at(-1), first, last, up };
  }
  if (!pick) return null;
  const { p, first, last, up } = pick;
  return {
    key: 'cost', icon: 'up', tone: 'tone-rose',
    ml: `${esc(p.item_ml ?? p.item)} വില ${up}% കൂടി: ${rs(first)} → ${rs(last)} / ${p.unit}. വേറെ കടയിൽ നോക്കാം, അല്ലെങ്കിൽ അടുത്തുള്ളവരുമായി ഒരുമിച്ച് വാങ്ങാം.`,
    en: `${esc(p.item)} went up ${up}% (${rs(first)} → ${rs(last)} per ${p.unit}). Try another shop, or buy together with women nearby.`,
  };
}

// Where this month is heading, compared with a usual month, and what that means for her goal.
function pace(d, top, now) {
  const month = thisMonth(now);
  const m = monthProfit(d.sales, d.products, d.bills, d.purchases, month);
  const avg = avgMonthlyProfit(d.history, 3);
  if (avg <= 0) return null;
  const daysIn = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
  const soldToday = d.sales.some((s) => s.date === now.toISOString().slice(0, 10));
  const done = Math.max(1, now.getDate() - (soldToday ? 0 : 1));
  if (done < 5) return null;
  const billsTotal = d.bills.filter((b) => b.month === month).reduce((s, b) => s + b.amount, 0);
  const bought = d.purchases.filter((p) => monthOf(p.date) === month).reduce((s, p) => s + p.amount, 0);
  const projected = (m.income / done) * daysIn - billsTotal - (bought / done) * daysIn;
  const gap = avg - projected;

  if (gap > 0 && top) {
    const n = Math.ceil(gap / top.price);
    return {
      key: 'pace', icon: 'down', tone: 'tone-gold',
      ml: `ഈ പോക്കിൽ ഈ മാസം ഏകദേശം ${rs(projected)} ലാഭം. ${n} ${esc(top.name_ml)} കൂടി വിറ്റാൽ സാധാരണ മാസം (${rs(avg)}) എത്തും.`,
      en: `At this pace, about ${rs(projected)} profit this month. ${n} more ${esc(top.name_en)} gets you to a usual month (${rs(avg)}).`,
    };
  }
  const extra = -gap;
  const goal = d.goals?.[0];
  let soonerMl = '', soonerEn = '';
  if (goal && extra >= 500) {
    const now1 = goalPlan(goal, avg), with1 = goalPlan({ ...goal, saved: goal.saved + extra }, avg);
    const gain = (now1.months ?? 0) - (with1.months ?? 0);
    if (gain >= 1) {
      soonerMl = ` ആ ${rs(extra)} മാറ്റിവെച്ചാൽ ${esc(goal.name_ml)} ${gain} മാസം നേരത്തെ കിട്ടും.`;
      soonerEn = ` Put that ${rs(extra)} aside and your ${esc(goal.name_en.split(' (')[0].toLowerCase())} comes ${gain} month${gain > 1 ? 's' : ''} sooner.`;
    }
  }
  return {
    key: 'pace', icon: 'up', tone: 'tone-leaf',
    ml: `നല്ല മാസം! ഈ പോക്കിൽ ഏകദേശം ${rs(projected)} ലാഭം, സാധാരണയേക്കാൾ ${rs(extra)} കൂടുതൽ.${soonerMl}`,
    en: `Good month! At this pace, about ${rs(projected)} profit: ${rs(extra)} more than usual.${soonerEn}`,
  };
}

// A high-price item she sells only a little of: one more a day adds up.
function smallButValuable(sales, products, now) {
  const month = thisMonth(now);
  const days = new Set(sales.filter((s) => monthOf(s.date) === month).map((s) => s.date)).size;
  if (days < 5) return null;
  const pick = products.map((p) => ({
    p, perDay: sales.filter((s) => s.product === p.id && monthOf(s.date) === month).reduce((n, s) => n + s.qty, 0) / days,
  })).filter((x) => x.perDay < 3).sort((a, b) => b.p.price - a.p.price)[0];
  if (!pick || pick.p.price < 50) return null;
  const add = pick.p.price * 30;
  const per = pick.perDay < 1 ? '1-ൽ താഴെ' : `ഏകദേശം ${Math.round(pick.perDay)}`;
  return {
    key: 'small', icon: 'sparkle', tone: 'tone-plum',
    ml: `${esc(pick.p.name_ml)} ദിവസം ${per} മാത്രം. ഓരോന്നിനും ${rs(pick.p.price)}. ദിവസം ഒന്ന് കൂടി വിറ്റാൽ മാസം ${rs(add)} കൂടുതൽ വരുമാനം.`,
    en: `${esc(pick.p.name_en)}: only about ${Math.max(1, Math.round(pick.perDay))} a day, at ${rs(pick.p.price)} each. One more a day = ${rs(add)} more sales a month.`,
  };
}

// Biggest single cost this month and its share of spending.
function bigCost(d, now) {
  const month = thisMonth(now);
  const spend = {};
  for (const b of d.bills.filter((x) => x.month === month)) spend[b.label_en ?? b.type] = { ml: b.label_ml, en: b.label_en ?? b.type, amt: (spend[b.label_en ?? b.type]?.amt ?? 0) + b.amount };
  for (const p of d.purchases.filter((x) => monthOf(x.date) === month)) spend[p.item] = { ml: p.item_ml, en: p.item, amt: (spend[p.item]?.amt ?? 0) + p.amount };
  const list = Object.values(spend);
  const total = list.reduce((s, x) => s + x.amt, 0);
  const top = list.sort((a, b) => b.amt - a.amt)[0];
  if (!top || !total) return null;
  const share = Math.round((top.amt / total) * 100);
  return {
    key: 'bigcost', icon: 'wallet', tone: 'tone-sky',
    ml: `ഏറ്റവും വലിയ ചെലവ്: ${esc(top.ml ?? top.en)}, ${rs(top.amt)} (ആകെ ചെലവിന്റെ ${share}%). ഇവിടെ ലാഭിച്ചാൽ ഏറ്റവും കൂടുതൽ ഗുണം.`,
    en: `${share}% of your spending is ${esc(top.en.toLowerCase())} (${rs(top.amt)}). Saving here helps the most.`,
  };
}

export function insights(d, now = new Date()) {
  const month = thisMonth(now);
  const monthSales = d.sales.filter((s) => monthOf(s.date) === month);
  const income = (p) => monthSales.filter((s) => s.product === p.id).reduce((n, s) => n + s.qty * p.price, 0);
  const top = [...d.products].sort((a, b) => income(b) - income(a))[0];
  return [
    pace(d, top, now),
    top && bestWeekday(d.sales, top),
    costRise(d.purchases, now),
    smallButValuable(d.sales, d.products, now),
    bigCost(d, now),
  ].filter(Boolean);
}

// One insight as a list row (icon badge + Malayalam + English).
export function insightHTML(i) {
  return `<div class="item insight">
    <span class="badge ${i.tone}">${icon(i.icon, 20)}</span>
    <div class="grow"><span class="ml">${i.ml}</span><span class="en">${i.en}</span></div>
  </div>`;
}
