extends RefCounted
## Stitch design tokens -> Godot theme: tokens load, theme builds, UiKit constants stay in sync.

var t


func test_stitch_theme() -> void:
	var tk := StitchTheme.tokens()
	t.check(tk.has("colors") and tk.has("shape"), "stitch tokens load")
	var th := StitchTheme.build()
	t.check(th.has_stylebox("normal", "ButtonPrimary"), "theme has primary button variation")
	t.check(th.has_stylebox("panel", "PanelCard"), "theme has card variation")
	t.check(UiKit.PANEL.is_equal_approx(StitchTheme.color("panel")), "UiKit.PANEL matches token")
	t.check(UiKit.TEXT.is_equal_approx(StitchTheme.color("text")), "UiKit.TEXT matches token")
	t.check(UiKit.ACCENT.is_equal_approx(StitchTheme.color("title_gold")), "UiKit.ACCENT matches token")
