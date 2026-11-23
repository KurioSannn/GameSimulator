class_name StoryBackdrop
extends Control
## Original procedural story backgrounds (no third-party art). Each kind = sky gradient + light +
## layered silhouettes + optional weather. "peta" is a translucent veil so the live 3D map of
## Indonesia stays visible behind the dialogue. Respects reduced motion.

const KINDS := {
	"istana_pagi": {"sky": ["9fd3e6", "f6e1b5"], "ground": "6f8f4e", "sun": "fff1c1", "shape": "istana"},
	"istana_siang": {"sky": ["6fb7da", "d8efe8"], "ground": "6f8f4e", "sun": "fffbe6", "shape": "istana"},
	"ruang_kerja": {"sky": ["5a4632", "8a6a48"], "ground": "3e2f22", "sun": "", "shape": "interior"},
	"ruang_rapat": {"sky": ["3f4b5a", "6c7a86"], "ground": "2d343c", "sun": "", "shape": "rapat"},
	"peta": {"sky": [], "ground": "", "sun": "", "shape": "veil"},
	"senja": {"sky": ["2b3a67", "f29e6b"], "ground": "3a3b2a", "sun": "ffcf8a", "shape": "istana"},
	"malam": {"sky": ["0c1328", "26345c"], "ground": "151a26", "sun": "e8eefc", "shape": "istana"},
	"kota": {"sky": ["8cc4e0", "e6efe9"], "ground": "596068", "sun": "fff6d8", "shape": "kota"},
	"kota_hujan": {"sky": ["4d5a66", "8b96a0"], "ground": "3c4650", "sun": "", "shape": "kota", "weather": "hujan"},
	"kota_gelap": {"sky": ["1d2433", "3b4560"], "ground": "1b2029", "sun": "", "shape": "kota_gelap"},
	"pesisir": {"sky": ["7fc6e4", "f2ead2"], "ground": "e3cf9a", "sun": "fff3c8", "shape": "pesisir"},
	"pesisir_rusak": {"sky": ["8a9aa6", "d6d1c4"], "ground": "a8957a", "sun": "", "shape": "pesisir_rusak"},
	"pesisir_malam": {"sky": ["0d1630", "2c3d6b"], "ground": "1c2338", "sun": "dfe7ff", "shape": "pesisir"},
	"pasar": {"sky": ["e7c58d", "f6e6c8"], "ground": "8a6a48", "sun": "", "shape": "pasar"},
	"kebun": {"sky": ["9ed0e2", "eef3d8"], "ground": "4f7a3a", "sun": "fff3c8", "shape": "sawit"},
	"ladang": {"sky": ["b7d6df", "efe6c6"], "ground": "7a8a3a", "sun": "fff0c0", "shape": "ladang"},
	"gambut": {"sky": ["a6c9cf", "e5ead3"], "ground": "4a5a34", "sun": "fff3c8", "shape": "ladang"},
	"asap": {"sky": ["b59a5a", "d9c58e"], "ground": "5a5236", "sun": "f7e6a6", "shape": "ladang", "weather": "asap"},
	"industri": {"sky": ["2a2f45", "7a5a5a"], "ground": "2c2a2e", "sun": "", "shape": "industri"},
	"kering": {"sky": ["e9c98f", "f7ead0"], "ground": "c09a62", "sun": "fff4cc", "shape": "kering"},
	"pegunungan": {"sky": ["9dc6d8", "e6efe6"], "ground": "3f6a3a", "sun": "fff6dc", "shape": "gunung", "weather": "kabut"},
	"rawa": {"sky": ["a9d3d8", "ecf1e2"], "ground": "4a6a4a", "sun": "fff6dc", "shape": "rawa"},
	"pelabuhan": {"sky": ["4f6d8f", "e7b98a"], "ground": "2e3e52", "sun": "ffd9a0", "shape": "pelabuhan"},
	"laut": {"sky": ["8ccde8", "e9f4f4"], "ground": "2f7ea6", "sun": "fff8e0", "shape": "laut"},
	"hutan": {"sky": ["a6d1c7", "e8f0dc"], "ground": "35603a", "sun": "fff6dc", "shape": "hutan"},
	"danau": {"sky": ["9fd0e4", "ecf3ea"], "ground": "3f6f5a", "sun": "fff6dc", "shape": "danau"},
	"banjir_bandang": {"sky": ["56606a", "9aa0a2"], "ground": "6a5a44", "sun": "", "shape": "gunung", "weather": "hujan"},
	"rumah_sakit": {"sky": ["d9e7ea", "f4f7f4"], "ground": "c9d3d6", "sun": "", "shape": "rumah_sakit"},
	"gunung_api": {"sky": ["4a4650", "a8907a"], "ground": "5a5048", "sun": "", "shape": "gunung_api", "weather": "asap"},
	"desa": {"sky": ["a8d6e6", "eef3dc"], "ground": "6a8a42", "sun": "fff3c8", "shape": "desa"},
}

