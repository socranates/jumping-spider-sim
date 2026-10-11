extends "res://tests/prey_test_case.gd"
## LEARN-01, the naturalist's notebook (Nathan, 2026-10-11: "this could also teach people about jumping spiders right? ... presenting facts
## maybe as you learn to play"):
##   * every page is complete, short and sourced, and names a trigger the game has;
##   * a page opens once, the first time its trigger happens, and the notebook keeps them (the player's own file; never a test's);
##   * play opens pages: the start, a jump (and a far and a long one), the spider-eye view and time in it, the motion shimmer, a fly
##     recognised, a catch, a meal, a felt vibration, a buzz, a rest;
##   * on screen: N / D-pad up or the Esc menu opens it and the game waits; Esc, B or N closes it; only found pages are listed, with no count
##     of pages left; a short note says when a page opens, unless the player turns that off;
##   * the key and the button can be changed like the others.

const FieldNotebook = preload("res://scripts/learning/field_notebook.gd")
const NotebookPanel = preload("res://scripts/presentation/notebook_panel.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const TEMP := "user://jss_test_notebook.cfg"


func after_each() -> void:
	if FileAccess.file_exists(TEMP):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP))
	sandbox.get_tree().paused = false
	super.after_each()


func _book(path: String = "") -> Node:
	var nb := FieldNotebook.new()
	nb.path = path
	sandbox.add_child(nb)
	return nb


func test_every_page_is_complete_short_and_sourced() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FieldNotebook.PAGES_PATH))
	var nb := _book()
	check_eq(nb.pages.size(), (raw["pages"] as Array).size(), "no page was left out for a missing field or an unknown trigger")
	var ids := {}
	for p: Dictionary in nb.pages:
		check(FieldNotebook.problems(p).is_empty(), "page %s is complete" % str(p["id"]))
		check(not ids.has(str(p["id"])), "page ids are unique (%s)" % str(p["id"]))
		ids[str(p["id"])] = true
		check(str(p["text"]).length() <= 520, "page %s is short enough to read in a moment (%d characters)" % [str(p["id"]), str(p["text"]).length()])
		for s: Variant in p["sources"]:
			check(str(s).length() > 20 and str(s).contains("("), "page %s names a full source: %s" % [str(p["id"]), str(s)])
	check(nb.pages.size() >= 12, "there is a first set of pages (%d)" % nb.pages.size())


func test_a_page_opens_once_and_the_notebook_keeps_them() -> void:
	var nb := _book(TEMP)
	var seen: Array[String] = []
	nb.page_opened.connect(func(id: String) -> void: seen.append(id))
	check_eq(nb.notice("jump"), ["dragline"] as Array[String], "the first jump opens the dragline page")
	check(nb.notice("jump").is_empty(), "and only once")
	nb.notice_jump(9.0)
	check(nb.is_open("legs_push") and nb.is_open("depth_blur"), "a long leap opens the far- and long-jump pages")
	nb.add_eye_time(19.0)
	check(not nb.is_open("moving_retinas"), "19 s in the eye view: not yet")
	nb.add_eye_time(2.0)
	check(nb.is_open("moving_retinas") and not nb.is_open("green_uv"), "20 s opens the moving-retina page")
	nb.add_eye_time(40.0)
	check(nb.is_open("green_uv"), "a minute opens the colour page")
	check_eq(seen, nb.opened, "each page was announced once, in order")
	var again := _book(TEMP)
	again.load_saved()
	check_eq(again.opened, nb.opened, "the notebook comes back as it was")
	check_near(again.eye_seconds, nb.eye_seconds, 0.01, "with the time in the eye view")
	var cfg := ConfigFile.new()
	cfg.set_value("notebook", "opened", PackedStringArray(["dragline", "no_such_page", "dragline"]))
	cfg.set_value("notebook", "eye_seconds", "nonsense")
	cfg.save(TEMP)
	again.load_saved()
	check_eq(again.opened, ["dragline"] as Array[String], "unknown and repeated ids are dropped")
	check_eq(again.eye_seconds, 0.0, "a bad number is read as none")
	var f := FileAccess.open(TEMP, FileAccess.WRITE)
	f.store_string("not a config file [[[")
	f.close()
	again.load_saved()
	check(again.opened.is_empty(), "an unreadable file is an empty notebook")
	allow_errors(1)


