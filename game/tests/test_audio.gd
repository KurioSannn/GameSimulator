extends RefCounted
## Verification tests for CC0 packaged audio assets, manifest integrity, and GameAudio mixer.


func test_audio_manifest_files_exist_and_match_sha256() -> String:
	var txt := FileAccess.get_file_as_string("res://assets/audio/MANIFEST.json")
	if txt == "":
		return "MANIFEST.json missing or empty"
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return "MANIFEST.json is not a valid JSON object"
	var assets: Array = parsed.get("assets", [])
	if assets.size() != 19:
		return "expected 19 audio assets in MANIFEST.json, got %d" % assets.size()

	for entry in assets:
		var rel: String = str(entry.get("file", ""))
		var full := "res://assets/audio/" + rel
		if not FileAccess.file_exists(full):
			return "missing audio asset: %s" % full
		var raw := FileAccess.get_file_as_bytes(full)
		if raw.size() != int(entry.get("bytes", -1)):
			return "size mismatch for %s (%d != %d)" % [rel, raw.size(), int(entry.get("bytes", -1))]
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(raw)
		var digest := ctx.finish().hex_encode()
		if digest != str(entry.get("sha256", "")):
			return "sha256 mismatch for %s" % rel
	return ""


func test_audio_buses_and_streams_loaded() -> String:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return "SceneTree unavailable"
	var ga := loop.root.get_node_or_null("GameAudio")
	if ga == null:
		return "GameAudio autoload not present on root"

	for bus_name in ["Master", "Musik", "Efek", "Dialog"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			return "missing AudioServer bus: %s" % bus_name

	var ui_keys: Array = ga.call("get_loaded_ui_keys")
	if ui_keys.size() != 10:
		return "expected 10 loaded UI SFX keys, got %d (%s)" % [ui_keys.size(), str(ui_keys)]

	var amb_keys: Array = ga.call("get_loaded_ambient_keys")
	if amb_keys.size() != 8:
		return "expected 8 loaded ambient loop keys, got %d (%s)" % [amb_keys.size(), str(amb_keys)]

	var horn := ResourceLoader.load("res://assets/audio/ambient/ship_horn.ogg")
	if not (horn is AudioStream):
		return "failed to load ship_horn.ogg as AudioStream"

	# Verify world ambience update reacts smoothly without errors across 2D, 3D + hazards, and modal ducking.
	ga.call("update_world_ambience", true, true, false, 450.0, 0.45, {
		"rain": 0.6, "drought": 0.2, "fire": 0.4, "flood": 0.5, "traffic": 0.7, "quake": 0.3,
	})
	ga.call("update_world_ambience", true, true, true, 450.0, 0.45, {
		"rain": 0.6, "drought": 0.2, "fire": 0.4, "flood": 0.5, "traffic": 0.7, "quake": 0.3,
	})
	ga.call("update_world_ambience", false, false, false, 1200.0, 0.45, {})
	return ""


func test_bgm_day_and_night_tracks_loaded() -> String:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return "SceneTree unavailable"
	var ga := loop.root.get_node_or_null("GameAudio")
	if ga == null:
		return "GameAudio autoload not present on root"
	if not bool(ga.call("has_bgm")):
		return "expected GameAudio.has_bgm() to be true"

	var tracks: Dictionary = ga.call("get_bgm_tracks")
	var day_path := str(tracks.get("day", ""))
	var night_path := str(tracks.get("night", ""))
	if day_path == "" or not ResourceLoader.exists(day_path):
		return "missing day BGM track: %s" % day_path
	if night_path == "" or not ResourceLoader.exists(night_path):
		return "missing night BGM track: %s" % night_path

	var day_stream := ResourceLoader.load(day_path)
	var night_stream := ResourceLoader.load(night_path)
	if not (day_stream is AudioStreamMP3) or not (night_stream is AudioStreamMP3):
		return "expected AudioStreamMP3 streams for day and night BGM"
	if not (day_stream as AudioStreamMP3).loop or not (night_stream as AudioStreamMP3).loop:
		return "expected both day and night BGM streams to have loop enabled"

	ga.call("update_world_ambience", true, true, false, 700.0, 0.48, {})
	if float(ga.call("get_day_bgm_weight")) < 0.99:
		return "expected noon (0.48) day BGM weight to be 1.0"
	ga.call("update_world_ambience", true, true, false, 700.0, 0.02, {})
	if float(ga.call("get_day_bgm_weight")) > 0.01:
		return "expected midnight (0.02) day BGM weight to be 0.0"
	return ""
