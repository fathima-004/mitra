"""Copy the shared content (demo data, Malayalam text, voice clips) into the Flutter app's assets.
Run from the repo root after changing anything in data/ or audio/:  python tools/sync_app_assets.py
"""
import shutil
from pathlib import Path

APP = Path("app/assets")
for name in ["demo.json", "ml.json", "limits.json", "join_call.json"]:
    (APP / "data").mkdir(parents=True, exist_ok=True)
    shutil.copy(Path("data") / name, APP / "data" / name)
shutil.copytree("audio/join", APP / "audio/join", dirs_exist_ok=True)
print("synced", sorted(str(p.relative_to(APP)) for p in APP.rglob("*") if p.is_file() and "fonts" not in p.parts))
