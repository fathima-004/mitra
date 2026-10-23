// POST { text, products } → { items:[{product, qty}], source, sure }. Owner: Hiba. PLAN.md §5 and §7a.
// Word lists first, then the AI backup chosen by AI_PROVIDER. Used by call.html; the phone call uses
// the same code directly. Nothing is saved here: the caller reads the result back and confirms it.
import { json, CORS } from '../lib/twiml.mjs';
import { understand } from '../lib/understand.mjs';
import { rows } from '../lib/store.mjs';

export const handler = async (event) => {
  if (event.httpMethod === 'OPTIONS') return { statusCode: 204, headers: CORS, body: '' };
  if (event.httpMethod !== 'POST') return json(405, { error: 'POST only' });

  let body;
  try {
    body = JSON.parse(event.body ?? '{}');
  } catch {
    return json(400, { error: 'Body must be JSON' });
  }

  const text = String(body.text ?? '').slice(0, 500).trim();
  if (!text) return json(400, { error: 'text is required' });

  // Only the fields the parser needs, and a sensible number of products.
  let products = Array.isArray(body.products) ? body.products.slice(0, 30) : [];
  products = products
    .filter((p) => p && typeof p.id === 'string' && typeof p.name_en === 'string')
    .map((p) => ({ id: p.id, name_en: p.name_en.slice(0, 60), name_ml: String(p.name_ml ?? '').slice(0, 60) }));
  if (!products.length) products = await rows('products');

  const words = await rows('words');
  const result = await understand(text, products, { host: event.headers.host, words });
  return json(200, result);
};
