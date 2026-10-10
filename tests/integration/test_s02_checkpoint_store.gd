extends "res://tests/prey_test_case.gd"
## Gate S02 (spec 22, 25): a truncated or corrupt checkpoint leaves the previous valid one available; an unsupported schema gives a useful
## error and is left untouched. Also: the record is refused when it is internally inconsistent (validation before anything is built), the
## temporary file of an interrupted write is never read as a checkpoint, and the pause menu's checkpoint action is off, with the reason,
## until there is something to return to. Files go to a test folder under user://, never the player's saves.

const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const CheckpointStore = preload("res://scripts/persistence/checkpoint_store.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")

const DIR := "user://jss_test_s02"

var store: CheckpointStore


func before_each() -> void:
	super.before_each()
	store = CheckpointStore.new(DIR)
	store.wipe()


func after_each() -> void:
	if store != null:
		store.wipe()
	super.after_each()


## A real checkpoint record from the windowsill with `count` flies, made by resting in the crack.
func make_record(count: int = 2, ticks: int = 60) -> Dictionary:
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25, 6, -90), count, 4242)
	await run_ticks(ticks)
	var loop: Node = world.habitat_loop
	loop.set_physics_process(false)
	loop.step(1.0 / 60.0, true, false)
	loop.set_physics_process(true)
	return world.last_checkpoint


func read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func same(a: Dictionary, b: Dictionary) -> bool:
	return CheckpointStore.canonical(a) == CheckpointStore.canonical(b)


func test_save_and_load_round_trip_and_keep_the_previous_as_backup() -> void:
	var first := await make_record(2, 30)
	var r1: Dictionary = store.save(first)
	check(bool(r1["ok"]), "the first checkpoint is written: %s %s" % [r1["message"], "; ".join(r1["errors"])])
	check(not FileAccess.file_exists(store.temp_path()), "no temporary file is left behind")
	var got := store.load_best()
	check(bool(got["ok"]) and str(got["source"]) == "current", "it loads from the current file")
	check(same(got["record"], first), "exactly the record that was saved")
	await run_ticks(60)
	var second: Dictionary = Checkpoint.capture(world)
	var r2: Dictionary = store.save(second)
	check(bool(r2["ok"]), "the second is written")
	check(FileAccess.file_exists(store.backup_path()), "the first is kept as the backup")
	check(same(CheckpointStore.decode(read(store.backup_path()))["record"], first), "the backup is the first checkpoint")
	check(same(store.load_best()["record"], second), "the newest is loaded")


func test_a_truncated_checkpoint_falls_back_to_the_previous_and_is_not_touched() -> void:
	var first := await make_record(2, 30)
	store.save(first)
	await run_ticks(30)
	store.save(Checkpoint.capture(world))
	var text := read(store.main_path())
	var cut := text.substr(0, text.length() / 2)
	write(store.main_path(), cut)
	var got := store.load_best()
	check(bool(got["ok"]), "a checkpoint is still available")
	check_eq(str(got["source"]), "backup", "the previous one")
	check(same(got["record"], first), "and it is the previous checkpoint")
	check(str(got["message"]).contains("cut short") or str(got["message"]).contains("not readable"), "the message says why: %s" % got["message"])
	check_eq(read(store.main_path()), cut, "loading did not change the damaged file")


func test_a_changed_number_fails_the_checksum() -> void:
	var first := await make_record(1, 30)
	store.save(first)
	await run_ticks(30)
	var second: Dictionary = Checkpoint.capture(world)
	store.save(second)
	var text := read(store.main_path())
	var data: Dictionary = JSON.parse_string(text)
	data["checkpoint"]["needs"]["energy"] = 0.99
	write(store.main_path(), JSON.stringify(data, "", true, true))
	var main := CheckpointStore.decode(read(store.main_path()))
	check(not bool(main["ok"]), "the edited file is refused")
	check("; ".join(main["errors"]).contains("checksum"), "because the checksum does not match: %s" % "; ".join(main["errors"]))
	check(same(store.load_best()["record"], first), "the backup is used instead")


func test_a_newer_schema_is_reported_and_left_untouched() -> void:
	var rec := await make_record(1, 10)
	store.save(rec)
	var data: Dictionary = JSON.parse_string(read(store.main_path()))
	data["checkpoint"]["schema_version"] = Checkpoint.SCHEMA_VERSION + 1
	var newer := JSON.stringify(data, "", true, true)
	write(store.main_path(), newer)
	var got := store.load_best()
	check(not bool(got["ok"]), "nothing to load (there is no backup)")
	check(str(got["message"]).contains("newer version"), "the message says it is from a newer version: %s" % got["message"])
	check_eq(read(store.main_path()), newer, "the newer file is left exactly as it was")
	var errors := Checkpoint.validate(data["checkpoint"])
	check(errors.size() == 1 and errors[0].contains("schema %d" % (Checkpoint.SCHEMA_VERSION + 1)), "validation names the schema: %s" % "; ".join(errors))


