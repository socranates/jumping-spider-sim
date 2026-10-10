extends RefCounted
## Evidence identity (A-020): which source, project settings and tests produced a report, and a way to keep
## a complete copy of exactly that state.
##
## Three hashes, each an md5 over, for every file in sorted order, the text "res://<relative path>" and the
## file's bytes:
##   source_hash_md5    scripts/, scenes/ and data/ (.gd .tscn .tres .json .gdshader). This is the algorithm
##                      the report has used since chunk 2, so the value is unchanged for unchanged sources.
##   settings_hash_md5  project.godot (renderer, physics, input map, autoloads: what a result depends on
##                      besides the code)
##   tests_hash_md5     the scripts and scenes under tests/ (.gd .tscn), not tests/reports
## evidence_id is the first 12 hex digits of the md5 of the three, so it changes when any of them does.
## The snapshot archive (snapshot.bat, tests/snapshot.gd) is named <UTC date>_<evidence_id>.zip and
## carries a SNAPSHOT.txt with the same hashes, so a report and an archive can be matched by name.
##
## Every function takes the project root (default res://) so a unit test can run on a small tree in user://.

const SOURCE_DIRS := ["scripts", "scenes", "data"]
const SOURCE_EXTENSIONS := ["gd", "tscn", "tres", "json", "gdshader"]
const SETTINGS_FILES := ["project.godot"]
const TESTS_DIR := "tests"
const TESTS_EXTENSIONS := ["gd", "tscn"]
const REPORTS_DIR := "tests/reports"
const SNAPSHOT_DIR := "tests/reports/snapshots"
## Left out of a complete archive: the editor's cache and the generated reports (which include the archives).
const ARCHIVE_SKIP := [".git", ".godot", "tests/reports"]
const ID_LENGTH := 12
## Zip entry modification times must be 1980 or later.
const ZIP_MIN_TIME := 315532800


static func _join(root: String, rel: String) -> String:
	if rel == "":
		return root
	return root + rel if root.ends_with("/") else root + "/" + rel


## Relative paths of the files below root/dir_rel with one of the extensions (all files when the list is
## empty), leaving out directories listed in skip (paths relative to root). Hidden files are listed
## when hidden is true. Sorted.
static func list_files(root: String, dir_rel: String, extensions: Array, skip: Array = [], hidden: bool = false) -> Array[String]:
	var out: Array[String] = []
	_walk(root, dir_rel, extensions, skip, hidden, out)
	out.sort()
	return out


static func _walk(root: String, dir_rel: String, extensions: Array, skip: Array, hidden: bool, out: Array[String]) -> void:
	var dir := DirAccess.open(_join(root, dir_rel))
	if dir == null:
		return
	dir.include_hidden = hidden
	for sub in dir.get_directories():
		var sub_rel := sub if dir_rel == "" else dir_rel + "/" + sub
		if not skip.has(sub_rel):
			_walk(root, sub_rel, extensions, skip, hidden, out)
	for f in dir.get_files():
		if extensions.is_empty() or extensions.has(f.get_extension()):
			out.append(f if dir_rel == "" else dir_rel + "/" + f)


## md5 over "res://<rel>" and the bytes of each file, in sorted order of the relative paths.
static func hash_files(root: String, rel_paths: Array[String]) -> String:
	var paths := rel_paths.duplicate()
	paths.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for rel: String in paths:
		ctx.update(("res://" + rel).to_utf8_buffer())
		var bytes := FileAccess.get_file_as_bytes(_join(root, rel))
		if bytes.size() > 0:
			ctx.update(bytes)
	return ctx.finish().hex_encode()


static func source_hash(root: String = "res://") -> String:
	var paths: Array[String] = []
	for d: String in SOURCE_DIRS:
		paths.append_array(list_files(root, d, SOURCE_EXTENSIONS))
	return hash_files(root, paths)


static func settings_hash(root: String = "res://") -> String:
	var paths: Array[String] = []
	for f: String in SETTINGS_FILES:
		if FileAccess.file_exists(_join(root, f)):
			paths.append(f)
	return hash_files(root, paths)


static func tests_hash(root: String = "res://") -> String:
	return hash_files(root, list_files(root, TESTS_DIR, TESTS_EXTENSIONS, [REPORTS_DIR]))


## The first ID_LENGTH hex digits of the md5 of the three hashes.
static func make_id(source: String, settings: String, tests: String) -> String:
	return ("source:%s settings:%s tests:%s" % [source, settings, tests]).md5_text().substr(0, ID_LENGTH)


## {source, settings, tests, id}
static func identity(root: String = "res://") -> Dictionary:
	var s := source_hash(root)
	var c := settings_hash(root)
	var t := tests_hash(root)
	return {"source": s, "settings": c, "tests": t, "id": make_id(s, c, t)}


## The one-line form for reports and the console.
static func describe(ident: Dictionary) -> String:
	return "evidence_id: %s (source %s, settings %s, tests %s)" % [ident["id"], str(ident["source"]).substr(0, 8), str(ident["settings"]).substr(0, 8), str(ident["tests"]).substr(0, 8)]


