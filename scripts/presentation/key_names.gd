extends RefCounted
## T09c (Chet review 5, P2): words on the screen name the keys the player chose. Hints are written with the default keyboard keys (as spec
## 17's action map gives them, each beside its controller button); apply() swaps every default key for the remapped one. With no settings,
## or the defaults, the text comes back unchanged.

## Default key words in hint text, and the action each one stands for.
const TOKENS := [
	["W / stick up", "move_forward", " / stick up"], ["S / stick down", "move_back", " / stick down"],
	["Q / B", "cancel", " / B"], ["E / X", "interact", " / X"], ["Space / A", "prepare_jump", " / A"], ["H / View", "help", " / View"],
]


static func key_of(settings: Object, action: String, fallback: String) -> String:
	if settings == null or not settings.has_method("get_key"):
		return fallback
	var code: int = settings.get_key(action)
	return OS.get_keycode_string(code as Key) if code > 0 else fallback


static func apply(text: String, settings: Object) -> String:
	if settings == null or not settings.has_method("get_key"):
		return text
	var out := text
	for t: Array in TOKENS:
		var token: String = t[0]
		if out.contains(token):
			var default_name := token.substr(0, token.find(" /"))
			out = out.replace(token, key_of(settings, str(t[1]), default_name) + str(t[2]))
	return out
