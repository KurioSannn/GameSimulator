class_name DesktopScreens
extends Control
## Native Godot implementation of the menu, profile, statistics, quarterly report,
## legacy summary, saves, help, and settings screens. Designed cleanly for 1280x720 and 1920x1080.

signal started
signal closed
signal region_selected(id: String)
signal preferences_changed
signal scenario_requested(case_id: String)
signal tutorial_requested
signal quit_requested

var active_screen := ""
var session_started := false
var visited: Dictionary = {}
var map_lod: MapLod
var _surface: Control
var _content: VBoxContainer
var _origin := "menu"

const INDICATORS := [
	["ANGGARAN", "fiscal_space", "imgIkonCoin"],
	["INDEKS HARGA", "price_level", "imgIkonEconomy"],
	["KESEJAHTERAAN", "welfare", "imgIkonHeart"],
	["KEPERCAYAAN", "trust", "imgIkonTrust"],
	["SENTIMEN", "sentiment", "imgIkonShield"],
	["LINGKUNGAN", "environment", "imgIkonLeaf"],
]


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func open(screen: String) -> void:
	active_screen = screen
	show()
	UiKit.clear(self)
	_surface = Control.new()
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_surface)
	if screen == "menu":
		_menu()
		UiKit.animate_open(_surface)
		return
	_background()

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_surface.add_child(margin)

	_content = UiKit.vbox(12)
	margin.add_child(_content)

	var names := {
		"profile": "PROFIL PRESIDEN",
		"statistics": "STATISTIK PEMERINTAHAN",
		"report": "LAPORAN PEMERINTAHAN",
		"legacy": "RAPOR WARISAN",
		"settings": "PENGATURAN",
		"help": "CARA BERMAIN",
		"saves": "MUAT PERMAINAN",
		"new": "MULAI PEMERINTAHAN BARU",
		"journal": "BUKU KISAH",
		"goals": "TUJUAN MASA BAKTI",
		"library": "KUMPULAN KISAH",
		"credits": "KREDIT",
		"scenario_end": "AKHIR KISAH",
	}

	var header := UiKit.hbox(12)
	var back := UiKit.ghost_button("", _back, "Kembali (Esc)")
	back.icon = FigmaAssets.texture(2 if screen == "profile" else 3 if screen == "statistics" else 4, "imgIkonBack")
	back.custom_minimum_size = Vector2(44, 38)
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for color_key in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		back.add_theme_color_override(color_key, UiKit.TEXT)
	header.add_child(back)

	header.add_child(UiKit.title(str(names.get(screen, screen)), 26, UiKit.ACCENT))
	header.add_child(UiKit.spacer())

	if screen in ["profile", "statistics", "report", "legacy"]:
		var tabs := [["PROFIL", "profile"], ["STATISTIK", "statistics"], ["LAPORAN", "report"]]
		if Game.world != null and Game.world.is_term_over():
			tabs.append(["WARISAN", "legacy"])
		for spec in tabs:
			var dest: String = spec[1]
			var button := UiKit.button(spec[0], func(): open(dest))
			button.theme_type_variation = "ButtonAccent" if screen == dest else "ButtonGhost"
			button.custom_minimum_size = Vector2(124, 38)
			header.add_child(button)
	_content.add_child(header)

	match screen:
		"profile": _profile()
		"statistics": _statistics()
		"report": _report()
		"legacy": _legacy()
		"settings":
			var settings := SettingsView.new()
			settings.size_flags_vertical = Control.SIZE_EXPAND_FILL
			_content.add_child(settings)
			settings.cancelled.connect(_back)
			settings.saved.connect(func(): preferences_changed.emit(); _back())
			settings.tutorial_requested.connect(func(): tutorial_requested.emit())
		"help": _help()
		"saves": _saves()
		"new": _new_confirmation()
		"journal": _journal()
		"goals": _goals()
		"library": _library()
		"credits": _credits()
		"scenario_end": _scenario_end()

	UiKit.animate_open(_content)
	_focus_first.call_deferred()


func close_screen() -> void:
	hide()
	active_screen = ""
	closed.emit()


func _back() -> void:
	if active_screen == "scenario_end":
		Game.end_scenario()
		open("library")
		return
	if active_screen in ["settings", "help", "saves", "new", "legacy", "journal", "goals", "library", "credits"]:
		if _origin == "map":
			close_screen()
		else:
			open(_origin)
	elif session_started:
		close_screen()
	else:
		open("menu")


func _background() -> void:
	var image := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("efe2c5"), Color("d3bd97"), Color("a18a66")])
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.4)
	texture.fill_to = Vector2(1.0, 1.0)
	image.texture = texture
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(image)

	var waves := FigmaAssets.picture(4, "imgRiakSamudra", Vector2.ZERO)
	waves.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	waves.stretch_mode = TextureRect.STRETCH_SCALE
	waves.modulate.a = 0.06
	_surface.add_child(waves)


