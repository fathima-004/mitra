// Key 1: asks what she sold, understands the sentence, reads it back. Owner: Hiba. PLAN.md §7 steps 3–5.
// First visit: <Gather input="speech" language="ml-IN">. Twilio posts SpeechResult back here.
import { say, response, fnUrl, redirect, form, query, verified, forbidden, readBack } from '../lib/twiml.mjs';
import { rows, logSpeech, setCall } from '../lib/store.mjs';
import { understand } from '../lib/understand.mjs';

const ASK = [
  'ഇന്ന് എന്തൊക്കെ വിറ്റു? ഉദാഹരണം: ഇന്ന് 12 ബിരിയാണി പോയി.',
  'What did you sell today? For example: innu 12 biriyani poyi.',
];

export const handler = async (event) => {
  if (!verified(event)) return forbidden;
  const { SpeechResult, CallSid } = form(event);
  const tries = Number(query(event).tries ?? 0);

  if (!SpeechResult) {
    // Nothing heard twice: go to the keypad, which always works.
    if (tries >= 2) return response(redirect(event, 'keypad'));
    return response(`
      <Gather input="speech" language="ml-IN" speechTimeout="auto" timeout="7" method="POST" action="${fnUrl(event, 'sales', { tries: tries + 1 })}">
        ${tries ? say('കേട്ടില്ല. ഒന്നുകൂടി പറയാമോ?', 'I did not hear that. Please say it again.') : say(...ASK)}
      </Gather>
      ${redirect(event, 'sales', { tries: tries + 1 })}`);
  }

  const [products, words] = await Promise.all([rows('products'), rows('words')]);
  const result = await understand(SpeechResult, products, { host: event.headers.host, words });
  await Promise.all([
    logSpeech({ callSid: CallSid ?? null, text: SpeechResult, source: result.source, sure: result.sure, items: result.items }),
    setCall(CallSid, { state: result.sure ? 'confirm' : 'keypad', pending: result.items }),
  ]);

  if (result.sure) return readBack(event, result.items, products);
  return response(`${say('മുഴുവൻ മനസ്സിലായില്ല. നമ്പർ അമർത്തി പറയാം.', 'I did not understand all of it. Let us use the keypad.')}
    ${redirect(event, 'keypad')}`);
};
