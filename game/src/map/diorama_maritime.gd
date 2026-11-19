class_name DioramaMaritime
extends Node3D
## Decorative offshore CC0 vessels batched on archipelagic sea lanes; zero simulation effect.
var materials: Array[ShaderMaterial] = []
var batches: Array[MultiMeshInstance3D] = []
var vessel_count := 0
var model_count := 0
var _reduced := false


func build(records: Array) -> void:
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
		for item in meshes:
			_batch(item, bounds, spec, list)
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


func _batch(item: Dictionary, bounds: AABB, spec: Dictionary, records: Array) -> void:
	var source: Mesh = item.mesh
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface))
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
		var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var root := Transform3D(basis, Vector3(r.x, -3.9, r.z) - basis * center)
		multimesh.set_instance_transform(n, root * (item.transform as Transform3D))
		multimesh.set_instance_custom_data(n, Color(0.0, float(r.get("phase", 0.0)) / TAU, float(n % 11) / 11.0, 1.0))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.extra_cull_margin = 120.0
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
