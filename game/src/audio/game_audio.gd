extends Node

const AUDIO_DIR := "res://assets/audio"
const BGM_DIR := "res://assets/audio/bgm"
const BGM_DAY_PATH := "res://assets/audio/bgm/Morning_at_the_Harbor.mp3"
const BGM_NIGHT_PATH := "res://assets/audio/bgm/Lantern_Light_and_Tea.mp3"
const MANIFEST_PATH := "res://assets/audio/MANIFEST.json"

const UI_PATHS := {
	"click": "res://assets/audio/ui/click_003.wav",
	"select": "res://assets/audio/ui/select_002.wav",
	"confirm": "res://assets/audio/ui/select_007.wav",
	"open": "res://assets/audio/ui/open_001.wav",
	"close": "res://assets/audio/ui/close_001.wav",
	"back": "res://assets/audio/ui/back_002.wav",
	"switch": "res://assets/audio/ui/toggle_004.wav",
	"tick": "res://assets/audio/ui/tick_001.wav",
	"error": "res://assets/audio/ui/error_008.wav",
	"alert": "res://assets/audio/ui/tick_004.wav",
}

const AMBIENT_PATHS := {
	"ocean": "res://assets/audio/ambient/ocean_waves.ogg",
	"birds": "res://assets/audio/ambient/birds_tropical.ogg",
	"wind": "res://assets/audio/ambient/wind_breeze.ogg",
	"rain": "res://assets/audio/ambient/rain_storm.ogg",
	"flood": "res://assets/audio/ambient/flood_water.ogg",
	"fire": "res://assets/audio/ambient/fire_crackling.ogg",
	"traffic": "res://assets/audio/ambient/city_traffic.ogg",
	"quake": "res://assets/audio/ambient/quake_rumble.ogg",
}

const SHIP_HORN_PATH := "res://assets/audio/ambient/ship_horn.ogg"
const UI_POOL_SIZE := 6
const MUTE_DB := -60.0
const BGM_BASE_DB := -9.0
const UI_DEBOUNCE_MSEC := 45
const STARTUP_GRACE_MSEC := 350

var _ui_streams: Dictionary = {}
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_cursor: int = 0
var _last_ui_msec: Dictionary = {}

var _ambient_players: Dictionary = {}
var _ambient_target_db: Dictionary = {}
var _ambient_current_db: Dictionary = {}
var _ship_horn_player: AudioStreamPlayer
var _ship_horn_timer: float = 9.0

var _bgm_day_player: AudioStreamPlayer
var _bgm_night_player: AudioStreamPlayer
var _bgm_day_path: String = ""
var _bgm_night_path: String = ""
var _bgm_day_weight: float = 1.0
var _bgm_day_cur_weight: float = 1.0
var _bgm_night_cur_weight: float = 0.0
var _bgm_day_time: float = 0.44

var _boot_msec: int = 0
var _world_active: bool = false
var _landscape_active: bool = false
var _modal_active: bool = false
var _cam_distance: float = 1200.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_boot_msec = Time.get_ticks_msec()
	_rng.seed = 20260417
	_ensure_buses()
	_setup_ui_pool()
	_setup_ambient_layers()
	_setup_bgm()
	var tree := get_tree()
	if tree != null:
		if not tree.node_added.is_connected(_on_tree_node_added):
			tree.node_added.connect(_on_tree_node_added)
		if tree.root != null:
			_bind_subtree(tree.root)


func _process(delta: float) -> void:
	var dt := clampf(delta, 0.001, 0.1)
	_process_bgm(dt)
	for key in _ambient_players.keys():
		var player := _ambient_players[key] as AudioStreamPlayer
		if player == null:
			continue
		var target := float(_ambient_target_db.get(key, MUTE_DB))
		var cur := float(_ambient_current_db.get(key, MUTE_DB))
		var speed := 3.2 if target > cur else 2.2
		cur = lerpf(cur, target, clampf(dt * speed, 0.0, 1.0))
		_ambient_current_db[key] = cur
		if cur <= -57.5:
			if player.playing:
				player.stop()
		else:
			player.volume_db = cur
			if not player.playing and player.stream != null and DisplayServer.get_name() != "headless":
				player.play(_rng.randf_range(0.0, 4.0))

	if _ship_horn_player != null and _ship_horn_player.stream != null:
		var sea_audible := _world_active and _landscape_active and not _modal_active and _cam_distance < 920.0
		if sea_audible and DisplayServer.get_name() != "headless":
			_ship_horn_timer -= dt
			if _ship_horn_timer <= 0.0:
				var proximity := clampf(1.0 - (_cam_distance - 240.0) / 680.0, 0.0, 1.0)
				_ship_horn_player.volume_db = lerpf(-26.0, -14.0, proximity)
				_ship_horn_player.pitch_scale = _rng.randf_range(0.94, 1.06)
				_ship_horn_player.play()
				_ship_horn_timer = _rng.randf_range(16.0, 29.0)


