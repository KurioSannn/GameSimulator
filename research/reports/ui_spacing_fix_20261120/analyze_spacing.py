"""Compare preserved audit geometry with final UI verification. No production writes."""
from pathlib import Path
import hashlib
import json

directory = Path(__file__).resolve().parent
root = directory.parents[2]
old = json.loads((root / "research/reports/ui_spacing_audit_20261120/inventory.json").read_text(encoding="utf-8"))
new = json.loads((directory / "inventory.json").read_text(encoding="utf-8"))

def summarize(shot):
    buttons = [b for b in shot["buttons"] if not b["partially_clipped"]]
    return {
        "state": shot["name"],
        "visible_buttons": len(shot["buttons"]),
        "safe_area_candidates": sum(bool(b.get("safe_area_candidate")) for b in buttons),
        "outside_panel": sum(bool(b.get("outside_frame_rect")) for b in buttons),
        "outside_viewport": sum(bool(b["outside_viewport"]) for b in buttons),
        "clipped_scroll_entries": sum(b["partially_clipped"] for b in shot["buttons"]),
    }

before = {s["name"]: summarize(s) for s in old["shots"]}
after = [summarize(s) for s in new["shots"]]
baseline = json.loads((directory / "production_before.json").read_text(encoding="utf-8"))
changed = [p for p, digest in baseline.items() if hashlib.sha256((root / p).read_bytes()).hexdigest() != digest]
stages = [{"state": s["name"], **stage} for s in new["shots"] for stage in s.get("stages", [])]
avatars = []
for shot in new["shots"]:
    for texture in shot["textures"]:
        if texture.get("slot") == "imgPotretPresidenNara":
            avatars.append({"state": shot["name"], "crop_size": texture["texture_size"], "destination": texture["rect"], "stretch_mode": texture["stretch_mode"]})
result = {
    "states": len(new["shots"]),
    "screenshots": len(list(directory.glob("*.png"))),
    "feature_observations": new["checks"],
    "runtime_errors": new["runtime_errors"],
    "world_unchanged": new["world_unchanged_after_fixture"],
    "safe_area_candidates_total": sum(s["safe_area_candidates"] for s in after),
    "outside_panel_total": sum(s["outside_panel"] for s in after),
    "outside_viewport_total": sum(s["outside_viewport"] for s in after),
    "summaries": after,
    "comparison_1280_100": [{"state": s["state"], "before_candidates": before[s["state"]]["safe_area_candidates"], "after_candidates": s["safe_area_candidates"]} for s in after if s["state"].endswith("1280_100") and s["state"] in before],
    "grounding": stages,
    "avatars": avatars,
    "production_files_changed": changed,
    "new_production_files": ["game/src/ui/player_name_editor.gd", "game/src/ui/president_portrait.gd"],
    "method_note": "Nine-slice safe rectangle is a conservative proxy. Naturally clipped scroll entries are excluded. Stage contact is a runtime alpha-crop geometry check, complemented by screenshot inspection.",
}
(directory / "summary.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8", newline="\n")
print(json.dumps({k: result[k] for k in ["states", "screenshots", "safe_area_candidates_total", "outside_panel_total", "outside_viewport_total", "world_unchanged", "production_files_changed"]}))
failed = [x for x in new["checks"] if not x["ok"]]
assert not failed, failed
assert not new["runtime_errors"]
assert new["world_unchanged_after_fixture"]
assert result["safe_area_candidates_total"] == 0
assert result["outside_panel_total"] == result["outside_viewport_total"] == 0
