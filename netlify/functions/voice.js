// Twilio webhook for an incoming or outgoing call: greets, then reads the main menu.
// Owner: Hiba. PLAN.md §5 (Netlify Functions) and §7 step 2.
const { say, response, fnUrl, verified, forbidden } = require('../lib/twiml');

const MENU =
  'To log today\'s sales, press 1. For this month\'s profit, press 2. ' +
  'For schemes, press 3. For support, press 4. For the team, press 9.';

exports.handler = async (event) => {
  if (!verified(event)) return forbidden;

  return response(`
    ${say('Namaskaram. This is Mitra, your business helper.')}
    <Gather input="dtmf" numDigits="1" timeout="6" method="POST" action="${fnUrl(event, 'menu')}">
      ${say(MENU)}
    </Gather>
    ${say('No key was pressed. Goodbye.')}`);
};
