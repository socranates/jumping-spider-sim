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
const SlowMotionHud = preload("res://scripts/presentation/slow_motion_hud.gd")
const Soundscape = preload("res://scripts/audio/soundscape.gd")
const SenseHud = preload("res://scripts/presentation/sense_hud.gd")
const VibrationSense = preload("res://scripts/perception/vibration_sense.gd")
const SimClock = preload("res://scripts/core/sim_clock.gd")
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
const FieldNotebook = preload("res://scripts/learning/field_notebook.gd")
const NotebookWatch = preload("res://scripts/learning/notebook_watch.gd")
const NotebookPanel = preload("res://scripts/presentation/notebook_panel.gd")
const WaspDirector = preload("res://scripts/predator/wasp_director.gd")
const CaughtPanel = preload("res://scripts/presentation/caught_panel.gd")
const Progress = preload("res://scripts/life/progress.gd")
const StartMenu = preload("res://scripts/presentation/start_menu.gd")
const Growth = preload("res://scripts/life/growth.gd")
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
## LIFE round 4: whether the mud dauber comes by itself (on the windowsill). On in a played world; test worlds switch it off.
@export var wasp_enabled: bool = true
## LIFE round 5 (MODES-01). The mode: "main" (the main life, which can be finished) or "free" (free play: its own save, never counts).
## The rules: "standard" (Natural: hunger and the wasp can kill) or "gentle" (Easy and free play: nothing kills, hunger forgives).
@export var mode: String = "main"
@export var rules: String = "standard"
## The player's progress across lives (shared by every world this one leads to; kept in PROGRESS_PATH when settings are saved).
const PROGRESS_PATH := "user://progress.cfg"
var progress: RefCounted
## Show the start menu over this world: a played world launched as the main scene shows it by itself (start_menu_on_launch).
var show_start_menu := false
var start_menu_on_launch := true
var start_menu: CanvasLayer
## This world's spider is another spider after a death (LIFE-03): somewhere new on the sill, unrelated to the last.
var new_spider := false
## The notebook to carry into this world when it has no file of its own (tests and captures: the notebook is kept in memory).
var carry_notebook: Dictionary = {}
## The life has ended (a death); end_life says how, once.
var life_ended := false
var end_summary: Dictionary = {}
signal life_ended_signal(cause: String, summary: Dictionary)
## Where another spider starts (on the floor, away from the crack and from each other).
const NEW_SPIDER_SPOTS: Array[Vector3] = [Vector3(12.0, 0.31, 9.0), Vector3(-8.0, 0.31, -10.0), Vector3(24.0, 0.31, 8.0), Vector3(-2.0, 0.31, 10.0)]
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
var slow_motion_hud: CanvasLayer  # T11a: says when slow motion is on, and switches it (played worlds only)
var vibration: Node  # T12a: what the spider feels through its feet (every world)
var wasp_director: Node  # LIFE round 4: the mud dauber's visits (the windowsill only)
var caught_panel: CanvasLayer  # what follows when the wasp catches the spider (played worlds only)
var soundscape: Node3D  # T12a: room and fly sounds (played worlds only)
var sense_hud: CanvasLayer  # T12a: captions and vibration ripples (played worlds only)
## LEARN-01: the naturalist's notebook, what opens its pages, and its pages on screen (played worlds only). It is the player's: kept in
## NOTEBOOK_PATH when settings are saved (never in a test's or a capture's world), and never part of the world's checkpoint.
const NOTEBOOK_PATH := "user://notebook.cfg"
var notebook: Node
var notebook_watch: Node
var notebook_panel: CanvasLayer
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
	if not restore_record.is_empty():
		_prepare_restore()
	if mode == "free":
		rules = "gentle"
	if checkpoint_dir != "":
		checkpoint_store = CheckpointStore.new(store_dir())
	if progress == null:
		progress = Progress.new()
		progress.path = PROGRESS_PATH if bool(settings.get("autosave")) else ""
		progress.load_saved()
	if new_spider and spawn_override == null:
		var spot: Vector3 = NEW_SPIDER_SPOTS[int(progress.lives.size()) % NEW_SPIDER_SPOTS.size()]
		spawn_override = Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), spot)
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
	needs.life_mode = use_windowsill   # LIFE_DESIGN.md round 1: on the windowsill hunger runs by the life clock's hours
	needs.gentle = rules == "gentle"   # LIFE round 5: Easy and free play forgive hunger
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
	if body != null and body.has_method("set_condition"):
		body.set_condition(needs.energy)
		body.shown_condition = needs.energy
		needs.energy_changed.connect(func(_old: float, now: float) -> void:
			if is_instance_valid(body):
				body.set_condition(now))
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
			habitat_loop.clock.load_dict(restore_record["life"])
			habitat_loop.growth.load_dict(restore_record["growth"])
		add_child(habitat_loop)
	vibration = VibrationSense.new()
	vibration.name = "VibrationSense"
	vibration.spider = spider
	vibration.prey = prey
	vibration.lab = lab
	vibration.settings = settings
	add_child(vibration)
	if use_windowsill:
		wasp_director = WaspDirector.new()
		wasp_director.name = "WaspDirector"
		wasp_director.world = self
		wasp_director.enabled = wasp_enabled
		wasp_director.seed_value = int(prey.seed_value)
		if restored:
			wasp_director.load_dict(restore_record["wasp"])
		add_child(wasp_director)
		wasp_director.carried_off.connect(func() -> void: end_life("wasp"))
	if habitat_loop != null:
		habitat_loop.moulted.connect(func(stage: int) -> void:
			if stage >= Growth.ADULT:
				_on_adult())
		if new_spider:
			habitat_loop.show_notice("Another bold jumping spider, a young juvenile. It is not related to the last. Home is the silk-lined crack at the west end.")
			habitat_loop.notice_seconds = 12.0  # longer than an ordinary notice: a new life begins
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
		tether_controller.feeding = feeding
		tether_controller.habitat_loop = habitat_loop
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
		eye_overlay.sensor = sensor
		add_child(eye_overlay)
		slow_motion_hud = SlowMotionHud.new()
		slow_motion_hud.settings = settings
		add_child(slow_motion_hud)
		sense_hud = SenseHud.new()
		sense_hud.settings = settings
		sense_hud.camera_rig = camera_rig
		sense_hud.spider = spider
		add_child(sense_hud)
		vibration.felt.connect(sense_hud.on_felt)
		soundscape = Soundscape.new()
		soundscape.name = "Soundscape"
		soundscape.settings = settings
		soundscape.prey = prey
		soundscape.spider = spider
		soundscape.habitat_loop = habitat_loop
		soundscape.vibration = vibration
		soundscape.wasp_director = wasp_director
		soundscape.seed_value = int(prey.seed_value)
		add_child(soundscape)
		soundscape.caption.connect(sense_hud.show_caption)
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
		_add_notebook()
		if wasp_director != null:
			caught_panel = CaughtPanel.new()
			caught_panel.name = "CaughtPanel"
			caught_panel.world = self
			caught_panel.settings = settings
			add_child(caught_panel)
		if habitat_loop != null and (show_start_menu or (start_menu_on_launch and not restored and not new_spider and get_tree().current_scene == self)):
			start_menu = StartMenu.new()
			start_menu.name = "StartMenu"
			start_menu.world = self
			start_menu.settings = settings
			add_child(start_menu)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_apply_ui_scale()
		_apply_game_speed()


