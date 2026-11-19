class_name TrustChart
extends Control
## Draws recorded quarterly/monthly observations cleanly; never interpolates unrecorded samples.
var points: Array = []  # [{tick, value}] supplied by current ledger and event history


func _ready() -> void:
	custom_minimum_size = Vector2(460, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var area := Rect2(56, 30, maxf(10, size.x - 96), maxf(10, size.y - 68))
	var font := get_theme_default_font()
	var axis_size := UiKit.font_size(14)
	var val_size := UiKit.font_size(16)

	for n in 5:
		var y := area.end.y - area.size.y * float(n) / 4.0
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(UiKit.MUTED, 0.25), 1.0)
		draw_string(font, Vector2(4, y + 4), "%d%%" % (n * 25), HORIZONTAL_ALIGNMENT_RIGHT, 44, axis_size, UiKit.MUTED)

	if points.is_empty():
		draw_string(font, area.position + Vector2(12, area.size.y * 0.5), "Riwayat belum tersedia.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiKit.MUTED)
		return

	var path := PackedVector2Array()
	var first := int(points[0].tick)
	var last := maxi(first + 1, int(points[-1].tick))
	for point in points:
		var px := area.position.x + area.size.x * float(int(point.tick) - first) / float(last - first)
		var py := area.end.y - area.size.y * clampf(float(point.value) / 100.0, 0.0, 1.0)
		path.append(Vector2(px, py))

	if path.size() > 1:
		var top_col := Color(UiKit.ACCENT, 0.22)
		var bot_col := Color(UiKit.ACCENT, 0.0)
		for i in path.size() - 1:
			var p0 := path[i]
			var p1 := path[i + 1]
			var b0 := Vector2(p0.x, area.end.y)
			var b1 := Vector2(p1.x, area.end.y)
			draw_polygon(
				PackedVector2Array([p0, p1, b1, b0]),
				PackedColorArray([top_col, top_col, bot_col, bot_col])
			)
		draw_polyline(path, UiKit.ACCENT, 3.5, true)

	for i in path.size():
		var pt := path[i]
		draw_circle(pt, 8.0, Color(UiKit.ACCENT, 0.25))
		draw_circle(pt, 5.0, UiKit.ACCENT)
		draw_circle(pt, 2.2, Color.WHITE)

		var txt := Fmt.num(float(points[i].value), 1) + "%"
		var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, val_size).x
		var lx := clampf(pt.x - tw * 0.5, area.position.x + 4.0, area.end.x - tw - 4.0)
		var ly := pt.y - 12.0 if pt.y > area.position.y + 22.0 else pt.y + 20.0
		draw_string(font, Vector2(lx, ly), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, val_size, UiKit.TEXT)

		var tick_txt := "Bln %d" % int(points[i].tick)
		var tkw := font.get_string_size(tick_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, axis_size).x
		var tkx := clampf(pt.x - tkw * 0.5, area.position.x, area.end.x - tkw)
		draw_string(font, Vector2(tkx, area.end.y + 22), tick_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, axis_size, UiKit.MUTED)
