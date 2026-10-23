"""Record the join-by-call demo (data/join_call.json) as Malayalam voice clips in audio/join/.

Run from the repo root:  python tools/make_join_audio.py      (needs: pip install edge-tts)
Mitra speaks with ml-IN-SobhanaNeural. Her replies use the same voice, a little lower and slower,
so the two sound different on the laptop speaker.
"""
import asyncio
import json
import os

import edge_tts

VOICE = "ml-IN-SobhanaNeural"
OUT = "audio/join"


async def main():
    os.makedirs(OUT, exist_ok=True)
    lines = json.load(open("data/join_call.json", encoding="utf-8"))["lines"]
    for line in lines:
        if "id" not in line:
            continue
        her = line["who"] == "her"
        tts = edge_tts.Communicate(line["ml"], VOICE, rate="-8%" if her else "+0%", pitch="-12Hz" if her else "+0Hz")
        path = f"{OUT}/{line['id']}.mp3"
        await tts.save(path)
        print(path)


asyncio.run(main())
