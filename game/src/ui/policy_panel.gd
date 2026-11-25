class_name PolicyPanel
extends PanelContainer
## Clean two-column policy browser and enactment modal:
## categorized selector -> KPI cost/timeline strip -> simulated impacts -> target scope -> confirm.

var _list: VBoxContainer
var _detail: VBoxContainer
var _status: VBoxContainer
var _status_card: PanelContainer
var _actions: VBoxContainer
var _selected := ""
var _target_type := "national"
var region_id := ""
var context: Dictionary = {}


func _ready() -> void:
	add_theme_stylebox_override("panel", GameSkin.frame())
	var root := UiKit.vbox(12)
	add_child(root)

	root.add_child(UiKit.modal_header(
		"",
		"PROGRAM PEMERINTAH",
		func(): visible = false,
		"",
		UiKit.WARN,
		"✕",
		"Tutup panel kebijakan (Esc / P)"
	))

	var cols := UiKit.hbox(14)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)

	# Left sidebar list inside soft card
	var list_card := PanelContainer.new()
	list_card.theme_type_variation = "PanelCard"
	list_card.custom_minimum_size = Vector2(280, 0)
	var ls := ScrollContainer.new()
	ls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ls.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_card.add_child(ls)
	_list = UiKit.vbox(6)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ls.add_child(_list)
	cols.add_child(list_card)

	# Right detail card
	var detail_card := PanelContainer.new()
	detail_card.theme_type_variation = "PanelCard"
	detail_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var detail_body := UiKit.vbox(12)
	detail_card.add_child(detail_body)
	var ds := ScrollContainer.new()
	ds.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_body.add_child(ds)
	_detail = UiKit.vbox(10)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(_detail)
	_actions = UiKit.vbox(8)
	detail_body.add_child(_actions)
	cols.add_child(detail_card)

	# Bottom compact active policies strip
	var status_card := PanelContainer.new()
	_status_card = status_card
	status_card.theme_type_variation = "PanelCard"
	var sv := UiKit.vbox(6)
	status_card.add_child(sv)
	sv.add_child(UiKit.title("STATUS PELAKSANAAN KEBIJAKAN", 13, UiKit.ACCENT))
	var ss := ScrollContainer.new()
	ss.custom_minimum_size.y = 72
	ss.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sv.add_child(ss)
	_status = UiKit.vbox(4)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ss.add_child(_status)
	root.add_child(status_card)
	visible = false


func open() -> void:
	var vp := get_viewport_rect().size
	custom_minimum_size = Vector2(minf(vp.x - 80.0, 1120.0), minf(vp.y - 80.0, 620.0))
	refresh()
	visible = true
	UiKit.animate_open(self)


func refresh() -> void:
	if not is_inside_tree():
		return
	UiKit.clear(_list)
	var by_cat := {}
	for id in ContentDB.policies:
		by_cat.get_or_add(ContentDB.policies[id].category, []).append(id)
	for cat in ContentDB.policy_categories:
		if not by_cat.has(cat.id):
			continue
		_list.add_child(UiKit.label(str(cat.label).to_upper(), 11, UiKit.ACCENT))
		for id in by_cat[cat.id]:
			if _selected == "":
				_selected = id
			var b := Button.new()
			b.text = ContentDB.policies[id].name
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			b.theme_type_variation = "ButtonAccent" if id == _selected else "ButtonGhost"
			b.custom_minimum_size.y = 38
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			var pid: String = id
			b.pressed.connect(func(): _selected = pid; refresh())
			_list.add_child(b)
	_show_detail()
	_show_status()


func _target() -> Dictionary:
	if not context.is_empty() and str(context.get("type", "")) == _target_type:
		return context.duplicate(true)
	match _target_type:
		"province": return {"type": "province", "id": region_id.substr(0, 2)}
		"kabkota": return {"type": "kabkota", "id": region_id}
		"island_group": return {"type": "island_group", "id": ContentDB.region_by_id.get(region_id, {}).get("island_group", "")}
	return {"type": "national"}


