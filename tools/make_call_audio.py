"""Record the Malayalam prompts for the Exotel call into audio/exotel/ (served by Netlify).

Run from the repo root:  python tools/make_call_audio.py      (needs: pip install edge-tts imageio-ffmpeg)
Clips are 8 kHz mono WAV, the format Exotel recommends for phone audio.
Clips follow the products in data/demo.json, so re-run this if her products change.
  ex-main.wav        greeting + "sales 1, profit 2, talk to someone 3"
  ex-menu.wav        "what did you sell? biriyani 1, chapathi 2, ..."
  ex-qty-<id>.wav    "how many <product>? type the number, then #"
  ex-support.wav     support message (Tele-MANAS)
  ex-bye.wav         "thank you"
"""
import asyncio
import json
import os
import subprocess

import edge_tts
import imageio_ffmpeg

VOICE = "ml-IN-SobhanaNeural"
OUT = "audio/exotel"
NUM_ML = ["ഒന്ന്", "രണ്ട്", "മൂന്ന്", "നാല്", "അഞ്ച്", "ആറ്", "ഏഴ്", "എട്ട്", "ഒൻപത്"]
FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


async def save(text, name):
    mp3 = f"{OUT}/{name}.mp3"
    await edge_tts.Communicate(text, VOICE).save(mp3)
    subprocess.run([FFMPEG, "-y", "-loglevel", "error", "-i", mp3, "-ar", "8000", "-ac", "1", "-c:a", "pcm_s16le", f"{OUT}/{name}.wav"], check=True)
    os.remove(mp3)
    print(f"{OUT}/{name}.wav  {text}")


async def main():
    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        os.remove(os.path.join(OUT, old))
    products = json.load(open("data/demo.json", encoding="utf-8"))["products"][:9]
    await save("നമസ്കാരം! ഞാൻ മിത്ര. ഇന്ന് വിറ്റത് പറയാൻ ഒന്ന് അമർത്തുക. ഈ മാസത്തെ ലാഭം അറിയാൻ രണ്ട്. "
               "ആരോടെങ്കിലും ഒന്ന് സംസാരിക്കാൻ മൂന്ന്.", "ex-main")
    options = " ".join(f"{p['name_ml']} ആണെങ്കിൽ {NUM_ML[i]}." for i, p in enumerate(products))
    await save(f"എന്താണ് വിറ്റത്? {options}", "ex-menu")
    for p in products:
        await save(f"{p['name_ml']} എത്ര എണ്ണം വിറ്റു? നമ്പർ അമർത്തി, ഒടുവിൽ ഹാഷ് അമർത്തുക.", f"ex-qty-{p['id']}")
    # Tele-MANAS 14416: confirm on telemanas.mohfw.gov.in before the demo.
    await save("മനസ്സിന് ഭാരം തോന്നുന്നുണ്ടെങ്കിൽ, നിങ്ങൾ ഒറ്റയ്ക്കല്ല. സർക്കാരിന്റെ ടെലി മനസ് ഹെൽപ്‌ലൈൻ, "
               "ഒന്ന്, നാല്, നാല്, ഒന്ന്, ആറ്, എന്ന നമ്പറിൽ വിളിച്ച് സംസാരിക്കാം. നന്ദി.", "ex-support")
    await save("നന്ദി. മിത്ര.", "ex-bye")


asyncio.run(main())
