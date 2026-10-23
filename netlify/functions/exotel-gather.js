// Exotel "Programmable Gather" URL: tells Exotel what to say and how many keys to wait for.
// Owner: Fathima (call agent). The flow in Exotel App Bazaar is a straight line (docs/exotel-setup.md):
//   G1 ?ask=product → G2 ?ask=qty → P1 exotel-save → G3 ?ask=done → P2 exotel-save → G4 ?ask=done → Hangup
// What each box says depends on where the call is (calls/{CallSid}.state):
//   G1  main menu: 1 tell today's sales, 2 hear this month's profit, 3 talk to someone
//   G2  after 1: "what did you sell? biriyani 1, …"   after 2: the profit   after 3: support message
//   P1  (exotel-save) remembers the product she pressed
//   G3  "how many <product>? number, then #"
//   P2  (exotel-save) saves the sale → the app updates live
//   G4  "Saved. 12 Biriyani. This month's profit is … rupees."
// Fixed sentences are Malayalam clips (audio/exotel/*.wav, tools/make_call_audio.py). Sentences with
// numbers are spoken by Exotel in English. CALL_LANG=en in Netlify makes everything English.
const { params, digitsOf, allowed, json, forbidden, audio, products, setPending, getPending, monthProfit } = require('../lib/exotel');

const ml = process.env.CALL_LANG !== 'en';
const say = (event, clip, text) => (ml && clip ? { audio_url: audio(event, clip) } : { text });
// A prompt that only talks: no keys expected, the call moves on (or hangs up) after it.
const talk = (prompt) => json({ gather_prompt: prompt, max_input_digits: 1, finish_on_key: '', input_timeout: 2 });
const rupees = (n) => `${Math.round(n)} rupees`;

exports.handler = async (event) => {
  const p = params(event);
  if (!allowed(p)) return forbidden;
  const sid = p.CallSid;

  // G1: main menu
  if (p.ask === 'product') {
    await setPending(sid, { state: 'main' });
    return json({
      gather_prompt: say(event, 'ex-main',
        "Hello, this is Mitra. To tell today's sales, press 1. To hear this month's profit, press 2. To talk to someone, press 3."),
      max_input_digits: 1,
      finish_on_key: '',
      input_timeout: 8,
      repeat_menu: 1,
    });
  }

  // G2: what she chose on the main menu
  if (p.ask === 'qty') {
    const choice = digitsOf(p);
    if (choice === '2') {
      await setPending(sid, { state: 'profit' });
      const profit = await monthProfit().catch(() => null);
      return talk({ text: profit === null ? 'Sorry, profit is not available right now. Thank you.' : `This month's profit is ${rupees(profit)}. Thank you.` });
    }
    if (choice === '3') {
      await setPending(sid, { state: 'support' });
      return talk(say(event, 'ex-support', 'You are not alone. Call the Tele-MANAS helpline, 1 4 4 1 6, to talk to someone. Thank you.'));
    }
    const options = (await products()).slice(0, 9).map((x, i) => `For ${x.name_en}, press ${i + 1}.`).join(' ');
    await setPending(sid, { state: 'product' });
    return json({
      gather_prompt: say(event, 'ex-menu', `What did you sell? ${options}`),
      max_input_digits: 1,
      finish_on_key: '',
      input_timeout: 8,
      repeat_menu: 1,
    });
  }

  // G3 and G4
  if (p.ask === 'done') {
    const pending = await getPending(sid);
    if (pending?.state === 'qty') {
      const pick = (await products()).find((x) => x.id === pending.product);
      return json({
        gather_prompt: say(event, `ex-qty-${pending.product}`, `How many ${pick?.name_en ?? ''} did you sell? Type the number, then press hash.`),
        max_input_digits: 3,
        finish_on_key: '#',
        input_timeout: 10,
        repeat_menu: 1,
      });
    }
    if (pending?.state === 'saved') {
      const profit = await monthProfit().catch(() => null);
      const money = profit === null ? '' : ` This month's profit is ${rupees(profit)}.`;
      return talk({ text: `Saved. ${pending.saved.qty} ${pending.saved.name}.${money} Thank you.` });
    }
    return talk(say(event, 'ex-bye', 'Thank you.'));
  }

  return json({ error: 'unknown ask' }, 400);
};
