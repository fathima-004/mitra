"""Copy the shared content (demo data, Malayalam text, schemes, voice clips) from web/ into the Flutter app's assets.
Run from the repo root after changing anything in web/data/ or web/audio/:  python tools/sync_app_assets.py
"""
import shutil
from pathlib import Path

WEB = Path("web")
APP = Path("app/assets")
for name in ["demo.json", "ml.json", "limits.json", "join_call.json", "schemes.json"]:
    (APP / "data").mkdir(parents=True, exist_ok=True)
    shutil.copy(WEB / "data" / name, APP / "data" / name)
shutil.copytree(WEB / "audio/join", APP / "audio/join", dirs_exist_ok=True)
print("synced", sorted(str(p.relative_to(APP)) for p in APP.rglob("*") if p.is_file() and "fonts" not in p.parts))
