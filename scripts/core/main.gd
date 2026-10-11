extends Node3D
## Main scene: loads the species and surface profiles and the traversal lab, spawns the spider at
## the lab's spawn point and adds the camera rig, player controller, jump controller with its landing
## patch and HUD, the safety line's input, drawing and anchor cue, pause menu, debug overlay (F3) and
## support view (F4, with the jump arcs, the line's constraint and the developer view of the senses).
## Chunk 6B: the sensor system and the observation memory (spec 7, 19.3) are part of every world, interactive or not, like
## the camera rig: sensing is simulation. Their presentation (edge markers, labels, the last-seen mark, the optional gaze
## footprint, the developer cones) is added only to an interactive world.
## Tests set interactive = false (no input, pause menu or overlay), settings and spawn_override
## before the node enters the tree.

const SpeciesProfile = preload("res://scripts/core/species_profile.gd")
const SurfaceProfile = preload("res://scripts/core/surface_profile.gd")
const SpiderMotor = preload("res://scripts/movement/spider_motor.gd")
const CameraRig = preload("res://scripts/movement/camera_rig.gd")
const PlayerController = preload("res://scripts/movement/player_controller.gd")
const JumpController = preload("res://scripts/movement/jump_controller.gd")
const LandingPatch = preload("res://scripts/presentation/landing_patch.gd")
const JumpHud = preload("res://scripts/presentation/jump_hud.gd")
const JumpDebug = preload("res://scripts/presentation/jump_debug.gd")
const TetherController = preload("res://scripts/movement/tether_controller.gd")
const SilkLines = preload("res://scripts/presentation/silk_lines.gd")
const AnchorCue = preload("res://scripts/presentation/anchor_cue.gd")
const TetherDebug = preload("res://scripts/presentation/tether_debug.gd")
const PauseMenu = preload("res://scripts/presentation/pause_menu.gd")
const DebugOverlay = preload("res://scripts/presentation/debug_overlay.gd")
const SupportDebug = preload("res://scripts/presentation/support_debug.gd")
const SensorSystem = preload("res://scripts/perception/sensor_system.gd")
const ObservationMemory = preload("res://scripts/perception/observation_memory.gd")
const PerceptionHud = preload("res://scripts/presentation/perception_hud.gd")
const GazeOverlay = preload("res://scripts/presentation/gaze_overlay.gd")
const EyeViewOverlay = preload("res://scripts/presentation/eye_view_overlay.gd")
const PerceptionDebug = preload("res://scripts/presentation/perception_debug.gd")
const PreyDebug = preload("res://scripts/presentation/prey_debug.gd")
const LabScene = preload("res://scenes/testbeds/traversal_lab.tscn")
const WindowsillScene = preload("res://scenes/habitats/windowsill.tscn")
const HabitatLoop = preload("res://scripts/habitat/habitat_loop.gd")
const SpiderScene = preload("res://scenes/actors/spider.tscn")
const PreyDirector = preload("res://scripts/prey/prey_director.gd")
const NeedsModel = preload("res://scripts/needs/needs_model.gd")
const FeedingController = preload("res://scripts/needs/feeding_controller.gd")
const NeedsHud = preload("res://scripts/presentation/needs_hud.gd")
const Checkpoint = preload("res://scripts/persistence/checkpoint.gd")
const CheckpointStore = preload("res://scripts/persistence/checkpoint_store.gd")
const SupportMath = preload("res://scripts/movement/support_math.gd")
const MAIN_SCENE_PATH := "res://scenes/main.tscn"

const PROFILE_PATH := "res://data/species/phidippus_audax_prototype.json"
const SPAWN_LIFT := 0.31  # WU above the floor, just over the 0.3 WU collider radius