func play_ui(kind: String = "click", pitch_jitter: float = 0.03) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if now - _boot_msec < STARTUP_GRACE_MSEC:
		return
	var last := int(_last_ui_msec.get(kind, -1000))
	if now - last < UI_DEBOUNCE_MSEC:
		return
	_last_ui_msec[kind] = now
	var stream := _ui_streams.get(kind) as AudioStream
	if stream == null:
		stream = _ui_streams.get("click") as AudioStream
	if stream == null or _ui_players.is_empty():
		return
	var player := _ui_players[_ui_cursor % _ui_players.size()]
	_ui_cursor = (_ui_cursor + 1) % _ui_players.size()
	player.stream = stream
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 1.0
	player.volume_db = _ui_gain_db(kind)
	player.play()


func update_world_ambience(mode_3d: bool, landscape: bool, modal_open: bool, cam_distance: float, day_time: float, climate: Dictionary) -> void:
	_world_active = mode_3d
	_landscape_active = landscape
	_modal_active = modal_open
	_cam_distance = cam_distance
	_bgm_day_time = day_time if mode_3d else 0.44
	_bgm_day_weight = compute_day_bgm_weight(_bgm_day_time)

	if not mode_3d or not landscape:
		for key in _ambient_target_db.keys():
			_ambient_target_db[key] = MUTE_DB
		return

	var modal_att := -12.0 if modal_open else 0.0
	var zoom_close := clampf(1.0 - (cam_distance - 240.0) / 1180.0, 0.0, 1.0)
	var zoom_mid := clampf(1.0 - (cam_distance - 380.0) / 1450.0, 0.0, 1.0)

	var rain := clampf(float(climate.get("rain", 0.0)), 0.0, 1.0)
	var drought := clampf(float(climate.get("drought", 0.0)), 0.0, 1.0)
	var fire := clampf(float(climate.get("fire", 0.0)), 0.0, 1.0)
	var flood := clampf(float(climate.get("flood", 0.0)), 0.0, 1.0)
	var traffic := clampf(float(climate.get("traffic", 0.0)), 0.0, 1.0)
	var quake := clampf(float(climate.get("quake", 0.0)), 0.0, 1.0)

	# Morning/daytime promotes tropical birds; heavy rain, fire or night quiets them.
	var daylight := 1.0 - clampf(absf(day_time - 0.46) * 2.5, 0.0, 1.0)
	var bird_weight := clampf(zoom_close * (0.35 + 0.65 * daylight) * (1.0 - rain * 0.8) * (1.0 - fire * 0.7), 0.0, 1.0)
	var ocean_weight := clampf(0.18 + zoom_mid * 0.65, 0.0, 1.0)
	var wind_weight := clampf(0.16 + drought * 0.48 + (1.0 - zoom_close) * 0.35, 0.0, 1.0)
	var rain_weight := clampf(rain * (0.45 + 0.55 * zoom_mid), 0.0, 1.0)
	var flood_weight := clampf(flood * (0.35 + 0.65 * zoom_close), 0.0, 1.0)
	var fire_weight := clampf(fire * (0.35 + 0.65 * zoom_close), 0.0, 1.0)
	var traffic_weight := clampf(traffic * zoom_close, 0.0, 1.0)
	var quake_weight := clampf(quake * (0.40 + 0.60 * zoom_mid), 0.0, 1.0)

	_ambient_target_db["ocean"] = _weight_to_db(ocean_weight, -29.0, -14.0, modal_att)
	_ambient_target_db["birds"] = _weight_to_db(bird_weight, -32.0, -16.0, modal_att)
	_ambient_target_db["wind"] = _weight_to_db(wind_weight, -31.0, -17.0, modal_att)
	_ambient_target_db["rain"] = _weight_to_db(rain_weight, -26.0, -11.0, modal_att)
	_ambient_target_db["flood"] = _weight_to_db(flood_weight, -27.0, -12.0, modal_att)
	_ambient_target_db["fire"] = _weight_to_db(fire_weight, -25.0, -10.5, modal_att)
	_ambient_target_db["traffic"] = _weight_to_db(traffic_weight, -28.0, -14.5, modal_att)
	_ambient_target_db["quake"] = _weight_to_db(quake_weight, -24.0, -9.5, modal_att)


static func compute_day_bgm_weight(day_time: float) -> float:
	# 0.0/1.0 midnight, 0.23 dawn (pagi), 0.48 noon (siang), 0.77 sunset (sore).
	var t := fposmod(day_time, 1.0)
	if t >= 0.25 and t <= 0.75:
		return 1.0
	if t > 0.17 and t < 0.25:
		return smoothstep(0.17, 0.25, t)
	if t > 0.75 and t < 0.83:
		return 1.0 - smoothstep(0.75, 0.83, t)
	return 0.0


