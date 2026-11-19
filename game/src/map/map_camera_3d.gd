class_name MapCamera3D
extends Camera3D
## 3D Desktop map navigation: tabletop diorama camera with strict Indonesia safe-zone clamping.
## Controls:
## - Left drag (via Main) / Middle drag / WASD / Arrows: Pan strictly within Indonesia archipelago safe zone.
## - Right drag / Q / E / R / F: Bounded orbit & tilt.
## - Wheel / + / -: Bounded smooth zoom toward ground target.
## - Home: Fit entire archipelago.

signal view_changed

const ZOOM_STEP := 1.15
const KEY_PAN_SPEED := 950.0
const MIN_DIST := 140.0
const HARD_MAX_DIST := 3200.0

var target := Vector3.ZERO
var distance := 2600.0
var pitch := 52.0
var yaw := -6.0
var min_distance := MIN_DIST
var max_distance := HARD_MAX_DIST
var min_pitch := 26.0
var max_pitch := 78.0
var min_yaw := -34.0
var max_yaw := 26.0

var map_bounds := Rect2()
var _dragging_pan := false
var _dragging_orbit := false
var _last_mouse_pos := Vector2.ZERO
var _focus_tween: Tween


func _ready() -> void:
	near = 2.0
	far = 36000.0
	fov = 48.0


func fit(rect: Rect2, viewport_size: Vector2) -> void:
	near = 2.0
	far = 36000.0
	map_bounds = rect
	target = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var max_dim := maxf(rect.size.x, rect.size.y)
	var fov_rad := deg_to_rad(fov)
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	var fit_dist := clampf((max_dim * 0.72) / (tan(fov_rad * 0.5) * aspect), MIN_DIST, HARD_MAX_DIST)
	max_distance = clampf(fit_dist * 1.12, 2200.0, HARD_MAX_DIST)
	distance = clampf(fit_dist, min_distance, max_distance)
	pitch = 52.0
	yaw = -6.0
	_clamp_target()
	_apply_transform()
	view_changed.emit()


func focus_rect(rect: Rect2, _viewport_size: Vector2) -> void:
	target = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var max_dim := maxf(rect.size.x, rect.size.y)
	var fov_rad := deg_to_rad(fov)
	distance = clampf((max_dim * 0.85) / tan(fov_rad * 0.5), min_distance, max_distance)
	pitch = 52.0
	yaw = -6.0
	_clamp_target()
	_apply_transform()
	view_changed.emit()


