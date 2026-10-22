extends RefCounted

var t
const DIR := "user://test_saves"


func _fresh() -> Array:
	var params: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sim_params.json"))
	var regions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))["regions"]
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/baseline.json"))
	var sim := Simulation.new(params, JSON.parse_string(FileAccess.get_file_as_string("res://data/budget.json")))
	return [sim, WorldFactory.build(regions, baseline, sim, 7), regions, baseline]


func _clean() -> void:
	var d := DirAccess.open(DIR)
	if d:
		for f in d.get_files():
			DirAccess.remove_absolute(DIR.path_join(f))


func test_roundtrip_restores_identical_future() -> void:
	_clean()
	var p := _fresh()
	var sim: Simulation = p[0]
	var w: SimWorld = p[1]
	EffectQueue.schedule(w, [{"scope": "province:72", "var": "damage", "op": "add", "value": 40.0, "delay": 4, "duration": 2}], "test")
	w.memory["test_flag"] = true
	for _i in 3:
		sim.step_month(w)
	var svc := SaveService.new(DIR)
	t.check(svc.save("slot a", "Uji", w.to_dict(), {"tick": w.tick}) == "", "save ok")
	# Continue original 12 months.
	for _i in 12:
		sim.step_month(w)
	# Load into a fresh world and continue the same 12 months.
	var q := _fresh()
	var w2: SimWorld = q[1]
	var r := svc.load_slot("slot a")
	t.check(r.ok, "load ok: %s" % r.get("error", ""))
	t.check(w2.load_dict(r.payload) == "", "load_dict ok")
	t.check(w2.memory.get("test_flag", false), "memory restored")
	t.check(w2.pending_effects.size() == 1, "pending delayed effect restored")
	for _i in 12:
		sim.step_month(w2)
	t.check(w.tick == w2.tick, "tick equal")
	t.check(w.vars["sentiment"] == w2.vars["sentiment"], "bit-identical sentiment after reload")
	t.check(w.vars["damage"] == w2.vars["damage"], "bit-identical damage after reload")


func test_corrupt_save_is_rejected_and_backup_recovers() -> void:
	_clean()
	var p := _fresh()
	var w: SimWorld = p[1]
	var svc := SaveService.new(DIR)
	svc.save("s", "v1", w.to_dict())
	w.tick = 5
	svc.save("s", "v2", w.to_dict())  # v1 becomes .bak
	var f := FileAccess.open(svc.path_for("s"), FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	var r := svc.load_slot("s")
	t.check(not r.ok, "corrupt file must be rejected")
	var rec := svc.load_with_recovery("s")
	t.check(rec.ok and rec.get("recovered_from_backup", false), "backup recovery works")
	t.check(int(rec.payload.tick) == 0, "backup holds previous version")


func test_tampered_payload_fails_checksum() -> void:
	_clean()
	var p := _fresh()
	var svc := SaveService.new(DIR)
	svc.save("x", "x", p[1].to_dict())
	var orig := FileAccess.get_file_as_string(svc.path_for("x"))
	var txt := orig.replace("\\\"tick\\\":0", "\\\"tick\\\":9")
	t.check(txt != orig, "tamper pattern must match")
	var f := FileAccess.open(svc.path_for("x"), FileAccess.WRITE)
	f.store_string(txt)
	f.close()
	var r := svc.load_slot("x")
	t.check(not r.ok, "tampered payload must fail checksum")


func test_many_slots_and_listing() -> void:
	_clean()
	var p := _fresh()
	var svc := SaveService.new(DIR)
	for i in 25:
		svc.save("manual_%d" % i, "Manual %d" % i, p[1].to_dict())
	svc.save(SaveService.QUICKSAVE_ID, "Simpan Cepat", p[1].to_dict())
	for i in 5:
		svc.autosave(p[1].to_dict(), {}, i)
	var slots := svc.list_slots()
	t.check(slots.size() == 25 + 1 + SaveService.AUTOSAVE_ROTATION, "slot count %d" % slots.size())


func test_mismatched_region_set_rejected() -> void:
	var p := _fresh()
	var d: Dictionary = p[1].to_dict()
	d.region_ids = d.region_ids.slice(0, 10)
	var q := _fresh()
	t.check(q[1].load_dict(d) != "", "save from different region snapshot must be rejected")


## Regression (2026-10-05): Godot JSON lost precision for ~9% of doubles, so reloaded saves
## diverged once floods produced arbitrary values. Saves must restore floats bit-exactly.
func test_codec_is_bit_exact_for_arbitrary_doubles() -> void:
	var arr := PackedFloat64Array()
	for k in 5000:
		arr.append(SimRng.u01(3, k, 7, 1) * 100.0)
	var payload := {"a": arr, "x": 95.91274172998964787, "n": 3, "nested": [{"y": 1.0 / 3.0, "s": "teks"}]}
	var text := JSON.stringify(SaveCodec.encode(payload))
	var back: Dictionary = SaveCodec.decode(JSON.parse_string(text))
	t.check(back.a == arr, "float64 array bit-exact through JSON")
	t.check(back.x == payload.x, "scalar float bit-exact")
	t.check(typeof(back.n) == TYPE_INT and back.n == 3, "ints stay ints")
	t.check(back.nested[0].y == 1.0 / 3.0 and back.nested[0].s == "teks", "nested values preserved")


func test_v1_save_is_migrated() -> void:
	var p := _fresh()
	var w: SimWorld = p[1]
	var v1 := {"schema": 1, "region_ids": Array(w.region_ids), "tick": 4, "rng_seed": 7, "rng_state": "0",
		"national": {"fiscal_space": 47.5, "budget_level": 1.0}, "vars": {}, "pending_effects": [],
		"memory": {"x": true}, "case_state": {"CASE-0001": {"status": "resolved", "count": 1.0}}}
	for k in w.vars:
		v1.vars[k] = Array(w.vars[k])
	var q := _fresh()
	t.check(q[1].load_dict(JSON.parse_string(JSON.stringify(v1))) == "", "v1 save loads via migration")
	t.check(q[1].tick == 4 and float(q[1].national.fiscal_space) == 47.5, "values preserved")
	t.check(typeof(q[1].case_state["CASE-0001"]["count"]) == TYPE_INT, "whole numbers restored as int")
