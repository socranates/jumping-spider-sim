extends RefCounted
## One fixture of an acceptance gate (A01, L01): a name, what was measured, and what went wrong. A gate test runs its fixtures one by
## one, each in a fresh world, and writes one block per fixture into its report. The same shape as the fixtures of the P01 gate.

var name: String
var notes: PackedStringArray = PackedStringArray()
var problems: PackedStringArray = PackedStringArray()


func _init(p_name: String) -> void:
	name = p_name


## Records a measurement; with a condition, a problem when it does not hold. Returns the condition.
func need(condition: bool, ok_text: String, problem: String) -> bool:
	if condition:
		notes.append(ok_text)
	else:
		problems.append(problem)
	return condition


func note(text: String) -> void:
	notes.append(text)


func ok() -> bool:
	return problems.is_empty()
