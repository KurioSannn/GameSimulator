class_name DioramaWeatherFX
extends Node3D
## 3D Seasonal & Disaster Visual Effects (rain streaks, flood ripples, wildfire flames & smoke plumes).
## Pure visual layer reacting to simulation month/cases/hotspots or preview overrides; zero sim state.
const MAX_FLOOD_MARKERS := 64
const MAX_FIRE_CLUSTERS := 72
const MAX_TRAFFIC_MARKERS := 48
const MAX_QUAKE_MARKERS := 24
const RAIN_STREAK_COUNT := 560

var materials: Array[ShaderMaterial] = []
var _rain_mat: ShaderMaterial
var _flood_mat: ShaderMaterial
var _fire_mat: ShaderMaterial
var _smoke_mat: ShaderMaterial
var _traffic_mat: ShaderMaterial
var _quake_mat: ShaderMaterial

var _rain_mm: MultiMesh
var _flood_mm: MultiMesh
var _fire_mm: MultiMesh
var _smoke_mm: MultiMesh
var _traffic_mm: MultiMesh
var _quake_mm: MultiMesh

var _region_anchors: Dictionary = {}  # region_id -> Vector2(x, z)
var _last_sig := ""


func build(art_config: Dictionary, region_ids: PackedStringArray) -> void:
	for prop in art_config.get("props", []):
		if str(prop.get("role", "")).ends_with("_core"):
			var idx := int(prop.region)
			if idx >= 0 and idx < region_ids.size():
				_region_anchors[region_ids[idx]] = Vector2(float(prop.x), float(prop.z))

	_build_rain_batch(art_config.get("field_bounds", [-2540.0, -847.0, 5080.0, 2188.0]))
	_build_flood_batch()
	_build_fire_and_smoke_batches()
	_build_traffic_and_quake_batches()


func _build_crossed_vertical_quad(w: float, h: float) -> ArrayMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(quad, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, h * 0.5, 0.0)))
	st.append_from(quad, 0, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.0, h * 0.5, 0.0)))
	return st.commit()


func _build_flat_card(w: float, h: float) -> ArrayMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(quad, 0, Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), Vector3.ZERO))
	return st.commit()


