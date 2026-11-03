class_name MapView3D
extends Node3D
## 3D Tabletop Diorama map of Indonesia for NUSANTARA.
## Uses the exact same packaged geography v2 LOD meshes (D-058) as MapView.
## Renders:
## - 3D Land Meshes: Flat tabletop projection on XZ plane (Y=0) with region lookup shader.
## - 3D Island Skirts: Extruded base giving physical relief/diorama depth to the archipelago.
## - 3D Ocean Surface: Animated water shader on the ocean floor (Y=-0.5).
## - 3D Border Lines: Elevated vector lines for kabupaten/kota and provincial boundaries.
## - 3D Region Highlight: Glowing elevated outline for hover/selection.
## - Sun & Environment: Directional lighting with soft shadows.

signal region_hovered(region_id: String)
signal region_clicked(region_id: String)
signal lod_changed(lod: String, reason: String)

const BORDER_COLOR := Color(0.12, 0.16, 0.22, 0.7)
const PROVINCE_BORDER_COLOR := Color(0.05, 0.08, 0.12, 0.95)
const SELECT_COLOR := Color(1.0, 0.85, 0.15)
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const SKIRT_DEPTH := -12.0

var bounds := Rect2()
var region_ids: PackedStringArray = []
var active_lod := "lod1"

var _map_view_2d: MapView
var _fill_instances: Dictionary = {}    # lod -> MeshInstance3D
var _border_instances: Dictionary = {}  # lod -> MeshInstance3D
var _skirt_instances: Dictionary = {}   # lod -> MeshInstance3D
var _highlight_instance: MeshInstance3D
var _ocean_mesh: MeshInstance3D
var _sun: DirectionalLight3D
var _env: WorldEnvironment

var _mat_fill: ShaderMaterial
var _mat_border: StandardMaterial3D
var _mat_province: StandardMaterial3D
var _mat_skirt: StandardMaterial3D
var _mat_highlight_select: StandardMaterial3D
var _mat_highlight_hover: StandardMaterial3D

var _selected := ""
var _hovered := ""


func setup(mv2d: MapView) -> void:
	_map_view_2d = mv2d
	bounds = mv2d.bounds
	region_ids = mv2d.region_ids
	_init_materials()
	_init_environment()
	_build_ocean()
	_build_highlight_node()
	# Build 3D meshes for whatever LODs are already loaded
	for lod_name in MapView.LOD_NAMES:
		if mv2d.is_loaded(lod_name):
			_build_lod_meshes(lod_name, mv2d.lod(lod_name))
	set_active_lod(mv2d.active_lod)


func _init_materials() -> void:
	# Land fill shader material
	_mat_fill = ShaderMaterial.new()
	_mat_fill.shader = load("res://src/map/map_fill_3d.gdshader")
	if _map_view_2d and _map_view_2d._colors_tex:
		_mat_fill.set_shader_parameter("region_colors", _map_view_2d._colors_tex)
	
	# Border line materials
	_mat_border = StandardMaterial3D.new()
	_mat_border.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_border.albedo_color = BORDER_COLOR
	_mat_border.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_mat_province = StandardMaterial3D.new()
	_mat_province.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_province.albedo_color = PROVINCE_BORDER_COLOR
	
	# Tabletop skirt material (dark basalt / wooden game board finish)
	_mat_skirt = StandardMaterial3D.new()
	_mat_skirt.albedo_color = Color(0.14, 0.18, 0.22)
	_mat_skirt.roughness = 0.9
	
	# Highlight line materials
	_mat_highlight_select = StandardMaterial3D.new()
	_mat_highlight_select.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_highlight_select.albedo_color = SELECT_COLOR
	
	_mat_highlight_hover = StandardMaterial3D.new()
	_mat_highlight_hover.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_highlight_hover.albedo_color = HOVER_COLOR


func _init_environment() -> void:
	# Directional Sun Light
	_sun = DirectionalLight3D.new()
	_sun.name = "SunLight"
	_sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	_sun.light_color = Color(1.0, 0.98, 0.94)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	add_child(_sun)
	
	# World Environment
	_env = WorldEnvironment.new()
	_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14222d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.55, 0.65)
	env.ambient_light_energy = 0.8
	_env.environment = env
	add_child(_env)


