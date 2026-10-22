class_name MapLod
extends RefCounted
## One level of detail of the packaged map (game/data/map/v2/kabkota_<lod>.json + .bin), built offline
## by scripts/pipelines/game/build_map_lods.py from the validated geography v2 LODs (D-053, D-058).
## Pure data: no rendering, no network. Coordinates are already projected (equirectangular, 100 units
## per degree, y down; see meta "projection"); the source lon/lat files are never touched at runtime.
##
## Region identity: entry i of `ids` owns every vertex whose region_uv.x == i. Entries 0..513 are the
## 514 kab/kota in game-registry (simulation) order; the rest are BIG unallocated fragments (D-052),
## which are drawn but never selectable.

const SCHEMA := "nusantara.map_mesh/1"
const GRID_CELL := 20.0  # world units (~22 km)

var lod := ""
var meta: Dictionary = {}
var positions := PackedVector2Array()
var region_uv := PackedVector2Array()
var triangles := PackedInt32Array()
var lines := PackedInt32Array()
var province_positions := PackedVector2Array()
var province_lines := PackedInt32Array()

var ids: PackedStringArray = []
var kinds: PackedStringArray = []
var index_of: Dictionary = {}           # region/fragment id -> entry index
var rings: Dictionary = {}              # id -> Array[PackedVector2Array] (outer rings and holes of all parts)
var ring_boxes: Dictionary = {}         # id -> Array[Rect2], parallel to rings (cheap rejection)
var bbox: Dictionary = {}               # id -> Rect2
var bounds := Rect2()
var timings: Dictionary = {}            # ms per stage: read, meta, arrays, index
var _grid: Dictionary = {}              # Vector2i -> PackedInt32Array of entry indices


## Loads `<base>.json` + `<base>.bin`. Returns "" on success or a readable error (Bahasa Indonesia);
## never crashes on a missing or malformed asset.
func load_from(base: String) -> String:
	var t0 := Time.get_ticks_usec()
	var meta_path := base + ".json"
	var bin_path := base + ".bin"
	if not FileAccess.file_exists(meta_path):
		return "Data peta tidak ditemukan: " + meta_path
	if not FileAccess.file_exists(bin_path):
		return "Data peta tidak ditemukan: " + bin_path
	# JSON instance parse: returns an error code instead of pushing an engine error on bad input.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(meta_path)) != OK or typeof(json.data) != TYPE_DICTIONARY \
			or json.data.get("schema", "") != SCHEMA:
		return "Data peta rusak atau versi tidak dikenal: " + meta_path
	meta = json.data
	lod = str(meta.get("lod", ""))
	var t1 := Time.get_ticks_usec()
	var bytes := FileAccess.get_file_as_bytes(bin_path)
	var bin_meta: Dictionary = meta.get("bin", {})
	if bytes.size() != int(bin_meta.get("bytes", -1)):
		return "Data peta rusak (ukuran berkas tidak cocok): " + bin_path
	var t2 := Time.get_ticks_usec()
	var sections: Dictionary = bin_meta.get("sections", {})
	for name in ["positions", "region_uv", "triangles", "lines", "province_positions", "province_lines"]:
		if not sections.has(name):
			return "Data peta rusak (bagian %s hilang): %s" % [name, bin_path]
		var s: Dictionary = sections[name]
		if int(s.offset) < 0 or int(s.offset) + int(s.bytes) > bytes.size():
			return "Data peta rusak (bagian %s di luar berkas): %s" % [name, bin_path]
	positions = _slice(bytes, sections.positions).to_vector2_array()
	region_uv = _slice(bytes, sections.region_uv).to_vector2_array()
	triangles = _slice(bytes, sections.triangles).to_int32_array()
	lines = _slice(bytes, sections.lines).to_int32_array()
	province_positions = _slice(bytes, sections.province_positions).to_vector2_array()
	province_lines = _slice(bytes, sections.province_lines).to_int32_array()
	var counts: Dictionary = meta.get("counts", {})
	if positions.size() != int(counts.get("vertices", -1)) or region_uv.size() != positions.size() \
			or triangles.size() != 3 * int(counts.get("triangles", -1)):
		return "Data peta rusak (jumlah verteks/segitiga tidak cocok): " + bin_path
	var t3 := Time.get_ticks_usec()
	var err := _index_regions()
	if err != "":
		return err
	var t4 := Time.get_ticks_usec()
	timings = {"meta_ms": (t1 - t0) / 1000.0, "read_ms": (t2 - t1) / 1000.0,
		"arrays_ms": (t3 - t2) / 1000.0, "index_ms": (t4 - t3) / 1000.0, "total_ms": (t4 - t0) / 1000.0}
	return ""


