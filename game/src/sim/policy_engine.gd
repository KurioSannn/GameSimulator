class_name PolicyEngine
extends RefCounted
## Data-driven policy system (game/data/policies/*.json, schema data/schemas/policy.schema.json).
## One generic engine; no per-policy scripts. Lifecycle (monthly ticks):
##
##   enact (month t) -> upfront cost now; running commitment starts (crowds out sector budgets)
##     -> IMPLEMENTING for implementation_months (implementation-phase effects, e.g. construction)
##     -> ACTIVE for duration_months (active-phase effects, e.g. capacity build-up)
##     -> ENDED (commitment released); re-enactable after cooldown_months
##
## Effects are scheduled through EffectQueue at enactment with explicit region lists, so they are
## saved/loaded exactly and every region still runs through the normal monthly simulation.
## Implementation uncertainty: one deterministic multiplier per enactment (counter RNG).

const IMPLEMENTING := "implementing"
const ACTIVE := "active"
const ENDED := "ended"
const NOT_ENACTED := "not_enacted"
const RNG_STREAM := 101

var policies: Dictionary            # policy_id -> record
var island_of: Dictionary = {}      # region_id -> island group (navigation grouping)


func _init(policy_records: Dictionary, regions: Array = []) -> void:
	policies = policy_records
	for r in regions:
		island_of[str(r.region_id)] = str(r.get("island_group", ""))


static func status_of(world: SimWorld, policy_id: String) -> String:
	var st: Dictionary = world.policy_state.get(policy_id, {})
	if st.is_empty():
		return NOT_ENACTED
	if world.tick < int(st.impl_end_tick):
		return IMPLEMENTING
	if world.tick < int(st.end_tick):
		return ACTIVE
	return ENDED


## National share of the baseline program envelope committed to running policies.
static func total_commitment(world: SimWorld) -> float:
	var total := 0.0
	for id in world.policy_state:
		var st: Dictionary = world.policy_state[id]
		if world.tick < int(st.commit_end_tick):
			total += float(st.commitment)
	return total


## Resolves a target to explicit region indices. target = {"type": national|island_group|province|kabkota|selected, ...}
func resolve_target(world: SimWorld, policy: Dictionary, target: Dictionary) -> PackedInt32Array:
	var out := PackedInt32Array()
	var t := str(target.get("type", "national"))
	if not (t in policy.get("target_scope", [])):
		return out
	var scope := ""
	match t:
		"national": scope = "all"
		"province": scope = "province:" + str(target.get("id", ""))
		"kabkota": scope = "region:" + str(target.get("id", ""))
		"selected": scope = "regions:" + ",".join(PackedStringArray(target.get("ids", [])))
		"island_group":
			for i in world.region_count():
				if island_of.get(world.region_ids[i], "") == str(target.get("id", "")):
					out.append(i)
			return _filter(world, policy, out)
	return _filter(world, policy, EffectQueue.resolve_scope(world, scope))


## Regional eligibility: policy.target_filter is a "<var><op><value>" expression (optional).
func _filter(world: SimWorld, policy: Dictionary, idx: PackedInt32Array) -> PackedInt32Array:
	var f := str(policy.get("target_filter", ""))
	if f == "":
		return idx
	var ok := {}
	for i in EffectQueue.resolve_where(world, f):
		ok[i] = true
	var out := PackedInt32Array()
	for i in idx:
		if ok.has(i):
			out.append(i)
	return out


## Returns "" if the policy can be enacted on this target now, else a Bahasa reason.
func can_enact(world: SimWorld, policy_id: String, target: Dictionary) -> String:
	if not policies.has(policy_id):
		return "Kebijakan tidak dikenal."
	var p: Dictionary = policies[policy_id]
	var st := status_of(world, policy_id)
	if st == IMPLEMENTING or st == ACTIVE:
		return "Kebijakan ini sedang berjalan."
	if st == ENDED and world.tick < int(world.policy_state[policy_id].end_tick) + int(p.get("cooldown_months", 0)):
		return "Kebijakan masih dalam masa jeda (cooldown)."
	for other in p.get("mutually_exclusive", []):
		if status_of(world, str(other)) in [IMPLEMENTING, ACTIVE]:
			return "Tidak dapat berjalan bersamaan dengan kebijakan %s." % policies.get(other, {}).get("name", other)
	if not Conditions.eval(world, p.get("prerequisites", {})):
		return "Prasyarat kebijakan belum terpenuhi."
	if resolve_target(world, p, target).is_empty():
		return "Sasaran kebijakan tidak valid atau tidak ada wilayah yang memenuhi syarat."
	var upfront := float(p.get("cost", {}).get("upfront_fiscal", 0.0))
	if upfront > float(world.national.get("fiscal_space", 0.0)):
		return "Ruang fiskal tidak cukup untuk biaya awal."
	return ""


## Enacts the policy. Returns "" or the reason it cannot be enacted.
func enact(world: SimWorld, policy_id: String, target: Dictionary) -> String:
	var err := can_enact(world, policy_id, target)
	if err != "":
		return err
	var p: Dictionary = policies[policy_id]
	var idx := resolve_target(world, p, target)
	var ids := PackedStringArray()
	for i in idx:
		ids.append(world.region_ids[i])
	var scope := "regions:" + ",".join(ids)
	var u := float(p.get("uncertainty", {}).get("magnitude", 0.0))
	var mult := 1.0 + u * (2.0 * SimRng.u01(world.rng_seed, world.tick, policy_id.hash() & 0x7FFFFFFF, RNG_STREAM) - 1.0)
	var impl := int(p.get("implementation_months", 0))
	var dur := int(p.get("duration_months", 0))
	var cost: Dictionary = p.get("cost", {})
	var source := "policy:%s" % policy_id
	world.national["fiscal_space"] = float(world.national.get("fiscal_space", 0.0)) - float(cost.get("upfront_fiscal", 0.0))
	var specs: Array = []
	for e in p.get("effects", []):
		var s: Dictionary = e.duplicate(true)
		var phase := str(s.get("phase", "active"))
		var base_delay := 0 if phase != "active" else impl
		s.delay = base_delay + int(s.get("delay", 0))
		if str(s.scope) == "target":
			s.scope = scope
		var v := float(s.value)
		s.value = v * mult if str(s.get("op", "add")) == "add" else 1.0 + (v - 1.0) * mult
		specs.append(s)
	EffectQueue.schedule(world, specs, source)
	var prev: Dictionary = world.policy_state.get(policy_id, {})
	world.policy_state[policy_id] = {
		"enacted_tick": world.tick, "target": target.duplicate(true), "regions": ids.size(),
		"impl_end_tick": world.tick + impl, "end_tick": world.tick + impl + dur,
		"commitment": float(cost.get("monthly_commitment", 0.0)),
		"commit_end_tick": world.tick + int(cost.get("commitment_months", impl + dur)),
		"multiplier": mult, "count": int(prev.get("count", 0)) + 1,
	}
	for k in p.get("memory", {}):
		world.memory[k] = p.memory[k]
	return ""


func active_policies(world: SimWorld) -> Array:
	var out: Array = []
	for id in world.policy_state:
		if status_of(world, id) in [IMPLEMENTING, ACTIVE]:
			out.append(id)
	out.sort()
	return out