func _build_ocean() -> void:
	_ocean_mesh = MeshInstance3D.new()
	_ocean_mesh.name = "OceanSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(32000.0, 20000.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	_ocean_mesh.mesh = plane
	_ocean_mesh.position = Vector3(0.0, -8.0, 0.0)
	
	var ocean_mat := ShaderMaterial.new()
	ocean_mat.shader = load("res://src/map/map_water_3d.gdshader")
	_ocean_mesh.material_override = ocean_mat
	add_child(_ocean_mesh)


func _build_highlight_node() -> void:
	_highlight_instance = MeshInstance3D.new()
	_highlight_instance.name = "RegionHighlight3D"
	_highlight_instance.position = Vector3(0.0, 1.2, 0.0)
	add_child(_highlight_instance)


func set_active_lod(lod_name: String) -> void:
	active_lod = lod_name
	if _map_view_2d and _map_view_2d.is_loaded(lod_name) and not _fill_instances.has(lod_name):
		_build_lod_meshes(lod_name, _map_view_2d.lod(lod_name))
	for k in _fill_instances:
		_fill_instances[k].visible = (k == lod_name)
	for k in _border_instances:
		_border_instances[k].visible = (k == lod_name)
	for k in _skirt_instances:
		_skirt_instances[k].visible = (k == lod_name)
	_update_highlight()


func update_view(zoom: float) -> void:
	var want := MapView.lod_for_scale(MapView.KM_PER_UNIT * 1000.0 / maxf(zoom, 1e-6))
	if want != active_lod:
		set_active_lod(want)


func set_selected(id: String) -> void:
	_selected = id
	_update_highlight()


func set_hovered(id: String) -> void:
	if id != _hovered:
		_hovered = id
		_update_highlight()
		region_hovered.emit(id)


func selected_id() -> String:
	return _selected


func hovered_id() -> String:
	return _hovered


func region_at(world_pos: Vector2) -> String:
	if _map_view_2d:
		return _map_view_2d.region_at(world_pos)
	return ""


func sync_colors() -> void:
	if _map_view_2d and _map_view_2d._colors_tex:
		_mat_fill.set_shader_parameter("region_colors", _map_view_2d._colors_tex)


