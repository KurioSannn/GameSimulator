class_name DioramaAtmosphere
extends Node3D
## Multi-layered soft volumetric-look FBM cloud puffs and sweeping monsoon decks.
var material: ShaderMaterial
var high_material: ShaderMaterial
var veil_material: ShaderMaterial
var cirrus_material: ShaderMaterial
var cluster_count := 0
var high_cluster_count := 0
var _reduced := false


func build(config: Dictionary) -> void:
	var cloud_card_base := _build_soft_cloud_cluster_mesh()

	# 1. Sea-anchored soft cumulus puff banks (120 clusters)
	material = ShaderMaterial.new()
	material.shader = load("res://src/map/diorama_cloud.gdshader")
	material.set_shader_parameter("close_fade_start", 190.0)
	material.set_shader_parameter("close_fade_end", 950.0)
	var sea_mesh := cloud_card_base.duplicate() as ArrayMesh
	sea_mesh.surface_set_material(0, material)
	var sea_points: Array = config.get("clouds", [])
	cluster_count = sea_points.size()
	add_child(_make_cloud_multimesh(sea_mesh, sea_points, 1.0))

	# 2. High-altitude archipelago soft cloud layers (64 clusters, fade early on city zoom)
	var high_points: Array = config.get("high_clouds", [])
	high_cluster_count = high_points.size()
	if high_cluster_count > 0:
		high_material = ShaderMaterial.new()
		high_material.shader = load("res://src/map/diorama_cloud.gdshader")
		high_material.set_shader_parameter("close_fade_start", 560.0)
		high_material.set_shader_parameter("close_fade_end", 1320.0)
		var high_mesh := cloud_card_base.duplicate() as ArrayMesh
		high_mesh.surface_set_material(0, high_material)
		add_child(_make_cloud_multimesh(high_mesh, high_points, 1.15))

	# 3. Mid monsoon cloud deck (sweeping translucent tropical weather systems)
	veil_material = ShaderMaterial.new()
	veil_material.shader = load("res://src/map/diorama_sky_veil.gdshader")
	veil_material.set_shader_parameter("layer_height_scale", 1.0)
	var veil_plane := PlaneMesh.new()
	veil_plane.size = Vector2(12500.0, 6800.0)
	var veil := MeshInstance3D.new()
	veil.name = "SkyCloudVeil"
	veil.mesh = veil_plane
	veil.position = Vector3(0.0, 295.0, 200.0)
	veil.material_override = veil_material
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(veil)

	# 4. Upper parallax cirrus haze sheet
	cirrus_material = ShaderMaterial.new()
	cirrus_material.shader = load("res://src/map/diorama_sky_veil.gdshader")
	cirrus_material.set_shader_parameter("layer_height_scale", 1.55)
	var cirrus_plane := PlaneMesh.new()
	cirrus_plane.size = Vector2(13000.0, 7200.0)
	var cirrus := MeshInstance3D.new()
	cirrus.name = "SkyCirrusVeil"
	cirrus.mesh = cirrus_plane
	cirrus.position = Vector3(120.0, 420.0, 140.0)
	cirrus.material_override = cirrus_material
	cirrus.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cirrus)


func _build_soft_cloud_cluster_mesh() -> ArrayMesh:
	# Build 3 staggered horizontal/gently-tilted UV quad sheets per cluster so radial FBM fades
	# seamlessly at every viewing pitch without showing blocky 3D sphere silhouettes.
	var quad := QuadMesh.new()
	quad.size = Vector2(155.0, 130.0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sheets := [
		[Vector3(0.0, 0.0, 0.0), Vector3(-PI * 0.5, 0.0, 0.0), Vector3(1.0, 1.0, 1.0)],
		[Vector3(-18.0, 11.0, 10.0), Vector3(-PI * 0.5 + 0.16, 0.4, 0.0), Vector3(0.84, 0.80, 1.0)],
		[Vector3(20.0, -7.0, -12.0), Vector3(-PI * 0.5 - 0.14, -0.5, 0.0), Vector3(0.88, 0.82, 1.0)],
	]
	for spec in sheets:
		var b := Basis.from_euler(spec[1]).scaled(spec[2])
		surface.append_from(quad, 0, Transform3D(b, spec[0]))
	return surface.commit()


func _make_cloud_multimesh(mesh: Mesh, points: Array, scale_mul: float) -> MultiMeshInstance3D:
	var clouds := MultiMesh.new()
	clouds.transform_format = MultiMesh.TRANSFORM_3D
	clouds.use_custom_data = true
	clouds.mesh = mesh
	clouds.instance_count = points.size()
	for i in points.size():
		var point: Array = points[i]
		var size := float(point[2]) * scale_mul
		var phase := float(point[3])
		var pos := Vector3(float(point[0]), float(point[4]), float(point[1]))
		var basis := Basis(Vector3.UP, phase).scaled(Vector3(1.0 + float(i % 3) * 0.12, 1.0, 0.92 + float(i % 2) * 0.18) * size)
		clouds.set_instance_transform(i, Transform3D(basis, pos))
		clouds.set_instance_custom_data(i, Color(0, phase / TAU, float(i % 5) / 5.0, 1))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = clouds
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = 220.0
	return instance


func sync_atmosphere(params: Dictionary) -> void:
	for mat in [material, high_material, veil_material, cirrus_material]:
		if mat == null:
			continue
		for k in ["sun_dir", "sun_color", "ambient_color", "fog_color", "fog_density", "rain_factor", "drought_factor", "smoke_factor"]:
			if params.has(k):
				mat.set_shader_parameter(k, params[k])


func set_reduced_motion(reduced: bool) -> void:
	if reduced == _reduced:
		return
	_reduced = reduced
	var m := 0.0 if reduced else 1.0
	for mat in [material, high_material, veil_material, cirrus_material]:
		if mat != null:
			mat.set_shader_parameter("motion", m)
