class_name SaveService
extends RefCounted
## Offline save/load (docs/11). One JSON file per slot under a save directory
## (default user://saves). No slot cap beyond disk space.
##
## File envelope:
##   {"format":"nusantara.save","envelope_version":1,"meta":{...},"payload":{...},"sha256":"<hex of payload JSON>"}
## Writes are atomic: write <slot>.tmp, keep previous file as <slot>.bak, then rename.
## A corrupt/unsupported file never crashes the game; load returns an error message and
## other slots are untouched.

const FORMAT := "nusantara.save"
const ENVELOPE_VERSION := 1
const QUICKSAVE_ID := "quicksave"
const AUTOSAVE_PREFIX := "autosave_"
const AUTOSAVE_ROTATION := 3

var save_dir: String


func _init(dir: String = "user://saves") -> void:
	save_dir = dir
	DirAccess.make_dir_recursive_absolute(save_dir)


static func sanitize_id(raw: String) -> String:
	var out := ""
	for ch in raw.to_lower():
		out += ch if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9") or ch == "_" or ch == "-" else "_"
	return out.substr(0, 64) if out != "" else "slot"


func path_for(slot_id: String) -> String:
	return save_dir.path_join(sanitize_id(slot_id) + ".json")


## payload: full game state (SimWorld.to_dict() plus app-level state); meta: preview fields.
func save(slot_id: String, label: String, payload: Dictionary, meta_extra: Dictionary = {}) -> String:
	var payload_json := JSON.stringify(payload, "", true, true)  # sorted keys, full float precision
	var now := Time.get_datetime_string_from_system(true)
	var path := path_for(slot_id)
	var created := now
	var prev := read_meta(slot_id)
	if prev.get("ok", false):
		created = str(prev.meta.get("created_at", now))
	var meta := {
		"save_id": sanitize_id(slot_id),
		"save_label": label,
		"created_at": created,
		"updated_at": now,
	}
	meta.merge(meta_extra, true)
	var envelope := {
		"format": FORMAT,
		"envelope_version": ENVELOPE_VERSION,
		"meta": meta,
		"payload_json": payload_json,
		"sha256": payload_json.sha256_text(),
	}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "Gagal menulis berkas simpanan (%s)." % error_string(FileAccess.get_open_error())
	f.store_string(JSON.stringify(envelope, "", true, true))
	f.close()
	if FileAccess.file_exists(path):
		var bak := path + ".bak"
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
		DirAccess.rename_absolute(path, bak)
	var err := DirAccess.rename_absolute(tmp, path)
	if err != OK:
		return "Gagal menyelesaikan simpanan (%s)." % error_string(err)
	return ""


## Returns {"ok": true, "meta": {...}, "payload": {...}} or {"ok": false, "error": "..."}.
func load_slot(slot_id: String) -> Dictionary:
	return _read(path_for(slot_id), true)


## Tries the slot, then its .bak (recovery from an interrupted write).
func load_with_recovery(slot_id: String) -> Dictionary:
	var r := load_slot(slot_id)
	if r.ok:
		return r
	var b := _read(path_for(slot_id) + ".bak", true)
	if b.ok:
		b["recovered_from_backup"] = true
		return b
	return r


func read_meta(slot_id: String) -> Dictionary:
	return _read(path_for(slot_id), false)


func list_slots() -> Array:
	var out: Array = []
	var d := DirAccess.open(save_dir)
	if d == null:
		return out
	for f in d.get_files():
		if not f.ends_with(".json"):
			continue
		var r := _read(save_dir.path_join(f), false)
		out.append({"slot_id": f.get_basename(), "ok": r.ok, "meta": r.get("meta", {}), "error": r.get("error", "")})
	out.sort_custom(func(a, b): return str(a.meta.get("updated_at", "")) > str(b.meta.get("updated_at", "")))
	return out


func delete_slot(slot_id: String) -> void:
	for p in [path_for(slot_id), path_for(slot_id) + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


## Rotating autosave: returns the slot id written.
func autosave(payload: Dictionary, meta_extra: Dictionary, counter: int) -> String:
	var slot := AUTOSAVE_PREFIX + str(counter % AUTOSAVE_ROTATION)
	var err := save(slot, "Simpan Otomatis", payload, meta_extra)
	if err != "":
		push_warning(err)
	return slot


func _read(path: String, with_payload: bool) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "Berkas simpanan tidak ditemukan."}
	var parsed: Variant = _parse_quiet(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Berkas simpanan rusak (bukan JSON valid)."}
	var env: Dictionary = parsed
	if env.get("format") != FORMAT:
		return {"ok": false, "error": "Bukan berkas simpanan NUSANTARA."}
	if int(env.get("envelope_version", -1)) > ENVELOPE_VERSION:
		return {"ok": false, "error": "Simpanan dibuat oleh versi permainan yang lebih baru."}
	var meta: Dictionary = env.get("meta", {})
	var pj := str(env.get("payload_json", ""))
	if pj.sha256_text() != str(env.get("sha256", "")):
		return {"ok": false, "error": "Berkas simpanan rusak (checksum tidak cocok).", "meta": meta}
	if not with_payload:
		return {"ok": true, "meta": meta}
	var payload: Variant = _parse_quiet(pj)
	if typeof(payload) != TYPE_DICTIONARY:
		return {"ok": false, "error": "Isi simpanan rusak.", "meta": meta}
	return {"ok": true, "meta": meta, "payload": payload}


## Parses without logging engine errors (corrupt saves are an expected, handled condition).
static func _parse_quiet(text: String) -> Variant:
	var j := JSON.new()
	return j.data if j.parse(text) == OK else null
