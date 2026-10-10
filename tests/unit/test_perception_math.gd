extends "res://tests/test_case.gd"
## Pure numbers of the perception layer (spec 7): angles, apparent size, how long a refinement needs, the confidence of a
## cue and of an inspection, the coarse bearing a cue gives, how a lost contact fades.

const PerceptionMath = preload("res://scripts/perception/perception_math.gd")
const Observation = preload("res://scripts/perception/observation.gd")

## The species numbers the sensor runs with (data/species): easy 0.4 s, fly-like 1.0 s, easy at 3 degrees, nothing below 0.6.
const EASY_S := 0.4
const FLY_S := 1.0
const EASY_DEG := 3.0
const MIN_DEG := 0.6


func test_apparent_size_is_the_angle_a_thing_covers() -> void:
	check_near(PerceptionMath.apparent_size_deg(1.0, 10.0), 5.725, 0.01, "1 WU across at 10 WU covers 5.7 degrees")
	check_near(PerceptionMath.apparent_size_deg(0.9, 5.0), 10.28, 0.02, "the test marker (0.9 WU) at 5 WU")
	check(PerceptionMath.apparent_size_deg(1.0, 20.0) < PerceptionMath.apparent_size_deg(1.0, 10.0), "farther looks smaller")
	check_near(PerceptionMath.apparent_size_deg(1.0, 0.0), 180.0, 1e-9, "from no distance it fills the view")


func test_cone_and_angle_helpers() -> void:
	check_near(PerceptionMath.angle_between(Vector3.FORWARD, Vector3.RIGHT), PI / 2.0, 1e-6, "a right angle")
	check_near(PerceptionMath.angle_between(Vector3.ZERO, Vector3.RIGHT), 0.0, 1e-9, "a zero vector has no angle")
	var half := deg_to_rad(15.0)
	check(PerceptionMath.in_cone(Vector3.FORWARD, Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(14.9)), half), "14.9 degrees off is inside a 15 degree half angle")
	check(not PerceptionMath.in_cone(Vector3.FORWARD, Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(15.5)), half), "15.5 degrees off is outside")
	check(not PerceptionMath.in_cone(Vector3.FORWARD, Vector3.ZERO, half), "no direction is never in a cone")


func test_exposure_needed_grows_as_a_thing_looks_smaller() -> void:
	check_near(PerceptionMath.required_exposure(EASY_S, 5.0, EASY_DEG), 0.4, 1e-9, "an easy target needs the base time")
	check_near(PerceptionMath.required_exposure(EASY_S, 3.0, EASY_DEG), 0.4, 1e-9, "at the easy size exactly")
	check_near(PerceptionMath.required_exposure(EASY_S, 1.5, EASY_DEG), 0.8, 1e-9, "half the easy size needs twice as long")
	check(PerceptionMath.required_exposure(EASY_S, 0.0, EASY_DEG) == INF, "something with no size can never be refined")


func test_classification_refines_with_continuous_exposure() -> void:
	var big := 8.0
	var cases := [[0.0, Observation.MOVEMENT], [0.39, Observation.MOVEMENT], [0.4, Observation.POSSIBLE_PREY], [0.9, Observation.POSSIBLE_PREY], [1.0, Observation.FLY_LIKE_PREY], [5.0, Observation.FLY_LIKE_PREY]]
	for c: Array in cases:
		check_eq(PerceptionMath.classify(float(c[0]), big, EASY_S, FLY_S, EASY_DEG, MIN_DEG), c[1], "%.2f s of an easy target" % float(c[0]))
	check_eq(PerceptionMath.classify(9.0, 0.5, EASY_S, FLY_S, EASY_DEG, MIN_DEG), Observation.MOVEMENT, "below the minimum apparent size nothing is ever refined")
	var small := 1.5  # half the easy size
	check_eq(PerceptionMath.classify(0.5, small, EASY_S, FLY_S, EASY_DEG, MIN_DEG), Observation.MOVEMENT, "a small target needs twice the time: 0.5 s is not enough")
	check_eq(PerceptionMath.classify(0.8, small, EASY_S, FLY_S, EASY_DEG, MIN_DEG), Observation.POSSIBLE_PREY, "0.8 s is")
	check_eq(PerceptionMath.classify(1.9, small, EASY_S, FLY_S, EASY_DEG, MIN_DEG), Observation.POSSIBLE_PREY, "and 2 s are needed for fly-like")
	check_eq(PerceptionMath.classify(2.0, small, EASY_S, FLY_S, EASY_DEG, MIN_DEG), Observation.FLY_LIKE_PREY, "which it then is")


