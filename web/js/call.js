// Browser call page: the same menu, understanding and save as the phone call (PLAN.md §7, call.html). Owner: Hiba.
import { get, add } from './data.js';
import { monthProfit, breakdown, thisMonth, today } from './calc.js';
import { rupees, renderNav, toast } from './app.js';
import { parse } from './parse.js';

const $ = (id) => document.getElementById(id);

// Text for this page. Malayalam first, English under it.
const T = {
  home_sales: ['വിൽപ്പന ചേർക്കുക', 'Add today\'s sales'],
  home_profit: ['ഈ മാസത്തെ ലാഭം', 'This month\'s profit'],
  ask: ['ഇന്ന് എന്തൊക്കെ വിറ്റു?', 'What did you sell today?'],
  example: ['ഉദാഹരണം: "ഇന്ന് 12 ബിരിയാണി വിറ്റു"', 'Example: "innu 12 biriyani poyi"'],
  speak: ['🎤 സംസാരിക്കുക', '🎤 Speak'],
  type_it: ['അല്ലെങ്കിൽ ടൈപ്പ് ചെയ്യുക', 'Or type it'],
  understand: ['മനസ്സിലാക്കുക', 'Understand'],
  readback_q: ['ശരിയാണോ?', 'Is this right?'],
  yes: ['1 · ശരി, സേവ് ചെയ്യുക', '1 · Yes, save'],
  again: ['2 · വീണ്ടും പറയാം', '2 · Say it again'],
  not_sure: ['മനസ്സിലായില്ല. താഴെ എണ്ണം ടൈപ്പ് ചെയ്യുക', 'Didn\'t catch it. Type the numbers below'],
  save: ['സേവ് ചെയ്യുക', 'Save'],
  saved: ['സേവ് ആയി', 'Saved'],
  nothing: ['ഒന്നും സേവ് ചെയ്തില്ല', 'Nothing to save'],
  no_voice: ['ഈ ബ്രൗസറിൽ സംസാരം പ്രവർത്തിക്കില്ല. ടൈപ്പ് ചെയ്യൂ.', 'Voice doesn\'t work in this browser. Type instead.'],
  voice_error: ['സംസാരം കേട്ടില്ല. വീണ്ടും ശ്രമിക്കൂ.', 'Didn\'t hear that. Try again.'],
  income: ['വരുമാനം', 'Income'],
  spending: ['ചെലവ്', 'Spending'],
  listen: ['🔊 കേൾക്കുക', '🔊 Listen'],
  title: ['വിളി', 'Phone call'],
};
const t = (key) => `<span class="ml">${T[key][0]}</span><span class="en">${T[key][1]}</span>`;

let products = [];
let bills = [];
let purchases = [];
let pending = null; // items waiting for "yes"

async function load() {
  [products, bills, purchases] = await Promise.all([get('products'), get('bills'), get('purchases')]);
}

function show(screen) {
  for (const s of ['home', 'sales', 'profit']) $(s).hidden = s !== screen;
  window.scrollTo(0, 0);
}

function clearSalesUI() {
  pending = null;
  $('text').value = '';
  $('readback').hidden = true;
  $('keypad').hidden = true;
}

function nameOf(id) {
  return products.find((p) => p.id === id)?.name_ml ?? id;
}

// Read-back: "12 ബിരിയാണി, 30 ചപ്പാത്തി. ശരിയാണോ?"
function showReadback(items) {
  pending = items;
  const line = items.map((i) => `${i.qty} ${nameOf(i.product)}`).join(', ');
  $('readback-text').textContent = line;
  $('readback').hidden = false;
  $('keypad').hidden = true;
}

// Keypad: one number box per product, for when the words were not clear.
function showKeypad(prefill) {
  const rows = products.map((p) => {
    const found = prefill.find((i) => i.product === p.id);
    return `<label class="field"><span class="ml">${p.name_ml}</span><span class="en">${p.name_en}</span>
      <input type="number" inputmode="numeric" min="0" max="999" data-product="${p.id}" value="${found?.qty ?? ''}"></label>`;
  }).join('');
  $('keypad-rows').innerHTML = rows;
  $('keypad').hidden = false;
  $('readback').hidden = true;
}