## The spider's jump reach: the player's "Jump reach" setting, times the growth's (LIFE_DESIGN round 3: a newly moulted, soft spider
## jumps less far until its skin hardens).
func apply_reach() -> void:
	if spider == null:
		return
	var growth_factor: float = habitat_loop.growth.reach_factor() if habitat_loop != null else 1.0
	spider.set_reach_factor(float(settings.get_value("jump_reach")) * growth_factor)


## The notebook comes after the pause menu in the tree, so its keys are read first while it is open (Esc closes the notebook, not the menu).
func _add_notebook() -> void:
	notebook = FieldNotebook.new()
	notebook.name = "Notebook"
	notebook.path = NOTEBOOK_PATH if bool(settings.get("autosave")) else ""
	notebook.load_saved()
	if notebook.path == "" and not carry_notebook.is_empty():
		for id: Variant in carry_notebook.get("opened", []):
			if not notebook.opened.has(str(id)) and not notebook.page(str(id)).is_empty():
				notebook.opened.append(str(id))
		notebook.eye_seconds = float(carry_notebook.get("eye_seconds", 0.0))
	add_child(notebook)
	notebook_panel = NotebookPanel.new()
	notebook_panel.notebook = notebook
	notebook_panel.settings = settings
	add_child(notebook_panel)
	notebook_watch = NotebookWatch.new()
	notebook_watch.notebook = notebook
	notebook_watch.spider = spider
	notebook_watch.camera_rig = camera_rig
	notebook_watch.eye_overlay = eye_overlay
	notebook_watch.memory = memory
	notebook_watch.prey = prey
	notebook_watch.feeding = feeding
	notebook_watch.vibration = vibration
	notebook_watch.soundscape = soundscape
	notebook_watch.habitat_loop = habitat_loop
	notebook_watch.needs = needs
	notebook_watch.wasp = wasp_director
	add_child(notebook_watch)


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
		SimClock.set_speed(1.0)  # the next world (a checkpoint's, a test's) starts at normal speed and applies its own


