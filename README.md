# Mitra

A Malayalam-first app for women running small businesses from home (Kudumbashree units, home cooks, small makers in Kerala).

Built at MakeHerHack 2026, CITTIC CUSAT.

## What it does
- **Profit tracker:** set up products, prices and monthly bills once, log daily sales in seconds, see real monthly profit in Malayalam.
- **Call page:** a phone-call style menu for women who don't use apps. Say "innu 12 biriyani" and it's logged; the app updates live.
- **Money Health:** savings goals (auto, bike), EMI affordability, GST status and GST paid on purchases.
- **Schemes:** checked government schemes (non-loan) with a document checklist.
- **Bulk-buy board** and a **support** page (Tele-MANAS 14416).

## Folders
| Folder | What's in it |
|---|---|
| `web/` | the website Netlify publishes: pages, `js/`, `css/`, `icons/`, `data/` (demo month, Malayalam text, schemes), `audio/` (call and join voice clips) |
| `netlify/` | backend: phone call (Exotel, Twilio backup), call-me, seed-demo, ping |
| `app/` | Flutter app (Android) |
| `tools/` | Python scripts: dev server, demo data, voice clips, copy content into the app |
| `docs/` | how Mitra works, setup notes, requests between teammates |

Run the website locally with `python tools/serve.py`, then open http://localhost:8080. Read [docs/how-mitra-works.md](docs/how-mitra-works.md) for the full picture.

Mitra never offers or recommends loans. Tax information is for guidance only.
