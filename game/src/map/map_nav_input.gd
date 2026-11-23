class_name MapNavInput
extends RefCounted
## Translates mouse, laptop trackpad and touchscreen events into two map intents shared by the
## 2D and 3D cameras, so every pointing device navigates without click-and-hold:
##   pan.call(view_delta_px: Vector2)          -> move the view by this many screen pixels
##   zoom.call(zoom_in: float, at: Vector2)    -> zoom_in > 1 zooms in, anchored at a screen point
##
## Device mapping (desktop-first, mouse + keyboard primary):
## - Mouse wheel: zoom toward cursor (smooth fractional factor on high-resolution wheels/touchpads).
## - Shift + wheel, horizontal wheel/tilt: pan sideways.
## - Trackpad two-finger swipe (InputEventPanGesture; macOS): pan, with OS momentum.
## - Trackpad pinch (InputEventMagnifyGesture) or Ctrl/Cmd + scroll: zoom toward cursor.
## - Touchscreen: two-finger pinch zooms and two-finger drag pans (one finger = emulated left drag).
## ScrollMode lets Windows precision-touchpad users (who receive wheel events, not pan gestures)
## choose "scroll pans, Ctrl+scroll zooms".

enum ScrollMode { AUTO, ZOOM, PAN }

const ZOOM_STEP := 1.15
const PAN_GESTURE_PX := 36.0  # Godot scales precise trackpad deltas by 0.03 -> ~1:1 with finger travel
const GESTURE_ZOOM_RATE := 0.5  # zoom steps per unit of pan-gesture delta when scrolling zooms
const WHEEL_PAN_PX := 64.0

var _touches := {}  # touch index -> screen position
var _pinch_dist := 0.0
var _pinch_mid := Vector2.ZERO


static func scroll_mode() -> int:
	return clampi(int(UiPreferences.values.get("scroll_mode", ScrollMode.AUTO)), 0, 2)


## True while two or more fingers are on a touchscreen; Main suppresses its one-finger drag/click.
func is_multitouch() -> bool:
	return _touches.size() >= 2


## Returns true when the event was a navigation event and has been consumed.
func handle(event: InputEvent, pan: Callable, zoom: Callable, mouse_pos: Vector2, mode: int = -1) -> bool:
	if mode < 0:
		mode = scroll_mode()
	if event is InputEventMouseButton:
		return _wheel(event as InputEventMouseButton, pan, zoom, mode)
	if event is InputEventPanGesture:
		var pg := event as InputEventPanGesture
		if mode == ScrollMode.ZOOM or pg.ctrl_pressed or pg.meta_pressed:
			if pg.delta.y != 0.0:
				zoom.call(pow(ZOOM_STEP, -pg.delta.y * GESTURE_ZOOM_RATE), _at(pg.position, mouse_pos))
		elif pg.delta != Vector2.ZERO:
			pan.call(pg.delta * PAN_GESTURE_PX)
		return true
	if event is InputEventMagnifyGesture:
		var mg := event as InputEventMagnifyGesture
		if mg.factor > 0.0 and mg.factor != 1.0:
			zoom.call(mg.factor, _at(mg.position, mouse_pos))
		return true
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_reset_pinch()
		return false  # single touches stay available to Main as emulated left clicks
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if not _touches.has(sd.index):
			return false
		_touches[sd.index] = sd.position
		if _touches.size() < 2:
			return false
		var pts: Array = _touches.values()
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[1]
		var dist := a.distance_to(b)
		var mid := (a + b) * 0.5
		if _pinch_dist > 1.0 and dist > 1.0:
			zoom.call(dist / _pinch_dist, mid)
			pan.call(_pinch_mid - mid)
		_pinch_dist = dist
		_pinch_mid = mid
		return true
	return false


func _wheel(mb: InputEventMouseButton, pan: Callable, zoom: Callable, mode: int) -> bool:
	var idx := mb.button_index
	if idx not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		return false
	if not mb.pressed:
		return true
	# factor is the fraction of a wheel notch (high-resolution wheels and touchpads report < 1).
	var f := mb.factor if mb.factor > 0.0 else 1.0
	var zoom_mod := mb.ctrl_pressed or mb.meta_pressed
	if idx == MOUSE_BUTTON_WHEEL_LEFT or idx == MOUSE_BUTTON_WHEEL_RIGHT:
		pan.call(Vector2((-1.0 if idx == MOUSE_BUTTON_WHEEL_LEFT else 1.0) * WHEEL_PAN_PX * f, 0.0))
		return true
	var down := 1.0 if idx == MOUSE_BUTTON_WHEEL_DOWN else -1.0
	if not zoom_mod and mb.shift_pressed:
		pan.call(Vector2(down * WHEEL_PAN_PX * f, 0.0))
	elif not zoom_mod and mode == ScrollMode.PAN:
		pan.call(Vector2(0.0, down * WHEEL_PAN_PX * f))
	else:
		zoom.call(pow(ZOOM_STEP, -down * f), mb.position)
	return true


func _reset_pinch() -> void:
	_pinch_dist = 0.0
	if _touches.size() >= 2:
		var pts: Array = _touches.values()
		_pinch_dist = (pts[0] as Vector2).distance_to(pts[1])
		_pinch_mid = ((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5


static func _at(pos: Vector2, fallback: Vector2) -> Vector2:
	return pos if pos != Vector2.ZERO else fallback
