class_name Narrative
extends RefCounted
## Story layer over the authoritative simulation (docs/02_GDD.md, "Lapisan cerita").
## Pure static functions on SimWorld.story, so the whole narrative is deterministic, saveable and
## testable headless. The simulation never reads world.story; the story only *reads* simulation state,
## so a story line can never contradict the calculations it describes.
##
## world.story keys (all optional until ensure()):
##   flags {k: v}            narrative flags set by beats/options
##   seen {scene_key: tick}  scenes already played
##   pending [scene]         story scenes waiting to be shown (reaction, callback, unattended, quarter, ending)
##   snapshots {case: {...}} focus-region means at decision time (for "what changed since" lines)
##   callbacks [{case, id, due_tick, choice}]  scheduled callback scenes
##   promises {id: {...}}    long-term government promises and their status
##   journal [entry]         the player's story history (Buku Kisah)
##   met {character_id: tick}
##   history [{q, pillars}]  pillar values at every quarter end (ending + retrospective)
##   agenda {case: {opened_tick}} / expired [case] / quarter_taken: int   (Campaign)
##   outcomes {case: category} / taken_log [{q, case, critical}]   (Campaign agenda outcome categories)
##   prologue_done, tutorial {step, done}, agenda_mode, start {pillar: value}

const PILLARS := ["welfare", "trust", "services", "fiscal"]
const PILLAR_LABELS := {"welfare": "Kesejahteraan Warga", "trust": "Kepercayaan Publik",
	"services": "Pelayanan Publik", "fiscal": "Kesehatan Fiskal"}
const SNAPSHOT_VARS := ["welfare", "trust", "services", "damage", "infrastructure", "environment", "flood_protection", "fire_prevention", "welfare_base"]
const JOURNAL_CAP := 400


static func ensure(world: SimWorld) -> Dictionary:
	var s := world.story
	for k in ["flags", "seen", "snapshots", "promises", "met", "agenda", "outcomes"]:
		if not s.has(k):
			s[k] = {}
	for k in ["pending", "callbacks", "journal", "history", "expired", "taken_log"]:
		if not s.has(k):
			s[k] = []
	if not s.has("quarter_taken"):
		s["quarter_taken"] = -1
	if not s.has("tutorial"):
		s["tutorial"] = {"step": 0, "done": false}
	return s


## Called once by Game for a brand-new campaign (not for loads or headless test sessions).
static func begin_campaign(session: Session) -> void:
	var s := ensure(session.world)
	s["agenda_mode"] = true
	s["prologue_done"] = false
	s["start"] = start_values(session)


# ------------------------------------------------------------------ pillars (Tujuan Masa Bakti)

static func pillar_values(world: SimWorld) -> Dictionary:
	return {
		"welfare": world.national_mean("welfare"),
		"trust": world.national_mean("trust"),
		"services": world.national_mean("services"),
		"fiscal": float(world.national.get("fiscal_space", 0.0)),
	}


static func start_values(session: Session) -> Dictionary:
	var w := session.world
	var out := {"fiscal": session.initial_fiscal}
	for p in ["welfare", "trust", "services"]:
		if session.initial_vars.has(p):
			out[p] = w.weighted_mean_of(session.initial_vars[p])
		else:
			out[p] = w.national_mean(p)
	return out


## {pillar: {value, start, delta}} with a plain-language trend word.
static func pillars(session: Session) -> Dictionary:
	var s := ensure(session.world)
	if not s.has("start"):
		s["start"] = start_values(session)
	var now := pillar_values(session.world)
	var out := {}
	for p in PILLARS:
		var st := float(s.start.get(p, now[p]))
		var d := float(now[p]) - st
		out[p] = {"value": float(now[p]), "start": st, "delta": d, "trend": trend_word(p, d)}
	return out


