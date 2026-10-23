class_name QaChecklist
extends Node
## Automated run of the manual QA checklist on the REAL main screen (windowed, real renderer, real
## input path). Started by main.gd only with `-- --qa-checklist=<output dir>`; never in normal play.
##   tools/Godot.app/Contents/MacOS/Godot --path game -- --qa-checklist=<dir>
## Keys go through Input.parse_input_event (so Input state, e.g. held arrow keys, is real); mouse
## events go through Viewport.push_input in viewport coordinates. Saves go to an isolated directory
## (user://qa_checklist_saves), never to the player's own slots. Writes <dir>/qa_checklist.json and
## screenshots, then quits.

var main: Node
var out_dir := ""
var _items: Dictionary = {}     # checklist item -> {checks: [...], passed: bool}
var _item := ""
var _shots: Array = []
var _log := _ErrorLog.new()
var _mouse_method := "push_input"


class _ErrorLog extends Logger:
	var errors: Array = []
	var warnings := 0

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _bt: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			warnings += 1
			return
		errors.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])


func run() -> void:
	OS.add_logger(_log)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var qa_saves := "user://qa_checklist_saves"
	_clear_dir(qa_saves)
	Game.saves = SaveService.new(qa_saves)  # isolated: the player's quicksave is never touched
	await _frames(5)

	await _item_case()
	await _item_navigation()
	await _item_selection()
	await _item_small_islands()
	await _item_panel_and_movement()
	await _item_gameplay_and_save()

	var all_ok := true
	for k in _items:
		all_ok = all_ok and _items[k].passed
	var report := {"generated_at": Time.get_datetime_string_from_system(true),
		"window_size": DisplayServer.window_get_size(), "viewport": get_viewport().get_visible_rect().size,
		"mouse_injection": _mouse_method, "save_dir_used": ProjectSettings.globalize_path(qa_saves),
		"runtime_errors": _log.errors, "runtime_warnings": _log.warnings,
		"all_passed": all_ok and _log.errors.is_empty(), "items": _items, "screenshots": _shots}
	var f := FileAccess.open(out_dir.path_join("qa_checklist.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "  "))
	f.close()
	for k in _items:
		print("QA %s: %s" % ["PASS" if _items[k].passed else "FAIL", k])
		for c in _items[k].checks:
			if not c.ok:
				print("    FAIL ", c.what, " -> ", c.detail)
	print("QA runtime errors: %d" % _log.errors.size())
	get_tree().quit(0 if report.all_passed else 1)


# --- checklist items -------------------------------------------------------------------------------

func _item_case() -> void:
	_begin("CASE-0001: pilih keputusan dengan tombol 1-3, jendela kasus tertutup")
	var pend: String = Game.pending_case()
	_check("CASE-0001 ditampilkan saat mulai", pend == "CASE-0001" and main.case_modal.visible, "pending=%s visible=%s" % [pend, main.case_modal.visible])
	await _shot("01_case0001_open")
	await _key(KEY_1)
	await _frames(3)
	_check("tombol 1 memutuskan kasus", Game.pending_case() == "", "pending=%s" % Game.pending_case())
	_check("jendela kasus tertutup", not main.case_modal.visible, "visible=%s" % main.case_modal.visible)
	_check("peta terlihat (tidak tertutup modal)", main.map_view.visible and not main.case_modal.visible, "")
	await _shot("02_case_closed_map_visible")


func _item_navigation() -> void:
	_begin("Navigasi peta: Home, zoom masuk/keluar melalui LOD1, LOD2, LOD3")
	main.camera.zoom = Vector2.ONE * 6.0  # start away from the national view so Home is meaningful
	main.camera.view_changed.emit()
	await _frames(2)
	await _key(KEY_HOME)
	await _frames(2)
	_check("Home menampilkan seluruh Indonesia", main.map_view.active_lod == "lod1"
		and _view_rect().grow(1.0).encloses(main.map_view.bounds.grow(-60.0)), "lod=%s" % main.map_view.active_lod)
	await _shot("03_home_national_lod1")
	var seen_in: Array = [main.map_view.active_lod]
	var center := get_viewport().get_visible_rect().size / 2.0
	for _i in 40:
		await _wheel(MOUSE_BUTTON_WHEEL_UP, center)
		if seen_in[-1] != main.map_view.active_lod:
			seen_in.append(main.map_view.active_lod)
			await _shot("04_zoom_in_now_%s" % main.map_view.active_lod)
	_check("zoom masuk: LOD1 -> LOD2 -> LOD3", seen_in == ["lod1", "lod2", "lod3"], str(seen_in))
	var seen_out: Array = [main.map_view.active_lod]
	for _i in 60:
		await _wheel(MOUSE_BUTTON_WHEEL_DOWN, center)
		if seen_out[-1] != main.map_view.active_lod:
			seen_out.append(main.map_view.active_lod)
	_check("zoom keluar: LOD3 -> LOD2 -> LOD1", seen_out == ["lod3", "lod2", "lod1"], str(seen_out))
	_check("LOD sesuai skala (label panel kiri)", main._lod_label.text.contains("LOD1"), main._lod_label.text)


func _item_selection() -> void:
	_begin("Pemilihan wilayah: hover + klik di Sumatera, Jawa, Kalimantan, Papua")
	var probes := {"sumatera": ["12.71", "13.75", "18.71", "11.06"], "jawa": ["31.71", "32.71", "35.78", "33.74"],
		"kalimantan": ["64.72", "61.06", "63.71", "65.02"], "papua": ["91.71", "93.01", "94.04", "92.02"]}
	for group in probes:
		for id in probes[group]:
			await _probe_region(id, 120.0)
		await _shot("05_selection_%s" % group)


func _item_small_islands() -> void:
	_begin("Pulau kecil: Maluku, Nusa Tenggara, gugus pulau; klik tidak memilih wilayah yang salah")
	for id in ["81.07", "81.01", "82.71", "53.14", "53.20", "52.08", "31.01", "74.07", "96.03"]:
		var parts := _parts_by_area(id)
		var picks: Array = []
		for k in [0, parts.size() / 2, parts.size() - 1, parts.size() / 4, (3 * parts.size()) / 4]:
			if k >= 0 and k < parts.size() and not picks.has(parts[k]):
				picks.append(parts[k])
		var ok := 0
		var tried := 0
		for p in picks:
			var pt: Vector2 = p.point
			var scale := clampf(p.extent_m / 12.0, 4.0, 150.0)  # island spans ~12 px or more
			_center_on(pt, scale)
			await _frames(2)
			var got := await _click_center()
			tried += 1
			if got == id:
				ok += 1
			else:
				_check("klik pulau %s bagian %d (%.0f m²)" % [id, p.part, p.area_m2], false, "terpilih '%s'" % got)
		_check("%s: %d/%d pulau terpilih dengan ID yang benar" % [id, ok, tried], ok == tried, "")
		# Water next to the largest island must select nothing.
		var big: Dictionary = parts[0]
		var water := _water_point_near(big)
		if water != Vector2.INF:
			_center_on(water, 60.0)
			await _frames(2)
			var w := await _click_center()
			_check("%s: klik di laut tidak memilih wilayah" % id, w == "", "terpilih '%s'" % w)
		_center_on(big.point, maxf(big.extent_m / 300.0, 40.0))
		await _frames(3)
		await _shot("06_islands_%s" % id.replace(".", "_"))


func _item_panel_and_movement() -> void:
	_begin("Panel dan pergerakan: Lihat Provinsi, Esc, pan mouse/trackpad, panah, WASD")
	var id := "81.01"
	_center_on(_parts_by_area(id)[0].point, 300.0)
	await _frames(2)
	_check("pilih wilayah untuk panel", await _click_center() == id, "")
	await _frames(3)
	var btn := _find_button(main.region_panel, "Lihat Provinsi")
	_check("tombol Lihat Provinsi ada", btn != null, "")
	if btn:
		await _click_at(btn.get_global_rect().get_center())
		await _frames(3)
		var prect: Rect2 = main.map_view.province_rect("81")
		_check("Lihat Provinsi menampilkan seluruh Provinsi Maluku", _view_rect().encloses(prect), "view=%s prov=%s" % [_view_rect(), prect])
		await _shot("07_lihat_provinsi_maluku")
	await _key(KEY_ESCAPE)
	await _frames(2)
	_check("Esc menutup panel dan membatalkan pilihan", not main.region_panel.visible and main.map_view.selected_id() == "", "")
	var center := get_viewport().get_visible_rect().size / 2.0
	var p0: Vector2 = main.camera.position
	await _drag(MOUSE_BUTTON_RIGHT, center, Vector2(120, 60))
	_check("geser dengan mouse (klik kanan + tarik)", (main.camera.position - p0).length() > 1.0, "moved %.2f" % (main.camera.position - p0).length())
	p0 = main.camera.position
	await _drag(MOUSE_BUTTON_MIDDLE, center, Vector2(-80, 40))
	_check("geser dengan mouse (klik tengah + tarik)", (main.camera.position - p0).length() > 1.0, "moved %.2f" % (main.camera.position - p0).length())
	p0 = main.camera.position
	var pan := InputEventPanGesture.new()
	pan.position = center
	pan.delta = Vector2(4, 2)
	get_viewport().push_input(pan, true)
	await _frames(2)
	_check("geser dengan trackpad (pan gesture)", (main.camera.position - p0).length() > 1.0, "moved %.2f" % (main.camera.position - p0).length())
	var z0: float = main.camera.zoom.x
	var mag := InputEventMagnifyGesture.new()
	mag.position = center
	mag.factor = 1.2
	get_viewport().push_input(mag, true)
	await _frames(2)
	_check("zoom dengan trackpad (pinch)", main.camera.zoom.x > z0 * 1.1, "zoom %.3f -> %.3f" % [z0, main.camera.zoom.x])
	for spec in [[KEY_RIGHT, "panah kanan"], [KEY_DOWN, "panah bawah"], [KEY_D, "WASD: D"], [KEY_A, "WASD: A"], [KEY_W, "WASD: W"], [KEY_S, "WASD: S"]]:
		p0 = main.camera.position
		await _hold_key(spec[0], 20)
		_check("geser dengan %s" % spec[1], (main.camera.position - p0).length() > 1.0, "moved %.2f" % (main.camera.position - p0).length())


func _item_gameplay_and_save() -> void:
	_begin("Gameplay dan simpan: Spasi maju satu kuartal, F5, F9, tanpa data rusak")
	await _key(KEY_HOME)
	var t0: int = Game.world.tick
	var period0: String = main._period.text
	await _key(KEY_SPACE)
	await _frames(3)
	_check("Spasi memajukan satu kuartal (3 bulan)", Game.world.tick == t0 + 3, "tick %d -> %d" % [t0, Game.world.tick])
	_check("label periode berubah", main._period.text != period0, "%s -> %s" % [period0, main._period.text])
	if Game.pending_case() != "":
		await _key(KEY_1)  # a follow-up case may open; decide it so play can continue
		await _frames(3)
	var saved := _world_hash()
	var tick_saved: int = Game.world.tick
	await _key(KEY_F5)
	await _frames(2)
	var path: String = Game.saves.path_for(SaveService.QUICKSAVE_ID)
	_check("F5 menulis simpanan cepat", FileAccess.file_exists(path), path)
	var check: Dictionary = Game.saves.load_with_recovery(SaveService.QUICKSAVE_ID)
	_check("berkas simpanan valid (checksum)", check.ok, str(check.get("error", "")))
	await _key(KEY_SPACE)
	await _frames(3)
	if Game.pending_case() != "":
		await _key(KEY_1)
		await _frames(3)
	_check("keadaan berubah setelah kuartal berikutnya", _world_hash() != saved, "")
	await _key(KEY_F9)
	await _frames(3)
	_check("F9 memulihkan keadaan persis (hash dunia simulasi sama)", _world_hash() == saved and Game.world.tick == tick_saved,
		"tick %d (saved %d)" % [Game.world.tick, tick_saved])
	_check("514 wilayah utuh setelah muat", Game.world.region_ids.size() == 514, "")
	_check("tidak ada kesalahan runtime selama QA", _log.errors.is_empty(), str(_log.errors.slice(0, 5)))
	await _shot("08_after_quickload")


# --- region probes ---------------------------------------------------------------------------------

## Hover then click the interior of the region's largest part; checks tooltip, panel and identity.
func _probe_region(id: String, m_per_px: float) -> void:
	var r: Dictionary = ContentDB.region_by_id[id]
	var p: Dictionary = ContentDB.province_by_id[r.parent_region_id]
	var part: Dictionary = _parts_by_area(id)[0]
	_center_on(part.point, clampf(part.extent_m / 500.0, 30.0, m_per_px))
	await _frames(2)
	await _move_mouse(get_viewport().get_visible_rect().size / 2.0)
	var hovered: String = main.map_view.hovered_id()
	var tip: String = main._tooltip_label.text
	_check("%s hover" % id, hovered == id and main._tooltip.visible and tip.contains(RegionPanel._display_name(r)),
		"hover='%s' tooltip='%s'" % [hovered, tip.replace("\n", " | ")])
	var got := await _click_center()
	await _frames(2)
	var text := _texts(main.region_panel)
	var want := ["Kode Kemendagri %s" % id, "Kode BPS %s" % r.kode_bps, "Provinsi %s" % p.name, RegionPanel._display_name(r)]
	var missing: Array = want.filter(func(s): return not text.contains(s))
	_check("%s klik: %s, panel benar" % [id, RegionPanel._display_name(r)], got == id and main.region_panel.region_id == id and missing.is_empty(),
		"terpilih '%s', hilang di panel: %s" % [got, str(missing)])


## Parts of a region in the active-agnostic LOD3 data: interior point, area, extent; largest first.
func _parts_by_area(id: String) -> Array:
	var l: MapLod = main.map_view.lod("lod3")
	if l == null:
		main.map_view.update_view(100.0)
		l = main.map_view.lod("lod3")
	var entry: Dictionary = l.meta.regions[l.index_of[id]]
	var groups := {}
	for ring in entry.rings:
		var pi := int(ring[2])
		if not groups.has(pi):
			groups[pi] = []
		groups[pi].append(l.positions.slice(int(ring[0]), int(ring[0]) + int(ring[1])))
	var out: Array = []
	for pi in groups:
		var rings: Array = groups[pi]
		var outer: PackedVector2Array = rings[0]
		var box := Rect2(outer[0], Vector2.ZERO)
		for v in outer:
			box = box.expand(v)
		var area := absf(_area(outer))
		for h in rings.slice(1):
			area -= absf(_area(h))
		var pt := _interior(rings)
		if pt == Vector2.INF:
			continue
		out.append({"part": pi, "point": pt, "area_m2": area * pow(MapView.KM_PER_UNIT * 1000.0, 2),
			"extent_m": maxf(box.size.x, box.size.y) * MapView.KM_PER_UNIT * 1000.0, "box": box})
	out.sort_custom(func(a, b): return a.area_m2 > b.area_m2)
	return out


func _water_point_near(part: Dictionary) -> Vector2:
	var l: MapLod = main.map_view.lod("lod3")
	var box: Rect2 = part.box
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var p: Vector2 = box.get_center() + d * (box.size / 2.0 + Vector2(3, 3))
		if l.region_at(p) == "" and not _in_fragment(l, p):
			return p
	return Vector2.INF


static func _in_fragment(l: MapLod, p: Vector2) -> bool:
	for i in l.ids.size():
		if l.kinds[i] == "fragment" and (l.bbox[l.ids[i]] as Rect2).has_point(p):
			return true
	return false


## Widest horizontal inside-interval midpoint over several scanlines (even-odd with holes).
static func _interior(rings: Array) -> Vector2:
	var outer: PackedVector2Array = rings[0]
	var y0 := INF
	var y1 := -INF
	for v in outer:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var best := -1.0
	var best_pt := Vector2.INF
	for frac in [0.5, 0.37, 0.63, 0.21, 0.79, 0.3, 0.7]:
		var y: float = y0 + (y1 - y0) * float(frac)
		var xs: Array = []
		for r in rings:
			var ring: PackedVector2Array = r
			for i in ring.size():
				var a := ring[i]
				var b := ring[(i + 1) % ring.size()]
				if (a.y > y) != (b.y > y):
					xs.append(a.x + (y - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		for i in range(0, xs.size() - 1, 2):
			if xs[i + 1] - xs[i] > best:
				best = xs[i + 1] - xs[i]
				best_pt = Vector2((xs[i] + xs[i + 1]) / 2.0, y)
	return best_pt


static func _area(r: PackedVector2Array) -> float:
	var a := 0.0
	for i in r.size():
		a += r[i - 1].x * r[i].y - r[i].x * r[i - 1].y
	return a * 0.5


# --- input helpers ---------------------------------------------------------------------------------

func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(1)


func _hold_key(code: Key, frames: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(frames)
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(2)


func _move_mouse(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await _frames(1)
	if get_viewport().get_mouse_position().distance_to(pos) > 1.0:
		# Mouse position not injectable on this platform: move the real cursor (recorded in the report).
		_mouse_method = "warp_mouse"
		var scale := Vector2(DisplayServer.window_get_size()) / get_viewport().get_visible_rect().size
		Input.warp_mouse(pos * scale)
		await _frames(2)
		get_viewport().push_input(ev, true)
		await _frames(1)


func _click_at(pos: Vector2) -> void:
	await _move_mouse(pos)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = pos
		ev.global_position = pos
		get_viewport().push_input(ev, true)
		await _frames(1)


func _click_center() -> String:
	# The cursor lands on a whole physical pixel (warp_mouse), up to ~0.5 px off the viewport centre
	# (odd widths, HiDPI scale). At metre-scale islets that is more than the island, so re-centre the
	# camera on the pixel the cursor actually reached: the click then hits exactly the target point.
	var c := get_viewport().get_visible_rect().size / 2.0
	await _move_mouse(c)
	var m := get_viewport().get_mouse_position()
	if m.distance_to(c) <= 2.0:
		main.camera.position -= (m - c) / main.camera.zoom
		main.camera.view_changed.emit()
		await _frames(1)
		c = m
	await _click_at(c)
	await _frames(1)
	return main.map_view.selected_id()


func _wheel(button: MouseButton, pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	get_viewport().push_input(ev, true)
	await _frames(2)


func _drag(button: MouseButton, from: Vector2, by: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.pressed = true
	press.position = from
	get_viewport().push_input(press, true)
	await _frames(1)
	for i in 4:
		var mv := InputEventMouseMotion.new()
		mv.position = from + by * (i + 1) / 4.0
		mv.relative = by / 4.0
		mv.button_mask = MOUSE_BUTTON_MASK_RIGHT if button == MOUSE_BUTTON_RIGHT else MOUSE_BUTTON_MASK_MIDDLE
		get_viewport().push_input(mv, true)
		await _frames(1)
	var rel := press.duplicate() as InputEventMouseButton
	rel.pressed = false
	rel.position = from + by
	get_viewport().push_input(rel, true)
	await _frames(2)


# --- utilities -------------------------------------------------------------------------------------

func _center_on(world: Vector2, m_per_px: float) -> void:
	main.camera.position = world
	main.camera.zoom = Vector2.ONE * (MapView.KM_PER_UNIT * 1000.0 / m_per_px)
	main.camera.view_changed.emit()


func _view_rect() -> Rect2:
	var size: Vector2 = get_viewport().get_visible_rect().size / main.camera.zoom
	return Rect2(main.camera.position - size / 2.0, size)


func _world_hash() -> String:
	return JSON.stringify(Game.world.to_dict(), "", true, true).sha256_text()


func _texts(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	elif n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _texts(c)
	return out


func _find_button(n: Node, prefix: String) -> Button:
	if n is Button and (n as Button).text.begins_with(prefix):
		return n
	for c in n.get_children():
		var b := _find_button(c, prefix)
		if b:
			return b
	return null


func _begin(name: String) -> void:
	_item = name
	_items[name] = {"checks": [], "passed": true}


func _check(what: String, ok: bool, detail: String) -> void:
	_items[_item].checks.append({"what": what, "ok": ok, "detail": detail})
	if not ok:
		_items[_item].passed = false


func _shot(name: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	_shots.append(name + ".png")


func _frames(n: int) -> void:
	for _i in n:
		await RenderingServer.frame_post_draw


static func _clear_dir(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d:
		for f in d.get_files():
			d.remove(f)
