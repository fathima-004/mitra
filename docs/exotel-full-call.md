# The full Mitra phone call (Exotel, keypad)

One call can do everything the app does. Every change is saved the moment she confirms it, so the app updates while she is still on the call. At the end Mitra reads back what changed.

## What she hears
```
Main menu
 1  Add a sale          → which item (1–9) → how many + #   → "Saved. 12 Biriyani, 1200 rupees."
                           then 1 add another · 2 undo that · 0 main menu
 2  Add an expense      → 1 ingredients · 2 gas · 3 packaging · 4 transport · 5 other → rupees + #
                           then 1 add another · 2 undo that · 0 main menu
 3  My money            → 1 today + this month's profit
                           2 monthly report (income, spending, profit, best seller, vs last month)
                           3 savings goal → 1 add to savings → rupees + #
                           4 monthly bills → 1 add a bill → 1 gas · 2 electricity · 3 rent · 4 EMI · 5 other → rupees + #
                           5 GST paid this year (guidance only, confirm with MEC / tax consultant)
 4  Schemes & together  → 1 government scheme news (hand-checked data/schemes.json, else the official PIB feed, never loans)
                           2 buy together → pick a group → how much + #
 5  Change a price      → which item → new price + #
 9  Repeat · 0 Finish   → "On this call you made 3 changes: … It is all in your Mitra app. Goodbye."
```
Three silences in a row also end the call, with the same summary.

## What gets saved (same shapes as the app, PLAN.md §5)
| She does | Firestore |
|---|---|
| sale | `users/demo1/sales/{id}` `{date, time, product, qty, via:"call"}` |
| expense | `users/demo1/purchases/{id}` `{date, time, cat, item, item_ml, qty:1, amount, gst:0, via:"call"}` |
| bill | `users/demo1/bills/{id}` `{month, type, label_en, label_ml, amount, via:"call"}` |
| savings | `users/demo1/goals/{id}.saved` increased |
| price | `users/demo1/products/{id}.price` |
| join a group | `bulk_requests/{id}` `{user, name, month, item, qty, unit, place, via:"call"}` |
| every change | `users/demo1.changedAt`: the app sees it within 4 seconds and reloads |
| the call itself | `calls/{CallSid}`: menu position and the list of changes |

Undo (2) deletes the row it just saved. If Exotel sends the same request twice, it is applied once.

## Build the flow in Exotel App Bazaar (once)
Replace `<site>` with the Netlify site name. If `EXOTEL_HOOK_KEY` is set, add `&key=<value>` to both URLs.

| # | Applet | Setting | Connect |
|---|---|---|---|
| 1 | **Gather** (Programmable, URL) | `https://<site>.netlify.app/.netlify/functions/exotel-ivr?do=ask` | next → 2 |
| 2 | **Passthru** (synchronous) | `https://<site>.netlify.app/.netlify/functions/exotel-ivr?do=hear` | **200 OK → back to 1** · otherwise / error → 3 |
| 3 | **Hangup** | | |

The loop 1 → 2 → 1 is the whole call. When she finishes, `do=hear` answers status **302**, which sends the call to Hangup. If your Exotel account treats 302 as success, set `IVR_END_STATUS` in Netlify to another code (for example `404`) and test again.

Point the ExoPhone (incoming calls) and `EXOTEL_APP_ID` ("Call me") at this flow. The old one-sale flow (`exotel-gather`, `exotel-save`) still works and is untouched.

## Voice
Prompts are spoken by Exotel's text-to-speech in English, because they contain live numbers and names. Malayalam needs a voice that can speak changing numbers; that is the next step (pre-recorded clips for the fixed parts plus numbers).

## Try it without a phone
```
node netlify/lib/ivr-sim.js 1 1 12 0 2 2 900 0 3 2 0 0
```
The numbers are the keys she presses, in order. It prints what Mitra says and what was saved. Without Firebase settings it works on an in-memory copy of the demo, so nothing is written anywhere.
