extends "res://tests/test_case.gd"
## Evidence identity (A-020): the source hash is the one the report has always had, the settings and tests
## hashes change only with their own files, and the archive holds the whole project except the editor cache
## and the reports, and is read back and compared.

const Evidence := preload("res://tests/evidence.gd")
const TMP := "user://jss_evidence_test"
const OUT := "user://jss_evidence_test_out"


func before_each() -> void:
	_rm_tree(TMP)
	_rm_tree(OUT)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TMP))
	_write("project.godot", "config_version=5\n")
	_write("scripts/a.gd", "extends Node\n")
	_write("scripts/sub/b.gd", "extends Node\n")
	_write("scripts/a.gd.uid", "uid://abc\n")
	_write("scenes/main.tscn", "[gd_scene]\n")
	_write("data/x.json", "{}\n")
	_write("tests/t.gd", "extends Node\n")
	_write("tests/t.tscn", "[gd_scene]\n")
	_write("tests/t.gd.uid", "uid://def\n")
	_write("tests/reports/last_report.txt", "old report\n")
	_write(".gitignore", "tests/reports/\n")
	_write(".godot/cache.bin", "cache\n")
	_write(".git/config", "local repository settings\n")
	_write("docs/notes.md", "notes\n")
	_write("docs/empty.txt", "")


func after_each() -> void:
	_rm_tree(TMP)
	_rm_tree(OUT)


## The first report's algorithm, written out again independently: md5 over "res://path" and the bytes of
## every .gd .tscn .tres .json .gdshader file in scripts, scenes and data, in sorted order.
func _legacy_source_hash() -> String:
	var paths: Array[String] = []
	for dir_path in ["res://scripts", "res://scenes", "res://data"]:
		_legacy_collect(dir_path, paths)
	paths.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for p in paths:
		ctx.update(p.to_utf8_buffer())
		ctx.update(FileAccess.get_file_as_bytes(p))
	return ctx.finish().hex_encode()


