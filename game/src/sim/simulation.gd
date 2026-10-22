class_name Simulation
extends RefCounted
## Monthly tick orchestration. Every region is processed every tick, in a fixed order,
## inside centralized loops (no visibility- or selection-based skipping).
##
## Causal chains implemented (v0.3):
##   budget level -> fiscal space;  sector intensity -> infrastructure / services / food capacity /
##     flood protection (exposure-weighted) / recovery speed
##   BNPB frequency x season -> Poisson flood events; Exp severity x IRBI risk scale x (1 - mitigation)
##     x infrastructure resilience -> damage
##   damage -> logistics -> food realization -> (national pool / trade) -> food supply
##   food supply -> price level -> welfare -> sentiment -> trust (slow memory)
##   infrastructure + services -> recovery speed -> damage
## Coefficients live in data/sim_params.json (DERIVED design assumptions, not real data).

var params: Dictionary
var bounds: Dictionary   # var -> {min,max}
var c: Dictionary        # coefficient name -> float (flattened for fast access)
var sentiment_states: Array
var flood_season: PackedFloat64Array
var season_total: float
var start_month: int
var budget_cfg: Dictionary   # game/data/budget.json (DERIVED); sectors' base shares
# Attribution scratch (observational, filled only while a SimLedger quarter is open): the part of each
# region's price change caused by national price pressure, and which sources made up that pressure.
var _pp_part := PackedFloat64Array()
var _pp_fracs: Dictionary = {}


func _init(sim_params: Dictionary, budget: Dictionary = {}) -> void:
	budget_cfg = budget
	flood_season = PackedFloat64Array(sim_params.get("flood_season", {}).get("values", [1,1,1,1,1,1,1,1,1,1,1,1]))
	season_total = 0.0
	for x in flood_season:
		season_total += x
	start_month = int(sim_params.get("calendar", {}).get("start_month", 1))
	params = sim_params
	bounds = sim_params["variables"]
	c = {}
	for k in sim_params["coefficients"]:
		c[k] = float(sim_params["coefficients"][k]["value"])
	sentiment_states = sim_params["sentiment_states"]


func var_names() -> Array:
	return bounds.keys()


## Advances one month. Returns a tick report used by UI/logging (not authoritative state).
func step_month(world: SimWorld) -> Dictionary:
	var applied := EffectQueue.apply_due(world, bounds)
	var sentiment_before: PackedFloat64Array = world.vars["sentiment"].duplicate()

	# Each system's deltas are attributed to it in the quarter ledger (no-op when no ledger is open).
	var w := SimLedger.SYSTEM_WRITES
	var snap := SimLedger.snapshot(world, w.budget)
	_step_budget(world)
	SimLedger.record(world, "sys:budget", snap)
	snap = SimLedger.snapshot(world, w.floods)
	var floods := _step_floods(world)
	SimLedger.record(world, "sys:floods", snap)
	snap = SimLedger.snapshot(world, w.recovery)
	_step_recovery_and_logistics(world)
	SimLedger.record(world, "sys:recovery", snap)
	snap = SimLedger.snapshot(world, w.food_prices)
	_step_food_and_prices(world)
	SimLedger.record(world, "sys:food_prices", snap)
	SimLedger.split(world, "price_level", "sys:food_prices", _pp_part, _pp_fracs, "drv:price_pressure|")
	snap = SimLedger.snapshot(world, w.welfare)
	_step_welfare(world)
	SimLedger.record(world, "sys:welfare", snap)
	snap = SimLedger.snapshot(world, w.sentiment)
	_step_sentiment_and_trust(world)
	SimLedger.record(world, "sys:sentiment", snap)

	world.tick += 1
	return {
		"tick": world.tick,
		"applied_effects": applied.size(),
		"floods": floods,
		"national": national_summary(world),
		"sentiment_delta": _delta_stats(sentiment_before, world.vars["sentiment"]),
	}


