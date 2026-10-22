"""Calibration: REAL observations -> DERIVED game baseline (game/data/baseline.json).

Per simulation variable (data/calibration/variable_map.json):
  1. choose ONE reference period: the latest period whose kab/kota coverage >= MIN_COVERAGE,
     else the latest period with any data (recorded either way; years are never mixed silently)
  2. per region: kab/kota observation -> REAL; else province observation (if rule allows) ->
     PROVINCE_PROXY; else neutral default -> UNCALIBRATED
  3. write values + region_status + provenance; write a calibration coverage report

Never fills a missing value with a guess: the only non-sourced values are the documented neutral
defaults, and those carry status UNCALIBRATED so the UI labels them.
"""
from __future__ import annotations

import json
import sys
from collections import Counter
from pathlib import Path
from typing import Callable

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from lib import observations  # noqa: E402
from lib.fetch import REPO_ROOT, utc_now  # noqa: E402

MIN_COVERAGE = 0.9
VAR_MAP = REPO_ROOT / "data/calibration/variable_map.json"
REGISTRY = REPO_ROOT / "data/normalized/regions/region_registry.json"
PARAMS = REPO_ROOT / "game/data/sim_params.json"
OUT = REPO_ROOT / "game/data/baseline.json"
REPORT = REPO_ROOT / "research/reports/validation/calibration_coverage.md"
SNAPSHOT_ID = "SNAP-2026-10-DEV1"


def _index(rows: list[dict]) -> dict[tuple[str, str], dict]:
    """(period, region_id) -> row with a value. Duplicate keys are an error (conflicts must be resolved upstream)."""
    idx: dict[tuple[str, str], dict] = {}
    for r in rows:
        if r.get("value") is None:
            continue
        k = (r["reference_period"], r["region_id"])
        if k in idx:
            raise ValueError(f"duplicate observation for {r['obs_variable_id']} {k}; resolve conflict explicitly")
        idx[k] = r
    return idx


def choose_period(indexes: list[dict], region_order: list[str]) -> tuple[str | None, float]:
    periods = set.intersection(*[{p for (p, _r) in ix} for ix in indexes]) if indexes else set()
    best = None
    for p in sorted(periods, reverse=True):
        cov = sum(all((p, r) in ix for ix in indexes) for r in region_order) / len(region_order)
        if best is None:
            best = (p, cov)
        if cov >= MIN_COVERAGE:
            return p, cov
    return best if best else (None, 0.0)


def _combine(rule: dict, vals: list[float]) -> float:
    if rule["rule"] == "identity":
        return vals[0]
    if rule["rule"] == "scaled":
        return vals[0] * float(rule["scale"])
    if rule["rule"] == "ratio_pct":
        return 100.0 * vals[0] / vals[1] if vals[1] else float("nan")
    raise ValueError(f"unknown rule {rule['rule']}")


def gamma_poisson_rate(rule: dict, rows: list[dict], region_order: list[str]) -> dict:
    """Empirical-Bayes event rate per year (Gamma-Poisson), pooling ALL observed years per region.

    y_i = total recorded events, n_i = number of observed years. Cross-sectional rates r_i = y_i/n_i give
    mean m and variance v. Method of moments: alpha = m^2/(v - m) (overdispersion; if v <= m the
    data show no extra-Poisson variation and alpha is set very large = full pooling), beta = alpha/m
    (prior strength in years). Province prior mean is itself shrunk toward the national mean:
    m_p = (beta*m + sum_p y) / (beta + N_p) over the province's observed region-years, so it is never 0
    even if every observed region in the province recorded 0 events (regression 2026-10-06).
    lambda_i = (beta*m_p + y_i) / (beta + n_i). Regions with no observation get the prior mean and
    status PROVINCE_PROXY (province prior) or UNCALIBRATED (national prior). Nothing is set to 0
    by default: absence of records is not evidence of zero frequency.
    """
    MIN_PROV = 3
    y: dict[str, float] = {}
    n: dict[str, int] = {}
    years: set[str] = set()
    for r in rows:
        if r.get("value") is None:
            continue
        y[r["region_id"]] = y.get(r["region_id"], 0.0) + float(r["value"])
        n[r["region_id"]] = n.get(r["region_id"], 0) + 1
        years.add(r["reference_period"])
    rates = {k: y[k] / n[k] for k in y}
    vals = list(rates.values())
    m = sum(vals) / len(vals)
    v = sum((x - m) ** 2 for x in vals) / len(vals)
    alpha = m * m / (v - m) if v > m else 1e6
    beta = alpha / m
    py: dict[str, float] = {}
    pn: dict[str, int] = {}
    pr: dict[str, int] = {}
    for k in y:
        py[k[:2]] = py.get(k[:2], 0.0) + y[k]
        pn[k[:2]] = pn.get(k[:2], 0) + n[k]
        pr[k[:2]] = pr.get(k[:2], 0) + 1
    prov_mean = {p: (beta * m + py[p]) / (beta + pn[p]) for p in py if pr[p] >= MIN_PROV}
    values, status = [], []
    for rid in region_order:
        mp = prov_mean.get(rid[:2], m)
        values.append((beta * mp + y.get(rid, 0.0)) / (beta + n.get(rid, 0)))
        status.append("REAL" if rid in y else ("PROVINCE_PROXY" if rid[:2] in prov_mean else "UNCALIBRATED"))
    return {"values": values, "status": status, "years": sorted(years),
            "params": {"national_mean_rate": round(m, 6), "cross_sectional_variance": round(v, 6),
                       "alpha": round(alpha, 6), "beta_years": round(beta, 6), "min_regions_for_province_prior": MIN_PROV,
                       "provinces_with_own_prior": len(prov_mean)}}