func _legacy_collect(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_legacy_collect(dir_path + "/" + sub, out)
	for f in dir.get_files():
		if ["gd", "tscn", "tres", "json", "gdshader"].has(f.get_extension()):
			out.append(dir_path + "/" + f)


func test_the_source_hash_is_the_one_the_report_always_had() -> void:
	check_eq(Evidence.source_hash("res://"), _legacy_source_hash(), "same algorithm over the real project, so old and new reports compare")
	check_eq(Evidence.source_hash("res://").length(), 32, "an md5 in hex")


func test_hashes_follow_their_own_files_only() -> void:
	var base := Evidence.identity(TMP)
	check_eq(base["id"], Evidence.identity(TMP)["id"], "the same files give the same id")
	_write("scripts/sub/b.gd", "extends Node3D\n")
	var a := Evidence.identity(TMP)
	check(a["source"] != base["source"], "a script changes the source hash")
	check_eq(a["settings"], base["settings"], "and not the settings hash")
	check_eq(a["tests"], base["tests"], "and not the tests hash")
	check(a["id"] != base["id"], "and the id")
	_write("project.godot", "config_version=5\n[physics]\n")
	var b := Evidence.identity(TMP)
	check(b["settings"] != a["settings"], "project.godot changes the settings hash")
	check_eq(b["source"], a["source"], "and not the source hash")
	check_eq(b["tests"], a["tests"], "and not the tests hash")
	check(b["id"] != a["id"], "and the id")
	_write("tests/t.tscn", "[gd_scene load_steps=2]\n")
	var c := Evidence.identity(TMP)
	check(c["tests"] != b["tests"], "a test scene changes the tests hash")
	check_eq(c["source"], b["source"], "and not the source hash")
	check_eq(c["settings"], b["settings"], "and not the settings hash")
	check(c["id"] != b["id"], "and the id")


func test_files_that_are_not_evidence_change_nothing() -> void:
	var base := Evidence.identity(TMP)
	_write("scripts/a.gd.uid", "uid://changed\n")
	_write("tests/t.gd.uid", "uid://changed\n")
	_write("tests/reports/last_report.txt", "a newer report\n")
	_write("tests/reports/shots/x.png", "png\n")
	_write("docs/notes.md", "more notes\n")
	_write(".godot/cache.bin", "other cache\n")
	var after := Evidence.identity(TMP)
	check_eq(after["source"], base["source"], "uid files, reports and docs are not in the source hash")
	check_eq(after["tests"], base["tests"], "or in the tests hash (a report is output, not a test)")
	check_eq(after["id"], base["id"], "so the id holds")
	_write("data/new.json", "[]\n")
	check(Evidence.source_hash(TMP) != base["source"], "a new data file does")


func test_the_id_is_twelve_hex_digits_made_from_all_three() -> void:
	var ident := Evidence.identity(TMP)
	var id: String = ident["id"]
	check_eq(id.length(), 12, "twelve characters")
	check(id.is_valid_hex_number(false), "hexadecimal")
	check(Evidence.make_id("a", "b", "c") != Evidence.make_id("a", "b", "d"), "the tests hash is part of it")
	check(Evidence.make_id("a", "b", "c") != Evidence.make_id("a", "x", "c"), "the settings hash is part of it")
	check(Evidence.make_id("a", "b", "c") != Evidence.make_id("x", "b", "c"), "the source hash is part of it")
	check(Evidence.describe(ident).contains(id), "the one-line form names the id")
	check_eq(Evidence.archive_name(ident, "2026-10-07"), "2026-10-07_" + id, "the archive is named date_id")


func test_the_archive_holds_the_project_except_the_cache_and_the_reports() -> void:
	var files := Evidence.archive_files(TMP)
	check(files.has("project.godot"), "project.godot")
	check(files.has(".gitignore"), "hidden files are included")
	check(not files.has(".git/config"), "repository internals stay out of snapshots")
	check(files.has("scripts/sub/b.gd") and files.has("scripts/a.gd.uid"), "nested files and uid files")
	check(files.has("docs/empty.txt"), "an empty file")
	check(files.has("tests/t.tscn") and files.has("docs/notes.md"), "tests and docs")
	for f in files:
		check(not f.begins_with(".godot") and not f.begins_with("tests/reports"), "left out: %s" % f)
	check_eq(files.size(), 12, "everything else, nothing twice")


func test_the_archive_is_written_read_back_and_checked() -> void:
	var ident := Evidence.identity(TMP)
	var name := "2026-10-07_" + str(ident["id"])
	var zip_path := ProjectSettings.globalize_path(OUT + "/" + name + ".zip")
	DirAccess.make_dir_recursive_absolute(zip_path.get_base_dir())
	var r := Evidence.write_archive(TMP, zip_path, name, ident, "2026-10-07T12:00:00")
	check(r["ok"], "written and verified (%s)" % str(r["error"]))
	check_eq(r["files"], 12, "the project's files")
	var reader := ZIPReader.new()
	check_eq(reader.open(zip_path), OK, "opens as a zip")
	var entries := Evidence.archive_file_entries(reader)
	check_eq(entries.size(), 13, "SNAPSHOT.txt and the files")
	check_eq(entries[0], name + "/SNAPSHOT.txt", "the manifest comes first")
	for e in reader.get_files():
		check(e.begins_with(name + "/") and not e.contains("\\") and not e.begins_with("/"), "relative, forward slashes, one top folder: %s" % e)
	check(not reader.file_exists(name + "/.godot/cache.bin") and not reader.file_exists(name + "/tests/reports/last_report.txt"), "no cache, no reports")
	check_eq(reader.read_file(name + "/scripts/sub/b.gd").get_string_from_utf8(), "extends Node\n", "contents are the files'")
	check_eq(reader.read_file(name + "/docs/empty.txt").size(), 0, "an empty file stays empty")
	var note := reader.read_file(name + "/SNAPSHOT.txt")
	var manifest := note.get_string_from_utf8()
	check(manifest.contains(ident["id"]) and manifest.contains(ident["source"]) and manifest.contains(ident["settings"]) and manifest.contains(ident["tests"]), "the manifest carries the id and the three hashes")
	reader.close()
	var files := Evidence.archive_files(TMP)
	check_eq(Evidence.verify_archive(TMP, zip_path, name, files, note), "", "the archive matches the files")
	_write("scripts/a.gd", "extends Node2D\n")
	var problem := Evidence.verify_archive(TMP, zip_path, name, files, note)
	check(problem.contains("scripts/a.gd"), "a file that changed after the archive was made is named (%s)" % problem)


func test_a_missing_folder_is_reported_not_crashed() -> void:
	var ident := Evidence.identity(TMP)
	allow_errors(2)
	var r := Evidence.write_archive(TMP, ProjectSettings.globalize_path(OUT + "/no/such/folder/x.zip"), "x", ident, "t")
	check(not r["ok"] and str(r["error"]) != "", "a clear error: %s" % str(r["error"]))


func test_the_real_project_archive_would_hold_what_matters() -> void:
	var files := Evidence.archive_files("res://")
	for must in ["project.godot", ".gitattributes", ".gitignore", "run_tests.bat", "snapshot.bat", "tests/evidence.gd", "tests/snapshot.gd", "tests/test_runner.gd", "scripts/movement/spider_motor.gd", "docs/SESSION_LOG.md"]:
		check(files.has(must), "the archive would include %s" % must)
	for f in files:
		if f.begins_with(".godot/") or f.begins_with("tests/reports/"):
			check(false, "must not be archived: %s" % f)
			break


func _write(rel: String, text: String) -> void:
	var path := ProjectSettings.globalize_path(TMP + "/" + rel)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _rm_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for sub in dir.get_directories():
		_rm_tree(path + "/" + sub)
	for f in dir.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + "/" + f))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