func _step_recovery_and_logistics(world: SimWorld) -> void:
	var dmg: PackedFloat64Array = world.vars["damage"]
	var infra: PackedFloat64Array = world.vars["infrastructure"]
	var serv: PackedFloat64Array = world.vars["services"]
	var logi: PackedFloat64Array = world.vars["logistics"]
	var base: float = c.recovery_base_rate * (1.0 + c.budget_recovery_weight * (sector_intensity(world, "kebencanaan") - 1.0))
	var capw: float = c.recovery_capacity_weight
	var dlp: float = c.damage_logistics_penalty
	for i in dmg.size():
		var capacity := (infra[i] + serv[i]) / 200.0          # 0..1
		var rate := base * ((1.0 - capw) + capw * 2.0 * capacity)  # avg capacity -> base rate
		dmg[i] = clampf(dmg[i] * (1.0 - rate), 0.0, 100.0)
		logi[i] = clampf(infra[i] * (1.0 - dlp * dmg[i] / 100.0), 0.0, 100.0)
	world.vars["damage"] = dmg
	world.vars["logistics"] = logi


## Calendar month 1..12 of the current tick.
func month_of(tick: int) -> int:
	return (start_month - 1 + tick) % 12 + 1


## Funding intensity of a sector relative to its baseline (1.0 = baseline funding).
## intensity = spending_level x share / base_share. Unit-free, so real rupiah can replace the
## neutral pool later without changing any equation.
func sector_intensity(world: SimWorld, sector: String) -> float:
	var sectors: Dictionary = budget_cfg.get("sectors", {})
	if not sectors.has(sector):
		return 1.0
	var base := float(sectors[sector].base_share)
	var shares: Dictionary = world.national.get("budget_shares", {})
	var share := float(shares.get(sector, base))
	# Running policy commitments are paid from the same envelope first (opportunity cost, D-039).
	var available := maxf(0.0, float(world.national.get("budget_level", 1.0)) - PolicyEngine.total_commitment(world))
	return available * share / base if base > 0.0 else 1.0


## Budget: spending level moves fiscal space; sector intensities above/below baseline move
## capacities. At baseline (level 1, base shares) nothing drifts (tested equilibrium).
func _step_budget(world: SimWorld) -> void:
	var level := float(world.national.get("budget_level", 1.0))
	var fs := float(world.national.get("fiscal_space", 50.0))
	if fs <= 0.0 and level > 1.0:
		level = 1.0  # no room left: overspending is not possible
		world.national["budget_level"] = level
	# Spending covers policy commitments even when they exceed the envelope (excess = deficit).
	var spending := maxf(level, PolicyEngine.total_commitment(world))
	world.national["fiscal_space"] = clampf(fs + c.budget_fiscal_rate * (1.0 - spending), 0.0, 100.0)
	SimLedger.national_change(world, "fiscal_space", float(world.national.fiscal_space) - fs, "sys:budget")
	var d_infra: float = c.budget_infra_rate * (sector_intensity(world, "infrastruktur") - 1.0)
	var d_serv: float = c.budget_services_rate * (sector_intensity(world, "layanan") - 1.0)
	var f_food: float = 1.0 + c.budget_food_rate * (sector_intensity(world, "pangan") - 1.0)
	var d_prot: float = c.budget_protection_rate * (sector_intensity(world, "kebencanaan") - 1.0)
	if d_infra == 0.0 and d_serv == 0.0 and f_food == 1.0 and d_prot == 0.0:
		return
	var infra: PackedFloat64Array = world.vars["infrastructure"]
	var serv: PackedFloat64Array = world.vars["services"]
	var food: PackedFloat64Array = world.vars["food_capacity"]
	var prot: PackedFloat64Array = world.vars["flood_protection"]
	var freq: PackedFloat64Array = world.vars["flood_frequency"]
	var fmean := 0.0
	for x in freq:
		fmean += x
	fmean = fmean / freq.size() if freq.size() > 0 else 0.0
	for i in infra.size():
		infra[i] = clampf(infra[i] + d_infra, 0.0, 100.0)
		serv[i] = clampf(serv[i] + d_serv, 0.0, 100.0)
		food[i] = clampf(food[i] * f_food, 0.0, 5.0)
		# Disaster-sector money goes where floods happen: weight lambda / (lambda + national mean) in (0, 1).
		if freq[i] > 0.0:
			prot[i] = clampf(prot[i] + d_prot * freq[i] / (freq[i] + fmean), 0.0, 100.0)
	world.vars["infrastructure"] = infra
	world.vars["services"] = serv
	world.vars["food_capacity"] = food
	world.vars["flood_protection"] = prot