static func trend_word(pillar: String, delta: float) -> String:
	var eps := 1.0 if pillar == "fiscal" else 0.4
	if delta > eps:
		return "membaik"
	if delta < -eps:
		return "menurun"
	return "stabil"


static func record_quarter(session: Session) -> void:
	var s := ensure(session.world)
	var row := {"q": session.world.quarter_index(), "tick": session.world.tick}
	var p := pillars(session)
	for k in PILLARS:
		row[k] = p[k].value
	s.history.append(row)


# ------------------------------------------------------------------ conditions

## Story conditions = simulation Conditions + story-only keys:
##   {"flag": k, "equals": v}                    narrative flag (omit equals => truthy)
##   {"choice": "a"} / {"choice": ["a", "b"]}     choice made in the case of the current context
##   {"delta": var, "op": ">", "value": 0}        change of a focus-region mean since the case decision
##   {"pillar": "trust", "op": "<", "value": 0}   change of a pillar since the start of the term
##   {"pillar_value": "fiscal", "op": "<", "value": 10}
##   {"promise": id, "status": "kept|broken|open"}
static func eval(world: SimWorld, cond: Variant, ctx: Dictionary = {}) -> bool:
	if cond == null or (cond is Dictionary and (cond as Dictionary).is_empty()):
		return true
	var c: Dictionary = cond
	if c.has("all"):
		for sub in c.all:
			if not eval(world, sub, ctx):
				return false
		return true
	if c.has("any"):
		for sub in c.any:
			if eval(world, sub, ctx):
				return true
		return false
	if c.has("not"):
		return not eval(world, c["not"], ctx)
	var s := ensure(world)
	if c.has("flag"):
		if c.has("equals"):
			return s.flags.get(c.flag) == c.equals
		return bool(s.flags.get(c.flag, false))
	if c.has("choice"):
		var made := str(world.case_state.get(str(ctx.get("case", "")), {}).get("choice_id", ""))
		var want: Array = c.choice if c.choice is Array else [c.choice]
		return made in want.map(func(x): return str(x))
	if c.has("delta"):
		var case_id := str(c.get("case", ctx.get("case", "")))
		var snap: Dictionary = s.snapshots.get(case_id, {})
		if snap.is_empty() or not snap.has(str(c.delta)):
			return false
		var now := focus_means(world, ContentDB_cases_get(ctx, case_id))
		return Conditions.cmp(float(now.get(str(c.delta), 0.0)) - float(snap[str(c.delta)]), str(c.op), float(c.value))
	if c.has("pillar") or c.has("pillar_value"):
		var key := str(c.get("pillar", c.get("pillar_value", "")))
		var now_v := float(pillar_values(world).get(key, 0.0))
		var start_v := float(s.get("start", {}).get(key, now_v))
		var x := now_v - start_v if c.has("pillar") else now_v
		return Conditions.cmp(x, str(c.op), float(c.value))
	if c.has("pillar_q"):
		# change of a pillar over the last recorded quarter (history rows are written at quarter end)
		var hist: Array = s.history
		if hist.is_empty():
			return false
		var key_q := str(c.pillar_q)
		var last := float(hist[-1].get(key_q, 0.0))
		var prev := float(hist[-2].get(key_q, last)) if hist.size() > 1 else float(s.get("start", {}).get(key_q, last))
		return Conditions.cmp(last - prev, str(c.op), float(c.value))
	if c.has("agenda_open"):
		return Conditions.cmp(float((s.agenda as Dictionary).size()), str(c.agenda_open), float(c.get("value", 0)))
	if c.has("promise"):
		return str(s.promises.get(str(c.promise), {}).get("status", "")) == str(c.status)
	if c.has("promises_due"):
		var n := 0
		for pid in s.promises:
			if str(s.promises[pid].status) != "open" and int(s.promises[pid].get("settled_tick", -1)) == world.tick:
				n += 1
		return Conditions.cmp(float(n), str(c.promises_due), float(c.get("value", 0)))
	return Conditions.eval(world, c)


