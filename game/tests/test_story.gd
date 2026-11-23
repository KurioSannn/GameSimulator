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
