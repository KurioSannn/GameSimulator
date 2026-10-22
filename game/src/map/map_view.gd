class_name MapView
extends Node2D
## Map of all 514 kab/kota from the packaged geography v2 meshes (D-058), offline, three LODs.
## - Fills: one indexed ArrayMesh per LOD with the offline earcut triangulation, so holes (lakes,
##   enclaves) are real holes. Colour comes from a 1-px lookup texture via map_fill.gdshader; each
##   vertex carries its region index (UV.x), so recolouring rewrites one texel per region, for all LODs.
## - Borders: kab/kota and province outlines as indexed line meshes (child node, no fill shader).
## - LOD: chosen from the on-screen scale in metres per pixel (thresholds from the documented LOD view
##   bands, research/reports/lod_tolerance_selection.json). Region identity never depends on the LOD.
## - Hit testing: even-odd point-in-polygon over the active LOD's rings (MapLod.entry_at).
## No Node per region. Simulation state is read-only here; colours come from a callable supplied by the UI.

signal region_hovered(region_id: String)
signal region_clicked(region_id: String)
signal lod_changed(lod: String, reason: String)

const BASE_DIR := "res://data/map/v2/"
const LOD_NAMES := ["lod1", "lod2", "lod3"]
## The selection record defines LOD view bands for a 1,600-px viewport: LOD1 >= 2,000 km wide,
## LOD2 300-2,000 km, LOD3 < 300 km. As on-screen scale (resolution independent):
const REF_VIEWPORT_PX := 1600.0
const LOD1_MIN_M_PER_PX := 2000000.0 / REF_VIEWPORT_PX   # 1,250 m/px
const LOD2_MIN_M_PER_PX := 300000.0 / REF_VIEWPORT_PX    # 187.5 m/px
const KM_PER_UNIT := 1.1119492664455874                  # 1/100 degree latitude, sphere R = 6371 km
## Projection used by the packaged meshes (build_map_lods.py; same as the earlier game map):
## equirectangular, lon0 118 E, standard parallel 2.5 S, 100 units per degree, y down.
const LON0 := 118.0
const LAT0 := -2.5
const UNITS_PER_DEG := 100.0

const DISPUTED_COLOR := Color(0.78, 0.78, 0.76)
const BORDER_COLOR := Color(0.16, 0.2, 0.26, 0.55)
const PROVINCE_BORDER_COLOR := Color(0.08, 0.1, 0.14, 0.9)
const SELECT_COLOR := Color(1.0, 0.84, 0.2)
const HOVER_COLOR := Color(1, 1, 1, 0.9)

var region_ids: PackedStringArray = []  # the 514 kab/kota, game-registry order
var bounds := Rect2()
var load_ms := 0.0
var active_lod := ""
var lod_reason := ""
var load_log: Array = []                # one entry per LOD load: {lod, ms, mesh_ms, timings}

var _lods: Dictionary = {}              # lod name -> MapLod
var _fill: Dictionary = {}              # lod name -> ArrayMesh (triangles, UV = region index)
var _borders: Dictionary = {}           # lod name -> ArrayMesh (kab/kota outlines, lines)
var _province: Dictionary = {}          # lod name -> ArrayMesh (province outlines, lines)
var _colors := Image.create(1, 1, false, Image.FORMAT_RGBA8)
var _colors_tex: ImageTexture
var _lines_node := _MapLines.new()
var _highlight_node := _MapHighlight.new()
var _selected := ""
var _hovered := ""
var _pending: Dictionary = {}           # lod name -> {task: int, lod: MapLod, err: String, t0: int}


## Parses LOD2/LOD3 on worker threads (MapLod is pure data) so the first zoom into detail does not
## stall the frame. Meshes are built on the main thread when a task finishes (_process) or when the
## LOD is needed first (_ensure_lod waits for its task instead of loading it twice).
func preload_remaining(base_dir: String = BASE_DIR) -> void:
	for name in LOD_NAMES:
		if _lods.has(name) or _pending.has(name):
			continue
		var job := {"lod": MapLod.new(), "err": "", "t0": Time.get_ticks_usec()}
		job["task"] = WorkerThreadPool.add_task(func(): job["err"] = (job["lod"] as MapLod).load_from(base_dir + "kabkota_" + name))
		_pending[name] = job
	set_process(true)


