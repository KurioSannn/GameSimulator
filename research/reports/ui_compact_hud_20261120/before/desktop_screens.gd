class_name DesktopScreens
extends Control
## Native Godot implementation of the menu, profile, statistics, quarterly report,
## legacy summary, saves, help, and settings screens. Designed cleanly for 1280x720 and 1920x1080.

signal started
signal closed
signal region_selected(id: String)
signal preferences_changed

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
		margin.add_theme_constant_override("margin_" + side, 28)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_surface.add_child(margin)

	_content = UiKit.vbox(14)
	margin.add_child(_content)

	var names := {
		"profile": "PROFIL PRESIDEN",
		"statistics": "STATISTIK PEMERINTAHAN",
		"report": "LAPORAN PEMERINTAHAN",
		"legacy": "RAPOR WARISAN",
		"settings": "PENGATURAN",
		"help": "CARA BERMAIN",
		"saves": "LANJUTKAN PEMERINTAHAN",
		"new": "MULAI MANDAT BARU",
	}

	var header := UiKit.hbox(14)
	var back := UiKit.ghost_button("", _back, "Kembali (Esc)")
	back.icon = FigmaAssets.texture(2 if screen == "profile" else 3 if screen == "statistics" else 4, "imgIkonBack")
	back.custom_minimum_size = Vector2(56, 46)
	back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(back)

	header.add_child(UiKit.title(str(names.get(screen, screen)), 32, UiKit.ACCENT))
	header.add_child(UiKit.spacer())

	if screen in ["profile", "statistics", "report", "legacy"]:
		var tabs := [["PROFIL", "profile"], ["STATISTIK", "statistics"], ["LAPORAN", "report"]]
		if Game.world != null and Game.world.is_term_over():
			tabs.append(["WARISAN", "legacy"])
		for spec in tabs:
			var dest: String = spec[1]
			var button := UiKit.button(spec[0], func(): open(dest))
			button.theme_type_variation = "ButtonAccent" if screen == dest else "ButtonGhost"
			button.custom_minimum_size = Vector2(148, 42)
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
		"help": _help()
		"saves": _saves()
		"new": _new_confirmation()

	UiKit.animate_open(_content)
	_focus_first.call_deferred()


func close_screen() -> void:
	hide()
	active_screen = ""
	closed.emit()