## T11a: slow motion (SimClock): the same ticks, fewer of them each real second. Played worlds only; tests set the clock themselves.
func _apply_game_speed() -> void:
	if interactive and is_inside_tree():
		SimClock.set_speed(float(settings.get_value("slow_speed")) if bool(settings.get_value("slow_motion")) else 1.0)


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
	if key == "slow_motion" or key == "slow_speed":
		_apply_game_speed()
	if key == "reduced_motion":
		_apply_reduced_motion()
	if key == "struggle_auto" and feeding != null:
		feeding.struggle_auto = bool(settings.get_value("struggle_auto"))
	if key == "jump_reach" and spider != null:
		apply_reach()
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
	var lr: Dictionary = restore_record.get("life_rules", {})
	mode = str(lr.get("mode", "main"))
	rules = str(lr.get("rules", "standard"))
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
	var fresh := _fresh_world()
	fresh.restore_record = rec.duplicate(true)
	fresh.last_checkpoint_message = last_checkpoint_message
	return _swap_in(fresh)


## A new world in place of this one: a new spider in the crack at the start of its life (LIFE round 4: after the wasp, when there is no
## checkpoint to go back to). The notebook is the player's and stays. Returns the new world.
func start_new_life() -> Node3D:
	var fresh := _fresh_world()
	fresh.mode = mode
	fresh.rules = rules
	return _swap_in(fresh)


# ------------------------------------------------------------------ lives and modes (LIFE round 5, MODES-01)

## The top line's title: the main life, the main life on Easy, or free play.
func mode_title() -> String:
	if mode == "free":
		return "FREE PLAY"
	return "THE WINDOWSILL (EASY)" if rules == "gentle" else "THE WINDOWSILL"


## Where this world's checkpoints are kept: the main life's folder, or free play's own inside it.
func store_dir() -> String:
	return checkpoint_dir.path_join("free") if mode == "free" else checkpoint_dir


## The spider's life has ended (Standard rules only: "wasp" or "starved"). Once: the player's progress counts it, and the end-of-life
## screen shows the plain line, the life's summary and the way on.
func end_life(cause: String) -> void:
	if life_ended or rules == "gentle":
		return
	life_ended = true
	progress.record_death()
	var summary := life_summary(cause)
	end_summary = summary
	life_ended_signal.emit(cause, summary)
	if caught_panel != null:
		caught_panel.show_end(cause, summary)


