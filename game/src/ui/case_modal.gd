class_name CaseModal
extends PanelContainer
## Select then confirm. Facts/fiction/provenance remain distinct and available on demand.
signal decided(case_id: String, choice_id: String)
signal region_data_requested(region_id: String)
var _body: VBoxContainer
var _scroll: ScrollContainer
var _header_slot: VBoxContainer
var _footer: HBoxContainer
var _confirm: Button
var case_id := ""
var _selected := ""
var _cards: Array = []
var _selection_summary: Label
var _selection_detail: VBoxContainer
var _context_details: VBoxContainer
var _facts_preview: VBoxContainer
var map_lod: MapLod

func _ready() -> void:
	add_theme_stylebox_override("panel", GameSkin.frame())
	var content := UiKit.vbox(14)
	add_child(content)
	_header_slot = UiKit.vbox(0)
	_header_slot.minimum_size_changed.connect(func(): if visible: _fit.call_deferred())
	content.add_child(_header_slot)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(_scroll)
	_body = UiKit.vbox(14)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	_body.minimum_size_changed.connect(func(): if visible: _fit.call_deferred())
	content.add_child(HSeparator.new())
	_footer = UiKit.hbox(14)
	content.add_child(_footer)
	var data := UiKit.ghost_button("Data Wilayah", _view_data, "Buka detail wilayah kasus")
	data.custom_minimum_size = Vector2(160, 46)
	_footer.add_child(data)
	_selection_summary = UiKit.label("Pilih opsi 1–3, lalu tetapkan keputusan.", 16, UiKit.MUTED, true)
	_selection_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_selection_summary)
	_confirm = UiKit.button("Tetapkan keputusan", _confirm_choice, true)
	_confirm.custom_minimum_size = Vector2(268, 48)
	_footer.add_child(_confirm)
	hide()

func present(id: String) -> void:
	case_id = id
	_selected = ""
	_cards.clear()
	var current: Dictionary = ContentDB.cases[id]
	UiKit.clear(_header_slot)
	UiKit.clear(_body)
	_header_slot.add_child(UiKit.modal_header("", str(current.title), close_modal))

	# Prominent Situation Briefing Card so the player immediately reads the core problem clearly
	var brief_card := PanelContainer.new()
	var brief_style := StitchTheme.soft_box(Color("fbf1da"), Color("b64926"), 6, 18, 10, 1)
	brief_style.border_width_left = 6
	brief_style.border_width_top = 1
	brief_style.border_width_right = 1
	brief_style.border_width_bottom = 1
	brief_card.add_theme_stylebox_override("panel", brief_style)
	var brief_col := UiKit.vbox(4)
	brief_card.add_child(brief_col)

	var brief_top := UiKit.hbox(12)
	var loc := str(current.get("location_label", "")).strip_edges()
	var eyebrow_txt := ("SITUASI KRISIS · " + loc.to_upper()) if loc != "" else "SITUASI KRISIS"
	var eyebrow := UiKit.subheader(eyebrow_txt, UiKit.WARN, 16)
	eyebrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brief_top.add_child(eyebrow)

	_context_details = UiKit.vbox(12)
	var more := UiKit.ghost_button("Laporan lengkap  ▾", func():
		_context_details.visible = not _context_details.visible
		_fit.call_deferred())
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	brief_top.add_child(more)
	brief_col.add_child(brief_top)

	_facts_preview = UiKit.vbox(4)
	_facts_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var intro := UiKit.title(_player_intro(current), 24, UiKit.TEXT)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_facts_preview.add_child(intro)
	brief_col.add_child(_facts_preview)

	brief_col.add_child(_context_details)
	_build_context(current)
	_context_details.hide()
	_body.add_child(brief_card)

	var columns := UiKit.hbox(16)
	_body.add_child(columns)
	var choices := UiKit.vbox(8)
	choices.custom_minimum_size.x = 460
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_child(UiKit.subheader("PILIH KEBIJAKAN (TEKAN 1–3)", UiKit.MUTED, 15))
	columns.add_child(choices)
	var detail := _card()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_stretch_ratio = 1.35
	_selection_detail = detail.get_child(0)
	columns.add_child(detail)
	var group := ButtonGroup.new()
	var number := 1
	for choice in current.choices:
		choices.add_child(_build_choice_card(number, choice, group))
		number += 1
	_show_selection()
	show()
	_update_confirm()
	_scroll.scroll_vertical = 0
	_fit.call_deferred()
	UiKit.animate_open(self)


