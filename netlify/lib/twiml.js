// TwiML helpers shared by the Twilio voice functions. Owner: Hiba.
const twilio = require('twilio');

const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' };
const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ESC[c]);

// Spoken prompt. Fathima's Malayalam clips (PLAN.md §7) replace these once they are in audio/.
const say = (text) => `<Say voice="Polly.Aditi" language="en-IN">${esc(text)}</Say>`;

const response = (inner) => ({
  statusCode: 200,
  headers: { 'Content-Type': 'text/xml; charset=utf-8' },
  body: `<?xml version="1.0" encoding="UTF-8"?><Response>${inner}</Response>`,
});

const fnUrl = (event, name) => `https://${event.headers.host}/.netlify/functions/${name}`;

// Twilio sends a form-encoded POST body.
function form(event) {
  const raw = event.isBase64Encoded ? Buffer.from(event.body ?? '', 'base64').toString('utf8') : event.body ?? '';
  return Object.fromEntries(new URLSearchParams(raw));
}

// Rejects requests not signed by Twilio. With TWILIO_AUTH_TOKEN unset (local testing only),
// every request is accepted, so always set the token on Netlify.
function verified(event) {
  const token = process.env.TWILIO_AUTH_TOKEN;
  if (!token) return true;
  const signature = event.headers['x-twilio-signature'];
  const url = `https://${event.headers.host}${event.path}`;
  return twilio.validateRequest(token, signature ?? '', url, form(event));
}

const forbidden = { statusCode: 403, body: 'Invalid Twilio signature' };

module.exports = { say, response, fnUrl, form, verified, forbidden, esc };
