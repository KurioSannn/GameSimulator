"""Remove / check U+2014 (em dash) in human-authored, player-facing and documentation text.

  python3 scripts/text/em_dash.py --check     exit 1 if any in-scope file contains U+2014
  python3 scripts/text/em_dash.py --fix       rewrite in place (rules below), print a summary

Rewrite rules (applied per line, conservative and readable):
  1. A line with two dashes "A — aside — B"      -> "A (aside) B"
  2. Heading / label "ID — Title" at line start   -> "ID: Title"
  3. Placeholder value "—" alone in quotes        -> "-"
  4. Any other " — " / "—"                         -> ", "
Out of scope (immutable or generated; reported, never edited): data/** (raw captures, normalized and
calibration outputs carry checksums), scripts/pipelines/** (generators of those outputs), captured
evidence under research/reports/**/*.json and research/reports/**/before/**, third-party licenses,
binary assets. game/data/ui/sources.json is regenerated from the registry by its export script.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DASH = "—"
TEXT_EXT = {".md", ".json", ".gd", ".py", ".txt", ".cfg", ".csv", ".tscn", ".gdshader", ".yaml", ".yml", ".sh", ""}


def in_scope(path: str) -> bool:
    p = path
    if p.startswith(("data/", "scripts/pipelines/", "game/assets/", "game/.godot/")):
        return False
    if p.startswith("research/reports/") and (p.endswith(".json") or "/before/" in p or p.endswith(".gd")):
        return False
    if "license" in p.lower() or p.endswith("OFL.txt"):
        return False
    if p == "game/data/ui/sources.json":  # generated: export_ui_sources.py
        return False
    if p.startswith("game/data/map/"):  # generated map/art exports (provenance copied from registry)
        return False
    return Path(p).suffix in TEXT_EXT


def tracked() -> list:
    out = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n")
    return [f for f in out if f]


LABEL = re.compile(r"^(\s*(?:#+\s*|[-*]\s+|\|\s*)?(?:\*\*)?[^\s]{1,40}?(?:\s[^\s]{1,20}){0,3}?(?:\*\*)?)\s+" + DASH + r"\s+")


def fix_line(line: str) -> str:
    if DASH not in line:
        return line
    line = line.replace('"' + DASH + '"', '"-"').replace("'" + DASH + "'", "'-'")
    if line.count(DASH) >= 2 and line.count(" " + DASH + " ") >= 2:
        line = re.sub(r"\s+" + DASH + r"\s+([^" + DASH + r"]+?)\s+" + DASH + r"\s+", r" (\1) ", line, count=1)
    m = LABEL.match(line)
    if m and line.lstrip().startswith(("#", "|", "**", "- **", "* **")):
        line = m.group(1) + ": " + line[m.end():]
    line = re.sub(r"\s*" + DASH + r"\s*", ", ", line)
    line = line.replace(", ,", ",").replace(" ,", ",")
    return line


def fix_text(text: str) -> str:
    return "\n".join(fix_line(l) for l in text.split("\n"))


def fix_json_value(v):
    if isinstance(v, str):
        return fix_text(v)
    if isinstance(v, list):
        return [fix_json_value(x) for x in v]
    if isinstance(v, dict):
        return {k: fix_json_value(x) for k, x in v.items()}
    return v


def count(path: Path) -> int:
    try:
        s = path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return 0
    n = s.count(DASH)
    if path.suffix == ".json" and "\\u2014" in s:
        n += s.count("\\u2014")
    return n


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "--check"
    files = tracked()
    bad, skipped, fixed = [], [], []
    for f in files:
        p = ROOT / f
        if not p.is_file():
            continue
        n = count(p)
        if n == 0:
            continue
        if not in_scope(f):
            skipped.append((f, n))
            continue
        if mode == "--fix":
            s = p.read_text(encoding="utf-8")
            # Text-level rewrite keeps each file's own formatting; the dash only occurs inside string
            # values, and the replacement introduces no JSON-structural characters.
            s = s.replace("\\u2014", DASH)
            p.write_text(fix_text(s), encoding="utf-8")
            fixed.append((f, n))
        else:
            bad.append((f, n))
    if mode == "--fix":
        print(f"rewrote {sum(n for _, n in fixed)} occurrences in {len(fixed)} files")
    for f, n in bad:
        print(f"U+2014 x{n}: {f}")
    print(f"out of scope (left unchanged): {len(skipped)} files, {sum(n for _, n in skipped)} occurrences")
    for f, n in skipped:
        print(f"  skip x{n}: {f}")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
