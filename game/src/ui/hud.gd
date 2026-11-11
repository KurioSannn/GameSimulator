class_name Hud
extends Control
## Main-screen HUD laid out after the Stitch "Beranda" screen (sidebar, stat cards, agenda, big CTA).
## Presentation only: it owns no gameplay state. Main wires its signals to Game.

signal next_pressed
signal policy_pressed
signal budget_pressed
signal log_pressed
signal decision_pressed
signal menu_selected(id: String)
signal overlay_selected(def: Dictionary)
signal change_toggled(on: bool)
signal zoom_pressed(factor: float)

var indicators: HBoxContainer
var next_btn: Button
var legend: Label
var lod_label: Label
var weighting_label: Label
var change_btn: CheckButton
var uncal_tag: Control
var right_col: VBoxContainer
var _bab: Label
var _agenda_box: VBoxContainer
var _period: Label
var _mandat_bar: ProgressBar
var _mandat_text: Label
var _kabar: Label
var _agenda_title: Label
var _agenda_sub: Label
var _agenda_btn: Button
var _agenda_count: Label
var _term: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_sidebar()
	_build_right()
	_build_bottom()


# ---- top: profile + indicators + menu -------------------------------------------------------
func _build_top() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 24; bar.offset_right = -24; bar.offset_top = 16
	bar.add_theme_constant_override("separation", 14)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bar)

	var prof := PanelContainer.new()
	prof.theme_type_variation = "PanelCard"
	prof.custom_minimum_size = Vector2(320, 0)
	var ph := UiKit.hbox(10)
	prof.add_child(ph)
	ph.add_child(UiKit.icon("res://assets/ui/nara_portrait.png", Vector2(60, 64)))
	var pv := UiKit.vbox(2)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_child(UiKit.title("NARA ADINATA", 22))
	_period = UiKit.label("", 12, UiKit.MUTED)
	pv.add_child(_period)
	_mandat_bar = ProgressBar.new()
	_mandat_bar.show_percentage = false
	_mandat_bar.custom_minimum_size = Vector2(0, 10)
	_mandat_bar.max_value = 20
	pv.add_child(_mandat_bar)
	ph.add_child(pv)
	bar.add_child(prof)

	indicators = UiKit.hbox(12)
	indicators.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(indicators)

	var wl := UiKit.vbox(2)
	weighting_label = UiKit.label("", 11, UiKit.MUTED)
	wl.add_child(weighting_label)
	var menu := MenuButton.new()
	menu.text = "☰  MENU"
	menu.flat = false
	menu.add_theme_stylebox_override("normal", StitchTheme.box(StitchTheme.color("accent")))
	menu.add_theme_stylebox_override("hover", StitchTheme.box(StitchTheme.color("accent").lightened(0.12)))
	menu.add_theme_stylebox_override("pressed", StitchTheme.box(StitchTheme.color("accent").darkened(0.18)))
	var pm := menu.get_popup()
	for it in [["Simpan Cepat (F5)", "save_quick"], ["Muat Cepat (F9)", "load_quick"], ["Simpan Slot Baru (Ctrl+S)", "save_new"], ["Catatan Peristiwa (L)", "log"]]:
		pm.add_item(it[0])
		pm.set_item_metadata(pm.item_count - 1, it[1])
	pm.id_pressed.connect(func(i: int): menu_selected.emit(str(pm.get_item_metadata(pm.get_item_index(i)))))
	var mr := UiKit.vbox(2)
	mr.add_child(menu)
	bar.add_child(mr)


