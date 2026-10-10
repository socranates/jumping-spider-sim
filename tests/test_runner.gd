extends Node
## Discovers and runs the test scripts in tests/unit and tests/integration, prints each result
## and writes tests/reports/last_report.txt. Exit code 1 on any failure, any unexpected engine
## error, or when no test ran.
## Run: godot --headless --path . res://tests/test_runner.tscn   (optional: -- --seed=123)
## Filters (after --, so the whole suite can be run in parts):
##   --only=unit,integration,gates  any comma-separated mix of the three groups. "unit" is tests/unit,
##       "gates" the acceptance-gate tests (tests/integration/test_m0*.gd: M01, M02, M03, test_p0*.gd: P01, test_a0*.gd: A01 and
##       test_l0*.gd: L01), and
##       "integration" every other file in tests/integration. Without --only everything runs.
##   --part=i/n  after --only, run the i-th of n contiguous slices of the selected files (sorted by
##       name), for example --only=integration --part=1/2.
##   --files=a,b  (a developer convenience) only the selected files whose names contain one of the strings.
## The report and the SUMMARY line state the filter. A filter that selects no test is a failure, like
## any run in which no test ran.
## The report header carries the source, settings and tests hashes and the evidence id (tests/evidence.gd, A-020);
## snapshot.bat keeps a complete archive of that state under the same id.

const Evidence := preload("res://tests/evidence.gd")

const REPORT_DIR := "res://tests/reports"
const REPORT_PATH := "res://tests/reports/last_report.txt"
## Reports written by tests, and the test file that writes each. A report is removed before a run in which its test
## runs, like the main report, so that it always belongs to the run that just happened; a run that does not include
## its test leaves it alone.
const TEST_REPORTS := {
	"res://tests/reports/m01_report.txt": "test_m01_route.gd",
	"res://tests/reports/m02_report.txt": "test_m02_jumps.gd",
	"res://tests/reports/m03_report.txt": "test_m03_tether.gd",
	"res://tests/reports/p01_report.txt": "test_p01_perception.gd",
	"res://tests/reports/a01_report.txt": "test_a01_fly_evidence.gd",
	"res://tests/reports/l01_report.txt": "test_l01_feeding.gd",
	"res://tests/reports/catch_camera_report.txt": "test_catch_camera.gd",
	"res://tests/reports/t07_cost_report.txt": "test_prey_cost.gd",
}
const UNIT_DIR := "res://tests/unit"
const INTEGRATION_DIR := "res://tests/integration"
## test_m01_route.gd, test_m02_jumps.gd, test_m03_tether.gd (movement gates), test_p01_perception.gd (perception gate P01),
## test_a01_fly_evidence.gd (prey gate A01) and test_l01_feeding.gd (feeding gate L01)
const GATE_PREFIXES := ["test_m0", "test_p0", "test_a0", "test_l0"]
const GROUPS := ["unit", "integration", "gates"]
const DEFAULT_SEED := 20261005
## The whole suite takes about 980 s of real time in the Linux VM (chunk 7B: unit 1 s, integration 843 s, gates 138 s; it was 676 s in chunk 7A,
## 560 s in 6B and 345 s in 6A, and this was 900 s, 600 s and 420 s then), so this is set well above it: a slower PC still has room before it fires.
const WATCHDOG_SECONDS := 1500.0


## Counts engine errors (push_error, script errors) so a test that trips one cannot pass quietly.
class ErrorLogger extends Logger:
	var mutex := Mutex.new()
	var count: int = 0
	var messages: PackedStringArray = PackedStringArray()

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		mutex.lock()
		count += 1
		if messages.size() < 50:
			messages.append("%s:%d %s %s" % [file, line, code, rationale])
		mutex.unlock()