func focus_region(rect: Rect2, animate: bool = true) -> void:
	var new_target := Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	var max_dim := maxf(rect.size.x, rect.size.y)
	var fov_rad := deg_to_rad(fov)
	var want_dist := clampf((max_dim * 3.2) / tan(fov_rad * 0.5), 320.0, minf(1800.0, max_distance))

	if _focus_tween and _focus_tween.is_valid():
		_focus_tween.kill()

	if animate:
		_focus_tween = create_tween().set_parallel(true)
		_focus_tween.tween_property(self, "target", new_target, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_focus_tween.tween_property(self, "distance", want_dist, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_focus_tween.tween_method(func(_v): _clamp_target(); _apply_transform(); view_changed.emit(), 0.0, 1.0, 0.45)
	else:
		target = new_target
		distance = want_dist
		_clamp_target()
		_apply_transform()
		view_changed.emit()


## Projects screen coordinate to ground plane (Y = 0) and returns 2D world coords (X, Z).
func get_ground_position(screen_pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return Vector2(target.x, target.z)
	var ray_from := project_ray_origin(screen_pos)
	var ray_dir := project_ray_normal(screen_pos)
	if absf(ray_dir.y) < 1e-4:
		return Vector2(target.x, target.z)
	var t := -ray_from.y / ray_dir.y
	if t <= 0.0:
		return Vector2(target.x, target.z)
	var hit := ray_from + ray_dir * minf(t, 12000.0)
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
				_dragging_orbit = true
			else:
				_dragging_orbit = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _dragging_orbit:
			drag_orbit_step(mm.relative)
	elif event is InputEventKey and event.pressed:
		match (event as InputEventKey).keycode:
			KEY_EQUAL, KEY_KP_ADD: _zoom_step(1.0 / ZOOM_STEP, get_viewport().get_visible_rect().size * 0.5)
			KEY_MINUS, KEY_KP_SUBTRACT: _zoom_step(ZOOM_STEP, get_viewport().get_visible_rect().size * 0.5)
			KEY_HOME, KEY_BACKSPACE: fit(map_bounds, get_viewport().get_visible_rect().size)


func drag_pan_step(from_screen: Vector2, to_screen: Vector2) -> void:
	var prev_ground := get_ground_position(from_screen)
	var curr_ground := get_ground_position(to_screen)
	var delta_ground := prev_ground - curr_ground
	target.x += delta_ground.x
	target.z += delta_ground.y
	_clamp_target()
	_apply_transform()
	view_changed.emit()


func drag_orbit_step(relative: Vector2) -> void:
	yaw = clampf(yaw - relative.x * 0.35, min_yaw, max_yaw)
	pitch = clampf(pitch - relative.y * 0.35, min_pitch, max_pitch)
	_clamp_target()
	_apply_transform()
	view_changed.emit()


func _process(delta: float) -> void:
	if not current or get_viewport().gui_get_focus_owner() != null:
		return
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down"))
	if not (Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META)):
		dir += Vector2(
			float(Input.is_physical_key_pressed(int(UiPreferences.values.pan_right))) - float(Input.is_physical_key_pressed(int(UiPreferences.values.pan_left))),
			float(Input.is_physical_key_pressed(int(UiPreferences.values.pan_down))) - float(Input.is_physical_key_pressed(int(UiPreferences.values.pan_up))))
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

	# Keyboard Orbit (Q / E) bounded
	var rot_dir := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if rot_dir != 0.0:
		yaw = clampf(yaw + rot_dir * 65.0 * delta, min_yaw, max_yaw)
		_clamp_target()
		_apply_transform()
		view_changed.emit()

	# Keyboard Tilt (R / F) bounded
	var tilt_dir := float(Input.is_physical_key_pressed(KEY_R)) - float(Input.is_physical_key_pressed(KEY_F))
	if tilt_dir != 0.0:
		pitch = clampf(pitch + tilt_dir * 45.0 * delta, min_pitch, max_pitch)
		_clamp_target()
		_apply_transform()
		view_changed.emit()


func _zoom_step(factor: float, screen_pos: Vector2) -> void:
	var ground_before := get_ground_position(screen_pos)
	distance = clampf(distance * factor, min_distance, max_distance)
	_clamp_target()
	_apply_transform()
	var ground_after := get_ground_position(screen_pos)
	var diff := ground_before - ground_after
	target.x += diff.x
	target.z += diff.y
	_clamp_target()
	_apply_transform()
	view_changed.emit()


## Adaptive safe-zone pan clamping: keeps camera anchored inside Indonesian archipelago islands
## at close zoom, and progressively centers toward Nusantara overview when zoomed out so oceans stay out of empty bounds.
func _clamp_target() -> void:
	if map_bounds.size == Vector2.ZERO:
		return
	var span := maxf(max_distance - min_distance, 1.0)
	var zoom_ratio := clampf((distance - min_distance) / span, 0.0, 1.0)
	var safe_t := pow(zoom_ratio, 1.25)
	var inset_x := lerpf(-25.0, map_bounds.size.x * 0.36, safe_t)
	var inset_z := lerpf(-25.0, map_bounds.size.y * 0.32, safe_t)
	var min_x := map_bounds.position.x + inset_x
	var max_x := map_bounds.end.x - inset_x
	var min_z := map_bounds.position.y + inset_z
	var max_z := map_bounds.end.y - inset_z
	var cx := map_bounds.get_center().x
	var cz := map_bounds.get_center().y
	if min_x > max_x:
		min_x = cx
		max_x = cx
	if min_z > max_z:
		min_z = cz
		max_z = cz
	target.x = clampf(target.x, min_x, max_x)
	target.z = clampf(target.z, min_z, max_z)


func _apply_transform() -> void:
	var p_rad := deg_to_rad(pitch)
	var y_rad := deg_to_rad(yaw)
	var offset := Vector3(
		sin(y_rad) * cos(p_rad),
		sin(p_rad),
		cos(y_rad) * cos(p_rad)
	) * distance
	if is_inside_tree():
		global_position = target + offset
		look_at(target, Vector3.UP)
	else:
		position = target + offset