func test_the_categories_are_ordered_and_never_name_a_species() -> void:
	check_eq(Observation.CATEGORIES.size(), 3, "movement, possible prey, fly-like prey (A-004)")
	check(Observation.rank(Observation.MOVEMENT) < Observation.rank(Observation.POSSIBLE_PREY), "movement is coarser than possible prey")
	check(Observation.rank(Observation.POSSIBLE_PREY) < Observation.rank(Observation.FLY_LIKE_PREY), "which is coarser than fly-like prey")
	for c: StringName in Observation.CATEGORIES:
		var words := str(c).to_lower()
		check(not ("fly" in words and "house" in words) and not ("musca" in words) and not ("drosophila" in words), "no species in '%s'" % words)


func test_inspection_confidence_rises_with_exposure_and_falls_with_hiding() -> void:
	var needed := 1.0
	var lo := PerceptionMath.inspection_confidence(0.0, needed, 1.0)
	var mid := PerceptionMath.inspection_confidence(0.5, needed, 1.0)
	var hi := PerceptionMath.inspection_confidence(1.0, needed, 1.0)
	check(lo < mid and mid < hi, "more exposure, more confidence (%.2f, %.2f, %.2f)" % [lo, mid, hi])
	check_near(hi, 1.0, 1e-9, "fully refined and fully seen is certain")
	check(PerceptionMath.inspection_confidence(1.0, needed, 0.2) < hi, "a thing mostly hidden is less certain")
	var worst := PerceptionMath.inspection_confidence(0.0, needed, 0.2)
	check(worst > 0.26 and worst < 0.28, "the least it can be with one point seen is 0.27 (%.3f)" % worst)
	check_near(PerceptionMath.inspection_confidence(5.0, needed, 1.0), 1.0, 1e-9, "never above 1")
	check(PerceptionMath.inspection_confidence(0.5, INF, 1.0) > 0.0, "a thing that cannot be refined still has a confidence")


func test_a_cue_is_weak_and_a_little_stronger_when_near() -> void:
	var near := PerceptionMath.peripheral_confidence(1.0, 40.0)
	var far := PerceptionMath.peripheral_confidence(39.0, 40.0)
	check(near > far, "nearer is stronger")
	check(near <= 0.3 and far >= 0.1, "between 0.1 and 0.3 (%.3f, %.3f)" % [near, far])
	check(PerceptionMath.peripheral_confidence(1000.0, 40.0) >= 0.1, "and never below 0.1")