func _show_detail() -> void:
	UiKit.clear(_detail)
	UiKit.clear(_actions)
	if _selected == "":
		_detail.add_child(UiKit.label("Pilih kebijakan di daftar sebelah kiri.", 15, UiKit.MUTED))
		return
	var p: Dictionary = ContentDB.policies[_selected]
	_detail.add_child(UiKit.subheader("DETAIL PROGRAM", UiKit.INFO, 11))
	var program_name := UiKit.title(str(p.name), 24)
	program_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.add_child(program_name)
	_detail.add_child(UiKit.label(str(p.description), 14, UiKit.TEXT, true))

	# Clean KPI strip for Cost & Timeline (plain Indonesian, zero cryptic codes)
	var c: Dictionary = p.cost
	var kpis := GridContainer.new()
	kpis.columns = 2
	kpis.add_theme_constant_override("h_separation", 8)
	kpis.add_theme_constant_override("v_separation", 8)
	var upfront_txt := "%s poin" % Fmt.num(float(c.upfront_fiscal), 1) if float(c.upfront_fiscal) > 0.0 else "Gratis"
	for spec in [
		["BIAYA AWAL", upfront_txt, UiKit.ACCENT],
		["BIAYA BULANAN", "%s%% · %d bln" % [Fmt.num(float(c.monthly_commitment) * 100.0, 0), int(c.commitment_months)], UiKit.TEXT],
		["MASA BANGUN", "%d bulan" % int(p.implementation_months), UiKit.MUTED],
		["MASA BERLAKU", "%d bulan" % int(p.duration_months), UiKit.SUCCESS],
	]:
		var cell := PanelContainer.new()
		cell.add_theme_stylebox_override("panel", StitchTheme.soft_box(UiKit.PANEL_SOFT, Color(1, 1, 1, 0.10), 8, 12, 8, 1))
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cv := UiKit.vbox(3)
		cv.add_child(UiKit.subheader(spec[0], UiKit.MUTED, 10))
		cv.add_child(UiKit.title(spec[1], 15, spec[2]))
		cell.add_child(cv)
		kpis.add_child(cell)
	_detail.add_child(kpis)

	if not p.get("mutually_exclusive", []).is_empty():
		_detail.add_child(UiKit.label("Tidak dapat dijalankan bersama: " + ", ".join(p.mutually_exclusive.map(func(x): return ContentDB.policies.get(x, {}).get("name", x))), 12, UiKit.WARN, true))

	var eff_sec := UiKit.section_bar("DAMPAK", "±%s%%" % Fmt.num(float(p.uncertainty.magnitude) * 100.0, 0), UiKit.ACCENT)
	eff_sec.tooltip_text = "Variasi hasil acak di lapangan berkisar ±%s%%." % Fmt.num(float(p.uncertainty.magnitude) * 100.0, 0)
	_detail.add_child(eff_sec)
	var dim_names := {
		"environmental": "Lingkungan", "environment": "Lingkungan", "regional": "Daerah",
		"welfare": "Kesejahteraan", "infrastructure": "Infrastruktur", "trust": "Kepercayaan",
		"price": "Harga", "food": "Pangan", "logistics": "Logistik", "services": "Layanan",
		"flood_protection": "Anti-Banjir", "fire_prevention": "Cegah Karhutla", "damage": "Pemulihan",
	}
	for e in p.effects:
		var phase: String = {"immediate": "Segera", "implementation": "Saat Dibangun", "active": "Saat Berjalan"}.get(str(e.phase), str(e.phase))
		var dim: String = dim_names.get(str(e.dimension).to_lower(), str(e.dimension).capitalize())
		var erow := UiKit.hbox(8)
		erow.add_child(UiKit.tag("%s · %s" % [phase, dim], UiKit.INFO, 11))
		var elbl := UiKit.label(str(e.label), 14, UiKit.TEXT, true)
		elbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		erow.add_child(elbl)
		_detail.add_child(erow)

	_detail.add_child(HSeparator.new())
	var trow := UiKit.hbox(10)
	trow.add_child(UiKit.title("SASARAN:", 14))
	var opt := OptionButton.new()
	opt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var types := []
	for tt in p.target_scope:
		if tt == "selected":
			continue
		if tt != "national" and region_id == "":
			if context.is_empty() or tt != str(context.get("type", "")):
				continue
		types.append(tt)
		opt.add_item({"national": "Nasional", "island_group": "Pulau/kawasan terpilih", "province": "Provinsi terpilih", "kabkota": "Kab/kota terpilih"}.get(tt, tt))
	if not (_target_type in types):
		_target_type = str(types[0]) if not types.is_empty() else "national"
	opt.selected = types.find(_target_type)
	opt.item_selected.connect(func(ix): _target_type = types[ix]; _show_detail())
	trow.add_child(opt)
	var n := Game.session.policies.resolve_target(Game.world, p, _target()).size()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_actions.add_child(HSeparator.new())
	_actions.add_child(trow)
	var target := _target()
	var target_name := "Indonesia"
	match str(target.get("type", "national")):
		"province": target_name = str(ContentDB.province_by_id.get(str(target.get("id", "")), {}).get("name", "Provinsi terpilih"))
		"kabkota": target_name = str(ContentDB.region_by_id.get(str(target.get("id", "")), {}).get("name", "Kab/kota terpilih"))
		"island_group": target_name = str(RegionViewModel.ISLANDS.get(str(target.get("id", "")), "Kawasan terpilih"))
	_actions.add_child(UiKit.label("%s · %d wilayah memenuhi syarat" % [target_name, n], 14, UiKit.INFO if n > 0 else UiKit.WARN, true))
	var reason := Game.session.policies.can_enact(Game.world, _selected, _target())
	var go := UiKit.button("TETAPKAN KEBIJAKAN", _confirm, true)
	go.custom_minimum_size = Vector2(220, 44)
	go.disabled = reason != ""
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if region_id == "" and context.is_empty():
		_actions.add_child(UiKit.label("Pilih wilayah di peta untuk sasaran provinsi, kab/kota, atau kawasan.", 14, UiKit.MUTED, true))
	if reason != "":
		_actions.add_child(UiKit.label(reason, 14, UiKit.WARN, true))
	_actions.add_child(go)


