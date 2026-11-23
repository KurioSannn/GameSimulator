class_name AgendaBoard
extends PanelContainer
## "Agenda Kuartal": the issues currently on the President's desk. The player takes up one per
## quarter; every card states how long it can wait and what happens if it does (Campaign).

signal taken(case_id: String)
signal delegated(case_id: String)
signal closed

var _list: VBoxContainer
var _head: Label
var _sub: Label
var _foot: Label


func _ready() -> void:
	add_theme_stylebox_override("panel", GameSkin.frame())
	custom_minimum_size = Vector2(960, 0)
	var col := UiKit.vbox(12)
	add_child(col)
	var top := UiKit.hbox(12)
	var tcol := UiKit.vbox(2)
	tcol.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_head = UiKit.title("AGENDA KUARTAL", 30, UiKit.ACCENT)
	tcol.add_child(_head)
	_sub = UiKit.label("", 17, UiKit.MUTED, true)
	tcol.add_child(_sub)
	top.add_child(tcol)
	var close := UiKit.ghost_button("Lihat peta dulu", func(): hide(); closed.emit(), "Tutup agenda dan jelajahi peta (Esc)")
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(close)
	col.add_child(top)
	col.add_child(HSeparator.new())
	_list = UiKit.vbox(12)
	col.add_child(_list)
	_foot = UiKit.label("", 15, UiKit.MUTED, true)
	col.add_child(_foot)
	hide()


func open(session: Session) -> void:
	UiKit.clear(_list)
	var w := session.world
	_head.text = "AGENDA KUARTAL %d DARI 20" % (w.quarter_index() + 1)
	var items := Campaign.items(session)
	if Campaign.taken_this_quarter(w):
		_sub.text = "Keputusan besar kuartal ini sudah diambil. Agenda lain menunggu kuartal berikutnya."
	elif items.size() == 1:
		_sub.text = "Satu persoalan menunggu arahan Bapak kuartal ini."
	else:
		_sub.text = "Pilih satu persoalan untuk ditangani langsung kuartal ini. Yang lain menunggu, dan tidak bisa menunggu selamanya."
	for item in items:
		_list.add_child(_card(session, item))
	var waiting := Campaign.waiting(session).size()
	_foot.text = ("%d persoalan lain sudah antre dan akan masuk ke meja Bapak saat ada ruang." % waiting) if waiting > 0 else ""
	show()
	UiKit.animate_open(self)
	UiKit.trap_focus.call_deferred(self)


func _card(session: Session, item: Dictionary) -> PanelContainer:
	var c: Dictionary = session.cases.cases[item.case_id]
	var story: Dictionary = c.get("story", {})
	var card := PanelContainer.new()
	card.theme_type_variation = "PanelCard"
	var row := UiKit.hbox(16)
	card.add_child(row)
	var info := UiKit.vbox(4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var tags := UiKit.hbox(8)
	var follow := str(c.get("class", "")) == "secondary_consequence"
	tags.add_child(UiKit.tag("LANJUTAN" if follow else "BARU", UiKit.INFO if follow else UiKit.ACCENT, 12))
	var critical := Campaign.is_critical(c)
	if critical:
		tags.add_child(UiKit.tag("KRISIS BESAR", UiKit.DANGER, 12))
	var left := int(item.quarters_left)
	var urgent := left <= 1
	tags.add_child(UiKit.tag("Harus ditangani kuartal ini" if urgent else "Bisa menunggu %d kuartal" % (left - 1), UiKit.DANGER if urgent else UiKit.MUTED, 12))
	info.add_child(tags)
	var t := UiKit.title(str(c.get("title", item.case_id)), 23)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(t)
	var loc := str(c.get("location_label", ""))
	if loc != "":
		info.add_child(UiKit.subheader(loc.to_upper(), UiKit.WARN, 13))
	var hook := str(story.get("agenda", {}).get("hook", c.get("briefing", {}).get("text", "")))
	info.add_child(UiKit.label(hook, 17, UiKit.TEXT, true))
	var post := str(story.get("agenda", {}).get("if_postponed", ""))
	if post != "":
		info.add_child(UiKit.label("Jika terlalu lama ditunda: " + post, 15, UiKit.MUTED, true))
	if critical:
		info.add_child(UiKit.label("Krisis sebesar ini menunggu keputusan Presiden sendiri. Bila terlewat demi urusan yang lebih kecil, rakyat akan mengingatnya.", 15, UiKit.DANGER, true))
	var acts := UiKit.vbox(8)
	acts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(acts)
	var btn := UiKit.button("TANGANI", func(): hide(); taken.emit(str(item.case_id)), true)
	btn.custom_minimum_size = Vector2(196, 52)
	btn.disabled = Campaign.taken_this_quarter(session.world) or session.pending_case() != ""
	acts.add_child(btn)
	if not critical:
		var del := UiKit.ghost_button("Serahkan ke kementerian", func(): delegated.emit(str(item.case_id)),
			"Kementerian menangani tanpa arahan langsung. Lebih ringan daripada dibiarkan menunggu, tetapi tidak sebaik ditangani sendiri.")
		del.custom_minimum_size = Vector2(196, 44)
		acts.add_child(del)
	return card


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hide()
		closed.emit()
