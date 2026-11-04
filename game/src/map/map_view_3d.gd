class_name MapView3D
extends Node3D
## 3D Tabletop Diorama map of Indonesia for NUSANTARA.
## Inspired by Clash of Clans / Civ VI diorama tabletop aesthetics.
## Uses the exact same packaged geography v2 LOD meshes (D-058) as MapView.
## Renders:
## - 3D Land Meshes: Base tabletop projection on XZ plane (Y=0) with region lookup shader.
## - 3D Island Skirts: Extruded diorama base giving physical relief depth down to ocean.
## - 3D Ocean Surface: Animated tropical wave shader with specular glints on water floor.
## - 3D Border Lines: Elevated vector lines for kabupaten/kota and provincial boundaries.
## - 3D Extruded Pop-up: When selected, a kabupaten extrudes upward (+28 units) with
##   chiseled cliff walls, golden bevel rim, underglow light, and floating rotating beacon!
## - 3D Hover Lift: Subtle physical lift (+6 units) and cyan rim on hover.
## - Directional Sun & Environment: Isometric sunlight with soft directional shadows.

signal region_hovered(region_id: String)
signal region_clicked(region_id: String)
signal lod_changed(lod: String, reason: String)

const BORDER_COLOR := Color(0.12, 0.16, 0.22, 0.7)
const PROVINCE_BORDER_COLOR := Color(0.05, 0.08, 0.12, 0.95)
const SELECT_COLOR := Color(1.0, 0.88, 0.18)
const HOVER_COLOR := Color(0.85, 0.95, 1.0)
const SKIRT_DEPTH := -28.0

const HOVER_LIFT := 10.0
const DEFAULT_SELECTED_LIFT := 55.0
const ELEVATION_DURATION := 0.35
const ELEVATION_DOWN_DURATION := 0.22

var bounds := Rect2()
var region_ids: PackedStringArray = []
var active_lod := "lod1"

var _map_view_2d: MapView
var _fill_instances: Dictionary = {}    # lod -> MeshInstance3D
var _border_instances: Dictionary = {}  # lod -> MeshInstance3D
var _skirt_instances: Dictionary = {}   # lod -> MeshInstance3D
var _ocean_mesh: MeshInstance3D
var _sun: DirectionalLight3D
var _env: WorldEnvironment

var _mat_fill: ShaderMaterial
var _mat_border: StandardMaterial3D
var _mat_province: StandardMaterial3D
var _mat_skirt: StandardMaterial3D
var _mat_highlight_select: StandardMaterial3D
var _mat_highlight_hover: StandardMaterial3D
var _mat_elevated_wall: StandardMaterial3D

# 3D Extruded Pop-up Nodes (Selected)
var _selected_root: Node3D
var _sel_top_mesh: MeshInstance3D
var _sel_wall_mesh: MeshInstance3D
var _sel_rim_mesh: MeshInstance3D
var _sel_light: OmniLight3D
var _sel_beacon: Node3D
var _sel_center := Vector2.ZERO
var _selected_lift := 0.0
var _target_selected_lift := DEFAULT_SELECTED_LIFT
var _selected_tween: Tween

# 3D Hover Lift Nodes
var _hover_root: Node3D
var _hov_top_mesh: MeshInstance3D
var _hov_wall_mesh: MeshInstance3D
var _hov_rim_mesh: MeshInstance3D
var _hover_lift := 0.0
var _hover_tween: Tween

var _selected := ""
var _hovered := ""