func test_play_opens_pages() -> void:
	prey_struggle = false
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED, true)
	var nb: Node = world.notebook
	if not check(nb != null, "a played world has a notebook"):
		return
	check_eq(nb.path, "", "a test world's notebook is never written to the player's file")
	check(nb.is_open("bold_jumper"), "the first page opens at the start")
	add_fly("floor_east_open", 1, true)
	await strike_at(4.0, 11.0)
	check(nb.is_open("dragline"), "a jump opens the dragline page")
	check(not nb.is_open("legs_push"), "a 3.5 WU strike is not a far jump")
	check(nb.is_open("venom"), "a catch opens the bite page")
	world.feeding.feeding_ended.emit("finished", {"taken": 0.2})
	check(nb.is_open("drinking"), "a meal opens its page")
	world.vibration.felt.emit({"kind": "footsteps", "word": "ahead", "strength": 0.5, "direction": Vector3.FORWARD})
	check(nb.is_open("felt"), "a felt vibration opens its page")
	world.soundscape.caption.emit("[buzzing, ahead-left]")
	check(nb.is_open("hearing"), "a buzz opens the hearing page")
	world.soundscape.caption.emit("[air stirs beyond the window]")
	settings.set_value("eye_view", true)
	await wait_until(func() -> bool: return nb.is_open("eight_eyes"), 10)
	check(nb.is_open("eight_eyes"), "the spider-eye view opens the eyes page")
	check(not nb.is_open("motion_first"), "nothing has moved in the surround yet")


func test_the_panel_opens_pauses_lists_only_found_pages_and_closes() -> void:
	var nb := _book()
	nb.notice("start")
	nb.notice("jump")
	var panel := NotebookPanel.new()
	panel.notebook = nb
	panel.settings = settings
	sandbox.add_child(panel)
	check(not panel.is_open(), "closed at first")
	panel.open()
	check(panel.is_open() and sandbox.get_tree().paused, "open: the game waits")
	var list: VBoxContainer = panel.find_child("Pages", true, false)
	await sandbox.get_tree().process_frame
	check_eq(list.get_child_count(), 2, "only the two pages found are listed")
	check_eq(panel.shown, "dragline", "it opens at the newest page")
	var all_text := ""
	for l: Label in [panel.find_child("Title", true, false), panel.find_child("Text", true, false), panel.find_child("InThisGame", true, false), panel.find_child("Sources", true, false)]:
		all_text += l.text + "\n"
	check(all_text.contains("A line before every leap") and all_text.contains("Source: Chen"), "the page shows its title, text and source")
	check(all_text.contains("In this game:"), "and says where the game simplifies")
	check(not all_text.contains(" of 14") and not all_text.contains("/14"), "no count of pages left to find")
	var esc := InputEventAction.new()
	esc.action = "pause"
	esc.pressed = true
	panel._input(esc)
	check(not panel.is_open() and not sandbox.get_tree().paused, "Esc closes it and the game goes on")
	sandbox.get_tree().paused = true   # as the Esc menu leaves it
	panel.open("bold_jumper")
	check_eq(panel.shown, "bold_jumper", "opened at a chosen page")
	panel.close()
	check(sandbox.get_tree().paused, "opened over the Esc menu, closing goes back to the menu, still paused")
	sandbox.get_tree().paused = false


func test_a_new_page_says_so_unless_turned_off() -> void:
	var nb := _book()
	var panel := NotebookPanel.new()
	panel.notebook = nb
	panel.settings = settings
	sandbox.add_child(panel)
	nb.notice("felt")
	var note: Label = panel.find_child("NotebookNote", true, false)
	check(note.visible and note.text.contains("Feeling through the feet") and note.text.contains("N / D-pad up"), "a short note names the page and the key: %s" % note.text)
	panel._process(panel.NOTE_S + 0.1)
	check(not note.visible, "and goes after a few seconds")
	settings.set_value("notebook_notes", false)
	nb.notice("buzz")
	check(not note.visible, "turned off, no note")
	check(nb.is_open("hearing"), "though the page still opens")


func test_the_key_and_button_can_be_changed_and_the_menu_offers_it() -> void:
	check(settings.REMAPPABLE.has("notebook") and settings.PAD_REMAPPABLE.has("notebook"), "the notebook key and button can be changed")
	check_eq(settings.get_key("notebook"), KEY_N, "N by default")
	check_eq(str(settings.pad_name("notebook")), "D-pad up", "D-pad up on a controller")
	await spawn_prey_world(floor_pose(4.0, 7.5, 180.0), 0, PREY_SEED, true)
	var menu: Node = world.pause_menu
	menu.set_paused(true)
	var button: Button = menu.find_child("Notebook", true, false)
	check(button != null and button.visible and button.text.contains("N / D-pad up"), "the Esc menu has a Notebook button")
	button.pressed.emit()
	check(world.notebook_panel.is_open(), "which opens the notebook")
	world.notebook_panel.close()
	check(sandbox.get_tree().paused and menu.visible, "closing it goes back to the menu")
	menu.set_paused(false)
