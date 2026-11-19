extends RefCounted
## Stitch design tokens -> Godot theme: tokens load, theme variations build, UiKit helpers stay valid.

var t


func test_stitch_theme() -> void:
	var tk := StitchTheme.tokens()
	t.check(tk.has("colors") and tk.has("shape"), "stitch tokens load")
	var th := StitchTheme.build()
	for variation in ["ButtonPrimary", "ButtonAccent", "ButtonGhost", "ButtonChoice"]:
		t.check(th.has_stylebox("normal", variation), "theme has button variation: " + variation)
	for panel_var in ["PanelCard", "PanelDock", "PanelHeader", "PanelElevated"]:
		t.check(th.has_stylebox("panel", panel_var), "theme has panel variation: " + panel_var)
	t.check(UiKit.PANEL.is_equal_approx(StitchTheme.color("panel")), "UiKit.PANEL matches token")
	t.check(UiKit.TEXT.is_equal_approx(StitchTheme.color("text")), "UiKit.TEXT matches token")
	t.check(UiKit.ACCENT.is_equal_approx(StitchTheme.color("title_gold")), "UiKit.ACCENT matches token")


func test_ui_kit_helpers_instantiate_cleanly() -> void:
	var hdr := UiKit.modal_header("KATEGORI", "JUDUL", func(): pass, "URGENT", UiKit.WARN)
	t.check(hdr.get_child_count() == 3, "modal header builds bar, badge, and close button")
	hdr.free()
	var kv := UiKit.kv_row("Kunci", "Nilai")
	t.check(kv.get_child_count() == 2, "kv_row builds two columns")
	kv.free()
	var sec := UiKit.section_bar("BAGIAN", "Sub")
	t.check(sec.get_child_count() == 2, "section_bar builds header and separator")
	sec.free()


func test_game_type_roles_and_desktop_readability() -> void:
	var heading := UiKit.title("NUSANTARA", 28)
	var small_heading := UiKit.title("Keputusan", 19)
	var number := UiKit.number("73,8", 24)
	var body := UiKit.label("Laporan wilayah", 16)
	body.theme = StitchTheme.build()
	t.check(heading.get_theme_font("font").get_font_name() == "Bree Serif", "major headings use the display family")
	t.check(small_heading.get_theme_font("font").get_font_name() == "Alegreya Sans", "small headings use the strong body family")
	t.check(body.get_theme_font("font").get_font_name().begins_with("Alegreya Sans"), "body text uses the bundled body family")
	t.check(number.get_theme_font("font").get_font_name().begins_with("Alegreya Sans"), "numbers share the main family with a stronger weight")
	t.check(float(body.get_theme_font_size("font_size")) * 1280.0 / 1440.0 >= 19.5, "body stays at least 19.5 output pixels at 1280x720")
	for control in [heading, small_heading, number, body]:
		control.free()


func test_frame_safe_area_and_avatar_geometry() -> void:
	var frame := GameSkin.frame()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		t.check(frame.get_content_margin(side) >= frame.get_texture_margin(side) + 8, "outer frame keeps controls clear of decorative edge")
	var header: StyleBoxTexture = StitchTheme.build().get_stylebox("panel", "PanelHeader")
	t.check(header.get_content_margin(SIDE_RIGHT) >= header.get_texture_margin(SIDE_RIGHT) + 8, "banner close control clears the hanging edge")
	var avatar := FigmaAssets.avatar(2, Vector2(64, 64))
	var picture: TextureRect = avatar.get_child(0)
	t.check(is_equal_approx(picture.texture.get_size().aspect(), 1.0), "square avatar crop preserves the face aspect")
	t.check(picture.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "portrait never stretches to fill")
	avatar.free()
	var stage := PresidentPortrait.new()
	for extent in [Vector2(260, 440), Vector2(420, 660)]:
		stage.size = extent
		stage._layout_art()
		t.check(Rect2(Vector2.ZERO, extent).encloses(stage.art_rect), "profile figure stays inside its stage")
		t.check(is_equal_approx(stage.art_rect.end.y, stage.contact_y) and stage.shadow_rect.has_point(Vector2(stage.shadow_rect.get_center().x, stage.contact_y)), "figure feet remain in contact with shadow at each size")
	stage.free()


func test_compact_hud_type_keeps_dialog_readability() -> void:
	var previous := float(UiPreferences.values.text_scale)
	UiPreferences.values.text_scale = 1.0
	var hud_label := UiKit.label("Kuartal 4", 18)
	UiKit.hud_type(hud_label, 18)
	var body := UiKit.label("Laporan wilayah", 16)
	UiPreferences.values.text_scale = 1.1
	UiKit.rescale(hud_label)
	UiKit.rescale(body)
	t.check(hud_label.get_theme_font_size("font_size") == 20, "compact HUD text respects 110 percent preference")
	t.check(body.get_theme_font_size("font_size") >= 24, "dialog body retains its larger readability floor")
	var frame := GameSkin.hud_frame()
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		t.check(frame.get_content_margin(side) >= frame.get_texture_margin(side) + 2, "compact chrome retains a safe inset")
	UiPreferences.values.text_scale = previous
	hud_label.free()
	body.free()
