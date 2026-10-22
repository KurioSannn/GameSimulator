extends RefCounted
## Content validation: every case references real regions/variables and labels facts.

var t

const VALID_FACT := ["REAL_OFFICIAL", "REAL_ACADEMIC", "REAL_NEWS", "REAL_SECONDARY", "DERIVED", "SIMULATED", "FICTIONAL"]


func test_cases_reference_valid_regions_vars_and_labels() -> void:
	var params: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/sim_params.json"))
	var regions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))["regions"]
	var provinces: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))["provinces"]
	var rids := {}
	for r in regions:
		rids[r.region_id] = true
	var pids := {}
	for p in provinces:
		pids[p.region_id] = true
	var d := DirAccess.open("res://data/cases")
	t.check(d != null, "cases dir exists")
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var c: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cases/" + f))
		t.check(c.has("research_ref"), "%s: research_ref required" % f)
		var secondary: bool = c.get("class", "") == "secondary_consequence"
		if secondary:
			# Simulated follow-ups must never carry "real" lines and must be labeled SIMULATED.
			t.check(c.real_context.fact_class == "NONE" and c.real_context.lines.is_empty(), "%s: secondary case must not claim real facts" % f)
			t.check(c.get("simulated_context", {}).get("fact_class", "") == "SIMULATED", "%s: simulated_context required" % f)
			t.check(FileAccess.file_exists("res://data/cases/%s.json" % c.get("origin_case", "?")), "%s: origin_case exists" % f)
		else:
			t.check(str(c.get("real_context", {}).get("fact_class", "")) in VALID_FACT, "%s: real_context.fact_class" % f)
		for fu in c.get("follow_ups", []):
			t.check(FileAccess.file_exists("res://data/cases/%s.json" % fu), "%s: follow_up %s exists" % [f, fu])
		for line in c.get("real_context", {}).get("lines", []):
			t.check(not line.get("source_refs", []).is_empty(), "%s: every real line needs source_refs" % f)
		t.check(c.choices.size() >= 2, "%s: at least 2 choices" % f)
		var all_effects: Array = c.get("on_trigger_effects", []).duplicate()
		for ch in c.choices:
			t.check(str(ch.get("fact_class", "")) == "SIMULATED", "%s/%s: choices must be SIMULATED" % [f, ch.choice_id])
			all_effects.append_array(ch.get("effects", []))
		for r in c.get("focus_regions", []):
			t.check(rids.has(r), "%s: unknown focus region %s" % [f, r])
		for e in all_effects:
			var scope := str(e.scope)
			if scope != "national":
				t.check(params.variables.has(e["var"]), "%s: unknown var %s" % [f, e["var"]])
			if scope.begins_with("province:"):
				t.check(pids.has(scope.substr(9)), "%s: unknown province %s" % [f, scope])
			elif scope.begins_with("region:"):
				t.check(rids.has(scope.substr(7)), "%s: unknown region %s" % [f, scope])
			elif scope.begins_with("regions:"):
				for id in scope.substr(8).split(","):
					t.check(rids.has(id), "%s: unknown region %s" % [f, id])


func test_baseline_status_vocabulary() -> void:
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/baseline.json"))
	for v in b.variables:
		var s := str(b.variables[v].status)
		t.check(s in ["REAL_OFFICIAL", "DERIVED", "BY_DESIGN", "UNCALIBRATED"], "baseline %s status %s" % [v, s])
		if s == "BY_DESIGN":
			t.check(str(b.variables[v].provenance.get("reason", "")) != "", "baseline %s: BY_DESIGN needs a documented reason" % v)
		if s != "UNCALIBRATED":
			t.check(b.variables[v].provenance != null, "baseline %s needs provenance" % v)
