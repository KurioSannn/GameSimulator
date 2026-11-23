extends RefCounted
## Story layer: content completeness, deterministic agenda (no silent skips), choice-specific
## reactions, callbacks that read real state, save/load of story state, campaign to an ending.

var t


func _init() -> void:
	if ContentDB.cases.is_empty() or ContentDB.story.is_empty():
		ContentDB.load_all()


func _cases() -> Dictionary:
	return ContentDB.cases


func _session(cases: Dictionary = {}, campaign := true) -> Session:
	var s := Session.new(ContentDB.sim_params, ContentDB.regions, ContentDB.baseline,
		cases if not cases.is_empty() else ContentDB.cases, 20261115, ContentDB.budget, ContentDB.policies)
	if campaign:
		Narrative.begin_campaign(s)
	return s


func _speakers(beats: Array, out: Array) -> void:
	for b in beats:
		if b.has("pick"):
			for v in b.pick:
				_speakers(v.get("beats", []), out)
			continue
		out.append(b)
		for o in b.get("options", []):
			_speakers(o.get("reply", []), out)


func test_every_case_has_a_complete_episode() -> void:
	var cast: Dictionary = ContentDB.story.cast.characters
	for id in _cases():
		var c: Dictionary = _cases()[id]
		var st: Dictionary = c.get("story", {})
		t.check(not st.is_empty(), "%s: narrative episode present" % id)
		if st.is_empty():
			continue
		t.check(st.get("opening", []).size() >= 3, "%s: opening scene (>= 3 beats)" % id)
		t.check(StoryBackdrop.KINDS.has(str(st.get("background", ""))), "%s: known background" % id)
		var texts := {}
		for ch in c.choices:
			var r: Array = st.get("reactions", {}).get(ch.choice_id, [])
			t.check(r.size() >= 2, "%s/%s: reaction scene" % [id, ch.choice_id])
			texts[JSON.stringify(r)] = true
			t.check(str(st.get("journal", {}).get(ch.choice_id, "")) != "", "%s/%s: journal line" % [id, ch.choice_id])
			if str(c.get("class", "")) == "major_historical":
				var info: Dictionary = st.get("choices", {}).get(ch.choice_id, {})
				for k in ["intent", "helps", "burden", "now", "later"]:
					t.check(str(info.get(k, "")) != "", "%s/%s: choice %s" % [id, ch.choice_id, k])
		t.check(texts.size() == c.choices.size(), "%s: every choice has its own reaction" % id)
		var beats: Array = []
		_speakers(st.get("opening", []), beats)
		for k in st.get("reactions", {}):
			_speakers(st.reactions[k], beats)
		for cb in st.get("callbacks", []):
			_speakers(cb.get("beats", []), beats)
		_speakers(st.get("unattended", []), beats)
		for b in beats:
			var who := str(b.get("s", ""))
			t.check(cast.has(who) or st.get("locals", {}).has(who), "%s: speaker '%s' defined" % [id, who])
			if b.has("bg"):
				t.check(StoryBackdrop.KINDS.has(str(b.bg)), "%s: background '%s' known" % [id, str(b.bg)])


func test_every_speaker_has_drawn_art_and_every_scene_a_painted_backdrop() -> void:
	# Release rule: no generated medallion placeholders and no procedural-only scenes in story mode.
	for id in _cases():
		var c: Dictionary = _cases()[id]
		var st: Dictionary = c.get("story", {})
		var beats: Array = []
		_speakers(st.get("opening", []), beats)
		for k in st.get("reactions", {}):
			_speakers(st.reactions[k], beats)
		for cb in st.get("callbacks", []):
			_speakers(cb.get("beats", []), beats)
		_speakers(st.get("unattended", []), beats)
		var seen := {}
		for b in beats:
			var who := str(b.get("s", ""))
			if who == "narasi" or seen.has(who):
				continue
			seen[who] = true
			var ch := ContentDB.character(who, c)
			var path := str(ch.get("portrait", ""))
			t.check(path != "" and ResourceLoader.exists(path), "%s: '%s' has a portrait" % [id, who])
		for bg in [str(st.get("background", ""))] + beats.map(func(x): return str(x.get("bg", ""))):
			if bg != "" and bg != "peta":
				t.check(StoryBackdrop.art_for(bg) != null, "%s: backdrop '%s' is painted" % [id, bg])


