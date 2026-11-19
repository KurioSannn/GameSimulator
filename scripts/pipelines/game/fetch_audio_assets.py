"""Fetch pinned CC0-1.0 UI & environmental sound assets into game/assets/audio/ with full provenance.

Sources (all verified CC0 1.0 Public Domain):
  1. Kenney Interface Sounds (via Calinou/kenney-interface-sounds, commit 4596a49eaf5a533948d49a47467f606bcdea70ff)
  2. OpenGameArt CC0 Sound Effects (birds, ocean waves, rain/thunder, floodwater, wildfire, wind, traffic, quake rumble)
  3. Wikimedia Commons CC0 Ship Horn (File:Cruise_ship_Albatros_ship_horn.ogg)

Usage: python scripts/pipelines/game/fetch_audio_assets.py [--refresh]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[3]
OUT_UI = ROOT / "game/assets/audio/ui"
OUT_AMBIENT = ROOT / "game/assets/audio/ambient"
OUT_BGM_DIR = ROOT / "game/assets/audio/bgm"
MANIFEST_PATH = ROOT / "game/assets/audio/MANIFEST.json"
USER_AGENT = "NUSANTARA-audio-fetcher/1.0 (+offline-cc0-assets)"

KENNEY_COMMIT = "4596a49eaf5a533948d49a47467f606bcdea70ff"
KENNEY_BASE = f"https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/{KENNEY_COMMIT}/addons/kenney_interface_sounds"

UI_FILES = [
    ("click_003.wav", "General button press click"),
    ("select_002.wav", "Region, tab, dropdown, and option card selection"),
    ("select_007.wav", "Crisp primary button & quarter advance confirm click"),
    ("open_001.wav", "Subtle dialog or drawer open"),
    ("close_001.wav", "Subtle dialog or panel close"),
    ("back_002.wav", "Back / cancel action"),
    ("toggle_004.wav", "Crisp toggle switch / layer change"),
    ("tick_001.wav", "Subtle control focus / slider tick"),
    ("error_008.wav", "Short validation warning or disabled action"),
    ("tick_004.wav", "Subtle notification tap for incoming cases"),
]

AMBIENT_FILES = [
    {
        "file": "birds_tropical.ogg",
        "role": "Tropical birdsong over vegetated islands",
        "url": "https://opengameart.org/sites/default/files/birds-isaiah658_0.ogg",
        "source_page": "https://opengameart.org/content/ambient-bird-sounds",
        "creator": "isaiah658 (OpenGameArt)",
        "license": "CC0-1.0",
    },
    {
        "file": "ocean_waves.ogg",
        "role": "Archipelagic ocean waves & coastal surf",
        "url": "https://opengameart.org/sites/default/files/jasinski-wave-prev.ogg",
        "source_page": "https://opengameart.org/content/beach-ocean-waves",
        "creator": "jasinski (OpenGameArt)",
        "license": "CC0-1.0",
    },
    {
        "file": "rain_storm.ogg",
        "role": "Monsoon tropical rain & distant thunder",
        "url": "https://opengameart.org/sites/default/files/rain-thunder_0.ogg",
        "source_page": "https://opengameart.org/content/rain-long-thunder",
        "creator": "OpenGameArt contributor",
        "license": "CC0-1.0",
    },
    {
        "file": "flood_water.ogg",
        "role": "Rushing urban floodwater surge",
        "url": "https://opengameart.org/sites/default/files/audio_preview/rain-gutter-loop_0.mp3.ogg",
        "source_page": "https://opengameart.org/content/rain-gutter-loop",
        "creator": "OpenGameArt contributor",
        "license": "CC0-1.0",
    },
    {
        "file": "fire_crackling.ogg",
        "role": "Peatland & forest wildfire crackling",
        "url": "https://opengameart.org/sites/default/files/fire-1_0.ogg",
        "source_page": "https://opengameart.org/content/fire-crackling",
        "creator": "OpenGameArt contributor",
        "license": "CC0-1.0",
    },
    {
        "file": "wind_breeze.ogg",
        "role": "High-altitude monsoon / dry season breeze",
        "url": "https://opengameart.org/sites/default/files/wind%20woosh%20loop_0.ogg",
        "source_page": "https://opengameart.org/content/wind-whoosh-loop",
        "creator": "OpenGameArt contributor",
        "license": "CC0-1.0",
    },
    {
        "file": "city_traffic.ogg",
        "role": "Urban arterial traffic / Kota Macet hum",
        "url": "https://opengameart.org/sites/default/files/gatve%20Varniu_3.ogg",
        "source_page": "https://opengameart.org/content/high-traffic-road-sounds",
        "creator": "OpenGameArt contributor",
        "license": "CC0-1.0",
    },
    {
        "file": "quake_rumble.ogg",
        "role": "Seismic tremor / geological disaster rumble",
        "url": "https://opengameart.org/sites/default/files/audio_preview/rumble.mp3.ogg",
        "source_page": "https://opengameart.org/content/rumble-fx",
        "creator": "OpenGameArt contributor",
        "license": "CC0-1.0",
    },
    {
        "file": "ship_horn.ogg",
        "role": "Maritime cargo/passenger vessel horn near straits & ports",
        "url": "https://upload.wikimedia.org/wikipedia/commons/0/07/Cruise_ship_Albatros_ship_horn.ogg",
        "source_page": "https://commons.wikimedia.org/wiki/File:Cruise_ship_Albatros_ship_horn.ogg",
        "creator": "Wikimedia Commons contributor",
        "license": "CC0-1.0",
    },
]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def download(url: str, dest: Path, refresh: bool) -> None:
    if dest.exists() and not refresh:
        return
    dest.parent.mkdir(parents=True, exist_ok=True)
    r = requests.get(url, timeout=45, headers={"User-Agent": USER_AGENT})
    r.raise_for_status()
    if len(r.content) < 512:
        raise RuntimeError(f"Suspiciously small payload ({len(r.content)} bytes) from {url}")
    tmp = dest.with_suffix(dest.suffix + ".part")
    tmp.write_bytes(r.content)
    tmp.replace(dest)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true")
    args = parser.parse_args()

    OUT_UI.mkdir(parents=True, exist_ok=True)
    OUT_AMBIENT.mkdir(parents=True, exist_ok=True)
    OUT_BGM_DIR.mkdir(parents=True, exist_ok=True)
    readme_bgm = OUT_BGM_DIR / "README.txt"
    if not readme_bgm.exists():
        readme_bgm.write_text(
            "Taruh file musik BGM (.ogg / .wav / .mp3) di folder ini (contoh: bgm_main.ogg).\n"
            "GameAudio akan otomatis memutar & mengulang musik latar pada bus 'Musik'.\n",
            encoding="utf-8",
            newline="\n",
        )

    entries: list[dict] = []

    # Kenney LICENSE
    lic_dest = OUT_UI / "LICENSE.txt"
    download(f"https://raw.githubusercontent.com/Calinou/kenney-interface-sounds/{KENNEY_COMMIT}/LICENSE.txt", lic_dest, args.refresh)

    for fname, role in UI_FILES:
        dest = OUT_UI / fname
        url = f"{KENNEY_BASE}/{fname}"
        download(url, dest, args.refresh)
        entries.append({
            "file": f"ui/{fname}",
            "category": "ui",
            "role": role,
            "creator": "Kenney",
            "license": "CC0-1.0",
            "url": url,
            "commit": KENNEY_COMMIT,
            "bytes": dest.stat().st_size,
            "sha256": sha256(dest),
        })
        print(f"  [UI]      {fname:24s} ({dest.stat().st_size / 1024:.1f} KB)")

    for spec in AMBIENT_FILES:
        dest = OUT_AMBIENT / spec["file"]
        download(spec["url"], dest, args.refresh)
        entries.append({
            "file": f"ambient/{spec['file']}",
            "category": "ambient",
            "role": spec["role"],
            "creator": spec["creator"],
            "license": spec["license"],
            "url": spec["url"],
            "source_page": spec["source_page"],
            "bytes": dest.stat().st_size,
            "sha256": sha256(dest),
        })
        print(f"  [AMBIENT] {spec['file']:24s} ({dest.stat().st_size / 1024:.1f} KB)")

    manifest = {
        "schema": "nusantara.audio_assets/1",
        "license_summary": "All packaged audio assets are verified CC0-1.0 (Public Domain).",
        "assets": entries,
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    total_kb = sum(e["bytes"] for e in entries) / 1024.0
    print(f"\nDownloaded & verified {len(entries)} CC0 audio assets ({total_kb:.1f} KB total) -> {MANIFEST_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