func test_a_cue_gives_a_sector_and_a_band_and_no_more() -> void:
	var forward := Vector3.FORWARD
	var sector := 22.5
	for deg in [0.0, 5.0, 10.0, 30.0, 47.0, 90.0, -100.0, 140.0, -171.0]:
		var d := forward.rotated(Vector3.UP, deg_to_rad(deg))
		var q := PerceptionMath.quantize_direction(d, forward, Vector3.UP, sector)
		check_near(q.length(), 1.0, 1e-6, "a unit vector (%.0f degrees)" % deg)
		var shown := rad_to_deg(forward.signed_angle_to(Vector3(q.x, 0.0, q.z), Vector3.UP))
		var snapped := roundf(deg / sector) * sector
		check_near(absf(angle_difference(deg_to_rad(shown), deg_to_rad(snapped))), 0.0, deg_to_rad(0.5), "%.0f degrees is given as the sector %.1f (got %.1f)" % [deg, snapped, shown])
		check(absf(angle_difference(deg_to_rad(shown), deg_to_rad(deg))) <= deg_to_rad(sector * 0.5 + 0.5), "never off by more than half a sector (%.0f)" % deg)
	var up30 := (forward + Vector3.UP * tan(deg_to_rad(28.0))).normalized()
	var q30 := PerceptionMath.quantize_direction(up30, forward, Vector3.UP, sector)
	check_near(rad_to_deg(asin(q30.y)), 30.0, 0.5, "28 degrees up is given as the 30 degree band")
	var up10 := (forward + Vector3.UP * tan(deg_to_rad(10.0))).normalized()
	check_near(PerceptionMath.quantize_direction(up10, forward, Vector3.UP, sector).y, 0.0, 1e-6, "10 degrees up is given as level")
	var straight := PerceptionMath.quantize_direction(Vector3.UP, forward, Vector3.UP, sector)
	check_near(straight.y, 1.0, 1e-6, "straight up has no bearing to round")


func test_coarseness_is_real_two_nearby_bearings_give_the_same_answer() -> void:
	var forward := Vector3.FORWARD
	var a := PerceptionMath.quantize_direction(forward.rotated(Vector3.UP, deg_to_rad(15.0)), forward, Vector3.UP, 22.5)
	var b := PerceptionMath.quantize_direction(forward.rotated(Vector3.UP, deg_to_rad(31.0)), forward, Vector3.UP, 22.5)
	check_vec_near(a, b, 1e-6, "15 and 31 degrees are the same sector: a cue cannot tell them apart")
	var c := PerceptionMath.quantize_direction(forward.rotated(Vector3.UP, deg_to_rad(40.0)), forward, Vector3.UP, 22.5)
	check(a.distance_to(c) > 0.1, "40 degrees is the next sector")


func test_a_lost_contact_fades_in_a_straight_line_to_nothing() -> void:
	check_near(PerceptionMath.decayed_confidence(0.8, 0.0, 6.0), 0.8, 1e-9, "at the loss it has what it had")
	check_near(PerceptionMath.decayed_confidence(0.8, 3.0, 6.0), 0.4, 1e-9, "half way, half")
	check_near(PerceptionMath.decayed_confidence(0.8, 6.0, 6.0), 0.0, 1e-9, "gone at the decay time")
	check_near(PerceptionMath.decayed_confidence(0.8, 60.0, 6.0), 0.0, 1e-9, "and not negative")
	check_near(PerceptionMath.decayed_confidence(0.8, 1.0, 0.0), 0.0, 1e-9, "no decay time means no memory")
	check_near(PerceptionMath.staleness(0.0, 6.0), 0.0, 1e-9, "fresh")
	check_near(PerceptionMath.staleness(1.5, 6.0), 0.25, 1e-9, "a quarter stale")
	check_near(PerceptionMath.staleness(7.0, 6.0), 1.0, 1e-9, "stale at most")