## Recurring floods (v0.5, D-032). Per region per month:
##   k ~ Poisson(lambda_i * s_m)             lambda_i = flood_frequency (BNPB history), s_m = seasonal share
##   impact = sum_k Exp(mu) * scale_i * (1 - 0.75 * protection/100) * resilience(infrastructure)
##   scale_i = 0.5 + flood_risk_profile/100 (IRBI-derived; 1.0 if uncalibrated)
## Mitigation and resilience change future impacts only when floods occur (no permanent bonus).
## Returns the number of regions flooded this month (report only).
func _step_floods(world: SimWorld) -> int:
	var freq: PackedFloat64Array = world.vars["flood_frequency"]
	var prof: PackedFloat64Array = world.vars["flood_risk_profile"]
	var prot: PackedFloat64Array = world.vars["flood_protection"]
	var infra: PackedFloat64Array = world.vars["infrastructure"]
	var dmg: PackedFloat64Array = world.vars["damage"]
	var last: PackedFloat64Array = world.vars["flood_damage_last"]
	var nev: PackedFloat64Array = world.vars["flood_events_last"]
	var share := flood_season[month_of(world.tick) - 1] / season_total
	var smean: float = c.flood_severity_mean
	var scap: float = c.flood_severity_cap
	var mit: float = c.flood_mitigation_max
	var smin: float = c.flood_risk_scale_min
	var rslope: float = c.resilience_infra_slope
	var flooded := 0
	for i in freq.size():
		last[i] = 0.0
		nev[i] = 0.0
		var mean_k := freq[i] * share
		if mean_k <= 0.0:
			continue
		var k := _poisson(mean_k, SimRng.u01(world.rng_seed, world.tick, i, SimRng.Stream.FLOOD_OCCURS))
		if k == 0:
			continue
		var modifier := (smin + prof[i] / 100.0) * (1.0 - mit * prot[i] / 100.0) \
			* clampf(1.0 + rslope * 0.5 - rslope * infra[i] / 100.0, 1.0 - rslope * 0.5, 1.0 + rslope * 0.5)
		var raw := 0.0
		for j in k:
			raw += minf(scap, -smean * log(1.0 - SimRng.u01(world.rng_seed, world.tick, i, SimRng.Stream.FLOOD_SEVERITY + 16 * j)))
		var hit := minf(raw, scap) * modifier
		dmg[i] = clampf(dmg[i] + hit, 0.0, 100.0)
		last[i] = hit
		nev[i] = float(k)
		flooded += 1
	world.vars["damage"] = dmg
	world.vars["flood_damage_last"] = last
	world.vars["flood_events_last"] = nev
	return flooded


## Inverse-CDF Poisson draw from one uniform (k small in practice; capped for safety).
static func _poisson(mean: float, u: float) -> int:
	var p := exp(-mean)
	var cdf := p
	var k := 0
	while u > cdf and k < 200:
		k += 1
		p *= mean / k
		cdf += p
	return k


