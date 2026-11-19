class_name MapPreview
extends Control
## Embedded report/case map reuses the exact offline triangulation and hit testing.
signal selected(region_id: String)
var lod: MapLod
var values: Dictionary = {}
var focus_ids: Array = []
var _mesh: ArrayMesh
var _transform := Transform2D.IDENTITY


func _ready() -> void:
	custom_minimum_size = Vector2(400, 190)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	resized.connect(queue_redraw)
	if lod == null:
		return
	var colors := PackedColorArray()
	for uv in lod.region_uv:
		var rid: String = lod.ids[int(uv.x)]
		colors.append(values.get(rid, Color("8fbf7f")))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = lod.positions
	arrays[Mesh.ARRAY_INDEX] = lod.triangles
	arrays[Mesh.ARRAY_COLOR] = colors
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("287eaf"))
	if lod == null or _mesh == null:
		return
	var bounds := lod.bounds
	if not focus_ids.is_empty():
		bounds = lod.bbox.get(str(focus_ids[0]), bounds)
		for id in focus_ids:
			bounds = bounds.merge(lod.bbox.get(str(id), bounds))
	var scale_factor := minf((size.x - 20) / bounds.size.x, (size.y - 20) / bounds.size.y)
	var offset := size / 2 - bounds.get_center() * scale_factor
	_transform = Transform2D(Vector2(scale_factor, 0), Vector2(0, scale_factor), offset)
	draw_set_transform(offset, 0.0, Vector2.ONE * scale_factor)
	draw_mesh(_mesh, null)
	var borders := PackedVector2Array()
	for index in lod.province_lines:
		borders.append(lod.province_positions[index])
	if not borders.is_empty():
		draw_multiline(borders, Color("15294f"), 0.8 / scale_factor, true)
	for id in focus_ids:
		for ring in lod.rings.get(str(id), []):
			var outline: PackedVector2Array = ring.duplicate()
			outline.append(ring[0])
			draw_polyline(outline, UiKit.ACCENT, 1.5 / scale_factor, true)
	draw_set_transform(Vector2.ZERO)


func _gui_input(event: InputEvent) -> void:
	if lod == null or not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var entry := lod.entry_at(_transform.affine_inverse() * event.position)
	if entry >= 0:
		selected.emit(lod.ids[entry])
	accept_event()
