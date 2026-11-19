class_name DioramaAviation
extends Node3D
## Decorative Indonesian domestic commercial aircraft cruising between real airport hubs.
## Batched in 2 GPU draw calls (planes + twin condensation contrails); zero simulation state.
const ROUTES := [
	# Jawa - Bali - Sumatera trunk corridors
	["31.71", "35.78", 94.0, 0.04], # Jakarta - Surabaya #1
	["31.71", "35.78", 98.0, 0.54], # Jakarta - Surabaya #2
	["31.71", "51.71", 102.0, 0.18], # Jakarta - Denpasar #1
	["31.71", "51.71", 96.0, 0.68], # Jakarta - Denpasar #2
	["31.71", "12.71", 108.0, 0.12], # Jakarta - Medan
	["31.71", "16.71", 86.0, 0.35], # Jakarta - Palembang
	["31.71", "13.71", 98.0, 0.76], # Jakarta - Padang
	["31.71", "14.71", 95.0, 0.42], # Jakarta - Pekanbaru
	["31.71", "21.71", 94.0, 0.88], # Jakarta - Batam
	["31.71", "34.71", 82.0, 0.27], # Jakarta - Yogyakarta
	["12.71", "11.71", 88.0, 0.61], # Medan - Banda Aceh
	["12.71", "21.71", 90.0, 0.09], # Medan - Batam
	["16.71", "21.71", 88.0, 0.52], # Palembang - Batam
	# Jawa - Kalimantan - Sulawesi bridges
	["31.71", "61.71", 94.0, 0.31], # Jakarta - Pontianak
	["31.71", "64.71", 106.0, 0.71], # Jakarta - Balikpapan
	["31.71", "63.71", 98.0, 0.15], # Jakarta - Banjarmasin
	["35.78", "64.71", 96.0, 0.47], # Surabaya - Balikpapan
	["35.78", "63.71", 88.0, 0.83], # Surabaya - Banjarmasin
	["35.78", "73.71", 98.0, 0.22], # Surabaya - Makassar
	["61.71", "64.71", 94.0, 0.65], # Pontianak - Balikpapan
	# Kawasan Timur Indonesia (Bali, NTT, Sulawesi, Maluku, Papua)
	["31.71", "73.71", 110.0, 0.44], # Jakarta - Makassar
	["51.71", "73.71", 92.0, 0.79], # Denpasar - Makassar
	["51.71", "53.71", 94.0, 0.14], # Denpasar - Kupang
	["73.71", "71.71", 98.0, 0.38], # Makassar - Manado
	["73.71", "72.71", 88.0, 0.91], # Makassar - Palu
	["73.71", "74.71", 84.0, 0.58], # Makassar - Kendari
	["73.71", "81.71", 102.0, 0.05], # Makassar - Ambon
	["73.71", "92.71", 108.0, 0.49], # Makassar - Sorong
	["71.71", "82.71", 86.0, 0.72], # Manado - Ternate
	["81.71", "91.71", 106.0, 0.28], # Ambon - Jayapura
	["92.71", "91.71", 100.0, 0.67], # Sorong - Jayapura
	["64.71", "71.71", 98.0, 0.19], # Balikpapan - Manado
]

var materials: Array[ShaderMaterial] = []
var plane_count := 0
var _reduced := false