func _player_intro(current: Dictionary) -> String:
	var narrative := str(current.get("simulated_context", {}).get("text", current.get("briefing", {}).get("text", ""))).strip_edges()
	if narrative.begins_with("Pak Presiden, kasus ini diangkat"):
		var end := narrative.find(". ")
		if end >= 0:
			narrative = narrative.substr(end + 2).strip_edges()
	narrative = narrative.trim_prefix("Dalam simulasi kita, ")
	var parts := narrative.split(". ")
	var out := parts[0].strip_edges()
	if parts.size() > 1 and out.length() < 95:
		var second := parts[1].strip_edges()
		if second != "" and (out.length() + second.length()) < 220:
			out = out + ". " + second
	if out != "":
		out = out[0].to_upper() + out.substr(1)
	return out if out.ends_with(".") else out + "."


func _show_selection() -> void:
	UiKit.clear(_selection_detail)
	if _selected == "":
		_selection_detail.add_child(UiKit.title("Wilayah Terdampak", 26))
		_selection_detail.add_child(UiKit.label("Klik salah satu opsi di kiri (atau tekan 1–3) untuk melihat manfaat, risiko, dan jangkauannya.", 18, UiKit.MUTED, true))
		var current: Dictionary = ContentDB.cases[case_id]
		if map_lod != null and not current.get("focus_regions", []).is_empty():
			var preview := MapPreview.new()
			preview.lod = map_lod
			preview.focus_ids = current.focus_regions
			preview.custom_minimum_size = Vector2(0, 210)
			preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
			preview.selected.connect(func(region): hide(); region_data_requested.emit(region))
			_selection_detail.add_child(preview)
		return
	for choice in ContentDB.cases[case_id].choices:
		if str(choice.choice_id) != _selected:
			continue
		var data := ChangeText.choice_card_data(choice)
		var heading := UiKit.title(str(choice.label), 26)
		heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_selection_detail.add_child(heading)
		_selection_detail.add_child(HSeparator.new())
		var ben_box := _tint_box(UiKit.SUCCESS)
		var ben_col: VBoxContainer = ben_box.get_child(0)
		ben_col.add_child(UiKit.title("Manfaat", 20, UiKit.SUCCESS))
		ben_col.add_child(UiKit.label(str(data.benefit), 20, UiKit.TEXT, true))
		_selection_detail.add_child(ben_box)
		var risk_box := _tint_box(UiKit.WARN)
		var risk_col: VBoxContainer = risk_box.get_child(0)
		risk_col.add_child(UiKit.title("Risiko", 20, UiKit.WARN))
		risk_col.add_child(UiKit.label(str(data.risk), 20, UiKit.TEXT, true))
		_selection_detail.add_child(risk_box)
		_selection_detail.add_child(UiKit.spacer())
		_selection_detail.add_child(UiKit.label(str(data.scope_chip), 18, UiKit.MUTED, true))
	_fit.call_deferred()


