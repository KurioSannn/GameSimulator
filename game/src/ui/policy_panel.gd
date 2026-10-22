class_name PolicyPanel
extends PanelContainer
## Minimal functional policy UI: list -> detail (cost, prerequisites, target, effects) -> confirm,
## plus implementation status of running policies. Reads state; enactment goes through Game.

var _list: VBoxContainer
var _detail: VBoxContainer
var _status: VBoxContainer
var _selected := ""
var _target_type := "national"
var region_id := ""   # currently selected map region (set by main) for province/kab/island targets


func _ready() -> void:
	custom_minimum_size = Vector2(980, 640)
	add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_LIGHT, 10, 18))
	var root := UiKit.vbox(8)
	add_child(root)
	var head := UiKit.hbox()
	var title := UiKit.label("Kebijakan", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): visible = false)
	head.add_child(close)
	root.add_child(head)
	root.add_child(UiKit.tag("OPSI KEBIJAKAN = RANCANGAN PERMAINAN · besaran dampak belum terkalibrasi", UiKit.WARN))
	var cols := UiKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(cols)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(300, 0)
	cols.add_child(ls)
	_list = UiKit.vbox(4)
	ls.add_child(_list)
	var ds := ScrollContainer.new()
	ds.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(ds)
	_detail = UiKit.vbox(6)
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ds.add_child(_detail)
	root.add_child(HSeparator.new())
	root.add_child(UiKit.label("Status pelaksanaan", 15))
	_status = UiKit.vbox(2)
	root.add_child(_status)
	visible = false


func open() -> void:
	refresh()
	visible = true


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
		_list.add_child(UiKit.label(str(cat.label).to_upper(), 12, UiKit.MUTED))
		for id in by_cat[cat.id]:
			var b := Button.new()
			b.text = ContentDB.policies[id].name
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var pid: String = id
			b.pressed.connect(func(): _selected = pid; _show_detail())
			_list.add_child(b)
	_show_detail()
	_show_status()


func _target() -> Dictionary:
	match _target_type:
		"province": return {"type": "province", "id": region_id.substr(0, 2)}
		"kabkota": return {"type": "kabkota", "id": region_id}
		"island_group": return {"type": "island_group", "id": ContentDB.region_by_id.get(region_id, {}).get("island_group", "")}
	return {"type": "national"}


func _show_detail() -> void:
	UiKit.clear(_detail)
	if _selected == "":
		_detail.add_child(UiKit.label("Pilih kebijakan di daftar kiri.", 15, UiKit.MUTED))
		return
	var p: Dictionary = ContentDB.policies[_selected]
	_detail.add_child(UiKit.label(str(p.name), 22, UiKit.TEXT, true))
	_detail.add_child(UiKit.label(str(p.description), 14, UiKit.TEXT, true))
	var c: Dictionary = p.cost
	_detail.add_child(UiKit.label("Biaya: awal %s ruang fiskal · komitmen %s%% anggaran program selama %d bulan (mengurangi dana sektor lain)" % [
		Fmt.num(float(c.upfront_fiscal), 1), Fmt.num(float(c.monthly_commitment) * 100.0, 0), int(c.commitment_months)], 14, UiKit.ACCENT, true))
	_detail.add_child(UiKit.label("Waktu: implementasi %d bulan → berjalan %d bulan · jeda ulang %d bulan · ketidakpastian ±%s%%" % [
		int(p.implementation_months), int(p.duration_months), int(p.cooldown_months), Fmt.num(float(p.uncertainty.magnitude) * 100.0, 0)], 13, UiKit.MUTED, true))
	if p.has("target_filter"):
		_detail.add_child(UiKit.label("Syarat wilayah: " + str(p.target_filter), 13, UiKit.MUTED))
	if not p.get("mutually_exclusive", []).is_empty():
		_detail.add_child(UiKit.label("Tidak bisa bersamaan dengan: " + ", ".join(p.mutually_exclusive.map(func(x): return ContentDB.policies.get(x, {}).get("name", x))), 13, UiKit.MUTED, true))
	_detail.add_child(UiKit.label("Dampak yang diharapkan (SIMULASI):", 14))
	for e in p.effects:
		var phase: String = {"immediate": "segera", "implementation": "selama implementasi", "active": "setelah implementasi"}.get(str(e.phase), str(e.phase))
		_detail.add_child(UiKit.label("• [%s · %s] %s" % [phase, str(e.dimension), str(e.label)], 13, UiKit.TEXT, true))
	# Target selection
	var trow := UiKit.hbox()
	trow.add_child(UiKit.label("Sasaran:", 14))
	var opt := OptionButton.new()
	var types := []
	for tt in p.target_scope:
		if tt == "selected":
			continue
		if tt != "national" and region_id == "":
			continue
		types.append(tt)
		opt.add_item({"national": "Nasional", "island_group": "Pulau/kawasan wilayah terpilih", "province": "Provinsi wilayah terpilih", "kabkota": "Kab/kota terpilih"}.get(tt, tt))
	if not (_target_type in types):
		_target_type = "national"
	opt.selected = types.find(_target_type)
	opt.item_selected.connect(func(ix): _target_type = types[ix]; _show_detail())
	trow.add_child(opt)
	_detail.add_child(trow)
	if region_id == "":
		_detail.add_child(UiKit.label("Klik wilayah di peta untuk sasaran provinsi/kab-kota/pulau.", 12, UiKit.MUTED))
	var reason := Game.session.policies.can_enact(Game.world, _selected, _target())
	var n := Game.session.policies.resolve_target(Game.world, p, _target()).size()
	_detail.add_child(UiKit.label("Wilayah memenuhi syarat: %d" % n, 13, UiKit.MUTED))
	var go := Button.new()
	go.text = "Tetapkan kebijakan"
	go.disabled = reason != ""
	go.pressed.connect(_confirm)
	_detail.add_child(go)
	if reason != "":
		_detail.add_child(UiKit.label(reason, 13, UiKit.WARN, true))


func _confirm() -> void:
	var err := Game.enact_policy(_selected, _target())
	refresh()
	if err != "":
		_detail.add_child(UiKit.label(err, 13, UiKit.WARN, true))


func _show_status() -> void:
	UiKit.clear(_status)
	var w: SimWorld = Game.world
	if w.policy_state.is_empty():
		_status.add_child(UiKit.label("Belum ada kebijakan yang ditetapkan.", 13, UiKit.MUTED))
		return
	for id in w.policy_state:
		var st: Dictionary = w.policy_state[id]
		var s := PolicyEngine.status_of(w, id)
		var label: String = {"implementing": "IMPLEMENTASI", "active": "BERJALAN", "ended": "SELESAI"}.get(s, s)
		var left := int(st.impl_end_tick) - w.tick if s == "implementing" else int(st.end_tick) - w.tick
		_status.add_child(UiKit.label("%s — %s%s · %d wilayah · faktor pelaksanaan %s" % [
			ContentDB.policies.get(id, {}).get("name", id), label, (" (%d bulan lagi)" % left) if s != "ended" else "",
			int(st.regions), Fmt.num(float(st.multiplier), 2)], 13))