var fixture_seed: int = DEFAULT_SEED
var only_groups: Array[String] = []   # empty: every group
var part_index: int = 1
var part_count: int = 1
var file_filters: PackedStringArray = PackedStringArray()
var _filter_error: String = ""
var _logger := ErrorLogger.new()
var _results: Array[Dictionary] = []   # {name, status, detail, ms}
var _elapsed: float = 0.0
var _finished: bool = false
var _current: String = ""
var _accounted_errors: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			fixture_seed = int(arg.substr(7))
		elif arg.begins_with("--only="):
			for g in arg.substr(7).split(",", false):
				var group := g.strip_edges().to_lower()
				if not GROUPS.has(group):
					_filter_error = "unknown --only group '%s' (use unit, integration, gates)" % group
				elif not only_groups.has(group):
					only_groups.append(group)
			if only_groups.is_empty() and _filter_error == "":
				_filter_error = "--only names no group"
		elif arg.begins_with("--files="):
			file_filters = arg.substr(8).split(",", false)
		elif arg.begins_with("--part="):
			var bits := arg.substr(7).split("/")
			if bits.size() != 2 or not bits[0].is_valid_int() or not bits[1].is_valid_int() or int(bits[1]) < 1 or int(bits[0]) < 1 or int(bits[0]) > int(bits[1]):
				_filter_error = "bad --part '%s' (use i/n with 1 <= i <= n)" % arg.substr(7)
			else:
				part_index = int(bits[0])
				part_count = int(bits[1])
	var stale: Array = [REPORT_PATH]
	if _filter_error == "":
		var running := PackedStringArray()
		for test_path in _discover():
			running.append(test_path.get_file())
		for path: String in TEST_REPORTS:
			if running.has(TEST_REPORTS[path]):
				stale.append(path)
	for path: String in stale:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	OS.add_logger(_logger)
	_run()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > WATCHDOG_SECONDS and not _finished:
		_record(_current if _current != "" else "<runner>", "FAIL", "timed out after %d s" % int(WATCHDOG_SECONDS), 0)
		_finish()


func _run() -> void:
	await get_tree().process_frame
	if _filter_error != "":
		_record("<runner>", "FAIL", _filter_error, 0)
		_finish()
		return
	for path in _discover():
		var script: Script = load(path)
		if script == null or not script.can_instantiate():
			_record(path, "FAIL", "script failed to load", 0)
			continue
		var case = script.new()
		var names: Array[String] = []
		for m in case.get_method_list():
			if String(m["name"]).begins_with("test_"):
				names.append(String(m["name"]))
		names.sort()
		for method in names:
			if _finished:
				return
			await _run_one(case, path.get_file(), method)
	_finish()


## The test files the filter selects, unit files first, each group sorted by name.
func _discover() -> Array[String]:
	var out: Array[String] = []
	for dir_path in [UNIT_DIR, INTEGRATION_DIR]:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var files := Array(dir.get_files())
		files.sort()
		for f in files:
			var file_name := String(f)
			if file_name.begins_with("test_") and file_name.ends_with(".gd") and _group_selected(_group_of(dir_path, file_name)) and _file_selected(file_name):
				out.append(dir_path + "/" + file_name)
	if part_count <= 1:
		return out
	var lo := int(floor(float(out.size()) * float(part_index - 1) / float(part_count)))
	var hi := int(floor(float(out.size()) * float(part_index) / float(part_count)))
	return out.slice(lo, hi)


func _group_of(dir_path: String, file_name: String) -> String:
	if dir_path == UNIT_DIR:
		return "unit"
	for prefix: String in GATE_PREFIXES:
		if file_name.begins_with(prefix):
			return "gates"
	return "integration"


func _file_selected(file_name: String) -> bool:
	if file_filters.is_empty():
		return true
	for f in file_filters:
		if file_name.contains(f):
			return true
	return false


func _group_selected(group: String) -> bool:
	return only_groups.is_empty() or only_groups.has(group)


## How the run was filtered, for the report and the SUMMARY line: "all" or "only=unit,gates part=1/2".
func filter_text() -> String:
	if only_groups.is_empty() and part_count <= 1 and file_filters.is_empty():
		return "all"
	var groups := ",".join(PackedStringArray(only_groups)) if not only_groups.is_empty() else "unit,integration,gates"
	var text := "only=%s" % groups
	if part_count > 1:
		text += " part=%d/%d" % [part_index, part_count]
	if not file_filters.is_empty():
		text += " files=%s" % ",".join(file_filters)
	return text


