// Storage for the full phone menu (netlify/lib/ivr.js). Owner: Hiba.
// Same paths and shapes as the app (PLAN.md §5): users/demo1/{sales,purchases,bills,goals,products},
// bulk_requests/{id}, and the call session in calls/{CallSid}. Every change is written the moment she
// confirms it, so the app updates live during the call.
// Without Firebase settings it keeps everything in memory (from data/demo.json), so the call can still
// be tried end to end; nothing is lost from Firestore because nothing was written there.
const demo = require('../../data/demo.json');
const { db } = require('./firestore');

const USER = 'demo1';

function firestoreStore(fs) {
  const col = (name) => (name === 'bulk_requests' ? fs.collection('bulk_requests') : fs.collection('users').doc(USER).collection(name));
  // The app reads users/demo1 every few seconds; a new changedAt tells it to reload everything (not just today's sales).
  const touch = () => fs.collection('users').doc(USER).set({ changedAt: new Date().toISOString() }, { merge: true });
  return {
    kind: 'firestore',
    async user() {
      const d = await fs.collection('users').doc(USER).get();
      return d.exists ? d.data() : demo.user;
    },
    async list(name) {
      const snap = await col(name).get();
      return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    },
    async set(name, id, row) {
      await col(name).doc(id).set({ ...row, id });
      await touch();
    },
    async update(name, id, patch) {
      await col(name).doc(id).set(patch, { merge: true });
      await touch();
    },
    async remove(name, id) {
      await col(name).doc(id).delete();
      await touch();
    },
    // Her language (users/demo1.lang), shared with the app's language switch.
    async setLang(lang) {
      await fs.collection('users').doc(USER).set({ lang, changedAt: new Date().toISOString() }, { merge: true });
    },
    // The spoken prompt for one step of the call (Malayalam audio), fetched by Exotel right after.
    async setAudio(sid, seq, mp3) {
      await fs.collection('call_audio').doc(sid).set({ seq, mp3: mp3.toString('base64'), at: new Date().toISOString() });
    },
    async getAudio(sid) {
      const d = await fs.collection('call_audio').doc(sid).get();
      return d.exists ? Buffer.from(d.data().mp3, 'base64') : null;
    },
    async getCall(sid) {
      const d = await fs.collection('calls').doc(sid).get();
      return d.exists ? d.data() : null;
    },
    async setCall(sid, state) {
      await fs.collection('calls').doc(sid).set({ ...state, updatedAt: new Date().toISOString() });
    },
  };
}

// In-memory copy of the demo, shared by every call while the function stays warm.
function memoryStore() {
  const data = { bulk_requests: structuredClone(demo.bulk_requests ?? []) };
  for (const c of ['products', 'bills', 'purchases', 'sales', 'history', 'goals']) data[c] = structuredClone(demo[c] ?? []);
  const calls = new Map();
  const audio = new Map();
  const user = structuredClone(demo.user);
  return {
    kind: 'memory',
    data,
    async user() {
      return structuredClone(user);
    },
    async setLang(lang) {
      user.lang = lang;
    },
    async setAudio(sid, seq, mp3) {
      audio.set(sid, mp3);
    },
    async getAudio(sid) {
      return audio.get(sid) ?? null;
    },
    async list(name) {
      return structuredClone(data[name] ?? []);
    },
    async set(name, id, row) {
      data[name] = [...(data[name] ?? []).filter((r) => r.id !== id), { ...row, id }];
    },
    async update(name, id, patch) {
      data[name] = (data[name] ?? []).map((r) => (r.id === id ? { ...r, ...patch } : r));
    },
    async remove(name, id) {
      data[name] = (data[name] ?? []).filter((r) => r.id !== id);
    },
    async getCall(sid) {
      return calls.has(sid) ? structuredClone(calls.get(sid)) : null;
    },
    async setCall(sid, state) {
      calls.set(sid, structuredClone(state));
    },
  };
}

let memory;
function store() {
  const fs = db();
  if (fs) return firestoreStore(fs);
  memory ??= memoryStore();
  return memory;
}

module.exports = { store, memoryStore, USER };
