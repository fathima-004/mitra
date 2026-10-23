// POST: rings DEMO_PHONE and starts the Mitra call (the "Call me" button). Owner: Hiba. PLAN.md §5 and §7 step 1.
// It only ever calls the one demo number set on Netlify, so the button cannot be used to call anyone else.
import twilio from 'twilio';
import { json, CORS } from '../lib/twiml.mjs';

let lastCall = 0;
const MIN_GAP_MS = 20000; // one call at a time while the demo phone is ringing

export const handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS, body: '' };
  if (event.httpMethod !== 'POST') return json(405, { error: 'POST only' });

  const { TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_NUMBER, DEMO_PHONE } = process.env;
  if (!TWILIO_ACCOUNT_SID || !TWILIO_AUTH_TOKEN || !TWILIO_NUMBER || !DEMO_PHONE) {
    return json(503, { error: 'Call is not set up: add the Twilio and DEMO_PHONE variables on Netlify.' });
  }
  if (Date.now() - lastCall < MIN_GAP_MS) return json(429, { error: 'A call was just started. Wait a moment.' });

  try {
    const client = twilio(TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN);
    const call = await client.calls.create({
      to: DEMO_PHONE,
      from: TWILIO_NUMBER,
      url: `https://${event.headers.host}/.netlify/functions/voice`,
      method: 'POST',
    });
    lastCall = Date.now();
    return json(200, { ok: true, sid: call.sid });
  } catch (e) {
    console.error('call-me failed', e.message);
    return json(502, { error: 'Twilio could not start the call.', detail: e.message });
  }
};
