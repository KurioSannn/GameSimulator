extends RefCounted
## Map integration (geography v2 meshes, D-058): offline loading, canonical identity, holes and
## multipart rendering data, projection, LOD selection/transitions, hit testing against independent
## fixtures (scripts/pipelines/game/build_map_test_points.py), asset errors, no network.

var t

const LODS := ["lod1", "lod2", "lod3"]
const BASE := "res://data/map/v2/kabkota_"

static var _cache: Dictionary = {}


func _lod(name: String) -> MapLod:
	if not _cache.has(name):
		var l := MapLod.new()
		var err := l.load_from(BASE + name)
		_cache[name] = l if err == "" else err
	return _cache[name] if _cache[name] is MapLod else null


func _registry() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/regions.json"))


func test_each_lod_loads_offline_from_packaged_files() -> void:
	for name in LODS:
		var l := MapLod.new()
		var err := l.load_from(BASE + name)
		t.check(err == "", "%s loads: %s" % [name, err])
		t.check(l.lod == name, "%s meta names itself" % name)
		t.check(str(l.meta.source.decision) == "D-053", "%s provenance points to the LOD decision" % name)
		t.check(l.timings.has("total_ms"), "%s records load timings" % name)


func test_all_514_canonical_ids_in_registry_order_with_parents_and_bps_codes() -> void:
	var reg := _registry()
	var regions: Array = reg.regions
	var provinces := {}
	for p in reg.provinces:
		provinces[p.region_id] = p
	for name in LODS:
		var l := _lod(name)
		var n_kab := 0
		for i in l.ids.size():
			if l.kinds[i] != "kabkota":
				t.check(l.kinds[i] == "fragment" and l.ids[i].begins_with("F"), "%s: non-region entries are BIG fragments only" % name)
				continue
			n_kab += 1
			var r: Dictionary = regions[i]
			t.check(l.ids[i] == r.region_id, "%s: entry %d is %s (registry order)" % [name, i, r.region_id])
			t.check(str(l.meta.regions[i].parent) == r.parent_region_id, "%s: parent of %s" % [name, r.region_id])
			t.check(provinces.has(r.parent_region_id), "%s: parent province %s exists" % [name, r.parent_region_id])
			var kb := str(r.get("kode_bps", ""))
			t.check(kb.length() == 4 and kb.begins_with(str(provinces[r.parent_region_id].kode_bps)),
				"%s: kode_bps %s of %s matches its province's BPS code" % [name, kb, r.region_id])
		t.check(n_kab == 514, "%s: 514 kab/kota (got %d)" % [name, n_kab])
		t.check(l.ids == _lod("lod1").ids, "%s: identical entry order to lod1 (alignment)" % name)


func test_every_vertex_and_triangle_maps_to_exactly_one_region() -> void:
	for name in LODS:
		var l := _lod(name)
		var ok := true
		for i in l.ids.size():
			var r: Dictionary = l.meta.regions[i]
			for k in range(int(r.v[0]), int(r.v[0]) + int(r.v[1])):
				if int(l.region_uv[k].x) != i:
					ok = false
					break
			for k in range(int(r.t[0]), int(r.t[0]) + int(r.t[1]), 3):
				for j in 3:
					var vi := l.triangles[k + j]
					if vi < int(r.v[0]) or vi >= int(r.v[0]) + int(r.v[1]):
						ok = false
			if not ok:
				t.check(false, "%s: geometry of %s leaks outside its own vertex range" % [name, l.ids[i]])
				break
		t.check(ok, "%s: every triangle and vertex belongs to one region" % name)