func setup(mv2d: MapView) -> void:
	_map_view_2d = mv2d
	bounds = mv2d.bounds
	region_ids = mv2d.region_ids
	_init_materials()
	_init_environment()
	_build_ocean()
	_build_elevated_nodes()
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
	
	# Tabletop skirt material (dark basalt cliff)
	_mat_skirt = StandardMaterial3D.new()
	_mat_skirt.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat_skirt.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	_mat_skirt.albedo_color = Color(0.20, 0.24, 0.29)
	_mat_skirt.metallic = 0.15
	_mat_skirt.roughness = 0.75
	
	# Extruded side walls (chiseled stone cliff with vertical AO vertex colors)
	_mat_elevated_wall = StandardMaterial3D.new()
	_mat_elevated_wall.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_mat_elevated_wall.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	_mat_elevated_wall.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	_mat_elevated_wall.vertex_color_use_as_albedo = true
	_mat_elevated_wall.albedo_color = Color(0.32, 0.36, 0.42)
	_mat_elevated_wall.metallic = 0.12
	_mat_elevated_wall.roughness = 0.60
	_mat_elevated_wall.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# Golden selection rim
	_mat_highlight_select = StandardMaterial3D.new()
	_mat_highlight_select.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_highlight_select.albedo_color = SELECT_COLOR
	
	# Soft cyan hover rim
	_mat_highlight_hover = StandardMaterial3D.new()
	_mat_highlight_hover.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat_highlight_hover.albedo_color = HOVER_COLOR


func _init_environment() -> void:
	# Directional Sun Light (isometric angle with soft shadows)
	_sun = DirectionalLight3D.new()
	_sun.name = "SunLight"
	_sun.rotation_degrees = Vector3(-42.0, 40.0, 0.0)
	_sun.light_color = Color(1.0, 0.98, 0.93)
	_sun.light_energy = 1.40
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 18000.0
	_sun.shadow_bias = 0.02
	add_child(_sun)
	
	# World Environment
	_env = WorldEnvironment.new()
	_env.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0d1720")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.60, 0.72)
	env.ambient_light_energy = 0.85
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.35
	env.glow_bloom = 0.12
	_env.environment = env
	add_child(_env)


func _build_ocean() -> void:
	_ocean_mesh = MeshInstance3D.new()
	_ocean_mesh.name = "OceanSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(36000.0, 24000.0)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	_ocean_mesh.mesh = plane
	_ocean_mesh.position = Vector3(0.0, -25.0, 0.0)
	
	var ocean_mat := ShaderMaterial.new()
	ocean_mat.shader = load("res://src/map/map_water_3d.gdshader")
	_ocean_mesh.material_override = ocean_mat
	add_child(_ocean_mesh)


func _build_elevated_nodes() -> void:
	# 1. Selected Elevated Pop-up Container
	_selected_root = Node3D.new()
	_selected_root.name = "SelectedElevatedRoot"
	_selected_root.visible = false
	add_child(_selected_root)
	
	_sel_wall_mesh = MeshInstance3D.new()
	_sel_wall_mesh.name = "SelectedWalls"
	_selected_root.add_child(_sel_wall_mesh)
	
	_sel_top_mesh = MeshInstance3D.new()
	_sel_top_mesh.name = "SelectedTop"
	_selected_root.add_child(_sel_top_mesh)
	
	_sel_rim_mesh = MeshInstance3D.new()
	_sel_rim_mesh.name = "SelectedRim"
	_selected_root.add_child(_sel_rim_mesh)
	
	_sel_light = OmniLight3D.new()
	_sel_light.name = "UnderglowLight"
	_sel_light.light_color = Color(1.0, 0.85, 0.40)
	_sel_light.light_energy = 2.8
	_sel_light.omni_range = 140.0
	_sel_light.omni_attenuation = 1.3
	_sel_light.shadow_enabled = false
	_selected_root.add_child(_sel_light)
	
	_sel_beacon = _build_beacon_pin()
	_selected_root.add_child(_sel_beacon)
	
	# 2. Hover Elevated Container
	_hover_root = Node3D.new()
	_hover_root.name = "HoverElevatedRoot"
	_hover_root.visible = false
	add_child(_hover_root)
	
	_hov_wall_mesh = MeshInstance3D.new()
	_hov_wall_mesh.name = "HoverWalls"
	_hover_root.add_child(_hov_wall_mesh)
	
	_hov_top_mesh = MeshInstance3D.new()
	_hov_top_mesh.name = "HoverTop"
	_hover_root.add_child(_hov_top_mesh)
	
	_hov_rim_mesh = MeshInstance3D.new()
	_hov_rim_mesh.name = "HoverRim"
	_hover_root.add_child(_hov_rim_mesh)