@export var interactive: bool = true
@export var use_windowsill: bool = false
var habitat_loop: Node
## Chunk 7B: how many flies the world keeps (0 for none). The seed fixes every fly's streams; 0 picks one when the world starts (printed
## in the console and shown in the developer views) in a played world and uses the fixed default seed in a test world.
@export var prey_count: int = 0
@export var prey_seed: int = 0
## Whether a lost fly is replaced (PreyPopulation: after a delay, through a vent, never in view). On in a played world; test worlds switch it off.
@export var prey_replenish: bool = true
## T09b: whether a caught fly struggles and must be held with presses (FeedingController). On in a played world; test worlds switch it off.
@export var prey_struggle: bool = true
var settings: Node
## Optional Transform3D for the spider origin instead of the lab spawn point.
var spawn_override: Variant = null
## T09 (S01-C): a validated checkpoint record to build this world from (set before the node enters the tree). Empty: a new world.
var restore_record: Dictionary = {}
## Why the restore record was refused (then the world starts new), and whether the world was built from a checkpoint.
var restore_errors: PackedStringArray = PackedStringArray()
var restored: bool = false
## Where checkpoints are kept: the player's save folder in a played world; a test names its own folder, and a test world without one keeps
## its checkpoint in memory only, so tests never touch the player's saves.
var checkpoint_dir: String = ""
var checkpoint_store: CheckpointStore
## The newest checkpoint this world made or was built from (also kept when there is no store).
var last_checkpoint: Dictionary = {}
var last_checkpoint_message: String = ""