func _run_one(case, file_name: String, method: String) -> void:
	_current = "%s::%s" % [file_name, method]
	case.runner = self
	case.fixture_seed = fixture_seed
	case.rng = RandomNumberGenerator.new()
	case.rng.seed = fixture_seed
	case.failures = PackedStringArray()
	case.skipped_reason = ""
	case.allowed_errors = 0
	case.checks = 0
	case.sandbox = Node.new()
	add_child(case.sandbox)
	var errors_before := _logger.count
	var started := Time.get_ticks_msec()
	await case.before_each()
	await case.call(method)
	await case.after_each()
	var ms := Time.get_ticks_msec() - started
	var new_errors := _logger.count - errors_before
	_accounted_errors += new_errors
	var unexpected: int = maxi(0, new_errors - int(case.allowed_errors))
	if case.skipped_reason != "":
		_record(_current, "NOT RUN", case.skipped_reason, ms)
	else:
		var problems: PackedStringArray = case.failures
		if unexpected > 0:
			problems.append("%d unexpected engine error(s), first: %s" % [unexpected, _first_error_after(errors_before)])
		if case.checks == 0 and problems.is_empty():
			problems.append("the test made no checks")
		if problems.is_empty():
			var note := ""
			if new_errors > 0:
				note = ", %d expected engine error(s) printed above" % new_errors
			_record(_current, "PASS", "%d checks%s" % [case.checks, note], ms)
		else:
			_record(_current, "FAIL", "; ".join(problems), ms)
	case.sandbox.free()
	_current = ""


func _first_error_after(index: int) -> String:
	_logger.mutex.lock()
	var text := ""
	if index < _logger.messages.size():
		text = _logger.messages[index]
	elif not _logger.messages.is_empty():
		text = _logger.messages[_logger.messages.size() - 1]
	_logger.mutex.unlock()
	return text


func _record(test_name: String, status: String, detail: String, ms: int) -> void:
	_results.append({"name": test_name, "status": status, "detail": detail, "ms": ms})
	print("%-8s %s  [%d ms]  %s" % [status, test_name, ms, detail])


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var stray := _logger.count - _accounted_errors
	if stray > 0:
		_record("<runner>", "FAIL", "%d engine error(s) outside any test, first: %s" % [stray, _first_error_after(_accounted_errors)], 0)
	var passed := 0
	var failed := 0
	var not_run := 0
	for r in _results:
		match r["status"]:
			"PASS":
				passed += 1
			"FAIL":
				failed += 1
			_:
				not_run += 1
	var total := _results.size()
	var ran := passed + failed
	var ok := failed == 0 and ran > 0
	var summary := "SUMMARY tests=%d passed=%d failed=%d not_run=%d seed=%d filter=%s result=%s" % [total, passed, failed, not_run, fixture_seed, filter_text().replace(" ", ","), "PASS" if ok else "FAIL"]
	if ran == 0:
		summary += " (no test ran)"
	var ident := Evidence.identity("res://")
	var lines := PackedStringArray()
	lines.append("Jumping Spider Sim test report")
	lines.append("timestamp_utc: %sZ" % Time.get_datetime_string_from_system(true))
	var v := Engine.get_version_info()
	lines.append("engine: Godot %d.%d.%d.%s.%s.%s" % [v["major"], v["minor"], v["patch"], v["status"], v["build"], str(v["hash"]).substr(0, 9)])
	lines.append("platform: %s" % OS.get_name())
	lines.append("renderer_setting: %s" % str(ProjectSettings.get_setting("rendering/renderer/rendering_method")))
	lines.append("renderer_active: %s" % RenderingServer.get_current_rendering_method())
	lines.append("physics_engine: %s" % str(ProjectSettings.get_setting("physics/3d/physics_engine")))
	lines.append("source_hash_md5: %s (scripts, scenes, data)" % ident["source"])
	lines.append("settings_hash_md5: %s (project.godot)" % ident["settings"])
	lines.append("tests_hash_md5: %s (tests/ scripts and scenes, not tests/reports)" % ident["tests"])
	lines.append("evidence_id: %s (keeps a copy of this state: snapshot.bat writes tests/reports/snapshots/DATE_%s.zip)" % [ident["id"], ident["id"]])
	lines.append("fixture_seed: %d" % fixture_seed)
	lines.append("filter: %s" % filter_text())
	lines.append("tests: %d" % total)
	lines.append("passed: %d" % passed)
	lines.append("failed: %d" % failed)
	lines.append("not_run: %d" % not_run)
	lines.append("result: %s" % ("PASS" if ok else "FAIL"))
	lines.append("")
	for r in _results:
		lines.append("%-8s %s  %s" % [r["status"], r["name"], r["detail"]])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT_DIR))
	var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if file == null:
		print("could not write %s (error %d)" % [REPORT_PATH, FileAccess.get_open_error()])
		ok = false
	else:
		file.store_string("\n".join(lines) + "\n")
		file.close()
	print(Evidence.describe(ident))
	print(summary)
	OS.remove_logger(_logger)
	get_tree().quit(0 if ok else 1)