func has_bgm() -> bool:
	var day_ok := _bgm_day_player != null and _bgm_day_player.stream != null
	var night_ok := _bgm_night_player != null and _bgm_night_player.stream != null
	return day_ok or night_ok


func get_bgm_path() -> String:
	return _bgm_day_path if _bgm_day_weight >= 0.5 or _bgm_night_path == "" else _bgm_night_path


func get_bgm_tracks() -> Dictionary:
	return {"day": _bgm_day_path, "night": _bgm_night_path}


func get_active_bgm_label() -> String:
	if not has_bgm():
		return "Belum ada musik latar"
	var use_day := _bgm_day_weight >= 0.5 or _bgm_night_player == null or _bgm_night_player.stream == null
	if use_day and _bgm_day_path != "":
		return "Morning at the Harbor (Pagi–Sore)"
	if _bgm_night_path != "":
		return "Lantern Light & Tea (Malam–Pagi)"
	return _bgm_day_path.get_file().get_basename()


func get_day_bgm_weight() -> float:
	return _bgm_day_weight


func reload_bgm() -> bool:
	_bgm_day_path = BGM_DAY_PATH if ResourceLoader.exists(BGM_DAY_PATH) else _find_first_bgm_path()
	_bgm_night_path = BGM_NIGHT_PATH if ResourceLoader.exists(BGM_NIGHT_PATH) else ""
	if _bgm_day_player != null:
		_bgm_day_player.stop()
		_bgm_day_player.stream = _load_audio_stream(_bgm_day_path, true) if _bgm_day_path != "" else null
	if _bgm_night_player != null:
		_bgm_night_player.stop()
		_bgm_night_player.stream = _load_audio_stream(_bgm_night_path, true) if _bgm_night_path != "" else null

	_bgm_day_weight = compute_day_bgm_weight(_bgm_day_time)
	if _bgm_night_player == null or _bgm_night_player.stream == null:
		_bgm_day_cur_weight = 1.0 if (_bgm_day_player != null and _bgm_day_player.stream != null) else 0.0
		_bgm_night_cur_weight = 0.0
	elif _bgm_day_player == null or _bgm_day_player.stream == null:
		_bgm_day_cur_weight = 0.0
		_bgm_night_cur_weight = 1.0
	else:
		_bgm_day_cur_weight = _bgm_day_weight
		_bgm_night_cur_weight = 1.0 - _bgm_day_weight

	_apply_bgm_volumes()
	return has_bgm()


func get_loaded_ui_keys() -> Array[String]:
	var out: Array[String] = []
	for k in UI_PATHS.keys():
		if _ui_streams.get(k) != null:
			out.append(str(k))
	out.sort()
	return out


func get_loaded_ambient_keys() -> Array[String]:
	var out: Array[String] = []
	for k in AMBIENT_PATHS.keys():
		var p := _ambient_players.get(k) as AudioStreamPlayer
		if p != null and p.stream != null:
			out.append(str(k))
	out.sort()
	return out


func _process_bgm(dt: float) -> void:
	if not has_bgm():
		return
	var target_day := _bgm_day_weight
	if _bgm_night_player == null or _bgm_night_player.stream == null:
		target_day = 1.0
	elif _bgm_day_player == null or _bgm_day_player.stream == null:
		target_day = 0.0
	var target_night := 1.0 - target_day
	var step := clampf(dt * 0.45, 0.0, 1.0)
	_bgm_day_cur_weight = move_toward(_bgm_day_cur_weight, target_day, step)
	_bgm_night_cur_weight = move_toward(_bgm_night_cur_weight, target_night, step)
	_apply_bgm_volumes()


func _apply_bgm_volumes() -> void:
	var modal_att := -4.0 if _modal_active else 0.0
	_sync_bgm_deck(_bgm_day_player, _bgm_day_cur_weight, modal_att)
	_sync_bgm_deck(_bgm_night_player, _bgm_night_cur_weight, modal_att)


func _sync_bgm_deck(player: AudioStreamPlayer, weight: float, modal_att: float) -> void:
	if player == null or player.stream == null:
		return
	if weight <= 0.005:
		if player.playing:
			player.stop()
		player.volume_db = MUTE_DB
		return
	player.volume_db = BGM_BASE_DB + modal_att + linear_to_db(clampf(weight, 0.001, 1.0))
	if not player.playing and DisplayServer.get_name() != "headless":
		player.play()


func _ensure_buses() -> void:
	for bus_name in ["Musik", "Efek", "Dialog"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)