func _build_beacon_pin() -> Node3D:
	var pin := Node3D.new()
	pin.name = "DioramaBeacon"
	
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	crystal_mat.albedo_color = Color(1.0, 0.88, 0.22)
	
	# Top diamond crystal
	var crystal := MeshInstance3D.new()
	crystal.name = "Crystal"
	var box := BoxMesh.new()
	box.size = Vector3(4.0, 7.5, 4.0)
	crystal.mesh = box
	crystal.rotation_degrees = Vector3(45.0, 45.0, 0.0)
	crystal.material_override = crystal_mat
	pin.add_child(crystal)
	
	# Pointer cone below crystal pointing down
	var ptr := MeshInstance3D.new()
	ptr.name = "Pointer"
	var prism := PrismMesh.new()
	prism.size = Vector3(2.5, 4.5, 2.5)
	ptr.mesh = prism
	ptr.position = Vector3(0.0, -4.8, 0.0)
	ptr.rotation_degrees = Vector3(180.0, 0.0, 0.0)
	ptr.material_override = crystal_mat
	pin.add_child(ptr)
	
	return pin


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
	
	# Refresh elevated meshes with current LOD detail
	if _selected != "":
		_rebuild_selected_mesh(_selected)
		_apply_selected_lift(_selected_lift)
	if _hovered != "" and _hovered != _selected:
		_rebuild_hover_mesh(_hovered)
		_apply_hover_lift(_hover_lift)


func update_view(zoom: float) -> void:
	var want := MapView.lod_for_scale(MapView.KM_PER_UNIT * 1000.0 / maxf(zoom, 1e-6))
	if want != active_lod:
		set_active_lod(want)


