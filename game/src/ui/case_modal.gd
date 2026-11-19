class_name CaseModal
extends PanelContainer
## Clean, scannable decision modal: unified header, crisis facts + map preview | advisor quote,
## structured composite choice cards (no text-wall jumping), and clear select-then-confirm footer.
## Real context (sourced, dated) -> fictional briefing -> simulated choices stay visibly labeled (docs/27).

signal decided(case_id: String, choice_id: String)
signal region_data_requested(region_id: String)

var _body: VBoxContainer
var _scroll: ScrollContainer
var _header_slot: VBoxContainer
var _confirm: Button
var case_id := ""
var _selected := ""
var _cards: Array = []  # [[choice_id, Button, badge_Control]]
var _selection_summary: Label
var map_lod: MapLod


func _ready() -> void:
	add_theme_stylebox_override("panel", StitchTheme.box(StitchTheme.color("surface"), StitchTheme.color("outline"), 4, 14, 20, 18))
	var root := UiKit.vbox(12)
	add_child(root)

	_header_slot = UiKit.vbox(0)
	root.add_child(_header_slot)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_body = UiKit.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)

	root.add_child(HSeparator.new())
	var foot := UiKit.hbox(14)
	var data := UiKit.ghost_button("LIHAT DATA WILAYAH", _view_data, "Tutup sementara dan buka detail wilayah kasus")
	data.custom_minimum_size = Vector2(200, 48)
	foot.add_child(data)
	_selection_summary = UiKit.label("Pilih satu opsi sebelum menetapkan keputusan.", 14, UiKit.MUTED, true)
	_selection_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(_selection_summary)
	_confirm = Button.new()
	_confirm.text = "TETAPKAN KEPUTUSAN"
	_confirm.theme_type_variation = "ButtonPrimary"
	_confirm.custom_minimum_size = Vector2(300, 50)
	_confirm.add_theme_font_size_override("font_size", 18)
	_confirm.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_confirm.pressed.connect(_confirm_choice)
	foot.add_child(_confirm)
	root.add_child(foot)
	visible = false