## Triangles must cover exactly (outer rings) - (holes) for every region: holes are not filled and
## no island is missing from the fill.
func test_triangulation_area_equals_polygon_area_minus_holes() -> void:
	for name in LODS:
		var l := _lod(name)
		var worst := 0.0
		var worst_id := ""
		for i in l.ids.size():
			var r: Dictionary = l.meta.regions[i]
			var poly := 0.0
			for ring in r.rings:
				var a := absf(_ring_area(l.positions, int(ring[0]), int(ring[1])))
				poly += -a if int(ring[3]) == 1 else a
			var tri := 0.0
			for k in range(int(r.t[0]), int(r.t[0]) + int(r.t[1]), 3):
				var a := l.positions[l.triangles[k]]
				var b := l.positions[l.triangles[k + 1]]
				var c := l.positions[l.triangles[k + 2]]
				tri += absf((b - a).cross(c - a)) * 0.5
			var rel := absf(tri - poly) / maxf(poly, 1e-12)
			if rel > worst:
				worst = rel
				worst_id = l.ids[i]
		t.check(worst < 1e-4, "%s: worst triangle/polygon area mismatch %s at %s" % [name, String.num_scientific(worst), worst_id])


func test_holes_exist_and_are_not_filled() -> void:
	var l := _lod("lod3")
	var holes := 0
	for r in l.meta.regions:
		for ring in r.rings:
			holes += int(ring[3])
	t.check(holes >= 25, "lod3 keeps enclave/lake holes (got %d)" % holes)


func test_hit_testing_matches_independent_fixtures() -> void:
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/map_points.json"))
	var per := {}
	var wrong: Array = []
	for p in fx.points:
		var l := _lod(p.lod)
		var xy := MapView.project_lonlat(float(p.lon), float(p.lat))
		var got := l.region_at(xy)
		var key := "%s/%s" % [p.lod, p.category]
		per[key] = int(per.get(key, 0)) + 1
		if got != str(p.expected):
			wrong.append("%s %s (%.5f,%.5f) expected '%s' got '%s' %s" % [p.lod, p.category, p.lon, p.lat, p.expected, got, p.note])
	t.check(wrong.is_empty(), "%d of %d fixture points resolve differently: %s" % [wrong.size(), fx.points.size(), str(wrong.slice(0, 5))])
	for name in LODS:
		for cat in ["extreme", "multipart", "enclave", "border"]:
			t.check(int(per.get("%s/%s" % [name, cat], 0)) > 0, "fixture covers %s %s" % [name, cat])
	t.check(int(per.get("lod3/true_hole", 0)) > 0, "fixture covers lod3 true holes")


func test_projection_matches_offline_build_and_is_lod_independent() -> void:
	var fx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/map_points.json"))
	var worst := 0.0
	for p in fx.points:
		var xy := MapView.project_lonlat(float(p.lon), float(p.lat))
		worst = maxf(worst, xy.distance_to(Vector2(p.xy[0], p.xy[1])))
	t.check(worst < 1e-3, "GDScript projection equals the build projection (worst %s units)" % String.num_scientific(worst))
	# Same projection for every LOD: national bounds agree within the coarsest simplification interval.
	var b1 := _lod("lod1").bounds
	for name in ["lod2", "lod3"]:
		var b := _lod(name).bounds
		var d := maxf(maxf(absf(b.position.x - b1.position.x), absf(b.position.y - b1.position.y)),
			maxf(absf(b.end.x - b1.end.x), absf(b.end.y - b1.end.y)))
		t.check(d * MapView.KM_PER_UNIT < 1.0, "%s bounds align with lod1 within 1 km (%.3f km)" % [name, d * MapView.KM_PER_UNIT])
	# Representative points across Indonesia (from the fixture's extreme parts) land inside the map.
	for p in fx.points:
		if p.category == "extreme":
			t.check(b1.grow(1.0).has_point(MapView.project_lonlat(float(p.lon), float(p.lat))), "extreme %s inside map bounds" % p.note)


