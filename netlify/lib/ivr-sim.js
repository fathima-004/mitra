// Try the full phone menu without a phone. Owner: Hiba.
//   node netlify/lib/ivr-sim.js 1 1 12 0 0      (the keys she presses, in order; 8 switches the language)
// Prints what Mitra says and what was saved. Without Firebase settings it uses an in-memory copy of the
// demo, so nothing is written anywhere.
const path = require('path');
process.chdir(path.join(__dirname, '..', '..'));
// Show the Malayalam words too (they reach Exotel as audio).
const tts = require('./tts');
const realSynth = tts.synth;
let spoken = '';
tts.synth = (text, lang, ms) => {
  spoken = text;
  return realSynth(text, lang, ms);
};
const { handler } = require('../functions/exotel-ivr');
const { store } = require('./ivr-store');

const sid = `SIM${Date.now()}`;
const ev = (q) => ({ httpMethod: 'GET', headers: { host: 'localhost' }, queryStringParameters: { CallSid: sid, ...q } });

(async () => {
  const keys = process.argv.slice(2);
  for (let i = 0; i < 100; i++) {
    const a = JSON.parse((await handler(ev({ do: 'ask' }))).body);
    console.log(a.gather_prompt.audio_url ? `MITRA (Malayalam audio): ${spoken}` : `MITRA: ${a.gather_prompt.text}`);
    const k = keys.shift() ?? '';
    console.log(`  keys: ${k || '(none)'}`);
    const h = await handler(ev({ do: 'hear', digits: `"${k}"` }));
    if (h.statusCode !== 200) break;
  }
  const call = await store().getCall(sid);
  console.log(`\nSaved on this call (${store().kind}):`);
  for (const a of call.ivr.actions.filter((x) => x.col)) console.log(`  ${a.col}/${a.id}: ${a.say}`);
})();
