// Firestore access for the call (firebase-admin). Owner: Hiba. Same shapes as PLAN.md §5.
// Without FIREBASE_SERVICE_ACCOUNT, or when Firestore is slow, reads fall back to data/demo.json, so the
// call still speaks the right menu and profit. Writes return false, so the call never claims a save it did not make.
import { initializeApp, cert, getApps } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { today, thisMonth } from '../../js/calc.js';
import demo from '../../data/demo.json' with { type: 'json' };

export const USER = 'demo1';
const TIMEOUT_MS = 4000;

let db;
function firestore() {
  if (db !== undefined) return db;
  db = null;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return db;
  try {
    const app = getApps()[0] ?? initializeApp({ credential: cert(JSON.parse(raw)) });
    db = getFirestore(app);
  } catch (e) {
    console.error('Firestore init failed', e.message);
  }
  return db;
}

export const hasFirestore = () => Boolean(firestore());

const timeout = (promise, ms = TIMEOUT_MS) =>
  Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), ms))]);

// India time, whatever the server's time zone is. Sales are dated by her day, not by UTC.
export const istNow = () => new Date(Date.now() + (330 + new Date().getTimezoneOffset()) * 60000);
export const todayIST = () => today(istNow());
export const monthIST = () => thisMonth(istNow());

// users/demo1/{col} as an array of rows.
export async function rows(col) {
  const d = firestore();
  if (d) {
    try {
      const snap = await timeout(d.collection('users').doc(USER).collection(col).get());
      const list = snap.docs.map((x) => ({ id: x.id, ...x.data() }));
      // An empty product list means Firestore was never seeded. The demo products keep the call usable.
      if (list.length || col !== 'products') return list;
    } catch (e) {
      console.error(`read ${col} failed`, e.message);
    }
  }
  return structuredClone(demo[col] ?? []);
}

// Saves the confirmed items as sales with via:"call". The app's listen('sales') shows them live.
export async function saveSales(items, via = 'call') {
  const d = firestore();
  if (!d) return false;
  try {
    const col = d.collection('users').doc(USER).collection('sales');
    const batch = d.batch();
    for (const i of items) {
      const ref = col.doc();
      batch.set(ref, { id: ref.id, date: todayIST(), product: i.product, qty: i.qty, via, createdAt: Date.now() });
    }
    await timeout(batch.commit());
    return true;
  } catch (e) {
    console.error('save sales failed', e.message);
    return false;
  }
}

// Every sentence and which step understood it (PLAN.md §7a), so the word lists can be improved.
export async function logSpeech(entry) {
  const d = firestore();
  if (!d) {
    console.log('call_log', JSON.stringify(entry));
    return;
  }
  try {
    await timeout(d.collection('call_logs').add({ ...entry, at: FieldValue.serverTimestamp() }), 2000);
  } catch (e) {
    console.error('call log failed', e.message);
  }
}

// Call session (PLAN.md §5 calls/{callSid}). Best effort only: the URL carries what the call needs.
export async function setCall(callSid, data) {
  const d = firestore();
  if (!d || !callSid) return;
  try {
    await timeout(d.collection('calls').doc(callSid).set({ ...data, updatedAt: Date.now() }, { merge: true }), 2000);
  } catch (e) {
    console.error('call state failed', e.message);
  }
}
