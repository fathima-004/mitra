// TwiML helpers shared by the Twilio voice functions. Owner: Hiba.
import twilio from 'twilio';

const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' };
export const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ESC[c]);

// Spoken prompt, Malayalam text first, English second.
// Set ML_VOICE on Netlify (for example Google.ml-IN-Wavenet-A) once a Malayalam voice is tested on the
// account. Until then the English line is spoken with an Indian English voice, which always works.
export const isMalayalam = () => Boolean(process.env.ML_VOICE);

export function say(ml, en) {
  const voice = process.env.ML_VOICE;
  if (voice) return `<Say voice="${esc(voice)}" language="ml-IN">${esc(ml)}</Say>`;
  return `<Say voice="Polly.Aditi" language="en-IN">${esc(en)}</Say>`;
}

export const response = (inner) => ({
  statusCode: 200,
  headers: { 'Content-Type': 'text/xml; charset=utf-8' },
  body: `<?xml version="1.0" encoding="UTF-8"?><Response>${inner}</Response>`,
});

// Absolute URL of another function, with an optional query. Escaped, ready to put in TwiML.
export function fnUrl(event, name, query = {}) {
  const q = new URLSearchParams(query).toString();
  return esc(`https://${event.headers.host}/.netlify/functions/${name}${q ? `?${q}` : ''}`);
}

export const redirect = (event, name, query) => `<Redirect method="POST">${fnUrl(event, name, query)}</Redirect>`;

// Twilio sends a form-encoded POST body.
export function form(event) {
  const raw = event.isBase64Encoded ? Buffer.from(event.body ?? '', 'base64').toString('utf8') : event.body ?? '';
  return Object.fromEntries(new URLSearchParams(raw));
}

export const query = (event) => event.queryStringParameters ?? {};

// Rejects requests not signed by Twilio. Twilio signs the full URL including the query string,
// so the query must be part of the URL we check. With TWILIO_AUTH_TOKEN unset (local testing only),
// every request is accepted, so always set the token on Netlify.
export function verified(event) {
  const token = process.env.TWILIO_AUTH_TOKEN;
  if (!token) return true;
  const signature = event.headers['x-twilio-signature'] ?? '';
  const raw = event.rawQuery ? `?${event.rawQuery}` : '';
  const url = `https://${event.headers.host}${event.path}${raw}`;
  return twilio.validateRequest(token, signature, url, form(event));
}

export const forbidden = { statusCode: 403, body: 'Invalid Twilio signature' };

// Pending sale items travel in the URL ("p1:12,p2:30"), so the call works even if Firestore is down.
export const packItems = (items) => items.map((i) => `${i.product}:${i.qty}`).join(',');

export function unpackItems(s) {
  return String(s ?? '').split(',').filter(Boolean).map((pair) => {
    const [product, qty] = pair.split(':');
    return { product, qty: Math.floor(Number(qty)) };
  }).filter((i) => i.product && i.qty >= 1 && i.qty <= 999);
}

// "12 ബിരിയാണി, 30 ചപ്പാത്തി" or "12 Biriyani, 30 Chapathi"
export function itemsLine(items, products, lang) {
  return items.map((i) => {
    const p = products.find((x) => x.id === i.product);
    const name = lang === 'ml' ? p?.name_ml ?? p?.name_en : p?.name_en;
    return `${i.qty} ${name ?? i.product}`;
  }).join(', ');
}

// JSON response for the browser and the Flutter app (a different origin on Flutter web).
export const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'Content-Type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export const json = (status, obj) => ({
  statusCode: status,
  headers: { 'Content-Type': 'application/json', ...CORS },
  body: JSON.stringify(obj),
});

// "12 Biriyani, 30 Chapathi. Is that right? Press 1 for yes, 2 for no."
// With no key pressed, confirm is called without Digits and reads it back again (tries counts that).
export function readBack(event, items, products, tries = 0) {
  const ml = itemsLine(items, products, 'ml');
  const en = itemsLine(items, products, 'en');
  const packed = packItems(items);
  return response(`
    <Gather input="dtmf" numDigits="1" timeout="8" method="POST" action="${fnUrl(event, 'confirm', { items: packed })}">
      ${say(`${ml}. ശരിയാണെങ്കിൽ 1, തെറ്റാണെങ്കിൽ 2 അമർത്തുക.`, `${en}. If this is right, press 1. If it is wrong, press 2.`)}
    </Gather>
    ${redirect(event, 'confirm', { items: packed, tries: tries + 1 })}`);
}
