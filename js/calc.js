// Profit maths shared by the app screens and the call. Pure functions, no data access.
// Owner: Hiba (first version written by Fathima). Keep names and return shapes (PLAN.md §5).

export const monthOf = (isoDate) => isoDate.slice(0, 7);
export const thisMonth = (now = new Date()) => localISO(now).slice(0, 7);
export const today = (now = new Date()) => localISO(now);

function localISO(d) {
  const z = new Date(d.getTime() - d.getTimezoneOffset() * 60000);
  return z.toISOString().slice(0, 10);
}

const priceMap = (products) => Object.fromEntries(products.map((p) => [p.id, p.price]));

export function salesIncome(sales, products) {
  const price = priceMap(products);
  return sales.reduce((sum, s) => sum + s.qty * (price[s.product] ?? 0), 0);
}

export function monthIncome(sales, products, month) {
  return salesIncome(sales.filter((s) => monthOf(s.date) === month), products);
}

export function monthSpending(bills, purchases, month) {
  const b = bills.filter((x) => x.month === month).reduce((sum, x) => sum + x.amount, 0);
  const p = purchases.filter((x) => monthOf(x.date) === month).reduce((sum, x) => sum + x.amount, 0);
  return b + p;
}

export function monthProfit(sales, products, bills, purchases, month) {
  const income = monthIncome(sales, products, month);
  const spending = monthSpending(bills, purchases, month);
  return { income, spending, profit: income - spending };
}

// What sold best and where the money went this month.
export function breakdown(sales, products, bills, purchases, month) {
  const byProduct = products.map((p) => {
    const qty = sales.filter((s) => s.product === p.id && monthOf(s.date) === month)
      .reduce((sum, s) => sum + s.qty, 0);
    return { product: p, qty, income: qty * p.price };
  }).sort((a, b) => b.income - a.income);

  const spend = {};
  for (const b of bills.filter((x) => x.month === month)) {
    const key = b.label_en ?? b.type;
    spend[key] = { label_ml: b.label_ml ?? key, label_en: key, amount: (spend[key]?.amount ?? 0) + b.amount };
  }
  for (const p of purchases.filter((x) => monthOf(x.date) === month)) {
    const key = p.item;
    spend[key] = { label_ml: p.item_ml ?? key, label_en: key, amount: (spend[key]?.amount ?? 0) + p.amount };
  }
  const bySpend = Object.values(spend).sort((a, b) => b.amount - a.amount);
  return { byProduct, bySpend };
}

// Average profit of the last `months` finished months, from history totals.
export function avgMonthlyProfit(history, months = 3) {
  const last = [...history].sort((a, b) => a.month.localeCompare(b.month)).slice(-months);
  if (!last.length) return 0;
  return Math.round(last.reduce((sum, h) => sum + (h.income - h.spending), 0) / last.length);
}

export function worstMonth(history) {
  return [...history].sort((a, b) => (a.income - a.spending) - (b.income - b.spending))[0] ?? null;
}

// Indian financial year starts 1 April. Returns "YYYY-04".
export function fyStart(now = new Date()) {
  const y = now.getMonth() >= 3 ? now.getFullYear() : now.getFullYear() - 1;
  return `${y}-04`;
}

// Sales this financial year: finished months from history + this month's sales entries.
export function yearTurnover(sales, products, history, start = fyStart()) {
  const current = thisMonth();
  const past = history.filter((h) => h.month >= start && h.month < current)
    .reduce((sum, h) => sum + h.income, 0);
  return past + monthIncome(sales, products, current);
}