func _process(_delta: float) -> void:
	for name in _pending.keys():
		if WorkerThreadPool.is_task_completed(_pending[name].task):
			var err := _finish_pending(name)
			if err != "":
				push_error(err)
	if _pending.is_empty():
		set_process(false)


func _finish_pending(name: String) -> String:
	var job: Dictionary = _pending[name]
	WorkerThreadPool.wait_for_task_completion(job.task)
	_pending.erase(name)
	if job.err != "":
		return job.err
	return _adopt(name, job.lod, job.t0, true)


## Loads LOD1 (required at start). Returns "" or a readable error. LOD2/LOD3 load on first use.
func load_map(base_dir: String = BASE_DIR) -> String:
	var t0 := Time.get_ticks_usec()
	var err := _ensure_lod("lod1", base_dir)
	if err != "":
		return err
	var l1: MapLod = _lods["lod1"]
	bounds = l1.bounds
	region_ids = PackedStringArray()
	for i in l1.ids.size():
		if l1.kinds[i] == "kabkota":
			region_ids.append(l1.ids[i])
	_colors = Image.create(l1.ids.size(), 1, false, Image.FORMAT_RGBA8)
	_colors.fill(Color(0.6, 0.7, 0.62))
	for i in l1.ids.size():
		if l1.kinds[i] != "kabkota":
			_colors.set_pixel(i, 0, DISPUTED_COLOR)
	_colors_tex = ImageTexture.create_from_image(_colors)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://src/map/map_fill.gdshader")
	mat.set_shader_parameter("region_colors", _colors_tex)
	material = mat
	if _lines_node.get_parent() == null:
		_lines_node.view = self
		_highlight_node.view = self
		add_child(_lines_node)
		add_child(_highlight_node)
	_set_active("lod1", "awal (seluruh Indonesia)")
	load_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return ""


## Same formula as the offline build; for placing the camera on a geographic point (QA, focus).
static func project_lonlat(lon: float, lat: float) -> Vector2:
	return Vector2((lon - LON0) * cos(deg_to_rad(LAT0)) * UNITS_PER_DEG, -lat * UNITS_PER_DEG)


## LOD for an on-screen scale. Pure function of the scale: panning never changes the LOD, and the
## same scale always gives the same LOD in both zoom directions.
static func lod_for_scale(m_per_px: float) -> String:
	if m_per_px >= LOD1_MIN_M_PER_PX:
		return "lod1"
	if m_per_px >= LOD2_MIN_M_PER_PX:
		return "lod2"
	return "lod3"


## Called on every camera change. `zoom` = screen pixels per world unit.
func update_view(zoom: float) -> void:
	var m_per_px := KM_PER_UNIT * 1000.0 / maxf(zoom, 1e-6)
	var want := lod_for_scale(m_per_px)
	if want != active_lod:
		var err := _ensure_lod(want, BASE_DIR)
		if err != "":
			push_error(err)
			return
		_set_active(want, "skala %.0f m/piksel" % m_per_px)
	queue_redraw()
	_lines_node.queue_redraw()
	_highlight_node.queue_redraw()


func active() -> MapLod:
	return _lods.get(active_lod)


func lod(name: String) -> MapLod:
	return _lods.get(name)


func is_loaded(name: String) -> bool:
	return _lods.has(name)


## color_for: Callable(region_id: String) -> Color. One texel per region; applies to every LOD.
func recolor(color_for: Callable) -> void:
	var l1: MapLod = _lods.get("lod1")
	if l1 == null:
		return
	for id in region_ids:
		_colors.set_pixel(l1.index_of[id], 0, color_for.call(id))
	_colors_tex.update(_colors)
	queue_redraw()


func region_at(world_pos: Vector2) -> String:
	var l := active()
	return l.region_at(world_pos) if l else ""


func region_rect(id: String) -> Rect2:
	var l := active()
	return l.bbox.get(id, Rect2()) if l else Rect2()


## Bounding box of every kab/kota of a province (for "return to the province view").
func province_rect(province_id: String) -> Rect2:
	var l := active()
	var out := Rect2()
	var first := true
	for i in l.ids.size():
		if l.kinds[i] == "kabkota" and l.ids[i].begins_with(province_id + "."):
			out = l.bbox[l.ids[i]] if first else out.merge(l.bbox[l.ids[i]])
			first = false
	return out