func set_selected(id: String) -> void:
	if id == _selected and id != "":
		return
	if _selected_tween and _selected_tween.is_valid():
		_selected_tween.kill()
	
	_selected = id
	if id == "":
		_selected_tween = create_tween()
		_selected_tween.tween_method(_apply_selected_lift, _selected_lift, 0.0, ELEVATION_DOWN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_selected_tween.finished.connect(func(): if _selected == "": _selected_root.visible = false)
	else:
		_selected_root.visible = true
		_rebuild_selected_mesh(id)
		var start_lift := _selected_lift if _selected_lift > 0.0 else (_hover_lift if id == _hovered else 0.0)
		_apply_selected_lift(start_lift)
		_selected_tween = create_tween()
		# Clash of Clans bouncy spring pop-up effect:
		_selected_tween.tween_method(_apply_selected_lift, start_lift, _target_selected_lift, ELEVATION_DURATION).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		region_clicked.emit(id)
	
	# If hovered was the newly selected region, drop hover
	if _hovered == _selected:
		set_hovered("")


func set_hovered(id: String) -> void:
	if id == _hovered:
		return
	_hovered = id
	region_hovered.emit(id)
	
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	
	if id == "" or id == _selected:
		if _hover_lift > 0.0:
			_hover_tween = create_tween()
			_hover_tween.tween_method(_apply_hover_lift, _hover_lift, 0.0, 0.12).set_trans(Tween.TRANS_QUAD)
			_hover_tween.finished.connect(func(): if _hovered == "" or _hovered == _selected: _hover_root.visible = false)
		else:
			_hover_root.visible = false
	else:
		_hover_root.visible = true
		_rebuild_hover_mesh(id)
		_hover_tween = create_tween()
		_hover_tween.tween_method(_apply_hover_lift, _hover_lift, HOVER_LIFT, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _apply_selected_lift(h: float) -> void:
	_selected_lift = h
	if _sel_top_mesh:
		_sel_top_mesh.position.y = h
	if _sel_wall_mesh:
		_sel_wall_mesh.scale.y = maxf(h, 0.001)
	if _sel_rim_mesh:
		_sel_rim_mesh.position.y = h + 0.35
	if _sel_light:
		_sel_light.position = Vector3(_sel_center.x, h * 0.45 + 1.0, _sel_center.y)
		_sel_light.light_energy = clampf(h / maxf(_target_selected_lift, 1.0) * 3.2, 0.0, 4.0)
	if _sel_beacon:
		_sel_beacon.position = Vector3(_sel_center.x, h + 16.0, _sel_center.y)


func _apply_hover_lift(h: float) -> void:
	_hover_lift = h
	if _hov_top_mesh:
		_hov_top_mesh.position.y = h
	if _hov_wall_mesh:
		_hov_wall_mesh.scale.y = maxf(h, 0.001)
	if _hov_rim_mesh:
		_hov_rim_mesh.position.y = h + 0.25


func _rebuild_selected_mesh(id: String) -> void:
	var l: MapLod = _map_view_2d.lod(active_lod) if _map_view_2d else null
	if l == null or not l.index_of.has(id):
		_sel_top_mesh.mesh = null
		_sel_wall_mesh.mesh = null
		_sel_rim_mesh.mesh = null
		return
	
	_sel_top_mesh.mesh = _build_region_top_mesh(l, id)
	_sel_wall_mesh.mesh = _build_region_wall_mesh(l, id)
	_sel_rim_mesh.mesh = _build_region_rim_mesh(l, id, _mat_highlight_select)
	
	if l.bbox.has(id):
		var box: Rect2 = l.bbox[id]
		_sel_center = box.get_center()
		var rad := maxf(box.size.x, box.size.y) * 0.5
		_target_selected_lift = clampf(rad * 0.85, 45.0, 95.0)
		if _sel_light:
			_sel_light.omni_range = maxf(rad * 2.8, 120.0)


func _rebuild_hover_mesh(id: String) -> void:
	var l: MapLod = _map_view_2d.lod(active_lod) if _map_view_2d else null
	if l == null or not l.index_of.has(id):
		_hov_top_mesh.mesh = null
		_hov_wall_mesh.mesh = null
		_hov_rim_mesh.mesh = null
		return
	
	_hov_top_mesh.mesh = _build_region_top_mesh(l, id)
	_hov_wall_mesh.mesh = _build_region_wall_mesh(l, id)
	_hov_rim_mesh.mesh = _build_region_rim_mesh(l, id, _mat_highlight_hover)


func _build_region_top_mesh(l: MapLod, id: String) -> ArrayMesh:
	var r_idx: int = l.index_of.get(id, -1)
	if r_idx < 0 or not l.meta.has("regions"):
		return null
	var r_meta: Dictionary = l.meta.regions[r_idx]
	var v_spec: Array = r_meta.get("v", [])
	var t_spec: Array = r_meta.get("t", [])
	if v_spec.size() < 2 or t_spec.size() < 2:
		return null
	var v_start: int = int(v_spec[0])
	var v_count: int = int(v_spec[1])
	var t_start: int = int(t_spec[0])
	var t_count: int = int(t_spec[1])
	if v_count <= 0 or t_count <= 0:
		return null

	var verts := PackedVector3Array()
	verts.resize(v_count)
	var norms := PackedVector3Array()
	norms.resize(v_count)
	for i in v_count:
		var p: Vector2 = l.positions[v_start + i]
		verts[i] = Vector3(p.x, 0.0, p.y)
		norms[i] = Vector3.UP

	var indices := PackedInt32Array()
	indices.resize(t_count)
	for k in t_count:
		indices[k] = l.triangles[t_start + k] - v_start

	var uvs := l.region_uv.slice(v_start, v_start + v_count)

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = indices
	arr[Mesh.ARRAY_TEX_UV] = uvs

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _mat_fill)
	return mesh


func _build_region_wall_mesh(l: MapLod, id: String) -> ArrayMesh:
	if not l.rings.has(id):
		return null
	var rs: Array = l.rings[id]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	var dark_base := Color(0.28, 0.32, 0.38)
	var lit_top := Color(0.85, 0.90, 0.98)

	for ring in rs:
		var n: int = ring.size()
		if n < 3:
			continue
		for k in n:
			var p1: Vector2 = ring[k]
			var p2: Vector2 = ring[(k + 1) % n]
			var edge := (p2 - p1).normalized()
			var norm := Vector3(-edge.y, 0.0, edge.x) # Outward normal

			var base_idx := verts.size()
			# Quad: (p1, 0) -> (p1, 1) -> (p2, 1) -> (p2, 0)
			verts.append(Vector3(p1.x, 0.0, p1.y))
			verts.append(Vector3(p1.x, 1.0, p1.y))
			verts.append(Vector3(p2.x, 1.0, p2.y))
			verts.append(Vector3(p2.x, 0.0, p2.y))

			norms.append(norm)
			norms.append(norm)
			norms.append(norm)
			norms.append(norm)

			colors.append(dark_base)
			colors.append(lit_top)
			colors.append(lit_top)
			colors.append(dark_base)

			indices.append(base_idx + 0)
			indices.append(base_idx + 1)
			indices.append(base_idx + 2)
			indices.append(base_idx + 0)
			indices.append(base_idx + 2)
			indices.append(base_idx + 3)

	if verts.is_empty():
		return null

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_COLOR] = colors
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _mat_elevated_wall)
	return mesh


