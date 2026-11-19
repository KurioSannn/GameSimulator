class_name UiPreferences
extends RefCounted
## Device UI preferences, separate from authoritative simulation/save data.
const PATH := "user://ui_preferences.cfg"
const DEFAULTS := {"volume": 80.0, "music": 60.0, "effects": 85.0, "dialog": 90.0,
	"window_mode": 0, "resolution": 0, "antialiasing": 1, "text_scale": 1.0, "reduce_motion": false,
	"player_name": "Pemain", "pan_left": KEY_A, "pan_right": KEY_D, "pan_up": KEY_W, "pan_down": KEY_S}
static var values: Dictionary = DEFAULTS.duplicate(true)
static var config_path := PATH


static func read() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(config_path) != OK:
		return
	for key in DEFAULTS:
		values[key] = cfg.get_value("ui", key, DEFAULTS[key])
	values.text_scale = clampf(float(values.text_scale), 1.0, 1.1)
	for key in ["volume", "music", "effects", "dialog"]:
		values[key] = clampf(float(values[key]), 0.0, 100.0)
	values.window_mode = clampi(int(values.window_mode), 0, 1)
	values.resolution = clampi(int(values.resolution), 0, 2)
	values.antialiasing = clampi(int(values.antialiasing), 0, 2)


static func write(next_values: Dictionary) -> Error:
	var cfg := ConfigFile.new()
	for key in DEFAULTS:
		cfg.set_value("ui", key, next_values.get(key, DEFAULTS[key]))
	var err := cfg.save(config_path)
	if err == OK:
		values = next_values.duplicate(true)
	return err


static func apply_audio_values(source: Dictionary) -> void:
	for pair in [["Master", "volume"], ["Musik", "music"], ["Efek", "effects"], ["Dialog", "dialog"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, pair[0])
			AudioServer.set_bus_send(index, "Master")
		var val := clampf(float(source.get(pair[1], DEFAULTS[pair[1]])), 0.0, 100.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, val / 100.0)))
		AudioServer.set_bus_mute(index, val == 0.0)


static func apply(viewport: Viewport) -> void:
	apply_audio_values(values)
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][int(values.antialiasing)]
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if int(values.window_mode) == 0 else DisplayServer.WINDOW_MODE_WINDOWED)
		if int(values.window_mode) == 1:
			DisplayServer.window_set_size([Vector2i(1920, 1080), Vector2i(1600, 900), Vector2i(1280, 720)][int(values.resolution)])