## The case record travels in ctx so this file has no autoload dependency (tests pass records directly).
static func ContentDB_cases_get(ctx: Dictionary, case_id: String) -> Dictionary:
	var rec: Dictionary = ctx.get("case_record", {})
	if not rec.is_empty() and str(rec.get("case_id", "")) == case_id:
		return rec
	var lib: Dictionary = ctx.get("cases", {})
	return lib.get(case_id, {})


## Means of SNAPSHOT_VARS over the case's focus regions (all regions for national cases).
static func focus_means(world: SimWorld, case_record: Dictionary) -> Dictionary:
	var ids: Array = case_record.get("focus_regions", [])
	var idx: Array = []
	for id in ids:
		if world.region_index.has(id):
			idx.append(world.region_index[id])
	var out := {}
	for v in SNAPSHOT_VARS:
		if not world.vars.has(v):
			continue
		if idx.is_empty():
			out[v] = world.national_mean(v)
			continue
		var arr: PackedFloat64Array = world.vars[v]
		var acc := 0.0
		for i in idx:
			acc += arr[i]
		out[v] = acc / idx.size()
	out["fiscal"] = float(world.national.get("fiscal_space", 0.0))
	return out


# ------------------------------------------------------------------ beats

## Filters beats by their "if" condition, expands "pick" groups (first matching variant) and fills
## tokens. A beat: {"s": speaker, "e": expression, "t": text, "bg": background, "if": cond,
## "set": {flag: value}, "options": [{"t", "set", "reply": [beats]}]}.
static func resolve(world: SimWorld, beats: Array, ctx: Dictionary = {}) -> Array:
	var out: Array = []
	for b in beats:
		if not (b is Dictionary):
			continue
		if b.has("pick"):
			for variant in b.pick:
				if eval(world, variant.get("if", {}), ctx):
					out.append_array(resolve(world, variant.get("beats", []), ctx))
					break
			continue
		if not eval(world, b.get("if", {}), ctx):
			continue
		var beat: Dictionary = b.duplicate(true)
		beat["t"] = fill(str(b.get("t", "")), world, ctx)
		out.append(beat)
	return out


static func fill(text: String, world: SimWorld, ctx: Dictionary) -> String:
	if not text.contains("{"):
		return text
	var q := world.quarter_index()
	var tokens := {
		"{tahun}": str(world.year_index() + 1),
		"{kuartal}": str(q % SimWorld.QUARTERS_PER_YEAR + 1),
		"{kuartal_ke}": str(q + 1),
		"{sisa_kuartal}": str(maxi(0, SimWorld.TERM_TICKS / SimWorld.TICKS_PER_QUARTER - q)),
		"{lokasi}": str(ctx.get("case_record", {}).get("location_label", "")),
	}
	for k in tokens:
		text = text.replace(k, tokens[k])
	return text


static func apply_sets(world: SimWorld, beat: Dictionary) -> void:
	var s := ensure(world)
	for k in beat.get("set", {}):
		s.flags[str(k)] = beat.set[k]
	var who := str(beat.get("s", ""))
	if who != "" and who != "narasi" and not s.met.has(who):
		s.met[who] = world.tick


# ------------------------------------------------------------------ decisions, callbacks, promises

