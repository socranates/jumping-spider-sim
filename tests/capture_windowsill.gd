extends SceneTree
## Scripted stills for visual inspection, never claimed as a human playtest.
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	world.prey_seed = 4242
	root.add_child(world)
	for i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/reports/shots"))
	root.get_texture().get_image().save_png("res://tests/reports/shots/t08_spawn.png")
	var overview := Camera3D.new()
	world.add_child(overview)
	overview.position = Vector3(0, 38, 34)
	overview.look_at(Vector3(0, 0, 0))
	overview.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/reports/shots/t08_overview.png")
	quit()
