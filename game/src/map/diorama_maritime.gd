class_name DioramaMaritime
extends Node3D
## Decorative offshore CC0 vessels batched on archipelagic sea lanes; zero simulation effect.
var materials: Array[ShaderMaterial] = []
var batches: Array[MultiMeshInstance3D] = []
var vessel_count := 0
var model_count := 0
var _reduced := false


func build(records: Array, sea_level: float = -0.85) -> void:
	if records.is_empty():
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/map/art_catalog.json")).groups
	var spec: Dictionary = catalog["vessel"]
	var subdir := str(spec.get("subdir", ""))
	var groups := {}
	for record in records:
		var model_name := str(spec.models[int(record.variant)])
		var key := ("%s/%s" % [subdir, model_name]) if subdir != "" else model_name
		groups.get_or_add(key, []).append(record)
	model_count = groups.size()
	for model in groups:
		var packed: PackedScene = load("res://assets/map/kenney/%s.glb" % model)
		if packed == null:
			continue
		var scene := packed.instantiate()
		var meshes: Array = []
		_collect(scene, Transform3D.IDENTITY, meshes)
		var bounds := AABB()
		var first := true
		for item in meshes:
			var box: AABB = item.transform * (item.mesh as Mesh).get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		var list: Array = groups[model]
		var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		for item in meshes:
			_batch(item, bounds, center, spec, list, sea_level + 0.03)
		_batch_wakes(bounds, spec, list, sea_level + 0.05)
		vessel_count += list.size()
		scene.free()


func _collect(node: Node, parent: Transform3D, result: Array) -> void:
	var local: Transform3D = parent * node.transform if node is Node3D else parent
	if node is MeshInstance3D and node.mesh != null:
		var active_materials: Array = []
		for surface in node.mesh.get_surface_count():
			active_materials.append(node.get_active_material(surface))
		result.append({"mesh": node.mesh, "transform": local, "materials": active_materials})
	for child in node.get_children():
		_collect(child, local, result)


func _batch(item: Dictionary, bounds: AABB, center: Vector3, spec: Dictionary, records: Array, base_y: float) -> void:
	var source: Mesh = item.mesh
	var rel_xf := Transform3D(Basis.IDENTITY, -center) * (item.transform as Transform3D)
	var rel_norm_basis := (item.transform as Transform3D).basis.orthonormalized()
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vi in verts.size():
			verts[vi] = rel_xf * verts[vi]
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] != null:
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for ni in norms.size():
				norms[ni] = (rel_norm_basis * norms[ni]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = norms
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		var original := item.materials[surface] as BaseMaterial3D
		var material := ShaderMaterial.new()
		material.shader = load("res://src/map/diorama_vessel.gdshader")
		if original != null:
			material.set_shader_parameter("tint", original.albedo_color)
			if original.albedo_texture != null:
				material.set_shader_parameter("palette", original.albedo_texture)
				material.set_shader_parameter("use_palette", true)
		mesh.surface_set_material(surface, material)
		materials.append(material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = records.size()
	for n in records.size():
		var r: Dictionary = records[n]
		var height_scale := float(spec.height) / maxf(bounds.size.y, 0.01)
		var footprint_scale := float(spec.footprint) / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)
		var scale_factor := minf(height_scale, footprint_scale) * float(r.size)
		var basis := Basis(Vector3.UP, float(r.rotation)).scaled(Vector3.ONE * scale_factor)
		var root := Transform3D(basis, Vector3(float(r.x), base_y, float(r.z)))
		multimesh.set_instance_transform(n, root)
		multimesh.set_instance_custom_data(n, Color(
			float(r.get("cruise_a", 0.0)) / 64.0,
			float(r.get("cruise_b", 0.0)) / 64.0,
			float(r.get("phase", 0.0)) / TAU,
			clampf(0.5 + float(r.get("speed", 0.0)) * 0.5, 0.0, 1.0)
		))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.extra_cull_margin = 160.0
	add_child(batch)
	batches.append(batch)


func _batch_wakes(bounds: AABB, spec: Dictionary, records: Array, wake_y: float) -> void:
	var hw := maxf(bounds.size.x * 1.45, 2.2)
	var z_front := bounds.size.z * 0.35
	var z_back := -bounds.size.z * 2.55
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-hw, 0.0, z_front))
	st.set_uv(Vector2(1.0, 0.0)); st.add_vertex(Vector3(hw, 0.0, z_front))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(hw, 0.0, z_back))
	st.set_uv(Vector2(0.0, 0.0)); st.add_vertex(Vector3(-hw, 0.0, z_front))
	st.set_uv(Vector2(1.0, 1.0)); st.add_vertex(Vector3(hw, 0.0, z_back))
	st.set_uv(Vector2(0.0, 1.0)); st.add_vertex(Vector3(-hw, 0.0, z_back))
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/map/diorama_wake.gdshader")
	mesh.surface_set_material(0, mat)
	materials.append(mat)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = records.size()
	for n in records.size():
		var r: Dictionary = records[n]
		var height_scale := float(spec.height) / maxf(bounds.size.y, 0.01)
		var footprint_scale := float(spec.footprint) / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)
		var scale_factor := minf(height_scale, footprint_scale) * float(r.size)
		var basis := Basis(Vector3.UP, float(r.rotation)).scaled(Vector3.ONE * scale_factor)
		multimesh.set_instance_transform(n, Transform3D(basis, Vector3(float(r.x), wake_y, float(r.z))))
		multimesh.set_instance_custom_data(n, Color(
			float(r.get("cruise_a", 0.0)) / 64.0,
			float(r.get("cruise_b", 0.0)) / 64.0,
			float(r.get("phase", 0.0)) / TAU,
			clampf(0.5 + float(r.get("speed", 0.0)) * 0.5, 0.0, 1.0)
		))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.extra_cull_margin = 160.0
	add_child(batch)
	batches.append(batch)


func set_reduced_motion(reduced: bool) -> void:
	if reduced == _reduced:
		return
	_reduced = reduced
	var m := 0.0 if reduced else 1.0
	for material in materials:
		material.set_shader_parameter("motion", m)


func sync_atmosphere(params: Dictionary) -> void:
	for material in materials:
		for k in ["sun_dir", "sun_color", "ambient_color", "fog_color", "fog_density", "night_factor", "rain_factor", "drought_factor"]:
			if params.has(k):
				material.set_shader_parameter(k, params[k])