var lab: Node3D
var spider: SpiderMotor
var camera_rig: CameraRig
var controller: PlayerController
var jump_controller: JumpController
var landing_patch: LandingPatch
var jump_hud: JumpHud
var jump_debug: JumpDebug
var tether_controller: TetherController
var silk_lines: SilkLines
var anchor_cue: AnchorCue
var tether_debug: TetherDebug
var pause_menu: PauseMenu
var overlay: DebugOverlay
var support_debug: SupportDebug
## The senses (every world): the sensor reads the world and the spider's eyes and gaze; the memory holds what it sensed.
var sensor: SensorSystem
var memory: ObservationMemory
## The living prey (chunk 7B): the flies, their perches and the order they act in.
var prey: PreyDirector
## The reserves (energy and rest only) and the feeding that is the one door to them.
var needs: NeedsModel
var feeding: FeedingController
var needs_hud: NeedsHud
var perception_hud: PerceptionHud
var gaze_overlay: GazeOverlay
var eye_overlay: CanvasLayer  # T10a: the spider-eye view's picture (played worlds only)
var perception_debug: PerceptionDebug
var prey_debug: PreyDebug
## Surface profiles by id (data/surfaces).
var surfaces: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if settings == null:
		settings = get_node("/root/Settings")
	var profile := SpeciesProfile.load_file(PROFILE_PATH)
	if profile == null:
		OS.alert("The species profile could not be loaded:\n" + "\n".join(SpeciesProfile.last_errors), "Jumping Spider Sim")
		get_tree().quit(1)
		return
	surfaces = SurfaceProfile.load_dir()
	if surfaces.is_empty():
		OS.alert("The surface profiles could not be loaded:\n" + "\n".join(SurfaceProfile.last_errors), "Jumping Spider Sim")
		get_tree().quit(1)
		return
	if checkpoint_dir == "" and interactive:
		checkpoint_dir = CheckpointStore.DEFAULT_DIR
	if checkpoint_dir != "":
		checkpoint_store = CheckpointStore.new(checkpoint_dir)
	if not restore_record.is_empty():
		_prepare_restore()
	lab = (WindowsillScene if use_windowsill else LabScene).instantiate() as Node3D
	add_child(lab)
	_check_lab_surfaces()
	if restored and lab.has_method("apply_changes"):
		lab.apply_changes(restore_record.get("habitat_changes", []))
	spider = SpiderScene.instantiate() as SpiderMotor
	spider.profile = profile
	spider.surfaces = surfaces
	spider.play_bounds = lab.get_play_bounds()
	spider.bounds_enabled = true
	spider.reach_factor = float(settings.get_value("jump_reach"))
	spider.transform = _spawn_transform()
	add_child(spider)
	settings.setting_changed.connect(_on_setting_changed)
	# The practice perches drop away when a jump is aimed at them; a surface that leaves the world lets go
	# of any line anchored to it (spec 21.2).
	if lab.has_method("on_jump_committed"):
		spider.jump_committed.connect(lab.on_jump_committed)
	lab.surface_availability_changed.connect(spider.on_surface_availability_changed)
	camera_rig = CameraRig.new()
	camera_rig.target = spider
	camera_rig.settings = settings
	add_child(camera_rig)  # the rig snaps behind the spider in its own _ready
	memory = ObservationMemory.new()
	sensor = SensorSystem.new()
	sensor.observer = spider
	sensor.memory = memory
	sensor.configure_from(profile)
	add_child(sensor)
	prey = PreyDirector.new()
	prey.name = "Prey"
	prey.spider = spider
	prey.lab = lab
	prey.target_population = maxi(prey_count, 0)
	prey.seed_value = _resolved_prey_seed()
	prey.assist = bool(settings.get_value("capture_assist"))
	prey.camera_rig = camera_rig
	prey.sensor = sensor
	prey.replenish = prey_replenish
	prey.captured.connect(sensor.on_capture)
	add_child(prey)
	needs = NeedsModel.new()
	if restored:
		prey.restore_record = restore_record["prey"]
		needs.load_dict(restore_record["needs"])
	feeding = FeedingController.new()
	feeding.name = "Feeding"
	feeding.motor = spider
	feeding.prey = prey
	feeding.needs = needs
	feeding.interactive = interactive
	feeding.settings = settings
	feeding.struggle_enabled = prey_struggle
	feeding.struggle_auto = bool(settings.get_value("struggle_auto"))
	if restored:
		var fr: Dictionary = restore_record["feeding"]
		feeding.meals_started = int(fr["meals_started"])
		feeding.meals_finished = int(fr["meals_finished"])
		feeding.taken_total = float(fr["taken_total"])
		feeding.granted_total = float(fr["granted_total"])
	add_child(feeding)
	prey.captured.connect(feeding.on_captured)
	var body := spider.get_node_or_null("Body")
	if body != null:
		feeding.struggle_changed.connect(func(phase: String) -> void:
			if not is_instance_valid(body):
				return
			if phase == "jerk":
				body.jolt()
			elif phase == "tap":
				body.jolt(0.35))
	_apply_reduced_motion()
	if use_windowsill:
		habitat_loop = HabitatLoop.new()
		habitat_loop.world = self
		habitat_loop.interactive = interactive
		if restored:
			habitat_loop.apply_record(restore_record["habitat"])
		add_child(habitat_loop)
	if interactive:
		controller = PlayerController.new()
		controller.motor = spider
		controller.camera_rig = camera_rig
		controller.settings = settings
		controller.feeding_controller = feeding
		add_child(controller)
		jump_controller = JumpController.new()
		jump_controller.motor = spider
		jump_controller.camera_rig = camera_rig
		jump_controller.settings = settings
		jump_controller.feeding = feeding
		add_child(jump_controller)
		controller.jump_controller = jump_controller
		tether_controller = TetherController.new()
		tether_controller.motor = spider
		tether_controller.settings = settings
		add_child(tether_controller)
		silk_lines = SilkLines.new()
		silk_lines.motor = spider
		add_child(silk_lines)
		anchor_cue = AnchorCue.new()
		anchor_cue.controller = jump_controller
		anchor_cue.motor = spider
		add_child(anchor_cue)
		landing_patch = LandingPatch.new()
		landing_patch.controller = jump_controller
		landing_patch.settings = settings
		add_child(landing_patch)
		jump_hud = JumpHud.new()
		jump_hud.controller = jump_controller
		jump_hud.settings = settings
		jump_hud.motor = spider
		jump_hud.tether_controller = tether_controller
		add_child(jump_hud)
		pause_menu = PauseMenu.new()
		pause_menu.settings = settings
		pause_menu.world = self
		add_child(pause_menu)
		overlay = DebugOverlay.new()
		overlay.motor = spider
		overlay.camera_rig = camera_rig
		add_child(overlay)
		perception_hud = PerceptionHud.new()
		perception_hud.memory = memory
		perception_hud.settings = settings
		perception_hud.motor = spider
		perception_hud.controller = controller
		add_child(perception_hud)
		gaze_overlay = GazeOverlay.new()
		gaze_overlay.motor = spider
		gaze_overlay.sensor = sensor
		gaze_overlay.settings = settings
		add_child(gaze_overlay)
		eye_overlay = EyeViewOverlay.new()
		eye_overlay.camera_rig = camera_rig
		eye_overlay.motor = spider
		eye_overlay.settings = settings
		add_child(eye_overlay)
		overlay.sensor = sensor
		overlay.memory = memory
		overlay.prey = prey
		overlay.needs = needs
		overlay.feeding = feeding
		needs_hud = NeedsHud.new()
		needs_hud.needs = needs
		needs_hud.feeding = feeding
		add_child(needs_hud)
		support_debug = SupportDebug.new()
		support_debug.motor = spider
		add_child(support_debug)
		perception_debug = PerceptionDebug.new()
		perception_debug.sensor = sensor
		perception_debug.memory = memory
		support_debug.add_child(perception_debug)  # hidden and shown with the support view
		prey_debug = PreyDebug.new()
		prey_debug.prey = prey
		prey_debug.spider = spider
		support_debug.add_child(prey_debug)  # hidden and shown with the support view
		jump_debug = JumpDebug.new()
		jump_debug.motor = spider
		jump_debug.controller = jump_controller
		support_debug.add_child(jump_debug)  # hidden and shown with the support view
		tether_debug = TetherDebug.new()
		tether_debug.motor = spider
		support_debug.add_child(tether_debug)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_apply_ui_scale()


