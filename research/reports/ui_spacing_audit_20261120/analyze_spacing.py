"""Analyze existing audit captures. No game/source files are changed."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re
from datetime import datetime, timezone
from PIL import Image

directory = Path(__file__).resolve().parent
root = directory.parents[2]
inventory = json.loads((directory / "inventory.json").read_text(encoding="utf-8"))
hero = root / "game/assets/ui/figma/2_NaraAdinataKarakterPemain_e7034.png"
image = Image.open(hero).convert("RGBA")
opaque = image.getchannel("A").point(lambda alpha: 255 if alpha >= 32 else 0).getbbox()
summaries = []
grounding = []
avatars = []
for shot in inventory["shots"]:
    buttons = shot["buttons"]
    summaries.append({
        "state": shot["name"], "buttons": len(buttons),
        "unclipped_safe_area_candidates": sum(bool(b.get("safe_area_candidate")) and not b["partially_clipped"] for b in buttons),
        "unclipped_outside_panel_rect": sum(bool(b.get("outside_frame_rect")) and not b["partially_clipped"] for b in buttons),
        "unclipped_outside_viewport": sum(b["outside_viewport"] and not b["partially_clipped"] for b in buttons),
        "partially_clipped": sum(b["partially_clipped"] for b in buttons),
    })
    textures = {item.get("slot"): item for item in shot["textures"] if item.get("slot")}
    if "imgNaraAdinataKarakterPemain" in textures and "imgPermukaanPanggung" in textures:
        figure = textures["imgNaraAdinataKarakterPemain"]
        platform = textures["imgPermukaanPanggung"]
        assert figure["stretch_mode"] == 5 and platform["stretch_mode"] == 5
        x, y, width, height = figure["rect"]
        scale = min(width / image.width, height / image.height)
        drawn_top = y + (height - image.height * scale) / 2
        opaque_foot = drawn_top + opaque[3] * scale
        platform_top = platform["rect"][1]
        gap = platform_top - opaque_foot
        grounding.append({"state": shot["name"], "logical_gap": gap,
                          "output_gap_px": gap * shot["output_scale"],
                          "figure_rect": figure["rect"], "platform_rect": platform["rect"]})
    for avatar in shot["textures"]:
        if avatar.get("slot") != "imgPotretPresidenNara":
            continue
        width, height = [float(part) for part in re.findall(r"[\d.]+", avatar["texture_size"])]
        _, _, draw_width, draw_height = avatar["rect"]
        record = {"state": shot["name"], "rect": avatar["rect"], "source_crop_aspect": width / height,
                  "draw_aspect": draw_width / draw_height,
                  "horizontal_relative_scale": (draw_width / width) / (draw_height / height)}
        parents = [f for f in shot["frames"] if avatar["path"].startswith(f["path"] + "/")]
        if parents:
            parent = max(parents, key=lambda item: len(item["path"]))
            x, y, w, h = parent["rect"]
            ax, ay, aw, ah = avatar["rect"]
            record["nearest_frame"] = parent
            record["edge_distances"] = [ax - x, ay - y, x + w - ax - aw, y + h - ay - ah]
        avatars.append(record)

before = json.loads((directory / "production_before.json").read_text(encoding="utf-8"))
changed = [path for path, checksum in before.items() if hashlib.sha256((root / path).read_bytes()).hexdigest() != checksum]
name_checks = json.loads((directory / "name_checks.json").read_text(encoding="utf-8"))
summary = {
    "analyzed_at": datetime.now(timezone.utc).isoformat(),
    "states": len(inventory["shots"]),
    "screenshots": len(list(directory.glob("*.png"))),
    "production_baseline_file_count": len(before),
    "production_files_changed": changed,
    "production_hash_note": "Workspace changes are detected, not attributed to this audit. The audit driver does not write production source files.",
    "final_feature_observations": name_checks["checks"],
    "runtime_errors": {"layout_run": inventory["runtime_errors"], "name_rerun": name_checks["runtime_errors"]},
    "world_unchanged_after_fixture": inventory["world_unchanged_after_fixture"],
    "summaries": summaries,
    "grounding": grounding,
    "avatar_geometry": avatars,
    "method_notes": [
        "Safe-area flags use nine-slice margins as a conservative rectangle, not an opaque-pixel border mask.",
        "Partially clipped scroll entries are separated from un-clipped controls.",
        "Ground gap projects the original figure's alpha>=32 bounding box through KEEP_ASPECT_CENTERED; the SVG ellipse occupies its full local height.",
        "Avatar aspect calculation uses the actual AtlasTexture size and destination rectangle; no bitmap is altered.",
    ],
}
(directory / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({"states": summary["states"], "screenshots": summary["screenshots"],
                  "production_files_changed": changed,
                  "outside_panel_unclipped_total": sum(s["unclipped_outside_panel_rect"] for s in summaries),
                  "ground_gaps": [{"state": g["state"], "output_gap_px": round(g["output_gap_px"], 1)} for g in grounding]}, ensure_ascii=True))