async function saveItems(items) {
  const usable = items.filter((i) => i.qty > 0);
  if (!usable.length) {
    toast(`${T.nothing[0]} · ${T.nothing[1]}`);
    return;
  }
  for (const i of usable) {
    await add('sales', { date: today(), product: i.product, qty: i.qty, via: 'web-call' });
  }
  toast(`✅ ${T.saved[0]} · ${T.saved[1]}`);
  clearSalesUI();
  show('home');
}

function understand() {
  const text = $('text').value.trim();
  if (!text) return;
  const result = parse(text, products);
  if (result.sure) showReadback(result.items);
  else {
    $('keypad-note').innerHTML = t('not_sure');
    showKeypad(result.items);
  }
}

// Speech recognition in Malayalam, where the browser supports it (Chrome on Android and desktop).
const Recognition = window.SpeechRecognition ?? window.webkitSpeechRecognition;

function startSpeech() {
  const rec = new Recognition();
  rec.lang = 'ml-IN';
  rec.interimResults = false;
  rec.maxAlternatives = 1;
  rec.onresult = (e) => {
    $('text').value = e.results[0][0].transcript;
    understand();
  };
  rec.onerror = () => toast(`${T.voice_error[0]} · ${T.voice_error[1]}`);
  rec.start();
}

function speak(text) {
  if (!('speechSynthesis' in window)) return;
  const u = new SpeechSynthesisUtterance(text);
  u.lang = 'ml-IN';
  speechSynthesis.cancel();
  speechSynthesis.speak(u);
}

async function renderProfit() {
  const sales = await get('sales');
  const month = thisMonth();
  const m = monthProfit(sales, products, bills, purchases, month);
  $('profit-number').textContent = rupees(m.profit);
  $('profit-number').className = `big-number ${m.profit >= 0 ? 'positive' : 'negative'}`;
  $('profit-income').textContent = rupees(m.income);
  $('profit-spend').textContent = rupees(m.spending);

  const b = breakdown(sales, products, bills, purchases, month);
  $('profit-products').innerHTML = b.byProduct
    .filter((r) => r.qty > 0)
    .map((r) => `<div class="row"><span><span class="ml">${r.product.name_ml}</span><span class="en">${r.product.name_en}</span></span><span class="amount">${r.qty} · ${rupees(r.income)}</span></div>`)
    .join('') || `<p class="muted">${T.nothing[0]}</p>`;

  $('read-aloud').onclick = () => speak(`ഈ മാസത്തെ ലാഭം ${rupees(m.profit)}`);
}

function init() {
  renderNav();
  $('title').innerHTML = t('title');
  $('home-sales').innerHTML = t('home_sales');
  $('home-profit').innerHTML = t('home_profit');
  $('ask').innerHTML = t('ask');
  $('example').innerHTML = t('example');
  $('speak').innerHTML = t('speak');
  $('type-label').innerHTML = t('type_it');
  $('understand').innerHTML = t('understand');
  $('readback-q').innerHTML = t('readback_q');
  $('yes').innerHTML = t('yes');
  $('again').innerHTML = t('again');
  $('keypad-save').innerHTML = t('save');
  $('read-aloud').innerHTML = t('listen');
  $('profit-income-label').innerHTML = t('income');
  $('profit-spend-label').innerHTML = t('spending');

  if (!Recognition) {
    $('speak').hidden = true;
    toast(`${T.no_voice[0]} · ${T.no_voice[1]}`);
  }

  $('home-sales').addEventListener('click', async () => { await load(); clearSalesUI(); show('sales'); });
  $('home-profit').addEventListener('click', async () => { await load(); await renderProfit(); show('profit'); });
  $('back-sales').addEventListener('click', () => { clearSalesUI(); show('home'); });
  $('back-profit').addEventListener('click', () => show('home'));
  $('speak').addEventListener('click', startSpeech);
  $('understand').addEventListener('click', understand);
  $('yes').addEventListener('click', () => saveItems(pending ?? []));
  $('again').addEventListener('click', () => { clearSalesUI(); $('text').focus(); });
  $('keypad-save').addEventListener('click', () => {
    const items = [...document.querySelectorAll('#keypad-rows input')]
      .map((el) => ({ product: el.dataset.product, qty: Math.min(999, Math.max(0, Math.floor(Number(el.value) || 0))) }));
    saveItems(items);
  });
}

init();
