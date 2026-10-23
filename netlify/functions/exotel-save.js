// Exotel Passthru URL after "how many?": saves the sale so the app updates live during the call.
// Owner: Fathima (call agent). Writes users/demo1/sales/{id} with via:"call" (PLAN.md §5).
// The number was typed on the keypad, so it is already confirmed. One sale per call: the id comes
// from CallSid, so if Exotel retries the request the sale is not saved twice.
const { USER, params, digitsOf, allowed, json, forbidden, products, setPending, getPending, todayIST } = require('../lib/exotel');
const { db } = require('../lib/firestore');

exports.handler = async (event) => {
  const p = params(event);
  if (!allowed(p)) return forbidden;

  const qty = Number(digitsOf(p));
  const pending = await getPending(p.CallSid);
  if (!pending?.product || !(qty >= 1 && qty <= 999)) {
    console.log('not saved', { callSid: p.CallSid, digits: p.digits, pending });
    return json({ saved: false });
  }

  const product = (await products()).find((x) => x.id === pending.product);
  const sale = { date: todayIST(), product: pending.product, qty, via: 'call' };
  const store = db();
  if (store) {
    const id = `x${p.CallSid}`.replace(/[^\w-]/g, '');
    await store.collection('users').doc(USER).collection('sales').doc(id).set({ id, ...sale });
  } else {
    console.log('FIREBASE_SERVICE_ACCOUNT not set, sale not stored', sale);
  }
  await setPending(p.CallSid, { state: 'saved', saved: { qty, name: product?.name_en ?? pending.product } });
  return json({ saved: Boolean(store), sale });
};
