// Health check. Open /.netlify/functions/ping after a deploy to confirm functions are live.
// /.netlify/functions/ping?check=1 also says which settings are present and whether Firestore
// answers. It reports names and yes/no only, never the values.
const { db } = require('../lib/firestore');

const NAMES = [
  'EXOTEL_API_KEY', 'EXOTEL_API_TOKEN', 'EXOTEL_SID', 'EXOTEL_SUBDOMAIN', 'EXOPHONE', 'EXOTEL_APP_ID', 'DEMO_PHONE',
  'FIREBASE_SERVICE_ACCOUNT', 'FIREBASE_PROJECT_ID', 'FIREBASE_CLIENT_EMAIL', 'FIREBASE_PRIVATE_KEY',
];

exports.handler = async (event) => {
  const body = { ok: true, time: new Date().toISOString() };
  if (event.queryStringParameters?.check) {
    body.settings = Object.fromEntries(NAMES.map((n) => [n, Boolean(process.env[n])]));
    const key = process.env.FIREBASE_PRIVATE_KEY ?? '';
    body.privateKeyLooksRight = key ? key.includes('BEGIN PRIVATE KEY') && key.includes('END PRIVATE KEY') : null;
    body.privateKeyLength = key.length; // a real key is about 1700 characters; the private_key_id is 40
    body.deployedAt = process.env.DEPLOY_ID ?? null;
    const store = db();
    if (!store) body.firestore = 'not connected (Firebase settings missing or wrong)';
    else {
      try {
        const user = await store.collection('users').doc('demo1').get();
        const sales = await store.collection('users').doc('demo1').collection('sales').count().get();
        body.firestore = 'connected';
        body.demoUser = user.exists ? 'found' : 'missing (open the app once, or press Reset demo, to load it)';
        body.sales = sales.data().count;
      } catch (err) {
        body.firestore = `error: ${err.message.slice(0, 200)}`;
      }
    }
  }
  return { statusCode: 200, headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) };
};
