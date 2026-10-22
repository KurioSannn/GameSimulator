class_name Fmt
extends RefCounted
## Presentation-only formatting (Bahasa Indonesia conventions). Never mutates source values.


## 3153580000000000 -> "Rp3,15 kuadriliun"
static func rupiah(v: float) -> String:
	var a := absf(v)
	var units := [[1e15, "kuadriliun"], [1e12, "triliun"], [1e9, "miliar"], [1e6, "juta"], [1e3, "ribu"]]
	for u in units:
		if a >= u[0]:
			return "Rp%s %s" % [num(v / u[0], 2), u[1]]
	return "Rp" + num(v, 0)


## Decimal comma, dot thousands: 12345.6 -> "12.345,6"
static func num(v: float, decimals: int = 1) -> String:
	var neg := v < 0.0
	var s := String.num(absf(v), decimals)
	var parts := s.split(".")
	var int_part: String = parts[0]
	var grouped := ""
	var count := 0
	for i in range(int_part.length() - 1, -1, -1):
		grouped = int_part[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	var out := grouped + ("," + parts[1] if parts.size() > 1 and decimals > 0 else "")
	return ("-" if neg else "") + out


static func signed(v: float, decimals: int = 1) -> String:
	return ("+" if v > 0.0 else "") + num(v, decimals)


## Label shown next to any value whose baseline is not sourced yet (D-016).
static func calib_tag(status: String) -> String:
	match status:
		"REAL_OFFICIAL": return "NYATA"
		"DERIVED": return "TURUNAN"
		"UNCALIBRATED": return "BELUM TERKALIBRASI"
	return "SIMULASI"


static func period(world: SimWorld) -> String:
	var month := world.tick % 12 + 1
	return "Tahun %d · Kuartal %d · Bulan %d" % [world.year_index() + 1, world.quarter_index() % 4 + 1, month]


## Formats a REAL value in its source unit for display (value itself is untouched in data).
static func unit_value(v: float, unit: String) -> String:
	match unit:
		"km2": return "%s km²" % num(v, 1)
		"jiwa": return "%s jiwa" % num(v, 0)
		"persen": return "%s%%" % num(v, 2)
		"rupiah": return rupiah(v)
		"juta rupiah": return rupiah(v * 1e6)
		"indeks": return num(v, 2)
		"skor IRBI": return num(v, 2)
		"kejadian": return "%s kejadian" % num(v, 0)
	return "%s %s" % [num(v, 2), unit]


static func short_institution(name: String) -> String:
	if name.contains("(BIG)") or name.begins_with("Badan Informasi Geospasial"):
		return "BIG"
	if name.begins_with("Badan Nasional Penanggulangan"):
		return "BNPB"
	if name.begins_with("Badan Pusat Statistik"):
		return "BPS"
	return name.substr(0, 24)