func test_an_interrupted_write_never_costs_the_last_good_checkpoint() -> void:
	var first := await make_record(2, 30)
	store.save(first)
	# a write that stopped half way: a temporary file with half a checkpoint in it
	var half := CheckpointStore.encode(Checkpoint.capture(world))
	write(store.temp_path(), half.substr(0, half.length() / 3))
	check(same(store.load_best()["record"], first), "the temporary file is never read as a checkpoint")
	await run_ticks(20)
	var second: Dictionary = Checkpoint.capture(world)
	check(bool(store.save(second)["ok"]), "the next save works over the stale temporary file")
	check(same(store.load_best()["record"], second), "and is the one loaded")
	# a damaged current file does not push out a good backup
	write(store.main_path(), "{\"format\": \"jumping-spider-sim checkpoint\", \"checks")
	var third: Dictionary = Checkpoint.capture(world)
	check(bool(store.save(third)["ok"]), "saving over a damaged current file works")
	var bak := CheckpointStore.decode(read(store.backup_path()))
	check(bool(bak["ok"]) and same(bak["record"], first), "the good backup was kept, not replaced by the damaged file")
	check(same(store.load_best()["record"], third), "the new checkpoint is current")


func test_a_record_that_contradicts_itself_is_refused_with_a_reason() -> void:
	var rec := await make_record(2, 30)
	check(Checkpoint.validate(rec).is_empty(), "the real record is valid")
	var cases := {
		"needs: the reserves or their ledger are not a valid record": func(r: Dictionary) -> void: r["needs"]["energy"] = NAN,
		"repeated id": func(r: Dictionary) -> void: r["prey"]["flies"][1]["id"] = r["prey"]["flies"][0]["id"],
		"a free fly carries a capture": func(r: Dictionary) -> void: r["prey"]["flies"][0]["captured_by"] = "spider",
		"not a recorded capture": func(r: Dictionary) -> void:
			r["needs"]["granted_by_source"] = {"capture:spider:fly_99": 0.1}
			r["needs"]["granted_total"] = 0.1,
		"unknown perch": func(r: Dictionary) -> void: r["prey"]["flies"][0]["perch"] = "under_the_rug",
		"not part of the habitat": func(r: Dictionary) -> void: r["player"]["surface_id"] = "moon",
		"outside the habitat": func(r: Dictionary) -> void: r["player"]["position"] = [500.0, 0.0, 0.0],
		"unknown event phase": func(r: Dictionary) -> void: r["habitat"]["phase"] = "storm",
		"cannot be restored": func(r: Dictionary) -> void: r["prey"]["flies"][0]["state"] = "CONSUMED",
		"not a whole number written as text": func(r: Dictionary) -> void: r["prey"]["flies"][0]["rng_state"] = 12345,
		"habitat content": func(r: Dictionary) -> void: r["content_revision"] = "kitchen-v9",
		"missing section": func(r: Dictionary) -> void: r.erase("prey"),
	}
	for expected: String in cases:
		var bad := rec.duplicate(true)
		(cases[expected] as Callable).call(bad)
		var errors := Checkpoint.validate(bad)
		check(not errors.is_empty() and "; ".join(errors).contains(expected), "%s: %s" % [expected, "; ".join(errors)])
	check(not bool(store.save(rec.duplicate(true).merged({"kind": "photo"}, true))["ok"]), "an invalid record is never written")
	check(not FileAccess.file_exists(store.main_path()), "nothing was written")


func test_the_pause_menu_offers_the_checkpoint_only_when_there_is_one() -> void:
	use_windowsill = true
	await spawn_prey_world(floor_pose(-25, 6, -90), 0, 4242)
	var menu := PauseMenu.new()
	menu.settings = settings
	menu.world = world
	sandbox.add_child(menu)
	menu._refresh_checkpoint()
	var button := menu.find_child("ReturnToCheckpoint", true, false) as Button
	var label := menu.find_child("CheckpointStatus", true, false) as Label
	check(button != null and button.disabled, "off before any rest")
	check(label.text.contains("rest in the silk-lined crack"), "and says how to make one: %s" % label.text)
	var loop: Node = world.habitat_loop
	loop.set_physics_process(false)
	loop.step(1.0 / 60.0, true, false)
	menu._refresh_checkpoint()
	check(not button.disabled, "on after resting")
	check(label.text.contains("anything since is undone"), "and says it is recovery of the whole world, not a save of the present: %s" % label.text)
	check(not label.text.to_lower().contains("save current"), "never 'save current position'")
	menu.queue_free()
