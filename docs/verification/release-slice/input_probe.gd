extends SceneTree
## Diagnostic only: identify synthetic keyboard event codes without changing input.
class Observer extends Node:
    func _input(event: InputEvent) -> void:
        if event is InputEventKey:
            print("KEY_PROBE ", event.as_text(), " physical=", event.physical_keycode, " logical=", event.keycode, " pressed=", event.pressed)
func _initialize() -> void:
    call_deferred("run")
func run() -> void:
    root.add_child(load("res://scenes/main.tscn").instantiate())
    root.add_child(Observer.new())
