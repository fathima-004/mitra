"""Record the Malayalam prompts for the Exotel call into audio/exotel/ (served by Netlify).

Run from the repo root:  python tools/make_call_audio.py      (needs: pip install edge-tts)
Clips follow the products in data/demo.json, so re-run this if her products change.
  ex-menu.mp3        greeting + "biriyani: press 1, chapathi: press 2, ..."
  ex-qty-<id>.mp3    "how many <product>? type the number, then #"
"""
import asyncio
import json
import os

import edge_tts

VOICE = "ml-IN-SobhanaNeural"
OUT = "audio/exotel"
NUM_ML = ["ഒന്ന്", "രണ്ട്", "മൂന്ന്", "നാല്", "അഞ്ച്", "ആറ്", "ഏഴ്", "എട്ട്", "ഒൻപത്"]


async def save(text, name):
    await edge_tts.Communicate(text, VOICE).save(f"{OUT}/{name}.mp3")
    print(f"{OUT}/{name}.mp3  {text}")


async def main():
    os.makedirs(OUT, exist_ok=True)
    products = json.load(open("data/demo.json", encoding="utf-8"))["products"][:9]
    options = " ".join(f"{p['name_ml']} ആണെങ്കിൽ {NUM_ML[i]}." for i, p in enumerate(products))
    await save(f"നമസ്കാരം! ഞാൻ മിത്ര. ഇന്ന് എന്താണ് വിറ്റത്? {options}", "ex-menu")
    for p in products:
        await save(f"{p['name_ml']} എത്ര എണ്ണം വിറ്റു? നമ്പർ അമർത്തി, ഒടുവിൽ ഹാഷ് അമർത്തുക.", f"ex-qty-{p['id']}")


asyncio.run(main())