func _build_lod_meshes(name: String, l: MapLod) -> void:
	if _fill_instances.has(name) or l == null:
		return
	
	# 1. Land Fills (3D ArrayMesh)
	var land_mesh := ArrayMesh.new()
	var verts_3d := PackedVector3Array()
	verts_3d.resize(l.positions.size())
	var normals_3d := PackedVector3Array()
	normals_3d.resize(l.positions.size())
	for i in l.positions.size():
		var p := l.positions[i]
		verts_3d[i] = Vector3(p.x, 0.0, p.y)
		normals_3d[i] = Vector3.UP
	
	var fill_arrays := []
	fill_arrays.resize(Mesh.ARRAY_MAX)
	fill_arrays[Mesh.ARRAY_VERTEX] = verts_3d
	fill_arrays[Mesh.ARRAY_NORMAL] = normals_3d
	fill_arrays[Mesh.ARRAY_INDEX] = l.triangles
	fill_arrays[Mesh.ARRAY_TEX_UV] = l.region_uv
	land_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fill_arrays)
	
	var fill_inst := MeshInstance3D.new()
	fill_inst.name = "LandFill_" + name
	fill_inst.mesh = land_mesh
	fill_inst.material_override = _mat_fill
	add_child(fill_inst)
	_fill_instances[name] = fill_inst
	
	# 2. Border Lines (elevated slightly at Y=0.5)
	var border_mesh := ArrayMesh.new()
	var b_verts := PackedVector3Array()
	b_verts.resize(l.positions.size())
	for i in l.positions.size():
		var p := l.positions[i]
		b_verts[i] = Vector3(p.x, 0.5, p.y)
	
	var border_arrays := []
	border_arrays.resize(Mesh.ARRAY_MAX)
	border_arrays[Mesh.ARRAY_VERTEX] = b_verts
	border_arrays[Mesh.ARRAY_INDEX] = l.lines
	border_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, border_arrays)
	border_mesh.surface_set_material(0, _mat_border)
	
	# Province outlines (elevated at Y=0.8)
	var prov_verts := PackedVector3Array()
	prov_verts.resize(l.province_positions.size())
	for i in l.province_positions.size():
		var p := l.province_positions[i]
		prov_verts[i] = Vector3(p.x, 0.8, p.y)
	
	var prov_arrays := []
	prov_arrays.resize(Mesh.ARRAY_MAX)
	prov_arrays[Mesh.ARRAY_VERTEX] = prov_verts
	prov_arrays[Mesh.ARRAY_INDEX] = l.province_lines
	border_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, prov_arrays)
	border_mesh.surface_set_material(1, _mat_province)
	
	var border_inst := MeshInstance3D.new()
	border_inst.name = "Borders_" + name
	border_inst.mesh = border_mesh
	add_child(border_inst)
	_border_instances[name] = border_inst
	
	# 3. Island Skirts (tabletop relief edge dropped to Y = -2.5)
	# Build skirt quads around outer ring boundaries
	var skirt_mesh := ArrayMesh.new()
	var sk_verts := PackedVector3Array()
	var sk_norms := PackedVector3Array()
	var sk_idx := PackedInt32Array()
	
	for rid in l.rings:
		for ring in l.rings[rid]:
			var n: int = ring.size()
			if n < 3:
				continue
			var base_idx := sk_verts.size()
			for k in n:
				var p1: Vector2 = ring[k]
				var p2: Vector2 = ring[(k + 1) % n]
				var edge_dir := (p2 - p1).normalized()
				var normal := Vector3(-edge_dir.y, 0.0, edge_dir.x) # outward normal
				
				var v0 := sk_verts.size()
				sk_verts.append(Vector3(p1.x, 0.0, p1.y))
				sk_verts.append(Vector3(p1.x, SKIRT_DEPTH, p1.y))
				sk_verts.append(Vector3(p2.x, SKIRT_DEPTH, p2.y))
				sk_verts.append(Vector3(p2.x, 0.0, p2.y))
				
				for _vi in 4:
					sk_norms.append(normal)
				
				sk_idx.append(v0)
				sk_idx.append(v0 + 1)
				sk_idx.append(v0 + 2)
				sk_idx.append(v0)
				sk_idx.append(v0 + 2)
				sk_idx.append(v0 + 3)
	
	if not sk_verts.is_empty():
		var skirt_arrays := []
		skirt_arrays.resize(Mesh.ARRAY_MAX)
		skirt_arrays[Mesh.ARRAY_VERTEX] = sk_verts
		skirt_arrays[Mesh.ARRAY_NORMAL] = sk_norms
		skirt_arrays[Mesh.ARRAY_INDEX] = sk_idx
		skirt_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, skirt_arrays)
		
		var skirt_inst := MeshInstance3D.new()
		skirt_inst.name = "IslandSkirts_" + name
		skirt_inst.mesh = skirt_mesh
		skirt_inst.material_override = _mat_skirt
		add_child(skirt_inst)
		_skirt_instances[name] = skirt_inst


func _update_highlight() -> void:
	if _highlight_instance == null:
		return
	var l: MapLod = _map_view_2d.lod(active_lod) if _map_view_2d else null
	if l == null:
		_highlight_instance.mesh = null
		return
	
	var mesh := ArrayMesh.new()
	
	# Hover outline
	if _hovered != "" and _hovered != _selected and l.rings.has(_hovered):
		_add_highlight_surface(mesh, l.rings[_hovered], _mat_highlight_hover, 0.20)
	
	# Selection outline
	if _selected != "" and l.rings.has(_selected):
		_add_highlight_surface(mesh, l.rings[_selected], _mat_highlight_select, 0.28)
	
	_highlight_instance.mesh = mesh if mesh.get_surface_count() > 0 else null


func _add_highlight_surface(mesh: ArrayMesh, rings: Array, mat: Material, elevation: float) -> void:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	
	for ring in rings:
		var n: int = ring.size()
		if n < 2:
			continue
		var start := verts.size()
		for k in n:
			var p: Vector2 = ring[k]
			verts.append(Vector3(p.x, elevation, p.y))
			indices.append(start + k)
			indices.append(start + (k + 1) % n)
	
	if verts.is_empty():
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var s_idx := mesh.get_surface_count()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh.surface_set_material(s_idx, mat)