func _back() -> void:
	if active_screen in ["settings", "help", "saves", "new", "legacy"]:
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

	# Top-left Brand Lockup
	var brand := UiKit.vbox(8)
	brand.position = Vector2(48, 36)
	brand.add_child(UiKit.title("NUSANTARA", 64, Color("ffe9a7")))
	var ribbon := PanelContainer.new()
	ribbon.add_theme_stylebox_override("panel", StitchTheme.soft_box(Color("ed4b39"), StitchTheme.color("outline"), 8, 14, 6, 2))
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var subtitle := UiKit.title("MANDAT KEPEMIMPINAN", 22, Color("fff4d2"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ribbon.add_child(subtitle)
	brand.add_child(ribbon)
	brand.add_child(UiKit.title("Bangun negeri. Tentukan warisanmu.", 18, Color("fff4d2")))
	_surface.add_child(brand)

	# Top-right utility pills (clean inline row)
	var top_right := UiKit.hbox(10)
	top_right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	top_right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	top_right.offset_top = 28
	top_right.offset_right = -32
	_surface.add_child(top_right)

	var settings := UiKit.ghost_button("PENGATURAN", func(): _origin = "menu"; open("settings"), "Buka pengaturan audio, layar, dan kontrol")
	settings.icon = FigmaAssets.texture(0, "imgGroup465")
	settings.custom_minimum_size = Vector2(154, 44)
	top_right.add_child(settings)

	# Right action card
	var panel := PanelContainer.new()
	panel.theme_type_variation = "PanelDock"
	panel.anchor_left = 0.60
	panel.anchor_right = 0.955
	panel.anchor_top = 0.52
	panel.anchor_bottom = 0.52
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := GameSkin.frame()
	panel.add_theme_stylebox_override("panel", style)
	_surface.add_child(panel)

	var body := UiKit.vbox(14)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(body)
	var heading := UiKit.heading("PEMERINTAHANMU")
	body.add_child(heading)

	var begin := UiKit.button("MULAI MANDAT BARU", func():
		_origin = "menu"
		if session_started:
			open("new")
		else:
			_start_new(), true)
	begin.custom_minimum_size.y = 62
	begin.add_theme_font_size_override("font_size", 21)
	body.add_child(begin)

	if session_started:
		var cont := UiKit.button("KEMBALI KE PEMERINTAHAN", close_screen)
		cont.custom_minimum_size.y = 48
		body.add_child(cont)
	elif not Game.saves.list_slots().is_empty():
		var load_btn := UiKit.button("LANJUTKAN SIMPANAN", func(): _origin = "menu"; open("saves"))
		load_btn.custom_minimum_size.y = 48
		body.add_child(load_btn)

	var help_btn := UiKit.button("CARA BERMAIN", func(): _origin = "menu"; open("help"))
	help_btn.custom_minimum_size.y = 46
	body.add_child(help_btn)

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
		info.add_child(UiKit.label("Tahun %s · Kuartal %s · Diperbarui %s" % [meta.get("year", "—"), meta.get("quarter", "—"), meta.get("updated_at", "")], 13, UiKit.MUTED))
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
	var row := UiKit.hbox(20)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var left := UiKit.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.2
	row.add_child(left)

	var mandate := _card("PERJALANAN MANDAT", left)
	mandate.add_child(UiKit.title("TAHUN %d DARI 5 TAHUN" % mini(Game.world.year_index() + 1, 5), 28, UiKit.ACCENT))
	mandate.add_child(UiKit.label("Kuartal %d · %d kasus aktif" % [Game.world.quarter_index() % 4 + 1, Game.cases.active_cases(Game.world).size()], 22, UiKit.MUTED))
	var years := UiKit.hbox(10)
	var cur_y := mini(Game.world.year_index(), 4)
	for y in 5:
		var badge := PanelContainer.new()
		var active := y == cur_y
		badge.add_theme_stylebox_override("panel", StitchTheme.soft_box(
			Color(UiKit.ACCENT, 0.22) if active else Color(1, 1, 1, 0.05),
			UiKit.ACCENT if active else Color(1, 1, 1, 0.12), 99, 0, 6, 1))
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var yt := UiKit.title("Thn " + str(y + 1), 15, UiKit.ACCENT if active else UiKit.MUTED)
		yt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(yt)
		years.add_child(badge)
	mandate.add_child(years)
	var bar := ProgressBar.new()
	bar.max_value = 60
	bar.value = Game.world.tick
	bar.show_percentage = false
	bar.custom_minimum_size.y = 12
	mandate.add_child(bar)

	mandate.add_child(UiKit.kv_row("Kepercayaan rakyat", "%s%%" % Fmt.num(Game.world.national_mean("trust"), 1), UiKit.SUCCESS, 22))

	var badges := _card("LENCANA PENCAPAIAN", left)
	var badges_row := UiKit.hbox(12)
	var decisions := 0
	for state in Game.world.case_state.values():
		decisions += state.get("history", []).size()
	for spec in [
		["Mandat pertama", "imgMedaliMandatPertama", true, "imgTepiMedaliMandatPertama", "imgIkonStar"],
		["Kenali Nusantara", "imgMedaliKenaliNusantara", visited.size() >= 3, "imgTepiMedaliKenaliNusantara", "imgIkonCompass"],
		["Solusi pertama", "imgMedaliSolusiPertama", decisions > 0, "imgTepiMedaliSolusiPertama", "imgIkonLock"],
	]:
		var tile := PanelContainer.new()
		tile.add_theme_stylebox_override("panel", StitchTheme.soft_box(UiKit.PANEL_SOFT, Color(1, 1, 1, 0.10), 8, 8, 8, 1))
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var badge := UiKit.vbox(4)
		badge.alignment = BoxContainer.ALIGNMENT_CENTER
		tile.add_child(badge)
		var symbol: String = "imgIkonStar" if spec[4] == "imgIkonLock" and bool(spec[2]) else str(spec[4])
		var art := FigmaAssets.badge(spec[1], spec[3], symbol)
		art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		art.modulate.a = 1.0 if spec[2] else 0.35
		badge.add_child(art)
		var bl := UiKit.label(spec[0], 13, UiKit.TEXT, true)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		var bs := UiKit.label("TERBUKA" if spec[2] else "TERKUNCI", 11, UiKit.SUCCESS if spec[2] else UiKit.MUTED)
		bs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(bs)
		badges_row.add_child(tile)
	badges.add_child(badges_row)

	# Character and contact shadow resize together from one feet anchor.
	var stage := UiKit.vbox(12)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.alignment = BoxContainer.ALIGNMENT_CENTER
	stage.add_child(PresidentPortrait.new())
	var nameplate := PanelContainer.new()
	nameplate.add_theme_stylebox_override("panel", GameSkin.frame("panel_brown", 18, 12))
	var identity := UiKit.vbox(4)
	var character_name := UiKit.title("NARA ADINATA", 28, UiKit.ACCENT)
	character_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_child(character_name)
	var role := UiKit.label("Presiden Republik Indonesia", 22, UiKit.MUTED, true)
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.add_child(role)
	nameplate.add_child(identity)
	stage.add_child(nameplate)
	row.add_child(stage)

	# Right player profile card
	var right := UiKit.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.9
	row.add_child(right)
	var profile := _card("IDENTITAS PEMAIN", right)
	profile.add_child(PlayerNameEditor.new())



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
	report.add_child(UiKit.title("NARA ADINATA", 20, UiKit.ACCENT))
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
	var lhead := PanelContainer.new()
	lhead.theme_type_variation = "PanelHeader"
	var lh := UiKit.hbox(12)
	var lt := UiKit.vbox(2)
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.add_child(UiKit.subheader("RAPOR AKHIR MASA JABATAN", Color("fff4d2"), 11))
	lt.add_child(UiKit.title("PEMERINTAHAN PRESIDEN NARA ADINATA", 20, Color("fff4d2")))
	lh.add_child(lt)
	lhead.add_child(lh)
	_content.add_child(lhead)
	_indicator_row(_content, false)

	var row := UiKit.hbox(16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(row)

	var left := _card("RINGKASAN PEMERINTAHAN", row)
	left.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var decisions := 0
	for state in Game.world.case_state.values():
		decisions += state.get("history", []).size()
	var w := Game.world
	var trust := w.national_mean("trust")
	var welfare := w.national_mean("welfare")
	var env := w.national_mean("environment")
	var grade := "MANDAT KOKOH" if trust >= 60.0 and welfare >= 75.0 else ("MANDAT STABIL" if trust >= 48.0 and welfare >= 65.0 else "MANDAT PENUH UJIAN")
	left.add_child(UiKit.subheader("PREDIKAT AKHIR", UiKit.INFO, 11))
	left.add_child(UiKit.title(grade, 26, UiKit.ACCENT))
	for pair in [
		["Status Masa Jabatan", Fmt.period(w)],
		["Keputusan Kasus", "%d keputusan" % decisions],
		["Kebijakan Dijalankan", "%d program" % w.policy_state.size()],
		["Wilayah Ditinjau", "%d dari %d kab/kota" % [visited.size(), w.region_count()]],
		["Kesejahteraan Akhir", "%s / 100" % Fmt.num(welfare, 1)],
		["Lingkungan Akhir", "%s / 100" % Fmt.num(env, 1)],
	]:
		left.add_child(UiKit.kv_row(pair[0], pair[1], UiKit.TEXT, 14))

	var right := _card("CATATAN PENUTUP", row)
	right.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var adv := UiKit.hbox(14)
	var portrait := FigmaAssets.avatar(2, Vector2(84, 84))
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	adv.add_child(portrait)
	var qbox := PanelContainer.new()
	qbox.add_theme_stylebox_override("panel", StitchTheme.soft_box(UiKit.PANEL_SOFT, Color(1, 1, 1, 0.10), 8, 14, 12, 1))
	qbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var quote := UiKit.label(
		"“Kepemimpinan berarti memilih pengorbanan mana yang paling sanggup dipikul bersama oleh seluruh wilayah Nusantara.”",
		15, UiKit.TEXT, true)
	qbox.add_child(quote)
	adv.add_child(qbox)
	right.add_child(adv)
	right.add_child(HSeparator.new())
	right.add_child(UiKit.subheader("REKAM JEJAK SINGKAT", UiKit.ACCENT, 11))
	var summary_line := "Kepercayaan publik berakhir di angka %s%% dengan tingkat kesejahteraan rata-rata %s/100." % [Fmt.num(trust, 1), Fmt.num(welfare, 1)]
	right.add_child(UiKit.label(summary_line, 14, UiKit.TEXT, true))
	right.add_child(UiKit.spacer())
	right.add_child(UiKit.label("Gunakan 'Mulai Mandat Baru' untuk mencoba strategi dan prioritas wilayah yang berbeda.", 13, UiKit.MUTED, true))

	var foot := UiKit.hbox(14)
	var stat := UiKit.ghost_button("TINJAU STATISTIK", func(): open("statistics"))
	stat.custom_minimum_size.y = 44
	foot.add_child(stat)
	foot.add_child(UiKit.spacer())
	var back := UiKit.ghost_button("KEMBALI KE PETA", close_screen)
	back.custom_minimum_size.y = 44
	foot.add_child(back)
	var new_btn := UiKit.button("MULAI MANDAT BARU", func(): _origin = "map"; open("new"), true)
	new_btn.custom_minimum_size = Vector2(230, 44)
	foot.add_child(new_btn)
	_content.add_child(foot)


func _focus_first() -> void:
	UiKit.trap_focus(self)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed:
		return
	get_viewport().set_input_as_handled()
	if event.keycode == KEY_ESCAPE:
		_back()