## Entry index of the selectable kab/kota containing `p`, or -1. Even-odd over every ring of a
## region (outer rings and holes of all parts), so a point in an enclave's hole is NOT in the
## surrounding kabupaten but in the enclave.
func entry_at(p: Vector2) -> int:
	var cell := Vector2i(floori(p.x / GRID_CELL), floori(p.y / GRID_CELL))
	for i in _grid.get(cell, PackedInt32Array()):
		var id := ids[i]
		if kinds[i] != "kabkota" or not (bbox[id] as Rect2).has_point(p):
			continue
		var inside := false
		var rs: Array = rings[id]
		var boxes: Array = ring_boxes[id]
		for k in rs.size():
			if (boxes[k] as Rect2).has_point(p) and point_in_ring(p, rs[k]):
				inside = not inside
		if inside:
			return i
	return -1


## Crossing-number test (half-open edges). Geometry2D.is_point_in_polygon is NOT used: it casts a
## ray to a point ~1e20 away and intersects segments in 32-bit floats, which was measured to report
## points outside metre-scale island rings as inside (regression: test_map fixture, 2026-10-22).
static func point_in_ring(p: Vector2, ring: PackedVector2Array) -> bool:
	var inside := false
	var j := ring.size() - 1
	for i in ring.size():
		var a := ring[i]
		var b := ring[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < a.x + (p.y - a.y) * (b.x - a.x) / (b.y - a.y):
			inside = not inside
		j = i
	return inside


func region_at(p: Vector2) -> String:
	var i := entry_at(p)
	return ids[i] if i >= 0 else ""


func _index_regions() -> String:
	var table: Array = meta.get("regions", [])
	ids.clear()
	kinds.clear()
	index_of.clear()
	rings.clear()
	ring_boxes.clear()
	bbox.clear()
	_grid.clear()
	for i in table.size():
		var r: Dictionary = table[i]
		var id := str(r.get("id", ""))
		if id == "" or index_of.has(id):
			return "Data peta rusak (id wilayah kosong atau ganda): %s" % id
		ids.append(id)
		kinds.append(str(r.get("kind", "")))
		index_of[id] = i
		var rs: Array[PackedVector2Array] = []
		var boxes: Array[Rect2] = []
		for ring in r.get("rings", []):
			var start := int(ring[0])
			var n := int(ring[1])
			if n < 3 or start < 0 or start + n > positions.size():
				return "Data peta rusak (cincin poligon %s)" % id
			var pts := positions.slice(start, start + n)
			rs.append(pts)
			var box := Rect2(pts[0], Vector2.ZERO)
			for v in pts:
				box = box.expand(v)
			boxes.append(box)
		rings[id] = rs
		ring_boxes[id] = boxes
		var b: Array = r.get("bbox", [0, 0, 0, 0])
		var rect := Rect2(b[0], b[1], b[2] - b[0], b[3] - b[1])
		bbox[id] = rect
		for x in range(floori(rect.position.x / GRID_CELL), floori(rect.end.x / GRID_CELL) + 1):
			for y in range(floori(rect.position.y / GRID_CELL), floori(rect.end.y / GRID_CELL) + 1):
				var key := Vector2i(x, y)
				var arr: PackedInt32Array = _grid.get(key, PackedInt32Array())
				arr.append(i)
				_grid[key] = arr
	var b2: Array = meta.get("bounds", [0, 0, 0, 0])
	bounds = Rect2(b2[0], b2[1], b2[2] - b2[0], b2[3] - b2[1])
	return ""


static func _slice(bytes: PackedByteArray, s: Dictionary) -> PackedByteArray:
	return bytes.slice(int(s.offset), int(s.offset) + int(s.bytes))