func test_story_scripts_reference_defined_speakers() -> void:
	var cast: Dictionary = ContentDB.story.cast.characters
	var beats: Array = []
	_speakers(ContentDB.story.prologue.beats, beats)
	_speakers(ContentDB.story.quarters.transition, beats)
	for a in ContentDB.story.endings.archetypes.values():
		_speakers(a.beats, beats)
	_speakers(ContentDB.story.endings.closing, beats)
	for b in beats:
		t.check(cast.has(str(b.get("s", ""))), "speaker '%s' in cast" % str(b.get("s", "")))
		if b.has("bg"):
			t.check(StoryBackdrop.KINDS.has(str(b.bg)), "background '%s' known" % str(b.bg))


func test_agenda_opens_visibly_and_gates_the_quarter() -> void:
	var s := _session()
	t.check(s.present_next_case() == "", "campaign never silently picks a case")
	var items := Campaign.items(s)
	t.check(items.size() >= 1 and items[0].case_id == "CASE-0001", "first agenda item is the opening chapter")
	t.check(not Campaign.can_advance(s), "cannot advance before taking an agenda item")
	t.check(s.advance_quarter().is_empty(), "advance blocked")
	t.check(Campaign.take(s, "CASE-0001") == "", "take ok")
	t.check(s.pending_case() == "CASE-0001", "decision open after taking")
	var opening := Narrative.pop_pending(s.world)
	t.check(opening.get("kind", "") == "opening", "opening scene queued before the decision")
	t.check(Campaign.take(s, "CASE-0001") != "", "cannot take twice")


func test_reactions_are_choice_specific_and_callbacks_read_state() -> void:
	var ends := {}
	for choice in ["a", "b", "c"]:
		var s := _session()
		s.present_next_case()
		Campaign.take(s, "CASE-0001")
		Narrative.pop_pending(s.world)
		t.check(s.decide("CASE-0001", choice) == "", "decide %s" % choice)
		var scene := Narrative.pop_pending(s.world)
		t.check(scene.kind == "reaction" and scene.choice == choice, "reaction for %s queued" % choice)
		var beats := Narrative.scene_beats(s.world, scene, ContentDB.cases)
		ends[JSON.stringify(beats)] = true
		for _q in 3:
			s.advance_quarter()
			if s.pending_case() != "":
				break
			var it := Campaign.items(s)
			if not it.is_empty():
				Campaign.take(s, it[0].case_id)
				if s.pending_case() != "":
					s.decide(s.pending_case(), "a")
		var callbacks: Array = []
		while true:
			var sc := Narrative.pop_pending(s.world)
			if sc.is_empty():
				break
			if sc.kind == "callback" and sc.case == "CASE-0001":
				callbacks.append(Narrative.scene_beats(s.world, sc, ContentDB.cases))
		t.check(not callbacks.is_empty(), "choice %s: a later scene remembers the decision" % choice)
	t.check(ends.size() == 3, "three distinct reactions")


func test_unattended_items_expire_with_explicit_consequences() -> void:
	var s := _session()
	s.present_next_case()
	Campaign.take(s, "CASE-0001")
	s.decide("CASE-0001", "a")
	var seen_expired := false
	for _q in 20:
		if s.world.is_term_over():
			break
		if not Campaign.can_advance(s):
			var it := Campaign.items(s)
			if it.is_empty():
				break
			# always take the LAST item so earlier ones age out
			Campaign.take(s, it[-1].case_id)
			s.decide(s.pending_case(), "a")
		s.advance_quarter()
		if not (s.world.story.expired as Array).is_empty():
			seen_expired = true
	t.check(seen_expired, "an unattended agenda item expired")
	for id in s.world.story.expired:
		t.check(s.world.case_state[id].choice_id == Campaign.SKIP_CHOICE, "%s resolved as unattended, not dropped" % id)
		var logged := false
		for e in s.world.story.journal:
			if str(e.get("case", "")) == id and str(e.get("kind", "")) == "tertunda":
				logged = true
		t.check(logged, "%s: expiry recorded in Buku Kisah (event_log is capped)" % id)


func _play_campaign(choice: String) -> Session:
	var s := _session()
	s.present_next_case()
	var guard := 0
	while not s.world.is_term_over() and guard < 200:
		guard += 1
		if s.pending_case() != "":
			var c: Dictionary = s.cases.cases[s.pending_case()]
			var ids: Array = c.choices.map(func(x): return str(x.choice_id))
			s.decide(s.pending_case(), choice if choice in ids else ids[0])
			continue
		if not Campaign.can_advance(s):
			var it := Campaign.items(s)
			Campaign.take(s, it[0].case_id)
			continue
		s.advance_quarter()
	return s


