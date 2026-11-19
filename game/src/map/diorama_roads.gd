class_name DioramaRoads
extends Node3D
## Offline real Indonesian road network (Jalan Nasional Bina Marga & Jalan Tol Operasi BPJT)
## rendered as 2 distance-adaptive 3D highway ribbon batches with animated carriageway traffic.
var materials: Array[ShaderMaterial] = []
var national_mesh_inst: MeshInstance3D
var toll_mesh_inst: MeshInstance3D

var national_line_count := 0
var national_point_count := 0
var toll_line_count := 0
var toll_point_count := 0
var total_km := 0.0
var _reduced := false


func build() -> bool:
	var meta_path := "res://data/map/art/indonesia_roads.json"
	var bin_path := "res://data/map/art/indonesia_roads.bin"
	if not FileAccess.file_exists(meta_path) or not FileAccess.file_exists(bin_path):
		return false
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if not (meta is Dictionary):
		return false
	var raw := FileAccess.get_file_as_bytes(bin_path)
	if raw.is_empty():
		return false
	var sections: Dictionary = meta.get("bin", {}).get("sections", {})

	var nat_pos := _read_f32(raw, sections["national_positions"])
	var nat_rng := _read_i32(raw, sections["national_ranges"])
	var tol_pos := _read_f32(raw, sections["toll_positions"])
	var tol_rng := _read_i32(raw, sections["toll_ranges"])

	national_point_count = nat_pos.size() / 2
	national_line_count = nat_rng.size() / 2
	toll_point_count = tol_pos.size() / 2
	toll_line_count = tol_rng.size() / 2
	var stats: Dictionary = meta.get("stats", {})
	total_km = float(stats.get("national_km_approx", 0.0)) + float(stats.get("toll_km_approx", 0.0))

	national_mesh_inst = _build_ribbon_node("JalanNasional", nat_pos, nat_rng, 0.09, false, 0.68, 2.35)
	toll_mesh_inst = _build_ribbon_node("JalanTolOperasi", tol_pos, tol_rng, 0.14, true, 1.05, 2.65)
	return true


func _read_f32(raw: PackedByteArray, sec: Dictionary) -> PackedFloat32Array:
	var off := int(sec.offset)
	var byte_len := int(sec.bytes)
	if byte_len <= 0:
		return PackedFloat32Array()
	return raw.slice(off, off + byte_len).to_float32_array()


func _read_i32(raw: PackedByteArray, sec: Dictionary) -> PackedInt32Array:
	var off := int(sec.offset)
	var byte_len := int(sec.bytes)
	if byte_len <= 0:
		return PackedInt32Array()
	return raw.slice(off, off + byte_len).to_int32_array()


func _build_ribbon_node(
	node_name: String,
	pos: PackedFloat32Array,
	rng: PackedInt32Array,
	y_base: float,
	is_toll: bool,
	base_half_w: float,
	far_scale: float
) -> MeshInstance3D:
	var line_count := rng.size() / 2
	var total_pts := pos.size() / 2
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var indices := PackedInt32Array()

	verts.resize(total_pts * 2)
	norms.resize(total_pts * 2)
	uvs.resize(total_pts * 2)
	uv2s.resize(total_pts * 2)

	var v_cursor := 0
	for li in line_count:
		var start_idx := rng[li * 2]
		var count := rng[li * 2 + 1]
		if count < 2:
			continue

		var cum_dist := 0.0
		var line_v0 := v_cursor
		for k in count:
			var pi := (start_idx + k) * 2
			var px := pos[pi]
			var pz := pos[pi + 1]

			var t_prev := Vector2.ZERO
			var t_next := Vector2.ZERO
			if k > 0:
				var prev_i := (start_idx + k - 1) * 2
				var d := Vector2(px - pos[prev_i], pz - pos[prev_i + 1])
				var seg_len := d.length()
				cum_dist += seg_len
				if seg_len > 1e-6:
					t_prev = d / seg_len
			if k < count - 1:
				var next_i := (start_idx + k + 1) * 2
				var d2 := Vector2(pos[next_i] - px, pos[next_i + 1] - pz)
				var seg_len2 := d2.length()
				if seg_len2 > 1e-6:
					t_next = d2 / seg_len2

			var n_prev := Vector2(-t_prev.y, t_prev.x)
			var n_next := Vector2(-t_next.y, t_next.x)
			var miter := Vector2.ZERO
			if k == 0:
				miter = n_next
			elif k == count - 1:
				miter = n_prev
			else:
				var avg := n_prev + n_next
				var avg_len := avg.length()
				if avg_len < 0.25:
					miter = n_next if n_next.length_squared() > 0.0 else n_prev
				else:
					var unit_m := avg / avg_len
					var denom := maxf(unit_m.dot(n_prev), 0.45)
					miter = unit_m * minf(1.0 / denom, 1.55)

			var center := Vector3(px, y_base, pz)
			verts[v_cursor] = center
			norms[v_cursor] = Vector3.UP
			uvs[v_cursor] = Vector2(cum_dist, 0.0)
			uv2s[v_cursor] = -miter

			verts[v_cursor + 1] = center
			norms[v_cursor + 1] = Vector3.UP
			uvs[v_cursor + 1] = Vector2(cum_dist, 1.0)
			uv2s[v_cursor + 1] = miter

			v_cursor += 2

		for k in count - 1:
			var a := line_v0 + k * 2
			var b := a + 1
			var c := a + 2
			var d := a + 3
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(b)
			indices.append(d)
			indices.append(c)

	verts.resize(v_cursor)
	norms.resize(v_cursor)
	uvs.resize(v_cursor)
	uv2s.resize(v_cursor)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	if not indices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/map/diorama_road.gdshader")
	mat.set_shader_parameter("is_toll", is_toll)
	mat.set_shader_parameter("base_half_width", base_half_w)
	mat.set_shader_parameter("far_scale", far_scale)
	materials.append(mat)

	var inst := MeshInstance3D.new()
	inst.name = node_name
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.extra_cull_margin = 160.0
	add_child(inst)
	return inst


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