func present(id: String) -> void:
	case_id = id
	_selected = ""
	_cards.clear()
	var c: Dictionary = ContentDB.cases[id]
	UiKit.clear(_header_slot)
	UiKit.clear(_body)

	var eyebrow := "KEPUTUSAN PRESIDEN · " + str(c.get("location_label", "")).to_upper()
	_header_slot.add_child(UiKit.modal_header(
		eyebrow,
		str(c.title).to_upper(),
		close_modal,
		"MENDESAK!",
		StitchTheme.color("danger"),
		"✕",
		"Tutup sementara tanpa memutuskan (Esc)."
	))

	# Upper two-column context: Crisis Report | Advisor Briefing
	var cols := UiKit.hbox(12)
	_body.add_child(cols)

	var report := _card()
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report.size_flags_stretch_ratio = 1.45
	var rv: VBoxContainer = report.get_child(0)
	var rhead := UiKit.hbox(8)
	var rtitle := UiKit.title("LAPORAN SITUASI", 17)
	rtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rhead.add_child(rtitle)
	var real: Dictionary = c.get("real_context", {})
	if not real.get("lines", []).is_empty():
		var fbadge := UiKit.tag("FAKTA NYATA", UiKit.REAL, 11)
		fbadge.tooltip_text = "Berdasarkan berita & data resmi tercatat."
		fbadge.mouse_filter = Control.MOUSE_FILTER_STOP
		rhead.add_child(fbadge)
	rv.add_child(rhead)
	rv.add_child(UiKit.subheader("RINGKASAN KEJADIAN", UiKit.INFO, 11))

	var report_row := UiKit.hbox(12)
	rv.add_child(report_row)
	var facts_scroll := ScrollContainer.new()
	facts_scroll.custom_minimum_size = Vector2(0, 206)
	facts_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_row.add_child(facts_scroll)
	var flist := UiKit.vbox(10)
	flist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts_scroll.add_child(flist)

	if not real.get("lines", []).is_empty():
		for line in real.lines:
			var item := UiKit.vbox(3)
			item.add_child(UiKit.label("• " + str(line.text), 14, UiKit.TEXT, true))
			var src_lbl := UiKit.label("Sumber: " + ChangeText.clean_source_names(line.source_refs, str(line.as_of)), 12, UiKit.MUTED, true)
			src_lbl.tooltip_text = "ID sumber: %s (per %s)" % [", ".join(line.source_refs), line.as_of]
			src_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
			item.add_child(src_lbl)
			flist.add_child(item)
	var simctx: Dictionary = c.get("simulated_context", {})
	if not simctx.is_empty():
		flist.add_child(UiKit.tag("KONSEKUENSI LANJUTAN · SIMULASI", UiKit.SIM, 11))
		flist.add_child(UiKit.label(str(simctx.text), 14, UiKit.MUTED, true))
	var trig: Dictionary = c.get("trigger", {})
	if str(trig.get("type", "")) == "follow_up":
		flist.add_child(UiKit.subheader("ALASAN MUNCUL", UiKit.INFO, 11))
		for line in ChangeText.describe_conditions(Game.world, trig.get("conditions", {})):
			flist.add_child(UiKit.label(str(line), 13, UiKit.MUTED, true))

	if map_lod != null and not c.get("focus_regions", []).is_empty():
		var map_frame := PanelContainer.new()
		map_frame.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("163d66"), Color(1, 1, 1, 0.16), 8, 2, 2, 1))
		var preview := MapPreview.new()
		preview.lod = map_lod
		preview.focus_ids = c.focus_regions
		preview.custom_minimum_size = Vector2(215, 190)
		preview.selected.connect(func(rid): hide(); region_data_requested.emit(rid))
		map_frame.add_child(preview)
		report_row.add_child(map_frame)
	cols.add_child(report)

	var adv := _card()
	adv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var av: VBoxContainer = adv.get_child(0)
	var b: Dictionary = c.get("briefing", {})
	var ahead := UiKit.hbox(8)
	var stitle := UiKit.title(str(b.get("speaker", "PENASIHAT")).to_upper(), 17)
	stitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ahead.add_child(stitle)
	var ftag := UiKit.tag("FIKSI", UiKit.FICTION, 11)
	ftag.tooltip_text = "Dialog penasihat merupakan narasi fiksi permainan."
	ftag.mouse_filter = Control.MOUSE_FILTER_STOP
	ahead.add_child(ftag)
	av.add_child(ahead)
	av.add_child(UiKit.subheader("ARAHAN PENASIHAT", UiKit.FICTION, 11))

	var ah := UiKit.hbox(12)
	var pframe := PanelContainer.new()
	pframe.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("1d3269"), Color(1, 1, 1, 0.18), 10, 4, 4, 1))
	pframe.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var pic := FigmaAssets.picture(5, "imgAvatarPenasihatPemerintah", Vector2(88, 88))
	pframe.add_child(pic)
	ah.add_child(pframe)

	var qbox := PanelContainer.new()
	qbox.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("0d193b"), Color(1, 1, 1, 0.10), 10, 14, 12, 1))
	qbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var q := UiKit.label("“" + str(b.get("text", "")) + "”", 14, UiKit.TEXT, true)
	qbox.add_child(q)
	ah.add_child(qbox)
	av.add_child(ah)
	cols.add_child(adv)

	# Choices section header
	var ch_head := UiKit.hbox(10)
	ch_head.add_child(UiKit.title("TENTUKAN KEBIJAKAN", 18, UiKit.ACCENT))
	var sim_badge := UiKit.tag("SIMULASI", UiKit.SIM, 11)
	sim_badge.tooltip_text = "Efek dihitung simulasi (bukan sejarah). Pintasan: tekan angka 1–%d lalu Enter." % c.choices.size()
	sim_badge.mouse_filter = Control.MOUSE_FILTER_STOP
	ch_head.add_child(sim_badge)
	ch_head.add_child(UiKit.spacer())
	ch_head.add_child(UiKit.label("Pilih satu langkah penanganan:", 13, UiKit.MUTED))
	_body.add_child(ch_head)

	# Composite structured choice cards
	var row := UiKit.hbox(12)
	_body.add_child(row)
	var group := ButtonGroup.new()
	var n := 1
	for ch in c.choices:
		var btn := _build_choice_card(n, ch, group)
		row.add_child(btn)
		n += 1

	visible = true
	_update_confirm()
	_scroll.scroll_vertical = 0
	_fit.call_deferred()
	UiKit.animate_open(self)