func selected_id() -> String:
	return _selected


func hovered_id() -> String:
	return _hovered


## [kab/kota border mesh, province border mesh] of the active LOD, or [] before loading.
func active_line_meshes() -> Array:
	if not _borders.has(active_lod):
		return []
	return [_borders[active_lod], _province[active_lod]]


func set_selected(id: String) -> void:
	_selected = id
	_highlight_node.queue_redraw()


func set_hovered(id: String) -> void:
	if id != _hovered:
		_hovered = id
		_highlight_node.queue_redraw()
		region_hovered.emit(id)


func _draw() -> void:
	if _fill.has(active_lod):
		draw_mesh(_fill[active_lod], null)


func _set_active(name: String, reason: String) -> void:
	active_lod = name
	lod_reason = reason
	queue_redraw()
	_lines_node.queue_redraw()
	_highlight_node.queue_redraw()
	lod_changed.emit(name, reason)


func _ensure_lod(name: String, base_dir: String) -> String:
	if _lods.has(name):
		return ""
	if _pending.has(name):
		var tw := Time.get_ticks_usec()
		var err_p := _finish_pending(name)
		if load_log.size() > 0:
			load_log[-1]["main_thread_wait_ms"] = (Time.get_ticks_usec() - tw) / 1000.0
		return err_p
	var t0 := Time.get_ticks_usec()
	var l := MapLod.new()
	var err := l.load_from(base_dir + "kabkota_" + name)
	if err != "":
		return err
	return _adopt(name, l, t0, false)


## Builds the meshes for a parsed LOD (main thread) and makes it available.
func _adopt(name: String, l: MapLod, t0: int, background: bool) -> String:
	if not _lods.is_empty() and l.ids != (_lods.values()[0] as MapLod).ids:
		return "Data peta %s tidak sejajar dengan LOD lain (urutan wilayah berbeda)" % name
	var t1 := Time.get_ticks_usec()
	_fill[name] = _mesh(Mesh.PRIMITIVE_TRIANGLES, l.positions, l.triangles, l.region_uv)
	_borders[name] = _mesh(Mesh.PRIMITIVE_LINES, l.positions, l.lines)
	_province[name] = _mesh(Mesh.PRIMITIVE_LINES, l.province_positions, l.province_lines)
	_lods[name] = l
	var t2 := Time.get_ticks_usec()
	load_log.append({"lod": name, "ms": (t2 - t0) / 1000.0, "mesh_ms": (t2 - t1) / 1000.0,
		"parsed_on_worker_thread": background, "ready_at_engine_ms": Time.get_ticks_msec(), "timings": l.timings})
	return ""


static func _mesh(prim: int, verts: PackedVector2Array, idx: PackedInt32Array, uv := PackedVector2Array()) -> ArrayMesh:
	var m := ArrayMesh.new()
	if verts.is_empty():
		return m
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	if not uv.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uv
	m.add_surface_from_arrays(prim, arrays)
	return m


## Borders (no fill shader; children do not inherit the parent's material).
class _MapLines extends Node2D:
	var view: MapView

	func _draw() -> void:
		var meshes: Array = view.active_line_meshes() if view else []
		if meshes.is_empty():
			return
		draw_mesh(meshes[0], null, Transform2D(), BORDER_COLOR)
		draw_mesh(meshes[1], null, Transform2D(), PROVINCE_BORDER_COLOR)


## Hover and selection outlines: every ring (all islands and holes) of the region in the active LOD.
class _MapHighlight extends Node2D:
	var view: MapView

	func _draw() -> void:
		var l := view.active() if view else null
		if l == null:
			return
		var zoom := get_viewport().get_canvas_transform().get_scale().x
		var w := 2.5 / maxf(zoom, 0.01)
		var hov := view.hovered_id()
		var sel := view.selected_id()
		if hov != "" and hov != sel:
			_outline(l, hov, HOVER_COLOR, w * 0.6)
		if sel != "":
			_outline(l, sel, SELECT_COLOR, w)

	func _outline(l: MapLod, id: String, c: Color, w: float) -> void:
		for ring in l.rings.get(id, []):
			var closed: PackedVector2Array = ring.duplicate()
			closed.append(ring[0])
			draw_polyline(closed, c, w)