const ART_DIR := "res://assets/story/backgrounds/"

var kind := "ruang_kerja"
var _t := 0.0
var _motion := true
var _art: Texture2D
static var _art_cache := {}


## Painted backdrop for a kind (game/assets/story/backgrounds/<kind>.jpg), or null when none exists
## (the procedural drawing below is then used, e.g. for the map veil).
static func art_for(k: String) -> Texture2D:
	if not _art_cache.has(k):
		var path := ART_DIR + k + ".jpg"
		_art_cache[k] = load(path) if ResourceLoader.exists(path) else null
	return _art_cache[k]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_motion = not bool(UiPreferences.values.get("reduce_motion", false))
	set_process(_motion)


func set_kind(k: String) -> void:
	kind = k if KINDS.has(k) else "ruang_kerja"
	_art = art_for(kind)
	_t = 0.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if _art != null:
		queue_redraw()
		return
	if KINDS[kind].has("weather") or KINDS[kind].shape in ["pesisir", "laut", "danau", "rawa", "pelabuhan", "industri"]:
		queue_redraw()


static func _c(hex: String, a := 1.0) -> Color:
	return Color(hex, a)


func _draw() -> void:
	var spec: Dictionary = KINDS.get(kind, KINDS.ruang_kerja)
	var w := size.x
	var h := size.y
	if spec.shape == "veil":
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.07, 0.12, 0.35))
		return
	if _art != null:
		_draw_art(w, h)
		return
	var sky: Array = spec.sky
	var top := _c(sky[0])
	var bot := _c(sky[1])
	var bands := 24
	for i in bands:
		var y0 := h * 0.72 * i / bands
		draw_rect(Rect2(0, y0, w, h * 0.72 / bands + 1), top.lerp(bot, float(i) / (bands - 1)))
	if str(spec.sun) != "":
		var sun := Vector2(w * 0.78, h * 0.22)
		for r in [110.0, 80.0, 52.0]:
			draw_circle(sun, r * h / 900.0, Color(spec.sun, 0.12 if r > 60 else 0.9))
	var horizon := h * 0.68
	draw_rect(Rect2(0, horizon, w, h - horizon), _c(spec.ground))
	call("_shape_" + str(spec.shape), w, h, horizon, spec)
	match str(spec.get("weather", "")):
		"hujan":
			var rain := Color(0.85, 0.9, 1.0, 0.28)
			for i in 140:
				var x := fmod(i * 97.13 + _t * 380.0, w + 60.0) - 30.0
				var y := fmod(i * 53.7 + _t * 900.0, h)
				draw_line(Vector2(x, y), Vector2(x - 6, y + 22), rain, 1.5)
		"asap":
			for i in 7:
				var x := fmod(i * 260.0 + _t * 12.0, w + 400.0) - 200.0
				draw_circle(Vector2(x, h * (0.35 + 0.06 * (i % 3))), h * 0.28, Color(0.85, 0.72, 0.42, 0.18))
		"kabut":
			for i in 5:
				var x := fmod(i * 340.0 + _t * 8.0, w + 400.0) - 200.0
				draw_circle(Vector2(x, horizon - h * 0.06), h * 0.16, Color(1, 1, 1, 0.16))
	# soft vignette for dialogue readability
	draw_rect(Rect2(0, h * 0.62, w, h * 0.38), Color(0, 0, 0, 0.22))


