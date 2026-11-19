class_name Hud
extends Control
## Desktop command HUD: one national strip, one agenda, opt-in map tools.
signal next_pressed
signal policy_pressed
signal budget_pressed
signal log_pressed
signal decision_pressed
signal legacy_pressed
signal menu_selected(id: String)
signal overlay_selected(def: Dictionary)
signal change_toggled(on: bool)
signal zoom_pressed(factor: float)
signal home_pressed
signal mode_3d_pressed
signal context_requested(kind: String, id: String)
signal time_mode_selected(mode: String)
signal weather_mode_selected(mode: String)

const PINNED_INDICATORS := ["welfare", "trust", "fiscal_space"]
var indicators: HBoxContainer
var next_btn: Button
var legend: Label
var lod_label: Label
var weighting_label: Label
var season_label: Label
var change_btn: CheckButton
var mode_btn: Button
var layer_select: OptionButton
var time_select: OptionButton
var weather_select: OptionButton
var right_col: VBoxContainer
var map_controls: VBoxContainer
var map_tools_card: PanelContainer
var atmosphere_controls: VBoxContainer
var _period: Label
var _term: Label
var _agenda_title: Label
var _agenda_sub: Label
var _agenda_btn: Button
var _term_over := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top()
	_build_sidebar()
	_build_right()
	_build_bottom()

func _build_top() -> void:
	var dock := Control.new()
	dock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dock.set_anchors_preset(Control.PRESET_TOP_WIDE)
	dock.offset_left = 14
	dock.offset_right = -14
	dock.offset_top = 12
	dock.offset_bottom = 82
	add_child(dock)
	var row := UiKit.hbox(18)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock.add_child(row)
	var identity := PanelContainer.new()
	identity.add_theme_stylebox_override("panel", GameSkin.frame("panel_brown_corners_a", 12, 24))
	row.add_child(identity)
	var profile := UiKit.ghost_button("", func(): menu_selected.emit("profile"), "Profil Presiden · perjalanan mandat")
	profile.custom_minimum_size = Vector2(242, 62)
	profile.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	var portrait_row := UiKit.hbox(10)
	portrait_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	profile.add_child(portrait_row)
	portrait_row.add_child(FigmaAssets.portrait(1, Vector2(44, 44)))
	var names := UiKit.vbox(2)
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_child(UiKit.title("NARA ADINATA", 19))
	_period = UiKit.label("", 14, UiKit.MUTED)
	_term = _period
	names.add_child(_period)
	portrait_row.add_child(names)
	UiKit.ignore_mouse(portrait_row)
	identity.add_child(profile)
	row.add_child(UiKit.spacer())
	var resources := PanelContainer.new()
	resources.theme_type_variation = "PanelDock"
	resources.custom_minimum_size.x = 460
	row.add_child(resources)
	indicators = UiKit.hbox(20)
	indicators.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resources.add_child(indicators)
	var menu := MenuButton.new()
	menu.text = "☰"
	menu.flat = false
	menu.tooltip_text = "Menu pemerintahan"
	menu.add_theme_stylebox_override("normal", GameSkin.frame("round_brown", 0, 0))
	menu.add_theme_stylebox_override("hover", GameSkin.frame("round_brown", 0, 0, Color("ffe7ac")))
	menu.custom_minimum_size = Vector2(66, 66)
	menu.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	menu.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var popup := menu.get_popup()
	for item in [["Profil Presiden", "profile"], ["Semua indikator nasional", "statistics"],
		["Laporan Kuartal", "report"], ["Rapor Warisan", "legacy"],
		["Catatan Peristiwa (L)", "log"], ["Daftar Simpanan", "saves"],
		["Simpan Cepat (F5)", "save_quick"], ["Muat Cepat (F9)", "load_quick"],
		["Simpan Slot Baru (Ctrl+S)", "save_new"], ["Pengaturan", "settings"], ["Menu Utama", "menu"]]:
		popup.add_item(item[0])
		popup.set_item_metadata(popup.item_count - 1, item[1])
	popup.id_pressed.connect(func(id: int): menu_selected.emit(str(popup.get_item_metadata(popup.get_item_index(id)))))
	row.add_child(menu)

func _build_sidebar() -> void:
	var column := UiKit.vbox(12)
	column.position = Vector2(22, 116)
	for item in [["Kebijakan", "imgIkonScroll", "policy", "Kebijakan (P)"],
		["Anggaran", "imgIkonCoin1", "budget", "Anggaran nasional (B)"],
		["Statistik", "imgIkonBook", "statistics", "Semua indikator nasional"]]:
		var action: String = item[2]
		var on_press := func():
			match action:
				"policy": policy_pressed.emit()
				"budget": budget_pressed.emit()
				_: menu_selected.emit(action)
		var button := UiKit.ghost_button("", on_press, item[3])
		button.theme_type_variation = "ButtonHex"
		button.icon = FigmaAssets.texture(1, item[1])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 30)
		button.custom_minimum_size = Vector2(66, 82)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(button)
	add_child(column)

