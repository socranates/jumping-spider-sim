extends RefCounted
## T09c (Chet review 5, P2): words on the screen name the keys the player chose. Hints are written with the default keyboard keys (as spec
## 17's action map gives them, each beside its controller button); apply() swaps every default key for the remapped one, and (T09d) every
## default controller button for the remapped one. With no settings, or the defaults, the text comes back unchanged.

## Default key words in hint text, the action each one stands for, and whether the part after " / " is a button the player may change
## (the sticks stay).
const TOKENS := [
	["W / stick up", "move_forward", false], ["S / stick down", "move_back", false],
	["Q / B", "cancel", true], ["E / X", "interact", true], ["Space / A", "prepare_jump", true], ["H / View", "help", true],
	["V / Y", "eye_view", true], ["T / right trigger", "slow_motion", true], ["N / D-pad up", "notebook", true],
	["F / D-pad down", "drop_line", true],
]


static func key_of(settings: Object, action: String, fallback: String) -> String:
	if settings == null or not settings.has_method("get_key"):
		return fallback
	var code: int = settings.get_key(action)
	return OS.get_keycode_string(code as Key) if code > 0 else fallback


## T09d: the controller button or trigger an action answers to now.
static func pad_of(settings: Object, action: String, fallback: String) -> String:
	if settings == null or not settings.has_method("pad_name"):
		return fallback
	return str(settings.pad_name(action))


## "Key / button" for an action, as the hints write it.
static func both(settings: Object, action: String, key_fallback: String, pad_fallback: String) -> String:
	return "%s / %s" % [key_of(settings, action, key_fallback), pad_of(settings, action, pad_fallback)]


static func apply(text: String, settings: Object) -> String:
	if settings == null or not settings.has_method("get_key"):
		return text
	# Two passes, so a name put in for one token is never read again as another (cancel given E and X must not become interact's).
	var out := text
	var names: Array[String] = []
	for i in TOKENS.size():
		var t: Array = TOKENS[i]
		var token: String = t[0]
		var parts := token.split(" / ")
		var pad_word: String = pad_of(settings, str(t[1]), parts[1]) if bool(t[2]) else parts[1]
		names.append(key_of(settings, str(t[1]), parts[0]) + " / " + pad_word)
		out = out.replace(token, "\u0001%d\u0001" % i)
	for i in names.size():
		out = out.replace("\u0001%d\u0001" % i, names[i])
	return out