func build(art_config: Dictionary, region_ids: PackedStringArray) -> void:
	var anchors: Dictionary = {}
	for prop in art_config.get("props", []):
		if str(prop.get("role", "")).ends_with("_core"):
			var idx := int(prop.region)
			if idx >= 0 and idx < region_ids.size():
				anchors[region_ids[idx]] = Vector2(float(prop.x), float(prop.z))

	var valid_routes: Array = []
	for spec in ROUTES:
		var a_id: String = spec[0]
		var b_id: String = spec[1]
		if anchors.has(a_id) and anchors.has(b_id):
			valid_routes.append({
				"a": anchors[a_id] as Vector2,
				"b": anchors[b_id] as Vector2,
				"alt": float(spec[2]),
				"phase": float(spec[3]),
			})
	if valid_routes.is_empty():
		return
	plane_count = valid_routes.size()

	var plane_mesh := _build_jetliner_mesh()
	var plane_mat := ShaderMaterial.new()
	plane_mat.shader = load("res://src/map/diorama_plane.gdshader")
	plane_mesh.surface_set_material(0, plane_mat)
	materials.append(plane_mat)

	var trail_mesh := _build_contrail_mesh()
	var trail_mat := ShaderMaterial.new()
	trail_mat.shader = load("res://src/map/diorama_contrail.gdshader")
	trail_mesh.surface_set_material(0, trail_mat)
	materials.append(trail_mat)

	var p_mm := MultiMesh.new()
	p_mm.transform_format = MultiMesh.TRANSFORM_3D
	p_mm.use_custom_data = true
	p_mm.mesh = plane_mesh
	p_mm.instance_count = plane_count

	var t_mm := MultiMesh.new()
	t_mm.transform_format = MultiMesh.TRANSFORM_3D
	t_mm.use_custom_data = true
	t_mm.mesh = trail_mesh
	t_mm.instance_count = plane_count

	for i in plane_count:
		var r: Dictionary = valid_routes[i]
		var pa: Vector2 = r.a
		var pb: Vector2 = r.b
		var mid := (pa + pb) * 0.5
		var delta := pb - pa
		var dist := maxf(delta.length(), 48.0)
		var half_len := dist * 0.5
		var heading := atan2(delta.x, delta.y)
		var xform := Transform3D(Basis(Vector3.UP, heading), Vector3(mid.x, float(r.alt), mid.y))

		# Cruise at realistic ~36..44 wu/s regardless of route length
		var cruise_speed := 38.0 + float(i % 5) * 2.2
		var omega := clampf(cruise_speed / maxf(half_len, 60.0), 0.035, 0.22)
		var custom := Color(
			clampf(half_len / 1200.0, 0.02, 1.0),
			float(r.phase),
			clampf(omega / 0.25, 0.05, 1.0),
			float(i % 11) / 11.0
		)
		p_mm.set_instance_transform(i, xform)
		p_mm.set_instance_custom_data(i, custom)
		t_mm.set_instance_transform(i, xform)
		t_mm.set_instance_custom_data(i, custom)

	var p_inst := MultiMeshInstance3D.new()
	p_inst.name = "PesawatKomersial"
	p_inst.multimesh = p_mm
	p_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p_inst.extra_cull_margin = 1400.0
	add_child(p_inst)

	var t_inst := MultiMeshInstance3D.new()
	t_inst.name = "JejakKondensasi"
	t_inst.multimesh = t_mm
	t_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t_inst.extra_cull_margin = 1400.0
	add_child(t_inst)