# ---- left: sidebar of destinations ----------------------------------------------------------
func _build_sidebar() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(24, 150)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var title := UiKit.vbox(0)
	title.add_child(UiKit.title("NUSANTARA", 40, UiKit.ACCENT))
	title.add_child(UiKit.title("PETA NASIONAL", 16))
	col.add_child(title)
	for spec in [
		["KABINET", "kabinet", "", "Belum tersedia dalam versi ini."],
		["KEBIJAKAN", "kebijakan", "policy", "Kebijakan wilayah (P)"],
		["ANGGARAN", "anggaran", "budget", "Anggaran nasional (B)"],
		["PUSAT DATA", "pusat_data", "log", "Catatan peristiwa & data (L)"],
		["WARISAN", "warisan", "", "Belum tersedia dalam versi ini."]]:
		col.add_child(_side_button(spec))


func _side_button(spec: Array) -> Control:
	var v := UiKit.vbox(2)
	v.custom_minimum_size = Vector2(96, 0)
	var b := Button.new()
	b.theme_type_variation = "ButtonAccent" if spec[2] == "policy" else "Button"
	b.icon = load("res://assets/ui/icons/%s.png" % spec[1])
	b.expand_icon = true
	b.custom_minimum_size = Vector2(84, 72)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.tooltip_text = spec[3]
	b.disabled = spec[2] == ""
	match spec[2]:
		"policy": b.pressed.connect(func(): policy_pressed.emit())
		"budget": b.pressed.connect(func(): budget_pressed.emit())
		"log": b.pressed.connect(func(): log_pressed.emit())
	v.add_child(b)
	var l := UiKit.title(spec[0], 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	return v


# ---- right: chapter, agenda, time, layer, zoom ----------------------------------------------
func _build_right() -> void:
	right_col = VBoxContainer.new()
	right_col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_col.offset_right = -24
	right_col.offset_left = -324
	right_col.offset_top = 130
	right_col.custom_minimum_size = Vector2(300, 0)
	right_col.add_theme_constant_override("separation", 10)
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_col)

	var bab := PanelContainer.new()
	bab.theme_type_variation = "PanelHeader"
	var bv := UiKit.vbox(0)
	bv.add_child(UiKit.title("BAB 01", 12, UiKit.ACCENT))
	_bab = UiKit.title("SEBUAH MANDAT BARU", 16)
	bv.add_child(_bab)
	bab.add_child(bv)
	right_col.add_child(bab)

	var ag := PanelContainer.new()
	ag.theme_type_variation = "PanelCard"
	var av := UiKit.vbox(6)
	av.add_child(UiKit.title("LAPISAN PETA", 14, UiKit.ACCENT))
	var opt := OptionButton.new()
	for d in Overlays.DEFS:
		opt.add_item(d.label)
	opt.item_selected.connect(func(i: int): overlay_selected.emit(Overlays.DEFS[i]))
	av.add_child(opt)
	change_btn = CheckButton.new()
	change_btn.text = "Perubahan kuartal (C)"
	change_btn.tooltip_text = "Warnai peta menurut perubahan variabel ini selama kuartal terakhir, bukan nilainya."
	change_btn.toggled.connect(func(on: bool): change_toggled.emit(on))
	av.add_child(change_btn)
	legend = UiKit.label("", 12, UiKit.MUTED, true)
	legend.custom_minimum_size.x = 270
	av.add_child(legend)
	lod_label = UiKit.label("", 11, UiKit.MUTED, true)
	lod_label.custom_minimum_size.x = 270
	av.add_child(lod_label)
	ag.add_child(av)
	right_col.add_child(ag)

	var zoom := HBoxContainer.new()
	zoom.alignment = BoxContainer.ALIGNMENT_END
	zoom.add_theme_constant_override("separation", 8)
	for spec in [["+", 1.3], ["−", 1.0 / 1.3]]:
		var z := Button.new()
		z.text = spec[0]
		z.custom_minimum_size = Vector2(48, 44)
		var f: float = spec[1]
		z.pressed.connect(func(): zoom_pressed.emit(f))
		zoom.add_child(z)
	right_col.add_child(zoom)


