// Key 2: speaks this month's profit. Owner: Hiba. PLAN.md §7 step 7.
// The maths is js/calc.js, the same file the app uses, so the call and the laptop always agree.
import { say, response, redirect, verified, forbidden } from '../lib/twiml.mjs';
import { rows, monthIST } from '../lib/store.mjs';
import { monthProfit, breakdown } from '../../js/calc.js';

const rs = (n) => Math.round(Math.abs(n)).toLocaleString('en-IN');

export const handler = async (event) => {
  if (!verified(event)) return forbidden;
  const [sales, products, bills, purchases] = await Promise.all(
    ['sales', 'products', 'bills', 'purchases'].map(rows),
  );
  const month = monthIST();
  const m = monthProfit(sales, products, bills, purchases, month);
  const top = breakdown(sales, products, bills, purchases, month).byProduct.find((r) => r.qty > 0);

  const profitLine = m.profit >= 0
    ? say(`ഈ മാസം ഇതുവരെ നിങ്ങളുടെ ലാഭം ${rs(m.profit)} രൂപ.`, `This month so far, your profit is ${rs(m.profit)} rupees.`)
    : say(`ഈ മാസം ഇതുവരെ ചെലവ് വരുമാനത്തേക്കാൾ ${rs(m.profit)} രൂപ കൂടുതലാണ്.`, `This month so far, spending is ${rs(m.profit)} rupees more than income.`);

  return response(`
    ${profitLine}
    ${say(`വരുമാനം ${rs(m.income)} രൂപ. ചെലവ് ${rs(m.spending)} രൂപ.`, `Income ${rs(m.income)} rupees. Spending ${rs(m.spending)} rupees.`)}
    ${top ? say(`ഏറ്റവും കൂടുതൽ വരുമാനം ${top.product.name_ml} വഴി.`, `Your best seller is ${top.product.name_en}.`) : ''}
    ${redirect(event, 'voice', { menu: 1 })}`);
};
