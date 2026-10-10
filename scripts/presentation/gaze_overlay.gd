extends Node3D
## Gaze footprint (A-003, spec 7, 17): an optional, instructional overlay, off by default (setting "Show where the spider
## looks"). It draws where the inspection cone, along the spider's gaze, meets the world: a faint ring and disc lying on the
## first surface the gaze reaches, as wide as the cone is at that distance. Where something stands in the way, that is where
## it stops: the footprint is the cone meeting the occluder, never the cone going on past it, and it is worked out from the
## spider's eye, its gaze and the world's geometry alone, so it cannot show anything about what is hidden (nothing in it
## depends on whether a target exists, where it is, or what has been sensed). It never uses the camera: turning the camera does
## not move it, only the body and Focus do.

const Layers = preload("res://scripts/core/physics_layers.gd")
const SupportMath = preload("res://scripts/movement/support_math.gd")

const RING_SEGMENTS := 56
## The footprint floats this far off the surface so it does not fight with it.
const SURFACE_OFFSET := 0.02
const MIN_RADIUS := 0.25
const MAX_RADIUS := 6.0
## On a surface the gaze meets at a shallow angle the footprint is stretched along the gaze, by at most this.
const MAX_STRETCH := 3.0
const RING_COLOR := Color(1.0, 0.93, 0.62, 0.42)
const DISC_COLOR := Color(1.0, 0.93, 0.62, 0.07)

var motor: Node3D       # SpiderMotor
var sensor: Node        # SensorSystem, for the cone and the range
var settings: Node      # Settings autoload, or a test instance
## The last footprint: {point, normal, radius, distance}, empty when the gaze meets nothing within range or the overlay is off.
var footprint: Dictionary = {}

var _ring: MeshInstance3D
var _disc: MeshInstance3D


func _ready() -> void:
	top_level = true
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_ring = _part(make_annulus(0.92, 1.0, RING_SEGMENTS), RING_COLOR)
	_disc = _part(make_annulus(0.0, 0.92, RING_SEGMENTS), DISC_COLOR)
	add_child(_ring)
	add_child(_disc)
	if settings == null:
		settings = get_node_or_null("/root/Settings")
	_hide()


func _process(_delta: float) -> void:
	if settings == null or not bool(settings.get_value("show_gaze")) or motor == null or not is_instance_valid(motor):
		footprint = {}
		_hide()
		return
	var cone: float = sensor.cone_deg if sensor != null else 30.0
	var reach: float = sensor.range_wu if sensor != null else 40.0
	footprint = compute_footprint(motor.get_world_3d().direct_space_state, motor.get_eye_position(true), motor.get_gaze_direction(), cone, reach)
	if footprint.is_empty():
		_hide()
		return
	var normal: Vector3 = footprint["normal"]
	var xform := Transform3D(footprint_basis(motor.get_gaze_direction(), normal, float(footprint["radius"])), (footprint["point"] as Vector3) + normal * SURFACE_OFFSET)
	_ring.global_transform = xform
	_disc.global_transform = xform
	_ring.visible = true
	_disc.visible = true


## Where the gaze first meets the world within `reach`, and how wide the cone is there. {} when it meets nothing.
static func compute_footprint(space: PhysicsDirectSpaceState3D, eye: Vector3, axis: Vector3, cone_deg: float, reach: float) -> Dictionary:
	if space == null:
		return {}
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + axis.normalized() * reach, Layers.WORLD))
	if hit.is_empty():
		return {}
	var point: Vector3 = hit["position"]
	var distance := eye.distance_to(point)
	var radius := clampf(distance * tan(deg_to_rad(cone_deg) * 0.5), MIN_RADIUS, MAX_RADIUS)
	return {"point": point, "normal": hit["normal"], "radius": radius, "distance": distance}


## The footprint's frame: a circle of `radius` lying on the surface, stretched along the gaze where the surface is steep to it.
static func footprint_basis(axis: Vector3, normal: Vector3, radius: float) -> Basis:
	var n := normal.normalized()
	var stretch := minf(1.0 / maxf(absf(axis.normalized().dot(n)), 1e-3), MAX_STRETCH)
	var along := axis - n * axis.dot(n)
	if along.length_squared() < 1e-6:
		along = SupportMath.any_perpendicular(n)
	along = along.normalized()
	return Basis(along * radius * stretch, n, n.cross(along) * radius)


## A flat ring (or disc, with inner radius 0) of unit outer radius lying in the XZ plane, facing +Y.
static func make_annulus(inner: float, outer: float, segments: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for i in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var i0 := Vector3(cos(a0), 0.0, sin(a0)) * inner
		var o0 := Vector3(cos(a0), 0.0, sin(a0)) * outer
		var i1 := Vector3(cos(a1), 0.0, sin(a1)) * inner
		var o1 := Vector3(cos(a1), 0.0, sin(a1)) * outer
		st.add_vertex(i0)
		st.add_vertex(o0)
		st.add_vertex(o1)
		st.add_vertex(i0)
		st.add_vertex(o1)
		st.add_vertex(i1)
	return st.commit()


func is_showing() -> bool:
	return _ring != null and _ring.visible


func _hide() -> void:
	if _ring != null:
		_ring.visible = false
		_disc.visible = false


func _part(mesh: Mesh, color: Color) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = color
	m.render_priority = 3
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
