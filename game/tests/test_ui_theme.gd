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
