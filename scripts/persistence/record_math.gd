extends RefCounted
## T09: small helpers for plain persisted records (spec 21.3, 21.4). Records hold only JSON types: numbers, strings, booleans, arrays and
## dictionaries. Vectors are [x, y, z] arrays; random stream states and seeds are decimal strings so that a 64-bit value survives JSON
## (whose numbers are doubles) without loss. Nothing here touches a node.


static func v3(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


## A validated [x, y, z] back into a Vector3 (call is_v3 first).
static func to_v3(a: Variant) -> Vector3:
	var arr := a as Array
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


static func is_num(v: Variant) -> bool:
	return (typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT) and is_finite(float(v))


## A whole number (JSON gives every number back as a float).
static func is_whole(v: Variant) -> bool:
	return is_num(v) and float(v) == floorf(float(v)) and absf(float(v)) < 9.0e15


static func is_v3(v: Variant) -> bool:
	if typeof(v) != TYPE_ARRAY or (v as Array).size() != 3:
		return false
	for x: Variant in v:
		if not is_num(x):
			return false
	return true


static func is_unit_v3(v: Variant) -> bool:
	return is_v3(v) and absf(to_v3(v).length() - 1.0) < 1.0e-3


## A 64-bit integer written as a decimal string (an RNG state or seed).
static func is_int_string(v: Variant) -> bool:
	if typeof(v) != TYPE_STRING:
		return false
	var s := String(v)
	return s.is_valid_int() and str(s.to_int()) == s


static func path_to_array(p: PackedVector3Array) -> Array:
	var out: Array = []
	for v in p:
		out.append(v3(v))
	return out


static func array_to_path(a: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for v: Variant in a:
		out.append(to_v3(v))
	return out


## Only the plain values of a dictionary (numbers that are finite, strings, booleans): for evidence and similar developer records whose
## other contents need not survive.
static func plain(d: Dictionary) -> Dictionary:
	var out := {}
	for k: Variant in d:
		var v: Variant = d[k]
		if typeof(k) != TYPE_STRING and typeof(k) != TYPE_STRING_NAME:
			continue
		if typeof(v) == TYPE_BOOL or typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME or is_num(v):
			out[str(k)] = str(v) if typeof(v) == TYPE_STRING_NAME else v
	return out
