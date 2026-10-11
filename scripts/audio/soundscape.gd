extends Node3D
## T12a, what the player hears (ROADMAP step 3; spec 16). Two layers on their own buses, each with its own volume:
##   * Ambience (human scale): a refrigerator's hum and room tone, a thud somewhere in the house now and then, and air moving as the
##     shadow passes the window.
##   * Cues (the spider's world): each flying fly's buzz, placed where the fly is (the camera hears it), louder and higher while a caught
##     fly struggles; a whirr when a fly takes off; a low thrum when the spider feels a vibration through its feet (VibrationSense).
## Nothing here is claimed to be what a spider hears (spec 16). The buzz is the fly as a person would hear it, though at 195 Hz it is
## also inside the range Phidippus audax's auditory neurons answered to (Shamble et al. 2016). The thrum stands in for a felt vibration.
## Every cue that matters also makes a caption (the `caption` signal), so a muted player misses nothing (U01). World sounds pause with
## the game. In slow motion SimClock slows all playback, so the world sounds slower and lower too.
##
## T12b (Nathan: "i dont hear anything while playing"; "you can optomize for headphones or have a setting for switvhing"): louder levels,
## birds outside the window, and the setting "headphones". Off (the default, for laptop and small speakers), the Master bus cuts the deep
## bass such speakers cannot play and lifts the 1-3 kHz presence, a little louder overall. On, the full range plays as made.

signal caption(text: String)

const SoundBank = preload("res://scripts/audio/sound_bank.gd")
const VibrationSense = preload("res://scripts/perception/vibration_sense.gd")

const BUSES: Array[String] = ["Ambience", "Cues"]
const ROOM_DB := -7.0
const THUD_DB := -6.0
const WHOOSH_DB := -4.0
const BIRDS_DB := -16.0
const BUZZ_DB := 0.0
const STRUGGLE_DB := 4.0
const TAKEOFF_DB := 0.0
const THRUM_DB := 0.0
const THUD_EVERY_S := Vector2(25.0, 70.0)
const BIRDS_EVERY_S := Vector2(9.0, 30.0)
## The speaker setting's effects on Master, in order: cut below 110 Hz, lift the presence, a little more level.
const SPEAKER_EQ_DB := [-24.0, -9.0, 1.0, 3.0, 4.0, 1.0]   # AudioEffectEQ6 bands: 32, 100, 320, 1000, 3200, 10000 Hz
const SPEAKER_GAIN_DB := 3.0
const SPEAKER_EFFECTS := 2                 # the first two effects on Master are the speaker shaping; the limiter after them is always on
const LIMIT_DB := -1.0                     # nothing louder than this leaves the game (a recording of speaker mode peaked at 0 dBFS)
const HEAR_WU := 10.0          # a fly taking off this close gets a caption

var settings: Node
var prey: Node3D          # PreyDirector
var spider: Node3D        # SpiderMotor
var habitat_loop: Node    # the windowsill's loop (null in the lab)
var vibration: Node       # VibrationSense
var seed_value: int = 1

var _room: AudioStreamPlayer
var _whoosh: AudioStreamPlayer
var _thud: AudioStreamPlayer
var _birds: AudioStreamPlayer
var _birds_in: float = 0.0
var _buzz: Dictionary = {}        # fly id -> AudioStreamPlayer3D
var _was_flying: Dictionary = {}  # fly id -> bool
var _rng := RandomNumberGenerator.new()
var _thud_in: float = 0.0
var _phase := ""


func _ready() -> void:
	ensure_buses()
	apply_volumes()
	if settings != null:
		settings.setting_changed.connect(func(key: String) -> void:
			if key.begins_with("volume_") or key == "headphones":
				apply_volumes())
	_rng.seed = seed_value
	_thud_in = _rng.randf_range(THUD_EVERY_S.x, THUD_EVERY_S.y)
	_room = _player("room", "Ambience", ROOM_DB)
	_room.play()
	_whoosh = _player("whoosh", "Ambience", WHOOSH_DB)
	_thud = _player("thud", "Ambience", THUD_DB)
	_birds = _player("birds", "Ambience", BIRDS_DB)
	_birds_in = _rng.randf_range(2.0, BIRDS_EVERY_S.y * 0.5)
	if vibration != null:
		vibration.felt.connect(_on_felt)


## Every sound stops when the world goes (a quit, a return to the checkpoint), so no playback outlives its player.
func _exit_tree() -> void:
	for c in get_children():
		if c is AudioStreamPlayer:
			(c as AudioStreamPlayer).stop()
		elif c is AudioStreamPlayer3D:
			(c as AudioStreamPlayer3D).stop()


## The two buses, sent to Master, and the speaker effects on Master, made once per run.
static func ensure_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	var m := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(m) == 0:
		var eq := AudioEffectEQ6.new()
		for band in 6:
			eq.set_band_gain_db(band, float(SPEAKER_EQ_DB[band]))
		AudioServer.add_bus_effect(m, eq)
		var gain := AudioEffectAmplify.new()
		gain.volume_db = SPEAKER_GAIN_DB
		AudioServer.add_bus_effect(m, gain)
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = LIMIT_DB
		AudioServer.add_bus_effect(m, limiter)