func _resolved_prey_seed() -> int:
	if prey_seed != 0:
		return prey_seed
	if interactive:
		var picked := int(Time.get_ticks_usec() & 0x7fffffff)
		print("prey seed %d" % picked)
		return picked
	return PreyDirector.DEFAULT_SEED


func _exit_tree() -> void:
	if interactive:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## T09 (U01): the size of all text and panels (the window's 2D content scale; the 3D view keeps its size). Played worlds only.
func _apply_ui_scale() -> void:
	if interactive and is_inside_tree():
		get_tree().root.content_scale_factor = float(settings.get_value("ui_scale"))


## "Reduced motion" keeps the model still: neutral legs, no twitch or catch recoil.
func _apply_reduced_motion() -> void:
	var body := spider.get_node_or_null("Body") if spider != null else null
	if body != null:
		var calm := bool(settings.get_value("reduced_motion"))
		body.twitch_enabled = not calm
		body.recoil_enabled = not calm
		body.gait_enabled = not calm


func _on_setting_changed(key: String) -> void:
	if key == "ui_scale":
		_apply_ui_scale()
	if key == "reduced_motion":
		_apply_reduced_motion()
	if key == "struggle_auto" and feeding != null:
		feeding.struggle_auto = bool(settings.get_value("struggle_auto"))
	if key == "jump_reach" and spider != null:
		spider.set_reach_factor(float(settings.get_value("jump_reach")))
	if key == "capture_assist" and prey != null:
		prey.assist = bool(settings.get_value("capture_assist"))


## A checkpoint record is checked before anything is built; a valid one decides the habitat, the spider's place and the prey's seed.
func _prepare_restore() -> void:
	restore_record = Checkpoint.upgrade(restore_record)
	restore_errors = Checkpoint.validate(restore_record)
	if not restore_errors.is_empty():
		push_warning("The checkpoint was refused and a new world started: %s" % "; ".join(restore_errors))
		restore_record = {}
		return
	restored = true
	use_windowsill = true
	var pr: Dictionary = restore_record["prey"]
	prey_seed = String(pr["seed"]).to_int()
	prey_count = int(pr["target_population"])
	prey_replenish = bool(pr["replenish"])
	var player: Dictionary = restore_record["player"]
	spawn_override = Transform3D(SupportMath.body_basis(_v3(player["normal"]), _v3(player["heading"])), _v3(player["position"]))
	last_checkpoint = restore_record


