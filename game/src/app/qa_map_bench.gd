class_name QaMapBench
extends Node
## In-engine map benchmark + screenshots on the REAL main screen (windowed, real renderer).
## Started by main.gd only with `-- --map-bench=<output dir>`; never active in normal play.
##   tools/Godot.app/Contents/MacOS/Godot --path game -- --map-bench=<dir>
## Writes <dir>/map_bench.json and <dir>/*.png, then quits. Measurements are recorded, never assumed:
## frame time = wall time between consecutive frame_post_draw signals with vsync off; render CPU/GPU
## time from RenderingServer viewport measurement; memory from Performance monitors.

var main: Node
var out_dir := ""
var _results := {}
var _vp_rid: RID


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	var startup := {
		"engine_ticks_at_main_ready_ms": main.get("ready_ticks_ms"),
		"lod1_load_ms": main.map_view.load_ms,
	}
	await RenderingServer.frame_post_draw
	startup["first_frame_ticks_ms"] = Time.get_ticks_msec()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	main.case_modal.visible = false  # map-only measurements; the case flow is untouched
	_results = {
		"machine": _machine(),
		"viewport": {"logical": get_viewport().get_visible_rect().size, "texture": get_viewport().get_texture().get_size()},
		"startup": startup,
		"memory": {"after_lod1": _mem()},
	}
	await _frames(10)
	_results["first_complete_frame_note"] = "first_frame_ticks_ms is engine start -> first drawn frame of the main screen (LOD1)."

	# Views (lon, lat, metres per screen pixel)
	var national := [118.0, -2.5, 3000.0]
	var province := [113.4, -7.8, 600.0]       # Jawa Timur - Bali (LOD2)
	var dense := [106.85, -6.3, 90.0]          # Jabodetabek kab/kota (LOD3)
	var islands := [130.6, -0.9, 150.0]        # Raja Ampat (LOD3)
	var enclave := [100.37, -0.3, 30.0]        # Kota Bukittinggi enclave in Agam (LOD3, hole)
	var lakes := [122.72, -4.84, 25.0]         # Muna, Sulawesi Tenggara: true holes (LOD3)

	print("bench: startup recorded")
	# First-ever zoom into detail, right after startup: what a player meets. Records whether the
	# background preload (MapView.preload_remaining) had finished before each LOD was first needed.
	_results["preloaded_at_first_frame"] = {"lod2": main.map_view.is_loaded("lod2"), "lod3": main.map_view.is_loaded("lod3")}
	_results["zoom_sweep_in_first"] = await _sweep(national, 1.15, 120)
	_results["memory"]["after_all_lods"] = _mem()
	_results["lod_load_log"] = main.map_view.load_log

	_results["idle"] = {}
	_results["pan"] = {}
	for spec in [["lod1", national], ["lod2", province], ["lod3", dense]]:
		_set_view(spec[1])
		await _frames(5)
		print("bench: idle ", spec[0])
		_results["idle"][spec[0]] = await _measure(120, Callable())
		var step: Vector2 = Vector2(6.0, 2.0) / float(main.camera.zoom.x)
		_results["pan"][spec[0]] = await _measure(120, func(): main.camera.position += step; main.camera.view_changed.emit())

	print("bench: zoom sweeps")
	# Warm sweeps (all LODs cached) through every boundary, both directions.
	_results["zoom_sweep_out"] = await _sweep([106.85, -6.3, 25.0], 1.0 / 1.15, 120)
	_results["zoom_sweep_in_warm"] = await _sweep(national, 1.15, 120)

	# Hover / click handler cost at the dense view (explicit world points; mouse not moved).
	_set_view(dense)
	await _frames(5)
	_results["interaction"] = await _interaction()
	main.map_view.set_hovered("")
	main._tooltip.visible = false

	print("bench: screenshots")
	# Screenshots
	var shots := {"01_national_lod1": national, "02_provincial_jatim_bali_lod2": province,
		"03_dense_jabodetabek_lod3": dense, "04_islands_raja_ampat_lod3": islands,
		"05_enclave_bukittinggi_lod3": enclave, "06_true_holes_muna_lod3": lakes,
		"08a_threshold_1300mpx_lod1": [110.4, -7.0, 1300.0], "08b_threshold_1200mpx_lod2": [110.4, -7.0, 1200.0],
		"08c_threshold_190mpx_lod2": [110.4, -7.0, 190.0], "08d_threshold_185mpx_lod3": [110.4, -7.0, 185.0]}
	var lod_of := {}
	for name in shots:
		_set_view(shots[name])
		await _frames(4)
		lod_of[name] = main.map_view.active_lod
		_shot(name)
	# QA colouring: a distinct colour per region, so holes, enclaves, seams and outline spill are
	# visible (the gameplay overlays are uniform at game start). Restored afterwards.
	main.map_view.recolor(func(id): return Color.from_hsv(float(hash(id) % 997) / 997.0, 0.45, 0.88))
	var qa_shots := {"09_qa_enclave_bukittinggi_agam_lod3": [100.37, -0.3, 30.0],
		"10_qa_true_hole_muna_lod3": [122.7288, -4.8481, 4.0],
		"11_qa_enclave_kota_bogor_lod3": [106.79, -6.59, 40.0],
		"12_qa_dense_jabodetabek_lod3": dense, "13_qa_islands_seribu_lod3": [106.57, -5.75, 60.0]}
	for name in qa_shots:
		_set_view(qa_shots[name])
		await _frames(4)
		lod_of[name] = main.map_view.active_lod
		_shot(name)
	main._recolor()
	# Selected region with its information panel (enclave kota, canonical id from the registry).
	_set_view([100.37, -0.3, 60.0])
	main.map_view.set_selected("13.75")
	main.region_panel.show_region("13.75")
	await _frames(4)
	lod_of["07_selected_bukittinggi_panel"] = main.map_view.active_lod
	_shot("07_selected_bukittinggi_panel")
	_results["screenshots"] = lod_of

	var f := FileAccess.open(out_dir.path_join("map_bench.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(_results, "  "))
	f.close()
	print("map bench written: ", out_dir.path_join("map_bench.json"))
	get_tree().quit()


func _set_view(v: Array) -> void:
	main.camera.position = MapView.project_lonlat(v[0], v[1])
	main.camera.zoom = Vector2.ONE * (MapView.KM_PER_UNIT * 1000.0 / float(v[2]))
	main.camera.view_changed.emit()


func _frames(n: int) -> void:
	for _i in n:
		await RenderingServer.frame_post_draw


## Runs `n` frames, calling `each` before every frame; returns frame-time stats (ms).
func _measure(n: int, each: Callable) -> Dictionary:
	var times := PackedFloat64Array()
	var cpu := PackedFloat64Array()
	var gpu := PackedFloat64Array()
	await RenderingServer.frame_post_draw
	var last := Time.get_ticks_usec()
	for _i in n:
		if each.is_valid():
			each.call()
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid))
	return {"frames": n, "lod": main.map_view.active_lod, "frame_ms": _stats(times),
		"render_cpu_ms": _stats(cpu), "render_gpu_ms": _stats(gpu)}


