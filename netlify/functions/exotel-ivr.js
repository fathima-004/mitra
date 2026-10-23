// The full Mitra phone menu for Exotel (netlify/lib/ivr.js). Owner: Hiba.
// Exotel flow, built once in App Bazaar (docs/exotel-full-call.md):
//   [1] Gather (programmable)  /.netlify/functions/exotel-ivr?do=ask   → next: [2]
//   [2] Passthru               /.netlify/functions/exotel-ivr?do=hear  → 200 OK: back to [1] · otherwise: [3]
//   [3] Hangup
// do=ask  answers Exotel's Programmable Gather with what to say and how many keys to collect.
// do=hear gets the keys she pressed (Exotel sends them as `digits`), saves what she confirmed to Firestore,
//         and answers 200 to keep going, or IVR_END_STATUS (default 302) to hang up.
const { params, allowed, json, forbidden } = require('../lib/exotel');
const { store } = require('../lib/ivr-store');
const { ask, hear, newState } = require('../lib/ivr');

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

exports.handler = async (event) => {
  const p = params(event);
  if (!allowed(p)) return forbidden;
  if (!p.CallSid) return json({ error: 'CallSid missing' }, 400);

  const ctx = context(p);
  const state = (await ctx.store.getCall(p.CallSid).catch(() => null))?.ivr ?? newState(ctx.now());
  state.from ??= p.CallFrom ?? p.From ?? null;

  try {
    if (p.do === 'ask') {
      const say = await ask(state, ctx);
      await ctx.store.setCall(p.CallSid, { ivr: state, state: state.node });
      return json({
        gather_prompt: { text: say.text },
        max_input_digits: say.digits,
        finish_on_key: say.finish,
        input_timeout: say.timeout ?? (say.digits > 1 ? 12 : 8),
        repeat_menu: 1,
      });
    }

    if (p.do === 'hear') {
      const r = await hear(state, p.digits, ctx);
      await ctx.store.setCall(p.CallSid, { ivr: state, state: state.node, actions: state.actions });
      if (r.end) return json({ end: true, actions: state.actions.length }, Number(process.env.IVR_END_STATUS ?? 302));
      return json({ ok: true, next: state.node });
    }
  } catch (err) {
    // Never leave her in silence: log it, go back to the main menu with an apology.
    console.error('ivr error', p.do, state.node, err.message);
    state.node = 'main';
    state.msg = 'Sorry, something went wrong. Nothing was lost.';
    await ctx.store.setCall(p.CallSid, { ivr: state, state: state.node }).catch(() => {});
    if (p.do === 'ask') return json({ gather_prompt: { text: state.msg }, max_input_digits: 1, finish_on_key: '', input_timeout: 2 });
    return json({ ok: false });
  }

  return json({ error: 'use do=ask or do=hear' }, 400);
};