func test_lod_selection_thresholds_and_both_zoom_directions() -> void:
	# Thresholds must equal the documented view bands (meta view_width_km at the 1,600-px reference).
	t.near(MapView.LOD1_MIN_M_PER_PX, float(_lod("lod1").meta.view_width_km[0]) * 1000.0 / MapView.REF_VIEWPORT_PX, 1e-6, "LOD1 threshold")
	t.near(MapView.LOD2_MIN_M_PER_PX, float(_lod("lod2").meta.view_width_km[0]) * 1000.0 / MapView.REF_VIEWPORT_PX, 1e-6, "LOD2 threshold")
	t.check(MapView.lod_for_scale(3000.0) == "lod1", "national scale -> lod1")
	t.check(MapView.lod_for_scale(1250.0) == "lod1", "exact LOD1 threshold -> lod1")
	t.check(MapView.lod_for_scale(1249.9) == "lod2", "just below -> lod2")
	t.check(MapView.lod_for_scale(187.5) == "lod2", "exact LOD2 threshold -> lod2")
	t.check(MapView.lod_for_scale(187.4) == "lod3", "just below -> lod3")
	# Zoom in then out through every band: the sequence is monotonic and symmetric (no flapping).
	var down: Array = []
	var s := 4000.0
	while s > 20.0:
		down.append(MapView.lod_for_scale(s))
		s /= 1.15
	var up: Array = []
	for i in range(down.size() - 1, -1, -1):
		up.append(MapView.lod_for_scale(4000.0 / pow(1.15, i)))
	var changes := 0
	for i in range(1, down.size()):
		if down[i] != down[i - 1]:
			changes += 1
	t.check(changes == 2, "zooming in crosses exactly two LOD boundaries (got %d)" % changes)
	var rev := down.duplicate()
	rev.reverse()
	t.check(up == rev, "zooming out retraces the same LODs in reverse")


func test_mapview_switches_lod_and_keeps_identity_and_selection() -> void:
	var mv := MapView.new()
	var err := mv.load_map()
	t.check(err == "", "MapView loads: " + err)
	t.check(mv.active_lod == "lod1" and mv.region_ids.size() == 514, "starts at lod1 with 514 regions")
	var ids_before := mv.region_ids
	mv.set_selected("13.75")
	var p := MapView.project_lonlat(100.3661, -0.2874)  # inside Kota Bukittinggi (enclave in Agam)
	var at := {}
	for zoom in [0.5, 3.0, 20.0, 3.0, 0.5]:
		mv.update_view(zoom)
		at[mv.active_lod] = mv.region_at(p)
	t.check(at.keys().size() == 3, "visited all three LODs: %s" % str(at.keys()))
	for k in at:
		t.check(at[k] == "13.75", "%s: Bukittinggi resolves to 13.75 (got %s)" % [k, at[k]])
	t.check(mv.region_ids == ids_before, "region ids unchanged by LOD switches")
	t.check(mv.selected_id() == "13.75", "selection kept across LOD switches")
	t.check(mv.load_log.size() == 3, "each LOD loaded once (cached afterwards)")
	t.check(mv.province_rect("13").has_point(p), "province view rect of Sumatera Barat contains the selection")
	mv.free()


func test_background_preload_gives_the_same_lods_without_double_loading() -> void:
	var mv := MapView.new()
	t.check(mv.load_map() == "", "MapView loads")
	mv.preload_remaining()
	mv.update_view(20.0)  # needs lod3 now: must wait for its worker task, not parse it again
	mv.update_view(3.0)   # lod2
	t.check(mv.active_lod == "lod2", "switched through lod3 to lod2 (got %s)" % mv.active_lod)
	var by_lod := {}
	for e in mv.load_log:
		by_lod[e.lod] = int(by_lod.get(e.lod, 0)) + 1
	t.check(by_lod == {"lod1": 1, "lod2": 1, "lod3": 1}, "each LOD loaded exactly once: %s" % str(by_lod))
	for e in mv.load_log:
		if e.lod != "lod1":
			t.check(e.parsed_on_worker_thread, "%s parsed on a worker thread" % e.lod)
	t.check(mv.lod("lod3").ids == mv.lod("lod1").ids, "preloaded lod3 aligned with lod1")
	var p := MapView.project_lonlat(100.3661, -0.2874)
	t.check(mv.lod("lod3").region_at(p) == "13.75" and mv.lod("lod2").region_at(p) == "13.75",
		"preloaded LODs resolve Bukittinggi canonically")
	mv.free()