func _make_batch(mesh: Mesh, count: int, fx_mode: int, cull: float) -> Dictionary:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/map/diorama_hazard.gdshader")
	mat.set_shader_parameter("fx_mode", fx_mode)
	mat.set_shader_parameter("intensity", 0.0)
	mesh.surface_set_material(0, mat)
	materials.append(mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = count
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = cull
	add_child(inst)
	return {"mat": mat, "mm": mm, "inst": inst}


func _build_rain_batch(bounds: Array) -> void:
	var mesh := _build_crossed_vertical_quad(1.6, 26.0)
	var b := _make_batch(mesh, RAIN_STREAK_COUNT, 0, 260.0)
	_rain_mat = b.mat
	_rain_mm = b.mm
	var x0 := float(bounds[0]) + 180.0
	var z0 := float(bounds[1]) + 120.0
	var w := float(bounds[2]) - 360.0
	var h := float(bounds[3]) - 240.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261120
	for i in RAIN_STREAK_COUNT:
		var rx := x0 + rng.randf() * w
		var rz := z0 + rng.randf() * h
		var basis := Basis(Vector3.FORWARD, 0.17).scaled(Vector3.ONE * rng.randf_range(0.85, 1.4))
		_rain_mm.set_instance_transform(i, Transform3D(basis, Vector3(rx, 0.0, rz)))
		_rain_mm.set_instance_custom_data(i, Color(0.0, rng.randf(), rng.randf(), 1.0))


func _build_flood_batch() -> void:
	var mesh := _build_flat_card(44.0, 44.0)
	var b := _make_batch(mesh, MAX_FLOOD_MARKERS, 1, 90.0)
	_flood_mat = b.mat
	_flood_mm = b.mm
	_flood_mm.visible_instance_count = 0


func _build_fire_and_smoke_batches() -> void:
	var fire_mesh := _build_crossed_vertical_quad(14.0, 18.0)
	var fb := _make_batch(fire_mesh, MAX_FIRE_CLUSTERS, 2, 120.0)
	_fire_mat = fb.mat
	_fire_mm = fb.mm
	_fire_mm.visible_instance_count = 0

	var smoke_mesh := QuadMesh.new()
	smoke_mesh.size = Vector2(54.0, 44.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(smoke_mesh, 0, Transform3D(Basis.from_euler(Vector3(-0.65, 0.0, 0.0)), Vector3(0.0, 8.0, 0.0)))
	st.append_from(smoke_mesh, 0, Transform3D(Basis.from_euler(Vector3(-0.65, 1.05, 0.0)), Vector3(4.0, 14.0, -3.0)))
	var sb := _make_batch(st.commit(), MAX_FIRE_CLUSTERS, 3, 160.0)
	_smoke_mat = sb.mat
	_smoke_mm = sb.mm
	_smoke_mm.visible_instance_count = 0


func _build_traffic_and_quake_batches() -> void:
	var t_mesh := _build_flat_card(48.0, 48.0)
	var tb := _make_batch(t_mesh, MAX_TRAFFIC_MARKERS, 4, 90.0)
	_traffic_mat = tb.mat
	_traffic_mm = tb.mm
	_traffic_mm.visible_instance_count = 0

	var q_mesh := _build_flat_card(74.0, 74.0)
	var qb := _make_batch(q_mesh, MAX_QUAKE_MARKERS, 5, 110.0)
	_quake_mat = qb.mat
	_quake_mm = qb.mm
	_quake_mm.visible_instance_count = 0


func update_hazards(flood_ids: Array, fire_ids: Array, traffic_ids: Array = [], quake_ids: Array = []) -> void:
	var sig := "%s|%s|%s|%s" % [
		",".join(PackedStringArray(flood_ids)),
		",".join(PackedStringArray(fire_ids)),
		",".join(PackedStringArray(traffic_ids)),
		",".join(PackedStringArray(quake_ids)),
	]
	if sig == _last_sig:
		return
	_last_sig = sig

	var f_idx := 0
	for rid in flood_ids:
		if f_idx >= MAX_FLOOD_MARKERS:
			break
		if _region_anchors.has(rid):
			var p: Vector2 = _region_anchors[rid]
			_flood_mm.set_instance_transform(f_idx, Transform3D(Basis.IDENTITY, Vector3(p.x, 0.72, p.y)))
			_flood_mm.set_instance_custom_data(f_idx, Color(0.0, float(f_idx % 13) / 13.0, 1.0, 1.0))
			f_idx += 1
	_flood_mm.visible_instance_count = f_idx

	var c_idx := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261121
	for rid in fire_ids:
		if not _region_anchors.has(rid):
			continue
		var center: Vector2 = _region_anchors[rid]
		# Cluster 3 wildfire flames + smoke plumes per affected peatland/forest district
		for sub in 3:
			if c_idx >= MAX_FIRE_CLUSTERS:
				break
			var ox := rng.randf_range(-12.0, 12.0)
			var oz := rng.randf_range(-10.0, 10.0)
			var scl := rng.randf_range(0.75, 1.35)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * scl), Vector3(center.x + ox, 0.5, center.y + oz))
			_fire_mm.set_instance_transform(c_idx, xf)
			_fire_mm.set_instance_custom_data(c_idx, Color(0.0, rng.randf(), rng.randf(), 1.0))
			var sx := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * (scl * 1.15)), Vector3(center.x + ox, 9.0, center.y + oz))
			_smoke_mm.set_instance_transform(c_idx, sx)
			_smoke_mm.set_instance_custom_data(c_idx, Color(0.0, rng.randf(), rng.randf(), 1.0))
			c_idx += 1
	_fire_mm.visible_instance_count = c_idx
	_smoke_mm.visible_instance_count = c_idx

	var t_idx := 0
	for rid in traffic_ids:
		if t_idx >= MAX_TRAFFIC_MARKERS:
			break
		if _region_anchors.has(rid):
			var p: Vector2 = _region_anchors[rid]
			var rot := (float(t_idx) * 0.45)
			_traffic_mm.set_instance_transform(t_idx, Transform3D(Basis(Vector3.UP, rot), Vector3(p.x, 0.76, p.y)))
			_traffic_mm.set_instance_custom_data(t_idx, Color(0.0, float(t_idx % 9) / 9.0, 1.0, 1.0))
			t_idx += 1
	_traffic_mm.visible_instance_count = t_idx

	var q_idx := 0
	for rid in quake_ids:
		if q_idx >= MAX_QUAKE_MARKERS:
			break
		if _region_anchors.has(rid):
			var p: Vector2 = _region_anchors[rid]
			_quake_mm.set_instance_transform(q_idx, Transform3D(Basis.IDENTITY, Vector3(p.x, 0.82, p.y)))
			_quake_mm.set_instance_custom_data(q_idx, Color(0.0, float(q_idx % 7) / 7.0, 1.0, 1.0))
			q_idx += 1
	_quake_mm.visible_instance_count = q_idx


func sync(rain_intensity: float, flood_intensity: float, fire_intensity: float, reduced: bool, landscape: bool, fog_col: Color, fog_dens: float, traffic_intensity: float = 0.0, quake_intensity: float = 0.0) -> void:
	visible = landscape
	var m := 0.0 if reduced else 1.0
	for mat in materials:
		mat.set_shader_parameter("motion", m)
		mat.set_shader_parameter("fog_color", fog_col)
		mat.set_shader_parameter("fog_density", fog_dens)
	_rain_mat.set_shader_parameter("intensity", rain_intensity)
	_flood_mat.set_shader_parameter("intensity", flood_intensity)
	_fire_mat.set_shader_parameter("intensity", fire_intensity)
	_smoke_mat.set_shader_parameter("intensity", fire_intensity)
	_traffic_mat.set_shader_parameter("intensity", traffic_intensity)
	_quake_mat.set_shader_parameter("intensity", quake_intensity)
