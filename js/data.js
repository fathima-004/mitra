// Owner: Hiba. Data layer for the app, call.html and the phone call (PLAN.md §5).
// Firestore is the source of truth when it can be reached. Browser storage (localStorage) keeps a
// copy, so the demo still works without Wi-Fi, and writes made offline sync when the page reconnects.
// Keep every exported name and return shape. Pages depend on them.

// Paste the web app config from Firebase: Project settings → Your apps → Config.
// It is public by design; access is controlled by the Firestore rules. While this is null, the app
// runs on browser storage only.
const FIREBASE_CONFIG = null;

const FIREBASE_APP = 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
const FIREBASE_STORE = 'https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js';

export const USER = 'demo1';
const KEY = `mitra:${USER}`;
const BULK_KEY = 'mitra:bulk';
const COLLECTIONS = ['products', 'bills', 'purchases', 'sales', 'history', 'goals', 'words'];
const TIMEOUT_MS = 3000;

const channel = 'BroadcastChannel' in window ? new BroadcastChannel('mitra') : null;
const listeners = new Set();

let fs = null; // Firestore functions, once the SDK has loaded
let db = null; // Firestore instance, null while offline or not configured
let ready = null;

// Loads Firestore, and seeds it with the demo user the first time. Resolves to null when offline.
function connect() {
  ready ??= (async () => {
    if (!FIREBASE_CONFIG) return null;
    try {
      const [app, store] = await Promise.all([import(FIREBASE_APP), import(FIREBASE_STORE)]);
      fs = store;
      const instance = store.getFirestore(app.initializeApp(FIREBASE_CONFIG));
      const user = await timeout(store.getDoc(store.doc(instance, 'users', USER)));
      if (!user.exists()) await timeout(seedRemote(await fetchDemo(), instance), 10000);
      db = instance;
      return db;
    } catch {
      return null;
    }
  })();
  return ready;
}

const timeout = (promise, ms = TIMEOUT_MS) =>
  Promise.race([promise, new Promise((_, reject) => setTimeout(() => reject(new Error('timeout')), ms))]);

// Firestore allows 500 writes per batch; 400 leaves room.
async function commit(instance, ops) {
  for (let i = 0; i < ops.length; i += 400) {
    const batch = fs.writeBatch(instance);
    for (const op of ops.slice(i, i + 400)) op(batch);
    await batch.commit();
  }
}

async function seedRemote(demo, instance = db) {
  const ops = [(b) => b.set(fs.doc(instance, 'users', USER), demo.user)];
  for (const c of COLLECTIONS) {
    for (const row of demo[c] ?? []) ops.push((b) => b.set(fs.doc(instance, 'users', USER, c, row.id), row));
  }
  for (const row of demo.bulk_requests ?? []) ops.push((b) => b.set(fs.doc(instance, 'bulk_requests', row.id), row));
  await commit(instance, ops);
}

async function clearRemote(instance) {
  const ops = [];
  for (const c of COLLECTIONS) {
    const snap = await fs.getDocs(fs.collection(instance, 'users', USER, c));
    for (const d of snap.docs) ops.push((b) => b.delete(d.ref));
  }
  const bulk = await fs.getDocs(fs.collection(instance, 'bulk_requests'));
  for (const d of bulk.docs) ops.push((b) => b.delete(d.ref));
  await commit(instance, ops);
}

const rowOf = (x) => ({ id: x.id, ...x.data() });

function fetchDemo() {
  return fetch('data/demo.json').then((r) => r.json());
}

// Browser storage: the local copy used when Firestore cannot be reached.
function read(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function writeLocal(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage full or blocked: keep working in memory for this page.
  }
}

function write(key, value) {
  writeLocal(key, value);
  notify();
}

function notify() {
  for (const fn of listeners) fn();
  channel?.postMessage('changed');
}
channel?.addEventListener('message', () => { for (const fn of listeners) fn(); });

// Copies rows that came from Firestore into the local copy. Does not notify: the data is not new.
function mirror(col, docs) {
  const s = read(KEY, {});
  s[col] = docs;
  writeLocal(KEY, s);
}

function seedLocal(demo) {
  const s = { user: demo.user };
  for (const c of COLLECTIONS) s[c] = demo[c] ?? [];
  writeLocal(KEY, s);
  writeLocal(BULK_KEY, demo.bulk_requests ?? []);
  return s;
}

