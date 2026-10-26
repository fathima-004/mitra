// Money Health maths (Fathima). Pure functions, no data access, no AI. Never suggests a loan or lender.
import { thisMonth } from './calc.js';

// "YYYY-MM" that is `n` months after `month`.
export function addMonths(month, n) {
  const [y, m] = month.split('-').map(Number);
  const d = new Date(y, m - 1 + n, 1);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
}

// Savings goal: how far along, how much is left, and when it's ready if she keeps saving `goal.monthly`.
// `share` = how much of a usual month's profit the monthly saving takes.
export function goalPlan(goal, avgProfit) {
  const pct = goal.target > 0 ? Math.min(100, Math.round((goal.saved / goal.target) * 100)) : 0;
  const left = Math.max(0, goal.target - goal.saved);
  const months = left === 0 ? 0 : goal.monthly > 0 ? Math.ceil(left / goal.monthly) : null;
  return {
    pct,
    left,
    months,
    ready: months === null ? null : addMonths(thisMonth(), months),
    share: avgProfit > 0 ? goal.monthly / avgProfit : null,
  };
}

// A new EMI she is thinking about: what's left of a usual month and of her worst month after paying it.
// level: 'ok' (easy), 'tight' (possible but careful), 'risky' (worst month goes below zero or EMI takes too much).
export function emiCheck(newEmi, avgProfit, worstMonthProfit) {
  const afterAvg = avgProfit - newEmi;
  const afterWorst = worstMonthProfit - newEmi;
  const share = avgProfit > 0 ? newEmi / avgProfit : 1;
  const level = afterWorst < 0 || share > 0.4 ? 'risky' : share > 0.2 ? 'tight' : 'ok';
  return { afterAvg, afterWorst, share, level };
}

// Sales this financial year vs the registration limit in data/limits.json.
export function gstStatus(turnover, limits) {
  const g = limits.gst;
  const limit = g[g.use];
  return {
    limit,
    turnover,
    pct: limit > 0 ? Math.min(100, (turnover / limit) * 100) : 0,
    left: Math.max(0, limit - turnover),
    needed: turnover >= limit,
    checked: Boolean(g.checked_by && g.date_checked),
  };
}

// GST she already paid on purchases this financial year (`purchase.gst`, optional field).
// Finished months come from history totals (gst_paid), this month from her purchase entries.
export function gstPaid(purchases, fyStart, history = []) {
  const current = thisMonth();
  const past = history.filter((h) => h.month >= fyStart && h.month < current)
    .reduce((sum, h) => sum + (h.gst_paid ?? 0), 0);
  const now = purchases.filter((p) => p.date.slice(0, 7) === current)
    .reduce((sum, p) => sum + (p.gst ?? 0), 0);
  return past + now;
}
