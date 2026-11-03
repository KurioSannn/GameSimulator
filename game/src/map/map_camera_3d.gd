class_name MapCamera3D
extends Camera3D
## 3D Desktop map navigation: tabletop diorama camera.
## Controls:
## - Right/Middle drag: Pan across ground plane.
## - Shift + Right drag or Alt + Drag: Orbit / Tilt (pitch and yaw).
## - Wheel: Smooth zoom toward ground target.
## - WASD / Arrows: Keyboard pan.
## - Home: Fit entire archipelago.

signal view_changed

const ZOOM_STEP := 1.15
const KEY_PAN_SPEED := 950.0

var target := Vector3.ZERO
var distance := 1200.0
var pitch := 55.0       # degrees down from horizontal (90 = straight down top-down)
var yaw := 0.0         # degrees orbit around Y axis
var min_distance := 80.0
var max_distance := 4500.0
var min_pitch := 25.0
var max_pitch := 85.0

var map_bounds := Rect2()
var _dragging_pan := false
var _dragging_orbit := false
var _last_mouse_pos := Vector2.ZERO


func fit(rect: Rect2, viewport_size: Vector2) -> void:
	map_bounds = rect
	target = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	# Estimate required distance based on FOV and bounding rect
	var max_dim := maxf(rect.size.x, rect.size.y)
	var fov_rad := deg_to_rad(fov)
	distance = clampf((max_dim * 0.75) / tan(fov_rad * 0.5), min_distance, max_distance)
	pitch = 55.0
	yaw = 0.0
	_apply_transform()
	view_changed.emit()


func focus_rect(rect: Rect2, viewport_size: Vector2) -> void:
	target = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var max_dim := maxf(rect.size.x, rect.size.y)
	var fov_rad := deg_to_rad(fov)
	distance = clampf((max_dim * 0.9) / tan(fov_rad * 0.5), min_distance, max_distance)
	_apply_transform()
	view_changed.emit()


## Projects screen coordinate to ground plane (Y = 0) and returns 2D world coords (X, Z).
func get_ground_position(screen_pos: Vector2) -> Vector2:
	var ray_from := project_ray_origin(screen_pos)
	var ray_dir := project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 1e-5:
		return Vector2.ZERO
	var t := -ray_from.y / ray_dir.y
	var hit := ray_from + ray_dir * t
	return Vector2(hit.x, hit.z)


func _unhandled_input(event: InputEvent) -> void:
	if not current:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_step(1.0 / ZOOM_STEP, mb.position)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_step(ZOOM_STEP, mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT or mb.button_index == MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				_last_mouse_pos = mb.position
				if Input.is_key_pressed(KEY_SHIFT) or mb.button_index == MOUSE_BUTTON_MIDDLE:
					_dragging_orbit = true
				else:
					_dragging_pan = true
			else:
				_dragging_pan = false
				_dragging_orbit = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging_orbit:
			yaw -= mm.relative.x * 0.3
			pitch = clampf(pitch - mm.relative.y * 0.3, min_pitch, max_pitch)
			_apply_transform()
			view_changed.emit()
		elif _dragging_pan:
			var prev_ground := get_ground_position(_last_mouse_pos)
			var curr_ground := get_ground_position(mm.position)
			var delta_ground := prev_ground - curr_ground
			target.x += delta_ground.x
			target.z += delta_ground.y
			_clamp_target()
			_last_mouse_pos = mm.position
			_apply_transform()
			view_changed.emit()
	elif event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_EQUAL, KEY_KP_ADD: _zoom_step(1.0 / ZOOM_STEP, get_viewport().get_visible_rect().size * 0.5)
			KEY_MINUS, KEY_KP_SUBTRACT: _zoom_step(ZOOM_STEP, get_viewport().get_visible_rect().size * 0.5)
			KEY_HOME: fit(map_bounds, get_viewport().get_visible_rect().size)


func _process(delta: float) -> void:
	if not current or get_viewport().gui_get_focus_owner() != null:
		return
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
		dir += Vector2(
			float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
			float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	dir = dir.clamp(-Vector2.ONE, Vector2.ONE)
	if dir != Vector2.ZERO:
		var speed := KEY_PAN_SPEED * (distance / 1200.0) * delta
		var forward := Vector3(sin(deg_to_rad(yaw)), 0.0, -cos(deg_to_rad(yaw))).normalized()
		var right := Vector3(cos(deg_to_rad(yaw)), 0.0, sin(deg_to_rad(yaw))).normalized()
		var move := (right * dir.x - forward * dir.y) * speed
		target += move
		_clamp_target()
		_apply_transform()
		view_changed.emit()


func _zoom_step(factor: float, screen_pos: Vector2) -> void:
	var ground_before := get_ground_position(screen_pos)
	distance = clampf(distance * factor, min_distance, max_distance)
	_apply_transform()
	var ground_after := get_ground_position(screen_pos)
	var diff := ground_before - ground_after
	target.x += diff.x
	target.z += diff.y
	_clamp_target()
	_apply_transform()
	view_changed.emit()


func _clamp_target() -> void:
	if map_bounds.size != Vector2.ZERO:
		target.x = clampf(target.x, map_bounds.position.x, map_bounds.end.x)
		target.z = clampf(target.z, map_bounds.position.y, map_bounds.end.y)


func _apply_transform() -> void:
	var p_rad := deg_to_rad(pitch)
	var y_rad := deg_to_rad(yaw)
	var offset := Vector3(
		sin(y_rad) * cos(p_rad),
		sin(p_rad),
		cos(y_rad) * cos(p_rad)
	) * distance
	global_position = target + offset
	look_at(target, Vector3.UP)