func _build_right() -> void:
	right_col = UiKit.vbox(8)
	right_col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right_col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right_col.offset_right = -14
	right_col.offset_left = -370
	right_col.offset_top = 112
	right_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_col)
	var toggle_tools := func(): map_tools_card.visible = not map_tools_card.visible
	var tools := UiKit.ghost_button("PETA  ▾", toggle_tools, "Lapisan data, wilayah, zoom, dan suasana peta")
	tools.theme_type_variation = "Button"
	tools.size_flags_horizontal = Control.SIZE_SHRINK_END
	tools.icon = GameSkin.texture("minimap_compass_toon_n")
	tools.expand_icon = true
	tools.add_theme_constant_override("icon_max_width", 24)
	tools.custom_minimum_size.x = 142
	tools.custom_minimum_size.y = 46
	right_col.add_child(tools)
	var panel := PanelContainer.new()
	map_tools_card = panel
	panel.theme_type_variation = "PanelDock"
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	map_controls = UiKit.vbox(10)
	map_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(map_controls)
	map_controls.minimum_size_changed.connect(_fit_tools)
	right_col.add_child(panel)
	layer_select = OptionButton.new()
	layer_select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for definition in Overlays.DEFS:
		layer_select.add_item(definition.label)
	layer_select.item_selected.connect(func(i: int): overlay_selected.emit(Overlays.DEFS[i]))
	map_controls.add_child(layer_select)
	var scope := MenuButton.new()
	scope.text = "Jelajahi wilayah  ▾"
	scope.flat = false
	scope.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var popup := scope.get_popup()
	popup.add_item("Indonesia")
	popup.set_item_metadata(0, {"kind": "national", "id": "ID"})
	popup.add_separator("PROVINSI")
	for province in ContentDB.provinces:
		popup.add_item(str(province.name))
		popup.set_item_metadata(popup.item_count - 1, {"kind": "province", "id": str(province.region_id)})
	popup.add_separator("KAWASAN PULAU")
	for id in RegionViewModel.ISLANDS:
		popup.add_item(RegionViewModel.ISLANDS[id])
		popup.set_item_metadata(popup.item_count - 1, {"kind": "island_group", "id": id})
	popup.id_pressed.connect(func(id: int):
		var context: Dictionary = popup.get_item_metadata(popup.get_item_index(id))
		context_requested.emit(context.kind, context.id))
	map_controls.add_child(scope)
	change_btn = CheckButton.new()
	change_btn.text = "Perubahan kuartal (C)"
	change_btn.tooltip_text = "Warna menunjukkan kenaikan/penurunan selama kuartal terakhir."
	change_btn.toggled.connect(func(on: bool): change_toggled.emit(on))
	map_controls.add_child(change_btn)
	legend = UiKit.label("", 14, UiKit.MUTED, true)
	map_controls.add_child(legend)
	var navigation := UiKit.hbox(6)
	for item in [["+", 1.3, "Perbesar peta"], ["−", 1.0 / 1.3, "Perkecil peta"]]:
		var zoom := UiKit.ghost_button(item[0], func(): zoom_pressed.emit(float(item[1])), item[2])
		zoom.custom_minimum_size = Vector2(38, 38)
		navigation.add_child(zoom)
	var home := UiKit.ghost_button("Indonesia", func(): home_pressed.emit(), "Seluruh Indonesia (Home)")
	home.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation.add_child(home)
	mode_btn = UiKit.ghost_button("3D (T)", func(): mode_3d_pressed.emit(), "Ganti 2D / 3D (T)")
	navigation.add_child(mode_btn)
	map_controls.add_child(navigation)
	atmosphere_controls = UiKit.vbox(8)
	var toggle_adv := func(): atmosphere_controls.visible = not atmosphere_controls.visible
	var advanced := UiKit.ghost_button("Suasana & informasi peta  ▾", toggle_adv)
	map_controls.add_child(advanced)
	map_controls.add_child(atmosphere_controls)
	season_label = UiKit.label("", 14, UiKit.INFO, true)
	atmosphere_controls.add_child(season_label)
	var atmosphere := UiKit.hbox(8)
	time_select = _preview_select([["Otomatis", "auto"], ["Pagi", "pagi"], ["Siang", "siang"], ["Sore", "sore"], ["Malam", "malam"]])
	time_select.tooltip_text = "Pencahayaan peta · hanya tampilan"
	time_select.item_selected.connect(func(i: int): time_mode_selected.emit(str(time_select.get_item_metadata(i))))
	atmosphere.add_child(time_select)
	weather_select = _preview_select([["Kalender", "sim"], ["Hujan", "hujan"], ["Kemarau", "kemarau"], ["Kebakaran", "kebakaran"], ["Macet & Bencana", "bencana"]])
	weather_select.tooltip_text = "Cuaca peta"
	weather_select.item_selected.connect(func(i: int): weather_mode_selected.emit(str(weather_select.get_item_metadata(i))))
	atmosphere.add_child(weather_select)
	atmosphere_controls.add_child(atmosphere)
	lod_label = UiKit.label("", 14, UiKit.MUTED, true)
	atmosphere_controls.add_child(lod_label)
	weighting_label = UiKit.label("", 14, UiKit.MUTED, true)
	atmosphere_controls.add_child(weighting_label)
	atmosphere_controls.hide()
	map_tools_card.hide()
	map_tools_card.visibility_changed.connect(_fit_tools)

