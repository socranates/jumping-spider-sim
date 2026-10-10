extends "res://tests/jump_test_case.gd"
## Helpers for the safety-line tests: misses the line has to catch, set up in the lab with the real planner,
## motor and (where it matters) the real controllers. The lab's yellow practice perches drop away when a jump is
## committed toward them (main connects the spider to the lab), which is how a miss happens on purpose.

## Units (A-019): 1 WU = 1 cm = 10 mm. Every tolerance in this file is in WU; convert with this factor to say it in mm.
const WU_TO_MM := 10.0

## The most the physics engine's collision recovery may lift a body in one tick, in WU: Godot's sweep keeps a body
## 0.001 WU (its default safe margin, 0.01 mm) off what it touches and a tick makes at most two sweeps on the line, so
## the cap is 0.002 WU, which is 0.02 mm. (Chunk 5's notes called this 2 mm: that read the WU as metres. The cap
## itself, a number of WU, was never changed.)
const CONTACT_LIFT_MAX := 0.002


## Standing on the wooden cap of the coated cliff, facing +X toward the practice perch.
func cliff_pose(z: float = -7.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(24.6, 6.71, z))


## Standing on the M01 slab's top at x, facing -Z toward its north edge.
func slab_pose(x: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, 0.0), Vector3(x, 4.91, 5.0))


## Jumps from the cliff cap to the practice perch east of it, which drops away. True once the line has caught
## the spider (HANGING), below the cap's lip and clear of the coated face.
func miss_off_the_cliff(spider: Node3D, z: float = -7.0) -> bool:
	var plan: RefCounted = spider.plan_jump(top_target(27.3, z))
	if not plan.is_valid() or plan.target_surface_id != "drop_perch":
		return false
	spider.begin_prepare()
	if not spider.commit_jump(plan):
		return false
	return await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 150)


## Adds a practice perch north of the slab at x and jumps to it from the slab top; the perch drops away. True
## once the line has caught the spider, hanging below the slab's north edge.
func miss_off_the_slab(spider: Node3D, x: float) -> bool:
	var piece := "test_perch_%d" % int(round(x * 10.0))
	world.lab.add_fixture_piece(piece, "drop", Vector3(x - 0.5, 4.2, 2.0), Vector3(x + 0.5, 4.6, 3.0))
	await physics_frames(2)
	var plan: RefCounted = spider.plan_jump(top_target(x, 2.5))
	if not plan.is_valid() or plan.target_surface_id != piece:
		return false
	spider.begin_prepare()
	if not spider.commit_jump(plan):
		return false
	return await wait_until(func() -> bool: return spider.state == spider.State.HANGING, 150)


## Waits until a hanging spider has come to rest (the motor stops it once it is slow enough for long enough).
func wait_settled(spider: Node3D, max_ticks: int = 600) -> bool:
	return await wait_until(func() -> bool: return spider.state == spider.State.HANGING and spider.velocity == Vector3.ZERO, max_ticks)


## Records the line events of a spider as "kind" or "kind:detail".
func record_line_events(spider: Node3D) -> Array[String]:
	var events: Array[String] = []
	spider.line_event.connect(func(kind: String, detail: String) -> void: events.append(kind if detail == "" else "%s:%s" % [kind, detail]))
	return events


## Every check M03 makes on one traced tick of a locked line, as a list of problems (empty when fine).
##
## What the energy check counts (per unit mass, 0.5 v^2 + g y): the energy at the start of the tick, plus the work of
## the reel (g times the rise the reel's own pull made, measured up to the contact on a tick where the body takes
## hold), plus the seat step when the legs take hold (signed: the legs seat the body onto the surface, which is
## support, not line), plus what the physics engine's collision recovery lifted the body by when it is pressed
## into something (contact_lift, itself capped at CONTACT_LIFT_MAX), plus 2e-4 for float rounding. The line's own
## step (gravity, damping, the constraint) may add nothing: that is what the clamp in the motor and the constraint's
## radial and tangential checks below guarantee. The rows of a tick on which the body took hold (state LANDING,
## the line still recorded until the body is ATTACHED) are checked like any other, except that the path may be a
## little longer than the rest length then: the legs hold the body, not the line.
static func tick_problems(r: Dictionary, g: float) -> PackedStringArray:
	var out := PackedStringArray()
	if bool(r.get("overlap", false)):
		out.append("tick %d: the body overlaps the world" % int(r["tick"]))
	if not r.has("e0"):
		return out  # a payout tick: only lengths
	if str(r["mode"]) != "locked":
		return out
	var rest := float(r["rest"])
	var mx := float(r["max"])
	if float(r["paid"]) < -1e-4 or float(r["paid"]) > rest + 1e-4 or rest < -1e-4 or rest > mx + 1e-4:
		out.append("tick %d: lengths out of bounds (paid %f, rest %f, max %f)" % [int(r["tick"]), float(r["paid"]), rest, mx])
	var landing := str(r["state"]) == "LANDING"
	if not landing and float(r["path"]) > rest + 0.01:
		out.append("tick %d: the line is longer than its rest length (%f > %f)" % [int(r["tick"]), float(r["path"]), rest])
	if bool(r["acted"]):
		var rb := float(r["radial_before"])
		var ra := float(r["radial_after"])
		if ra < minf(rb, 0.0) - 1e-5 or ra > maxf(rb, 0.0) + 1e-5 or ra > 1e-5:
			out.append("tick %d: the constraint changed radial speed %f to %f (it may only remove outward speed)" % [int(r["tick"]), rb, ra])
		if float(r["tangential_change"]) > 1e-4:
			out.append("tick %d: the constraint changed tangential speed by %f" % [int(r["tick"]), float(r["tangential_change"])])
	var lift := float(r.get("contact_lift", 0.0))
	var allowed := float(r["e0"]) + float(r["reel_work"]) + float(r.get("hold_work", 0.0)) + lift + 2e-4
	if float(r["e"]) > allowed:
		out.append("tick %d (%s): energy rose by %f, more than the reel work %f, the seat step %f and the engine's contact recovery %f allow" % [int(r["tick"]), str(r["state"]), float(r["e"]) - float(r["e0"]), float(r["reel_work"]), float(r.get("hold_work", 0.0)), lift])
	if lift > g * CONTACT_LIFT_MAX:
		out.append("tick %d: the engine's collision recovery lifted the body by %f WU (more than %f)" % [int(r["tick"]), lift / g, CONTACT_LIFT_MAX])
	if float(r["reel_work"]) > float(r["reel_bound"]) + 1e-4:
		out.append("tick %d: reel work %f above what the reel could do (%f)" % [int(r["tick"]), float(r["reel_work"]), float(r["reel_bound"])])
	if float(r.get("hold_work", 0.0)) > g * 0.021:
		out.append("tick %d: taking hold lifted the body more than one seat step" % int(r["tick"]))
	return out
