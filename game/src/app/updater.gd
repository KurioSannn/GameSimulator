extends Node
## Automatic updates (D-096). First autoload, so a downloaded patch is mounted before any other game
## script or data is loaded.
##
## Two kinds of update, described by one JSON manifest (res://data/update_config.json -> manifest_url):
##   - small/medium (content, story, balance, scripts): a Godot patch pack (.pck) for this binary line.
##     Downloaded in the background, SHA-256 verified, stored in user://updates/, mounted on next start.
##     Works the same on Windows, macOS and Android.
##   - major (engine or binary change): the manifest names a newer binary line; the game shows a
##     "Versi baru tersedia" notice with a download link for this platform. A running program cannot
##     replace its own installer, so this step needs one tap from the player.
## Offline, a missing manifest or a bad download never block play; failures are only logged.
##
## Manifest:
## {"latest": "1.0.3", "notes": "...",
##  "patch": {"version": "1.0.3", "binary_line": "1.0",
##            "files": {"windows": {"url", "sha256", "size"}, "macos": {...}, "android": {...}}},
##  "full":  {"version": "1.1.0", "binary_line": "1.1", "windows": "url", "android": "url", "macos": "url"}}

signal patch_ready(version: String)
signal major_available(version: String, url: String, notes: String)

const UPDATES_DIR := "user://updates"
const INSTALLED := "user://updates/installed.json"
const CONFIG := "res://data/update_config.json"

## Version of the running content: the binary's version, or the mounted patch's.
var current_version := ""
var binary_version := ""
var binary_line := ""
var pending_version := ""
var _http: HTTPRequest
var _cfg := {}
var _manifest := {}


func _init() -> void:
	binary_version = str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	binary_line = line_of(binary_version)
	current_version = binary_version
	_mount_installed_patch()


static func line_of(v: String) -> String:
	var p := v.split(".")
	return "%s.%s" % [p[0], p[1] if p.size() > 1 else "0"]


## Numeric comparison of dotted versions: 1 if a > b, -1 if a < b, 0 if equal.
static func compare(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


func _mount_installed_patch() -> void:
	if not FileAccess.file_exists(INSTALLED):
		return
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(INSTALLED))
	if not (info is Dictionary):
		return
	var path := str(info.get("path", ""))
	# A patch belongs to one binary line; after a full reinstall of a newer binary it is dropped.
	if str(info.get("binary_line", "")) != binary_line or compare(str(info.get("version", "0")), binary_version) <= 0:
		_remove_patch(path)
		return
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != str(info.get("sha256", "")):
		push_warning("Updater: installed patch missing or corrupted; ignored.")
		_remove_patch(path)
		return
	if ProjectSettings.load_resource_pack(path, true):
		current_version = str(info.version)
		print("Updater: content %s mounted over binary %s" % [current_version, binary_version])
	else:
		push_warning("Updater: could not mount %s" % path)


func _remove_patch(path: String) -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if FileAccess.file_exists(INSTALLED):
		DirAccess.remove_absolute(INSTALLED)


func _ready() -> void:
	if FileAccess.file_exists(CONFIG):
		var c: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
		if c is Dictionary:
			_cfg = c
	# Testing/staging override, e.g. NUSANTARA_UPDATE_URL=http://127.0.0.1:8765/update.json
	if OS.get_environment("NUSANTARA_UPDATE_URL") != "":
		_cfg["manifest_url"] = OS.get_environment("NUSANTARA_UPDATE_URL")
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	add_child(_http)
	if _should_check():
		check_now.call_deferred()


func _should_check() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("editor"):
		return false
	if str(_cfg.get("manifest_url", "")) == "":
		return false
	return bool(UiPreferences.values.get("auto_update", true))


func check_now() -> void:
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_http.request_completed.connect(_on_manifest, CONNECT_ONE_SHOT)
	if _http.request(str(_cfg.manifest_url)) != OK:
		_http.request_completed.disconnect(_on_manifest)


func _on_manifest(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("Updater: no manifest (result %d, http %d)" % [result, code])
		return
	var m: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (m is Dictionary):
		return
	_manifest = m
	var full: Dictionary = m.get("full", {})
	if not full.is_empty() and compare(line_of(str(full.get("version", "0"))), binary_line) > 0:
		var url := str(full.get(platform_key(), ""))
		if url != "":
			major_available.emit(str(full.version), url, str(m.get("notes", "")))
	var patch: Dictionary = m.get("patch", {})
	if patch.is_empty() or str(patch.get("binary_line", "")) != binary_line:
		return
	if compare(str(patch.get("version", "0")), current_version) <= 0:
		return
	# Patch packs are per platform (desktop and Android use different texture formats).
	var file: Dictionary = patch.get("files", {}).get(platform_key(), {})
	if str(file.get("url", "")) == "":
		return
	_download_patch({"version": str(patch.version), "url": str(file.url), "sha256": str(file.get("sha256", ""))})


static func platform_key() -> String:
	if OS.has_feature("android"):
		return "android"
	if OS.has_feature("macos"):
		return "macos"
	return "windows"


func _download_patch(patch: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(UPDATES_DIR)
	var tmp := UPDATES_DIR + "/download.tmp"
	_http.download_file = tmp
	_http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		_http.download_file = ""
		_on_patch(result, code, tmp, patch), CONNECT_ONE_SHOT)
	if _http.request(str(patch.url)) != OK:
		_http.download_file = ""


func _on_patch(result: int, code: int, tmp: String, patch: Dictionary) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		print("Updater: patch download failed (result %d, http %d)" % [result, code])
		return
	if FileAccess.get_sha256(tmp) != str(patch.get("sha256", "")):
		push_warning("Updater: patch checksum mismatch; discarded.")
		DirAccess.remove_absolute(tmp)
		return
	var dest := "%s/nusantara_%s.pck" % [UPDATES_DIR, str(patch.version)]
	DirAccess.rename_absolute(tmp, dest)
	var old := {}
	if FileAccess.file_exists(INSTALLED):
		var o: Variant = JSON.parse_string(FileAccess.get_file_as_string(INSTALLED))
		if o is Dictionary:
			old = o
	var f := FileAccess.open(INSTALLED, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": str(patch.version), "binary_line": binary_line,
		"path": dest, "sha256": str(patch.sha256)}))
	f.close()
	var old_path := str(old.get("path", ""))
	if old_path != "" and old_path != dest and FileAccess.file_exists(old_path):
		DirAccess.remove_absolute(old_path)
	pending_version = str(patch.version)
	print("Updater: patch %s ready for next start" % pending_version)
	patch_ready.emit(pending_version)


## Restart so a downloaded patch takes effect (desktop). On Android the player reopens the app.
func restart_now() -> void:
	if not OS.has_feature("mobile"):
		OS.set_restart_on_exit(true, OS.get_cmdline_args())
	get_tree().quit()