async function store() {
  const s = read(KEY, null);
  return s ?? seedLocal(await fetchDemo());
}

// Sends a write to Firestore in the background. The local copy is already updated, and the
// Firestore SDK queues writes made offline until the connection returns.
function sync(fn) {
  connect().then((instance) => instance && fn(instance).catch(() => {}));
}

const newId = () => Math.random().toString(36).slice(2, 10);

export async function getUser() {
  const instance = await connect();
  if (instance) {
    try {
      const snap = await timeout(fs.getDoc(fs.doc(instance, 'users', USER)));
      if (snap.exists()) return snap.data();
    } catch {
      // Offline: use the local copy.
    }
  }
  return (await store()).user ?? {};
}

export async function get(col) {
  const instance = await connect();
  if (instance) {
    try {
      const snap = await timeout(fs.getDocs(fs.collection(instance, 'users', USER, col)));
      const docs = snap.docs.map(rowOf);
      mirror(col, docs);
      return docs;
    } catch {
      // Offline: use the local copy.
    }
  }
  return [...((await store())[col] ?? [])];
}

// Local writes run one after another. Two saves in the same moment (a bill and a purchase, or
// "12 biriyani, 30 chapathi" saved together) would otherwise both read the same old copy, and the
// second write would drop the first one's row. Online, Firestore would repair it; offline, a sale was lost.
let queue = Promise.resolve();
function mutate(key, change, fallback) {
  const run = queue.then(async () => {
    const s = key === KEY ? await store() : read(key, fallback);
    const next = change(s) ?? s;
    write(key, next);
  });
  queue = run.catch(() => {});
  return run;
}

export async function add(col, obj) {
  const id = obj.id ?? newId();
  const row = { ...obj, id };
  await mutate(KEY, (s) => { s[col] = [...(s[col] ?? []), row]; });
  sync((instance) => fs.setDoc(fs.doc(instance, 'users', USER, col, id), row));
  return id;
}

export async function update(col, id, obj) {
  await mutate(KEY, (s) => { s[col] = (s[col] ?? []).map((d) => (d.id === id ? { ...d, ...obj, id } : d)); });
  sync((instance) => fs.setDoc(fs.doc(instance, 'users', USER, col, id), obj, { merge: true }));
}

export async function remove(col, id) {
  await mutate(KEY, (s) => { s[col] = (s[col] ?? []).filter((d) => d.id !== id); });
  sync((instance) => fs.deleteDoc(fs.doc(instance, 'users', USER, col, id)));
}

// Calls cb(docs) now and after every change: from this tab, other tabs, and Firestore itself
// (so a sale saved by the phone call appears here live). Returns unsubscribe.
export function listen(col, cb) {
  const fire = () => get(col).then(cb);
  listeners.add(fire);
  fire();

  let stop = () => {};
  connect().then((instance) => {
    if (!instance) return;
    stop = fs.onSnapshot(
      fs.collection(instance, 'users', USER, col),
      (snap) => {
        const docs = snap.docs.map(rowOf);
        mirror(col, docs);
        cb(docs);
      },
      () => {}
    );
  });

  return () => {
    listeners.delete(fire);
    stop();
  };
}

// Resets demo1 from data/demo.json, in browser storage and in Firestore.
export async function loadDemo() {
  const demo = await fetchDemo();
  seedLocal(demo);
  notify();
  const instance = await connect();
  if (instance) {
    try {
      await timeout(clearRemote(instance), 10000);
      await timeout(seedRemote(demo, instance), 10000);
    } catch {
      // Offline: the local reset still works for this page.
    }
  }
}

export async function getBulk() {
  const instance = await connect();
  if (instance) {
    try {
      const snap = await timeout(fs.getDocs(fs.collection(instance, 'bulk_requests')));
      const list = snap.docs.map(rowOf);
      writeLocal(BULK_KEY, list);
      return list;
    } catch {
      // Offline: use the local copy.
    }
  }
  await store();
  return read(BULK_KEY, []);
}

export async function addBulk(obj) {
  await getBulk(); // refresh the local copy from Firestore when it can be reached
  const id = newId();
  const row = { ...obj, id };
  await mutate(BULK_KEY, (list) => [...list, row], []);
  sync((instance) => fs.setDoc(fs.doc(instance, 'bulk_requests', id), row));
  return id;
}