func test_full_campaign_reaches_an_ending_and_accounts_for_every_case() -> void:
	var s := _play_campaign("b")
	t.check(s.world.is_term_over(), "20 quarters completed")
	var ev := EndingEvaluator.evaluate(s, ContentDB.story.endings)
	t.check(ev.id in EndingEvaluator.ARCHETYPES, "ending archetype chosen")
	t.check(ContentDB.story.endings.archetypes.has(ev.id), "ending has a scene")
	var majors: Array = ContentDB.library_cases()
	for id in majors:
		var handled: bool = s.world.case_state.has(id)
		var queued: bool = (s.world.story.agenda as Dictionary).has(id)
		var reported: bool = id in Campaign.never_opened(s)
		t.check(handled or queued or reported, "%s accounted for (decided, expired, on agenda or reported)" % id)
	t.check((s.world.story.history as Array).size() == 20, "pillar history per quarter")


func test_abandoning_the_agenda_is_a_mandate_crisis() -> void:
	# Neglect counterfactual: take up no agenda item all term. Best fiscal balance, but most issues expire.
	var s := _session()
	s.present_next_case()
	var guard := 0
	while not s.world.is_term_over() and guard < 400:
		guard += 1
		if s.pending_case() != "":
			break
		if not Campaign.can_advance(s):
			Narrative.ensure(s.world)["quarter_taken"] = s.world.quarter_index()  # counterfactual: nothing taken up
			continue
		s.advance_quarter()
	t.check(s.world.is_term_over(), "neglect term completes")
	var cfg: Dictionary = ContentDB.story.endings
	var ev := EndingEvaluator.evaluate(s, cfg)
	t.check(int(ev.features.neglect) >= int(cfg.thresholds.crisis_neglect), "neglect misses critical crises and lets items lapse idle")
	t.check(ev.id == "krisis_mandat", "abandoning the agenda ends in Krisis Mandat (got %s)" % ev.id)


func test_strong_route_reaches_warisan_besar_and_misses_no_crisis() -> void:
	# Deterministic excellent-but-plausible play (game/tests/data/strong_route.json): no bugs, no edited
	# state, every event left on. Proves the top ending is attainable; regenerate after balance changes.
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/data/strong_route.json"))
	var acts: Array = route.actions
	var s := _session()
	s.present_next_case()
	var i := 0
	var guard := 0
	while not s.world.is_term_over() and guard < 500:
		guard += 1
		if s.pending_case() != "":
			var a: Dictionary = acts[i] if i < acts.size() else {}
			t.check(str(a.get("decide", "")) == s.pending_case(), "route decides %s" % s.pending_case())
			s.decide(s.pending_case(), str(a.get("choice", "")))
			i += 1
			continue
		if i < acts.size() and int(acts[i].q) == s.world.quarter_index():
			var a: Dictionary = acts[i]
			if a.has("delegate"):
				t.check(Campaign.delegate(s, str(a.delegate)) == "", "delegate %s" % a.delegate)
			else:
				t.check(Campaign.take(s, str(a.take)) == "", "take %s" % a.take)
				s.decide(str(a.take), str(a.choice))
			i += 1
			continue
		if not Campaign.can_advance(s):
			t.check(false, "route stalls at quarter %d" % s.world.quarter_index())
			break
		s.advance_quarter()
	t.check(s.world.is_term_over(), "strong route completes the term")
	var ev := EndingEvaluator.evaluate(s, ContentDB.story.endings)
	t.check(int(ev.features.missed_critical) == 0, "strong route misses no critical crisis")
	t.check(ev.id == "warisan_besar", "strong route reaches Warisan Besar (got %s)" % ev.id)


func test_legacy_sequence_is_built_from_the_term() -> void:
	var s := _play_campaign("c")
	var ev := EndingEvaluator.evaluate(s, ContentDB.story.endings)
	var beats := EndingStory.build_beats(s, ev)
	var r := EndingStory.retrospective(s)
	t.check((r.best as Array).size() == 2 and (r.worst as Array).size() == 2, "best and struggling provinces named")
	t.check(not str(r.best[0].name).begins_with("provinsi "), "province names resolved")
	t.check((r.defining as Array).size() == 3, "three defining decisions")
	var speakers := beats.map(func(b): return str(b.s))
	for who in ["nara", "bayu", "sekar", "yosef", "laras"]:
		t.check(who in speakers, "legacy sequence includes %s" % who)
	t.check(beats.any(func(b): return str(b.get("bg", "")) == "peta"), "map overview of Indonesia")
	var local_lines := beats.filter(func(b): return b.has("case"))
	t.check(local_lines.size() >= 1, "a regional character returns")
	for b in local_lines:
		var ch := ContentDB.character(str(b.s), ContentDB.cases[str(b.case)])
		t.check(str(ch.get("name", "")) != "" and str(ch.get("portrait", "")) != "", "returning local %s has name and portrait" % b.s)
	for b in beats:
		t.check(not str(b.t).contains("\u2014"), "no em dash in legacy text")


