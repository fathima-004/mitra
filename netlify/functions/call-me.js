// "Mitra, call me": Exotel rings the demo phone and plays the Mitra call flow.
// Owner: Fathima (call agent). Used by the "Call me" button in the app (PLAN.md §5).
// Env: EXOTEL_API_KEY, EXOTEL_API_TOKEN, EXOTEL_SID, EXOTEL_SUBDOMAIN, EXOPHONE, EXOTEL_APP_ID, DEMO_PHONE.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};
const reply = (statusCode, body) => ({ statusCode, headers: { ...CORS, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });

exports.handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS };
  if (event.httpMethod !== 'POST') return reply(405, { error: 'POST only' });

  const env = process.env;
  const missing = ['EXOTEL_API_KEY', 'EXOTEL_API_TOKEN', 'EXOTEL_SID', 'EXOTEL_SUBDOMAIN', 'EXOPHONE', 'EXOTEL_APP_ID', 'DEMO_PHONE']
    .filter((k) => !env[k]);
  if (missing.length) return reply(500, { error: `missing env: ${missing.join(', ')}` });

  const host = env.EXOTEL_SUBDOMAIN.replace(/^https?:\/\//, '').replace(/\/$/, '');
  const form = new URLSearchParams({
    From: env.DEMO_PHONE,
    CallerId: env.EXOPHONE,
    Url: `http://my.exotel.com/${env.EXOTEL_SID}/exoml/start_voice/${env.EXOTEL_APP_ID}`,
    CallType: 'trans',
    TimeLimit: '300',
  });

  try {
    const res = await fetch(`https://${host}/v1/Accounts/${env.EXOTEL_SID}/Calls/connect.json`, {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${env.EXOTEL_API_KEY}:${env.EXOTEL_API_TOKEN}`).toString('base64')}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: form,
      signal: AbortSignal.timeout(8000),
    });
    const text = await res.text();
    if (!res.ok) {
      console.error('Exotel call failed', res.status, text);
      return reply(502, { error: 'exotel', status: res.status, detail: text.slice(0, 300) });
    }
    const sid = JSON.parse(text)?.Call?.Sid;
    return reply(200, { ok: true, sid });
  } catch (err) {
    console.error('Exotel call error', err.message);
    return reply(502, { error: err.message });
  }
};
