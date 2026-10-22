class_name MapCamera
extends Camera2D
## Desktop map navigation: wheel zoom toward cursor, middle/right-drag pan, WASD/arrow pan,
## +/- zoom, Home to fit. Uses _unhandled_input so GUI panels consume their own events first.

signal view_changed

const ZOOM_STEP := 1.15
const KEY_PAN_SPEED := 900.0

var min_zoom := 0.2
var max_zoom := 40.0
var map_bounds := Rect2()
var _dragging := false


func fit(rect: Rect2, viewport_size: Vector2) -> void:
	map_bounds = rect
	var z := minf(viewport_size.x / rect.size.x, viewport_size.y / rect.size.y) * 0.95
	min_zoom = z * 0.8
	zoom = Vector2(z, z)
	position = rect.get_center()
	view_changed.emit()


func focus_rect(rect: Rect2, viewport_size: Vector2) -> void:
	var z := clampf(minf(viewport_size.x / rect.size.x, viewport_size.y / rect.size.y) * 0.5, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	position = rect.get_center()
	view_changed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at(ZOOM_STEP, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at(1.0 / ZOOM_STEP, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		_clamp()
		view_changed.emit()
	elif event is InputEventMagnifyGesture:  # trackpads on laptops
		_zoom_at((event as InputEventMagnifyGesture).factor, get_viewport().get_mouse_position())
	elif event is InputEventPanGesture:
		position += (event as InputEventPanGesture).delta * 20.0 / zoom.x
		_clamp()
		view_changed.emit()
	elif event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_EQUAL, KEY_KP_ADD: _zoom_at(ZOOM_STEP, get_viewport_rect().size / 2)
			KEY_MINUS, KEY_KP_SUBTRACT: _zoom_at(1.0 / ZOOM_STEP, get_viewport_rect().size / 2)
			KEY_HOME: fit(map_bounds, get_viewport_rect().size)


func _process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	# WASD by physical key position (works on any keyboard layout). The default ui_* actions only
	# cover the arrow keys (regression: QA checklist 2026-10-22). Ctrl/Cmd+S is manual save, not pan.
	if not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
		dir += Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	dir = dir.clamp(-Vector2.ONE, Vector2.ONE)
	if dir != Vector2.ZERO and get_viewport().gui_get_focus_owner() == null:
		position += dir * KEY_PAN_SPEED * delta / zoom.x
		_clamp()
		view_changed.emit()


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen_pos
	var z := clampf(zoom.x * factor, min_zoom, max_zoom)
	zoom = Vector2(z, z)
	force_update_scroll()
	var after := get_canvas_transform().affine_inverse() * screen_pos
	position += before - after
	_clamp()
	view_changed.emit()


func _clamp() -> void:
	if map_bounds.size != Vector2.ZERO:
		position = position.clamp(map_bounds.position, map_bounds.end)