static func _v3(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


# ------------------------------------------------------------------ checkpoints (T09, S01-C, S02)

## Why a checkpoint cannot be made now ("" when it can).
func checkpoint_problem() -> String:
	return Checkpoint.boundary_problem(self)


## Makes a checkpoint of this world now and keeps it (on disk when there is a store). {"ok", "message", "record", "errors"}.
func save_checkpoint() -> Dictionary:
	var why := checkpoint_problem()
	if why != "":
		last_checkpoint_message = "No checkpoint: %s." % why
		return {"ok": false, "message": last_checkpoint_message, "record": {}, "errors": PackedStringArray([why])}
	var record := Checkpoint.capture(self)
	var errors := Checkpoint.validate(record)
	if not errors.is_empty():
		last_checkpoint_message = "The checkpoint failed its own checks and was not kept."
		push_error("checkpoint capture failed validation: %s" % "; ".join(errors))
		return {"ok": false, "message": last_checkpoint_message, "record": {}, "errors": errors}
	if checkpoint_store != null:
		var result: Dictionary = checkpoint_store.save(record)
		last_checkpoint_message = str(result["message"])
		if not bool(result["ok"]):
			return {"ok": false, "message": last_checkpoint_message, "record": {}, "errors": result["errors"]}
	else:
		last_checkpoint_message = "Checkpoint kept."
	last_checkpoint = record
	return {"ok": true, "message": last_checkpoint_message, "record": record, "errors": PackedStringArray()}


## The checkpoint "Return to checkpoint" would load: from disk when there is a store (current file, else its backup), else the newest one this
## world made. {"ok", "record", "source", "message"}.
func available_checkpoint() -> Dictionary:
	if checkpoint_store != null:
		return checkpoint_store.load_best()
	if not last_checkpoint.is_empty():
		return {"ok": true, "record": last_checkpoint, "source": "memory", "message": "Checkpoint found.", "errors": PackedStringArray()}
	return {"ok": false, "record": {}, "source": "", "message": "No checkpoint yet: rest in the silk-lined crack to make one.", "errors": PackedStringArray()}


## Discards this whole world and builds the checkpoint's world in its place (whatever the spider is doing now: walking, in the air, on its
## line, feeding). Returns the new world, or null with the reason in last_checkpoint_message when there is no usable checkpoint (this world
## is then left exactly as it was). `record` overrides the stored checkpoint (tests).
func return_to_checkpoint(record: Dictionary = {}) -> Node3D:
	var rec := record
	if rec.is_empty():
		var found := available_checkpoint()
		if not bool(found["ok"]):
			last_checkpoint_message = str(found["message"])
			return null
		rec = found["record"]
		last_checkpoint_message = str(found["message"])
	rec = Checkpoint.upgrade(rec)
	var errors := Checkpoint.validate(rec)
	if not errors.is_empty():
		last_checkpoint_message = "The checkpoint cannot be loaded: " + "; ".join(errors)
		return null
	var fresh: Node3D = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	fresh.interactive = interactive
	fresh.settings = settings
	fresh.prey_struggle = prey_struggle
	fresh.checkpoint_dir = checkpoint_dir
	fresh.restore_record = rec.duplicate(true)
	fresh.last_checkpoint_message = last_checkpoint_message
	var parent := get_parent()
	var index := get_index()
	var tree := get_tree()
	var was_current := tree.current_scene == self
	tree.paused = false
	parent.remove_child(self)
	parent.add_child(fresh)
	parent.move_child(fresh, index)
	if was_current:
		tree.current_scene = fresh
	queue_free()
	return fresh


## Returns the spider to the spawn point; the camera snaps with it.
func respawn() -> void:
	spider.teleport_to(_spawn_transform())
	camera_rig.snap_to_target()


## Every lab piece must name a surface profile that exists.
func _check_lab_surfaces() -> void:
	for piece_name: String in lab.get_piece_names():
		var id := str(lab.get_piece(piece_name).get_meta("surface_profile_id", ""))
		if not surfaces.has(id):
			push_error("Lab piece %s uses an unknown surface profile '%s'" % [piece_name, id])


func _spawn_transform() -> Transform3D:
	if spawn_override is Transform3D:
		return spawn_override
	var t: Transform3D = lab.get_spawn_transform()
	t.origin += Vector3.UP * SPAWN_LIFT
	return t
