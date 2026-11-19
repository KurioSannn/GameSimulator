class_name QaDiorama
extends Node
## Windowed visual/input QA of the remake, with no simulation mutations or player-save writes.
var main: Node
var out_dir := ""
var checks: Array = []
var _errors := ErrorLog.new()


class ErrorLog extends Logger:
	var entries: Array = []
	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String,
			_editor_notify: bool, kind: int, _backtrace: Array[ScriptBacktrace]) -> void:
		if kind != ERROR_TYPE_WARNING:
			entries.append(rationale if rationale != "" else code)


func run() -> void:
	OS.add_logger(_errors)
	get_tree().create_timer(90).timeout.connect(func(): get_tree().quit(2))
	DirAccess.make_dir_recursive_absolute(out_dir)
	main.case_modal.hide()
	main.get_window().mode = Window.MODE_WINDOWED
	main.get_window().size = Vector2i(1600, 900)
	var before := _world_hash()
	if not main._mode_3d:
		main._toggle_3d_mode()
	main._fit_home()
	await _frames(30)
	main._toast.hide()
	main._toast.get_parent().hide()
	_check(main.map_view_3d.region_ids.size() == 514, "all canonical regions remain in 3D")
	_check(main.map_view_3d._props.prop_count == main.map_view_3d._art_config.props.size(), "all generated decorative props render")
	_check(main.map_view_3d._props.model_count == 121 and main.map_view_3d._props.batches.size() >= 121, "121 land model variants render as mesh batches")
	_check(main.map_view_3d._maritime.vessel_count == 136 and main.map_view_3d._maritime.model_count == 8, "136 maritime vessels across 8 watercraft models render")
	_check(main.map_view_3d._atmosphere.cluster_count == 120 and main.map_view_3d._atmosphere.high_cluster_count == 64, "184 varied cloud clusters render")
	_check(main.map_view_3d._neighbor_mesh != null and main.map_view_3d._neighbor_props != null and main.map_view_3d._neighbor_props.prop_count >= 1500 and main.map_view_3d._weather_fx != null, "neighbor backdrop, neighbor trees and seasonal/disaster weather FX built")
	_check(main.map_view_3d._roads != null and main.map_view_3d._roads.national_line_count >= 3000 and main.map_view_3d._roads.toll_line_count >= 140,
		"official Indonesian Jalan Nasional and Jalan Tol ribbons render in 3D")
	_check(main.map_view_3d._aviation != null and main.map_view_3d._aviation.plane_count >= 30,
		"Indonesian domestic commercial aircraft and contrails render in 3D")
	_check(main.map_view_3d._province_labels.size() == 38,
		"all 38 official Indonesian province labels render on regional zoom")
	# Camera safe zone & zoom clamp verification
	main.camera_3d.target = Vector3(20000.0, 0.0, -20000.0)
	main.camera_3d._clamp_target()
	_check(absf(main.camera_3d.target.x) < 2350.0 and main.camera_3d.max_distance <= 3200.0 and main.camera_3d.min_distance >= 120.0,
		"camera zoom bounds and archipelago safe zone clamp pan targets")
	main._fit_home()
	await _frames(8)
	_check(main.map_view_3d._case_pins.size() == 1, "pending case creates a location marker")
	await _shot("01_national")
	var frame_ms: Array[float] = []
	for n in 90:
		var start := Time.get_ticks_usec()
		await get_tree().process_frame
		frame_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	frame_ms.sort()
	main._view_province("31")
	main.camera_3d.distance = 480.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(10)
	await _shot("02b_jabodetabek")
	main._view_province("35")
	await _frames(12)
	await _shot("02_jawa_timur")
	# Independently resolve interior city anchor and pick through the actual 3D camera.
	var config: Dictionary = main.map_view_3d._art_config
	var anchor := Vector2.ZERO
	for prop in config.props:
		if prop.role == "city_core" and main.map_view.region_ids[int(prop.region)] == "35.78":
			anchor = Vector2(prop.x, prop.z)
			break
	main.camera_3d.target = Vector3(anchor.x, 0, anchor.y)
	main.camera_3d.distance = 540.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(10)
	var screen: Vector2 = main.camera_3d.unproject_position(Vector3(anchor.x, 0, anchor.y))
	var picked: String = main.map_view_3d.region_at_ray(main.camera_3d, screen)
	_check(picked == "35.78", "3D camera picking returns canonical Surabaya")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = screen
		click.global_position = screen
		get_viewport().push_input(click, true)
		await _frames(2)
	await _frames(25)
	_check(main.region_panel._model.name == "Kota Surabaya", "3D selection opens the matching data context")
	_check(main.map_view_3d.selected_id() == "35.78", "actual mouse click selects the 3D region")
	await _shot("03_surabaya")
	main.camera_3d.distance = 155.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(8)
	await get_tree().create_timer(0.4).timeout
	var selected_index: int = main.map_view_3d.region_ids.find("35.78")
	_check(main.map_view_3d._props.materials.all(func(m):
		return (m.get_shader_parameter("selected_region") == selected_index
			and is_equal_approx(float(m.get_shader_parameter("selected_lift")), main.map_view_3d._selected_lift))),
		"all prop batches follow the selected region lift")
	await _shot("03b_settlement_detail")
	var close_ms: Array[float] = []
	for n in 60:
		var start := Time.get_ticks_usec()
		await get_tree().process_frame
		close_ms.append(float(Time.get_ticks_usec() - start) / 1000.0)
	close_ms.sort()
	UiPreferences.values.reduce_motion = true
	main.map_view_3d._apply_selected_lift(main.map_view_3d._target_selected_lift)
	await _frames(3)
	_check(main.map_view_3d._water_material.get_shader_parameter("motion") == 0.0, "reduced motion freezes water")
	_check(main.map_view_3d._mat_fill.get_shader_parameter("motion") == 0.0
		and main.map_view_3d._atmosphere.material.get_shader_parameter("motion") == 0.0
		and main.map_view_3d._atmosphere.high_material.get_shader_parameter("motion") == 0.0
		and main.map_view_3d._atmosphere.veil_material.get_shader_parameter("motion") == 0.0,
		"reduced motion freezes cloud clusters, sky veil and ground shadows")
	_check(main.map_view_3d._props.materials.all(func(m): return m.get_shader_parameter("motion") == 0.0)
		and (main.map_view_3d._neighbor_props == null or main.map_view_3d._neighbor_props.materials.all(func(m): return m.get_shader_parameter("motion") == 0.0))
		and (main.map_view_3d._roads == null or main.map_view_3d._roads.materials.all(func(m): return m.get_shader_parameter("motion") == 0.0))
		and (main.map_view_3d._aviation == null or main.map_view_3d._aviation.materials.all(func(m): return m.get_shader_parameter("motion") == 0.0))
		and main.map_view_3d._maritime.materials.all(func(m): return m.get_shader_parameter("motion") == 0.0)
		and main.map_view_3d._weather_fx.materials.all(func(m): return m.get_shader_parameter("motion") == 0.0)
		and main.map_view_3d._atmosphere.cirrus_material.get_shader_parameter("motion") == 0.0,
		"reduced motion freezes vegetation, neighbor trees, roads, buildings, vessels, wakes, cirrus and weather FX")
	# Visual captures across Time-of-Day, Coastlines, Neighbors & Hazard modes
	UiPreferences.values.reduce_motion = false
	main.map_view_3d.set_time_mode("siang")
	main.map_view_3d.set_weather_mode("sim")
	main.camera_3d.target = Vector3(-120.0, 0.0, -340.0) # Northern frontier: Sabah, Malaysia, Brunei, Philippines, Anambas/Sangihe
	main.camera_3d.distance = 1120.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(10)
	await _shot("09_northern_neighbors")

	# Close-up of small island coast + surrounding water/ships (Kepulauan Anambas 21.05 or Sangihe 71.03)
	var island_anchor := Vector2(-1170.0, -300.0)
	for prop in config.props:
		if str(prop.role).ends_with("_core") and main.map_view.region_ids[int(prop.region)] == "21.05":
			island_anchor = Vector2(prop.x, prop.z)
			break
	main.camera_3d.target = Vector3(island_anchor.x, 0.0, island_anchor.y)
	main.camera_3d.distance = 165.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(12)
	await _shot("10_small_islands_closeup")

	main.map_view_3d.set_time_mode("siang")
	main.map_view_3d.set_weather_mode("bencana")
	main._view_province("31")
	main.camera_3d.distance = 520.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(12)
	await _shot("11_bencana_macet")

	main.map_view_3d.set_time_mode("sore")
	main.map_view_3d.set_weather_mode("kebakaran")
	main.camera_3d.target = Vector3(-420.0, 0.0, 120.0) # Kalimantan Tengah & Jawa overview
	main.camera_3d.distance = 1050.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(8)
	await _shot("06_sore_kebakaran")
	main.map_view_3d.set_time_mode("malam")
	main.map_view_3d.set_weather_mode("sim")
	main._view_province("31")
	main.camera_3d.distance = 480.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(8)
	await _shot("07_malam_jakarta")
	main.map_view_3d.set_time_mode("pagi")
	main.map_view_3d.set_weather_mode("hujan")
	main.camera_3d.distance = 680.0
	main.camera_3d._apply_transform()
	main.camera_3d.view_changed.emit()
	await _frames(8)
	await _shot("08_pagi_hujan")
	main.map_view_3d.set_time_mode("siang")
	main.map_view_3d.set_weather_mode("sim")
	UiPreferences.values.reduce_motion = true
	await _frames(4)
	main._set_overlay(Overlays.DEFS[2])
	await _frames(5)
	_check(not main.map_view_3d._props.visible and (main.map_view_3d._neighbor_props == null or not main.map_view_3d._neighbor_props.visible) and (main.map_view_3d._roads == null or not main.map_view_3d._roads.visible) and (main.map_view_3d._aviation == null or not main.map_view_3d._aviation.visible) and not main.map_view_3d._maritime.visible and not main.map_view_3d._weather_fx.visible and not main.map_view_3d.landscape,
		"analytical layers hide decorative land, neighbor, road, aviation, maritime and weather props")
	_check(main.hud.layer_select.selected == 2, "layer menu matches displayed data")
	await _shot("04_analytical")
	main.region_panel.show_region("")
	main._toggle_3d_mode()
	await _frames(8)
	_check(main.map_view.visible and not main.map_view_3d.visible, "2D cartographic mode remains available")
	main._set_overlay(Overlays.DEFS[0])
	main._fit_home()
	await _frames(8)
	await _shot("05_2d")
	_check(before == _world_hash(), "rendering, picking and overlays leave world/RNG unchanged")
	var passed := checks.all(func(item): return item.ok) and _errors.entries.is_empty()
	var file := FileAccess.open(out_dir.path_join("qa.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "checks": checks, "runtime_errors": _errors.entries,
		"props": main.map_view_3d._props.prop_count, "vessels": main.map_view_3d._maritime.vessel_count,
		"batches": main.map_view_3d._props.batches.size(), "maritime_batches": main.map_view_3d._maritime.batches.size(),
		"window": str(main.get_window().size), "frame_median_ms": frame_ms[45], "frame_p95_ms": frame_ms[85],
		"close_frame_median_ms": close_ms[30], "close_frame_p95_ms": close_ms[57],
		"cloud_clusters": main.map_view_3d._atmosphere.cluster_count,
		"high_cloud_clusters": main.map_view_3d._atmosphere.high_cluster_count,
		"counts": main.map_view_3d._art_config.counts,
		"renderer": RenderingServer.get_current_rendering_method(), "device": RenderingServer.get_video_adapter_name()}, "  "))
	file.close()
	for check in checks:
		print("DIORAMA %s: %s" % ["PASS" if check.ok else "FAIL", check.label])
	get_tree().quit(0 if passed else 1)


func _check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "label": label})


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _world_hash() -> String:
	return JSON.stringify(Game.world.to_dict(), "", true, true).sha256_text()
