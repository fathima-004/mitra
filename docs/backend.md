# Backend: call agent setup and checks (Hiba)

## The call flow (Netlify Functions in `netlify/functions/`)
| Function | What it does |
|---|---|
| `voice` | Greets, reads the menu. Twilio number's Voice webhook points here (POST). |
| `menu` | 1 sales, 2 profit, 3 top scheme (from `data/schemes.json` only), 4 Tele-MANAS, 9 `TEAM_PHONE` |
| `sales` | Speech in `ml-IN` → word lists → AI backup → read-back. Twice silent → keypad. |
| `keypad` | One product at a time: "Biriyani, how many?" number + `#`. Always works. |
| `confirm` | 1 saves to `users/demo1/sales` with `via:"call"` (laptop updates live), 2 → keypad |
| `profit` | Speaks this month's profit with `js/calc.js` (same maths as the app) |
| `parse` | `POST {text, products}` → `{items, source, sure}`. Used by `call.html`. |
| `call-me` | `POST`: rings `DEMO_PHONE`. Used by the "Call me" button (web and Flutter). |
| `ping` | Health check |

Pending items travel in the URL (`?items=p1:12,p2:30`), so a call works even when Firestore is slow.
Without Firestore, reads use `data/demo.json` and saving says "could not save, add it in the app". The call never claims a save it did not make.
Dates use India time on the server, so a sale at 1 a.m. is not dated yesterday.

## Netlify environment variables
| Name | Needed for | Example |
|---|---|---|
| `TWILIO_ACCOUNT_SID`, `TWILIO_AUTH_TOKEN`, `TWILIO_NUMBER` | every call; the token also checks Twilio signatures | `+1...` |
| `DEMO_PHONE` | `call-me` | `+91...` (must be a Verified Caller ID on a trial account) |
| `FIREBASE_SERVICE_ACCOUNT` | saving from the call, live update | the whole service-account JSON on one line |
| `AI_PROVIDER` | AI backup | `gemini` (default), `groq` or `claude` |
| `GEMINI_API_KEY` / `GROQ_API_KEY` / `ANTHROPIC_API_KEY` | the chosen provider | |
| `GEMINI_MODEL`, `GROQ_MODEL`, `CLAUDE_MODEL` | optional model override | `gemini-2.5-flash` |
| `ML_VOICE` | optional: speak Malayalam text | `Google.ml-IN-Wavenet-A`. Test it on the account first. Unset = Indian English voice. |
| `TEAM_PHONE` | optional: key 9 | `+91...` |

## Still to do by hand
1. **Firebase web config:** paste it into `FIREBASE_CONFIG` in `js/data.js`. Until then the app runs on browser storage only and will **not** see sales saved by the phone call.
2. **Firestore rules:** test mode, or allow read/write on `users/demo1/**` and `bulk_requests/**` for the demo.
3. **Twilio:** number → Voice webhook `https://<site>.netlify.app/.netlify/functions/voice` (POST). Geo Permissions: India on.
4. After each deploy: open `/.netlify/functions/ping`, then press "Call me".

## Local check of the call flow
`npm install`, then run the functions with fake Twilio requests (no token set = signature check off):
```
node -e "import('./netlify/functions/sales.mjs').then(async m=>console.log((await m.handler({httpMethod:'POST',headers:{host:'x'},body:'SpeechResult=innu%2012%20biriyani%20poyi'})).body))"
```
