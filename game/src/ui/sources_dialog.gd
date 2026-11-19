class_name SourcesDialog
extends PanelContainer
## Clean structured provenance & baseline metadata modal.
## Preserves exact source attribution fields and unknown markers.

signal closed
var _content: VBoxContainer
const FIELDS := [
	["institution", "Institusi"],
	["title", "Judul"],
	["url", "URL"],
	["publication_date", "Tanggal publikasi / pembaruan"],
	["retrieved_at", "Waktu pengambilan"],
	["geographic_resolution", "Resolusi sumber"],
	["reference_period", "Periode sumber"],
	["unit", "Satuan sumber"],
	["status", "Status sumber"],
]


func _ready() -> void:
	add_theme_stylebox_override("panel", StitchTheme.box(StitchTheme.color("surface"), StitchTheme.color("outline"), 4, 14, 20, 18))
	var root := UiKit.vbox(12)
	add_child(root)

	root.add_child(UiKit.modal_header(
		"TRANSPARANSI DATA & SUMBER RESMI",
		"DATA DAN SUMBER",
		func(): hide(); closed.emit(),
		"",
		UiKit.REAL,
		"×",
		"Tutup dialog sumber (Esc)"
	))

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_content = UiKit.vbox(12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_content)
	hide()


func open(model: Dictionary) -> void:
	var vp := get_viewport_rect().size
	custom_minimum_size = Vector2(minf(vp.x - 80.0, 1020.0), minf(vp.y - 80.0, 740.0))
	UiKit.clear(_content)

	_content.add_child(UiKit.title(str(model.name).to_upper(), 26, UiKit.ACCENT))
	_content.add_child(UiKit.label(str(model.resolution), 14, UiKit.MUTED, true))
	_content.add_child(UiKit.tag("Data acuan memakai satuan & resolusi sumber · Nilai permainan adalah SIMULASI", UiKit.SIM, 12))

	var shown := {}
	for fact in model.facts:
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelCard"
		var body := UiKit.vbox(8)
		card.add_child(body)
		var fhead := UiKit.hbox(8)
		var flbl := UiKit.title(str(fact.label).to_upper(), 18)
		flbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fhead.add_child(flbl)
		fhead.add_child(UiKit.tag("%s · %s" % [Fmt.unit_value(float(fact.value), str(fact.unit)), fact.period], UiKit.REAL, 12))
		body.add_child(fhead)
		var sid := str(fact.get("source_id", ""))
		body.add_child(UiKit.label("Identitas sumber: %s · %s" % [sid, fact.get("fact_class", "")], 12, UiKit.MUTED, true))
		if not shown.has(sid):
			shown[sid] = true
			_add_source(body, ContentDB.sources.get(sid, {}))
		_content.add_child(card)

	if model.facts.is_empty():
		_content.add_child(UiKit.tag("Data acuan pada resolusi ini belum tersedia · statistik kab/kota tidak disamaratakan ke tingkat provinsi/pulau.", UiKit.WARN, 12))

	_content.add_child(UiKit.section_bar("ASAL NILAI AWAL SIMULASI", "Metodologi & Kalibrasi", UiKit.ACCENT))
	for metric in model.metrics:
		var key := str(metric.key)
		var spec: Dictionary = ContentDB.baseline.get("variables", {}).get(key, {})
		var mcard := PanelContainer.new()
		mcard.theme_type_variation = "PanelCard"
		var mbody := UiKit.vbox(6)
		mcard.add_child(mbody)

		var mhead := UiKit.hbox(8)
		var mt := UiKit.title(str(metric.label), 17)
		mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mhead.add_child(mt)
		mhead.add_child(UiKit.tag(", ".join(metric.baseline_flags), UiKit.SIM, 11))
		mbody.add_child(mhead)

		mbody.add_child(UiKit.label("Periode: %s · Satuan: %s" % [spec.get("reference_period", "Belum tercatat"), spec.get("unit", metric.unit)], 13, UiKit.MUTED, true))
		var raw_provenance: Variant = spec.get("provenance")
		var provenance: Dictionary = raw_provenance if raw_provenance is Dictionary else {}
		if provenance.has("reason"):
			mbody.add_child(UiKit.label(str(provenance.reason), 13, UiKit.TEXT, true))
		for sid in provenance.get("sources", []):
			if not shown.has(sid):
				shown[sid] = true
				_add_source(mbody, ContentDB.sources.get(sid, {}))
		_content.add_child(mcard)

	show()
	UiKit.animate_open(self)


func _add_source(body: VBoxContainer, source: Dictionary) -> void:
	body.add_child(HSeparator.new())
	var url_val := ""
	for field in FIELDS:
		var raw: Variant = source.get(field[0])
		var value := "Belum tercatat" if raw == null or str(raw) == "" else str(raw)
		if field[0] == "url":
			url_val = value
		var row := UiKit.hbox(12)
		var k := UiKit.label(field[1], 13, UiKit.MUTED)
		k.custom_minimum_size.x = 240
		row.add_child(k)
		var v := UiKit.label(value, 13, UiKit.TEXT, true)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		body.add_child(row)
	if url_val.begins_with("https://"):
		var url := url_val
		var link := UiKit.ghost_button("BUKA SUMBER RESMI ↗", func(): OS.shell_open(url), "Buka halaman resmi institusi sumber")
		link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		body.add_child(link)