## Zoom by `factor` per frame toward a fixed geographic point; records each frame's time and LOD.
func _sweep(start: Array, factor: float, max_frames: int) -> Dictionary:
	_set_view(start)
	await _frames(3)
	var rows: Array = []
	await RenderingServer.frame_post_draw
	var last := Time.get_ticks_usec()
	for _i in max_frames:
		var z: float = main.camera.zoom.x * factor
		if z > main.camera.max_zoom or z < main.camera.min_zoom:
			break
		main.camera.zoom = Vector2(z, z)
		main.camera.view_changed.emit()
		var before: String = main.map_view.active_lod
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		rows.append({"m_per_px": MapView.KM_PER_UNIT * 1000.0 / z, "lod": main.map_view.active_lod,
			"frame_ms": (now - last) / 1000.0})
		last = now
		if before != main.map_view.active_lod:
			pass
	var transitions: Array = []
	var other := PackedFloat64Array()
	for i in range(1, rows.size()):
		if rows[i].lod != rows[i - 1].lod:
			transitions.append({"from": rows[i - 1].lod, "to": rows[i].lod, "m_per_px": rows[i].m_per_px, "frame_ms": rows[i].frame_ms})
		else:
			other.append(rows[i].frame_ms)
	return {"frames": rows.size(), "transitions": transitions, "non_transition_frame_ms": _stats(other), "rows": rows}


func _interaction() -> Dictionary:
	var xf: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var size := get_viewport().get_visible_rect().size
	var hover := PackedFloat64Array()
	var pick := PackedFloat64Array()
	var hits := 0
	var ids := {}
	for gy in 20:
		for gx in 25:
			var wp: Vector2 = xf * Vector2((gx + 0.5) * size.x / 25.0, (gy + 0.5) * size.y / 20.0)
			var t0 := Time.get_ticks_usec()
			var id: String = main.map_view.region_at(wp)
			var t1 := Time.get_ticks_usec()
			main.map_view.set_hovered(id)
			main._update_tooltip(id, Vector2(100, 100))
			var t2 := Time.get_ticks_usec()
			pick.append((t1 - t0) / 1000.0)
			hover.append((t2 - t0) / 1000.0)
			if id != "":
				hits += 1
				ids[id] = true
	var click := PackedFloat64Array()
	var to_frame := PackedFloat64Array()
	for id in ids.keys().slice(0, 20):
		var t0 := Time.get_ticks_usec()
		main.map_view.set_selected(id)
		main.region_panel.show_region(id)
		var t1 := Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		click.append((t1 - t0) / 1000.0)
		to_frame.append((Time.get_ticks_usec() - t0) / 1000.0)
	main.map_view.set_selected("")
	main.region_panel.show_region("")
	main.map_view.set_hovered("")
	return {"lod": main.map_view.active_lod, "samples": hover.size(), "samples_on_a_region": hits,
		"distinct_regions": ids.size(), "region_at_ms": _stats(pick),
		"hover_handler_ms (region_at + highlight + tooltip)": _stats(hover),
		"click_handler_ms (select + region panel build)": _stats(click),
		"click_to_next_frame_ms": _stats(to_frame)}


func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(name + ".png"))


func _mem() -> Dictionary:
	return {"static_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6,
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6,
		"buffer_mem_mb": Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1e6,
		"texture_mem_mb": Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6}


func _machine() -> Dictionary:
	return {"os": OS.get_name() + " " + OS.get_version(), "cpu": OS.get_processor_name(),
		"cpu_threads": OS.get_processor_count(), "gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"godot": Engine.get_version_info().string, "screen_scale": DisplayServer.screen_get_scale(),
		"window_size": DisplayServer.window_get_size()}


static func _stats(a: PackedFloat64Array) -> Dictionary:
	if a.is_empty():
		return {"n": 0}
	var s := a.duplicate()
	s.sort()
	var sum := 0.0
	for v in s:
		sum += v
	return {"n": s.size(), "mean": sum / s.size(), "median": s[s.size() / 2],
		"p95": s[mini(s.size() - 1, int(s.size() * 0.95))], "max": s[s.size() - 1]}
