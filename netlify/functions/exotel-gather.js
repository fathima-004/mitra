// Exotel "Programmable Gather" URL: tells Exotel what to say and how many keys to wait for.
// Owner: Fathima (call agent). The flow in Exotel App Bazaar is (docs/exotel-setup.md):
//   Gather ?ask=product → Gather ?ask=qty → Passthru exotel-save → Gather ?ask=done → Hangup
// ask=product  greeting + "biriyani 1, chapathi 2, …" (1 key)
// ask=qty      remembers the product she pressed, asks "how many?" (up to 3 keys, then #)
// ask=done     "Saved. This month's profit is …" (spoken by Exotel, numbers in English)
const { params, digitsOf, allowed, json, forbidden, audio, products, setPending, getPending, monthProfit } = require('../lib/exotel');

exports.handler = async (event) => {
  const p = params(event);
  if (!allowed(p)) return forbidden;

  if (p.ask === 'product') {
    return json({
      gather_prompt: { audio_url: audio(event, 'ex-menu') },
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
      gather_prompt: { audio_url: audio(event, `ex-qty-${pick.id}`) },
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