def build(var_map: dict, sim_vars: list[str], region_order: list[str],
          read_obs: Callable[[str], list[dict]]) -> tuple[dict, list[str]]:
    out_vars: dict[str, dict] = {}
    report: list[str] = []
    n = len(region_order)
    for v in sim_vars:
        rule = var_map["rules"].get(v)
        default = float(var_map["neutral_defaults"][v])
        entry = {"status": "UNCALIBRATED", "default": default, "values": None, "region_status": None,
                 "provenance": None, "reference_period": None, "rule": None, "inputs": None}
        if rule is None and v in var_map["by_design_neutral"]:
            # Model states defined by the simulation, not measurements awaiting data (e.g. damage 0 at
            # start, price index 100). Labeled BY_DESIGN with the documented reason, never as data.
            entry.update(status="BY_DESIGN", provenance={"reason": var_map["by_design_neutral"][v],
                                                         "built_by": "scripts/pipelines/calibration/build_baseline.py"})
            out_vars[v] = entry
            report.append(f"| `{v}` | by design | — | — | — | — | {var_map['by_design_neutral'][v]} |")
            continue
        if rule is None or rule["rule"] == "copy":
            out_vars[v] = entry
            continue
        if rule["rule"] == "gamma_poisson_rate":
            rows = read_obs(rule["inputs"][0])
            if rule.get("years"):  # production years pinned (D-037); other years are candidates only
                rows = [r for r in rows if r["reference_period"] in set(rule["years"])]
            if not any(r.get("value") is not None for r in rows):
                report.append(f"| `{v}` | gamma_poisson_rate({rule['inputs'][0]}) | — | 0/{n} | 0 | {n} | inputs not yet ingested |")
                entry.update(rule=rule["rule"], inputs=rule["inputs"])
                out_vars[v] = entry
                continue
            g = gamma_poisson_rate(rule, rows, region_order)
            c = Counter(g["status"])
            entry.update(status="DERIVED", values=g["values"], region_status=g["status"],
                         reference_period="+".join(g["years"]), rule=rule["rule"], inputs=rule["inputs"],
                         provenance={"rule": rule["rule"], "inputs": rule["inputs"], "years": g["years"],
                                     "params": g["params"], "sources": sorted({r["source_id"] for r in rows}),
                                     "built_by": "scripts/pipelines/calibration/build_baseline.py"})
            out_vars[v] = entry
            report.append(f"| `{v}` | gamma_poisson_rate({rule['inputs'][0]}) | {'+'.join(g['years'])} | {c['REAL']}/{n} | "
                          f"{c['PROVINCE_PROXY']} | {c['UNCALIBRATED']} | alpha={g['params']['alpha']:.3f}, beta={g['params']['beta_years']:.3f} yr, national mean {g['params']['national_mean_rate']:.3f}/yr |")
            continue
        indexes = [_index(read_obs(i)) for i in rule["inputs"]]
        if any(not ix for ix in indexes):
            missing = [i for i, ix in zip(rule["inputs"], indexes) if not ix]
            report.append(f"| `{v}` | {rule['rule']}({', '.join(rule['inputs'])}) | — | 0/{n} | 0 | {n} | inputs not yet ingested: {', '.join(missing)} |")
            entry.update(rule=rule["rule"], inputs=rule["inputs"])
            out_vars[v] = entry
            continue
        period, cov = choose_period(indexes, region_order)
        lo, hi = rule.get("clamp", [float("-inf"), float("inf")])
        values, status, used_refs = [], [], set()
        for rid in region_order:
            src = None
            if period and all((period, rid) in ix for ix in indexes):
                src, st = [ix[(period, rid)] for ix in indexes], "REAL"
            elif period and rule.get("fallback") == "province_proxy" and all((period, rid[:2]) in ix for ix in indexes):
                src, st = [ix[(period, rid[:2])] for ix in indexes], "PROVINCE_PROXY"
            if src is None:
                values.append(default)
                status.append("UNCALIBRATED")
                continue
            val = _combine(rule, [r["value"] for r in src])
            if val != val:  # NaN (e.g. zero denominator) -> not computable, do not invent
                values.append(default)
                status.append("UNCALIBRATED")
                continue
            values.append(min(max(val, lo), hi))
            status.append(st)
            used_refs.update(f"{r['source_id']}|{r['dataset_ref'].split(';th=')[0]}" for r in src)
        c = Counter(status)
        entry.update(
            status=("REAL_OFFICIAL" if c["REAL"] == n and rule["rule"] == "identity"
                    else "DERIVED" if c["REAL"] + c["PROVINCE_PROXY"] > 0 else "UNCALIBRATED"),
            values=values, region_status=status, reference_period=period, rule=rule["rule"], inputs=rule["inputs"],
            provenance={"rule": rule["rule"], "inputs": rule["inputs"], "reference_period": period,
                        "sources": sorted(used_refs), "built_by": "scripts/pipelines/calibration/build_baseline.py"},
        )
        out_vars[v] = entry
        report.append(f"| `{v}` | {rule['rule']}({', '.join(rule['inputs'])}) | {period} | {c['REAL']}/{n} | "
                      f"{c['PROVINCE_PROXY']} | {c['UNCALIBRATED']} | period coverage {cov:.0%} |")
    # copy rules after their sources exist
    for v in sim_vars:
        rule = var_map["rules"].get(v)
        if rule and rule["rule"] == "copy":
            src = dict(out_vars[rule["from"]])
            src["default"] = float(var_map["neutral_defaults"][v])
            src["rule"] = f"copy:{rule['from']}"
            out_vars[v] = src
    return out_vars, report