func _menu() -> void:
	var shade := TextureRect.new()
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.46, 0.64, 1.0])
	gradient.colors = PackedColorArray([Color("182a30", 0.20), Color("182a30", 0.08), Color("182a30", 0.12), Color("182a30", 0.35)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	shade.texture = texture
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(shade)

	# Top-left Brand Lockup (clean AAA logo only, aligned to 40px/32px margins)
	var brand_logo := TextureRect.new()
	brand_logo.texture = load("res://assets/ui/nusantara_logo.png") as Texture2D
	brand_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	brand_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand_logo.custom_minimum_size = Vector2(380, 285)
	brand_logo.position = Vector2(40, 32)
	brand_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_surface.add_child(brand_logo)

	# Top-right utility pills (aligned with right card edge at -40px, top 32px)
	var top_right := UiKit.hbox(10)
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.offset_top = 32
	top_right.offset_right = -40
	_surface.add_child(top_right)

	var settings := UiKit.ghost_button("PENGATURAN", func(): _origin = "menu"; open("settings"), "Buka pengaturan audio, layar, dan kontrol")
	settings.icon = FigmaAssets.texture(0, "imgGroup465")
	settings.custom_minimum_size = Vector2(142, 40)
	top_right.add_child(settings)

	# Right action card (exact same -40px right margin, uniform 32px inner padding, uniform 10px gaps)
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelDock"
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.offset_right = -40
	panel.offset_left = -460
	panel.custom_minimum_size.x = 420
	panel.add_theme_stylebox_override("panel", GameSkin.frame("panel_brown_corners_a", 32, 24))
	_surface.add_child(panel)

	var body := UiKit.vbox(10)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(body)
	var hdr_lbl := UiKit.title("PEMERINTAHANMU", 20, UiKit.ACCENT)
	hdr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(hdr_lbl)
	body.add_child(HSeparator.new())

	var begin := UiKit.button("MULAI PEMERINTAHAN BARU", func():
		_origin = "menu"
		if session_started and not Game.in_scenario():
			open("new")
		else:
			_start_new(), true)
	begin.custom_minimum_size.y = 48
	begin.add_theme_font_size_override("font_size", 19)
	body.add_child(begin)

	if Game.in_scenario():
		var leave := UiKit.button("KELUAR DARI KISAH INI", func(): Game.end_scenario(); open("library"))
		leave.custom_minimum_size.y = 40
		body.add_child(leave)
	if session_started and not Game.in_scenario():
		var cont := UiKit.button("LANJUTKAN", close_screen)
		cont.custom_minimum_size.y = 40
		body.add_child(cont)
	elif not Game.saves.list_slots().is_empty():
		var latest := UiKit.button("LANJUTKAN", _continue_latest)
		latest.custom_minimum_size.y = 40
		latest.tooltip_text = "Lanjutkan simpanan terakhir"
		body.add_child(latest)
	var row := UiKit.hbox(10)
	for spec in [["MUAT PERMAINAN", "saves"], ["KUMPULAN KISAH", "library"]]:
		var dest: String = spec[1]
		var b := UiKit.button(spec[0], func(): _origin = "menu"; open(dest))
		b.custom_minimum_size.y = 38
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	body.add_child(row)
	var row2 := UiKit.hbox(10)
	for spec in [["CARA BERMAIN", "help"], ["KREDIT", "credits"]]:
		var dest2: String = spec[1]
		var b2 := UiKit.ghost_button(spec[0], func(): _origin = "menu"; open(dest2))
		b2.custom_minimum_size.y = 38
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row2.add_child(b2)
	body.add_child(row2)
	var quit_btn := UiKit.ghost_button("KELUAR", func(): quit_requested.emit(), "Simpan otomatis dan keluar dari permainan")
	quit_btn.custom_minimum_size.y = 38
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(quit_btn)


func _continue_latest() -> void:
	var slots: Array = Game.saves.list_slots().filter(func(x): return bool(x.ok))
	if slots.is_empty():
		return
	var err := Game.load_from(str(slots[0].slot_id))  # list_slots is newest first
	if err != "":
		open("saves")
		return
	session_started = true
	close_screen()
	started.emit()


func _start_new() -> void:
	visited.clear()
	Game.new_game(Game.DEFAULT_SEED)
	session_started = true
	close_screen()
	started.emit()


func _new_confirmation() -> void:
	var card := _card("KONFIRMASI MANDAT BARU")
	card.add_child(UiKit.label("Simpan pemerintahan sekarang sebelum memulai mandat baru. Simpanan sebelumnya tetap tersedia di daftar simpanan.", 16, UiKit.TEXT, true))
	var row := UiKit.hbox(12)
	var confirm := UiKit.button("SIMPAN DAN MULAI MANDAT BARU", func():
		var slot := "sebelum_mandat_" + str(Time.get_unix_time_from_system()).replace(".", "_")
		var err := Game.save_to(slot, "Sebelum mandat baru · " + Fmt.period(Game.world))
		if err == "":
			_start_new()
		else:
			card.add_child(UiKit.label(err, 15, UiKit.WARN)), true)
	confirm.custom_minimum_size = Vector2(320, 48)
	row.add_child(confirm)
	var cancel := UiKit.ghost_button("BATAL", func(): open("menu"))
	cancel.custom_minimum_size = Vector2(140, 48)
	row.add_child(cancel)
	card.add_child(row)


func _saves() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(scroll)
	var list := UiKit.vbox(10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for slot in Game.saves.list_slots():
		var meta: Dictionary = slot.meta
		var id: String = slot.slot_id
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelCard"
		var row := UiKit.hbox(14)
		card.add_child(row)
		var info := UiKit.vbox(4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(UiKit.title(str(meta.get("save_label", id)), 17))
		info.add_child(UiKit.label("Tahun %s · Kuartal %s · Diperbarui %s" % [meta.get("year", "-"), meta.get("quarter", "-"), meta.get("updated_at", "")], 13, UiKit.MUTED))
		if not bool(slot.ok):
			info.add_child(UiKit.tag(str(slot.error), UiKit.DANGER, 11))
		row.add_child(info)
		var load_btn := UiKit.button("MUAT SIMPANAN", func():
			var err := Game.load_from(id)
			if err == "":
				session_started = true
				close_screen()
				started.emit()
			else:
				list.add_child(UiKit.label(err, 15, UiKit.WARN)), true)
		load_btn.disabled = not bool(slot.ok)
		load_btn.custom_minimum_size = Vector2(180, 44)
		row.add_child(load_btn)
		list.add_child(card)
	if list.get_child_count() == 0:
		list.add_child(UiKit.label("Belum ada simpanan di perangkat ini.", 18, UiKit.MUTED))


func _help() -> void:
	var cols := UiKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(cols)

	var left := _card("ALUR PEMERINTAHAN (5 TAHUN)", cols)
	left.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for text in [
		"1. Mulai mandat baru atau lanjutkan simpanan lokal.",
		"2. Pilih wilayah di peta untuk membaca kondisi dan data acuannya.",
		"3. Baca kasus, pilih satu opsi, lalu tekan Tetapkan Keputusan.",
		"4. Atur anggaran (B) dan kebijakan (P) sesuai cakupan wilayah.",
		"5. Lanjutkan Kuartal menjalankan 3 bulan untuk seluruh 514 kabupaten/kota.",
		"6. Buka laporan kuartal untuk mengevaluasi dampak keputusan di seluruh Nusantara.",
	]:
		left.add_child(UiKit.label(text, 15, UiKit.TEXT, true))
	left.add_child(UiKit.spacer())

	var right := _card("KONTROL & PINTASAN KEYBOARD", cols)
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for pair in [
		["Navigasi Peta", "WASD / Panah / Seret Kiri"],
		["Zoom & Reset", "Roda Mouse / Home (Seluruh Indonesia)"],
		["Putar Peta 3D", "Tahan Klik Kanan atau Q / E"],
		["Lanjut Kuartal", "Spasi atau Enter"],
		["Keputusan Kasus", "Angka 1–9 lalu Enter"],
		["Panel Kebijakan / Anggaran", "P (Kebijakan) · B (Anggaran)"],
		["Analisis Peta & Log", "C (Perubahan) · L (Catatan) · T (2D/3D)"],
		["Simpan / Muat Cepat", "F5 (Simpan) · F9 (Muat) · Ctrl+S (Baru)"],
	]:
		right.add_child(UiKit.kv_row(pair[0], pair[1], UiKit.ACCENT, 14))

	var foot := UiKit.hbox(12)
	foot.add_child(UiKit.spacer())
	var back_btn := UiKit.button("KEMBALI", _back, true)
	back_btn.custom_minimum_size = Vector2(180, 44)
	foot.add_child(back_btn)
	_content.add_child(foot)


func _card(title: String, parent: Node = null) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body := UiKit.vbox(10)
	panel.add_child(body)
	if title != "":
		body.add_child(UiKit.section_bar(title, "", UiKit.ACCENT))
	(parent if parent != null else _content).add_child(panel)
	return body


func _profile() -> void:
	var row := UiKit.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var left := UiKit.vbox(10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	row.add_child(left)

	var mandate := _card("PERJALANAN MANDAT", left)
	mandate.add_child(UiKit.title("TAHUN %d DARI 5 TAHUN" % mini(Game.world.year_index() + 1, 5), 20, UiKit.ACCENT))
	mandate.add_child(UiKit.label("Kuartal %d · %d kasus aktif" % [Game.world.quarter_index() % 4 + 1, Game.cases.active_cases(Game.world).size()], 15, UiKit.MUTED))
	var years := UiKit.hbox(6)
	var cur_y := mini(Game.world.year_index(), 4)
	for y in 5:
		var badge := PanelContainer.new()
		var active := y == cur_y
		badge.add_theme_stylebox_override("panel", StitchTheme.soft_box(
			Color(UiKit.ACCENT, 0.22) if active else Color(1, 1, 1, 0.05),
			UiKit.ACCENT if active else Color(1, 1, 1, 0.12), 99, 0, 4, 1))
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var yt := UiKit.title("Thn " + str(y + 1), 13, UiKit.ACCENT if active else UiKit.MUTED)
		yt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(yt)
		years.add_child(badge)
	mandate.add_child(years)
	var bar := ProgressBar.new()
	bar.max_value = 60
	bar.value = Game.world.tick
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	mandate.add_child(bar)

	mandate.add_child(UiKit.kv_row("Kepercayaan rakyat", "%s%%" % Fmt.num(Game.world.national_mean("trust"), 1), UiKit.SUCCESS, 15))

	var badges := _card("LENCANA PENCAPAIAN", left)
	var badges_row := UiKit.hbox(8)
	var decisions := 0
	for state in Game.world.case_state.values():
		decisions += state.get("history", []).size()
	for spec in [
		["Mandat pertama", "imgMedaliMandatPertama", true, "imgTepiMedaliMandatPertama", "imgIkonStar"],
		["Kenali Nusantara", "imgMedaliKenaliNusantara", visited.size() >= 3, "imgTepiMedaliKenaliNusantara", "imgIkonCompass"],
		["Solusi pertama", "imgMedaliSolusiPertama", decisions > 0, "imgTepiMedaliSolusiPertama", "imgIkonLock"],
	]:
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", StitchTheme.soft_box(UiKit.PANEL_SOFT, Color(1, 1, 1, 0.10), 8, 6, 6, 1))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge := UiKit.vbox(3)
		badge.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(badge)
		var symbol: String = "imgIkonStar" if spec[4] == "imgIkonLock" and bool(spec[2]) else str(spec[4])
		var art := FigmaAssets.badge(spec[1], spec[3], symbol)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art.modulate.a = 1.0 if spec[2] else 0.35
		badge.add_child(art)
		var bl := UiKit.label(spec[0], 12, UiKit.TEXT, true)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		var bs := UiKit.label("TERBUKA" if spec[2] else "TERKUNCI", 10, UiKit.SUCCESS if spec[2] else UiKit.MUTED)
		bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(bs)
		badges_row.add_child(tile)
	badges.add_child(badges_row)

	# Character and contact shadow resize together from one feet anchor.
	var stage := UiKit.vbox(8)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_stretch_ratio = 0.9
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(PresidentPortrait.new())
	var nameplate := PanelContainer.new()
	nameplate.add_theme_stylebox_override("panel", GameSkin.frame("panel_brown", 18, 16))
	var identity := UiKit.vbox(2)
	var character_name := UiKit.title(UiPreferences.display_name().to_upper(), 20, UiKit.ACCENT)
	character_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_child(character_name)
	var role := UiKit.label("Presiden Republik Indonesia", 14, UiKit.MUTED, true)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_child(role)
	nameplate.add_child(identity)
	stage.add_child(nameplate)
	row.add_child(stage)

	# Right player profile card
	var right := UiKit.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.85
	row.add_child(right)
	var profile := _card("IDENTITAS PEMAIN", right)
	var name_editor := PlayerNameEditor.new()
	name_editor.saved.connect(func():
		character_name.text = UiPreferences.display_name().to_upper()
		preferences_changed.emit())
	profile.add_child(name_editor)



func _statistics() -> void:
	var columns := UiKit.hbox(18)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(columns)

	var left := UiKit.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.65
	columns.add_child(left)

	var support := _card("DUKUNGAN RAKYAT", left)
	support.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sup_head := UiKit.hbox(10)
	var sup_titles := UiKit.vbox(2)
	sup_titles.add_child(UiKit.title("Riwayat kepercayaan publik", 24))
	sup_head.add_child(sup_titles)
	sup_head.add_child(UiKit.spacer())
	support.add_child(sup_head)

	var chart := TrustChart.new()
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if SimLedger.active(Game.world):
		chart.points.append({"tick": int(Game.world.ledger.start_tick), "value": Game.world.weighted_mean_of(Game.world.ledger.start.trust)})
		for report in Game.last_quarter_reports:
			chart.points.append({"tick": report.tick, "value": report.national.trust})
	if chart.points.is_empty() or int(chart.points[-1].tick) != Game.world.tick:
		chart.points.append({"tick": Game.world.tick, "value": Game.world.national_mean("trust")})
	support.add_child(chart)

	var right := UiKit.vbox(12)
	right.custom_minimum_size.x = 280
	columns.add_child(right)
	var report := _card("RAPOR MANDAT", right)
	report.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	report.add_child(UiKit.title(UiPreferences.display_name().to_upper(), 20, UiKit.ACCENT))
	report.add_child(UiKit.label(Fmt.period(Game.world), 14, UiKit.MUTED, true))
	var pic := FigmaAssets.picture(3, "imgNaraRaporStatistik", Vector2(220, 230))
	pic.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report.add_child(pic)
	var decisions := 0
	for st in Game.world.case_state.values():
		decisions += st.get("history", []).size()
	report.add_child(HSeparator.new())
	report.add_child(UiKit.kv_row("Keputusan diambil", "%d" % decisions, UiKit.ACCENT, 13))
	report.add_child(UiKit.kv_row("Kebijakan aktif", "%d" % Game.world.policy_state.size(), UiKit.TEXT, 13))
	report.add_child(UiKit.kv_row("Daerah ditinjau", "%d wilayah" % visited.size(), UiKit.TEXT, 13))
	var rep_btn := UiKit.button("LAPORAN KUARTAL", func(): open("report"), true)
	rep_btn.custom_minimum_size.y = 44
	report.add_child(rep_btn)

	_indicator_row(_content, false)


func _indicator_row(parent: Node, comparison: bool) -> void:
	var row := UiKit.hbox(10)
	parent.add_child(row)
	for spec in INDICATORS:
		var key: String = spec[1]
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var body := UiKit.vbox(4)
		card.add_child(body)
		var top := UiKit.hbox(6)
		top.add_child(FigmaAssets.picture(3, spec[2], Vector2(20, 20)))
		var label := UiKit.label(spec[0], 11, UiKit.MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		top.add_child(label)
		body.add_child(top)
		var current := float(Game.world.national.get(key, 0.0)) if key == "fiscal_space" else Game.world.national_mean(key)
		if comparison and SimLedger.active(Game.world):
			var previous := float(Game.world.ledger.fiscal_space_start) if key == "fiscal_space" else Game.world.weighted_mean_of(Game.world.ledger.start[key])
			var diff := current - previous
			var good := diff < 0.0 if key == "price_level" else diff >= 0.0
			var dcol := UiKit.MUTED if absf(diff) < 0.05 else (UiKit.SUCCESS if good else UiKit.DANGER)
			var val_row := UiKit.hbox(6)
			val_row.add_child(UiKit.number(Fmt.num(current, 1), 24, UiKit.ACCENT))
			val_row.add_child(UiKit.spacer())
			val_row.add_child(UiKit.label("Δ " + Fmt.signed(diff, 1), 13, dcol))
			body.add_child(val_row)
			body.add_child(UiKit.label("Sebelumnya: %s" % Fmt.num(previous, 1), 11, UiKit.MUTED))
		else:
			body.add_child(UiKit.number(Fmt.num(current, 1), 24, UiKit.ACCENT))
			body.add_child(UiKit.label("%" if key == "trust" else "indeks" if key == "price_level" else "poin" if key == "fiscal_space" else "/ 100", 11, UiKit.MUTED))
		row.add_child(card)


func _report() -> void:
	if not SimLedger.active(Game.world):
		var empty := _card("LAPORAN KUARTAL")
		empty.add_child(UiKit.label("Belum ada kuartal yang selesai. Ambil keputusan lalu lanjutkan kuartal untuk melihat laporan.", 18, UiKit.TEXT, true))
		var back := UiKit.button("KEMBALI KE PETA", close_screen, true)
		back.custom_minimum_size = Vector2(220, 46)
		empty.add_child(back)
		return

	var report_root := _content
	var report_scroll := ScrollContainer.new()
	report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	report_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	report_root.add_child(report_scroll)
	_content = UiKit.vbox(14)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	report_scroll.add_child(_content)
	_content.add_child(UiKit.title("Tahun %d ? Kuartal %d" % [
		mini(int(Game.world.ledger.start_tick) / 12 + 1, 5), int(Game.world.ledger.start_tick) / 3 % 4 + 1], 22))
	_indicator_row(_content, true)

	var row := UiKit.hbox(14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var map_card := _card("PETA DAMPAK WILAYAH", row)
	map_card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_card.get_parent().size_flags_stretch_ratio = 0.85
	map_card.add_child(UiKit.subheader("PERUBAHAN KESEJAHTERAAN (BIRU TURUN · ORANYE NAIK)", UiKit.MUTED, 11))
	var preview := MapPreview.new()
	preview.lod = map_lod
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.custom_minimum_size = Vector2(360, 175)
	var deltas := SimLedger.deltas(Game.world, "welfare")
	var scale := Overlays.change_scale(deltas)
	for i in Game.world.region_count():
		preview.values[Game.world.region_ids[i]] = Overlays.change_color(deltas[i], scale)
	preview.selected.connect(func(id): close_screen(); region_selected.emit(id))
	map_card.add_child(preview)
	map_card.add_child(UiKit.label("Klik salah satu wilayah di peta untuk membuka detail kondisinya.", 12, UiKit.MUTED, true))

	var events := _card("PERISTIWA SELAMA KUARTAL", row)
	events.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	events.get_parent().size_flags_stretch_ratio = 1.3
	events.add_child(UiKit.subheader("KEJADIAN, KEPUTUSAN & PERKEMBANGAN DAERAH", UiKit.MUTED, 11))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(440, 175)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	events.add_child(scroll)
	var event_body := UiKit.vbox(8)
	event_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(event_body)
	for event in Game.world.event_log:
		if int(event.get("tick", 0)) >= int(Game.world.ledger.start_tick):
			var ev := ChangeText.entry_card(event)
			var ec := PanelContainer.new()
			ec.add_theme_stylebox_override("panel", StitchTheme.soft_box(UiKit.PANEL_SOFT, Color(1, 1, 1, 0.09), 8, 12, 9, 1))
			var ecv := UiKit.vbox(6)
			ec.add_child(ecv)
			var eh := UiKit.hbox(8)
			var bcol := UiKit.ACCENT
			match str(ev.badge_key):
				"danger": bcol = UiKit.DANGER
				"info": bcol = UiKit.INFO
				"real": bcol = UiKit.REAL
			eh.add_child(UiKit.tag(str(ev.badge), bcol, 10))
			eh.add_child(UiKit.subheader(str(ev.when), UiKit.MUTED, 11))
			var et := UiKit.title(str(ev.title), 14, UiKit.TEXT)
			et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			et.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eh.add_child(et)
			ecv.add_child(eh)
			if str(ev.subtitle) != "":
				ecv.add_child(UiKit.label(str(ev.subtitle), 13, UiKit.MUTED, true))
			for r in (ev.rows as Array).slice(0, 5):
				var rline := UiKit.hbox(8)
				var vcol := UiKit.SUCCESS if str(r.tone) == "good" else UiKit.DANGER
				var rl := UiKit.label("%s · %s" % [str(r.label), str(r.where)], 13, UiKit.TEXT, true)
				rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				rline.add_child(rl)
				rline.add_child(UiKit.tag("%s (%s)" % [str(r.delta), str(r.when)], vcol, 11))
				ecv.add_child(rline)
			event_body.add_child(ec)

	var why := _card("FAKTOR UTAMA PERUBAHAN")
	var causes: Array = []
	for key in Game.world.ledger.causes.get("welfare", {}):
		var amount := Game.world.weighted_mean_of(Game.world.ledger.causes.welfare[key])
		causes.append({"label": ChangeText.cause_label(key).replace(" (model bahaya)", "").replace(" (model)", ""), "delta": amount})
	causes.sort_custom(func(a, b): return absf(a.delta) > absf(b.delta))
	var why_row := UiKit.hbox(12)
	for cause in causes.slice(0, 3):
		var col := UiKit.SUCCESS if cause.delta >= 0.0 else UiKit.DANGER
		var tag := UiKit.tag("%s: %s poin" % [cause.label, Fmt.signed(cause.delta, 2)], col, 12)
		why_row.add_child(tag)
	if causes.is_empty():
		why_row.add_child(UiKit.label("Kesejahteraan nasional relatif stabil selama kuartal ini.", 13, UiKit.MUTED))
	why.add_child(why_row)

	var foot := UiKit.hbox(14)
	var stat_btn := UiKit.ghost_button("TINJAU STATISTIK", func(): open("statistics"))
	stat_btn.custom_minimum_size = Vector2(200, 44)
	foot.add_child(stat_btn)
	foot.add_child(UiKit.spacer())
	var back_btn := UiKit.button("KEMBALI KE PETA", close_screen, true)
	back_btn.custom_minimum_size = Vector2(220, 44)
	foot.add_child(back_btn)
	report_root.add_child(foot)
	_content = report_root


func _legacy() -> void:
	var w := Game.world
	var ev: Dictionary = w.story.get("ending", {})
	if ev.is_empty():
		ev = Game.evaluate_ending()
	var cfg: Dictionary = ContentDB.story.get("endings", {})
	var arch: Dictionary = cfg.get("archetypes", {}).get(str(ev.get("id", "")), {})
	var head := PanelContainer.new()
	head.theme_type_variation = "PanelHeader"
	var hv := UiKit.vbox(2)
	hv.add_child(UiKit.subheader("AKHIR MASA BAKTI PRESIDEN " + UiPreferences.display_name().to_upper(), Color("fff4d2"), 12))
	hv.add_child(UiKit.title(str(arch.get("title", "")), 34, Color("fff4d2")))
	hv.add_child(UiKit.label(str(arch.get("subtitle", "")), 17, Color("f4dcae")))
	head.add_child(hv)
	_content.add_child(head)
	var row := UiKit.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var left := _card("EMPAT TUJUAN MASA BAKTI", row)
	left.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var words: Dictionary = cfg.get("rating_words", {})
	var ratings: Dictionary = ev.get("ratings", {})
	for p in Narrative.PILLARS:
		var r := str(ratings.get(p, "fair"))
		var col := UiKit.SUCCESS if r == "good" else UiKit.DANGER if r == "poor" else UiKit.MUTED
		left.add_child(UiKit.kv_row(str(Narrative.PILLAR_LABELS[p]), str(words.get(r, r)), col, 15))
	left.add_child(HSeparator.new())
	left.add_child(UiKit.label(str(arch.get("legacy", "")), 16, UiKit.TEXT, true))
	var f: Dictionary = ev.get("features", {})
	left.add_child(UiKit.label("%d keputusan besar diambil langsung." % int(f.get("decided", 0)), 14, UiKit.MUTED, true))
	var oc := Campaign.outcome_counts(w)
	for k in [Campaign.OUTCOME_DELEGATED, Campaign.OUTCOME_COVERED, Campaign.OUTCOME_DISPLACED, Campaign.OUTCOME_LAPSED, Campaign.OUTCOME_MISSED_CRITICAL]:
		if int(oc.get(k, 0)) > 0:
			var bad: bool = k == Campaign.OUTCOME_MISSED_CRITICAL or k == Campaign.OUTCOME_LAPSED
			left.add_child(UiKit.kv_row(str(Campaign.OUTCOME_LABELS[k]), str(oc[k]), UiKit.DANGER if bad else UiKit.MUTED, 14))
	var retro := EndingStory.retrospective(Game.session)
	left.add_child(HSeparator.new())
	left.add_child(UiKit.subheader("PALING MEMBAIK", UiKit.SUCCESS, 12))
	left.add_child(UiKit.label(EndingStory._names(retro.best), 15, UiKit.TEXT, true))
	left.add_child(UiKit.subheader("MASIH BERJUANG", UiKit.DANGER, 12))
	left.add_child(UiKit.label(EndingStory._names(retro.worst), 15, UiKit.TEXT, true))

	var mid := _card("JANJI PEMERINTAH", row)
	mid.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var promises: Dictionary = w.story.get("promises", {})
	if promises.is_empty():
		mid.add_child(UiKit.label("Tidak ada janji jangka panjang yang dibuat.", 15, UiKit.MUTED, true))
	for pid in promises:
		var pr: Dictionary = promises[pid]
		var st := str(pr.status)
		var tag := "TERPENUHI" if st == "kept" else "BELUM TERPENUHI" if st == "broken" else "MASIH BERJALAN"
		var tcol := UiKit.SUCCESS if st == "kept" else UiKit.DANGER if st == "broken" else UiKit.INFO
		var line := UiKit.hbox(8)
		line.add_child(UiKit.tag(tag, tcol, 11))
		var txt := UiKit.label(str(pr.text), 14, UiKit.TEXT, true)
		txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(txt)
		mid.add_child(line)

	var right := _card("KEPUTUSAN YANG MEMBENTUK NEGERI", row)
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var shown := 0
	for e in w.story.get("journal", []):
		if str(e.kind) != "keputusan":
			continue
		right.add_child(UiKit.title(str(e.title), 15, UiKit.ACCENT))
		right.add_child(UiKit.label(str(e.text), 14, UiKit.TEXT, true))
		shown += 1
		if shown >= 8:
			break
	var missed := Campaign.never_opened(Game.session)
	if not missed.is_empty():
		right.add_child(HSeparator.new())
		right.add_child(UiKit.label("%d kisah lain tidak sempat sampai ke meja Presiden pada masa bakti ini. Semuanya bisa dimainkan di Kumpulan Kisah." % missed.size(), 13, UiKit.MUTED, true))

	var foot := UiKit.hbox(14)
	foot.add_child(UiKit.ghost_button("BUKA BUKU KISAH", func(): open("journal")))
	foot.add_child(UiKit.spacer())
	var back := UiKit.ghost_button("KEMBALI KE PETA", close_screen)
	foot.add_child(back)
	foot.add_child(UiKit.ghost_button("KUMPULAN KISAH", func(): open("library")))
	var new_btn := UiKit.button("MULAI PEMERINTAHAN BARU", func(): _origin = "map"; open("new"), true)
	new_btn.custom_minimum_size = Vector2(260, 44)
	foot.add_child(new_btn)
	_content.add_child(foot)


func _scroll_card(title: String, parent: Node) -> VBoxContainer:
	var card := _card(title, parent)
	card.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.get_parent().size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	card.add_child(sc)
	var box := UiKit.vbox(10)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(box)
	return box


## Buku Kisah: the player's own story history. No sources, citations or provenance here.
func _journal() -> void:
	var w := Game.world
	var st := Narrative.ensure(w)
	var row := UiKit.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)
	var story := _scroll_card("PERJALANAN", row)
	story.get_parent().get_parent().get_parent().size_flags_stretch_ratio = 1.6
	var entries: Array = st.journal
	if entries.is_empty():
		story.add_child(UiKit.label("Belum ada catatan. Kisahmu dimulai dari keputusan pertama.", 15, UiKit.MUTED, true))
	for k in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[k]
		var when := "Tahun %d · Kuartal %d" % [int(e.tick) / 12 + 1, (int(e.tick) % 12) / 3 + 1]
		var tag: Array = {"keputusan": ["KEPUTUSAN", UiKit.ACCENT], "janji": ["JANJI", UiKit.INFO], "tertunda": ["TERTUNDA", UiKit.DANGER], "bab": ["BAB", UiKit.REAL]}.get(str(e.kind), ["CATATAN", UiKit.MUTED])
		var head := UiKit.hbox(8)
		head.add_child(UiKit.tag(tag[0], tag[1], 11))
		head.add_child(UiKit.subheader(when, UiKit.MUTED, 12))
		story.add_child(head)
		story.add_child(UiKit.title(str(e.title), 17))
		story.add_child(UiKit.label(str(e.text), 15, UiKit.TEXT, true))
		story.add_child(HSeparator.new())
	var side := UiKit.vbox(16)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(side)
	var prom := _scroll_card("JANJI DAN AKIBAT YANG MASIH BERJALAN", side)
	var any := false
	for pid in st.promises:
		var p: Dictionary = st.promises[pid]
		if str(p.status) != "open":
			continue
		any = true
		var months := maxi(0, int(p.due_tick) - w.tick)
		prom.add_child(UiKit.label("• %s (ditagih sekitar %d bulan lagi)" % [str(p.text), months], 14, UiKit.TEXT, true))
	var pend := {}
	for e in w.pending_effects:
		var src := str(e.get("source", ""))
		if src.begins_with("case:") and int(e.get("apply_tick", 0)) > w.tick:
			var cid := src.get_slice("/", 0).trim_prefix("case:")
			pend[cid] = mini(int(pend.get(cid, 999)), int(e.apply_tick) - w.tick)
	for cid in pend:
		any = true
		prom.add_child(UiKit.label("• Hasil keputusan \"%s\" mulai terasa sekitar %d bulan lagi." % [str(ContentDB.cases.get(cid, {}).get("title", cid)), int(pend[cid])], 14, UiKit.TEXT, true))
	if not any:
		prom.add_child(UiKit.label("Tidak ada janji atau akibat tertunda saat ini.", 14, UiKit.MUTED, true))
	var people := _scroll_card("TOKOH YANG DITEMUI", side)
	for id in st.met:
		var c: Dictionary = ContentDB.character(str(id))
		if str(c.get("name", "")) == "":
			for cid in ContentDB.cases:
				var loc: Dictionary = ContentDB.cases[cid].get("story", {}).get("locals", {})
				if loc.has(id):
					c = loc[id]
					break
		if str(c.get("name", "")) != "":
			people.add_child(UiKit.label("%s · %s" % [str(c.name), str(c.get("role", ""))], 14, UiKit.TEXT, true))
	var foot := UiKit.hbox(12)
	foot.add_child(UiKit.ghost_button("ULANGI TUTORIAL", func(): tutorial_requested.emit()))
	foot.add_child(UiKit.spacer())
	foot.add_child(UiKit.ghost_button("TUJUAN MASA BAKTI", func(): open("goals")))
	_content.add_child(foot)


func _goals() -> void:
	var p := Narrative.pillars(Game.session)
	var intro := _card("APA YANG KITA JAGA SELAMA LIMA TAHUN")
	intro.add_child(UiKit.label("Masa bakti berlangsung dua puluh kuartal. Tidak ada pemerintahan yang menyelesaikan semuanya. Di akhir masa bakti, keempat tujuan ini dinilai bersama, bersama janji yang ditepati dan persoalan yang dibiarkan.", 16, UiKit.TEXT, true))
	intro.add_child(UiKit.label("Lima tahun ini penuh bencana dan krisis, jadi angka di banyak daerah bisa turun meski pemerintah bekerja keras. Yang dinilai adalah seberapa baik dampaknya ditahan dibanding jika persoalan dibiarkan.", 15, UiKit.MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(grid)
	var notes := {
		"welfare": ["Kesejahteraan warga", "Apakah hidup orang di daerah membaik: penghasilan, pangan, rasa aman."],
		"trust": ["Kepercayaan publik", "Apakah warga merasa didengar dan percaya pemerintah hadir."],
		"services": ["Pelayanan publik", "Puskesmas, sekolah, air bersih, listrik, dan layanan yang terasa setiap hari."],
		"fiscal": ["Kesehatan fiskal", "Kemampuan negara membiayai program tanpa membebani masa depan."],
	}
	for k in Narrative.PILLARS:
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := UiKit.vbox(6)
		card.add_child(v)
		v.add_child(UiKit.title(str(notes[k][0]), 22, UiKit.ACCENT))
		v.add_child(UiKit.label(str(notes[k][1]), 15, UiKit.MUTED, true))
		var word := str(p[k].trend)
		var col := UiKit.SUCCESS if word == "membaik" else UiKit.DANGER if word == "menurun" else UiKit.MUTED
		v.add_child(UiKit.title("Sejak awal masa bakti: %s" % word, 19, col))
		var unit := " poin ruang fiskal" if k == "fiscal" else " / 100"
		v.add_child(UiKit.label("Sekarang %s%s (awal %s, perubahan %s)" % [Fmt.num(float(p[k].value), 1), unit, Fmt.num(float(p[k].start), 1), Fmt.signed(float(p[k].delta), 1)], 14, UiKit.MUTED, true))
		grid.add_child(card)


func _library() -> void:
	var intro := UiKit.label("Setiap kisah bisa dimainkan sendiri di ruang terpisah. Pilihanmu di sini tidak mengubah pemerintahan utama atau simpananmu.", 16, UiKit.MUTED, true)
	_content.add_child(intro)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	sc.add_child(grid)
	for id in ContentDB.library_cases():
		var c: Dictionary = ContentDB.cases[id]
		var card := PanelContainer.new()
		card.theme_type_variation = "PanelCard"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var hrow := UiKit.hbox(12)
		card.add_child(hrow)
		# Episode thumbnail: the scene's painted backdrop (game/assets/story/backgrounds).
		var art := StoryBackdrop.art_for(str(c.get("story", {}).get("background", "")))
		if art != null:
			var thumb := TextureRect.new()
			thumb.texture = art
			thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			thumb.custom_minimum_size = Vector2(150, 150)
			thumb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			thumb.clip_contents = true
			hrow.add_child(thumb)
		var v := UiKit.vbox(6)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hrow.add_child(v)
		var loc := UiKit.subheader(str(c.get("location_label", "")).to_upper(), UiKit.WARN, 12)
		loc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		loc.custom_minimum_size.x = 200
		v.add_child(loc)
		var t := UiKit.title(str(c.get("title", id)), 19)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		var hook := UiKit.label(str(c.get("story", {}).get("agenda", {}).get("hook", "")), 14, UiKit.TEXT, true)
		hook.custom_minimum_size.x = 200
		v.add_child(hook)
		var cid: String = id
		var play := UiKit.button("MAINKAN KISAH", func(): scenario_requested.emit(cid), true)
		play.size_flags_horizontal = Control.SIZE_SHRINK_END
		play.disabled = c.get("story", {}).is_empty()
		v.add_child(play)
		grid.add_child(card)


func _credits() -> void:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(sc)
	var v := UiKit.vbox(16)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	for sec in ContentDB.story.get("credits", {}).get("sections", []):
		var card := _card(str(sec.title).to_upper(), v)
		for line in sec.lines:
			card.add_child(UiKit.label(str(line), 16, UiKit.TEXT, true))


func _scenario_end() -> void:
	var w := Game.world
	var cid := Game.scenario_case
	var c: Dictionary = ContentDB.cases.get(cid, {})
	var card := _card(str(c.get("title", "")).to_upper())
	var choice := str(w.case_state.get(cid, {}).get("choice_id", ""))
	card.add_child(UiKit.label(str(c.get("story", {}).get("journal", {}).get(choice, "")), 18, UiKit.TEXT, true))
	var p := Narrative.pillars(Game.session)
	for k in Narrative.PILLARS:
		card.add_child(UiKit.kv_row(str(Narrative.PILLAR_LABELS[k]), "%s (%s)" % [str(p[k].trend), Fmt.signed(float(p[k].delta), 1)], UiKit.TEXT, 15))
	card.add_child(UiKit.label("Setahun setelah keputusanmu. Coba pilihan lain untuk melihat bagaimana kisahnya berubah.", 15, UiKit.MUTED, true))
	var row := UiKit.hbox(12)
	row.add_child(UiKit.button("MAINKAN ULANG", func(): Game.end_scenario(); scenario_requested.emit(cid), true))
	row.add_child(UiKit.ghost_button("KEMBALI KE KUMPULAN KISAH", func(): Game.end_scenario(); open("library")))
	card.add_child(row)


func _focus_first() -> void:
	UiKit.trap_focus(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_back()
