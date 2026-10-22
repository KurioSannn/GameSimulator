"""Validate all research/game data files against data/schemas/*.schema.json.

Usage: .venv/bin/python scripts/validate_all.py   (exit 1 on any violation)
"""
from __future__ import annotations

import glob
import json
import sys
from pathlib import Path

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    "source_registry": ["research/sources/source_registry.json"],
    "region_registry": ["data/normalized/regions/region_registry.json"],
    "baseline": ["game/data/baseline.json"],
    "case": sorted(glob.glob(str(ROOT / "game/data/cases/*.json"))),
    "case_research": sorted(glob.glob(str(ROOT / "research/cases/*.json"))),
    "cultural_record": sorted(glob.glob(str(ROOT / "research/culture/records/*.json"))),
    "policy": sorted(glob.glob(str(ROOT / "game/data/policies/*.json"))),
}


def main() -> int:
    bad = 0
    for schema_name, files in TARGETS.items():
        schema = json.loads((ROOT / f"data/schemas/{schema_name}.schema.json").read_text(encoding="utf-8"))
        v = Draft202012Validator(schema)
        for f in files:
            p = Path(f) if Path(f).is_absolute() else ROOT / f
            errs = sorted(v.iter_errors(json.loads(p.read_text(encoding="utf-8"))), key=lambda e: list(e.path))
            for e in errs[:20]:
                print(f"FAIL {p.relative_to(ROOT)} @ {'/'.join(map(str, e.path))}: {e.message[:200]}")
            bad += len(errs)
            if not errs:
                print(f"ok   {p.relative_to(ROOT)}  [{schema_name}]")
    # Observations (JSON Lines): every row against observation.schema.json.
    ov = Draft202012Validator(json.loads((ROOT / "data/schemas/observation.schema.json").read_text(encoding="utf-8")))
    for f in sorted(glob.glob(str(ROOT / "data/normalized/observations/*.jsonl"))):
        n_bad = 0
        lines = Path(f).read_text(encoding="utf-8").splitlines()
        for i, line in enumerate(lines):
            for e in ov.iter_errors(json.loads(line)):
                n_bad += 1
                if n_bad <= 5:
                    print(f"FAIL {Path(f).relative_to(ROOT)}:{i + 1}: {e.message[:200]}")
        bad += n_bad
        if not n_bad:
            print(f"ok   {Path(f).relative_to(ROOT)}  [observation x{len(lines)}]")
    # Cross-file: every game case research_ref exists and its sources are declared in the research record.
    for f in TARGETS["case"]:
        c = json.loads(Path(f).read_text(encoding="utf-8"))
        ref = ROOT / c["research_ref"]
        if not ref.exists():
            print(f"FAIL {f}: research_ref missing {ref}")
            bad += 1
            continue
        declared = {s["source_id"] for s in json.loads(ref.read_text(encoding="utf-8"))["sources"]}
        for line in c["real_context"]["lines"]:
            for sid in line["source_refs"]:
                if sid not in declared:
                    print(f"FAIL {c['case_id']}: source {sid} not declared in {c['research_ref']}")
                    bad += 1
    # Policies: categories, variables, exclusivity symmetry, cultural hook integrity.
    cats = {c["id"] for c in json.loads((ROOT / "game/data/policy_categories.json").read_text(encoding="utf-8"))["categories"]}
    sim_vars = set(json.loads((ROOT / "game/data/sim_params.json").read_text(encoding="utf-8"))["variables"])
    pols = {json.loads(Path(f).read_text(encoding="utf-8"))["policy_id"]: json.loads(Path(f).read_text(encoding="utf-8")) for f in TARGETS["policy"]}
    for pid, p in pols.items():
        problems = []
        if p["category"] not in cats:
            problems.append(f"unknown category {p['category']}")
        for e in p["effects"]:
            if e["scope"] == "target" and e["var"] not in sim_vars:
                problems.append(f"unknown var {e['var']}")
            if e.get("scale_by") and e["scale_by"]["var"] not in sim_vars:
                problems.append(f"unknown scale_by var {e['scale_by']['var']}")
        for o in p["mutually_exclusive"]:
            if o not in pols or pid not in pols[o]["mutually_exclusive"]:
                problems.append(f"mutual exclusion with {o} not symmetric/known")
        cb = p.get("cultural_basis")
        if cb and not (ROOT / f"research/culture/records/{cb['culture_record_ref']}.json").exists():
            problems.append("cultural_basis references a missing culture record")
        for pr in problems:
            print(f"FAIL policy {pid}: {pr}")
        bad += len(problems)
    print(f"\n{'OK' if bad == 0 else f'{bad} violation(s)'}")
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