func _step_food_and_prices(world: SimWorld) -> void:
	var cap: PackedFloat64Array = world.vars["food_capacity"]
	var dmg: PackedFloat64Array = world.vars["damage"]
	var logi: PackedFloat64Array = world.vars["logistics"]
	var pop: PackedFloat64Array = world.vars["population"]
	var supply: PackedFloat64Array = world.vars["food_supply"]
	var price: PackedFloat64Array = world.vars["price_level"]
	var n := cap.size()
	var floor_share: float = c.logistics_food_floor
	var dfp: float = c.damage_food_penalty

	# Pass 1: local realized supply ratio, and the national pool (population-weighted).
	var local := PackedFloat64Array()
	local.resize(n)
	var pool_num := 0.0
	var pool_den := 0.0
	for i in n:
		# Logistics relative to the region's own infrastructure: 1.0 when undisrupted, so an
		# unshocked region realizes exactly its capacity (stable equilibrium).
		var infra_i: float = world.vars["infrastructure"][i]
		var rel := clampf(logi[i] / maxf(infra_i, 1.0), 0.0, 1.0)
		var l := cap[i] * (floor_share + (1.0 - floor_share) * rel) * (1.0 - dfp * dmg[i] / 100.0)
		local[i] = l
		var w := maxf(pop[i], 1.0)
		pool_num += l * w
		pool_den += w
	var national_ratio := pool_num / pool_den if pool_den > 0.0 else 1.0

	# Pass 2: inter-regional trade blends local supply toward the national pool, gated by logistics.
	var tmax: float = c.trade_share_max
	var el: float = c.price_elasticity
	var ps: float = c.price_smoothing
	# National commodity price pressure (e.g. an edible-oil shock) raises every region's price target;
	# it decays slowly unless policy reduces it (D-045). 0 by default -> no effect.
	var pp_raw := float(world.national.get("price_pressure", 0.0))
	var pp := clampf(pp_raw, 0.0, 1.0)
	world.national["price_pressure"] = pp * (1.0 - c.get("price_pressure_decay", 0.0))
	var track := SimLedger.active(world)
	_pp_part = PackedFloat64Array()
	_pp_fracs = {}
	if track:
		_pp_fracs = SimLedger.driver_fractions(world, "price_pressure", pp_raw)
		SimLedger.national_change(world, "price_pressure", float(world.national.price_pressure) - pp_raw, "sys:pp_decay")
		_pp_part.resize(n)
	SimLedger.driver_rescale(world, "price_pressure", pp_raw, float(world.national.price_pressure))
	for i in n:
		var t := tmax * logi[i] / 100.0
		var s := clampf(lerpf(local[i], national_ratio, t), 0.05, 5.0)
		supply[i] = s
		var base_target := 100.0 * pow(clampf(s, 0.05, 1.5), -el)
		var target := clampf(base_target * (1.0 + pp), 20.0, 400.0)
		var p_new := clampf(price[i] + (target - price[i]) * ps, 20.0, 400.0)
		if track:  # same step without national pressure; the difference is the pressure's share
			_pp_part[i] = p_new - clampf(price[i] + (clampf(base_target, 20.0, 400.0) - price[i]) * ps, 20.0, 400.0)
		price[i] = p_new
	world.vars["food_supply"] = supply
	world.vars["price_level"] = price
	world.national["food_supply_ratio"] = national_ratio


func _step_welfare(world: SimWorld) -> void:
	var wel: PackedFloat64Array = world.vars["welfare"]
	var price: PackedFloat64Array = world.vars["price_level"]
	var dmg: PackedFloat64Array = world.vars["damage"]
	var serv: PackedFloat64Array = world.vars["services"]
	var base: PackedFloat64Array = world.vars["welfare_base"]
	var sm: float = c.welfare_smoothing
	var wp: float = c.welfare_price_weight
	var wd: float = c.welfare_damage_weight
	var ws: float = c.welfare_services_weight
	for i in wel.size():
		var target := base[i] - wp * maxf(price[i] - 100.0, 0.0) - wd * dmg[i] + ws * (serv[i] - 50.0)
		target = clampf(target, 0.0, 100.0)
		wel[i] = clampf(wel[i] + (target - wel[i]) * sm, 0.0, 100.0)
	world.vars["welfare"] = wel


