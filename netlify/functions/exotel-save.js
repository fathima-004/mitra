// Exotel Passthru URL (used twice in the flow, see exotel-gather.js). Owner: Fathima (call agent).
//   state 'product' → the key she pressed is the product → state 'qty'
//   state 'qty'     → the number she typed is the quantity → save the sale → state 'saved'
// Writes users/demo1/sales/{id} with via:"call" (PLAN.md §5), so the app updates live during the call.
// The number was typed on the keypad, so it is already confirmed. One sale per call: the id comes from
// CallSid, so if Exotel retries the request the sale is not saved twice.
// Always answers 200 with an EMPTY body: Exotel reads any body as "go to this applet" and hangs up.
const { USER, params, digitsOf, allowed, forbidden, products, setPending, getPending, todayIST } = require('../lib/exotel');
const { db } = require('../lib/firestore');

const ok = { statusCode: 200, headers: { 'Content-Type': 'text/plain' }, body: '' };

exports.handler = async (event) => {
  const p = params(event);
  if (!allowed(p)) return forbidden;
  const sid = p.CallSid;
  const digits = digitsOf(p);
  const pending = await getPending(sid);
  const list = await products();

  if (pending?.state === 'product') {
    const pick = list[Number(digits) - 1] ?? list[0];
    await setPending(sid, { state: 'qty', product: pick.id });
    return ok;
  }

  if (pending?.state === 'qty') {
    const qty = Number(digits);
    if (!(qty >= 1 && qty <= 999)) {
      console.log('not saved, bad number', { sid, digits: p.digits });
      await setPending(sid, { state: 'bye' });
      return ok;
    }
    const product = list.find((x) => x.id === pending.product);
    const sale = { date: todayIST(), product: pending.product, qty, via: 'call' };
    const store = db();
    if (store) {
      const id = `x${sid}`.replace(/[^\w-]/g, '');
      await store.collection('users').doc(USER).collection('sales').doc(id).set({ id, ...sale });
    } else {
      console.log('Firebase not connected, sale not stored', sale);
    }
    await setPending(sid, { state: 'saved', saved: { qty, name: product?.name_en ?? pending.product } });
    return ok;
  }

  console.log('passthru with nothing to do', { sid, state: pending?.state });
  return ok;
};