## A-024 (chunk 7A): how far short of a sample point the world may stop a ray and the point still count as seen.
func test_the_sight_allowance_follows_the_size_of_the_thing_and_never_hides_a_whole_speck() -> void:
	var speck := PerceptionMath.sight_tolerance(0.01, 1.0)
	check_near(speck, 0.00101, 1e-6, "a speck 0.02 WU across, 1 WU away: a tenth of its radius and the float error of the cast")
	check(speck < 0.01, "far less than the speck's own radius, so its whole body can never lie inside it")
	check(PerceptionMath.sight_tolerance(0.01, 1.0) < PerceptionMath.sight_tolerance(0.1, 1.0) and PerceptionMath.sight_tolerance(0.1, 1.0) < PerceptionMath.sight_tolerance(0.45, 1.0), "it grows with the size of the thing")
	check_near(PerceptionMath.sight_tolerance(0.45, 5.0), 0.04505, 1e-6, "the 0.9 WU test marker keeps close to what it had: a tenth of 0.45")
	check_near(PerceptionMath.sight_tolerance(5.0, 5.0), PerceptionMath.SIGHT_CEILING, 1e-9, "and nothing is ever allowed more than the old flat 0.05")
	check(PerceptionMath.sight_tolerance(0.0, 0.0) == 0.0 and PerceptionMath.sight_tolerance(-1.0, -1.0) == 0.0, "a thing of no size, or nonsense, is allowed nothing")
	for r in [0.005, 0.01, 0.02, 0.05, 0.1, 0.3]:
		# the nearest a barrier of 0.02 can stand in front of a sphere that is wholly behind it
		check(PerceptionMath.sight_tolerance(r, 1.0) < 0.02 + r, "a sphere of radius %s behind a barrier 0.02 thick is never forgiven" % str(r))


## A-027 (chunk 7A): the region a lost contact's thing could be in when something is seen again.
func test_the_plausible_region_grows_with_time_and_uses_nothing_but_what_was_seen() -> void:
	var r0 := PerceptionMath.plausible_radius(0.5, 0.5, 0.0, 2.0, 0.0)
	check_near(r0, 0.5, 1e-9, "at once, only the size of what was seen: a position is no better than the thing is big")
	check_near(PerceptionMath.plausible_radius(0.5, 0.5, 3.0, 2.0, 0.0), 0.5 + 6.0, 1e-9, "it grows by the speed bound each second")
	check_near(PerceptionMath.plausible_radius(0.5, 0.5, 3.0, 2.0, 5.0), 0.5 + 15.0, 1e-9, "or by the speed it was seen moving at, when that was more")
	check_near(PerceptionMath.plausible_radius(0.5, 0.5, -4.0, 2.0, 0.0), 0.5, 1e-9, "time does not run backwards")
	var a := PerceptionMath.plausible_radius(0.4, 0.6, 1.5, 2.0, 0.8)
	var b := PerceptionMath.plausible_radius(0.4, 0.6, 1.5, 2.0, 0.8)
	check_eq(a, b, "the same sightings give the same region: there is nothing else in it")


func test_sizes_and_categories_that_can_be_one_thing() -> void:
	check(PerceptionMath.sizes_compatible(0.5, 0.5, 1.5) and PerceptionMath.sizes_compatible(0.5, 0.74, 1.5) and PerceptionMath.sizes_compatible(0.74, 0.5, 1.5), "within the ratio, either way round")
	check(not PerceptionMath.sizes_compatible(0.5, 0.8, 1.5) and not PerceptionMath.sizes_compatible(0.8, 0.5, 1.5), "beyond it they are two things")
	check(PerceptionMath.sizes_compatible(0.0, 0.9, 1.5) and PerceptionMath.sizes_compatible(0.9, 0.0, 1.5), "a size that was not known is compatible with any")
	check(PerceptionMath.sizes_compatible(1.0, 1.0, 0.2), "a ratio under 1 is taken as 1: equal sizes are always one size")
	check(PerceptionMath.categories_compatible(Observation.MOVEMENT, Observation.MOVEMENT), "movement can be a thing that never looks like more")
	check(PerceptionMath.categories_compatible(Observation.POSSIBLE_PREY, Observation.FLY_LIKE_PREY), "possible prey can be a thing that can look fly-like")
	check(not PerceptionMath.categories_compatible(Observation.FLY_LIKE_PREY, Observation.MOVEMENT), "what was learned cannot be finer than the new thing can ever look")
	check(not PerceptionMath.categories_compatible(Observation.POSSIBLE_PREY, Observation.MOVEMENT), "nor can possible prey be a thing that is only ever movement")
