"""Bundle selected original CC0 sprites from the cached creator-distributed archive."""
from pathlib import Path
from zipfile import ZipFile
from datetime import datetime, timezone
import hashlib
import json

root = Path(__file__).resolve().parents[3]
archive_path = Path(__file__).resolve().parent / "raw/kenney_ui-pack-adventure.zip"
destination = root / "game/assets/ui/kenney_adventure"
chosen = ["panel_brown_corners_a", "panel_brown", "panel_grey_bolts_detail_a", "panel_grey_bolts_dark",
          "panel_border_brown_detail", "button_brown", "button_grey", "button_red", "round_brown",
          "round_brown_dark", "round_grey_dark", "hexagon_brown", "hexagon_brown_dark", "hexagon_grey_dark",
          "banner_hanging", "minimap_icon_exclamation_red", "minimap_icon_star_yellow",
          "minimap_icon_jewel_yellow", "minimap_compass_toon_n", "minimap_arrow_a",
          "progress_red_border", "progress_transparent", "checkbox_beige_checked", "checkbox_beige_empty"]
destination.mkdir(parents=True, exist_ok=True)
records = []
with ZipFile(archive_path) as archive:
    for name in chosen:
        entry = "PNG/Double/" + name + ".png"
        payload = archive.read(entry)
        (destination / (name + ".png")).write_bytes(payload)
        records.append({"file": name + ".png", "archive_entry": entry,
                        "sha256": hashlib.sha256(payload).hexdigest()})
    (destination / "License.txt").write_bytes(archive.read("License.txt"))
manifest = {
    "source_institution": "Kenney", "title": "UI Pack - Adventure", "license": "CC0-1.0",
    "version": "1.1 per archive License.txt; creator HTML listing still reports 1.0",
    "url": "https://kenney.nl/assets/ui-pack-adventure", "publication_update_date": "2024-08-13 (archive creation date)",
    "creator_distribution_url": "https://opengameart.org/content/ui-pack-adventure",
    "download_url": "https://opengameart.org/sites/default/files/kenney_ui-pack-adventure.zip",
    "retrieval_timestamp": datetime.fromtimestamp(archive_path.stat().st_mtime, timezone.utc).isoformat(),
    "geographic_resolution": "Not applicable; UI art", "reference_period": "Archive version 1.1",
    "unit": "Original double-resolution PNG sprite", "source_status": "Creator distribution and bundled CC0 notice verified",
    "archive_sha256": hashlib.sha256(archive_path.read_bytes()).hexdigest(), "files": records,
    "usage": "Native Godot nine-slice frames, game buttons and HUD decorations; original bytes retained."
}
(destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n")
print("Bundled", len(records), "original CC0 PNGs and license")