## Painted backdrop scaled to cover the screen, with a very slow drift (none with reduced motion) and
## the same lower-third shade the procedural scenes use so dialogue stays readable.
func _draw_art(w: float, h: float) -> void:
	var ts := _art.get_size()
	var zoom := 1.06 if _motion else 1.0
	var sc := maxf(w / ts.x, h / ts.y) * zoom
	var ds := ts * sc
	var drift := 0.0
	if _motion:
		drift = sin(_t * 0.05) * (ds.x - w) * 0.5
	var pos := Vector2((w - ds.x) * 0.5 + drift, (h - ds.y) * 0.5)
	draw_texture_rect(_art, Rect2(pos, ds), false)
	for i in 12:
		var y0 := h * (0.6 + 0.4 * i / 12.0)
		draw_rect(Rect2(0, y0, w, h * 0.4 / 12.0 + 1), Color(0, 0, 0, 0.03 * i))


func _poly(points: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), col)


func _hills(w: float, horizon: float, col: Color, amp: float, phase: float) -> void:
	var pts: Array = [Vector2(0, horizon + 2)]
	for i in 25:
		var x := w * i / 24.0
		pts.append(Vector2(x, horizon - amp * (0.6 + 0.4 * sin(i * 0.9 + phase))))
	pts.append(Vector2(w, horizon + 2))
	_poly(pts, col)


