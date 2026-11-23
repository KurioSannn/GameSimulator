"""Narrative coverage of the 50 top-level cases (machine-readable record + content-level checks).

Writes research/reports/STORY_COVERAGE.json. A case is narrative-complete only when the scenes are
present AND pass content checks (who speaks, distinct per-choice reactions, delayed state-dependent
callback, unattended scene, art, language rules), not merely when JSON fields are non-empty.
Run: python3 scripts/story/coverage.py [--strict]   (--strict exits 1 on any incomplete case)
"""
import json, glob, re, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CAST = json.load(open(ROOT / "game/data/story/cast.json", encoding="utf-8"))["characters"]
ADVISERS = {"laras", "bayu", "yosef", "sekar"}
BG_DIR = ROOT / "game/assets/story/backgrounds"
LOC_DIR = ROOT / "game/assets/story/portraits/locals"
BAD = [("—", "em dash"), ("http", "url"), ("SRC-", "source id"), ("www.", "url")]


def flat(beats):
    out = []
    for b in beats:
        if "pick" in b:
            for v in b["pick"]:
                out += flat(v.get("beats", []))
            continue
        out.append(b)
        for o in b.get("options", []):
            out += flat(o.get("reply", []))
    return out


def check(case, ep, cases):
    cid = case["case_id"]
    loc = set(ep.get("locals", {}))
    op = flat(ep.get("opening", []))
    sp = [b.get("s") for b in op]
    r = {"case_id": cid, "title": case["title"]}
    r["opening"] = len(op) >= 5 and "narasi" in sp and bool(loc & set(sp)) and bool(ADVISERS & set(sp)) and "nara" in sp
    r["opening_beats"] = len(op)
    r["human_context"] = len(loc) >= 1 and all(k in sp or any(k in [b.get("s") for b in flat(v)] for v in ep.get("reactions", {}).values()) for k in loc)
    reacts = ep.get("reactions", {})
    ids = [c["choice_id"] for c in case["choices"]]
    texts = [json.dumps(reacts.get(i, []), ensure_ascii=False) for i in ids]
    per = {}
    for i in ids:
        bs = flat(reacts.get(i, []))
        per[i] = len(bs) >= 3 and any(b.get("s") in loc for b in bs) and any(b.get("s") == "narasi" for b in bs)
    r["reactions"] = len(ids) >= 3 and all(per.values()) and len(set(texts)) == len(ids)
    r["reaction_detail"] = per
    cbs = ep.get("callbacks", [])
    r["aftermath"] = all(len(flat(reacts.get(i, []))) >= 3 for i in ids)
    r["delayed_callback"] = any(int(cb.get("after_quarters", 0)) >= 2 and any("pick" in b and len(b["pick"]) >= 2 for b in cb.get("beats", [])) for cb in cbs)
    r["unattended_scene"] = len(flat(ep.get("unattended", []))) >= 2
    fus = case.get("follow_ups", [])
    fu_ids = [f.get("case_id", f) if isinstance(f, dict) else f for f in fus]
    r["follow_ups"] = {f: bool(cases.get(f, {}).get("_ep")) for f in fu_ids}
    r["follow_up_scenes"] = all(r["follow_ups"].values())
    r["standalone_scenario"] = case.get("class") == "major_historical"
    bgs = {ep.get("background")} | {b.get("bg") for b in flat(ep.get("opening", [])) + [x for v in reacts.values() for x in flat(v)]}
    bgs.discard(None)
    r["art"] = all((BG_DIR / (b + ".jpg")).exists() for b in bgs) and all((LOC_DIR / ("%s_%s.jpg" % (cid, k))).exists() for k in loc)
    alltext = json.dumps(ep, ensure_ascii=False)
    issues = [name for s, name in BAD if s in alltext]
    long = [b["t"] for b in flat(ep.get("opening", [])) + [x for v in reacts.values() for x in flat(v)] if len(b.get("t", "")) > 190]
    if long:
        issues.append("%d beats over 190 chars" % len(long))
    r["language_issues"] = issues
    keys = ["opening", "human_context", "reactions", "aftermath", "delayed_callback", "unattended_scene", "follow_up_scenes", "standalone_scenario", "art"]
    r["narrative_validation"] = "complete" if all(r[k] for k in keys) and not issues else "incomplete"
    r["missing"] = [k for k in keys if not r[k]] + issues
    return r


def main():
    cases = {}
    for f in glob.glob(str(ROOT / "game/data/cases/CASE-*.json")):
        c = json.load(open(f, encoding="utf-8"))
        cases[c["case_id"]] = c
    for f in glob.glob(str(ROOT / "game/data/story/episodes/*.json")):
        e = json.load(open(f, encoding="utf-8"))
        if e["case_id"] in cases:
            cases[e["case_id"]]["_ep"] = e
    rows = [check(c, c.get("_ep", {}), cases) for cid, c in sorted(cases.items()) if c.get("class") == "major_historical"]
    done = sum(r["narrative_validation"] == "complete" for r in rows)
    out = {"schema": "nusantara.story_coverage/1", "generated_by": "scripts/story/coverage.py",
           "cases": len(rows), "complete": done, "rows": rows}
    (ROOT / "research/reports/STORY_COVERAGE.json").write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    print("narrative-complete: %d / %d" % (done, len(rows)))
    for r in rows:
        if r["missing"]:
            print(r["case_id"], r["missing"])
    if "--strict" in sys.argv and done != len(rows):
        sys.exit(1)


if __name__ == "__main__":
    main()
