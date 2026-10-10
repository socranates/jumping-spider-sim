extends Node3D
## Developer view of the living prey (F4, a child of the support view, so it shows with it; off by default), and the "Needs" and "Prey" lines of
## the F3 overlay (describe()). Developers see what the player may not (spec 17, A-007), so it says which is which. For every living fly:
##   * a label above it: its id, state, goal, awareness, the perch it is on or flying to, the utility's winner with the scores, any reaction
##     waiting out its delay, and the reason of its last transition (the trace explains each one);
##   * a cyan line from its eye to the spider while it sees it, grey while it does not (line of sight is what it has, not the truth);
##   * the path it is flying, in orange;
## and the perches and the wall vents replacements come in through: green when valid, red when the world refused them, amber while a fly has reserved one.
## Nothing here is read by the simulation.

const JumpArc = preload("res://scripts/presentation/jump_arc.gd")
const Fly = preload("res://scripts/prey/fly.gd")

const SEE_COLOR := Color(0.2, 0.9, 1.0)
const BLIND_COLOR := Color(0.55, 0.55, 0.6)
const PATH_COLOR := Color(1.0, 0.6, 0.15)
const OK_COLOR := Color(0.25, 0.9, 0.35)
const REFUSED_COLOR := Color(1.0, 0.25, 0.25)
const RESERVED_COLOR := Color(1.0, 0.8, 0.2)
const POOL := 8
const REASON_CHARS := 110

var prey: Node3D     # PreyDirector
var spider: Node3D

var _labels: Array[Label3D] = []
var _sight: Array = []
var _paths: Array = []
var _perch_marks: Array[MeshInstance3D] = []


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for i in POOL:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0011
		label.font_size = 26
		label.outline_size = 8
		label.modulate = Color(1.0, 1.0, 1.0)
		label.outline_modulate = Color(0.05, 0.05, 0.08)
		label.visible = false
		label.render_priority = 10
		label.outline_render_priority = 9
		add_child(label)
		_labels.append(label)
		var sight := JumpArc.new(SEE_COLOR, 0.012, false)
		add_child(sight)
		_sight.append(sight)
		var path := JumpArc.new(PATH_COLOR, 0.02, false)
		add_child(path)
		_paths.append(path)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and prey != null:
		refresh()


func refresh() -> void:
	_refresh_perches()
	var living: Array[Node3D] = prey.living()
	for i in POOL:
		var label := _labels[i]
		if i >= living.size():
			label.visible = false
			(_sight[i] as Node3D).call("clear")
			(_paths[i] as Node3D).call("clear")
			continue
		var f := living[i]
		label.visible = true
		label.global_position = f.global_position + Vector3(0.0, 0.9, 0.0)
		label.text = label_text(f)
		var ev: Dictionary = f.senses.evidence
		var sees: bool = not ev.is_empty() and bool(ev.get("seen", false)) and prey.now - float(ev.get("t", -1.0e9)) < 0.5
		(_sight[i] as Node3D).call("set_color", SEE_COLOR if sees else BLIND_COLOR)
		if spider != null:
			(_sight[i] as Node3D).call("set_path", PackedVector3Array([f.eye_position(), spider.global_position]) if sees else PackedVector3Array())
		var pts := PackedVector3Array()
		if f.is_flying() and f.flight.path.size() > 1:
			pts.append(f.global_position)
			for k in range(1, f.flight.path.size()):
				pts.append(f.flight.path[k])
		(_paths[i] as Node3D).call("set_path", pts)


static func label_text(f: Node3D) -> String:
	var lines := PackedStringArray()
	lines.append("%s %s  goal %s  aw %.2f" % [f.id, f.state_name(), str(f.goal), f.senses.awareness])
	lines.append("perch %s%s" % [f.perch.id if f.perch != null else "-", "  -> " + f.flight.target.id if f.flight.target != null else ""])
	if f.mind != null:
		lines.append(f.mind.describe())
	var reason: String = f.last_reason()
	if reason != "":
		lines.append(reason.substr(0, REASON_CHARS) + ("..." if reason.length() > REASON_CHARS else ""))
	return "\n".join(lines)


func _refresh_perches() -> void:
	var perches: Array = prey.graph.all()
	if prey.population != null:
		perches.append_array(prey.population.vents)   # the vents a replacement comes in through, marked like the perches
	while _perch_marks.size() < perches.size():
		var m := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.18, 0.18)
		m.mesh = box
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.no_depth_test = true
		mat.render_priority = 8
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_perch_marks.append(m)
	for i in _perch_marks.size():
		var m := _perch_marks[i]
		m.visible = i < perches.size()
		if not m.visible:
			continue
		var p = perches[i]
		m.global_position = p.position + p.normal * 0.2
		var color := OK_COLOR if p.valid else REFUSED_COLOR
		if p.valid and (p.reserved_by != "" or p.occupant != ""):
			color = RESERVED_COLOR
		(m.material_override as StandardMaterial3D).albedo_color = color


## The "Needs" and "Prey" lines of the F3 overlay: the reserves and the feeding, then the director's counters and one line per living fly.
static func describe(prey_node: Node3D, needs: RefCounted, feeding: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if needs != null:
		out.append("Needs: %s" % needs.describe())
	if feeding != null:
		out.append(feeding.describe())
	if prey_node != null:
		var living: Array[Node3D] = prey_node.living()
		out.append("Prey: seed %d, %d living of %d wanted, tick %d, refused perches %d, strike %s, captures %d" % [
			prey_node.seed_value, living.size(), prey_node.target_population, prey_node.tick, (prey_node.validation.get("refused", {}) as Dictionary).size(),
			"on" if prey_node.strike_active else "off", prey_node.capture_log.size()])
		var avg: int = prey_node.cpu_us_total / maxi(prey_node.cost_ticks(), 1)
		out.append("  cost per tick: avg %d us, p95 %d us, max %d us" % [avg, prey_node.cost_percentile(0.95), prey_node.cpu_us_max])
		if prey_node.population != null:
			out.append("  population: " + prey_node.population.describe(prey_node.now))
		for f in living:
			out.append("  " + f.describe_line().substr(0, 150))
	return out