func _step_sentiment_and_trust(world: SimWorld) -> void:
	var sen: PackedFloat64Array = world.vars["sentiment"]
	var tru: PackedFloat64Array = world.vars["trust"]
	var ss: float = c.sentiment_smoothing
	var ts: float = c.trust_smoothing
	for i in sen.size():
		var target := sentiment_target(world, i)
		sen[i] = clampf(sen[i] + (target - sen[i]) * ss, 0.0, 100.0)
		tru[i] = clampf(tru[i] + (sen[i] - tru[i]) * ts, 0.0, 100.0)
	world.vars["sentiment"] = sen
	world.vars["trust"] = tru


func sentiment_target(world: SimWorld, i: int) -> float:
	var total: float = world.vars["sentiment_base"][i]
	for v in sentiment_components(world, i).values():
		total += v
	return clampf(total, 0.0, 100.0)


## Signed contributions (sentiment points) relative to the region's baseline. Drives the
## "why did sentiment change" explanation in the UI (docs/22).
func sentiment_components(world: SimWorld, i: int) -> Dictionary:
	var base: float = world.vars["sentiment_base"][i]
	return {
		"kesejahteraan": c.sentiment_w_welfare * (world.get_v("welfare", i) - world.get_v("welfare_base", i)),
		"harga": c.sentiment_w_price * (100.0 - world.get_v("price_level", i)),
		"kepercayaan": c.sentiment_w_trust * (world.get_v("trust", i) - base),
		"lingkungan": c.sentiment_w_environment * (world.get_v("environment", i) - 50.0),
		"kerusakan": -c.sentiment_w_damage * world.get_v("damage", i),
	}


func sentiment_state(score: float) -> Dictionary:
	for s in sentiment_states:
		if score >= float(s["min"]):
			return s
	return sentiment_states[-1]


## Monthly fiscal ledger in Fiscal Units (FU): 100 FU = one year of the baseline program envelope.
## When real APBN data is ingested, FU convert to rupiah via budget.json pool_rp (display only).
func fiscal_report(world: SimWorld) -> Dictionary:
	var level := float(world.national.get("budget_level", 1.0))
	var commit := PolicyEngine.total_commitment(world)
	var spending := maxf(level, commit)
	var revenue := 100.0 / 12.0  # baseline revenue covering the baseline envelope (index; UNCALIBRATED)
	var programs := maxf(0.0, level - commit) * 100.0 / 12.0
	var policies := commit * 100.0 / 12.0
	return {"unit": "FU/bulan", "revenue": revenue, "programs": programs, "policies": policies,
		"expenditure": spending * 100.0 / 12.0, "balance": revenue - spending * 100.0 / 12.0,
		"commitment_share": commit, "fiscal_space": float(world.national.get("fiscal_space", 0.0))}


func national_summary(world: SimWorld) -> Dictionary:
	return {
		"tick": world.tick,
		"welfare": world.national_mean("welfare"),
		"sentiment": world.national_mean("sentiment"),
		"price_level": world.national_mean("price_level"),
		"trust": world.national_mean("trust"),
		"environment": world.national_mean("environment"),
		"fiscal_space": float(world.national.get("fiscal_space", 0.0)),
		"budget_level": float(world.national.get("budget_level", 1.0)),
	}


static func _delta_stats(before: PackedFloat64Array, after: PackedFloat64Array) -> Dictionary:
	var mn := INF
	var mx := -INF
	var mn_i := -1
	var mx_i := -1
	for i in before.size():
		var d := after[i] - before[i]
		if d < mn:
			mn = d
			mn_i = i
		if d > mx:
			mx = d
			mx_i = i
	return {"min": mn, "min_index": mn_i, "max": mx, "max_index": mx_i}
