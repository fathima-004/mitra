// Firestore from Netlify Functions (firebase-admin). Owner: Fathima (call agent).
// Needs the FIREBASE_SERVICE_ACCOUNT environment variable (the service-account JSON, PLAN.md §4).
// Without it, db() returns null and the call still runs; it just can't save or read live data.
const admin = require('firebase-admin');

let instance;

function db() {
  if (instance !== undefined) return instance;
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (!raw) return (instance = null);
  try {
    if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(JSON.parse(raw)) });
    instance = admin.firestore();
  } catch (err) {
    console.error('Firestore init failed', err.message);
    instance = null;
  }
  return instance;
}

module.exports = { db };
