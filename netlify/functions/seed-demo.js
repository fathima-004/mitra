// One-time: copy Sheela's example month (web/data/demo.json) into Firestore, in the same layout as
// seedRemote() in js/data.js. Owner: Fathima (call agent).
// POST /.netlify/functions/seed-demo — writes only if users/demo1 does not exist yet, so it never
// overwrites data. To reload the demo later, use "Reset demo" in the app.
const demo = require('../../web/data/demo.json');
const { db } = require('../lib/firestore');

const USER = 'demo1';
const COLLECTIONS = ['products', 'bills', 'purchases', 'sales', 'history', 'goals', 'words'];

exports.handler = async (event) => {
  if (event.httpMethod !== 'POST') return { statusCode: 405, body: 'POST only' };
  const store = db();
  if (!store) return { statusCode: 500, body: 'Firestore not connected' };

  const userRef = store.collection('users').doc(USER);
  if ((await userRef.get()).exists) return { statusCode: 200, body: 'already there, nothing written' };

  const writes = [(b) => b.set(userRef, demo.user)];
  for (const c of COLLECTIONS) {
    for (const row of demo[c] ?? []) writes.push((b) => b.set(userRef.collection(c).doc(row.id), row));
  }
  for (const row of demo.bulk_requests ?? []) writes.push((b) => b.set(store.collection('bulk_requests').doc(row.id), row));

  for (let i = 0; i < writes.length; i += 400) {
    const batch = store.batch();
    writes.slice(i, i + 400).forEach((w) => w(batch));
    await batch.commit();
  }
  return { statusCode: 200, body: `loaded ${writes.length} documents` };
};
