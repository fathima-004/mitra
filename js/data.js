// TEMPORARY version written by Fathima so the screens work before the Firestore version.
// Owner: Hiba. Replace the inside with Firestore + localStorage fallback, but keep every
// exported name and shape below (PLAN.md §5), so no page needs to change.
// This version stores everything in the browser (localStorage) and syncs open tabs.

export const USER = 'demo1';
const KEY = `mitra:${USER}`;
const BULK_KEY = 'mitra:bulk';
const COLLECTIONS = ['products', 'bills', 'purchases', 'sales', 'history', 'goals', 'words'];

const channel = 'BroadcastChannel' in window ? new BroadcastChannel('mitra') : null;
const listeners = new Set();

function read(key, fallback) {
  try {
    const raw = localStorage.getItem(key);
    return raw ? JSON.parse(raw) : fallback;
  } catch {
    return fallback;
  }
}

function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value));
  } catch {
    // Storage full or blocked: keep working in memory for this page.
  }
  notify();
}

function notify() {
  for (const fn of listeners) fn();
  channel?.postMessage('changed');
}
channel?.addEventListener('message', () => { for (const fn of listeners) fn(); });

async function store() {
  let s = read(KEY, null);
  if (!s) {
    await loadDemo();
    s = read(KEY, {});
  }
  return s;
}

const newId = () => Math.random().toString(36).slice(2, 10);

export async function getUser() {
  return (await store()).user ?? {};
}

export async function get(col) {
  return [...((await store())[col] ?? [])];
}

export async function add(col, obj) {
  const s = await store();
  const id = obj.id ?? newId();
  s[col] = [...(s[col] ?? []), { ...obj, id }];
  write(KEY, s);
  return id;
}

export async function update(col, id, obj) {
  const s = await store();
  s[col] = (s[col] ?? []).map((d) => (d.id === id ? { ...d, ...obj, id } : d));
  write(KEY, s);
}

export async function remove(col, id) {
  const s = await store();
  s[col] = (s[col] ?? []).filter((d) => d.id !== id);
  write(KEY, s);
}

// Calls cb(docs) now and after every change (this tab and other tabs). Returns unsubscribe.
export function listen(col, cb) {
  const fire = () => get(col).then(cb);
  listeners.add(fire);
  fire();
  return () => listeners.delete(fire);
}

export async function loadDemo() {
  const demo = await fetch('data/demo.json').then((r) => r.json());
  const s = { user: demo.user };
  for (const c of COLLECTIONS) s[c] = demo[c] ?? [];
  localStorage.setItem(BULK_KEY, JSON.stringify(demo.bulk_requests ?? []));
  write(KEY, s);
}

export async function getBulk() {
  await store();
  return read(BULK_KEY, []);
}

export async function addBulk(obj) {
  const list = await getBulk();
  const id = newId();
  write(BULK_KEY, [...list, { ...obj, id }]);
  return id;
}
