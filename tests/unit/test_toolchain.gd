extends "res://tests/test_case.gd"
## Guards the pinned toolchain settings that the documentation promises.


func test_pinned_engine_and_project_settings() -> void:
	var v := Engine.get_version_info()
	check_eq(int(v["major"]), 4, "Godot major version")
	check_eq(int(v["minor"]), 7, "Godot minor version")
	check_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")), "gl_compatibility", "renderer")
	check_eq(str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile")), "gl_compatibility", "mobile renderer")
	check_eq(str(ProjectSettings.get_setting("physics/3d/physics_engine")), "Jolt Physics", "physics engine")
	check_eq(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")), 60, "physics ticks per second")
	check_eq(bool(ProjectSettings.get_setting("physics/common/physics_interpolation")), true, "physics interpolation")
	check_eq(str(ProjectSettings.get_setting("application/run/main_scene")), "res://scenes/main.tscn", "main scene")
	check_eq(Engine.physics_ticks_per_second, 60, "the running engine uses 60 ticks")


func test_autoloads_are_registered() -> void:
	check(runner.get_node_or_null("/root/Settings") != null, "Settings autoload")
	check(runner.get_node_or_null("/root/InputSetup") != null, "InputSetup autoload")