func test_missing_and_malformed_assets_give_readable_errors() -> void:
	var l := MapLod.new()
	var err := l.load_from("res://data/map/v2/tidak_ada")
	t.check(err.begins_with("Data peta tidak ditemukan"), "missing asset: " + err)
	var dir := "user://test_map_assets/"
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "bad.json", FileAccess.WRITE)
	f.store_string("{ bukan json")
	f.close()
	f = FileAccess.open(dir + "bad.bin", FileAccess.WRITE)
	f.store_buffer(PackedByteArray([1, 2, 3]))
	f.close()
	err = MapLod.new().load_from(dir + "bad")
	t.check(err.begins_with("Data peta rusak"), "malformed metadata: " + err)
	# Valid metadata with a truncated binary.
	f = FileAccess.open(dir + "trunc.json", FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(BASE + "lod1.json"))
	f.close()
	f = FileAccess.open(dir + "trunc.bin", FileAccess.WRITE)
	f.store_buffer(FileAccess.get_file_as_bytes(BASE + "lod1.bin").slice(0, 1000))
	f.close()
	err = MapLod.new().load_from(dir + "trunc")
	t.check(err.begins_with("Data peta rusak"), "truncated binary: " + err)
	var mv := MapView.new()
	err = mv.load_map("res://tidak/ada/")
	t.check(err.begins_with("Data peta tidak ditemukan") and mv.region_ids.is_empty(), "MapView reports missing map: " + err)
	mv.free()


## Regression (2026-10-22): Geometry2D.is_point_in_polygon reported this point inside a metre-scale
## Wakatobi islet ring that lies entirely to its right, so the even-odd count flipped twice and the
## islet the cursor was on resolved to no region. MapLod uses its own crossing-number test.
func test_tiny_islet_hit_test_regression() -> void:
	var l := _lod("lod3")
	var p := MapView.project_lonlat(123.997462881579, -5.7566262)
	var containing := 0
	var outside_ring_found := false
	for ring in l.rings["74.07"]:
		var box := Rect2(ring[0], Vector2.ZERO)
		for v in ring:
			box = box.expand(v)
		if MapLod.point_in_ring(p, ring):
			containing += 1
			t.check(box.has_point(p), "a ring containing the point must also contain it in its bbox")
		elif not box.has_point(p) and box.grow(0.01).has_point(p):
			outside_ring_found = true
	t.check(containing == 1, "exactly one Wakatobi ring contains the point (got %d)" % containing)
	t.check(outside_ring_found, "the neighbouring islet ring (the one the engine misjudged) is present")
	t.check(l.region_at(p) == "74.07", "the islet resolves to Wakatobi")


## Regression (2026-10-22): a parse error in main.gd (new class not yet in the class cache) passed every
## headless suite, because no suite loads main.gd, and the game then sat idle with no screen.
func test_every_game_script_parses() -> void:
	for path in _scripts("res://src"):
		var s: Script = load(path)
		t.check(s != null and s.can_instantiate(), "%s parses and compiles" % path)


static func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_scripts(dir.path_join(sub)))
	return out


func test_map_code_makes_no_network_requests() -> void:
	var forbidden := ["HTTPRequest", "HTTPClient", "StreamPeerTCP", "StreamPeerTLS", "WebSocket", "PacketPeerUDP", "http://", "https://"]
	for path in ["res://src/map/map_view.gd", "res://src/map/map_lod.gd", "res://src/map/map_camera.gd", "res://src/app/main.gd"]:
		var src := FileAccess.get_file_as_string(path)
		for word in forbidden:
			t.check(not src.contains(word), "%s must not use %s" % [path, word])
	t.check(MapView.BASE_DIR.begins_with("res://"), "map data is packaged with the game (res://)")


static func _ring_area(pos: PackedVector2Array, start: int, n: int) -> float:
	var a := 0.0
	for k in n:
		var p := pos[start + k]
		var q := pos[start + (k + 1) % n]
		a += p.x * q.y - q.x * p.y
	return a * 0.5
