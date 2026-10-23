// Speech text → [{product, qty}] for the call and the parse endpoint (PLAN.md §7a). Owner: Hiba.
// 1. Word lists (js/parse.js + data/synonyms.json + her personal words). 2. Free AI backup chosen by
// AI_PROVIDER. 3. Keypad, handled by the caller when sure is false. The AI never does maths: it only
// names products and quantities, and every result is read back and confirmed before saving.
import { parse } from '../../js/parse.js';

const AI_TIMEOUT_MS = 4000;

// data/synonyms.json is fetched from the deployed site, so Fathima's word list updates go live
// with a normal push. Missing file = built-in words only. Cached while the function stays warm.
let synonymsCache = null;
let synonymsAt = 0;
async function synonyms(host) {
  if (synonymsCache && Date.now() - synonymsAt < 60000) return synonymsCache;
  try {
    const res = await fetch(`https://${host}/data/synonyms.json`, { signal: AbortSignal.timeout(1500) });
    synonymsCache = res.ok ? await res.json() : {};
  } catch {
    synonymsCache = synonymsCache ?? {};
  }
  synonymsAt = Date.now();
  return synonymsCache;
}

function prompt(text, products) {
  const list = products.map((p) => `${p.id} = ${p.name_en} (${p.name_ml ?? ''})`).join('\n');
  return `A woman who runs a small food business in Kerala said what she sold today, in Malayalam or Manglish.
Her products:
${list}

What she said: "${text}"

Reply with JSON only, in this exact shape: {"items":[{"product":"p1","qty":12}]}
Use only the product ids above. qty is a whole number she said. Do not add anything she did not say.
If you are not sure, reply {"items":[]}.`;
}

async function askGemini(p) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return null;
  const model = process.env.GEMINI_MODEL ?? 'gemini-2.5-flash';
  const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': key },
    body: JSON.stringify({
      contents: [{ parts: [{ text: p }] }],
      generationConfig: { temperature: 0, responseMimeType: 'application/json' },
    }),
    signal: AbortSignal.timeout(AI_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`gemini ${res.status}`);
  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.map((x) => x.text).join('') ?? '';
}

async function askGroq(p) {
  const key = process.env.GROQ_API_KEY;
  if (!key) return null;
  const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
    body: JSON.stringify({
      model: process.env.GROQ_MODEL ?? 'llama-3.3-70b-versatile',
      temperature: 0,
      response_format: { type: 'json_object' },
      messages: [{ role: 'user', content: p }],
    }),
    signal: AbortSignal.timeout(AI_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`groq ${res.status}`);
  const data = await res.json();
  return data.choices?.[0]?.message?.content ?? '';
}

async function askClaude(p) {
  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) return null;
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-api-key': key, 'anthropic-version': '2023-06-01' },
    body: JSON.stringify({
      model: process.env.CLAUDE_MODEL ?? 'claude-haiku-5-5',
      max_tokens: 200,
      temperature: 0,
      messages: [{ role: 'user', content: p }],
    }),
    signal: AbortSignal.timeout(AI_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`claude ${res.status}`);
  const data = await res.json();
  return data.content?.map((x) => x.text ?? '').join('') ?? '';
}

const PROVIDERS = { gemini: askGemini, groq: askGroq, claude: askClaude };

// Keeps only items with a known product id and a whole quantity from 1 to 999.
export function validItems(raw, products) {
  let parsed;
  try {
    const s = String(raw ?? '');
    parsed = JSON.parse(s.slice(s.indexOf('{'), s.lastIndexOf('}') + 1));
  } catch {
    return [];
  }
  const ids = new Set(products.map((p) => p.id));
  const totals = {};
  for (const i of Array.isArray(parsed?.items) ? parsed.items : []) {
    const qty = Number(i?.qty);
    if (!ids.has(i?.product) || !Number.isInteger(qty) || qty < 1 || qty > 999) continue;
    totals[i.product] = (totals[i.product] ?? 0) + qty;
  }
  return Object.entries(totals)
    .filter(([, qty]) => qty <= 999)
    .map(([product, qty]) => ({ product, qty }));
}

// Only demo data is ever sent here (CLAUDE.md): the product list and the spoken sentence.
async function askAI(text, products) {
  const name = (process.env.AI_PROVIDER ?? 'gemini').toLowerCase();
  const ask = PROVIDERS[name];
  if (!ask) return null;
  try {
    const raw = await ask(prompt(text, products));
    if (raw === null) return null; // no key for this provider
    const items = validItems(raw, products);
    return { items, sure: items.length > 0, source: name };
  } catch (e) {
    console.error('AI backup failed', e.message);
    return null;
  }
}

export async function understand(text, products, { host, words = [] } = {}) {
  const extra = { synonyms: host ? await synonyms(host) : {}, words };
  const byWords = parse(text, products, extra);
  if (byWords.sure) return byWords;
  const byAI = await askAI(text, products);
  if (byAI?.sure) return byAI;
  // Not sure: keep what the word lists found so the keypad can start from it.
  return { ...byWords, sure: false };
}
