// The full Mitra phone menu for Exotel (netlify/lib/ivr.js). Owner: Hiba.
// Exotel flow, built once in App Bazaar (docs/exotel-full-call.md):
//   [1] Gather (programmable)  /.netlify/functions/exotel-ivr?do=ask   → next: [2]
//   [2] Passthru               /.netlify/functions/exotel-ivr?do=hear  → 200 OK: back to [1] · otherwise: [3]
//   [3] Hangup
// do=ask  answers Exotel's Programmable Gather with what to say and how many keys to collect.
//         In Malayalam the prompt is spoken audio (netlify/lib/tts.js), stored for this call and handed to Exotel
//         as a link (do=say). If the voice fails, the prompt falls back to Exotel's English voice.
// do=hear gets the keys she pressed (Exotel sends them as `digits`), saves what she confirmed to Firestore,
//         and answers 200 to keep going, or IVR_END_STATUS (default 302) to hang up.
// do=say  serves the audio made for the current step.
// The call's language is the one chosen in the app (users/demo1.lang); key 8 switches it for both.
const { params, allowed, json, forbidden } = require('../lib/exotel');
const { store } = require('../lib/ivr-store');
const { ask, hear, newState, T } = require('../lib/ivr');
const { synth } = require('../lib/tts');

function context(p) {
  const s = store();
  let cache = null;
  return {
    store: s,
    sid: p.CallSid,
    now: () => new Date(),
    fetch,
    async load() {
      if (!cache) {
        const names = ['products', 'sales', 'purchases', 'bills', 'goals', 'history', 'bulk_requests'];
        const lists = await Promise.all(names.map((n) => s.list(n)));
        cache = Object.fromEntries(names.map((n, i) => [n, lists[i]]));
        cache.products.sort((a, b) => String(a.id).localeCompare(String(b.id)));
      }
      return cache;
    },
  };
}

// Link Exotel fetches the spoken prompt from (same key as the flow URLs, if one is set).
function sayUrl(event, p, seq) {
  const q = new URLSearchParams({ do: 'say', CallSid: p.CallSid, seq: String(seq) });
  if (p.key) q.set('key', p.key);
  return `https://${event.headers.host}/.netlify/functions/exotel-ivr?${q}`;
}

async function gatherReply(event, p, ctx, state, say, before) {
  const reply = {
    max_input_digits: say.digits,
    finish_on_key: say.finish,
    input_timeout: say.timeout ?? (say.digits > 1 ? 12 : 8),
    repeat_menu: 1,
  };
  if (say.lang === 'ml' && process.env.CALL_VOICE !== 'exotel') {
    try {
      const mp3 = await synth(say.text, 'ml');
      await ctx.store.setAudio(p.CallSid, state.seq, mp3);
      return { ...reply, gather_prompt: { audio_url: sayUrl(event, p, state.seq) } };
    } catch (err) {
      console.error('Malayalam voice failed, using English text', err.message);
      // Fall through: English words for the same step, so she is never left in silence.
      const copy = { ...structuredClone(before), lang: 'en' };
      if (/[ഀ-ൿ]/.test(copy.msg ?? '')) copy.msg = ''; // the English voice can't read Malayalam letters
      const english = await ask(copy, ctx).catch(() => null);
      return { ...reply, gather_prompt: { text: english?.text ?? T.main[0] } };
    }
  }
  return { ...reply, gather_prompt: { text: say.text } };
}

exports.handler = async (event) => {
  const p = params(event);
  if (!allowed(p)) return forbidden;
  if (!p.CallSid) return json({ error: 'CallSid missing' }, 400);
  const ctx = context(p);

  if (p.do === 'say') {
    const mp3 = await ctx.store.getAudio(p.CallSid).catch(() => null);
    if (!mp3) return { statusCode: 404, body: 'no audio' };
    return { statusCode: 200, headers: { 'Content-Type': 'audio/mpeg', 'Cache-Control': 'no-store' }, body: mp3.toString('base64'), isBase64Encoded: true };
  }

  let state = (await ctx.store.getCall(p.CallSid).catch(() => null))?.ivr;
  if (!state) {
    const user = await ctx.store.user().catch(() => ({}));
    state = newState(ctx.now(), user.lang === 'en' ? 'en' : 'ml');
  }
  state.from ??= p.CallFrom ?? p.From ?? null;

  try {
    if (p.do === 'ask') {
      const before = structuredClone(state); // for the English fallback, with the same message
      const say = await ask(state, ctx);
      const reply = await gatherReply(event, p, ctx, state, say, before);
      await ctx.store.setCall(p.CallSid, { ivr: state, state: state.node });
      return json(reply);
    }

    if (p.do === 'hear') {
      const r = await hear(state, p.digits, ctx);
      await ctx.store.setCall(p.CallSid, { ivr: state, state: state.node, lang: state.lang, actions: state.actions });
      if (r.end) return json({ end: true, actions: state.actions.length }, Number(process.env.IVR_END_STATUS ?? 302));
      return json({ ok: true, next: state.node });
    }
  } catch (err) {
    // Never leave her in silence: log it, go back to the main menu with an apology.
    console.error('ivr error', p.do, state.node, err.message);
    state.node = 'main';
    state.msg = T.oops[state.lang === 'ml' ? 1 : 0];
    await ctx.store.setCall(p.CallSid, { ivr: state, state: state.node }).catch(() => {});
    if (p.do === 'ask') return json({ gather_prompt: { text: T.oops[0] }, max_input_digits: 1, finish_on_key: '', input_timeout: 2 });
    return json({ ok: false });
  }

  return json({ error: 'use do=ask, do=hear or do=say' }, 400);
};