func _tint_box(accent: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StitchTheme.soft_box(Color(accent, 0.09), Color(accent, 0.36), 6, 14, 10, 1)
	s.border_width_left = 4
	p.add_theme_stylebox_override("panel", s)
	p.add_child(UiKit.vbox(4))
	return p


func _build_context(current: Dictionary) -> void:
	var real: Dictionary = current.get("real_context", {})
	if not real.get("lines", []).is_empty():
		_context_details.add_child(UiKit.subheader("FAKTA SEJARAH", UiKit.REAL, 14))
		for fact in real.lines:
			_context_details.add_child(UiKit.label("• " + str(fact.text), 16, UiKit.TEXT, true))
			var source := UiKit.label("Sumber: " + ChangeText.clean_source_names(fact.source_refs, str(fact.as_of)), 14, UiKit.MUTED, true)
			source.tooltip_text = "ID sumber: " + ", ".join(fact.source_refs)
			_context_details.add_child(source)
	var simulated: Dictionary = current.get("simulated_context", {})
	if not simulated.is_empty():
		_context_details.add_child(UiKit.label(str(simulated.text), 16, UiKit.TEXT, true))
	var trigger: Dictionary = current.get("trigger", {})
	if str(trigger.get("type", "")) == "follow_up":
		_context_details.add_child(UiKit.title("Alasan kasus muncul", 18))
		for line in ChangeText.describe_conditions(Game.world, trigger.get("conditions", {})):
			_context_details.add_child(UiKit.label(str(line), 16, UiKit.TEXT, true))
	var advisor: Dictionary = current.get("briefing", {})
	_context_details.add_child(HSeparator.new())
	_context_details.add_child(UiKit.label(str(advisor.get("speaker", "Penasihat")) + " · DIALOG FIKSI", 14, UiKit.FICTION, true))
	_context_details.add_child(UiKit.label("“" + str(advisor.get("text", "")) + "”", 16, UiKit.TEXT, true))
func _build_choice_card(number: int, choice: Dictionary, group: ButtonGroup) -> Button:
	var data := ChangeText.choice_card_data(choice)
	var button := Button.new()
	button.theme_type_variation = "ButtonChoice"
	button.toggle_mode = true
	button.button_group = group
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 86)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = str(data.cost_tooltip)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22 if side in ["left", "right"] else 12)
	button.add_child(margin)
	var body := UiKit.vbox(4)
	margin.add_child(body)
	var head := UiKit.hbox(8)
	var title := UiKit.title("%d. %s" % [number, str(choice.label)], 21)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var selected := UiKit.label("✓", 21, UiKit.ACCENT)
	selected.modulate.a = 0.0
	head.add_child(selected)
	body.add_child(head)
	var cost_row := UiKit.hbox(8)
	cost_row.add_child(FigmaAssets.picture(6, "imgIkonCoin", Vector2(20, 20)))
	var cost := UiKit.number(str(data.cost_text).trim_prefix("Anggaran "), 20, UiKit.ACCENT)
	cost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cost.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost.set_meta("choice_cost_value", true)
	cost_row.add_child(cost)
	body.add_child(cost_row)
	UiKit.ignore_mouse(margin)
	margin.minimum_size_changed.connect(func():
		var height := maxf(86.0, margin.get_combined_minimum_size().y)
		if not is_equal_approx(button.custom_minimum_size.y, height):
			button.custom_minimum_size.y = height)
	var id: String = choice.choice_id
	button.pressed.connect(func(): _select(id))
	_cards.append([id, button, selected])
	return button


func _card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelCard"
	panel.add_child(UiKit.vbox(8))
	return panel

func _select(choice_id: String) -> void:
	_selected = choice_id
	for entry in _cards:
		var selected: bool = entry[0] == choice_id
		entry[1].button_pressed = selected
		entry[2].modulate.a = 1.0 if selected else 0.0
	_show_selection()
	_update_confirm()

func _update_confirm() -> void:
	_confirm.disabled = _selected == ""
	_selection_summary.text = "Pilih opsi 1–3 untuk melihat detail sebelum menetapkan."
	if _selected != "":
		for choice in ContentDB.cases[case_id].choices:
			if choice.choice_id == _selected:
				_selection_summary.text = "Opsi %s terpilih — tekan Enter untuk menetapkan." % _selected.to_upper()
	_confirm.tooltip_text = "Pilih satu opsi terlebih dahulu." if _selected == "" else "Tetapkan pilihan (Enter)"

func _confirm_choice() -> void:
	if _selected != "":
		_choose(_selected)

func close_modal() -> void:
	hide()

func _view_data() -> void:
	var current: Dictionary = ContentDB.cases[case_id]
	hide()
	if not current.get("focus_regions", []).is_empty():
		region_data_requested.emit(str(current.focus_regions[0]))

func _fit() -> void:
	if not visible:
		return
	var viewport := get_viewport_rect().size
	var width := minf(viewport.x - 48.0, 1320.0)
	custom_minimum_size.x = width
	var content: VBoxContainer = get_child(0)
	var reserved: float = get_theme_stylebox("panel").get_minimum_size().y
	var count := 0
	for child in content.get_children():
		if child is Control and child.visible:
			count += 1
			if child != _scroll:
				reserved += child.get_combined_minimum_size().y
	reserved += content.get_theme_constant("separation") * maxi(0, count - 1)
	var cap := maxf(120.0, viewport.y - 48.0 - reserved)
	var inner_width := width - get_theme_stylebox("panel").get_minimum_size().x
	_scroll.custom_minimum_size = Vector2(inner_width, minf(_body.get_combined_minimum_size().y, cap))

func _choose(choice_id: String) -> void:
	hide()
	decided.emit(case_id, choice_id)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and not is_ancestor_of(focus):
		return
	var key := (event as InputEventKey).keycode
	if key >= KEY_1 and key <= KEY_9:
		var index := key - KEY_1
		var choices: Array = ContentDB.cases[case_id].choices
		if index < choices.size():
			get_viewport().set_input_as_handled()
			_select(choices[index].choice_id)
	elif key in [KEY_ENTER, KEY_KP_ENTER]:
		get_viewport().set_input_as_handled()
		_confirm_choice()
	elif key == KEY_ESCAPE:
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