def main() -> int:
    var_map = json.loads(VAR_MAP.read_text(encoding="utf-8"))
    sim_vars = list(json.loads(PARAMS.read_text(encoding="utf-8"))["variables"])
    missing = set(sim_vars) - set(var_map["neutral_defaults"])
    if missing:
        raise SystemExit(f"variable_map.neutral_defaults missing: {sorted(missing)}")
    region_order = [r["region_id"] for r in json.loads(REGISTRY.read_text(encoding="utf-8"))["kabkota"]]
    out_vars, report = build(var_map, sim_vars, region_order, observations.read)
    baseline = {"schema": "nusantara.game_baseline/2", "generated_at": utc_now(), "snapshot_id": SNAPSHOT_ID,
                "region_order": region_order, "variables": out_vars}
    OUT.write_text(json.dumps(baseline, ensure_ascii=False, indent=1), encoding="utf-8")
    statuses = Counter(e["status"] for e in out_vars.values())
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text("\n".join([
        "# Calibration coverage", "", f"Generated {baseline['generated_at']} · snapshot `{SNAPSHOT_ID}`", "",
        f"Variable status: {dict(statuses)}", "",
        "| Sim variable | Rule | Period | REAL | Province proxy | Uncalibrated | Note |", "|---|---|---|---|---|---|---|",
        *report, "",
        "Variables neutral by design: " + ", ".join(f"`{k}`" for k in var_map["by_design_neutral"]), "",
    ]), encoding="utf-8")
    print(f"baseline written: {dict(statuses)}")
    for line in report:
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
