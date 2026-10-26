// Helpers shared by the Exotel call functions. Owner: Fathima (call agent).
// Exotel calls our URLs with GET and URL-encoded call details (CallSid, CallFrom, digits, ...).
const demo = require('../../web/data/demo.json');
const { db } = require('./firestore');

const USER = 'demo1';

// Query string (GET) and form body (POST) together.
function params(event) {
  const raw = event.isBase64Encoded ? Buffer.from(event.body ?? '', 'base64').toString('utf8') : event.body ?? '';
  return { ...Object.fromEntries(new URLSearchParams(raw)), ...(event.queryStringParameters ?? {}) };
}

// Exotel sends digits wrapped in double quotes, e.g. "\"12\"".
const digitsOf = (p) => String(p.digits ?? '').replace(/["\s#*]/g, '');

// Exotel doesn't sign its requests. If EXOTEL_HOOK_KEY is set, every URL configured in the
// Exotel flow must end with ?key=<that value>, so strangers can't write sales.
function allowed(p) {
  const key = process.env.EXOTEL_HOOK_KEY;
  return !key || p.key === key;
}

const json = (body, statusCode = 200) => ({
  statusCode,
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body),
});
const forbidden = json({ error: 'forbidden' }, 403);

// Public URL of a Malayalam clip (.wav) in web/audio/exotel/ (served by Netlify from web/).
const audio = (event, name) => `https://${event.headers.host}/audio/exotel/${name}.wav`;

// Her products in menu order (Firestore, else the demo file).
async function products() {
  const store = db();
  if (store) {
    try {
      const snap = await store.collection('users').doc(USER).collection('products').get();
      if (!snap.empty) return snap.docs.map((d) => ({ id: d.id, ...d.data() })).sort((a, b) => a.id.localeCompare(b.id));
    } catch (err) {
      console.error('products read failed', err.message);
    }
  }
  return demo.products;
}

// Call session: which product she picked. Firestore calls/{CallSid}, plus memory as a backup.
const memory = new Map();
async function setPending(callSid, data) {
  memory.set(callSid, data);
  const store = db();
  if (store) {
    await store.collection('calls').doc(callSid).set({ ...data, updatedAt: new Date().toISOString() }, { merge: true })
      .catch((err) => console.error('call session write failed', err.message));
  }
}
async function getPending(callSid) {
  const store = db();
  if (store) {
    try {
      const doc = await store.collection('calls').doc(callSid).get();
      if (doc.exists) return doc.data();
    } catch (err) {
      console.error('call session read failed', err.message);
    }
  }
  return memory.get(callSid) ?? null;
}

// Today and this month in India time, as "YYYY-MM-DD" / "YYYY-MM".
function todayIST() {
  return new Date(Date.now() + 5.5 * 3600 * 1000).toISOString().slice(0, 10);
}

// This month's profit. Same maths as monthProfit() in js/calc.js: income from sales minus bills
// and purchases of this month. Plain code, no AI.
async function monthProfit() {
  const store = db();
  if (!store) return null;
  const month = todayIST().slice(0, 7);
  const col = (name) => store.collection('users').doc(USER).collection(name).get().then((s) => s.docs.map((d) => d.data()));
  const [sales, prods, bills, purchases] = await Promise.all([col('sales'), col('products'), col('bills'), col('purchases')]);
  const price = Object.fromEntries(prods.map((p) => [p.id, p.price]));
  const income = sales.filter((s) => s.date?.slice(0, 7) === month).reduce((sum, s) => sum + s.qty * (price[s.product] ?? 0), 0);
  const spending = bills.filter((b) => b.month === month).reduce((sum, b) => sum + b.amount, 0)
    + purchases.filter((p) => p.date?.slice(0, 7) === month).reduce((sum, p) => sum + p.amount, 0);
  return income - spending;
}

module.exports = { USER, params, digitsOf, allowed, json, forbidden, audio, products, setPending, getPending, todayIST, monthProfit };
