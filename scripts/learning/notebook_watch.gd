extends Node
## Watches play for the moments the naturalist's notebook opens pages on (LEARN-01). It only listens and reads: it changes nothing the
## spider does, knows or senses. Signals where the game already has them (a committed jump, a category refined to fly-like prey, a catch,
## a meal, a felt vibration, a buzz caption, a rest), and a light look each frame for the rest (the spider-eye view, time in it, the motion
## shimmer). It pauses with the game.

const Observation = preload("res://scripts/perception/observation.gd")

var notebook: Node           # FieldNotebook
var spider: Node3D           # SpiderMotor: jump_committed
var camera_rig: Node3D       # eye_view
var eye_overlay: CanvasLayer # movers (the motion shimmer)
var memory: RefCounted       # ObservationMemory: category_changed
var prey: Node3D             # PreyDirector: captured
var feeding: Node            # FeedingController: feeding_ended
var vibration: Node          # VibrationSense: felt
var soundscape: Node         # caption
var habitat_loop: Node       # rest_changed, woke (the windowsill only)
var needs: RefCounted        # NeedsModel: energy_changed (hungry, well fed)


func _ready() -> void:
	if notebook == null:
		return
	notebook.notice("start")
	if spider != null and spider.has_signal("jump_committed"):
		spider.jump_committed.connect(func(plan: RefCounted) -> void:
			var origin: Vector3 = plan.get("origin")
			var target: Vector3 = plan.get("target_point")
			notebook.notice_jump(origin.distance_to(target)))
	if memory != null and memory.has_signal("category_changed"):
		memory.category_changed.connect(func(_c: RefCounted, _old: StringName, new_category: StringName) -> void:
			if new_category == Observation.FLY_LIKE_PREY:
				notebook.notice("fly_recognised"))
	if prey != null and prey.has_signal("captured"):
		prey.captured.connect(func(_ev: Dictionary) -> void: notebook.notice("catch"))
	if feeding != null:
		feeding.feeding_ended.connect(func(_reason: String, summary: Dictionary) -> void:
			if float(summary.get("taken", 0.0)) > 0.0:
				notebook.notice("meal"))
	if vibration != null:
		vibration.felt.connect(func(_ev: Dictionary) -> void: notebook.notice("felt"))
	if soundscape != null:
		soundscape.caption.connect(func(text: String) -> void:
			if text.begins_with("[buzzing"):
				notebook.notice("buzz"))
	if habitat_loop != null and habitat_loop.has_signal("woke"):
		habitat_loop.woke.connect(func(_day: int) -> void: notebook.notice("sleep"))
	if needs != null and needs.has_signal("energy_changed"):
		needs.energy_changed.connect(func(_old: float, now: float) -> void:
			if now <= notebook.HUNGRY_AT:
				notebook.notice("hungry")
			elif now >= notebook.WELL_FED_AT:
				notebook.notice("well_fed"))
	if habitat_loop != null and habitat_loop.has_signal("rest_changed"):
		habitat_loop.rest_changed.connect(func(active: bool) -> void:
			if active:
				notebook.notice("rest"))


func _process(delta: float) -> void:
	if notebook == null or camera_rig == null or not is_instance_valid(camera_rig):
		return
	if camera_rig.get("eye_view") == true:
		notebook.notice("eye_view")
		notebook.add_eye_time(delta)
		if eye_overlay != null and is_instance_valid(eye_overlay) and not (eye_overlay.get("movers") as Array).is_empty():
			notebook.notice("shimmer")
