class_name CaseModal
extends PanelContainer
## Decision screen after the Stitch "Peristiwa dan Keputusan" layout: header, crisis report + advisor,
## three selectable policy cards, footer (Lihat Data Wilayah / Tetapkan Keputusan).
## Real context (sourced, dated) → fictional briefing → simulated choices stay visibly labeled (docs/27).
## Choosing is select-then-confirm: keys 1-9 select, Enter or the button confirms; Esc/✕ closes without deciding.

signal decided(case_id: String, choice_id: String)
signal region_data_requested(region_id: String)

var _body: VBoxContainer
var _scroll: ScrollContainer
var _header: HBoxContainer
var _confirm: Button
var case_id := ""
var _selected := ""
var _cards: Array = []


func _ready() -> void:
	custom_minimum_size = Vector2(1480, 0)
	add_theme_stylebox_override("panel", StitchTheme.box(StitchTheme.color("bg"), Color(), 6))
	var root := UiKit.vbox(10)
	add_child(root)
	_header = UiKit.hbox(12)
	root.add_child(_header)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)
	_body = UiKit.vbox(12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	var foot := UiKit.hbox(12)
	var data := Button.new()
	data.text = "LIHAT DATA WILAYAH"
	data.theme_type_variation = "ButtonAccent"
	data.pressed.connect(_view_data)
	foot.add_child(data)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	_confirm = Button.new()
	_confirm.text = "TETAPKAN KEPUTUSAN"
	_confirm.theme_type_variation = "ButtonPrimary"
	_confirm.custom_minimum_size = Vector2(380, 54)
	_confirm.add_theme_font_size_override("font_size", 20)
	_confirm.pressed.connect(_confirm_choice)
	foot.add_child(_confirm)
	root.add_child(foot)
	visible = false


func present(id: String) -> void:
	case_id = id
	_selected = ""
	_cards.clear()
	var c: Dictionary = ContentDB.cases[id]
	UiKit.clear(_header)
	UiKit.clear(_body)

	# Header
	var hp := PanelContainer.new()
	hp.theme_type_variation = "PanelHeader"
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hv := UiKit.vbox(0)
	hv.add_child(UiKit.title("KEPUTUSAN · " + str(c.get("location_label", "")).to_upper(), 12, UiKit.ACCENT))
	var t := UiKit.title(str(c.title).to_upper(), 34)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(t)
	hp.add_child(hv)
	_header.add_child(hp)
	var urgent := PanelContainer.new()
	urgent.add_theme_stylebox_override("panel", StitchTheme.box(StitchTheme.color("danger")))
	urgent.add_child(UiKit.title("MENDESAK!", 18))
	urgent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	urgent.tooltip_text = "Kuartal tidak bisa dilanjutkan sebelum keputusan ditetapkan."
	_header.add_child(urgent)
	var close := Button.new()
	close.text = "✕"
	close.theme_type_variation = "ButtonAccent"
	close.tooltip_text = "Tutup tanpa memutuskan (Esc). Buka lagi dari bar agenda."
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_modal)
	_header.add_child(close)

	# Two columns: crisis report | advisor
	var cols := UiKit.hbox(12)
	_body.add_child(cols)
	var report := _card()
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report.size_flags_stretch_ratio = 1.4
	var rv: VBoxContainer = report.get_child(0)
	rv.add_child(UiKit.title("LAPORAN KRISIS", 20))
	var real: Dictionary = c.get("real_context", {})
	if not real.get("lines", []).is_empty():
		rv.add_child(UiKit.tag("FAKTA NYATA · bersumber", UiKit.REAL))
		for line in real.lines:
			rv.add_child(UiKit.label("• " + str(line.text), 15, UiKit.TEXT, true))
			rv.add_child(UiKit.label("  Sumber: %s (per %s)" % [", ".join(line.source_refs), line.as_of], 11, UiKit.MUTED, true))
	var simctx: Dictionary = c.get("simulated_context", {})
	if not simctx.is_empty():
		rv.add_child(UiKit.tag("KONSEKUENSI SIMULASI · bukan peristiwa sejarah", UiKit.SIM))
		rv.add_child(UiKit.label(str(simctx.text), 14, UiKit.MUTED, true))
	var trig: Dictionary = c.get("trigger", {})
	if str(trig.get("type", "")) == "follow_up":
		rv.add_child(UiKit.tag("PEMICU · kondisi permainan yang terpenuhi", UiKit.SIM))
		for line in ChangeText.describe_conditions(Game.world, trig.get("conditions", {})):
			rv.add_child(UiKit.label(str(line), 12, UiKit.MUTED, true))
	cols.add_child(report)

	var adv := _card()
	adv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var av: VBoxContainer = adv.get_child(0)
	var b: Dictionary = c.get("briefing", {})
	av.add_child(UiKit.title(str(b.get("speaker", "PENASIHAT")).to_upper(), 20))
	av.add_child(UiKit.tag("NARASI FIKSI", UiKit.FICTION))
	var ah := UiKit.hbox(12)
	var pic := UiKit.icon("res://assets/ui/penasihat.png", Vector2(96, 96))
	pic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	ah.add_child(pic)
	var q := UiKit.label("“" + str(b.get("text", "")) + "”", 15, UiKit.TEXT, true)
	q.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ah.add_child(q)
	av.add_child(ah)
	av.add_child(UiKit.label("Tidak ada pilihan tanpa risiko dan konsekuensi.", 11, UiKit.MUTED, true))
	cols.add_child(adv)

	# Policy cards
	_body.add_child(UiKit.title("TENTUKAN KEBIJAKAN", 22, UiKit.ACCENT))
	_body.add_child(UiKit.tag("PILIHAN · dampaknya adalah hasil SIMULASI, bukan sejarah · tekan 1–%d lalu Enter" % c.choices.size(), UiKit.SIM))
	var row := UiKit.hbox(12)
	_body.add_child(row)
	var group := ButtonGroup.new()
	var n := 1
	for ch in c.choices:
		var btn := Button.new()
		btn.theme_type_variation = "ButtonChoice"
		btn.toggle_mode = true
		btn.button_group = group
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 230)
		btn.text = "%d  ·  %s\n\n%s\n\n%s" % [n, str(ch.label).to_upper(), ch.description, _cost_line(ch)]
		var preview := ChangeText.choice_preview(ch)
		if preview != "":
			btn.text += "\n" + preview
		btn.tooltip_text = "Tekan %d" % n
		var cid: String = ch.choice_id
		btn.pressed.connect(func(): _select(cid))
		row.add_child(btn)
		_cards.append([cid, btn])
		n += 1
	visible = true
	_update_confirm()
	_scroll.scroll_vertical = 0
	_fit.call_deferred()


func _card() -> PanelContainer:
	var p := PanelContainer.new()
	p.theme_type_variation = "PanelCard"
	p.add_child(UiKit.vbox(8))
	return p


func _select(choice_id: String) -> void:
	_selected = choice_id
	for pair in _cards:
		pair[1].button_pressed = pair[0] == choice_id
	_update_confirm()


func _update_confirm() -> void:
	_confirm.disabled = _selected == ""
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


## Height = content, capped so header, footer and the HUD's top/bottom rows stay clear.
func _fit() -> void:
	var cap := get_viewport_rect().size.y - 520.0
	_scroll.custom_minimum_size = Vector2(1440, minf(_body.get_combined_minimum_size().y, cap))


func _choose(choice_id: String) -> void:
	visible = false
	decided.emit(case_id, choice_id)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.pressed:
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
			# Multi-month fiscal effects are shown as their total, with timing (e.g. a subsidy drain).
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
	parts.append_array(later)  # a gain arriving later is not a cost (e.g. CASE-0005 revenue)
	if delayed:
		parts.append("sebagian dampak tertunda")
	return " · ".join(parts)
