extends SceneTree
## Writes a complete archive of the project (everything except .godot and tests/reports) to
## tests/reports/snapshots/<UTC date>_<evidence id>.zip, so the exact state a report was made from can be kept
## (A-020). Run by snapshot.bat; by hand:
##   godot --headless --path . --script res://tests/snapshot.gd
##   godot --headless --path . --script res://tests/snapshot.gd -- --out=C:/some/folder
## The output ends with one line starting SNAPSHOT: the file, its size and the evidence id. Exit code 0 only
## when the archive was written and read back with every file identical.

const Evidence := preload("res://tests/evidence.gd")


func _init() -> void:
	var out_dir := ProjectSettings.globalize_path("res://" + Evidence.SNAPSHOT_DIR)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out_dir = arg.trim_prefix("--out=")
	var ident := Evidence.identity("res://")
	var now := Time.get_datetime_dict_from_system(true)
	var stamp := Time.get_datetime_string_from_system(true)
	var date := "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]
	var base := Evidence.archive_name(ident, date)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var zip_path := out_dir.path_join(base + ".zip")
	var r := Evidence.write_archive("res://", zip_path, base, ident, stamp)
	print(Evidence.describe(ident))
	if r["ok"]:
		print("SNAPSHOT %s files=%d (plus SNAPSHOT.txt) bytes=%d evidence_id=%s verified=yes" % [zip_path, r["files"], r["bytes"], ident["id"]])
		quit(0)
	else:
		print("SNAPSHOT FAILED %s: %s" % [zip_path, r["error"]])
		quit(1)