func _setup_ui_pool() -> void:
	for key in UI_PATHS.keys():
		_ui_streams[key] = _load_audio_stream(str(UI_PATHS[key]), false)
	for i in range(UI_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "UiSfx_%d" % i
		player.bus = "Efek"
		add_child(player)
		_ui_players.append(player)


func _setup_ambient_layers() -> void:
	for key in AMBIENT_PATHS.keys():
		var player := AudioStreamPlayer.new()
		player.name = "Ambient_%s" % str(key)
		player.bus = "Efek"
		player.volume_db = MUTE_DB
		player.stream = _load_audio_stream(str(AMBIENT_PATHS[key]), true)
		add_child(player)
		_ambient_players[key] = player
		_ambient_target_db[key] = MUTE_DB
		_ambient_current_db[key] = MUTE_DB

	_ship_horn_player = AudioStreamPlayer.new()
	_ship_horn_player.name = "Ambient_ship_horn"
	_ship_horn_player.bus = "Efek"
	_ship_horn_player.volume_db = -20.0
	_ship_horn_player.stream = _load_audio_stream(SHIP_HORN_PATH, false)
	add_child(_ship_horn_player)


func _setup_bgm() -> void:
	_bgm_day_player = AudioStreamPlayer.new()
	_bgm_day_player.name = "BgmDayPlayer"
	_bgm_day_player.bus = "Musik"
	_bgm_day_player.volume_db = MUTE_DB
	add_child(_bgm_day_player)

	_bgm_night_player = AudioStreamPlayer.new()
	_bgm_night_player.name = "BgmNightPlayer"
	_bgm_night_player.bus = "Musik"
	_bgm_night_player.volume_db = MUTE_DB
	add_child(_bgm_night_player)

	reload_bgm()


func _load_audio_stream(path: String, enable_loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var res := load(path)
	if not (res is AudioStream):
		return null
	var stream := res as AudioStream
	if enable_loop:
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
	return stream


func _find_first_bgm_path() -> String:
	var dir := DirAccess.open(BGM_DIR)
	if dir == null:
		return ""
	var files: Array[String] = []
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and not fname.ends_with(".import"):
			var lower := fname.to_lower()
			if lower.ends_with(".ogg") or lower.ends_with(".wav") or lower.ends_with(".mp3"):
				files.append(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	files.sort()
	if files.is_empty():
		return ""
	return "%s/%s" % [BGM_DIR, files[0]]


func _bind_subtree(node: Node) -> void:
	_bind_control_audio(node)
	for child in node.get_children():
		_bind_subtree(child)


func _on_tree_node_added(node: Node) -> void:
	_bind_control_audio(node)


func _bind_control_audio(node: Node) -> void:
	if not (node is Control):
		return
	if node.has_meta("_game_audio_bound"):
		return
	node.set_meta("_game_audio_bound", true)

	if node is CheckButton or node is CheckBox:
		(node as BaseButton).toggled.connect(func(_pressed: bool) -> void:
			play_ui("switch", 0.02)
		)
	elif node is OptionButton:
		var opt := node as OptionButton
		opt.pressed.connect(func() -> void:
			play_ui("open", 0.02)
		)
		opt.item_selected.connect(func(_idx: int) -> void:
			play_ui("select", 0.02)
		)
	elif node is BaseButton:
		var btn := node as BaseButton
		btn.pressed.connect(func() -> void:
			play_ui(_classify_button_sound(btn), 0.03)
		)
	elif node is TabBar:
		(node as TabBar).tab_clicked.connect(func(_tab: int) -> void:
			play_ui("select", 0.02)
		)
	elif node is HSlider:
		var slider := node as HSlider
		slider.drag_started.connect(func() -> void:
			play_ui("tick", 0.01)
		)
		slider.drag_ended.connect(func(_changed: bool) -> void:
			play_ui("tick", 0.01)
		)


func _classify_button_sound(btn: BaseButton) -> String:
	var variant := str(btn.theme_type_variation)
	if variant == "ButtonPrimary":
		return "confirm"
	if variant == "ButtonChoice":
		return "select"
	if btn is Button:
		var label := (btn as Button).text.strip_edges().to_lower()
		if label in ["tutup", "x", "batal", "keluar", "close", "cancel"]:
			return "close"
		if label in ["kembali", "back", "<"]:
			return "back"
		if label.begins_with("lanjut") or label.begins_with("terapkan") or label.begins_with("simpan") or label.begins_with("tetapkan"):
			return "confirm"
	return "click"


func _ui_gain_db(kind: String) -> float:
	match kind:
		"confirm":
			return -7.5
		"alert":
			return -7.5
		"error":
			return -8.0
		"tick":
			return -11.5
		"switch", "select":
			return -8.5
		"open", "close", "back":
			return -9.5
		_:
			return -8.5


func _weight_to_db(weight: float, min_db: float, max_db: float, modal_att: float) -> float:
	if weight <= 0.02:
		return MUTE_DB
	return lerpf(min_db, max_db, clampf(weight, 0.0, 1.0)) + modal_att
