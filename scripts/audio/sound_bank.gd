extends RefCounted
## T12a, the game's sounds, made in code (there are no audio files): mono 16-bit PCM at RATE, built once per run and cached. Every sound
## is deterministic (fixed noise seeds), and every loop has whole cycles of each component in its length, so it joins without a click.
##
##   * "room"     4 s loop: a refrigerator's mains hum (60 Hz and harmonics, slowly swelling) over a soft low room tone. Human scale.
##   * "buzz"     1 s loop: a fly's wings. House flies beat their wings at about 190-200 Hz (Wigglesworth 1972, cited at hypertextbook.com),
##                so the fundamental is 195 Hz with falling harmonics, a slight wobble and a beat. This is also inside the range (80-380 Hz)
##                that Phidippus audax's auditory neurons answered to (Shamble et al. 2016, Current Biology), so the spider plausibly hears
##                it too.
##   * "takeoff"  0.4 s: the buzz rising from 120 to 195 Hz as the wings come up to speed, with a puff of air.
##   * "thrum"    0.5 s: a felt vibration, translated: a low 55 and 90 Hz knock that dies away. Spiders feel substrate vibration through
##                slit sensilla in their legs, mostly tens to hundreds of hertz; this is a stand-in for that feeling, not a recording.
##   * "thud"     0.6 s: something far off in the house (a door, a footstep). Human scale.
##   * "whoosh"   2.5 s: air moving as a large shape passes the window (the shadow event).

const RATE := 22050
static var _cache: Dictionary = {}


static func stream(sound_name: String) -> AudioStreamWAV:
	if not _cache.has(sound_name):
		_cache[sound_name] = _make(sound_name)
	return _cache[sound_name]


static func names() -> Array[String]:
	return ["room", "buzz", "takeoff", "thrum", "thud", "whoosh"]


static func _make(sound_name: String) -> AudioStreamWAV:
	match sound_name:
		"room":
			return _wav(_room(), true)
		"buzz":
			return _wav(_buzz(), true)
		"takeoff":
			return _wav(_takeoff(), false)
		"thrum":
			return _wav(_thrum(), false)
		"thud":
			return _wav(_thud(), false)
		"whoosh":
			return _wav(_whoosh(), false)
	push_error("SoundBank: no sound '%s'" % sound_name)
	return _wav(PackedFloat32Array([0.0]), false)


static func _wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


## Low noise that loops: one-pole low-passed white noise, cross-faded over `fade` samples so the end runs into the start.
static func _low_noise(n: int, cutoff_hz: float, seed_value: int, fade: int = 2000) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var a := 1.0 - exp(-TAU * cutoff_hz / float(RATE))
	var raw := PackedFloat32Array()
	raw.resize(n + fade)
	var y := 0.0
	for i in n + fade:
		y += a * (rng.randf_range(-1.0, 1.0) - y)
		raw[i] = y
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = raw[i]
	for i in fade:
		var k := float(i) / float(fade)
		out[i] = raw[i] * k + raw[n + i] * (1.0 - k)
	return out


static func _normalize(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0
	for v in s:
		m = maxf(m, absf(v))
	if m > 0.0:
		for i in s.size():
			s[i] = s[i] * peak / m
	return s


static func _room() -> PackedFloat32Array:
	var n := RATE * 4
	var tone := _low_noise(n, 180.0, 1101)
	var tone_peak := 0.0
	for v in tone:
		tone_peak = maxf(tone_peak, absf(v))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var swell := 1.0 + 0.12 * sin(TAU * 0.5 * t)
		var hum := 0.30 * sin(TAU * 60.0 * t) + 0.16 * sin(TAU * 120.0 * t + 0.4) + 0.07 * sin(TAU * 180.0 * t + 1.1) + 0.04 * sin(TAU * 240.0 * t + 2.0)
		out[i] = hum * swell + 0.35 * tone[i] / maxf(tone_peak, 1.0e-6)
	return _normalize(out, 0.7)


static func _wings(t: float, f0: float, phase: float) -> float:
	var v := 0.0
	for k in range(1, 11):
		v += sin(float(k) * phase + 0.3 * float(k)) / pow(float(k), 1.2)
	return v


static func _buzz() -> PackedFloat32Array:
	var n := RATE  # 1 s: 195, 7 and 11 Hz all complete whole cycles
	var out := PackedFloat32Array()
	out.resize(n)
	var f0 := 195.0
	var beta := 0.02 * f0 / 7.0
	for i in n:
		var t := float(i) / float(RATE)
		var phase := TAU * f0 * t + beta * sin(TAU * 7.0 * t)
		out[i] = _wings(t, f0, phase) * (1.0 + 0.15 * sin(TAU * 11.0 * t))
	return _normalize(out, 0.8)


static func _takeoff() -> PackedFloat32Array:
	var n := int(RATE * 0.4)
	var puff := _low_noise(n, 900.0, 2202, 10)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(RATE)
		var f := lerpf(120.0, 195.0, clampf(t / 0.25, 0.0, 1.0))
		phase += TAU * f / float(RATE)
		var env := clampf(t / 0.03, 0.0, 1.0) * clampf((0.4 - t) / 0.12, 0.0, 1.0)
		out[i] = (_wings(t, f, phase) + 2.0 * puff[i] * exp(-t / 0.06)) * env
	return _normalize(out, 0.8)


static func _thrum() -> PackedFloat32Array:
	var n := int(RATE * 0.5)
	var grit := _low_noise(n, 140.0, 3303, 10)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := clampf(t / 0.008, 0.0, 1.0) * exp(-t / 0.11)
		out[i] = (0.7 * sin(TAU * 55.0 * t) + 0.4 * sin(TAU * 90.0 * t + 0.5) + 0.8 * grit[i]) * env
	return _normalize(out, 0.9)


static func _thud() -> PackedFloat32Array:
	var n := int(RATE * 0.6)
	var body := _low_noise(n, 90.0, 4404, 10)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := clampf(t / 0.005, 0.0, 1.0) * exp(-t / 0.09)
		out[i] = (sin(TAU * 70.0 * t) * 0.6 + body[i] * 2.0) * env
	return _normalize(out, 0.8)


static func _whoosh() -> PackedFloat32Array:
	var n := int(RATE * 2.5)
	var air := _low_noise(n, 420.0, 5505, 10)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / float(RATE)
		var env := sin(PI * clampf(t / 2.5, 0.0, 1.0))
		out[i] = air[i] * env * env
	return _normalize(out, 0.7)
