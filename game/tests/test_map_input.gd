extends RefCounted
## MapNavInput: every pointing device must navigate the map without click-and-hold.

var t
var pans: Array = []
var zooms: Array = []


func _reset() -> void:
	pans.clear()
	zooms.clear()


func _feed(nav: MapNavInput, ev: InputEvent, mode: int = MapNavInput.ScrollMode.AUTO) -> bool:
	return nav.handle(ev, func(d): pans.append(d), func(f, at): zooms.append([f, at]), Vector2(400, 300), mode)


func _wheel(button: MouseButton, factor: float = 1.0, shift := false, ctrl := false) -> InputEventMouseButton:
	var mb := InputEventMouseButton.new()
	mb.button_index = button
	mb.pressed = true
	mb.factor = factor
	mb.shift_pressed = shift
	mb.ctrl_pressed = ctrl
	mb.position = Vector2(100, 120)
	return mb


func test_trackpad_two_finger_swipe_pans_without_click() -> void:
	_reset()
	var nav := MapNavInput.new()
	var pg := InputEventPanGesture.new()
	pg.delta = Vector2(0.5, -1.0)
	t.check(_feed(nav, pg), "pan gesture must be consumed")
	t.check(pans.size() == 1 and zooms.is_empty(), "two-finger swipe should pan, not zoom")
	t.check((pans[0] as Vector2).is_equal_approx(Vector2(0.5, -1.0) * MapNavInput.PAN_GESTURE_PX), "pan follows gesture delta")


func test_trackpad_pinch_and_ctrl_scroll_zoom() -> void:
	_reset()
	var nav := MapNavInput.new()
	var mg := InputEventMagnifyGesture.new()
	mg.factor = 1.2
	mg.position = Vector2(50, 60)
	t.check(_feed(nav, mg), "pinch consumed")
	t.check(zooms.size() == 1 and is_equal_approx(zooms[0][0], 1.2) and zooms[0][1] == Vector2(50, 60), "pinch zooms at fingers")
	var pg := InputEventPanGesture.new()
	pg.delta = Vector2(0, -2.0)
	pg.ctrl_pressed = true
	_feed(nav, pg)
	t.check(zooms.size() == 2 and zooms[1][0] > 1.0 and pans.is_empty(), "Ctrl + swipe up zooms in")


func test_mouse_wheel_zooms_and_respects_fractional_factor() -> void:
	_reset()
	var nav := MapNavInput.new()
	_feed(nav, _wheel(MOUSE_BUTTON_WHEEL_UP))
	_feed(nav, _wheel(MOUSE_BUTTON_WHEEL_DOWN, 0.25))
	t.check(zooms.size() == 2 and pans.is_empty(), "wheel zooms by default")
	t.near(zooms[0][0], MapNavInput.ZOOM_STEP, 1e-5, "wheel up = one zoom step in")
	t.near(zooms[1][0], pow(MapNavInput.ZOOM_STEP, -0.25), 1e-5, "fractional notch = fractional zoom out")
	t.check(zooms[0][1] == Vector2(100, 120), "wheel zoom anchors at cursor")
	var release := _wheel(MOUSE_BUTTON_WHEEL_UP)
	release.pressed = false
	_feed(nav, release)
	t.check(zooms.size() == 2, "wheel release must not double-zoom")


func test_shift_and_horizontal_wheel_pan_sideways() -> void:
	_reset()
	var nav := MapNavInput.new()
	_feed(nav, _wheel(MOUSE_BUTTON_WHEEL_DOWN, 1.0, true))
	_feed(nav, _wheel(MOUSE_BUTTON_WHEEL_LEFT))
	t.check(pans.size() == 2 and zooms.is_empty(), "shift/horizontal wheel pans")
	t.check(pans[0].x > 0.0 and pans[1].x < 0.0, "pan direction follows wheel")


func test_scroll_mode_pan_makes_wheel_pan_and_ctrl_zoom() -> void:
	_reset()
	var nav := MapNavInput.new()
	_feed(nav, _wheel(MOUSE_BUTTON_WHEEL_DOWN), MapNavInput.ScrollMode.PAN)
	t.check(pans.size() == 1 and pans[0].y > 0.0 and zooms.is_empty(), "PAN mode: wheel scrolls the map")
	_feed(nav, _wheel(MOUSE_BUTTON_WHEEL_UP, 1.0, false, true), MapNavInput.ScrollMode.PAN)
	t.check(zooms.size() == 1 and zooms[0][0] > 1.0, "PAN mode: Ctrl+wheel still zooms (Windows pinch)")
	var pg := InputEventPanGesture.new()
	pg.delta = Vector2(0, 1.0)
	_reset()
	_feed(nav, pg, MapNavInput.ScrollMode.ZOOM)
	t.check(zooms.size() == 1 and zooms[0][0] < 1.0 and pans.is_empty(), "ZOOM mode: swipe down zooms out")


func test_touchscreen_two_finger_pinch_and_drag() -> void:
	_reset()
	var nav := MapNavInput.new()
	for i in 2:
		var st := InputEventScreenTouch.new()
		st.index = i
		st.pressed = true
		st.position = Vector2(100 + i * 100, 100)
		t.check(not _feed(nav, st), "touch presses stay available for emulated clicks")
	t.check(nav.is_multitouch(), "two fingers = multitouch")
	var sd := InputEventScreenDrag.new()
	sd.index = 1
	sd.position = Vector2(300, 100)  # fingers spread 100 -> 200 px
	t.check(_feed(nav, sd), "two-finger drag consumed")
	t.check(zooms.size() == 1 and is_equal_approx(zooms[0][0], 2.0), "spread doubles zoom")
	t.check(pans.size() == 1 and pans[0].x < 0.0, "midpoint moved right -> view moves left")
	var up := InputEventScreenTouch.new()
	up.index = 1
	up.pressed = false
	_feed(nav, up)
	t.check(not nav.is_multitouch(), "lifting a finger ends multitouch")


func test_preference_defaults_to_auto() -> void:
	t.check(int(UiPreferences.DEFAULTS.get("scroll_mode", -1)) == MapNavInput.ScrollMode.AUTO, "scroll_mode default AUTO")
