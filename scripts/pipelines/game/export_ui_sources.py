"""Export existing provenance to the offline UI; never fetch or invent source metadata."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "research/sources/source_registry.json"
OUTPUT = ROOT / "game/data/ui/sources.json"
FIELDS = (
    "source_id", "institution", "title", "url", "publication_date", "retrieved_at",
    "geographic_resolution", "reference_period", "unit", "status", "methodology_note",
    "license_or_terms",
)


def main() -> None:
    raw = SOURCE.read_bytes()
    registry = json.loads(raw)
    payload = {
        "schema": "nusantara.ui_sources/1",
        "registry_sha256": hashlib.sha256(raw).hexdigest(),
        "sources": {
            row["source_id"]: {key: row[key] for key in FIELDS if key in row}
            for row in registry["sources"]
        },
    }
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(payload['sources'])} source records to {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
