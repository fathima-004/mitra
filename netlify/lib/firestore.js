// Firestore from Netlify Functions (firebase-admin). Owner: Fathima (call agent).
// Needs the FIREBASE_SERVICE_ACCOUNT environment variable (the service-account JSON, PLAN.md §4).
// Without it, db() returns null and the call still runs; it just can't save or read live data.
const admin = require('firebase-admin');

let instance;

function db() {
  if (instance !== undefined) return instance;
  // Either the whole service-account JSON, or its three fields as separate variables (smaller,
  // useful because Netlify Functions allow only about 4 KB of environment variables in total).
  const env = process.env;
  if (!env.FIREBASE_SERVICE_ACCOUNT && !env.FIREBASE_PRIVATE_KEY) return (instance = null);
  try {
    const account = env.FIREBASE_SERVICE_ACCOUNT
      ? JSON.parse(env.FIREBASE_SERVICE_ACCOUNT)
      : {
          project_id: env.FIREBASE_PROJECT_ID,
          client_email: env.FIREBASE_CLIENT_EMAIL,
          private_key: env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
        };
    if (!admin.apps.length) admin.initializeApp({ credential: admin.credential.cert(account) });
    instance = admin.firestore();
  } catch (err) {
    console.error('Firestore init failed', err.message);
    instance = null;
  }
  return instance;
}

module.exports = { db };
