// Twilio webhook for an incoming or outgoing call: greets, then reads the main menu.
// Owner: Hiba. PLAN.md §5 (Netlify Functions) and §7 step 2.
// ?menu=1 skips the greeting (coming back after a save or the profit).
// ?tries=N counts menus with no key pressed, so a silent call ends instead of looping.
import { say, response, fnUrl, redirect, query, verified, forbidden } from '../lib/twiml.mjs';

export const MENU = [
  'ഇന്നത്തെ വിൽപ്പന പറയാൻ 1 അമർത്തുക. ഈ മാസത്തെ ലാഭം അറിയാൻ 2. പദ്ധതികൾക്ക് 3. സഹായത്തിന് 4. ഒരാളോട് സംസാരിക്കാൻ 9.',
  "To tell today's sales, press 1. For this month's profit, press 2. For schemes, press 3. For support, press 4. To talk to a person, press 9.",
];

export const handler = async (event) => {
  if (!verified(event)) return forbidden;
  const q = query(event);
  const tries = Number(q.tries ?? 0);

  const greet = q.menu ? '' : say('നമസ്കാരം. ഞാൻ മിത്ര, നിങ്ങളുടെ ബിസിനസ് സഹായി.', 'Namaskaram. This is Mitra, your business helper.');
  const after = tries >= 1
    ? `${say('ഒന്നും അമർത്തിയില്ല. നന്ദി, വീണ്ടും വിളിക്കൂ.', 'No key was pressed. Thank you, call again. Goodbye.')}<Hangup/>`
    : redirect(event, 'voice', { menu: 1, tries: tries + 1 });

  return response(`${greet}
    <Gather input="dtmf" numDigits="1" timeout="6" method="POST" action="${fnUrl(event, 'menu')}">
      ${say(...MENU)}
    </Gather>
    ${after}`);
};
