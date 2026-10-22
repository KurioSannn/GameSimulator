class_name Overlays
extends RefCounted
## Thematic map overlays. Each maps a regional variable to a colour ramp with a readable legend.

const DEFS := [
	{"id": "sentiment", "label": "Sentimen", "var": "sentiment", "min": 20.0, "max": 80.0, "ramp": "diverging"},
	{"id": "welfare", "label": "Kesejahteraan", "var": "welfare", "min": 30.0, "max": 80.0, "ramp": "sequential"},
	{"id": "price", "label": "Tingkat Harga", "var": "price_level", "min": 80.0, "max": 160.0, "ramp": "heat"},
	{"id": "damage", "label": "Kerusakan", "var": "damage", "min": 0.0, "max": 60.0, "ramp": "heat"},
	{"id": "flood_frequency", "label": "Frekuensi Banjir", "var": "flood_frequency", "min": 0.0, "max": 10.0, "ramp": "heat"},
	{"id": "flood_protection", "label": "Proteksi Banjir", "var": "flood_protection", "min": 0.0, "max": 80.0, "ramp": "sequential"},
	{"id": "infrastructure", "label": "Infrastruktur", "var": "infrastructure", "min": 20.0, "max": 90.0, "ramp": "sequential"},
	{"id": "services", "label": "Layanan Publik", "var": "services", "min": 30.0, "max": 70.0, "ramp": "sequential"},
	{"id": "trust", "label": "Kepercayaan", "var": "trust", "min": 35.0, "max": 75.0, "ramp": "diverging"},
	{"id": "environment", "label": "Lingkungan", "var": "environment", "min": 20.0, "max": 70.0, "ramp": "sequential"},
	{"id": "fire_prevention", "label": "Pencegahan Api", "var": "fire_prevention", "min": 0.0, "max": 15.0, "ramp": "sequential"},
	{"id": "island", "label": "Pulau/Kawasan", "var": "", "ramp": "categorical"},
]

const ISLAND_COLORS := {
	"sumatera": Color("7fb3a3"), "jawa": Color("e0b46c"), "bali_nusa_tenggara": Color("d98c7a"),
	"kalimantan": Color("8fbf7f"), "sulawesi": Color("9aa7d6"), "maluku": Color("c79bd1"), "papua": Color("76a9c9"),
}


## Change mode: colour of a quarter's change. Neutral blue (down) / orange (up) on purpose: whether a rise
## is good depends on the variable (prices vs welfare), so the palette carries no judgement.
static func change_color(delta: float, scale: float) -> Color:
	var t := clampf(delta / maxf(scale, 1e-9), -1.0, 1.0)
	var mid := Color("e6e3da")
	if absf(delta) < 0.05:
		return mid
	return mid.lerp(Color("3d6fb0"), -t) if t < 0.0 else mid.lerp(Color("d7832f"), t)


## Symmetric legend scale for change mode: the 95th percentile of |delta| (robust to a few extreme
## regions), at least 0.5 so tiny noise does not look dramatic.
static func change_scale(deltas: PackedFloat64Array) -> float:
	var a: Array = []
	for d in deltas:
		a.append(absf(d))
	if a.is_empty():
		return 0.5
	a.sort()
	return maxf(0.5, float(a[int(0.95 * (a.size() - 1))]))


## Marks a colour as "starting value uncalibrated" (texel alpha; hatched by map_fill.gdshader).
static func uncalibrated(c: Color) -> Color:
	return Color(c.r, c.g, c.b, 0.5)


static func color(def: Dictionary, value: float) -> Color:
	var t := clampf((value - float(def.min)) / (float(def.max) - float(def.min)), 0.0, 1.0)
	match def.ramp:
		"diverging":  # red (low) -> neutral -> green (high)
			return Color("c0504d").lerp(Color("ece7d9"), t * 2.0) if t < 0.5 else Color("ece7d9").lerp(Color("4f9a6a"), (t - 0.5) * 2.0)
		"sequential":
			return Color("f1ede1").lerp(Color("2f6f73"), t)
		"heat":
			return Color("f6f1e3").lerp(Color("d8893d"), minf(t * 1.6, 1.0)).lerp(Color("a3302b"), maxf(t - 0.6, 0.0) * 2.5)
	return Color.GRAY
