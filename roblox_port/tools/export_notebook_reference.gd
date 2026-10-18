extends SceneTree
## Actual frozen Godot notebook, not expectations reproduced from the port.
const Notebook = preload("res://scripts/learning/field_notebook.gd")
func _init() -> void:
	var book := Notebook.new()
	var actions := [{"kind":"notice","value":"start"},{"kind":"notice","value":"jump"},{"kind":"notice","value":"jump"},{"kind":"jump","value":4.99},{"kind":"jump","value":5.0},{"kind":"jump","value":8.0},{"kind":"eye","value":19.0},{"kind":"eye","value":-2.0},{"kind":"eye","value":2.0},{"kind":"eye","value":40.0},{"kind":"notice","value":"unknown"}]
	for trigger in Notebook.TRIGGERS:
		actions.append({"kind":"notice","value":trigger})
	var rows := []
	for a: Dictionary in actions:
		match a.kind:
			"notice": book.notice(a.value)
			"jump": book.notice_jump(a.value)
			"eye": book.add_eye_time(a.value)
		rows.append({"action":a,"opened":book.opened.duplicate(),"eye_seconds":book.eye_seconds})
	var f := FileAccess.open("res://roblox_port/tests/notebook_godot.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"  ")+"\n")
	print("NOTEBOOK_REFERENCE: ",rows.size()," transitions")
	book.free()
	quit()