func _confirm() -> void:
	var err := Game.enact_policy(_selected, _target())
	refresh()
	if err != "":
		_detail.add_child(UiKit.tag(err, UiKit.DANGER, 12))


func _show_status() -> void:
	UiKit.clear(_status)
	var w: SimWorld = Game.world
	_status_card.visible = not w.policy_state.is_empty()
	if w.policy_state.is_empty():
		_status.add_child(UiKit.label("Belum ada kebijakan yang ditetapkan.", 13, UiKit.MUTED))
		return
	for id in w.policy_state:
		var st: Dictionary = w.policy_state[id]
		var s := PolicyEngine.status_of(w, id)
		var label: String = {"implementing": "IMPLEMENTASI", "active": "BERJALAN", "ended": "SELESAI"}.get(s, s)
		var col := UiKit.ACCENT if s == "implementing" else (UiKit.SUCCESS if s == "active" else UiKit.MUTED)
		var left := int(st.impl_end_tick) - w.tick if s == "implementing" else int(st.end_tick) - w.tick
		var row := UiKit.hbox(8)
		row.add_child(UiKit.tag(label, col, 10))
		var txt := "%s%s · %d wilayah · faktor ×%s" % [
			ContentDB.policies.get(id, {}).get("name", id),
			(" (%d bln lagi)" % left) if s != "ended" else "",
			int(st.regions),
			Fmt.num(float(st.multiplier), 2),
		]
		row.add_child(UiKit.label(txt, 13, UiKit.TEXT, true))
		_status.add_child(row)
