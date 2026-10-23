// Routes the key pressed on the main menu. Owner: Hiba. PLAN.md §5 and §7 steps 3–8.
// Keys 1, 2, 3, 4 and 9 are placeholders until their flows are built:
//   1 → sales (H3–H5), 2 → profit (H5–H7), 3 / 4 / 9 → schemes, support, team (H7–H9).
const { say, response, fnUrl, form, verified, forbidden } = require('../lib/twiml');

const PLACEHOLDERS = {
  1: 'Sales logging is not ready yet.',
  2: 'Profit is not ready yet.',
  3: 'Schemes are not ready yet.',
  4: 'Support is not ready yet.',
  9: 'The team number is not ready yet.',
};

exports.handler = async (event) => {
  if (!verified(event)) return forbidden;

  const { Digits } = form(event);
  const back = `<Redirect method="POST">${fnUrl(event, 'voice')}</Redirect>`;

  if (Digits && PLACEHOLDERS[Digits]) {
    return response(`${say(PLACEHOLDERS[Digits])}${back}`);
  }
  return response(`${say('Sorry, that key is not on the menu.')}${back}`);
};
