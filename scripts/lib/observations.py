"""Read/write normalized REAL observations (data/normalized/observations/<obs_variable_id>.jsonl).

Every row is validated against data/schemas/observation.schema.json on write. Rows are sorted
deterministically so diffs are reviewable.
"""
from __future__ import annotations

import json
from pathlib import Path

from jsonschema import Draft202012Validator

from lib.fetch import REPO_ROOT

OBS_DIR = REPO_ROOT / "data/normalized/observations"
_SCHEMA = json.loads((REPO_ROOT / "data/schemas/observation.schema.json").read_text(encoding="utf-8"))
_VALIDATOR = Draft202012Validator(_SCHEMA)


class ObservationError(ValueError):
    pass


def validate(rows: list[dict]) -> None:
    for i, r in enumerate(rows):
        errs = list(_VALIDATOR.iter_errors(r))
        if errs:
            raise ObservationError(f"row {i} ({r.get('region_id')}): {errs[0].message}")
    keys = [(r["region_id"], r["reference_period"], r["dataset_ref"]) for r in rows]
    if len(keys) != len(set(keys)):
        raise ObservationError("duplicate (region, period, dataset_ref) rows")


def write(obs_variable_id: str, rows: list[dict], obs_dir: Path = OBS_DIR) -> Path:
    if any(r["obs_variable_id"] != obs_variable_id for r in rows):
        raise ObservationError("mixed obs_variable_id in one file")
    validate(rows)
    rows = sorted(rows, key=lambda r: (r["reference_period"], r["region_id"], r["dataset_ref"]))
    obs_dir.mkdir(parents=True, exist_ok=True)
    path = obs_dir / f"{obs_variable_id}.jsonl"
    path.write_text("".join(json.dumps(r, ensure_ascii=False, sort_keys=True) + "\n" for r in rows), encoding="utf-8")
    return path


def read(obs_variable_id: str, obs_dir: Path = OBS_DIR) -> list[dict]:
    path = obs_dir / f"{obs_variable_id}.jsonl"
    if not path.exists():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