func _fit_tools() -> void:
	if map_tools_card == null or not map_tools_card.visible:
		return
	var height := map_controls.get_combined_minimum_size().y + map_tools_card.get_theme_stylebox("panel").get_minimum_size().y
	map_tools_card.custom_minimum_size = Vector2(356, minf(height, get_viewport_rect().size.y - 280))

func _preview_select(items: Array) -> OptionButton:
	var select := OptionButton.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for item in items:
		select.add_item(item[0])
		select.set_item_metadata(select.item_count - 1, item[1])
	return select

func add_map_note(note: Control) -> void:
	atmosphere_controls.add_child(note)

func _build_bottom() -> void:
	var dock := PanelContainer.new()
	dock.theme_type_variation = "PanelDock"
	dock.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	dock.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dock.offset_left = 112
	dock.offset_right = -14
	dock.offset_top = -100
	dock.offset_bottom = -12
	add_child(dock)
	var row := UiKit.hbox(18)
	dock.add_child(row)
	var log := UiKit.ghost_button("", func(): log_pressed.emit(), "Catatan peristiwa (L)")
	log.theme_type_variation = "ButtonMedallion"
	log.icon = GameSkin.texture("minimap_icon_exclamation_red")
	log.expand_icon = true
	log.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	log.add_theme_constant_override("icon_max_width", 14)
	log.custom_minimum_size = Vector2(46, 46)
	log.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(log)
	var text := UiKit.vbox(4)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_agenda_title = UiKit.title("", 20)
	_agenda_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(_agenda_title)
	_agenda_sub = UiKit.label("", 14, UiKit.MUTED)
	_agenda_sub.clip_text = true
	text.add_child(_agenda_sub)
	row.add_child(text)
	var on_agenda := func():
		if _term_over:
			legacy_pressed.emit()
		else:
			decision_pressed.emit()
	_agenda_btn = UiKit.button("BUKA KEPUTUSAN", on_agenda, true)
	_agenda_btn.custom_minimum_size = Vector2(206, 48)
	_agenda_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_agenda_btn)
	next_btn = UiKit.button("LANJUTKAN KUARTAL", func(): next_pressed.emit(), true)
	next_btn.custom_minimum_size = Vector2(226, 48)
	next_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_btn.tooltip_text = "Jalankan 3 bulan untuk seluruh wilayah (Spasi)"
	row.add_child(next_btn)

func refresh(world: SimWorld, pending_case: String) -> void:
	_term_over = world.is_term_over()
	_period.text = "Tahun %d · K%d/20" % [mini(world.year_index() + 1, 5), mini(world.quarter_index() + 1, 20)]
	_period.tooltip_text = Fmt.period(world)
	var month := world.month()
	var season := "Musim hujan" if month in [11, 12, 1, 2, 3] else ("Musim kemarau" if month in [6, 7, 8, 9] else "Pancaroba")
	var fire := false
	for id in ["CASE-0004", "CASE-0004-C", "CASE-0004-R"]:
		if world.case_state.get(id, {}).get("status", "") == CaseEngine.STATUS_ACTIVE:
			fire = true
	season_label.text = "%s · %s" % [season, "Kebakaran aktif" if fire else "Bulan %d" % month]
	var pending := pending_case != ""
	_agenda_btn.visible = pending or _term_over
	next_btn.visible = not pending and not _term_over
	if pending:
		var current: Dictionary = ContentDB.cases[pending_case]
		_agenda_title.text = str(current.title)
		_agenda_sub.text = str(current.get("location_label", ""))
		_agenda_btn.text = "BUKA KEPUTUSAN"
	elif _term_over:
		_agenda_title.text = "Masa jabatan selesai"
		_agenda_sub.text = "Tinjau warisan pemerintahan Nara Adinata."
		_agenda_btn.text = "RAPOR WARISAN"
	else:
		_agenda_title.text = "Siap melanjutkan kuartal"
		var latest := "Atur kebijakan dan anggaran, lalu tinjau perkembangan negeri."
		if not world.event_log.is_empty():
			var event := ChangeText.entry_card(world.event_log[-1])
			latest = "%s · %s" % [str(event.when), str(event.title)]
		_agenda_sub.text = latest
	_agenda_sub.tooltip_text = _agenda_sub.text