# ---- bottom: mandate, news, agenda, CTA -----------------------------------------------------
func _build_bottom() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = 24; row.offset_right = -24; row.offset_bottom = -20; row.offset_top = -150
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	var mandat := PanelContainer.new()
	mandat.theme_type_variation = "PanelHeader"
	mandat.custom_minimum_size = Vector2(340, 0)
	var mv := UiKit.vbox(4)
	mv.add_child(UiKit.title("MANDAT NASIONAL", 18, UiKit.ACCENT))
	_mandat_text = UiKit.label("", 14)
	mv.add_child(_mandat_text)
	_term = UiKit.label("", 12, UiKit.MUTED)
	mv.add_child(_term)
	mandat.add_child(mv)
	row.add_child(mandat)

	var mid := VBoxContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 8)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kb := PanelContainer.new()
	kb.theme_type_variation = "PanelCard"
	var kh := UiKit.hbox(12)
	kh.add_child(UiKit.title("KABAR", 14, UiKit.ACCENT))
	_kabar = UiKit.label("", 14, UiKit.TEXT, false)
	_kabar.clip_text = true
	_kabar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kh.add_child(_kabar)
	kb.add_child(kh)
	mid.add_child(kb)
	var agb := PanelContainer.new()
	agb.theme_type_variation = "PanelCard"
	var agh := UiKit.hbox(14)
	_agenda_count = UiKit.title("0", 34, UiKit.WARN)
	agh.add_child(_agenda_count)
	var agv := UiKit.vbox(0)
	agv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agenda_title = UiKit.title("", 22)
	_agenda_sub = UiKit.label("", 13, UiKit.MUTED)
	agv.add_child(_agenda_title)
	agv.add_child(_agenda_sub)
	agh.add_child(agv)
	_agenda_btn = Button.new()
	_agenda_btn.text = "AMBIL KEPUTUSAN ➜"
	_agenda_btn.theme_type_variation = "ButtonPrimary"
	_agenda_btn.pressed.connect(func(): decision_pressed.emit())
	agh.add_child(_agenda_btn)
	agb.add_child(agh)
	mid.add_child(agb)
	row.add_child(mid)

	next_btn = Button.new()
	next_btn.text = "LANJUTKAN\nKUARTAL"
	next_btn.theme_type_variation = "ButtonPrimary"
	next_btn.add_theme_font_size_override("font_size", 28)
	next_btn.custom_minimum_size = Vector2(300, 104)
	next_btn.tooltip_text = "Simulasikan 3 bulan untuk seluruh wilayah (Spasi)"
	next_btn.pressed.connect(func(): next_pressed.emit())
	row.add_child(next_btn)


## Pulls display text from the world. Read-only.
func refresh(w: SimWorld, pending_case: String) -> void:
	_period.text = "PRESIDEN · TAHUN %d / 5" % (w.year_index() + 1)
	_mandat_bar.value = w.quarter_index()
	_mandat_text.text = "Kuartal %d dari 20" % mini(w.quarter_index() + 1, 20)
	_term.text = "MASA JABATAN SELESAI" if w.is_term_over() else Fmt.period(w)
	var last := ""
	for k in range(w.event_log.size() - 1, -1, -1):
		last = ChangeText.entry_text(w.event_log[k]).split("\n")[0]
		break
	_kabar.text = last if last != "" else "Belum ada kabar. Keputusan dan ringkasan kuartal akan muncul di sini."
	var has := pending_case != ""
	_agenda_count.text = "1" if has else "0"
	_agenda_btn.visible = has
	if has:
		var c: Dictionary = ContentDB.cases[pending_case]
		_agenda_title.text = str(c.title).to_upper()
		_agenda_sub.text = str(c.get("location_label", ""))
		_bab.text = str(c.title).to_upper()
	else:
		_agenda_title.text = "TIDAK ADA KEPUTUSAN MENDESAK"
		_agenda_sub.text = "Lanjutkan kuartal untuk melihat perkembangan."
		_bab.text = "SEBUAH MANDAT BARU"