func _build_jetliner_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var body_white := Color(0.95, 0.96, 0.98)
	var wing_silver := Color(0.82, 0.85, 0.89)
	var cockpit_dark := Color(0.14, 0.20, 0.28)
	var engine_metal := Color(0.42, 0.46, 0.52)
	var accent_marker := Color(1.0, 0.0, 1.0) # Replaced per-instance in shader with carrier livery accent

	# 1. Fuselage tapered octagonal tube along Z (nose +5.2 -> tail -5.2)
	var rings := [
		[5.2, 0.0, 0.08, body_white],
		[4.1, 0.56, 0.16, cockpit_dark],
		[2.8, 0.78, 0.34, body_white],
		[-2.4, 0.76, 0.34, body_white],
		[-4.2, 0.44, 0.48, body_white],
		[-5.2, 0.10, 0.62, accent_marker],
	]
	var sides := 8
	for ri in rings.size() - 1:
		var z0: float = rings[ri][0]
		var r0: float = rings[ri][1]
		var y0: float = rings[ri][2]
		var z1: float = rings[ri + 1][0]
		var r1: float = rings[ri + 1][1]
		var y1: float = rings[ri + 1][2]
		var c1: Color = rings[ri + 1][3]
		for s in sides:
			var a0 := TAU * float(s) / float(sides)
			var a1 := TAU * float(s + 1) / float(sides)
			var p00 := Vector3(cos(a0) * r0, sin(a0) * r0 + y0, z0)
			var p01 := Vector3(cos(a1) * r0, sin(a1) * r0 + y0, z0)
			var p10 := Vector3(cos(a0) * r1, sin(a0) * r1 + y1, z1)
			var p11 := Vector3(cos(a1) * r1, sin(a1) * r1 + y1, z1)
			var use_cockpit := (ri == 1 and sin((a0 + a1) * 0.5) > 0.15)
			var col_tri := cockpit_dark if use_cockpit else (c1 if ri >= 4 else body_white)
			_add_quad(st, p00, p01, p11, p10, col_tri)

	# 2. Swept main wings (left & right with slight dihedral & upturned winglets)
	for side: float in [-1.0, 1.0]:
		var root_f := Vector3(side * 0.62, 0.15, 1.35)
		var root_b := Vector3(side * 0.62, 0.12, -1.25)
		var tip_f := Vector3(side * 5.65, 0.52, -1.55)
		var tip_b := Vector3(side * 5.65, 0.48, -2.55)
		var thick := Vector3(0.0, 0.16, 0.0)
		var flip: bool = side < 0.0
		_add_quad(st, root_f + thick, tip_f + thick, tip_b + thick, root_b + thick, wing_silver, flip)
		_add_quad(st, root_b, tip_b, tip_f, root_f, wing_silver, flip)
		_add_quad(st, root_f, tip_f, tip_f + thick, root_f + thick, wing_silver, flip)
		# Winglet accent
		var wl_top_f := tip_f + Vector3(side * 0.25, 0.85, -0.25)
		var wl_top_b := tip_b + Vector3(side * 0.25, 0.82, -0.15)
		_add_quad(st, tip_f + thick, wl_top_f, wl_top_b, tip_b + thick, accent_marker, flip)

		# Underwing turbofan engine nacelle
		var ex: float = side * 2.35
		var ey := -0.22
		var ez_f := 0.72
		var ez_b := -0.78
		var er := 0.34
		for k in 6:
			var a0 := TAU * float(k) / 6.0
			var a1 := TAU * float(k + 1) / 6.0
			var e00 := Vector3(ex + cos(a0) * er, ey + sin(a0) * er, ez_f)
			var e01 := Vector3(ex + cos(a1) * er, ey + sin(a1) * er, ez_f)
			var e10 := Vector3(ex + cos(a0) * er * 0.82, ey + sin(a0) * er * 0.82, ez_b)
			var e11 := Vector3(ex + cos(a1) * er * 0.82, ey + sin(a1) * er * 0.82, ez_b)
			_add_quad(st, e00, e01, e11, e10, engine_metal)

		# Horizontal tail stabilizer
		var hr_f := Vector3(side * 0.28, 0.55, -3.55)
		var hr_b := Vector3(side * 0.22, 0.55, -4.85)
		var ht_f := Vector3(side * 2.25, 0.70, -4.55)
		var ht_b := Vector3(side * 2.25, 0.68, -5.25)
		_add_quad(st, hr_f, ht_f, ht_b, hr_b, wing_silver, flip)

	# 3. Tall swept vertical tail fin (carrier livery accent!)
	var tf_rf := Vector3(0.0, 0.62, -2.75)
	var tf_rb := Vector3(0.0, 0.58, -4.95)
	var tf_tf := Vector3(0.0, 2.75, -4.45)
	var tf_tb := Vector3(0.0, 2.70, -5.45)
	var fin_w := Vector3(0.11, 0.0, 0.0)
	_add_quad(st, tf_rf + fin_w, tf_tf + fin_w, tf_tb + fin_w, tf_rb + fin_w, accent_marker)
	_add_quad(st, tf_rb - fin_w, tf_tb - fin_w, tf_tf - fin_w, tf_rf - fin_w, accent_marker)
	_add_quad(st, tf_rf - fin_w, tf_rf + fin_w, tf_tf + fin_w, tf_tf - fin_w, accent_marker)

	st.generate_normals()
	return st.commit()


func _add_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, flip: bool = false) -> void:
	if flip:
		st.set_color(col); st.add_vertex(a)
		st.set_color(col); st.add_vertex(d)
		st.set_color(col); st.add_vertex(c)
		st.set_color(col); st.add_vertex(a)
		st.set_color(col); st.add_vertex(c)
		st.set_color(col); st.add_vertex(b)
	else:
		st.set_color(col); st.add_vertex(a)
		st.set_color(col); st.add_vertex(b)
		st.set_color(col); st.add_vertex(c)
		st.set_color(col); st.add_vertex(a)
		st.set_color(col); st.add_vertex(c)
		st.set_color(col); st.add_vertex(d)


func _build_contrail_mesh() -> ArrayMesh:
	var hw := 5.6
	var z_start := -1.4
	var z_end := -46.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-hw, -0.1, z_start))
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(hw, -0.1, z_start))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(hw * 1.45, -0.1, z_end))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-hw, -0.1, z_start))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(hw * 1.45, -0.1, z_end))
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(-hw * 1.45, -0.1, z_end))
	return st.commit()


func set_reduced_motion(reduced: bool) -> void:
	if reduced == _reduced:
		return
	_reduced = reduced
	var m := 0.0 if reduced else 1.0
	for mat in materials:
		mat.set_shader_parameter("motion", m)


func sync_atmosphere(params: Dictionary) -> void:
	for mat in materials:
		for k in ["sun_dir", "sun_color", "ambient_color", "fog_color", "fog_density", "night_factor", "rain_factor", "drought_factor"]:
			if params.has(k):
				mat.set_shader_parameter(k, params[k])
