extends RefCounted
## Base class for test scripts: extends "res://tests/test_case.gd".
## The runner calls every method named test_*; a test may be a coroutine that awaits frames.
## Assertions record failures and let the test continue.

var runner: Node               # the TestRunner node, for the scene tree
var sandbox: Node              # per-test parent for nodes; freed after each test
var rng: RandomNumberGenerator # seeded with the fixture seed before each test
var fixture_seed: int = 0
var failures: PackedStringArray = PackedStringArray()
var skipped_reason: String = ""
var allowed_errors: int = 0
var checks: int = 0


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func check_eq(actual: Variant, expected: Variant, message: String) -> bool:
	return check(typeof(actual) == typeof(expected) and actual == expected, "%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String) -> bool:
	return check(is_finite(actual) and absf(actual - expected) <= tolerance, "%s (expected %s +/- %s, got %s)" % [message, str(expected), str(tolerance), str(actual)])


func check_vec_near(actual: Vector3, expected: Vector3, tolerance: float, message: String) -> bool:
	return check(actual.is_finite() and actual.distance_to(expected) <= tolerance, "%s (expected %s +/- %s, got %s)" % [message, str(expected), str(tolerance), str(actual)])


## Marks the test as not run. Call it and return.
func skip(reason: String) -> void:
	skipped_reason = reason


## Engine errors expected during this test (for example a parser reporting a corrupt file).
## Any more than this count as a failure.
func allow_errors(count: int) -> void:
	allowed_errors = count


func physics_frames(count: int) -> void:
	for i in count:
		await runner.get_tree().physics_frame


func process_frames(count: int) -> void:
	for i in count:
		await runner.get_tree().process_frame


## Waits up to max_frames physics frames for the predicate. Returns true if it became true.
func wait_until(predicate: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if predicate.call():
			return true
		await runner.get_tree().physics_frame
	return predicate.call()
