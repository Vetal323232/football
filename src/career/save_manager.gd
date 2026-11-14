class_name SaveManager
extends RefCounted
## Career persistence under user:// with a schema version, atomic replacement
## (write temp file -> verify -> keep previous save as .bak -> rename) and a
## recovery path: if the main file is damaged the backup is loaded instead.

const DIR := "user://saves"
const FILE := "career.json"


static func path(dir := DIR) -> String:
	return dir + "/" + FILE


static func exists(dir := DIR) -> bool:
	return FileAccess.file_exists(path(dir)) or FileAccess.file_exists(path(dir) + ".bak")


static func save(cs: CareerState, dir := DIR) -> String:
	var errs := CareerState.validate(cs.data)
	if not errs.is_empty():
		return "refusing to save invalid state: %s" % str(errs[0])
	DirAccess.make_dir_recursive_absolute(dir)
	var final := path(dir)
	var tmp := final + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return "cannot write %s" % tmp
	f.store_string(JSON.stringify(cs.data))
	f.close()
	# Verify what was written before touching the existing save.
	var check := _read(tmp)
	if check.has("error"):
		DirAccess.remove_absolute(tmp)
		return "verification failed: %s" % check["error"]
	if FileAccess.file_exists(final):
		DirAccess.remove_absolute(final + ".bak")
		DirAccess.rename_absolute(final, final + ".bak")
	var err := DirAccess.rename_absolute(tmp, final)
	if err != OK:
		return "rename failed (%d)" % err
	return ""


static func _read(p: String) -> Dictionary:
	if not FileAccess.file_exists(p):
		return {"error": "missing"}
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return {"error": "unreadable"}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {"error": "broken JSON"}
	var d: Variant = json.data
	var errs := CareerState.validate(d)
	if not errs.is_empty():
		return {"error": str(errs[0])}
	CareerState.normalize(d)
	return {"data": d}


## Returns {career: CareerState or null, recovered: bool, error: String}.
static func load_career(dir := DIR) -> Dictionary:
	var main := _read(path(dir))
	if main.has("data"):
		var cs := CareerState.new()
		cs.data = main["data"]
		return {"career": cs, "recovered": false, "error": ""}
	var bak := _read(path(dir) + ".bak")
	if bak.has("data"):
		var cs2 := CareerState.new()
		cs2.data = bak["data"]
		return {"career": cs2, "recovered": true, "error": str(main["error"])}
	return {"career": null, "recovered": false, "error": str(main["error"])}


static func delete(dir := DIR) -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path(dir) + suffix):
			DirAccess.remove_absolute(path(dir) + suffix)
