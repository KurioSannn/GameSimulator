class_name StoryPortrait
extends Control
## Character portrait for dialogue. Uses the team's art when the cast record has a portrait path;
## otherwise draws a generated medallion (role colour, bust silhouette, initials) that is clearly a
## placeholder ("art_pending") until the art team supplies a drawing. Expressions animate subtly.

var character: Dictionary = {}
var expression := "netral"
var _tex: Texture2D
var _anim := 0.0
var _motion := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motion = not bool(UiPreferences.values.get("reduce_motion", false))


func show_character(c: Dictionary, expr: String) -> void:
	character = c
	expression = expr if expr != "" else "netral"
	_tex = null
	var path := expression_path(c, expression)
	if path != "" and ResourceLoader.exists(path):
		_tex = load(path)
	_anim = 0.0
	set_process(_motion)
	queue_redraw()


## Expression families map the script's many moods onto the drawn variants (netral, senyum, cemas,
## serius); a character without a variant keeps the base portrait.
const EXPRESSION_FAMILY := {
	"senyum": "senyum", "lega": "senyum", "yakin": "senyum", "bangga": "senyum",
	"cemas": "cemas", "sedih": "cemas", "kecewa": "cemas", "terkejut": "cemas",
	"serius": "serius", "marah": "serius", "berpikir": "serius",
}


static func expression_path(c: Dictionary, expr: String) -> String:
	var variants: Dictionary = c.get("expressions", {})
	var fam := str(EXPRESSION_FAMILY.get(expr, ""))
	if fam != "" and variants.has(fam):
		return str(variants[fam])
	return str(c.get("portrait", ""))


func _process(delta: float) -> void:
	_anim += delta
	if _anim > 0.6:
		set_process(false)
	queue_redraw()


func _offset() -> Vector2:
	if not _motion:
		return Vector2.ZERO
	var k := clampf(1.0 - _anim / 0.6, 0.0, 1.0)
	match expression:
		"marah", "terkejut":
			return Vector2(sin(_anim * 60.0) * 4.0 * k, 0)
		"senyum", "lega", "yakin":
			return Vector2(0, -absf(sin(_anim * 10.0)) * 6.0 * k)
		"sedih", "kecewa":
			return Vector2(0, 6.0 * (1.0 - k))
	return Vector2(0, -8.0 * k)


func _draw() -> void:
	if character.is_empty():
		return
	var off := _offset()
	var kind := str(character.get("portrait_kind", "generated"))
	if _tex != null:
		var ts := _tex.get_size()
		var scale := minf(size.x / ts.x, size.y / ts.y)
		if kind == "avatar":
			scale = minf(size.x * 0.7 / ts.x, size.y * 0.5 / ts.y)
		if kind == "card":
			_draw_card(off)
			return
		var ds := ts * scale
		var pos := Vector2((size.x - ds.x) * 0.5, size.y - ds.y) + off
		if kind == "avatar":
			pos.y = size.y - ds.y - 12
			var frame := Rect2(pos - Vector2(8, 8), ds + Vector2(16, 16))
			draw_rect(frame, Color("f4e6c4"))
			draw_rect(frame, Color("6a4a2a"), false, 4)
		draw_texture_rect(_tex, Rect2(pos, ds), false)
		return
	# Generated medallion (art pending): circle + bust silhouette + initials.
	var col := Color(str(character.get("color", "8a7a5a")))
	var r := minf(size.x * 0.3, size.y * 0.26)
	var c := Vector2(size.x * 0.5, size.y - r - 70) + off
	draw_circle(c, r + 6, Color("f4e6c4"))
	draw_circle(c, r, col)
	draw_circle(c + Vector2(0, -r * 0.28), r * 0.3, col.lightened(0.35))
	var shoulders := PackedVector2Array()
	for i in 21:
		var a := PI + PI * i / 20.0
		shoulders.append(c + Vector2(cos(a) * r * 0.62, r * 0.62 + sin(a) * r * 0.42))
	draw_colored_polygon(shoulders, col.lightened(0.35))
	var font := get_theme_default_font()
	var ini := str(character.get("initials", str(character.get("name", "?")).left(1)))
	var fs := int(r * 0.3)
	var tw := font.get_string_size(ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, c + Vector2(-tw * 0.5, r * 0.62), ini, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("1f1a14", 0.85))
	draw_arc(c, r + 6, 0, TAU, 64, Color("6a4a2a"), 4)


## Framed portrait card (advisers and episode locals): square art in a cream frame with a dark
## outline and soft shadow, bottom-aligned above the name plate like the team's avatar style.
func _draw_card(off: Vector2) -> void:
	var side := minf(size.x * 0.72, size.y * 0.74)
	var pos := Vector2((size.x - side) * 0.5, size.y * 0.86 - side) + off
	var rect := Rect2(pos, Vector2(side, side))
	draw_rect(Rect2(rect.position + Vector2(8, 10), rect.size + Vector2(12, 12)), Color(0, 0, 0, 0.28))
	var frame := rect.grow(10)
	draw_rect(frame, Color("f4e6c4"))
	draw_rect(frame, Color("6a4a2a"), false, 4)
	draw_texture_rect(_tex, rect, false)
	draw_rect(rect, Color("6a4a2a"), false, 2)
