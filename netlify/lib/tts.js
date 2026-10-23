// Text → speech for the phone menu. Owner: Hiba.
// Exotel's own voice speaks English only, and the Malayalam prompts carry live numbers ("ലാഭം 12457 രൂപ"),
// so they are spoken with Microsoft's neural Malayalam voice (the same voice as the recorded clips made with
// tools/make_call_audio.py), generated while the call runs. Returns an MP3 buffer, or throws.
const { MsEdgeTTS, OUTPUT_FORMAT } = require('msedge-tts');

const VOICES = { ml: 'ml-IN-SobhanaNeural', en: 'en-IN-NeerjaNeural' };
const ESC = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&apos;' };

async function once(text, lang, ms) {
  const tts = new MsEdgeTTS();
  const work = (async () => {
    await tts.setMetadata(VOICES[lang] ?? VOICES.ml, OUTPUT_FORMAT.AUDIO_24KHZ_48KBITRATE_MONO_MP3);
    const { audioStream } = tts.toStream(String(text).replace(/[&<>"']/g, (c) => ESC[c]));
    const chunks = [];
    for await (const c of audioStream) chunks.push(c);
    const buf = Buffer.concat(chunks);
    if (buf.length < 1000) throw new Error(`audio too short (${buf.length} bytes)`);
    return buf;
  })();
  try {
    return await Promise.race([work, new Promise((_, no) => setTimeout(() => no(new Error('tts timeout')), ms))]);
  } finally {
    try {
      tts.close();
    } catch {
      // already closed
    }
  }
}

// Microsoft's service refuses about half of new connections at random (it answers "200" instead of opening the
// socket), so try up to five times with a short pause; a refusal takes about half a second. Prompts already made (the menus, which
// repeat) are reused while the function stays warm.
const cache = new Map();
async function synth(text, lang = 'ml', ms = 7000) {
  const key = `${lang}|${text}`;
  if (cache.has(key)) return cache.get(key);
  let last;
  for (let i = 0; i < 5; i++) {
    if (i) await new Promise((ok) => setTimeout(ok, 250));
    try {
      const mp3 = await once(text, lang, ms);
      if (cache.size > 60) cache.delete(cache.keys().next().value);
      cache.set(key, mp3);
      return mp3;
    } catch (err) {
      last = err;
    }
  }
  throw last;
}

module.exports = { synth, VOICES };