## <UTC date>_<evidence id>, the archive's file name without .zip and the name of its top folder.
static func archive_name(ident: Dictionary, utc_date: String) -> String:
	return "%s_%s" % [utc_date, ident["id"]]


## Every file of a complete copy of the project: all of root except ARCHIVE_SKIP, hidden files included. Sorted.
static func archive_files(root: String) -> Array[String]:
	return list_files(root, "", [], ARCHIVE_SKIP, true)


## The text of SNAPSHOT.txt, the first entry of an archive.
static func manifest(ident: Dictionary, utc_stamp: String, file_count: int, byte_count: int) -> String:
	var v := Engine.get_version_info()
	var lines := PackedStringArray()
	lines.append("Jumping Spider Sim snapshot")
	lines.append("timestamp_utc: %sZ" % utc_stamp)
	lines.append("engine: Godot %d.%d.%d.%s.%s" % [v["major"], v["minor"], v["patch"], v["status"], v["build"]])
	lines.append(describe(ident))
	lines.append("source_hash_md5: %s (scripts, scenes, data)" % ident["source"])
	lines.append("settings_hash_md5: %s (project.godot)" % ident["settings"])
	lines.append("tests_hash_md5: %s (tests/ scripts and scenes, not tests/reports)" % ident["tests"])
	lines.append("files: %d (%d bytes), everything except .git, .godot and tests/reports" % [file_count, byte_count])
	lines.append("These are the files as they were when the archive was written. Extract the folder and open it as a project.")
	return "\n".join(lines) + "\n"


## Writes a zip of the whole project to zip_path (an absolute path, or res:// or user://), every entry under
## top_folder/ and SNAPSHOT.txt first, then reads the archive back and checks every entry against the file
## it came from. Returns {ok, files, bytes, error}.
static func write_archive(root: String, zip_path: String, top_folder: String, ident: Dictionary, utc_stamp: String) -> Dictionary:
	var files := archive_files(root)
	var total := 0
	for rel in files:
		total += FileAccess.get_file_as_bytes(_join(root, rel)).size()
	var packer := ZIPPacker.new()
	var err := packer.open(zip_path)
	if err != OK:
		return {"ok": false, "files": 0, "bytes": 0, "error": "could not create %s (error %d)" % [zip_path, err]}
	var note := manifest(ident, utc_stamp, files.size(), total).to_utf8_buffer()
	var failure := _add(packer, top_folder + "/SNAPSHOT.txt", note, int(Time.get_unix_time_from_system()))
	for rel in files:
		if failure != "":
			break
		var path := _join(root, rel)
		failure = _add(packer, top_folder + "/" + rel, FileAccess.get_file_as_bytes(path), FileAccess.get_modified_time(path))
	packer.close()
	if failure != "":
		return {"ok": false, "files": files.size(), "bytes": total, "error": failure}
	var problem := verify_archive(root, zip_path, top_folder, files, note)
	return {"ok": problem == "", "files": files.size(), "bytes": total, "error": problem}


static func _add(packer: ZIPPacker, entry: String, bytes: PackedByteArray, mtime: int) -> String:
	var err := packer.start_file(entry, 420, maxi(mtime, ZIP_MIN_TIME))
	if err != OK:
		return "could not add %s (error %d)" % [entry, err]
	if bytes.size() > 0:
		err = packer.write_file(bytes)
		if err != OK:
			packer.close_file()
			return "could not write %s (error %d)" % [entry, err]
	err = packer.close_file()
	if err != OK:
		return "could not finish %s (error %d)" % [entry, err]
	return ""


## The file entries of an open archive in order (the packer also writes an entry for each folder, ending in a slash).
static func archive_file_entries(reader: ZIPReader) -> PackedStringArray:
	var out := PackedStringArray()
	for e in reader.get_files():
		if not e.ends_with("/"):
			out.append(e)
	return out


## "" when the archive holds exactly SNAPSHOT.txt and the listed files with the same bytes; otherwise the first problem.
static func verify_archive(root: String, zip_path: String, top_folder: String, files: Array[String], note: PackedByteArray) -> String:
	var reader := ZIPReader.new()
	var err := reader.open(zip_path)
	if err != OK:
		return "could not read back %s (error %d)" % [zip_path, err]
	var problem := ""
	var count := archive_file_entries(reader).size()
	if count != files.size() + 1:
		problem = "the archive holds %d files, expected %d" % [count, files.size() + 1]
	elif reader.read_file(top_folder + "/SNAPSHOT.txt") != note:
		problem = "SNAPSHOT.txt differs from what was written"
	else:
		for rel in files:
			var entry := top_folder + "/" + rel
			if not reader.file_exists(entry):
				problem = "missing from the archive: %s" % rel
				break
			if reader.read_file(entry) != FileAccess.get_file_as_bytes(_join(root, rel)):
				problem = "differs from the file: %s" % rel
				break
	reader.close()
	return problem
