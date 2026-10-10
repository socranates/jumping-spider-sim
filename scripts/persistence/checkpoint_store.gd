extends RefCounted
## T09 / S02: where a checkpoint lives on disk, written so that a failed or interrupted write never costs the last good one (spec 22).
## Files in `dir`:
##   checkpoint.json      the current checkpoint
##   checkpoint.bak.json  the previous valid checkpoint (kept when a new one replaces it)
##   checkpoint.tmp.json  a write in progress (never read as a checkpoint)
## A file is {"format", "checksum", "checkpoint"}; the checksum is the MD5 of the checkpoint's canonical JSON (sorted keys, full precision),
## so a file that is cut short or changed is refused even if what is left still parses.
## Saving: the record is validated, written to the temporary file, closed, read back and checked (parse, checksum, validation). Only then is
## the current file (if it is itself valid) moved to the backup, and the temporary file moved into its place. A current file that is already
## damaged is not allowed to push out a good backup. Loading never writes: the current file is tried, then the backup, and each refusal
## says why. A newer schema is reported and left exactly as it is.
## Godot's `user://` maps to the player's application data folder on Windows (AppData\Roaming\Godot\app_userdata\<project>).

const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")

const FORMAT := "jumping-spider-sim checkpoint"
const MAIN_NAME := "checkpoint.json"
const BACKUP_NAME := "checkpoint.bak.json"
const TEMP_NAME := "checkpoint.tmp.json"
const DEFAULT_DIR := "user://saves"

var dir: String = DEFAULT_DIR
## The last save or load, for the screen and the tests: what happened and why.
var last_message: String = ""
var last_errors: PackedStringArray = PackedStringArray()


func _init(save_dir: String = DEFAULT_DIR) -> void:
	dir = save_dir


func main_path() -> String:
	return dir.path_join(MAIN_NAME)


func backup_path() -> String:
	return dir.path_join(BACKUP_NAME)


func temp_path() -> String:
	return dir.path_join(TEMP_NAME)


## The canonical text a checksum is taken over: numbers as JSON gives them back (doubles), keys sorted.
static func canonical(record: Dictionary) -> String:
	var round_trip: Variant = JSON.parse_string(JSON.stringify(record, "", true, true))
	return JSON.stringify(round_trip, "", true, true)


static func encode(record: Dictionary) -> String:
	var body := canonical(record)
	return JSON.stringify({"format": FORMAT, "checksum": body.md5_text(), "checkpoint": JSON.parse_string(body)}, "", true, true)


## Reads and checks the text of a checkpoint file: {"ok", "record", "errors"}.
static func decode(text: String) -> Dictionary:
	var errors := PackedStringArray()
	if text.strip_edges() == "":
		errors.append("the file is empty")
		return {"ok": false, "record": {}, "errors": errors}
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("the file is not readable JSON (line %d: %s); it may have been cut short" % [json.get_error_line(), json.get_error_message()])
		return {"ok": false, "record": {}, "errors": errors}
	var data: Variant = json.data
	if typeof(data) != TYPE_DICTIONARY or str((data as Dictionary).get("format", "")) != FORMAT:
		errors.append("the file is not a checkpoint of this game")
		return {"ok": false, "record": {}, "errors": errors}
	var record: Variant = (data as Dictionary).get("checkpoint")
	if typeof(record) != TYPE_DICTIONARY:
		errors.append("the file holds no checkpoint")
		return {"ok": false, "record": {}, "errors": errors}
	# A newer schema is reported as such before the checksum (a newer build may checksum differently).
	var version: Variant = (record as Dictionary).get("schema_version")
	if (typeof(version) == TYPE_FLOAT or typeof(version) == TYPE_INT) and int(version) > Checkpoint.SCHEMA_VERSION:
		errors.append_array(Checkpoint.validate(record))
		return {"ok": false, "record": {}, "errors": errors}
	if canonical(record).md5_text() != str((data as Dictionary).get("checksum", "")):
		errors.append("the checksum does not match: the file was changed or damaged after it was written")
		return {"ok": false, "record": {}, "errors": errors}
	errors.append_array(Checkpoint.validate(record))
	return {"ok": errors.is_empty(), "record": record if errors.is_empty() else {}, "errors": errors}