func _build_choice_card(num: int, ch: Dictionary, group: ButtonGroup) -> Button:
	var data := ChangeText.choice_card_data(ch)
	var letter := char(64 + num)  # A, B, C...
	var btn := Button.new()
	btn.theme_type_variation = "ButtonChoice"
	btn.toggle_mode = true
	btn.button_group = group
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 248)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.tooltip_text = "Tekan %d untuk memilih · %s" % [num, str(data.cost_tooltip)]

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 15)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 14)
	btn.add_child(margin)

	var v := UiKit.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)

	# Top selected indicator bar (constant height so layout never shifts on select)
	var sel_row := UiKit.hbox(6)
	sel_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s_spacer := UiKit.spacer()
	s_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_row.add_child(s_spacer)
	var sel_badge := PanelContainer.new()
	sel_badge.add_theme_stylebox_override("panel", StitchTheme.soft_box(StitchTheme.color("primary"), StitchTheme.color("outline"), 6, 8, 2, 1))
	sel_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sel_lbl := UiKit.label("✓ TERPILIH", 11, StitchTheme.color("primary_text"))
	sel_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sel_badge.add_child(sel_lbl)
	sel_badge.modulate.a = 0.0
	sel_row.add_child(sel_badge)
	v.add_child(sel_row)

	# Card header: Icon + "A. TITLE" + [1] keycap
	var top := UiKit.hbox(10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic_wrap := PanelContainer.new()
	ic_wrap.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("1c3575"), Color(1, 1, 1, 0.14), 8, 5, 5, 1))
	ic_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic_wrap.add_child(FigmaAssets.picture(int(data.icon_screen), str(data.icon_slot), Vector2(24, 24)))
	top.add_child(ic_wrap)

	var lbl := UiKit.title("%s. %s" % [letter, str(ch.label).to_upper()], 15, UiKit.TEXT)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(lbl)

	var num_pill := PanelContainer.new()
	num_pill.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("0a1430"), Color(1, 1, 1, 0.22), 6, 8, 3, 1))
	num_pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	num_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nl := UiKit.label(str(num), 12, UiKit.MUTED)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	num_pill.add_child(nl)
	top.add_child(num_pill)
	v.add_child(top)

	# Structured Header + Subheader blocks: POTENSI MANFAAT & RISIKO
	var body_box := UiKit.vbox(6)
	body_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(body_box)

	var ben_hdr := UiKit.subheader("POTENSI MANFAAT", UiKit.SUCCESS, 11)
	ben_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_box.add_child(ben_hdr)
	var ben_txt := UiKit.label(str(data.benefit), 14, Color("f0f5ff"), true)
	ben_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_box.add_child(ben_txt)

	var risk_hdr := UiKit.subheader("RISIKO", UiKit.WARN, 11)
	risk_hdr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_box.add_child(risk_hdr)
	var risk_txt := UiKit.label(str(data.risk), 13, UiKit.MUTED, true)
	risk_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body_box.add_child(risk_txt)

	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)

	# Footer row: Target chip + Coin Cost badge
	var foot := UiKit.hbox(8)
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_lbl := UiKit.label(str(data.scope_chip), 12, UiKit.MUTED)
	scope_lbl.clip_text = true
	scope_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(scope_lbl)

	var cost_col := UiKit.ACCENT
	match str(data.cost_tone):
		"green": cost_col = UiKit.SUCCESS
		"warn": cost_col = UiKit.WARN
		"muted": cost_col = UiKit.MUTED
	var cost_pill := PanelContainer.new()
	cost_pill.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color(cost_col, 0.14), Color(cost_col, 0.40), 7, 9, 4, 1))
	cost_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chbox := UiKit.hbox(5)
	chbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chbox.add_child(FigmaAssets.picture(6, "imgIkonCoin", Vector2(16, 16)))
	var clbl := UiKit.title(str(data.cost_text), 14, cost_col)
	clbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chbox.add_child(clbl)
	cost_pill.add_child(chbox)
	foot.add_child(cost_pill)
	v.add_child(foot)

	var cid: String = ch.choice_id
	btn.pressed.connect(func(): _select(cid))
	_cards.append([cid, btn, sel_badge])
	return btn


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "PanelCard"
	p.add_child(UiKit.vbox(8))
	return p