## True while the speaker shaping is on (the "headphones" setting off).
static func speaker_mode() -> bool:
	var m := AudioServer.get_bus_index("Master")
	return AudioServer.get_bus_effect_count(m) > 0 and AudioServer.is_bus_effect_enabled(m, 0)


## Volumes from Settings (0 to 1 each); 0 mutes the bus.
func apply_volumes() -> void:
	if settings == null:
		return
	_set_bus("Master", float(settings.get_value("volume_master")))
	var speakers := not bool(settings.get_value("headphones"))
	var m := AudioServer.get_bus_index("Master")
	for e in mini(SPEAKER_EFFECTS, AudioServer.get_bus_effect_count(m)):
		AudioServer.set_bus_effect_enabled(m, e, speakers)
	_set_bus("Ambience", float(settings.get_value("volume_ambience")))
	_set_bus("Cues", float(settings.get_value("volume_cues")))


static func _set_bus(bus: String, level: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, level <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(level, 0.001)))


func _player(sound: String, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.name = sound.capitalize()
	p.stream = SoundBank.stream(sound)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	return p


func _process(delta: float) -> void:
	_update_flies()
	_thud_in -= delta
	if _thud_in <= 0.0:
		_thud_in = _rng.randf_range(THUD_EVERY_S.x, THUD_EVERY_S.y)
		_thud.pitch_scale = _rng.randf_range(0.85, 1.15)
		_thud.play()
	_birds_in -= delta
	if _birds_in <= 0.0:
		_birds_in = _rng.randf_range(BIRDS_EVERY_S.x, BIRDS_EVERY_S.y)
		_birds.pitch_scale = _rng.randf_range(0.9, 1.12)
		_birds.play()
	if habitat_loop != null and is_instance_valid(habitat_loop):
		var phase := str(habitat_loop.get("event_phase"))
		if phase != _phase:
			if phase == "warning":
				_whoosh.play()
				caption.emit("[air stirs beyond the window]")
			elif phase == "passing":
				caption.emit("[a shadow sweeps over the sill]")
			_phase = phase


## Each fly buzzes while it flies, and while it struggles in the jaws; take-offs whirr. Players are made as flies appear and freed as they go.
func _update_flies() -> void:
	if prey == null or not is_instance_valid(prey):
		return
	var alive := {}
	for f: Node3D in prey.flies:
		if not is_instance_valid(f):
			continue
		var id := str(f.id)
		alive[id] = true
		var p: AudioStreamPlayer3D = _buzz.get(id)
		if p == null:
			p = AudioStreamPlayer3D.new()
			p.name = "Buzz_" + id
			p.stream = SoundBank.stream("buzz")
			p.bus = "Cues"
			p.unit_size = 12.0
			p.max_distance = 80.0
			p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
			add_child(p)
			_buzz[id] = p
		p.global_position = f.global_position
		var struggling: bool = bool(f.get("struggling")) and prey.held == f
		var flying: bool = f.is_flying()
		var base_pitch := 0.94 + 0.12 * float(absi(hash(id)) % 1000) / 1000.0   # each fly its own note
		p.pitch_scale = base_pitch * (1.15 if struggling else 1.0)
		p.volume_db = STRUGGLE_DB if struggling else BUZZ_DB
		var want: bool = flying or struggling
		if want and not p.playing:
			p.play(fposmod(float(absi(hash(id)) % 997) / 997.0, 1.0))
		elif not want and p.playing:
			p.stop()
		if flying and not bool(_was_flying.get(id, false)):
			_take_off(f)
		_was_flying[id] = flying
	for id: String in _buzz.keys():
		if not alive.has(id):
			(_buzz[id] as Node).queue_free()
			_buzz.erase(id)
			_was_flying.erase(id)


func _take_off(f: Node3D) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = SoundBank.stream("takeoff")
	p.bus = "Cues"
	p.volume_db = TAKEOFF_DB
	p.unit_size = 12.0
	p.max_distance = 80.0
	add_child(p)
	p.global_position = f.global_position
	p.finished.connect(p.queue_free)
	p.play()
	if spider != null and is_instance_valid(spider) and f.global_position.distance_to(spider.global_position) <= HEAR_WU:
		caption.emit("[buzzing, %s]" % VibrationSense.direction_word(spider, f.global_position))


## A felt vibration: a low thrum from its direction (a short distance out from the spider that way), and a caption.
func _on_felt(ev: Dictionary) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = SoundBank.stream("thrum")
	p.bus = "Cues"
	p.volume_db = THRUM_DB + linear_to_db(clampf(float(ev["strength"]), 0.05, 1.0)) * 0.5
	p.unit_size = 4.0
	add_child(p)
	var dir: Vector3 = ev.get("direction", Vector3.ZERO)
	p.global_position = spider.global_position + dir * 2.0 if spider != null else Vector3.ZERO
	p.finished.connect(p.queue_free)
	p.play()
	caption.emit("[felt: %s, %s]" % [str(ev["kind"]), str(ev["word"])])


## True while the given fly's buzz is playing (tests).
func is_buzzing(fly_id: String) -> bool:
	var p: AudioStreamPlayer3D = _buzz.get(fly_id)
	return p != null and p.playing


func buzz_player(fly_id: String) -> AudioStreamPlayer3D:
	return _buzz.get(fly_id)


func room_playing() -> bool:
	return _room != null and _room.playing
