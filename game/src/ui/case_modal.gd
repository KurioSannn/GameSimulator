class_name CaseModal
extends PanelContainer
## Presents an active case: real context (sourced, dated) → fictional briefing → simulated choices.
## The three layers are visually labeled so facts and fiction are never confused (docs/27 labels).

signal decided(case_id: String, choice_id: String)

var _body: VBoxContainer
var _scroll: ScrollContainer
var case_id := ""


func _ready() -> void:
	custom_minimum_size = Vector2(760, 0)
	add_theme_stylebox_override("panel", UiKit.panel_style(UiKit.PANEL_LIGHT, 10, 22))
	# Long cases (many sourced facts + three choices) must never push choices off screen: scroll.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = UiKit.vbox(10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_body)
	visible = false


func present(id: String) -> void:
	case_id = id
	var c: Dictionary = ContentDB.cases[id]
	UiKit.clear(_body)
	_body.add_child(UiKit.label("KASUS · " + str(c.get("location_label", "")), 13, UiKit.MUTED))
	_body.add_child(UiKit.label(str(c.title), 28, UiKit.TEXT, true))

	var real: Dictionary = c.get("real_context", {})
	if not real.get("lines", []).is_empty():
		_body.add_child(UiKit.tag("FAKTA NYATA · bersumber", UiKit.REAL))
		for line in real.lines:
			_body.add_child(UiKit.label("• " + str(line.text), 15, UiKit.TEXT, true))
			_body.add_child(UiKit.label("  Sumber: %s (per %s)" % [", ".join(line.source_refs), line.as_of], 11, UiKit.MUTED, true))

	var simctx: Dictionary = c.get("simulated_context", {})
	if not simctx.is_empty():
		_body.add_child(UiKit.tag("KONSEKUENSI SIMULASI · bukan peristiwa sejarah", UiKit.SIM))
		_body.add_child(UiKit.label(str(simctx.text), 14, UiKit.MUTED, true))

	# Follow-ups: show the actual game conditions that triggered the case, with current values.
	var trig: Dictionary = c.get("trigger", {})
	if str(trig.get("type", "")) == "follow_up":
		_body.add_child(UiKit.tag("PEMICU · kondisi permainan yang terpenuhi", UiKit.SIM))
		for line in ChangeText.describe_conditions(Game.world, trig.get("conditions", {})):
			_body.add_child(UiKit.label(str(line), 12, UiKit.MUTED, true))

	var b: Dictionary = c.get("briefing", {})
	_body.add_child(UiKit.tag("NARASI FIKSI · " + str(b.get("speaker", "")), UiKit.FICTION))
	_body.add_child(UiKit.label("“" + str(b.get("text", "")) + "”", 16, UiKit.TEXT, true))

	_body.add_child(HSeparator.new())
	_body.add_child(UiKit.tag("PILIHAN · dampaknya adalah hasil SIMULASI, bukan sejarah · tekan 1–%d" % c.choices.size(), UiKit.SIM))
	var n := 1
	for ch in c.choices:
		var btn := Button.new()
		btn.text = "%d.  %s\n      %s\n      %s" % [n, ch.label, ch.description, _cost_line(ch)]
		var preview := ChangeText.choice_preview(ch)
		if preview != "":
			btn.text += "\n      " + preview
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 64)
		btn.tooltip_text = "Tekan %d" % n
		var cid: String = ch.choice_id
		btn.pressed.connect(func(): _choose(cid))
		_body.add_child(btn)
		n += 1
	visible = true
	_scroll.scroll_vertical = 0
	_fit.call_deferred()


## Height = content, capped to the viewport minus top bar and turn controls.
func _fit() -> void:
	var cap := get_viewport_rect().size.y - 240.0  # clear the top bar (86 px) and the turn controls
	_scroll.custom_minimum_size = Vector2(716, minf(_body.get_combined_minimum_size().y, cap))


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
			_choose(chs[idx].choice_id)


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
