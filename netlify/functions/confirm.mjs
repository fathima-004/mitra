// After the read-back: 1 saves the sales to Firestore (the laptop updates live), 2 goes to the keypad.
// Owner: Hiba. PLAN.md §7 step 6. The pending items arrive in the URL (?items=p1:12,p2:30).
import { say, response, redirect, form, query, verified, forbidden, unpackItems, readBack } from '../lib/twiml.mjs';
import { rows, saveSales, setCall } from '../lib/store.mjs';

export const handler = async (event) => {
  if (!verified(event)) return forbidden;
  const { Digits, CallSid } = form(event);
  const q = query(event);
  const products = await rows('products');
  const known = new Set(products.map((p) => p.id));
  const items = unpackItems(q.items).filter((i) => known.has(i.product));
  const menu = redirect(event, 'voice', { menu: 1 });

  if (!items.length) {
    return response(`${say('ഒന്നും സേവ് ചെയ്തില്ല.', 'Nothing was saved.')}${menu}`);
  }

  if (Digits === '1') {
    const ok = await saveSales(items, 'call');
    await setCall(CallSid, { state: ok ? 'saved' : 'save-failed', pending: items });
    if (!ok) {
      return response(`${say(
        'ക്ഷമിക്കണം, ഇപ്പോൾ സേവ് ചെയ്യാൻ കഴിഞ്ഞില്ല. ദയവായി ആപ്പിൽ ചേർക്കുക.',
        'Sorry, I could not save it right now. Please add it in the app.',
      )}${menu}`);
    }
    return response(`${say('സേവ് ചെയ്തു. നന്ദി.', 'Saved. Thank you.')}${menu}`);
  }

  if (Digits === '2') return response(redirect(event, 'keypad'));

  // No key or another key: read it back again, then give up without saving.
  const tries = Number(q.tries ?? 0);
  if (tries >= 2) return response(`${say('ഒന്നും സേവ് ചെയ്തില്ല.', 'Nothing was saved.')}${menu}`);
  return readBack(event, items, products, tries);
};