## What the end-of-life screen tells (no score): how long it lived, how far it grew, what it ate, the wasp's visits it lived through.
func life_summary(cause: String) -> Dictionary:
	var out := {"cause": cause, "mode": mode, "rules": rules, "hours": 0.0, "stage": 0, "stage_name": "", "meals": 0,
		"wasp_visits": 0, "wasp_escapes": 0}
	if habitat_loop != null:
		out["hours"] = maxf(float(habitat_loop.clock.day - 1) * 24.0 + float(habitat_loop.clock.hour) - 9.0, 0.0)
		out["stage"] = int(habitat_loop.growth.stage)
		out["stage_name"] = str(habitat_loop.growth.stage_name())
	if feeding != null:
		out["meals"] = int(feeding.meals_finished)
	if wasp_director != null:
		out["wasp_visits"] = int(wasp_director.visits)
		out["wasp_escapes"] = int(wasp_director.escapes)
	return out


## After a death: the player goes on as another spider (LIFE-03), a young juvenile somewhere new on the sill and unrelated to the last.
## The life that ended is kept in the player's progress and its checkpoints are put away, so "Continue" never brings the dead spider
## back; the notebook goes on. Returns the new world.
func continue_as_another() -> Node3D:
	progress.record_life(end_summary if not end_summary.is_empty() else life_summary("ended"))
	if checkpoint_store != null:
		checkpoint_store.wipe()
	var fresh := _fresh_world()
	fresh.mode = mode
	fresh.rules = rules
	fresh.new_spider = true
	return _swap_in(fresh)


## The start menu's new life in this (fresh) world: the main life on Standard, or on Easy once it has been earned. A life that was going
## on in the main life's folder is put away first.
func begin_new_life(easy: bool) -> void:
	mode = "main"
	rules = "gentle" if easy and progress.easy_unlocked() else "standard"
	if needs != null:
		needs.gentle = rules == "gentle"
	if checkpoint_store != null:
		checkpoint_store.wipe()


## Free play: its own world with gentle rules and its own save (the last free-play rest, if there is one). Returns the new world.
func start_free_play() -> Node3D:
	var free_store := CheckpointStore.new(checkpoint_dir.path_join("free")) if checkpoint_dir != "" else null
	if free_store != null:
		var found: Dictionary = free_store.load_best()
		if bool(found["ok"]):
			return return_to_checkpoint(found["record"])
	var fresh := _fresh_world()
	fresh.mode = "free"
	fresh.rules = "gentle"
	return _swap_in(fresh)


## Back to the start menu: a fresh world of the main life with the menu over it. Returns the new world.
func open_start_menu() -> Node3D:
	var fresh := _fresh_world()
	fresh.show_start_menu = true
	return _swap_in(fresh)


## The main life was finished: a spider of the main life, on Standard, reached adulthood. Easy opens for later lives.
func _on_adult() -> void:
	if mode != "main" or rules != "standard":
		return
	if progress.finish_main_life() and habitat_loop != null:
		habitat_loop.show_notice("You brought a spider through its whole life. From now on a new life can also be played on Easy (start menu).")


## A new world like this one (same player, settings, saves and progress), not yet in the tree.
func _fresh_world() -> Node3D:
	var fresh: Node3D = (load(MAIN_SCENE_PATH) as PackedScene).instantiate()
	fresh.interactive = interactive
	fresh.settings = settings
	fresh.use_windowsill = use_windowsill
	fresh.prey_count = prey_count
	fresh.prey_seed = 0
	fresh.prey_replenish = prey_replenish
	fresh.prey_struggle = prey_struggle
	fresh.wasp_enabled = wasp_enabled
	fresh.checkpoint_dir = checkpoint_dir
	fresh.progress = progress
	fresh.start_menu_on_launch = false
	if notebook != null:
		fresh.carry_notebook = {"opened": notebook.opened.duplicate(), "eye_seconds": notebook.eye_seconds}
	return fresh


## Puts `fresh` where this world is and frees this one.
func _swap_in(fresh: Node3D) -> Node3D:
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