func test_active_prioritisation_is_not_neglect() -> void:
	# Taking an item every quarter (always the first) leaves many items lapsed by displacement, but is
	# never classified as abandoning the agenda (D-093).
	var s := _play_campaign("b")
	var f := EndingEvaluator.features(s)
	t.check(int(f.lapsed) == 0, "active play has no idle lapses")
	t.check(int(f.neglect) < int(ContentDB.story.endings.thresholds.crisis_neglect), "active play stays below the neglect line")


func test_dialogue_position_survives_save_and_load() -> void:
	var s := _session()
	var st := Narrative.ensure(s.world)
	st["playing"] = {"beats": [{"s": "laras", "t": "Satu."}, {"s": "bayu", "e": "cemas", "t": "Dua."}], "index": 1,
		"resume": "quarter", "revealed": true, "waiting_option": false, "case": "CASE-0001", "bg": "ruang_rapat",
		"history": [{"name": "Laras Prameswari", "text": "Satu."}]}
	var d := s.world.to_dict()
	var s2 := _session()
	t.check(s2.world.load_dict(JSON.parse_string(JSON.stringify(d))) == "", "save loads")
	var pl: Dictionary = s2.world.story.get("playing", {})
	t.check(int(pl.get("index", -1)) == 1 and str(pl.get("resume", "")) == "quarter", "beat index and flow restored")
	t.check(str(pl.beats[1].s) == "bayu" and str(pl.beats[1].e) == "cemas", "speaker and expression restored")
	t.check(str(pl.get("bg", "")) == "ruang_rapat" and bool(pl.get("revealed", false)), "backdrop and reveal state restored")


func test_updater_versions_and_binary_lines() -> void:
	var U: GDScript = load("res://src/app/updater.gd")
	t.check(U.compare("1.0.10", "1.0.9") == 1 and U.compare("1.0.0", "1.0") == 0 and U.compare("1.1.0", "1.2.0") == -1, "numeric version compare")
	t.check(U.line_of("1.0.7") == "1.0" and U.line_of("2.3.0") == "2.3", "binary line = major.minor")
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/update_config.json"))
	t.check(str(cfg.get("manifest_url", "")).begins_with("https://"), "update manifest served over https")


func test_story_state_survives_save_and_load() -> void:
	var s := _session()
	s.present_next_case()
	Campaign.take(s, "CASE-0001")
	s.decide("CASE-0001", "c")
	Narrative.ensure(s.world).flags["prioritas_awal"] = "trust"
	var d := s.world.to_dict()
	var s2 := _session({}, false)
	t.check(s2.world.load_dict(JSON.parse_string(JSON.stringify(d))) == "", "load ok")
	t.check(s2.world.story.flags.get("prioritas_awal") == "trust", "flags restored")
	t.check(s2.world.story.promises.has("CASE-0001/c"), "promise restored")
	t.check(not (s2.world.story.pending as Array).is_empty(), "pending reaction restored")
	t.check(Campaign.enabled(s2.world), "campaign mode restored")


func test_old_saves_skip_the_prologue() -> void:
	var s := _session({}, false)
	var d := s.world.to_dict()
	d["schema"] = 5
	d.erase("story")
	var s2 := _session({}, false)
	t.check(s2.world.load_dict(d) == "", "v5 save loads")
	t.check(bool(s2.world.story.get("prologue_done", false)), "migrated save does not replay the prologue")


func test_no_em_dash_in_player_facing_story_text() -> void:
	var dash := String.chr(0x2014)
	for f in ["cast", "prologue", "tutorial", "quarters", "endings", "credits"]:
		t.check(not JSON.stringify(ContentDB.story[f]).contains(dash), "%s.json free of U+2014" % f)
	for id in _cases():
		t.check(not JSON.stringify(_cases()[id].get("story", {})).contains(dash), "%s story free of U+2014" % id)


func _scan_dir(dir: String, exts: Array, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() in exts:
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if d != "map":  # generated map/art exports keep their copied provenance text
			_scan_dir(dir.path_join(d), exts, out)


func test_no_em_dash_in_any_game_text_or_code() -> void:
	var dash := String.chr(0x2014)
	var files: Array = []
	_scan_dir("res://data", ["json"], files)
	_scan_dir("res://src", ["gd"], files)
	for f in files:
		var s := FileAccess.get_file_as_string(f)
		t.check(not s.contains(dash) and not s.contains("\\u2014"), "%s free of U+2014 (scripts/text/em_dash.py --fix)" % f)
