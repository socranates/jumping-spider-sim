extends Node3D
## Developer view of the senses (F4, a child of the support view, so it shows with it; off by default). Developers may see
## what the player may not (spec 17, A-007), so it is explicit about which is which:
##   * the inspection cone, from the spider's eye along its gaze: spokes and a rim, in cyan; the gaze axis in white;
##   * the peripheral field, as a dashed arc on the horizontal plane through the eye, in violet;
##   * what the memory holds: a green sphere at the position of a contact being inspected, an amber one at the position of a
##     lost one (the last-seen mark), both from the memory only;
##   * TRUTH: a small red cross-sphere at where each perceivable thing really is, whether or not it is seen. This is the only
##     thing here that comes from the world, and it is there so that a developer can see the memory NOT following the thing.
## The F3 overlay's "Senses" lines give the numbers (describe()). Nothing in the player's presentation reads any of this.

const JumpArc = preload("res://scripts/presentation/jump_arc.gd")
const Perceivable = preload("res://scripts/perception/perceivable.gd")

const CONE_COLOR := Color(0.2, 0.9, 1.0)
const AXIS_COLOR := Color(1.0, 1.0, 1.0)
const FIELD_COLOR := Color(0.75, 0.5, 1.0)
const LIVE_COLOR := Color(0.2, 1.0, 0.3)
const LOST_COLOR := Color(1.0, 0.7, 0.1)
const TRUTH_COLOR := Color(1.0, 0.2, 0.2)
const CONE_LENGTH := 10.0
const SPOKES := 12
const RIM_POINTS := 32
const FIELD_RADIUS := 4.0
const POOL := 8

var sensor: Node           # SensorSystem
var memory: RefCounted     # ObservationMemory

var _spokes: Node3D
var _rim: Node3D
var _axis: Node3D
var _field: Node3D
var _memory_markers: Array[MeshInstance3D] = []
var _truth_markers: Array[MeshInstance3D] = []


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_spokes = JumpArc.new(CONE_COLOR, 0.012, false)
	_rim = JumpArc.new(CONE_COLOR, 0.016, false)
	_axis = JumpArc.new(AXIS_COLOR, 0.012, false)
	_field = JumpArc.new(FIELD_COLOR, 0.014, false)
	for a in [_spokes, _rim, _axis, _field]:
		add_child(a)
	for i in POOL:
		var m := _marker(LIVE_COLOR, 0.14)
		add_child(m)
		_memory_markers.append(m)
		var t := _marker(TRUTH_COLOR, 0.09)
		add_child(t)
		_truth_markers.append(t)


func _process(_delta: float) -> void:
	if is_visible_in_tree() and sensor != null and memory != null:
		refresh()


## Rebuilds the drawing from what the sensor looked from on its last tick and what the memory holds now.
func refresh() -> void:
	var eye: Vector3 = sensor.last_eye
	var axis: Vector3 = sensor.last_axis
	var up: Vector3 = sensor.last_up
	var reach := minf(CONE_LENGTH, float(sensor.range_wu))
	var half := deg_to_rad(float(sensor.cone_deg)) * 0.5
	var u := axis.cross(up)
	if u.length_squared() < 1e-6:
		u = axis.cross(Vector3.RIGHT)
	u = u.normalized()
	var v := axis.cross(u).normalized()
	var rim := PackedVector3Array()
	for k in RIM_POINTS + 1:
		var a := TAU * float(k) / float(RIM_POINTS)
		rim.append(eye + (axis * cos(half) + (u * cos(a) + v * sin(a)) * sin(half)) * reach)
	var spokes := PackedVector3Array()
	for k in SPOKES:
		spokes.append(eye)
		spokes.append(rim[k * (RIM_POINTS / SPOKES)])
	_spokes.set_path(spokes, false)
	_rim.set_path(rim, false)
	_axis.set_path(PackedVector3Array([eye, eye + axis * reach]), false)
	var flat := axis - up * axis.dot(up)
	if flat.length_squared() < 1e-6:
		flat = u
	flat = flat.normalized()
	var side := flat.cross(up).normalized()
	var field := PackedVector3Array([eye])
	var span := deg_to_rad(float(sensor.peripheral_cone_deg)) * 0.5
	for k in 41:
		var a := lerpf(-span, span, float(k) / 40.0)
		field.append(eye + (flat * cos(a) - side * sin(a)) * FIELD_RADIUS)
	field.append(eye)
	_field.set_path(field, true)
	var contacts: Array = memory.contacts().filter(func(c: RefCounted) -> bool: return c.has_position)
	for i in POOL:
		var m := _memory_markers[i]
		m.visible = i < contacts.size()
		if m.visible:
			var c: RefCounted = contacts[i]
			m.global_position = c.position
			(m.material_override as StandardMaterial3D).albedo_color = LIVE_COLOR if c.state == &"live" else LOST_COLOR
	var things: Array = []
	for node: Node in get_tree().get_nodes_in_group(Perceivable.GROUP):
		if node.has_method("get_percept"):
			var p: Dictionary = node.get_percept()
			if not p.is_empty():
				things.append(p)
	for i in POOL:
		var t := _truth_markers[i]
		t.visible = i < things.size()
		if t.visible:
			t.global_position = things[i]["position"]


## The "Senses" lines of the F3 overlay: the sensor's counters, what it checked last, and what the memory holds, with the
## numbers a developer wants (confidence, ages). Developer text only; the player's words are in PerceptionText.
static func describe(sensor_node: Node, mem: RefCounted) -> PackedStringArray:
	var out := PackedStringArray()
	if sensor_node == null or mem == null:
		return out
	out.append("Senses: tick %d, broad scans %d, checks %d, rays %d (most in a tick %d), cues %d, inspections %d" % [
		sensor_node.tick, sensor_node.broad_scans, sensor_node.checks_total, sensor_node.rays_total, sensor_node.max_rays_in_a_tick, sensor_node.cues_made, sensor_node.inspections_made])
	for row: Dictionary in sensor_node.describe_tracks():
		var parts := PackedStringArray()
		parts.append("  check (developer, from the world) %s: distance %.1f" % [str(row["percept_id"]), float(row.get("distance", 0.0))])
		if row.has("off_axis_deg"):
			parts.append("off axis %.0f deg" % float(row["off_axis_deg"]))
		if row.has("visible_points"):
			parts.append("sees %d of 5 points" % int(row["visible_points"]))
		if row.has("in_cone"):
			parts.append("in cone %s" % ("yes" if row["in_cone"] else "no"))
		parts.append("exposure %.2f s" % float(row["exposure_s"]))
		out.append(", ".join(parts))
	for c: RefCounted in mem.contacts():
		var pos := "no position"
		if c.has_position:
			pos = "at (%.2f, %.2f, %.2f), observed %.2f s ago" % [c.position.x, c.position.y, c.position.z, mem.observed_age_s(c)]
		var line := "  %s %s %s, %s, confidence %.2f, %s" % [str(c.track_id), str(c.state), str(c.modality), str(c.category), c.confidence, pos]
		if c.state == &"lost":
			line += ", lost %.1f s ago%s" % [mem.age_s(c), ", mark" if c.has_mark() else ""]
		out.append(line)
	return out


func _marker(color: Color, radius: float) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 9
	var mi := MeshInstance3D.new()
	mi.mesh = sphere
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi
