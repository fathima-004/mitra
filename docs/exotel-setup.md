# Exotel call flow for Mitra (keypad first)

What she hears:
1. "Hello, this is Mitra. What did you sell today? For Biriyani, press 1. For Chapathi, press 2 …"
2. She presses **1** → "How many Biriyani did you sell? Type the number, then press hash."
3. She types **12 #** → the sale is saved to Firestore with `via:"call"` → **the app updates live**
4. "Saved. 12 Biriyani. This month's profit is … rupees. Thank you."

Prompts are in English (Exotel's voice). To use the Malayalam clips instead, add `CALL_LANG` = `ml` in Netlify.

Replace `<site>` with the Netlify site name. If you set `EXOTEL_HOOK_KEY` in Netlify, add `&key=<that value>` to every URL below.

## 1. Netlify environment variables
| Key | Value |
|---|---|
| `EXOTEL_API_KEY`, `EXOTEL_API_TOKEN` | from Exotel → API Credentials (tick "secret") |
| `EXOTEL_SID` | Account SID |
| `EXOTEL_SUBDOMAIN` | `api.exotel.com` or `api.in.exotel.com` |
| `EXOPHONE` | your ExoPhone number |
| `DEMO_PHONE` | the phone that should ring for "Call me" |
| `EXOTEL_APP_ID` | the flow's id from step 2 (add after making the flow) |
| `FIREBASE_SERVICE_ACCOUNT` | Firebase service-account JSON (needed to save sales) |
| `EXOTEL_HOOK_KEY` | optional: any random word, protects the URLs |

After adding or changing any of these: Deploys → Trigger deploy → Deploy site.

## 1b. Connect Firebase (so the call can save sales)
1. console.firebase.google.com → the Mitra project (create one if there is none; Firestore Database → Create database, region `asia-south1`).
2. ⚙ Project settings → **Service accounts** → **Generate new private key** → a `.json` file downloads. Keep it private, never commit it.
3. Open the file in Notepad. In Netlify add three variables (tick "secret" for the key):
   - `FIREBASE_PROJECT_ID` = the `project_id` value
   - `FIREBASE_CLIENT_EMAIL` = the `client_email` value
   - `FIREBASE_PRIVATE_KEY` = the whole `private_key` value, from `-----BEGIN PRIVATE KEY-----` to `-----END PRIVATE KEY-----
` (without the quotes)
   (Or paste the whole file as `FIREBASE_SERVICE_ACCOUNT`, but Netlify Functions only allow about 4 KB of variables in total, so the three separate ones are safer.)
4. Trigger a deploy. The app side also needs the project's web config (Hiba: `js/data.js` and the Flutter `--dart-define` values in `app/lib/config.dart`).

## 2. Build the flow in Exotel App Bazaar
Create a new app named **Mitra** and add these boxes in order:

| # | Applet | Setting |
|---|---|---|
| 1 | **Gather** (programmable, "URL" option) | `https://<site>.netlify.app/.netlify/functions/exotel-gather?ask=product` |
| 2 | **Gather** (programmable) | `https://<site>.netlify.app/.netlify/functions/exotel-gather?ask=qty` |
| 3 | **Passthru** (wait for response / sync) | `https://<site>.netlify.app/.netlify/functions/exotel-save` |
| 4 | **Gather** (programmable) | `https://<site>.netlify.app/.netlify/functions/exotel-gather?ask=done` |
| 5 | **Hangup** | |

Connect each box's "next" (and Passthru's success, error and timeout exits) to the following box. Save. The app id is the number at the end of the flow's page link: put it in `EXOTEL_APP_ID`.

## 3. Use the flow
- **She calls in:** ExoPhones → your number → set its flow to **Mitra**.
- **"Call me" button:** the app POSTs to `/.netlify/functions/call-me`, Exotel rings `DEMO_PHONE` and plays the flow.
- Trial accounts can only call **verified** numbers: add the demo phones in Exotel first.

## 4. Test
1. Open `https://<site>.netlify.app/.netlify/functions/exotel-gather?ask=product`: you should see JSON with `audio_url`. Open that audio link: the Malayalam greeting should play.
2. Call the ExoPhone from a verified phone: press 1, type 12, press #.
3. The app shows 12 biriyani (Netlify → Functions → exotel-save → logs show what happened).

## Files
- `netlify/functions/exotel-gather.js`: what Mitra says and how many keys to wait for
- `netlify/functions/exotel-save.js`: saves the sale (one per call, id from CallSid, so retries don't double-count)
- `netlify/functions/call-me.js`: rings the demo phone via Exotel `Calls/connect`
- `netlify/lib/exotel.js`, `netlify/lib/firestore.js`: shared helpers
- `audio/exotel/*.mp3`: Malayalam prompts, made with `python tools/make_call_audio.py`

Speech ("innu 12 biriyani poyi") is the next step: a Record applet → our function transcribes and parses → read back → keypad confirm. The keypad flow above is the safe demo path.