func _build_region_rim_mesh(l: MapLod, id: String, mat: Material) -> ArrayMesh:
	if not l.rings.has(id):
		return null
	var rs: Array = l.rings[id]
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()

	for ring in rs:
		var n: int = ring.size()
		if n < 2:
			continue
		var start := verts.size()
		for k in n:
			var p: Vector2 = ring[k]
			verts.append(Vector3(p.x, 0.0, p.y))
			indices.append(start + k)
			indices.append(start + (k + 1) % n)

	if verts.is_empty():
		return null

	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	mesh.surface_set_material(0, mat)
	return mesh


## Raycast picking: checks intersection against elevated 3D region plane first,
## then falls back to ground plane Y=0 to avoid isometric parallax skew.
func region_at_ray(cam: Camera3D, screen_pos: Vector2) -> String:
	if cam == null:
		return ""
	var origin := cam.project_ray_origin(screen_pos)
	var normal := cam.project_ray_normal(screen_pos)
	if absf(normal.y) < 1e-5:
		return ""

	# 1. If selected region is elevated, check intersection with elevated plane Y = _selected_lift
	if _selected != "" and _selected_lift > 2.0:
		var t_sel := (_selected_lift - origin.y) / normal.y
		if t_sel > 0.0:
			var hit_sel := origin + normal * t_sel
			var p_sel := Vector2(hit_sel.x, hit_sel.z)
			if _map_view_2d and _map_view_2d.region_at(p_sel) == _selected:
				return _selected

	# 2. Check intersection with ground plane Y = 0.0
	var t_ground := -origin.y / normal.y
	if t_ground > 0.0:
		var hit_ground := origin + normal * t_ground
		var p_ground := Vector2(hit_ground.x, hit_ground.z)
		if _map_view_2d:
			return _map_view_2d.region_at(p_ground)
	return ""


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


func _process(delta: float) -> void:
	if _selected_root and _selected_root.visible and _sel_beacon:
		_sel_beacon.rotate_y(delta * 2.2)
		var bob := sin(Time.get_ticks_msec() * 0.004) * 2.2
		_sel_beacon.position.y = _selected_lift + 14.0 + bob


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
	
	# 3. Island Skirts (tabletop relief edge dropped to ocean)
	var skirt_mesh := ArrayMesh.new()
	var sk_verts := PackedVector3Array()
	var sk_norms := PackedVector3Array()
	var sk_idx := PackedInt32Array()
	
	for rid in l.rings:
		for ring in l.rings[rid]:
			var n: int = ring.size()
			if n < 3:
				continue
			var box := Rect2(ring[0], Vector2.ZERO)
			for pt in ring:
				box = box.expand(pt)
			var ring_span := maxf(box.size.x, box.size.y)
			if ring_span < 2.0:
				continue
			var skirt_h := clampf(ring_span * 0.9, 4.0, absf(SKIRT_DEPTH))
			var skirt_y := -skirt_h
			for k in n:
				var p1: Vector2 = ring[k]
				var p2: Vector2 = ring[(k + 1) % n]
				var edge_dir := (p2 - p1).normalized()
				var normal := Vector3(-edge_dir.y, 0.0, edge_dir.x)
				
				var v0 := sk_verts.size()
				sk_verts.append(Vector3(p1.x, 0.0, p1.y))
				sk_verts.append(Vector3(p1.x, skirt_y, p1.y))
				sk_verts.append(Vector3(p2.x, skirt_y, p2.y))
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