## Writes `record` as the current checkpoint, keeping the previous valid one as the backup. {"ok", "message", "errors"}.
func save(record: Dictionary) -> Dictionary:
	last_errors = Checkpoint.validate(record)
	if not last_errors.is_empty():
		return _result(false, "The checkpoint was not written: it did not pass its own checks.")
	var made := DirAccess.make_dir_recursive_absolute(dir)
	if made != OK and not DirAccess.dir_exists_absolute(dir):
		last_errors = PackedStringArray(["could not create %s (%s)" % [dir, error_string(made)]])
		return _result(false, "The checkpoint could not be written.")
	var text := encode(record)
	var f := FileAccess.open(temp_path(), FileAccess.WRITE)
	if f == null:
		last_errors = PackedStringArray(["could not open %s for writing (%s)" % [temp_path(), error_string(FileAccess.get_open_error())]])
		return _result(false, "The checkpoint could not be written.")
	f.store_string(text)
	f.flush()
	var write_error := f.get_error()
	f.close()
	if write_error != OK:
		last_errors = PackedStringArray(["writing %s failed (%s)" % [temp_path(), error_string(write_error)]])
		return _result(false, "The checkpoint could not be written; the previous one is unchanged.")
	var back := decode(FileAccess.get_file_as_string(temp_path()))
	if not bool(back["ok"]):
		last_errors = back["errors"]
		DirAccess.remove_absolute(temp_path())
		return _result(false, "The checkpoint did not read back correctly; the previous one is unchanged.")
	if FileAccess.file_exists(main_path()):
		var current := decode(FileAccess.get_file_as_string(main_path()))
		if bool(current["ok"]):
			if FileAccess.file_exists(backup_path()):
				DirAccess.remove_absolute(backup_path())
			var moved := DirAccess.rename_absolute(main_path(), backup_path())
			if moved != OK:
				last_errors = PackedStringArray(["could not keep the previous checkpoint as the backup (%s)" % error_string(moved)])
				return _result(false, "The checkpoint was not written; the previous one is unchanged.")
		else:
			DirAccess.remove_absolute(main_path())  # damaged: the backup, if any, stays as it is
	var placed := DirAccess.rename_absolute(temp_path(), main_path())
	if placed != OK:
		last_errors = PackedStringArray(["could not move the new checkpoint into place (%s)" % error_string(placed)])
		return _result(false, "The checkpoint could not be put in place; the backup is still available.")
	last_errors = PackedStringArray()
	return _result(true, "Checkpoint kept.")


## The newest valid checkpoint: {"ok", "record", "source" ("current" or "backup"), "message", "errors"}. Never writes or deletes a file.
func load_best() -> Dictionary:
	var errors := PackedStringArray()
	var current_errors := PackedStringArray()
	if FileAccess.file_exists(main_path()):
		var main := decode(FileAccess.get_file_as_string(main_path()))
		if bool(main["ok"]):
			last_errors = PackedStringArray()
			last_message = "Checkpoint found."
			return {"ok": true, "record": main["record"], "source": "current", "message": last_message, "errors": last_errors}
		current_errors = main["errors"]
		for m: String in current_errors:
			errors.append("checkpoint: " + m)
	if FileAccess.file_exists(backup_path()):
		var bak := decode(FileAccess.get_file_as_string(backup_path()))
		if bool(bak["ok"]):
			last_errors = errors
			last_message = "The latest checkpoint could not be used (%s); the previous one was used instead." % ("; ".join(current_errors) if not current_errors.is_empty() else "it is missing")
			return {"ok": true, "record": bak["record"], "source": "backup", "message": last_message, "errors": errors}
		for m: String in bak["errors"]:
			errors.append("backup: " + m)
	last_errors = errors
	if errors.is_empty():
		last_message = "No checkpoint yet: rest in the silk-lined crack to make one."
	else:
		last_message = "No usable checkpoint: " + "; ".join(errors)
	return {"ok": false, "record": {}, "source": "", "message": last_message, "errors": errors}


func has_any_file() -> bool:
	return FileAccess.file_exists(main_path()) or FileAccess.file_exists(backup_path())


## Removes every file of the store (tests).
func wipe() -> void:
	for p in [main_path(), backup_path(), temp_path()]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _result(ok: bool, message: String) -> Dictionary:
	last_message = message
	return {"ok": ok, "message": message, "errors": last_errors}
