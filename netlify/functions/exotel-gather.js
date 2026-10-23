// Exotel "Programmable Gather" URL: tells Exotel what to say and how many keys to wait for.
// Owner: Fathima (call agent). The flow in Exotel App Bazaar is (docs/exotel-setup.md):
//   Gather ?ask=product → Gather ?ask=qty → Passthru exotel-save → Gather ?ask=done → Hangup
// ask=product  greeting + "for Biriyani press 1, …" (1 key)
// ask=qty      remembers the product she pressed, asks "how many?" (up to 3 keys, then #)
// ask=done     "Saved. This month's profit is …"
// Prompts are spoken in English by Exotel. Set CALL_LANG=ml in Netlify to play the Malayalam
// clips in audio/exotel/ instead (tools/make_call_audio.py).
const { params, digitsOf, allowed, json, forbidden, audio, products, setPending, getPending, monthProfit } = require('../lib/exotel');

const say = (event, clip, text) => (process.env.CALL_LANG === 'ml' ? { audio_url: audio(event, clip) } : { text });

exports.handler = async (event) => {
  const p = params(event);
  if (!allowed(p)) return forbidden;

  if (p.ask === 'product') {
    const options = (await products()).slice(0, 9).map((x, i) => `For ${x.name_en}, press ${i + 1}.`).join(' ');
    return json({
      gather_prompt: say(event, 'ex-menu', `Hello, this is Mitra. What did you sell today? ${options}`),
      max_input_digits: 1,
      finish_on_key: '',
      input_timeout: 8,
      repeat_menu: 1,
    });
  }

  if (p.ask === 'qty') {
    const list = await products();
    const pick = list[Number(digitsOf(p)) - 1] ?? list[0];
    await setPending(p.CallSid, { product: pick.id, state: 'qty' });
    return json({
      gather_prompt: say(event, `ex-qty-${pick.id}`, `How many ${pick.name_en} did you sell? Type the number, then press hash.`),
      max_input_digits: 3,
      finish_on_key: '#',
      input_timeout: 10,
      repeat_menu: 1,
    });
  }

  if (p.ask === 'done') {
    const pending = await getPending(p.CallSid);
    const profit = await monthProfit().catch(() => null);
    const saved = pending?.saved ? `Saved. ${pending.saved.qty} ${pending.saved.name}. ` : '';
    const money = profit === null ? '' : `This month's profit is ${Math.round(profit)} rupees. `;
    return json({
      gather_prompt: { text: `${saved}${money}Thank you. Mitra.` },
      max_input_digits: 1,
      finish_on_key: '',
      input_timeout: 1,
    });
  }

  return json({ error: 'unknown ask' }, 400);
};