func _select(choice_id: String) -> void:
	_selected = choice_id
	for entry in _cards:
		var is_sel: bool = entry[0] == choice_id
		entry[1].button_pressed = is_sel
		entry[2].modulate.a = 1.0 if is_sel else 0.0
	_update_confirm()


func _update_confirm() -> void:
	_confirm.disabled = _selected == ""
	_selection_summary.text = "Pilih satu opsi sebelum menetapkan keputusan."
	_selection_summary.add_theme_color_override("font_color", UiKit.MUTED)
	if _selected != "":
		for choice in ContentDB.cases[case_id].choices:
			if choice.choice_id == _selected:
				var data := ChangeText.choice_card_data(choice)
				_selection_summary.text = "%s · %s (klik Tetapkan atau tekan Enter)" % [choice.label, data.cost_text]
				_selection_summary.add_theme_color_override("font_color", UiKit.TEXT)
	_confirm.tooltip_text = "Pilih satu kebijakan dulu (tombol 1–%d)." % _cards.size() if _selected == "" else "Tetapkan keputusan (Enter)"


func _confirm_choice() -> void:
	if _selected != "":
		_choose(_selected)


func close_modal() -> void:
	visible = false


func _view_data() -> void:
	var c: Dictionary = ContentDB.cases[case_id]
	visible = false
	if not c.get("focus_regions", []).is_empty():
		region_data_requested.emit(str(c.focus_regions[0]))


## Responsive modal sizing so margins stay clear at both 1280x720 and 1920x1080.
func _fit() -> void:
	var vp := get_viewport_rect().size
	var w := minf(vp.x - 80.0, 1340.0)
	custom_minimum_size = Vector2(w, 0)
	var cap := maxf(260.0, vp.y - 220.0)
	_scroll.custom_minimum_size = Vector2(w - 40.0, minf(_body.get_combined_minimum_size().y, cap))


func _choose(choice_id: String) -> void:
	visible = false
	decided.emit(case_id, choice_id)


func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and not is_ancestor_of(focus):
		return
	var k := (event as InputEventKey).keycode
	if k >= KEY_1 and k <= KEY_9:
		var idx := k - KEY_1
		var chs: Array = ContentDB.cases[case_id].choices
		if idx < chs.size():
			get_viewport().set_input_as_handled()
			_select(chs[idx].choice_id)
	elif k == KEY_ENTER or k == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_confirm_choice()
	elif k == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		close_modal()


## Explicit resource cost of a choice (from its fiscal_space effects), e.g. "Biaya: −8 ruang fiskal".
static func _cost_line(ch: Dictionary) -> String:
	var now := 0.0
	var later: Array = []
	var delayed := false
	for e in ch.get("effects", []):
		var d := int(e.get("delay", 0))
		var n := int(e.get("duration", 1))
		if e.get("scope") == "national" and e.get("var") == "fiscal_space":
			var total := float(e.value) * n
			if d == 0 and n == 1:
				now += total
			elif n > 1:
				later.append("ruang fiskal %s total selama %d bulan%s" % [Fmt.signed(total, 1), n, (" mulai %d bulan lagi" % d) if d > 0 else ""])
			else:
				later.append("ruang fiskal %s setelah %d bulan" % [Fmt.signed(total, 1), d])
		if d > 0:
			delayed = true
	var parts: Array = []
	if now < 0.0:
		parts.append("Biaya: %s ruang fiskal" % Fmt.signed(now, 1))
	elif now > 0.0:
		parts.append("Tambahan ruang fiskal: %s" % Fmt.signed(now, 1))
	elif later.is_empty():
		parts.append("Biaya: tidak ada")
	parts.append_array(later)
	if delayed:
		parts.append("sebagian dampak tertunda")
	return " · ".join(parts)