func _shape_istana(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_hills(w, horizon, _c(spec.ground).darkened(0.15), h * 0.05, 1.2)
	var cx := w * 0.42
	var bw := w * 0.36
	var bh := h * 0.16
	var base := horizon
	var wall := Color("f4efe4") if kind != "malam" else Color("5a6070")
	draw_rect(Rect2(cx - bw / 2, base - bh, bw, bh), wall)
	_poly([Vector2(cx - bw * 0.56, base - bh), Vector2(cx, base - bh * 1.55), Vector2(cx + bw * 0.56, base - bh)], Color("c9472f") if kind != "malam" else Color("3a2a30"))
	for i in 8:
		var x := cx - bw * 0.44 + bw * 0.88 * i / 7.0
		draw_rect(Rect2(x - 4, base - bh * 0.92, 8, bh * 0.92), wall.darkened(0.08))
	draw_rect(Rect2(cx - bw * 0.62, base - 6, bw * 1.24, 8), wall.darkened(0.15))
	draw_line(Vector2(cx, base - bh * 1.55), Vector2(cx, base - bh * 2.2), Color("4a4a4a"), 2)
	_poly([Vector2(cx, base - bh * 2.2), Vector2(cx + 28, base - bh * 2.12), Vector2(cx, base - bh * 2.04)], Color("d8332b"))
	_poly([Vector2(cx, base - bh * 2.04), Vector2(cx + 28, base - bh * 1.96), Vector2(cx, base - bh * 1.88)], Color("f4f4f4"))
	_trees(w, horizon, 7, Color("2f5a35"))


func _shape_interior(w: float, h: float, horizon: float, _spec: Dictionary) -> void:
	draw_rect(Rect2(w * 0.08, h * 0.1, w * 0.3, h * 0.36), Color("cfe3ea"))
	draw_rect(Rect2(w * 0.08, h * 0.1, w * 0.3, h * 0.36), Color("3e2f22"), false, 10)
	draw_line(Vector2(w * 0.23, h * 0.1), Vector2(w * 0.23, h * 0.46), Color("3e2f22"), 6)
	draw_rect(Rect2(w * 0.5, h * 0.14, w * 0.4, h * 0.3), Color("2f6f73", 0.85))
	draw_rect(Rect2(w * 0.5, h * 0.14, w * 0.4, h * 0.3), Color("c9a46a"), false, 6)
	for i in 6:
		var x := w * 0.53 + i * w * 0.06
		_poly([Vector2(x, h * 0.3), Vector2(x + w * 0.04, h * 0.27 + (i % 2) * h * 0.02), Vector2(x + w * 0.05, h * 0.33), Vector2(x + w * 0.01, h * 0.34)], Color("8cbf6a"))
	draw_rect(Rect2(w * 0.25, horizon - h * 0.08, w * 0.5, h * 0.1), Color("6a4a2a"))
	for i in 5:
		draw_rect(Rect2(w * 0.3 + i * w * 0.08, horizon - h * 0.1, w * 0.05, h * 0.02), Color("f4ecd8"))


func _shape_rapat(w: float, h: float, horizon: float, _spec: Dictionary) -> void:
	for i in 5:
		draw_rect(Rect2(w * (0.06 + i * 0.19), h * 0.12, w * 0.12, h * 0.34), Color("8fb0c4", 0.7))
	_poly([Vector2(w * 0.12, horizon), Vector2(w * 0.88, horizon), Vector2(w * 0.76, horizon - h * 0.1), Vector2(w * 0.24, horizon - h * 0.1)], Color("5a3e28"))
	for i in 6:
		draw_circle(Vector2(w * (0.27 + i * 0.09), horizon - h * 0.13), h * 0.022, Color("1f2630"))


func _shape_kota(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	var dark := kind == "kota_hujan"
	for layer in 2:
		var col := Color("7d8a96") if layer == 0 else Color("4f5a66")
		if dark:
			col = col.darkened(0.25)
		for i in 14:
			var bw := w * (0.05 + 0.02 * ((i * 7 + layer) % 3))
			var bh := h * (0.14 + 0.05 * ((i * 5 + layer * 3) % 5)) * (0.75 if layer == 0 else 1.0)
			var x := w * i / 13.0 - bw * 0.5 + layer * w * 0.03
			draw_rect(Rect2(x, horizon - bh, bw, bh), col)
			if layer == 1:
				for wy in 4:
					for wx in 2:
						var lit := ((i + wy + wx) % 3) != 0
						draw_rect(Rect2(x + bw * (0.2 + wx * 0.4), horizon - bh + bh * (0.15 + wy * 0.2), bw * 0.18, bh * 0.08),
							Color("ffe9a7", 0.8) if lit and not dark else Color("c9d6de", 0.4))
	if dark:
		draw_rect(Rect2(0, horizon - h * 0.03, w, h * 0.06), Color("6a7d8c", 0.55))


func _shape_kota_gelap(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	for i in 14:
		var bw := w * (0.05 + 0.02 * (i % 3))
		var bh := h * (0.16 + 0.05 * ((i * 5) % 5))
		draw_rect(Rect2(w * i / 13.0 - bw * 0.5, horizon - bh, bw, bh), Color("2a3142"))
	for i in 3:
		draw_circle(Vector2(w * (0.2 + i * 0.3), horizon - h * 0.02), 3, Color("ffd27a", 0.9))


func _waves(w: float, y: float, col: Color, amp: float, speed: float) -> void:
	var pts: Array = [Vector2(0, y + 40)]
	for i in 41:
		var x := w * i / 40.0
		pts.append(Vector2(x, y + amp * sin(i * 0.7 + _t * speed)))
	pts.append(Vector2(w, y + 40))
	_poly(pts, col)


func _shape_pesisir(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	var night := kind == "pesisir_malam"
	draw_rect(Rect2(0, h * 0.5, w, horizon - h * 0.5), Color("2f7ea6") if not night else Color("15244a"))
	_waves(w, h * 0.55, Color("3f93bd", 0.8) if not night else Color("22345e", 0.8), 4, 1.2)
	_waves(w, horizon - 6, Color("e8f4f4", 0.7) if not night else Color("8aa0c8", 0.5), 3, 1.8)
	for i in 4:
		var x := w * (0.08 + i * 0.07)
		draw_line(Vector2(x, horizon + 4), Vector2(x + 18, horizon - h * 0.2), Color("4a3a24"), 6)
		for k in 5:
			var a := k * 1.25
			draw_line(Vector2(x + 18, horizon - h * 0.2), Vector2(x + 18 + cos(a) * 46, horizon - h * 0.2 + sin(a) * 22 - 10), Color("2f6a35"), 5)
	if night:
		for i in 6:
			draw_rect(Rect2(w * (0.55 + i * 0.06), horizon - h * 0.05, w * 0.04, h * 0.04), Color("ffcf7a", 0.75))


func _shape_pesisir_rusak(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	draw_rect(Rect2(0, h * 0.5, w, horizon - h * 0.5), Color("5f7f8f"))
	for i in 18:
		var x := w * (0.05 + i * 0.053)
		var tilt := sin(i * 2.3) * 14.0
		_poly([Vector2(x, horizon + 8), Vector2(x + 40, horizon + 4), Vector2(x + 34 + tilt, horizon - 18 - (i % 3) * 10), Vector2(x + tilt, horizon - 10)], Color("7a6a54"))
	for i in 9:
		draw_line(Vector2(w * (0.1 + i * 0.1), horizon + 20), Vector2(w * (0.14 + i * 0.1), horizon - 14), Color("4a3a2a"), 5)


func _shape_pasar(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	var colors := ["d8332b", "2f6f73", "e1a23a", "4f7a3a", "8a4a6a"]
	for i in 7:
		var x := w * (0.02 + i * 0.14)
		draw_rect(Rect2(x, horizon - h * 0.12, w * 0.12, h * 0.12), Color("caa77a"))
		for s in 6:
			draw_rect(Rect2(x + s * w * 0.02, horizon - h * 0.2, w * 0.02, h * 0.06), Color(colors[(i + s) % 5]) if s % 2 == 0 else Color("f4ecd8"))
		for k in 4:
			draw_circle(Vector2(x + w * (0.02 + k * 0.027), horizon - h * 0.125), 7, Color(colors[(i + k + 2) % 5]).lightened(0.2))


func _trees(w: float, horizon: float, n: int, col: Color) -> void:
	for i in n:
		var x := w * (0.04 + i * 0.95 / n) + 20 * sin(i * 3.1)
		var th := 40.0 + 20.0 * ((i * 7) % 3)
		draw_line(Vector2(x, horizon + 2), Vector2(x, horizon - th * 0.6), Color("4a3a24"), 4)
		draw_circle(Vector2(x, horizon - th * 0.8), th * 0.42, col)


func _shape_sawit(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_hills(w, horizon, Color("5f8a46"), h * 0.06, 0.4)
	for row in 2:
		for i in 12:
			var x := w * (0.03 + i * 0.085) + row * w * 0.04
			var base := horizon + row * h * 0.08
			draw_line(Vector2(x, base), Vector2(x, base - h * 0.12), Color("5a4630"), 6)
			for k in 7:
				var a := -PI + k * PI / 6.0
				draw_line(Vector2(x, base - h * 0.12), Vector2(x + cos(a) * 44, base - h * 0.12 + sin(a) * 26 + 12), Color("2e5a2a"), 5)


func _shape_ladang(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_hills(w, horizon, _c(spec.ground).darkened(0.2), h * 0.07, 2.0)
	for i in 6:
		draw_rect(Rect2(w * (0.05 + i * 0.16), horizon + h * 0.04, w * 0.12, h * 0.05), _c(spec.ground).lightened(0.15))
	_trees(w, horizon, 5, Color("3f6a30") if kind != "asap" else Color("5a5a3a"))


func _shape_industri(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	for i in 5:
		var x := w * (0.1 + i * 0.17)
		draw_rect(Rect2(x, horizon - h * 0.14, w * 0.12, h * 0.14), Color("3a3a44"))
		draw_rect(Rect2(x + w * 0.08, horizon - h * 0.32, w * 0.025, h * 0.18), Color("4a4a54"))
		var puff := fmod(_t * 6.0 + i * 9.0, 40.0)
		for k in 3:
			draw_circle(Vector2(x + w * 0.092, horizon - h * 0.34 - k * 26 - puff), 16 + k * 6, Color(0.75, 0.7, 0.72, 0.3 - k * 0.08))
		for k in 3:
			draw_rect(Rect2(x + w * (0.015 + k * 0.035), horizon - h * 0.08, w * 0.02, h * 0.03), Color("ff9a4a", 0.85))


func _shape_kering(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_hills(w, horizon, Color("b0884f"), h * 0.05, 0.7)
	for i in 30:
		var x := w * (i * 0.034)
		var y := horizon + h * (0.03 + 0.2 * ((i * 37) % 10) / 10.0)
		draw_line(Vector2(x, y), Vector2(x + 26, y + 8 * sin(i)), Color("8a6a3a"), 2)
	for i in 3:
		var x := w * (0.2 + i * 0.3)
		draw_line(Vector2(x, horizon), Vector2(x, horizon - h * 0.16), Color("5a4630"), 5)
		draw_line(Vector2(x, horizon - h * 0.1), Vector2(x + 30, horizon - h * 0.16), Color("5a4630"), 3)
		draw_line(Vector2(x, horizon - h * 0.12), Vector2(x - 24, horizon - h * 0.18), Color("5a4630"), 3)


func _shape_gunung(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_poly([Vector2(-w * 0.1, horizon), Vector2(w * 0.28, h * 0.2), Vector2(w * 0.62, horizon)], Color("5a7a5a"))
	_poly([Vector2(w * 0.35, horizon), Vector2(w * 0.72, h * 0.26), Vector2(w * 1.1, horizon)], Color("4a6a4a"))
	_trees(w, horizon, 9, Color("2f5a35"))


func _shape_rawa(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	draw_rect(Rect2(0, horizon - h * 0.02, w, h * 0.1), Color("5f8a7a"))
	_waves(w, horizon + h * 0.04, Color("6f9a8a", 0.8), 2, 0.8)
	draw_rect(Rect2(w * 0.1, horizon - h * 0.07, w * 0.8, h * 0.015), Color("8a6a48"))
	for i in 16:
		draw_line(Vector2(w * (0.11 + i * 0.05), horizon - h * 0.06), Vector2(w * (0.11 + i * 0.05), horizon + h * 0.05), Color("6a4a2a"), 3)
	for i in 4:
		var x := w * (0.15 + i * 0.22)
		draw_rect(Rect2(x, horizon - h * 0.16, w * 0.1, h * 0.09), Color("a07a50"))
		_poly([Vector2(x - 8, horizon - h * 0.16), Vector2(x + w * 0.05, horizon - h * 0.22), Vector2(x + w * 0.1 + 8, horizon - h * 0.16)], Color("5a3e28"))
	_trees(w, horizon - h * 0.08, 6, Color("2f6a45"))


func _shape_pelabuhan(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	draw_rect(Rect2(0, h * 0.52, w, horizon - h * 0.52), Color("3a5a7a"))
	_waves(w, h * 0.6, Color("4a6a8a", 0.7), 3, 1.0)
	for i in 6:
		var x := w * (0.08 + i * 0.15)
		var bob := sin(_t * 1.4 + i) * 3.0
		_poly([Vector2(x, horizon - 14 + bob), Vector2(x + w * 0.11, horizon - 14 + bob), Vector2(x + w * 0.095, horizon + bob), Vector2(x + w * 0.015, horizon + bob)], Color(["c9472f", "2f6f73", "e1a23a"][i % 3]))
		draw_line(Vector2(x + w * 0.05, horizon - 14 + bob), Vector2(x + w * 0.05, horizon - h * 0.14 + bob), Color("3a2a1a"), 3)
	draw_rect(Rect2(0, horizon, w, h * 0.04), Color("5a4630"))


func _shape_laut(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	draw_rect(Rect2(0, h * 0.5, w, h * 0.5), Color("2f7ea6"))
	for k in 4:
		_waves(w, h * (0.56 + k * 0.1), Color("4a9ac4", 0.55 - k * 0.08), 5, 1.0 + k * 0.4)
	var bob := sin(_t * 1.2) * 4.0
	_poly([Vector2(w * 0.4, h * 0.6 + bob), Vector2(w * 0.55, h * 0.6 + bob), Vector2(w * 0.53, h * 0.64 + bob), Vector2(w * 0.42, h * 0.64 + bob)], Color("c9472f"))


func _shape_hutan(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_hills(w, horizon, Color("3f6a45"), h * 0.1, 0.3)
	_trees(w, horizon, 14, Color("2a5a32"))
	_trees(w, horizon + h * 0.08, 10, Color("35703a"))


func _shape_danau(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_poly([Vector2(0, horizon), Vector2(w * 0.3, h * 0.36), Vector2(w * 0.7, horizon)], Color("4f7a5a"))
	draw_rect(Rect2(0, horizon, w, h * 0.14), Color("4a8ab0"))
	_waves(w, horizon + h * 0.02, Color("6aa6c8", 0.6), 2, 0.7)
	_trees(w, horizon, 6, Color("2f6a45"))


func _shape_rumah_sakit(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	draw_rect(Rect2(0, h * 0.08, w, h * 0.6), Color("eef3f2"))
	for i in 6:
		draw_rect(Rect2(w * (0.04 + i * 0.16), h * 0.16, w * 0.1, h * 0.2), Color("bcd8e0"))
	draw_rect(Rect2(w * 0.45, h * 0.42, w * 0.1, h * 0.04), Color("d8332b"))
	draw_rect(Rect2(w * 0.48, h * 0.39, w * 0.04, h * 0.1), Color("d8332b"))
	for i in 5:
		draw_rect(Rect2(w * (0.1 + i * 0.18), horizon - h * 0.06, w * 0.08, h * 0.02), Color("8a9aa0"))


func _shape_desa(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_hills(w, horizon, Color("5f8a46"), h * 0.08, 1.7)
	for i in 5:
		var x := w * (0.08 + i * 0.19)
		draw_rect(Rect2(x, horizon - h * 0.08, w * 0.09, h * 0.08), Color("e9dcc0"))
		_poly([Vector2(x - 10, horizon - h * 0.08), Vector2(x + w * 0.045, horizon - h * 0.15), Vector2(x + w * 0.09 + 10, horizon - h * 0.08)], Color("a0452f"))
	_trees(w, horizon, 6, Color("3f7a3a"))


func _shape_gunung_api(w: float, h: float, horizon: float, spec: Dictionary) -> void:
	_poly([Vector2(w * 0.05, horizon), Vector2(w * 0.42, h * 0.16), Vector2(w * 0.5, h * 0.14), Vector2(w * 0.9, horizon)], Color("4a403a"))
	for i in 4:
		draw_circle(Vector2(w * 0.46 + i * 18, h * 0.1 - i * 22 - fmod(_t * 5.0, 20.0)), 30 + i * 10, Color(0.55, 0.5, 0.48, 0.45 - i * 0.08))
	_poly([Vector2(w * 0.4, h * 0.2), Vector2(w * 0.46, h * 0.18), Vector2(w * 0.56, horizon), Vector2(w * 0.36, horizon)], Color("6a5a50"))
	_trees(w, horizon, 6, Color("4a5a3a"))
