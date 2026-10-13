extends "res://tests/prey_test_case.gd"

func after_each() -> void:
	runner.get_tree().paused = false
	settings.set_value("ui_scale", 1.0)
	runner.get_tree().root.size = Vector2i(1280, 720)

func _menu() -> void:
	use_windowsill = true
	show_start_menu = true
	await spawn_prey_world(floor_pose(-25,6,-90),0,PREY_SEED,true)
	await process_frames(4)

func _choices() -> void:
	for i in 1000:
		if world.caught_panel.shown_seconds >= 3.1:
			return
		await process_frames(1)

func _key(code: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frames(2)
	ev.pressed = false
	Input.parse_input_event(ev)
	await process_frames(2)

func _pad(button: JoyButton) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frames(2)
	ev.pressed = false
	Input.parse_input_event(ev)
	await process_frames(2)

func test_start_menu_keyboard_dpad_stick_and_a_reach_the_focused_action() -> void:
	await _menu()
	var menu: Node = world.start_menu
	menu._new.grab_focus()
	await _key(KEY_DOWN)
	check(menu._free.has_focus(),"keyboard down skips hidden Easy")
	await _pad(JOY_BUTTON_DPAD_DOWN)
	check(menu._notebook.has_focus(),"D-pad down reaches notebook")
	var ev := InputEventJoypadMotion.new()
	ev.axis = JOY_AXIS_LEFT_Y
	ev.axis_value = -1.0
	Input.parse_input_event(ev)
	await process_frames(3)
	ev.axis_value = 0.0
	Input.parse_input_event(ev)
	check(menu._free.has_focus(),"left stick moves focus back")
	menu._notebook.grab_focus()
	await _pad(JOY_BUTTON_A)
	check(world.notebook_panel.is_open(),"A activates focused Notebook")
	check(world.notebook_panel.layer > menu.layer,"notebook draws above start menu")

func test_end_screen_a_activates_notebook_instead_of_default_continuation() -> void:
	await _menu()
	world.start_menu._close()
	world.end_life("starved")
	await _choices()
	world.caught_panel._notebook.grab_focus()
	var original := world
	await _pad(JOY_BUTTON_A)
	if check(is_instance_valid(original),"A must not replace this world when Notebook has focus"):
		check(original.notebook_panel.is_open(),"focused notebook opens")

func test_large_menu_with_continue_and_easy_and_end_stay_on_screen() -> void:
	await _menu()
	var window := runner.get_tree().root
	window.size = Vector2i(1920,1080)
	settings.set_value("ui_scale",1.5)
	world.start_menu._close()
	await physics_frames(20)
	world.prey.ensure_ready()
	world.habitat_loop.request_rest()
	await physics_frames(3)
	world.habitat_loop.stop_rest()
	world.progress.finished_main_life = true
	world.start_menu.open()
	await process_frames(5)
	check(window.get_visible_rect().grow(1).encloses(world.start_menu._panel.get_global_rect()),"all-options menu fits")
	world.start_menu._close()
	world.end_life("wasp")
	await _choices()
	check(window.get_visible_rect().grow(1).encloses(world.caught_panel._box.get_global_rect()),"end summary and three choices fit")
	settings.set_value("ui_scale",1.0)

func test_new_life_confirmation_belongs_to_the_selected_mode() -> void:
	await _menu()
	world.start_menu._close()
	await physics_frames(20)
	world.prey.ensure_ready()
	world.habitat_loop.request_rest()
	await physics_frames(3)
	world.progress.finished_main_life = true
	world.start_menu.open()
	check(not world.start_menu.new_life(true),"Easy asks first")
	check(not world.start_menu.new_life(false),"switching to Standard asks again")
	check(world.start_menu.new_life(false),"second Standard press confirms")
