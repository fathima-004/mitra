// Keypad entry: "Biriyani, how many? Type the number, then hash." One product at a time.
// Owner: Hiba. PLAN.md §7a step 3, the fallback that always works.
// ?i = which product is being asked, ?items = what she typed so far ("p1:12,p2:30").
import { say, response, fnUrl, redirect, form, query, verified, forbidden, packItems, unpackItems, readBack } from '../lib/twiml.mjs';
import { rows } from '../lib/store.mjs';

export const handler = async (event) => {
  if (!verified(event)) return forbidden;
  const { Digits } = form(event);
  const q = query(event);
  const products = await rows('products');
  const items = unpackItems(q.items);
  let i = Number(q.i ?? 0);

  // A number typed for the product we just asked about. 0 or nothing means none sold.
  if (q.asked !== undefined) {
    const qty = Math.floor(Number(Digits || 0));
    const p = products[i];
    if (p && qty >= 1 && qty <= 999) items.push({ product: p.id, qty });
    i += 1;
  }

  if (i >= products.length) {
    if (!items.length) return response(`${say('ഒന്നും സേവ് ചെയ്തില്ല.', 'Nothing was saved.')}${redirect(event, 'voice', { menu: 1 })}`);
    return readBack(event, items, products);
  }

  const p = products[i];
  const next = { i, items: packItems(items), asked: 1 };
  const intro = i === 0 && q.asked === undefined
    ? say('ഓരോന്നും എത്ര വിറ്റു എന്ന് നമ്പർ അമർത്തി, അവസാനം ഹാഷ് അമർത്തുക. ഇല്ലെങ്കിൽ ഹാഷ് മാത്രം.',
      'For each item, type how many you sold, then press hash. If none, just press hash.')
    : '';
  return response(`${intro}
    <Gather input="dtmf" finishOnKey="#" timeout="8" method="POST" action="${fnUrl(event, 'keypad', next)}">
      ${say(`${p.name_ml ?? p.name_en} എത്ര?`, `${p.name_en}, how many?`)}
    </Gather>
    ${redirect(event, 'keypad', next)}`);
};