## After Session.decide(): remember the state, journal the decision, open a promise, queue the
## choice-specific reaction scene and schedule the case's callbacks for this choice.
static func on_decided(world: SimWorld, case_record: Dictionary, choice_id: String) -> void:
	var s := ensure(world)
	var id := str(case_record.get("case_id", ""))
	var story: Dictionary = case_record.get("story", {})
	s.snapshots[id] = focus_means(world, case_record)
	var label := id
	for ch in case_record.get("choices", []):
		if ch.choice_id == choice_id:
			label = str(ch.get("label", choice_id))
	journal(world, "keputusan", str(case_record.get("title", id)),
		str(story.get("journal", {}).get(choice_id, "Pemerintah memilih: %s." % label)), id)
	var promise: Dictionary = story.get("promises", {}).get(choice_id, {})
	if not promise.is_empty():
		var pid := "%s/%s" % [id, choice_id]
		s.promises[pid] = {"case": id, "text": str(promise.text), "made_tick": world.tick,
			"due_tick": world.tick + int(promise.get("due_quarters", 4)) * SimWorld.TICKS_PER_QUARTER,
			"check": promise.get("check", {}), "status": "open"}
	if story.get("reactions", {}).has(choice_id):
		queue(world, {"kind": "reaction", "case": id, "choice": choice_id})
	for cb in story.get("callbacks", []):
		var only: Array = cb.get("choices", [])
		if not only.is_empty() and choice_id not in only:
			continue
		s.callbacks.append({"case": id, "id": str(cb.id), "choice": choice_id,
			"due_tick": world.tick + int(cb.get("after_quarters", 2)) * SimWorld.TICKS_PER_QUARTER})


## Moves callbacks whose time has come into the pending scene queue (deterministic order).
static func collect_due(world: SimWorld) -> void:
	var s := ensure(world)
	var keep: Array = []
	for cb in s.callbacks:
		if int(cb.due_tick) <= world.tick:
			queue(world, {"kind": "callback", "case": cb.case, "id": cb.id, "choice": cb.choice})
		else:
			keep.append(cb)
	s["callbacks"] = keep


## Settles promises that are due: kept if their check holds against the actual state.
static func settle_promises(world: SimWorld, cases: Dictionary) -> Array:
	var s := ensure(world)
	var settled: Array = []
	var keys: Array = s.promises.keys()
	keys.sort()
	for pid in keys:
		var p: Dictionary = s.promises[pid]
		if p.status != "open" or int(p.due_tick) > world.tick:
			continue
		var ok := eval(world, p.get("check", {}), {"case": p.case, "cases": cases})
		p["status"] = "kept" if ok else "broken"
		p["settled_tick"] = world.tick
		settled.append(pid)
		journal(world, "janji", "Janji %s" % ("terpenuhi" if ok else "belum terpenuhi"), str(p.text), str(p.case))
	return settled


static func queue(world: SimWorld, scene: Dictionary) -> void:
	ensure(world).pending.append(scene)


static func pop_pending(world: SimWorld) -> Dictionary:
	var s := ensure(world)
	if s.pending.is_empty():
		return {}
	var scene: Dictionary = s.pending[0]
	s.pending.remove_at(0)
	return scene


static func mark_seen(world: SimWorld, key: String) -> void:
	ensure(world).seen[key] = world.tick


static func journal(world: SimWorld, kind: String, title: String, text: String, case_id: String = "") -> void:
	var s := ensure(world)
	s.journal.append({"tick": world.tick, "kind": kind, "title": title, "text": text, "case": case_id})
	if s.journal.size() > JOURNAL_CAP:
		s.journal = s.journal.slice(s.journal.size() - JOURNAL_CAP)


## Beats for a pending scene, already resolved against the current state.
static func scene_beats(world: SimWorld, scene: Dictionary, cases: Dictionary) -> Array:
	var rec: Dictionary = cases.get(str(scene.get("case", "")), {})
	var story: Dictionary = rec.get("story", {})
	var ctx := {"case": str(scene.get("case", "")), "case_record": rec, "cases": cases}
	match str(scene.get("kind", "")):
		"opening":
			return resolve(world, story.get("opening", []), ctx)
		"reaction":
			return resolve(world, story.get("reactions", {}).get(str(scene.choice), []), ctx)
		"unattended":
			return resolve(world, story.get("unattended", []), ctx)
		"callback":
			for cb in story.get("callbacks", []):
				if str(cb.id) == str(scene.id):
					return resolve(world, cb.get("beats", []), ctx)
	return []
