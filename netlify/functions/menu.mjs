// Routes the key pressed on the main menu. Owner: Hiba. PLAN.md §5 and §7 steps 3–8.
// 1 sales, 2 profit, 3 top scheme, 4 support (Tele-MANAS), 9 a person on the team.
import { say, response, redirect, form, verified, forbidden, esc } from '../lib/twiml.mjs';

const back = (event) => redirect(event, 'voice', { menu: 1 });

// Scheme titles come only from data/schemes.json (hand-checked by Fathima, CLAUDE.md). Nothing is invented here.
async function topScheme(event) {
  try {
    const res = await fetch(`https://${event.headers.host}/data/schemes.json`, { signal: AbortSignal.timeout(1500) });
    if (!res.ok) return null;
    const data = await res.json();
    const s = (Array.isArray(data) ? data : data.schemes ?? [])[0];
    const ml = s?.title_ml ?? s?.name_ml;
    const en = s?.title_en ?? s?.name_en;
    return ml || en ? { ml: ml ?? en, en: en ?? ml } : null;
  } catch {
    return null;
  }
}

export const handler = async (event) => {
  if (!verified(event)) return forbidden;
  const { Digits } = form(event);

  switch (Digits) {
    case '1':
      return response(redirect(event, 'sales'));
    case '2':
      return response(redirect(event, 'profit'));
    case '3': {
      const s = await topScheme(event);
      const text = s
        ? say(`നിങ്ങൾക്ക് പറ്റിയ ഒരു പദ്ധതി: ${s.ml}. രേഖകളുടെ ലിസ്റ്റ് മിത്ര ആപ്പിൽ ഉണ്ട്.`,
          `A scheme that may suit you: ${s.en}. The document checklist is in the Mitra app.`)
        : say('പദ്ധതികളുടെ വിവരങ്ങൾ മിത്ര ആപ്പിൽ കാണാം.', 'Scheme details are in the Mitra app.');
      return response(`${text}${back(event)}`);
    }
    case '4':
      // Tele-MANAS, PLAN.md §3. Twilio cannot dial Indian short codes, so the number is read out.
      return response(`${say(
        'മനസ്സിന് വിഷമം തോന്നുന്നുണ്ടെങ്കിൽ ടെലി മനസ് ഹെൽപ്‌ലൈനിൽ വിളിക്കൂ: 1 4 4 1 6. സൗജന്യമാണ്.',
        'If you feel stressed or low, call the Tele MANAS helpline: 1 4 4 1 6. It is free.',
      )}${back(event)}`);
    case '9': {
      const team = process.env.TEAM_PHONE;
      if (!team) return response(`${say('ഇപ്പോൾ ആരെയും ബന്ധപ്പെടാൻ കഴിയില്ല.', 'Nobody is available right now.')}${back(event)}`);
      return response(`${say('ഒരാളുമായി ബന്ധിപ്പിക്കുന്നു.', 'Connecting you to a person.')}<Dial>${esc(team)}</Dial>`);
    }
    default:
      return response(`${say('ആ നമ്പർ മെനുവിൽ ഇല്ല.', 'Sorry, that key is not on the menu.')}${back(event)}`);
  }
};
