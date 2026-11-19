class_name DioramaProps
extends Node3D
## CC0 display dressing, batched by mesh. No nodes or simulation state per entity.
var materials: Array[ShaderMaterial] = []
var batches: Array[MultiMeshInstance3D] = []
var prop_count := 0
var model_count := 0
var _last_state := ""
var catalog: Dictionary


func build(records: Array) -> void:
	catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/map/art_catalog.json")).groups
	var groups := {}
	for record in records:
		var spec: Dictionary = catalog[str(record.kind)]
		var subdir := str(spec.get("subdir", ""))
		var model_name := str(spec.models[int(record.variant)])
		var key := ("%s/%s" % [subdir, model_name]) if subdir != "" else model_name
		groups.get_or_add(key, []).append(record)
	model_count = groups.size()
	for model_key in groups:
		var packed: PackedScene = load("res://assets/map/kenney/%s.glb" % model_key)
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
		var list: Array = groups[model_key]
		for item in meshes:
			_batch(item, bounds, list, model_key)
		prop_count += list.size()
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


func _batch(item: Dictionary, bounds: AABB, records: Array, model_key: String) -> void:
	var source: Mesh = item.mesh
	var kind: String = records[0].kind
	var spec: Dictionary = catalog[kind]
	var building := kind in ["house", "midrise", "tower", "urban_block", "industrial", "port_cargo"]
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface))
		var original := item.materials[surface] as BaseMaterial3D
		var material := ShaderMaterial.new()
		material.shader = load("res://src/map/diorama_building.gdshader" if building else "res://src/map/diorama_prop.gdshader")
		if building:
			material.set_shader_parameter("warm_roofs", kind == "house")
		if original != null:
			material.set_shader_parameter("tint", original.albedo_color)
			if original.albedo_texture != null:
				material.set_shader_parameter("palette", original.albedo_texture)
				material.set_shader_parameter("use_palette", true)
		if kind in ["tree", "highland_tree", "palm", "shrub", "rock", "crop"]:
			var is_trunk := original != null and original.albedo_color.r > original.albedo_color.g
			var color := Color("468438")
			if kind == "highland_tree":
				color = Color("6b4d37") if is_trunk else Color("285930")
			elif kind == "palm":
				color = Color("8a6a47") if is_trunk else Color("569438")
			elif kind == "shrub":
				color = Color("3f7a35")
			elif kind == "crop":
				if "wheat" in model_key:
					color = Color("cbb047")
				elif "corn" in model_key:
					color = Color("8aa83b")
				else:
					color = Color("52943b")
			elif kind == "rock":
				color = Color("6d7069") if surface % 2 == 0 else Color("989b8d")
			elif is_trunk:
				color = Color("7d5d3f")
			material.set_shader_parameter("tint", color)
		if not building:
			material.set_shader_parameter("foliage", bool(spec.foliage))
		mesh.surface_set_material(surface, material)
		materials.append(material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = records.size()
	for n in records.size():
		var r: Dictionary = records[n]
		# Both dimensions are constrained so tall/narrow source models cannot spill over the block.
		var height_scale := float(spec.height) / maxf(bounds.size.y, 0.01)
		var footprint_scale := float(spec.footprint) / maxf(maxf(bounds.size.x, bounds.size.z), 0.01)
		var scale_factor := minf(height_scale, footprint_scale) * float(r.size)
		var basis := Basis(Vector3.UP, float(r.rotation)).scaled(Vector3.ONE * scale_factor)
		var center := Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
		var root := Transform3D(basis, Vector3(r.x, 0.4, r.z) - basis * center)
		multimesh.set_instance_transform(n, root * (item.transform as Transform3D))
		multimesh.set_instance_custom_data(n, Color(float(r.region) / 1024.0, float(n % 37) / 37.0, float(n % 11) / 11.0, 1))
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = multimesh
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.extra_cull_margin = 150.0
	add_child(batch)
	batches.append(batch)


func sync(selected: int, lift: float, hovered: int, hover_lift: float, reduced_motion: bool, landscape: bool) -> void:
	visible = landscape
	var state := "%d/%s/%d/%s/%s" % [selected, lift, hovered, hover_lift, reduced_motion]
	if state == _last_state:
		return
	_last_state = state
	for material in materials:
		material.set_shader_parameter("selected_region", selected)
		material.set_shader_parameter("selected_lift", lift)
		material.set_shader_parameter("hovered_region", hovered)
		material.set_shader_parameter("hovered_lift", hover_lift)
		material.set_shader_parameter("motion", 0.0 if reduced_motion else 1.0)


func sync_atmosphere(params: Dictionary) -> void:
	for material in materials:
		for k in ["sun_dir", "sun_color", "ambient_color", "fog_color", "fog_density", "night_factor", "rain_factor", "drought_factor"]:
			if params.has(k):
				material.set_shader_parameter(k, params[k])
